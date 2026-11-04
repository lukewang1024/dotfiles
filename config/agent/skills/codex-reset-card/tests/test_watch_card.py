"""Offline watcher tests; no real credits or systemd timers are used."""

import contextlib
import datetime as dt
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import prepare_watch
import reset_card
import watch_card


def snapshot(used=99, expiration=1000):
    return {"rateLimits": {"primary": {"windowDurationMins": 10080, "usedPercent": used}},
            "rateLimitResetCredits": {"availableCount": 1, "credits": [
                {"id": "chosen-card", "status": "available", "resetType": "codexRateLimits", "expiresAt": expiration}]}}


class PlannerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        binary = self.root / "bin"
        binary.mkdir()
        for name in ("codex", "systemctl"):
            (binary / name).write_text("")
            (binary / name).chmod(0o700)
        self.env = {"PATH": str(binary), "XDG_CONFIG_HOME": str(self.root / "config with spaces%"),
                    "XDG_STATE_HOME": str(self.root / "state$files"), "HTTP_PROXY": "http://example.invalid:1234",
                    "NO_PROXY": "localhost"}

    def test_earliest_selection_requires_complete_details(self):
        data = snapshot()
        data["rateLimitResetCredits"]["credits"].append({"id": "earlier", "status": "available",
                                                          "resetType": "codexRateLimits", "expiresAt": 900})
        data["rateLimitResetCredits"]["availableCount"] = 2
        self.assertEqual(prepare_watch.select_card(data)["id"], "earlier")
        data["rateLimitResetCredits"]["availableCount"] = 3
        with self.assertRaisesRegex(ValueError, "incomplete"):
            prepare_watch.select_card(data)
        self.assertEqual(prepare_watch.select_card(data, "chosen-card")["id"], "chosen-card")

    def test_earliest_selection_does_not_ignore_missing_expiration(self):
        data = snapshot()
        data["rateLimitResetCredits"]["credits"].append({"id": "unknown", "status": "available",
                                                          "resetType": "codexRateLimits"})
        data["rateLimitResetCredits"]["availableCount"] = 2
        with self.assertRaisesRegex(ValueError, "expiration is missing"):
            prepare_watch.select_card(data)
        self.assertEqual(prepare_watch.select_card(data, "chosen-card")["id"], "chosen-card")

    @unittest.skipUnless(sys.platform.startswith("linux"), "watcher timer requires Linux")
    def test_prepared_watcher_is_private_unarmed_and_runs_every_minute(self):
        result = prepare_watch.prepare(snapshot(), self.env, now=100)
        self.assertFalse(result["armed"])
        self.assertEqual(result["credit_id"], "chosen-card")
        config = json.loads(Path(result["config"]).read_text())
        self.assertEqual(config["monitor_deadline_epoch"], 1000)
        self.assertEqual(config["mode"], "weekly-zero")
        timer = Path(result["timer"]).read_text()
        self.assertIn("OnActiveSec=1s", timer)
        self.assertIn("OnUnitInactiveSec=60s", timer)
        for key in ("config", "environment_file", "service", "timer"):
            self.assertEqual(stat.S_IMODE(Path(result[key]).stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(Path(result["state_dir"]).stat().st_mode), 0o700)
        self.assertNotIn("example.invalid", json.dumps(result))
        saved = Path(result["environment_file"]).read_text()
        self.assertIn('http_proxy="http://example.invalid:1234"', saved)
        self.assertIn('no_proxy="localhost"', saved)
        original = Path(result["config"]).read_bytes()
        with self.assertRaisesRegex(ValueError, "already exists"):
            prepare_watch.prepare(snapshot(), self.env, now=100)
        self.assertEqual(Path(result["config"]).read_bytes(), original)

    @unittest.skipUnless(sys.platform.startswith("linux"), "watcher timer requires Linux")
    def test_nonexpiring_card_requires_explicit_monitor_deadline(self):
        data = snapshot(expiration=None)
        with self.assertRaisesRegex(ValueError, "known expiration"):
            prepare_watch.prepare(data, self.env, now=100)
        with self.assertRaisesRegex(ValueError, "requires an explicit"):
            prepare_watch.prepare(data, self.env, credit_id="chosen-card", now=100)
        until = dt.datetime.fromtimestamp(900, dt.timezone.utc)
        result = prepare_watch.prepare(data, self.env, credit_id="chosen-card", until=until, now=100)
        self.assertEqual(result["monitor_deadline_epoch"], 900)

    @unittest.skipUnless(sys.platform.startswith("linux") and Path("/usr/bin/systemd-analyze").exists(),
                         "systemd-analyze not installed on Linux")
    def test_systemd_accepts_generated_units_with_escaped_paths(self):
        result = prepare_watch.prepare(snapshot(), self.env, now=100)
        verified = subprocess.run(["/usr/bin/systemd-analyze", "--user", "verify", result["service"], result["timer"]],
                                  text=True, capture_output=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)


class FakeServer:
    snapshots = []
    outcomes = []
    calls = []
    def __init__(self, *args, **kwargs):
        pass
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass
    def call(self, method, params):
        if method == "account/rateLimits/read":
            if len(FakeServer.snapshots) > 1:
                return FakeServer.snapshots.pop(0)
            return FakeServer.snapshots[0]
        if method == "account/rateLimitResetCredit/consume":
            FakeServer.calls.append(params.copy())
            result = FakeServer.outcomes.pop(0)
            if isinstance(result, Exception):
                raise result
            return result
        raise AssertionError(method)


class WatcherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / "state"
        self.config = {"mode": "weekly-zero", "task_name": "codex-reset-card-watch-test",
                       "credit_id": "chosen-card", "idempotency_key": "e5268a0b-f088-4435-9ff1-03d7298dd50e",
                       "expires_at_epoch": 1000, "monitor_deadline_epoch": 1000, "max_runtime_seconds": 480,
                       "state_dir": str(self.state), "codex_path": "unused", "systemctl_path": "unused",
                       "required_proxy_variables": []}
        FakeServer.snapshots = [snapshot()]
        FakeServer.outcomes = []
        FakeServer.calls = []
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.stack.enter_context(mock.patch.object(reset_card, "AppServer", FakeServer))
        self.stack.enter_context(mock.patch.object(reset_card.time, "time", return_value=200))
        self.stack.enter_context(mock.patch.object(reset_card.time, "sleep"))
        self.real_disarm = watch_card.disarm
        self.disarm = self.stack.enter_context(mock.patch.object(watch_card, "disarm"))

    def status(self):
        return json.loads((self.state / "watch-status.json").read_text())

    def test_waits_before_zero_then_uses_only_selected_card_and_stops(self):
        watch_card.run(self.config)
        self.assertEqual(self.status()["state"], "waiting_for_zero")
        self.assertFalse((self.state / "watch-execution.json").exists())
        self.disarm.assert_not_called()
        FakeServer.snapshots = [snapshot(100)]
        FakeServer.outcomes = [{"outcome": "reset"}]
        watch_card.run(self.config)
        self.assertEqual(FakeServer.calls, [{"creditId": "chosen-card", "idempotencyKey": self.config["idempotency_key"]}])
        self.assertEqual(self.status()["outcome"], "reset")
        self.disarm.assert_called_once()
        self.assertEqual(json.loads((self.state / "receipt.json").read_text())["outcome"], "reset")
        watch_card.run(self.config)
        self.assertEqual(len(FakeServer.calls), 1)

    def test_fresh_check_prevents_use_if_weekly_limit_resets_first(self):
        FakeServer.snapshots = [snapshot(100), snapshot(100), snapshot(0)]
        with self.assertRaises(reset_card.StopTask):
            watch_card.run(self.config)
        self.assertEqual(FakeServer.calls, [])
        self.assertFalse((self.state / "receipt.json").exists())
        self.assertEqual(self.status()["state"], "execution_pending")

    def test_lost_response_retries_original_key_and_stops_on_receipt(self):
        FakeServer.snapshots = [snapshot(100)]
        FakeServer.outcomes = [TimeoutError("lost"), {"outcome": "alreadyRedeemed"}]
        watch_card.run(self.config)
        expected = {"creditId": "chosen-card", "idempotencyKey": self.config["idempotency_key"]}
        self.assertEqual(FakeServer.calls, [expected, expected])
        self.assertEqual(self.status()["outcome"], "alreadyRedeemed")
        self.disarm.assert_called_once()

    def test_lost_response_after_weekly_recovery_stays_unconfirmed(self):
        FakeServer.snapshots = [snapshot(100), snapshot(100), snapshot(100), snapshot(0), snapshot(0)]
        FakeServer.outcomes = [TimeoutError("lost response")]
        with self.assertRaises(reset_card.StopTask):
            watch_card.run(self.config)
        self.assertEqual(len(FakeServer.calls), 1)
        self.assertFalse((self.state / "receipt.json").exists())
        with mock.patch.object(reset_card.time, "time", return_value=680):
            watch_card.run(self.config)
        self.assertEqual(self.status()["state"], "attempt_unconfirmed")
        self.assertEqual(len(FakeServer.calls), 1)
        self.disarm.assert_called_once()

    def test_nonreset_and_unknown_receipts_stop_without_claiming_success(self):
        for outcome in ("nothingToReset", "noCredit", "unknownOutcome"):
            with self.subTest(outcome=outcome):
                self.config["state_dir"] = str(self.state / outcome)
                FakeServer.snapshots = [snapshot(100)]
                FakeServer.outcomes = [{"outcome": outcome}]
                FakeServer.calls = []
                self.disarm.reset_mock()
                watch_card.run(self.config)
                status = json.loads((Path(self.config["state_dir"]) / "watch-status.json").read_text())
                self.assertEqual(status["outcome"], outcome)
                self.assertEqual(status["state"], "unknown_receipt" if outcome == "unknownOutcome" else "receipt")
                self.assertEqual(len(FakeServer.calls), 1)
                self.disarm.assert_called_once()

    def test_expiry_stops_without_connection_or_card_use(self):
        with mock.patch.object(reset_card.time, "time", return_value=1001):
            watch_card.run(self.config)
        self.assertEqual(self.status()["state"], "monitor_deadline_reached")
        self.assertEqual(FakeServer.calls, [])
        self.disarm.assert_called_once()

    def test_expired_uncertain_attempt_is_never_reopened(self):
        self.state.mkdir()
        execution = dict(self.config, not_before_epoch=100, deadline_epoch=200)
        reset_card.save_json(self.state / "watch-execution.json", execution)
        reset_card.save_json(self.state / "attempt.json", {"credit_id": "chosen-card",
                             "idempotency_key": self.config["idempotency_key"]})
        watch_card.run(self.config)
        self.assertEqual(self.status()["state"], "attempt_unconfirmed")
        self.assertEqual(FakeServer.calls, [])
        self.disarm.assert_called_once()

    def test_incomplete_snapshot_never_consumes_or_disarms(self):
        FakeServer.snapshots = [{"rateLimits": {"primary": {"usedPercent": 100}},
                                 "rateLimitResetCredits": {"availableCount": 1, "credits": None}}]
        with self.assertRaises(reset_card.StopTask):
            watch_card.run(self.config)
        self.assertEqual(FakeServer.calls, [])
        self.disarm.assert_not_called()

    def test_disarm_checks_timer_is_disabled_and_inactive(self):
        results = [subprocess.CompletedProcess([], 0, "", ""),
                   subprocess.CompletedProcess([], 1, "disabled\n", ""),
                   subprocess.CompletedProcess([], 3, "inactive\n", "")]
        with mock.patch.object(watch_card.subprocess, "run", side_effect=results) as command:
            self.real_disarm(self.config)
        self.assertEqual(command.call_count, 3)
        self.assertEqual(command.call_args_list[0].args[0][-1], "codex-reset-card-watch-test.timer")


if __name__ == "__main__":
    unittest.main()

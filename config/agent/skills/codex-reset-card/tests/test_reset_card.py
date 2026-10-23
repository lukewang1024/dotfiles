"""Offline checks: no real account, card redemption or timer activation."""

import contextlib
import copy
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
import prepare_timer
import reset_card


def snapshot(expiration=1000):
    return {"rateLimitResetCredits": {"availableCount": 1, "credits": [{
        "id": "chosen-card", "status": "available", "resetType": "codexRateLimits",
        "expiresAt": expiration,
    }]}, "rateLimits": {"primary": {"usedPercent": 90}}}


class ExecutorTests(unittest.TestCase):
    def setUp(self):
        self.contexts = contextlib.ExitStack()
        self.addCleanup(self.contexts.close)
        directory = self.contexts.enter_context(tempfile.TemporaryDirectory())
        self.state = Path(directory) / "state"
        self.config = {
            "credit_id": "chosen-card", "idempotency_key": "e5268a0b-f088-4435-9ff1-03d7298dd50e",
            "not_before_epoch": 100, "expires_at_epoch": 1000,
            "max_runtime_seconds": 480, "state_dir": str(self.state), "codex_path": "unused",
        }
        self.contexts.enter_context(contextlib.redirect_stdout(io.StringIO()))

    def run_execute(self, outcomes, reads=None):
        calls = []
        consume = mock.Mock(side_effect=outcomes)
        snapshots = iter(reads or [])

        def rpc(method, params):
            calls.append((method, copy.deepcopy(params)))
            if method == "account/rateLimits/read":
                return next(snapshots, snapshot(self.config["expires_at_epoch"]))
            return consume(params)

        server = mock.MagicMock()
        server.__enter__.return_value = server
        server.call.side_effect = rpc
        with mock.patch.object(reset_card, "AppServer", return_value=server) as factory, \
                mock.patch.object(reset_card.time, "time", return_value=200), \
                mock.patch.object(reset_card.time, "sleep"):
            reset_card.execute(self.config)
        return calls, consume, factory

    def test_early_and_expired_execution_never_connect(self):
        for instant in (99, 580, 1001):
            with self.subTest(instant=instant), \
                    mock.patch.object(reset_card.time, "time", return_value=instant), \
                    mock.patch.object(reset_card, "AppServer") as factory:
                with self.assertRaises(reset_card.StopTask):
                    reset_card.execute(self.config)
                factory.assert_not_called()
                self.assertFalse((self.state / "attempt.json").exists())

    def test_transport_loss_reuses_key_even_if_card_disappears(self):
        missing = {"rateLimitResetCredits": {"availableCount": 0, "credits": []}}
        calls, consume, factory = self.run_execute(
            [TimeoutError("lost reply"), {"outcome": "alreadyRedeemed"}], [snapshot(), missing, missing])
        expected = {"creditId": "chosen-card", "idempotencyKey": self.config["idempotency_key"]}
        self.assertEqual(consume.call_args_list, [mock.call(expected), mock.call(expected)])
        self.assertEqual(factory.call_count, 2)
        self.assertEqual(json.loads((self.state / "receipt.json").read_text())["outcome"], "alreadyRedeemed")
        with mock.patch.object(reset_card, "AppServer") as factory:
            reset_card.execute(self.config)
            factory.assert_not_called()

    def test_all_known_outcomes_are_terminal_and_noop_is_not_reset(self):
        for outcome in sorted(reset_card.OUTCOMES):
            with self.subTest(outcome=outcome):
                self.config["state_dir"] = str(self.state / outcome)
                _, consume, _ = self.run_execute([{"outcome": outcome}])
                consume.assert_called_once()
                directory = Path(self.config["state_dir"])
                events = [json.loads(line) for line in (directory / "events.jsonl").read_text().splitlines()]
                result = next(event for event in events if event["event"] == "result")
                self.assertEqual(result["reset_confirmed"], outcome in ("reset", "alreadyRedeemed"))
                self.run_execute([])[1].assert_not_called()

    def test_unknown_outcome_is_preserved_and_not_retried(self):
        with self.assertRaises(reset_card.StopTask):
            self.run_execute([{"outcome": "new-server-outcome"}])
        self.assertEqual(json.loads((self.state / "receipt.json").read_text())["outcome"], "new-server-outcome")
        with mock.patch.object(reset_card, "AppServer") as factory:
            with self.assertRaises(reset_card.StopTask):
                reset_card.execute(self.config)
            factory.assert_not_called()

    def test_changed_identity_is_rejected_before_connecting(self):
        for filename in ("attempt.json", "receipt.json"):
            with self.subTest(filename=filename):
                record = {"credit_id": "chosen-card", "idempotency_key": "different-key", "outcome": "reset"}
                reset_card.save_json(self.state / filename, record)
                with mock.patch.object(reset_card, "AppServer") as factory:
                    with self.assertRaises(reset_card.StopTask):
                        reset_card.execute(self.config)
                    factory.assert_not_called()
                (self.state / filename).unlink()

    def test_card_validation_never_substitutes_other_card(self):
        for change in ({"id": "other-card"}, {"status": "unknown"},
                       {"resetType": "other-limit"}, {"expiresAt": 1001}):
            with self.subTest(change=change):
                data = snapshot()
                data["rateLimitResetCredits"]["credits"][0].update(change)
                with self.assertRaises(reset_card.StopTask):
                    reset_card.selected_card(self.config, data)
        with self.assertRaises(reset_card.StopTask):
            reset_card.selected_card(self.config, {"rateLimitResetCredits": {"availableCount": 2, "credits": None}})

    def test_nonexpiring_card_has_finite_deadline(self):
        self.config["expires_at_epoch"] = None
        self.assertEqual(reset_card.deadline(self.config), 580)
        reset_card.selected_card(self.config, snapshot(None))
        self.run_execute([{"outcome": "reset"}])[1].assert_called_once()

    def test_readonly_transport_blocks_consume_and_inherits_proxy_pairs(self):
        fake = Path(self.state.parent) / "fake-codex"
        fake.write_text("#!" + sys.executable + "\n" + '''import json, os, sys
for line in sys.stdin:
    request = json.loads(line)
    if "id" not in request:
        continue
    result = {} if request["method"] == "initialize" else {
        "proxy_presence": {name: bool(os.environ.get(name)) for name in
                           ("HTTP_PROXY", "http_proxy", "NO_PROXY", "no_proxy")}}
    print(json.dumps({"id": request["id"], "result": result}), flush=True)
''')
        fake.chmod(0o700)
        with mock.patch.dict(os.environ, {"HTTP_PROXY": "http://example.invalid:1234", "no_proxy": "localhost"}, clear=True):
            with reset_card.AppServer({"codex_path": str(fake)}) as server:
                result = server.call("account/rateLimits/read", {})
                self.assertTrue(all(result["proxy_presence"].values()))
                with self.assertRaises(reset_card.StopTask):
                    server.call("account/rateLimitResetCredit/consume", {})


class PlannerTests(unittest.TestCase):
    def setUp(self):
        self.contexts = contextlib.ExitStack()
        self.addCleanup(self.contexts.close)
        root = self.contexts.enter_context(tempfile.TemporaryDirectory())
        self.root = Path(root)
        binary = self.root / "bin/codex"
        binary.parent.mkdir()
        binary.write_text("")
        binary.chmod(0o700)
        self.environment = {
            "PATH": str(binary.parent), "XDG_CONFIG_HOME": str(self.root / "config with spaces%"),
            "XDG_STATE_HOME": str(self.root / "state$files"), "HTTP_PROXY": "http://example.invalid:1234",
            "NO_PROXY": "localhost,127.0.0.1", "CODEX_HOME": str(self.root / "account"),
        }
        self.at = prepare_timer.execution_time("2026-10-24T05:00:00+08:00")
        self.start = int(self.at.timestamp())

    def plan(self, **changes):
        parameters = dict(snapshot=snapshot(self.start + 100), credit_id="chosen-card", at=self.at,
                          name=None, runtime=480, environment=self.environment, now=self.start - 100)
        parameters.update(changes)
        return prepare_timer.prepare(**parameters)

    def test_generated_plan_is_private_bounded_unarmed_and_in_utc(self):
        result = self.plan()
        self.assertFalse(result["armed"])
        config = json.loads(Path(result["config"]).read_text())
        self.assertEqual(config["deadline_epoch"], self.start + 100)
        self.assertEqual(config["not_before_epoch"], self.start)
        self.assertIn("OnCalendar=2026-10-23 21:00:00 UTC", Path(result["timer"]).read_text())
        for key in ("config", "environment_file", "service", "timer"):
            self.assertEqual(stat.S_IMODE(Path(result[key]).stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(Path(result["state_dir"]).stat().st_mode), 0o700)
        self.assertNotIn("example.invalid", json.dumps(result))
        env_text = Path(result["environment_file"]).read_text()
        self.assertIn('http_proxy="http://example.invalid:1234"', env_text)
        self.assertIn('no_proxy="localhost,127.0.0.1"', env_text)
        self.assertEqual(config["credit_id"], "chosen-card")

    def test_existing_plan_cannot_rotate_idempotency_key(self):
        result = self.plan()
        original = Path(result["config"]).read_bytes()
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.plan()
        self.assertEqual(Path(result["config"]).read_bytes(), original)

    def test_invalid_selection_or_time_creates_no_task(self):
        cases = ({"credit_id": "other-card"}, {"now": self.start},
                 {"snapshot": snapshot(self.start)}, {"runtime": 0},
                 {"name": "codex-reset-card-../../other"},
                 {"snapshot": {"rateLimitResetCredits": {"availableCount": 3, "credits": None}}})
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ValueError):
                self.plan(**case)
        self.assertFalse(Path(self.environment["XDG_CONFIG_HOME"]).exists())
        with self.assertRaises(ValueError):
            prepare_timer.execution_time("2026-10-24T05:00:00")

    def test_nonexpiring_plan_is_still_bounded(self):
        result = self.plan(snapshot=snapshot(None))
        self.assertEqual(json.loads(Path(result["config"]).read_text())["deadline_epoch"], self.start + 480)

    def test_proxy_normalization_preserves_distinct_existing_values(self):
        normalized = prepare_timer.process_environment({"HTTP_PROXY": "upper", "http_proxy": "lower", "no_proxy": "local"})
        self.assertEqual(normalized["HTTP_PROXY"], "upper")
        self.assertEqual(normalized["http_proxy"], "lower")
        self.assertEqual(normalized["NO_PROXY"], "local")
        with self.assertRaises(ValueError):
            prepare_timer.process_environment({"HTTPS_PROXY": "invalid\nentry"})

    @unittest.skipUnless(Path("/usr/bin/systemd-analyze").exists(), "systemd-analyze not installed")
    def test_systemd_accepts_units_with_escaped_paths(self):
        result = self.plan()
        verified = subprocess.run(["/usr/bin/systemd-analyze", "--user", "verify", result["service"], result["timer"]],
                                  text=True, capture_output=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)


if __name__ == "__main__":
    unittest.main()

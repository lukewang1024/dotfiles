#!/usr/bin/env python3
"""Check a weekly limit and redeem one selected credit only when it is exhausted."""

import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

import reset_card


def weekly_window(snapshot):
    limits = snapshot.get("rateLimits") or {}
    windows = [limits.get("primary"), limits.get("secondary")]
    matches = [window for window in windows if isinstance(window, dict)
               and window.get("windowDurationMins") == 10080]
    if len(matches) != 1:
        raise reset_card.StopTask("Expected exactly one Codex weekly limit window")
    used = matches[0].get("usedPercent")
    if isinstance(used, bool) or not isinstance(used, (int, float)) or not 0 <= used <= 100:
        raise reset_card.StopTask("Weekly used percentage is missing or invalid")
    return matches[0]


def read_snapshot(config):
    missing = [name for name in config["required_proxy_variables"] if not os.environ.get(name)]
    if missing:
        raise reset_card.StopTask("Required proxy variables are absent: " + ", ".join(missing))
    with reset_card.AppServer(config) as server:
        return server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})


def save_status(config, state, weekly=None, **fields):
    status = {"at": dt.datetime.now(dt.timezone.utc).isoformat(), "state": state,
              "credit_id": config["credit_id"], **fields}
    if weekly is not None:
        status.update({"weekly_used_percent": weekly["usedPercent"],
                       "weekly_remaining_percent": 100 - weekly["usedPercent"],
                       "weekly_resets_at": weekly.get("resetsAt")})
    reset_card.save_json(Path(config["state_dir"]) / "watch-status.json", status)
    reset_card.event(config, "watch_status", **{k: v for k, v in status.items() if k != "at"})
    return status


def disarm(config):
    timer = config["task_name"] + ".timer"
    base = [config["systemctl_path"], "--user"]
    result = subprocess.run(base + ["disable", "--now", timer], capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise reset_card.StopTask("Could not disable the completed watcher timer")
    enabled = subprocess.run(base + ["is-enabled", timer], capture_output=True, text=True, timeout=10)
    active = subprocess.run(base + ["is-active", timer], capture_output=True, text=True, timeout=10)
    if enabled.stdout.strip() != "disabled" or active.stdout.strip() != "inactive":
        raise reset_card.StopTask("Watcher timer disablement could not be verified")
    reset_card.event(config, "watch_disarmed", timer=timer)


def terminal(config, state, weekly=None, **fields):
    save_status(config, state, weekly, **fields)
    disarm(config)


def redeem(config):
    """Recheck the weekly limit immediately before every consume request."""
    original = reset_card.AppServer

    class GuardedServer(original):
        def call(self, method, params):
            if method == "account/rateLimitResetCredit/consume":
                fresh = super().call("account/rateLimits/read", {"excludeResetCreditDetails": False})
                if weekly_window(fresh)["usedPercent"] < 100:
                    raise reset_card.StopTask("Weekly limit is no longer exhausted; no consume request sent")
                reset_card.selected_card(config, fresh, allow_missing=True)
                reset_card.check_window(config)
            return super().call(method, params)

    reset_card.AppServer = GuardedServer
    try:
        reset_card.execute(config)
    finally:
        reset_card.AppServer = original


def inspect_receipt(config, receipt_path):
    receipt = json.loads(receipt_path.read_text())
    if any(receipt.get(key) != config[key] for key in ("credit_id", "idempotency_key")):
        raise reset_card.StopTask("Saved receipt does not match this task's card and idempotency key")
    return receipt.get("outcome")


def check(config):
    if time.time() >= config["monitor_deadline_epoch"]:
        raise reset_card.StopTask("Monitoring deadline has passed")
    snapshot = read_snapshot(config)
    card = reset_card.selected_card(config, snapshot)
    weekly = weekly_window(snapshot)
    print(json.dumps({"read_only": True, "credit_id": card["id"], "expires_at": card["expiresAt"],
                      "weekly": weekly, "monitor_deadline_epoch": config["monitor_deadline_epoch"]},
                     ensure_ascii=False), flush=True)


def run(config):
    directory = Path(config["state_dir"])
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / "watch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        receipt_path = directory / "receipt.json"
        attempt_path = directory / "attempt.json"
        execution_path = directory / "watch-execution.json"
        if receipt_path.exists():
            outcome = inspect_receipt(config, receipt_path)
            terminal(config, "receipt" if outcome in reset_card.OUTCOMES else "unknown_receipt", outcome=outcome)
            return
        prepared = None
        if execution_path.exists():
            prepared = json.loads(execution_path.read_text())
            if any(prepared.get(key) != config[key] for key in
                   ("credit_id", "idempotency_key", "state_dir", "expires_at_epoch")):
                raise reset_card.StopTask("Saved execution window does not match the watcher")
        elif attempt_path.exists():
            raise reset_card.StopTask("Attempt exists without its original execution window")
        now = time.time()
        if prepared and now >= reset_card.deadline(prepared):
            terminal(config, "attempt_unconfirmed" if attempt_path.exists() else "execution_window_expired")
            return
        if now >= config["monitor_deadline_epoch"]:
            state = "attempt_unconfirmed" if attempt_path.exists() else "monitor_deadline_reached"
            terminal(config, state)
            return
        try:
            snapshot = read_snapshot(config)
            weekly = weekly_window(snapshot)
            if prepared is None and weekly["usedPercent"] < 100:
                reset_card.selected_card(config, snapshot)
                save_status(config, "waiting_for_zero", weekly)
                return
            if prepared is None:
                reset_card.selected_card(config, snapshot)
                start = int(time.time())
                end = min(start + config["max_runtime_seconds"], config["monitor_deadline_epoch"])
                if end <= start:
                    terminal(config, "monitor_deadline_reached", weekly)
                    return
                prepared = dict(config, not_before_epoch=start, deadline_epoch=end,
                                execute_at=dt.datetime.fromtimestamp(start, dt.timezone.utc).isoformat())
                reset_card.save_json(execution_path, prepared)
            save_status(config, "execution_pending", weekly)
            redeem(prepared)
            if receipt_path.exists():
                outcome = inspect_receipt(config, receipt_path)
                terminal(config, "receipt" if outcome in reset_card.OUTCOMES else "unknown_receipt", outcome=outcome)
        except Exception as error:
            if receipt_path.exists():
                outcome = inspect_receipt(config, receipt_path)
                terminal(config, "receipt" if outcome in reset_card.OUTCOMES else "unknown_receipt", outcome=outcome)
                return
            if prepared and time.time() >= reset_card.deadline(prepared) and not receipt_path.exists():
                terminal(config, "attempt_unconfirmed" if attempt_path.exists() else "execution_window_expired",
                         error_type=type(error).__name__)
                return
            save_status(config, "execution_pending" if prepared else "query_error", error_type=type(error).__name__)
            raise


def main():
    os.umask(0o077)
    os.environ.update(reset_card.proxy_environment(os.environ))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Read only; never submit a credit")
    mode.add_argument("--run", action="store_true", help="Check the weekly limit and execute the prepared task")
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text())
    uuid.UUID(config["idempotency_key"])
    if config.get("mode") != "weekly-zero" or not re.fullmatch(r"codex-reset-card-[A-Za-z0-9_.-]{1,90}", config["task_name"]):
        raise reset_card.StopTask("Invalid watcher mode or task name")
    if args.check:
        check(config)
    else:
        run(config)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error_type": type(error).__name__, "reason": str(error) if isinstance(error, reset_card.StopTask) else None}),
              file=sys.stderr, flush=True)
        sys.exit(1)

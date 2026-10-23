#!/usr/bin/env python3
"""Redeem one explicitly selected Codex reset credit from a local timer."""

import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


class StopTask(Exception):
    pass


OUTCOMES = {"reset", "alreadyRedeemed", "nothingToReset", "noCredit"}


def proxy_environment(environment):
    copied = dict(environment)
    for upper in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY"):
        lower = upper.lower()
        first = copied.get(upper) or copied.get(lower)
        second = copied.get(lower) or copied.get(upper)
        if first:
            copied[upper], copied[lower] = first, second
    return copied


def deadline(config):
    ends = [config["not_before_epoch"] + config.get("max_runtime_seconds", 480)]
    for key in ("expires_at_epoch", "deadline_epoch"):
        if config.get(key) is not None:
            ends.append(config[key])
    return min(ends)


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def event(config, name, **fields):
    entry = {"at": dt.datetime.now(dt.timezone.utc).isoformat(), "event": name, **fields}
    line = json.dumps(entry, ensure_ascii=False)
    print(line, flush=True)
    directory = Path(config["state_dir"])
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / "events.jsonl").open("a") as stream:
        stream.write(line + "\n")


def check_window(config, now=None):
    now = time.time() if now is None else now
    if now < config["not_before_epoch"]:
        raise StopTask("Scheduled time has not arrived; no credit was consumed")
    if now >= deadline(config):
        raise StopTask("Redemption window has ended; no new request will be sent")


class AppServer:
    def __init__(self, config, allow_consume=False, deadline=None):
        self.allow_consume = allow_consume
        self.deadline = deadline
        self.buffer = b""
        self.request_id = 0
        self.process = subprocess.Popen(
            [config["codex_path"], "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=proxy_environment(os.environ),
            start_new_session=True,
            bufsize=0,
        )
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)

    def __enter__(self):
        try:
            self.call("initialize", {
                "clientInfo": {"name": "reset_card_once", "version": "1.0.0"},
                "capabilities": {"experimentalApi": True},
            })
            self.send({"method": "initialized", "params": {}})
            return self
        except BaseException:
            self.close()
            raise

    def __exit__(self, *_):
        self.close()

    def close(self):
        self.selector.close()
        try:
            self.process.stdin.close()
        except (BrokenPipeError, OSError):
            pass
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(self.process.pid, signal.SIGTERM)
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait()
        self.process.stdout.close()

    def send(self, value):
        self.process.stdin.write((json.dumps(value) + "\n").encode())
        self.process.stdin.flush()

    def call(self, method, params):
        allowed = {"initialize", "account/rateLimits/read"}
        if self.allow_consume:
            allowed.add("account/rateLimitResetCredit/consume")
        if method not in allowed:
            raise StopTask("This connection does not permit the requested method")
        timeout = 40.0
        if self.deadline is not None:
            timeout = min(timeout, self.deadline - time.time())
        if timeout <= 0:
            raise StopTask("Request deadline reached; no new request will be sent")
        self.request_id += 1
        request_id = self.request_id
        self.send({"id": request_id, "method": method, "params": params})
        end = time.monotonic() + timeout
        while True:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                if not line.strip():
                    continue
                response = json.loads(line)
                if response.get("id") != request_id:
                    continue
                if "error" in response:
                    error = response["error"]
                    raise RuntimeError("RPC error " + str(error.get("code")) + ": " + str(error.get("message")))
                return response["result"]
            remaining = end - time.monotonic()
            if remaining <= 0 or not self.selector.select(remaining):
                raise TimeoutError("Timed out waiting for " + method)
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError("App-server connection closed before " + method + " completed")
            self.buffer += chunk


def selected_card(config, snapshot, allow_missing=False):
    summary = snapshot.get("rateLimitResetCredits") or {}
    card = next((item for item in summary.get("credits") or [] if item.get("id") == config["credit_id"]), None)
    if card is None:
        if allow_missing:
            return None
        raise StopTask("Selected credit was not returned as available; no other credit will be selected")
    if card.get("resetType") != "codexRateLimits":
        raise StopTask("Selected credit has an unexpected type")
    status = card.get("status")
    if status != "available" and not (allow_missing and status in ("redeeming", "redeemed")):
        raise StopTask("Selected credit is unavailable")
    if card.get("expiresAt") != config["expires_at_epoch"]:
        raise StopTask("Selected credit expiration does not match the saved task")
    return card


def check(config):
    if config.get("expires_at_epoch") is not None and time.time() >= config["expires_at_epoch"]:
        raise StopTask("Selected credit has expired")
    with AppServer(config) as server:
        snapshot = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
        card = selected_card(config, snapshot)
        limits = snapshot.get("rateLimits") or {}
        event(config, "check_passed", credit_id=card["id"], status=card["status"],
              expires_at=card["expiresAt"], available_count=snapshot["rateLimitResetCredits"]["availableCount"],
              primary=limits.get("primary"), read_only=True)


def execute(config):
    directory = Path(config["state_dir"])
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / "execute.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        receipt_path = directory / "receipt.json"
        attempt_path = directory / "attempt.json"
        if receipt_path.exists():
            receipt = json.loads(receipt_path.read_text())
            if any(receipt.get(key) != config[key] for key in ("credit_id", "idempotency_key")):
                raise StopTask("Receipt identity changed; inspect the original task before retrying")
            if receipt.get("outcome") in OUTCOMES:
                event(config, "already_complete", outcome=receipt["outcome"])
                return
            raise StopTask("Saved receipt has an unknown outcome; inspect it before retrying")
        if attempt_path.exists():
            saved = json.loads(attempt_path.read_text())
            if any(saved.get(key) != config[key] for key in ("credit_id", "idempotency_key")):
                raise StopTask("Attempt identity changed; restore the original card and idempotency key")
        check_window(config)
        attempt = 0
        while time.time() < deadline(config):
            check_window(config)
            attempt += 1
            try:
                with AppServer(config, allow_consume=True, deadline=deadline(config)) as server:
                    snapshot = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
                    selected_card(config, snapshot, allow_missing=attempt_path.exists())
                    check_window(config)
                    save_json(attempt_path, {"credit_id": config["credit_id"], "idempotency_key": config["idempotency_key"]})
                    event(config, "redeeming", attempt=attempt, credit_id=config["credit_id"])
                    result = server.call("account/rateLimitResetCredit/consume", {
                        "creditId": config["credit_id"],
                        "idempotencyKey": config["idempotency_key"],
                    })
                    outcome = result.get("outcome")
                    receipt = {"at": dt.datetime.now(dt.timezone.utc).isoformat(),
                               "credit_id": config["credit_id"], "idempotency_key": config["idempotency_key"],
                               "outcome": outcome}
                    save_json(receipt_path, receipt)
                    event(config, "result", outcome=outcome, credit_id=config["credit_id"],
                          reset_confirmed=outcome in ("reset", "alreadyRedeemed"))
                    if outcome not in OUTCOMES:
                        raise StopTask("Unknown redemption outcome: " + str(outcome))
                    try:
                        refreshed = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
                        summary = refreshed.get("rateLimitResetCredits") or {}
                        limits = refreshed.get("rateLimits") or {}
                        event(config, "verified", available_count=summary.get("availableCount"), primary=limits.get("primary"))
                    except Exception as error:
                        event(config, "refresh_failed_after_result", error_type=type(error).__name__)
                    return
            except StopTask:
                raise
            except Exception as error:
                event(config, "retry_pending", attempt=attempt, error_type=type(error).__name__)
                remaining = deadline(config) - time.time()
                if remaining <= 0:
                    break
                time.sleep(min(10, remaining))
        raise StopTask("Redemption window ended without a confirmed outcome; inspect the receipt before rescheduling")


def main():
    os.umask(0o077)
    os.environ.update(proxy_environment(os.environ))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config")
    parser.add_argument("--codex", default=shutil.which("codex"), help="Codex executable for read-only listing")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", action="store_true", help="Read rate limits and card details; never redeem")
    mode.add_argument("--check", action="store_true", help="Only query the selected card; never redeem")
    mode.add_argument("--execute", action="store_true", help="Redeem at or after the configured scheduled time")
    arguments = parser.parse_args()
    if arguments.list:
        if not arguments.codex:
            parser.error("codex is not on PATH; supply --codex")
        with AppServer({"codex_path": arguments.codex}) as server:
            result = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    if not arguments.config:
        parser.error("--config is required for --check and --execute")
    config = json.loads(Path(arguments.config).read_text())
    uuid.UUID(config["idempotency_key"])
    if config["not_before_epoch"] >= deadline(config):
        raise StopTask("Scheduled time must be before the redemption deadline")
    missing = [name for name in config["required_proxy_variables"] if not os.environ.get(name)]
    event(config, "environment", mode="check" if arguments.check else "execute",
          proxy_variables={name: bool(os.environ.get(name)) for name in config["required_proxy_variables"]})
    if missing:
        raise StopTask("Required proxy variables are absent: " + ", ".join(missing))
    try:
        check(config) if arguments.check else execute(config)
    except Exception as error:
        event(config, "failed", error_type=type(error).__name__, reason=str(error) if isinstance(error, StopTask) else None)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

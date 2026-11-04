#!/usr/bin/env python3
"""Prepare, but do not enable, a one-card weekly-limit watcher."""

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import uuid

from prepare_timer import execution_time, process_environment, quoted, unit_path
from reset_card import AppServer, StopTask


def select_card(snapshot, credit_id=None):
    summary = snapshot.get("rateLimitResetCredits") or {}
    details = summary.get("credits")
    if not isinstance(details, list):
        raise ValueError("Card details are unavailable; do not guess a card ID")
    available = [card for card in details if isinstance(card, dict)
                 and card.get("status") == "available" and card.get("resetType") == "codexRateLimits"]
    if credit_id is not None:
        card = next((item for item in available if item.get("id") == credit_id), None)
        if card is None:
            raise ValueError("Selected credit is not available in the returned card details")
    else:
        count = summary.get("availableCount")
        if isinstance(count, bool) or not isinstance(count, int) or count != len(available):
            raise ValueError("Available card details are incomplete; specify an explicitly verified card ID")
        if any(not isinstance(item.get("id"), str) or not item["id"] or "expiresAt" not in item
               or (item["expiresAt"] is not None and
                   (isinstance(item["expiresAt"], bool) or not isinstance(item["expiresAt"], int)))
               for item in available):
            raise ValueError("Available card ID or expiration is missing or invalid")
        dated = [item for item in available if item.get("expiresAt") is not None]
        if not dated:
            raise ValueError("No available card has a known expiration; specify a card ID")
        card = min(dated, key=lambda item: (item["expiresAt"], item["id"]))
    if not isinstance(card.get("id"), str) or not card["id"] or "expiresAt" not in card:
        raise ValueError("Selected card has an invalid ID or missing expiration")
    expires = card["expiresAt"]
    if expires is not None and (isinstance(expires, bool) or not isinstance(expires, int)):
        raise ValueError("Selected card has an invalid expiration")
    return card


def prepare(snapshot, environment, credit_id=None, until=None, name=None, runtime=480, now=None):
    if not sys.platform.startswith("linux"):
        raise ValueError("The watcher timer generator requires Linux user-level systemd")
    current = dt.datetime.now(dt.timezone.utc).timestamp() if now is None else now
    if not 1 <= runtime <= 3600:
        raise ValueError("--max-runtime-seconds must be between 1 and 3600")
    card = select_card(snapshot, credit_id)
    expires = card["expiresAt"]
    if until is not None and (until.tzinfo is None or until.utcoffset() is None):
        raise ValueError("Monitoring deadline must include a UTC offset")
    ends = ([expires] if expires is not None else []) + ([int(until.timestamp())] if until else [])
    if not ends:
        raise ValueError("A card without expiration requires an explicit --until deadline")
    monitor_deadline = min(ends)
    if monitor_deadline <= current:
        raise ValueError("Monitoring deadline and card expiration must be in the future")
    credit_id = card["id"]
    if name is None:
        name = "codex-reset-card-watch-" + hashlib.sha256(credit_id.encode()).hexdigest()[:16]
    if not re.fullmatch(r"codex-reset-card-[A-Za-z0-9_.-]{1,90}", name):
        raise ValueError("Task name must start with codex-reset-card- and use letters, digits, _, . or -")

    saved = process_environment(environment)
    codex = shutil.which("codex", path=environment.get("PATH", os.defpath))
    systemctl = shutil.which("systemctl", path=environment.get("PATH", os.defpath))
    if not codex or not systemctl:
        raise ValueError("codex and systemctl must be on the launch PATH")
    config_root = Path(environment.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    state_root = Path(environment.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    if not config_root.is_absolute() or not state_root.is_absolute():
        raise ValueError("XDG config and state directories must be absolute paths")
    config_path = config_root / "codex-reset-card" / (name + ".json")
    env_path = config_path.with_suffix(".env")
    state_dir = state_root / "codex-reset-card" / name
    unit_dir = config_root / "systemd/user"
    service_path = unit_dir / (name + ".service")
    timer_path = unit_dir / (name + ".timer")
    paths = (config_path, env_path, service_path, timer_path)
    if any(path.exists() or path.is_symlink() for path in paths) or state_dir.exists():
        raise ValueError("Task already exists; inspect its state instead of replacing its idempotency key")
    proxy_keys = [key for key in saved if key.lower() in ("http_proxy", "https_proxy", "all_proxy", "no_proxy")]
    config = {
        "mode": "weekly-zero", "task_name": name, "codex_path": str(Path(codex).absolute()),
        "systemctl_path": str(Path(systemctl).absolute()), "credit_id": credit_id,
        "idempotency_key": str(uuid.uuid4()), "expires_at_epoch": expires,
        "monitor_deadline_epoch": monitor_deadline, "max_runtime_seconds": runtime,
        "state_dir": str(state_dir), "required_proxy_variables": proxy_keys,
    }
    watcher = Path(__file__).resolve().with_name("watch_card.py")
    command = " ".join(quoted(value, unit=True, command=True) for value in (
        Path(sys.executable).absolute(), "-B", watcher, "--config", config_path, "--run"))
    service = (
        "[Unit]\nDescription=Watch weekly Codex limit and use one selected credit at zero\n\n"
        "[Service]\nType=oneshot\n"
        + "EnvironmentFile=" + unit_path(env_path) + "\n"
        + "WorkingDirectory=" + unit_path(state_dir) + "\n"
        + "ExecStart=" + command + "\n"
        + "UMask=0077\nTimeoutStartSec=" + str(runtime + 180) + "s\n"
        + "KillMode=control-group\nRestart=no\nStandardOutput=journal\nStandardError=journal\n"
    )
    timer = (
        "[Unit]\nDescription=Check weekly Codex limit every minute\n\n[Timer]\n"
        "OnActiveSec=1s\nOnUnitInactiveSec=60s\nAccuracySec=1s\nRandomizedDelaySec=0\n"
        + "Unit=" + name + ".service\n\n[Install]\nWantedBy=timers.target\n"
    )
    contents = (json.dumps(config, ensure_ascii=False, indent=2) + "\n",
                "".join(key + "=" + quoted(value) + "\n" for key, value in saved.items()), service, timer)
    created = []
    created_state = False
    try:
        state_dir.mkdir(parents=True, mode=0o700, exist_ok=False)
        created_state = True
        for path, content in zip(paths, contents):
            path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            created.append(path)
            with os.fdopen(descriptor, "w") as stream:
                stream.write(content)
    except BaseException:
        for path in created:
            path.unlink(missing_ok=True)
        if created_state:
            try:
                state_dir.rmdir()
            except OSError:
                pass
        raise
    return {"task_name": name, "armed": False, "credit_id": credit_id,
            "expires_at_epoch": expires, "monitor_deadline_epoch": monitor_deadline,
            "interval_seconds": 60, "config": str(config_path), "environment_file": str(env_path),
            "state_dir": str(state_dir), "service": str(service_path), "timer": str(timer_path),
            "proxy_variables": {key: True for key in proxy_keys}}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credit-id", help="Explicit available card ID; defaults to earliest expiration")
    parser.add_argument("--until", type=execution_time, help="Optional monitoring deadline with UTC offset")
    parser.add_argument("--name", help="Optional unique name beginning with codex-reset-card-")
    parser.add_argument("--max-runtime-seconds", default=480, type=int)
    args = parser.parse_args()
    codex = shutil.which("codex")
    if not codex:
        parser.error("codex is not on PATH")
    with AppServer({"codex_path": codex}) as server:
        snapshot = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
    print(json.dumps(prepare(snapshot, os.environ, args.credit_id, args.until, args.name,
                             args.max_runtime_seconds), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, StopTask) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

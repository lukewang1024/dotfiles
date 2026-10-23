#!/usr/bin/env python3
"""Prepare a single Codex reset-credit timer; never enable it or redeem a credit."""

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

from reset_card import AppServer, StopTask, proxy_environment


def execution_time(value):
    instant = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise ValueError("--at must include a UTC offset, for example 2026-10-24T05:00:00+08:00")
    return instant


def process_environment(environment):
    inherited = proxy_environment(environment)
    keys = ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
            "http_proxy", "https_proxy", "all_proxy", "no_proxy",
            "PATH", "CODEX_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
            "XDG_STATE_HOME", "XDG_CACHE_HOME")
    saved = {key: inherited[key] for key in keys if inherited.get(key)}
    for value in saved.values():
        if any(character in value for character in "\0\r\n"):
            raise ValueError("Environment values must not contain NUL or line breaks")
    return saved


def quoted(value, *, unit=False, command=False):
    value = str(value)
    if any(character in value for character in "\0\r\n"):
        raise ValueError("Unit values must not contain NUL or line breaks")
    if unit:
        value = value.replace("%", "%%")
    if command:
        value = value.replace("$", "$$")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def unit_path(value):
    # Single-path directives in systemd 241 do not remove surrounding quotes:
    # https://github.com/systemd/systemd/blob/v241/src/core/load-fragment.c
    value = str(value)
    if any(character in value for character in "\0\r\n"):
        raise ValueError("Unit paths must not contain NUL or line breaks")
    return value.replace("%", "%%")


def prepare(snapshot, credit_id, at, name, runtime, environment, now=None):
    if at.tzinfo is None or at.utcoffset() is None:
        raise ValueError("Scheduled time must include a UTC offset")
    if not 1 <= runtime <= 3600:
        raise ValueError("--max-runtime-seconds must be between 1 and 3600")
    start = int(at.timestamp())
    current = dt.datetime.now(dt.timezone.utc).timestamp() if now is None else now
    if start <= current:
        raise ValueError("Scheduled time must be in the future")
    summary = snapshot.get("rateLimitResetCredits") or {}
    card = next((card for card in summary.get("credits") or [] if card.get("id") == credit_id), None)
    if card is None or card.get("status") != "available":
        raise ValueError("Selected credit is not available in the returned card details")
    if card.get("resetType") != "codexRateLimits" or "expiresAt" not in card:
        raise ValueError("Selected credit has an unsupported type or missing expiration")
    expires = card["expiresAt"]
    if expires is not None and start >= expires:
        raise ValueError("Scheduled time must be before the selected credit expires")
    end = min(start + runtime, expires) if expires is not None else start + runtime
    utc = at.astimezone(dt.timezone.utc)
    if name is None:
        suffix = hashlib.sha256(credit_id.encode()).hexdigest()[:10]
        name = "codex-reset-card-" + utc.strftime("%Y%m%dT%H%M%SZ-") + suffix
    if not re.fullmatch(r"codex-reset-card-[A-Za-z0-9_.-]{1,90}", name):
        raise ValueError("Task name must start with codex-reset-card- and contain only letters, digits, _, . or -")
    saved = process_environment(environment)
    codex = shutil.which("codex", path=environment.get("PATH", os.defpath))
    if codex is None:
        raise ValueError("codex is not on the launch PATH")
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
        "task_name": name, "codex_path": str(Path(codex).absolute()),
        "credit_id": credit_id, "idempotency_key": str(uuid.uuid4()),
        "execute_at": at.isoformat(), "not_before_epoch": start,
        "expires_at_epoch": expires, "deadline_epoch": end,
        "max_runtime_seconds": runtime, "state_dir": str(state_dir),
        "required_proxy_variables": proxy_keys,
    }
    executor = Path(__file__).resolve().with_name("reset_card.py")
    command = " ".join(quoted(value, unit=True, command=True) for value in (
        Path(sys.executable).absolute(), executor, "--config", config_path, "--execute"))
    service = (
        "[Unit]\nDescription=Use one selected Codex reset credit\n\n[Service]\nType=oneshot\n"
        + "EnvironmentFile=" + unit_path(env_path) + "\n"
        + "WorkingDirectory=" + unit_path(state_dir) + "\n"
        + "ExecStart=" + command + "\n"
        + "UMask=0077\nTimeoutStartSec=" + str(runtime + 15) + "s\n"
        + "KillMode=control-group\nRestart=no\nStandardOutput=journal\nStandardError=journal\n"
    )
    timer = (
        "[Unit]\nDescription=Schedule one selected Codex reset credit\n\n[Timer]\n"
        + "OnCalendar=" + utc.strftime("%Y-%m-%d %H:%M:%S UTC") + "\n"
        + "AccuracySec=1s\nRandomizedDelaySec=0\nPersistent=true\nUnit=" + name + ".service\n"
        + "\n[Install]\nWantedBy=timers.target\n"
    )
    contents = (json.dumps(config, ensure_ascii=False, indent=2) + "\n",
                "".join(key + "=" + quoted(value) + "\n" for key, value in saved.items()),
                service, timer)
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
    return {
        "task_name": name, "armed": False, "execute_at": at.isoformat(),
        "deadline": dt.datetime.fromtimestamp(end, dt.timezone.utc).isoformat(),
        "config": str(config_path), "environment_file": str(env_path), "state_dir": str(state_dir),
        "service": str(service_path), "timer": str(timer_path),
        "proxy_variables": {key: True for key in proxy_keys},
    }


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credit-id", required=True)
    parser.add_argument("--at", required=True, type=execution_time, help="ISO 8601 time with an explicit UTC offset")
    parser.add_argument("--name", help="Optional unique name beginning with codex-reset-card-")
    parser.add_argument("--max-runtime-seconds", default=480, type=int)
    arguments = parser.parse_args()
    codex = shutil.which("codex")
    if codex is None:
        parser.error("codex is not on PATH")
    with AppServer({"codex_path": codex}) as server:
        snapshot = server.call("account/rateLimits/read", {"excludeResetCreditDetails": False})
    result = prepare(snapshot, arguments.credit_id, arguments.at, arguments.name,
                     arguments.max_runtime_seconds, os.environ)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, StopTask) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

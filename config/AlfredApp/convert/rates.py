#!/usr/bin/python3
"""Exchange-rate cache for the `conv` workflow.

Rates are cached on disk and served **stale-while-revalidate**: a Script Filter
runs on every keystroke, so it must never wait on the network. A stale cache is
used immediately and a detached refresh is kicked off in the background; only a
completely cold cache blocks, and then only once.

Run standalone to refresh:  /usr/bin/python3 rates.py

Two providers, tried in order:
  1. open.er-api.com  — ~160 currencies, no key, daily
  2. api.frankfurter.dev — ECB reference rates, ~30 currencies, no key, weekdays

Fiat only. Crypto was deliberately left out: every keyless quote source tried
(CoinGecko, Coinbase) is unreachable from this machine's network, and a
conversion that silently works at home and fails at the office is worse than one
that was never offered.

Pinned to system python 3.9: no 3.10+ syntax.
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Refresh after this long. Both providers publish once a day, so anything under a
# few hours is just burning requests.
TTL = 6 * 3600

# Past this, refuse to quote at all rather than convert money at a week-old rate
# without saying so. (The filter surfaces the age in every subtitle regardless.)
MAX_AGE = 14 * 86400

USER_AGENT = "alfred-convert (+https://github.com/lukewang1024/.dotfiles)"
TIMEOUT = 8

PROVIDERS = [
    ("open.er-api.com", "https://open.er-api.com/v6/latest/USD"),
    ("frankfurter (ECB)", "https://api.frankfurter.dev/v1/latest?base=USD"),
]


def cache_path():
    """Cache lives under XDG_CACHE_HOME — re-downloadable, so not state."""
    root = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return os.path.join(root, "alfred-convert", "rates.json")


def _fetch_one(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch():
    """Fetch USD-based rates from the first provider that answers.

    Returns the cache dict, or raises the last error if every provider failed.
    """
    last = None
    for name, url in PROVIDERS:
        try:
            payload = _fetch_one(url)
            rates = payload.get("rates") or {}
            if not rates:
                raise ValueError("no rates in response")
            rates = {k.upper(): float(v) for k, v in rates.items()}
            rates.setdefault("USD", 1.0)
            return {
                "base": "USD",
                "rates": rates,
                "fetched": int(time.time()),
                "provider": name,
            }
        except (urllib.error.URLError, ValueError, KeyError, TypeError, OSError) as exc:
            last = exc
            continue
    raise RuntimeError("all rate providers failed: %s" % last)


def save(data):
    path = cache_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Write-then-rename: a Script Filter may be reading this file at any moment,
    # and a half-written cache would poison every later lookup.
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w") as fh:
        json.dump(data, fh)
    os.replace(tmp, path)


def load():
    try:
        with open(cache_path()) as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or not data.get("rates"):
        return None
    return data


def refresh_in_background():
    """Kick off a detached refresh and return immediately."""
    try:
        subprocess.Popen(
            ["/usr/bin/python3", os.path.join(os.path.dirname(os.path.abspath(__file__)), "rates.py")],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def get():
    """Return (data, age_seconds, error).

    `data` is None only when there is no usable cache AND the network is down.
    A stale cache is still returned — with its true age — so the filter can quote
    and say how old the number is.
    """
    data = load()
    now = int(time.time())

    if data is None:
        # Cold cache: this one time, block. Better a 2-second first run than a
        # workflow that shows nothing until some future keystroke gets lucky.
        try:
            data = fetch()
            save(data)
        except RuntimeError as exc:
            return None, None, str(exc)
        return data, 0, None

    age = now - int(data.get("fetched", 0))
    if age > TTL:
        refresh_in_background()
    return data, age, None


def rate(data, code):
    """USD-relative rate for a currency code, or None."""
    return data.get("rates", {}).get(code.upper())


def convert(data, amount, src, dst):
    """Convert between two currency codes via the USD base."""
    r_src = rate(data, src)
    r_dst = rate(data, dst)
    if not r_src or not r_dst:
        return None
    return amount / r_src * r_dst


def main():
    try:
        data = fetch()
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        return 1
    save(data)
    print("%d rates from %s" % (len(data["rates"]), data["provider"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

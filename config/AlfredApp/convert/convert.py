#!/usr/bin/python3
"""Alfred Script Filter for the `conv` keyword — units and live exchange rates.

    conv 100 usd cny        100 USD in yuan
    conv 100 usd            100 USD in every favourite currency
    conv 1200*3 hkd sgd     the amount may be arithmetic
    conv $100 to jpy        currency symbols work
    conv 10 km mi           units, across 12 dimensions
    conv 72 f c             temperature (affine, not a multiplier)
    conv 1 gb mib           decimal and binary byte ladders in one table

Replaces deanishe's alfred-convert 3.7 (Python 2 + `pint` + `Alfred-Workflow`,
none of which survive on a modern macOS). Standard library only.

Pinned to /usr/bin/python3 (system 3.9): `python3` on PATH is a pyenv shim that
Alfred's environment does not reliably resolve. No 3.10+ syntax.
"""

import ast
import json
import math
import os
import re
import sys

import rates
import units

# --- configuration ------------------------------------------------------------
#
# Both are declared as Alfred workflow variables in info.plist, so they can be
# edited either in Alfred's UI or in git.

FAVOURITES = [
    c.strip().upper()
    for c in os.environ.get("CONVERT_CURRENCIES", "CNY,USD,HKD,SGD,EUR,JPY,GBP").split(",")
    if c.strip()
]
DECIMALS = int(os.environ.get("CONVERT_DECIMALS", "4") or 4)

# Currency symbols. `¥` is genuinely ambiguous between CNY and JPY; it maps to CNY
# here because that is the one being typed day to day. `conv 100 jpy …` is the
# unambiguous spelling and always wins.
SYMBOLS = {
    "$": "USD", "US$": "USD", "¥": "CNY", "￥": "CNY", "€": "EUR", "£": "GBP",
    "₩": "KRW", "₹": "INR", "₽": "RUB", "฿": "THB", "₫": "VND", "₺": "TRY",
    "HK$": "HKD", "S$": "SGD", "NT$": "TWD", "A$": "AUD", "C$": "CAD",
}

# Spoken names for the currencies that actually get typed.
CURRENCY_ALIASES = {
    "rmb": "CNY", "yuan": "CNY", "kuai": "CNY", "元": "CNY", "人民币": "CNY",
    "dollar": "USD", "dollars": "USD", "buck": "USD", "bucks": "USD",
    "yen": "JPY", "euro": "EUR", "euros": "EUR",
    "pound": "GBP", "pounds": "GBP", "sterling": "GBP", "quid": "GBP",
    "won": "KRW", "rupee": "INR", "rupees": "INR", "baht": "THB",
    "ringgit": "MYR", "peso": "PHP", "rupiah": "IDR", "dong": "VND",
    "franc": "CHF", "real": "BRL", "lira": "TRY", "rouble": "RUB", "ruble": "RUB",
}

CONNECTORS = {"to", "in", "into", "as", "->", ">", "=", ":", "对", "换", "兑"}

NUM = r"[-+]?(?:[\d,]+(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?"


# --- parsing ------------------------------------------------------------------

def take_amount(text):
    """Split a leading number — or arithmetic expression — off the query.

    Returns (expression_string_or_None, rest). Consuming operator-joined numbers
    one at a time (rather than regexing for "an expression") is what keeps
    `10 euro` from being read as `10 e` — the scan stops at the first thing that
    is not an operator followed by another number.
    """
    text = text.strip()
    m = re.match(NUM, text)
    if not m:
        return None, text
    expr = m.group(0)
    rest = text[m.end():]
    while True:
        m2 = re.match(r"\s*([+\-*/])\s*(" + NUM + ")", rest)
        if not m2:
            break
        expr += m2.group(1) + m2.group(2)
        rest = rest[m2.end():]
    return expr, rest.strip()


def evaluate(expr):
    """Evaluate a numeric expression safely — no eval(), no names, no calls."""
    node = ast.parse(expr.replace(",", ""), mode="eval").body

    def walk(n):
        if isinstance(n, ast.Constant):
            if isinstance(n.value, bool) or not isinstance(n.value, (int, float)):
                raise ValueError("not a number")
            return float(n.value)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.UAdd, ast.USub)):
            v = walk(n.operand)
            return v if isinstance(n.op, ast.UAdd) else -v
        if isinstance(n, ast.BinOp):
            ops = {ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/", ast.Pow: "**"}
            op = ops.get(type(n.op))
            if op is None:
                raise ValueError("unsupported operator")
            a, b = walk(n.left), walk(n.right)
            if op == "+":
                return a + b
            if op == "-":
                return a - b
            if op == "*":
                return a * b
            if op == "/":
                if b == 0:
                    raise ValueError("division by zero")
                return a / b
            return a ** b
        raise ValueError("unsupported expression")

    return walk(node)


def strip_symbol(text):
    """Pull a leading (or trailing) currency symbol off, returning (code, rest)."""
    text = text.strip()
    # Longest first, so "HK$" is not eaten as "$".
    for sym in sorted(SYMBOLS, key=len, reverse=True):
        if text.startswith(sym):
            return SYMBOLS[sym], text[len(sym):].strip()
        if text.endswith(sym):
            return SYMBOLS[sym], text[: -len(sym)].strip()
    return None, text


def split_units(tokens):
    """Split the post-amount tokens into (from, to).

    The connector search deliberately starts at index 1. `in` is both a
    preposition and the abbreviation for inch, so `conv 10 in cm` must read the
    first token as a unit — only a connector with something before it is a
    connector. And when dropping it would leave no target (`conv 10 cm in`), it
    was the unit after all.
    """
    if not tokens:
        return None, None
    for i in range(1, len(tokens)):
        if tokens[i].lower() in CONNECTORS:
            src = " ".join(tokens[:i]).strip()
            dst = " ".join(tokens[i + 1:]).strip()
            if dst:
                return src, dst
            return src, tokens[i]
    if len(tokens) == 1:
        return tokens[0], None
    return tokens[0], " ".join(tokens[1:]).strip()


# --- resolution ---------------------------------------------------------------

def candidates(token, fx):
    """Every way a token could be read: unit, currency, or both.

    Returning a list rather than a single answer is what disambiguates the
    genuine collisions between the two namespaces — `cup` is both a volume and
    the Cuban peso. The pairing step below picks whichever reading makes the two
    sides of the conversion compatible.
    """
    out = []
    if not token:
        return out
    key = token.strip().lower()

    hit = units.lookup(key)
    if hit:
        out.append(("unit", hit[0], hit[1]))

    code = CURRENCY_ALIASES.get(key, key.upper())
    if fx and rates.rate(fx, code) is not None:
        out.append(("currency", "currency", code))
    return out


def pair(src_cands, dst_cands):
    """Pick the (src, dst) reading whose two sides can actually be converted."""
    for s in src_cands:
        for d in dst_cands:
            if s[0] == "currency" and d[0] == "currency":
                return s, d
            if s[0] == "unit" and d[0] == "unit" and s[1] == d[1]:
                return s, d
    return None, None


# --- formatting ---------------------------------------------------------------

def fmt(value):
    """Readable number: thousands separators, adaptive precision, no noise."""
    if value == 0:
        return "0"
    if not math.isfinite(value):
        return str(value)
    a = abs(value)
    if a >= 1e15 or a < 1e-9:
        return "%.6g" % value
    if a >= 1000:
        dp = 2
    elif a >= 1:
        dp = DECIMALS
    else:
        # Keep DECIMALS significant digits rather than DECIMALS decimal places,
        # or 0.00034 renders as "0.0003" and loses the number.
        dp = min(12, DECIMALS - int(math.floor(math.log10(a))) - 1)
    out = "{:,.{}f}".format(value, dp)
    if "." in out:
        out = out.rstrip("0").rstrip(".")
    return out


def age_text(seconds):
    if seconds is None:
        return "just fetched"
    if seconds < 90:
        return "just now"
    if seconds < 5400:
        return "%dm ago" % (seconds // 60)
    if seconds < 172800:
        return "%dh ago" % (seconds // 3600)
    return "%dd ago" % (seconds // 86400)


def item(title, subtitle, valid=False, arg=None, copy=None):
    it = {"title": title, "subtitle": subtitle, "valid": valid, "icon": {"path": "icon.png"}}
    if arg is not None:
        it["arg"] = arg
    if copy is not None:
        it["text"] = {"copy": copy, "largetype": copy}
    return it


def result_item(amount, src_label, value, dst_label, note):
    """One conversion row.

    ↩ copies the bare number — the common case is pasting into a spreadsheet or
    another field. ⌘↩ copies it with the unit attached.
    """
    shown = fmt(value)
    with_unit = "%s %s" % (shown, dst_label)
    it = item(
        "= %s" % with_unit,
        "%s %s → %s%s" % (fmt(amount), src_label, dst_label, note),
        valid=True,
        arg=shown,
        copy=shown,
    )
    it["mods"] = {
        "cmd": {"valid": True, "arg": with_unit, "subtitle": "Copy “%s” (with unit)" % with_unit}
    }
    return it


# --- main ---------------------------------------------------------------------

def build(query):
    fx, age, fx_error = rates.get()

    if not query.strip():
        rows = [item("Convert units and currencies",
                     "conv 100 usd cny · conv 10 km mi · conv 72 f c · conv 1 gb mib")]
        if fx_error:
            rows.append(item("Exchange rates unavailable", fx_error))
        elif fx:
            rows.append(item(
                "%d currencies cached" % len(fx.get("rates", {})),
                "%s, updated %s" % (fx.get("provider", "?"), age_text(age)),
            ))
        return rows

    text = query.strip()
    sym_code, text = strip_symbol(text)
    expr, rest = take_amount(text)

    if expr is None:
        return [item("Start with a number", "e.g. conv 100 usd cny — got “%s”" % query.strip())]

    try:
        amount = evaluate(expr)
    except (SyntaxError, ValueError, TypeError, ZeroDivisionError, RecursionError) as exc:
        return [item("Can't read “%s”" % expr, str(exc) or "invalid expression")]

    # A symbol found before the number names the SOURCE ("$100 to cny"); the
    # tokens after it are then the target only.
    tokens = [t for t in rest.split() if t]
    if sym_code:
        src_token, dst_token = sym_code, " ".join(t for t in tokens if t.lower() not in CONNECTORS)
        dst_token = dst_token or None
    else:
        src_token, dst_token = split_units(tokens)

    if not src_token:
        return [item("What unit is %s?" % fmt(amount), "e.g. conv %s usd cny" % fmt(amount))]

    src_cands = candidates(src_token, fx)
    if not src_cands:
        hint = "exchange rates unavailable — %s" % fx_error if fx_error else "unknown unit or currency"
        return [item("Don't know “%s”" % src_token, hint)]

    # No target: fan out. Currencies go to the favourites list, units to the
    # dimension's usual companions — the answer is almost always in there, and it
    # saves typing the second half of the query.
    if not dst_token:
        kind, dim, canon = src_cands[0]
        note = ""
        rows = []
        if kind == "currency":
            note = "  ·  %s, %s" % (fx.get("provider", "?"), age_text(age))
            for code in FAVOURITES:
                if code == canon or rates.rate(fx, code) is None:
                    continue
                value = rates.convert(fx, amount, canon, code)
                rows.append(result_item(amount, canon, value, code, note))
        else:
            for unit in units.companions(dim, canon):
                value = units.convert(amount, dim, canon, unit)
                rows.append(result_item(amount, units.display(dim, canon), value,
                                        units.display(dim, unit), note))
        if rows:
            return rows
        return [item("Nothing to convert %s into" % src_token, "add a target: conv %s %s <target>"
                     % (fmt(amount), src_token))]

    dst_cands = candidates(dst_token, fx)
    if not dst_cands:
        hint = "exchange rates unavailable — %s" % fx_error if fx_error else "unknown unit or currency"
        return [item("Don't know “%s”" % dst_token, hint)]

    s, d = pair(src_cands, dst_cands)
    if s is None:
        return [item("Can't convert %s to %s" % (src_token, dst_token),
                     "%s and %s measure different things" % (src_token, dst_token))]

    if s[0] == "currency":
        if age is not None and age > rates.MAX_AGE:
            return [item("Exchange rates are %s" % age_text(age),
                         "Too stale to quote — run rates.py, or check the network")]
        value = rates.convert(fx, amount, s[2], d[2])
        one = rates.convert(fx, 1.0, s[2], d[2])
        note = "  ·  1 %s = %s %s  ·  %s, %s" % (
            s[2], fmt(one), d[2], fx.get("provider", "?"), age_text(age))
        return [result_item(amount, s[2], value, d[2], note)]

    value = units.convert(amount, s[1], s[2], d[2])
    return [result_item(amount, units.display(s[1], s[2]), value, units.display(d[1], d[2]), "")]


def main():
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        items = build(query)
    except Exception as exc:  # a Script Filter that crashes just shows nothing
        items = [item("convert: %s" % type(exc).__name__, str(exc))]
    json.dump({"items": items}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Script Filter behind `amp help`.

The original workflow's help was an Open URL action pointing at a uservoice
article that has been dead since 2016. This builds the reference inside Alfred
instead, and derives it from live data so it cannot drift:

  * the command list comes from this workflow's own info.plist keywords, so
    renaming or adding a keyword updates the help automatically;
  * each command is annotated with how often it has actually been used, read
    from the log the workflow writes on every invocation, and ordered by it;
  * the current session state is the first row (see `amp status` for the
    full picture).

Actioning a row copies that command to the clipboard.
"""
import lib

# Formats accepted by the AppleScript duration parser. These live in the parser
# rather than in info.plist, so they are spelled out here.
DURATION_EXAMPLES = (
    ("amp on", "Indefinite session (no duration given)"),
    ("amp on 30m", "30 minutes"),
    ("amp on 2h", "2 hours"),
    ("amp on 1h 30m", "1 hour 30 minutes"),
    ("amp on 90", "Bare number means minutes"),
    ("amp on 1 30", "Two bare numbers mean hours then minutes"),
)


def build_items():
    title, subtitle = lib.session_headline(lib.read_state())
    items = [{"uid": "state", "title": title, "subtitle": subtitle, "valid": False}]

    counts, last = lib.usage_stats()

    # Most-used commands first; info.plist order breaks ties.
    def sort_key(cmd):
        return -counts.get(cmd["keyword"].split()[-1], 0)

    for cmd in sorted(lib.commands(), key=sort_key):
        label = cmd["keyword"].split()[-1]
        bits = []
        if cmd["subtext"]:
            bits.append(cmd["subtext"])
        used = counts.get(label, 0)
        if used:
            note = "used {}x".format(used)
            when = lib.ago(last.get(label))
            if when:
                note += ", last " + when
            bits.append(note)
        else:
            bits.append("never used")

        items.append(
            {
                "uid": "cmd-" + label,
                "title": " ".join(filter(None, (cmd["keyword"], cmd["arg_hint"]))),
                "subtitle": "  ·  ".join(bits),
                "arg": cmd["keyword"],
                "valid": True,
                "match": cmd["keyword"] + " " + cmd["title"],
                "text": {"copy": cmd["keyword"], "largetype": cmd["title"]},
            }
        )

    for example, note in DURATION_EXAMPLES:
        items.append(
            {
                "uid": "ex-" + example,
                "title": example,
                "subtitle": note,
                "arg": example,
                "valid": True,
                "text": {"copy": example},
            }
        )

    items.append(
        {
            "uid": "log",
            "title": "Workflow log",
            "subtitle": str(lib.LOG),
            "arg": str(lib.LOG),
            "valid": True,
            "text": {"copy": str(lib.LOG)},
        }
    )
    return items


if __name__ == "__main__":
    items = build_items()
    lib.log_invocation("help")
    lib.emit(items)

---
name: code-ship
description: Ship committed changes using a machine-local repository policy, either direct push or PR/MR. Use when asked to code-ship, ship it, push, or create a PR/MR.
---

# code-ship

Use `code-ship` from PATH. The self-contained implementation is
`scripts/code-ship.py` beside this skill and requires Python 3; it can also be
invoked directly with `python3`.

Before choosing a branch or shipping, run:

```sh
code-ship --repo-dir /path/to/worktree --show-policy
```

If `needsChoice` is true, ask the user which strategy to remember for this
repository. Recommend direct push for a known personal project, but never
choose on the user's behalf. Offer direct push, PR/MR for review, or automatic
merge where supported. An explicit strategy already given by the user counts
as their choice; no repeated question is needed. If they said it is only for
this invocation, do not save it. Otherwise save the first choice with:

```sh
code-ship --repo-dir /path/to/worktree --configure --strategy direct-push
```

`--configure` only saves configuration; it never ships. A noninteractive ship
without a strategy returns JSON `status: needs-policy` and exit code 20 before
network access or writes. Ask the user and continue after their answer; never
treat that exit as permission to choose. Interactive terminal users get a menu
with no default; their selection is remembered.

Subsequent invocations use the saved policy. Explicit strategy/target/provider
flags override it for one run; add `--remember` only when asked to change future
behavior. `--target-branch auto` restores automatic remote default detection.
Repository instructions still constrain permitted actions; if they conflict
with saved policy, resolve the conflict with the user rather than silently
rewriting policy or bypassing repository rules.

## Strategies

- `direct-push`: push HEAD to the remote target through ordinary Git auth,
  only when it is a fast-forward. Works from a feature branch or main/master.
- `manual-merge`: push a feature branch and create a PR/MR. When starting on
  the target branch, create `ship/<sha>` without resetting the target branch.
- `auto-merge`: provider-specific creation, checks, and merge. Built-in GitHub
  support currently offers manual PRs only, using authenticated `gh`.

Commit the intended changes and run appropriate project checks before shipping.
Use `--description-file` for multiline PR descriptions. An invocation such as
`code-ship --repo-dir /path/to/worktree` uses saved defaults. `--dry-run` validates
and fetches but does not save policy, create branches, push, or create a PR.
Local branches are preserved after shipping; divergence or server rejection
stops the operation. Never force push or silently switch strategy.

## Machine-local policy and providers

Policy lives only at `${XDG_CONFIG_HOME:-$HOME/.config}/code-ship/config.yml`.
The file uses JSON syntax (a YAML-compatible subset) to avoid a YAML dependency;
use the command to edit it. Writes are locked and atomic, with mode 0600.
Do not write policy to repository files or Git config; previous
`.skill-config.yml` and `git config code-ship.*` defaults are not read.

Keys normalize origin SSH/HTTPS URLs, strip credentials and `.git`, and retain
host, repository path, and nonstandard ports. Clones/worktrees of the same
remote share policy. SSH host aliases are not resolved automatically.

Direct push needs no provider. github.com selects the built-in provider.
Other hosts require `--provider NAME`, remembered alongside the strategy.
The command invokes `code-ship-provider-NAME` from PATH; if absent, install the
organization's private provider package. Do not assume an unknown host belongs
to any particular organization.

Provider protocol v1: `--check` verifies dependencies without writes. For ship,
the executable runs in the worktree with STRATEGY, TARGET_BRANCH,
CURRENT_BRANCH, FEATURE_BRANCH, BASE_REF, HOST, REPO_NAME, TITLE, DESCRIPTION,
DRAFT, REMOVE_SOURCE, POLL_INTERVAL, POLL_TIMEOUT, COMMITS_AHEAD,
SHIP_BRANCH_CREATED and SKIP_RECONCILE in its environment. It pushes the feature
branch and manages the PR/MR, emits JSON to stdout and diagnostics to stderr,
and exits nonzero on failure. The common entrypoint owns policy and worktree
validation. Credentials remain in the local authentication tools/environment.

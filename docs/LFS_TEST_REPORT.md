# Git LFS migration verification — 2026-10-24

## Published scope

Both writable public branches were atomically updated with explicit leases against
the backed-up old tips. Uploaded LFS objects were independently downloaded and
verified before publishing the rewritten Git history.

| Branch | Old tip | Rewritten history tip |
| --- | --- | --- |
| main | `4f5f8a04d00a18d636d917e161b298221b49046c` | `1d4b08bfbd06a32d8ae1abc88550a263fa6d7e72` |
| wip | `fae616ac3bd4b3e002fa47426087ee18e8214988` | `d20f36276413e1b3b093d86d36a64cc52ce701a4` |

Implementation was then added to main as `bbd862d`. Subsequent documentation
commits extend that migrated history normally. The commit map records the 712
original rewritten commits, not these new implementation/documentation commits.

## Results

| Check | Result | Actual evidence and limits |
| --- | --- | --- |
| Remote backup | PASS | Verified full bundle/mirror, including 37 original refs; public heads/tags recorded before modification |
| Local work preservation | PASS | Original repository's refs bundled; worktree status and ordinary modified/untracked files backed up; original working directories left untouched |
| Historical content | PASS | All 712 mapped commit trees compared with LFS pointers resolved to original blob content; only `.gitattributes`/LFS representation differs |
| Historical metadata | PASS | Authors, committers, timestamps, messages and mapped parents checked for all 712 commits |
| Resource integrity | PASS | 18 fonts/models/dictionaries, 153,243,563 bytes; original content SHA256 matches pointers and manifest |
| Ordinary Git object sizes | PASS | No blob >=1 MiB remains reachable from the two migrated public branch histories |
| GitHub LFS distribution | PASS | 18/18 uploaded; separate clone fetched all 18 from GitHub LFS, SHA256 verified, clean Git status afterward |
| Default fetch behavior | PASS | Clone with active Git LFS filters retained all 18 pointers and downloaded no LFS objects |
| Published ordinary HTTPS clone | PASS | Full history, no sparse/partial/shallow flags; Git pack 3,729,513 bytes at `bbd862d`; 713 commits; later pull succeeded |
| Resource repeat | PASS | Already hydrated task verifies locally and invokes no package/Git commands |
| Resource push gate | PASS | Real new LFS object pushed through tracked pre-push hook to a disposable local LFS remote |
| Bootstrap regression | PASS | 159 tests: 151 passed, 8 platform skips; no host package provisioning |
| Shell validation | PASS | POSIX syntax and ShellCheck for standalone migration and pre-push hook |
| Platform plans | PASS | macOS/Windows core plans contain resource tasks; iSH/Termux core plans contain no git-lfs install/fetch |
| Genuine old checkout migration | PASS | Original public pre-migration checkout replaced at the same path; full old backup and 18 new pointers checked |
| Migration recovery cases | PASS | Modified/untracked work, unpublished commits, stash and linked worktree refusal; ignored files/local Git settings retained; check-only/idempotence; sync failure restores old checkout |
| Real iSH ordinary clone | PASS | Alpine 3.24.3 x86, git-lfs absent; published normal full-history clone had pointers only and the same 3,729,513-byte Git pack |
| Real iSH initialization | PASS | Actual `./init sync` from the published normal checkout exited 0 |
| Real iSH one-command migration | PASS | Genuine old commit IDs in a pre-migration sparse checkout; downloaded published recovery script; retained old directory, ran actual sync, clean Git status and later pull succeeded |
| Native macOS/Windows full provisioning | NOT TESTED | Resource command itself fetched successfully on Linux; platform plans and shared tests do not prove native full installation |
| Windows PowerShell recovery wrapper | NOT TESTED | Added native dispatcher sharing the POSIX Python implementation; no Windows runtime was available in this verification |
| iPad/Termux hardware and device networks | NOT TESTED | Linux-hosted iSH is separate from the iPad app; cloud network inherited configured proxies |

The iSH binary uses official source commit
`c5ebcabec14f1d8709e91e1905ce0edd7cb9c13c`, previously built with the GNU linker
compatibility adjustment. Guest script and emulator both exited 0. No real
enterprise Kerberos service was contacted.

## Reproduction evidence retained outside the repository

Migration backups, commit/content verifier and logs are under the implementation
machine's XDG data path:

```text
~/.local/share/dotfiles-lfs-migration/20261024T102226/
  before.git/
  remote-before.bundle
  local-all-before.bundle
  local-worktree-*.status
  local-worktree-*.tar.gz
  after-verified.bundle
  verify-history.py
  history-verification.json
  github-lfs-verification.json
  published-normal-clone.json
  published-migration.json
  remote-refs.before
  remote-refs.after
  full-tests-final.log
```

The real iSH fixture/log remains outside dotfiles:

```text
~/.local/share/repro-environments/ish-kerberos/tests/lfs-migration.sh
~/.local/share/repro-environments/ish-kerberos/artifacts/dotfiles-lfs-migration.log
```

Original cloud-machine linked worktrees and unpublished changes were not replaced
or rebased. The recovery command deliberately refuses those conditions so work
can be reviewed first. Backups were not pushed as public Git refs, since that
would make old large blobs reachable again. GitHub's old PR refs/caches may
remain; this is a distribution/history migration, not a claim of server-wide
object erasure.

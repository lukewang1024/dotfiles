# SSH device pairing verification — 2026-10-24

- **PASS**: POSIX `sh -n`, ShellCheck for `ssh-setup` and `ssh-pair`.
- **PASS**: full Python suite: 165 tests, 157 passed, 8 platform skips.
- **PASS**: six pairing regression tests cover configuration preservation and
  backup, repetition, copy/verification failures, alias collision, input
  injection, and setup argument validation. SSH subprocesses are stubs here.
- **PASS**: iSH CLI / Alpine 3.24 x86: real installation of `openssh-server`,
  isolated foreground SSHD config validation/startup, ED25519 host key and
  public-key-only loopback login returning `root`.
- **PASS**: same iSH guest: real `ssh-copy-id` with a preauthorized test key,
  public-key-only verification, repeated pairing without duplicate alias,
  and real login through the saved SSH alias returning `root`. Guest exit 0.
- **PASS**: server and pairing override the client's existing Kerberos-only
  defaults for this device connection. Server does not replace the GSSAPI SSH
  client package.
- **NOT TESTED**: first-time interactive password entry and upload of a new key,
  random-password terminal interaction, passphrase/ssh-agent interaction,
  macOS client, actual iPad/LAN reachability and iPadOS background behavior.

The Alpine guest's upstream `ssh-copy-id` printed `expr` compatibility warnings,
but returned success; subsequent independent SSH verification also succeeded.
Initial reproducer failures (missing cached server APKs, slow RSA generation,
then disabled client public-key auth inherited from Kerberos configuration)
were resolved before the successful final run. The implementation generates
only the ED25519 key it uses and explicitly enables public-key authentication.

Reproducer and logs remain outside Git at the existing
`$XDG_DATA_HOME/repro-environments/ish-kerberos/` laboratory. No Docker images,
server credentials, test keys or filesystem archives are included in this change.
The Python-runtime initialization stall is a separate, still-open investigation.

## Init subcommand follow-up

- **PASS**: full suite after routing changes: 167 tests, 159 passed, 8 platform skips.

- **PASS**: `./init sshd --key-only --port 2233`, `./init pair`, repeated
  pairing and SSH login through the saved alias in the real iSH CLI guest.
  Guest exit 0; the test key was preauthorized as above.
- **PASS**: launcher regression verifies routing without `bootstrap/main.py`
  or a Python runtime, exact argument forwarding and nonzero exit propagation.
- **PASS**: `./init sshd --help`, `./init pair --help`, shell syntax/ShellCheck.
- Pairing leaves password access unchanged. `./init sshd --key-only` remains
  an explicit, optional device-side restart; additional computers can be paired
  while password login is enabled.

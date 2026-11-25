# Termux biometric SSH unlock

English | [简体中文](README.zh.md)

An Android 11+ companion app that protects one SSH key passphrase. Your existing
SSH private keys and their passphrases stay unchanged.

The app encrypts the passphrase with AES-256-GCM in Android Keystore. Every
encryption or decryption requires authentication through a BiometricPrompt
CryptoObject. Ciphertext and the IV stay in private app storage, with backups
disabled. The passphrase never enters Termux files, command arguments, logs, or
the clipboard. Hardware backing depends on the device and is not guaranteed
by using the Keystore API alone.

## Optional installation

Run this command from the dotfiles repository:

```sh
./init ssh-biometric
```

It installs dependencies, builds the APK, and links the CLI helpers. This is
an opt-in feature, separate from the default core setup. The installer prints
the command for installing the APK through Android's package installer.

## First use

For an existing checkout and a scenario checklist, see
[testing on another phone](../../docs/termux-ssh-biometric-testing.md).

1. Install `~/.cache/termux-biometric-ssh/ssh-biometric.apk`.
2. Open **SSH 指纹解锁** (SSH biometric unlock), enter your SSH private key
   passphrase, and authenticate to save it. The app then closes.
3. In a terminal connected to your existing ssh-agent, run:

   ```sh
   ssh-add-biometric /path/to/private-key
   ```

   Without arguments, the command loads all recognized private keys directly
   under `~/.ssh`, including custom filenames, and excludes public keys and
   configuration files. Explicit arguments are passed to ssh-add, including
   options such as `-t 1h`.
4. On the first connection, compare the certificate SHA-256 fingerprint shown
   in the app and Termux. Confirm only if they match exactly.
5. Authenticate, then check the loaded identities with `ssh-add -l`.

Reuse an existing agent where possible. If none is available in your terminal,
start one with `eval "$(ssh-agent -s)"`.

Once loaded, keys are managed by ssh-agent. Locking the phone or closing the app
does not remove them. Use `ssh-add -d /path/to/private-key` to remove a key.
The saved passphrase can unlock multiple keys that share it; keys with a
different passphrase cannot use that saved secret.

If the app is installed but no passphrase is saved, the command reports the
setup steps instead of waiting for authentication. Missing APKs and canceled
authentication are also reported. A wrong saved passphrase stops further
biometric retries for that key.

## Transport and lifecycle

The SSH_ASKPASS helper listens on a random port bound only to `127.0.0.1` and
uses TLS. Its transport private key is stored at
`$XDG_STATE_HOME/termux-biometric-ssh/transport-key.pem` with mode `0600`.
When XDG_STATE_HOME is unset, the default is `~/.local/state`.

During first pairing, the user compares the certificate fingerprint shown in
Termux and the app. The app pins that certificate for subsequent connections;
the TLS handshake proves possession of the corresponding private key. The app
also sends a fresh 192-bit request token, and the helper rejects connections
with the wrong token.

The app needs Android's INTERNET permission for the loopback connection. Its
code connects only to `127.0.0.1`. It does not use cross-app Unix sockets, the
clipboard, or temporary files containing the plaintext passphrase. The app
waits for an acknowledgement before closing the connection, and returns fixed
error stages and exception class names to Termux when possible.

Processes running under the Termux UID share the same trust boundary. Do not
run `termux-biometric-askpass` directly: its standard output carries the
passphrase for ssh-add. First-pairing authentication depends on comparing the
fingerprints; do not approve requests you did not initiate.

Install updates over the existing app, preserving its signing identity and
Keystore alias. Deleting the saved passphrase also clears the pinned
certificate. If the transport identity is lost, verify and pair it again.

## Recovery and removal

Keep the original passphrase in KeePassDX or another password manager.
Uninstalling the app, clearing its data, changing some screen-lock settings, or
enrolling another fingerprint may invalidate its Keystore key. If that happens,
open the app, delete the saved entry, and enter the passphrase again. Your SSH
private key files and password-manager entries are unaffected.

To remove the integration, delete the `~/.local/bin/ssh-add-biometric` and
`~/.local/bin/termux-biometric-askpass` symlinks, then uninstall the Android app.
Build caches can also be removed when no longer needed. Keep the signing key
if you intend to install compatible updates later.

## Build and verification

Termux dependencies: `openjdk-21`, `aapt`, `d8`, `apksigner`, `zip`, `python`,
`python-cryptography`, and `openssh`.

The installer downloads the base64-encoded AOSP SDK file `35/public/android.jar`
from commit `3af7c93524be6f51e092b87b17f009f13ee98b43` and verifies the decoded
file against this SHA-256:

```text
ee568219aa3754977207a8fd849fdbf3a299658dd26dd0907d39ca830587f8aa
```

With that SDK jar in `~/.cache/termux-biometric-ssh/android.jar`, run `./build.sh`
from this directory to build the APK and verify its signature. The app signing
key is stored at `~/.local/state/termux-biometric-ssh/signing.p12`; preserve it
for future updates. These paths follow the corresponding XDG environment
variables when set.

Run `python test_bridge.py` to check TLS transport, invalid request tokens,
certificate mismatch, cancellation, truncated messages, invalid lengths,
identity persistence, and application error reporting. Actual biometric
operation and the complete ssh-agent flow require verification on the phone.

## Shell startup integration

The shared `config/sh/ssh-agent-connect.sh` detects Termux and an executable
`~/.local/bin/ssh-add-biometric`. When keys are missing from the agent, it
explains the action and waits: press Enter to open fingerprint authentication,
or enter any other text followed by Enter to skip loading. Noninteractive
shells never launch biometric authentication.

The existing zsh preparation flow calls `connectSSHAgent` outside tmux and
continues to reuse the stable agent socket. No authentication prompt appears
when all keys are already loaded. The existing forwarded-agent rules continue
to skip local key loading.

New terminals use this configuration automatically. Run `ssh-agent-connect`
to reload the connection script in the current terminal.

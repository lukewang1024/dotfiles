# Testing biometric SSH unlock on an existing Termux phone

These steps use an existing dotfiles checkout and existing SSH private keys.
Android 11 or newer and strong biometrics are required. Keep each private key's
original passphrase in your password manager.

## Update the checkout

In the phone's dotfiles directory, run:

```sh
git switch main && git pull --ff-only origin main
```

If Git reports local changes or a divergent branch, resolve that before
continuing. Updating the checkout does not install the optional biometric tool
or open a fingerprint dialog. Existing RC links use the updated source. Without
the helper, missing keys are loaded through the ordinary SSH passphrase prompt.

## Install the optional tool

```sh
./init ssh-biometric
```

The command installs dependencies, downloads and verifies the SDK jar if needed,
builds the companion locally, installs the CLI links, and automatically opens
Android's installer. Finish installation on the phone, allowing Termux to install
apps if Android asks. On subsequent runs, an unchanged source/SDK/signing
identity and matching APK checksum skip downloads and compilation; the existing
APK is opened directly. Corrupt artifacts or changed build inputs trigger a rebuild.

Each phone generates and retains its own app signing identity in XDG state.
Rerunning the command preserves it. Install updates over the existing app;
uninstalling the app deletes its saved Keystore credentials.

## Exercise the startup flow without clearing your normal agent

An already-loaded agent will correctly suppress the prompt. To test missing
keys, run this block from the dotfiles directory in an interactive terminal:

```sh
(
  eval "$(ssh-agent -s)" >/dev/null
  trap 'ssh-agent -k >/dev/null' 0
  . ./config/sh/ssh-agent-connect.sh
  addKeys || exit "$?"
  ssh-add -l
  addKeys
)
```

This uses a temporary agent inside a subshell. It does not clear your normal
agent, rewrite its stable socket, or change its profile. The last `addKeys`
checks that successfully loaded keys do not prompt again. The temporary agent
is stopped when the block exits.

## Scenarios and expected behavior

| State | Action | Expected behavior |
| --- | --- | --- |
| Checkout updated, optional helper absent | Run the temporary-agent block | Ordinary SSH passphrase input; no biometric app is opened. |
| CLI installed, APK absent | Run the block, then press Enter at the RC prompt | Installation instructions, followed by ordinary SSH passphrase input; no 90-second wait for an absent app. |
| APK installed, no SSH passphrase saved | Run the block and press Enter | Compare and confirm the certificate fingerprint on first pairing, then receive an explicit instruction to open the app and save the passphrase. The RC flow then offers ordinary SSH passphrase input. |
| No fingerprint enrolled in Android | Before saving a passphrase, use the app's save button | The app asks you to enroll a fingerprint in Android settings. Unavailable strong biometrics produce an explanation and status code. |
| Passphrase saved | Run the block and press Enter | Fingerprint authentication opens. On success, all recognized private keys sharing the saved passphrase are loaded; `ssh-add -l` lists them. |
| Password fallback selected | Press Escape, without Enter | No app or fingerprint dialog opens; ordinary SSH passphrase input starts immediately. Other text followed by Enter also selects this fallback. |
| Biometric authentication canceled | Cancel the system dialog | The RC flow reports cancellation, then uses ordinary SSH passphrase input. Explicit ssh-add-biometric calls fail instead of retrying biometrics. |
| First certificate pairing canceled | Cancel the pairing dialog | The RC flow reports cancellation and falls back to ordinary SSH passphrase input. A later attempt can pair again. |
| Startup attempt canceled | Press Ctrl-C or Ctrl-D at the choice prompt | No loading is started and terminal input settings are restored. |
| All keys already loaded | Run `addKeys` again | No confirmation or fingerprint prompt. |
| Wrong saved passphrase or a key with a different passphrase | Attempt loading that key | The helper reports a mismatch instead of repeatedly reopening fingerprint authentication. The RC flow falls back to ordinary ssh-add for manual passphrase entry. |
| Noninteractive shell | Invoke the RC function with redirected input | The biometric helper is not launched and no Enter prompt is shown. |

Open **SSH 指纹解锁** from the app list to save the existing private key's
passphrase. This encrypts the passphrase; it does not replace the SSH key or
change its passphrase. Compare certificate fingerprints only for requests you
initiated.

After setup, `ssh-agent-connect` retries the normal connection flow in an
existing configured shell. `ssh-add-biometric` explicitly loads keys without
the RC Enter prompt. Shells started inside tmux retain the existing preparation
behavior; use the explicit command to test from a pane.

Do not remove or add fingerprints just to test an already-configured phone:
enrollment changes may invalidate its Keystore key. If that happens, delete the
app's saved entry and save the original SSH passphrase again.

## Automated coverage and physical-device checks

The repository tests exercise RC consent, skip behavior, loaded identities,
missing helpers, platform selection, and dry-run installation. The transport
tests use real local TLS with simulated Android responses for success,
unconfigured state, cancellation, invalid tokens, certificate mismatch, and
wrong-passphrase retries. Isolated installation checks cover a fresh SDK
download, APK generation, command links, signing-key preservation on rerun, cached-build reuse, and installer launch requests.

Android installation permissions, device-specific biometric hardware, and the
full fingerprint-to-ssh-agent flow must still be verified on the second phone.
Transport simulations do not replace those physical-device checks.

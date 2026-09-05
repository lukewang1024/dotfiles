# Termux setup

Configure Distributed Workbench through the platform-neutral top-level task:

```sh
./init workbench
```

On first interactive setup, the bootstrap asks for the SSH config alias of one
existing distributed-workbench node. It stores that choice and an automatically
derived phone node ID in the machine-local file
`$XDG_CONFIG_HOME/distributed-workbench/peer.conf` with mode `0600`.
Neither value is committed to dotfiles.

The same task is available on every supported dotfiles platform. On Termux it
installs the Android release of distributed-workbench, configures
its Controller and restricted Executor under `termux-services`, and creates a
persistent outbound peer connection. Re-running `./init core` upgrades and
reconciles the same services. If SSH is not ready, setup is deferred without
breaking the rest of the Termux bootstrap.

Before an Android artifact is published, the same flow may use an artifact from
the selected peer's authenticated SSH bootstrap cache. This fallback contains
no built-in hostname or account data and is replaced automatically by the
normal checksum-protected release path once available.

For unattended provisioning, create the local configuration before running the
bootstrap:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/distributed-workbench"
cp config/workbench/peer.conf.example \
  "${XDG_CONFIG_HOME:-$HOME/.config}/distributed-workbench/peer.conf"
chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/distributed-workbench/peer.conf"
```

Edit the copied file with local values. The example contains no hostnames,
usernames, addresses, keys, or tokens.

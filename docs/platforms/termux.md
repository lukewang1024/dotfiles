# Termux setup

Run the normal core flow for the Termux shell environment:

```sh
./init core
```

This installs/configures the Termux packages, zsh, tmux plugins, Vim plugins,
SSH, and the shared agent configuration. It also installs `agent-team` through
the common core flow.

Machine Fabric v0.1.33 publishes an Android aarch64 runtime. To install it from
the pinned release, provide the release CDN root explicitly:

```sh
MACHINE_FABRIC_VERSION=0.1.33 \
MACHINE_FABRIC_RELEASE_BASE_URL=https://<release-cdn-root> \
./init core
```

The same variables can be used with `./init machine-fabric`. The installer
configures the local Controller/Executor through `termux-services`; peer
topology remains owned by Machine Fabric's release/bootstrap tools. The old
distributed-workbench peer bootstrap is no longer part of dotfiles.

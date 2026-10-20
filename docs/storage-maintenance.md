# Storage utilities

These tools do not know project directories, tasks, virtual machines, or image
lifecycles. Project resource owners manage their own retention and deletion.

## Capacity admission (POSIX)

`storage-admit --path PATH --working-gib 32 --reserve-gib 30` reports whether
the selected filesystem has the requested working budget plus reserve. Without
a command it is read-only. Append `-- COMMAND ARG...` to run a producer only
when admitted. Cooperating producers share an advisory lock for the command's
lifetime. Children inherit the actual environment, including proxy variables.
Direct launches bypass admission; this is not an OS quota or resource manager.

## macOS code-signing clone cleanup

`storage-maintain` defaults to a read-only plan. `--apply` only removes unused
code-signing clones in the current user's macOS-managed `X` directory. Other
files, application profiles, caches and project resources are outside its scope.

Defaults: retain two newest clones per bundle, seven idle days normally, one
idle day below a 30 GiB free-space reserve. Configure these with `--keep`,
`--retention-days`, `--pressure-days`, and `--reserve-gib`. Every descendant must
be older than the cutoff. Failed process/open-file inventory blocks deletion;
each deletion refreshes that inventory. No applications are terminated.

Apply mode excludes concurrent runs and saves its last report under
`$XDG_STATE_HOME/storage-maintain/last-run.json`. Directory sizes may count
APFS shared blocks multiple times; actual free capacity determines recovery.

The bootstrap links both tools. The opt-in `setup_storage_maintenance` task
installs the hourly macOS LaunchAgent using the existing setup-launchagent
helper. The scheduled command contains no project hooks or external cleanup
plugins. Scheduling and logs remain machine-local.

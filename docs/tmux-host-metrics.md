# tmux host metrics

At 140 columns and above the host capsule shows CPU, memory, disk usage, upload
speed and download speed together. At 80–139 columns it shows only CPU; below
80 columns the existing theme hides metrics. Percentage fields occupy 4 columns; each rate occupies 10 columns, including
its unit. Values are right-aligned; unavailable values use the same padding.
Rates use decimal MB/s (1 MB = 1,000,000 bytes), with two decimals. Rates above
999.99 MB/s display `>999MB/s` without widening the field.

The sampler is installed as `~/.local/bin/tmux-host-metrics` by shell bootstrap.
It is invoked through `sh`, including on Termux where `/bin/sh` may not exist.
No Python, background service or additional monitoring package is required.

- Linux: CPU counter deltas from `/proc/stat`; memory is total minus available.
- macOS: CPU from `top`; memory is active + wired + compressor pages from `vm_stat`.
- Disk: usage of the filesystem containing HOME (`df -Pk`). Override the path
  with `TMUX_METRICS_DISK_PATH` if another mounted filesystem matters more.
- Network: Linux uses byte-counter deltas for the default-route interface from
  `/proc/net/dev`. A new interface or reset counters start a fresh sample. macOS
  uses a one-second `nettop` TCP/UDP delta across external interfaces, excluding
  loopback, because some drivers leave `netstat` receive counters frozen.
  Upload and download are shown separately.
- Termux: uses the Linux path; Android may deny `/proc/stat` or network counters.
  Unavailable metrics show `--`, while available memory/disk metrics still work.
  Real-device Termux acceptance remains pending.

Samples share a two-second cache in `$XDG_CACHE_HOME/tmux-host-metrics` (default
`~/.cache/tmux-host-metrics`). The first counter sample and samples more than
120 seconds apart show `--` until a new baseline is established. The tmux
status interval controls subsequent refreshes. No traffic payload is collected.

Icons use Nerd Fonts: `oct-cpu`, `md-memory`, `md-harddisk`, `md-upload`,
`md-download`, verified against the official glyph map:
https://github.com/ryanoasis/nerd-fonts/blob/master/glyphnames.json

Verification: `python3 -m unittest discover -s tests -p test_tmux_host_metrics.py`.
Fixtures cover Linux, macOS, restricted Android counters, caching, interface
changes and counter resets. macOS and Linux also have live sampling coverage.

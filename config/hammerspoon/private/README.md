# Hammerspoon

[Hammerspoon](https://www.hammerspoon.org/) · [Original configuration article](http://seanxp.com/2016/mac-hammerspoon/)

Hyper+Space opens its menu on the display containing the active window. Submenus
stay on that display; the next invocation follows the active window again. With
no active window, it uses the current main display.

## Away guard for desktop automation

Search for “Enable away guard” with **Hyper+Space**, or use **H+0 → X → G**.
There is no permanent menu bar button. Keep the MacBook lid open; external power
is recommended. Notifications and lock reasons follow the system's preferred
language: Chinese variants use Chinese, and other languages fall back to English.
Diagnostic logs use stable English identifiers.

On activation, the guard saves ordinary window frames and displays, internal
display brightness and automatic brightness, and the hardware identities of
online external displays. It temporarily disables and verifies automatic
brightness, disables signal output to those external displays, and lowers the
internal display brightness to zero after confirming that only it remains online.
No cables need to be unplugged. A notification confirms successful activation.
Display disabling and automatic brightness use private macOS SkyLight and
DisplayServices interfaces, which may stop working after an OS update. Preparation
failure or timeout requests a screen lock; restoration is attempted after an
authenticated unlock.

For native fullscreen Windows App (Microsoft RDP) sessions, preparation saves
window and display identities, temporarily exits fullscreen, and waits for the
Space transition to settle. Connections stay active. Fullscreen is restored after
authenticated unlock and external display restoration. Session discovery combines
the remote-window filter cache with direct Accessibility (AX) queries, including
RDP windows in inactive Spaces. Original displays are recorded through Space
membership rather than potentially stale cross-Space coordinates. This changes
RDP window sizes and may change remote resolution when dynamic resolution is on.

Preparation allows up to 15 seconds to confirm that external displays are offline.
If a Space transition disables only some displays, retries target only displays
recorded for this activation. The internal-only state must remain stable for
1.5 seconds before brightness is lowered. Once armed, display changes or increased
brightness are not retried or ignored: the guard checks for lock triggers every
300 ms. Preparation failure logs include IDs of displays still online.

The native helper checks both the underlying display list, including disabled
external displays, and the online list every 300 ms. It also listens for display
configuration events, so physically disconnecting a disabled display is detected.
On first use, system `swiftc` compiles the helper into
`$XDG_CACHE_HOME/away-guard` (default: `~/.cache/away-guard`). The guard saves the
original brightness, lowers it to zero, and runs a separate `caffeinate -d -i`
process to prevent idle display and system sleep. It does not intercept input,
cover the desktop, or alter screenshots.

### Lock triggers and restoration

Every 300 ms, the guard checks internal brightness and display identity. It
requests a lock if brightness becomes greater than zero or unreadable, an external
display is connected or disconnected, display configuration changes, a keep-awake
or display-monitor process exits, a heartbeat is lost, or the system sleeps or
wakes. Brightness detection does not distinguish manual changes from system
changes. Automatic brightness stays off while armed and is restored afterward.

Hammerspoon display notifications compare display identity, position, resolution,
scaling, and refresh rate. Duplicate notifications with no configuration change do
not trigger a lock; native display events and physical connection detection remain
active. Lock requests continue until a lock notification is observed. After an
authenticated unlock, the guard restores brightness and the external displays it
disabled, releases the keep-awake process, and exits.

Lock requests precede display reads, logging, and state writes. Failures in those
operations cannot prevent the request; Lua event-handler failures also request a
lock. Only a session that observed a lock may handle a subsequent unlock. An
unpaired unlock requests another lock. Locking again during restoration cancels
that attempt and invalidates its callbacks; the next unlock starts a new attempt.
Disconnected displays are skipped. Restoration failures retain recovery data so
another lock/unlock cycle can retry.

Trying to enable the guard after a restoration failure reports pending recovery.
Use “Away guard: lock and return” (**H+0 → X → E**) and authenticate to retry.
Activation during restoration asks you to wait. Rejected activation attempts log
`arm_rejected` with the actual state.

Disabling external displays moves windows onto the internal display. After the
external displays return and the layout settles, the guard restores accessible
ordinary windows to their saved positions and sizes, verifies each result, and
retries a bounded number of times. Closed windows and replaced processes are
skipped. Cached zero-size windows are treated as closed after bounded retries.
Window and RDP fullscreen restoration are best effort: failures are logged and
the latest failure snapshot is saved in `awayGuard.lastWindowRecovery`, without
blocking exit or the next activation. Missing displays, changed layouts, or apps
that reject resizing can prevent exact restoration. Failed external display
restoration keeps the active session available for another attempt.

Native fullscreen RDP windows are restored separately. Other fullscreen windows,
hidden or minimized windows, Space membership, stacking order, mirroring, and
virtual desktop arrangement are outside this recovery scope.

Raise internal brightness to trigger the return flow, search for “Away guard:
lock and return” in Hyper+Space, or use **H+0 → X → E**. Restoration follows
authenticated unlock. Reloading or quitting Hammerspoon while armed requests a
lock; a persisted session requests another lock on the next load. Do not quit
Hammerspoon as a way to disarm the guard.

### Native watchdog and limitations

The native helper independently monitors brightness and display changes and
requests a system lock. Once Lua authorizes display disabling, it sends a
heartbeat every 300 ms. The helper checks heartbeats on an independent queue and
requests a lock after more than two seconds without one, or when its input pipe
closes. It retries until it observes a locked system. The authenticated recovery
path explicitly sends `disarm` to end monitoring normally.

Monitor messages use nonblocking output: a parent that stops reading cannot block
heartbeat checks. Activation is refused if the independent lock API is unavailable.
This is best-effort monitoring within the user's session; 300 ms is a polling
interval, not a guarantee of lock completion. The helper can cover a stalled or
exited Hammerspoon process, but cannot guarantee protection if both processes are
terminated, the system stalls, or private lock APIs fail.

Zero brightness does not prevent blind interaction. Keyboard and mouse input stay
enabled so GUI automation can continue. Lid closure, power loss, forced sleep,
and existing system lock policies are not overridden. During initial acceptance,
verify in person that external displays lose signal, the internal display is dark,
and automation continues. Confirm that raising brightness, unplugging a disabled
display, and connecting a new display each trigger a lock. If automation is still
sending input after unlock, pause it before resuming manual interaction.

### Logs and diagnostics

Lifecycle and trigger events are written to `$XDG_STATE_HOME/away-guard/events.jsonl`
(default: `~/.local/state/away-guard/events.jsonl`). At 5 MiB, one `.1` backup is
retained. Logs are event-driven, not written every 300 ms. They include timestamps,
trigger reasons, brightness and display identities, heartbeat delay, native display
event IDs/flags, and window recovery results. Window titles are not logged.

`lock_requested` means the guard requested a lock. A `lock_observed` event with
`system_or_external_lock` means a system or external lock was observed first; it
does not identify the responsible policy. After recovery, a notification shows
the trigger reason. Run `workbenchAwayGuard:lastTrigger()` in the Hammerspoon
console, or inspect the full sequence with:

```sh
tail -n 30 ~/.local/state/away-guard/events.jsonl
```

Display events do not necessarily mean physical interaction, and increased
brightness does not necessarily mean someone touched the computer.

Run the logic tests:

```sh
luajit config/hammerspoon/private/tests/away-guard.lua
luajit config/hammerspoon/private/tests/away-guard-windows.lua
```

The native watchdog self-test checks heartbeats, retries, lock observation,
disarming, pipe commands, and EOF. It resolves the real lock symbol but never
invokes it:

```sh
/bin/sh config/hammerspoon/private/helpers/away-guard-display self-test
/bin/sh config/hammerspoon/private/helpers/away-guard-display status
```

For terminal recovery, use the hardware identities recorded in
`awayGuard.session.external`:

```sh
/bin/sh config/hammerspoon/private/helpers/away-guard-display restore '<hardware-identity>' ...
```

If `awayGuard.session.autoBrightness` was saved, add `--auto-brightness=on` or
`--auto-brightness=off` to restore its original value.

## Image synchronization and Hyper shortcuts

**Ctrl+Option+Shift+V** opens the native image synchronization menu. Select with
arrow keys or the mouse, press Enter to run, and Esc to close. There is no permanent
menu bar entry. This no longer uses a searchable chooser, so there are no Cmd+number
hints or bindings. The menu has three actions: send the existing clipboard image,
choose a destination, and inspect the last result. **Ctrl+Option+V** sends the
current clipboard image directly. Ctrl+Option+C, Ctrl+Option+Z, and Ctrl+Option+/
are released.

Hyper bindings are owned by the [shared configuration](../../hyper/README.md).
In a menu with an empty search field, Backspace goes back one level. With text in
the field, it deletes normally. Backspace does not exit the top-level menu; Esc
closes the entire panel.

Application bindings:

| Keys | Applications |
| --- | --- |
| H+Q / H+Shift+Q | Firefox / Safari |
| H+W / H+Shift+W | Edge / Chrome |
| H+E / H+Shift+E | Sublime Text / VS Code |
| H+A / H+S | ChatGPT / Doubao |
| H+D / H+Shift+D | Dictionary / DevDocs |
| H+Z | Finder |
| H+X / H+Shift+X | Feishu / Feishu Meetings |
| H+C / H+Shift+C | WeChat / Telegram |
| H+R | Toggle the remote desktop group |
| H+Shift+R / H+Shift+N | Reeder / NoMachine |
| H+semicolon / H+Shift+semicolon | Primary / secondary terminal |

Enter and backtick terminal bindings have been removed. Repeating an application
shortcut still hides that application, except H+R, which operates on the group.

The number row uses H+1 for window search, H+2 for application search, H+3 for
clipboard history, H+4 for region capture, H+5 for recording, H+6 for audio output,
H+7 for microphone selection, and H+0 for Hyper configuration. Shift+number and
H+8/9 are unassigned. The old H+Shift+V clipboard tools menu is now at H+0 → C.
H+0 → S/V/D/F/X opens screenshot, recording, display settings, Focus settings, and
the system menu respectively. H+3 requires first-use consent for in-memory text
history.

On landscape displays, H+Left/Right selects the left/right half. H+Up/Down from a
half-screen window selects the corresponding upper/lower quarter. On ordinary
windows, H+Up maximizes and H+Down minimizes; H+Up first restores the most recent
window minimized by Hyper. H+Shift+Up cycles left/right two-thirds, while
H+Shift+Down cycles right/middle/left thirds. H+Backspace undoes placement and
H+Shift+Left/Right moves between displays.

Portrait mode is detected when the current usable display height exceeds its
width. H+Left/Right then selects the upper/lower half; H+Shift+Up cycles upper/lower
two-thirds, and H+Shift+Down cycles lower/middle/upper thirds. H+Up/Down retains
maximize, restore, and minimize behavior without landscape half/quarter transitions.
Display-movement bindings are unchanged.

H+Home centers a window, H+End toggles maximize/restore, and H+PageUp/PageDown
provides fixed upper/lower halves on full keyboards. With Shift, these four keys
focus windows to the left/right/up/down. H+Shift+Space toggles native fullscreen.
H+brackets decreases/increases width; adding Shift adjusts height. These actions
do not open menus.

Hammerspoon exclusively owns Hyper window actions. On first migration, run the
Rectangle migration script documented in the shared configuration. H+Space opens
search and H+/ opens the shortcut reference. The old window menu, semicolon split
bindings, and single-quote entry have been removed.

H+Shift+/ or H+0 followed by A configures application roles, showing the current
application and shortcut. Changes save immediately; defaults can be restored.
Roles without a shortcut remain searchable through H+Space. Role overrides affect
role actions immediately, while fixed application shortcuts retain their targets.
Candidates include a cached index of installed apps. The old `chat` preference
migrates to `workChat` without affecting `dailyChat`.

Menus follow the system's preferred Chinese or English language after reload;
features remain searchable in both languages. Hyper means Ctrl+Option+Command.
Automatic Karabiner switching for remote desktops and image synchronization remain
available. The new entry point does not load legacy ModalMgr, appM, ClipShow,
HSearch, KSheet, clocks, or countdown panels.

### Installation

`bootstrap/dotfiles/platforms.py` links the parent directory's `init.lua` to
`$XDG_CONFIG_HOME/hammerspoon/init.lua` and `workbench-init.lua`, and points
Hammerspoon's `MJConfigFile` to that path. Use Reload Config from the Hammerspoon
menu after the first switch. The previous local entry point is backed up at
`$XDG_CONFIG_HOME/hammerspoon/legacy-init.lua`. Both entry paths target the new
configuration, preventing a running Hammerspoon from reloading its cached legacy
path. The legacy awesome-hammerspoon launcher and Spoons are not required.

## Workbench image synchronization

`modules/workbench-clipboard.lua` obtains connected remote nodes through the
Machine Fabric CLI. The menu refreshes node metadata every 30 seconds without
reading or watching the clipboard. After choosing a destination, press
**Ctrl+Option+V** (without Command; not Hyper or HyperAlt) to send the current
clipboard image. It does not simulate Cmd-C or require a recent clipboard change;
both screenshots and copied images work. **Ctrl+Option+Shift+V** opens the menu
for destination selection, sending, and status.

Success is reported only after the destination acknowledges the write. Missing
images, unavailable nodes, disconnects, and timeouts show a reason without
retrying automatically or switching to another device. Text continues to use
normal terminal paste.

The installed CLI must support:

```sh
machine-fabric clipboard targets --json
machine-fabric clipboard push --target ID --image-only --json
```

The default executable is `~/.local/bin/machine-fabric`. For development, set the
following and reload:

```lua
hs.settings.set('machine-fabric.clipboard.binary', '/absolute/path/to/machine-fabric')
```

The legacy `workbench.clipboard.binary` setting is still accepted. Clear the
setting to restore the default. Nodes without image support are disabled in the
menu.

The dotfiles agent shell functions launch agents directly, without the Workbench
CLI or updater. Before launching, they may read
`${XDG_CONFIG_HOME:-$HOME/.config}/machine-fabric/clipboard-env`. Only literal
`DISPLAY` and `XAUTHORITY` values are passed to children, whose `WAYLAND_DISPLAY`
is cleared. File content is never executed, and the current shell environment is
unchanged. `AGENT_CLIPBOARD_ENV_FILE` selects an alternative provider file; an empty
string disables this integration. Missing files, unknown fields, or missing
nonempty required values preserve the inherited environment and do not prevent
agent startup. Image synchronization itself remains the Machine Fabric feature
described above. Existing terminals must reload
`config/zsh/agent-resume-history.zsh` and restart the agent.

Run the logic tests:

```sh
luajit config/hammerspoon/private/tests/workbench-clipboard.lua
luajit config/hammerspoon/private/tests/toolbox.lua
luajit config/hammerspoon/private/tests/window-shortcuts.lua
```

## Configured window groups

`modules/window-groups.lua` declares which windows join each group.
`modules/window-group.lua` implements membership, group activation, coordinated
show/hide, stacking, and restoration. `remote-window-stack` uses this controller
and adds the remote-specific cascade, aspect constraints, and layout shortcuts.
Hyper+R continues to toggle the configured `remote` group; its saved layout and
screen settings retain their existing `remoteStack.*` keys.

Each application rule has a `bundleID`, an optional `appName` for immediate focus
notifications, and a `selection`: `all` includes every matching standard window;
`main` includes a single matching main window. Matchers can combine exact `title`,
Lua `titlePattern`, `nonEmptyTitle`, `excludeTitles`, AX `role` / `subrole`, and
an application-specific `match(window)` predicate. `main` never guesses from the
frontmost or largest window: if multiple candidates match, that application is
excluded and `group.selectionErrors` records the ambiguity. Missing applications
or main windows are skipped without launching anything. Membership is refreshed
for each operation, so newly opened matching windows join automatically.

For example, a future personal-chat configuration can use different main-window
rules per app (the bundle IDs and titles below are placeholders):

```lua
local group = require('private/modules/window-group').new({
  id='personalChat',
  apps={
    {bundleID='com.example.chat',appName='Example Chat',selection='main',
      title='Example Chat',role='AXWindow',subrole='AXStandardWindow'},
    {bundleID='com.example.messenger',appName='Example Messenger',selection='main',
      match=function(win) return win:title()=='Chats' end},
  },
}):start()
group:toggle()
-- Call group:stop() at shutdown.
```

The generic controller preserves existing window positions. Only the remote
adapter applies automatic sizing and cascading. Show/hide operates on member
windows, not the entire application, so connection libraries, separate chats,
settings, and previews excluded by the rules are left alone. Activating a member
raises the visible group together; focusing an excluded window does not activate
the group. Personal-chat rules are not enabled until real per-app main-window
selectors have been configured.

## Remote desktop group

`remote-window-stack` continuously manages Windows App remote sessions and
NoMachine sessions whose titles end in ` - NoMachine`. Connection libraries,
untitled content windows, and settings windows are excluded. It reconciles every
two seconds and immediately after display changes or remote-window focus events.
When a session is active, the visible group is raised together in its existing
order so other applications cannot cover its inactive titlebars. Switching to
another application stops group raising. Hidden or minimized windows
are not raised; updates pause while the mouse is being dragged.

The group defaults to the primary display. Set
`hs.settings.set('remoteStack.screenUUID', '<display-UUID>')` to choose another;
if that display is offline, the group falls back to the primary display. There are
no fixed outer margins. Titlebars are staggered by 28 points. A visible Dock uses
macOS's usable display area without additional padding. An auto-hidden Dock gets
only a two-point activation strip on its left, right, or bottom edge. Dock settings
are read on each reconciliation to follow orientation and visibility changes.

When NoMachine constrains the aspect ratio, all sessions use its accepted size and
are horizontally centered; additional unused space may remain. The foremost
remote session occupies the lowest slot so the other titlebars stay exposed. The
layout does not steal focus. Native fullscreen sessions are automatically returned
to windowed mode, so a new connection may briefly enter fullscreen before being
corrected. Disable startup fullscreen in the Windows App connection's display
settings to avoid that transition entirely.

Layout management pauses while away guard is not `idle`, and resumes after
recovery. It overrides manual placement. To disable it temporarily, run
`workbenchRemoteStack:stop()`; reloading the configuration enables it again.

### Group layouts and display movement

The group saves its display and normalized layout (`remoteStack.unit`). With any
remote session focused, Hyper half-screen, one-third, two-thirds, maximize, and
fullscreen actions operate on the entire group. Directional display actions move
the group while retaining its layout proportions. Hyper+Up fills the available
area; Hyper+Down restores the previous group layout, or does nothing without
history. For the group, fullscreen means filling the usable area, not entering a
native fullscreen Space. Other shortcuts retain the existing remote-keyboard
policy.

New sessions join the group. For N windows, the common height limit is the group
region height minus `(N-1) × 28` points, subject to NoMachine's aspect constraint.
Three windows therefore have a height limit 28 points smaller than two windows.
Display and layout selection survive configuration reloads. `window.undo` undoes
the preceding group layout or display move.

### Visibility and restoration

Hyper+R toggles the group. With a group session active, it minimizes all session
windows; from another application, it restores and raises the group. Connections
remain active. Connection libraries are not minimized. An empty group presents
installed remote clients from the application index; selecting one opens it. If no
client is found, a notification explains this. This entry point no longer launches
the default application assigned to the remote role.

Hiding retains each window's AX reference, window/PID identity, and focus.
Before showing the remote group, the adapter computes its final frames from the
configured screen/layout and cached accepted client sizes. It uses those same
targets during restoration and subsequent polling, rather than restoring old
coordinates and then deriving a second layout from their bounding rectangle.
Logical slot order survives temporary CG stacking changes during unminimize;
explicitly focusing another member moves that member to the lowest cascade slot.

Restoration pauses layout reconciliation, sets targets before and immediately
after unminimizing, and waits for two stable observations before completing. It
retries up to 12 times at 200 ms intervals and does not depend on live enumeration
that may temporarily omit minimized clients. Closed windows and replaced
processes are skipped. `workbenchRemoteStack.restoreReport` exposes completion
status; clients rejecting their rule targets may prevent exact restoration.

Run the group and shortcut regression tests:

```sh
luajit config/hammerspoon/private/tests/window-group.lua
luajit config/hammerspoon/private/tests/remote-window-stack.lua
luajit config/hammerspoon/private/tests/hyper.lua
```

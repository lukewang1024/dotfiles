# Away Guard timing and incident evidence

The CU availability snapshot has a 10,000ms lifetime. Lua allows 10 seconds of
missing helper heartbeats; the native helper separately allows 10 seconds of
parent heartbeat loss. These transport grace periods do not delay explicit
return, lock, display-topology or brightness events. Such events revoke CU input
and the worker retains the existing pause notification and generation rules.

Native topology, online-display and brightness checks still run every 300ms.
An independent 2-second watchdog measures actual successful check progress.
Parent heartbeats cannot update this progress. Failed checks and positive
brightness request a lock immediately; stalled checks cannot be hidden by an
otherwise responsive command thread. Initial display setup retains its separate
25-second bounded handshake.

Heartbeats carry sequence numbers and sender monotonic times in both directions.
Lua and Swift share the mach_absolute_time clock. Delivery of an old, duplicate
or reordered pipe message never changes it into a fresh check. An elapsed native
deadline cannot be reset by a late heartbeat, check or arm acknowledgement.

Lifecycle and incident records contain bounded gap histograms, maximum gaps,
direction-specific sequences, native progress time, configured limits and the
first native incident ID/request time. Regular polls do not append logs. The
Guard's return action is attributed explicitly; externally observed locks remain
unknown unless a matching native incident supplies evidence. A later brightness
signal cannot overwrite an already recorded manual return cause.

Deploy the compatible Fabric reader before this publisher, behind owned desktop
maintenance. Its reader accepts both the old 1,500ms and new 10,000ms lifetimes,
but rejects future, expired, malformed and non-provider snapshots. Do not arm the
Guard or inject lock/stall faults on a user's desktop for acceptance. The Lua
fixtures and Swift `self-test` exercise those failures with fake lock closures.

-- Lease/transport grace is independent of the native display-check watchdog.
local M = {snapshotLifetimeMs=10000, helperHeartbeatSeconds=10, pollSeconds=0.3}
function M.now() return hs.timer.absoluteTime() / 1000000000 end
return M

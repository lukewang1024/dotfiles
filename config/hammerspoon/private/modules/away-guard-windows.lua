-- Restore existing normal windows after displays settle, verifying AX results.
local M = {}
local function rect(frame) return {x=frame.x,y=frame.y,w=frame.w,h=frame.h} end
local function same(a,b)
  return a and b and math.abs(a.x-b.x)<=2 and math.abs(a.y-b.y)<=2
    and math.abs(a.w-b.w)<=2 and math.abs(a.h-b.h)<=2
end
function M.new(options)
  options = options or {}
  local self = {}
  local function windows()
    if options.windows then return options.windows() end
    return hs.window.filter.default:getWindows()
  end
  function self:capture()
    local snapshot = {windows={}, screens={}}
    for _,screen in ipairs(hs.screen.allScreens()) do
      snapshot.screens[screen:getUUID()] = rect(screen:fullFrame())
    end
    for _,window in ipairs(windows()) do
      local ok, saved = pcall(function()
        local screen, app = window:screen(), window:application()
        -- Fullscreen applications own their Space geometry; RDP is handled separately.
        if not screen or not app or not window:isStandard() or window:isFullScreen() then return end
        local id = window:id()
        if not id or id <= 0 then return end -- Menu extras can report AXStandardWindow with no real window ID.
        local frame = window:frame()
        if not frame or frame.w <= 0 or frame.h <= 0 then return end
        return {id=id, pid=app:pid(), bundle=app:bundleID(), screen=screen:getUUID(), frame=rect(frame)}
      end)
      if ok and saved then snapshot.windows[#snapshot.windows+1] = saved end
    end
    return snapshot
  end
  function self:stop()
    if self.timer then self.timer:stop(); self.timer=nil end
  end
  function self:restore(snapshot, callback)
    self:stop()
    snapshot = snapshot or {windows={},screens={}}
    if #(snapshot.windows or {}) == 0 then callback({restored=0,closed=0,failed={}});return end
    local deadline, stable, lastSignature, attempts = hs.timer.secondsSinceEpoch()+10, 0, nil, 0
    local function finish(report) self:stop();callback(report) end
    self.timer=hs.timer.doEvery(0.3,function()
      local screens, signature = {}, {}
      for _,screen in ipairs(hs.screen.allScreens()) do
        local uuid, frame=screen:getUUID(),screen:fullFrame()
        screens[uuid]=screen
        signature[#signature+1]=string.format('%s:%g:%g:%g:%g',uuid,frame.x,frame.y,frame.w,frame.h)
      end
      table.sort(signature);signature=table.concat(signature,';')
      if signature==lastSignature then stable=stable+1 else stable=0;lastSignature=signature end
      if stable<3 and hs.timer.secondsSinceEpoch()<deadline then return end
      local current={}
      for _,window in ipairs(windows()) do
        local ok,id=pcall(function()return window:id()end)
        if ok and id and id > 0 then current[id]=window end
      end
      local report={restored=0,closed=0,failed={}}
      attempts=attempts+1
      for _,saved in ipairs(snapshot.windows) do
        local window,screen=current[saved.id],screens[saved.screen]
        local ok,status=pcall(function()
          -- Do not move a replacement window whose ID was recycled by another process.
          if not window or window:application():pid()~=saved.pid or window:application():bundleID()~=saved.bundle then return 'closed' end
          if not screen then return 'display_missing' end
          if not same(screen:fullFrame(),snapshot.screens[saved.screen]) then return 'display_layout_changed' end
          if window:isFullScreen() then return 'window_now_fullscreen' end
          if attempts <= 5 and (not same(window:frame(),saved.frame) or window:screen():getUUID()~=saved.screen) then
            -- Absolute coordinates also move across monitors. Avoid the intermediate
            -- shrink/move steps in setFrameWithWorkarounds: Electron can apply them out of order.
            window:setFrame(hs.geometry.rect(saved.frame),0)
          end
          if same(window:frame(),saved.frame) and window:screen():getUUID()==saved.screen then return 'restored' end
          return 'frame_not_applied'
        end)
        if ok and status=='restored' then report.restored=report.restored+1
        elseif ok and status=='closed' then report.closed=report.closed+1
        else report.failed[#report.failed+1]={id=saved.id,bundle=saved.bundle,screen=saved.screen,reason=ok and status or tostring(status)} end
      end
      -- One final read-only pass gives asynchronous AX setters time to settle.
      if #report.failed==0 or attempts>=6 or hs.timer.secondsSinceEpoch()>=deadline then finish(report) end
    end)
  end
  return self
end
return M

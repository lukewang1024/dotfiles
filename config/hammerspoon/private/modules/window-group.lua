-- Window membership and group lifecycle, independent of application/layout policy.
local M = {}

function M.matches(rule, bundle, title, win)
  if bundle ~= rule.bundleID then return false end
  if rule.nonEmptyTitle and title == '' then return false end
  if rule.title and title ~= rule.title then return false end
  if rule.titlePattern and not title:match(rule.titlePattern) then return false end
  for _,excluded in ipairs(rule.excludeTitles or {}) do
    if title == excluded then return false end
  end
  if rule.role and (not win or win:role() ~= rule.role) then return false end
  if rule.subrole and (not win or win:subrole() ~= rule.subrole) then return false end
  return not rule.match or (win ~= nil and rule.match(win))
end

function M.new(config, options)
  assert(config and config.id and config.apps, 'window group needs id and apps')
  options=options or {}
  local self={config=config,selectionErrors={}}
  local rules={}
  for _,rule in ipairs(config.apps) do
    assert(rule.bundleID and not rules[rule.bundleID], 'one rule per bundle ID')
    assert(rule.selection=='all' or rule.selection=='main', 'selection must be all or main')
    rules[rule.bundleID]=rule
  end
  function self:rule(win)
    local app=win and win:application()
    return app and rules[app:bundleID()] or nil
  end
  function self:members()
    local candidates={}
    self.selectionErrors={}
    for _,app in ipairs(hs.application.runningApplications()) do
      local bundle=app:bundleID()
      local rule=rules[bundle]
      if rule then
        local bucket=candidates[bundle] or {}
        candidates[bundle]=bucket
        for _,win in ipairs(app:allWindows()) do
          if win:isStandard() and M.matches(rule,bundle,win:title(),win) then
            bucket[win:id()]=win
          end
        end
      end
    end
    local windows={}
    for _,rule in ipairs(config.apps) do
      local bucket=candidates[rule.bundleID] or {}
      local count=0
      for _ in pairs(bucket) do count=count+1 end
      if rule.selection=='main' and count>1 then
        self.selectionErrors[#self.selectionErrors+1]={bundleID=rule.bundleID,count=count,reason='ambiguous main window'}
      else
        for _,win in pairs(bucket) do windows[#windows+1]=win end
      end
    end
    table.sort(windows,function(a,b)return a:id()<b:id() end)
    return windows
  end
  function self:contains(win)
    if not win or not self:rule(win) then return false end
    for _,member in ipairs(self:members()) do if member:id()==win:id() then return true end end
    return false
  end
  function self:focusedWindow()
    local app=hs.application.frontmostApplication()
    if not app then return nil end
    local members={}
    for _,win in ipairs(self:members()) do members[win:id()]=win end
    -- Remote clients can omit AX focus events. Consult the actual CG order,
    -- and do not treat a focused settings/library window as group activation.
    for _,cg in ipairs(hs.window.list()) do
      if cg.kCGWindowOwnerPID==app:pid() and cg.kCGWindowLayer==0
          and cg.kCGWindowName and cg.kCGWindowName~='' then
        return members[cg.kCGWindowNumber]
      end
    end
  end
  function self:capture(windows,focused)
    local ranks={}
    for i,cg in ipairs(hs.window.list()) do ranks[cg.kCGWindowNumber]=i end
    local saved={windows={},focused=focused and focused:id()}
    for _,win in ipairs(windows) do
      local f=win:frame()
      saved.windows[#saved.windows+1]={window=win,id=win:id(),pid=win:application():pid(),
        title=win:title(),frame={x=f.x,y=f.y,w=f.w,h=f.h},
        minimized=win:isMinimized(),rank=ranks[win:id()] or math.huge}
    end
    table.sort(saved.windows,function(a,b)return a.rank>b.rank end)
    return saved
  end
  function self:restore(saved)
    self.restoring=true
    self.hidden=false
    if self.prepareRestore then self:prepareRestore(saved) end
    local attempts,stablePasses=0,0
    local function pass()
      attempts=attempts+1
      local pending=false
      local targets={}
      for _,item in ipairs(saved.windows) do
        local win=item.window
        -- Retain the original AX reference: minimized clients can disappear
        -- temporarily from allWindows(). Never restore an unrelated new window.
        local ok,valid=pcall(function()
          return win:id()==item.id and win:application():pid()==item.pid
        end)
        if ok and valid and not item.minimized then
          local success=pcall(function()
            win:application():unhide()
            if win:isMinimized() then
              -- Set the rule target before showing where AX permits it, and
              -- correct synchronously after unminimize if the client resets it.
              win:setFrame(item.frame,0)
              win:unminimize()
              pending=true
            end
            local f=win:frame();local target=item.frame
            if math.abs(f.x-target.x)>1 or math.abs(f.y-target.y)>1
                or math.abs(f.w-target.w)>1 or math.abs(f.h-target.h)>1 then
              win:setFrame(target,0)
              -- Verify on a later pass; the client's AX return is asynchronous.
              pending=true
            end
            targets[#targets+1]=win
          end)
          if not success then pending=true end
        end
      end
      if pending then stablePasses=0 else stablePasses=stablePasses+1 end
      if (pending or stablePasses<2) and attempts<12 then
        self.restoreTimer=hs.timer.doAfter(.2,pass)
        return
      end
      -- Restore back-to-front order only after every client's frame has settled.
      for _,win in ipairs(targets) do win:raise() end
      for _,win in ipairs(targets) do if win:id()==saved.focused then win:focus();break end end
      if not pending and self.didRestore then self:didRestore(saved) end
      self.restoreTimer=nil
      self.restoring=false
      self.restoreReport={attempts=attempts,complete=not pending}
      self.savedHidden=nil
    end
    pass()
  end
  function self:toggle()
    if self.restoring then return true end
    -- Restore the captured members, not a possibly incomplete live enumeration.
    if self.hidden and self.savedHidden then self:restore(self.savedHidden);return true end
    local windows=self:members()
    if #windows==0 then self.hidden=false;return false end
    local focused=self:focusedWindow()
    if focused then
      self.savedHidden=self:capture(windows,focused)
      self.hidden=true
      for _,win in ipairs(windows) do if not win:isMinimized() then win:minimize() end end
    else
      -- Generic groups retain positions; a layout adapter may replace these
      -- frames with rule targets in prepareRestore before any window is shown.
      local saved=self:capture(windows,nil)
      for _,item in ipairs(saved.windows) do item.minimized=false end
      saved.focused=saved.windows[#saved.windows].id
      self:restore(saved)
    end
    return true
  end
  function self:raiseActiveGroup(windows, ordered)
    local focused=self:focusedWindow()
    if not focused then return end
    local members={}
    for _,win in ipairs(windows) do members[win:id()]=true end
    if not members[focused:id()] then return end
    local foreign=false
    local obstructed=false
    for _,cg in ipairs(ordered) do
      if members[cg.kCGWindowNumber] then
        if foreign then obstructed=true;break end
      elseif cg.kCGWindowLayer==0 then
        foreign=true
      end
    end
    if not obstructed then return end
    -- windows are back-to-front. AXRaise preserves keyboard focus; raising
    -- the active member last keeps both its focus and the cascade order.
    for _,win in ipairs(windows) do
      if win:id()~=focused:id() then win:raise() end
    end
    focused:raise()
  end
  function self:apply()
    if self.hidden or self.restoring then return end
    if options.suspended and options.suspended() then return end
    if hs.eventtap.checkMouseButtons().left then return end
    local ordered=hs.window.list()
    local ranks={}
    for i,cg in ipairs(ordered) do ranks[cg.kCGWindowNumber]=i end
    local windows={}
    for _,win in ipairs(self:members()) do
      if win:isVisible() and not win:isMinimized() then windows[#windows+1]=win end
    end
    table.sort(windows,function(a,b)return (ranks[a:id()] or math.huge)>(ranks[b:id()] or math.huge) end)
    self:raiseActiveGroup(windows,ordered)
  end
  function self:start()
    if self.timer then return self end
    local function reconcile()
      local ok,err=pcall(function()self:apply()end)
      if not ok then hs.printf('[window-group:%s] %s',config.id,tostring(err)) end
    end
    self.timer=hs.timer.doEvery(2,reconcile)
    self.screenWatcher=hs.screen.watcher.new(reconcile):start()
    self.focusWatcher=hs.window.filter.new(false)
    for _,rule in ipairs(config.apps) do
      -- Window filters take application names, while membership uses bundle IDs.
      if rule.appName then self.focusWatcher:setAppFilter(rule.appName,{}) end
    end
    self.focusWatcher:subscribe(hs.window.filter.windowFocused,reconcile)
    reconcile()
    return self
  end
  function self:stop()
    if self.restoreTimer then self.restoreTimer:stop() end
    if self.timer then self.timer:stop() end
    if self.screenWatcher then self.screenWatcher:stop() end
    if self.focusWatcher then self.focusWatcher:unsubscribeAll() end
  end
  return self
end
return M

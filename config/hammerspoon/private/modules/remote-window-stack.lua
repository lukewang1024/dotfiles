-- Keep remote sessions in a windowed cascade, independent of client frame memory.
local M = {}
M.defaults = {titlebar=28, dockTrigger=2}

function M.isSession(bundle, title)
  if bundle == 'com.nomachine.nxdock' then
    return title:match(' %- NoMachine$') ~= nil
  end
  if bundle == 'com.microsoft.rdc.macos' then
    return title ~= '' and title ~= 'Windows App' and title ~= 'Microsoft Remote Desktop'
      and title ~= 'Settings' and title ~= 'Preferences' and title ~= '设置'
  end
  return false
end

-- macOS already removes a visible Dock and the menu bar from usableFrame.
-- For an auto-hidden Dock, reserve only a thin strip on its activation edge.
function M.bounds(usableFrame, fullFrame, dock, options)
  local c=options or M.defaults
  local r={x=usableFrame.x,y=usableFrame.y,w=usableFrame.w,h=usableFrame.h}
  if not dock.autohide then return r end
  local edge=dock.orientation or 'bottom'
  local gap=c.dockTrigger or M.defaults.dockTrigger
  local right,bottom=r.x+r.w,r.y+r.h
  if edge=='left' then r.x=math.max(r.x,fullFrame.x+gap)
  elseif edge=='right' then right=math.min(right,fullFrame.x+fullFrame.w-gap)
  else bottom=math.min(bottom,fullFrame.y+fullFrame.h-gap) end
  r.w=right-r.x;r.h=bottom-r.y
  return r
end

function M.frames(screen, count, options)
  local c=options or M.defaults
  local out={}
  local height=screen.h-(count-1)*c.titlebar
  if height<240 or screen.w<320 then return out end
  for i=1,count do
    out[i]={x=screen.x,y=screen.y+(i-1)*c.titlebar,w=screen.w,h=height}
  end
  return out
end

function M.region(bounds, unit)
  return {x=math.floor(bounds.x+bounds.w*unit[1]),y=math.floor(bounds.y+bounds.h*unit[2]),
    w=math.floor(bounds.w*unit[3]),h=math.floor(bounds.h*unit[4])}
end

function M.new(options)
  options = options or {}
  local self = {errors={}, aspectRatios={}, sizes={}}
  self.unit=hs.settings.get('remoteStack.unit') or {0,0,1,1}
  function self:screen()
    return hs.screen.find(hs.settings.get('remoteStack.screenUUID') or '') or hs.screen.primaryScreen()
  end
  function self:contains(win)
    local app=win and win:application()
    return app and M.isSession(app:bundleID(),win:title()) or false
  end
  function self:sessions()
    local windows={}
    for _,app in ipairs(hs.application.runningApplications()) do
      local bundle=app:bundleID()
      if bundle=='com.microsoft.rdc.macos' or bundle=='com.nomachine.nxdock' then
        for _,win in ipairs(app:allWindows()) do
          if win:isStandard() and self:contains(win) then windows[#windows+1]=win end
        end
      end
    end
    return windows
  end
  function self:focusedSession()
    local app=hs.application.frontmostApplication()
    if not app then return nil end
    for _,cg in ipairs(hs.window.list()) do
      if cg.kCGWindowOwnerPID==app:pid() and cg.kCGWindowLayer==0
          and cg.kCGWindowName and cg.kCGWindowName~='' then
        if M.isSession(app:bundleID(),cg.kCGWindowName) then
          for _,win in ipairs(self:sessions()) do if win:id()==cg.kCGWindowNumber then return win end end
        end
        return nil
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
    local attempts=0
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
            if win:isMinimized() then win:unminimize();pending=true;return end
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
      if pending and attempts<12 then
        self.restoreTimer=hs.timer.doAfter(.2,pass)
        return
      end
      -- Restore back-to-front order only after every client's frame has settled.
      for _,win in ipairs(targets) do win:raise() end
      for _,win in ipairs(targets) do if win:id()==saved.focused then win:focus();break end end
      local region,ids=nil,{}
      for _,item in ipairs(saved.windows) do
        if not item.minimized then
          local f=item.frame
          ids[item.id]=true
          if not region then region={x=f.x,y=f.y,w=f.w,h=f.h}
          else
            local right=math.max(region.x+region.w,f.x+f.w)
            local bottom=math.max(region.y+region.h,f.y+f.h)
            region.x=math.min(region.x,f.x);region.y=math.min(region.y,f.y)
            region.w=right-region.x;region.h=bottom-region.y
          end
        end
      end
      if region and not pending then
        local f=self:screen():frame()
        self.restoredPlacement={region=region,ids=ids,screen=self:screen():getUUID(),
          geometry=table.concat({f.x,f.y,f.w,f.h},':')}
      end
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
    local windows=self:sessions()
    if #windows==0 then self.hidden=false;return false end
    local focused=self:focusedSession()
    if focused then
      self.savedHidden=self:capture(windows,focused)
      self.hidden=true
      for _,win in ipairs(windows) do if not win:isMinimized() then win:minimize() end end
    else
      -- When bringing the visible group forward from another local app, keep
      -- its current positions instead of renegotiating its layout.
      local saved=self:capture(windows,nil)
      for _,item in ipairs(saved.windows) do item.minimized=false end
      saved.focused=saved.windows[#saved.windows].id
      self:restore(saved)
    end
    return true
  end
  function self:canHandle(action,win,layouts)
    if not self:contains(win) then return false end
    local kind,arg=action:match('^([^.]+)%.(.+)$')
    return kind=='screen' or (kind=='window' and
      ((layouts and layouts[arg])~=nil or arg=='max' or arg=='maximize' or arg=='fullscreen' or arg=='undo' or arg=='cycleTwoThirds' or arg=='cycleThirds' or arg=='up' or arg=='down'))
  end
  function self:place(unit,screen)
    self.restoredPlacement=nil
    local same=true
    for i=1,4 do if math.abs(unit[i]-self.unit[i])>.001 then same=false end end
    if same and (not screen or screen:getUUID()==self:screen():getUUID()) then self:apply();return end
    self.previous={unit=self.unit,screen=hs.settings.get('remoteStack.screenUUID')}
    self.unit=unit
    hs.settings.set('remoteStack.unit',unit)
    if screen then hs.settings.set('remoteStack.screenUUID',screen:getUUID()) end
    self:apply()
  end
  function self:undo()
    self.restoredPlacement=nil
    if not self.previous then return end
    local previous=self.previous
    self.previous={unit=self.unit,screen=hs.settings.get('remoteStack.screenUUID')}
    self.unit=previous.unit
    hs.settings.set('remoteStack.unit',self.unit)
    hs.settings.set('remoteStack.screenUUID',previous.screen)
    self:apply()
  end
  local function closeEnough(a,b)
    return math.abs(a.x-b.x)<1 and math.abs(a.y-b.y)<1
      and math.abs(a.w-b.w)<1 and math.abs(a.h-b.h)<1
  end
  function self:apply()
    if self.hidden or self.restoring then return end
    if options.suspended and options.suspended() then return end
    if hs.eventtap.checkMouseButtons().left then return end
    local groups, seen = {}, {}
    -- orderedWindows is front-to-back. Place the foremost session last/bottom
    -- so every other titlebar stays exposed when switching between sessions.
    local ordered = hs.window.list()
    local rank = {}
    for i,w in ipairs(ordered) do rank[w.kCGWindowNumber] = i end
    for _,app in ipairs(hs.application.runningApplications()) do
      local bundle = app:bundleID()
      if bundle == 'com.microsoft.rdc.macos' or bundle == 'com.nomachine.nxdock' then
        for _,w in ipairs(app:allWindows()) do
          if not seen[w:id()] and w:isStandard() and w:isVisible()
              and M.isSession(bundle,w:title()) then
            seen[w:id()] = true
            if w:isFullScreen() then
              w:setFullScreen(false)
            else
              local screen = self:screen()
              if screen then
                local id = screen:getUUID()
                groups[id] = groups[id] or {screen=screen,windows={}}
                table.insert(groups[id].windows,w)
                if bundle == 'com.nomachine.nxdock' and not self.aspectRatios[w:id()] then
                  local f=w:frame()
                  self.aspectRatios[w:id()] = f.w / math.max(1,f.h-M.defaults.titlebar)
                end
              end
            end
          end
        end
      end
    end
    self.errors = {}
    for _,group in pairs(groups) do
      table.sort(group.windows,function(a,b)
        local ar,br = rank[a:id()] or math.huge,rank[b:id()] or math.huge
        if ar == br then return a:id()<b:id() end
        return ar>br
      end)
      -- Move onto the destination before negotiating size, so mixed-size
      -- monitors cannot clamp the group's cached size to the previous display.
      for _,w in ipairs(group.windows) do
        local current=w:screen()
        if current and current:getUUID()~=group.screen:getUUID() then
          w:moveToScreen(group.screen,false,true,0)
        end
      end
      local dock=hs.plist.read(os.getenv('HOME')..'/Library/Preferences/com.apple.dock.plist') or {}
      local bounds=M.bounds(group.screen:frame(),group.screen:fullFrame(),dock,options.layout)
      local region=M.region(bounds,self.unit)
      local restored=self.restoredPlacement
      if restored then
        local sf=group.screen:frame()
        local valid=restored.screen==group.screen:getUUID()
          and restored.geometry==table.concat({sf.x,sf.y,sf.w,sf.h},':')
        local count=0;for _ in pairs(restored.ids) do count=count+1 end
        valid=valid and count==#group.windows
        for _,w in ipairs(group.windows) do if not restored.ids[w:id()] then valid=false end end
        if valid then region=restored.region else self.restoredPlacement=nil end
      end
      local frames = M.frames(region,#group.windows,options.layout)
      -- Negotiate NoMachine's constrained size once per screen/count. Reuse
      -- its accepted pixel-rounded dimensions for every session in the stack.
      if frames[1] then
        local f=frames[1]
        local key=table.concat({group.screen:getUUID(),f.x,f.y,f.w,f.h,#frames},':')
        local size=self.sizes[key]
        if not size then
          size={w=f.w,h=f.h}
          for _,w in ipairs(group.windows) do
            local ratio=self.aspectRatios[w:id()]
            if ratio then
              local width=math.min(f.w,math.floor((f.h-M.defaults.titlebar)*ratio))
              w:setFrame({x=f.x,y=f.y,w=width,h=f.h},0)
              local actual=w:frame()
              if actual.h>f.h then
                width=math.floor(width*(f.h-M.defaults.titlebar)/(actual.h-M.defaults.titlebar))-2
                w:setFrame({x=f.x,y=f.y,w=width,h=f.h},0)
                actual=w:frame()
              end
              size.w=math.min(size.w,actual.w)
              size.h=math.min(size.h,actual.h)
            end
          end
          self.sizes[key]=size
        end
        for _,frame in ipairs(frames) do
          frame.x=math.floor(frame.x+(frame.w-size.w)/2)
          frame.w=size.w;frame.h=size.h
        end
      end
      for i,w in ipairs(group.windows) do
        local frame = frames[i]
        if frame and not closeEnough(w:frame(),frame) then
          local current=w:frame()
          if current.w~=frame.w or current.h~=frame.h then w:setFrame(frame,0) end
          w:setTopLeft({x=frame.x,y=frame.y})
          if not closeEnough(w:frame(),frame) then
            self.errors[#self.errors+1] = {id=w:id(),title=w:title(),expected=frame,actual=w:frame()}
          end
        end
      end
      -- Propagate the final accepted client dimensions, including one-pixel
      -- backing-scale rounding, without resizing that client again on focus.
      for _,w in ipairs(group.windows) do
        if self.aspectRatios[w:id()] then
          local a=w:frame()
          for i,other in ipairs(group.windows) do
            local b=other:frame()
            if other:id()~=w:id() and (b.w~=a.w or b.h~=a.h) then other:setFrame({x=b.x,y=b.y,w=a.w,h=a.h},0) end
          end
          for _,size in pairs(self.sizes) do
            if math.abs(size.w-a.w)<=2 and math.abs(size.h-a.h)<=2 then size.w=a.w;size.h=a.h end
          end
        end
      end
    end
  end
  local function reconcile()
    local ok,err = pcall(function()self:apply()end)
    if not ok then hs.printf('[remote-window-stack] %s',tostring(err)) end
  end
  -- Polling also catches NoMachine child processes and missing AX lifecycle
  -- events. Frame equality prevents a resize loop and resolution churn.
  self.timer = hs.timer.doEvery(2,reconcile)
  self.screenWatcher = hs.screen.watcher.new(reconcile):start()
  function self:stop()
    if self.restoreTimer then self.restoreTimer:stop() end
    self.timer:stop()
    self.screenWatcher:stop()
  end
  reconcile()
  return self
end
return M

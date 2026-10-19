-- Keep remote sessions in a windowed cascade, independent of client frame memory.
local M = {}
M.defaults = {titlebar=28, dockTrigger=2}

local windowGroup = require('private/modules/window-group')
local groups = require('private/modules/window-groups')

function M.isSession(bundle, title)
  for _,rule in ipairs(groups.remote.apps) do
    if windowGroup.matches(rule,bundle,title) then return true end
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
  local self = windowGroup.new(options.group or groups.remote,options)
  self.errors,self.aspectRatios,self.sizes={},{},{}
  self.unit=hs.settings.get('remoteStack.unit') or {0,0,1,1}
  function self:screen()
    return hs.screen.find(hs.settings.get('remoteStack.screenUUID') or '') or hs.screen.primaryScreen()
  end
  function self:canHandle(action,win,layouts)
    if not self:contains(win) then return false end
    local kind,arg=action:match('^([^.]+)%.(.+)$')
    return kind=='screen' or (kind=='window' and
      ((layouts and layouts[arg])~=nil or arg=='max' or arg=='maximize' or arg=='fullscreen' or arg=='undo' or arg=='cycleTwoThirds' or arg=='cycleThirds' or arg=='up' or arg=='down'))
  end
  function self:place(unit,screen)
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
  function self:orderWindows(windows,focused)
    local slots=self.stackSlots or {}
    table.sort(windows,function(a,b)
      if a:id()==focused then return false end
      if b:id()==focused then return true end
      local ar,br=slots[a:id()] or math.huge,slots[b:id()] or math.huge
      if ar==br then return a:id()<b:id() end
      return ar<br
    end)
    self.stackSlots={}
    for i,win in ipairs(windows) do self.stackSlots[win:id()]=i end
  end
  function self:framesFor(windows,screen,negotiate)
    local dock=hs.plist.read(os.getenv('HOME')..'/Library/Preferences/com.apple.dock.plist') or {}
    local bounds=M.bounds(screen:frame(),screen:fullFrame(),dock,options.layout)
    local region=M.region(bounds,self.unit)
    local frames = M.frames(region,#windows,options.layout)
    -- Negotiate NoMachine's constrained size once per screen/count. Reuse
    -- its accepted pixel-rounded dimensions for every session in the stack.
    if frames[1] then
      local f=frames[1]
      local key=table.concat({screen:getUUID(),f.x,f.y,f.w,f.h,#frames},':')
      local size=self.sizes[key]
      if not size then
        size={w=f.w,h=f.h}
        for _,w in ipairs(windows) do
          local ratio=self.aspectRatios[w:id()]
          if ratio then
            local width=math.min(f.w,math.floor((f.h-M.defaults.titlebar)*ratio))
            if not negotiate then
              size.w=math.min(size.w,width)
            else
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
        end
        self.sizes[key]=size
      end
      for _,frame in ipairs(frames) do
        frame.x=math.floor(frame.x+(frame.w-size.w)/2)
        frame.w=size.w;frame.h=size.h
      end
    end
    return frames
  end
  function self:prepareRestore(saved)
    local windows,items={},{}
    for _,item in ipairs(saved.windows) do
      local ok,valid=pcall(function()
        return item.window:id()==item.id and item.window:application():pid()==item.pid
      end)
      if ok and valid and not item.minimized then
        windows[#windows+1]=item.window;items[item.id]=item
      end
    end
    self:orderWindows(windows,saved.focused)
    local frames=self:framesFor(windows,self:screen(),false)
    local ordered={}
    for i,win in ipairs(windows) do
      local item=items[win:id()]
      if frames[i] then item.frame=frames[i] end
      ordered[#ordered+1]=item
    end
    -- Retain pre-minimized/closed entries for reporting, but never show them.
    for _,item in ipairs(saved.windows) do
      if not items[item.id] then ordered[#ordered+1]=item end
    end
    saved.windows=ordered
  end
  function self:apply()
    if self.hidden or self.restoring then return end
    if options.suspended and options.suspended() then return end
    if hs.eventtap.checkMouseButtons().left then return end
    local groups, seen = {}, {}
    -- Preserve logical slots across temporary CG order changes during show.
    -- Only an explicitly focused member moves to the bottom of the cascade.
    local ordered = hs.window.list()
    for _,w in ipairs(self:members()) do
      if not seen[w:id()] and w:isVisible() and not w:isMinimized() then
        seen[w:id()]=true
        if w:isFullScreen() then
          w:setFullScreen(false)
        else
          local screen=self:screen()
          if screen then
            local id=screen:getUUID()
            groups[id]=groups[id] or {screen=screen,windows={}}
            table.insert(groups[id].windows,w)
            local rule=self:rule(w)
            if rule.keepAspectRatio and not self.aspectRatios[w:id()] then
              local f=w:frame()
              self.aspectRatios[w:id()]=f.w/math.max(1,f.h-M.defaults.titlebar)
            end
          end
        end
      end
    end
    self.errors = {}
    for _,group in pairs(groups) do
      local focused=self:focusedWindow()
      self:orderWindows(group.windows,focused and focused:id())
      self:raiseActiveGroup(group.windows,ordered)
      -- Move onto the destination before negotiating size, so mixed-size
      -- monitors cannot clamp the group's cached size to the previous display.
      for _,w in ipairs(group.windows) do
        local current=w:screen()
        if current and current:getUUID()~=group.screen:getUUID() then
          w:moveToScreen(group.screen,false,true,0)
        end
      end
      local frames=self:framesFor(group.windows,group.screen,true)
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
  return self:start()
end
return M

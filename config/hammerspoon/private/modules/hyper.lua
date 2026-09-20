-- Shared Hyper action adapter. Owns every Hyper chord, including window actions.
local M = {}
local defaults = require 'private/modules/hyper-generated'
local paletteModule = require 'private/modules/hyper-rust-palette'
local appsModule = require 'private/modules/hyper-apps'
local rolesModule = require 'private/modules/hyper-roles'
local i18n = require 'private/modules/hyper-i18n'
local t=i18n.t
local function copy(v) return hs.json.decode(hs.json.encode(v)) end
M.actionTitle=t

function M.appTarget(spec,installed)
  -- Prefer the configured bundle; use the discovered identity when a locally
  -- installed app has the expected name but a different bundle identifier.
  local named
  for _,app in ipairs(installed) do
    if app.bundle==spec.mac then return spec.mac end
    if app.title:lower()==spec.title:lower() then named=named or app.bundle end
  end
  return named and named~='' and named or spec.mac
end

function M.rebaseFrame(frame,source,destination)
  return hs.geometry.rect(destination.x+(frame.x-source.x)/source.w*destination.w,
    destination.y+(frame.y-source.y)/source.h*destination.h,
    frame.w/source.w*destination.w,frame.h/source.h*destination.h)
end

function M.sameFrame(a,b)
  return a and b and math.abs(a.x-b.x)<3 and math.abs(a.y-b.y)<3
    and math.abs(a.w-b.w)<3 and math.abs(a.h-b.h)<3
end

function M.layout(data,name,area)
  local r=data.layouts[name]
  if area.h>area.w and data.adaptiveLayouts[name] then return {r[2],r[1],r[4],r[3]} end
  return r
end

function M.cycleLayout(data,name,frame,area)
  local cycle=data.layoutCycles[name]
  for i,layout in ipairs(cycle) do
    local r=M.layout(data,layout,area)
    local target={x=area.x+area.w*r[1],y=area.y+area.h*r[2],w=area.w*r[3],h=area.h*r[4]}
    if M.sameFrame(frame,target) then return cycle[i % #cycle+1] end
  end
  return cycle[1]
end

function M.new(options)
  local self = {keys={}, history={}, maximized={}, snapped={}, managed={}, minimized={}, screenMoves={}, placements={}, options=options or {}}
  self.palette=paletteModule.new()
  self.apps=appsModule.new()
  local data = copy(defaults)
  local overrides = hs.settings.get('hyper.apps') or {}
  for id, app in pairs(overrides) do data.apps[id] = app end
  self.roles=rolesModule.new(data,self.apps)
  local function alert(s) hs.alert.show(t(s), 2) end
  local function window() return self.target or hs.window.focusedWindow() end
  local function setFrame(win, frame)
    if not win or not win:isStandard() then alert('No standard window'); return end
    if win:isFullScreen() then alert('Exit system fullscreen first'); return end
    if M.sameFrame(win:frame(),frame) then return end
    self.history[win:id()] = win:frame()
    win:setFrame(frame, 0)
    self.managed[win:id()]=win:frame()
  end
  local function toggleApp(id)
    local spec = data.apps[id]
    local target = spec and spec.mac and M.appTarget(spec,self.apps.apps)
    if not target then alert(t('error.unavailable',{name=id})); return end
    local apps = hs.application.applicationsForBundleID(target)
    local app = apps and apps[1] or hs.application.find(target, true)
    local win=app and app:mainWindow()
    if app and win and app:isFrontmost() then app:hide()
    elseif app and win then
      app:unhide(); app:activate(true); win:focus()
    elseif app then
      -- Use the running app's actual path. A bundle ID or display name can
      -- activate a windowless process without sending its reopen request.
      local path=app:path()
      local opened=path and hs.application.launchOrFocus(path)
      if not opened then opened=hs.application.launchOrFocus(spec.title) end
      if not opened then alert(t('error.launch',{name=spec.title})) end
    elseif not hs.application.launchOrFocusByBundleID(target) then
      if not hs.application.launchOrFocus(target) then alert(t('error.launch',{name=spec.title})) end
    end
  end
  local function screenInDirection(screen, direction)
    local screens=hs.screen.allScreens()
    if #screens<2 then return nil end
    local a=screen:frame()
    local function find(dir,wrap)
      local best,score,secondary
      for _,candidate in ipairs(screens) do
        local b=candidate:frame()
        local dx=b.x+b.w/2-a.x-a.w/2;local dy=b.y+b.h/2-a.y-a.h/2
        local horizontal=dir=='left' or dir=='right'
        local primary=horizontal and math.abs(dx) or math.abs(dy)
        local perpendicular=horizontal and math.abs(dy) or math.abs(dx)
        local valid=(dir=='left' and dx<0) or (dir=='right' and dx>0) or (dir=='up' and dy<0) or (dir=='down' and dy>0)
        local rank=wrap and -primary or dx*dx+dy*dy
        if candidate~=screen and valid and primary>=perpendicular and
          (not score or rank<score or (rank==score and perpendicular<secondary)) then
          best=candidate;score=rank;secondary=perpendicular
        end
      end
      return best
    end
    local opposite={left='right',right='left',up='down',down='up'}
    local other={left='up',right='down',up='left',down='right'}
    local result=find(direction,false) or find(opposite[direction],true)
      or find(other[direction],false) or find(opposite[other[direction]],true)
    if result then return result end
    for _,candidate in ipairs(screens) do if candidate~=screen then return candidate end end
  end
  local function showChoices(choices,title,options,callback)
    options=options or {}
    for _,choice in ipairs(choices) do
      choice.keywords=(choice.keywords or '')..' '..i18n.keywords(choice.action)
      local kind=choice.action and choice.action:match('^([^.]+)%.')
      choice.navigate=kind=='menu' or kind=='role' or kind=='mode'
        or choice.action=='clipboard.history' or choice.action=='clipboard.targets'
        or choice.action=='clipboard.enableHistory'
        or choice.action=='system.audioOutput' or choice.action=='system.audioInput'
    end
    local target=self.target or hs.window.focusedWindow()
    self.target=target
    self.palette:show(choices,{title=title,target=target,quick=options.quick,continuous=options.continuous,
      onClose=function()self.target=nil;self.mode=nil end},function(choice)
      self.target=target
      if callback then callback(choice) else self:run(choice.action) end
      if not self.palette.visible then self.target=nil end
    end)
  end
  local function modal(title, items, continuous)
    local choices={}
    for _,item in ipairs(items) do
      choices[#choices+1]={text=t(item[3]),shortcut=item[1],action=item[3]}
    end
    showChoices(choices,title,{quick=true,continuous=continuous})
    if continuous then self.mode={continuous=true} end
    self.cancelMode=function()self.palette:close()end
  end
  local function menu(name)
    if name=='roles' then showChoices(self.roles:rows(),t('menu.roles'));return end
    if name=='config' then
      local rows=copy(data.menus.config)
      rows[#rows+1]={'b','Sync Alfred blacklist','clipboard.syncBlacklist'}
      modal(t('menu.config'),rows)
      return
    end
    if data.menus[name] then modal(t('menu.'..name),data.menus[name]);return end
    local choices={}
    if name=='windows' then
      for _,win in ipairs(hs.window.orderedWindows()) do
        if win:isStandard() then choices[#choices+1]={text=win:title(),subText=win:application():name(),action='winid.'..win:id()} end
      end
    elseif name=='apps' then
      choices=self.apps:choices()
    elseif name=='all' or name=='help' then
      for _,b in ipairs(data.bindings) do
        if b.action~='menu.all' and b.action~='menu.help' then
          local role=b.action:match('^app%.(.+)$')
          local appTitle=role and self.roles:title(self.roles:get(role)) or ''
          choices[#choices+1]={text=M.actionTitle(b.action),subText='H+'..(b.shift and 'Shift+' or '')..b.key..(role and ' · '..appTitle or ''),action=b.action,keywords=appTitle}
        end
      end
      if name=='all' then
        local roles={}
        for role in pairs(data.roles) do roles[#roles+1]=role end
        table.sort(roles)
        for _,role in ipairs(roles) do
          if self.roles:keys(role)=='' then
            local appTitle=self.roles:title(self.roles:get(role))
            choices[#choices+1]={text=M.actionTitle('app.'..role),subText=appTitle,action='app.'..role,keywords=appTitle}
          end
        end
        for _,choice in ipairs(self.apps:choices()) do choices[#choices+1]=choice end
      end
    end
    showChoices(choices,t('menu.'..name))
  end
  function self:run(action)
    local kind,arg=action:match('^([^.]+)%.(.+)$')
    if kind=='window' and arg=='up' then
      while #self.minimized>0 do
        local minimized=table.remove(self.minimized)
        local ok,hidden=pcall(function()return minimized:isMinimized()end)
        if ok and hidden then minimized:unminimize();minimized:focus();return end
      end
    end
    -- Pointer movement must not wait for an application's Accessibility reply.
    local win=kind~='mouse' and window() or nil
    if kind=='app' then
      local choice=self.roles:get(arg)
      if choice:match('^installed%.') then self:run(choice) else toggleApp(choice) end
    elseif kind=='role' then
      if not data.roles[arg] then alert(t('error.role',{name=arg}));return end
      showChoices(self.roles:choices(arg),t('menu.roleApps')..' · '..t('role.'..arg))
    elseif kind=='setrole' or kind=='resetrole' then
      local role,choice=arg:match('^([^.]+)%.(.+)$')
      if kind=='resetrole' then
        role=arg
        if not data.roles[role] then alert(t('error.role',{name=role}));return end
        choice=self.roles:default(role)
      end
      local _,message=self.roles:set(role,choice);alert(message)
    elseif kind=='launch' then toggleApp(arg)
    elseif kind=='installed' then
      if not hs.fs.attributes(arg) then self.apps:refresh();alert('Application no longer installed');return end
      local info=hs.application.infoForBundlePath(arg)
      local apps=info and info.CFBundleIdentifier and hs.application.applicationsForBundleID(info.CFBundleIdentifier)
      local app=apps and apps[1]
      if app and app:mainWindow() and app:isFrontmost() then app:hide()
      elseif not hs.application.launchOrFocus(arg) then alert(t('error.launch',{name=arg})) end
    elseif kind=='menu' then menu(arg)
    elseif kind=='edit' or kind=='select' then
      local keys={left='left',right='right',up='up',down='down',home='left', ['end']='right',pageup='pageup',pagedown='pagedown'}
      local mods=kind=='select' and {'shift'} or {}
      local app=hs.application.frontmostApplication()
      local bundle=app and app:bundleID() or ''
      local terminal=bundle:find('kitty',1,true) or bundle:find('alacritty',1,true)
        or bundle:find('iterm',1,true) or bundle=='com.apple.Terminal'
      if arg=='home' or arg=='end' then
        if terminal then keys[arg]=arg=='home' and 'home' or 'end' else mods[#mods+1]='cmd' end
      end
      hs.eventtap.keyStroke(mods,keys[arg],0)
    elseif kind=='window' and arg=='previous' then
      local ordered=hs.window.orderedWindows()
      for _,other in ipairs(ordered) do
        if other~=win and other:isStandard() then other:focus();break end
      end
    elseif kind=='winid' then local other=hs.window.get(tonumber(arg));if other then other:focus() end
    elseif kind=='window' and win then
      if not win:isStandard() then alert('No standard window');return end
      if win:isFullScreen() and arg~='fullscreen' then alert('Exit system fullscreen first');return end
      local id=win:id()
      -- Dragging/resizing outside Hyper starts a new normal-window state.
      if self.managed[id] and not M.sameFrame(self.managed[id],win:frame()) then
        self.maximized[id]=nil;self.snapped[id]=nil;self.managed[id]=nil
      end
      if data.layoutCycles[arg] then arg=M.cycleLayout(data,arg,win:frame(),win:screen():frame()) end
      if arg=='up' or arg=='down' then
        local nextAction
        local f=win:screen():frame()
        for name,result in pairs(f.w>=f.h and data.windowTransitions[arg] or {}) do
          local r=data.layouts[name]
          if M.sameFrame(win:frame(),hs.geometry.rect(f.x+f.w*r[1],f.y+f.h*r[2],f.w*r[3],f.h*r[4])) then nextAction=result;break end
        end
        arg=nextAction or (arg=='up' and 'maximize' or 'restoreDown')
      end
      if arg=='undo' then
        local frame=self.history[win:id()]
        if frame then
          self.history[id]=nil;self.maximized[id]=nil;self.snapped[id]=nil;self.managed[id]=nil
          win:setFrame(frame,0)
        end
      elseif arg=='restoreDown' then
        local old=self.maximized[id] or self.snapped[id]
        if old then
          if self.maximized[id] then self.maximized[id]=nil else self.snapped[id]=nil end
          setFrame(win,old)
        elseif M.sameFrame(win:frame(),win:screen():frame()) then
          -- Native maximize before Hyper has no saved normal geometry.
          local f=win:screen():frame()
          setFrame(win,hs.geometry.rect(f.x+f.w*.1,f.y+f.h*.1,f.w*.8,f.h*.8))
        else win:minimize();self.minimized[#self.minimized+1]=win end
      elseif arg=='max' or arg=='maximize' then
        local old=self.maximized[win:id()]
        if arg=='max' and old then setFrame(win,old);self.maximized[id]=nil
        elseif not M.sameFrame(win:frame(),win:screen():frame()) then
          self.maximized[id]=win:frame();setFrame(win,win:screen():frame())
        end
      elseif arg=='fullscreen' then win:toggleFullScreen()
      elseif arg=='center' then
        self.maximized[id]=nil;self.snapped[id]=nil;self.managed[id]=nil
        self.history[win:id()]=win:frame();win:centerOnScreen(nil,false,0)
      elseif data.layouts[arg] then
        local f=win:screen():frame();local r=M.layout(data,arg,f)
        self.snapped[id]=self.snapped[id] or self.maximized[id] or win:frame()
        self.maximized[win:id()]=nil
        setFrame(win,hs.geometry.rect(f.x+f.w*r[1],f.y+f.h*r[2],f.w*r[3],f.h*r[4]))
      end
    elseif kind=='screen' and win then
      if self.screenMoves[win:id()] or self.placements[win:id()] then return end
      local nextScreen=screenInDirection(win:screen(),arg)
      if nextScreen then
        local id=win:id();local source=win:screen():frame();local destination=nextScreen:frame()
        local nativeFullscreen=win:isFullScreen()
        -- Keep the semantic state when macOS clamps the requested frame to the
        -- previous display's size. An external resize still invalidates it.
        local maximized=M.sameFrame(win:frame(),source) or
          (self.maximized[id]~=nil and M.sameFrame(self.managed[id],win:frame()))
        local hadHistory=self.history[id]~=nil
        self.history[id]=M.rebaseFrame(self.history[id] or win:frame(),source,destination)
        if self.maximized[id] then self.maximized[id]=M.rebaseFrame(self.maximized[id],source,destination) end
        if self.snapped[id] then self.snapped[id]=M.rebaseFrame(self.snapped[id],source,destination) end
        if self.resizeOrigin then self.resizeOrigin=M.rebaseFrame(self.resizeOrigin,source,destination) end
        local target
        local attempts=0
        local function move()
          -- Apply the intended target explicitly: screen conversion/bounds
          -- clamping can otherwise shrink a maximized window on mixed displays.
          target=target or (maximized and destination or M.rebaseFrame(win:frame(),source,destination))
          -- iTerm processes AX size/position changes asynchronously. Resizing
          -- before crossing displays can snap it back to the source display.
          -- Move first; resize only after the app has processed that move.
          if self.placements[id] then return end
          attempts=attempts+1
          win:setTopLeft({x=target.x,y=target.y})
          self.placements[id]=hs.timer.doAfter(0.2,function()
            if not win:id() then self.placements[id]=nil;return end
            win:setFrame(target,0)
            self.placements[id]=hs.timer.doAfter(0.1,function()
              self.placements[id]=nil
              if not win:id() then return end
              -- Some apps apply an older AX request after the newer one.
              -- Verify the result, not just the setter's return value.
              if attempts<4 and (win:screen()~=nextScreen or not M.sameFrame(win:frame(),target)) then
                move();return
              end
              self.managed[id]=win:frame()
            end)
          end)
        end
        if not nativeFullscreen then move()
        else
          -- AX fullscreen transitions are asynchronous. Never set geometry while
          -- the window still belongs to its fullscreen Space.
          local ticks,settled,phase=0,0,'exit'
          win:setFullScreen(false)
          self.screenMoves[id]=hs.timer.doEvery(0.1,function()
            if not self.screenMoves[id] then return end
            ticks=ticks+1
            if not win:id() or ticks>80 then
              self.screenMoves[id]:stop();self.screenMoves[id]=nil
              if win:id() then win:setFullScreen(true) end
              return
            end
            if phase=='exit' then
              if win:isFullScreen() then settled=0;return end
              settled=settled+1
              if settled<4 then return end
              -- Preserve the normal placement revealed by leaving fullscreen.
              maximized=M.sameFrame(win:frame(),source)
              if not hadHistory then self.history[id]=M.rebaseFrame(win:frame(),source,destination) end
              move();phase='move';settled=0
            else
              if self.placements[id] then return end
              if win:screen()~=nextScreen then move();settled=0;return end
              settled=settled+1
              if settled<4 then return end
              win:setFullScreen(true)
              self.screenMoves[id]:stop();self.screenMoves[id]=nil
            end
          end)
        end
      else alert('Only one screen detected') end
    elseif kind=='focus' and win then
      local methods={left='focusWindowWest',right='focusWindowEast',up='focusWindowNorth',down='focusWindowSouth'}
      win[methods[arg]](win)
    elseif kind=='desktop' then
      -- Deliberately do not depend on experimental Spaces mutation APIs.
      alert('error.macDesktop')
      hs.spaces.openMissionControl()
    elseif kind=='mode' then
      if arg=='resize' and win then self.resizeOrigin=win:frame() end
      local items={}
      for _,entry in ipairs({{'h','left'},{'j','down'},{'k','up'},{'l','right'}}) do
        items[#items+1]={entry[1],entry[2],arg..'.'..entry[2]}
        items[#items+1]={'S-'..entry[1],'fast '..entry[2],arg..'.fast-'..entry[2]}
      end
      if arg=='mouse' then
        for _,entry in ipairs({{'return','Click','mouse.click'},{'delete','Right click','mouse.rightclick'},{'u','Scroll up','mouse.scrollup'},{'o','Scroll down','mouse.scrolldown'}}) do items[#items+1]=entry end
      end
      modal(t('mode.'..arg),items,true)
    elseif kind=='mouse' then
      local point=hs.mouse.absolutePosition();local distance=arg:find('fast-',1,true) and 40 or 10
      if arg=='click' then hs.eventtap.leftClick(point)
      elseif arg=='rightclick' then hs.eventtap.rightClick(point)
      elseif arg=='scrollup' or arg=='scrolldown' then hs.eventtap.scrollWheel({0,arg=='scrollup' and 3 or -3},{},'line')
      else
        if arg:find('left',1,true) then point.x=point.x-distance elseif arg:find('right',1,true) then point.x=point.x+distance
        elseif arg:find('up',1,true) then point.y=point.y-distance else point.y=point.y+distance end
        hs.mouse.absolutePosition(point)
      end
    elseif kind=='resize' and win then
      local frame=win:frame();local step=arg:find('fast-',1,true) and 50 or 10
      if arg:find('left',1,true) then frame.w=math.max(100,frame.w-step)
      elseif arg:find('right',1,true) then frame.w=frame.w+step
      elseif arg:find('up',1,true) then frame.h=math.max(100,frame.h-step) else frame.h=frame.h+step end
      -- Keep the entry frame as the undo target throughout a resize mode.
      setFrame(win,frame)
      if self.resizeOrigin then self.history[win:id()]=self.resizeOrigin end
    elseif kind=='capture' then hs.eventtap.keyStroke({'cmd','shift'},arg=='record' and '5' or '4',0)
    elseif kind=='clipboard' then
      if arg=='targets' and self.options.clipboard then
        local status=self.options.clipboard.status();local choices={}
        for _,target in ipairs(status.targets) do
          choices[#choices+1]={text=target.nodeId,subText=target.ready and t('ui.syncTarget') or self.options.clipboard.reason(target.reason),
            valid=target.ready,action='clipboardtarget.'..target.nodeId}
        end
        showChoices(choices,t('ui.syncTarget'))
      elseif arg=='send' and self.options.clipboard then self.options.clipboard.push(self.options.clipboard.status().selected)
      elseif arg=='history' then
        local items={}
        if not hs.settings.get('hyper.clipboardHistory') then
          showChoices({{text=t('clipboard.enableHistory'),subText=t('ui.clipboardConsent'),action='clipboard.enableHistory'}},t('clipboard.history'))
          return
        end
        for _,value in ipairs(self.clips or {}) do items[#items+1]={text=value:sub(1,100),subText=t('ui.textClipboard')} end
        -- Separate chooser callback keeps clipboard text out of action IDs.
        local values=copy(self.clips or {})
        for i,item in ipairs(items) do item.index=i;item.action=nil end
        showChoices(items,t('ui.clipboardSearch'),nil,function(choice)hs.pasteboard.setContents(values[choice.index])end)
      elseif arg=='syncBlacklist' then
        alert(self.clipboardPolicy:sync() and 'ui.blacklistSynced' or 'error.blacklistSync')
      elseif arg=='enableHistory' then
        hs.settings.set('hyper.clipboardHistory',true);self:run('clipboard.history')
      else alert('Clipboard sync is unavailable') end
    elseif kind=='clipboardtarget' and self.options.clipboard then self.options.clipboard.selectTarget(arg)
    elseif kind=='system' then
      if arg=='lock' then hs.caffeinate.lockScreen()
      elseif arg=='audioOutput' or arg=='audioInput' then
        local input=arg=='audioInput'
        local devices=input and hs.audiodevice.allInputDevices() or hs.audiodevice.allOutputDevices()
        local current=input and hs.audiodevice.defaultInputDevice() or hs.audiodevice.defaultOutputDevice()
        local rows={}
        for _,device in ipairs(devices) do
          rows[#rows+1]={text=device:name(),subText=current and current:uid()==device:uid() and t('ui.currentDevice') or '',uid=device:uid()}
        end
        showChoices(rows,t('system.'..arg),nil,function(choice)
          local device=input and hs.audiodevice.findInputByUID(choice.uid) or hs.audiodevice.findOutputByUID(choice.uid)
          if not device then alert('error.audioDevice');return end
          local ok
          if input then ok=device:setDefaultInputDevice() else ok=device:setDefaultOutputDevice() end
          if not ok then alert('error.audioDevice') end
        end)
      elseif arg=='displays' or arg=='focus' then
        local pane=arg=='displays' and 'com.apple.Displays-Settings.extension' or 'com.apple.Focus-Settings.extension'
        if not hs.urlevent.openURLWithBundle('x-apple.systempreferences:'..pane,'com.apple.systempreferences') then
          hs.application.launchOrFocusByBundleID('com.apple.systempreferences')
        end
      elseif arg=='hyperKeys' then
        local config=os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME')..'/.config'
        hs.task.new('/usr/bin/open',nil,{'-t',config..'/dotfiles/config/hyper/keys.json'}):start()
      elseif arg=='settings' then hs.application.launchOrFocusByBundleID('com.apple.systempreferences')
      elseif arg=='activity' then hs.application.launchOrFocus('Activity Monitor')
      elseif arg=='launcher' then hs.eventtap.keyStroke({'cmd'},'space',0)
      elseif arg=='reload' then hs.reload()
      elseif arg=='power' then
        local choice=hs.dialog.blockAlert(t('ui.power'),t('ui.chooseAction'),t('ui.sleep'),t('ui.cancel'))
        if choice==t('ui.sleep') then hs.caffeinate.systemSleep() end
      end
    elseif kind=='remote' then
      if arg=='compatibility' and self.options.remote then self.options.remote.toggleCompatibility()
      elseif arg=='escape' and self.options.remote and self.options.remote.isFocused() then
        local app=hs.application.frontmostApplication();if app then app:hide() end
      end
    end
  end
  self.clipboardPolicy=require('private/modules/hyper-clipboard-policy').new()
  self.clips={};local change=hs.pasteboard.changeCount()
  local function collectClipboard(origin)
    local now=hs.pasteboard.changeCount()
    if now==change then return end
    change=now
    -- Memory-only and opt-in: never collect clipboard history by default.
    if not hs.settings.get('hyper.clipboardHistory') then return end
    local types=hs.pasteboard.contentTypes()
    if self.clipboardPolicy:blocked(origin or hs.application.frontmostApplication(),types) then return end
    local value=hs.pasteboard.getContents()
    if value and #value<=65536 and self.clips[1]~=value then
      table.insert(self.clips,1,value);if #self.clips>50 then table.remove(self.clips) end
    end
  end
  self.clipTimer=hs.timer.doEvery(0.2,collectClipboard)
  -- Observe the outgoing application before a quick Cmd-Tab can make a
  -- password-manager copy appear to originate in the next foreground app.
  self.clipWatcher=hs.application.watcher.new(function(_,event,app)
    if event==hs.application.watcher.deactivated or event==hs.application.watcher.activated then
      collectClipboard(app)
    end
  end):start()
  for _,binding in ipairs(data.bindings) do
    local b=binding;local mods={'ctrl','alt','cmd'}
    if b.shift then mods[#mods+1]='shift' end
    local function fire()
      if self.palette.visible then
        if b.action=='menu.roles' then self:run(b.action)
        elseif b.action:match('^mouse%.') then self:run(b.action)
        elseif b.action:match('^edit%.') or b.action:match('^select%.') then self.palette:navigate(b.action)
        elseif b.key=='return' then self.palette:navigate('accept')
        elseif b.key=='escape' or b.key=='space' then self.palette:close() end
        return
      end
      if b.action~='remote.escape' and self.options.remote and self.options.remote.isFocused() then return end
      local ok,err=pcall(function()self:run(b.action)end)
      if not ok then alert('Hyper: '..tostring(err)) end
    end
    local input=b.action:match('^edit%.') or b.action:match('^select%.') or b.action:match('^mouse%.')
    -- Menus open on release so held modifiers do not select menu shortcuts.
    if input then
      self.keys[#self.keys+1]=hs.hotkey.bind(mods,b.key,fire,nil,fire)
    else
      self.keys[#self.keys+1]=hs.hotkey.bind(mods,b.key,nil,fire)
    end
  end
  -- Disabled bindings allow remote clients to receive the original chord.
  self.remoteTimer=hs.timer.doEvery(.2,function()
    local focused=self.options.remote and self.options.remote.isFocused()
    if focused==self.remoteFocused then return end
    self.remoteFocused=focused
    for i,b in ipairs(data.bindings) do
      if b.action~='remote.escape' then
        if focused then self.keys[i]:disable() else self.keys[i]:enable() end
      end
    end
  end)
  function self:stop()
    self.clipWatcher:stop()
    for _,timer in pairs(self.placements) do timer:stop() end
    for _,timer in pairs(self.screenMoves) do timer:stop() end
    if self.mode then self.cancelMode() end
    self.palette:stop()
    self.apps:stop()
    for _,key in ipairs(self.keys) do key:delete() end
    self.clipTimer:stop()
    self.remoteTimer:stop()
  end
  return self
end
return M

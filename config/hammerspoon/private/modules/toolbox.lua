-- One searchable entry point. Choices contain IDs only, never callbacks/userdata.
local i18n = require('private/modules/hyper-i18n')
local t = i18n.t
local M = {}
local featureKey = 'workbench.toolbox.features'
function M.features()
  local saved = hs.settings.get(featureKey) or {}
  return {windows=saved.windows~=false, clipboard=saved.clipboard~=false,
    workbench=saved.workbench~=false}
end
function M.new(options)
  local self = {options=options or {}, history={}}
  local features = M.features()
  local clipboard = self.options.clipboard
  local registry = {}
  local function alert(text) hs.alert.show(text, 3) end
  local function originalWindow()
    return self.windowId and hs.window.get(self.windowId)
  end
  local function remember(win)
    self.history[win:id()] = win:frame()
  end
  local function position(rect)
    local win = originalWindow()
    if not win then alert(t('error.originalWindow')); return end
    if self.options.remoteStack and self.options.remoteStack:contains(win) then self.options.remoteStack:place(rect);return end
    if win:isFullScreen() then alert(t('Exit system fullscreen first')); return end
    remember(win)
    local frame = win:screen():frame()
    win:setFrame({x=frame.x+frame.w*rect[1], y=frame.y+frame.h*rect[2],
      w=frame.w*rect[3], h=frame.h*rect[4]}, 0)
  end
  local function register(id, label, run)
    registry[#registry+1] = {id=id, group=t('ui.windowGroup'), title=t(label or id), detail=i18n.keywords(label or id), run=run}
  end
  if features.windows then
    register('window.left',nil,function()position({0,0,.5,1})end)
    register('window.right',nil,function()position({.5,0,.5,1})end)
    register('window.top',nil,function()position({0,0,1,.5})end)
    register('window.bottom',nil,function()position({0,.5,1,.5})end)
    register('window.twoThirds',nil,function()position({0,0,2/3,1})end)
    register('window.lastThird',nil,function()position({2/3,0,1/3,1})end)
    register('window.max',nil,function()position({0,0,1,1})end)
    register('window.center',nil,function()
      local win=originalWindow(); if not win then alert(t('error.originalWindow')); return end
      remember(win); win:centerOnScreen(nil, false, 0)
    end)
    register('window.next','window.nextScreen',function()
      local win=originalWindow(); if not win then alert(t('error.originalWindow')); return end
      local group=self.options.remoteStack
      if group and group:contains(win) then group:place(group.unit,group:screen():next());return end
      local nextScreen=win:screen():next()
      if nextScreen == win:screen() then alert(t('Only one screen detected')); return end
      remember(win); win:moveToScreen(nextScreen, false, true, 0)
    end)
    register('window.previous','window.previousScreen',function()
      local win=originalWindow(); if not win then alert(t('error.originalWindow')); return end
      local group=self.options.remoteStack
      if group and group:contains(win) then group:place(group.unit,group:screen():previous());return end
      local previous=win:screen():previous()
      if previous == win:screen() then alert(t('Only one screen detected')); return end
      remember(win); win:moveToScreen(previous, false, true, 0)
    end)
    register('window.undo',nil,function()
      local win=originalWindow(); local frame=win and self.history[win:id()]
      if not frame then alert(t('error.noUndo')); return end
      self.history[win:id()]=nil; win:setFrame(frame,0)
    end)
  end
  self.registry=registry
  function self:runWindowAction(id)
    if self.stopped or self.menuOpen then return end
    local win=hs.window.focusedWindow()
    self.windowId=win and win:id()
    for _,action in ipairs(registry) do
      if action.id==id then
        local ok,err=pcall(action.run)
        if not ok then alert(t('error.actionFailed',{name=tostring(err)})) end
        return
      end
    end
  end
  function self:items()
    if not clipboard then return {{title=t('clipboard.disabled'),disabled=true}} end
    local status=clipboard.status()
    local targets={}
    local selectedReady=false
    for _,target in ipairs(status.targets) do
      local id=target.nodeId
      if id==status.selected and target.ready then selectedReady=true end
      targets[#targets+1]={title=id..(target.ready and '' or (' — '..clipboard.reason(target.reason))),
        checked=id==status.selected,disabled=not target.ready or status.busy,
        fn=function()clipboard.selectTarget(id)end}
    end
    if #targets==0 then
      targets[#targets+1]={title=status.error or t('clipboard.noTargets'),disabled=true}
    end
    targets[#targets+1]={title='-'}
    targets[#targets+1]={title=status.refreshing and t('clipboard.refreshing') or t('clipboard.refresh'),disabled=status.refreshing,fn=clipboard.refresh}
    return {
      {title=status.busy and t('clipboard.busy') or t('clipboard.sendTo',{name=status.selected or t('clipboard.noSelection')}),
        disabled=status.busy or not selectedReady,fn=function()clipboard.push(status.selected)end},
      {title=t('clipboard.chooseTarget'),menu=targets},
      {title=t('clipboard.status'),menu={
        {title=status.lastResult or t('clipboard.noHistory'),disabled=true},
        {title=status.lastError or status.error or t('clipboard.target',{name=status.selected or t('clipboard.noSelection')}),disabled=true},
      }},
    }
  end
  -- Keep the native menu for the shortcut without occupying menu bar space.
  self.menu=hs.menubar.new(false)
  if self.menu then
    self.menu:setMenu(function()return self:items()end)
  end
  function self:toggle()
    if self.stopped or not self.menu or self.menuOpen then return end
    self.menuOpen=true
    local ok,err=pcall(function()self.menu:popupMenu(hs.mouse.absolutePosition())end)
    self.menuOpen=false
    if not ok then alert(t('error.actionFailed',{name=tostring(err)})) end
  end
  if hs.hotkey.assignable({'ctrl','alt','shift'},'v') then
    -- Open after release so modifiers do not affect native menu navigation.
    self.hotkey=hs.hotkey.bind({'ctrl','alt','shift'},'v',function()end,function()self:toggle()end)
  else alert(t('clipboard.menuHotkeyBusy')) end
  function self:stop()
    if self.stopped then return end
    self.stopped=true
    if self.hotkey then self.hotkey:delete() end
    if self.menu then self.menu:delete() end
  end
  return self
end
return M

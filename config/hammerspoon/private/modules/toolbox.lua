-- One searchable entry point. Choices contain IDs only, never callbacks/userdata.
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
    if not win then alert('原窗口已关闭或不可操作'); return end
    if win:isFullScreen() then alert('请先退出系统全屏模式'); return end
    remember(win)
    local frame = win:screen():frame()
    win:setFrame({x=frame.x+frame.w*rect[1], y=frame.y+frame.h*rect[2],
      w=frame.w*rect[3], h=frame.h*rect[4]}, 0)
  end
  local function register(id, group, title, detail, run)
    registry[#registry+1] = {id=id, group=group, title=title, detail=detail, run=run}
  end
  if features.windows then
    register('window.left','窗口','窗口靠左','左半屏 · left half',function()position({0,0,.5,1})end)
    register('window.right','窗口','窗口靠右','右半屏 · right half',function()position({.5,0,.5,1})end)
    register('window.top','窗口','窗口上半屏','top half',function()position({0,0,1,.5})end)
    register('window.bottom','窗口','窗口下半屏','bottom half',function()position({0,.5,1,.5})end)
    register('window.twoThirds','窗口','窗口左侧三分之二','first two thirds',function()position({0,0,2/3,1})end)
    register('window.lastThird','窗口','窗口右侧三分之一','last third',function()position({2/3,0,1/3,1})end)
    register('window.max','窗口','窗口最大化','使用可用屏幕区域 · maximize',function()position({0,0,1,1})end)
    register('window.center','窗口','窗口居中','居中并保留尺寸 · center',function()
      local win=originalWindow(); if not win then alert('原窗口已关闭'); return end
      remember(win); win:centerOnScreen(nil, false, 0)
    end)
    register('window.next','窗口','移到下一块屏幕','next screen monitor',function()
      local win=originalWindow(); if not win then alert('原窗口已关闭'); return end
      local nextScreen=win:screen():next()
      if nextScreen == win:screen() then alert('当前只有一块屏幕'); return end
      remember(win); win:moveToScreen(nextScreen, false, true, 0)
    end)
    register('window.previous','窗口','移到上一块屏幕','previous screen monitor',function()
      local win=originalWindow(); if not win then alert('原窗口已关闭'); return end
      local previous=win:screen():previous()
      if previous == win:screen() then alert('当前只有一块屏幕'); return end
      remember(win); win:moveToScreen(previous, false, true, 0)
    end)
    register('window.undo','窗口','撤销上次窗口调整','恢复该窗口的上一个位置 · undo',function()
      local win=originalWindow(); local frame=win and self.history[win:id()]
      if not frame then alert('这个窗口没有可撤销的调整'); return end
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
        if not ok then alert('窗口操作失败：'..tostring(err)) end
        return
      end
    end
  end
  function self:items()
    if not clipboard then return {{title='图片同步已关闭',disabled=true}} end
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
      targets[#targets+1]={title=status.error or '没有已连接的设备',disabled=true}
    end
    targets[#targets+1]={title='-'}
    targets[#targets+1]={title=status.refreshing and '正在刷新…' or '刷新设备',disabled=status.refreshing,fn=clipboard.refresh}
    return {
      {title=status.busy and '正在同步…' or ('发送已有图片 → '..(status.selected or '未选择目标')),
        disabled=status.busy or not selectedReady,fn=function()clipboard.push(status.selected)end},
      {title='选择同步目标',menu=targets},
      {title='同步状态',menu={
        {title=status.lastResult or '还没有同步记录',disabled=true},
        {title=status.lastError or status.error or ('目标：'..(status.selected or '未选择')),disabled=true},
      }},
    }
  end
  self.menu=hs.menubar.new()
  if self.menu then
    self.menu:setTitle('图片同步'):setTooltip('图片同步 · Ctrl+Alt+Shift+V')
    self.menu:setMenu(function()return self:items()end)
  end
  function self:toggle()
    if self.stopped or not self.menu or self.menuOpen then return end
    self.menuOpen=true
    local ok,err=pcall(function()self.menu:popupMenu(hs.mouse.absolutePosition())end)
    self.menuOpen=false
    if not ok then alert(tostring(err)) end
  end
  if hs.hotkey.assignable({'ctrl','alt','shift'},'v') then
    -- Open after release so modifiers do not affect native menu navigation.
    self.hotkey=hs.hotkey.bind({'ctrl','alt','shift'},'v',function()end,function()self:toggle()end)
  else alert('Ctrl+Alt+Shift+V 已被占用，请点击菜单栏“图片同步”') end
  function self:stop()
    if self.stopped then return end
    self.stopped=true
    if self.hotkey then self.hotkey:delete() end
    if self.menu then self.menu:delete() end
  end
  return self
end
return M

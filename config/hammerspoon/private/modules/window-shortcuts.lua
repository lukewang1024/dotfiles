-- Match the user's Rectangle bindings. Only one app owns them at a time.
local M = {}
M.bindings = {
  {id='window.left',key='left'}, {id='window.right',key='right'},
  {id='window.top',key='up'}, {id='window.bottom',key='down'},
  {id='window.max',key='return'},
  {id='window.previous',key='left',shift=true},
  {id='window.next',key='right',shift=true},
  {id='window.twoThirds',key='up',shift=true},
  {id='window.lastThird',key='down',shift=true},
}
function M.new(toolbox)
  local self={hotkeys={}, owner=nil}
  for _,binding in ipairs(M.bindings) do
    for _,action in ipairs(toolbox.registry) do
      if action.id==binding.id then
        action.detail=action.detail..' · Hyper+'..(binding.shift and 'Shift+' or '')..binding.key
      end
    end
  end
  function self:refresh()
    local owner=hs.application.get('com.knollsoft.Rectangle') and 'Rectangle' or 'Hammerspoon'
    if self.owner==owner then return end
    for _,hotkey in ipairs(self.hotkeys) do hotkey:delete() end
    self.hotkeys={}; self.owner=owner
    if owner=='Rectangle' then return end
    for _,binding in ipairs(M.bindings) do
      local mods={'ctrl','alt','cmd'}
      if binding.shift then mods[#mods+1]='shift' end
      local id=binding.id
      if hs.hotkey.assignable(mods,binding.key) then
        self.hotkeys[#self.hotkeys+1]=hs.hotkey.bind(mods,binding.key,function()toolbox:runWindowAction(id)end)
      else hs.alert.show('窗口快捷键被占用：'..binding.key,3) end
    end
  end
  self.watcher=hs.application.watcher.new(function(_,event)
    if event==hs.application.watcher.launched or event==hs.application.watcher.terminated then
      if self.pending then self.pending:stop() end
      self.pending=hs.timer.doAfter(.2,function()self:refresh()end)
    end
  end):start()
  self:refresh()
  function self:stop()
    if self.pending then self.pending:stop() end
    self.watcher:stop()
    for _,hotkey in ipairs(self.hotkeys) do hotkey:delete() end
  end
  return self
end
return M

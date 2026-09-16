-- Data/action adapter only. All menu UI and parent navigation live in Rust.
local M={}
function M.new()
  local self={visible=false,serial=0,entries={},queue={}}
  local root=(os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME')..'/.config'))..'/dotfiles/config/hyper/'
  local python
  for _,path in ipairs({'/opt/homebrew/bin/python3','/usr/local/bin/python3','/usr/bin/python3'}) do
    if hs.fs.attributes(path) then python=path;break end
  end
  function self:pump()
    if self.task and not self.waiting and #self.queue>0 then
      self.waiting=true;self.task:setInput(table.remove(self.queue,1))
    end
  end
  function self:send(command)
    self.queue[#self.queue+1]=hs.json.encode(command)..'\n';self:pump()
  end
  function self:closed(restore)
    self.visible=false
    if restore and self.target then self.target:focus() end
    if self.onClose then self.onClose() end
    self.entries={};self.queue={};self.waiting=false
  end
  function self:dispatch(event)
    if event.request_id and event.request_id~=self.rid then return end
    if event.type=='shown' or event.type=='ack' then self.waiting=false;self:pump();return end
    if event.type=='action' then
      local entry=self.entries[event.action]
      if not entry or entry.choice.valid==false then return end
      if not event.keep_open then self:closed(true) end
      entry.callback(entry.choice)
    elseif event.type=='dismissed' then self:closed(event.reason=='escape')
    elseif event.type=='error' then
      self:closed(false);hs.alert.show('Hyper Palette: '..(event.message or 'failed'))
    end
  end
  function self:show(choices,options,callback)
    options=options or {}
    local push=self.visible
    if not push then
      if not python then hs.alert.show('Hyper Palette requires Python 3');return end
      self.serial=self.serial+1
      self.rid=tostring(hs.timer.absoluteTime())..'-'..self.serial
      self.entries={};self.queue={};self.waiting=false
      self.target=options.target or hs.window.focusedWindow();self.onClose=options.onClose
    end
    self.serial=self.serial+1
    local page='page-'..self.serial
    local items={}
    for index,choice in ipairs(choices) do
      local id=page..'-'..index
      self.entries[id]={choice=choice,callback=callback}
      items[#items+1]={id=id,title=choice.text or '',detail=choice.subText or '',
        shortcut=choice.shortcut or '',keywords=choice.keywords or '',disabled=choice.valid==false,
        navigate=choice.navigate==true,keep_open=choice.navigate==true or options.continuous==true}
    end
    local request={request_id=self.rid,root=page,menus={[page]={title=options.title or 'Hyper',items=items,quick=options.quick==true}}}
    if not push then
      local buffer=''
      local task
      task=hs.task.new(python,function(code)
        -- hs.task may deliver its final streaming chunk after termination.
        hs.timer.doAfter(0,function()
          if self.task~=task then return end
          self.task=nil
          if self.visible then self:closed(false) end
          if code~=0 then hs.alert.show('Hyper Palette failed; check host.log') end
        end)
      end,function(_,out)
        if self.task~=task then return false end
        buffer=buffer..(out or '')
        while buffer:find('\n',1,true) do
          local line,rest=buffer:match('^([^\n]*)\n(.*)$');buffer=rest
          local ok,event=pcall(hs.json.decode,line)
          if ok and type(event)=='table' then self:dispatch(event) end
        end
        return true
      end,{'-B',root..'palette_bridge.py','--interactive'})
      self.task=task
      if not task:start() then self.task=nil;hs.alert.show('Hyper Palette bridge failed to start');return end
    end
    self.visible=true
    self:send({type=push and 'push' or 'show',request=request})
  end
  function self:navigate(action)
    if not self.visible then return false end
    self:send({type='navigate',request_id=self.rid,action=action});return true
  end
  function self:close() self:navigate('close') end
  function self:stop()
    if self.task then self.task:closeInput();self.task=nil end
    if self.warm then self.warm:terminate();self.warm=nil end
    self:closed(false)
  end
  if python then
    self.warm=hs.task.new(python,function()self.warm=nil end,{'-B',root..'palette_bridge.py','--warm'})
    self.warm:start()
  end
  return self
end
return M

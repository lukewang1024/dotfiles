package.path='config/hammerspoon/?.lua;'..package.path
local messages,tasks={},{}
local focused=0
local target={focus=function()focused=focused+1 end}
hs={fs={attributes=function()return {} end},window={focusedWindow=function()return target end},
  timer={absoluteTime=function()return 123 end},alert={show=function(message)error(message)end},
  json={encode=function(value)messages[#messages+1]=value;return 'json' end},task={new=function(_,done,stream,args)
    local task={done=done,stream=stream,args=args}
    function task:start()return true end
    function task:setInput(value)self.input=value end
    function task:closeInput()self.closed=true end
    function task:terminate()self.closed=true end
    tasks[#tasks+1]=task;return task
  end}}
local palette=require('private/modules/hyper-rust-palette').new()
local picked,closed=0,0
palette:show({{text='Devices',navigate=true}}, {title='Root',quick=true,onClose=function()closed=closed+1 end},function()
  palette:show({{text='Speaker',uid='private-uid'}},{title='Child'},function(choice)
    assert(choice.uid=='private-uid');picked=picked+1
  end)
end)
local root=messages[1].request
local rid=palette.rid
assert(root.menus[root.root].quick and root.menus[root.root].items[1].navigate)
assert(palette.visible)
palette:dispatch({type='shown',request_id=rid})
palette:dispatch({type='action',request_id='stale',action=root.root..'-1',keep_open=true})
assert(#messages==1)
palette:dispatch({type='action',request_id=rid,action=root.root..'-1',keep_open=true})
assert(messages[2].type=='push' and palette.visible and focused==0)
palette:dispatch({type='ack',request_id=rid})
palette:navigate('back');assert(messages[3].action=='back')
palette:dispatch({type='ack',request_id=rid})
palette:dispatch({type='action',request_id=rid,action='unknown'})
assert(palette.visible and picked==0)
local child=messages[2].request
palette:dispatch({type='action',request_id=rid,action=child.root..'-1'})
assert(picked==1 and not palette.visible and focused==1 and closed==1)
palette:show({{text='Resize'}},{continuous=true},function()picked=picked+1 end)
local request=messages[4].request
palette:dispatch({type='shown',request_id=palette.rid})
palette:dispatch({type='action',request_id=palette.rid,action=request.root..'-1',keep_open=true})
assert(palette.visible and picked==2)
palette:dispatch({type='dismissed',request_id=palette.rid,reason='blur'})
assert(not palette.visible and focused==1)
palette:stop()
print('Rust adapter: opaque IDs, dynamic push, ack queue, callbacks, continuous actions and blur passed')

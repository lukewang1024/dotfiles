-- Run with luajit. No live app, clipboard, or service is touched.
local tasks, alerts = {}, {}
local selected
local menu = {}
for _, method in ipairs({'setTitle','setTooltip','delete'}) do menu[method]=function(self) return self end end
function menu:setMenu(fn) self.items=fn; return self end
hs = {
  settings={get=function(key)if key=='workbench.clipboard.target' then return selected end end,set=function(_,value)selected=value end},
  alert={show=function(message)table.insert(alerts,message)end},
  menubar={new=function()return menu end},
  hotkey={assignable=function(mods,key)assert(table.concat(mods,',')=='ctrl,alt');assert(key=='v');return true end,
    bind=function(_,_,press,release)return {fire=press,release=release,delete=function()end}end},
  eventtap={keyStroke=function()error('must not synthesize copy')end},
  pasteboard={changeCount=function()error('must not wait for clipboard changes')end},
  json={decode=function(value)return value end},
  timer={
    doAfter=function(_,fn)return {fire=fn,stop=function(self)self.stopped=true end}end,
    doEvery=function(_,fn)return {fire=fn,stop=function(self)self.stopped=true end}end},
  task={new=function(binary,callback,args)
    assert(binary:sub(1,1)=='/')
    local task={args=args,callback=callback,environment=function()return {}end,setEnvironment=function()end,
      start=function()return true end,terminate=function()end}
    table.insert(tasks,task);return task
  end},
}
local module = dofile(arg[1] or 'config/hammerspoon/private/modules/workbench-clipboard.lua')
local ready={nodeId='new-peer',ready=true}
local old={nodeId='old-peer',ready=false,reason='CLIPBOARD_UNSUPPORTED'}
local function completeTargets(list) tasks[#tasks].callback(0,{ok=true,result={targets=list}},'') end
assert(#tasks==1 and tasks[1].args[2]=='targets')
completeTargets({ready,old})
local entries=menu.items()
assert(entries[4].title=='new-peer' and entries[5].disabled)
entries[4].fn()
assert(selected=='new-peer' and #tasks==1) -- choosing does not copy or send
module.hotkey.fire()
assert(#tasks==1) -- no action until key release
module.hotkey.release()
assert(module.busy and #tasks==2 and tasks[2].args[4]=='new-peer')
assert(tasks[2].args[5]=='--image-only')
module.hotkey.release();assert(#tasks==2) -- busy guard
-- CLI reads the current image; no local copy or change-count dependency.
tasks[2].callback(0,{ok=true,result={applied=true}},'')
assert(not module.busy and alerts[#alerts]:find('new-peer',1,true))
completeTargets({ready})
module.hotkey.release()
local failed=tasks[#tasks]
failed.callback(1,{ok=false,error={message='NO_IMAGE'}},'')
assert(not module.busy and module.status().lastError=='剪贴板中没有图片')
completeTargets({ready})
local before=#tasks
module.pushSelected();assert(#tasks==before+1)
tasks[#tasks].callback(1,{},'RPC_TIMEOUT')
assert(not module.busy and alerts[#alerts]:find('不会自动重试',1,true))
completeTargets({old})
before=#tasks
module.pushSelected()
assert(#tasks==before+1 and tasks[#tasks].args[2]=='targets') -- refresh only, never redirect
module.stop()
print('Image sync: existing clipboard send, no synthetic copy or change polling, busy guard, errors and disconnect passed')

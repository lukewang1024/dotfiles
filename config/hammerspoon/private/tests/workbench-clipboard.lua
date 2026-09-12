-- Run with luajit. No live app, clipboard, or service is touched.
local tasks, alerts = {}, {}
local deferred={}
local function flush()
  local pending=deferred; deferred={}
  for _,t in ipairs(pending) do if not t.stopped then t.fire() end end
end
local selected
local hud={}
function hud:start(id) self.target=id; self.active=true; self.result=nil; self.error=nil end
function hud:update(event) self.event=event end
function hud:finish(result,err) self.result=result; self.error=err end
function hud:close() self.active=false end
package.loaded['private/modules/clipboard-progress']={new=function()return hud end}
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
  json={decode=function(value)
    if value=='{progress}' then return {event='clipboard.progress',stage='transferring',bytes=1024} end
    if value=='timeout' then return {ok=false,error={message='TARGET_CHECK_TIMEOUT'}} end
    if value=='result' then return {ok=true,result={applied=true}} end
    return value
  end},
  timer={
    doAfter=function(delay,fn)
      local t={fire=fn,stop=function(self)self.stopped=true end}
      if delay==0 then deferred[#deferred+1]=t end
      return t
    end,
    doEvery=function(_,fn)return {fire=fn,stop=function(self)self.stopped=true end}end},
  task={new=function(binary,callback,stream,args)
    if not args then args=stream; stream=nil end
    assert(binary:sub(1,1)=='/')
    local task={args=args,onExit=callback,callback=function(...)callback(...);flush()end,stream=stream,environment=function()return {}end,setEnvironment=function()end,
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
assert(hud.active and hud.target=='new-peer')
tasks[2].stream(tasks[2],'','{pro')
assert(not hud.event)
tasks[2].stream(tasks[2],'','gress}\n')
assert(hud.event.stage=='transferring' and hud.event.bytes==1024)
module.hotkey.release();assert(#tasks==2) -- busy guard
-- CLI reads the current image; no local copy or change-count dependency.
tasks[2].stream(tasks[2],'res','')
tasks[2].callback(0,'ult','') -- task completion carries only the remaining output
assert(not module.busy and hud.result.applied)
completeTargets({ready})
module.hotkey.release()
local failed=tasks[#tasks]
failed.callback(1,{ok=false,error={message='NO_IMAGE'}},'')
assert(not module.busy and module.status().lastError=='本机剪贴板没有可传输的图片，请先截图或复制图片')
completeTargets({ready})
local before=#tasks
module.pushSelected();assert(#tasks==before+1)
tasks[#tasks].callback(1,{},'RPC_TIMEOUT')
assert(not module.busy and hud.error:find('不要立即重传',1,true))
completeTargets({old})
before=#tasks
module.pushSelected()
assert(#tasks==before+1 and tasks[#tasks].args[2]=='targets') -- refresh only, never redirect
-- A timed-out metadata probe must not disable an explicit send. The CLI reads
-- the current image and revalidates the same target; no write is retried.
completeTargets({{nodeId='new-peer',ready=false,reason='RPC_TIMEOUT: no response'}})
assert(not menu.items()[1].disabled and not menu.items()[4].disabled)
before=#tasks
module.hotkey.release()
assert(#tasks==before+1 and tasks[#tasks].args[2]=='push' and tasks[#tasks].args[4]=='new-peer')
module.hotkey.release()
assert(#tasks==before+1)
tasks[#tasks].callback(1,{},'RPC_TIMEOUT')
assert(not module.busy and tasks[#tasks].args[2]=='targets')
completeTargets({ready})
assert(#tasks==before+2) -- metadata refresh only after an uncertain write
-- Hammerspoon can deliver the result in the last stream callback after exit.
module.pushSelected()
local late=tasks[#tasks]
late.stream(late,'','{progress}\n')
late.onExit(1,'','')
assert(module.busy)
late.stream(nil,'timeout','')
flush()
assert(not module.busy and hud.error=='目标检查超时，图片尚未发送')
completeTargets({ready})
module.stop()
print('Image sync: existing clipboard send, no synthetic copy or change polling, busy guard, errors and disconnect passed')

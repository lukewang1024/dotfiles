local running=true
local made, deleted, invoked=0,0,nil
hs={
  application={get=function()return running and {} or nil end,
    watcher={launched=1,terminated=2,new=function(fn)return {callback=fn,start=function(self)return self end,stop=function()end}end}},
  hotkey={assignable=function()return true end,bind=function(mods,key,fn)
    made=made+1;assert(mods[1]=='ctrl' and mods[3]=='cmd')
    return {fire=fn,delete=function()deleted=deleted+1 end}
  end},
  alert={show=function()end},timer={doAfter=function(_,fn)fn();return {stop=function()end}end},
}
local module=dofile('config/hammerspoon/private/modules/window-shortcuts.lua')
local toolbox={registry={},runWindowAction=function(_,id)invoked=id end}
local instance=module.new(toolbox)
assert(made==0 and instance.owner=='Rectangle')
running=false;instance.watcher.callback(nil,2)
assert(made==9 and instance.owner=='Hammerspoon')
instance.hotkeys[1].fire();assert(invoked=='window.left')
instance:refresh();assert(made==9)
running=true;instance.watcher.callback(nil,1);assert(deleted==9 and #instance.hotkeys==0)
running=false;instance:refresh();instance:stop();assert(made==18 and deleted==18)
print('Window shortcuts: Rectangle handoff, no duplicate registration, action dispatch and cleanup passed')

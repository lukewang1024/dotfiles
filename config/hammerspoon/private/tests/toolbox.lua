local frame={x=0,y=0,w=800,h=600}
local win={id=function()return 1 end,isFullScreen=function()return false end,
  frame=function()return frame end,setFrame=function(_,f)frame=f end,
  screen=function()return {frame=function()return {x=100,y=0,w=1200,h=900}end}end}
local current={targets={{nodeId='new',ready=true},{nodeId='old',ready=false,reason='unsupported'}},selected='new'}
local selected,sent,refreshed
local clip={status=function()return current end,reason=function(s)return s end,
  selectTarget=function(id)selected=id end,push=function(id)sent=id end,refresh=function()refreshed=true end}
local menu={}
for _,key in ipairs({'setTitle','setTooltip','delete'})do menu[key]=function(self)return self end end
function menu:setMenu(fn)self.items=fn;return self end
function menu:popupMenu()self.opened=true end
hs={settings={get=function()return nil end},alert={show=function()end},
  window={focusedWindow=function()return win end,get=function()return win end},
  menubar={new=function()return menu end},mouse={absolutePosition=function()return {x=0,y=0}end},
  hotkey={assignable=function(mods,key)assert(table.concat(mods,',')=='ctrl,alt,shift');assert(key=='v');return true end,
    bind=function(_,_,press,release)return {press=press,release=release,delete=function()end}end}}
local box=dofile('config/hammerspoon/private/modules/toolbox.lua').new({clipboard=clip})
local items=box:items();assert(#items==3 and not items[1].disabled)
assert(items[2].menu[2].disabled)
items[2].menu[1].fn();assert(selected=='new' and not sent)
items[1].fn();assert(sent=='new')
current.targets={};current.error='CLI needs upgrade'
items=box:items();assert(items[1].disabled and items[2].menu[1].title=='CLI needs upgrade')
items[2].menu[3].fn();assert(refreshed)
box:runWindowAction('window.left');assert(frame.x==100 and frame.w==600)
box:runWindowAction('window.undo');assert(frame.w==800)
box.hotkey.press();assert(not menu.opened)
box.hotkey.release();assert(menu.opened and not box.menuOpen)
box:stop();box:stop();menu.opened=false;box:toggle();assert(not menu.opened)
print('Native menu: three actions, disabled targets, errors, copy-free selection, window actions and shortcut release passed')

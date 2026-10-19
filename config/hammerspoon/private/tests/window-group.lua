package.path='config/hammerspoon/?.lua;'..package.path
local m=require('private/modules/window-group')
local config=require('private/modules/window-groups')
local apps,ordered,pending,raised={},{},{},{}
local front
hs={
  application={runningApplications=function()return apps end,frontmostApplication=function()return front end},
  window={list=function()return ordered end},
  timer={doAfter=function(_,fn)pending[#pending+1]=fn;return {stop=function()end}end},
}
local function app(bundle,pid)
  local a={windows={}}
  function a:bundleID()return bundle end
  function a:pid()return pid end
  function a:allWindows()return self.windows end
  function a:unhide()end
  apps[#apps+1]=a
  return a
end
local function window(a,id,title)
  local w={name=title,minimized=false,standard=true,alive=true,f={x=10,y=20,w=500,h=600}}
  function w:id()return self.alive and id or nil end
  function w:title()return self.name end
  function w:application()return a end
  function w:isStandard()return self.standard end
  function w:isMinimized()return self.minimized end
  function w:minimize()self.minimized=true end
  function w:unminimize()self.minimized=false end
  function w:frame()return self.f end
  function w:setFrame(f)self.f={x=f.x,y=f.y,w=f.w,h=f.h}end
  function w:raise()raised[#raised+1]=id end
  function w:focus()front=a end
  function w:role()return 'AXWindow' end
  function w:subrole()return 'AXStandardWindow' end
  a.windows[#a.windows+1]=w
  return w
end
local function cg(w)
  return {kCGWindowNumber=w:id(),kCGWindowOwnerPID=w:application():pid(),
    kCGWindowLayer=0,kCGWindowName=w:title()}
end
local function settle()
  for _=1,12 do
    if #pending==0 then return end
    table.remove(pending,1)()
  end
  error('restore did not settle')
end
local rdp=app('com.microsoft.rdc.macos',100)
local library=window(rdp,1,'Windows App')
local first=window(rdp,2,'Remote A')
local second=window(rdp,3,'Remote B')
local settings=window(rdp,4,'Settings')
local noMachine=app('com.nomachine.nxdock',200)
local connection=window(noMachine,5,'Test - NoMachine')
local browser=window(app('com.example.browser',300),6,'Remote A')
local group=m.new(config.remote)
assert(#group:members()==3 and group:contains(first) and group:contains(connection))
assert(not group:contains(library) and not group:contains(settings) and not group:contains(browser))
front=rdp;ordered={cg(first),cg(browser),cg(second),cg(connection),cg(library)}
assert(group:focusedWindow()==first)
-- Hide affects every matching session, including sessions in another app.
assert(group:toggle() and first.minimized and second.minimized and connection.minimized)
assert(not library.minimized and not settings.minimized and not browser.minimized)
-- Minimized windows may disappear; use the captured references on restore.
rdp.windows={library,settings};noMachine.windows={}
assert(group:toggle());settle()
assert(not first.minimized and not second.minimized and not connection.minimized)
assert(#raised==3 and raised[#raised]==first:id())
rdp.windows={library,settings,first,second};noMachine.windows={connection}
-- Focusing an excluded window in a member application is not group activation.
ordered={cg(library),cg(first),cg(second),cg(connection)}
assert(group:focusedWindow()==nil)
assert(group:toggle() and not group.hidden);settle()
-- Do not resurrect a pre-minimized member or a closed member on hide/restore.
ordered={cg(first),cg(second),cg(connection)}
second.minimized=true
assert(group:toggle());connection.alive=false
assert(group:toggle());settle()
assert(not first.minimized and second.minimized)
print('Configured remote group: membership, excluded windows, cross-app toggle, retained/closed/minimized members passed')

local chat=app('com.example.chat',400)
local main=window(chat,10,'Personal Chat')
local conversation=window(chat,11,'A conversation')
local preview=window(chat,12,'Image preview')
local personal=m.new({id='personalChat',apps={
  {bundleID='com.example.chat',selection='main',title='Personal Chat',
    role='AXWindow',subrole='AXStandardWindow'},
}})
assert(#personal:members()==1 and personal:contains(main))
assert(not personal:contains(conversation) and not personal:contains(preview))
local duplicate=window(chat,13,'Personal Chat')
assert(#personal:members()==0 and #personal.selectionErrors==1)
assert(personal.selectionErrors[1].count==2)
duplicate.name='Settings'
assert(#personal:members()==1 and #personal.selectionErrors==0)
main.name='Signed out'
assert(#personal:members()==0) -- never substitute the remaining conversation
local custom=m.new({id='custom',apps={
  {bundleID='com.example.chat',selection='main',match=function(w)return w:id()==11 end},
}})
assert(#custom:members()==1 and custom:contains(conversation))
print('Main-window group: per-app selectors, ambiguity, missing main and custom matching passed')

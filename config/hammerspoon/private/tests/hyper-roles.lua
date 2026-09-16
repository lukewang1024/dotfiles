package.path='config/hammerspoon/?.lua;'..package.path
local saved={['hyper.defaults']={chat='lark',browser='chrome',clipboardTarget='keep'}}
hs={settings={get=function(key)return saved[key]end,set=function(key,value)saved[key]=value;return true end}}
local data=require 'private/modules/hyper-generated'
local module=require 'private/modules/hyper-roles'
local index={apps={{title='Custom Editor',path='/Applications/Custom Editor.app',bundle='vendor.actual.editor'},
  {title='iTerm',path='/Applications/iTerm.app',bundle='com.googlecode.iterm2'}}}
local roles=module.new(data,index)
assert(roles:get('workChat')=='lark' and roles:get('dailyChat')=='wechat')
assert(roles:get('ai')=='chatgpt')
assert(saved['hyper.defaults'].workChat==nil) -- Migration is non-destructive until a save.
assert(roles:keys('workChat')=='H+w' and roles:keys('dailyChat')=='H+c')
assert(roles:keys('terminal')=='H+;')
assert(roles:keys('secondaryTerminal')=='H+Shift+;')
local count=0;for _ in pairs(data.roles) do count=count+1 end
assert(#roles:rows()==count)
local found
for _,row in ipairs(roles:choices('editor')) do
  if row.action=='setrole.editor.installed./Applications/Custom Editor.app' then found=true end
end
assert(found)
assert(roles:set('editor','installed./Applications/Custom Editor.app'))
assert(roles:get('editor')=='installed./Applications/Custom Editor.app')
assert(roles:title(roles:get('editor'))=='Custom Editor')
assert(saved['hyper.defaults'].browser=='chrome' and saved['hyper.defaults'].clipboardTarget=='keep')
assert(saved['hyper.defaults'].chat=='lark' and saved['hyper.defaults'].workChat=='lark')
assert(roles:set('workChat','feishu'));assert(module.new(data,index):get('workChat')=='feishu')
assert(roles:set('editor',roles:default('editor')) and roles:get('editor')=='sublime')
assert(not roles:set('missing','code') and not roles:set('editor','unknown'))
assert(not roles:set('editor',nil))
hs.settings.set=function()return false end
assert(not roles:set('browser','firefox') and roles:get('browser')=='chrome')
print('Roles: defaults, legacy migration, all roles, discovered apps, persistence, reset and save failure passed')

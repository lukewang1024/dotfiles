package.path='config/hammerspoon/?.lua;'..package.path
hs={keycodes={map={m=46,q=12}},processInfo={arch='arm64'},json={}}
local config=require 'private/modules/hyper-config'
local defaults=require 'private/modules/hyper-generated'
local function localConfig()
  return {apps={example={title='Example Music',mac='test.example.music',arch='arm64'}},bindings={
    {key='m',shift=true,action='launch.example',arch='arm64',title={en='Show music',zh='呼出音乐'}},
    {key='q',action='launch.example',arch='arm64',title={en='Show music',zh='呼出音乐'}}}}
end
local function chord(data,key,shift)
  local result,count=nil,0
  for _,binding in ipairs(data.bindings) do
    if binding.key==key and (not not binding.shift)==shift then result=binding;count=count+1 end
  end
  assert(count<=1,'A local override must replace the chord, not register it twice')
  return result
end
local defaultShiftM=chord(defaults,'m',true)
local merged=config.merge(defaults,localConfig(),'arm64')
assert(merged.apps.example.mac=='test.example.music')
assert(chord(merged,'m',true).action=='launch.example')
assert(chord(merged,'m',false).action=='app.music')
assert(chord(merged,'q',false).action=='launch.example')
assert(not defaults.apps.example and chord(defaults,'m',true)==defaultShiftM)
assert(chord(defaults,'q',false).action=='launch.firefox')
local intel=config.merge(defaults,localConfig(),'x86_64')
assert(not intel.apps.example)
assert((chord(intel,'m',true) or {}).action==(defaultShiftM or {}).action)
assert(chord(intel,'q',false).action=='launch.firefox')
local unscoped=localConfig();unscoped.apps.example.arch=nil
for _,binding in ipairs(unscoped.bindings) do binding.arch=nil end
assert(chord(config.merge(defaults,unscoped,'x86_64'),'m',true).action=='launch.example')
assert(chord(config.merge(defaults,{bindings={{key='m',action='launch.firefox'}}},'arm64'),'m',false).action=='launch.firefox')

local function invalid(change,field)
  local value=localConfig();change(value)
  local ok,err=pcall(config.merge,defaults,value,'arm64')
  assert(not ok and tostring(err):find(field,1,true),tostring(err))
end
invalid(function(v)v.bindings[1].title.zh=nil end,'title.en/zh')
invalid(function(v)v.bindings[1].title.en=' ' end,'title.en/zh')
invalid(function(v)v.bindings[1].title=nil end,'title.en/zh')
invalid(function(v)v.bindings[1].key='unknown' end,'.key')
invalid(function(v)v.bindings[1].key='M' end,'.key')
invalid(function(v)v.bindings[1].shift='true' end,'.shift')
invalid(function(v)v.bindings[1].arch='aarch64' end,'.arch')
invalid(function(v)v.bindings[1].action='launch.missing' end,'.action')
invalid(function(v)v.bindings[3]=v.bindings[1] end,'.key/shift')
invalid(function(v)v.bindings={named=v.bindings[1]} end,'bindings')
invalid(function(v)v.bindings=false end,'bindings')
invalid(function(v)v.apps.example.mac=nil end,'.mac')
invalid(function(v)v.binding={} end,'binding')

-- Missing/unreadable/malformed files must not lose the shared bindings. Even a
-- late validation failure must not leave part of the local file applied.
local open=io.open
io.open=function()return nil,'missing',2 end
local loaded,err=config.load(defaults,'missing.json')
assert(loaded==defaults and err==nil)
io.open=function()return nil,'unreadable',13 end
loaded,err=config.load(defaults,'unreadable.json')
assert(loaded==defaults and err:find('unreadable.json',1,true))
local closed=false
io.open=function()return {read=function()return 'contents' end,close=function()closed=true end}end
hs.json.decode=function()error('malformed')end
loaded,err=config.load(defaults,'bad.json')
assert(loaded==defaults and err:find('bad.json',1,true) and closed)
hs.json.decode=function()return nil end
loaded,err=config.load(defaults,'null.json');assert(loaded==defaults and err)
hs.json.decode=function()local v=localConfig();v.bindings[2].title.zh=nil;return v end
loaded,err=config.load(defaults,'bad-title.json')
assert(loaded==defaults and not loaded.apps.example and err:find('title.en/zh',1,true))
hs.json.decode=localConfig
loaded,err=config.load(defaults,'good.json')
assert(not err and chord(loaded,'m',true).title.zh=='呼出音乐')
io.open=open
for _,lang in ipairs({'en','zh'}) do
  assert(defaults.i18n[lang]['error.localConfig']:find('{name}',1,true))
end
print('Hyper local config: chord replacement, ARM scope, bilingual validation and atomic fallback passed')

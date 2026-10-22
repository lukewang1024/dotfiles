-- Machine-local declarative overrides; shared generation never reads this file.
local M={}
local function copy(value)
  if type(value)~='table' then return value end
  local result={};for key,item in pairs(value) do result[key]=copy(item) end;return result
end
local function check(condition,field)
  if not condition then error(field,0) end
end
local function text(value)return type(value)=='string' and value:find('%S')~=nil end
local function matches(item,arch,field)
  check(item.arch==nil or item.arch=='arm64' or item.arch=='x86_64',field..'.arch')
  return item.arch==nil or item.arch==arch
end

function M.path()
  return (os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME')..'/.config')..'/dotfiles/config/hyper/keys.local.json'
end

function M.merge(data,overrides,arch)
  check(type(overrides)=='table','keys.local.json')
  for key in pairs(overrides) do check(key=='apps' or key=='bindings',tostring(key)) end
  local result=copy(data)
  check(overrides.apps==nil or type(overrides.apps)=='table','apps')
  for id,app in pairs(overrides.apps or {}) do
    local field='apps.'..tostring(id)
    check(text(id) and type(app)=='table',field)
    check(text(app.title),field..'.title')
    check(text(app.mac),field..'.mac')
    if matches(app,arch,field) then result.apps[id]=copy(app) end
  end
  check(overrides.bindings==nil or type(overrides.bindings)=='table','bindings')
  local bindings=overrides.bindings or {}
  for index in pairs(bindings) do
    check(type(index)=='number' and index%1==0 and index>=1 and index<=#bindings,'bindings')
  end
  local seen={}
  for index,binding in ipairs(bindings) do
    local field='bindings['..index..']'
    check(type(binding)=='table',field)
    check(text(binding.key) and binding.key==binding.key:lower()
      and hs.keycodes.map[binding.key]~=nil,field..'.key')
    check(binding.shift==nil or type(binding.shift)=='boolean',field..'.shift')
    check(text(binding.action),field..'.action')
    if binding.title~=nil then
      check(type(binding.title)=='table' and text(binding.title.en) and text(binding.title.zh),field..'.title.en/zh')
    else
      check(data.i18n.en[binding.action] and data.i18n.zh[binding.action],field..'.title.en/zh')
    end
    if matches(binding,arch,field) then
      local app=binding.action:match('^launch%.(.+)$')
      check(not app or (result.apps[app] and result.apps[app].mac),field..'.action')
      local chord=binding.key..(binding.shift and '+shift' or '')
      check(not seen[chord],field..'.key/shift');seen[chord]=true
      for i=#result.bindings,1,-1 do
        local existing=result.bindings[i]
        if existing.key==binding.key and (not not existing.shift)==(not not binding.shift) then
          table.remove(result.bindings,i)
        end
      end
      result.bindings[#result.bindings+1]=copy(binding)
    end
  end
  return result
end

function M.load(data,path)
  path=path or M.path()
  local file,err,code=io.open(path,'r')
  if not file then
    if code==2 then return data end -- An absent local file is the normal default.
    return data,path..': '..tostring(err)
  end
  local content=file:read('*a');file:close()
  local ok,result=pcall(function()
    return M.merge(data,hs.json.decode(content),hs.processInfo.arch)
  end)
  if ok then return result end
  return data,path..': '..tostring(result)
end
return M

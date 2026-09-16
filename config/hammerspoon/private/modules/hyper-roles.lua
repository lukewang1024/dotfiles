-- Preference editing is separate from launching: role hotkeys never open menus.
local M={}
local t=require('private/modules/hyper-i18n').t
function M.migrate(defaults)
  local result={};for key,value in pairs(defaults or {}) do result[key]=value end
  if result.workChat==nil then result.workChat=result.chat end
  return result
end
function M.new(data,index)
  local self={preferred=M.migrate(hs.settings.get('hyper.defaults'))}
  function self:default(role)return (data.defaults.mac or {})[role] or data.roles[role].apps[1]end
  function self:get(role)return self.preferred[role] or self:default(role)end
  function self:title(choice)
    if data.apps[choice] then return data.apps[choice].title end
    local path=choice:match('^installed%.(.+)$')
    for _,app in ipairs(index.apps) do if app.path==path then return app.title end end
    return path and (path:match('([^/]+)%.app$') or path) or choice
  end
  function self:keys(role)
    local keys={}
    for _,b in ipairs(data.bindings) do
      if b.action=='app.'..role then keys[#keys+1]='H+'..(b.shift and 'Shift+' or '')..b.key end
    end
    return table.concat(keys,' / ')
  end
  function self:rows()
    local rows={}
    for role in pairs(data.roles) do
      rows[#rows+1]={text=t('role.'..role),subText=self:keys(role)..' · '..t('ui.roleCurrent',{name=self:title(self:get(role))}),
        action='role.'..role,keywords=self:title(self:get(role))}
    end
    table.sort(rows,function(a,b)return a.text<b.text end)
    return rows
  end
  function self:choices(role)
    local rows={{text=t('ui.roleReset'),subText=self:title(self:default(role)),action='resetrole.'..role}}
    local seen={}
    local function add(choice,title,detail,identity)
      if seen[identity or choice] then return end
      seen[identity or choice]=true
      rows[#rows+1]={text=title,subText=(choice==self:get(role) and '✓ ' or '')..(detail or ''),action='setrole.'..role..'.'..choice}
    end
    local current=self:get(role)
    local identity=data.apps[current] and data.apps[current].mac or current
    for _,app in ipairs(index.apps) do
      if current=='installed.'..app.path then identity=app.bundle~='' and app.bundle or app.path;break end
    end
    add(current,self:title(current),t('ui.roleCurrent',{name=self:title(current)}),identity)
    -- Keep configured defaults available even before discovery completes.
    for _,name in ipairs(data.roles[role].apps) do
      local app=data.apps[name]
      if app.mac then add(name,app.title,app.mac,app.mac) end
    end
    for _,app in ipairs(index.apps) do
      add('installed.'..app.path,app.title,app.path,app.bundle~='' and app.bundle or app.path)
    end
    for name,app in pairs(data.apps) do if app.mac then add(name,app.title,app.mac,app.mac) end end
    return rows
  end
  function self:set(role,choice)
    if not data.roles[role] or type(choice)~='string' or not ((data.apps[choice] and data.apps[choice].mac) or choice:match('^installed%./')) then
      return false,t('error.role',{name=role})
    end
    local updated=M.migrate(hs.settings.get('hyper.defaults'))
    updated[role]=choice
    local ok,result=pcall(hs.settings.set,'hyper.defaults',updated)
    if not ok or result==false then return false,t('error.roleSave') end
    self.preferred=updated
    return true,t('ui.roleSaved',{name=t('role.'..role)..' → '..self:title(choice)})
  end
  return self
end
return M

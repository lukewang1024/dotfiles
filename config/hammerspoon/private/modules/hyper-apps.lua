-- Discover installed bundles off the UI thread; menus read the in-memory cache.
local M={}
function M.new()
  local self={apps={}}
  local home=os.getenv('HOME')
  local config=os.getenv('XDG_CONFIG_HOME') or home..'/.config'
  local cache=(os.getenv('XDG_CACHE_HOME') or home..'/.cache')..'/hyper/apps-mac.json'
  local ok,saved=pcall(hs.json.read,cache)
  if ok and type(saved)=='table' and saved.version==1 and type(saved.apps)=='table' then self.apps=saved.apps end
  function self:refresh()
    if self.task then return end
    self.task=hs.task.new('/usr/bin/env',function(code,output)
      self.task=nil
      if code~=0 then return end
      local valid,apps=pcall(hs.json.decode,output)
      if valid and type(apps)=='table' then self.apps=apps end
    end,{'python3',config..'/dotfiles/config/hyper/app_index.py','--platform','mac','--refresh'})
    if self.task and not self.task:start() then self.task=nil end
  end
  function self:choices()
    local rows={}
    for _,app in ipairs(self.apps) do
      rows[#rows+1]={text=app.title,subText=app.path,action='installed.'..app.path}
    end
    return rows
  end
  function self:stop()
    self.initial:stop();self.timer:stop()
    if self.task then self.task:terminate();self.task=nil end
  end
  self.initial=hs.timer.doAfter(.2,function()self:refresh()end)
  self.timer=hs.timer.doEvery(600,function()self:refresh()end)
  return self
end
return M

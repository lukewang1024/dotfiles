local M={}
local catalog=require('private/modules/hyper-generated').i18n
function M.normalize(locale)
  return tostring(locale or ''):lower():match('^[a-z]+')=='zh' and 'zh' or 'en'
end
function M.detect()
  local locale=hs.host and hs.host.locale
  local languages=locale and locale.preferredLanguages() or {}
  -- Some Hammerspoon/macOS builds return an empty preference array.
  if not languages[1] and hs.plist then
    local ok,prefs=pcall(hs.plist.read,os.getenv('HOME')..'/Library/Preferences/.GlobalPreferences.plist')
    if ok and prefs then languages=prefs.AppleLanguages or {} end
  end
  return M.normalize(languages[1] or (locale and locale.current()) or os.getenv('LANG'))
end
local current
function M.language()
  if not current then current=M.detect() end
  return current
end
function M.t(key,values,language)
  local labels=catalog[language or M.language()] or catalog.en
  local result=labels[key] or catalog.en[key] or key
  return (result:gsub('{([%w_]+)}',function(name)return values and tostring(values[name] or '{'..name..'}') or '{'..name..'}' end))
end
function M.keywords(action)
  if not action then return '' end
  return action..' '..(catalog.en[action] or '')..' '..(catalog.zh[action] or '')
end
function M.ui()
  local result={}
  for _,key in ipairs({'search','quickHint','searchHint','count','empty'}) do result[key]=M.t('ui.'..key) end
  return result
end
return M

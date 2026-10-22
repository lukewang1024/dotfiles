package.path='config/hammerspoon/?.lua;'..package.path
local preferred={'en-US','zh-Hans'}
hs={host={locale={preferredLanguages=function()return preferred end,current=function()return 'en_US'end}}}
local i18n=require('private/modules/away-guard-i18n')
assert(i18n.t('armed'):find('Away guard enabled',1,true))
preferred={'zh-Hant-HK','en-US'}
assert(i18n.t('armed'):find('离开守护已开启',1,true))
assert(i18n.reason('display configuration changed')=='显示器配置发生变化')
assert(i18n.reason('brightness increased or unreadable: 0.0625'):find('0.0625',1,true))
assert(i18n.reason('display setup timed out','en')=='Display setup timed out')
assert(i18n.reason(nil)=='已观察到屏幕锁定，来源未知')
assert(i18n.reason('native display check progress timed out')=='原生屏幕安全检查停止推进')
assert(i18n.reason('native display check progress timed out','en')=='Native display checks stopped progressing')
assert(i18n.reason('display monitor heartbeat timed out')=='显示监视进程心跳超时')
assert(i18n.reason('invalid display monitor heartbeat','en')=='Invalid display monitor heartbeat')
local message=i18n.t('restored',{reason=i18n.reason('manual return')})
assert(message:find('手动请求锁屏并退出',1,true) and not message:find('{reason}',1,true))
preferred={'fr-FR','zh-Hans'}
assert(i18n.t('inactive')=='Away guard is not active.')
assert(i18n.reason('new native error'):find('new native error',1,true))
preferred={};hs.plist={read=function()return {AppleLanguages={'zh-Hans'}}end}
assert(i18n.t('inactive')=='离开守护尚未开启。')
print('Away guard i18n: system preference order, live language selection, variants, fallback and translated reasons passed')

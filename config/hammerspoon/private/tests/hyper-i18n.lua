package.path='config/hammerspoon/?.lua;'..package.path
local preferred={'en-US','zh-Hans'}
hs={host={locale={preferredLanguages=function()return preferred end,current=function()return 'zh_CN' end}}}
local i18n=require 'private/modules/hyper-i18n'
assert(i18n.detect()=='en') -- Do not choose Chinese just because it is secondary.
preferred={'zh-Hant-HK'};assert(i18n.detect()=='zh')
assert(i18n.normalize('ZH')=='zh' and i18n.normalize('ja-JP')=='en')
assert(i18n.t('window.maximize',nil,'en')=='Maximize window')
assert(i18n.t('window.maximize',nil,'zh')=='最大化窗口')
assert(i18n.t('ui.count',{count=3},'zh')=='3 项')
assert(i18n.t('unknown',nil,'en')=='unknown')
assert(i18n.keywords('capture.screenshot'):find('截图',1,true))
assert(i18n.keywords('capture.screenshot'):find('screenshot',1,true))
print('Hyper i18n: system preference order, variants, fallback, placeholders and bilingual keywords passed')

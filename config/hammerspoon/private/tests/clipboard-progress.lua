package.path='config/hammerspoon/?.lua;'..package.path
table.unpack=table.unpack or unpack
local now=100
local canvas
local timers={}
local function timer(delay,fn)
  local t={delay=delay,fire=fn,stop=function(self)self.stopped=true end}
  timers[#timers+1]=t; return t
end
hs={timer={secondsSinceEpoch=function()return now end,
  doEvery=timer,doAfter=timer},
  screen={mainScreen=function()return {frame=function()return {x=0,y=0,w=1440,h=900}end}end},
  canvas={windowLevels={overlay=1},new=function(frame)
    canvas={frame=frame}
    function canvas:replaceElements(...) self.elements={...} end
    function canvas:level()end
    function canvas:behavior()end
    function canvas:mouseCallback(fn)self.click=fn end
    function canvas:show()self.visible=true end
    function canvas:delete()self.visible=false end
    return canvas
  end}}
local hud=dofile('config/hammerspoon/private/modules/clipboard-progress.lua').new()
local i18n=require('private/modules/hyper-i18n')
i18n.language=function()return 'zh' end
hud:start('cndevbox')
assert(canvas.visible and canvas.frame.w==190 and canvas.frame.h==44)
assert(canvas.elements[2].text=='正在传图片…')
local firstX=canvas.elements[3].coordinates[1].x
now=100.25;timers[1].fire()
assert(canvas.elements[3].coordinates[1].x~=firstX)
hud:update({stage='confirmed',bytes=1048576})
timers[1].fire()
assert(canvas.elements[2].text=='正在传图片…' and not timers[1].stopped)
hud:finish({bytes=1048576},nil)
assert(canvas.elements[2].text=='图片已传好' and timers[1].stopped)
assert(timers[#timers].delay==2)
timers[#timers].fire();assert(not canvas.visible)
hud:start('cndevbox')
hud:finish(nil,'waiting for confirmation','RPC_TIMEOUT')
assert(canvas.elements[2].text=='远端未确认，结果未知')
assert(timers[#timers].delay==5)
timers[#timers].fire();assert(not canvas.visible)
hud:start('cndevbox')
hud:finish(nil,'no image available','NO_IMAGE')
assert(canvas.elements[2].text=='剪贴板中没有图片')
hud:start('cndevbox')
hud:finish(nil,'其他错误')
assert(canvas.elements[2].text=='图片传输失败')
hud:close();assert(not canvas.visible)
for _,language in ipairs({'en','zh'}) do
  i18n.language=function()return language end
  for _,case in ipairs({
    {'NO_IMAGE','No image in clipboard','剪贴板中没有图片'},
    {'TARGET_CHECK_TIMEOUT','Connection timed out; image not sent','连接超时，图片尚未发送'},
    {'CLIPBOARD_UNCONFIRMED','Remote unconfirmed; result unknown','远端未确认，结果未知'},
    {'RPC_TIMEOUT','Remote unconfirmed; result unknown','远端未确认，结果未知'},
    {'OTHER','Image transfer failed','图片传输失败'},
  }) do
    hud:start('device')
    assert(canvas.frame.w==(language=='zh' and 190 or 330))
    assert(canvas.elements[2].text==(language=='zh' and '正在传图片…' or 'Sending image…'))
    -- Deliberately misleading copy: only the error code may choose the state.
    hud:finish(nil,'剪贴板中没有图片 / unconfirmed',case[1])
    assert(canvas.elements[2].text==case[language=='en' and 2 or 3])
    hud:close()
  end
  hud:start('device');hud:finish({},nil)
  assert(canvas.elements[2].text==(language=='zh' and '图片已传好' or 'Image sent'))
  hud:close()
end
print('Compact HUD: immediate 190x44 display, moving spinner, terminal states, 2s/5s dismissal and cleanup passed')
print('Image HUD: English/Chinese states, code-based errors and English text width passed')

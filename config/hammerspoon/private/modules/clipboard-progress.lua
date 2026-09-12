-- Non-activating, single-line transfer feedback. No estimated progress.
local M = {}
function M.new()
  local self = {}
  local stages = {reading=true,checking=true,preparing=true,transferring=true,confirmed=true}
  function self:close()
    if self.timer then self.timer:stop(); self.timer=nil end
    if self.dismiss then self.dismiss:stop(); self.dismiss=nil end
    if self.canvas then self.canvas:delete(); self.canvas=nil end
  end
  function self:draw()
    if not self.canvas then return end
    local complete = self.stage=='success'
    local failed = self.stage=='failed'
    local label = complete and '图片已传好' or (failed and '图片传输失败' or '正在传图片…')
    if failed then
      local error=tostring(self.error)
      if error:find('没有可传输的图片',1,true) or error:find('NO_IMAGE',1,true) then
        label='剪贴板中没有图片'
      elseif error:find('尚未发送',1,true) then
        label='连接超时，图片尚未发送'
      elseif error:find('未确认写入',1,true) or error:find('结果未知',1,true)
          or error:find('超时',1,true) then
        label='远端未确认，结果未知'
      end
    end
    local elements = {
      {type='rectangle',action='fill',fillColor={hex='#272931'},roundedRectRadii={xRadius=12,yRadius=12}},
      {type='text',text=label,textSize=14,textColor={hex='#EEF0F5'},frame={x=42,y=12,w=140,h=23}},
    }
    if complete then
      elements[#elements+1]={type='segments',action='stroke',strokeWidth=2,strokeColor={hex='#82D3A1'},
        coordinates={{x=18,y=22},{x=22,y=26},{x=30,y=18}}}
    elseif failed then
      elements[#elements+1]={type='circle',action='stroke',strokeWidth=1.5,strokeColor={hex='#F2998F'},
        frame={x=16,y=14,w=16,h=16}}
      elements[#elements+1]={type='text',text='!',textSize=12,textAlignment='center',textColor={hex='#F2998F'},
        frame={x=16,y=14,w=16,h=18}}
    else
      local elapsed=math.max(0,hs.timer.secondsSinceEpoch()-self.started)
      for i=0,9 do
        local angle=(i/10+elapsed)*2*math.pi
        elements[#elements+1]={type='segments',action='stroke',strokeWidth=2,
          strokeColor={hex='#EEF0F5',alpha=.2+.8*i/9},
          coordinates={{x=24+4*math.cos(angle),y=22+4*math.sin(angle)},
            {x=24+8*math.cos(angle),y=22+8*math.sin(angle)}}}
      end
    end
    self.canvas:replaceElements(table.unpack(elements))
  end
  function self:start(target)
    self:close()
    self.target=target; self.stage='reading'; self.error=nil
    self.started=hs.timer.secondsSinceEpoch()
    local screen=hs.screen.mainScreen():frame()
    self.canvas=hs.canvas.new({x=screen.x+screen.w-210,y=screen.y+24,w=190,h=44})
    self.canvas:level(hs.canvas.windowLevels.overlay)
    self.canvas:behavior({'canJoinAllSpaces','fullScreenAuxiliary'})
    self:draw(); self.canvas:show()
    self.timer=hs.timer.doEvery(.05,function()self:draw()end)
  end
  function self:update(event)
    if not stages[event.stage] or self.stage=='success' or self.stage=='failed' then return end
    self.stage=event.stage
  end
  function self:finish(result,err)
    self.stage=result and 'success' or 'failed'
    self.error=err
    if self.timer then self.timer:stop(); self.timer=nil end
    self:draw()
    self.dismiss=hs.timer.doAfter(result and 2 or 5,function()self:close()end)
  end
  return self
end
return M

-- Lifecycle/incident logging only; never runs on every 300ms poll.
local M = {}
function M.new(options)
  options = options or {}
  local root = (os.getenv('XDG_STATE_HOME') or os.getenv('HOME') .. '/.local/state') .. '/away-guard'
  local path = root .. '/events.jsonl'
  local function write(event, fields)
    local record = fields or {}
    record.event, record.time = event, os.date('!%Y-%m-%dT%H:%M:%SZ')
    record.epoch = hs.timer.secondsSinceEpoch()
    hs.printf('[away-guard] %s: %s', event, record.reason or '')
    if options.sink then options.sink(record); return record end
    local ok, error = pcall(function()
      local directory = ''
      for part in root:gmatch('[^/]+') do
        directory = directory .. '/' .. part
        if not hs.fs.attributes(directory) then assert(hs.fs.mkdir(directory)) end
      end
      local size = hs.fs.attributes(path, 'size') or 0
      if size > 5 * 1024 * 1024 then
        os.remove(path .. '.1')
        assert(os.rename(path, path .. '.1'))
      end
      local line = hs.json.encode(record)
      local file = assert(io.open(path, 'a'))
      local wrote, error = file:write(line, '\n')
      file:close()
      assert(wrote, error)
    end)
    if not ok then hs.printf('[away-guard] Cannot write incident log: %s', tostring(error)) end
    return record
  end
  return {write=write, path=path}
end
return M

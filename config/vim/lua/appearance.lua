-- appearance.lua — track the terminal's light/dark theme live and flip
-- &background accordingly (vim-one adapts to &background automatically).
--
-- Why a file and not OSC directly: inside tmux, tmux negotiates the terminal's
-- native theme reporting (DEC mode 2031) itself and does NOT forward it to
-- panes, so an in-nvim OSC/2031 listener would never fire. Instead
-- tmux-adaptive-theme publishes the resolved appearance to a per-host state
-- file (set-appearance.sh) whenever the terminal reports a change; we watch that
-- file. This behaves identically inside tmux, over SSH, and in nested sessions —
-- tmux is the single detector, per host — and needs no tty of our own.
local M = {}
local uv = vim.uv or vim.loop

local state = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. '/.local/state'))
  .. '/appearance'

local function apply()
  local f = io.open(state, 'r')
  if not f then return end
  local v = (f:read('*l') or ''):gsub('%s', '')
  f:close()
  if v ~= 'light' and v ~= 'dark' then return end
  if vim.o.background == v then return end
  vim.o.background = v
  -- Setting &background is not enough for every colorscheme to regenerate its
  -- highlights; re-sourcing the active scheme forces it, cheaply (rare event).
  local cs = vim.g.colors_name
  if cs and cs ~= '' then pcall(vim.cmd.colorscheme, cs) end
  -- vim-airline derives its palette from the colorscheme's highlight groups but
  -- caches it; the ColorScheme autocmd usually re-derives it, yet segments like
  -- the tabline can lag. Force a full rebuild so the bar never trails the buffer.
  if vim.fn.exists(':AirlineRefresh') == 2 then pcall(vim.cmd.AirlineRefresh) end
end

function M.setup()
  apply() -- initial sync at startup

  -- Watch the directory, not the file: set-appearance.sh writes atomically
  -- (temp + rename), which swaps the inode out from under a file-level watch;
  -- a directory watch survives the rename and fires on the new file.
  local dir = vim.fn.fnamemodify(state, ':h')
  local name = vim.fn.fnamemodify(state, ':t')
  local handle = uv.new_fs_event()
  if not handle then return end
  handle:start(dir, {}, vim.schedule_wrap(function(err, fname)
    if err then return end
    if fname == nil or fname == name then apply() end
  end))
end

return M

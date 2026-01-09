-- ==================================================
-- Basic Neovim settings
-- ==================================================

vim.opt.number = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

vim.opt.termguicolors = true
vim.opt.mouse = "a"

-- Reduce redraw overhead over SSH
if vim.env.SSH_TTY then
  vim.opt.mouse = ""
  vim.opt.updatetime = 300
end

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ==================================================
-- Windows shell configuration (Git Bash)
-- ==================================================

if vim.fn.has("win32") == 1 then
  vim.env.PATH = vim.env.PATH
  .. ";C:\\Program Files\\Git\\bin"
  .. ";C:\\Program Files\\Git\\cmd"
  vim.opt.shell = [[C:\Program Files\Git\bin\bash.exe]]
  vim.opt.shellcmdflag = "-lc"
  vim.opt.shellredir = ">"
  vim.opt.shellpipe = "2>&1 | tee"
  vim.opt.shellquote = ""
  vim.opt.shellxquote = ""
end


-- ==================================================
-- Plugins
-- ==================================================

require("plugins")

-- ==================================================
-- Theme
-- ==================================================

vim.cmd.colorscheme("onedark")

-- ==================================================
-- nvim-tree color overrides (robust against onedark)
-- ==================================================

local ORANGE = "#ff7500"
local WHITE = "#e6e6e6"

local function set_tree_colors()
  -- onedark re-applies highlights late, so schedule this
  vim.schedule(function()
    -- Folders
    vim.api.nvim_set_hl(0, "NvimTreeFolderName",        { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName",  { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeRootFolder",       { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeSymlinkFolderName",{ fg = ORANGE })

    -- Files
    vim.api.nvim_set_hl(0, "NvimTreeFileName",         { fg = WHITE })
    vim.api.nvim_set_hl(0, "NvimTreeExecFile",         { fg = WHITE })
    vim.api.nvim_set_hl(0, "NvimTreeSpecialFile",      { fg = WHITE })
    vim.api.nvim_set_hl(0, "NvimTreeSymlink",          { fg = WHITE })

    -- Tree UI
    vim.api.nvim_set_hl(0, "NvimTreeIndentMarker",     { fg = ORANGE })
  end)
end

-- Apply immediately
set_tree_colors()

-- Re-apply after any colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_tree_colors,
})

-- ==================================================
-- Terminal toggle (single instance)
-- ==================================================

local term_buf = nil
local term_win = nil
local term_expanded = false

local SMALL_HEIGHT = 15
local EXPAND_RATIO = 1.6

-- Helper: find terminal window
local function find_term_win()
  if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
    return nil
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == term_buf then
      return win
    end
  end

  return nil
end

-- Open / close terminal
vim.keymap.set("n", "<leader>t", function()
  local win = find_term_win()

  -- Close terminal
  if win then
    vim.api.nvim_buf_delete(term_buf, { force = true })
    term_buf = nil
    term_win = nil
    term_expanded = false
    return
  end

  -- Open terminal
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  vim.cmd("belowright split")
  vim.cmd("resize " .. SMALL_HEIGHT)
  vim.cmd("terminal")

  term_buf = vim.api.nvim_get_current_buf()
  term_win = vim.api.nvim_get_current_win()
  term_expanded = false

  vim.cmd("startinsert")
end, { silent = true })

-- Toggle terminal height
local function toggle_terminal_height()
  local win = find_term_win()
  if not win then
    return
  end

  vim.api.nvim_set_current_win(win)

  if not term_expanded then
    -- Expand
    local total_lines = vim.o.lines
    local target = math.floor(total_lines * EXPAND_RATIO)
    vim.api.nvim_win_set_height(win, target)
    term_expanded = true
  else
    -- Shrink
    vim.api.nvim_win_set_height(win, SMALL_HEIGHT)
    term_expanded = false
  end
end

-- Normal mode
vim.keymap.set("n", "<leader>T", toggle_terminal_height, { silent = true })

-- Esc exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

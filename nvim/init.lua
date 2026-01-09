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
-- Terminal toggle with proper fullscreen toggle
-- ==================================================

local term_buf = nil
local term_fullscreen = false
local saved_winrestcmd = nil

-- Helper: find window displaying terminal buffer
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

-- Open / close terminal (split)
vim.keymap.set("n", "<leader>t", function()
  local win = find_term_win()

  -- Close terminal if open
  if win then
    vim.api.nvim_win_close(win, true)
    term_buf = nil
    term_fullscreen = false
    saved_winrestcmd = nil
    return
  end

  -- If focus is in nvim-tree, move to file window first
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  -- Open terminal split
  vim.cmd("belowright split")
  vim.cmd("resize 15")
  vim.cmd("terminal")

  term_buf = vim.api.nvim_get_current_buf()
  term_fullscreen = false

  vim.cmd("startinsert")
end, { silent = true })

-- Toggle fullscreen (only if terminal exists)
local function toggle_terminal_fullscreen()
  local win = find_term_win()
  if not win then
    return
  end

  if not term_fullscreen then
    -- Go fullscreen
    saved_winrestcmd = vim.fn.winrestcmd()
    vim.api.nvim_set_current_win(win)
    vim.cmd("only")
    term_fullscreen = true
  else
    -- Restore layout
    if saved_winrestcmd then
      vim.cmd(saved_winrestcmd)
    end
    term_fullscreen = false
  end
end

-- Normal mode toggle
vim.keymap.set("n", "<leader>T", toggle_terminal_fullscreen, { silent = true })

-- Terminal mode toggle
vim.keymap.set("t", "<leader>T", function()
  vim.cmd("stopinsert")
  toggle_terminal_fullscreen()
  vim.cmd("startinsert")
end, { silent = true })

-- Esc exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

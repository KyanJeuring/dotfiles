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
-- Terminal toggle with SAFE fullscreen
-- ==================================================

local term_buf = nil
local term_win = nil
local term_fullscreen = false
local saved_view = nil

-- Open / close terminal
vim.keymap.set("n", "<leader>t", function()
  -- Close terminal
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    if term_fullscreen then
      vim.cmd("wincmd =")
      term_fullscreen = false
    end

    vim.api.nvim_buf_delete(term_buf, { force = true })
    term_buf = nil
    term_win = nil
    saved_view = nil
    return
  end

  -- Open terminal
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  vim.cmd("belowright split")
  vim.cmd("resize 15")
  vim.cmd("terminal")

  term_win = vim.api.nvim_get_current_win()
  term_buf = vim.api.nvim_get_current_buf()
  term_fullscreen = false

  vim.cmd("startinsert")
end, { silent = true })

-- Toggle fullscreen (maximize split)
local function toggle_terminal_fullscreen()
  if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
    return
  end

  if not term_fullscreen then
    -- Save view & maximize
    saved_view = vim.fn.winsaveview()
    vim.cmd("wincmd |")
    vim.cmd("wincmd _")
    term_fullscreen = true
  else
    -- Restore layout
    vim.cmd("wincmd =")
    if saved_view then
      vim.fn.winrestview(saved_view)
    end
    term_fullscreen = false
  end
end

-- Normal mode
vim.keymap.set("n", "<leader>T", toggle_terminal_fullscreen, { silent = true })

-- Terminal mode
vim.keymap.set("t", "<leader>T", function()
  vim.cmd("stopinsert")
  toggle_terminal_fullscreen()
  vim.cmd("startinsert")
end, { silent = true })

-- Esc exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

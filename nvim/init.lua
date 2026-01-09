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
-- nvim-tree color overrides (FINAL, CORRECT)
-- ==================================================

local ORANGE = "#ff7500"
local BLUE   = "#61afef"
local WHITE  = "#e6e6e6"

local function set_tree_colors()
  vim.schedule(function()
    -- Folders
    vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName", { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeRootFolder", { fg = ORANGE, bold = true })

    -- Files
    vim.api.nvim_set_hl(0, "NvimTreeFileName", { fg = WHITE })
    vim.api.nvim_set_hl(0, "NvimTreeExecFile", { fg = WHITE })

    -- Highlighted Opened file
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFile", {
      fg = BLUE,
      bold = true,
    })

    vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = ORANGE })
  end)
end

set_tree_colors()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_tree_colors,
})

-- ==================================================
-- Terminal toggle
-- ==================================================

local term_win = nil

vim.keymap.set("n", "<leader>t", function()
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
    term_win = nil
    return
  end

  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  vim.cmd("belowright split")
  vim.cmd("resize 15")
  vim.cmd("terminal")
  term_win = vim.api.nvim_get_current_win()
  vim.cmd("startinsert")
end, {
  silent = true
})

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

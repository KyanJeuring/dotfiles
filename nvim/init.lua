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
  vim.opt.lazyredraw = true
  vim.opt.updatetime = 300
end

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ==================================================
-- Plugins
-- ==================================================

require("plugins")

-- ==================================================
-- nvim-tree color overrides (orange)
-- ==================================================

local orange = "#ff7500" -- you can tweak this later

vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = orange })
vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = orange, bold = true })
vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName", { fg = orange })
vim.api.nvim_set_hl(0, "NvimTreeRootFolder", { fg = orange, bold = true })
vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = orange })


-- ==================================================
-- Terminal toggle (single instance)
-- ==================================================

local term_win = nil

vim.keymap.set("n", "<leader>t", function()
  -- If terminal window exists → close it
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
    term_win = nil
    return
  end

  -- If we're in nvim-tree, move to the file window first
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  -- Open terminal below the file window
  vim.cmd("belowright split")
  vim.cmd("resize 15")
  vim.cmd("terminal")

  term_win = vim.api.nvim_get_current_win()

  -- Enter insert mode immediately
  vim.cmd("startinsert")
end, { silent = true })

-- Esc exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

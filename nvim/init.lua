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

-- ==================================================
-- SAFETY
-- ==================================================

vim.opt.confirm = true
vim.opt.hidden = false

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
-- nvim-tree color overrides
-- ==================================================

local ORANGE = "#ff7500"
local WHITE  = "#e6e6e6"

local function set_tree_colors()
  vim.schedule(function()
    vim.api.nvim_set_hl(0, "NvimTreeFolderName",        { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName",  { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeRootFolder",       { fg = ORANGE, bold = true })

    vim.api.nvim_set_hl(0, "NvimTreeFileName",         { fg = WHITE })
    vim.api.nvim_set_hl(0, "NvimTreeSymlink",          { fg = WHITE })
  end)
end

set_tree_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_tree_colors })

-- ==================================================
-- Terminal toggle
-- ==================================================

local term_buf, term_expanded = nil, false
local SMALL_HEIGHT = 15
local EXPAND_RATIO = 1.5

local function find_term_win()
  if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then return nil end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == term_buf then return win end
  end
end

vim.keymap.set("n", "<leader>t", function()
  local win = find_term_win()
  if win then
    vim.api.nvim_buf_delete(term_buf, { force = true })
    term_buf, term_expanded = nil, false
    return
  end

  if vim.bo.filetype == "NvimTree" then vim.cmd("wincmd l") end
  vim.cmd("belowright split")
  vim.cmd("resize " .. SMALL_HEIGHT)
  vim.cmd("terminal")
  term_buf = vim.api.nvim_get_current_buf()
  vim.cmd("startinsert")
end, { silent = true })

vim.keymap.set("n", "<leader>T", function()
  local win = find_term_win()
  if not win then return end
  vim.api.nvim_set_current_win(win)

  if term_expanded then
    vim.api.nvim_win_set_height(win, SMALL_HEIGHT)
  else
    vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * EXPAND_RATIO))
  end

  term_expanded = not term_expanded
end, { silent = true })

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

-- ==================================================
-- BUFFER TABS
-- ==================================================

vim.keymap.set("n", "<leader>bn", ":bnext<CR>",     { silent = true })
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>",{ silent = true })
vim.keymap.set("n", "<leader>bc", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local cur = vim.api.nvim_get_current_buf()

  -- Delete current buffer
  vim.cmd("bdelete")

  -- Find next listed buffer
  for _, buf in ipairs(bufs) do
    if buf.bufnr ~= cur and vim.api.nvim_buf_is_loaded(buf.bufnr) then
      vim.cmd("buffer " .. buf.bufnr)
      return
    end
  end

  -- Fallback: focus tree if no buffers left
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then
    api.tree.focus()
  end
end, { silent = true })


vim.keymap.set("n", "<leader>1", ":buffer 1<CR>")
vim.keymap.set("n", "<leader>2", ":buffer 2<CR>")
vim.keymap.set("n", "<leader>3", ":buffer 3<CR>")

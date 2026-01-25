-- ==================================================
-- Basic Neovim settings
-- ==================================================

vim.opt.number = true
vim.opt.relativenumber = true

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
-- Colors
-- ==================================================

local ORANGE = "#ff7500"
local WHITE  = "#e6e6e6"

-- ==================================================
-- SAFETY
-- ==================================================

vim.opt.confirm = true

if vim.env.SSH_TTY then
  vim.opt.mouse = ""
  vim.opt.updatetime = 300
end

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
-- Window separators (remove)
-- ==================================================

vim.opt.fillchars = vim.opt.fillchars
  + { vert = " ", vertleft = " ", vertright = " ", verthoriz = " " }

local function remove_window_separators()
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "NONE", bg = "NONE" })
  vim.api.nvim_set_hl(0, "VertSplit",   { fg = "NONE", bg = "NONE" })
end

remove_window_separators()
vim.api.nvim_create_autocmd("ColorScheme", { callback = remove_window_separators })

-- ==================================================
-- Bufferline / Tree background alignment
-- ==================================================

local function fix_tree_bufferline_bg()
  local bg = vim.api.nvim_get_hl(0, { name = "NvimTreeNormal", link = false }).bg
  if not bg then return end

  vim.api.nvim_set_hl(0, "BufferLineFill", { bg = bg })
  vim.api.nvim_set_hl(0, "BufferLineOffset", { bg = bg })
  vim.api.nvim_set_hl(0, "BufferLineTabClose", { bg = bg })
end

fix_tree_bufferline_bg()
vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_tree_bufferline_bg })

-- ==================================================
-- Active tab styling
-- ==================================================

local function set_bufferline_active_tab()
  vim.api.nvim_set_hl(0, "BufferLineBufferSelected", {
    fg = ORANGE,
    bg = "NONE",
    bold = true,
  })
end

set_bufferline_active_tab()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_bufferline_active_tab })

-- ==================================================
-- NvimTree colors
-- ==================================================

local function set_tree_colors()
  vim.schedule(function()
    vim.api.nvim_set_hl(0, "NvimTreeFolderName",        { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName",  { fg = ORANGE })
    vim.api.nvim_set_hl(0, "NvimTreeRootFolder",       { fg = ORANGE, bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeFileName",         { fg = WHITE })
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
end)

vim.keymap.set("n", "<leader>T", function()
  local win = find_term_win()
  if not win then return end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_height(
    win,
    term_expanded and SMALL_HEIGHT or math.floor(vim.o.lines * EXPAND_RATIO)
  )
  term_expanded = not term_expanded
end)

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

-- ==================================================
-- Buffer / tab management
-- ==================================================

local function close_buffer_tab()
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_get_current_buf()

  if vim.bo[cur].buftype ~= "" then
    vim.cmd("confirm bdelete")
    return
  end

  local repl = vim.fn.bufnr("#")
  if repl <= 0 or not vim.fn.buflisted(repl) then
    for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      if b.bufnr ~= cur and vim.bo[b.bufnr].buftype == "" then
        repl = b.bufnr
        break
      end
    end
  end

  if not repl or repl == cur then
    vim.cmd("confirm bdelete")
    require("nvim-tree.api").tree.focus()
    return
  end

  vim.api.nvim_win_set_buf(win, repl)
  vim.cmd("confirm bdelete " .. cur)
end

vim.keymap.set("n", "<Tab>", ":bnext<CR>")
vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>")
vim.keymap.set("n", "gt", ":bnext<CR>")
vim.keymap.set("n", "gT", ":bprevious<CR>")
vim.keymap.set("n", "<leader>x", close_buffer_tab)

-- ==================================================
-- Floating Keybindings Overview
-- ==================================================

vim.api.nvim_set_hl(0, "KeysHelpTitle", { fg = ORANGE, bold = true })

local function open_keys_help()
  local lines = {
    "=== Keybindings Overview ===",
    "",
    "Tabs (files):",
    "  Tab / Shift-Tab     → Next / Previous tab",
    "  gt / gT             → Next / Previous tab",
    "  Space + x           → Close tab",
    "  :q                  → Close tab",
    "  :qa                 → Quit all",
    "",
    "Files & Tree:",
    "  Space + e           → Toggle file tree",
    "  Space + f           → Focus file tree",
    "  Enter (tree)        → Open file / expand folder",
    "",
    "Terminal:",
    "  Space + t           → Toggle terminal",
    "  Space + T           → Expand / shrink terminal",
    "  Esc (terminal)      → Normal mode",
    "",
    "Editing:",
    "  :w                  → Save file",
    "",
    "Press q or Esc to close",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local ui = vim.api.nvim_list_uis()[1]
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 60,
    height = #lines + 2,
    row = math.floor((ui.height - (#lines + 2)) / 2),
    col = math.floor((ui.width - 60) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_add_highlight(buf, -1, "KeysHelpTitle", 0, 0, -1)
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf })
end

vim.api.nvim_create_user_command("Keys", open_keys_help, {})

vim.cmd([[
  cnoreabbrev <expr> keys getcmdtype()==':' && getcmdline()=='keys' ? 'Keys' : 'keys'
  cnoreabbrev <expr> kb   getcmdtype()==':' && getcmdline()=='kb'   ? 'Keys' : 'kb'
  cnoreabbrev <expr> ?    getcmdtype()==':' && getcmdline()=='?'    ? 'Keys' : '?'
]])

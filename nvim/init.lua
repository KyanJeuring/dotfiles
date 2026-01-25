-- ==================================================
-- Basic Neovim settings
-- ==================================================

vim.opt.showmode = false

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

vim.opt.cmdheight = 1
vim.opt.laststatus = 3
vim.opt.shortmess:append("c")

-- ==================================================
-- Color scheme
-- ==================================================

local ORANGE = "#ff7500"
local WHITE  = "#e6e6e6"

-- ==================================================
-- SAFETY
-- ==================================================
vim.opt.confirm = true

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
-- Custom Keybindings
-- ==================================================

-- Save file
vim.keymap.set({ "n", "i", "v" }, "<C-s>", function()
  vim.cmd("write")
end, { silent = true, desc = "Save file" })

-- Close / quit
vim.keymap.set("n", "<C-q>", ":Q<CR>", { silent = true, desc = "Quit / close tab" })
vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true, desc = "Save file" })

-- Clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", { silent = true })

-- Window navigation and resizing
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Duplicate line / selection
vim.keymap.set("n", "<leader>d", "yyp", { desc = "Duplicate line" })
vim.keymap.set("v", "<leader>d", "y`>p", { desc = "Duplicate selection" })

-- Move lines up / down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { silent = true })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { silent = true })
vim.keymap.set("i", "<A-j>", "<Esc>:m .+1<CR>==gi", { silent = true })
vim.keymap.set("i", "<A-k>", "<Esc>:m .-2<CR>==gi", { silent = true })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { silent = true })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { silent = true })

-- Move to beginning and end of line
vim.keymap.set({ "n", "v" }, "H", "^")
vim.keymap.set({ "n", "v" }, "L", "$")

-- Redo
vim.keymap.set("n", "U", "<C-r>", { desc = "Redo" })

-- ==================================================
-- Highlight active window (clarifies resize target)
-- ==================================================

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  callback = function()
    vim.wo.cursorline = true
  end,
})

vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    vim.wo.cursorline = false
  end,
})

-- ==================================================
-- Theme
-- ==================================================

vim.cmd.colorscheme("onedark")

-- ==================================================
-- Command-line styling
-- ==================================================

local CMD_BG     = "#21252b"
local CMD_FG     = "#abb2bf"
local CMD_PROMPT = "#ff7500"
local CMD_ERROR  = "#e06c75"
local CMD_WARN   = "#e5c07b"

local function set_cmdline_colors()
  vim.api.nvim_set_hl(0, "Cmdline",        {})
  vim.api.nvim_set_hl(0, "CmdlinePrompt",  {})
  vim.api.nvim_set_hl(0, "MsgArea",         {})
  vim.api.nvim_set_hl(0, "ErrorMsg",        {})
  vim.api.nvim_set_hl(0, "WarningMsg",      {})

  vim.api.nvim_set_hl(0, "Cmdline", {
    fg = CMD_FG,
    bg = CMD_BG,
  })

  vim.api.nvim_set_hl(0, "CmdlinePrompt", {
    fg = CMD_PROMPT,
    bg = CMD_BG,
    bold = true,
  })

  vim.api.nvim_set_hl(0, "MsgArea", {
    fg = CMD_FG,
    bg = CMD_BG,
  })

  vim.api.nvim_set_hl(0, "ErrorMsg", {
    fg = CMD_ERROR,
    bg = CMD_BG,
    bold = true,
  })

  vim.api.nvim_set_hl(0, "WarningMsg", {
    fg = CMD_WARN,
    bg = CMD_BG,
  })
end

set_cmdline_colors()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_cmdline_colors,
})

-- ==================================================
-- ORANGE title for floating Keys window
-- ==================================================

vim.api.nvim_set_hl(0, "KeysHelpTitle", {
  fg = ORANGE,
  bold = true,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "KeysHelpTitle", {
      fg = ORANGE,
      bold = true,
    })
  end,
})

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

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = remove_window_separators,
})

-- ==================================================
-- Bufferline / NvimTree background alignment
-- ==================================================

local function fix_tree_bufferline_bg()
  local tree_bg = vim.api.nvim_get_hl(0, { name = "NvimTreeNormal", link = false }).bg
  if not tree_bg then return end

  vim.api.nvim_set_hl(0, "BufferLineFill", { bg = tree_bg })
  vim.api.nvim_set_hl(0, "BufferLineOffset", { bg = tree_bg })
  vim.api.nvim_set_hl(0, "BufferLineTabClose", { bg = tree_bg })
end

fix_tree_bufferline_bg()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = fix_tree_bufferline_bg,
})

-- ==================================================
-- Active tab styling
-- ==================================================

local function set_bufferline_active_tab()
  vim.api.nvim_set_hl(0, "BufferLineBufferSelected", {
    fg = ORANGE,
    bg = "NONE",
    bold = true,
    italic = false,
  })
end

set_bufferline_active_tab()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_bufferline_active_tab,
})

-- ==================================================
-- nvim-tree color overrides
-- ==================================================

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
-- BUFFER / TAB MANAGEMENT
-- ==================================================

local function close_buffer_tab()
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_get_current_buf()

  if vim.bo[cur].buftype ~= "" then
    vim.cmd("confirm bdelete")
    return
  end

  local function is_good_buf(b)
    return b
      and b > 0
      and vim.fn.buflisted(b) == 1
      and vim.api.nvim_buf_is_loaded(b)
      and vim.bo[b].buftype == ""
      and vim.bo[b].filetype ~= "NvimTree"
  end

  local repl = vim.fn.bufnr("#")
  if not is_good_buf(repl) then
    repl = nil
    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      if info.bufnr ~= cur and is_good_buf(info.bufnr) then
        repl = info.bufnr
        break
      end
    end
  end

  if not repl then
    vim.cmd("confirm bdelete " .. cur)
    local ok, api = pcall(require, "nvim-tree.api")
    if ok then api.tree.focus() end
    return
  end

  vim.api.nvim_win_set_buf(win, repl)
  local ok = pcall(vim.cmd, "confirm bdelete " .. cur)
  if not ok and vim.api.nvim_buf_is_valid(cur) then
    vim.api.nvim_win_set_buf(win, cur)
  end
end

vim.keymap.set("n", "<Tab>", ":bnext<CR>", { silent = true })
vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>", { silent = true })
vim.keymap.set("n", "gt", ":bnext<CR>", { silent = true })
vim.keymap.set("n", "gT", ":bprevious<CR>", { silent = true })
vim.keymap.set("n", "<leader>x", close_buffer_tab, { silent = true })

-- ==================================================
-- EMPTY BUFFER / WINDOW CLEANUP
-- ==================================================

-- Focus tree when no file buffers remain
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr)
        and vim.bo[buf.bufnr].buftype == ""
        and vim.bo[buf.bufnr].filetype ~= "NvimTree"
      then
        return
      end
    end

    local ok, api = pcall(require, "nvim-tree.api")
    if ok then api.tree.focus() end
  end,
})

-- Never show [No Name] buffers as tabs
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(buf) == ""
      and vim.bo[buf].buftype == ""
      and vim.bo[buf].filetype == ""
    then
      vim.bo[buf].buflisted = false
    end
  end,
})

-- Close empty editor window when only tree remains
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr)
        and vim.bo[buf.bufnr].buftype == ""
        and vim.bo[buf.bufnr].filetype ~= "NvimTree"
      then
        return
      end
    end

    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype ~= "NvimTree" then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end)
  end,
})

-- ==================================================
-- Make :q behave like closing a tab
-- ==================================================

vim.api.nvim_create_user_command("Q", function()
  local buf = vim.api.nvim_get_current_buf()
  local bt = vim.bo[buf].buftype
  local ft = vim.bo[buf].filetype

  if bt == "" and ft ~= "NvimTree" then
    close_buffer_tab()
  else
    vim.cmd("confirm quit")
  end
end, {})

vim.cmd([[
  cnoreabbrev <expr> q getcmdtype() == ':' && getcmdline() == 'q' ? 'Q' : 'q'
]])

-- ==================================================
-- Floating Keybindings Overview
-- ==================================================

local function open_keys_help()
  local lines = {
    "=== Keybindings Overview ===",
    "",
    "Saving:",
    "  Ctrl + S            → Save file (normal / insert / visual)",
    "  Space + w           → Save file",
    "",
    "Tabs (files):",
    "  Tab / Shift-Tab     → Next / Previous tab",
    "  gt / gT             → Next / Previous tab",
    "  Space + x           → Close tab",
    "  Ctrl + q            → Quit / close tab",
    "  :q                  → Close tab",
    "  :qa                 → Quit all",
    "",
    "File Tree:",
    "  Space + e           → Toggle file tree",
    "  Space + f           → Focus file tree",
    "  Enter (tree)        → Open file / expand folder",
    "",
    "Terminal:",
    "  Space + t           → Toggle terminal",
    "  Space + T           → Expand / shrink terminal",
    "  Esc (terminal)      → Normal mode",
    "",
    "Windows:",
    "  Ctrl + h/j/k/l      → Move between windows",
    "",
    "Editing:",
    "  Space + d           → Duplicate line / selection",
    "  Alt + j / Alt + k   → Move line or selection down / up",
    "  H / L               → Jump to start / end of line",
    "  U                   → Redo",
    "  Esc                 → Clear search highlight",
    "",
    "Help:",
    "  :keys, :keybinds, :bindings, :kb, :? → Open this help",
    "",
    "Press q or Esc to close",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "help"
  vim.bo[buf].readonly = true

  local width = 60
  local height = #lines + 2
  local ui = vim.api.nvim_list_uis()[1]

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_add_highlight(buf, -1, "KeysHelpTitle", 0, 0, -1)

  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, silent = true })
end

vim.api.nvim_create_user_command("Keys", open_keys_help, {})

vim.cmd([[
  cnoreabbrev <expr> keys      getcmdtype()==':' && getcmdline()=='keys'      ? 'Keys' : 'keys'
  cnoreabbrev <expr> keybinds  getcmdtype()==':' && getcmdline()=='keybinds'  ? 'Keys' : 'keybinds'
  cnoreabbrev <expr> bindings  getcmdtype()==':' && getcmdline()=='bindings'  ? 'Keys' : 'bindings'
  cnoreabbrev <expr> kb        getcmdtype()==':' && getcmdline()=='kb'        ? 'Keys' : 'kb'
  cnoreabbrev <expr> ?         getcmdtype()==':' && getcmdline()=='?'         ? 'Keys' : '?'
]])

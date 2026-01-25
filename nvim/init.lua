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
-- Theme
-- ==================================================

vim.cmd.colorscheme("onedark")

-- Remove window separators
vim.opt.fillchars = vim.opt.fillchars
  + { vert = " ", vertleft = " ", vertright = " ", verthoriz = " " }

local function remove_window_separators()
  -- Fully neutralize separator highlight groups
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "NONE", bg = "NONE" })
  vim.api.nvim_set_hl(0, "VertSplit",   { fg = "NONE", bg = "NONE" })
end

remove_window_separators()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = remove_window_separators,
})

-- Bufferline / NvimTree background alignment
local function fix_tree_bufferline_bg()
  local tree_bg = vim.api.nvim_get_hl(0, { name = "NvimTreeNormal", link = false }).bg

  if not tree_bg then
    return
  end

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

  vim.api.nvim_set_hl(0, "BufferLineCloseButtonSelected", {
    fg = ORANGE,
    bg = "NONE",
  })

  vim.api.nvim_set_hl(0, "BufferLineSeparatorSelected", {
    fg = "NONE",
    bg = "NONE",
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

-- Core logic: close a "tab" (buffer) like a browser
local function close_buffer_tab()
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_get_current_buf()

  -- Non-file buffers → normal delete
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

  -- Prefer alternate buffer
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

  -- Last file → delete and focus tree
  if not repl then
    vim.cmd("confirm bdelete " .. cur)
    local ok, api = pcall(require, "nvim-tree.api")
    if ok then api.tree.focus() end
    return
  end

  -- Switch first, then delete
  vim.api.nvim_win_set_buf(win, repl)
  local ok = pcall(vim.cmd, "confirm bdelete " .. cur)
  if not ok and vim.api.nvim_buf_is_valid(cur) then
    vim.api.nvim_win_set_buf(win, cur)
  end
end

-- Keymaps
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { silent = true })
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { silent = true })
vim.keymap.set("n", "<leader>bc", close_buffer_tab, { silent = true })

vim.keymap.set("n", "<leader>1", ":buffer 1<CR>")
vim.keymap.set("n", "<leader>2", ":buffer 2<CR>")
vim.keymap.set("n", "<leader>3", ":buffer 3<CR>")

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
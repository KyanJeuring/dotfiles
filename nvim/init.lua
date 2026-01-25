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
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_get_current_buf()

  -- If we're not on a normal file buffer, just try to delete it normally.
  if vim.bo[cur].buftype ~= "" then
    vim.cmd("confirm bdelete")
    return
  end

  -- Pick a replacement buffer:
  -- 1) alternate buffer (#) if it's a normal listed file buffer
  -- 2) otherwise any other listed normal file buffer
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

  -- If no replacement file buffer exists, delete and focus the tree.
  if not repl then
    vim.cmd("confirm bdelete " .. cur)
    local ok, api = pcall(require, "nvim-tree.api")
    if ok then api.tree.focus() end
    return
  end

  -- Force the editor window to show the replacement buffer FIRST,
  -- so focus never falls into NvimTree after deletion.
  vim.api.nvim_win_set_buf(win, repl)

  -- Now delete the old buffer (with confirm prompts if modified).
  local ok = pcall(vim.cmd, "confirm bdelete " .. cur)
  if not ok then
    -- If user cancelled, put the original buffer back in the same window.
    if vim.api.nvim_buf_is_valid(cur) then
      vim.api.nvim_win_set_buf(win, cur)
    end
  end
end, { silent = true })

vim.keymap.set("n", "<leader>1", ":buffer 1<CR>")
vim.keymap.set("n", "<leader>2", ":buffer 2<CR>")
vim.keymap.set("n", "<leader>3", ":buffer 3<CR>")

-- When no file buffers remain, focus NvimTree and remove empty buffer
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    -- Check if any normal file buffers exist
    for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr)
        and vim.bo[buf.bufnr].buftype == ""
        and vim.bo[buf.bufnr].filetype ~= "NvimTree"
      then
        return
      end
    end

    -- If we are in an empty buffer, clean it up and focus tree
    local cur = vim.api.nvim_get_current_buf()
    if vim.bo[cur].buftype == "" and vim.bo[cur].filetype == "" then
      pcall(vim.cmd, "bdelete " .. cur)
    end

    local ok, api = pcall(require, "nvim-tree.api")
    if ok then
      api.tree.focus()
    end
  end,
})


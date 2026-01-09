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

local term_win = nil

vim.keymap.set("n", "<leader>t", function()
  -- Close terminal if it exists
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
    term_win = nil
    return
  end

  -- If focus is in nvim-tree, move to file window first
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  -- Open terminal below file window
  vim.cmd("belowright split")
  vim.cmd("resize 15")
  vim.cmd("terminal")

  term_win = vim.api.nvim_get_current_win()

  -- Enter insert mode immediately
  vim.cmd("startinsert")
end, { silent = true })

-- Esc exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

-- ==================================================
-- Git graph sidebar (true toggle with <Space> g)
-- ==================================================

local git_graph = {
  win = nil,
  buf = nil,
}

local GIT_GRAPH_WIDTH = 15

local function is_git_repo()
  return vim.fn.finddir(".git", ".;") ~= ""
end

local function is_graph_open()
  return git_graph.win
    and vim.api.nvim_win_is_valid(git_graph.win)
    and git_graph.buf
    and vim.api.nvim_buf_is_valid(git_graph.buf)
end

local function close_git_graph()
  if is_graph_open() then
    vim.api.nvim_win_close(git_graph.win, true)
  end
  git_graph.win = nil
  git_graph.buf = nil
end

local function open_git_graph()
  if not is_git_repo() then
    vim.notify("Not a git repository", vim.log.levels.INFO)
    return
  end

  local source_win = vim.api.nvim_get_current_win()

  vim.cmd("botright vsplit")
  vim.cmd("vertical resize " .. GIT_GRAPH_WIDTH)
  vim.cmd("setlocal winfixwidth")

  git_graph.win = vim.api.nvim_get_current_win()

  vim.cmd("enew")
  git_graph.buf = vim.api.nvim_get_current_buf()

  vim.cmd("Git -c color.ui=always log --graph --oneline --decorate --all")

  vim.bo[git_graph.buf].buflisted = false
  vim.bo[git_graph.buf].swapfile = false
  vim.bo[git_graph.buf].modifiable = false
  vim.bo[git_graph.buf].filetype = "gitgraph"

  vim.opt_local.wrap = false
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.cursorline = false

  vim.keymap.set("n", "q", close_git_graph, {
    buffer = git_graph.buf,
    silent = true,
  })

  -- restore focus
  if vim.api.nvim_win_is_valid(source_win) then
    vim.api.nvim_set_current_win(source_win)
  end
end

local function toggle_git_graph()
  if is_graph_open() then
    close_git_graph()
  else
    open_git_graph()
  end
end

vim.keymap.set("n", "<leader>g", toggle_git_graph, { silent = true })

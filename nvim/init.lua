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
-- Git graph sidebar
-- ==================================================

local git_graph_win = nil
local git_graph_buf = nil
local GIT_GRAPH_WIDTH = 45

local function toggle_git_graph()
  -- If open → close
  if git_graph_win and vim.api.nvim_win_is_valid(git_graph_win) then
    vim.api.nvim_win_close(git_graph_win, true)
    git_graph_win = nil
    git_graph_buf = nil
    return
  end

  -- Only open inside a git repo
  if vim.fn.finddir(".git", ".;") == "" then
    vim.notify("Not a git repository", vim.log.levels.INFO)
    return
  end

  -- If focus is in nvim-tree, move to file window first
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end

  -- Open sidebar on the right
  vim.cmd("botright  vertical new")
  vim.cmd("setlocal winfixwidth")
  vim.cmd("vertical resize " .. GIT_GRAPH_WIDTH)

  git_graph_win = vim.api.nvim_get_current_win()

  -- Run git graph
  vim.cmd("Git log --graph --oneline --decorate --all")


  git_graph_buf = vim.api.nvim_get_current_buf()

  -- Sidebar behavior
  vim.bo[git_graph_buf].buflisted = false
  vim.bo[git_graph_buf].swapfile = false
  vim.bo[git_graph_buf].filetype = "gitgraph"

  vim.opt_local.wrap = false
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.cursorline = false

  -- Close with q (like tree plugins)
  vim.keymap.set("n", "q", function()
    if git_graph_win and vim.api.nvim_win_is_valid(git_graph_win) then
      vim.api.nvim_win_close(git_graph_win, true)
      git_graph_win = nil
      git_graph_buf = nil
    end
  end, { buffer = git_graph_buf, silent = true })

  -- Return focus to file window
  vim.cmd("wincmd l")
end

-- Keybinding (matches tree mental model)
vim.keymap.set("n", "<leader>g", toggle_git_graph, { silent = true })


-- ==================================================
-- lazy.nvim bootstrap
-- ==================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- ==================================================
-- Plugins
-- ==================================================

require("lazy").setup({

  -- ==================================================
  -- Theme
  -- ==================================================

  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
  },

  -- ==================================================
  -- File tree
  -- ==================================================

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },

    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
        renderer = {
          group_empty = true,
          add_trailing = true,
          indent_markers = {
            enable = false,
          },
          icons = {
            show = {
              file = false,
              folder = false,
              folder_arrow = false,
              git = false,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
        update_focused_file = {
          enable = false,
        },
        sync_root_with_cwd = false,
        git = {
          enable = false,
        },
        filesystem_watchers = {
          enable = true,
        },
      })

      -- Toggle tree
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })

      -- Focus tree
      vim.keymap.set("n", "<leader>f", function()
        require("nvim-tree.api").tree.focus()
      end, { silent = true })

      -- Auto-open tree on startup
      local augroup =
        vim.api.nvim_create_augroup("NvimTreeStartup", { clear = true })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        callback = function(data)
          local is_file = vim.fn.filereadable(data.file) == 1
          local is_dir = vim.fn.isdirectory(data.file) == 1

          if is_dir then
            vim.cmd.cd(data.file)
            require("nvim-tree.api").tree.open()
          elseif is_file then
            require("nvim-tree.api").tree.open({ focus = false })
          end
        end,
      })

      -- Tree window performance tweaks
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "NvimTree",
        callback = function()
          vim.opt_local.cursorline = false
          vim.opt_local.signcolumn = "no"
        end,
      })
    end,
  },

})

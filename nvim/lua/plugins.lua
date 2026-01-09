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
  -- Git Graph integration
  -- ==================================================

  {
  "tpope/vim-fugitive",
  cmd = { "Git", "Glog" },
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
          width = 15,
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
        update_focused_file = {
          enable = true,
          update_root = false,
        },
        filters = {
          dotfiles = false,
        },
        sync_root_with_cwd = false,
        git = {
          enable = false,
        },
        filesystem_watchers = {
          enable = true,
        },
      })

      -- Keymaps
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
      vim.keymap.set("n", "<leader>f", function()
        require("nvim-tree.api").tree.focus()
      end, { silent = true })

      -- Performance tweaks
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

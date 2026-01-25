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
      local api = require("nvim-tree.api")

      require("nvim-tree").setup({
        view = {
          width = 30,
        },

        on_attach = function(bufnr)
          local function open_node()
            local node = api.tree.get_node_under_cursor()
            if not node or node.type ~= "file" then
              return
            end

            if vim.bo.modified then
              vim.cmd("tabedit " .. vim.fn.fnameescape(node.absolute_path))
            else
              vim.cmd("edit " .. vim.fn.fnameescape(node.absolute_path))
            end
          end

          vim.keymap.set("n", "<CR>", open_node, {
            buffer = bufnr,
            silent = true,
            nowait = true,
          })
        end,

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
      
      local function only_nvimtree_open()
        local wins = vim.api.nvim_list_wins()
        if #wins ~= 1 then
          return false
        end

        local buf = vim.api.nvim_win_get_buf(wins[1])
        return vim.bo[buf].filetype == "NvimTree"
      end

      vim.keymap.set("n", "<leader>e", function()
        if only_nvimtree_open() then
          return
        end
        vim.cmd("NvimTreeToggle")
      end, { silent = true })

      vim.keymap.set("n", "<leader>f", function()
        api.tree.focus()
      end, { silent = true })

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
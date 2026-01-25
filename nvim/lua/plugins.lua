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
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
  },

  -- ==================================================
  -- BUFFERLINE
  -- ==================================================

  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          always_show_bufferline = false,
          separator_style = "slant",
          diagnostics = false,
          close_command = "bdelete %d",
          right_mouse_command = "bdelete %d",
          custom_filter = function(bufnr)
            return vim.bo[bufnr].buftype ~= "terminal"
          end,
        },
      })
    end,
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
          adaptive_size = false,
        },

        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = false,
            window_picker = {
              enable = false,
            },
          },
        },

        on_attach = function(bufnr)
          local function open_node()
            local node = api.tree.get_node_under_cursor()
            if not node or node.type ~= "file" then
              return
            end

            vim.cmd("edit " .. vim.fn.fnameescape(node.absolute_path))
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
          icons = { show = { file=false, folder=false, folder_arrow=false, git=false } },
        },

        update_focused_file = { enable = true },
        filters = { dotfiles = false },
        git = { enable = false },
      })

      -- Lock NvimTree window width
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "NvimTree",
        callback = function()
          vim.opt_local.winfixwidth = true
        end,
      })

      -- Re-lock NvimTree width after first file open
      vim.api.nvim_create_autocmd("BufWinEnter", {
        callback = function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "NvimTree" then
              vim.api.nvim_win_set_width(win, 30)
              vim.api.nvim_win_set_option(win, "winfixwidth", true)
            end
          end
        end,
      })

      -- Existing keymaps (unchanged)
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
      vim.keymap.set("n", "<leader>f", function() api.tree.focus() end, { silent = true })
    end,
  },

})
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
          always_show_bufferline = true,
          separator_style = { "|", "|" },
          diagnostics = false,
          close_command = "bdelete %d",
          right_mouse_command = "bdelete %d",
          show_buffer_icons = false,
          show_buffer_close_icons = true,
          show_close_icon = true,
          buffer_close_icon = " x ",
          close_icon = " x ",
          modified_icon = " * ",
          left_trunc_marker = "<",
          right_trunc_marker = ">",

          offsets = {
            {
              filetype = "NvimTree",
              text = "",
              highlight = "BufferLineFill",
              separator = false,
            },
          },

          custom_filter = function(bufnr)
            return vim.bo[bufnr].buftype ~= "terminal"
          end,
        },
      })
    end,
  },

  -- ==================================================
  -- LUALINE
  -- ==================================================

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local NORMAL = "#ff7500"
      local INSERT = "#ff7500"
      local VISUAL = "#ff7500"
      local REPLACE = "#ff7500"
      local COMMAND = "#ff7500"
      local FG      = "#abb2bf"
      local BG      = "#2c323c"
      local BG_DARK = "#21252b"

      require("lualine").setup({
        options = {
          globalstatus = true,
          icons_enabled = false,
          section_separators = "",
          component_separators = "",
          theme = {
            normal = {
              a = { fg = BG_DARK, bg = NORMAL, gui = "bold" },
              b = { fg = FG, bg = BG },
              c = { fg = FG, bg = BG_DARK },
            },
            insert = {
              a = { fg = BG_DARK, bg = INSERT, gui = "bold" },
            },
            visual = {
              a = { fg = BG_DARK, bg = VISUAL, gui = "bold" },
            },
            replace = {
              a = { fg = BG_DARK, bg = REPLACE, gui = "bold" },
            },
            command = {
              a = { fg = BG_DARK, bg = COMMAND, gui = "bold" },
            },
            inactive = {
              a = { fg = FG, bg = BG_DARK },
              b = { fg = FG, bg = BG_DARK },
              c = { fg = FG, bg = BG_DARK },
            },
          },
        },

        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = {
                modified = " [+]",
                readonly = " [RO]",
                unnamed = "",
              },
            },
          },
          lualine_x = { "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },

        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
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
            if not node then
              return
            end

            if node.type == "directory" then
              api.node.open.edit()
              return
            end

            if node.type == "file" then
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
          icons = {
            webdev_colors = false,
            git_placement = "after",
            show = {
              file = false,
              folder = false,
              folder_arrow = false,
              git = false,
            },
            glyphs = {
              default = " ",
              symlink = "@",

              folder = {
                default = ">",
                open = "v",
                empty = ">",
                empty_open = "v",
                symlink = ">@",
                symlink_open = "v@",
                arrow_open = "v",
                arrow_closed = ">",
              },

              git = {
                unstaged = "~",
                staged = "+",
                unmerged = "!",
                renamed = ">",
                untracked = "?",
                deleted = "x",
                ignored = ".",
              },
            },
          },
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
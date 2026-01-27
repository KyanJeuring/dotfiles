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
      local FG_LIGHT = "#d7dae0"
      local FG_DARK  = "#1e222a"
      local BG_DARK  = "#21252b"

      require("lualine").setup({
        options = {
          globalstatus = true,
          icons_enabled = false,
          section_separators = "",
          component_separators = "",
          theme = {
            normal = {
              a = { fg = FG_LIGHT, bg = BG_DARK },
              b = { fg = FG_LIGHT, bg = BG_DARK },
              c = { fg = FG_LIGHT, bg = BG_DARK },
            },
            inactive = {
              a = { fg = "#7f848e", bg = BG_DARK },
              b = { fg = "#7f848e", bg = BG_DARK },
              c = { fg = "#7f848e", bg = BG_DARK },
            },
          },
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(mode)
                return " " .. mode .. " "
              end,
              color = function()
                local mode = vim.fn.mode()
                local colors = {
                  n = { bg = "#21252b", fg = "#abb2bf" }, -- NORMAL
                  i = { bg = "#ff7700", fg = FG_DARK },     -- INSERT
                  v = { bg = "#61afef", fg = FG_DARK },     -- VISUAL
                  V = { bg = "#61afef", fg = FG_DARK },
                  ["\22"] = { bg = "#61afef", fg = FG_DARK },
                  R = { bg = "#e06c75", fg = FG_DARK },     -- REPLACE
                  c = { bg = "#98c379", fg = FG_DARK },     -- COMMAND
                  t = { bg = "#e5c07b", fg = FG_DARK },     -- TERMINAL
                }
                return colors[mode] or { bg = "#21252b", fg = "#abb2bf" }
              end,
            },
          },
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
          local api = require("nvim-tree.api")

          local function edit_no_split(fn)
            return function(...)
              local old = vim.o.splitkeep
              vim.o.splitkeep = "screen"
              fn(...)
              vim.schedule(function()
                vim.o.splitkeep = old
              end)
            end
          end

          api.config.mappings.default_on_attach(bufnr)

          vim.keymap.set("n", "<CR>", edit_no_split(api.node.open.edit), { buffer = bufnr })
          vim.keymap.set("n", "o",    edit_no_split(api.node.open.edit), { buffer = bufnr })
        end

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

        update_focused_file = {
          enable = true,
          update_root = false,
        },
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

      -- Existing keymaps (unchanged)
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
      vim.keymap.set("n", "<leader>f", function() api.tree.focus() end, { silent = true })
    end,
  },

})
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
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })

      -- Toggle tree
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })

      -- Focus tree
      vim.keymap.set("n", "<leader>f", function()
        require("nvim-tree.api").tree.focus()
      end, { silent = true })

      -- ==================================================
      -- Auto-open tree on startup
      -- ==================================================

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
    end,
  },
})

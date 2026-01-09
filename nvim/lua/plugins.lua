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

            -- Keybind: <leader>e to toggle tree
            vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })

            -- ==================================================
            -- Auto-open tree on startup
            -- ==================================================

            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function(data)
                    -- Buffer is a file
                    local is_file = vim.fn.filereadable(data.file) == 1
                    -- Buffer is a directory
                    local is_dir = vim.fn.isdirectory(data.file) == 1

                    if is_dir then
                    -- Change to the directory and open tree
                    vim.cmd.cd(data.file)
                    require("nvim-tree.api").tree.open()
                    elseif is_file then
                    -- Open tree but keep focus on file
                    require("nvim-tree.api").tree.open({ focus = false })
                    end
                end,
            })
        end,
    },

})

--open telescope on startup
vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
        if vim.fn.argv(0) == "" then
            require('telescope.builtin').find_files()
        end
    end,
})

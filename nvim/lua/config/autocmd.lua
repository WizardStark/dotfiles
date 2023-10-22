--open telescope on startup
vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
        if vim.fn.argv(0) == "" then
            require('telescope.builtin').find_files()
        end
    end,
})

--autoformat on save
vim.api.nvim_create_autocmd('BufWritePre', {
    callback = function()
        if vim.bo.filetype == 'json' then
            return
        elseif vim.bo.filetype == 'python' then
            return
        end
        vim.lsp.buf.format()
    end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { "*.py" },
    command = [[ !ufmt format % ]]
})

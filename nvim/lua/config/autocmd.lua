vim.api.nvim_create_autocmd('VimEnter', {
	callback = function()
		if vim.fn.argv(0) == "" then
			require('telescope.builtin').find_files()
		end
	end,
})

vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function()
    vim.lsp.buf.format()
  end,
})

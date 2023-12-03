--open telescope on startup
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		if vim.fn.argv(0) == "" then
			require("telescope.builtin").find_files()
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function(opts)
		vim.opt.wrap = false
	end,
})

--terminal
function _G.set_terminal_keymaps()
	require("legendary").keymaps({
		{ mode = "t", "<esc>", [[<C-\><C-n>]], { buffer = 0 }, description = "Exit insert mode in terminal" },
		{ mode = "t", "jf", [[<C-\><C-n>]], { buffer = 0 }, description = "Exit insert mode in terminal" },
		{ mode = "t", "<C-h>", [[<Cmd>wincmd h<CR>]], { buffer = 0 }, description = "Move left from terminal" },
		{ mode = "t", "<C-j>", [[<Cmd>wincmd j<CR>]], { buffer = 0 }, description = "Move down from terminal" },
		{ mode = "t", "<C-k>", [[<Cmd>wincmd k<CR>]], { buffer = 0 }, description = "Move up from terminal" },
		{ mode = "t", "<C-l>", [[<Cmd>wincmd l<CR>]], { buffer = 0 }, description = "Move right from terminal" },
	})
end

vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "term://*",
	callback = function(opts)
		set_terminal_keymaps()
	end,
})

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

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = ".bib",
	callback = function(opts)
		vim.cmd([[!bibtex main]])
	end,
})

local user_session_manager_group = vim.api.nvim_create_augroup("UserSessionManager", {})
local session_manager = require("session_manager")

vim.api.nvim_create_autocmd({ "VimEnter" }, {
	group = user_session_manager_group,
	nested = true,
	callback = function()
		if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
			local ok, _ = pcall(session_manager.load_current_dir_session, true)
			if not ok then
				vim.notify("Session corrupted, deleting")
				vim.cmd([[:SessionManager delete_current_dir_session<CR>]])
			end
		end
	end,
})

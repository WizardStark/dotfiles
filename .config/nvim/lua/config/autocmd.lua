local function is_restorable(buffer)
	if #vim.api.nvim_buf_get_option(buffer, "bufhidden") ~= 0 then
		return false
	end

	local buftype = vim.api.nvim_buf_get_option(buffer, "buftype")
	if #buftype == 0 then
		-- Normal buffer, check if it listed.
		if not vim.api.nvim_buf_get_option(buffer, "buflisted") then
			return false
		end
		-- Check if it has a filename.
		if #vim.api.nvim_buf_get_name(buffer) == 0 then
			return false
		end
	elseif buftype ~= "terminal" and buftype ~= "help" then
		-- Buffers other then normal, terminal and help are impossible to restore.
		return false
	end
end

local function is_restorable_buffer_present()
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buffer) and is_restorable(buffer) then
			return true
		end
	end
	return false
end

require("legendary").autocmds({
	{
		"FileType",
		opts = {
			pattern = "markdown",
		},
		function()
			vim.opt.wrap = false
		end,
	},
	{
		"BufWritePost",
		opts = {
			pattern = "*.bib",
		},
		function()
			vim.cmd([[!bibtex main]])
		end,
	},
	{
		name = "UserSessionManager",
		clear = true,
		{
			"VimEnter",
			opts = {
				nested = true,
			},
			function()
				if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
					local ok, _ = pcall(require("session_manager").load_current_dir_session, true)
					if not ok then
						vim.notify("Session corrupted, deleting")
						vim.cmd([[:SessionManager delete_current_dir_session<CR>]])
					end
				end
			end,
		},
		{
			"VimLeavePre",
			function()
				if is_restorable_buffer_present() then
					if string.find(vim.fn.expand("%:p"), vim.fn.getcwd()) then
						require("session_manager").save_current_session()
					end
				end
			end,
		},
	},
})

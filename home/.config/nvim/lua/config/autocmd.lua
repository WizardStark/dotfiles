local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local autocmds = require("legendary").autocmds

prefixifier(autocmds)({
	{
		"BufEnter",
		function()
			if not vim.g.workspaces_loaded then
				if next(vim.fn.argv()) == nil then
					vim.g.workspaces_loaded = true
					local is_floating_win = vim.api.nvim_win_get_config(0).relative ~= ""
					if is_floating_win then
						vim.cmd.wincmd({ args = { "w" }, count = 1 })
					end

					require("workspaces.persistence").load_workspaces()
					require("workspaces.workspaces").setup_lualine()
					vim.cmd.stopinsert()
				else
					require("lualine")
				end
			end
		end,
		prefix = P.auto,
	},
	{
		"BufEnter",
		opts = {
			pattern = { "*.zsh-theme", "*.zshrc", "*.zshenv", "*.zprofile" },
		},
		function()
			vim.cmd("setfiletype zsh")
		end,
		prefix = P.auto,
	},
	{
		"FileType",
		opts = {
			pattern = "markdown",
		},
		function()
			vim.opt.wrap = false
		end,
		prefix = P.auto,
	},
	{
		"BufWritePost",
		opts = {
			pattern = "*.bib",
		},
		function()
			vim.cmd("!bibtex main")
		end,
		prefix = P.auto,
	},
	{
		"BufWinEnter",
		function()
			if vim.bo.bt == "terminal" then
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
			end
			if vim.bo.ft == "help" then
				vim.cmd("wincmd L")
			end
		end,
		prefix = P.auto,
	},
	{
		"TermOpen",
		function()
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
			vim.cmd.startinsert()
		end,
		prefix = P.auto,
	},
	{
		"QuitPre",
		function()
			local terms = require("toggleterm.terminal").get_all()
			for _, term in ipairs(terms) do
				if vim.fn.win_id2win(term.window) == vim.fn.winnr() then
					local session_terms = require("workspaces.toggleterms").get_session_terms()
					for _, value in ipairs(session_terms) do
						if value.global_id == term.id then
							require("workspaces.toggleterms").delete_term(value.local_id)
						end
					end
				end
			end
		end,
		prefix = P.auto,
	},
	{
		"BufAdd",
		function(event)
			vim.notify("Adding buffer")
			if vim.bo.ft == "minifiles" then
				vim.notify("In minifiles buffer")
			end
			vim.notify(vim.inspect(event))
		end,
		prefix = P.auto,
	},
	{
		name = "UserMiniFiles",
		{
			"User",
			opts = {
				pattern = { "MiniFilesBufferUpdate" },
			},
			function(args)
				local bufnr = args.data.buf_id
				local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
				local utils = require("utils")
				local gitStatusCache = utils.getStatusCache()
				if gitStatusCache[git_root] then
					utils.updateMiniWithGit(bufnr, gitStatusCache[git_root].statusMap)
				end
			end,
		},
		{
			"User",
			opts = {
				pattern = "MiniFilesExplorerClose",
			},
			function()
				require("utils").clearCache()
			end,
		},
		{
			"User",
			opts = {
				pattern = "MiniFilesExplorerOpen",
			},
			function()
				local bufnr = vim.api.nvim_get_current_buf()
				require("utils").updateGitStatus(bufnr)
			end,
		},
		{
			"User",
			opts = {
				pattern = "MiniFilesWindowOpen",
			},
			function(args)
				local win_id = args.data.win_id
				vim.api.nvim_win_set_config(win_id, { border = "rounded" })
			end,
			prefix = P.auto,
		},
		{
			"User",
			opts = {
				pattern = "MiniFilesBufferCreate",
			},
			function(args)
				local MiniFiles = require("mini.files")
				local buf_id = args.data.buf_id
				local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
				vim.keymap.set("n", "h", function()
					MiniFiles.go_out()
					MiniFiles.go_out()
					MiniFiles.go_in({})
					local utils = require("utils")
					local gitStatusCache = utils.getStatusCache()
					if gitStatusCache[git_root] then
						require("utils").updateMiniWithGit(buf_id, gitStatusCache[git_root].statusMap)
					end
				end, { buffer = buf_id })

				vim.keymap.set("n", "<CR>", function()
					MiniFiles.go_in({ close_on_file = true })
				end, { buffer = buf_id })

				vim.keymap.set("n", "<leader>scs", function()
					local fs_entry = MiniFiles.get_fs_entry()

					if not fs_entry then
						vim.notify("Cannot identify filesystem entry")
						return
					end

					if fs_entry.fs_type == "directory" then
						MiniFiles.close()
						require("workspaces.workspaces").create_session(fs_entry.name, fs_entry.path)
					else
						MiniFiles.close()
						vim.notify("File selected, creating session from parent directory")
						local split_path = vim.split(fs_entry.path, "/")
						table.remove(split_path)
						local new_path = table.concat(split_path, "/")
						require("workspaces.workspaces").create_session(fs_entry.name, new_path)
					end
				end, { buffer = buf_id })

				vim.keymap.set("n", "<leader>scw", function()
					local fs_entry = MiniFiles.get_fs_entry()

					if not fs_entry then
						vim.notify("Cannot identify filesystem entry")
						return
					end

					if fs_entry.fs_type == "directory" then
						MiniFiles.close()
						require("workspaces.workspaces").create_workspace(fs_entry.name, fs_entry.name, fs_entry.path)
						vim.notify("Workspace created")
					else
						MiniFiles.close()
						vim.notify("File selected, creating workspace from parent directory")
						local split_path = vim.split(fs_entry.path, "/")
						table.remove(split_path)
						local new_path = table.concat(split_path, "/")
						require("workspaces.workspaces").create_workspace(fs_entry.name, fs_entry.name, new_path)
						vim.notify("Workspace created")
					end
				end, { buffer = buf_id })
			end,
			prefix = P.auto,
		},
	},
	{
		"QuickFixCmdPost",
		function()
			require("trouble").toggle("quickfix")
		end,
		prefix = P.auto,
	},
	{
		"User",
		opts = {
			pattern = "LazyReload",
		},
		function()
			if vim.g.workspaces_loaded then
				require("workspaces.workspaces").setup_lualine()
			end
		end,
		prefix = P.auto,
	},
	{
		"VimLeavePre",
		function()
			if vim.g.workspaces_loaded then
				local state = require("workspaces.state")
				local persist = require("workspaces.persistence")
				local current_session = state.get().current_session
				persist.write_nvim_session_file(state.get().current_workspace, current_session)
				local toggled_types = require("utils").toggle_special_buffers({})
				M.set_session_metadata(current_session, toggled_types)
				persist.persist_workspaces()
			end
		end,
		prefix = P.auto,
	},
})

return {}

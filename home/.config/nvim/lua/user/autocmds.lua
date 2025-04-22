local last_refreshed_time = nil

local mappings = {
	{
		event = "BufEnter",
		callback = function()
			if vim.g.workspaces_loaded then
				require("workspaces.marks").clear_marks()
				require("workspaces.marks").display_marks()
			end
		end,
	},
	{
		event = { "BufEnter", "BufWritePost" },
		callback = function()
			vim.lsp.codelens.refresh({ bufnr = 0 })
			last_refreshed_time = vim.loop.now()
		end,
	},
	{
		event = "InsertLeave",
		callback = function()
			if last_refreshed_time == nil or vim.loop.now() - last_refreshed_time > 15000 then
				vim.lsp.codelens.refresh({ bufnr = 0 })
				last_refreshed_time = vim.loop.now()
			end
		end,
	},
	{
		event = "BufEnter",
		pattern = { "*.zsh-theme", "*.zshrc", "*.zshenv", "*.zprofile" },
		callback = function()
			vim.cmd("setfiletype zsh")
		end,
	},
	{
		event = "BufWinEnter",
		callback = function()
			if vim.bo.bt == "terminal" then
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
			end
			if vim.bo.ft == "help" then
				vim.cmd("wincmd L")
			end
		end,
	},
	{
		event = "WinClosed",
		callback = function()
			if vim.g.backdrop_buf then
				require("user.utils").close_backdrop_window()
			end
		end,
	},
	{
		event = "FileType",
		pattern = "markdown",
		callback = function()
			vim.opt.wrap = false
		end,
	},
	{
		event = "BufWritePost",
		pattern = "*.bib",
		callback = function()
			vim.cmd("!bibtex main")
		end,
	},
	{
		event = "TermOpen",
		callback = function()
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
		end,
	},
	{
		event = "QuitPre",
		callback = function()
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
	},
	{
		event = "User",
		pattern = "MiniFilesWindowOpen",
		callback = function(args)
			if not vim.g.backdrop_buf then
				require("user.utils").create_backdrop_window()
			end
		end,
	},
	{
		event = "User",
		pattern = "MiniFilesActionRename",
		callback = function(event)
			require("snacks").rename.on_rename_file(event.data.from, event.data.to)
		end,
	},
	{
		event = "User",
		pattern = "MiniFilesBufferCreate",
		callback = function(args)
			local MiniFiles = require("mini.files")
			local buf_id = args.data.buf_id
			vim.keymap.set("n", "h", function()
				MiniFiles.go_out()
				MiniFiles.go_out()
				MiniFiles.go_in({})
			end, { buffer = buf_id })

			vim.keymap.set("n", "<esc>", function()
				MiniFiles.close()
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
	},
	{
		event = "QuickFixCmdPost",
		callback = function()
			require("trouble").open("qflist")
		end,
	},
	{
		event = "User",
		pattern = "LazyReload",
		callback = function()
			if vim.g.workspaces_loaded then
				require("workspaces.workspaces").setup_lualine()
			end
		end,
	},
	{
		event = "VimLeave",
		callback = function()
			if vim.g.workspaces_loaded then
				local state = require("workspaces.state")
				local persist = require("workspaces.persistence")
				local workspaces = require("workspaces.workspaces")
				local current_session = state.get().current_session
				persist.write_nvim_session_file(state.get().current_workspace, current_session)
				local toggled_types = require("user.utils").toggle_special_buffers({})
				workspaces.set_session_metadata(current_session, toggled_types)
				persist.persist_workspaces()
			end
		end,
	},
}

return {
	setup = function()
		for _, cmd in ipairs(mappings) do
			vim.api.nvim_create_autocmd(cmd.event, {
				pattern = cmd.pattern and cmd.pattern or nil,
				callback = cmd.callback,
			})
		end
	end,
}

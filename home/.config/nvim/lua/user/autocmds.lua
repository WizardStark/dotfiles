local toggled_terms = false

local function fold_virt_text(result, s, lnum, coloff)
	if not coloff then
		coloff = 0
	end
	local text = ""
	local hl
	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local _hl = hls[#hls]
		if _hl then
			local new_hl = "@" .. _hl.capture
			if new_hl ~= hl then
				table.insert(result, { text, hl })
				text = ""
				hl = nil
			end
			text = text .. char
			hl = new_hl
		else
			text = text .. char
		end
	end
	table.insert(result, { text, hl })
end

local function custom_foldtext()
	local start = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop))
	local end_str = vim.fn.getline(vim.v.foldend)
	local end_ = vim.trim(end_str)
	local result = {}
	fold_virt_text(result, start, vim.v.foldstart - 1)
	table.insert(result, { " " .. tostring(vim.v.foldend - vim.v.foldstart) .. " lines ", "Delimiter" })
	fold_virt_text(result, end_, vim.v.foldend - 1, #(end_str:match("^(%s+)") or ""))
	return result
end

local mappings = {
	{
		event = "BufEnter",
		pattern = { "*.zsh-theme", "*.zshrc", "*.zshenv", "*.zprofile" },
		callback = function()
			vim.cmd("setfiletype zsh")
		end,
	},
	{
		event = "BufEnter",
		pattern = { "octo://*" },
		callback = function()
			if vim.wo.diff then
				vim.wo.foldenable = false
			end
		end,
	},
	{
		event = "BufWinEnter",
		callback = function()
			if vim.bo.bt == "terminal" then
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
				vim.bo.buflisted = false
			end
			if vim.bo.ft == "help" then
				vim.cmd("wincmd L")
			end
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
		event = "FileType",
		pattern = { "dap-float" },
		callback = function(e)
			vim.keymap.set("n", "q", "<C-w>q", { buffer = e.buf })
			vim.keymap.set("n", "<Esc>", "<C-w>q", { buffer = e.buf })
		end,
	},
	{
		event = "BufWinEnter",
		pattern = { "COMMIT_EDITMSG", "git-rebase-todo" },
		callback = function()
			vim.bo.bufhidden = "delete"
			if not toggled_terms then
				toggled_terms = true
				vim.defer_fn(function()
					require("workspaces.toggleterms").close_visible_terms(true)
				end, 100)
			end
		end,
	},
	{
		event = "BufLeave",
		pattern = { "COMMIT_EDITMSG", "git-rebase-todo" },
		callback = function()
			toggled_terms = false
			vim.defer_fn(function()
				require("workspaces.toggleterms").toggle_active_terms(true)
			end, 100)
		end,
	},
	{
		event = "FileType",
		callback = function(args)
			vim.opt.foldcolumn = "0"

			if require("user.utils").is_big_file(args.buf) then
				return
			end

			local buf = args.buf
			local filetype = args.match

			local language = vim.treesitter.language.get_lang(filetype) or filetype
			if not vim.treesitter.language.add(language) then
				return
			end

			vim.wo.foldmethod = "expr"
			vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
			vim.wo.foldtext = "v:lua.custom_foldtext()"
			vim.wo.foldenable = true
			vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			vim.treesitter.start(buf, language)
		end,
	},
	{
		event = "TextYankPost",
		callback = function()
			vim.hl.on_yank({ higroup = "Visual", timeout = 200 })
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
			if not package.loaded["toggleterm"] and not package.loaded["toggleterm.terminal"] then
				return
			end

			if not package.loaded["workspaces.toggleterms"] then
				return
			end

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
				MiniFiles.go_in()
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
		event = "DirChangedPre",
		callback = function()
			require("config.editor.opencode").reset_manual_server_override()
		end,
	},
	{
		event = { "BufEnter", "FocusGained", "DirChanged" },
		callback = function()
			if vim.g.workspaces_loaded then
				require("workspaces.workspaces").refresh_current_session_targets(false)
			end
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
				local current_target = workspaces.get_current_target()
				persist.write_nvim_session_file(state.get().current_workspace, current_session, current_target)
				local toggled_types = require("user.utils").toggle_special_buffers({})
				workspaces.set_session_metadata(current_session, current_target, toggled_types)
				persist.persist_workspaces()
			end
		end,
	},
	{
		event = "FileType",
		pattern = "dart",
		callback = function()
			vim.opt_local.tabstop = 2
			vim.opt_local.shiftwidth = 2
			vim.opt_local.softtabstop = 2
			vim.opt_local.expandtab = true
		end,
	},
}

return {
	setup = function()
		_G.custom_foldtext = custom_foldtext
		for _, cmd in ipairs(mappings) do
			vim.api.nvim_create_autocmd(cmd.event, {
				pattern = cmd.pattern and cmd.pattern or nil,
				callback = cmd.callback,
			})
		end
	end,
}

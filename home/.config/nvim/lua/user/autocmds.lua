local last_refreshed_time = nil

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

function _G.custom_foldtext()
	local start = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop))
	local end_str = vim.fn.getline(vim.v.foldend)
	local end_ = vim.trim(end_str)
	local result = {}
	fold_virt_text(result, start, vim.v.foldstart - 1)
	table.insert(result, { " " .. tostring(vim.v.foldend - vim.v.foldstart) .. " lines ", "Delimiter" })
	fold_virt_text(result, end_, vim.v.foldend - 1, #(end_str:match("^(%s+)") or ""))
	return result
end

local imb = function()
	vim.schedule(function()
		local kernels = vim.fn.MoltenAvailableKernels()
		local cwd = vim.fn.getcwd()
		local function escape_lua_patterns(s)
			return s:gsub("([^%w])", "%%%1")
		end

		local kernel_name = nil

		for _, kernel in ipairs(kernels) do
			if cwd:find(escape_lua_patterns(kernel)) then
				kernel_name = kernel
				break
			end
		end

		if kernel_name ~= nil and vim.tbl_contains(kernels, kernel_name) then
			vim.cmd(("MoltenInit %s"):format(kernel_name))
		end
		vim.cmd("MoltenImportOutput")
	end)
end

local mappings = {
	{
		event = "BufAdd",
		pattern = { "*.ipynb" },
		callback = imb,
	},
	{
		event = "BufEnter",
		pattern = { "*.ipynb" },
		callback = function()
			if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
				imb()
			end
		end,
	},
	{
		event = "BufEnter",
		pattern = "*.py",
		callback = function(e)
			if string.match(e.file, ".otter.") then
				return
			end
			if require("molten.status").initialized() == "Molten" then
				vim.fn.MoltenUpdateOption("virt_lines_off_by_1", false)
				vim.fn.MoltenUpdateOption("virt_text_output", false)
			else
				vim.g.molten_virt_lines_off_by_1 = false
				vim.g.molten_virt_text_output = false
			end
		end,
	},
	{
		event = "BufEnter",
		pattern = { "*.qmd", "*.md", "*.ipynb" },
		callback = function(e)
			if string.match(e.file, ".otter.") then
				return
			end
			if require("molten.status").initialized() == "Molten" then
				vim.fn.MoltenUpdateOption("virt_lines_off_by_1", true)
				vim.fn.MoltenUpdateOption("virt_text_output", true)
			else
				vim.g.molten_virt_lines_off_by_1 = true
				vim.g.molten_virt_text_output = true
			end
		end,
	},
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
			end
			if vim.bo.ft == "help" then
				vim.cmd("wincmd L")
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
		event = "BufWritePost",
		pattern = "*.bib",
		callback = function()
			vim.cmd("!bibtex main")
		end,
	},
	{
		event = "BufWritePost",
		pattern = { "*.ipynb" },
		callback = function()
			if require("molten.status").initialized() == "Molten" then
				vim.cmd("MoltenExportOutput!")
			end
		end,
	},
	{
		event = "FileType",
		pattern = "markdown",
		callback = function()
			vim.opt.wrap = false
			require("quarto").activate()
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
		event = "FileType",
		callback = function()
			vim.opt.foldcolumn = "0"
			vim.opt.foldmethod = "expr"
			vim.opt.foldtext = "v:lua.custom_foldtext()"
			vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
			vim.opt.foldenable = true
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
		event = "WinClosed",
		callback = function()
			if vim.g.backdrop_buf then
				require("user.utils").close_backdrop_window()
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

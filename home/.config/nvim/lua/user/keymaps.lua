local function trigger_dap(dapStart)
	require("dapui").open({ reset = true })
	dapStart()
end

local function continue()
	if require("dap").session() then
		require("dap").continue()
	else
		require("dapui").open({ reset = true })
		require("dap").continue()
	end
end

-- find all URLs in buffer
local function save_and_exit()
	local buflist = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(buflist) do
		if vim.bo[bufnr].bt == "terminal" then
			vim.cmd("bd! " .. tostring(bufnr))
		end
	end
	vim.cmd.xa()
end

local function is_detached_head()
	return vim.fn.system("git branch --show-current") == ""
end

local function open_in_non_dap_window(file, line)
	local wins = vim.api.nvim_list_wins()

	local target_win = nil
	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.bo[buf].filetype
		if not ft:match("dap") then
			target_win = win
			break
		end
	end

	if not target_win then
		vim.cmd("botright vnew")
		target_win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(target_win)
	vim.cmd("edit " .. file)
	if line then
		vim.api.nvim_win_set_cursor(0, { line, 0 })
	end
end

local original_branch = nil

local history_picker = function()
	Snacks.picker.pick(
		---@type snacks.picker.Config
		{
			source = "history_picker",
			finder = function()
				local items = {} ---@type snacks.picker.finder.Item

				for _, picker_opts in ipairs(Snacks_picker_hist) do
					---@cast picker_opts snacks.picker.Config
					local source = picker_opts.source and picker_opts.source or "unknown source"
					local pattern = picker_opts.pattern and picker_opts.pattern or ""
					local search = picker_opts.search and picker_opts.search or ""
					local text = source .. " | " .. pattern .. " > " .. search
					table.insert(items, {
						["data"] = { picker_opts = picker_opts },
						text = text,
					})
				end

				return items
			end,
			confirm = function(picker, item)
				picker:close()
				if item then
					local opts = item.data.picker_opts
					---@cast opts snacks.picker.Config

					local ret = Snacks.picker.pick(opts)
					ret.list:update()
					ret.input:update()
				end
			end,
			format = function(item, _)
				local ret = {}
				ret[#ret + 1] = { item.text }
				return ret
			end,
			layout = {
				preview = false,
				layout = {
					backdrop = {
						blend = 40,
					},
					width = 0.3,
					min_width = 80,
					max_height = 12,
					box = "vertical",
					border = "rounded",
					title = " Picker history ",
					title_pos = "center",
					{ win = "list", border = "none" },
					{ win = "input", height = 1, border = "top" },
				},
			},
		}
	)
end

local P = require("user.utils").PREFIXES

local mappings = {
	{
		mode = { "n", "v" },
		"<leader>Q",
		[[<CMD>qa! <CR>]],
		prefix = P.misc,
		description = "How to quit vim",
	},
	{
		mode = { "n", "v", "t" },
		"<D-v>",
		[["+p]],
		prefix = P.misc,
		description = "Paste with OS key",
	},
	{
		mode = { "i" },
		"<D-v>",
		[[<C-r>+]],
		prefix = P.misc,
		description = "Paste with OS key",
	},
	{
		mode = { "n", "v", "t" },
		"<C-v>",
		[["+p]],
		prefix = P.misc,
		description = "Paste with ctrl",
	},
	{
		mode = { "t" },
		"<S-BS>",
		"<BS>",
		prefix = P.misc,
		description = "Backspace in terminal when holding shift",
	},
	{
		mode = { "t" },
		"<C-BS>",
		"<BS>",
		prefix = P.misc,
		description = "Backspace in terminal when holding control",
	},
	{
		mode = { "n" },
		"<C-r>",
		"r",
		prefix = P.misc,
		description = "Replace one character",
	},
	{
		mode = { "i" },
		"<C-v>",
		[[<C-r>+]],
		prefix = P.misc,
		description = "Paste with ctrl",
	},
	{
		mode = { "n", "v" },
		"<leader>X",
		save_and_exit,
		prefix = P.misc,
		description = "How to save and quit vim",
	},
	{
		mode = { "n", "v" },
		"<leader>U",
		vim.cmd.wa,
		prefix = P.misc,
		description = "Write all open, modified buffers",
	},
	{
		mode = "n",
		"<esc>",
		function()
			vim.cmd.up()
			if vim.snippet.active() then
				vim.snippet.stop()
			end
			vim.schedule(function()
				vim.cmd("nohlsearch")
			end)
		end,
		prefix = P.misc,
		description = "Write buffer and stop snippet jumps",
	},
	{

		mode = "n",
		"gf",
		function()
			local text = vim.fn.expand("<cWORD>")

			local parts = vim.split(text, ":")
			local file = parts[1]
			local line = tonumber(parts[2])
			local col = tonumber(parts[3])

			if vim.fn.filereadable(file) == 1 then
				vim.cmd("edit " .. file)
				if line then
					if col then
						vim.api.nvim_win_set_cursor(0, { line, col - 1 })
					else
						vim.api.nvim_win_set_cursor(0, { line, 0 })
					end
				end
			else
				vim.cmd("normal! gf")
			end
		end,
		prefix = P.misc,
		description = "Go to file under cursor",
	},
	{
		mode = { "n" },
		"r",
		vim.cmd.redo,
		prefix = P.misc,
		description = "Redo",
	},
	{
		mode = { "n", "v" },
		"<leader>y",
		[["+y]],
		prefix = P.misc,
		description = "Copy/Yank to system clipboard",
	},
	{
		mode = { "n", "v" },
		"<leader>D",
		[["_d]],
		prefix = P.misc,
		description = "Delete without altering registers",
	},
	{
		mode = "n",
		"J",
		"mzJ`z",
		prefix = P.misc,
		description = "Join lines while maintaining cursor position",
	},
	{
		mode = "n",
		"j",
		"v:count ? 'j' : 'gj'",
		opts = { expr = true },
		prefix = P.misc,
		description = "Move down one line",
	},
	{
		mode = "n",
		"k",
		"v:count ? 'k' : 'gk'",
		opts = { expr = true },
		prefix = P.misc,
		description = "Move up one line",
	},
	{
		mode = "n",
		"<C-d>",
		"<C-d>zz",
		prefix = P.move,
		description = "Down half page and centre",
	},
	{
		mode = "n",
		"<C-u>",
		"<C-u>zz",
		prefix = P.move,
		description = "Up half page and centre",
	},
	{
		mode = "n",
		"n",
		"nzzzv",
		prefix = P.move,
		description = "Next occurrence of search and centre",
	},
	{
		mode = "n",
		"N",
		"Nzzzv",
		prefix = P.move,
		description = "Next occurrence of search and centre",
	},
	{
		mode = "v",
		"<leader>k",
		[[:s/\(.*\)/]],
		prefix = P.misc,
		description = "Initiate visual selection replace with selection as capture group 1",
	},
	{
		mode = "v",
		"<leader>uo",
		[[:s/\s\+/ /g | '<,'>s/\n/ /g | s/\s// | s/\s\+/ /g | s/\. /\.\r/g <CR>]],
		prefix = P.code,
		description = "Format one line per sentence",
	},
	{
		mode = "n",
		"<leader>a",
		"<C-^>",
		prefix = P.nav,
		description = "Alternate file",
	},
	{
		mode = { "n", "v", "i" },
		"<C-s>",
		vim.cmd.up,
		prefix = P.misc,
		description = "Save file",
	},
	{
		mode = "v",
		"<M-j>",
		":m '>+1<CR>gv=gv",
		prefix = P.misc,
		description = "Move visual selection one line down",
	},
	{
		mode = "v",
		"<M-k>",
		":m '<-2<CR>gv=gv",
		prefix = P.misc,
		description = "Move visual selection one line up",
	},
	{
		mode = "v",
		"<",
		"<gv",
		prefix = P.misc,
		description = "Move visual selection one indentation left",
	},
	{
		mode = "v",
		">",
		">gv",
		prefix = P.misc,
		description = "Move visual selection one indentation right",
	},
	{
		mode = { "n", "v" },
		"<leader>cp",
		function()
			local path = vim.fn.expand("%:p")
			vim.fn.setreg("+", path)
			vim.notify("Copied " .. path .. " to clipboard")
		end,
		prefix = P.misc,
		description = "Copy file path to clipboard",
	},
	{
		mode = "n",
		"zR",
		function()
			require("ufo").openAllFolds()
		end,
		prefix = P.fold,
		description = "Open all",
	},
	{
		mode = "n",
		"zM",
		function()
			require("ufo").closeAllFolds()
			vim.opt.foldlevel = 99
			vim.opt.foldlevelstart = 99
		end,
		prefix = P.fold,
		description = "Close all",
	},
	{
		mode = "n",
		"zr",
		function()
			require("ufo").openFoldsExceptKinds()
		end,
		prefix = P.fold,
		description = "Open all non-excluded",
	},
	{
		mode = "n",
		"zm",
		function()
			require("ufo").closeFoldsWith()
		end,
		prefix = P.fold,
		description = "Close folds with indentation level greater prefixed than number",
	},
	{
		mode = "n",
		"zP",
		function()
			require("ufo").peekFoldedLinesUnderCursor()
		end,
		prefix = P.fold,
		description = "Peek folded lines",
	},
	{
		mode = { "n" },
		"<leader>o",
		function()
			Snacks.picker.recent({ filter = { paths = { [vim.fn.getcwd()] = true } } })
		end,
		prefix = P.find,
		description = "Buffers in order of recent access",
	},
	{
		mode = { "n", "v", "o" },
		"<leader><leader>",
		function()
			require("legendary").find()
		end,
		prefix = P.misc,
		description = "Command palette",
	},
	-- {
	-- 	mode = "n",
	-- 	"<leader>ft",
	-- 	"<cmd>TodoTelescope<CR>",
	-- 	prefix = P.find,
	-- 	description = "TODOs, FIXs, NOTEs (etc) comments in cwd",
	-- },
	{
		mode = "n",
		"<leader>fg",
		function()
			Snacks.picker.grep()
		end,
		prefix = P.find,
		description = "Grep in cwd",
	},
	{
		mode = "n",
		"<leader>fd",
		function()
			Snacks.picker.git_status()
		end,
		prefix = P.find,
		description = "Changed files",
	},
	{
		mode = { "n", "x" },
		"<leader>fw",
		function()
			Snacks.picker.grep_word()
		end,
		prefix = P.find,
		description = "Word in cwd",
	},
	{
		mode = "n",
		"<leader>f/",
		function()
			Snacks.picker.lines()
		end,
		prefix = P.misc,
		description = "Fuzzy find in cwd",
	},
	{
		mode = "n",
		"<leader>f:",
		function()
			Snacks.picker.command_history()
		end,
		prefix = P.misc,
		description = "Show command history",
	},
	{
		mode = "n",
		"<leader>ff",
		function()
			Snacks.picker.files()
		end,
		prefix = P.find,
		description = "Files by filename in cwd",
	},
	{
		mode = "n",
		"<leader>fu",
		function()
			Snacks.picker.undo()
		end,
		prefix = P.misc,
		description = "Show change history (undotree)",
	},
	{
		mode = "n",
		"<leader>i",
		function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
		end,
		prefix = P.lsp,
		description = "Toggle inlay hints",
	},
	{
		mode = "n",
		"<leader>fr",
		function()
			Snacks.picker.lsp_references()
		end,
		prefix = P.find,
		description = "References to symbol under cursor",
	},
	{
		mode = "n",
		"<leader>fs",
		function()
			Snacks.picker.lsp_symbols({
				layout = {
					preview = "main",
					reverse = false,
					layout = {
						backdrop = false,
						width = 0.3,
						min_width = 80,
						height = 0.3,
						border = "none",
						box = "vertical",
						{
							win = "input",
							height = 1,
							border = "rounded",
							title = "{title} {live} {flags}",
							title_pos = "center",
						},
						{ win = "list", border = "rounded" },
						{ win = "preview", title = "{preview}", border = "rounded" },
					},
				},
			})
		end,
		prefix = P.misc,
		description = "List all symbols in current buffer",
	},
	{
		mode = "n",
		"<leader>fc",
		function()
			require("trouble").toggle({ focus = true, mode = "lsp_incoming_calls" })
		end,
		prefix = P.find,
		description = "Calls to this symbol",
	},
	{
		mode = "n",
		"<leader>fo",
		function()
			require("trouble").toggle({ focus = true, mode = "lsp_outgoing_calls" })
		end,
		prefix = P.find,
		description = "Calls made by this symbol",
	},
	{
		mode = "n",
		"<leader>fi",
		function()
			Snacks.picker.lsp_implementations()
		end,
		prefix = P.find,
		description = "Implementations of symbol under cursor",
	},
	{
		mode = "n",
		"<leader>fh",
		function()
			history_picker()
		end,
		prefix = P.find,
		description = "Open last picker",
	},
	{
		mode = "n",
		"<leader>fp",
		function()
			Snacks.picker()
		end,
		prefix = P.find,
		description = "Open list of pickers",
	},
	{
		mode = "n",
		"<leader>f?",
		function()
			Snacks.picker.help()
		end,
		prefix = P.find,
		description = "Help tags",
	},
	{
		mode = "n",
		"<leader>gd",
		[[<CMD>DiffviewOpen<CR>]],
		prefix = P.git,
		description = "Open Git diffview",
	},
	{
		mode = "n",
		"<leader>gn",
		function()
			local range = vim.fn.expand("<cWORD>")
			vim.cmd("DiffviewOpen " .. range)
		end,
		prefix = P.git,
		description = "Open Git diffview",
	},
	{
		mode = "n",
		"<leader>gq",
		[[<CMD>DiffviewClose<CR>]],
		prefix = P.git,
		description = "Close Git diffview",
	},
	{
		mode = { "o", "v" },
		"gh",
		function()
			require("mini.diff").textobject()
		end,
		prefix = P.text,
		description = "Git hunk",
	},
	{
		mode = { "n", "x" },
		"gs",
		opts = { expr = true },
		function()
			return require("mini.diff").operator("apply")
		end,
		prefix = P.git,
		description = "Stage selection/object",
	},
	{
		mode = { "n", "x" },
		"gr",
		opts = { expr = true },
		function()
			return require("mini.diff").operator("reset")
		end,
		prefix = P.git,
		description = "Reset selection/object",
	},
	{
		mode = { "n", "i" },
		"<M-n>",
		function()
			require("mini.diff").goto_hunk("next")
		end,
		prefix = P.git,
		description = "Go to next change/hunk",
	},
	{
		mode = { "n", "i" },
		"<M-t>",
		function()
			require("mini.diff").goto_hunk("prev")
		end,
		prefix = P.git,
		description = "Go to previous change/hunk",
	},
	{
		mode = { "n" },
		"<leader>go",
		function()
			require("mini.diff").toggle_overlay(0)
		end,
		prefix = P.git,
		description = "Toggle diff overlay",
	},
	{
		mode = "n",
		"<leader>gbt",
		"<cmd>GitBlameToggle<cr>",
		prefix = P.git,
		description = "Toggle inline git blame",
	},
	{
		mode = "n",
		"<leader>gbd",
		function()
			Snacks.git.blame_line()
		end,
		prefix = P.git,
		description = "Full detail git blame for current line",
	},
	{
		mode = "n",
		"<leader>gh",
		function()
			Snacks.picker.git_log()
		end,
		prefix = P.git,
		description = "Commit history",
	},
	{
		mode = "n",
		"<leader>gc",
		function()
			Snacks.picker.git_log({ current_file = true })
		end,
		prefix = P.git,
		description = "Commit history for current buffer",
	},
	{
		mode = "n",
		"<leader>bc",
		function()
			local cur_line = vim.api.nvim_win_get_cursor(0)[1]
			local rel_filepath = vim.fn.expand("%p"):gsub(vim.fn.system("git rev-parse --show-toplevel"), "")
			local command = "git blame -L " .. cur_line .. "," .. cur_line .. " -sl -- " .. rel_filepath
			local commit = vim.fn.system(command):sub(1, vim.fn.system(command):find(" "))
			if not is_detached_head() then
				original_branch = vim.fn
					.system("git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'")
					:gsub("^%s*(.-)%s*$", "%1")
				vim.fn.system(
					'git stash --include-untracked -m "nvim autostash" && git checkout '
						.. commit
						.. " && git reset HEAD~1"
				)
			else
				vim.fn.system("git reset --hard HEAD && git checkout " .. commit .. " && git reset HEAD~1")
			end
			vim.cmd(":e")
			vim.notify("Checked out " .. commit)
		end,
		prefix = P.git,
		description = "Browse source at the commit that changed the current line",
	},
	{
		mode = "n",
		"<leader>bm",
		function()
			if is_detached_head() then
				vim.fn.system(
					"git reset --hard HEAD && git checkout " .. original_branch .. " --force && git stash pop"
				)
				vim.cmd(":e")
				vim.notify("Checked out " .. original_branch)
				original_branch = nil
			else
				vim.notify("Not in detached HEAD state, risk of resetting local changes")
			end
		end,
		prefix = P.git,
		description = "Stop browsing source at commit",
	},
	{
		mode = "n",
		"<leader>-",
		function()
			vim.cmd("split")
		end,
		prefix = P.window,
		description = "Create horizontal split",
	},
	{
		mode = "n",
		"<leader>|",
		function()
			vim.cmd("vsplit")
		end,
		prefix = P.window,
		description = "Create vertical split",
	},
	{
		mode = "n",
		"<A-r>",
		function()
			require("smart-splits").start_resize_mode()
		end,
		prefix = P.window,
		description = "Enter resize mode",
	},
	{
		mode = "n",
		"<A-h>",
		function()
			require("smart-splits").resize_left()
		end,
		prefix = P.window,
		description = "Resize leftwards",
	},
	{
		mode = "n",
		"<A-j>",
		function()
			require("smart-splits").resize_down()
		end,
		prefix = P.window,
		description = "Resize downwards",
	},
	{
		mode = "n",
		"<A-k>",
		function()
			require("smart-splits").resize_up()
		end,
		prefix = P.window,
		description = "Resize upwards",
	},
	{
		mode = "n",
		"<A-l>",
		function()
			require("smart-splits").resize_right()
		end,
		prefix = P.window,
		description = "Resize rightwards",
	},
	{
		mode = "n",
		"<C-h>",
		function()
			require("smart-splits").move_cursor_left()
		end,
		prefix = P.window,
		description = "Focus window to the left",
	},
	{
		mode = "n",
		"<C-j>",
		function()
			require("smart-splits").move_cursor_down()
		end,
		prefix = P.window,
		description = "Focus window below",
	},
	{
		mode = "n",
		"<C-k>",
		function()
			require("smart-splits").move_cursor_up()
		end,
		prefix = P.window,
		description = "Focus window above",
	},
	{
		mode = "n",
		"<C-l>",
		function()
			require("smart-splits").move_cursor_right()
		end,
		prefix = P.window,
		description = "Focus window to the right",
	},
	{
		mode = "n",
		"<leader><C-h>",
		function()
			require("smart-splits").swap_buf_left()
		end,
		prefix = P.window,
		description = "Swap current buffer leftwards",
	},
	{
		mode = "n",
		"<leader><C-j>",
		function()
			require("smart-splits").swap_buf_down()
		end,
		prefix = P.window,
		description = "Swap current buffer downwards",
	},
	{
		mode = "n",
		"<leader><C-k>",
		function()
			require("smart-splits").swap_buf_up()
		end,
		prefix = P.window,
		description = "Swap current buffer upwards",
	},
	{
		mode = "n",
		"<leader><C-l>",
		function()
			require("smart-splits").swap_buf_right()
		end,
		prefix = P.window,
		description = "Swap current buffer rightwards",
	},
	{
		mode = "n",
		"<leader>e",
		function()
			require("user.utils").toggle_minifiles()
		end,
		prefix = P.nav,
		description = "Open file explorer",
	},
	{
		mode = "n",
		"<leader>xx",
		"<cmd>Trouble diagnostics toggle<cr>",
		prefix = P.diag,
		description = "Toggle diagnostics window",
	},
	---@diagnostic disable: missing-fields
	{
		mode = "n",
		"<leader>xw",
		function()
			require("trouble").toggle({ focus = true, auto_refresh = true, mode = "cascade" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for entire workspace",
	},
	{
		mode = "n",
		"<leader>xd",
		function()
			require("trouble").toggle({ focus = true, auto_refresh = true, mode = "diagnostics_buffer" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics for current file",
	},
	{
		mode = "n",
		"<leader>xq",
		function()
			require("trouble").toggle({ focus = true, mode = "qflist" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window with quickfix list",
	},
	{
		mode = "n",
		"<leader>xc",
		function()
			require("trouble").toggle({ focus = true, mode = "lsp_incoming_calls" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for calls to this symbol",
	},
	{
		mode = "n",
		"<leader>xo",
		function()
			require("trouble").toggle({ focus = true, mode = "lsp_outgoing_calls" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for calls by this symbol",
	},
	{
		mode = "n",
		"<leader>xr",
		function()
			require("trouble").toggle({ focus = true, mode = "lsp_references" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for references to this symbol",
	},
	{
		mode = "n",
		"<leader>xs",
		function()
			require("trouble").toggle({
				focus = true,
				win = {
					position = "right",
					size = { width = 0.2 },
				},
				mode = "lsp_document_symbols",
			})
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for all symbols in the current buffer",
	},
	{
		mode = "n",
		"<leader>xl",
		function()
			require("trouble").toggle({ focus = true, mode = "loclist" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for loclist",
	},
	{
		mode = "n",
		"<leader>xn",
		function()
			require("trouble").next({ jump = true })
		end,
		prefix = P.diag,
		description = "Go to next diagnostics item",
	},
	{
		mode = "n",
		"<leader>xt",
		function()
			require("trouble").prev({ jump = true })
		end,
		prefix = P.diag,
		description = "Go to previous diagnostic item",
	},
	{
		mode = "n",
		"<leader>xf",
		function()
			require("trouble").toggle({ focus = true, mode = "snacks" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for result exported from picker",
	},
	---@diagnostic enable: missing-fields
	-- debugging
	{
		mode = "n",
		"<leader>dd",
		function()
			require("dap").toggle_breakpoint()
		end,
		prefix = P.debug,
		description = "Toggle breakpoint",
	},
	{
		mode = "n",
		"<leader>dC",
		function()
			require("dap").clear_breakpoints()
		end,
		prefix = P.debug,
		description = "Clear all breakpoints",
	},
	{
		mode = "n",
		"<leader>dD",
		function()
			vim.ui.input({ prompt = "Condition: " }, function(input)
				require("dap").set_breakpoint(input)
			end)
		end,
		prefix = P.debug,
		description = "Toggle conditional breakpoint",
	},
	{
		mode = "n",
		"<leader>dl",
		function()
			trigger_dap(require("dap").run_last)
		end,
		prefix = P.debug,
		description = "Nearest test",
	},
	{
		mode = "n",
		"<leader>do",
		function()
			require("dap").step_over()
		end,
		prefix = P.debug,
		description = "Step over",
	},
	{
		mode = "n",
		"<leader>di",
		function()
			require("dap").step_into({ askForTargets = true })
		end,
		prefix = P.debug,
		description = "Step into",
	},
	{
		mode = "n",
		"<leader>du",
		function()
			require("dap").step_out()
		end,
		prefix = P.debug,
		description = "Step out",
	},
	{
		mode = "n",
		"<leader>db",
		function()
			require("dap").step_back()
		end,
		prefix = P.debug,
		description = "Step back",
	},
	{
		mode = "n",
		"<leader>dh",
		function()
			require("dap").run_to_cursor()
		end,
		prefix = P.debug,
		description = "Run to cursor",
	},
	{
		"<leader>dw",
		{
			n = function()
				require("dapui").elements.watches.add(vim.fn.expand("<cword>"))
			end,
			x = function()
				vim.cmd([[normal! vv]])
				local text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), "\n")
				require("dapui").elements.watches.add(text)
			end,
		},
		prefix = P.debug,
		description = "Add variable to watches",
	},
	{
		mode = { "n", "x" },
		"<leader>dr",
		function()
			require("dapui").eval()
		end,
		prefix = P.debug,
		description = "Add variable to watches",
	},
	{
		mode = "n",
		"<leader>dc",
		continue,
		prefix = P.debug,
		description = "Start debug session, or continue session",
	},
	{
		mode = "n",
		"<leader>de",
		function()
			require("dap").terminate()
			require("dapui").close()
			require("nvim-dap-virtual-text").refresh()
		end,
		prefix = P.debug,
		description = "Stop debug session",
	},
	{
		mode = "n",
		"<leader>dt",
		function()
			require("dapui").toggle({ reset = true })
		end,
		prefix = P.debug,
		description = "Reset and toggle ui",
	},
	{
		mode = "n",
		"<leader>bt",
		function()
			require("alternate-toggler").toggleAlternate()
		end,
		prefix = P.misc,
		description = "Toggle booleans",
	},
	{
		mode = "n",
		"<leader>ro",
		"<cmd>OverseerToggle<cr>",
		prefix = P.task,
		description = "Open task output window",
	},
	{
		mode = "n",
		"<leader>rt",
		"<cmd>OverseerRun<CR>",
		prefix = P.task,
		description = "List build tasks to run",
	},
	{
		mode = { "n", "v" },
		"gx",
		function()
			require("various-textobjs").url()
			local foundURL = vim.fn.mode():find("v")
			if foundURL then
				vim.cmd.normal('"zy')
				local url = vim.fn.getreg("z")
				vim.ui.open(url)
			else
				-- find all URLs in buffer
				local urlPattern = [[%l%l%l-://[^%s)"'`]+]]
				local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
				local urls = {}
				for url in bufText:gmatch(urlPattern) do
					table.insert(urls, url)
				end
				if #urls == 0 then
					return
				end

				vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
					if choice then
						vim.ui.open(choice)
					end
				end)
			end
		end,
		prefix = P.misc,
		description = "Open url in web browser",
	},
	{
		mode = { "n", "v" },
		"<leader>bf",
		function()
			require("conform").format({ async = false })
		end,
		prefix = P.code,
		description = "Format current buffer",
	},
	--latex
	{
		mode = "n",
		"<leader>lb",
		[[:VimtexCompile <CR>]],
		prefix = P.latex,
		description = "Build/compile document",
	},
	{
		mode = "n",
		"<leader>lc",
		[[:VimtexClean <CR>]],
		prefix = P.latex,
		description = "Clean aux files",
	},
	{
		mode = "n",
		"<leader>le",
		[[:VimtexTocOpen <CR>]],
		prefix = P.latex,
		description = "Open table of contents",
	},
	{
		mode = "n",
		"<leader>ln",
		[[:VimtexTocToggle <CR>]],
		prefix = P.latex,
		description = "Toggle table of contents",
	},
	{
		mode = "n",
		"K",
		function()
			vim.lsp.buf.hover()
		end,
		prefix = P.code,
		description = "Show documentation",
	},
	{
		mode = "n",
		"gd",
		function()
			require("snacks").picker.lsp_definitions()
		end,
		prefix = P.code,
		description = "Go to definition",
	},
	{
		mode = "n",
		"gD",
		function()
			vim.lsp.buf.declaration()
		end,
		prefix = P.code,
		description = "Go to declaration",
	},
	{
		mode = "n",
		"<leader>K",
		function()
			vim.lsp.buf.signature_help()
		end,
		prefix = P.code,
		description = "Show function signature",
	},
	{
		mode = "n",
		"gt",
		function()
			require("snacks").picker.lsp_type_definitions()
		end,
		prefix = P.code,
		description = "Go to type definition",
	},
	{
		mode = "n",
		"<leader>rn",
		function()
			require("config.editor.rename").rename({ insert = true })
		end,
		prefix = P.code,
		description = "Rename",
	},
	{
		mode = "n",
		"<leader>gf",
		function()
			require("grug-far").toggle_instance({
				instanceName = "main_instance",
				prefills = {
					search = vim.fn.expand("<cword>"),
				},
			})
		end,
		prefix = P.code,
		description = "Search and replace word under cursor",
	},
	{
		mode = "v",
		"<leader>gf",
		function()
			vim.cmd([[normal! vv]])
			local text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), "\n")
			text = require("user.utils").escape_special_chars(text)
			text = "(" .. text:gsub("\n%s+", "\n"):gsub("(\n)$", ""):gsub("[\n\r]", ")\n(.*") .. ")"
			require("grug-far").toggle_instance({
				instanceName = "main_instance",
				ignoreVisualSelection = true,
				prefills = {
					search = text,
					flags = "-U",
				},
			})
		end,
		prefix = P.code,
		description = "Search and replace word under cursor",
	},
	{
		mode = { "n", "x" },
		"<leader>ca",
		function()
			vim.lsp.buf.code_action()
		end,
		prefix = P.code,
		description = "Show code actions",
	},
	{
		mode = "n",
		"<leader>ds",
		function()
			vim.diagnostic.open_float()
		end,
		prefix = P.code,
		description = "Open LSP diagnostics in a floating window",
	},
	{
		mode = { "n", "x", "o" },
		"s",
		function()
			require("flash").jump()
		end,
		prefix = P.move,
		description = "Flash see :h flash.nvim.txt",
	},
	{
		mode = { "c" },
		"<c-s>",
		function()
			require("flash").toggle()
		end,
		prefix = P.move,
		description = "Toggle Flash Search",
	},
	{
		mode = "n",
		"<leader>cm",
		"<cmd>Mason<cr>",
		prefix = P.misc,
		description = "Open Mason: LSP server, formatter, DAP and linter manager",
	},
	{
		mode = "n",
		"<leader>nn",
		function()
			vim.ui.input({
				prompt = "New note name (without file extension)",
				default = "",
				kind = "tabline",
			}, function(input)
				vim.cmd.e("~/notes/" .. input .. ".md")
				vim.cmd.w()
			end)
		end,
		prefix = P.notes,
		description = "New note",
	},
	{
		mode = "n",
		"<leader>nf",
		function()
			Snacks.picker.files({
				dirs = { "~/notes/" },
			})
		end,
		prefix = P.notes,
		description = "Find note",
	},
	{
		mode = "n",
		"<leader>ng",
		function()
			Snacks.picker.grep({
				dirs = { "~/notes/" },
			})
		end,
		prefix = P.notes,
		description = "Grep notes",
	},
	{
		mode = "t",
		"<esc>",
		[[<C-\><C-n>]],
		{ buffer = 0 },
		prefix = P.term,
		description = "Exit insert mode in terminal",
	},
	{
		mode = "n",
		"<C-\\>",
		function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "horizontal", nil, "bottom")
		end,
		prefix = P.term,
		description = "Open in horizontal split",
	},
	{
		mode = "n",
		"<leader><C-\\>",
		function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = "n",
		"<C-]>",
		function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", nil, "right")
		end,
		prefix = P.term,
		description = "Open in vertical split",
	},
	{
		mode = "n",
		"<leader><C-]>",
		function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = "n",
		"<C-->",
		function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", nil, "left")
		end,
		prefix = P.term,
		description = "Open in left vertical split",
	},
	{
		mode = "n",
		"<leader><C-->",
		function()
			require("workspaces.toggleterms").toggle_active_terms(true)
		end,
		prefix = P.term,
		description = "Toggle all visible terminals",
	},
	{
		mode = { "o", "x" },
		"ii",
		function()
			require("various-textobjs").indentation("inner", "inner")
		end,
		prefix = P.text,
		description = "In inner indentation",
	},
	{
		mode = { "o", "x" },
		"ai",
		function()
			require("various-textobjs").indentation("outer", "inner")
		end,
		prefix = P.text,
		description = "Around inner indentation",
	},
	{
		mode = { "o", "x" },
		"iI",
		function()
			require("various-textobjs").indentation("inner", "outer")
		end,
		prefix = P.text,
		description = "In outer indentation",
	},
	{
		mode = { "o", "x" },
		"aI",
		function()
			require("various-textobjs").indentation("outer", "outer")
		end,
		prefix = P.text,
		description = "Around outer indentation",
	},
	{
		mode = { "o", "x" },
		"R",
		function()
			require("various-textobjs").restOfIndentation()
		end,
		prefix = P.text,
		description = "Rest of indentation",
	},
	{
		mode = { "o", "x" },
		"iS",
		function()
			require("various-textobjs").subword("inner")
		end,
		prefix = P.text,
		description = "In subword",
	},
	{
		mode = { "o", "x" },
		"aS",
		function()
			require("various-textobjs").subword("outer")
		end,
		prefix = P.text,
		description = "Around subword",
	},
	{
		mode = { "o", "x" },
		"r",
		function()
			require("various-textobjs").restOfParagraph()
		end,
		prefix = P.text,
		description = "Rest of paragraph",
	},
	{
		mode = { "o", "x" },
		"gG",
		function()
			require("various-textobjs").entireBuffer()
		end,
		prefix = P.text,
		description = "Entire buffer",
	},
	{
		mode = { "o", "x" },
		"n",
		function()
			require("various-textobjs").nearEoL()
		end,
		prefix = P.text,
		description = "1 char befor EoL",
	},
	{
		mode = { "o", "x" },
		"i_",
		function()
			require("various-textobjs").lineCharacterwise("inner")
		end,
		prefix = P.text,
		description = "In line characterwise",
	},
	{
		mode = { "o", "x" },
		"a_",
		function()
			require("various-textobjs").lineCharacterwise("outer")
		end,
		prefix = P.text,
		description = "Around line characterwise",
	},
	{
		mode = { "o", "x" },
		"|",
		function()
			require("various-textobjs").column()
		end,
		prefix = P.text,
		description = "Column",
	},
	{
		mode = { "o", "x" },
		"iN",
		function()
			require("various-textobjs").notebookCell("inner")
		end,
		prefix = P.text,
		description = "In notebook cell",
	},
	{
		mode = { "o", "x" },
		"aN",
		function()
			require("various-textobjs").notebookCell("outer")
		end,
		prefix = P.text,
		description = "Around notebook cell",
	},
	{
		mode = { "o", "x" },
		"iv",
		function()
			require("various-textobjs").value("inner")
		end,
		prefix = P.text,
		description = "In value",
	},
	{
		mode = { "o", "x" },
		"av",
		function()
			require("various-textobjs").value("outer")
		end,
		prefix = P.text,
		description = "Around value",
	},
	{
		mode = { "o", "x" },
		"ik",
		function()
			require("various-textobjs").key("inner")
		end,
		prefix = P.text,
		description = "In key",
	},
	{
		mode = { "o", "x" },
		"ak",
		function()
			require("various-textobjs").key("outer")
		end,
		prefix = P.text,
		description = "Around key",
	},
	{
		mode = { "o", "x" },
		"L",
		function()
			require("various-textobjs").url()
		end,
		prefix = P.text,
		description = "Url",
	},
	{
		mode = { "o", "x" },
		"in",
		function()
			require("various-textobjs").number("inner")
		end,
		prefix = P.text,
		description = "In number",
	},
	{
		mode = { "o", "x" },
		"an",
		function()
			require("various-textobjs").number("outer")
		end,
		prefix = P.text,
		description = "Around number",
	},
	{
		mode = { "o", "x" },
		"!",
		function()
			require("various-textobjs").diagnostic()
		end,
		prefix = P.text,
		description = "Lsp diagnostic",
	},
	{
		mode = { "o", "x" },
		"iM",
		function()
			require("various-textobjs").chainMember("inner")
		end,
		prefix = P.text,
		description = "In chain member",
	},
	{
		mode = { "o", "x" },
		"aM",
		function()
			require("various-textobjs").chainMember("outer")
		end,
		prefix = P.text,
		description = "Around chain member",
	},
	{
		mode = { "n" },
		"<leader>sn",
		function()
			require("workspaces.workspaces").next_session()
		end,
		prefix = P.work,
		description = "Next session",
	},
	{
		mode = { "n" },
		"<leader>sp",
		function()
			require("workspaces.workspaces").previous_session()
		end,
		prefix = P.work,
		description = "Previous session",
	},
	{
		mode = { "n" },
		"<leader>z",
		function()
			require("workspaces.workspaces").alternate_session()
		end,
		prefix = P.work,
		description = "Alternate session",
	},
	{
		mode = { "n" },
		"<leader>sz",
		function()
			require("workspaces.workspaces").alternate_workspace()
		end,
		prefix = P.work,
		description = "Alternate workspace",
	},
	{
		mode = { "n" },
		"<leader>sa",
		function()
			require("workspaces.ui").pick_session()
		end,
		prefix = P.work,
		description = "Pick session",
	},
	{
		mode = { "n" },
		"<leader>scd",
		function()
			require("workspaces.ui").change_current_session_directory_input()
		end,
		prefix = P.work,
		description = "Change session directory",
	},
	{
		mode = { "n" },
		"\\",
		function()
			require("workspaces.workspaces").switch_session_by_index(vim.v.count1)
		end,
		prefix = P.work,
		description = "Switch session by index",
	},
	{
		mode = { "n" },
		"<leader>sw",
		function()
			require("workspaces.ui").pick_workspace()
		end,
		prefix = P.work,
		description = "Pick workspace",
	},
	{
		mode = { "n" },
		"<leader>t",
		function()
			require("workspaces.ui").pick_mark()
		end,
		prefix = P.work,
		description = "Find mark",
	},
	{
		mode = { "n" },
		"<leader>q",
		function()
			require("workspaces.marks").toggle_mark()
		end,
		prefix = P.work,
		description = "Toggle mark",
	},
	{
		mode = { "n" },
		"<leader>scs",
		function()
			require("workspaces.ui").create_session_input()
		end,
		prefix = P.work,
		description = "Create session",
	},
	{
		mode = { "n" },
		"<leader>srs",
		function()
			require("workspaces.ui").rename_current_session_input()
		end,
		prefix = P.work,
		description = "Rename session",
	},
	{
		mode = { "n" },
		"<leader>scw",
		function()
			require("workspaces.ui").create_workspace_input()
		end,
		prefix = P.work,
		description = "Create workspace",
	},
	{
		mode = { "n" },
		"<leader>srw",
		function()
			require("workspaces.ui").rename_current_workspace_input()
		end,
		prefix = P.work,
		description = "Rename workspace",
	},
	{
		mode = { "n" },
		"<leader>sds",
		function()
			require("workspaces.ui").delete_session_input()
		end,
		prefix = P.work,
		description = "Delete session",
	},
	{
		mode = { "n" },
		"<leader>sdw",
		function()
			require("workspaces.ui").delete_workspace_input()
		end,
		prefix = P.work,
		description = "Delete workspace",
	},
	{
		mode = { "n" },
		"m",
		function()
			require("substitute").operator()
		end,
		prefix = P.misc,
		description = "Substitute text object",
	},
	{
		mode = { "n" },
		"mm",
		function()
			require("substitute").line()
		end,
		prefix = P.misc,
		description = "Substitute line",
	},
	{
		mode = { "n" },
		"M",
		function()
			require("substitute").eol()
		end,
		prefix = P.misc,
		description = "Substitute to end of line",
	},
	{
		mode = { "x" },
		"m",
		function()
			require("substitute").visual()
		end,
		prefix = P.misc,
		description = "Substitute visual selection",
	},
	{
		mode = { "n", "v" },
		"<leader><BS>",
		function()
			Snacks.notifier.hide()
		end,
		prefix = P.misc,
		description = "Dismiss all notifications",
	},
	{
		mode = { "n", "x" },
		"p",
		"<Plug>(YankyPutAfter)",
		prefix = P.misc,
		description = "Paste after cursor",
	},
	{
		mode = { "n", "x" },
		"P",
		"<Plug>(YankyPutBefore)",
		prefix = P.misc,
		description = "Paste before cursor",
	},
	{
		mode = { "n", "x" },
		"gp",
		"<Plug>(YankyGPutAfter)",
		prefix = P.misc,
		description = "Paste after selection",
	},
	{
		mode = { "n", "x" },
		"gP",
		"<Plug>(YankyGPutBefore)",
		prefix = P.misc,
		description = "Paste after selection",
	},
	{
		mode = "n",
		"<c-t>",
		"<Plug>(YankyPreviousEntry)",
		prefix = P.misc,
		description = "Cycle to next item in yank history",
	},
	{
		mode = "n",
		"<c-n>",
		"<Plug>(YankyNextEntry)",
		prefix = P.misc,
		description = "Cycle to next item in yank history",
	},
	{
		mode = { "n" },
		"<leader>p",
		function()
			Snacks.picker.yanky()
		end,
		prefix = P.misc,
		description = "Open yank history",
	},
	-- {
	-- 	mode = "n",
	-- 	"<leader>me",
	-- 	":MoltenEvaluateOperator<CR>",
	-- 	description = "evaluate operator",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>mo",
	-- 	":noautocmd MoltenEnterOutput<CR>",
	-- 	description = "open output window",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>mr",
	-- 	":MoltenReevaluateCell<CR>",
	-- 	{ desc = "re-eval cell", silent = true },
	-- },
	-- {
	-- 	mode = "v",
	-- 	"<leader>r",
	-- 	":<C-u>MoltenEvaluateVisual<CR>gv",
	-- 	description = "execute visual selection",
	-- },
	-- { mode = "n", "<leader>mc", ":MoltenHideOutput<CR>", description = "close output window" },
	-- { mode = "n", "<leader>md", ":MoltenDelete<CR>", description = "delete Molten cell" },
	-- {
	-- 	mode = "n",
	-- 	"<leader>mx",
	-- 	":MoltenOpenInBrowser<CR>",
	-- 	description = "open output in browser",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>rc",
	-- 	function()
	-- 		require("quarto.runner").run_cell()
	-- 	end,
	-- 	description = "run cell",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>ra",
	-- 	function()
	-- 		require("quarto.runner").run_above()
	-- 	end,
	-- 	description = "run cell and above",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>rA",
	-- 	function()
	-- 		require("quarto.runner").run_all()
	-- 	end,
	-- 	description = "run all cells",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>rl",
	-- 	function()
	-- 		require("quarto.runner").run_line()
	-- 	end,
	-- 	description = "run line",
	-- },
	-- {
	-- 	mode = "v",
	-- 	"<leader>rv",
	-- 	function()
	-- 		require("quarto.runner").run_range()
	-- 	end,
	-- 	description = "run visual range",
	-- },
	-- {
	-- 	mode = "n",
	-- 	"<leader>RA",
	-- 	function()
	-- 		require("quarto.runner").run_all(true)
	-- 	end,
	-- 	description = "run all cells of all languages",
	-- },
	{
		mode = "n",
		"<leader>bp",
		function()
			require("dropbar.api").pick()
		end,
		prefix = P.nav,
		description = "Enter breadcrumb selection",
	},
	{
		mode = "n",
		"<leader>w",
		function()
			local win = require("window-picker").pick_window()
			if win then
				vim.api.nvim_set_current_win(win)
			end
		end,
		prefix = P.move,
		description = "Enter window selection",
	},
	{
		mode = "n",
		"<leader>ll",
		function()
			require("lazy").home()
		end,
		prefix = P.misc,
		description = "Open plugin manager",
	},
	{
		mode = "n",
		"<leader>ld",
		function()
			require("osv").launch({ port = 8086 })
		end,
		prefix = P.debug,
		description = "Launch lua debugger server on this nvim instance",
	},
	{
		mode = "n",
		"<leader>rm",
		function()
			require("jdtls").test_nearest_method()
		end,
		prefix = P.test,
		description = "Run nearest java test",
	},
	{
		mode = "n",
		"<leader>rjc",
		function()
			require("jdtls").test_class()
		end,
		prefix = P.test,
		description = "Run java test class",
	},
	{
		mode = "n",
		"<leader>nr",
		function()
			require("neotest").run.run(vim.fn.expand("%"))
		end,
		prefix = P.test,
		description = "Run all tests in file",
	},
	{
		mode = "n",
		"<leader>nt",
		function()
			require("neotest").run.run()
		end,
		prefix = P.test,
		description = "Run nearest test",
	},
	{
		mode = "n",
		"<leader>no",
		function()
			require("neotest").output.open()
		end,
		prefix = P.test,
		description = "Show test output",
	},
	{
		mode = "n",
		"<leader>np",
		function()
			require("neotest").output_panel.toggle()
		end,
		prefix = P.test,
		description = "Toggle aggregated output window",
	},
	{
		mode = "n",
		"<leader>nc",
		function()
			require("neotest").output_panel.clear()
		end,
		prefix = P.test,
		description = "Clear aggregated output window",
	},
	{
		mode = "n",
		"<leader>ns",
		function()
			require("neotest").summary.toggle()
		end,
		prefix = P.test,
		description = "Toggle summary tree",
	},
	{
		mode = "v",
		"<leader>cs",
		"<cmd>CodeSnapASCII<cr>",
		prefix = P.misc,
		description = "Copy ASCII code snapshot to clipboard",
	},
	{
		mode = "x",
		"<leader>re",
		function()
			require("refactoring").refactor("Extract Function")
		end,
		prefix = P.code,
		description = "Extract function",
	},
	{
		mode = "x",
		"<leader>rff",
		function()
			require("refactoring").refactor("Extract Function To File")
		end,
		prefix = P.code,
		description = "Extract function to file",
	},
	{
		mode = "x",
		"<leader>rv",
		function()
			require("refactoring").refactor("Extract Variable")
		end,
		prefix = P.code,
		description = "Extract variable",
	},
	{
		mode = "n",
		"<leader>rI",
		function()
			require("refactoring").refactor("Inline Function")
		end,
		prefix = P.code,
		description = "Inline function",
	},
	{
		mode = { "n", "x" },
		"<leader>ri",
		function()
			require("refactoring").refactor("Inline Variable")
		end,
		prefix = P.code,
		description = "Inline variable",
	},
	{
		mode = "n",
		"<leader>rb",
		function()
			require("refactoring").refactor("Extract Block")
		end,
		prefix = P.code,
		description = "Extract block",
	},
	{
		mode = "n",
		"<leader>rfb",
		function()
			require("refactoring").refactor("Extract Block To File")
		end,
		prefix = P.code,
		description = "Extract block to file",
	},
	{
		mode = { "n", "x" },
		"<leader>rl",
		function()
			require("refactoring").get_refactors()
		end,
		prefix = P.code,
		description = "List available refactors",
	},
	{
		mode = "n",
		"<leader>rp",
		function()
			require("refactoring").debug.printf({ below = true, show_success_message = false })
		end,
		prefix = P.code,
		description = "Add print statement below current line",
	},
	{
		mode = { "x", "n" },
		"<leader>rdv",
		function()
			require("refactoring").debug.print_var({ show_success_message = false })
		end,
		prefix = P.code,
		description = "Add print statement with variable value",
	},
	{
		mode = "n",
		"<leader>rdc",
		function()
			require("refactoring").debug.cleanup({ show_success_message = true })
		end,
		prefix = P.code,
		description = "Clean up all automated print statements",
	},
	{
		mode = "n",
		"<leader>lw",
		function()
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
				require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
			end
		end,
		prefix = P.lsp,
		description = "Load all workspace files for diagnostics",
	},
	{
		mode = "n",
		"<leader>la",
		function()
			vim.g.extra_lsp_actions()
		end,
		prefix = P.lsp,
		description = "Run extra lsp actions",
	},
	{
		mode = "n",
		"<leader>ls",
		function()
			vim.cmd("LspStart")
		end,
		prefix = P.lsp,
		description = "Start",
	},
	{
		mode = "n",
		"<leader>lr",
		function()
			vim.cmd("LspRestart")
		end,
		prefix = P.lsp,
		description = "Restart",
	},
	{
		mode = "n",
		"<leader>J",
		function()
			vim.fn.setreg('"', vim.fn.getreg('"'):gsub("[\n\r]", " "))
		end,
		prefix = P.misc,
		description = 'Remove linebreaks from contents in " register',
	},
	{
		mode = { "n", "v" },
		"<leader><CR>",
		function()
			vim.cmd("CheckboxPrev")
		end,
		prefix = P.misc,
		description = "Next checkbox state",
	},
	{
		mode = { "n", "v" },
		"<leader><S-CR>",
		function()
			vim.cmd("CheckboxPrev")
		end,
		prefix = P.misc,
		description = "Previous checkbox state",
	},
	{
		mode = { "n", "v" },
		"<leader>ct",
		function()
			vim.cmd("CheckboxToggle")
		end,
		prefix = P.misc,
		description = "Toggle if line is a checkbox",
	},
	{
		mode = { "n", "v" },
		"<leader>mcc",
		function()
			vim.cmd("CodeCreate")
		end,
		prefix = P.misc,
		description = "Create code block in markdown",
	},
	{
		mode = { "n", "v" },
		"<leader>mce",
		function()
			vim.cmd("CodeEdit")
		end,
		prefix = P.misc,
		description = "Edit markdown code block",
	},
	{
		mode = { "n", "v" },
		"<leader>ms",
		function()
			vim.cmd({ cmd = "Markview", args = { "splitToggle" } })
		end,
		prefix = P.misc,
		description = "Toggle previewing markdown in a split",
	},
	{
		mode = { "n" },
		"]]",
		function()
			require("snacks").words.jump(vim.v.count1)
		end,
		prefix = P.misc,
		description = "Next reference",
	},
	{
		mode = { "n" },
		"[[",
		function()
			require("snacks").words.jump(-vim.v.count1)
		end,
		prefix = P.misc,
		description = "Previous reference",
	},
	{
		mode = { "n" },
		"gS",
		function()
			require("mini.splitjoin").toggle()
		end,
		prefix = P.misc,
		description = "Split/Join arguments",
	},
	{
		mode = { "n" },
		"<leader>mt",
		function()
			local wc_out = vim.fn.system("wc -L " .. vim.fn.expand("%:p"))
			local longest_line = tonumber(string.sub(wc_out, wc_out:find("%d+")))
			if longest_line < vim.o.columns then
				vim.cmd("Markview toggle")
			else
				vim.notify("File contains lines longer than the viewport, aborting rendering")
			end
		end,
		prefix = P.misc,
		description = "Enable markdown rendering",
	},
	{
		mode = { "n" },
		"<leader>nh",
		function()
			Snacks.notifier.show_history()
		end,
		prefix = P.misc,
		description = "Show notification history",
	},
	{
		mode = { "n", "v" },
		"<C-S-j>",
		"<cmd>Treewalker Down<cr>",
		prefix = P.misc,
		description = "Move down treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-S-k>",
		"<cmd>Treewalker Up<cr>",
		prefix = P.misc,
		description = "Move up treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-S-h>",
		"<cmd>Treewalker Left<cr>",
		prefix = P.misc,
		description = "Move left treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-S-l>",
		"<cmd>Treewalker Right<cr>",
		prefix = P.misc,
		description = "Move right treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-M-S-j>",
		"<cmd>Treewalker SwapDown<cr>",
		prefix = P.misc,
		description = "Swap down treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-M-S-k>",
		"<cmd>Treewalker SwapUp<cr>",
		prefix = P.misc,
		description = "Swap up treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-M-S-h>",
		"<cmd>Treewalker SwapLeft<cr>",
		prefix = P.misc,
		description = "Swap left treesitter node",
	},
	{
		mode = { "n", "v" },
		"<C-M-S-l>",
		"<cmd>Treewalker SwapRight<cr>",
		prefix = P.misc,
		description = "Swap right treesitter node",
	},
	{
		mode = { "n", "v" },
		"<leader><C-t>",
		function()
			require("config.hydra").treewalker_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start Treesitter navigation",
	},
	{
		mode = { "n", "v" },
		"<leader><C-d>",
		function()
			require("config.hydra").dap_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start debug mode",
	},
	{
		mode = { "n", "v" },
		"<leader><C-x>",
		function()
			require("config.hydra").trouble_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start trouble nav mode",
	},
	{
		mode = { "n", "v" },
		"<leader><C-g>",
		function()
			require("config.hydra").git_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start git mode",
	},

	{
		mode = { "n", "v" },
		"<leader>gs",
		function()
			local path = vim.fn.getcwd()
			local text = vim.fn.expand("<cWORD>")
			local parts = vim.split(text, ":")
			local line = tonumber(parts[2]:sub(1, #parts[2] - 1))
			parts = vim.split(vim.split(parts[1], "%(")[1], "%.")
			local filename = parts[#parts - 1] .. ".java"

			-- Find all matching files
			local find_command = string.format("find %s -name %q", path, vim.fn.fnamemodify(filename, ":t"))
			local matches = vim.fn.split(vim.fn.system(find_command), "\n")
			-- Remove empty entries
			matches = vim.tbl_filter(function(x)
				return x ~= ""
			end, matches)

			if #matches == 0 then
				vim.notify("File not found")
				return
			elseif #matches == 1 then
				vim.cmd("PinBuffer")
				open_in_non_dap_window(matches[1], line)
			else
				vim.ui.select(matches, {
					prompt = "Select file to open:",
					format_item = function(item)
						return vim.fn.fnamemodify(item, ":~:.")
					end,
				}, function(choice)
					if choice then
						open_in_non_dap_window(choice, line)
					end
				end)
			end
		end,
		description = "Go to stacktrace member",
	},
}

return {
	setup = function()
		local prefixifier = require("user.utils").prefixifier
		local keymaps = require("legendary").keymaps
		prefixifier(keymaps)(mappings)
	end,
}

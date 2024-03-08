local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
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

local original_branch = nil

<<<<<<< Updated upstream
---@param on_success fun(name: string, dir: string)
---@param on_cancel fun()
local function input_new_session(on_success, on_cancel)
	vim.ui.input({
		prompt = "New session name",
		default = "",
		kind = "tabline",
	}, function(name_input)
		if name_input then
			vim.ui.input({
				prompt = "New session directory",
				default = "",
				completion = "dir",
				kind = "tabline",
			}, function(dir_input)
				if dir_input then
					on_success(name_input, dir_input)
				else
					on_cancel()
				end
			end)
		else
			on_cancel()
		end
	end)
end

=======
>>>>>>> Stashed changes
local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local keymaps = require("legendary").keymaps

prefixifier(keymaps)({
	{
		mode = { "n", "v" },
		"<leader>Q",
		[[<CMD>qa! <CR>]],
		prefix = P.misc,
		description = "How to quit vim",
	},
	{
		mode = { "n", "v" },
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
		mode = { "n", "v" },
		"<leader>X",
		save_and_exit,
		prefix = P.misc,
		description = "How to save and quit vim",
	},
	{
		mode = "n",
		"<esc>",
		vim.cmd.up,
		prefix = P.misc,
		description = "Write buffer",
	},
	{
<<<<<<< Updated upstream
		mode = { "n" },
		"r",
		vim.cmd.redo,
		prefix = P.misc,
		description = "Redo",
	},
	{
=======
>>>>>>> Stashed changes
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
		"<leader>q",
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
		require("ufo").openAllFolds,
		prefix = P.fold,
		description = "Open all",
	},
	{
		mode = "n",
		"zM",
		require("ufo").closeAllFolds,
		prefix = P.fold,
		description = "Close all",
	},
	{
		mode = "n",
		"zr",
		require("ufo").openFoldsExceptKinds,
		prefix = P.fold,
		description = "Open all non-excluded",
	},
	{
		mode = "n",
		"zm",
		require("ufo").closeFoldsWith,
		prefix = P.fold,
		description = "Close folds with indentation level greater prefixed than number",
	},
	{
		mode = "n",
		"zP",
		require("ufo").peekFoldedLinesUnderCursor,
		prefix = P.fold,
		description = "Peek folded lines",
	},
<<<<<<< Updated upstream
=======
	--Legendary
>>>>>>> Stashed changes
	{
		mode = { "n", "v" },
		"<leader><leader>",
		function()
			require("legendary").find({})
		end,
		prefix = P.misc,
		description = "Command palette",
	},
	{
		mode = "n",
		"<leader>fg",
		require("telescope").extensions.live_grep_args.live_grep_args,
		prefix = P.find,
<<<<<<< Updated upstream
		description = "Grep in cwd",
=======
		description = "Grep in current working directory (cwd)",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fw",
		require("telescope-live-grep-args.shortcuts").grep_word_under_cursor,
		prefix = P.find,
<<<<<<< Updated upstream
		description = "Word in cwd",
=======
		description = "word in current working directory (cwd)",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fq",
		require("telescope.builtin").command_history,
		prefix = P.misc,
<<<<<<< Updated upstream
		description = "Show command history",
=======
		description = "Find command history",
>>>>>>> Stashed changes
	},
	{
		mode = "v",
		"<leader>fv",
		require("telescope-live-grep-args.shortcuts").grep_visual_selection,
		prefix = P.find,
		description = "Grep visual selection in cwd",
	},
	{
		mode = "n",
		"<leader>ff",
		require("telescope.builtin").find_files,
		prefix = P.find,
		description = "Files by filename in cwd",
	},
<<<<<<< Updated upstream
=======
	{ mode = "n", "<leader>ff", require("telescope.builtin").find_files, prefix = P.misc, description = "Find files" },
	{ mode = "n", "<leader>b", require("telescope.builtin").buffers, prefix = P.misc, description = "Show buffers" },
>>>>>>> Stashed changes
	{
		mode = "n",
		"<leader>fu",
		require("telescope").extensions.undo.undo,
		prefix = P.misc,
<<<<<<< Updated upstream
		description = "Show change history (undotree)",
=======
		description = "Show undotree",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fr",
		require("telescope.builtin").lsp_references,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "References to symbol under cursor",
=======
		prefix = P.misc,
		description = "Find symbol references",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fs",
		require("telescope.builtin").lsp_document_symbols,
		prefix = P.misc,
<<<<<<< Updated upstream
		description = "List all symbols in current buffer",
=======
		description = "Document symbols",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fc",
		require("telescope.builtin").lsp_incoming_calls,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "Calls to this symbol",
=======
		prefix = P.misc,
		description = "Find incoming calls",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fo",
		require("telescope.builtin").lsp_outgoing_calls,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "Calls made by this symbol",
=======
		prefix = P.misc,
		description = "Find outgoing calls",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fi",
		require("telescope.builtin").lsp_implementations,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "Implementations of symbol under cursor",
=======
		prefix = P.misc,
		description = "Find symbol implementations",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>fh",
		function()
			require("telescope.builtin").pickers()
		end,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "Open history of searches",
=======
		prefix = P.misc,
		description = "Resume last telescope search",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>f/",
		require("telescope.builtin").current_buffer_fuzzy_find,
<<<<<<< Updated upstream
		prefix = P.find,
		description = "Fuzzy search in current buffer",
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
		"<leader>gq",
		[[<CMD>DiffviewClose<CR>]],
		prefix = P.git,
		description = "Close Git diffview",
	},
	{
		mode = "n",
		"<leader>gsb",
		function()
			require("gitsigns").stage_buffer()
		end,
		prefix = P.git,
		description = "Git stage buffer",
	},
	{
		mode = "n",
		"<leader>grb",
		function()
			require("gitsigns").reset_buffer()
		end,
		prefix = P.git,
		description = "Git reset buffer",
	},
	{
		mode = "n",
		"<leader>guh",
		function()
			require("gitsigns").undo_stage_hunk()
		end,
		prefix = P.git,
		description = "Git undo last stage hunk",
	},
	{
		mode = "v",
		"<leader>gsv",
		function()
			require("gitsigns").stage_hunk(require("utils").get_visual_selection_lines())
		end,
		prefix = P.git,
		description = "Git stage visual selection",
	},
	{
		mode = "v",
		"<leader>grv",
		function()
			require("gitsigns").reset_hunk(require("utils").get_visual_selection_lines())
		end,
		prefix = P.git,
		description = "Git reset visual selection",
	},
	{
		mode = "n",
		"<leader>gh",
		require("telescope.builtin").git_commits,
		prefix = P.git,
		description = "Commit history",
	},
=======
		prefix = P.misc,
		description = "Fuzzy find in current buffer",
	},
	{ mode = "n", "<leader>gs", [[<CMD>DiffviewOpen<CR>]], prefix = P.misc, description = "Open Git diffview" },
	{ mode = "n", "<leader>gq", [[<CMD>DiffviewClose<CR>]], prefix = P.misc, description = "Close Git diffview" },
	{
		mode = "n",
		"<leader>gh",
		require("telescope.builtin").git_commits,
		prefix = P.misc,
		description = "Git commit history",
	},
>>>>>>> Stashed changes
	{
		mode = "n",
		"<leader>gc",
		require("telescope.builtin").git_bcommits,
<<<<<<< Updated upstream
		prefix = P.git,
		description = "Commit history for current buffer",
	},
	{
		mode = { "i", "n" },
		"<C-r>",
		require("telescope.builtin").registers,
		prefix = P.misc,
		description = "Show registers",
	},
=======
		prefix = P.misc,
		description = "Git commit history for current buffer",
	},
	{ mode = "i", "<C-r>", require("telescope.builtin").registers, prefix = P.misc, description = "Show registers" },
>>>>>>> Stashed changes
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
				vim.fn.system('git stash -m "nvim autostash" && git checkout ' .. commit .. " && git reset HEAD~1")
			else
				vim.fn.system("git reset --hard HEAD && git checkout " .. commit .. " && git reset HEAD~1")
			end
			vim.cmd(":e")
			vim.notify("Checked out " .. commit)
		end,
<<<<<<< Updated upstream
		prefix = P.git,
		description = "Browse source at the commit that changed the current line",
=======
		prefix = P.misc,
		description = "Git checkout the commit that changed the current line",
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
		prefix = P.git,
		description = "Stop browsing source at commit",
=======
		prefix = P.misc,
		description = "Git checkout previous branch",
	},
	--git
	{
		mode = "n",
		"<leader>gd",
		"[[:Gitsigns diffthis<CR>]]",
		prefix = P.misc,
		description = "Git diff of uncommitted changes",
>>>>>>> Stashed changes
	},
	{
		mode = { "n", "i" },
		"<C-n>",
		function()
			local gitsigns = require("gitsigns")
			gitsigns.preview_hunk_inline()
			gitsigns.next_hunk()
		end,
<<<<<<< Updated upstream
		prefix = P.git,
		description = "Go to next change/hunk",
=======
		prefix = P.misc,
		description = "Go to next git change/hunk",
>>>>>>> Stashed changes
	},
	{
		mode = { "n", "i" },
		"<C-p>",
		function()
			local gitsigns = require("gitsigns")
			gitsigns.preview_hunk_inline()
			gitsigns.prev_hunk()
		end,
<<<<<<< Updated upstream
		prefix = P.git,
		description = "Go to previous change/hunk",
=======
		prefix = P.misc,
		description = "Go to previous git change/hunk",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>gb",
		function()
			require("gitsigns").blame_line({ full = true })
		end,
<<<<<<< Updated upstream
		prefix = P.git,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Full commit message of last commit to change line",
	},
	{
		mode = "n",
		"<leader>a",
		require("grapple").toggle,
<<<<<<< Updated upstream
		prefix = P.nav,
		description = "Toggle file in quick access list",
=======
		prefix = P.misc,
		description = "Toggle file in grapple",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>t",
		require("grapple").toggle_tags,
<<<<<<< Updated upstream
		prefix = P.nav,
		description = "Open/close quick access list",
=======
		prefix = P.misc,
		description = "Toggle grapple window",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>ac",
		require("grapple").reset,
<<<<<<< Updated upstream
		prefix = P.nav,
		description = "Clear quick access tags for current grapple scope",
	},
	{
		mode = "n",
		"<A-h>",
		require("smart-splits").resize_left,
		prefix = P.window,
		description = "Resize leftwards",
	},
	{
		mode = "n",
		"<A-j>",
		require("smart-splits").resize_down,
		prefix = P.window,
		description = "Resize downwards",
	},
	{
		mode = "n",
		"<A-k>",
		require("smart-splits").resize_up,
		prefix = P.window,
		description = "Resize upwards",
	},
	{
		mode = "n",
		"<A-l>",
		require("smart-splits").resize_right,
		prefix = P.window,
		description = "Resize rightwards",
	},
	{
		mode = "n",
		"<C-h>",
		require("smart-splits").move_cursor_left,
		prefix = P.window,
		description = "Focus window to the left",
	},
	{
		mode = "n",
		"<C-j>",
		require("smart-splits").move_cursor_down,
		prefix = P.window,
		description = "Focus window below",
	},
	{
		mode = "n",
		"<C-k>",
		require("smart-splits").move_cursor_up,
		prefix = P.window,
		description = "Focus window above",
	},
	{
		mode = "n",
		"<C-l>",
		require("smart-splits").move_cursor_right,
		prefix = P.window,
		description = "Focus window to the right",
	},
=======
		prefix = P.misc,
		description = "Clear grapple tags for current scope",
	},
	--smart splits
	{ mode = "n", "<A-h>", require("smart-splits").resize_left, prefix = P.misc, description = "Resize left" },
	{ mode = "n", "<A-j>", require("smart-splits").resize_down, prefix = P.misc, description = "Resize down" },
	{ mode = "n", "<A-k>", require("smart-splits").resize_up, prefix = P.misc, description = "Resize up" },
	{ mode = "n", "<A-l>", require("smart-splits").resize_right, prefix = P.misc, description = "Resize right" },
	{
		mode = "n",
		"<C-h>",
		require("smart-splits").move_cursor_left,
		prefix = P.misc,
		description = "Move cursor left",
	},
	{
		mode = "n",
		"<C-j>",
		require("smart-splits").move_cursor_down,
		prefix = P.misc,
		description = "Move cursor down",
	},
	{ mode = "n", "<C-k>", require("smart-splits").move_cursor_up, prefix = P.misc, description = "Move cursor up" },
	{
		mode = "n",
		"<C-l>",
		require("smart-splits").move_cursor_right,
		prefix = P.misc,
		description = "Move cursor right",
	},
	{ mode = "n", "<A-n>", vim.cmd.tabnext, prefix = P.misc, description = "Go to next tab" },
	{ mode = "n", "<A-p>", vim.cmd.tabprevious, prefix = P.misc, description = "Go to previous tab" },
>>>>>>> Stashed changes
	{
		mode = "n",
		"<leader><C-h>",
		require("smart-splits").swap_buf_left,
<<<<<<< Updated upstream
		prefix = P.window,
		description = "Swap current buffer leftwards",
=======
		prefix = P.misc,
		description = "Swap buffer left",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader><C-j>",
		require("smart-splits").swap_buf_down,
<<<<<<< Updated upstream
		prefix = P.window,
		description = "Swap current buffer downwards",
=======
		prefix = P.misc,
		description = "Swap buffer down",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader><C-k>",
		require("smart-splits").swap_buf_up,
<<<<<<< Updated upstream
		prefix = P.window,
		description = "Swap current buffer upwards",
=======
		prefix = P.misc,
		description = "Swap buffer up",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader><C-l>",
		require("smart-splits").swap_buf_right,
<<<<<<< Updated upstream
		prefix = P.window,
		description = "Swap current buffer rightwards",
=======
		prefix = P.misc,
		description = "Swap buffer right",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>e",
		function()
			local MiniFiles = require("mini.files")
			local function open_and_center(path)
				MiniFiles.open(path)
				MiniFiles.go_out()
				MiniFiles.go_in()
			end
			if not MiniFiles.close() then
				if not pcall(open_and_center, vim.fn.expand("%:p")) then
					open_and_center()
				end
			end
		end,
<<<<<<< Updated upstream
		prefix = P.nav,
		description = "Open file explorer",
=======
		prefix = P.misc,
		description = "Open mini.files",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"H",
		function()
			local MiniFiles = require("mini.files")
			MiniFiles.go_out_plus()
			MiniFiles.go_out_plus()
			MiniFiles.go_in()
		end,
<<<<<<< Updated upstream
	},
	{
		mode = "n",
		"<leader>mm",
		"<cmd>AerialToggle!<CR>",
		prefix = P.code,
		description = "Open function minimap",
	},
=======
		prefix = P.misc,
		description = "Open mini.files",
	},
	--aerial
	{ mode = "n", "<leader>mm", "<cmd>AerialToggle!<CR>", prefix = P.misc, description = "Open function minimap" },
	--diagnostics quicklist
>>>>>>> Stashed changes
	{
		mode = "n",
		"<leader>xx",
		require("trouble").toggle,
<<<<<<< Updated upstream
		prefix = P.diag,
		description = "Toggle diagnostics window",
=======
		{ prefix = P.misc, description = "Toggle diagnostics window" },
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>xw",
		function()
			require("trouble").toggle("workspace_diagnostics")
		end,
<<<<<<< Updated upstream
		prefix = P.diag,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Toggle diagnostics window for entire workspace",
	},
	{
		mode = "n",
		"<leader>xd",
		function()
			require("trouble").toggle("document_diagnostics")
		end,
<<<<<<< Updated upstream
		prefix = P.diag,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Toggle diagnostics for current document",
	},
	{
		mode = "n",
		"<leader>xq",
		function()
			require("trouble").toggle("quickfix")
		end,
<<<<<<< Updated upstream
		prefix = P.diag,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Toggle diagnostics window with quickfix list",
	},
	{
		mode = "n",
		"<leader>xl",
		function()
			require("trouble").toggle("loclist")
		end,
<<<<<<< Updated upstream
		prefix = P.diag,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Toggle diagnostics window for loclist",
	},
	{
		mode = "n",
		"<leader>/",
		require("Comment.api").toggle.linewise.current,
<<<<<<< Updated upstream
		prefix = P.code,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Comment current line",
	},
	{
		mode = "x",
		"<leader>/",
		function()
			vim.api.nvim_feedkeys(esc, "nx", false)
			require("Comment.api").toggle.linewise(vim.fn.visualmode())
		end,
<<<<<<< Updated upstream
		prefix = P.code,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Comment selection linewise",
	},
	{
		mode = "x",
		"<leader>\\",
		function()
			vim.api.nvim_feedkeys(esc, "nx", false)
			require("Comment.api").toggle.blockwise(vim.fn.visualmode())
		end,
<<<<<<< Updated upstream
		prefix = P.code,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Comment selection blockwise",
	},
	--debugging
	{
		mode = "n",
		"<Leader>dd",
		function()
			require("dap").toggle_breakpoint()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Toggle breakpoint",
	},
	{
		mode = "n",
		"<Leader>dD",
		function()
			vim.ui.input({ prompt = "Condition: " }, function(input)
				require("dap").set_breakpoint(input)
			end)
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
		description = "Toggle conditional breakpoint",
=======
		prefix = P.misc,
		description = "Toggle breakpoint",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>dl",
		function()
			trigger_dap(require("dap").run_last)
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
		description = "Nearest test",
=======
		prefix = P.misc,
		description = "Choose nearest test",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>do",
		function()
			require("dap").step_over()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Step over",
	},
	{
		mode = "n",
		"<leader>di",
		function()
			require("dap").step_into()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Step into",
	},
	{
		mode = "n",
		"<leader>du",
		function()
			require("dap").step_out()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Step out",
	},
	{
		mode = "n",
		"<leader>db",
		function()
			require("dap").step_back()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Step back",
	},
	{
		mode = "n",
		"<leader>dh",
		function()
			require("dap").run_to_cursor()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Run to cursor",
	},
	{
		mode = "n",
		"<leader>dc",
		continue,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Start debug session, or continue session",
	},
	{
		mode = "n",
		"<leader>de",
		function()
			require("dap").terminate()
			require("dapui").close()
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
		description = "Stop debug session",
=======
		prefix = P.misc,
		description = "Terminate debug session",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>du",
		function()
			require("dapui").toggle({ reset = true })
		end,
<<<<<<< Updated upstream
		prefix = P.debug,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Reset and toggle ui",
	},
	{
		mode = "n",
		"<leader>bt",
		require("alternate-toggler").toggleAlternate,
		prefix = P.misc,
		description = "Toggle booleans",
	},
<<<<<<< Updated upstream
	{
		mode = "n",
		"<leader>r",
		[[:OverseerRun <CR>]],
		prefix = P.task,
		description = "Run task",
	},
=======
	--overseer
	{ mode = "n", "<leader>r", [[:OverseerRun <CR>]], prefix = P.misc, description = "Run task" },
	-- URL handling
>>>>>>> Stashed changes
	{
		mode = { "n", "v" },
		"gx",
		"<cmd>Browse<cr>",
		prefix = P.misc,
<<<<<<< Updated upstream
		description = "Open anything under cursor in web browser",
=======
		description = "Open URL under cursor",
>>>>>>> Stashed changes
	},
	{
		mode = { "n", "v" },
		"<leader>bf",
		function()
			require("conform").format({ async = false })
		end,
<<<<<<< Updated upstream
		prefix = P.code,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Format current buffer",
	},
	-- {
	-- 	mode = { "n", "v" },
	-- 	"<leader>fn",
	-- 	function()
	-- 		local gitsigns = require("gitsigns")
	-- 		for _ = 1, #gitsigns.get_hunks() do
	-- 			gitsigns.next_hunk()
	-- 			gitsigns.select_hunk()
	-- 			require("conform").format({ async = false })
	-- 		end
	-- 		gitsigns.next_hunk()
	-- 	end,
	-- 	prefix = P.misc, description = "Format all hunks",
	-- },
	--latex
	{
		mode = "n",
		"<leader>lb",
		[[:VimtexCompile <CR>]],
<<<<<<< Updated upstream
		prefix = P.latex,
		description = "Build/compile document",
=======
		prefix = P.misc,
		description = "Latex build/compile document",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>lc",
		[[:VimtexClean <CR>]],
<<<<<<< Updated upstream
		prefix = P.latex,
		description = "Clean aux files",
=======
		prefix = P.misc,
		description = "Latex clean aux files",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>le",
		[[:VimtexTocOpen <CR>]],
<<<<<<< Updated upstream
		prefix = P.latex,
		description = "Open table of contents",
=======
		prefix = P.misc,
		description = "Latex open table of contents",
>>>>>>> Stashed changes
	},

	{
		mode = "n",
		"<leader>ln",
		[[:VimtexTocToggle <CR>]],
<<<<<<< Updated upstream
		prefix = P.latex,
		description = "Toggle table of contents",
	},
	{
		mode = "n",
		"K",
		vim.lsp.buf.hover,
		prefix = P.code,
		description = "Show documentation",
	},
	{
		mode = "n",
		"gd",
		vim.lsp.buf.definition,
		prefix = P.code,
		description = "Go to definition",
	},
	{
		mode = "n",
		"gD",
		vim.lsp.buf.declaration,
		prefix = P.code,
		description = "Go to declaration",
	},
	{
		mode = "n",
		"<leader>K",
		vim.lsp.buf.signature_help,
		prefix = P.code,
		description = "Show function signature",
	},
	{
		mode = "n",
		"gt",
		vim.lsp.buf.type_definition,
		prefix = P.code,
		description = "Go to type definition",
	},
=======
		prefix = P.misc,
		description = "Latex toggle table of contents",
	},
	--LSP
	{ mode = "n", "K", vim.lsp.buf.hover, prefix = P.misc, description = "Show documentation" },
	{ mode = "n", "gd", vim.lsp.buf.definition, prefix = P.misc, description = "Go to definition" },
	{ mode = "n", "gi", vim.lsp.buf.implementation, prefix = P.misc, description = "Show implementations" },
	{ mode = "n", "gr", vim.lsp.buf.references, prefix = P.misc, description = "Show references" },
	{ mode = "n", "gD", vim.lsp.buf.declaration, prefix = P.misc, description = "Go to declaration" },
	{ mode = "n", "<leader>K", vim.lsp.buf.signature_help, prefix = P.misc, description = "Signature help" },
	{ mode = "n", "gt", vim.lsp.buf.type_definition, prefix = P.misc, description = "Go to type definition" },
>>>>>>> Stashed changes
	{
		mode = "n",
		"<F2>",
		function()
			return ":IncRename " .. vim.fn.expand("<cword>")
		end,
		opts = { expr = true },
<<<<<<< Updated upstream
		prefix = P.code,
		description = "Rename",
	},
	{
		mode = "n",
		"<leader>ca",
		vim.lsp.buf.code_action,
		prefix = P.code,
		description = "Show code actions",
	},
=======
		prefix = P.misc,
		description = "Rename",
	},
	{ mode = "n", "<leader>ca", vim.lsp.buf.code_action, prefix = P.misc, description = "Code Action" },
>>>>>>> Stashed changes
	{
		mode = "n",
		"<leader>ds",
		vim.diagnostic.open_float,
<<<<<<< Updated upstream
		prefix = P.code,
		description = "Open LSP diagnostics in a floating window",
=======
		prefix = P.misc,
		description = "Open LSP diagnostics in a popup",
>>>>>>> Stashed changes
	},
	{
		mode = { "n", "x", "o" },
		"s",
		function()
			require("flash").jump()
		end,
<<<<<<< Updated upstream
		prefix = P.move,
		description = "Flash see :h flash.nvim.txt",
=======
		prefix = P.misc,
		description = "Flash",
	},
	{
		mode = "o",
		"r",
		function()
			require("flash").remote()
		end,
		prefix = P.misc,
		description = "Remote Flash",
	},
	{
		mode = { "o", "x" },
		"R",
		function()
			require("flash").treesitter_search()
		end,
		prefix = P.misc,
		description = "Treesitter Search",
>>>>>>> Stashed changes
	},
	{
		mode = { "c" },
		"<c-s>",
		function()
			require("flash").toggle()
		end,
<<<<<<< Updated upstream
		prefix = P.move,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
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
		"<cmd>NotesNew<cr>",
		prefix = P.notes,
		description = "New note",
	},
	{
		mode = "n",
		"<leader>nf",
		"<cmd>NotesFind<cr>",
		prefix = P.notes,
		description = "Find note",
	},
	{
		mode = "n",
		"<leader>ng",
		"<cmd>NotesGrep<cr>",
		prefix = P.notes,
		description = "Grep notes",
	},
	{
		mode = "t",
		"<esc>",
		[[<C-\><C-n>]],
		{ buffer = 0 },
<<<<<<< Updated upstream
		prefix = P.term,
=======
		prefix = P.misc,
>>>>>>> Stashed changes
		description = "Exit insert mode in terminal",
	},
	{
		mode = "n",
		"<C-]>",
		function()
			vim.cmd(":ToggleTerm direction=vertical size=120")
		end,
<<<<<<< Updated upstream
		prefix = P.term,
		description = "Open in vertical split",
=======
		prefix = P.misc,
		description = "Open terminal in vertical split",
>>>>>>> Stashed changes
	},
	{
		mode = "n",
		"<leader>[",
		function()
			vim.cmd(":ToggleTerm direction=vertical size=120")
			vim.cmd("wincmd H")
			vim.cmd("vert res 120")
		end,
<<<<<<< Updated upstream
		prefix = P.term,
		description = "Open in left vertical split",
=======
		prefix = P.misc,
		description = "Open terminal in left vertical split",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ii",
		function()
			require("various-textobjs").indentation("inner", "inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In inner indentation",
=======
		prefix = P.misc,
		description = "Text object: in inner indentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ai",
		function()
			require("various-textobjs").indentation("outer", "inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around inner indentation",
=======
		prefix = P.misc,
		description = "Text object: around inner indentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"iI",
		function()
			require("various-textobjs").indentation("inner", "outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In outer indentation",
=======
		prefix = P.misc,
		description = "Text object: in outer indentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"aI",
		function()
			require("various-textobjs").indentation("outer", "outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around outer indentation",
=======
		prefix = P.misc,
		description = "Text object: around outer indentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"R",
		function()
			require("various-textobjs").restOfIndentation()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Rest of indentation",
=======
		prefix = P.misc,
		description = "Text object: rest of indentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ig",
		function()
			require("various-textobjs").greedyOuterIndentation("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In greedyOuterIndentation",
=======
		prefix = P.misc,
		description = "Text object: in greedyOuterIndentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ag",
		function()
			require("various-textobjs").greedyOuterIndentation("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around greedyOuterIndentation",
=======
		prefix = P.misc,
		description = "Text object: around greedyOuterIndentation",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"iS",
		function()
			require("various-textobjs").subword("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In subword",
=======
		prefix = P.misc,
		description = "Text object: in subword",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"aS",
		function()
			require("various-textobjs").subword("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around subword",
=======
		prefix = P.misc,
		description = "Text object: around subword",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"C",
		function()
			require("various-textobjs").toNextClosingBracket()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "To next closing bracket",
=======
		prefix = P.misc,
		description = "Text object: to next closing bracket",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"Q",
		function()
			require("various-textobjs").toNextQuotationMark()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "To next quotation mark",
=======
		prefix = P.misc,
		description = "Text object: to next quotation mark",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"io",
		function()
			require("various-textobjs").anyBracket("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In any bracket",
=======
		prefix = P.misc,
		description = "Text object: in any bracket",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ao",
		function()
			require("various-textobjs").anyBracket("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around any bracket",
=======
		prefix = P.misc,
		description = "Text object: around any bracket",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"r",
		function()
			require("various-textobjs").restOfParagraph()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Rest of paragraph",
=======
		prefix = P.misc,
		description = "Text object: rest of paragraph",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"gG",
		function()
			require("various-textobjs").entireBuffer()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Entire buffer",
=======
		prefix = P.misc,
		description = "Text object: entire buffer",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"n",
		function()
			require("various-textobjs").nearEoL()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "1 char befor EoL",
=======
		prefix = P.misc,
		description = "Text object: 1 char befor EoL",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"g;",
		function()
			require("various-textobjs").lastChange()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Last change",
=======
		prefix = P.misc,
		description = "Text object: last change",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"i_",
		function()
			require("various-textobjs").lineCharacterwise("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In line characterwise",
=======
		prefix = P.misc,
		description = "Text object: in line characterwise",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"a_",
		function()
			require("various-textobjs").lineCharacterwise("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around line characterwise",
=======
		prefix = P.misc,
		description = "Text object: around line characterwise",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"|",
		function()
			require("various-textobjs").column()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Column",
=======
		prefix = P.misc,
		description = "Text object: column",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"gc",
		function()
			require("various-textobjs").multiCommentedLines()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Multi commented lines",
=======
		prefix = P.misc,
		description = "Text object: multi commented lines",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"iN",
		function()
			require("various-textobjs").notebookCell("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In notebook cell",
=======
		prefix = P.misc,
		description = "Text object: in notebook cell",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"aN",
		function()
			require("various-textobjs").notebookCell("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around notebook cell",
=======
		prefix = P.misc,
		description = "Text object: around notebook cell",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"iv",
		function()
			require("various-textobjs").value("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In value",
=======
		prefix = P.misc,
		description = "Text object: in value",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"av",
		function()
			require("various-textobjs").value("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around value",
=======
		prefix = P.misc,
		description = "Text object: around value",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ik",
		function()
			require("various-textobjs").key("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In key",
=======
		prefix = P.misc,
		description = "Text object: in key",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"ak",
		function()
			require("various-textobjs").key("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around key",
=======
		prefix = P.misc,
		description = "Text object: around key",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"L",
		function()
			require("various-textobjs").url()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Url",
=======
		prefix = P.misc,
		description = "Text object: url",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"in",
		function()
			require("various-textobjs").number("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In number",
=======
		prefix = P.misc,
		description = "Text object: in number",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"an",
		function()
			require("various-textobjs").number("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around number",
=======
		prefix = P.misc,
		description = "Text object: around number",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"!",
		function()
			require("various-textobjs").diagnostic()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Lsp diagnostic",
=======
		prefix = P.misc,
		description = "Text object: lsp diagnostic",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"iz",
		function()
			require("various-textobjs").closedFold("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In fold",
=======
		prefix = P.misc,
		description = "Text object: in fold",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"az",
		function()
			require("various-textobjs").closedFold("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around fold",
=======
		prefix = P.misc,
		description = "Text object: around fold",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"im",
		function()
			require("various-textobjs").chainMember("inner")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "In chain member",
=======
		prefix = P.misc,
		description = "Text object: in chain member",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"am",
		function()
			require("various-textobjs").chainMember("outer")
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Around chain member",
=======
		prefix = P.misc,
		description = "Text object: around chain member",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"gw",
		function()
			require("various-textobjs").visibleInWindow()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Visible in window",
=======
		prefix = P.misc,
		description = "Text object: visible in window",
>>>>>>> Stashed changes
	},
	{
		mode = { "o", "x" },
		"gW",
		function()
			require("various-textobjs").restOfWindow()
		end,
<<<<<<< Updated upstream
		prefix = P.text,
		description = "Rest of window",
	},
	{
		mode = { "n" },
		"<leader>sn",
		require("workspaces").next_session,
		prefix = P.work,
		description = "Next session",
	},
	{
		mode = { "n" },
		"<leader>sp",
		require("workspaces").previous_session,
		prefix = P.work,
		description = "Previous session",
	},
	{
		mode = { "n" },
		"<leader>z",
		require("workspaces").alternate_session,
		prefix = P.work,
		description = "Alternate session",
	},
	{
		mode = { "n" },
		"<leader>sz",
		require("workspaces").alternate_workspace,
		prefix = P.work,
		description = "Alternate workspace",
	},
	{
		mode = { "n" },
		"<leader>sa",
		require("workspaces").pick_session,
		prefix = P.work,
		description = "Pick session",
	},
	{
		mode = { "n" },
		"<leader>si",
		require("workspaces").switch_session_by_index_input,
		prefix = P.work,
		description = "Switch session by index",
	},
	{
		mode = { "n" },
		"<leader>sw",
		require("workspaces").pick_workspace,
		prefix = P.work,
		description = "Pick workspace",
	},
	{
		mode = { "n" },
		"<leader>scs",
		require("workspaces").create_session_input,
		prefix = P.work,
		description = "Create session",
	},
	{
		mode = { "n" },
		"<leader>srs",
		require("workspaces").rename_current_session_input,
		prefix = P.work,
		description = "Rename session",
	},
	{
		mode = { "n" },
		"<leader>scw",
		require("workspaces").create_workspace_input,
		prefix = P.work,
		description = "Create workspace",
	},
	{
		mode = { "n" },
		"<leader>srw",
		require("workspaces").rename_current_workspace_input,
		prefix = P.work,
		description = "Rename workspace",
	},
	{
		mode = { "n" },
		"<leader>sds",
		require("workspaces").delete_session_input,
		prefix = P.work,
		description = "Delete session",
	},
	{
		mode = { "n" },
		"<leader>sdw",
		require("workspaces").delete_workspace_input,
		prefix = P.work,
		description = "Delete workspace",
=======
		prefix = P.misc,
		description = "Text object: rest of window",
>>>>>>> Stashed changes
	},
})

return {}

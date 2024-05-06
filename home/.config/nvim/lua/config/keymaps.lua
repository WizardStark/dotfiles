M = {}
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
		mode = "n",
		"<esc>",
		vim.cmd.up,
		prefix = P.misc,
		description = "Write buffer",
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
		mode = { "n", "v", "o" },
		"<leader><leader>",
		function()
			require("legendary").find()
		end,
		prefix = P.misc,
		description = "Command palette",
	},
	{
		mode = "n",
		"<leader>ft",
		"<cmd>TodoTelescope<CR>",
		prefix = P.find,
		description = "TODOs, FIXs, NOTEs (etc) comments in cwd",
	},
	{
		mode = "n",
		"<leader>fg",
		function()
			require("telescope").extensions.live_grep_args.live_grep_args()
		end,
		prefix = P.find,
		description = "Grep in cwd",
	},
	{
		mode = "n",
		"<leader>fd",
		function()
			vim.cmd("Easypick changed_files")
		end,
		prefix = P.find,
		description = "Grep in cwd",
	},
	{
		mode = "n",
		"<leader>fw",
		function()
			require("telescope-live-grep-args.shortcuts").grep_word_under_cursor()
		end,
		prefix = P.find,
		description = "Word in cwd",
	},
	{
		mode = "n",
		"<leader>fa",
		function()
			require("telescope.builtin").grep_string({
				only_sort_text = true,
				word_match = "-w",
				search = "",
				prompt_title = "Fuzzy in cwd",
			})
		end,
		prefix = P.find,
		description = "Fuzzy over all lines in cwd",
	},
	{
		mode = "n",
		"<leader>fq",
		function()
			require("telescope.builtin").command_history()
		end,
		prefix = P.misc,
		description = "Show command history",
	},
	{
		mode = "v",
		"<leader>fv",
		function()
			require("telescope-live-grep-args.shortcuts").grep_visual_selection()
		end,
		prefix = P.find,
		description = "Grep visual selection in cwd",
	},
	{
		mode = "n",
		"<leader>ff",
		function()
			require("telescope.builtin").find_files()
		end,
		prefix = P.find,
		description = "Files by filename in cwd",
	},
	{
		mode = "n",
		"<leader>fu",
		function()
			require("telescope").extensions.undo.undo()
		end,
		prefix = P.misc,
		description = "Show change history (undotree)",
	},
	{
		mode = "n",
		"<leader>fr",
		function()
			require("telescope.builtin").lsp_references()
		end,
		prefix = P.find,
		description = "References to symbol under cursor",
	},
	{
		mode = "n",
		"<leader>fs",
		function()
			require("telescope.builtin").lsp_document_symbols()
		end,
		prefix = P.misc,
		description = "List all symbols in current buffer",
	},
	{
		mode = "n",
		"<leader>fc",
		function()
			require("telescope.builtin").lsp_incoming_calls()
		end,
		prefix = P.find,
		description = "Calls to this symbol",
	},
	{
		mode = "n",
		"<leader>fo",
		function()
			require("telescope.builtin").lsp_outgoing_calls()
		end,
		prefix = P.find,
		description = "Calls made by this symbol",
	},
	{
		mode = "n",
		"<leader>fi",
		function()
			require("telescope.builtin").lsp_implementations()
		end,
		prefix = P.find,
		description = "Implementations of symbol under cursor",
	},
	{
		mode = "n",
		"<leader>fh",
		function()
			require("telescope.builtin").pickers()
		end,
		prefix = P.find,
		description = "Open history of searches",
	},
	{
		mode = "n",
		"<leader>f/",
		function()
			require("telescope.builtin").current_buffer_fuzzy_find()
		end,
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
		function()
			require("telescope.builtin").git_commits()
		end,
		prefix = P.git,
		description = "Commit history",
	},
	{
		mode = "n",
		"<leader>gc",
		function()
			require("telescope.builtin").git_bcommits()
		end,
		prefix = P.git,
		description = "Commit history for current buffer",
	},
	{
		mode = { "i" },
		"<C-r>",
		function()
			require("telescope.builtin").registers()
		end,
		prefix = P.misc,
		description = "Show registers",
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
				vim.fn.system('git stash -m "nvim autostash" && git checkout ' .. commit .. " && git reset HEAD~1")
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
		mode = { "n", "i" },
		"<C-n>",
		function()
			local gitsigns = require("gitsigns")
			gitsigns.preview_hunk_inline()
			gitsigns.next_hunk()
		end,
		prefix = P.git,
		description = "Go to next change/hunk",
	},
	{
		mode = { "n", "i" },
		"<C-p>",
		function()
			local gitsigns = require("gitsigns")
			gitsigns.preview_hunk_inline()
			gitsigns.prev_hunk()
		end,
		prefix = P.git,
		description = "Go to previous change/hunk",
	},
	{
		mode = "n",
		"<leader>gb",
		function()
			require("gitsigns").blame_line({ full = true })
		end,
		prefix = P.git,
		description = "Full commit message of last commit to change line",
	},
	{
		mode = "n",
		"<leader>q",
		function()
			if vim.bo.ft == "minifiles" then
				local path = require("mini.files").get_fs_entry().path
				require("grapple").toggle({ path = path })
			else
				require("grapple").toggle()
			end
		end,
		prefix = P.nav,
		description = "Toggle file in quick access list",
	},
	{
		mode = "n",
		"<leader>t",
		function()
			require("grapple").toggle_tags()
		end,
		prefix = P.nav,
		description = "Open/close quick access list",
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
			require("utils").toggle_minifiles()
		end,
		prefix = P.nav,
		description = "Open file explorer",
	},
	{
		mode = "n",
		"<leader>mm",
		"<cmd>AerialToggle!<CR>",
		prefix = P.code,
		description = "Open function minimap",
	},
	{
		mode = "n",
		"<leader>xx",
		function()
			require("trouble").toggle()
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window",
	},
	{
		mode = "n",
		"<leader>xw",
		function()
			require("trouble").toggle("workspace_diagnostics")
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for entire workspace",
	},
	{
		mode = "n",
		"<leader>xd",
		function()
			require("trouble").toggle("document_diagnostics")
		end,
		prefix = P.diag,
		description = "Toggle diagnostics for current document",
	},
	{
		mode = "n",
		"<leader>xq",
		function()
			require("trouble").toggle("quickfix")
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window with quickfix list",
	},
	{
		mode = "n",
		"<leader>xl",
		function()
			require("trouble").toggle("loclist")
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for loclist",
	},
	{
		mode = "n",
		"<leader>xn",
		function()
			require("trouble").next({ skip_groups = true, jump = true })
		end,
		prefix = P.diag,
		description = "Go to next diagnostics item",
	},
	{
		mode = "n",
		"<leader>xp",
		function()
			require("trouble").previous({ skip_groups = true, jump = true })
		end,
		prefix = P.diag,
		description = "Go to previous diagnostic item",
	},
	{
		mode = "n",
		"<leader>/",
		function()
			require("Comment.api").toggle.linewise.current()
		end,
		prefix = P.code,
		description = "Comment current line",
	},
	{
		mode = "x",
		"<leader>/",
		function()
			vim.api.nvim_feedkeys(esc, "nx", false)
			require("Comment.api").toggle.linewise(vim.fn.visualmode())
		end,
		prefix = P.code,
		description = "Comment selection linewise",
	},
	{
		mode = "x",
		"<leader>\\",
		function()
			vim.api.nvim_feedkeys(esc, "nx", false)
			require("Comment.api").toggle.blockwise(vim.fn.visualmode())
		end,
		prefix = P.code,
		description = "Comment selection blockwise",
	},
	--debugging
	{
		mode = "n",
		"<Leader>dd",
		function()
			require("dap").toggle_breakpoint()
		end,
		prefix = P.debug,
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
			require("dap").step_into()
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
		end,
		prefix = P.debug,
		description = "Stop debug session",
	},
	{
		mode = "n",
		"<leader>du",
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
		"<leader>rt",
		[[:CompilerOpen <CR>]],
		prefix = P.task,
		description = "Run task",
	},
	{
		mode = "n",
		"<leader>ro",
		[[:CompilerToggleResults <CR>]],
		prefix = P.task,
		description = "Open task output window",
	},
	{
		mode = "n",
		"<leader>rr",
		[[:CompilerRedo <CR>]],
		prefix = P.task,
		description = "Rerun last task",
	},
	{
		mode = "n",
		"<leader>rc",
		[[:CompilerStop <CR>]],
		prefix = P.task,
		description = "Stop all tasks",
	},
	{
		mode = { "n", "v" },
		"gx",
		"<cmd>Browse<cr>",
		prefix = P.misc,
		description = "Open anything under cursor in web browser",
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
			require("trouble").toggle("lsp_definitions")
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
			require("trouble").toggle("lsp_type_definitions")
		end,
		prefix = P.code,
		description = "Go to type definition",
	},
	{
		mode = "n",
		"<F2>",
		function()
			return ":IncRename " .. vim.fn.expand("<cword>")
		end,
		opts = { expr = true },
		prefix = P.code,
		description = "Rename",
	},
	{
		mode = "n",
		"<F5>",
		function()
			local search_term = vim.fn.expand("<cword>")
			local keys = vim.api.nvim_replace_termcodes(
				":sil grep! "
					.. search_term
					.. "\r:cdo s/"
					.. search_term
					.. "//g | up<Left><Left><Left><Left><Left><Left><Left>",
				true,
				true,
				true
			)
			vim.api.nvim_feedkeys(keys, "n", false)
		end,
		opts = { expr = true },
		prefix = P.code,
		description = "Search and replace word under cursor",
	},
	{
		mode = "n",
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
		prefix = P.term,
		description = "Exit insert mode in terminal",
	},
	{
		mode = "n",
		"<C-\\>",
		function()
			local height = vim.fn.min({ 20, vim.fn.round(vim.api.nvim_win_get_height(0) * 0.3) })
			require("workspaces.toggleterms").toggle_term(vim.v.count, "horizontal", height, "bottom")
		end,
		prefix = P.term,
		description = "Open in horizontal split",
	},
	{
		mode = "n",
		"<C-]>",
		function()
			local width = vim.fn.min({ 120, vim.fn.round(vim.api.nvim_win_get_width(0) * 0.4) })
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", width, "right")
		end,
		prefix = P.term,
		description = "Open in vertical split",
	},
	{
		mode = "n",
		"<leader>[",
		function()
			local width = vim.fn.min({ 120, vim.fn.round(vim.api.nvim_win_get_width(0) * 0.4) })
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", width, "left")
		end,
		prefix = P.term,
		description = "Open in left vertical split",
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
		"gc",
		function()
			require("various-textobjs").multiCommentedLines()
		end,
		prefix = P.text,
		description = "Multi commented lines",
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
			require("notify").dismiss({ pending = true, silent = true })
		end,
		prefix = P.misc,
		description = "Dismiss all notifications",
	},
	{
		mode = { "n" },
		"<leader>p",
		function()
			vim.cmd("YankBank")
		end,
		prefix = P.misc,
		description = "Open window to select item to paste from last 10 yanks",
	},
})

return M

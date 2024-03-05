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
return {
	require("legendary").keymaps({
		--general
		{ mode = { "n", "v" }, "<leader>Q", [[<CMD>qa! <CR>]], description = "How to quit vim" },
		{ mode = { "n", "v" }, "<D-v>", [["+p]], description = "Paste with OS key" },
		{
			mode = { "i" },
			"<D-v>",
			[[<C-r>+]],
			description = "Paste with OS key",
		},
		{ mode = { "n", "v" }, "<leader>X", save_and_exit, description = "How to save and quit vim" },
		{ mode = "n", "<esc>", vim.cmd.up, description = "Write buffer" },
		{ mode = { "n", "v" }, "<leader>y", [["+y]], description = "Yank to system clipboard" },
		{
			mode = { "n", "v" },
			"<leader>D",
			[["_d]],
			description = "Delete without adding to register",
		},
		{
			mode = "n",
			"J",
			"mzJ`z",
			description = "Join lines while maintaining cursor position",
		},
		{ mode = "n", "<C-d>", "<C-d>zz", description = "Down half page and centre" }, -- Movement
		{ mode = "n", "<C-u>", "<C-u>zz", description = "Up half page and centre" }, -- Movement
		{ mode = "n", "n", "nzzzv", description = "Next occurrence and centre" }, -- Movement

		{
			mode = "n",
			"N",
			"Nzzzv",
			description = "Previous occurrence and centre",
		},
		{ mode = "v", "<leader>k", [[:s/\(.*\)/]], description = "Kirby" }, --Kirby
		{
			mode = "v",
			"<leader>uo",
			[[:s/\s\+/ /g | '<,'>s/\n/ /g | s/\s// | s/\s\+/ /g | s/\. /\.\r/g <CR>]], --Code Util
			description = "Format one line per sentence",
		},
		{
			mode = "n",
			"<leader>q",
			"<C-^>",
			description = "Alternate file", -- Navigation
		},
		{ mode = { "n", "v", "i" }, "<C-s>", vim.cmd.up, description = "Save file" },
		{
			mode = "v",
			"<M-j>",
			":m '>+1<CR>gv=gv",
			description = "Move line down", -- beslis misc (Alex 2024), maar tegnies n code util (Alex, 2 minute later)
		},
		{
			mode = "v",
			"<M-k>",
			":m '<-2<CR>gv=gv",
			description = "Move line up",
		},
		{
			mode = "v",
			"<M-h>",
			"<gv",
			description = "Move line left",
		},
		{
			mode = "v",
			"<M-l>",
			">gv",
			description = "Move line right",
		},
		{
			mode = { "n", "v" },
			"<leader>cp",
			function()
				local path = vim.fn.expand("%:p")
				vim.fn.setreg("+", path)
				vim.notify("Copied " .. path .. " to clipboard")
			end,
			description = "Copy file path to clipboard",
		},
		--ufo
		{
			mode = "n",
			"zR",
			require("ufo").openAllFolds,
			description = "Open all folds",
		},
		{
			mode = "n",
			"zM",
			require("ufo").closeAllFolds,
			description = "Close all folds",
		},
		{
			mode = "n",
			"zr",
			require("ufo").openFoldsExceptKinds,
			description = "Open all non-excluded folds",
		},
		{ mode = "n", "zm", require("ufo").closeFoldsWith, description = "Close folds with" },
		{ mode = "n", "zP", require("ufo").peekFoldedLinesUnderCursor, description = "Peek folded lines" },
		--Legendary
		{
			mode = { "n", "v" },
			"<leader><leader>",
			function()
				require("legendary").find({})
			end,
			description = "Command palette",
		},
		--Telescope
		{
			mode = "n",
			"<leader>fg",
			require("telescope").extensions.live_grep_args.live_grep_args,
			description = "Live Grep",
		},
		{
			mode = "n",
			"<leader>fw",
			require("telescope-live-grep-args.shortcuts").grep_word_under_cursor,
			description = "Find word",
		},
		{
			mode = "n",
			"<leader>fq",
			require("telescope.builtin").command_history,
			description = "Find command history",
		},
		{
			mode = "v",
			"<leader>fv",
			require("telescope-live-grep-args.shortcuts").grep_visual_selection,
			desription = "Find visual selection",
		},
		{ mode = "n", "<leader>ff", require("telescope.builtin").find_files, description = "Find files" },
		{ mode = "n", "<leader>b", require("telescope.builtin").buffers, description = "Show buffers" },
		{
			mode = "n",
			"<leader>fu",
			require("telescope").extensions.undo.undo,
			description = "Show undotree",
		},
		{
			mode = "n",
			"<leader>fr",
			require("telescope.builtin").lsp_references,
			description = "Find symbol references",
		},
		{
			mode = "n",
			"<leader>fs",
			require("telescope.builtin").lsp_document_symbols,
			description = "Document symbols",
		},
		{
			mode = "n",
			"<leader>fc",
			require("telescope.builtin").lsp_incoming_calls,
			description = "Find incoming calls",
		},
		{
			mode = "n",
			"<leader>fo",
			require("telescope.builtin").lsp_outgoing_calls,
			description = "Find outgoing calls",
		},
		{
			mode = "n",
			"<leader>fi",
			require("telescope.builtin").lsp_implementations,
			description = "Find symbol implementations",
		},
		{
			mode = "n",
			"<leader>fh",
			function()
				require("telescope.builtin").pickers()
			end,
			description = "Resume last telescope search",
		},
		{
			mode = "n",
			"<leader>f/",
			require("telescope.builtin").current_buffer_fuzzy_find,
			description = "Fuzzy find in current buffer",
		},
		{ mode = "n", "<leader>gs", require("telescope.builtin").git_status, description = "Git status" },
		{ mode = "n", "<leader>gh", require("telescope.builtin").git_commits, description = "Git commit history" },
		{
			mode = "n",
			"<leader>gc",
			require("telescope.builtin").git_bcommits,
			description = "Git commit history for current buffer",
		},
		{ mode = "i", "<C-r>", require("telescope.builtin").registers, description = "Show registers" },
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
			description = "Git checkout the commit that changed the current line",
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
			description = "Git checkout previous branch",
		},
		--git
		{
			mode = "n",
			"<leader>gd",
			"[[:Gitsigns diffthis<CR>]]",
			description = "Git diff of uncommitted changes",
		},
		{
			mode = { "n", "i" },
			"<C-n>",
			function()
				local gitsigns = require("gitsigns")
				gitsigns.preview_hunk_inline()
				gitsigns.next_hunk()
			end,
			description = "Go to next git change/hunk",
		},
		{
			mode = { "n", "i" },
			"<C-p>",
			function()
				local gitsigns = require("gitsigns")
				gitsigns.preview_hunk_inline()
				gitsigns.prev_hunk()
			end,
			description = "Go to previous git change/hunk",
		},
		{
			mode = "n",
			"<leader>gb",
			function()
				require("gitsigns").blame_line({ full = true })
			end,
			description = "Full commit message of last commit to change line",
		},
		--grapple
		{
			mode = "n",
			"<leader>a",
			require("grapple").toggle,
			description = "Toggle file in grapple",
		},
		{
			mode = "n",
			"<leader>t",
			require("grapple").toggle_tags,
			description = "Toggle grapple window",
		},
		{
			mode = "n",
			"<leader>ac",
			require("grapple").reset,
			description = "Clear grapple tags for current scope",
		},
		--smart splits
		{ mode = "n", "<A-h>", require("smart-splits").resize_left, description = "Resize left" },
		{ mode = "n", "<A-j>", require("smart-splits").resize_down, description = "Resize down" },
		{ mode = "n", "<A-k>", require("smart-splits").resize_up, description = "Resize up" },
		{ mode = "n", "<A-l>", require("smart-splits").resize_right, description = "Resize right" },
		{ mode = "n", "<C-h>", require("smart-splits").move_cursor_left, description = "Move cursor left" },
		{ mode = "n", "<C-j>", require("smart-splits").move_cursor_down, description = "Move cursor down" },
		{ mode = "n", "<C-k>", require("smart-splits").move_cursor_up, description = "Move cursor up" },
		{ mode = "n", "<C-l>", require("smart-splits").move_cursor_right, description = "Move cursor right" },
		{ mode = "n", "<A-n>", vim.cmd.tabnext, description = "Go to next tab" },
		{ mode = "n", "<A-p>", vim.cmd.tabprevious, description = "Go to previous tab" },
		{
			mode = "n",
			"<leader><C-h>",
			require("smart-splits").swap_buf_left,
			description = "Swap buffer left",
		},
		{
			mode = "n",
			"<leader><C-j>",
			require("smart-splits").swap_buf_down,
			description = "Swap buffer down",
		},
		{
			mode = "n",
			"<leader><C-k>",
			require("smart-splits").swap_buf_up,
			description = "Swap buffer up",
		},
		{
			mode = "n",
			"<leader><C-l>",
			require("smart-splits").swap_buf_right,
			description = "Swap buffer right",
		},
		-- mini.files
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
			description = "Open mini.files",
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
			description = "Open mini.files",
		},
		--aerial
		{ mode = "n", "<leader>mm", "<cmd>AerialToggle!<CR>", description = "Open function minimap" },
		--diagnostics quicklist
		{
			mode = "n",
			"<leader>xx",
			require("trouble").toggle,
			{ description = "Toggle diagnostics window" },
		},
		{
			mode = "n",
			"<leader>xw",
			function()
				require("trouble").toggle("workspace_diagnostics")
			end,
			description = "Toggle diagnostics window for entire workspace",
		},
		{
			mode = "n",
			"<leader>xd",
			function()
				require("trouble").toggle("document_diagnostics")
			end,
			description = "Toggle diagnostics for current document",
		},
		{
			mode = "n",
			"<leader>xq",
			function()
				require("trouble").toggle("quickfix")
			end,
			description = "Toggle diagnostics window with quickfix list",
		},
		{
			mode = "n",
			"<leader>xl",
			function()
				require("trouble").toggle("loclist")
			end,
			description = "Toggle diagnostics window for loclist",
		},
		--comment keybinds
		{
			mode = "n",
			"<leader>/",
			require("Comment.api").toggle.linewise.current,
			description = "Comment current line",
		},
		{
			mode = "x",
			"<leader>/",
			function()
				vim.api.nvim_feedkeys(esc, "nx", false)
				require("Comment.api").toggle.linewise(vim.fn.visualmode())
			end,
			description = "Comment selection linewise",
		},
		{
			mode = "x",
			"<leader>\\",
			function()
				vim.api.nvim_feedkeys(esc, "nx", false)
				require("Comment.api").toggle.blockwise(vim.fn.visualmode())
			end,
			description = "Comment selection blockwise",
		},
		--debugging
		{
			mode = "n",
			"<Leader>dd",
			function()
				require("dap").toggle_breakpoint()
			end,
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
			description = "Toggle breakpoint",
		},
		{
			mode = "n",
			"<leader>dl",
			function()
				trigger_dap(require("dap").run_last)
			end,
			description = "Choose nearest test",
		},
		{
			mode = "n",
			"<leader>do",
			function()
				require("dap").step_over()
			end,
			description = "Step over",
		},
		{
			mode = "n",
			"<leader>di",
			function()
				require("dap").step_into()
			end,
			description = "Step into",
		},
		{
			mode = "n",
			"<leader>du",
			function()
				require("dap").step_out()
			end,
			description = "Step out",
		},
		{
			mode = "n",
			"<leader>db",
			function()
				require("dap").step_back()
			end,
			description = "Step back",
		},
		{
			mode = "n",
			"<leader>dh",
			function()
				require("dap").run_to_cursor()
			end,
			description = "Run to cursor",
		},
		{
			mode = "n",
			"<leader>dc",
			continue,
			description = "Start debug session, or continue session",
		},
		{
			mode = "n",
			"<leader>de",
			function()
				require("dap").terminate()
				require("dapui").close()
			end,
			description = "Terminate debug session",
		},
		{
			mode = "n",
			"<leader>du",
			function()
				require("dapui").toggle({ reset = true })
			end,
			description = "Reset and toggle ui",
		},
		--toggle booleans
		{
			mode = "n",
			"<leader>bt",
			require("alternate-toggler").toggleAlternate,
			description = "Toggle booleans",
		},
		--overseer
		{ mode = "n", "<leader>r", [[:OverseerRun <CR>]], description = "Run task" },
		-- URL handling
		{
			mode = { "n", "v" },
			"gx",
			"<cmd>Browse<cr>",
			description = "Open URL under cursor",
		},
		--conform
		{
			mode = { "n", "v" },
			"<leader>bf",
			function()
				require("conform").format({ async = false })
			end,
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
		-- 	description = "Format all hunks",
		-- },
		--latex
		{
			mode = "n",
			"<leader>lb",
			[[:VimtexCompile <CR>]],
			description = "Latex build/compile document",
		},
		{
			mode = "n",
			"<leader>lc",
			[[:VimtexClean <CR>]],
			description = "Latex clean aux files",
		},
		{
			mode = "n",
			"<leader>le",
			[[:VimtexTocOpen <CR>]],
			description = "Latex open table of contents",
		},

		{
			mode = "n",
			"<leader>ln",
			[[:VimtexTocToggle <CR>]],
			description = "Latex toggle table of contents",
		},
		--LSP
		{ mode = "n", "K", vim.lsp.buf.hover, description = "Show documentation" },
		{ mode = "n", "gd", vim.lsp.buf.definition, description = "Go to definition" },
		{ mode = "n", "gi", vim.lsp.buf.implementation, description = "Show implementations" },
		{ mode = "n", "gr", vim.lsp.buf.references, description = "Show references" },
		{ mode = "n", "gD", vim.lsp.buf.declaration, description = "Go to declaration" },
		{ mode = "n", "<leader>K", vim.lsp.buf.signature_help, description = "Signature help" },
		{ mode = "n", "gt", vim.lsp.buf.type_definition, description = "Go to type definition" },
		{
			mode = "n",
			"<F2>",
			function()
				return ":IncRename " .. vim.fn.expand("<cword>")
			end,
			opts = { expr = true },
			description = "Rename",
		},
		{ mode = "n", "<leader>ca", vim.lsp.buf.code_action, description = "Code Action" },
		{
			mode = "n",
			"<leader>ds",
			vim.diagnostic.open_float,
			description = "Open LSP diagnostics in a popup",
		},
		--session management
		{
			mode = "n",
			"<leader>sd",
			[[:SessionManager delete_current_dir_session<CR>]],
			description = "Delete session for current directory",
		},
		{
			mode = "n",
			"<leader>sl",
			[[:SessionManager load_session<CR>]],
			description = "Load session for selected directory",
		},
		--flash
		{
			mode = { "n", "x", "o" },
			"s",
			function()
				require("flash").jump()
			end,
			description = "Flash",
		},
		{
			mode = "o",
			"r",
			function()
				require("flash").remote()
			end,
			description = "Remote Flash",
		},
		{
			mode = { "o", "x" },
			"R",
			function()
				require("flash").treesitter_search()
			end,
			description = "Treesitter Search",
		},
		{
			mode = { "c" },
			"<c-s>",
			function()
				require("flash").toggle()
			end,
			description = "Toggle Flash Search",
		},
		--Mason
		{ mode = "n", "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" },
		--Notes
		{ mode = "n", "<leader>nn", "<cmd>NotesNew<cr>", desc = "New note" },
		{ mode = "n", "<leader>nf", "<cmd>NotesFind<cr>", desc = "Find note" },
		{ mode = "n", "<leader>ng", "<cmd>NotesGrep<cr>", desc = "Grep notes" },
		--Terminal
		{
			mode = "t",
			"<esc>",
			[[<C-\><C-n>]],
			{ buffer = 0 },
			description = "Exit insert mode in terminal",
		},
		{
			mode = "n",
			"<C-]>",
			function()
				vim.cmd(":ToggleTerm direction=vertical size=120")
			end,
			description = "Open terminal in vertical split",
		},
		{
			mode = "n",
			"<leader>[",
			function()
				vim.cmd(":ToggleTerm direction=vertical size=120")
				vim.cmd("wincmd H")
				vim.cmd("vert res 120")
			end,
			description = "Open terminal in left vertical split",
		},
		{
			mode = { "o", "x" },
			"ii",
			function()
				require("various-textobjs").indentation("inner", "inner")
			end,
			description = "Text object: in inner indentation",
		},
		{
			mode = { "o", "x" },
			"ai",
			function()
				require("various-textobjs").indentation("outer", "inner")
			end,
			description = "Text object: around inner indentation",
		},
		{
			mode = { "o", "x" },
			"iI",
			function()
				require("various-textobjs").indentation("inner", "outer")
			end,
			description = "Text object: in outer indentation",
		},
		{
			mode = { "o", "x" },
			"aI",
			function()
				require("various-textobjs").indentation("outer", "outer")
			end,
			description = "Text object: around outer indentation",
		},
		{
			mode = { "o", "x" },
			"R",
			function()
				require("various-textobjs").restOfIndentation()
			end,
			description = "Text object: rest of indentation",
		},
		{
			mode = { "o", "x" },
			"ig",
			function()
				require("various-textobjs").greedyOuterIndentation("inner")
			end,
			description = "Text object: in greedyOuterIndentation",
		},
		{
			mode = { "o", "x" },
			"ag",
			function()
				require("various-textobjs").greedyOuterIndentation("outer")
			end,
			description = "Text object: around greedyOuterIndentation",
		},
		{
			mode = { "o", "x" },
			"iS",
			function()
				require("various-textobjs").subword("inner")
			end,
			description = "Text object: in subword",
		},
		{
			mode = { "o", "x" },
			"aS",
			function()
				require("various-textobjs").subword("outer")
			end,
			description = "Text object: around subword",
		},
		{
			mode = { "o", "x" },
			"C",
			function()
				require("various-textobjs").toNextClosingBracket()
			end,
			description = "Text object: to next closing bracket",
		},
		{
			mode = { "o", "x" },
			"Q",
			function()
				require("various-textobjs").toNextQuotationMark()
			end,
			description = "Text object: to next quotation mark",
		},
		{
			mode = { "o", "x" },
			"io",
			function()
				require("various-textobjs").anyBracket("inner")
			end,
			description = "Text object: in any bracket",
		},
		{
			mode = { "o", "x" },
			"ao",
			function()
				require("various-textobjs").anyBracket("outer")
			end,
			description = "Text object: around any bracket",
		},
		{
			mode = { "o", "x" },
			"r",
			function()
				require("various-textobjs").restOfParagraph()
			end,
			description = "Text object: rest of paragraph",
		},
		{
			mode = { "o", "x" },
			"gG",
			function()
				require("various-textobjs").entireBuffer()
			end,
			description = "Text object: entire buffer",
		},
		{
			mode = { "o", "x" },
			"n",
			function()
				require("various-textobjs").nearEoL()
			end,
			description = "Text object: 1 char befor EoL",
		},
		{
			mode = { "o", "x" },
			"g;",
			function()
				require("various-textobjs").lastChange()
			end,
			description = "Text object: last change",
		},
		{
			mode = { "o", "x" },
			"i_",
			function()
				require("various-textobjs").lineCharacterwise("inner")
			end,
			description = "Text object: in line characterwise",
		},
		{
			mode = { "o", "x" },
			"a_",
			function()
				require("various-textobjs").lineCharacterwise("outer")
			end,
			description = "Text object: around line characterwise",
		},
		{
			mode = { "o", "x" },
			"|",
			function()
				require("various-textobjs").column()
			end,
			description = "Text object: column",
		},
		{
			mode = { "o", "x" },
			"gc",
			function()
				require("various-textobjs").multiCommentedLines()
			end,
			description = "Text object: multi commented lines",
		},
		{
			mode = { "o", "x" },
			"iN",
			function()
				require("various-textobjs").notebookCell("inner")
			end,
			description = "Text object: in notebook cell",
		},
		{
			mode = { "o", "x" },
			"aN",
			function()
				require("various-textobjs").notebookCell("outer")
			end,
			description = "Text object: around notebook cell",
		},
		{
			mode = { "o", "x" },
			"iv",
			function()
				require("various-textobjs").value("inner")
			end,
			description = "Text object: in value",
		},
		{
			mode = { "o", "x" },
			"av",
			function()
				require("various-textobjs").value("outer")
			end,
			description = "Text object: around value",
		},
		{
			mode = { "o", "x" },
			"ik",
			function()
				require("various-textobjs").key("inner")
			end,
			description = "Text object: in key",
		},
		{
			mode = { "o", "x" },
			"ak",
			function()
				require("various-textobjs").key("outer")
			end,
			description = "Text object: around key",
		},
		{
			mode = { "o", "x" },
			"L",
			function()
				require("various-textobjs").url()
			end,
			description = "Text object: url",
		},
		{
			mode = { "o", "x" },
			"in",
			function()
				require("various-textobjs").number("inner")
			end,
			description = "Text object: in number",
		},
		{
			mode = { "o", "x" },
			"an",
			function()
				require("various-textobjs").number("outer")
			end,
			description = "Text object: around number",
		},
		{
			mode = { "o", "x" },
			"!",
			function()
				require("various-textobjs").diagnostic()
			end,
			description = "Text object: lsp diagnostic",
		},
		{
			mode = { "o", "x" },
			"iz",
			function()
				require("various-textobjs").closedFold("inner")
			end,
			description = "Text object: in fold",
		},
		{
			mode = { "o", "x" },
			"az",
			function()
				require("various-textobjs").closedFold("outer")
			end,
			description = "Text object: around fold",
		},
		{
			mode = { "o", "x" },
			"im",
			function()
				require("various-textobjs").chainMember("inner")
			end,
			description = "Text object: in chain member",
		},
		{
			mode = { "o", "x" },
			"am",
			function()
				require("various-textobjs").chainMember("outer")
			end,
			description = "Text object: around chain member",
		},
		{
			mode = { "o", "x" },
			"gw",
			function()
				require("various-textobjs").visibleInWindow()
			end,
			description = "Text object: visible in window",
		},
		{
			mode = { "o", "x" },
			"gW",
			function()
				require("various-textobjs").restOfWindow()
			end,
			description = "Text object: rest of window",
		},
	}),
}

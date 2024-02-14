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
require("legendary").keymaps({
	--general
	{ mode = { "n", "v" }, "<leader>Q", [[<CMD>qa! <CR>]], description = "How to quit vim" },
	{ mode = { "n", "v" }, "<leader>X", save_and_exit, description = "How to save and quit vim" },
	{ mode = "i", "jf", "<esc>", description = "Exit insert mode" },
	{ mode = "i", "jk", "<right>", description = "Move right one space" },
	{ mode = { "n", "v" }, "<leader>y", [["+y]], description = "Yank to system clipboard" },
	{
		mode = { "n", "v" },
		"<leader>D",
		[["_d]],
		description = "Delete without adding to register",
	},
	{
		mode = { "n", "v" },
		"<leader>P",
		[["_dP]],
		description = "Paste without overriding register",
	},
	{
		mode = "n",
		"J",
		"mzJ`z",
		description = "Join lines while maintaining cursor position",
	},
	{ mode = "n", "<C-d>", "<C-d>zz", description = "Down half page and centre" },
	{ mode = "n", "<C-u>", "<C-u>zz", description = "Up half page and centre" },
	{ mode = "n", "n", "nzzzv", description = "Next occurrence and centre" },
	{
		mode = "n",
		"N",
		"Nzzzv",
		description = "Previous occurrence and centre",
	},
	{ mode = "v", "<leader>k", [[:s/\(.*\)/]], description = "Kirby" },
	{
		mode = "v",
		"<leader>uo",
		[[:s/\s\+/ /g | '<,'>s/\n/ /g | s/\s// | s/\s\+/ /g | s/\. /\.\r/g <CR>]],
		description = "Format one line per sentence",
	},
	{
		mode = "n",
		"<leader>q",
		"<C-^>",
		description = "Alternate file",
	},
	{ mode = { "n", "v", "i" }, "<C-s>", [[<CMD>w <CR>]], description = "Save file" },
	{
		mode = "v",
		"<M-j>",
		":m '>+1<CR>gv=gv",
		description = "Move line down",
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
		require("legendary").find,
		description = "Command palette",
	},
	--Bookmarks
	{
		mode = "n",
		"ma",
		require("bookmarks").bookmark_toggle,
		description = "Toggle bookmark on current line",
	},
	{
		mode = "n",
		"mi",
		require("bookmarks").bookmark_ann,
		description = "Add or edit bookmark annotation",
	},
	{
		mode = "n",
		"mc",
		require("bookmarks").bookmark_clean,
		description = "Delete current buffer bookmarks",
	},
	{
		mode = "n",
		"mn",
		require("bookmarks").bookmark_next,
		description = "Go to next bookmark in buffer",
	},
	{
		mode = "n",
		"mp",
		require("bookmarks").bookmark_prev,
		description = "Go to previous bookmark in buffer",
	},
	{
		mode = "n",
		"ml",
		require("bookmarks").bookmark_list,
		description = "List files that have bookmarks",
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
		mode = "v",
		"<leader>fv",
		require("telescope-live-grep-args.shortcuts").grep_visual_selection,
		desription = "Find visual selection",
	},
	{ mode = "n", "<leader>ff", require("telescope.builtin").find_files, description = "Find files" },
	{ mode = "n", "<leader>b", require("telescope.builtin").buffers, description = "Show buffers" },
	{
		mode = "n",
		"<leader>fm",
		[[<Cmd>Telescope bookmarks list<CR>]],
		description = "List all bookmarks in telescope",
	},
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
		require("telescope.builtin").resume,
		description = "Resume last telescope search",
	},
	{ mode = "n", "<leader>gs", require("telescope.builtin").git_status, description = "Git status" },
	{ mode = "n", "<leader>gc", require("telescope.builtin").git_commits, description = "Git commits" },
	{
		mode = "n",
		"<leader>gc",
		require("telescope.builtin").git_bcommits,
		description = "Git commits for current buffer",
	},
	{ mode = "i", "<C-r>", require("telescope.builtin").registers, description = "Show registers" },
	--harpoon
	{
		mode = "n",
		"<leader>a",
		require("harpoon.mark").add_file,
		description = "Add file to harpoon",
	},
	{
		mode = "n",
		"<leader>t",
		require("harpoon.ui").toggle_quick_menu,
		description = "Toggle harpoon ui",
	},
	--smart splits
	{ mode = "n", "<A-h>", require("smart-splits").resize_left, description = "Resize left" },
	{ mode = "n", "<A-j>", require("smart-splits").resize_down, description = "Resize down" },
	{ mode = "n", "<A-k>", require("smart-splits").resize_up, description = "Resize up" },
	{ mode = "n", "<A-l>", require("smart-splits").resize_right, description = "Resize right" },
	{ mode = "n", "<C-h>", require("smart-splits").move_cursor_left, description = "Move cursor left" },
	{ mode = "n", "<C-j>", require("smart-splits").move_cursor_down, description = "Move cursor down" },
	{ mode = "n", "<C-k>", require("smart-splits").move_cursor_up, description = "Move cursor up" },
	{
		mode = "n",
		"<C-l>",
		require("smart-splits").move_cursor_right,
		description = "Move cursor right",
	},
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
	--nvim-tree
	{
		mode = "n",
		"<leader>n",
		function()
			require("nvim-tree.api").tree.toggle({
				find_file = true,
				focus = true,
				path = "<arg>",
				update_root = "<bang>",
			})
		end,
		description = "Toggle file tree",
	},
	--mini.files
	{
		mode = "n",
		"<leader>e",
		function()
			local MiniFiles = require("mini.files")
			if not MiniFiles.close() then
				local function open_current_file()
					MiniFiles.open(vim.fn.expand("%:p"))
				end

				if not pcall(open_current_file) then
					MiniFiles.open()
				end
			end
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
	--git
	{ mode = "n", "<leader>gg", "[[:LazyGit<CR>]]", description = "Open LazyGit" },
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
	--multiple cursors
	{
		mode = { "n", "i" },
		"<C-M-j>",
		[[<Cmd>MultipleCursorsAddDown<CR>]],
		description = "Add cursor downwards",
	},
	{
		mode = { "n", "i" },
		"<C-M-k>",
		[[<Cmd>MultipleCursorsAddUp<CR>]],
		description = "Add cursor upwards",
	},
	{
		mode = { "n", "i" },
		"<C-LeftMouse>",
		[[<Cmd>MultipleCursorsMouseAddDelete<CR>]],
		description = "Add cursor upwards",
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
		mode = "n",
		"<leader>bf",
		require("conform").format,
		description = "Format current buffer",
	},
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
	{ mode = "n", "<F2>", vim.lsp.buf.rename, description = "Rename" },
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
		"<leader>ssd",
		[[:SessionManager delete_session<CR>]],
		description = "Delete session for selected directory",
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
	{ mode = "t", "jf", [[<C-\><C-n>]], { buffer = 0 }, description = "Exit insert mode in terminal" },
	{
		mode = "t",
		"<C-h>",
		[[<Cmd>wincmd h<CR>]],
		{ buffer = 0 },
		description = "Move left from terminal",
	},
	{
		mode = "t",
		"<C-j>",
		[[<Cmd>wincmd j<CR>]],
		{ buffer = 0 },
		description = "Move down from terminal",
	},
	{
		mode = "t",
		"<C-k>",
		[[<Cmd>wincmd k<CR>]],
		{ buffer = 0 },
		description = "Move up from terminal",
	},
	{
		mode = "t",
		"<C-l>",
		[[<Cmd>wincmd l<CR>]],
		{ buffer = 0 },
		description = "Move right from terminal",
	},
})

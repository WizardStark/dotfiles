return {
	{
		"mrjones2014/legendary.nvim",
		priority = 10000,
		lazy = false,
		config = function()
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

			local open_url = function()
				if vim.fn.has("unix") == 1 then
					return '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>'
				elseif vim.fn.has("mac") == 1 then
					return '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>'
				end
			end

			require("legendary").setup({
				select_prompt = " Command palette",
				commands = {
					{ ":Lazy", description = "Open Lazy plugin manager" },
					{ ":Mason", description = "Open Mason LSP manager" },
					{ ":LspInfo", description = "Show LSP information for current buffer" },
					{ ":LspLog", description = "Open LSP log in a new buffer" },
					{ ":LspStop", description = "Stop currently attached LSP" },
					{ ":LspStart", description = "Start LSP for current buffer" },
					{ ":LspRestart", description = "Restart currently attached LSP" },
					{
						":Gitsigns diffthis {diff_target}",
						unfinished = true,
						description = "Git diff, requires diff target, e.g. ~1 for previous commit",
					},
					{
						":GitMessenger",
						description = "Show commit message for current line",
					},
					{
						":Gitsigns stage_hunk<CR>",
						description = "Git stage visual selection",
					},
					{
						":Gitsigns stage_buffer<CR>",
						description = "Git stage buffer",
					},
					{
						":Gitsigns reset_hunk<CR>",
						description = "Git reset visual selection",
					},
					{
						":Gitsigns reset_buffer<CR>",
						description = "Git reset buffer",
					},
                    {
                        ":VimtexStop<CR>",
                        description = "Stop Latex compilation",
                    },
                    {
                        ":VimtexStopAll<CR>",
                        description = "Stop  all Latex compilation",
                    },
				},
				keymaps = {
					--general
					{ mode = { "n", "v" }, "<leader>Q", [[<CMD>qa! <CR>]], description = "How to quit vim" },
					{ mode = "i", "jf", "<esc>", description = "Exit insert mode" },
					{ mode = "i", "jk", "<right>", description = "Move right one space" },
					{ mode = { "n", "v" }, "<leader>y", [["+y]], description = "Yank to system clipboard" },
					{ mode = { "n", "v" }, "<leader>D", [["_d]], description = "Delete without adding to register" },
					{ mode = { "n", "v" }, "<leader>P", [["_dP]], description = "Paste without overriding register" },
					{ mode = "n", "J", "mzJ`z", description = "Join lines while maintaining cursor position" },
					{ mode = "n", "<C-d>", "<C-d>zz", description = "Down half page and centre" },
					{ mode = "n", "<C-u>", "<C-u>zz", description = "Up half page and centre" },
					{ mode = "n", "n", "nzzzv", description = "Next occurrence and centre" },
					{ mode = "n", "N", "Nzzzv", description = "Previous occurrence and centre" },
					{ mode = "v", "<leader>k", [[:s/\(.*\)/]], description = "Kirby" },
                    { mode = "v", "<leader>uo", [[:s/\s\+/ /g | '<,'>s/\n/ /g | s/\s// | s/\s\+/ /g | s/\. /\.\r/g <CR>]], description = "Format one line per sentence" },
					{ mode = "n", "<leader>q", "<C-^>", description = "Alternate file" },
					{ mode = { "n", "v", "i" }, "<C-s>", [[<CMD>w <CR>]], description = "Save file" },
					{ mode = "v", "<M-j>", ":m '>+1<CR>gv=gv", description = "Move line down" },
					{ mode = "v", "<M-k>", ":m '<-2<CR>gv=gv", description = "Move line up" },
					{ mode = "v", "<M-h>", "<gv", description = "Move line left" },
					{ mode = "v", "<M-l>", ">gv", description = "Move line right" },
					--ufo
					{ mode = "n", "zR", require("ufo").openAllFolds, description = "Open all folds" },
					{ mode = "n", "zM", require("ufo").closeAllFolds, description = "Close all folds" },
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
								MiniFiles.open(vim.fn.expand("%:p"))
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
						"<leader>df",
						function()
							trigger_dap(require("jdtls").test_class())
						end,
						description = "Debug test class",
					},
					{
						mode = "n",
						"<leader>dn",
						function()
							trigger_dap(require("jdtls").test_nearest_method())
						end,
						description = "Debug neartest test method",
					},
					{
						mode = "n",
						"<leader>dt",
						function()
							trigger_dap(require("jdtls").test_nearest_method)
						end,
						description = "Debug nearest test",
					},
					{
						mode = "n",
						"<leader>dT",
						function()
							trigger_dap(require("jdtls").test_class)
						end,
						description = "Debug test class",
					},
					{
						mode = "n",
						"<leader>dp",
						function()
							trigger_dap(require("jdtls").pick_test)
						end,
						description = "Choose nearest test",
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
					{ mode = "n", "<leader>dc", continue, description = "Start debug session, or continue session" },
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
					-- source: https://sbulav.github.io/vim/neovim-opening-urls/
					{ mode = "", "gx", open_url, description = "Open URL under cursor" },
					--conform
					{ mode = "n", "<leader>bf", require("conform").format, description = "Format current buffer" },
                    --latex
					{ mode = "n", "<leader>lb", [[:VimtexCompile <CR>]], description = "Latex build/compile document" },
					{ mode = "n", "<leader>lc", [[:VimtexClean <CR>]], description = "Latex clean aux files" },
					{ mode = "n", "<leader>le", [[:VimtexTocOpen <CR>]], description = "Latex open table of contents" },
					{ mode = "n", "<leader>ln", [[:VimtexTocToggle <CR>]], description = "Latex toggle table of contents" },
				},
			})
		end,
	},
}

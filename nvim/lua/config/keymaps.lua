local map = vim.keymap.set

--general
map("n", "H", "gT", { desc = "Previous Tab" })
map("n", "L", "gt", { desc = "Next Tab" })
map("i", "jf", "<esc>", { desc = "Exit insert mode" })
map("i", "jk", "<right>", { desc = "Move right one space" })
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Probably also yank to system clipboard" })
map({ "n", "v" }, "<leader>D", [["_d]], { desc = "Delete without adding to register" })
map({ "n", "v" }, "<leader>P", [["_dP]], { desc = "Paste without overriding register" })
map("n", "J", "mzJ`z", { desc = "Join lines while maintaining cursor position" })
map("n", "<C-d>", "<C-d>zz", { desc = "Down half page and centre" })
map("n", "<C-u>", "<C-u>zz", { desc = "Up half page and centre" })
map("n", "n", "nzzzv", { desc = "Next occurrence and centre" })
map("n", "N", "Nzzzv", { desc = "Previous occurrence and centre" })
map("v", "<leader>k", [[:s/\(.*\)/]], { desc = "Kirby" })
map("n", "<leader>q", "<C-^>", { desc = "Alternate file" })
map({ "n", "v", "i" }, "<C-s>", [[:w <CR>]], { desc = "Save file" })

--ufo
map("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
map("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
map("n", "zr", require("ufo").openFoldsExceptKinds, { desc = "Open all non-excluded folds" })
map("n", "zm", require("ufo").closeFoldsWith, { desc = "Close folds with" }) -- closeAllFolds == closeFoldsWith(0)
map("n", "zP", require("ufo").peekFoldedLinesUnderCursor, { desc = "Peek folded lines" })

--Telescope
map("n", "<leader>fg", require("telescope").extensions.live_grep_args.live_grep_args, { desc = "Live Grep" })
map("n", "<leader>ff", require("telescope.builtin").find_files, { desc = "Find files" })
map("n", "<leader>b", require("telescope.builtin").buffers, { desc = "Show buffers" })
map("n", "<leader>fm", require("telescope.builtin").marks, { desc = "Show marks" })
map("n", "<leader>fr", require("telescope.builtin").lsp_references, { desc = "Find symbol references" })
map("n", "<leader>fs", require("telescope.builtin").lsp_document_symbols, { desc = "Document symbols" })
map("n", "<leader>fc", require("telescope.builtin").lsp_incoming_calls, { desc = "Find incoming calls" })
map("n", "<leader>fo", require("telescope.builtin").lsp_outgoing_calls, { desc = "Find outgoing calls" })
map("n", "<leader>fi", require("telescope.builtin").lsp_implementations, { desc = "Find symbol implementations" })
map("n", "<leader>fh", require("telescope.builtin").resume, { desc = "Resume last telescope search" })
map("n", "<leader>gs", require("telescope.builtin").git_status, { desc = "Git status" })
map("n", "<leader>gc", require("telescope.builtin").git_commits, { desc = "Git commits" })
map("n", "<leader>gc", require("telescope.builtin").git_bcommits, { desc = "Git commits for current buffer" })
map("i", "<C-r>", require("telescope.builtin").registers, { desc = "Show registers" })
map("n", "<leader>fp", [[:Telescope neovim-project history<CR>]], { desc = "Show projects history" })

--harpoon
map("n", "<leader>a", require("harpoon.mark").add_file, { desc = "Add file to harpoon" })
map("n", "<leader>t", require("harpoon.ui").toggle_quick_menu, { desc = "Toggle harpoon ui" })
map("n", "<leader>hm", [[:Telescope harpoon marks<CR>]], { desc = "Show harpoon marks in telescope" })
map("n", "<leader>hn", require("harpoon.ui").nav_next, { desc = "Go to next harpoon file" })
map("n", "<leader>hp", require("harpoon.ui").nav_prev, { desc = "Go to previous harpoon file" })

--nvim-tree
map("n", "<leader>et", function()
	require("nvim-tree.api").tree.toggle({
		find_file = true,
		focus = true,
		path = "<arg>",
		update_root = "<bang>",
	})
end, { desc = "Toggle file tree" })
--mini.files
map("n", "<leader>e", function()
	local MiniFiles = require("mini.files")
	if not MiniFiles.close() then
		MiniFiles.open()
	end
end, { desc = "Open mini.files" })

--aerial
map("n", "<leader>mm", "<cmd>AerialToggle!<CR>", { desc = "Open function minimap" })

--diagnostics quicklist
map("n", "<leader>xx", require("trouble").toggle, { desc = "Toggle diagnostics window" })
map("n", "<leader>xw", function()
	require("trouble").toggle("workspace_diagnostics")
end, { desc = "Toggle diagnostics window for entire workspace" })
map("n", "<leader>xd", function()
	require("trouble").toggle("document_diagnostics")
end, { desc = "Toggle diagnostics for current document" })
map("n", "<leader>xq", function()
	require("trouble").toggle("quickfix")
end, { desc = "Toggle diagnostics window with quickfix list" })
map("n", "<leader>xl", function()
	require("trouble").toggle("loclist")
end, { desc = "Toggle diagnostics window for loclist" })
map("n", "gR", function()
	require("trouble").toggle("lsp_references")
end)

--git
map("n", "<leader>gg", "[[:LazyGit<CR>]]", { desc = "Open LazyGit" })
map("n", "<leader>gd", "[[:Gitsigns diffthis<CR>]]", { desc = "Git diff of uncommitted changes" })

-- URL handling
-- source: https://sbulav.github.io/vim/neovim-opening-urls/
if vim.fn.has("mac") == 1 then
	map("", "gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>', {})
elseif vim.fn.has("unix") == 1 then
	map("", "gx", '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', {})
end

--comment keybinds
map("n", "<leader>/", require("Comment.api").toggle.linewise.current, { desc = "Comment current line" })
local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

map("x", "<leader>/", function()
	vim.api.nvim_feedkeys(esc, "nx", false)
	require("Comment.api").toggle.linewise(vim.fn.visualmode())
end, { desc = "Comment selection linewise" })

map("x", "<leader>\\", function()
	vim.api.nvim_feedkeys(esc, "nx", false)
	require("Comment.api").toggle.blockwise(vim.fn.visualmode())
end, { desc = "Comment selection blockwise" })

--debugging
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

map("n", "<Leader>dd", function()
	require("dap").toggle_breakpoint()
end, { desc = "Toggle breakpoint" })
map("n", "<Leader>dD", function()
	vim.ui.input({ prompt = "Condition: " }, function(input)
		require("dap").set_breakpoint(input)
	end)
end, { desc = "Toggle breakpoint" })
map("n", "<leader>df", function()
	trigger_dap(require("jdtls").test_class())
end, { desc = "Debug test class" })
map("n", "<leader>dn", function()
	trigger_dap(require("jdtls").test_nearest_method())
end, { desc = "Debug neartest test method" })
map("n", "<leader>dt", function()
	trigger_dap(require("jdtls").test_nearest_method)
end, { desc = "Debug nearest test" })
map("n", "<leader>dT", function()
	trigger_dap(require("jdtls").test_class)
end, { desc = "Debug test class" })
map("n", "<leader>dp", function()
	trigger_dap(require("jdtls").pick_test)
end, { desc = "Choose nearest test" })
map("n", "<leader>dl", function()
	trigger_dap(require("dap").run_last)
end, { desc = "Choose nearest test" })
map("n", "<leader>do", function()
	require("dap").step_over()
end, { desc = "Step over" })
map("n", "<leader>di", function()
	require("dap").step_into()
end, { desc = "Step into" })
map("n", "<leader>du", function()
	require("dap").step_out()
end, { desc = "Step out" })
map("n", "<leader>db", function()
	require("dap").step_back()
end, { desc = "Step back" })
map("n", "<leader>dh", function()
	require("dap").run_to_cursor()
end, { desc = "Run to cursor" })
map("n", "<leader>dc", continue, { desc = "Start debug session, or continue session" })
map("n", "<leader>de", function()
	require("dap").terminate()
	require("dapui").close()
end, { desc = "Terminate debug session" })
map("n", "<leader>du", function()
	require("dapui").toggle({ reset = true })
end, { desc = "Reset and toggle ui" })

--terminal
function _G.set_terminal_keymaps()
	local opts = { buffer = 0 }
	map("t", "<esc>", [[<C-\><C-n>]], opts)
	map("t", "jf", [[<C-\><C-n>]], opts)
	map("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
	map("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
	map("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
	map("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
	map("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end
vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

--undotree
map("n", "<leader><F5>", vim.cmd.UndotreeToggle, { desc = "Open the undotree" })

--smart splits
-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
map("n", "<A-h>", require("smart-splits").resize_left, { desc = "Resize left" })
map("n", "<A-j>", require("smart-splits").resize_down, { desc = "Resize down" })
map("n", "<A-k>", require("smart-splits").resize_up, { desc = "Resize up" })
map("n", "<A-l>", require("smart-splits").resize_right, { desc = "Resize right" })
-- moving between splits
map("n", "<C-h>", require("smart-splits").move_cursor_left, { desc = "Move cursor left" })
map("n", "<C-j>", require("smart-splits").move_cursor_down, { desc = "Move cursor down" })
map("n", "<C-k>", require("smart-splits").move_cursor_up, { desc = "Move cursor up" })
map("n", "<C-l>", require("smart-splits").move_cursor_right, { desc = "Move cursor right" })
-- swapping buffers between windows
map("n", "<leader><leader>h", require("smart-splits").swap_buf_left, { desc = "Swap buffer left" })
map("n", "<leader><leader>j", require("smart-splits").swap_buf_down, { desc = "Swap buffer down" })
map("n", "<leader><leader>k", require("smart-splits").swap_buf_up, { desc = "Swap buffer up" })
map("n", "<leader><leader>l", require("smart-splits").swap_buf_right, { desc = "Swap buffer right" })

--toggle booleans
map("n", "<leader>bt", require("alternate-toggler").toggleAlternate, { desc = "Toggle booleans" })

--multiple cursors
map({ "n", "i" }, "<C-M-j>", [[<Cmd>MultipleCursorsAddDown<CR>]], { desc = "Add cursor downwards" })
map({ "n", "i" }, "<C-M-k>", [[<Cmd>MultipleCursorsAddUp<CR>]], { desc = "Add cursor upwards" })
map({ "n", "i" }, "<C-LeftMouse>", [[<Cmd>MultipleCursorsMouseAddDelete<CR>]], { desc = "Add cursor upwards" })

--overseer
map("n", "<leader>r", [[:w <CR> :OverseerRun <CR>]])

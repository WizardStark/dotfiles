local function trigger_dap(dapStart)
	require("dap-view").open()
	dapStart()
end

local function continue()
	if require("dap").session() then
		require("dap").continue()
	else
		require("dap-view").open()
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

local default_notebook = [[
  {
    "cells": [
     {
      "cell_type": "markdown",
      "metadata": {},
      "source": [
        ""
      ]
     }
    ],
    "metadata": {
     "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
     },
     "language_info": {
      "codemirror_mode": {
        "name": "ipython"
      },
      "file_extension": ".py",
      "mimetype": "text/x-python",
      "name": "python",
      "nbconvert_exporter": "python",
      "pygments_lexer": "ipython3"
     }
    },
    "nbformat": 4,
    "nbformat_minor": 5
  }
]]

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
		keys = "<leader>Q",
		callback = [[<CMD>qa! <CR>]],
		prefix = P.misc,
		description = "How to quit vim",
	},
	{
		mode = { "n", "v", "t" },
		keys = "<D-v>",
		callback = [["+p]],
		prefix = P.misc,
		description = "Paste with OS key",
	},
	{
		mode = { "i" },
		keys = "<D-v>",
		callback = [[<C-r>+]],
		prefix = P.misc,
		description = "Paste with OS key",
	},
	{
		mode = { "n", "v", "t" },
		keys = "<C-v>",
		callback = [["+p]],
		prefix = P.misc,
		description = "Paste with ctrl",
	},
	{
		mode = { "t" },
		keys = "<S-BS>",
		callback = "<BS>",
		prefix = P.misc,
		description = "Backspace in terminal when holding shift",
	},
	{
		mode = { "t" },
		keys = "<C-BS>",
		callback = "<BS>",
		prefix = P.misc,
		description = "Backspace in terminal when holding control",
	},
	{
		mode = { "n" },
		keys = "<C-r>",
		callback = "r",
		prefix = P.misc,
		description = "Replace one character",
	},
	{
		mode = { "i" },
		keys = "<C-v>",
		callback = [[<C-r>+]],
		prefix = P.misc,
		description = "Paste with ctrl",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>X",
		callback = save_and_exit,
		prefix = P.misc,
		description = "How to save and quit vim",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>U",
		callback = vim.cmd.wa,
		prefix = P.misc,
		description = "Write all open, modified buffers",
	},
	{
		mode = { "n" },
		keys = "<esc>",
		callback = function()
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

		mode = { "n" },
		keys = "gf",
		callback = function()
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
		keys = "r",
		callback = vim.cmd.redo,
		prefix = P.misc,
		description = "Redo",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>y",
		callback = [["+y]],
		prefix = P.misc,
		description = "Copy/Yank to system clipboard",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>D",
		callback = [["_d]],
		prefix = P.misc,
		description = "Delete without altering registers",
	},
	{
		mode = { "n" },
		keys = "J",
		callback = function()
			local pos = vim.api.nvim_win_get_cursor(0)
			vim.cmd([[normal! J]])
			vim.api.nvim_win_set_cursor(0, pos)
		end,
		prefix = P.misc,
		description = "Join lines while maintaining cursor position",
	},
	{
		mode = { "n" },
		keys = "j",
		callback = "v:count ? 'j' : 'gj'",
		opts = { expr = true },
		prefix = P.misc,
		description = "Move down one line",
	},
	{
		mode = { "n" },
		keys = "k",
		callback = "v:count ? 'k' : 'gk'",
		opts = { expr = true },
		prefix = P.misc,
		description = "Move up one line",
	},
	{
		mode = { "n" },
		keys = "<C-d>",
		callback = "<C-d>zz",
		prefix = P.move,
		description = "Down half page and centre",
	},
	{
		mode = { "n" },
		keys = "<C-u>",
		callback = "<C-u>zz",
		prefix = P.move,
		description = "Up half page and centre",
	},
	{
		mode = { "n" },
		keys = "n",
		callback = "nzzzv",
		prefix = P.move,
		description = "Next occurrence of search and centre",
	},
	{
		mode = { "n" },
		keys = "N",
		callback = "Nzzzv",
		prefix = P.move,
		description = "Next occurrence of search and centre",
	},
	{
		mode = { "v" },
		keys = "<leader>k",
		callback = [[:s/\(.*\)/]],
		prefix = P.misc,
		description = "Initiate visual selection replace with selection as capture group 1",
	},
	{
		mode = { "v" },
		keys = "<leader>uo",
		callback = [[:s/\s\+/ /g | '<,'>s/\n/ /g | s/\s// | s/\s\+/ /g | s/\. /\.\r/g <CR>]],
		prefix = P.code,
		description = "Format one line per sentence",
	},
	{
		mode = { "n" },
		keys = "<leader>a",
		callback = "<C-^>",
		prefix = P.nav,
		description = "Alternate file",
	},
	{
		mode = { "n", "v", "i" },
		keys = "<C-s>",
		callback = vim.cmd.up,
		prefix = P.misc,
		description = "Save file",
	},
	{
		mode = { "v" },
		keys = "<M-j>",
		callback = ":m '>+1<CR>gv=gv",
		prefix = P.misc,
		description = "Move visual selection one line down",
	},
	{
		mode = { "v" },
		keys = "<M-k>",
		callback = ":m '<-2<CR>gv=gv",
		prefix = P.misc,
		description = "Move visual selection one line up",
	},
	{
		mode = { "v" },
		keys = "<",
		callback = "<gv",
		prefix = P.misc,
		description = "Move visual selection one indentation left",
	},
	{
		mode = { "v" },
		keys = ">",
		callback = ">gv",
		prefix = P.misc,
		description = "Move visual selection one indentation right",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>cp",
		callback = function()
			local path = vim.fn.expand("%:p")
			vim.fn.setreg("+", path)
			vim.notify("Copied " .. path .. " to clipboard")
		end,
		prefix = P.misc,
		description = "Copy file path to clipboard",
	},
	{
		mode = { "n" },
		keys = "<leader>fm",
		callback = "zm",
		prefix = P.fold,
		description = "Increase folding",
	},
	{
		mode = { "n" },
		keys = "<leader>fl",
		callback = "zr",
		prefix = P.fold,
		description = "Decrease folding",
	},
	{
		mode = { "n" },
		keys = "<leader><Tab>",
		callback = "zM",
		prefix = P.fold,
		description = "Fold all",
	},
	{
		mode = { "n" },
		keys = "<leader><S-Tab>",
		callback = "zR",
		prefix = P.fold,
		description = "Open all folds",
	},
	{
		mode = { "n" },
		keys = "<C-f>",
		callback = "za",
		prefix = P.fold,
		description = "Toggle fold",
	},
	{
		mode = { "n" },
		keys = "<leader>o",
		callback = function()
			Snacks.picker.recent({ filter = { paths = { [vim.fn.getcwd()] = true } } })
		end,
		prefix = P.find,
		description = "Buffers in order of recent access",
	},
	{
		mode = { "n", "v", "o" },
		keys = "<leader><leader>",
		callback = function()
			Snacks.picker.keymaps()
		end,
		prefix = P.misc,
		description = "Command palette",
	},
	{
		mode = { "n" },
		keys = "<leader>fg",
		callback = function()
			Snacks.picker.grep()
		end,
		prefix = P.find,
		description = "Grep in cwd",
	},
	{
		mode = { "n" },
		keys = "<leader>fd",
		callback = function()
			Snacks.picker.git_status()
		end,
		prefix = P.find,
		description = "Changed files",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>fw",
		callback = function()
			Snacks.picker.grep_word()
		end,
		prefix = P.find,
		description = "Word in cwd",
	},
	{
		mode = { "n" },
		keys = "<leader>f/",
		callback = function()
			Snacks.picker.lines()
		end,
		prefix = P.misc,
		description = "Fuzzy find in cwd",
	},
	{
		mode = { "n" },
		keys = "<leader>f:",
		callback = function()
			Snacks.picker.command_history()
		end,
		prefix = P.misc,
		description = "Show command history",
	},
	{
		mode = { "n" },
		keys = "<leader>ff",
		callback = function()
			Snacks.picker.files()
		end,
		prefix = P.find,
		description = "Files by filename in cwd",
	},
	{
		mode = { "n" },
		keys = "<leader>fu",
		callback = function()
			Snacks.picker.undo()
		end,
		prefix = P.misc,
		description = "Show change history (undotree)",
	},
	{
		mode = { "n" },
		keys = "<leader>li",
		callback = function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
		end,
		prefix = P.lsp,
		description = "Toggle inlay hints",
	},
	{
		mode = { "n" },
		keys = "<leader>fr",
		callback = function()
			Snacks.picker.lsp_references()
		end,
		prefix = P.find,
		description = "References to symbol under cursor",
	},
	{
		mode = { "n" },
		keys = "<leader>fs",
		callback = function()
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
	---@diagnostic disable: missing-fields
	{
		mode = { "n" },
		keys = "<leader>fc",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "lsp_incoming_calls" })
		end,
		prefix = P.find,
		description = "Calls to this symbol",
	},
	{
		mode = { "n" },
		keys = "<leader>fo",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "lsp_outgoing_calls" })
		end,
		prefix = P.find,
		description = "Calls made by this symbol",
	},
	---@diagnostic enable: missing-fields
	{
		mode = { "n" },
		keys = "<leader>fi",
		callback = function()
			Snacks.picker.lsp_implementations()
		end,
		prefix = P.find,
		description = "Implementations of symbol under cursor",
	},
	{
		mode = { "n" },
		keys = "<leader>fh",
		callback = function()
			history_picker()
		end,
		prefix = P.find,
		description = "Open last picker",
	},
	{
		mode = { "n" },
		keys = "<leader>fp",
		callback = function()
			Snacks.picker()
		end,
		prefix = P.find,
		description = "Open list of pickers",
	},
	{
		mode = { "n" },
		keys = "<leader>f?",
		callback = function()
			Snacks.picker.help()
		end,
		prefix = P.find,
		description = "Help tags",
	},
	{
		mode = { "n" },
		keys = "<leader>gd",
		callback = [[<CMD>DiffviewOpen<CR>]],
		prefix = P.git,
		description = "Open Git diffview",
	},
	{
		mode = { "n" },
		keys = "<leader>gn",
		callback = function()
			local range = vim.fn.expand("<cWORD>")
			vim.cmd("DiffviewOpen " .. range)
		end,
		prefix = P.git,
		description = "Open Git diffview",
	},
	{
		mode = { "n" },
		keys = "<leader>gq",
		callback = [[<CMD>DiffviewClose<CR>]],
		prefix = P.git,
		description = "Close Git diffview",
	},
	{
		mode = { "o", "v" },
		keys = "gh",
		callback = function()
			require("mini.diff").textobject()
		end,
		prefix = P.text,
		description = "Git hunk",
	},
	{
		mode = { "n", "x" },
		keys = "gs",
		opts = { expr = true },
		callback = function()
			return require("mini.diff").operator("apply")
		end,
		prefix = P.git,
		description = "Stage selection/object",
	},
	{
		mode = { "n", "x" },
		keys = "gr",
		opts = { expr = true },
		callback = function()
			return require("mini.diff").operator("reset")
		end,
		prefix = P.git,
		description = "Reset selection/object",
	},
	{
		mode = { "n", "i" },
		keys = "<M-n>",
		callback = function()
			require("mini.diff").goto_hunk("next")
		end,
		prefix = P.git,
		description = "Go to next change/hunk",
	},
	{
		mode = { "n", "i" },
		keys = "<M-t>",
		callback = function()
			require("mini.diff").goto_hunk("prev")
		end,
		prefix = P.git,
		description = "Go to previous change/hunk",
	},
	{
		mode = { "n" },
		keys = "<leader>go",
		callback = function()
			require("mini.diff").toggle_overlay(0)
		end,
		prefix = P.git,
		description = "Toggle diff overlay",
	},
	{
		mode = { "n" },
		keys = "<leader>gbt",
		callback = "<cmd>GitBlameToggle<cr>",
		prefix = P.git,
		description = "Toggle inline git blame",
	},
	{
		mode = { "n" },
		keys = "<leader>gbd",
		callback = function()
			Snacks.git.blame_line()
		end,
		prefix = P.git,
		description = "Full detail git blame for current line",
	},
	{
		mode = { "n" },
		keys = "<leader>gh",
		callback = function()
			Snacks.picker.git_log()
		end,
		prefix = P.git,
		description = "Commit history",
	},
	{
		mode = { "n" },
		keys = "<leader>gc",
		callback = function()
			Snacks.picker.git_log({ current_file = true })
		end,
		prefix = P.git,
		description = "Commit history for current buffer",
	},
	{
		mode = { "n" },
		keys = "<leader>bc",
		callback = function()
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
		mode = { "n" },
		keys = "<leader>bm",
		callback = function()
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
		mode = { "n" },
		keys = "<leader>-",
		callback = function()
			vim.cmd("split")
		end,
		prefix = P.window,
		description = "Create horizontal split",
	},
	{
		mode = { "n" },
		keys = "<leader>|",
		callback = function()
			vim.cmd("vsplit")
		end,
		prefix = P.window,
		description = "Create vertical split",
	},
	{
		mode = { "n" },
		keys = "<A-r>",
		callback = function()
			require("smart-splits").start_resize_mode()
		end,
		prefix = P.window,
		description = "Enter resize mode",
	},
	{
		mode = { "n" },
		keys = "<A-h>",
		callback = function()
			require("smart-splits").resize_left()
		end,
		prefix = P.window,
		description = "Resize leftwards",
	},
	{
		mode = { "n" },
		keys = "<A-j>",
		callback = function()
			require("smart-splits").resize_down()
		end,
		prefix = P.window,
		description = "Resize downwards",
	},
	{
		mode = { "n" },
		keys = "<A-k>",
		callback = function()
			require("smart-splits").resize_up()
		end,
		prefix = P.window,
		description = "Resize upwards",
	},
	{
		mode = { "n" },
		keys = "<A-l>",
		callback = function()
			require("smart-splits").resize_right()
		end,
		prefix = P.window,
		description = "Resize rightwards",
	},
	{
		mode = { "n" },
		keys = "<C-h>",
		callback = function()
			require("smart-splits").move_cursor_left()
		end,
		prefix = P.window,
		description = "Focus window to the left",
	},
	{
		mode = { "n" },
		keys = "<C-j>",
		callback = function()
			require("smart-splits").move_cursor_down()
		end,
		prefix = P.window,
		description = "Focus window below",
	},
	{
		mode = { "n" },
		keys = "<C-k>",
		callback = function()
			require("smart-splits").move_cursor_up()
		end,
		prefix = P.window,
		description = "Focus window above",
	},
	{
		mode = { "n" },
		keys = "<C-l>",
		callback = function()
			require("smart-splits").move_cursor_right()
		end,
		prefix = P.window,
		description = "Focus window to the right",
	},
	{
		mode = { "n" },
		keys = "<leader><C-h>",
		callback = function()
			require("smart-splits").swap_buf_left()
		end,
		prefix = P.window,
		description = "Swap current buffer leftwards",
	},
	{
		mode = { "n" },
		keys = "<leader><C-j>",
		callback = function()
			require("smart-splits").swap_buf_down()
		end,
		prefix = P.window,
		description = "Swap current buffer downwards",
	},
	{
		mode = { "n" },
		keys = "<leader><C-k>",
		callback = function()
			require("smart-splits").swap_buf_up()
		end,
		prefix = P.window,
		description = "Swap current buffer upwards",
	},
	{
		mode = { "n" },
		keys = "<leader><C-l>",
		callback = function()
			require("smart-splits").swap_buf_right()
		end,
		prefix = P.window,
		description = "Swap current buffer rightwards",
	},
	{
		mode = { "n" },
		keys = "<leader>e",
		callback = function()
			require("user.utils").toggle_minifiles()
		end,
		prefix = P.nav,
		description = "Open file explorer",
	},
	{
		mode = { "n" },
		keys = "<leader>xx",
		callback = "<cmd>Trouble diagnostics toggle<cr>",
		prefix = P.diag,
		description = "Toggle diagnostics window",
	},
	---@diagnostic disable: missing-fields
	{
		mode = { "n" },
		keys = "<leader>xw",
		callback = function()
			require("trouble").toggle({ focus = true, auto_refresh = true, mode = "cascade" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for entire workspace",
	},
	{
		mode = { "n" },
		keys = "<leader>xd",
		callback = function()
			require("trouble").toggle({ focus = true, auto_refresh = true, mode = "diagnostics_buffer" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics for current file",
	},
	{
		mode = { "n" },
		keys = "<leader>xq",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "qflist" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window with quickfix list",
	},
	{
		mode = { "n" },
		keys = "<leader>xc",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "lsp_incoming_calls" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for calls to this symbol",
	},
	{
		mode = { "n" },
		keys = "<leader>xo",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "lsp_outgoing_calls" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for calls by this symbol",
	},
	{
		mode = { "n" },
		keys = "<leader>xr",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "lsp_references" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for references to this symbol",
	},
	{
		mode = { "n" },
		keys = "<leader>xs",
		callback = function()
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
		mode = { "n" },
		keys = "<leader>xl",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "loclist" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for loclist",
	},
	{
		mode = { "n" },
		keys = "<leader>xn",
		callback = function()
			require("trouble").next({ jump = true })
		end,
		prefix = P.diag,
		description = "Go to next diagnostics item",
	},
	{
		mode = { "n" },
		keys = "<leader>xt",
		callback = function()
			require("trouble").prev({ jump = true })
		end,
		prefix = P.diag,
		description = "Go to previous diagnostic item",
	},
	{
		mode = { "n" },
		keys = "<leader>xf",
		callback = function()
			require("trouble").toggle({ focus = true, mode = "snacks" })
		end,
		prefix = P.diag,
		description = "Toggle diagnostics window for result exported from picker",
	},
	---@diagnostic enable: missing-fields
	-- debugging
	{
		mode = { "n" },
		keys = "<leader>dd",
		callback = function()
			require("dap").toggle_breakpoint()
		end,
		prefix = P.debug,
		description = "Toggle breakpoint",
	},
	{
		mode = { "n" },
		keys = "<leader>dC",
		callback = function()
			require("dap").clear_breakpoints()
		end,
		prefix = P.debug,
		description = "Clear all breakpoints",
	},
	{
		mode = { "n" },
		keys = "<leader>dD",
		callback = function()
			vim.ui.input({ prompt = "Condition: " }, function(input)
				require("dap").set_breakpoint(input)
			end)
		end,
		prefix = P.debug,
		description = "Toggle conditional breakpoint",
	},
	{
		mode = { "n" },
		keys = "<leader>dl",
		callback = function()
			trigger_dap(require("dap").run_last)
		end,
		prefix = P.debug,
		description = "Nearest test",
	},
	{
		mode = { "n" },
		keys = "<leader>do",
		callback = function()
			require("dap").step_over()
		end,
		prefix = P.debug,
		description = "Step over",
	},
	{
		mode = { "n" },
		keys = "<leader>di",
		callback = function()
			require("dap").step_into({ askForTargets = true })
		end,
		prefix = P.debug,
		description = "Step into",
	},
	{
		mode = { "n" },
		keys = "<leader>du",
		callback = function()
			require("dap").step_out()
		end,
		prefix = P.debug,
		description = "Step out",
	},
	{
		mode = { "n" },
		keys = "<leader>db",
		callback = function()
			require("dap").step_back()
		end,
		prefix = P.debug,
		description = "Step back",
	},
	{
		mode = { "n" },
		keys = "<leader>dh",
		callback = function()
			require("dap").run_to_cursor()
		end,
		prefix = P.debug,
		description = "Run to cursor",
	},
	{
		mode = { "n" },
		keys = "<leader>dr",
		callback = function()
			require("dap.ui.widgets").hover(vim.fn.expand("<cword>"))
		end,
		prefix = P.debug,
		description = "Evaluate expression",
	},
	{
		mode = { "x" },
		keys = "<leader>dr",
		callback = function()
			vim.cmd([[normal! vv]])
			local text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), "\n")
			require("dap.ui.widgets").hover(text)
		end,
		prefix = P.debug,
		description = "Evaluate selection",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>dw",
		callback = function()
			require("dap-view").add_expr()
		end,
		prefix = P.debug,
		description = "Add variable to watches",
	},
	{
		mode = { "n" },
		keys = "<leader>dc",
		callback = continue,
		prefix = P.debug,
		description = "Start debug session, or continue session",
	},
	{
		mode = { "n" },
		keys = "<leader>de",
		callback = function()
			require("dap").terminate()
			require("nvim-dap-virtual-text").refresh()
		end,
		prefix = P.debug,
		description = "Stop debug session",
	},
	{
		mode = { "n" },
		keys = "<leader>dt",
		callback = function()
			require("dap-view").toggle()
		end,
		prefix = P.debug,
		description = "Reset and toggle ui",
	},
	{
		mode = { "n" },
		keys = "<leader>dv",
		callback = function()
			require("nvim-dap-virtual-text").toggle()
		end,
		prefix = P.debug,
		description = "Reset and toggle ui",
	},
	{
		mode = { "n" },
		keys = "<leader>bt",
		callback = function()
			require("alternate-toggler").toggleAlternate()
		end,
		prefix = P.misc,
		description = "Toggle booleans",
	},
	{
		mode = { "n" },
		keys = "<leader>ro",
		callback = "<cmd>OverseerToggle<cr>",
		prefix = P.task,
		description = "Open task output window",
	},
	{
		mode = { "n" },
		keys = "<leader>rt",
		callback = "<cmd>OverseerRun<CR>",
		prefix = P.task,
		description = "List build tasks to run",
	},
	{
		mode = { "n", "v" },
		keys = "gx",
		callback = function()
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
		keys = "<leader>bf",
		callback = function()
			require("conform").format({ async = false })
		end,
		prefix = P.code,
		description = "Format current buffer",
	},
	--latex
	{
		mode = { "n" },
		keys = "<leader>lb",
		callback = [[:VimtexCompile <CR>]],
		prefix = P.latex,
		description = "Build/compile document",
	},
	{
		mode = { "n" },
		keys = "<leader>lc",
		callback = [[:VimtexClean <CR>]],
		prefix = P.latex,
		description = "Clean aux files",
	},
	{
		mode = { "n" },
		keys = "<leader>le",
		callback = [[:VimtexTocOpen <CR>]],
		prefix = P.latex,
		description = "Open table of contents",
	},
	{
		mode = { "n" },
		keys = "<leader>ln",
		callback = [[:VimtexTocToggle <CR>]],
		prefix = P.latex,
		description = "Toggle table of contents",
	},
	{
		mode = { "n" },
		keys = "gd",
		callback = function()
			require("snacks").picker.lsp_definitions()
		end,
		prefix = P.code,
		description = "Go to definition",
	},
	{
		mode = { "n" },
		keys = "gD",
		callback = function()
			vim.lsp.buf.declaration()
		end,
		prefix = P.code,
		description = "Go to declaration",
	},
	{
		mode = { "n" },
		keys = "<leader>K",
		callback = function()
			vim.lsp.buf.signature_help()
		end,
		prefix = P.code,
		description = "Show function signature",
	},
	{
		mode = { "n" },
		keys = "gt",
		callback = function()
			require("snacks").picker.lsp_type_definitions()
		end,
		prefix = P.code,
		description = "Go to type definition",
	},
	{
		mode = { "n" },
		keys = "<leader>rn",
		callback = function()
			require("config.editor.rename").rename({ insert = true })
		end,
		prefix = P.code,
		description = "Rename",
	},
	{
		mode = { "n" },
		keys = "<leader>gf",
		callback = function()
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
		mode = { "v" },
		keys = "<leader>gf",
		callback = function()
			require("grug-far").with_visual_selection({
				instanceName = "main_instance",
			})
		end,
		prefix = P.code,
		description = "Search and replace visual selection",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>ca",
		callback = function()
			vim.lsp.buf.code_action()
		end,
		prefix = P.code,
		description = "Show code actions",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>cl",
		callback = function()
			vim.lsp.codelens.run()
		end,
		prefix = P.code,
		description = "Show code actions",
	},
	{
		mode = { "n" },
		keys = "<leader>ds",
		callback = function()
			vim.diagnostic.open_float()
		end,
		prefix = P.code,
		description = "Open LSP diagnostics in a floating window",
	},
	{
		mode = { "n", "x", "o" },
		keys = "s",
		callback = function()
			require("flash").jump()
		end,
		prefix = P.move,
		description = "Flash see :h flash.nvim.txt",
	},
	{
		mode = { "c" },
		keys = "<c-s>",
		callback = function()
			require("flash").toggle()
		end,
		prefix = P.move,
		description = "Toggle Flash Search",
	},
	{
		mode = { "n" },
		keys = "<leader>cm",
		callback = "<cmd>Mason<cr>",
		prefix = P.misc,
		description = "Open Mason: LSP server, formatter, DAP and linter manager",
	},
	{
		mode = { "n" },
		keys = "<leader>nn",
		callback = function()
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
		mode = { "n" },
		keys = "<leader>nf",
		callback = function()
			Snacks.picker.files({
				dirs = { "~/notes/" },
			})
		end,
		prefix = P.notes,
		description = "Find note",
	},
	{
		mode = { "n" },
		keys = "<leader>ng",
		callback = function()
			Snacks.picker.grep({
				dirs = { "~/notes/" },
			})
		end,
		prefix = P.notes,
		description = "Grep notes",
	},
	{
		mode = { "t" },
		keys = "<esc>",
		callback = [[<C-\><C-n>]],
		{ buffer = 0 },
		prefix = P.term,
		description = "Exit insert mode in terminal",
	},
	{
		mode = { "n" },
		keys = "<C-\\>",
		callback = function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "horizontal", nil, "bottom")
		end,
		prefix = P.term,
		description = "Open in horizontal split",
	},
	{
		mode = { "n" },
		keys = "<C-]>",
		callback = function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", nil, "right")
		end,
		prefix = P.term,
		description = "Open in vertical split",
	},
	{
		mode = { "n" },
		keys = "<C-->",
		callback = function()
			require("workspaces.toggleterms").toggle_term(vim.v.count, "vertical", nil, "left")
		end,
		prefix = P.term,
		description = "Open in left vertical split",
	},
	{
		mode = { "o", "x" },
		keys = "ii",
		callback = function()
			require("various-textobjs").indentation("inner", "inner")
		end,
		prefix = P.text,
		description = "In inner indentation",
	},
	{
		mode = { "o", "x" },
		keys = "ai",
		callback = function()
			require("various-textobjs").indentation("outer", "inner")
		end,
		prefix = P.text,
		description = "Around inner indentation",
	},
	{
		mode = { "o", "x" },
		keys = "iI",
		callback = function()
			require("various-textobjs").indentation("inner", "outer")
		end,
		prefix = P.text,
		description = "In outer indentation",
	},
	{
		mode = { "o", "x" },
		keys = "aI",
		callback = function()
			require("various-textobjs").indentation("outer", "outer")
		end,
		prefix = P.text,
		description = "Around outer indentation",
	},
	{
		mode = { "o", "x" },
		keys = "R",
		callback = function()
			require("various-textobjs").restOfIndentation()
		end,
		prefix = P.text,
		description = "Rest of indentation",
	},
	{
		mode = { "o", "x" },
		keys = "iS",
		callback = function()
			require("various-textobjs").subword("inner")
		end,
		prefix = P.text,
		description = "In subword",
	},
	{
		mode = { "o", "x" },
		keys = "aS",
		callback = function()
			require("various-textobjs").subword("outer")
		end,
		prefix = P.text,
		description = "Around subword",
	},
	{
		mode = { "o", "x" },
		keys = "r",
		callback = function()
			require("various-textobjs").restOfParagraph()
		end,
		prefix = P.text,
		description = "Rest of paragraph",
	},
	{
		mode = { "o", "x" },
		keys = "gG",
		callback = function()
			require("various-textobjs").entireBuffer()
		end,
		prefix = P.text,
		description = "Entire buffer",
	},
	{
		mode = { "o", "x" },
		keys = "n",
		callback = function()
			require("various-textobjs").nearEoL()
		end,
		prefix = P.text,
		description = "1 char befor EoL",
	},
	{
		mode = { "o", "x" },
		keys = "i_",
		callback = function()
			require("various-textobjs").lineCharacterwise("inner")
		end,
		prefix = P.text,
		description = "In line characterwise",
	},
	{
		mode = { "o", "x" },
		keys = "a_",
		callback = function()
			require("various-textobjs").lineCharacterwise("outer")
		end,
		prefix = P.text,
		description = "Around line characterwise",
	},
	{
		mode = { "o", "x" },
		keys = "|",
		callback = function()
			require("various-textobjs").column()
		end,
		prefix = P.text,
		description = "Column",
	},
	{
		mode = { "o", "x" },
		keys = "iN",
		callback = function()
			require("various-textobjs").notebookCell("inner")
		end,
		prefix = P.text,
		description = "In notebook cell",
	},
	{
		mode = { "o", "x" },
		keys = "aN",
		callback = function()
			require("various-textobjs").notebookCell("outer")
		end,
		prefix = P.text,
		description = "Around notebook cell",
	},
	{
		mode = { "o", "x" },
		keys = "iv",
		callback = function()
			require("various-textobjs").value("inner")
		end,
		prefix = P.text,
		description = "In value",
	},
	{
		mode = { "o", "x" },
		keys = "av",
		callback = function()
			require("various-textobjs").value("outer")
		end,
		prefix = P.text,
		description = "Around value",
	},
	{
		mode = { "o", "x" },
		keys = "ik",
		callback = function()
			require("various-textobjs").key("inner")
		end,
		prefix = P.text,
		description = "In key",
	},
	{
		mode = { "o", "x" },
		keys = "ak",
		callback = function()
			require("various-textobjs").key("outer")
		end,
		prefix = P.text,
		description = "Around key",
	},
	{
		mode = { "o", "x" },
		keys = "L",
		callback = function()
			require("various-textobjs").url()
		end,
		prefix = P.text,
		description = "Url",
	},
	{
		mode = { "o", "x" },
		keys = "in",
		callback = function()
			require("various-textobjs").number("inner")
		end,
		prefix = P.text,
		description = "In number",
	},
	{
		mode = { "o", "x" },
		keys = "an",
		callback = function()
			require("various-textobjs").number("outer")
		end,
		prefix = P.text,
		description = "Around number",
	},
	{
		mode = { "o", "x" },
		keys = "!",
		callback = function()
			require("various-textobjs").diagnostic()
		end,
		prefix = P.text,
		description = "Lsp diagnostic",
	},
	{
		mode = { "o", "x" },
		keys = "iM",
		callback = function()
			require("various-textobjs").chainMember("inner")
		end,
		prefix = P.text,
		description = "In chain member",
	},
	{
		mode = { "o", "x" },
		keys = "aM",
		callback = function()
			require("various-textobjs").chainMember("outer")
		end,
		prefix = P.text,
		description = "Around chain member",
	},
	{
		mode = { "n" },
		keys = "m",
		callback = function()
			require("substitute").operator()
		end,
		prefix = P.misc,
		description = "Substitute text object",
	},
	{
		mode = { "n" },
		keys = "mm",
		callback = function()
			require("substitute").line()
		end,
		prefix = P.misc,
		description = "Substitute line",
	},
	{
		mode = { "n" },
		keys = "M",
		callback = function()
			require("substitute").eol()
		end,
		prefix = P.misc,
		description = "Substitute to end of line",
	},
	{
		mode = { "x" },
		keys = "m",
		callback = function()
			require("substitute").visual()
		end,
		prefix = P.misc,
		description = "Substitute visual selection",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><BS>",
		callback = function()
			Snacks.notifier.hide()
		end,
		prefix = P.misc,
		description = "Dismiss all notifications",
	},
	{
		mode = { "n", "x" },
		keys = "p",
		callback = "<Plug>(YankyPutAfter)",
		prefix = P.misc,
		description = "Paste after cursor",
	},
	{
		mode = { "n", "x" },
		keys = "P",
		callback = "<Plug>(YankyPutBefore)",
		prefix = P.misc,
		description = "Paste before cursor",
	},
	{
		mode = { "n", "x" },
		keys = "gp",
		callback = "<Plug>(YankyGPutAfter)",
		prefix = P.misc,
		description = "Paste after selection",
	},
	{
		mode = { "n", "x" },
		keys = "gP",
		callback = "<Plug>(YankyGPutBefore)",
		prefix = P.misc,
		description = "Paste after selection",
	},
	{
		mode = { "n" },
		keys = "<c-t>",
		callback = "<Plug>(YankyPreviousEntry)",
		prefix = P.misc,
		description = "Cycle to next item in yank history",
	},
	{
		mode = { "n" },
		keys = "<c-n>",
		callback = "<Plug>(YankyNextEntry)",
		prefix = P.misc,
		description = "Cycle to next item in yank history",
	},
	{
		mode = { "n" },
		keys = "<leader>p",
		callback = function()
			Snacks.picker.yanky()
		end,
		prefix = P.misc,
		description = "Open yank history",
	},
	{
		mode = { "n" },
		keys = "<leader>me",
		callback = "<cmd>MoltenEvaluateOperator<CR>",
		prefix = P.ipynb,
		description = "evaluate operator",
	},
	{
		mode = { "n" },
		keys = "<leader>mo",
		callback = "<cmd>noautocmd MoltenEnterOutput<CR>",
		prefix = P.ipynb,
		description = "open output window",
	},
	{
		mode = { "n" },
		keys = "<leader>mr",
		callback = "<cmd>MoltenReevaluateCell<CR>",
		prefix = P.ipynb,
		description = "re-eval cell",
		opts = { silent = true },
	},
	{
		mode = { "v" },
		keys = "<leader>r",
		callback = "<cmd><C-u>MoltenEvaluateVisual<CR>gv",
		prefix = P.ipynb,
		description = "execute visual selection",
	},
	{
		mode = { "n" },
		keys = "<leader>mc",
		callback = "<cmd>MoltenHideOutput<CR>",
		prefix = P.ipynb,
		description = "close output window",
	},
	{
		mode = { "n" },
		keys = "<leader>md",
		callback = "<cmd>MoltenDelete<CR>",
		prefix = P.ipynb,
		description = "delete Molten cell",
	},
	{
		mode = { "n" },
		keys = "<leader>mx",
		callback = ":MoltenOpenInBrowser<CR>",
		prefix = P.ipynb,
		description = "open output in browser",
	},
	{
		mode = { "n" },
		keys = "<leader>rc",
		callback = function()
			require("quarto.runner").run_cell()
		end,
		prefix = P.ipynb,
		description = "run cell",
	},
	{
		mode = { "n" },
		keys = "<leader>ra",
		callback = function()
			require("quarto.runner").run_above()
		end,
		prefix = P.ipynb,
		description = "run cell and above",
	},
	{
		mode = { "n" },
		keys = "<leader>rA",
		callback = function()
			require("quarto.runner").run_all()
		end,
		prefix = P.ipynb,
		description = "run all cells",
	},
	{
		mode = { "n" },
		keys = "<leader>rl",
		callback = function()
			require("quarto.runner").run_line()
		end,
		prefix = P.ipynb,
		description = "run line",
	},
	{
		mode = { "v" },
		keys = "<leader>rv",
		callback = function()
			require("quarto.runner").run_range()
		end,
		prefix = P.ipynb,
		description = "run visual range",
	},
	{
		mode = { "n" },
		keys = "<leader>RA",
		callback = function()
			require("quarto.runner").run_all(true)
		end,
		prefix = P.ipynb,
		description = "run all cells of all languages",
	},
	{
		mode = { "n" },
		keys = "<leader>nb",
		callback = function()
			vim.ui.input({ prompt = "Notebook Path: ", completion = "file" }, function(input)
				-- local path = vim.fn.expand(input .. ".ipynb")
				-- local file = io.open(path, "w")
				-- if file then
				-- 	file:write(default_notebook)
				-- 	file:close()
				-- 	vim.cmd("edit " .. path)
				-- else
				-- 	print("Error: Could not open new notebook file for writing.")
				-- end
			end)
		end,
		prefix = P.ipynb,
		description = "Create new ipynb notebook",
	},
	{
		mode = { "n" },
		keys = "<leader>w",
		callback = function()
			local win = require("window-picker").pick_window()
			if win then
				vim.api.nvim_set_current_win(win)
			end
		end,
		prefix = P.move,
		description = "Enter window selection",
	},
	{
		mode = { "n" },
		keys = "<leader>ll",
		callback = function()
			require("lazy").home()
		end,
		prefix = P.misc,
		description = "Open plugin manager",
	},
	{
		mode = { "n" },
		keys = "<leader>ld",
		callback = function()
			require("osv").launch({ port = 8086 })
		end,
		prefix = P.debug,
		description = "Launch lua debugger server on this nvim instance",
	},
	{
		mode = { "n" },
		keys = "<leader>rm",
		callback = function()
			require("jdtls").test_nearest_method()
		end,
		prefix = P.test,
		description = "Run nearest java test",
	},
	{
		mode = { "n" },
		keys = "<leader>rjc",
		callback = function()
			require("jdtls").test_class()
		end,
		prefix = P.test,
		description = "Run java test class",
	},
	{
		mode = { "n" },
		keys = "<leader>na",
		callback = function()
			require("neotest").run.run(vim.fn.expand("%"))
		end,
		prefix = P.test,
		description = "Run all tests in file",
	},
	{
		mode = { "n" },
		keys = "<leader>nt",
		callback = function()
			require("neotest").run.run()
		end,
		prefix = P.test,
		description = "Run nearest test",
	},
	{
		mode = { "n" },
		keys = "<leader>nd",
		callback = function()
			require("neotest").run.run_last({ strategy = "dap" })
		end,
		prefix = P.test,
		description = "Run nearest test",
	},
	{
		mode = { "n" },
		keys = "<leader>nW",
		callback = function()
			require("neotest").watch.toggle(vim.fn.expand("%"))
		end,
		prefix = P.test,
		description = "Toggle watching of all tests in file",
	},
	{
		mode = { "n" },
		keys = "<leader>nw",
		callback = function()
			require("neotest").watch.toggle()
		end,
		prefix = P.test,
		description = "Toggle watching of this test",
	},
	{
		mode = { "n" },
		keys = "<leader>no",
		callback = function()
			require("neotest").output.open()
		end,
		prefix = P.test,
		description = "Show test output",
	},
	{
		mode = { "n" },
		keys = "<leader>np",
		callback = function()
			require("neotest").output_panel.toggle()
		end,
		prefix = P.test,
		description = "Toggle aggregated output window",
	},
	{
		mode = { "n" },
		keys = "<leader>nc",
		callback = function()
			require("neotest").output_panel.clear()
		end,
		prefix = P.test,
		description = "Clear aggregated output window",
	},
	{
		mode = { "n" },
		keys = "<leader>ns",
		callback = function()
			require("neotest").summary.toggle()
		end,
		prefix = P.test,
		description = "Toggle summary tree",
	},
	{
		mode = { "v" },
		keys = "<leader>cs",
		callback = "<cmd>CodeSnapASCII<cr>",
		prefix = P.misc,
		description = "Copy ASCII code snapshot to clipboard",
	},
	{
		mode = { "x" },
		keys = "<leader>re",
		callback = function()
			require("refactoring").refactor("Extract Function")
		end,
		prefix = P.code,
		description = "Extract function",
	},
	{
		mode = { "x" },
		keys = "<leader>rff",
		callback = function()
			require("refactoring").refactor("Extract Function To File")
		end,
		prefix = P.code,
		description = "Extract function to file",
	},
	{
		mode = { "x" },
		keys = "<leader>rv",
		callback = function()
			require("refactoring").refactor("Extract Variable")
		end,
		prefix = P.code,
		description = "Extract variable",
	},
	{
		mode = { "n" },
		keys = "<leader>rI",
		callback = function()
			require("refactoring").refactor("Inline Function")
		end,
		prefix = P.code,
		description = "Inline function",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>ri",
		callback = function()
			require("refactoring").refactor("Inline Variable")
		end,
		prefix = P.code,
		description = "Inline variable",
	},
	{
		mode = { "n" },
		keys = "<leader>rb",
		callback = function()
			require("refactoring").refactor("Extract Block")
		end,
		prefix = P.code,
		description = "Extract block",
	},
	{
		mode = { "n" },
		keys = "<leader>rfb",
		callback = function()
			require("refactoring").refactor("Extract Block To File")
		end,
		prefix = P.code,
		description = "Extract block to file",
	},
	{
		mode = { "n", "x" },
		keys = "<leader>rl",
		callback = function()
			require("refactoring").get_refactors()
		end,
		prefix = P.code,
		description = "List available refactors",
	},
	{
		mode = { "n" },
		keys = "<leader>rp",
		callback = function()
			require("refactoring").debug.printf({ below = true, show_success_message = false })
		end,
		prefix = P.code,
		description = "Add print statement below current line",
	},
	{
		mode = { "x", "n" },
		keys = "<leader>rdv",
		callback = function()
			require("refactoring").debug.print_var({ show_success_message = false })
		end,
		prefix = P.code,
		description = "Add print statement with variable value",
	},
	{
		mode = { "n" },
		keys = "<leader>rdc",
		callback = function()
			require("refactoring").debug.cleanup({ show_success_message = true })
		end,
		prefix = P.code,
		description = "Clean up all automated print statements",
	},
	{
		mode = { "n" },
		keys = "<leader>lw",
		callback = function()
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
				require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
			end
		end,
		prefix = P.lsp,
		description = "Load all workspace files for diagnostics",
	},
	{
		mode = { "n" },
		keys = "K",
		callback = function()
			vim.lsp.buf.hover({
				close_events = {
					"CursorMoved",
					"BufHidden", -- fix window persisting on buffer switch (not `BufLeave` so float can be entered)
					"LspDetach", -- fix window persisting when restarting LSP
				},
			})
		end,
		prefix = P.code,
		description = "Show documentation",
	},
	{
		mode = { "n" },
		keys = "<leader>la",
		callback = function()
			vim.g.extra_lsp_actions()
		end,
		prefix = P.lsp,
		description = "Run extra lsp actions",
	},
	{
		mode = { "n" },
		keys = "<leader>ls",
		callback = function()
			vim.cmd("LspStart")
		end,
		prefix = P.lsp,
		description = "Start",
	},
	{
		mode = { "n" },
		keys = "<leader>lr",
		callback = function()
			vim.cmd("LspRestart")
		end,
		prefix = P.lsp,
		description = "Restart",
	},
	{
		mode = { "n" },
		keys = "<leader>J",
		callback = function()
			vim.fn.setreg('"', vim.fn.getreg('"'):gsub("[\n\r]", " "))
		end,
		prefix = P.misc,
		description = 'Remove linebreaks from contents in " register',
	},
	{
		mode = { "n", "v" },
		keys = "<leader>mcc",
		callback = function()
			vim.cmd("CodeCreate")
		end,
		prefix = P.misc,
		description = "Create code block in markdown",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>mce",
		callback = function()
			vim.cmd("CodeEdit")
		end,
		prefix = P.misc,
		description = "Edit markdown code block",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>ms",
		callback = function()
			vim.cmd({ cmd = "Markview", args = { "splitToggle" } })
		end,
		prefix = P.misc,
		description = "Toggle previewing markdown in a split",
	},
	{
		mode = { "n" },
		keys = "]]",
		callback = function()
			require("snacks").words.jump(vim.v.count1)
		end,
		prefix = P.misc,
		description = "Next reference",
	},
	{
		mode = { "n" },
		keys = "[[",
		callback = function()
			require("snacks").words.jump(-vim.v.count1)
		end,
		prefix = P.misc,
		description = "Previous reference",
	},
	{
		mode = { "n" },
		keys = "gS",
		callback = function()
			require("mini.splitjoin").toggle()
		end,
		prefix = P.misc,
		description = "Split/Join arguments",
	},
	{
		mode = { "n" },
		keys = "<leader>mt",
		callback = function()
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
		keys = "<leader>nh",
		callback = function()
			Snacks.notifier.show_history()
		end,
		prefix = P.misc,
		description = "Show notification history",
	},
	{
		mode = { "x", "o" },
		keys = "af",
		callback = function()
			require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
		end,
		prefix = P.text,
		description = "Around function",
	},
	{
		mode = { "x", "o" },
		keys = "if",
		callback = function()
			require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects")
		end,
		prefix = P.text,
		description = "In function",
	},
	{
		mode = { "x", "o" },
		keys = "ac",
		callback = function()
			require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects")
		end,
		prefix = P.text,
		description = "Around class",
	},
	{
		mode = { "x", "o" },
		keys = "ic",
		callback = function()
			require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects")
		end,
		prefix = P.text,
		description = "In class",
	},
	{
		mode = { "x", "o" },
		keys = "as",
		callback = function()
			require("nvim-treesitter-textobjects.select").select_textobject("@locals.scope", "locals")
		end,
		prefix = P.text,
		description = "Around scope",
	},
	{
		mode = { "n", "x", "o" },
		keys = ";",
		callback = function()
			require("nvim-treesitter-textobjects.repeatable_move").repeat_last_move()
		end,
		prefix = P.nav,
		description = "Repeat last move",
	},
	{
		mode = { "n", "x", "o" },
		keys = ",",
		callback = function()
			require("nvim-treesitter-textobjects.repeatable_move").repeat_last_move_opposite()
		end,
		prefix = P.nav,
		description = "Repeat last move (opposite direction)",
	},
	{
		mode = { "n", "x", "o" },
		keys = "f",
		callback = require("nvim-treesitter-textobjects.repeatable_move").builtin_f_expr,
		opts = { expr = true },
		prefix = P.nav,
		description = "Up to and including character forwards",
	},
	{
		mode = { "n", "x", "o" },
		keys = "F",
		callback = require("nvim-treesitter-textobjects.repeatable_move").builtin_F_expr,
		opts = { expr = true },
		prefix = P.nav,
		description = "Up to and including character backwards",
	},
	{
		mode = { "n", "x", "o" },
		keys = "t",
		callback = require("nvim-treesitter-textobjects.repeatable_move").builtin_t_expr,
		opts = { expr = true },
		prefix = P.nav,
		description = "Up to character forwards",
	},
	{
		mode = { "n", "x", "o" },
		keys = "T",
		callback = require("nvim-treesitter-textobjects.repeatable_move").builtin_T_expr,
		opts = { expr = true },
		prefix = P.nav,
		description = "Up to character backwards",
	},
	{
		mode = { "n", "v" },
		keys = "<C-S-j>",
		callback = "<cmd>Treewalker Down<cr>",
		prefix = P.misc,
		description = "Move down treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-S-k>",
		callback = "<cmd>Treewalker Up<cr>",
		prefix = P.misc,
		description = "Move up treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-S-h>",
		callback = "<cmd>Treewalker Left<cr>",
		prefix = P.misc,
		description = "Move left treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-S-l>",
		callback = "<cmd>Treewalker Right<cr>",
		prefix = P.misc,
		description = "Move right treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-M-S-j>",
		callback = "<cmd>Treewalker SwapDown<cr>",
		prefix = P.misc,
		description = "Swap down treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-M-S-k>",
		callback = "<cmd>Treewalker SwapUp<cr>",
		prefix = P.misc,
		description = "Swap up treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-M-S-h>",
		callback = "<cmd>Treewalker SwapLeft<cr>",
		prefix = P.misc,
		description = "Swap left treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<C-M-S-l>",
		callback = "<cmd>Treewalker SwapRight<cr>",
		prefix = P.misc,
		description = "Swap right treesitter node",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><C-t>",
		callback = function()
			require("config.hydra").treewalker_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start Treesitter navigation",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><C-d>",
		callback = function()
			require("config.hydra").dap_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start debug mode",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><C-x>",
		callback = function()
			require("config.hydra").trouble_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start trouble nav mode",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><C-g>",
		callback = function()
			require("config.hydra").git_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start git mode",
	},
	{
		mode = { "n", "v" },
		keys = "<leader><C-n>",
		callback = function()
			require("config.hydra").notebook_hydra:activate()
		end,
		prefix = P.hydra,
		description = "Start notebook mode",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>gs",
		callback = function()
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
	{
		mode = { "n", "v" },
		keys = "<leader>Ol",
		callback = function()
			vim.cmd("Octo pr list")
		end,
		prefix = P.git,
		description = "List github PR's",
	},
	{
		mode = { "n", "v" },
		keys = "<leader>Oc",
		callback = function()
			vim.cmd("Octo pr create")
		end,
		prefix = P.git,
		description = "Create a new github PR from the current branch",
	},
	{
		mode = { "n", "v" },
		keys = "<localleader>co",
		callback = function()
			vim.cmd("Octo review thread")
		end,
		prefix = P.git,
		description = "Open comment buffer",
	},
}

return {
	setup = function()
		local prefixifier = require("user.utils").prefixifier
		local keymaps = require("user.utils").make_keymaps
		prefixifier(keymaps)(mappings)
	end,
}

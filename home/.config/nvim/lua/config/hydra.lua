local Hydra = require("hydra")
local M = {}

Hydra.setup({
	color = "pink",
	hint = {
		type = "window",
		offset = 2,
		position = { "bottom", "right" },
	},
})

local last_git_traversed_at
local hunk_starts
local changed_files

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

local function get_git_files()
	local file_str = vim.fn.system(
		'git status -suall | cut -c 4- | sed "s|^|$(git rev-parse --show-toplevel)/$(git rev-parse --show-prefix)|g"'
	)
	if file_str == "" or file_str == nil then
		return nil
	end
	local file_table = vim.split(file_str, "\n")
	table.remove(file_table, #file_table)
	return file_table
end

-- Next 2 methods ripped from mini.diff
local function get_hunk_buf_range(hunk)
	if hunk == nil then
		vim.notify("No hunks found, likely a staged or new file")
		return
	end

	if hunk.buf_count > 0 then
		return hunk.buf_start, hunk.buf_start + hunk.buf_count - 1
	end
	local from = math.max(hunk.buf_start, 1)
	return from, from
end

local function get_contiguous_hunk_ranges(hunks)
	hunks = vim.deepcopy(hunks)

	local h1_from, h1_to = get_hunk_buf_range(hunks[1])
	local reg = { { from = h1_from, to = h1_to } }
	for i = 2, #hunks do
		local h, cur_region = hunks[i], reg[#reg]
		local h_from, h_to = get_hunk_buf_range(h)
		if h_from <= cur_region.to + 1 then
			cur_region.to = math.max(cur_region.to, h_to)
		else
			table.insert(reg, { from = h_from, to = h_to })
		end
	end
	local res = {}

	for _, region in ipairs(reg) do
		table.insert(res, region.from)
	end

	return res
end

local function traverse_hunks(forward, file_changed)
	if last_git_traversed_at == nil or os.time() - last_git_traversed_at > 2 or file_changed then
		local buf_data = require("mini.diff").get_buf_data(0)
		if buf_data == nil then
			vim.notify("No hunks found, retry")
			return
		end

		local hunks = buf_data.hunks

		if hunks == nil or hunks == {} then
			vim.notify("No hunks found, retry")
			return
		end

		hunk_starts = get_contiguous_hunk_ranges(hunks)
	end

	local cur_line = unpack(vim.fn.getcurpos(), 2, 2)

	local hunk_found = false
	if forward then
		for _, line in ipairs(hunk_starts) do
			if line > cur_line then
				vim.api.nvim_win_set_cursor(0, { line, 0 })
				hunk_found = true
				break
			end
		end
	else
		for i = #hunk_starts, 1, -1 do
			if hunk_starts[i] < cur_line then
				vim.api.nvim_win_set_cursor(0, { hunk_starts[i], 0 })
				hunk_found = true
				break
			end
		end
	end

	if hunk_found then
		last_git_traversed_at = os.time()
	end

	return hunk_found
end

local function next_changed_file(forward)
	if changed_files == nil or os.time() - last_git_traversed_at > 2 then
		changed_files = get_git_files()

		if changed_files == nil then
			vim.notify("No changed files found")
			return
		end
	end

	local buf_path = vim.fn.expand("%:p")
	local buf_index = 0
	for i, file in ipairs(changed_files) do
		if buf_path == file then
			buf_index = i
		end
	end

	if forward then
		local target = buf_index < #changed_files and buf_index + 1 or 1
		vim.cmd.e(changed_files[target])
		vim.api.nvim_win_set_cursor(0, { 1, 1 })
		traverse_hunks(forward, true)
	else
		local target = buf_index > 1 and buf_index - 1 or #changed_files
		vim.cmd.e(changed_files[target])
		vim.api.nvim_win_set_cursor(0, { vim.fn.line("$"), 1 })
		traverse_hunks(forward, true)
	end
end

local function traverse_changes(forward)
	local hunk_found = traverse_hunks(forward, false)

	if not hunk_found then
		next_changed_file(forward)
	end
end

local function keys(str)
	return function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(str, true, false, true), "m", true)
	end
end

M.treewalker_hydra = Hydra({
	name = "Treewalker",
	mode = { "n", "x" },
	hint = [[
Move       Swap
_h_: Left  _H_: Left
_l_: Right _L_: Right
_j_: Down  _J_: Down
_k_: Up    _K_: Up

_q_: Exit]],
	heads = {
		{ "h", "<cmd>Treewalker Left<cr>" },
		{ "l", "<cmd>Treewalker Right<cr>" },
		{ "j", "<cmd>Treewalker Down<cr>" },
		{ "k", "<cmd>Treewalker Up<cr>" },

		{ "H", "<cmd>Treewalker SwapLeft<cr>" },
		{ "L", "<cmd>Treewalker SwapRight<cr>" },
		{ "K", "<cmd>Treewalker SwapUp<cr>" },
		{ "J", "<cmd>Treewalker SwapDown<cr>" },

		{ "q", nil, { exit = true, nowait = true, desc = false } },
	},
})

M.dap_hydra = Hydra({
	name = "Dap",
	mode = { "n", "x" },
	hint = [[
_B_: Toggle breakpoint _W_: Add to watches
_C_: Continue          _E_: Evaluate
_O_: Step over         _R_: Send to REPL
_I_: Step into         _T_: Toggle UI
_U_: Step out          _Q_: Quit debugger
_<C-b>_: Clear breakpoints
_<C-c>_: Run to cursor
_<C-r>_: Rerun last debug
_q_: Exit]],
	config = {
		hint = {
			offset = 3,
			position = "top-right",
		},
		foreign_keys = "run",
		invoke_on_body = true,
	},
	heads = {
		{
			"B",
			function()
				require("dap").toggle_breakpoint()
			end,
			{ desc = false },
		},
		{
			"<C-b>",
			function()
				require("dap").clear_breakpoints()
			end,
			{ desc = false },
		},
		{
			"<C-r>",
			function()
				trigger_dap(require("dap").run_last)
			end,
			{ desc = false },
		},
		{
			"O",
			function()
				require("dap").step_over()
			end,
			{ desc = false },
		},
		{
			"I",
			function()
				require("dap").step_into({ askForTargets = true })
			end,
			{ desc = false },
		},
		{
			"U",
			function()
				require("dap").step_out()
			end,
			{ desc = false },
		},
		{
			"<C-c>",
			function()
				require("dap").run_to_cursor()
			end,
			{ desc = false },
		},
		{
			"R",
			function()
				local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
				if mode == "n" then
					require("dap").repl.execute(vim.fn.expand("<cword>"))
				elseif mode == "V" or mode == "v" then
					vim.cmd([[normal! vv]])
					local text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), "\n")
					require("dap").repl.execute(text)
				end
			end,
			{ desc = false },
		},
		{
			"W",
			function()
				local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
				if mode == "n" then
					require("dapui").elements.watches.add(vim.fn.expand("<cword>"))
				elseif mode == "V" or mode == "v" then
					vim.cmd([[normal! vv]])
					local text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>")), "\n")
					require("dapui").elements.watches.add(text)
				end
			end,
			{ desc = false },
		},
		{
			"E",
			function()
				require("dapui").eval()
			end,
			{ desc = false },
		},
		{
			"C",
			continue,
			{ desc = false },
		},
		{
			"Q",
			function()
				require("dap").terminate()
				require("dapui").close()
				require("nvim-dap-virtual-text").refresh()
			end,
			{ desc = false },
		},
		{
			"T",
			function()
				require("dapui").toggle()
			end,
			{ desc = false },
		},
		{ "q", nil, { exit = true, nowait = true, desc = false } },
	},
})

M.trouble_hydra = Hydra({
	name = "Trouble",
	mode = { "n", "x" },
	hint = [[
_N_: Next item
_T_: Prev item

_q_: Exit]],
	heads = {
		{
			"N",
			function()
				require("trouble").next({ jump = true })
			end,
		},
		{
			"T",
			function()
				require("trouble").prev({ jump = true })
			end,
		},

		{ "q", nil, { exit = true, nowait = true, desc = false } },
	},
})

M.git_hydra = Hydra({
	name = "Git",
	mode = { "n", "x" },
	hint = [[
_N_: Next hunk  _<C-n>_: Next file
_T_: Prev hunk  _<C-t>_: Prev file
_S_: Stage hunk
_R_: Reset hunk
_O_: Toggle diff

_q_: Exit]],
	config = {
		color = "pink",
		hint = {
			type = "window",
			offset = 2,
			position = "bottom-right",
		},
	},
	heads = {
		{
			"S",
			function()
				return require("mini.diff").operator("apply")
			end,
			{ expr = true },
		},
		{
			"R",
			function()
				return require("mini.diff").operator("reset")
			end,
			{ expr = true },
		},
		{
			"N",
			function()
				traverse_changes(true)
			end,
		},
		{
			"T",
			function()
				traverse_changes(false)
			end,
		},
		{
			"<C-n>",
			function()
				next_changed_file(true)
			end,
		},
		{
			"<C-t>",
			function()
				next_changed_file(false)
			end,
		},
		{
			"O",
			function()
				require("mini.diff").toggle_overlay(0)
			end,
		},
		{ "q", nil, { exit = true, nowait = true, desc = false } },
	},
})

M.notebook_hydra = Hydra({
	name = "Notebook",
	mode = { "n" },
	hint = [[
_j_/_k_: move down/up  _r_: run cell
_l_: run line        _R_: run above
_q_: exit ]],
	config = {
		invoke_on_body = true,
	},
	heads = {
		{ "j", keys("]b") },
		{ "k", keys("[b") },
		{ "r", "<cmd>MoltenReevaluateCell<CR>" },
		{ "l", "<cmd>QuartoSendLine<CR>" },
		{ "R", "<cmd>MoltenReevaluateCell<CR>" },
		{ "q", nil, { exit = true } },
	},
})

return M

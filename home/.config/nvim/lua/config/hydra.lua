local Hydra = require("hydra")
M = {}

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
	config = {
		color = "pink",
		hint = {
			type = "window",
			offset = 2,
			position = "bottom-right",
			float_opts = {
				border = "rounded",
			},
		},
	},
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
_b_: Toggle breakpoint _w_: Add to watches
_B_: Clear breakpoints _e_: Evaluate
_o_: Step over         _c_: Continue
_i_: Step into         _Q_: Quit debugger
_u_: Step out          _t_: Toggle UI
_r_: Run to cursor

_q_: Exit]],
	config = {
		color = "pink",
		hint = {
			type = "window",
			offset = 2,
			position = "bottom-right",
			float_opts = {
				border = "rounded",
			},
		},
		foreign_keys = "run",
		invoke_on_body = true,
	},
	heads = {
		{
			"b",
			function()
				require("dap").toggle_breakpoint()
			end,
			{ desc = false },
		},
		{
			"B",
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
			"o",
			function()
				require("dap").step_over()
			end,
			{ desc = false },
		},
		{
			"i",
			function()
				require("dap").step_into({ askForTargets = true })
			end,
			{ desc = false },
		},
		{
			"u",
			function()
				require("dap").step_out()
			end,
			{ desc = false },
		},
		{
			"r",
			function()
				require("dap").run_to_cursor()
			end,
			{ desc = false },
		},
		{
			"w",
			function()
				local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
				if mode == "n" then
					require("dapui").elements.watches.add(vim.fn.expand("<cword>"))
				elseif mode == "V" or mode == "v" then
					vim.cmd([[normal! vv]])
					local text =
						require("user.utils").region_to_text(vim.region(0, "'<", "'>", vim.fn.visualmode(), true))
					require("dapui").elements.watches.add(text)
				end
			end,
			{ desc = false },
		},
		{
			"e",
			function()
				require("dapui").eval()
			end,
			{ desc = false },
		},
		{
			"c",
			continue,
			{ desc = false },
		},
		{
			"Q",
			function()
				require("dap").terminate()
				require("dapui").close()
			end,
			{ desc = false },
		},
		{
			"t",
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
_n_: Next item
_t_: Prev item

_q_: Exit]],
	config = {
		color = "pink",
		hint = {
			type = "window",
			offset = 2,
			position = "bottom-right",
			float_opts = {
				border = "rounded",
			},
		},
	},
	heads = {
		{
			"n",
			function()
				require("trouble").next({ jump = true })
			end,
		},
		{
			"t",
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
_n_: Next hunk  _<C-n>_: Next file
_t_: Prev hunk  _<C-t>_: Prev file
_s_: Stage hunk
_r_: Reset hunk
_o_: Toggle diff

_q_: Exit]],
	config = {
		color = "pink",
		hint = {
			type = "window",
			offset = 2,
			position = "bottom-right",
			float_opts = {
				border = "rounded",
			},
		},
	},
	heads = {
		{
			"s",
			function()
				return require("mini.diff").operator("apply")
			end,
			{ expr = true },
		},
		{
			"r",
			function()
				return require("mini.diff").operator("reset")
			end,
			{ expr = true },
		},
		{
			"n",
			function()
				traverse_changes(true)
			end,
		},
		{
			"t",
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
			"o",
			function()
				require("mini.diff").toggle_overlay(0)
			end,
		},

		{ "q", nil, { exit = true, nowait = true, desc = false } },
	},
})

return M

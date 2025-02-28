local Hydra = require("hydra")

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

local treewalker_hydra = Hydra({
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

local dap_hydra = Hydra({
	name = "Dap",
	mode = { "n", "x" },
	hint = [[
_b_: Add breakpoint _w_: Add to watches
_o_: Step over      _e_: Evaluate
_i_: Step into      _c_: Continue
_u_: Step out       _Q_: Quit debugger
_r_: Run to cursor  _t_: Toggle UI

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
				require("dap").step_into()
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

local trouble_hydra = Hydra({
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

local git_hydra = Hydra({
	name = "Git",
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
				local val = require("mini.diff").goto_hunk("next", { wrap = false })
				dd(val)
			end,
		},
		{
			"t",
			function()
				require("mini.diff").goto_hunk("prev", { wrap = false })
				local val = require("snacks").notifier.get_history()[1].msg
				-- if val:gmatch("No hunks to go to") then
				-- 	vim.notify("test")
				-- end
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

require("legendary").keymaps({
	{
		mode = { "n", "v" },
		"<leader><C-t>",
		function()
			treewalker_hydra:activate()
		end,
		description = "Start Treesitter navigation",
	},
	{
		mode = { "n", "v" },
		"<leader><C-d>",
		function()
			dap_hydra:activate()
		end,
		description = "Start debug mode",
	},
	{
		mode = { "n", "v" },
		"<leader><C-x>",
		function()
			trouble_hydra:activate()
		end,
		description = "Start trouble nav mode",
	},
	{
		mode = { "n", "v" },
		"<leader><C-g>",
		function()
			git_hydra:activate()
		end,
		description = "Start git mode",
	},
})

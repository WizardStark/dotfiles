local dropbar = require("dropbar")
local utils = require("dropbar.utils")

local enable = function(buf, win)
	local filetype = vim.bo[buf].filetype
	local disabled = {
		["oil"] = true,
		["trouble"] = true,
		["qf"] = true,
		["noice"] = true,
		["dapui_scopes"] = true,
		["dapui_breakpoints"] = true,
		["dapui_stacks"] = true,
		["dapui_watches"] = true,
		["dapui_console"] = true,
		["dap-repl"] = true,
		["neocomposer-menu"] = true,
	}
	if disabled[filetype] then
		return false
	end
	if vim.api.nvim_win_get_config(win).zindex ~= nil then
		return vim.bo[buf].buftype == "terminal" and vim.bo[buf].filetype == "terminal"
	end
	return vim.bo[buf].buflisted == true and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local close = function()
	local menu = require("dropbar.utils").menu.get_current()
	if not menu then
		return
	end
	menu:close()
end

dropbar.setup(
	---@module 'dropbar'
	{
		general = {
			enable = enable,
			attach_events = {
				"BufWinEnter",
				"BufWritePost",
				"FileType",
				"BufEnter",
			},
		},
		sources = {
			terminal = {
				name = function(buf)
					local term = require("toggleterm.terminal").find(function(term)
						return term.bufnr == buf
					end)
					local name
					if term then
						name = term.display_name or term.cmd or term.name
					else
						name = vim.api.nvim_buf_get_name(buf)
					end
					return " " .. name
				end,
				name_hl = "Normal",
			},
			path = {
				preview = "previous",
			},
		},
		bar = {
			padding = {
				left = 0,
				right = 0,
			},
			pick = {
				pivots = "scntk,aeihbplduoyf",
			},
		},
		menu = {
			keymaps = {
				q = close,
				["<Esc>"] = close,
				["h"] = "<C-w>q",
				["l"] = function()
					local menu = utils.menu.get_current()
					if not menu then
						return
					end
					local cursor = vim.api.nvim_win_get_cursor(menu.win)
					local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
					if component then
						menu:click_on(component, nil, 1, "l")
					end
				end,
			},
			quick_navigation = true,
			scrollbar = {
				background = false,
			},
			win_configs = {
				border = "rounded",
			},
		},
		fzf = {
			prompt = "%#GitSignsAdd# ",
			win_configs = {},
			keymaps = {
				["<C-n>"] = function()
					require("dropbar.api").fuzzy_find_navigate("down")
				end,
				["<C-t>"] = function()
					require("dropbar.api").fuzzy_find_navigate("up")
				end,
			},
		},
	}
)

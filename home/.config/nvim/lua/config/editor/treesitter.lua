local configs = require("nvim-treesitter.configs")

local disable = function(_, buf)
	local max_filesize = 500 * 1024 -- 500 KB
	local filename = vim.api.nvim_buf_get_name(buf)
	local ok, stats = pcall(vim.loop.fs_stat, filename)
	if ok and stats then
		return (stats.size > max_filesize) or (vim.fn.line("$") < 2 and stats.size > max_filesize / 10)
	end

	return false
end

configs.setup({
	ensure_installed = { "lua", "python", "java", "javascript", "html" },
	auto_install = true,
	modules = {},
	ignore_install = {},
	sync_install = false,
	highlight = {
		enable = true,
		disable = disable,
	},
	indent = {
		enable = true,
		disable = disable,
	},
	textobjects = {
		enable = true,
		disable = disable,
		lookahead = true,
		swap = {
			enable = true,
			swap_next = {
				["<leader>na"] = "@parameter.inner",
				["<leader>nm"] = "@function.outer",
			},
			swap_previous = {
				["<leader>pa"] = "@parameter.inner",
				["<leader>pm"] = "@function.outer",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {
				["]f"] = { query = "@call.outer", desc = "Next function call start" },
				["]m"] = { query = "@function.outer", desc = "Next method/function def start" },
			},
			goto_previous_start = {
				["[f"] = { query = "@call.outer", desc = "Prev function call start" },
				["[m"] = { query = "@function.outer", desc = "Prev method/function def start" },
			},
		},
	},
	textsubjects = {
		enable = true,
		disable = disable,
		prev_selection = ",",
		keymaps = {
			["."] = "textsubjects-smart",
			[";"] = "textsubjects-container-outer",
			["i;"] = "textsubjects-container-inner",
		},
	},
})

local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
-- Repeat movement with ; and ,
-- ensure ; goes forward and , goes backward regardless of the last direction
vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f)
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F)
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t)
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T)

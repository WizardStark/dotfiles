local configs = require("nvim-treesitter.configs")

local function disable(_, buf)
	return require("user.utils").is_big_file(buf)
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
	endwise = {
		enable = true,
	},
	playground = {
		enable = true,
	},
	textobjects = {
		enable = true,
		disable = disable,
		lookahead = true,
		move = {
			enable = true,
			set_jumps = false, -- you can change this if you want.
			goto_next_start = {
				["]b"] = { query = "@code_cell.inner", desc = "next code block" },
			},
			goto_previous_start = {
				["[b"] = { query = "@code_cell.inner", desc = "previous code block" },
			},
		},
		select = {
			enable = true,
			keymaps = {
				["af"] = { query = "@function.outer", desc = "Select outer part of a function region" },
				["if"] = { query = "@function.inner", desc = "Select inner part of a function region" },
				["ac"] = { query = "@class.outer", desc = "Select outer part of a class region" },
				["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
				["ib"] = { query = "@code_cell.inner", desc = "in block" },
				["ab"] = { query = "@code_cell.outer", desc = "around block" },
			},
			selection_modes = {
				["@function.outer"] = "V",
				["@function.inner"] = "V",
				["@class.outer"] = "V",
				["@class.inner"] = "V",
			},
		},
		lsp_interop = {
			enable = true,
			floating_preview_opts = {},
			peek_definition_code = {
				["<leader>df"] = "@function.outer",
				["<leader>dF"] = "@class.outer",
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

vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr())
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr())
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr())
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr())

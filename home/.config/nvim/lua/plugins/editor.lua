return {
	-- UTILS
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = "UiEnter",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
			"nvim-treesitter/playground",
			"RRethy/nvim-treesitter-textsubjects",
			"RRethy/nvim-treesitter-endwise",
		},
		config = function()
			require("config.editor.treesitter")
		end,
	},
	{
		"aaronik/treewalker.nvim",
		event = "VeryLazy",
		opts = {
			highlight = false,
			highlight_duration = 250,
			highlight_group = "CursorLine",
		},
	},
	{
		"kevinhwang91/nvim-ufo",
		dependencies = {
			"kevinhwang91/promise-async",
		},
		lazy = true,
		config = function()
			require("config.editor.folds")
		end,
	},
	{
		"echasnovski/mini.pairs",
		event = { "InsertEnter" },
		config = true,
		opts = {
			mappings = {
				-- Prevents the action if the cursor is just before any character or next to a "\".
				["("] = { action = "open", pair = "()", neigh_pattern = "[^\\][%s%)%]%}]" },
				["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\][%s%)%]%}]" },
				["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\][%s%)%]%}]" },
				-- This is default (prevents the action if the cursor is just next to a "\").
				[")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
				["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
				["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
				-- Prevents the action if the cursor is just before or next to any character.
				['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^%w][^%w]", register = { cr = false } },
				["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%w][^%w]", register = { cr = false } },
				["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^%w][^%w]", register = { cr = false } },
			},
		},
	},
	{
		"windwp/nvim-ts-autotag",
		event = { "InsertEnter", "CmdlineEnter" },
		config = true,
	},
	{
		"ThePrimeagen/refactoring.nvim",
		lazy = true,
		cmd = "Refactor",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("refactoring").setup()
		end,
	},
	{
		"SCJangra/table-nvim",
		ft = { "markdown", "tex" },
		opts = {
			padd_column_separators = true,
			mappings = {
				next = "<TAB>", -- Go to next cell.
				prev = "<S-TAB>", -- Go to previous cell.
				insert_row_up = "<M-S-k>", -- Insert a row above the current row.
				insert_row_down = "<M-S-j>", -- Insert a row below the current row.
				insert_column_left = "<M-S-h>", -- Insert a column to the left of current column.
				insert_column_right = "<M-S-l>", -- Insert a column to the right of current column.
				insert_table = "<M-S-t>", -- Insert a new table.
				insert_table_alt = "<C-M-S-t>", -- Insert a new table that is not surrounded by pipes.
				move_row_up = "<M-S-u>", -- Move the current row down.
				move_row_down = "<M-S-d>", -- Move the current row down.
				move_column_left = "<A-S-y>", -- Move the current column to the left.
				move_column_right = "<A-S-f>", -- Move the current column to the right.
				delete_column = "<A-d>",
			},
		},
	},
	-- COMPLETION
	{
		"saghen/blink.cmp",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"rafamadriz/friendly-snippets",
			"saghen/blink.compat",
			"rcarriga/cmp-dap",
			"Kaiser-Yang/blink-cmp-avante",
		},
		version = "v1.*",
		config = function()
			require("config.editor.blink_cmp")
		end,
	},
	-- DAP
	{
		"mfussenegger/nvim-dap",
		lazy = true,
		dependencies = {
			"theHamsta/nvim-dap-virtual-text",
			"neovim/nvim-lspconfig",
			{
				"rcarriga/nvim-dap-ui",
				dependencies = {
					"nvim-neotest/nvim-nio",
				},
			},
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			require("config.editor.dap")
		end,
	},
	{
		"leoluz/nvim-dap-go",
		lazy = true,
	},
	{
		"mfussenegger/nvim-dap-python",
		lazy = true,
	},
	{
		"jbyuki/one-small-step-for-vimkind",
		dependencies = {
			"mfussenegger/nvim-dap",
		},
		lazy = true,
	},
	-- LSP
	{
		"mfussenegger/nvim-jdtls",
		dependencies = {
			"mfussenegger/nvim-dap",
			"neovim/nvim-lspconfig",
		},
		ft = "java",
		config = function()
			require("config.editor.java")
		end,
	},
	{
		"folke/lazydev.nvim",
		ft = "lua",
		dependencies = {
			"Bilal2453/luvit-meta",
		},
		opts = {
			library = {
				"luvit-meta/library",
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			require("config.editor.lsp")
		end,
	},
	{
		"pmizio/typescript-tools.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"neovim/nvim-lspconfig",
		},
		lazy = true,
	},
	{
		"artemave/workspace-diagnostics.nvim",
		lazy = true,
	},
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		config = function()
			require("config.editor.format")
		end,
	},
	{
		"mfussenegger/nvim-lint",
		event = "VeryLazy",
		config = function()
			require("lint").linters_by_ft = {
				javascript = { "eslint" },
				javascriptreact = { "eslint" },
				typescript = { "eslint" },
				typescriptreact = { "eslint" },
			}
		end,
	},
	{
		"echasnovski/mini.files",
		lazy = true,
		version = false,
		opts = {
			mappings = {
				go_out = "H",
				go_out_plus = "",
				synchronize = "s",
			},
			windows = {
				max_number = 3,
				preview = true,
				width_nofocus = 30,
				width_focus = 50,
				width_preview = 75,
			},
		},
	},
	{
		"luckasRanarison/tailwind-tools.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {},
	},
}

return {
	-- UTILS
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = "UIEnter",
		version = "main",
		dependencies = {
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
		},
		config = function()
			require("config.editor.treesitter")
		end,
	},
	{
		src = "https://github.com/aaronik/treewalker.nvim",
		config = function()
			require("treewalker").setup({
				highlight = false,
				highlight_duration = 250,
				highlight_group = "CursorLine",
			})
		end,
	},
	{
		src = "https://github.com/echasnovski/mini.pairs",
		config = function()
			require("mini.pairs").setup()
		end,
	},
	{
		src = "https://github.com/windwp/nvim-ts-autotag",
		config = function()
			require("nvim-ts-autotag").setup()
		end,
	},
	{
		src = "https://github.com/ThePrimeagen/refactoring.nvim",
		dependencies = {
			{ src = "https://github.com/lewis6991/async.nvim" },
		},
		config = function()
			require("refactoring").setup()
		end,
	},
	{
		src = "https://github.com/SCJangra/table-nvim",
		config = function()
			require("table-nvim").setup({
				padd_column_separators = true,
				mappings = {
					next = "<TAB>",
					prev = "<S-TAB>",
					insert_row_up = "<M-S-k>",
					insert_row_down = "<M-S-j>",
					insert_column_left = "<M-S-h>",
					insert_column_right = "<M-S-l>",
					insert_table = "<M-S-t>",
					insert_table_alt = "<C-M-S-t>",
					move_row_up = "<M-S-u>",
					move_row_down = "<M-S-d>",
					move_column_left = "<A-S-y>",
					move_column_right = "<A-S-f>",
					delete_column = "<A-d>",
				},
			})
		end,
	},
	{
		src = "https://github.com/jmbuhr/otter.nvim",
		dependencies = {
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		},
		config = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				pattern = { "toml" },
				group = vim.api.nvim_create_augroup("EmbedToml", {}),
				callback = function()
					require("otter").activate()
				end,
			})
		end,
	},
	-- COMPLETION
	{
		src = "https://github.com/saghen/blink.cmp",
		dependencies = {
			{ src = "https://github.com/rafamadriz/friendly-snippets" },
			{ src = "https://github.com/saghen/blink.compat" },
			{ src = "https://github.com/rcarriga/cmp-dap" },
			{ src = "https://github.com/moyiz/blink-emoji.nvim" },
			{ src = "https://github.com/hrsh7th/cmp-calc" },
		},
		version = vim.version.range("1.*"),
		config = function()
			require("config.editor.blink_cmp")
		end,
	},
	-- DAP
	{
		src = "https://github.com/mfussenegger/nvim-dap",
		dependencies = {
			{ src = "https://github.com/igorlfs/nvim-dap-view" },
			{ src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },
		},
		config = function()
			require("config.editor.dap")
		end,
	},
	{
		src = "https://github.com/leoluz/nvim-dap-go",
	},
	{
		src = "https://github.com/mfussenegger/nvim-dap-python",
	},
	{
		src = "https://github.com/jbyuki/one-small-step-for-vimkind",
		dependencies = {
			{ src = "https://github.com/mfussenegger/nvim-dap" },
		},
	},
	-- LSP
	{
		src = "https://github.com/mfussenegger/nvim-jdtls",
		dependencies = {
			{ src = "https://github.com/mfussenegger/nvim-dap" },
		},
		config = function()
			require("config.editor.java")
		end,
	},
	{
		src = "https://github.com/folke/lazydev.nvim",
		config = function()
			require("lazydev").setup({
				library = {
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			})
		end,
	},
	{
		src = "https://github.com/neovim/nvim-lspconfig",
		dependencies = {
			{ src = "https://github.com/williamboman/mason.nvim" },
			{ src = "https://github.com/williamboman/mason-lspconfig.nvim" },
			{ src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
		},
		config = function()
			require("config.editor.lsp")
		end,
	},
	{
		src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim",
		priority = 1000,
		config = function()
			require("config.editor.diagnostics")
		end,
	},
	{
		src = "https://github.com/pmizio/typescript-tools.nvim",
		dependencies = {
			{ src = "https://github.com/nvim-lua/plenary.nvim" },
			{ src = "https://github.com/neovim/nvim-lspconfig" },
		},
	},
	{
		src = "https://github.com/stevearc/conform.nvim",
		config = function()
			require("config.editor.format")
		end,
	},
	{
		src = "https://github.com/mfussenegger/nvim-lint",
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
		src = "https://github.com/echasnovski/mini.files",
		config = function()
			require("config.editor.minifiles")
		end,
	},
	{
		src = "https://github.com/nickjvandyke/opencode.nvim",
		init = function()
			vim.g.opencode_opts = require("config.editor.opencode").opts
		end,
		config = function()
			require("config.editor.opencode")
		end,
	},
}

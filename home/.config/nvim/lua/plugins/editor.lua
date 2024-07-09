return {
	-- UTILS
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = "UiEnter",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
			"RRethy/nvim-treesitter-textsubjects",
		},
		config = function()
			require("config.editor.treesitter")
		end,
	},
	{
		"kevinhwang91/nvim-ufo",
		dependencies = {
			"kevinhwang91/promise-async",
		},
		event = "VeryLazy",
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
		"kawre/neotab.nvim",
		event = "InsertEnter",
		config = true,
	},
	-- COMPLETION
	{
		"hrsh7th/nvim-cmp",
		version = false,
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{
				"mireq/luasnip-snippets",
				dependencies = {
					"L3MON4D3/LuaSnip",
					lazy = true,
					build = "make install_jsregexp",
					dependencies = {
						"rafamadriz/friendly-snippets",
						"nvim-treesitter/nvim-treesitter",
					},
				},
			},
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-calc",
			"hrsh7th/cmp-path",
			"f3fora/cmp-spell",
			"onsails/lspkind.nvim",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			require("config.editor.completion")
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
			"nvim-telescope/telescope-dap.nvim",
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
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			require("config.editor.lsp")
		end,
	},
	{
		"zeioth/garbage-day.nvim",
		event = "VeryLazy",
		opts = {
			notifications = true,
		},
	},
	{
		"scalameta/nvim-metals",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		ft = { "scala", "sbt" },
		opts = function()
			local metals_config = require("metals").bare_config()
			return metals_config
		end,
		config = function(self, metals_config)
			local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				pattern = self.ft,
				callback = function()
					require("metals").initialize_or_attach(metals_config)
				end,
				group = nvim_metals_group,
			})
		end,
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
	-- FILES
	{
		"nvim-telescope/telescope.nvim",
		lazy = true,
		cmd = { "Telescope", "Easypick" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			"junegunn/fzf.vim",
			"nvim-tree/nvim-web-devicons",
			"debugloop/telescope-undo.nvim",
			"rcarriga/nvim-notify",
			"nvim-telescope/telescope-live-grep-args.nvim",
			"axkirillov/easypick.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
			},
			{
				"agoodshort/telescope-git-submodules.nvim",
				dependencies = "akinsho/toggleterm.nvim",
			},
		},
		config = function()
			require("config.editor.telescope")
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
}

return {
	-- UTILS
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
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
		"altermo/ultimate-autopair.nvim",
		event = { "InsertEnter", "CmdlineEnter" },
		branch = "v0.6",
		opts = {
			bs = {
				enable = false,
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
			{
				"rcarriga/nvim-dap-ui",
				dependencies = {
					"nvim-neotest/nvim-nio",
				},
			},
			"jay-babu/mason-nvim-dap.nvim",
			"nvim-telescope/telescope-dap.nvim",
			{
				"leoluz/nvim-dap-go",
				dependencies = {
					"mfussenegger/nvim-dap",
					"rcarriga/nvim-dap-ui",
				},
			},
			{
				"mfussenegger/nvim-dap-python",
				dependencies = {
					"mfussenegger/nvim-dap",
					"rcarriga/nvim-dap-ui",
				},
			},
		},
		config = function()
			require("config.editor.dap")
		end,
	},
	{
		"jbyuki/one-small-step-for-vimkind",
		dependencies = {
			"mfussenegger/nvim-dap",
		},
		lazy = true,
		config = function()
			local dap = require("dap")
			dap.configurations.lua = {
				{
					type = "nlua",
					request = "attach",
					name = "Attach to running Neovim instance",
				},
			}
			dap.adapters.nlua = function(callback, config)
				callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
			end
		end,
	},
	-- LSP
	{
		"mfussenegger/nvim-jdtls",
		dependencies = {
			"mfussenegger/nvim-dap",
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
		event = { "BufWinEnter", "BufNewFile" },
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
		event = "BufEnter",
		opts = {
			notifications = true,
		},
	},
	{
		"b0o/schemastore.nvim",
		lazy = true,
		ft = { "yaml", "json" },
	},
	{
		"someone-stole-my-name/yaml-companion.nvim",
		lazy = true,
		ft = { "yaml", "json" },
		dependencies = {
			"neovim/nvim-lspconfig",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			local cfg = require("yaml-companion").setup({})
			local lspconfig = require("lspconfig")
			local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()
			lsp_capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}
			cfg.capabilities = lsp_capabilities
			lspconfig.yamlls.setup(cfg)
		end,
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
		event = { "BufWritePre" },
		init = function()
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
		cmd = { "Telescope" },
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

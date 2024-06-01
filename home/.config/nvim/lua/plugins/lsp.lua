return {
	--neodev
	{
		"folke/neodev.nvim",
		lazy = true,
	},
	-- lspconfig
	{
		"neovim/nvim-lspconfig",
		event = { "BufWinEnter", "BufNewFile" },
		dependencies = {
			"mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

			lsp_capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}

			local mason_lspconfig = require("mason-lspconfig")
			local border = {
				{ "╭", "FloatBorder" },
				{ "─", "FloatBorder" },
				{ "╮", "FloatBorder" },
				{ "│", "FloatBorder" },
				{ "╯", "FloatBorder" },
				{ "─", "FloatBorder" },
				{ "╰", "FloatBorder" },
				{ "│", "FloatBorder" },
			}
			local handlers = {
				vim.diagnostic.config({
					float = { border = "rounded" },
				}),
				["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
				["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
			}

			mason_lspconfig.setup({
				ensure_installed = {
					"lua_ls",
					"basedpyright",
					"jdtls",
				},
			})
			mason_lspconfig.setup_handlers({
				function(server_name)
					lspconfig[server_name].setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
					})
				end,
				["jdtls"] = function() end,
				["lua_ls"] = function()
					require("neodev").setup({
						library = { plugins = { "neotest" }, types = true },
						override = function(root_dir, library)
							if root_dir:find("nvim") or root_dir:find("dotfiles") then
								library.enabled = true
								library.plugins = true
								library.types = true
								library.runtime = true
							end
						end,
					})
					lspconfig.lua_ls.setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							Lua = {
								hint = {
									enable = true,
								},
							},
						},
					})
				end,
				["basedpyright"] = function()
					lspconfig["basedpyright"].setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							basedpyright = {
								typeCheckingMode = "off",
							},
							python = {
								analysis = {
									diagnosticSeverityOverrides = {
										reportUnusedExpression = "none",
									},
									autoSearchPaths = true,
									diagnosticMode = "openFilesOnly",
									useLibraryCodeForTypes = true,
								},
							},
						},
					})
				end,
				["gopls"] = function()
					lspconfig.gopls.setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							gopls = {
								hints = {
									rangeVariableTypes = true,
									parameterNames = true,
									constantValues = true,
									assignVariableTypes = true,
									compositeLiteralFields = true,
									compositeLiteralTypes = true,
									functionTypeParameters = true,
								},
							},
						},
					})
				end,
				["tsserver"] = function()
					lspconfig.tsserver.setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							typescript = {
								inlayHints = {
									includeInlayParameterNameHints = "all",
									includeInlayParameterNameHintsWhenArgumentMatchesName = true,
									includeInlayFunctionParameterTypeHints = true,
									includeInlayVariableTypeHints = true,
									includeInlayVariableTypeHintsWhenTypeMatchesName = true,
									includeInlayPropertyDeclarationTypeHints = true,
									includeInlayFunctionLikeReturnTypeHints = true,
									includeInlayEnumMemberValueHints = true,
								},
							},
							javascript = {
								inlayHints = {
									includeInlayParameterNameHints = "all",
									includeInlayParameterNameHintsWhenArgumentMatchesName = true,
									includeInlayFunctionParameterTypeHints = true,
									includeInlayVariableTypeHints = true,
									includeInlayVariableTypeHintsWhenTypeMatchesName = true,
									includeInlayPropertyDeclarationTypeHints = true,
									includeInlayFunctionLikeReturnTypeHints = true,
									includeInlayEnumMemberValueHints = true,
								},
							},
						},
					})
				end,
				["kotlin_language_server"] = function()
					lspconfig.kotlin_language_server.setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							kotlin = {
								hints = {
									typeHints = true,
									parameterHints = true,
									chaineHints = true,
								},
							},
						},
					})
				end,
				["jsonls"] = function()
					lspconfig.jsonls.setup({
						on_attach = function()
							if vim.g.extra_lsp_actions ~= nil then
								vim.g.extra_lsp_actions()
							end
						end,
						capabilities = lsp_capabilities,
						handlers = handlers,
						settings = {
							json = {
								schemas = require("schemastore").json.schemas(),
								validate = { enable = true },
							},
						},
					})
				end,
			})
		end,
	},
	--lsp servers
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		opts = {
			ui = { border = "rounded" },
			registries = {
				"github:mason-org/mason-registry",
			},
		},
	},
	--lsp garbage collection
	{
		"zeioth/garbage-day.nvim",
		event = "BufEnter",
		opts = {
			notifications = true,
		},
	},
	-- formatter installer
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		lazy = true,
		opts = {
			ensure_installed = {
				"black",
				"usort",
				"prettier",
				"prettierd",
				"shfmt",
				"checkstyle",
				"stylua",
				"jq",
				"yamlfmt",
			},
		},
	},
	-- helper for using yaml and json schemas
	{
		"b0o/schemastore.nvim",
		lazy = true,
		ft = { "yaml", "json" },
	},
	-- yaml shema telescope interface
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
	-- scala lsp
	{
		"scalameta/nvim-metals",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		ft = { "scala", "sbt", "java" },
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
}

local lspconfig = require("lspconfig")
local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

require("mason").setup({
	ui = { border = "rounded" },
	registries = {
		"github:mason-org/mason-registry",
	},
})

require("mason-tool-installer").setup({
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
})

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
			init_options = {
				storagePath = require("lspconfig.util").path.join(vim.env.XDG_DATA_HOME, "nvim-data"),
			},
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

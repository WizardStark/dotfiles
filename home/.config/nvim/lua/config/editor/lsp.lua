local lspconfig = require("lspconfig")

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

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
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

local function on_attach(client, bufnr)
	if vim.g.extra_lsp_actions ~= nil then
		vim.g.extra_lsp_actions()
	end
end

require("typescript-tools").setup({
	on_attach = on_attach,
	capabilities = capabilities,
	handlers = handlers,
	settings = {
		expose_as_code_action = "all",
		tsserver_file_preferences = {
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
mason_lspconfig.setup({
	ensure_installed = {
		"lua_ls",
		"basedpyright",
		"jdtls",
		"ts_ls",
	},
	automatic_installation = true,
})

mason_lspconfig.setup_handlers({
	function(server_name)
		lspconfig[server_name].setup({
			on_attach = on_attach,
			capabilities = capabilities,
			handlers = handlers,
		})
	end,
	["jdtls"] = function() end,
	["ts_ls"] = function() end,
	["lua_ls"] = function()
		lspconfig.lua_ls.setup({
			on_attach = on_attach,
			capabilities = capabilities,
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
			on_attach = on_attach,
			capabilities = capabilities,
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
			on_attach = on_attach,
			capabilities = capabilities,
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
	["kotlin_language_server"] = function()
		lspconfig.kotlin_language_server.setup({
			on_attach = on_attach,
			capabilities = capabilities,
			handlers = handlers,
			init_options = {
				storagePath = table.concat({ vim.fn.stdpath("data") }, "nvim-data"),
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
})

-- require("typescript-tools")
-- require("typescript-tools").setup({
-- 	-- on_attach = on_attach,
-- 	-- capabilities = capabilities,
-- 	-- handlers = handlers,
-- 	settings = {
-- 		expose_as_code_action = "all",
-- 		tsserver_file_preferences = {
-- 			inlayHints = {
-- 				includeInlayParameterNameHints = "all",
-- 				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
-- 				includeInlayFunctionParameterTypeHints = true,
-- 				includeInlayVariableTypeHints = true,
-- 				includeInlayVariableTypeHintsWhenTypeMatchesName = true,
-- 				includeInlayPropertyDeclarationTypeHints = true,
-- 				includeInlayFunctionLikeReturnTypeHints = true,
-- 				includeInlayEnumMemberValueHints = true,
-- 			},
-- 		},
-- 	},
-- })
--
-- lspconfig.kulala_ls.setup({
-- 	-- capabilities = capabilities,
-- })

--as we lazy load this we need to trigger the ft event manually after everything is set up
vim.cmd("doautocmd FileType")

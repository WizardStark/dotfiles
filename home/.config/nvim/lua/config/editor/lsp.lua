local lspconfig = require("lspconfig")
-- local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

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

-- lsp_capabilities.textDocument.foldingRange = {
-- 	dynamicRegistration = false,
-- 	lineFoldingOnly = true,
-- }

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
		-- virtual_text = false,
	}),
	["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
	["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
}

local function on_attach(client, bufnr)
	if vim.g.extra_lsp_actions ~= nil then
		vim.g.extra_lsp_actions()
	end
end

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
			on_attach = on_attach,
			-- capabilities = lsp_capabilities,
			handlers = handlers,
		})
	end,
	["jdtls"] = function() end,
	["lua_ls"] = function()
		lspconfig.lua_ls.setup({
			on_attach = on_attach,
			-- capabilities = lsp_capabilities,
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
			-- capabilities = lsp_capabilities,
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
			-- capabilities = lsp_capabilities,
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
	["ts_ls"] = function()
		lspconfig.ts_ls.setup({
			on_attach = on_attach,
			-- capabilities = lsp_capabilities,
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
			on_attach = on_attach,
			-- capabilities = lsp_capabilities,
			handlers = handlers,
			init_options = {
<<<<<<< HEAD
				storagePath = table.concat({ vim.fn.stdpath("data") }, "nvim-data"),
||||||| parent of 06163f7 (Update blink.cmp config to version 0.8.2)
				storagePath = require("lspconfig.util").path.join(vim.env.XDG_DATA_HOME, "nvim-data"),
=======
				storagePath = vim.fn.stdpath("data") .. "/nvim-data",
>>>>>>> 06163f7 (Update blink.cmp config to version 0.8.2)
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

-- lspconfig.kulala_ls.setup({
-- 	-- capabilities = lsp_capabilities,
-- })

--as we lazy load this we need to trigger the ft event manually after everything is set up
vim.cmd("doautocmd FileType")

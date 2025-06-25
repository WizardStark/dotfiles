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

local mason_lspconfig = require("mason-lspconfig")

mason_lspconfig.setup({
	ensure_installed = {
		"lua_ls",
		"basedpyright",
		"ts_ls",
	},
	automatic_installation = true,
	automatic_enable = {
		exclude = {
			"basedpyright",
			"lua_ls",
			"jdtls",
			"ts_ls",
			"ruff",
		},
	},
})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
	dynamicRegistration = false,
	lineFoldingOnly = true,
}

local function on_attach(client, bufnr)
	if vim.g.extra_lsp_actions ~= nil then
		vim.g.extra_lsp_actions()
	end
end

vim.lsp.config("*", {
	capabilities = capabilities,
	on_attach = on_attach,
})

require("typescript-tools").setup({
	on_attach = function(client, bufnr)
		on_attach(client, bufnr)
		vim.cmd("au! TypescriptToolsCodeLensGroup")
	end,
	capabilities = capabilities,
	settings = {
		expose_as_code_action = "all",
		code_lens = "all",
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

lspconfig.lua_ls.setup({
	on_attach = on_attach,
	capabilities = capabilities,
	settings = {
		Lua = {
			hint = {
				enable = true,
			},
		},
	},
})

lspconfig.basedpyright.setup({
	on_attach = function(client, bufnr)
		on_attach(client, bufnr)
		local path = require("user.utils").get_python_venv()
		require("dap-python").setup(path)

		if client.settings then
			client.settings.python = vim.tbl_deep_extend("force", client.settings.python, { pythonPath = path })
		else
			client.config.settings =
				vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = path } })
		end
		client.notify("workspace/didChangeConfiguration", { settings = nil })
	end,
	capabilities = capabilities,
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

lspconfig.gopls.setup({
	on_attach = on_attach,
	capabilities = capabilities,
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

lspconfig.kotlin_language_server.setup({
	on_attach = on_attach,
	capabilities = capabilities,
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

-- lspconfig.kulala_ls.setup({
-- 	-- capabilities = capabilities,
-- })

--as we lazy load this we need to trigger the ft event manually after everything is set up
vim.cmd("doautocmd FileType")

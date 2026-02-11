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
		"stylua",
		"jq",
		"yamlfmt",
	},
})

local mason_lspconfig = require("mason-lspconfig")

mason_lspconfig.setup({
	ensure_installed = {
		"lua_ls",
		"ty",
		"ruff",
	},
	automatic_installation = true,
	automatic_enable = {
		exclude = {
			"basedpyright",
			"lua_ls",
			"ts_ls",
			"gopls",
			"stylua",
			"jdtls",
			"ty",
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
	vim.treesitter.start()
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

vim.lsp.config("lua_ls", {
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
vim.lsp.enable("lua_ls")

vim.lsp.config.ty = {
	on_attach = function(client, bufnr)
		on_attach(client, bufnr)
		require("dap-python").setup("uv")
	end,
	capabilities = capabilities,
}

vim.lsp.enable("ty")

vim.lsp.config.gopls = {
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
}

vim.lsp.enable("gopls")
-- As we lazy load this we need to trigger the ft event manually after everything is set up
vim.cmd("doautocmd FileType")

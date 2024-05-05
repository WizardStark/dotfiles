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
						capabilities = lsp_capabilities,
						handlers = handlers,
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
}

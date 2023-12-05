return {
	-- lspconfig
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
	},
	--lsp servers
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		dependencies = {
			{ "mfussenegger/nvim-jdtls" },
		},
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
				},
			})
			require("mason-lspconfig").setup({
				ensure_installed = {
					-- Replace these with whatever servers you want to install
					"lua_ls",
				},
			})

			local lspconfig = require("lspconfig")
			local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

			local function lsp_keymap(bufnr)
				local bufopts = { noremap = true, silent = true, buffer = bufnr }
				require("legendary").keymaps({
					{ mode = "n", "K", vim.lsp.buf.hover, description = "Show documentation", bufopts },
					{ mode = "n", "gd", vim.lsp.buf.definition, description = "Go to definition", bufopts },
					{ mode = "n", "gi", vim.lsp.buf.implementation, description = "Show implementations", bufopts },
					{ mode = "n", "gr", vim.lsp.buf.references, description = "Show references", bufopts },
					{ mode = "n", "gD", vim.lsp.buf.declaration, description = "Go to declaration", bufopts },
					{ mode = "n", "<leader>K", vim.lsp.buf.signature_help, description = "Signature help", bufopts },
					{ mode = "n", "gt", vim.lsp.buf.type_definition, description = "Go to type definition", bufopts },
					{ mode = "n", "<F2>", vim.lsp.buf.rename, description = "Rename", bufopts },
					{ mode = "n", "<leader>ca", vim.lsp.buf.code_action, description = "Code Action", bufopts },
					{
						mode = "n",
						"<leader>ds",
						vim.diagnostic.open_float,
						description = "Open LSP diagnostics in a popup",
					},
				})
			end

			local lsp_attach = function(client, bufnr)
				lsp_keymap(bufnr)
			end

			require("mason-lspconfig").setup_handlers({
				function(server_name)
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
						["textDocument/signatureHelp"] = vim.lsp.with(
							vim.lsp.handlers.signature_help,
							{ border = border }
						),
					}

					if server_name == "lua_ls" then
						lspconfig[server_name].setup({
							on_attach = lsp_attach,
							capabilities = lsp_capabilities,
							handlers = handlers,
							settings = {
								Lua = {
									diagnostics = {
										globals = { "vim" },
									},
								},
							},
						})
					else
						lspconfig[server_name].setup({
							on_attach = lsp_attach,
							capabilities = lsp_capabilities,
							handlers = handlers,
						})
					end
				end,
				["jdtls"] = function() end,
			})
		end,
	},
	--lsp diagnostics
	{
		"folke/trouble.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	--lsp garbage collection
	{
		"zeioth/garbage-day.nvim",
		event = "BufEnter",
		opts = {
			-- your options here
		},
	},
}

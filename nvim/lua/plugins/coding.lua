return {
	--git
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		opts = {
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text_pos = "right_align",
				delay = 500,
			},
		},
	},
	{
		"rhysd/git-messenger.vim",
		event = "VeryLazy",
		init = function()
			vim.cmd([[ let g:git_messenger_floating_win_opts = { "border":"rounded" } ]])
			vim.cmd([[ let g:git_messenger_always_into_popup = v:true ]])
		end,
	},
	--treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local configs = require("nvim-treesitter.configs")

			configs.setup({
				ensure_installed = { "lua", "python", "java", "javascript", "html" },
				auto_install = true,
				sync_install = false,
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},
	--auto close brackets
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
	--cmp
	{
		"hrsh7th/nvim-cmp",
		version = false, -- last release is way too old
		event = "VeryLazy",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{
				"L3MON4D3/LuaSnip",
				dependencies = { "rafamadriz/friendly-snippets" },
			},
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-calc",
			"onsails/lspkind.nvim",
			"hrsh7th/cmp-nvim-lsp-signature-help",
		},
		opts = function()
			local luasnip = require("luasnip")
			local lspkind = require("lspkind")
			local cmp = require("cmp")
			local window_scroll_bordered = cmp.config.window.bordered({
				scrolloff = 3,
				scrollbar = true,
			})

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-u>"] = cmp.mapping.scroll_docs(-4), -- Up
					["<C-d>"] = cmp.mapping.scroll_docs(4), -- Down
					-- C-b (back) C-f (forward) for snippet placeholder navigation.
					["<C-Space>"] = cmp.mapping.complete(),
					["<CR>"] = cmp.mapping.confirm({
						select = false,
					}),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				window = {
					documentation = window_scroll_bordered,
					completion = window_scroll_bordered,
				},
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "codeium" },
					{ name = "calc" },
					{ name = "nvim_lsp_signature_help" },
				}, {
					{ name = "buffer" },
				}),
				formatting = {
					fields = { "kind", "abbr", "menu" },
					format = function(entry, vim_item)
						local kind = lspkind.cmp_format({
							mode = "symbol_text",
							maxwidth = 50,
							symbol_map = { Codeium = "" },
						})(entry, vim_item)
						local strings = vim.split(kind.kind, "%s", { trimempty = true })
						kind.kind = " " .. (strings[1] or "") .. " "
						kind.menu = "    (" .. (strings[2] or "") .. ")"
						return kind
					end,
				},
			})
			-- `/` cmdline setup.
			cmp.setup.cmdline("/", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})
			-- `:` cmdline setup.
			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
					},
				}),
			})
		end,
	},
	--better commenting
	{
		"numToStr/Comment.nvim",
		event = "VeryLazy",
		opts = {
			-- add any options here
		},
	},
	--function overview
	{
		"stevearc/aerial.nvim",
		-- Optional dependencies
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		event = "VeryLazy",
		opts = {
			backends = { "lsp", "treesitter", "markdown", "man" },
			filter_kind = {
				"Array",
				"Class",
				"Constant",
				"Constructor",
				"Enum",
				"Field",
				"File",
				"Function",
				"Interface",
				"Method",
				"Module",
				"Namespace",
				"Null",
				-- "Object",
				"Package",
				"Struct",
				"TypeParameter",
			},
			layout = {
				min_width = 20,
			},
		},
	},
	--autoformat
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				-- Customize or remove this keymap to your liking
				"<leader>cf",
				function()
					require("conform").format({ async = true, lsp_fallback = false })
				end,
				mode = "",
				desc = "Format buffer",
			},
		},
		-- Everything in opts will be passed to setup()
		opts = {
			-- Define your formatters
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "usort", "black" },
				java = { "checkstyle" },
				javascript = { { "prettierd", "prettier" } },
				javascriptreact = { { "prettierd", "prettier" } },
				typescript = { { "prettierd", "prettier" } },
				typescriptreact = { { "prettierd", "prettier" } },
				json = { "jq" },
				go = { "gofumpt" },
				bash = { "shfmt" },
				sh = { "shfmt" },
				zsh = { "shfmt" },
				yml = { "yamlfmt" },
				yaml = { "yamlfmt" },
			},
			-- Set up format-on-save
			format_on_save = { timeout_ms = 500, lsp_fallback = false },
			-- Customize formatters
			formatters = {
				shfmt = {
					prepend_args = { "-i", "2" },
				},
			},
		},
		init = function()
			-- If you want the formatexpr, here is the place to set it
			vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
		end,
	},
}

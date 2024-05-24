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
			preview_config = {
				border = "rounded",
			},
		},
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		opts = {},
	},
	--treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
			"RRethy/nvim-treesitter-textsubjects",
		},
		config = function()
			local configs = require("nvim-treesitter.configs")

			local disable = function(_, buf)
				local max_filesize = 500 * 1024 -- 500 KB
				local filename = vim.api.nvim_buf_get_name(buf)
				local ok, stats = pcall(vim.loop.fs_stat, filename)
				if ok and stats then
					return (stats.size > max_filesize) or (vim.fn.line("$") < 2 and stats.size > max_filesize / 10)
				end

				return false
			end

			configs.setup({
				ensure_installed = { "lua", "python", "java", "javascript", "html" },
				auto_install = true,
				modules = {},
				ignore_install = {},
				sync_install = false,
				highlight = {
					enable = true,
					disable = disable,
				},
				indent = {
					enable = true,
					disable = disable,
				},
				textobjects = {
					enable = true,
					disable = disable,
					lookahead = true,
					swap = {
						enable = true,
						swap_next = {
							["<leader>na"] = "@parameter.inner",
							["<leader>nm"] = "@function.outer",
						},
						swap_previous = {
							["<leader>pa"] = "@parameter.inner",
							["<leader>pm"] = "@function.outer",
						},
					},
					move = {
						enable = true,
						set_jumps = true,
						goto_next_start = {
							["]f"] = { query = "@call.outer", desc = "Next function call start" },
							["]m"] = { query = "@function.outer", desc = "Next method/function def start" },
						},
						goto_previous_start = {
							["[f"] = { query = "@call.outer", desc = "Prev function call start" },
							["[m"] = { query = "@function.outer", desc = "Prev method/function def start" },
						},
					},
				},
				textsubjects = {
					enable = true,
					disable = disable,
					prev_selection = ",",
					keymaps = {
						["."] = "textsubjects-smart",
						[";"] = "textsubjects-container-outer",
						["i;"] = "textsubjects-container-inner",
					},
				},
			})

			local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
			-- Repeat movement with ; and ,
			-- ensure ; goes forward and , goes backward regardless of the last direction
			vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
			vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

			vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f)
			vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F)
			vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t)
			vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T)
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
	--auto close html tags
	{
		"windwp/nvim-ts-autotag",
		event = { "InsertEnter", "CmdlineEnter" },
		opts = {},
	},
	--cmp
	{
		"hrsh7th/nvim-cmp",
		version = false, -- last release is way too old
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-calc",
			"f3fora/cmp-spell",
			"onsails/lspkind.nvim",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"saadparwaiz1/cmp_luasnip",
		},
		opts = function()
			local luasnip = require("luasnip")
			local lspkind = require("lspkind")
			local cmp = require("cmp")
			local window_scroll_bordered = cmp.config.window.bordered({
				scrolloff = 3,
				scrollbar = true,
			})

			local function tab(fallback)
				if cmp.visible() then
					cmp.select_next_item()
				elseif luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				else
					fallback()
				end
			end

			local function shift_tab(fallback)
				if cmp.visible() then
					cmp.select_prev_item()
				elseif luasnip.jumpable(-1) then
					luasnip.jump(-1)
				else
					fallback()
				end
			end

			local function down(fallback)
				if cmp.visible() then
					cmp.select_next_item()
				else
					fallback()
				end
			end

			local function up(fallback)
				if cmp.visible() then
					cmp.select_prev_item()
				else
					fallback()
				end
			end

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = {
					["<Tab>"] = cmp.mapping(tab, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(shift_tab, { "i", "s" }),
					["<C-u>"] = cmp.mapping.scroll_docs(-4),
					["<C-d>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.close(),
					["<CR>"] = cmp.mapping.confirm({
						select = false,
					}),
					["<C-a>"] = cmp.mapping.confirm({
						select = false,
					}),
					["<C-t>"] = cmp.mapping(up, { "i", "s" }),
					["<C-n>"] = cmp.mapping(down, { "i", "s" }),
					["<Up>"] = cmp.mapping(up, { "i", "s" }),
					["<Down>"] = cmp.mapping(down, { "i", "s" }),
				},
				window = {
					documentation = window_scroll_bordered,
					completion = window_scroll_bordered,
				},
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "calc" },
					{ name = "nvim_lsp_signature_help" },
					{
						name = "spell",
						option = {
							keep_all_entries = true,
							enable_in_context = function()
								return true
							end,
						},
					},
				}, {
					{ name = "buffer" },
				}),
				formatting = {
					fields = { "kind", "abbr", "menu" },
					format = function(entry, vim_item)
						local kind = lspkind.cmp_format({
							mode = "symbol_text",
							maxwidth = 50,
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
	--snippets
	{
		"mireq/luasnip-snippets",
		lazy = true,
		dependencies = { "L3MON4D3/LuaSnip" },
		config = function()
			require("luasnip_snippets.common.snip_utils").setup()
		end,
	},
	{
		"L3MON4D3/LuaSnip",
		lazy = true,
		build = "make install_jsregexp",
		dependencies = {
			"rafamadriz/friendly-snippets",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("luasnip").setup({
				load_ft_func = require("luasnip_snippets.common.snip_utils").load_ft_func,
				ft_func = require("luasnip_snippets.common.snip_utils").ft_func,
				enable_autosnippets = true,
				history = true,
				updateevents = "TextChanged,TextChangedI",
			})
			require("luasnip/loaders/from_vscode").lazy_load()
		end,
	},
	{
		"stevearc/aerial.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		lazy = true,
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
		opts = {
			-- Define your formatters
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "usort", "black" },
				java = { "checkstyle" },
				kotlin = { "ktlint" },
				javascript = { { "prettierd", "prettier" } },
				javascriptreact = { { "prettierd", "prettier" } },
				typescript = { { "prettierd", "prettier" } },
				typescriptreact = { { "prettierd", "prettier" } },
				markdown = { { "prettierd", "prettier" } },
				css = { { "prettierd", "prettier" } },
				scss = { { "prettierd", "prettier" } },
				json = { "jq" },
				go = { "gofumpt" },
				bash = { "shfmt" },
				sh = { "shfmt" },
				zsh = { "shfmt" },
				yml = { "yamlfmt" },
				yaml = { "yamlfmt" },
			},
			format_on_save = true,
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
	-- lint
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
	--latex
	{
		"lervag/vimtex",
		ft = { "markdown", "tex" },
		init = function()
			vim.g.vimtex_syntax_enabled = 1
			vim.g.vimtex_compiler_latexmk = {
				build_dir = function()
					return vim.fn["vimtex#util#find_root"]()
				end,
				callback = 1,
				continuous = 1,
				executable = "latexmk",
				hooks = {},
				options = {
					"-xelatex",
					"-shell-escape",
					"-verbose",
					"-file-line-error",
					"-synctex=1",
					"-interaction=nonstopmode",
				},
			}
			vim.g.vimtex_view_method = "zathura"
			vim.g.vimtex_quickfix_enabled = 0
		end,
	},
}

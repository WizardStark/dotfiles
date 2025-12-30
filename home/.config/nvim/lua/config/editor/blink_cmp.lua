local default_sources = { "lsp", "path", "calc", "snippets", "buffer", "lazydev", "emoji" }
local debug_sources = vim.list_extend(vim.deepcopy(default_sources), { "dap" })

require("blink.cmp").setup({
	keymap = {
		preset = "enter",
		["<Tab>"] = {
			function(cmp)
				if cmp.is_menu_visible() then
					return require("blink.cmp").select_next()
				elseif cmp.snippet_active() then
					return cmp.snippet_forward()
				end
			end,
			"fallback",
		},
		["<S-Tab>"] = {
			function(cmp)
				if cmp.is_menu_visible() then
					return require("blink.cmp").select_prev()
				elseif cmp.snippet_active() then
					return cmp.snippet_backward()
				end
			end,
			"fallback",
		},
		["<C-k>"] = {},
	},
	enabled = function()
		if require("cmp_dap").is_dap_buffer() then
			return "force"
		end
		return true
	end,
	signature = {
		enabled = true,
		window = {
			border = "rounded",
			scrollbar = false,
		},
	},
	sources = {
		default = default_sources,
		per_filetype = { ["dap-repl"] = debug_sources, ["dap-view"] = debug_sources },
		providers = {
			lsp = {
				async = true,
			},
			calc = {
				name = "calc",
				module = "blink.compat.source",
			},
			dap = {
				name = "dap",
				module = "blink.compat.source",
				enabled = function()
					return require("cmp_dap").is_dap_buffer()
				end,
			},
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				fallbacks = { "lsp" },
			},
			emoji = {
				module = "blink-emoji",
				name = "Emoji",
				score_offset = 15,
				opts = {
					insert = true,
					---@type string|table|fun():table
					trigger = function()
						return { ":" }
					end,
				},
				should_show_items = function()
					return vim.tbl_contains(
						-- Enable emoji completion only for these filetypes.
						{ "gitcommit", "markdown", "octo" },
						vim.o.filetype
					)
				end,
			},
		},
	},
	appearance = {
		kind_icons = {
			Snippet = "",
		},
	},
	cmdline = {
		completion = {
			menu = {
				auto_show = true,
			},
			ghost_text = {
				enabled = false,
			},
			list = {
				selection = {
					preselect = false,
					auto_insert = true,
				},
			},
		},
	},
	completion = {
		keyword = {
			range = "prefix",
		},
		list = {
			selection = {
				preselect = false,
				auto_insert = true,
			},
		},
		accept = {
			auto_brackets = {
				enabled = true,
				override_brackets_for_filetypes = {
					tex = { "{", "}" },
				},
			},
		},
		menu = {
			min_width = 20,
			border = "rounded",
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
			draw = {
				columns = { { "kind_icon" }, { "label", gap = 1 }, { "source" } },
				components = {
					label = {
						text = require("colorful-menu").blink_components_text,
						highlight = require("colorful-menu").blink_components_highlight,
					},
					source = {
						text = function(ctx)
							local map = {
								["lsp"] = "[]",
								["path"] = "[󰉋]",
								["snippets"] = "[]",
							}

							return map[ctx.item.source_id]
						end,
						highlight = "BlinkCmpDoc",
					},
				},
			},
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 100,
			update_delay_ms = 50,
			window = {
				max_width = math.min(80, vim.o.columns),
				border = "rounded",
			},
		},
	},
})

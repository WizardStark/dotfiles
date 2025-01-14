require("blink.cmp").setup({
	keymap = {
		preset = "enter",
		["<Tab>"] = {
			function(cmp)
				if cmp.snippet_active() then
					return cmp.accept()
				else
					return require("blink.cmp").select_next()
				end
			end,
			"snippet_forward",
			"fallback",
		},
		["<S-Tab>"] = {
			"select_prev",
			"snippet_forward",
			"fallback",
		},
	},
	signature = {
		enabled = true,
		window = {
			border = "rounded",
		},
	},
	sources = {
		default = {
			"lsp",
			"path",
			"snippets",
			"buffer",
			"lazydev",
			"ripgrep",
		},
		providers = {
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				fallbacks = { "lsp" },
			},
			ripgrep = {
				module = "blink-ripgrep",
				name = "Ripgrep",
				-- the options below are optional, some default values are shown
				---@module "blink-ripgrep"
				---@type blink-ripgrep.Options
				opts = {
					prefix_min_len = 3,
					context_size = 5,
					max_filesize = "1M",
				},
			},
		},
	},
	appearance = {
		kind_icons = {
			Snippet = "",
		},
	},
	completion = {
		keyword = {
			range = "full",
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
						highlight = "BlinkCmpSource",
					},
				},
			},
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 100,
			update_delay_ms = 10,
			window = {
				max_width = math.min(80, vim.o.columns),
				border = "rounded",
			},
		},
	},
})

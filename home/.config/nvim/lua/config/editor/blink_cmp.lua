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
		completion = {
			enabled_providers = { "lsp", "path", "snippets", "buffer", "lazydev" },
		},
		providers = {
			lsp = { fallback_for = { "lazydev" } },
			lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
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
			selection = "auto_insert",
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
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source" } },
				components = {
					source = {
						ellipses = false,
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

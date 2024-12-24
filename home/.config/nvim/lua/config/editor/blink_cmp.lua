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
<<<<<<< HEAD

		default = {
			"lsp",
			"path",
			"snippets",
			"buffer",
			"lazydev",
			"ripgrep",
||||||| parent of 06163f7 (Update blink.cmp config to version 0.8.2)
		completion = {
			enabled_providers = {
				"lsp",
				"path",
				"snippets",
				"buffer",
				"lazydev",
				"ripgrep",
			},
=======
		default = {
			"lazydev",
			"lsp",
			"path",
			"snippets",
			"buffer",
			"ripgrep",
>>>>>>> 06163f7 (Update blink.cmp config to version 0.8.2)
		},
		providers = {
<<<<<<< HEAD
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				fallbacks = { "lsp" },
			},
||||||| parent of 06163f7 (Update blink.cmp config to version 0.8.2)
			lsp = { fallback_for = { "lazydev" } },
			lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
=======
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				score_offset = 100,
			},
>>>>>>> 06163f7 (Update blink.cmp config to version 0.8.2)
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
<<<<<<< HEAD
				columns = { { "kind_icon" }, { "label", gap = 1 }, { "source" } },
||||||| parent of 06163f7 (Update blink.cmp config to version 0.8.2)
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source" } },
=======
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_custom" } },
>>>>>>> 06163f7 (Update blink.cmp config to version 0.8.2)
				components = {
<<<<<<< HEAD
					label = {
						text = require("colorful-menu").blink_components_text,
						highlight = require("colorful-menu").blink_components_highlight,
					},
					source = {
||||||| parent of 06163f7 (Update blink.cmp config to version 0.8.2)
					source = {
						ellipses = false,
=======
					source_custom = {
>>>>>>> 06163f7 (Update blink.cmp config to version 0.8.2)
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

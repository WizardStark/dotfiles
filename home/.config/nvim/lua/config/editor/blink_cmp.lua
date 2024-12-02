---@param ctx blink.cmp.CompletionRenderContext
---@return blink.cmp.Component
local function render_item(ctx) end

require("blink.cmp").setup({
	highlight = {
		use_nvim_cmp_as_default = true,
	},
	nerd_font_variant = "mono",
	accept = {
		auto_brackets = {
			enabled = true,
			override_brackets_for_filetypes = {
				tex = { "{", "}" },
			},
		},
	},
	trigger = {
		keyword_range = "full",
		signature_help = { enabled = true },
	},
	keymap = {
		preset = "enter",
		["<Tab>"] = {
			function(cmp)
				if cmp.is_in_snippet() then
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
	sources = {
		completion = {
			enabled_providers = { "lsp", "path", "snippets", "buffer", "lazydev" },
		},
		providers = {
			lsp = { fallback_for = { "lazydev" } },
			lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
		},
	},
	windows = {
		autocomplete = {
			min_width = 20,
			max_width = 60,
			max_height = 10,
			border = "rounded",
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
			scrolloff = 2,
			direction_priority = { "s", "n" },
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
						highlight = function(ctx)
							return "BlinkCmpLabel"
						end,
					},
				},
			},
			selection = "auto_insert",
		},
		documentation = {
			min_width = 10,
			max_width = math.min(80, vim.o.columns),
			max_height = 20,
			border = "rounded",
			winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
			direction_priority = {
				autocomplete_north = { "e", "w", "n", "s" },
				autocomplete_south = { "e", "w", "s", "n" },
			},
			auto_show = true,
			auto_show_delay_ms = 100,
			update_delay_ms = 10,
		},
		signature_help = {
			min_width = 1,
			max_width = 100,
			max_height = 10,
			border = "rounded",
			winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
		},
	},
	kind_icons = {
		Snippet = "",
	},
})

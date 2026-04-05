local default_sources = { "lsp", "path", "calc", "snippets", "buffer", "lazydev", "emoji" }
local debug_sources = vim.list_extend(vim.deepcopy(default_sources), { "dap" })

local function patch_external_cmdline_positioning()
	local menu = require("blink.cmp.completion.windows.menu")
	local menu_config = require("blink.cmp.config").completion.menu
	local win = require("blink.cmp.lib.window")
	local original_get_cursor_screen_position = win.get_cursor_screen_position

	win.get_cursor_screen_position = function()
		if vim.g.ui_cmdline_pos ~= nil then
			local screen_height = vim.o.lines
			local screen_width = vim.o.columns
			local cmdline_position = menu_config.cmdline_position()

			return {
				distance_from_top = cmdline_position[1],
				distance_from_bottom = screen_height - cmdline_position[1] - 1,
				distance_from_left = cmdline_position[2],
				distance_from_right = screen_width - cmdline_position[2],
			}
		end

		return original_get_cursor_screen_position()
	end

	function menu.update_position()
		local context = menu.context
		if context == nil then
			return
		end

		local window = menu.win
		if not window:is_open() then
			return
		end

		window:update_size()

		local border_size = window:get_border_size()
		local pos = window:get_vertical_direction_and_height(menu_config.direction_priority, menu_config.max_height)
		if not pos then
			window:close()
			return
		end

		local alignment_start_col = menu.renderer:get_alignment_start_col()
		local row = pos.direction == "s" and 1 or -pos.height - border_size.vertical

		if vim.api.nvim_get_mode().mode == "c" or vim.g.ui_cmdline_pos ~= nil then
			local cmdline_position = menu_config.cmdline_position()
			window:set_win_config({
				relative = "editor",
				row = cmdline_position[1] + row,
				col = math.max(cmdline_position[2] + context.bounds.start_col - alignment_start_col, 0),
			})
		else
			local cursor_row, cursor_col = unpack(context.get_cursor())
			local virt_cursor_col = vim.fn.virtcol({ cursor_row, cursor_col })
			local col = vim.fn.virtcol({ cursor_row, context.bounds.start_col - 1 })
				- alignment_start_col
				- virt_cursor_col
				- border_size.left

			if menu_config.draw.align_to == "cursor" then
				col = 0
			end

			window:set_win_config({ relative = "cursor", row = row, col = col })
		end

		window:set_height(pos.height)
		menu.position_update_emitter:emit()
	end
end

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
			cmdline_position = function()
				if vim.g.ui_cmdline_pos ~= nil then
					local pos = vim.g.ui_cmdline_pos
					return { pos[1] - 1, pos[2] }
				end
				local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
				return { vim.o.lines - height, 0 }
			end,
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

patch_external_cmdline_positioning()

Snacks_picker_hist = {}

local keymaps_config = {
	format = function(item, picker)
		local ret = {} ---@type snacks.picker.Highlight[]
		---@type vim.api.keyset.get_keymap
		local k = item.item
		local a = Snacks.picker.util.align
		local lhs

		if item.item.type == "unmapped" then
			lhs = ""
		elseif item.type == "keymap" then
			lhs = Snacks.util.normkey(k.lhs)
		end

		ret[#ret + 1] = { a(k.mode, 1), "SnacksPickerKeymapMode" }
		ret[#ret + 1] = { " │ " }
		ret[#ret + 1] = { a(lhs, 15), "SnacksPickerKeymapLhs" }
		ret[#ret + 1] = { " " }

		if k.buffer and k.buffer > 0 then
			ret[#ret + 1] = { a("buf:" .. k.buffer, 6), "SnacksPickerBufNr" }
		else
			ret[#ret + 1] = { a("", 6) }
		end
		ret[#ret + 1] = { " │ " }
		ret[#ret + 1] = { a(k.desc or "", 20) }

		return ret
	end,
	preview = false,
	global = true,
	plugs = false,
	["local"] = true,
	modes = { "n", "v", "x", "s", "o", "i", "c", "t" },
	---@param picker snacks.Picker
	confirm = function(picker, item)
		picker:norm(function()
			if item then
				picker:close()
				if item.type == "keymap" then
					vim.api.nvim_input(item.item.lhs)
				elseif item.item.type == "unmapped" then
					item.item.callback()
				end
			end
		end)
	end,
	actions = {
		toggle_global = function(picker)
			picker.opts.global = not picker.opts.global
			picker:find()
		end,
		toggle_buffer = function(picker)
			picker.opts["local"] = not picker.opts["local"]
			picker:find()
		end,
	},
	win = {
		input = {
			keys = {
				["<a-g>"] = { "toggle_global", mode = { "n", "i" }, desc = "Toggle Global Keymaps" },
				["<a-b>"] = { "toggle_buffer", mode = { "n", "i" }, desc = "Toggle Buffer Keymaps" },
			},
		},
	},
}

require("snacks").setup({
	dashboard = { enabled = false },
	quickfile = { enabled = false },
	scroll = { enabled = false },
	scope = { enabled = false },

	bigfile = { enabled = true },
	notifier = { enabled = true, timeout = 3000 },
	words = {
		enabled = true,
		debounce = 30,
	},
	indent = {
		enabled = true,
		only_scope = true,
		animate = {
			enabled = false,
		},
	},
	input = { enabled = true },
	picker = {
		enabled = true,
		actions = require("trouble.sources.snacks").actions,
		formatters = {
			file = {
				filename_first = true,
			},
		},
		previewers = {
			git = {
				native = true,
			},
			diff = {
				native = true,
			},
		},
		win = {
			input = {
				keys = {
					["<c-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
					["<c-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
					["<c-f>"] = { "list_scroll_down", mode = { "i", "n" } },
					["<c-b>"] = { "list_scroll_up", mode = { "i", "n" } },
					["<c-t>"] = { "trouble_open", mode = { "i", "n" } },
				},
			},
		},
		layout = {
			reverse = true,
			layout = {
				box = "horizontal",
				backdrop = {
					blend = 40,
				},
				width = 0.8,
				height = 0.9,
				border = "none",
				{
					box = "vertical",
					{ win = "list", title = " Results ", title_pos = "center", border = "rounded" },
					{
						win = "input",
						height = 1,
						border = "rounded",
						title = "{title} {live} {flags}",
						title_pos = "center",
					},
				},
				{
					win = "preview",
					title = "{preview:Preview}",
					width = 0.6,
					border = "rounded",
					title_pos = "center",
				},
			},
		},
		sources = {
			select = {
				layout = {
					preset = "select",
					layout = {
						width = 0.5,
						min_height = 12,
						min_width = 70,
					},
				},
			},
			keymaps = {
				format = keymaps_config.format,
				confirm = keymaps_config.confirm,
				finder = function(opts, ctx)
					local items = require("snacks.picker.source.vim").keymaps(keymaps_config)

					for _, item in ipairs(items) do
						item.type = "keymap"
					end

					for _, item in ipairs(require("user.functions").functions) do
						table.insert(items, {
							text = item.description,
							item = item,
						})
					end

					return items
				end,
				layout = {
					preset = "select",
					preview = false,
					layout = {
						width = 0.5,
						min_height = 12,
						min_width = 120,
						max_height = 40,
					},
				},
			},
			gh_actions = {
				layout = {
					preset = "select",
					preview = false,
					layout = {
						height = 25,
					},
				},
			},
		},
		on_close = function(picker)
			if picker.opts.source ~= "history_picker" then
				picker.opts.pattern = picker.finder.filter.pattern
				picker.opts.search = picker.finder.filter.search
				local opts = picker.opts
				if #Snacks_picker_hist >= 20 then
					table.remove(Snacks_picker_hist, 20)
				end
				table.insert(Snacks_picker_hist, 1, opts)
			end
		end,
	},
	rename = { enabled = true },
	statuscolumn = { enabled = true },
	debug = { enabled = true },
	git = { enabled = true },
	gh = { enabled = true },
})

Snacks.indent.enable()
_G.dd = function(...)
	require("snacks").debug.inspect(...)
end
_G.bt = function()
	require("snacks").debug.backtrace()
end
vim.print = _G.dd

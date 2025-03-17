Snacks_picker_hist = {}

require("snacks").setup({
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
	input = {
		enabled = true,
	},
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
	quickfile = {
		enabled = true,
		exclude = { "latex" },
	},
	git = { enabled = true },
})

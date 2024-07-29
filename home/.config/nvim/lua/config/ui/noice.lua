require("noice").setup(
	---@module 'noice'
	{
		smart_move = {
			enabled = true,
		},
		views = {
			split = {
				win_options = {
					winhighlight = "Normal:Normal",
				},
			},
			mini = {
				win_options = {
					winblend = 0,
				},
			},
			cmdline_popup = {
				position = {
					row = "35%",
					col = "50%",
				},
				size = {
					width = "auto",
					height = "auto",
				},
			},
		},
		cmdline = {
			view = "cmdline_popup",
			format = {
				search_down = {
					view = "cmdline",
				},
				search_up = {
					view = "cmdline",
				},
			},
		},
		messages = {
			enabled = true, -- enables the Noice messages UI
			view = "notify", -- default view for messages
			view_error = "notify", -- view for errors
			view_warn = "notify", -- view for warnings
			view_history = "messages", -- view for :messages
			view_search = "virtualtext", -- view for search count messages. Set to `false` to disable
		},
		notify = {
			enabled = true,
		},
		lsp = {
			progress = {
				enabled = false,
			},
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = false,
			},
			signature = {
				enabled = false,
			},
		},
		popupmenu = {
			backend = "cmp", -- backend to use to show regular cmdline completions
		},
		presets = {
			bottom_search = true, -- use a classic bottom cmdline for search
			command_palette = true, -- position the cmdline and popupmenu together
			long_message_to_split = true, -- long messages will be sent to a split
			inc_rename = true, -- enables an input dialog for inc-rename.nvim
		},
	}
)

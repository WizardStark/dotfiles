---@diagnostic disable: missing-fields
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
			signature = {
				enabled = false,
			},
			hover = {
				enabled = false,
			},
		},
		presets = {
			bottom_search = false, -- use a classic bottom cmdline for search
			command_palette = true, -- position the cmdline and popupmenu together
			long_message_to_split = true, -- long messages will be sent to a split
		},
	}
)

require("smart-splits").setup(
	---@module 'smart-splits'
	{
		at_edge = "stop",
		resize_mode = {
			hooks = {
				on_leave = require("bufresize"),
			},
		},
		ignore_events = {
			"WinResized",
			"BufWinEnter",
			"BufEnter",
			"WinEnter",
		},
	}
)

require("bufresize").setup(
	---@module 'bufresize'
	{
		register = {
			trigger_events = { "BufWinEnter", "WinEnter" },
			keys = {},
		},
		resize = {
			trigger_events = {
				"VimResized",
			},
			increment = 1,
		},
	}
)

require("copilot").setup({
	suggestion = {
		auto_trigger = true,
		hide_during_completion = false,
		keymap = {
			accept = false,
			accept_word = false,
			accept_line = false,
			next = false,
			prev = false,
			dismiss = false,
		},
	},
	server_opts_overrides = {
		settings = {
			telemetry = {
				telemetryLevel = "off",
			},
		},
	},
})

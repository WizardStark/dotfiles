local nui = require("nui-components")

local renderer = nui.create_renderer({
	width = 60,
	height = 1,
})

local session_name = nui.create_signal({ value = "" })
local session_dir = nui.create_signal({ value = "" })

local body = nui.form(
	{
		id = "form",
		submit_key = "<CR>",
		on_submit = function()
			print(session_name.value:get_value())
			print(session_dir.value:get_value())
			renderer:close()
		end,
	},
	nui.paragraph({
		lines = "Create session",
		align = "center",
	}),
	nui.text_input({
		border_label = "Session name",
		id = "session_name",
		autofocus = true,
		flex = 1,
		max_lines = 1,
		value = session_name.value,
		on_change = function(value, _)
			session_name.value = value
		end,
	}),
	nui.text_input({
		border_label = "Session directory",
		id = "session_directory",
		autofocus = false,
		flex = 1,
		max_lines = 1,
		value = session_dir.value,
		on_change = function(value, _)
			session_dir.value = value
		end,
	})
)

renderer:render(body)

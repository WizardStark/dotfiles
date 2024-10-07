require("markview.extras.checkboxes").setup({
	remove_markers = true,
	exit = true,
	default_marker = "-",
	default_state = " ",
	states = {
		{ " ", "x", "/", "~" },
	},
})

require("markview.extras.editor").setup({
	---@type [ number, number ]
	width = { 50, 0.75 },

	---@type [ number, number ]
	height = { 5, 0.75 },

	---@type integer
	debounce = 50,

	---@type fun(buf:integer, win:integer): nil
	callback = function(buf, win) end,
})

require("markview").setup({
	latex = {
		enable = true,
		brackets = {
			enable = true,
			hl = "@punctuation.brackets",
		},
		block = {
			enable = true,
			hl = "Code",
			text = { " LaTeX ", "Special" },
		},
		inline = {
			enable = true,
		},
		operators = {
			enable = true,
			configs = {
				sin = {
					operator = {
						conceal = "",
						virt_text = { { "𝚜𝚒𝚗", "Special" } },
					},
					args = {
						{
							before = {},
							after = {},
							scope = {},
						},
					},
				},
			},
		},

		symbols = {
			enable = true,
			hl = "@operator.latex",
			overwrite = {
				today = function(buffer)
					return os.date("%d %B, %Y")
				end,
			},
			groups = {
				{
					match = { "lim", "today" },
					hl = "Special",
				},
			},
		},
		subscript = {
			enable = true,
			hl = "MarkviewLatexSubscript",
		},
		superscript = {
			enable = true,
			hl = "MarkviewLatexSuperscript",
		},
	},
})

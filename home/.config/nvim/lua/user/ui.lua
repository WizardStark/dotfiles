local catppuccin_opts = {
	integrations = {
		flash = true,
		gitsigns = true,
		mason = true,
		neotest = true,
		noice = true,
		blink_cmp = true,
		dap = true,
		dap_ui = true,
		diffview = true,
		treesitter = true,
		ufo = true,
		overseer = true,
		lsp_trouble = true,
	},
}

local signs = {
	DiagnosticSignError = "󰅚 ",
	DiagnosticSignWarn = "󰀪 ",
	DiagnosticSignHint = "󰌶 ",
	DiagnosticSignInfo = " ",
	DapBreakpoint = "",
	DapBreakpointCondition = "",
	DapBreakpointRejected = "",
	DapLogPoint = ".>",
	DapStopped = "󰁕",
}

for type, icon in pairs(signs) do
	vim.fn.sign_define(type, { text = icon, texthl = type, numhl = type })
end

local presets = {
	bush = {
		color_overrides = {
			all = {
				rosewater = "#ffc0b9",
				flamingo = "#f5aba3",
				pink = "#f592d6",
				mauve = "#d6a0ff",
				red = "#ea746c",
				maroon = "#ff8595",
				peach = "#fa9a6d",
				yellow = "#ffe499",
				green = "#99d783",
				teal = "#47deb4",
				sky = "#7daea3",
				sapphire = "#3db8ff",
				blue = "#78bbf2",
				lavender = "#9bd1e5",
				text = "#cccccc",
				subtext1 = "#bbbbbb",
				subtext0 = "#aaaaaa",
				overlay2 = "#999999",
				overlay1 = "#888888",
				overlay0 = "#777777",
				surface2 = "#666666",
				surface1 = "#555555",
				surface0 = "#444444",
				base = "#1a1a1a",
				mantle = "#1a1a1a",
				crust = "#333333",
			},
		},
		highlight_overrides = {
			all = function(colors)
				return {
					FloatBorder = { bg = colors.mantle, fg = colors.surface0 },
				}
			end,
		},
	},
	stark = {
		color_overrides = {
			all = {
				blue = "#89b4fa",
				flamingo = "#f2cdcd",
				green = "#a6e3a1",
				lavender = "#a3aded",
				maroon = "#eba0ac",
				mauve = "#ab84d5",
				overlay0 = "#6c7086",
				overlay1 = "#7f849c",
				overlay2 = "#9399b2",
				peach = "#fab387",
				pink = "#f5c2e7",
				red = "#f38ba8",
				rosewater = "#f5e0dc",
				sapphire = "#74c7ec",
				sky = "#89dceb",
				subtext0 = "#a6adc8",
				subtext1 = "#bac2de",
				surface0 = "#313244",
				surface1 = "#45475a",
				surface2 = "#585b70",
				teal = "#94e2d5",
				text = "#dee7f5",
				yellow = "#f9e2af",
				base = "#0e0e1e",
				mantle = "#0e0e1e",
				crust = "#1e1e2e",
			},
		},
		highlight_overrides = {
			all = function(C)
				return {
					FloatBorder = { bg = C.mantle, fg = C.subtext0 },
					Function = { fg = C.blue },
				}
			end,
		},
	},
}

return {
	setup = function()
		for key, value in pairs(presets) do
			if vim.g[key] then
				catppuccin_opts = vim.tbl_deep_extend("force", catppuccin_opts, value)
			end
		end

		catppuccin_opts = vim.tbl_deep_extend("force", catppuccin_opts, vim.g.catppuccin_opts or {})
		require("catppuccin").setup(catppuccin_opts)
		vim.cmd("colorscheme " .. vim.g.colorscheme)

		if vim.g.workspaces_disabled or next(vim.fn.argv()) ~= nil then
			require("lualine")
		else
			vim.g.workspaces_loaded = true
			local is_floating_win = vim.api.nvim_win_get_config(0).relative ~= ""
			if is_floating_win then
				vim.cmd.wincmd({ args = { "w" }, count = 1 })
			end

			require("workspaces.persistence").load_workspaces()
			require("workspaces.workspaces").setup_lualine()
			vim.cmd.stopinsert()
		end
	end,
}

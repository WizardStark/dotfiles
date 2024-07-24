local catppuccin_opts = {
	integrations = {
		flash = true,
		gitsigns = true,
		mason = true,
		neotest = true,
		noice = true,
		cmp = true,
		dap = true,
		dap_ui = true,
		diffview = true,
		notify = true,
		treesitter = true,
		ufo = true,
		overseer = true,
		lsp_trouble = true,
	},
}

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
				green = "#92c48e",
				text = "#94e2d5",
				base = "#0e0e1e",
				mantle = "#181825",
				crust = "#1e1e2e",
			},
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

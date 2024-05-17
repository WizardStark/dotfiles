return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			local opts = {
				integrations = {
					aerial = true,
					flash = true,
					gitsigns = true,
					-- headlines = true,
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

			opts = vim.tbl_deep_extend("force", opts, vim.g.catppuccin_opts or {})
			require("catppuccin").setup(opts)
			vim.cmd("colorscheme " .. vim.g.colorscheme)
		end,
	},
}

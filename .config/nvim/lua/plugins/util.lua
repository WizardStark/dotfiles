return {
	--indent blankline
	{
		"lukas-reineke/indent-blankline.nvim",
		event = "VeryLazy",
		main = "ibl",
		opts = {
			indent = {
				char = "│",
			},
			scope = {
				show_start = false,
				show_end = false,
			},
		},
	},
	-- surround
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		opts = {},
	},
	-- undotree
	{
		"mbbill/undotree",
		event = "VeryLazy",
	},
	--toggle booleans
	{
		"rmagatti/alternate-toggler",
		event = "VeryLazy",
		opts = {},
	},
	--overseer tasks
	{
		"Zeioth/compiler.nvim",
		cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = { "stevearc/overseer.nvim" },
		opts = {},
	},
	--overseer
	{
		"stevearc/overseer.nvim",
		cmd = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		opts = {
			task_list = {
				direction = "bottom",
				min_height = 25,
				max_height = 25,
				default_detail = 1,
			},
		},
	},
	--snippet creation
	{
		"chrisgrieser/nvim-scissors",
		cmd = { "ScissorsEditSnippet", "ScissorsAddNewSnippet" },
		dependencies = "nvim-telescope/telescope.nvim",
		opts = {},
	},
	--open links
	{

		"chrishrb/gx.nvim",
		cmd = { "Browse" },
		dependencies = { "nvim-lua/plenary.nvim" },
		init = function()
			vim.g.netrw_nogx = 1
		end,
		config = function()
			local app
			if vim.fn.has("mac") then
				app = "open"
			elseif vim.fn.has("wsl") then
				app = "wslview"
			else
				app = "xdg-open"
			end
			require("gx").setup({
				open_browser_app = app,
			})
		end,
	},
	--notes
	{

		"dhananjaylatkar/notes.nvim",
		cmd = { "NotesNew", "NotesFind", "NotesGrep" },
		dependencies = { "nvim-telescope/telescope.nvim" },
		opts = {
			root = vim.fn.expand("$HOME/notes/"),
		},
	},
	--legendary
	{
		"mrjones2014/legendary.nvim",
		priority = 10000,
		lazy = false,
		config = function()
			require("legendary").setup({
				select_prompt = " Command palette",
				sort = {
					frecency = false,
				},
			})
		end,
	},
	--flatten.nvim
	{
		"willothy/flatten.nvim",
		lazy = false,
		priority = 1001,
		opts = function()
			local saved_terminal

			return {
				window = {
					open = "alternate",
				},
				nest_if_no_args = true,
				callbacks = {
					should_block = function(argv)
						return vim.tbl_contains(argv, "-b")
					end,
					pre_open = function()
						local term = require("toggleterm.terminal")
						local termid = term.get_focused_id()
						saved_terminal = term.get(termid)
					end,
					post_open = function(bufnr, winnr, ft, is_blocking)
						if is_blocking and saved_terminal then
							saved_terminal:close()
						else
							vim.api.nvim_set_current_win(winnr)
						end
					end,
					block_end = function()
						vim.schedule(function()
							if saved_terminal then
								saved_terminal:open()
								saved_terminal = nil
							end
						end)
					end,
				},
			}
		end,
	},
	--paren-hint
	{
		"briangwaltney/paren-hint.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {},
	},
	--substitution
	{
		"gbprod/substitute.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--better macros
	{
		"chrisgrieser/nvim-recorder",
		event = "VeryLazy",
		dependencies = "rcarriga/nvim-notify",
		opts = {
			slots = { "a", "r", "s", "m", "n", "e" },
		},
	},
	--highlight symbol
	{
		"rrethy/vim-illuminate",
		event = "VeryLazy",
		config = function()
			require("illuminate").configure({
				delay = 20,
				large_file_cutoff = 10000,
				min_count_to_highlight = 2,
				filetypes_denylist = {
					"minifiles",
				},
			})
		end,
	},
	--local
	{
		dir = "~/.config/lcl",
		priority = 2000,
		enabled = function()
			local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/lua/init.lua"))
			return ok
		end,
		config = function()
			require("legendary").commands({
				{
					":Lazy reload lcl",
					description = "Reload local plugin",
				},
			})
			if vim.g.colorscheme == "catppuccin-mocha" then
				require("catppuccin").setup({
					color_overrides = vim.g.color_overrides,
				})
			end
			vim.cmd("colorscheme " .. vim.g.colorscheme)
		end,
	},
}

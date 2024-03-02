return {
	--sessions
	{
		"Shatur/neovim-session-manager",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local config = require("session_manager.config")
			require("session_manager").setup({
				autoload_mode = config.AutoloadMode.Disabled,
				autosave_last_session = false,
			})
		end,
	},
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
		version = "*", -- Use for stability; omit to use `main` branch for the latest features
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
	--overseer
	{
		"stevearc/overseer.nvim",
		event = "VeryLazy",
		opts = {
			strategy = { "toggleterm" },
			templates = { "builtin", "user.py_run", "user.go_run" },
		},
	},
	--snippet creation
	{
		"chrisgrieser/nvim-scissors",
		cmd = { "ScissorsEditSnippet", "ScissorsAddNewSnippet" },
		dependencies = "nvim-telescope/telescope.nvim", -- optional
		opts = {},
	},
	--open links
	{

		"chrishrb/gx.nvim",
		cmd = { "Browse" },
		dependencies = { "nvim-lua/plenary.nvim" },
		config = true,
		init = function()
			vim.g.netrw_nogx = 1
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
                log_level = 'debug'
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
        opts = {}
    },
	--local
	{
		dir = "~/.config/lcl",
		event = "VeryLazy",
		enabled = function()
			local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/init.lua"))
			return ok
		end,
		config = function()
			require("legendary").commands({
				{
					":Lazy reload lcl",
					description = "Reload local plugin",
				},
			})
		end,
	},
}

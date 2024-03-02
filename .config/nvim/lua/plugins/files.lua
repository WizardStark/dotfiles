return {
	--Telescope
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.3",
		event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"junegunn/fzf.vim",
			"nvim-tree/nvim-web-devicons",
			"debugloop/telescope-undo.nvim",
			"rcarriga/nvim-notify",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
			},
			{
				"nvim-telescope/telescope-live-grep-args.nvim",
				version = "^1.0.0",
			},
			{
				"agoodshort/telescope-git-submodules.nvim",
				dependencies = "akinsho/toggleterm.nvim",
			},
		},
		config = function()
			require("telescope").setup({
				defaults = {
					layout_strategy = "horizontal",
					layout_config = {
						horizontal = { width = 0.85, preview_width = 0.6 },
					},
					dynamic_preview_title = true,
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--hidden",
					},
				},
				extensions = {
					fzf = {
						fuzzy = true,
						override_generic_sorter = true,
						override_file_sorter = true,
						case_mode = "smart_case",
					},
					undo = {},
				},
				pickers = {
					find_files = {
						follow = true,
					},
				},
			})

			require("telescope").load_extension("fzf")
			require("telescope").load_extension("live_grep_args")
			require("telescope").load_extension("undo")
			require("telescope").load_extension("notify")
			require("telescope").load_extension("git_submodules")
		end,
	},
	{
		"LukasPietzschmann/telescope-tabs",
		dependencies = { "nvim-telescope/telescope.nvim" },
		config = function()
			require("telescope").load_extension("telescope-tabs")
			require("telescope-tabs").setup({})
		end,
	},
	--mini.files
	{
		"echasnovski/mini.files",
		event = "VeryLazy",
		version = false,
		opts = {
			mappings = {
				go_out = "H",
				go_out_plus = "",
				synchronize = "s",
			},
			windows = {
				max_number = 3,
				preview = true,
				width_nofocus = 30,
				width_focus = 50,
				width_preview = 75,
			},
		},
	},
	--harpoon
	{
		"ThePrimeagen/harpoon",
		event = "VeryLazy",
		opts = {
			global_settings = {
				mark_branch = true,
			},
		},
	},
}

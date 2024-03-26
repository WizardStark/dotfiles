return {
	--Telescope
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.3",
		lazy = true,
		cmd = { "Telescope" },
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
					mappings = {
						i = { ["<C-t>"] = require("trouble.providers.telescope").open_with_trouble },
						n = { ["<C-t>"] = require("trouble.providers.telescope").open_with_trouble },
					},
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
					cache_picker = { num_pickers = 15 },
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
					git_commits = {
						mappings = {
							i = {
								["<M-d>"] = function()
									local selected_entry = require("telescope.actions.state").get_selected_entry()
									local value = selected_entry.value
									vim.api.nvim_win_close(0, true)
									vim.cmd("stopinsert")
									vim.schedule(function()
										vim.cmd(("DiffviewOpen %s^!"):format(value))
									end)
								end,
							},
						},
					},
					git_bcommits = {
						mappings = {
							i = {
								["<M-d>"] = function()
									local selected_entry = require("telescope.actions.state").get_selected_entry()
									local value = selected_entry.value
									vim.api.nvim_win_close(0, true)
									vim.cmd("stopinsert")
									vim.schedule(function()
										vim.cmd(("DiffviewOpen %s^!"):format(value))
									end)
								end,
							},
						},
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
	--mini.files
	{
		"echasnovski/mini.files",
		lazy = true,
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
	--grapple
	{
		"cbochs/grapple.nvim",
		lazy = true,
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			scope = "git_branch",
			win_opts = {
				border = "rounded",
			},
		},
	},
}

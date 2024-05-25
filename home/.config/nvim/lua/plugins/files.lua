return {
	--Telescope
	{
		"nvim-telescope/telescope.nvim",
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
					file_ignore_patterns = {
						"^bin/",
						"/bin/",
						"^.git/",
						"/.git/",
					},
					cache_picker = { num_pickers = 15 },
					path_display = {
						filename_first = {
							reverse_directories = false,
						},
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
						hidden = true,
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
			require("telescope").load_extension("yaml_schema")
		end,
	},
	{
		"axkirillov/easypick.nvim",
		cmd = { "Easypick" },
		lazy = true,
		dependencies = { "nvim-telescope/telescope.nvim" },
		config = function()
			local easypick = require("easypick")

			local get_default_branch = "git rev-parse --symbolic-full-name refs/remotes/origin/HEAD | sed 's!.*/!!'"
			local base_branch = vim.fn.system(get_default_branch) or "main"

			easypick.setup({
				pickers = {
					{
						name = "ls",
						command = "ls",
						previewer = easypick.previewers.default(),
					},
					{
						name = "changed_files",
						command = "git status -suall| awk '{print $2}'",
						previewer = easypick.previewers.file_diff(),
					},
					{
						name = "conflicts",
						command = "git diff --name-only --diff-filter=U --relative",
						previewer = easypick.previewers.file_diff(),
					},
				},
			})
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
	--zoxide integration
	{
		"thunder-coding/zincoxide",
		lazy = true,
		cmd = { "Z", "Zg", "Zt", "Zw" },
		opts = {
			zincoxide_cmd = "zoxide",
			complete = true,
			behaviour = "tabs",
		},
	},
}

require("telescope").setup({
	defaults = {
		mappings = {
			i = { ["<C-t>"] = require("trouble.sources.telescope").open },
			n = { ["<C-t>"] = require("trouble.sources.telescope").open },
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

require("easypick").setup({
	pickers = {
		{
			name = "ls",
			command = "ls",
			previewer = require("easypick").previewers.default(),
		},
		{
			name = "changed_files",
			command = "git status -suall| awk '{print $2}'",
			previewer = require("easypick").previewers.file_diff(),
		},
		{
			name = "conflicts",
			command = "git diff --name-only --diff-filter=U --relative",
			previewer = require("easypick").previewers.file_diff(),
		},
	},
})

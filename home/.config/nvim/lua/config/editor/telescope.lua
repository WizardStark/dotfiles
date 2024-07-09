local focus_preview = function(prompt_bufnr)
	local action_state = require("telescope.actions.state")
	local actions = require("telescope.actions")
	local picker = action_state.get_current_picker(prompt_bufnr)
	local prompt_win = picker.prompt_win
	local previewer = picker.previewer
	local bufnr = previewer.state.bufnr or previewer.state.termopen_bufnr
	local winid = previewer.state.winid or vim.fn.bufwinid(bufnr)
	vim.keymap.set("n", "<Tab>", function()
		vim.cmd(string.format("noautocmd lua vim.api.nvim_set_current_win(%s)", prompt_win))
	end, { buffer = bufnr })
	vim.keymap.set("n", "<esc>", function()
		actions.close(prompt_bufnr)
	end, { buffer = bufnr })
	vim.cmd(string.format("noautocmd lua vim.api.nvim_set_current_win(%s)", winid))
end

require("telescope").setup({
	defaults = {
		mappings = {
			i = { ["<C-t>"] = require("trouble.sources.telescope").open },
			n = {
				["<C-t>"] = require("trouble.sources.telescope").open,
				["<Tab>"] = focus_preview,
			},
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
		set_env = {
			LESS = "",
			DELTA_PAGER = "less",
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
			previewer = require("telescope.previewers").new_termopen_previewer({
				get_command = function(entry)
					return {
						"git",
						"-c",
						"core.pager=delta",
						"-c",
						"delta.side-by-side=false",
						"diff",
						entry.value,
					}
				end,
			}),
		},
		{
			name = "conflicts",
			command = "git diff --name-only --diff-filter=U --relative",
			previewer = require("telescope.previewers").new_termopen_previewer({
				get_command = function(entry)
					return {
						"git",
						"-c",
						"core.pager=delta",
						"-c",
						"delta.side-by-side=false",
						"diff",
						entry.value,
					}
				end,
			}),
		},
	},
})

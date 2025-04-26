---@type avante.Config
---@diagnostic disable: missing-fields
local opts = {
	provider = "ollama",
	auto_suggestions_provider = "ollama",
	ollama = {
		model = vim.g.ollama_model,
	},
	behaviour = {
		-- auto_suggestions = true,
		enable_cursor_planning_mode = true,
		auto_set_keymaps = false,
		use_cwd_as_project_root = true,
	},
	mappings = {
		ask = "<leader>ia",
		edit = "<leader>ie",
		refresh = "<leader>ir",
	},
	windows = {
		ask = {
			start_insert = false,
		},
	},
}

if opts.ollama.model ~= nil then
	require("avante").setup(opts)
else
	vim.notify("No ollama model set, aborting Avante setup. Please set vim.g.ollama_model")
end

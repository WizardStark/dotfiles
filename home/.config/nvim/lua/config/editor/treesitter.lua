local ensureInstalled = { "lua", "python" }
local alreadyInstalled = require("nvim-treesitter.config").get_installed()
local parsersToInstall = vim.iter(ensureInstalled)
	:filter(function(parser)
		return not vim.tbl_contains(alreadyInstalled, parser)
	end)
	:totable()

vim.defer_fn(function()
	require("nvim-treesitter").install(parsersToInstall)
end, 1000)

require("nvim-treesitter-textobjects").setup({
	select = {
		lookahead = true,
		selection_modes = {
			["@function.outer"] = "V",
			["@function.inner"] = "V",
			["@class.outer"] = "V",
			["@class.inner"] = "V",
			["@parameter.outer"] = "v",
		},
		include_surrounding_whitespace = false,
	},
})

require("dressing").setup({
	select = {
		get_config = function(opts)
			if opts.kind == "legendary.nvim" then
				return {
					backend = "telescope",
					telescope = require("telescope.themes").get_ivy({}),
				}
			end
		end,
	},
	input = {
		get_config = function(opts)
			if opts.kind == "tabline" then
				return {
					relative = "win",
				}
			end
		end,
	},
})

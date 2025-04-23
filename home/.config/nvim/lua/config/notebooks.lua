vim.g.molten_output_win_max_height = 40
-- vim.g.molten_auto_open_output = false
vim.g.molten_wrap_output = true
vim.g.molten_virt_text_output = true
vim.g.molten_virt_lines_off_by_1 = true
vim.api.nvim_set_hl(0, "MoltenCell", { bg = "NONE" })

require("jupytext").setup({
	style = "markdown",
	output_extension = "md",
	force_ft = "markdown",
})

-- require("quarto").setup({
-- 	debug = true,
-- 	codeRunner = {
-- 		enabled = true,
-- 		default_method = "molten",
-- 	},
-- })

-- require("otter").setup({
-- 	debug = true,
-- 	verbose = {
-- 		no_code_found = false,
-- 	},
-- })

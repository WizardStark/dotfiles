local M = {}

M.prefixes = {
	-- Merge everything with Misc?
	code_u = "Code utils",
	debugging = "Debugging", -- Merge with Diagnostics?
	diag = "Diagnostics",
	git = "Git",
	lsp = "LSP", -- Merge with Diagnostics?
	misc = "Misc",
	move = "Movement",
	nav = "Navigation",
	notes = "Notes",
	run = "Run",
	term = "Terminal",
}

function M.get_visual_selection_lines()
	return { vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2] }
end

function M.prefix_description(prefix, description) end

return M
--  │
--general
--ufo - Code util
--Legendary - Misc
--Telescope - Navigation
--git - Git
--harpoon - Navigation
--smart splits - Windows
--mini.files - Navigation
--aerial - Navigation
--diagnostics quicklist - Diagnostics
--comment keybinds - Code utils
--toggle booleans - Code utils
--debugging - Debugging
--overseer - Run
--URL handling - External
--conform - Code Util
--latex - Misc
--LSP - LSP
--session management - Instances
--flash - Movement
--Mason - LSP
--Notes - Notes
--Terminal - Terminal

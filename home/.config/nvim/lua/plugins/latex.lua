return {
	{
		"lervag/vimtex",
		ft = { "markdown", "tex" },
		init = function()
			vim.g.vimtex_syntax_enabled = 1
			vim.g.vimtex_compiler_latexmk = {
				build_dir = function()
					return vim.fn["vimtex#util#find_root"]()
				end,
				callback = 1,
				continuous = 1,
				executable = "latexmk",
				hooks = {},
				options = {
					"-xelatex",
					"-shell-escape",
					"-verbose",
					"-file-line-error",
					"-synctex=1",
					"-interaction=nonstopmode",
				},
			}
			vim.g.vimtex_view_method = "zathura"
			vim.g.vimtex_quickfix_enabled = 0
		end,
	},
}

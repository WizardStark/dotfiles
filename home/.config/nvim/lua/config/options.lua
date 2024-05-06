vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

local opts = {
	foldcolumn = "0",
	foldlevel = 99,
	foldlevelstart = 99,
	foldenable = true,
	termguicolors = true,
	showmatch = true,
	incsearch = true,
	hlsearch = false,
	tabstop = 4,
	expandtab = true,
	shiftwidth = 4,
	autoindent = true,
	number = true,
	relativenumber = true,
	wildmode = "longest,list",
	cursorline = true,
	ttyfast = true,
	laststatus = 2,
	pumheight = 10,
	signcolumn = "yes",
	updatetime = 100,
	fillchars = {
		vert = "│",
		eob = " ",
	},
	scrolloff = 8,
	undofile = true,
	showtabline = 1,
	undodir = { vim.fn.expand("~/.undo") },
	swapfile = false,
	sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions",
	grepprg = "rg --vimgrep",
	grepformat = "%f:%l:%c:%m",
	-- from TJ's config
	formatoptions = opt.formatoptions
		- "a" -- Auto formatting is BAD.
		- "t" -- Don't auto format my code. I got linters for that.
		+ "c" -- In general, I like it when comments respect textwidth
		+ "q" -- Allow formatting comments w/ gq
		- "o" -- O and o, don't continue comments
		+ "r" -- But do continue when pressing enter.
		+ "n" -- Indent past the formatlistpat, not underneath it.
		+ "j" -- Auto-remove comments if possible.
		- "2", -- I'm not in gradeschool anymore
}

require("lcl.options")
opts = vim.tbl_deep_extend("force", opts, vim.g.overridden_opts or {})

for key, value in pairs(opts) do
	vim.opt[key] = value
end

vim.g.colorscheme = "catppuccin-mocha"

return {}

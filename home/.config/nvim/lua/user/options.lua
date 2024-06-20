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
	inccommand = "split",
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
	laststatus = 3,
	splitkeep = "screen",
	pumheight = 10,
	cmdheight = 0,
	virtualedit = "block",
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
	scrollback = 100000,
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

return {
	setup = function()
		require("lcl.options")
		opts = vim.tbl_deep_extend("force", opts, vim.g.overridden_opts or {})
		for key, value in pairs(opts) do
			vim.opt[key] = value
		end
	end,
}

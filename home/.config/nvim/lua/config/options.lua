vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

opt.foldcolumn = "0"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.termguicolors = true
opt.showmatch = true
opt.incsearch = true
opt.hlsearch = false
opt.tabstop = 4
opt.expandtab = true
opt.shiftwidth = 4
opt.autoindent = true
opt.number = true
opt.relativenumber = true
opt.wildmode = "longest,list"
opt.cursorline = true
opt.ttyfast = true
opt.laststatus = 2
opt.pumheight = 10
opt.signcolumn = "yes"
opt.updatetime = 100
opt.fillchars = {
	vert = "│",
	eob = " ",
}
opt.scrolloff = 8
opt.undofile = true
opt.showtabline = 1
opt.undodir = { vim.fn.expand("~/.undo") }
opt.swapfile = false
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"

-- from TJ's config
opt.formatoptions = opt.formatoptions
	- "a" -- Auto formatting is BAD.
	- "t" -- Don't auto format my code. I got linters for that.
	+ "c" -- In general, I like it when comments respect textwidth
	+ "q" -- Allow formatting comments w/ gq
	- "o" -- O and o, don't continue comments
	+ "r" -- But do continue when pressing enter.
	+ "n" -- Indent past the formatlistpat, not underneath it.
	+ "j" -- Auto-remove comments if possible.
	- "2" -- I'm not in gradeschool anymore

vim.g.colorscheme = "catppuccin-mocha"

return {}

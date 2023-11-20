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
opt.pumheight = 20
opt.signcolumn = "yes"
opt.updatetime = 100
vim.opt.fillchars = { eob = " " }
opt.scrolloff = 8

vim.notify = require("notify")

--blank lines
opt.list = true
vim.opt.listchars = { leadmultispace = "│   ", multispace = "│ ", tab = "│ ", }

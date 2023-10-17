vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.blamer_enabled = true
vim.g.blamer_delay = 500

local opt = vim.opt

opt.foldcolumn = '0'
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.termguicolors = true
opt.showmatch = true
opt.hlsearch = true
opt.incsearch = true
opt.tabstop = 4
opt.expandtab = true
opt.shiftwidth = 4
opt.autoindent = true
opt.number = true
opt.relativenumber = true
opt.wildmode = 'longest,list'
opt.cursorline = true
opt.ttyfast = true
opt.clipboard = "unnamedplus"
opt.laststatus = 2
opt.statusline = ([[%{expand('%:p:h:t')}/%t/%{%v:lua.require'nvim-navic'.get_location()%}]])
opt.signcolumn = 'yes'
opt.updatetime = 100

vim.notify = require("notify")

set showmatch               " show matching set ignorecase
set hlsearch                " highlight search 
set incsearch               " incremental search
set tabstop=4               " number of columns occupied by a tab
set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindents
set autoindent              " indent a new line the same amount as the line just typed
set number relativenumber                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
filetype plugin indent on   "allow auto-indenting depending on file type
syntax on                   " syntax highlighting
set cursorline              " highlight current cursorline
set ttyfast                 " Speed up scrolling in Vim
set clipboard=unnamed   " using system clipboard
set laststatus=2 
set statusline=%{expand('%:~:h')}/
set statusline+=%{%v:lua.require'nvim-navic'.get_location()%}


let mapleader = " " " map leader to Space
nnoremap H gT
nnoremap L gt
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fm <cmd>Telescope marks<cr>
nnoremap <leader>fr <cmd>Telescope lsp_references<cr>
nnoremap <leader>fs <cmd>Telescope lsp_document_symbols<cr>
nnoremap <leader>fc <cmd>Telescope lsp_incoming_calls<cr>
nnoremap <leader>fo <cmd>Telescope lsp_outgoing_calls<cr>
nnoremap <leader>fi <cmd>Telescope lsp_implementations<cr>
nnoremap <leader>b <cmd>NvimTreeToggle<cr> 
nnoremap <leader>bf <cmd>NvimTreeFindFile<cr>

call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')


Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'EdenEast/nightfox.nvim'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-fugitive'
Plug 'cohama/lexima.vim'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/nvim-cmp'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'L3MON4D3/LuaSnip'
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-live-grep-args.nvim'
Plug 'mfussenegger/nvim-jdtls'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'SmiteshP/nvim-navic'
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/fzf.vim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build' }
Plug 'kevinhwang91/nvim-ufo'
Plug 'kevinhwang91/promise-async'
Plug 'nvim-tree/nvim-tree.lua'

call plug#end()

source $HOME/.config/nvim/lua/init.lua
source $HOME/.config/nvim/colours/nightfox.vim
autocmd BufWritePre * lua vim.lsp.buf.format()

--general
vim.keymap.set('n', 'H', 'gT')
vim.keymap.set('n', 'L', 'gt')

--ufo
vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
vim.keymap.set('n', 'zr', require('ufo').openFoldsExceptKinds)
vim.keymap.set('n', 'zm', require('ufo').closeFoldsWith) -- closeAllFolds == closeFoldsWith(0)
vim.keymap.set('n', 'K', require('ufo').peekFoldedLinesUnderCursor)

--Telescope
vim.keymap.set("n", "<leader>fg", require('telescope').extensions.live_grep_args.live_grep_args)
vim.keymap.set('n', '<leader>ff', require 'telescope.builtin'.find_files)
vim.keymap.set('n', '<leader>fb', require 'telescope.builtin'.buffers)
vim.keymap.set('n', '<leader>fm', require 'telescope.builtin'.marks)
vim.keymap.set('n', '<leader>fr', require 'telescope.builtin'.lsp_references)
vim.keymap.set('n', '<leader>fs', require 'telescope.builtin'.lsp_document_symbols)
vim.keymap.set('n', '<leader>fc', require 'telescope.builtin'.lsp_incoming_calls)
vim.keymap.set('n', '<leader>fo', require 'telescope.builtin'.lsp_outgoing_calls)
vim.keymap.set('n', '<leader>fi', require 'telescope.builtin'.lsp_implementations)

--nvim-tree
vim.keymap.set('n', '<leader>b', require 'nvim-tree.api'.tree.toggle)

--sessions
vim.api.nvim_set_keymap("n", "<leader>qs", [[<cmd>lua require("persistence").load()<cr>]], {})
vim.api.nvim_set_keymap("n", "<leader>ql", [[<cmd>lua require("persistence").load({ last = true })<cr>]], {})
vim.api.nvim_set_keymap("n", "<leader>qd", [[<cmd>lua require("persistence").stop()<cr>]], {})

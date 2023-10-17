--general
vim.keymap.set('n', 'H', 'gT', { desc = 'Previous Tab' })
vim.keymap.set('n', 'L', 'gt', { desc = 'Next Tab' })
vim.keymap.set('i', 'jf', '<esc>', { desc = 'Exit insert mode' })
vim.keymap.set('i', 'jk', '<right>', { desc = 'Move right one space' })

--ufo
vim.keymap.set('n', 'zR', require('ufo').openAllFolds, { desc = 'Open all folds' })
vim.keymap.set('n', 'zM', require('ufo').closeAllFolds, { desc = 'Close all folds' })
vim.keymap.set('n', 'zr', require('ufo').openFoldsExceptKinds, { desc = 'Open all non-excluded folds' })
vim.keymap.set('n', 'zm', require('ufo').closeFoldsWith, { desc = 'Close folds with' }) -- closeAllFolds == closeFoldsWith(0)
vim.keymap.set('n', 'K', require('ufo').peekFoldedLinesUnderCursor, { desc = 'Peek folded lines' })

--Telescope
vim.keymap.set("n", "<leader>fg", require('telescope').extensions.live_grep_args.live_grep_args, { desc = 'Live Grep' })
vim.keymap.set('n', '<leader>ff', require 'telescope.builtin'.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>b', require 'telescope.builtin'.buffers, { desc = 'Show buffers' })
vim.keymap.set('n', '<leader>fm', require 'telescope.builtin'.marks, { desc = 'Show marks' })
vim.keymap.set('n', '<leader>fr', require 'telescope.builtin'.lsp_references, { desc = 'Find symbol references' })
vim.keymap.set('n', '<leader>fs', require 'telescope.builtin'.lsp_document_symbols, { desc = 'Document symbols' })
vim.keymap.set('n', '<leader>fc', require 'telescope.builtin'.lsp_incoming_calls, { desc = 'Find incoming calls' })
vim.keymap.set('n', '<leader>fo', require 'telescope.builtin'.lsp_outgoing_calls, { desc = 'Find outgoing calls' })
vim.keymap.set('n', '<leader>fi', require 'telescope.builtin'.lsp_implementations,
    { desc = 'Find symbol implementations' })

--nvim-tree
vim.keymap.set('n', '<leader>e', function()
        require 'nvim-tree.api'.tree.toggle({
            find_file = true,
            focus = true,
            path = "<arg>",
            update_root = '<bang>'
        })
    end,
    { desc = 'Toggle file tree' })

--aerial
vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>")

--sessions
vim.keymap.set("n", "<leader>ql", require("persistence").load, { desc = 'Load session' })
vim.keymap.set("n", "<leader>qd", require("persistence").stop, { desc = 'Stop session persistence' })

--diagnostics quicklist
vim.keymap.set("n", "<leader>xx", function() require("trouble").toggle() end)
vim.keymap.set("n", "<leader>xw", function() require("trouble").toggle("workspace_diagnostics") end)
vim.keymap.set("n", "<leader>xd", function() require("trouble").toggle("document_diagnostics") end)
vim.keymap.set("n", "<leader>xq", function() require("trouble").toggle("quickfix") end)
vim.keymap.set("n", "<leader>xl", function() require("trouble").toggle("loclist") end)
vim.keymap.set("n", "gR", function() require("trouble").toggle("lsp_references") end)

--jupyter notebooks (magma)
vim.keymap.set('n', '<leader>r', "<cmd>:MagmaEvaluateOperator<cr>")

--lazygit
vim.keymap.set('n', '<leader>gg', "<cmd>:LazyGit<cr>")

-- URL handling
-- source: https://sbulav.github.io/vim/neovim-opening-urls/
if vim.fn.has("mac") == 1 then
    vim.keymap.set("", "gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>', {})
elseif vim.fn.has("unix") == 1 then
    vim.keymap.set("", "gx", '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', {})
end

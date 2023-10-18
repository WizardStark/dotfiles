local map = vim.keymap.set

--general
map('n', 'H', 'gT', { desc = 'Previous Tab' })
map('n', 'L', 'gt', { desc = 'Next Tab' })
map('i', 'jf', '<esc>', { desc = 'Exit insert mode' })
map('i', 'jk', '<right>', { desc = 'Move right one space' })

--ufo
map('n', 'zR', require('ufo').openAllFolds, { desc = 'Open all folds' })
map('n', 'zM', require('ufo').closeAllFolds, { desc = 'Close all folds' })
map('n', 'zr', require('ufo').openFoldsExceptKinds, { desc = 'Open all non-excluded folds' })
map('n', 'zm', require('ufo').closeFoldsWith, { desc = 'Close folds with' }) -- closeAllFolds == closeFoldsWith(0)
map('n', 'K', require('ufo').peekFoldedLinesUnderCursor, { desc = 'Peek folded lines' })

--Telescope
map("n", "<leader>fg", require('telescope').extensions.live_grep_args.live_grep_args, { desc = 'Live Grep' })
map('n', '<leader>ff', require 'telescope.builtin'.find_files, { desc = 'Find files' })
map('n', '<leader>b', require 'telescope.builtin'.buffers, { desc = 'Show buffers' })
map('n', '<leader>fm', require 'telescope.builtin'.marks, { desc = 'Show marks' })
map('n', '<leader>fr', require 'telescope.builtin'.lsp_references, { desc = 'Find symbol references' })
map('n', '<leader>fs', require 'telescope.builtin'.lsp_document_symbols, { desc = 'Document symbols' })
map('n', '<leader>fc', require 'telescope.builtin'.lsp_incoming_calls, { desc = 'Find incoming calls' })
map('n', '<leader>fo', require 'telescope.builtin'.lsp_outgoing_calls, { desc = 'Find outgoing calls' })
map('n', '<leader>fi', require 'telescope.builtin'.lsp_implementations,
    { desc = 'Find symbol implementations' })

--harpoon
map("n", "<leader>ha", require('harpoon.mark').add_file, { desc = 'Add file to harpoon' })
map('n', '<leader>ht', require('harpoon.ui').toggle_quick_menu, { desc = 'Toggle harpoon ui' })
map('n', '<leader>hm', [[:Telescope harpoon marks<CR>]], { desc = 'Show harpoon marks in telescope' })
map("n", "<leader>hn", require('harpoon.ui').nav_next, { desc = 'Go to next harpoon file' })
map("n", "<leader>hp", require('harpoon.ui').nav_prev, { desc = 'Go to previous harpoon file' })


--nvim-tree
map('n', '<leader>e', function()
        require 'nvim-tree.api'.tree.toggle({
            find_file = true,
            focus = true,
            path = "<arg>",
            update_root = '<bang>'
        })
    end,
    { desc = 'Toggle file tree' })

--aerial
map("n", "<leader>a", "<cmd>AerialToggle!<CR>")

--sessions
map("n", "<leader>ql", require("persistence").load, { desc = 'Load session' })
map("n", "<leader>qd", require("persistence").stop, { desc = 'Stop session persistence' })

--diagnostics quicklist
map("n", "<leader>xx", function() require("trouble").toggle() end)
map("n", "<leader>xw", function() require("trouble").toggle("workspace_diagnostics") end)
map("n", "<leader>xd", function() require("trouble").toggle("document_diagnostics") end)
map("n", "<leader>xq", function() require("trouble").toggle("quickfix") end)
map("n", "<leader>xl", function() require("trouble").toggle("loclist") end)
map("n", "gR", function() require("trouble").toggle("lsp_references") end)

--jupyter notebooks (magma)
map('n', '<leader>r', "<cmd>:MagmaEvaluateOperator<cr>")

--lazygit
map('n', '<leader>gg', "<cmd>:LazyGit<cr>")

-- URL handling
-- source: https://sbulav.github.io/vim/neovim-opening-urls/
if vim.fn.has("mac") == 1 then
    map("", "gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>', {})
elseif vim.fn.has("unix") == 1 then
    map("", "gx", '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', {})
end

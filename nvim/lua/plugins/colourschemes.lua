return {
    {
        "bluz71/vim-nightfly-colors",
        name = "nightfly",
        lazy = false,
        priority = 1000,
        config = function()
            -- vim.cmd [[colorscheme nightfly]]
        end
    },
    {
        "bluz71/vim-moonfly-colors",
        name = "moonfly",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd [[colorscheme moonfly]]
        end
    },
}

return {
    -- lspconfig
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
    },

    --lsp servers
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
        build = ":MasonUpdate",
        dependencies = {
            {
                'SmiteshP/nvim-navic',
                config = function()
                    require('nvim-navic').setup {
                        icons = {
                            File          = "󰈙 ",
                            Module        = " ",
                            Namespace     = "󰌗 ",
                            Package       = " ",
                            Class         = "󰌗 ",
                            Method        = "󰆧 ",
                            Property      = " ",
                            Field         = " ",
                            Constructor   = " ",
                            Enum          = "󰕘",
                            Interface     = "󰕘",
                            Function      = "󰊕 ",
                            Variable      = "󰆧 ",
                            Constant      = "󰏿 ",
                            String        = "󰀬 ",
                            Number        = "󰎠 ",
                            Boolean       = "◩ ",
                            Array         = "󰅪 ",
                            Object        = "󰅩 ",
                            Key           = "󰌋 ",
                            Null          = "󰟢 ",
                            EnumMember    = " ",
                            Struct        = "󰌗 ",
                            Event         = " ",
                            Operator      = "󰆕 ",
                            TypeParameter = "󰊄 ",
                        },
                        lsp = {
                            auto_attach = false,
                            preference = nil,
                        },
                        highlight = false,
                        separator = " > ",
                        depth_limit = 10,
                        depth_limit_indicator = "..",
                        safe_output = true,
                        lazy_update_context = false,
                        click = false
                    }
                end
            },
            { 'mfussenegger/nvim-jdtls' }
        },
        config = function()
            require("mason").setup()
            require('mason-lspconfig').setup({
                ensure_installed = {
                    -- Replace these with whatever servers you want to install
                    'gopls',
                    'pyright',
                    'jdtls',
                    'jsonls',
                    'jqls',
                    'vimls',
                    'lua_ls'
                }
            })

            local lspconfig = require('lspconfig')
            local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()
            local navic = require("nvim-navic")

            local function lsp_keymap(bufnr)
                local bufopts = { noremap = true, silent = true, buffer = bufnr }
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
                vim.keymap.set('n', '<leader>K', vim.lsp.buf.signature_help, bufopts)
                vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, bufopts)
                vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, bufopts)
                vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
                vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
                vim.keymap.set('n', '<leader>lf', vim.lsp.buf.formatting, bufopts)
            end

            local lsp_attach = function(client, bufnr)
                if client.server_capabilities.documentSymbolProvider then
                    navic.attach(client, bufnr)
                end
                lsp_keymap(bufnr)
            end

            require('mason-lspconfig').setup_handlers({
                function(server_name)
                    if server_name == "lua_ls" then
                        lspconfig[server_name].setup({
                            on_attach = lsp_attach,
                            capabilities = lsp_capabilities,

                            settings = {
                                Lua = {
                                    diagnostics = {
                                        globals = { 'vim' }
                                    }
                                }
                            }
                        })
                    else
                        lspconfig[server_name].setup({
                            on_attach = lsp_attach,
                            capabilities = lsp_capabilities,
                        })
                    end
                end,
                ["jdtls"] = function()
                end,
            })
        end,
    },
}

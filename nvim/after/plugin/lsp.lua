require('mason').setup()
require('mason-lspconfig').setup({
    ensure_installed = {
        -- Replace these with whatever servers you want to install
        'rust_analyzer',
        'tsserver',
        'pyright',
        'gopls',
        'solargraph',
        'jdtls',
        'bashls',
        'jsonls',
        'kotlin_language_server',
        'jqls',
        'vimls',
        'lua_ls'
    }
})

local lspconfig = require('lspconfig')
local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()
local navic = require("nvim-navic")

local lsp_attach = function(client, bufnr)
    if client.server_capabilities.documentSymbolProvider then
        navic.attach(client, bufnr)
    end
    -- Create your keybindings here...
end
local noop = function() end

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
    ['jdtls'] = noop,
})

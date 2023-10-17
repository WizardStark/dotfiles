return {
    --git
    {
        'tpope/vim-rhubarb',
        event = 'VeryLazy'
    },
    {
        'tpope/vim-fugitive',
        event = 'VeryLazy'
    },
    {
        'airblade/vim-gitgutter',
        event = 'VeryLazy'
    },
    --treesitter
    {
        'nvim-treesitter/nvim-treesitter',
        event = 'VeryLazy',
        opts = function()
            local treesitter = require('nvim-treesitter.configs')
            treesitter.setup {
                ensure_installed = { 'python', 'vim', 'lua', 'java', 'go' }
            }
        end
    },
    --auto close brackets
    { 'cohama/lexima.vim' },
    --auto indent to current level
    {
        "lukas-reineke/indent-blankline.nvim",
        event = 'VeryLazy',
        main = "ibl",
        opts = {}
    },
    --cmp
    {
        "hrsh7th/nvim-cmp",
        version = false, -- last release is way too old
        event = "VeryLazy",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            'L3MON4D3/LuaSnip',
            'hrsh7th/cmp-cmdline',
            'hrsh7th/cmp-buffer',
            'onsails/lspkind.nvim',
        },
        opts = function()
            local luasnip = require 'luasnip'
            local lspkind = require 'lspkind'
            local cmp = require 'cmp'

            cmp.setup {
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-u>'] = cmp.mapping.scroll_docs(-4), -- Up
                    ['<C-d>'] = cmp.mapping.scroll_docs(4),  -- Down
                    -- C-b (back) C-f (forward) for snippet placeholder navigation.
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm {
                        select = false,
                    },
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                }),
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'buffer' },
                },
                formatting = {
                    format = lspkind.cmp_format({
                        mode = 'symbol',       -- show only symbol annotations
                        maxwidth = 50,         -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
                        ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)

                        -- The function below will be called before any actual modifications from lspkind
                        -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
                        before = function(entry, vim_item)
                            return vim_item
                        end
                    })
                }
            }
            -- `/` cmdline setup.
            cmp.setup.cmdline('/', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                }
            })
            -- `:` cmdline setup.
            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = 'path' }
                }, {
                    {
                        name = 'cmdline',
                        option = {
                            ignore_cmds = { 'Man', '!' }
                        }
                    }
                })
            })
        end
    },
    --debugging
    {
        "mfussenegger/nvim-dap",
        event = "BufReadPre",
        dependencies = {
            "theHamsta/nvim-dap-virtual-text",
            "rcarriga/nvim-dap-ui",
        },
        config = function()
            local dap_ui = require("dapui")
            local dap = require("dap")
            local jdtls = require("jdtls")
            dap_ui.setup({
                layouts = { {
                    elements = { {
                        id = "watches",
                        size = 0.5
                    }, {
                        id = "scopes",
                        size = 0.5
                    } },
                    position = "bottom",
                    size = 10
                } },
            })
            require("nvim-dap-virtual-text").setup()

            local function trigger_dap(dapStart)
                dap_ui.open({ reset = true })
                dapStart()
            end

            local function continue()
                if (dap.session()) then
                    dap.continue()
                else
                    dap_ui.open({ reset = true })
                    dap.continue()
                end
            end

            vim.keymap.set('n', '<Leader>dd', function() require('dap').toggle_breakpoint() end,
                { desc = "Toggle breakpoint" })

            vim.keymap.set('n', '<Leader>dD', function()
                    vim.ui.input({ prompt = "Condition: " }, function(input)
                        dap.set_breakpoint(input)
                    end)
                end,
                { desc = "Toggle breakpoint" })

            vim.keymap.set('n', '<leader>df', function() trigger_dap(require('jdtls').test_class()) end,
                { desc = "Debug test class" })
            vim.keymap.set('n', '<leader>dn',
                function() trigger_dap(require('jdtls').test_nearest_method()) end,
                { desc = "Debug neartest test method" })
            vim.keymap.set('n', '<leader>dt', function() trigger_dap(jdtls.test_nearest_method) end,
                { desc = 'Debug nearest test' });
            vim.keymap.set('n', '<leader>dT', function() trigger_dap(jdtls.test_class) end,
                { desc = 'Debug test class' });
            vim.keymap.set('n', '<leader>dp', function() trigger_dap(jdtls.pick_test) end,
                { desc = 'Choose nearest test' });
            vim.keymap.set('n', '<leader>dl', function() trigger_dap(dap.run_last) end,
                { desc = 'Choose nearest test' });
            vim.keymap.set('n', '<leader>do', function() dap.step_over() end, { desc = 'Step over' });
            vim.keymap.set('n', '<leader>di', function() dap.step_into() end, { desc = 'Step into' });
            vim.keymap.set('n', '<leader>du', function() dap.step_out() end, { desc = 'Step out' });
            vim.keymap.set('n', '<leader>db', function() dap.step_back() end, { desc = 'Step back' });
            vim.keymap.set('n', '<leader>dh', function() dap.run_to_cursor() end, { desc = 'Run to cursor' });
            vim.keymap.set('n', '<leader>dc', continue, { desc = 'Start debug session, or continue session' });
            vim.keymap.set('n', '<leader>de', function()
                dap.terminate()
                dap_ui.close()
            end, { desc = 'Terminate debug session' });
            vim.keymap.set('n', '<leader>du', function() dap_ui.toggle({ reset = true }) end,
                { desc = 'Reset and toggle ui' });

            vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#1f1d2e', bg = '#f6c177' })
            vim.fn.sign_define('DapStopped', {
                text = '->',
                texthl = 'DapStopped',
                linehl = 'DapStopped',
                numhl = 'DapStopped'
            })

            dap.configurations.java = {
                {
                    type = 'java',
                    request = 'attach',
                    name = "Debug (Attach) - Remote",
                    hostName = "127.0.0.1",
                    port = 5005,
                },
            }
        end,
    },
    --lsp diagnostics
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        },
    },
    --jupyter notebooks integration
    {
        'dccsillag/magma-nvim',
    },
    --better commenting
    {
        'numToStr/Comment.nvim',
        event = 'VeryLazy',
        opts = {
            -- add any options here
        },
    },
    --function overview
    {
        'stevearc/aerial.nvim',
        -- Optional dependencies
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons"
        },
        event = "VeryLazy",
        opts = {},
    },
    --git blame
    {
        'APZelos/blamer.nvim',
        event = "VeryLazy",
        opts = {}
    }
}

return {
    {
        "mfussenegger/nvim-dap",
        event = "VeryLazy",
        dependencies = {
            "theHamsta/nvim-dap-virtual-text",
            "rcarriga/nvim-dap-ui",
            {
                "jay-babu/mason-nvim-dap.nvim",
                opts = {
                    ensure_installed = { "python", "javascript" }
                }

            },

            --js dependencies
            --lazy spec to build "microsoft/vscode-js-debug" from source
            "mxsdev/nvim-dap-vscode-js",
            {
                "microsoft/vscode-js-debug",
                version = "1.x",
                build = "npm i && npm run compile vsDebugServerBundle && mv dist out"
            },
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            --ui setup
            dapui.setup()
            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open({ reset = true })
            end
            dap.listeners.before.event_terminated["dapui_config"] = dapui.close
            dap.listeners.before.event_exited["dapui_config"] = dapui.close
            require("nvim-dap-virtual-text").setup()

            vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#1f1d2e', bg = '#f6c177' })
            vim.fn.sign_define('DapStopped', {
                text = '->',
                texthl = 'DapStopped',
                linehl = 'DapStopped',
                numhl = 'DapStopped'
            })

            --java setup
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
    {
        'mfussenegger/nvim-dap-python',
        dependencies = {
            'mfussenegger/nvim-dap',
            'rcarriga/nvim-dap-ui'
        },
        event = 'VeryLazy',
        config = function()
            -- local debugpy_path = require('mason-registry').get_package('debugpy'):get_install_path()
            -- require('dap-python').setup(debugpy_path .. '/venv/bin/python')
            require('dap-python').setup('/usr/bin/python3')
        end
    }
}

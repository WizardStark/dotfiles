return {
    {
        "mfussenegger/nvim-dap",
        event = "VeryLazy",
        dependencies = {
            "theHamsta/nvim-dap-virtual-text",
            "rcarriga/nvim-dap-ui",

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
            dapui.setup({
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

            --js setup
            require("dap-vscode-js").setup({
                debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
                adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' },
            })
            for _, language in ipairs({ "typescript", "javascript", "svelte", "javascriptreact", "typescriptreact" }) do
                require("dap").configurations[language] = {
                    -- attach to a node process that has been started with
                    -- `--inspect` for longrunning tasks or `--inspect-brk` for short tasks
                    -- npm script -> `node --inspect-brk ./node_modules/.bin/vite dev`
                    {
                        -- use nvim-dap-vscode-js's pwa-node debug adapter
                        type = "pwa-node",
                        -- attach to an already running node process with --inspect flag
                        -- default port: 9222
                        request = "attach",
                        -- allows us to pick the process using a picker
                        processId = require 'dap.utils'.pick_process,
                        -- name of the debug action you have to select for this config
                        name = "Attach debugger to existing `node --inspect` process",
                        -- for compiled languages like TypeScript or Svelte.js
                        sourceMaps = true,
                        -- resolve source maps in nested locations while ignoring node_modules
                        resolveSourceMapLocations = {
                            "${workspaceFolder}/**",
                            "!**/node_modules/**" },
                        -- path to src in vite based projects (and most other projects as well)
                        cwd = "${workspaceFolder}/src",
                        -- we don't want to debug code inside node_modules, so skip it!
                        skipFiles = { "${workspaceFolder}/node_modules/**/*.js" },
                    },
                    {
                        type = "pwa-chrome",
                        name = "Launch Chrome to debug client",
                        request = "launch",
                        url = "http://localhost:5173",
                        sourceMaps = true,
                        protocol = "inspector",
                        port = 9222,
                        webRoot = "${workspaceFolder}/src",
                        -- skip files from vite's hmr
                        skipFiles = { "**/node_modules/**/*", "**/@vite/*", "**/src/client/*", "**/src/*" },
                    },
                    -- only if language is javascript, offer this debug action
                    language == "javascript" and {
                        -- use nvim-dap-vscode-js's pwa-node debug adapter
                        type = "pwa-node",
                        -- launch a new process to attach the debugger to
                        request = "launch",
                        -- name of the debug action you have to select for this config
                        name = "Launch file in new node process",
                        -- launch current file
                        program = "${file}",
                        cwd = "${workspaceFolder}",
                    } or nil,
                }
            end
        end,
    },
    {
        'mfussenegger/nvim-dap-python',
        event = 'VeryLazy',
        config = function()
            require('dap-python').setup('~/.virtualenvs/debugpy/bin/python')
        end
    }
}

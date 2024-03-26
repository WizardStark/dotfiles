return {
	-- dap
	{
		"mfussenegger/nvim-dap",
		lazy = true,
		dependencies = {
			"theHamsta/nvim-dap-virtual-text",
			"rcarriga/nvim-dap-ui",
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			local dap = require("dap")
			dap.set_log_level("TRACE")
			dap.defaults.fallback.exception_breakpoints = { "raised" }

			local chrome_debug_path = require("mason-registry").get_package("chrome-debug-adapter"):get_install_path()
			dap.adapters.chrome = {
				type = "executable",
				command = "node",
				args = { chrome_debug_path .. "/out/src/chromeDebug.js" },
			}
			dap.configurations.javascriptreact = {
				{
					name = "Launch",
					type = "chrome",
					request = "launch",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					-- TODO: Make runtime exe differ per os <19-03-24, yourname> --
					runtimeExecutable = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe",
					runtimeArgs = { "--remote-debugging-port=9222" },
					port = 9222,
					webRoot = "${workspaceFolder}",
					url = "http://localhost:5173/",
				},
				{
					name = "Attach",
					type = "chrome",
					request = "attach",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					port = 9222,
					webRoot = "${workspaceFolder}",
				},
			}
			dap.configurations.typescriptreact = {
				{
					name = "Launch",
					type = "chrome",
					request = "launch",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					runtimeExecutable = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe",
					runtimeArgs = { "--remote-debugging-port=9222" },
					port = 9222,
					webRoot = "${workspaceFolder}",
					url = "http://localhost:5173/",
				},
				{
					name = "Attach",
					type = "chrome",
					request = "attach",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					port = 9222,
					webRoot = "${workspaceFolder}",
				},
			}
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		lazy = true,
		opts = {},
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		lazy = true,
		opts = {
			automatic_installation = true,
			handlers = {
				function(config)
					require("mason-nvim-dap").default_setup(config)
				end,
			},
		},
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"nvim-neotest/nvim-nio",
		},
		lazy = true,
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

			vim.api.nvim_set_hl(0, "DapStopped", { ctermbg = 0, fg = "#1f1d2e", bg = "#f6c177" })
			vim.fn.sign_define("DapStopped", {
				text = "->",
				texthl = "DapStopped",
				linehl = "DapStopped",
				numhl = "DapStopped",
			})
		end,
	},
	-- dap-python
	{
		"mfussenegger/nvim-dap-python",
		dependencies = {
			"mfussenegger/nvim-dap",
			"rcarriga/nvim-dap-ui",
		},
		lazy = true,
		config = function()
			local debugpy_path = require("mason-registry").get_package("debugpy"):get_install_path()
			-- require("dap-python").setup(debugpy_path .. "/venv/bin/python")
			require("dap-python").setup("/usr/bin/python3")
		end,
	},
	--dap-go
	{
		"leoluz/nvim-dap-go",
		dependencies = {
			"mfussenegger/nvim-dap",
			"rcarriga/nvim-dap-ui",
		},
		lazy = true,
		config = function()
			require("dap-go").setup()
		end,
	},
	--dap-neovim-lua
	{
		"jbyuki/one-small-step-for-vimkind",
		dependencies = {
			"mfussenegger/nvim-dap",
		},
		lazy = true,
		config = function()
			local dap = require("dap")
			dap.configurations.lua = {
				{
					type = "nlua",
					request = "attach",
					name = "Attach to running Neovim instance",
				},
			}

			dap.adapters.nlua = function(callback, config)
				callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
			end
		end,
	},
}

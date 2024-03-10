return {
	-- dap
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		dependencies = {
			"theHamsta/nvim-dap-virtual-text",
			"rcarriga/nvim-dap-ui",
			"jay-babu/mason-nvim-dap.nvim",
		},
		--Add the following to run program in debug mode
		--require('dap').defaults.fallback.exception_breakpoints = {'raised'}
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		event = "VeryLazy",
		opts = {},
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		event = "VeryLazy",
		opts = {},
	},
	{
		"rcarriga/nvim-dap-ui",
		event = "VeryLazy",
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
		event = "VeryLazy",
		config = function()
			local debugpy_path = require("mason-registry").get_package("debugpy"):get_install_path()
			require("dap-python").setup(debugpy_path .. "/venv/bin/python")
			-- require("dap-python").setup("/usr/bin/python3")
		end,
	},
}

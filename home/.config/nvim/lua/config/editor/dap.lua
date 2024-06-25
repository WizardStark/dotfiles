local dap = require("dap")
local dapui = require("dapui")

require("nvim-dap-virtual-text").setup({
	automatic_installation = true,
	handlers = {
		function(config)
			require("mason-nvim-dap").default_setup(config)
		end,
	},
})

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

dap.set_log_level("TRACE")
dap.defaults.fallback.exception_breakpoints = { "uncaught" }

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

require("dap-go").setup()

-- local debugpy_path = require("mason-registry").get_package("debugpy"):get_install_path()
-- require("dap-python").setup(debugpy_path .. "/venv/bin/python")

require("dap-python").setup("/usr/bin/python3")

table.insert(require("dap").configurations.python, {
	type = "python",
	request = "launch",
	name = "Run file and debug libraries",
	program = "${file}",
	justMyCode = false,
})

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

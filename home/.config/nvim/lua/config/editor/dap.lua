local dap = require("dap")
local dapview = require("dap-view")

require("nvim-dap-virtual-text").setup({
	automatic_installation = true,
	handlers = {
		function(config)
			require("mason-nvim-dap").default_setup(config)
		end,
	},
})

dapview.setup({
	auto_toggle = true,
	winbar = {
		sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "console" },
	},
	switchbuf = "usetab",
})

vim.api.nvim_set_hl(0, "DapStopped", { ctermbg = 0, fg = "#1f1d2e", bg = "#f6c177" })
vim.fn.sign_define("DapStopped", {
	text = "->",
	texthl = "DapStopped",
	linehl = "DapStopped",
	numhl = "DapStopped",
})

dap.set_log_level("TRACE")
dap.defaults.fallback.exception_breakpoints = { "uncaught" }

local chrome_debug_path = vim.fn.exepath("chrome-debug-adapter")
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
dap.configurations.svelte = {
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

require("dap-python").setup(require("user.utils").get_python_venv())
-- require("dap-python").resolve_python = require("user.utils").get_python_venv

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
	callback({
		type = "server",
		host = "127.0.0.1",
		port = 8086,
	})
end

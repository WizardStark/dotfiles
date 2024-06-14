vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
require("conform").setup({
	-- Define your formatters
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "usort", "black" },
		java = { "checkstyle" },
		kotlin = { "ktlint" },
		javascript = { { "prettierd", "prettier" } },
		javascriptreact = { { "prettierd", "prettier" } },
		typescript = { { "prettierd", "prettier" } },
		typescriptreact = { { "prettierd", "prettier" } },
		markdown = { { "prettierd", "prettier" } },
		css = { { "prettierd", "prettier" } },
		scss = { { "prettierd", "prettier" } },
		json = { "jq" },
		go = { "gofumpt" },
		bash = { "shfmt" },
		sh = { "shfmt" },
		zsh = { "shfmt" },
		yml = { "yamlfmt" },
		yaml = { "yamlfmt" },
	},
	format_on_save = true,
	formatters = {
		shfmt = {
			prepend_args = { "-i", "2" },
		},
	},
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

local allowed_filetypes = {
	"lua",
	"go",
	"sh",
	"zsh",
}

local function is_allowed_ft(bufnr)
	return require("user.utils").contains(vim.bo[bufnr].ft, allowed_filetypes)
end

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

	format_on_save = function(bufnr)
		return {
			{
				lsp_format = "fallback",
				dry_run = is_allowed_ft(bufnr),
				timeout_ms = 500,
			},
		}
	end,

	formatters = {
		shfmt = {
			prepend_args = { "-i", "2" },
		},
	},
})

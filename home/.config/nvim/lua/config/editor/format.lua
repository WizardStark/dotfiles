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
		java = { "google-java-format" },
		kotlin = { "ktlint" },
		javascript = { "prettier" },
		javascriptreact = { "prettier" },
		typescript = { "prettier" },
		typescriptreact = { "prettier" },
		markdown = { "prettier" },
		css = { "prettier" },
		scss = { "prettier" },
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
			lsp_format = "fallback",
			dry_run = not is_allowed_ft(bufnr),
			timeout_ms = 500,
		}
	end,

	formatters = {
		prettier = {
			prepend_args = { "--tab-width", "4" },
		},
		shfmt = {
			prepend_args = { "-i", "2" },
		},
	},
})

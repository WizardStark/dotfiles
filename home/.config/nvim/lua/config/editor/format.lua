vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

local allowed_filetypes = {
	"lua",
	"python",
	"go",
	"sh",
	"svelte",
	"toml",
	"typescript",
	"zsh",
	"sql",
	"rust",
	"java",
}

local function is_allowed_ft(bufnr)
	return require("user.utils").contains(vim.bo[bufnr].ft, allowed_filetypes)
end

require("conform").setup(
	---@module 'conform'
	{
		-- Define your formatters
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "ruff_format", "ruff_organize_imports", "ruff_fix" },
			java = { "palantir-java-format" },
			kotlin = { "ktlint" },
			javascript = { "prettierd" },
			javascriptreact = { "prettierd" },
			typescript = { "prettierd" },
			typescriptreact = { "prettierd" },
			svelte = { "prettierd" },
			markdown = { "prettierd" },
			css = { "prettierd" },
			c = { "clang-format" },
			scss = { "prettierd" },
			json = { "jq" },
			go = { "gofumpt", "goimports" },
			rust = { "rustfmt" },
			bash = { "shfmt" },
			sh = { "shfmt" },
			sql = { "sqlfmt" },
			zsh = { "shfmt" },
			yml = { "yamlfmt" },
			yaml = { "yamlfmt" },
			toml = function(bufnr)
				local filename = vim.api.nvim_buf_get_name(bufnr)
				if vim.fn.fnamemodify(filename, ":t") == "pyproject.toml" then
					return { "pyproject-fmt" }
				else
					return {}
				end
			end,
		},

		format_on_save = function(bufnr)
			return {
				lsp_format = "fallback",
				dry_run = not is_allowed_ft(bufnr),
				timeout_ms = 500,
			}
		end,

		formatters = {
			["palantir-java-format"] = {
				command = "palantir-java-format",
				args = { "--aosp", "-" },
			},
			shfmt = {
				prepend_args = { "-i", "2" },
			},
			sqlfmt = {
				prepend_args = { "--dialect", "clickhouse" },
			},
		},
	}
)

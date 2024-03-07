local prefixifier = require("utils").prefixifier
local P = require("utils").PREFIXES
local commands = require("legendary").commands

prefixifier(commands)({
	{
		":Lazy",
		prefix = P.misc,
		description = "Open Lazy plugin manager",
	},
	{
		":LspInfo",
		prefix = P.lsp,
		description = "Show LSP information for current buffer",
	},
	{
		":LspLog",
		prefix = P.lsp,
		description = "Open LSP log in a new buffer",
	},
	{
		":LspStop",
		prefix = P.lsp,
		description = "Stop currently attached LSP",
	},
	{
		":LspStart",
		prefix = P.lsp,
		description = "Start LSP for current buffer",
	},
	{
		":LspRestart",
		prefix = P.lsp,
		description = "Restart currently attached LSP",
	},
	{
		":VimtexStop<CR>",
		prefix = P.latex,
		description = "Stop Latex compilation",
	},
	{
		":VimtexStopAll<CR>",
		prefix = P.latex,
		description = "Stop  all Latex compilation",
	},
})
return {}

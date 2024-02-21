return {
	require("legendary").commands({
		{ ":Lazy", description = "Open Lazy plugin manager" },
		{ ":Mason", description = "Open Mason LSP manager" },
		{ ":LspInfo", description = "Show LSP information for current buffer" },
		{ ":LspLog", description = "Open LSP log in a new buffer" },
		{ ":LspStop", description = "Stop currently attached LSP" },
		{ ":LspStart", description = "Start LSP for current buffer" },
		{ ":LspRestart", description = "Restart currently attached LSP" },
		{
			":Gitsigns diffthis {diff_target}",
			unfinished = true,
			description = "Git diff, requires diff target, e.g. ~1 for previous commit",
		},
		{
			":GitMessenger",
			description = "Show commit message for current line",
		},
		{
			":Gitsigns stage_hunk<CR>",
			description = "Git stage visual selection",
		},
		{
			":Gitsigns stage_buffer<CR>",
			description = "Git stage buffer",
		},
		{
			":Gitsigns reset_hunk<CR>",
			description = "Git reset visual selection",
		},
		{
			":Gitsigns reset_buffer<CR>",
			description = "Git reset buffer",
		},
		{
			":VimtexStop<CR>",
			description = "Stop Latex compilation",
		},
		{
			":VimtexStopAll<CR>",
			description = "Stop  all Latex compilation",
		},
	}),
}

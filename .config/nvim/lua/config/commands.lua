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
			":Gitsigns stage_buffer<CR>",
			description = "Git stage buffer",
		},
		{
			":Gitsigns reset_buffer<CR>",
			description = "Git reset buffer",
		},
		{
			":Gitsigns undo_stage_hunk<CR>",
			description = "Git undo stage hunk",
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

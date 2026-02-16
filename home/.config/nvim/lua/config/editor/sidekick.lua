require("sidekick").setup({
	cli = {
		mux = {
			backend = "tmux",
			enabled = false,
		},
		prompts = {
			commit = "Please update the WIP commit with a more descriptive message, use git log -n 5 to see recent commits for message format. DO NOT use conventional commit format, just a descriptive message is enough. If required add multiline details in the body of the commit message. If there is no WIP commit but there are unstaged changes then create a new commit with a descriptive message. If there are no WIP commits and no unstaged changes then do nothing.",
		},
	},
})

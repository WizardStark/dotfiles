return {
	require("legendary").funcs({
		{
			function()
				local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/init.lua"))
				if not ok then
					vim.fn.system(
						"mkdir -p ~/.config/lcl && touch ~/.config/lcl/init.lua && echo M={} return M >> ~/.config/lcl/init.lua"
					)
					vim.notify("Please close and reopen vim")
				else
					vim.notify("Local config already exists")
				end
			end,
			description = "Create local config file if it does not exist",
		},
		{
			function()
				local ok, _ = pcall(dofile, vim.fn.expand("$HOME/.config/lcl/init.lua"))
				if not ok then
					vim.cmd.e("~/.config/lcl/init.lua")
				else
					vim.notify("Local config does not exist")
				end
			end,
			description = "Edit local config",
		},
        -- Git
        {
            function()
                require("gitsigns").stage_hunk(
                    require("utils").get_visual_selection_lines()
                )
            end,
			description = "Git stage visual selection",
        },
        {
            function()
                require("gitsigns").reset_hunk(
                    require("utils").get_visual_selection_lines()
                )
            end,
			description = "Git reset visual selection",
        }
	}),
}

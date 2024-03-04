return {
	--ufo
	{
		"kevinhwang91/nvim-ufo",
		dependencies = {
			"kevinhwang91/promise-async",
		},
		event = "VeryLazy",
		config = function()
			local ftMap = {
				vim = "indent",
				python = { "indent" },
				git = "",
			}

			local handler = function(virtText, lnum, endLnum, width, truncate)
				local newVirtText = {}
				local suffix = (" 󰁂 %d "):format(endLnum - lnum)
				local sufWidth = vim.fn.strdisplaywidth(suffix)
				local targetWidth = width - sufWidth
				local curWidth = 0
				for _, chunk in ipairs(virtText) do
					local chunkText = chunk[1]
					local chunkWidth = vim.fn.strdisplaywidth(chunkText)
					if targetWidth > curWidth + chunkWidth then
						table.insert(newVirtText, chunk)
					else
						chunkText = truncate(chunkText, targetWidth - curWidth)
						local hlGroup = chunk[2]
						table.insert(newVirtText, { chunkText, hlGroup })
						chunkWidth = vim.fn.strdisplaywidth(chunkText)
						if curWidth + chunkWidth < targetWidth then
							suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
						end
						break
					end
					curWidth = curWidth + chunkWidth
				end
				table.insert(newVirtText, { suffix, "MoreMsg" })
				return newVirtText
			end

			require("ufo").setup({
				open_fold_hl_timeout = 150,
				close_fold_kinds = {}, --{ "imports", "comment" },
				preview = {
					win_config = {
						border = { "", "─", "", "", "", "─", "", "" },
						winhighlight = "Normal:Folded",
						winblend = 0,
					},
					mappings = {
						scrollU = "<C-u>",
						scrollD = "<C-d>",
						jumpTop = "[",
						jumpBot = "]",
					},
				},
				provider_selector = function(filetype)
					return ftMap[filetype]
				end,
				fold_virt_text_handler = handler,
			})
		end,
	},
	--notify
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		opts = {},
	},
	--responsive rename
	{
		"smjonas/inc-rename.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--cleaner UI
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		opts = {
			lsp = {
				progress = {
					enabled = false,
				},

				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
				signature = {
					enabled = false,
				},
			},
			popupmenu = {
				backend = "cmp", -- backend to use to show regular cmdline completions
			},
			presets = {
				bottom_search = true, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = true, -- enables an input dialog for inc-rename.nvim
			},
		},
	},
	--toggleterm
	{
		"akinsho/toggleterm.nvim",
		event = "VeryLazy",
		version = "*",
		config = true,
		opts = { open_mapping = [[<c-\>]] },
	},
	--dressing.nvim
	{
		"stevearc/dressing.nvim",
		event = "VeryLazy",
		opts = {
			select = {
				get_config = function(opts)
					if opts.kind == "legendary.nvim" then
						return {
							backend = "telescope",
							telescope = require("telescope.themes").get_ivy({}),
						}
					end
				end,
			},
			input = {
				get_config = function(opts)
					if opts.kind == "tabline" then
						return {
							relative = "win",
						}
					end
				end,
			},
		},
	},
	--markdown "rendering"
	{
		"lukas-reineke/headlines.nvim",
		event = "VeryLazy",
		dependencies = "nvim-treesitter/nvim-treesitter",
		opts = {},
	},
	{
		"cbochs/portal.nvim",
		dependencies = {
			"cbochs/grapple.nvim",
		},
		opts = {
			window_options = {
				width = 80,
				height = 7,
				row = 0.5,
				col = 0.5,

				relative = "cursor",
				border = "rounded",
				focusable = false,
				style = "minimal",
			},
		},
	},
}

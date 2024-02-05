local signs = {
	DiagnosticSignError = "󰅚 ",
	DiagnosticSignWarn = "󰀪 ",
	DiagnosticSignHint = "󰌶 ",
	DiagnosticSignInfo = " ",
	DapBreakpoint = "",
	DapBreakpointCondition = "",
	DapBreakpointRejected = "",
	DapLogPoint = ".>",
	DapStopped = "󰁕",
}
for type, icon in pairs(signs) do
	vim.fn.sign_define(type, { text = icon, texthl = type, numhl = type })
end

-- LSP clients attached to buffer
local function clients_lsp()
	local bufnr = vim.api.nvim_get_current_buf()

	local clients = vim.lsp.buf_get_clients(bufnr)
	if next(clients) == nil then
		return " No servers"
	end

	local buf_client_names = {}
	for _, client in pairs(clients) do
		table.insert(buf_client_names, client.name)
	end

	local ok, conform = pcall(require, "conform")
	local formatters = conform.list_formatters(bufnr)
	if ok then
		for _, formatter in ipairs(formatters) do
			table.insert(buf_client_names, formatter["name"])
		end
	end

	local hash = {}
	local unique_client_names = {}

	for _, v in ipairs(buf_client_names) do
		if not hash[v] then
			unique_client_names[#unique_client_names + 1] = v
			hash[v] = true
		end
	end
	local language_servers = table.concat(unique_client_names, " ∣ ")
	return " " .. language_servers
end

local function is_toggleterm()
	return vim.bo.filetype ~= "toggleterm"
end

local function diff_source()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return {
			added = gitsigns.added,
			modified = gitsigns.changed,
			removed = gitsigns.removed,
		}
	end
end

local function getWords()
	local wc = vim.fn.wordcount()
	if wc["visual_words"] then -- text is selected in visual mode
		return wc["visual_words"] .. " Words/" .. wc["visual_chars"] .. " Chars (Vis)"
	else -- all of the document
		return wc["words"] .. " Words"
	end
end

local function is_text_file()
	local ft = vim.opt_local.filetype:get()
	local count = {
		latex = true,
		tex = true,
		text = true,
		markdown = true,
		vimwiki = true,
	}
	return count[ft] ~= nil
end

return {
	--Telescope
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.3",
		event = "VeryLazy",
		dependencies = {
			{
				"nvim-lua/plenary.nvim",
			},
			{
				"junegunn/fzf.vim",
				event = "VeryLazy",
			},
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "gmake",
			},
			{
				"nvim-telescope/telescope-live-grep-args.nvim",
				-- This will not install any breaking changes.
				-- For major updates, this must be adjusted manually.
				version = "^1.0.0",
			},
			{
				"nvim-tree/nvim-web-devicons",
			},
			{
				"debugloop/telescope-undo.nvim",
			},
		},
		config = function()
			require("telescope").setup({
				defaults = {
					layout_strategy = "horizontal",
					layout_config = {
						horizontal = { width = 0.85, preview_width = 0.6 },
					},
					dynamic_preview_title = true,
				},
				extensions = {
					fzf = {
						fuzzy = true,
						override_generic_sorter = true,
						override_file_sorter = true,
						case_mode = "smart_case",
					},
					undo = {},
					bookmarks = {},
				},
			})

			require("telescope").load_extension("fzf")
			require("telescope").load_extension("live_grep_args")
			require("telescope").load_extension("bookmarks")
			require("telescope").load_extension("undo")
		end,
	},
	--nvim-tree
	{
		"nvim-tree/nvim-tree.lua",
		event = "VeryLazy",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			sort_by = "case_sensitive",
			view = {
				width = 40,
			},
			renderer = {
				group_empty = true,
			},
			filters = {
				dotfiles = false,
			},
		},
	},
	--mini.files
	{
		"echasnovski/mini.files",
		event = "VeryLazy",
		version = false,
		opts = {
			windows = {
				preview = true,
				width_preview = 75,
			},
		},
	},
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
						-- str width returned from truncate() may less than 2nd argument, need padding
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
				close_fold_kinds = { "imports", "comment" },
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
					-- if you prefer treesitter provider rather than lsp,
					-- return ftMap[filetype] or {'treesitter', 'indent'}
					return ftMap[filetype]

					-- refer to ./doc/example.lua for detail
				end,
				fold_virt_text_handler = handler,
			})
		end,
	},
	--cleaner UI
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			{
				"rcarriga/nvim-notify",
				opts = {
					stages = "static",
				},
			},
		},
		opts = {
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
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
				-- cmp-cmdline has more sources and can be extended
				backend = "cmp", -- backend to use to show regular cmdline completions
			},
			presets = {
				bottom_search = true, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
			},
		},
	},
	--lazygit
	{
		"kdheepak/lazygit.nvim",
		event = "VeryLazy",
		-- optional for floating window border decoration
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},
	--harpoon
	{
		"ThePrimeagen/harpoon",
		event = "VeryLazy",
		opts = {
			global_settings = {
				mark_branch = true,
			},
		},
	},
	--toggleterm
	{
		"akinsho/toggleterm.nvim",
		event = "VeryLazy",
		version = "*",
		config = true,
		opts = {
			open_mapping = [[<c-\>]],
		},
	},
	--dressing.nvim
	{
		"stevearc/dressing.nvim",
		event = "VeryLazy",
		opts = {},
	},
	--lualine
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			options = {
				theme = "moonfly",
				-- globalstatus = true,
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { { "b:gitsigns_head", icon = "" }, { "diff", source = diff_source }, "diagnostics" },
				lualine_c = { "windows", { getWords, cond = is_text_file } },
				lualine_x = { "filesize", "filetype" },
				lualine_y = { "progress", "location" },
				lualine_z = { clients_lsp },
			},
			inactive_sections = {
				lualine_a = { "mode" },
				lualine_b = { { "b:gitsigns_head", icon = "" }, { "diff", source = diff_source }, "diagnostics" },
				lualine_c = { "windows", { getWords, cond = is_text_file } },
				lualine_x = { "filesize", "filetype" },
				lualine_y = { "progress", "location" },
				lualine_z = { clients_lsp },
			},
			winbar = {
				lualine_a = { { "filename", path = 1, cond = is_toggleterm } },
				lualine_c = { "aerial" },
			},
			inactive_winbar = {
				lualine_a = { { "filename", path = 1, cond = is_toggleterm } },
				lualine_c = { "aerial" },
			},
			extensions = {
				"nvim-tree",
				"nvim-dap-ui",
				"mason",
				"aerial",
				"lazy",
				"toggleterm",
				"trouble",
			},
		},
	},
}

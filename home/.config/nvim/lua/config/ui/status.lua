-- LSP clients attached to buffer
local function clients_lsp()
	local bufnr = vim.api.nvim_get_current_buf()

	local clients = vim.lsp.get_clients({ bufnr = bufnr })

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
	local language_servers = table.concat(unique_client_names, " │ ")
	return " " .. language_servers
end

local function is_not_toggleterm()
	return vim.bo.filetype ~= "toggleterm"
end

local function is_toggleterm()
	return vim.bo.filetype == "toggleterm"
end

local function get_words()
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

local function get_term_name()
	local terms = require("toggleterm.terminal").get_all()
	for _, term in ipairs(terms) do
		if vim.fn.win_id2win(term.window) == vim.fn.winnr() then
			local session_terms = require("workspaces.toggleterms").get_session_terms()
			local prefix
			local term_display_id
			for _, value in ipairs(session_terms) do
				if value.global_id == term.id then
					term_display_id = value.local_id
				end
			end

			if next(vim.fn.argv()) ~= nil then
				prefix = "toggleterm"
			else
				local workspace = require("workspaces.state").get().current_workspace
				prefix = workspace.name .. "-" .. workspace.current_session_name
			end

			return prefix .. ": Term " .. term_display_id
		end
	end
end

local function get_plugin_info()
	local stats = require("lazy").stats()
	return "󰚥 " .. stats.loaded .. "/" .. stats.count
end

local function get_startup_time()
	local stats = require("lazy").stats()
	return "󰅕 " .. stats.startuptime .. "ms"
end

local palette = require("catppuccin.palettes").get_palette("mocha")
local theme = require("catppuccin.utils.lualine")("mocha")
theme.normal.c.bg = "NONE"
theme.normal.c.fg = palette.subtext1

require("bars").setup(
	---@module 'bars'
	{
		statuscolumn = {
			enable = false,
		},
		statusline = {
			enable = true,
			parts = {
				{
					type = "mode",
				},
				{
					type = "diagnostic",
				},
				{
					type = "git_branch",
				},
			},
			custom = {
				{
					type = "custom",

					value = function(buffer, window, used_len)
						-- All of them are [ text, highlight_group ]
						return {
							corner_left = { "󰊢 ", "Comment" },
							padding_left = {},

							content = { "Test", "CmdViolet" },

							padding_right = {},
							corner_right = {},
						}
					end,
				},
			},
		},
		tabline = {
			enable = true,
			parts = {},

			custom = {
				{
					type = "custom",

					value = function(len)
						return {
							corner_left = nil,
							corner_right = nil,
							value = { "Test", "CmdViolet" },

							padding_left = nil,
							padding_right = nil,
						}
					end,
				},
			},
		},
	}
	-- {
	-- 	options = {
	-- 		always_divide_middle = false,
	-- 		theme = theme,
	-- 		section_separators = { left = "", right = "" },
	-- 		component_separators = { left = "", right = "" },
	-- 	},
	-- 	sections = {
	-- 		lualine_a = { { "mode", cond = is_not_toggleterm }, { get_term_name, cond = is_toggleterm } },
	-- 		lualine_b = {
	-- 			{ get_words, cond = is_text_file },
	-- 			{ "b:gitsigns_head", icon = "" },
	-- 			"diagnostics",
	-- 		},
	-- 		lualine_c = { { get_plugin_info }, { get_startup_time } },
	-- 		lualine_x = { { "filesize", cond = is_not_toggleterm }, { "filetype", cond = is_not_toggleterm } },
	-- 		lualine_y = {
	-- 			{ "progress", cond = is_not_toggleterm },
	-- 			{ "location", cond = is_not_toggleterm },
	-- 			{ require("recorder").recordingStatus, cond = is_not_toggleterm },
	-- 			{ require("recorder").displaySlots, cond = is_not_toggleterm },
	-- 		},
	-- 		lualine_z = { { clients_lsp, cond = is_not_toggleterm } },
	-- 	},
	-- 	extensions = {
	-- 		"nvim-dap-ui",
	-- 		"mason",
	-- 		"lazy",
	-- 		"trouble",
	-- 	},
	-- }
)

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

local function is_not_toggleterm()
	return vim.bo.filetype ~= "toggleterm"
end

local function is_toggleterm()
	return vim.bo.filetype == "toggleterm"
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

local function get_term_name()
	local terms = require("toggleterm.terminal").get_all()
	for _, term in ipairs(terms) do
		if vim.fn.win_id2win(term.window) == vim.fn.winnr() then
			local session_terms = require("workspaces.toggleterms").get_session_terms()
			local prefix
			local term_id
			for key, value in pairs(session_terms) do
				if value == term.id then
					term_id = key
				end
			end

			if next(vim.fn.argv()) ~= nil then
				prefix = "toggleterm"
			else
				local workspace = require("workspaces.state").get().current_workspace
				prefix = workspace.name .. "-" .. workspace.current_session_name
			end

			return prefix .. ": Term " .. term_id
		end
	end
end

return {
	--lualine
	{
		"nvim-lualine/lualine.nvim",
		lazy = true,
		dependencies = { "stevearc/aerial.nvim" },
		config = function()
			require("lualine").setup({
				options = {
					always_divide_middle = false,
					theme = "catppuccin",
				},
				sections = {
					lualine_a = { { "mode", cond = is_not_toggleterm }, { get_term_name, cond = is_toggleterm } },
					lualine_b = {
						{ "b:gitsigns_head", icon = "" },
						{ "diff", source = diff_source },
						"diagnostics",
						{
							require("grapple").statusline,
							cond = require("grapple").exists,
						},
					},
					lualine_c = {
						{ getWords, cond = is_text_file },
						{ "filename", path = 1, cond = is_not_toggleterm },
						"aerial",
					},
					lualine_x = { { "filesize", cond = is_not_toggleterm }, { "filetype", cond = is_not_toggleterm } },
					lualine_y = {
						{ "progress", cond = is_not_toggleterm },
						{ "location", cond = is_not_toggleterm },
						{ require("recorder").recordingStatus, cond = is_not_toggleterm },
						{ require("recorder").displaySlots, cond = is_not_toggleterm },
					},
					lualine_z = { { clients_lsp, cond = is_not_toggleterm } },
				},
				inactive_sections = {
					lualine_a = { { "mode", cond = is_not_toggleterm }, { get_term_name, cond = is_toggleterm } },
					lualine_b = {
						{ "b:gitsigns_head", icon = "" },
						{ "diff", source = diff_source },
						"diagnostics",
						{
							require("grapple").statusline,
							cond = require("grapple").exists,
						},
					},
					lualine_c = {
						{ getWords, cond = is_text_file },
						{ "filename", path = 1, cond = is_not_toggleterm },
						"aerial",
					},
					lualine_x = { { "filesize", cond = is_not_toggleterm }, { "filetype", cond = is_not_toggleterm } },
					lualine_y = { { "progress", cond = is_not_toggleterm }, { "location", cond = is_not_toggleterm } },
					lualine_z = { { clients_lsp, cond = is_not_toggleterm } },
				},
				tabline = {},
				inactive_tabline = {},
				winbar = {},
				inactive_winbar = {},
				extensions = {
					"nvim-dap-ui",
					"mason",
					"aerial",
					"lazy",
					"trouble",
				},
			})
		end,
	},
}

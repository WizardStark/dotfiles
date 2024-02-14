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

local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
local folder_icon = "%#Conditional#" .. "󰉋" .. "%#Normal#"
local file_icon = "󰈙"

local kind_icons = {
	"%#File#" .. "󰈙" .. "%#Normal#", -- file
	"%#Module#" .. "" .. "%#Normal#", -- module
	"%#Structure#" .. "" .. "%#Normal#", -- namespace
	"%#Keyword#" .. "󰌋" .. "%#Normal#", -- key
	"%#Class#" .. "󰠱" .. "%#Normal#", -- class
	"%#Method#" .. "󰆧" .. "%#Normal#", -- method
	"%#Property#" .. "󰜢" .. "%#Normal#", -- property
	"%#Field#" .. "󰇽" .. "%#Normal#", -- field
	"%#Function#" .. "" .. "%#Normal#", -- constructor
	"%#Enum#" .. "" .. "%#Normal#", -- enum
	"%#Type#" .. "" .. "%#Normal#", -- interface
	"%#Function#" .. "󰊕" .. "%#Normal#", -- function
	"%#None#" .. "" .. "%#Normal#", -- variable
	"%#Constant#" .. "󰏿" .. "%#Normal#", -- constant
	"%#String#" .. "" .. "%#Normal#", -- string
	"%#Number#" .. "" .. "%#Normal#", -- number
	"%#Boolean#" .. "" .. "%#Normal#", -- boolean
	"%#Array#" .. "" .. "%#Normal#", -- array
	"%#Class#" .. "" .. "%#Normal#", -- object
	"", -- package
	"󰟢", -- null
	"", -- enum-member
	"%#Struct#" .. "" .. "%#Normal#", -- struct
	"", -- event
	"", -- operator
	"󰅲", -- type-parameter
}

local function range_contains_pos(range, line, char)
	local start = range.start
	local stop = range["end"]

	if line < start.line or line > stop.line then
		return false
	end

	if line == start.line and char < start.character then
		return false
	end

	if line == stop.line and char > stop.character then
		return false
	end

	return true
end

local function find_symbol_path(symbol_list, line, char, path)
	if not symbol_list or #symbol_list == 0 then
		return false
	end

	for _, symbol in ipairs(symbol_list) do
		if range_contains_pos(symbol.range, line, char) then
			local icon = kind_icons[symbol.kind] or ""
			table.insert(path, icon .. " " .. symbol.name)
			find_symbol_path(symbol.children, line, char, path)
			return true
		end
	end
	return false
end

local function lsp_callback(err, symbols, ctx, config)
	if err or not symbols then
		vim.o.winbar = ""
		return
	end

	local winnr = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(0)
	local cursor_line = pos[1] - 1
	local cursor_char = pos[2]

	local file_path = vim.fn.bufname(ctx.bufnr)
	if not file_path or file_path == "" then
		vim.o.winbar = "[No Name]"
		return
	end

	local relative_path

	local clients = vim.lsp.get_clients({ bufnr = ctx.bufnr })

	if #clients > 0 and clients[1].root_dir then
		local root_dir = clients[1].root_dir
		if root_dir == nil then
			relative_path = file_path
		else
			relative_path = vim.fs.relpath(root_dir, file_path)
		end
	else
		local root_dir = vim.fn.getcwd(0)
		relative_path = vim.fs.relpath(root_dir, file_path)
	end

	local breadcrumbs = {}

	local path_components = vim.split(relative_path or "", "[/\\]", { trimempty = true })
	local num_components = #path_components

	for i, component in ipairs(path_components) do
		if i == num_components then
			local icon
			local icon_hl

			if devicons_ok then
				icon, icon_hl = devicons.get_icon(component)
			end
			table.insert(breadcrumbs, "%#" .. icon_hl .. "#" .. (icon or file_icon) .. "%#Normal#" .. " " .. component)
		else
			table.insert(breadcrumbs, folder_icon .. " " .. component)
		end
	end
	find_symbol_path(symbols, cursor_line, cursor_char, breadcrumbs)

	local breadcrumb_string = table.concat(breadcrumbs, "%#Comment#  %#Normal#")

	if breadcrumb_string ~= "" then
		vim.api.nvim_set_option_value("winbar", breadcrumb_string, { win = winnr })
	else
		vim.api.nvim_set_option_value("winbar", " ", { win = winnr })
	end
end

local disabled = {
	["trouble"] = true,
	["toggleterm"] = true,
	["terminal"] = true,
	["qf"] = true,
	["noice"] = true,
	["dap-view"] = true,
	["dap-view-term"] = true,
	["dap-repl"] = true,
	["neocomposer-menu"] = true,
}

local function breadcrumbs_set()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype
	if disabled[filetype] or not vim.bo[bufnr].buflisted then
		vim.o.winbar = ""
		return
	end

	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	if #clients == 0 then
		return
	elseif not clients[1]:supports_method("textDocument/documentSymbol", bufnr) then
		return
	end

	---@type string
	local uri = vim.lsp.util.make_text_document_params(bufnr)["uri"]
	if not uri then
		vim.print("Error: Could not get URI for buffer. Is it saved?")
		return
	end

	local params = {
		textDocument = {
			uri = uri,
		},
	}

	local buf_src = uri:sub(1, uri:find(":") - 1)
	if buf_src ~= "file" then
		vim.o.winbar = ""
		return
	end

	local result, _ = pcall(vim.lsp.buf_request, bufnr, "textDocument/documentSymbol", params, lsp_callback)
	if not result then
		return
	end
end

local breadcrumbs_augroup = vim.api.nvim_create_augroup("Breadcrumbs", { clear = true })

-- Old enable method
-- local enable = function(buf, win)
-- 	local filetype = vim.bo[buf].filetype
-- 	local disabled = {
-- 		["oil"] = true,
-- 		["trouble"] = true,
-- 		["qf"] = true,
-- 		["noice"] = true,
-- 		["dap-view"] = true,
-- 		["dap-view-term"] = true,
-- 		["dap-repl"] = true,
-- 		["neocomposer-menu"] = true,
-- 	}
-- 	if disabled[filetype] then
-- 		return false
-- 	end
-- 	if vim.api.nvim_win_get_config(win).zindex ~= nil then
-- 		return vim.bo[buf].buftype == "terminal" and vim.bo[buf].filetype == "terminal"
-- 	end
-- 	return vim.bo[buf].buflisted == true and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
-- end

vim.api.nvim_create_autocmd({ "CursorMoved" }, {
	group = breadcrumbs_augroup,
	callback = breadcrumbs_set,
	desc = "Set breadcrumbs.",
})

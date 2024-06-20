local edgy_filetypes = {
	"neotest-output-panel",
	"neotest-summary",
	"noice",
	"trouble",
	"OverseerList",
}

local edgy_titles = {
	["neotest-output-panel"] = "neotest",
	["neotest-summary"] = "neotest",
	noice = "noice",
	trouble = "trouble",
	OverseerList = "overseer",
}
local function is_edgy_group(props)
	return vim.tbl_contains(edgy_filetypes, vim.bo[props.buf].filetype)
end

local function get_title(props)
	local title = " " .. edgy_titles[vim.bo[props.buf].filetype] .. " "
	return { { title, group = props.focused and "FloatTitle" or "Title" } }
end

require("incline").setup({
	window = {
		zindex = 30,
	},
	ignore = {
		buftypes = {},
		filetypes = { "toggleterm" },
		unlisted_buffers = false,
	},
	render = function(props)
		if is_edgy_group(props) then
			return get_title(props)
		else
			local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
			local ft_icon, ft_color = require("nvim-web-devicons").get_icon_color(filename)
			local modified = vim.bo[props.buf].modified and "bold,italic" or "bold"

			local function get_git_diff()
				local icons = { removed = "", changed = "", added = "" }
				icons["changed"] = icons.modified
				local signs = vim.b[props.buf].gitsigns_status_dict
				local labels = {}
				if signs == nil then
					return labels
				end
				for name, icon in pairs(icons) do
					if tonumber(signs[name]) and signs[name] > 0 then
						table.insert(labels, { icon .. signs[name] .. " ", group = "Diff" .. name })
					end
				end
				if #labels > 0 then
					table.insert(labels, { "┊ " })
				end
				return labels
			end

			local function get_diagnostic_label()
				local icons = { error = "", warn = "", info = "", hint = "" }
				local label = {}

				for severity, icon in pairs(icons) do
					local n =
						#vim.diagnostic.get(props.buf, { severity = vim.diagnostic.severity[string.upper(severity)] })
					if n > 0 then
						table.insert(label, { icon .. n .. " ", group = "DiagnosticSign" .. severity })
					end
				end
				if #label > 0 then
					table.insert(label, { "┊ " })
				end
				return label
			end

			local buffer = {
				{ get_diagnostic_label() },
				{ get_git_diff() },
				{ (ft_icon or "") .. " ", guifg = ft_color, guibg = "none" },
				{ filename .. " ", gui = modified },
			}
			return buffer
		end
	end,
})

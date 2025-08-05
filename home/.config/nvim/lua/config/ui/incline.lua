local special_filetypes = {
	"neotest-output-panel",
	"neotest-summary",
	"noice",
	"trouble",
	"OverseerList",
}

local special_ft_titles = {
	["neotest-output-panel"] = "neotest",
	["neotest-summary"] = "neotest",
	noice = "noice",
	trouble = "trouble",
	OverseerList = "overseer",
}
local function is_special_group(props)
	return vim.tbl_contains(special_filetypes, vim.bo[props.buf].filetype)
end

local function get_title(props)
	local title = " " .. special_ft_titles[vim.bo[props.buf].filetype] .. " "
	return { { title, group = props.focused and "FloatTitle" or "Title" } }
end

require("incline").setup(
	---@module 'incline'
	{
		window = {
			zindex = 30,
		},
		hide = {
			cursorline = "focused_win",
		},
		debounce_threshold = {
			falling = 50,
			rising = 50,
		},
		ignore = {
			buftypes = {},
			filetypes = { "toggleterm" },
			unlisted_buffers = false,
		},
		render = function(props)
			if is_special_group(props) then
				return get_title(props)
			else
				local unhelpfuls =
					{ "init.lua", "index.tsx", "index.ts", "index.js", "index.jsx", "__init__.py", "+page.svelte" }
				local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
				if require("user.utils").contains(filename, unhelpfuls) then
					local full_path = vim.api.nvim_buf_get_name(props.buf)
					filename = vim.fn.fnamemodify(full_path, ":h:t") .. "/" .. vim.fn.fnamemodify(full_path, ":t")
				end
				local ft_icon, ft_color = require("nvim-web-devicons").get_icon_color(filename)
				local modified = vim.bo[props.buf].modified and "bold,italic" or "bold"

				local function get_git_diff()
					local icons = { delete = "", change = "", add = "" }
					local labels = {}
					local buf_data = require("mini.diff").get_buf_data(props.buf)

					if buf_data == nil then
						return labels
					end

					local hunks = buf_data.hunks

					if hunks == nil then
						return labels
					end

					local diffs = { delete = 0, change = 0, add = 0 }

					for _, hunk in ipairs(hunks) do
						diffs[hunk.type] = hunk.type == "delete" and diffs[hunk.type] + hunk.ref_count
							or diffs[hunk.type] + hunk.buf_count
					end

					for name, icon in pairs(icons) do
						if diffs[name] > 0 then
							table.insert(
								labels,
								{ icon .. diffs[name] .. " ", group = "MiniDiffSign" .. name:gsub("^%l", string.upper) }
							)
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
						local n = #vim.diagnostic.get(
							props.buf,
							{ severity = vim.diagnostic.severity[string.upper(severity)] }
						)
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
	}
)

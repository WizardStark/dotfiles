local function get_lsp_completion_context(completion)
	local ok, source_name = pcall(function()
		return vim.lsp.get_client_by_id(completion.client_id).name
	end)

	if not ok then
		return nil
	end

	if source_name == "basedpyright" and completion.labelDetails ~= nil then
		return completion.labelDetails.description
	elseif source_name == "clangd" then
		local doc = completion.documentation
		if doc == nil then
			return
		end

		local import_str = doc.value
		import_str = import_str:gsub("[\n]+", "")

		local str
		str = import_str:match("<(.-)>")
		if str then
			return "<" .. str .. ">"
		end

		str = import_str:match("[\"'](.-)[\"']")
		if str then
			return '"' .. str .. '"'
		end

		return nil
	elseif source_name == "jdtls" then
		return nil
	else
		return completion.detail
	end
end

---@param ctx blink.cmp.CompletionRenderContext
---@return blink.cmp.Component
local function render_item(ctx)
	local cmp_ctx
	if ctx.item.source_id == "lsp" then
		cmp_ctx = get_lsp_completion_context(ctx.item)

		if cmp_ctx == nil then
			cmp_ctx = ""
		end
	end

	local map = {
		["lsp"] = "[]",
		["path"] = "[󰉋]",
		["snippets"] = "[]",
	}
	return {
		{ " " .. ctx.kind_icon, hl_group = "BlinkCmpKind" .. ctx.kind },
		{
			" " .. ctx.item.label,
			fill = true,
			-- hl_group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "BlinkCmpLabel",
		},
		{
			string.format("%6s ", map[ctx.item.source_id] or ""),
			hl_group = "BlinkCmpSource",
		},
		{
			cmp_ctx,
		},
	}
end

require("blink.cmp").setup({
	highlight = {
		use_nvim_cmp_as_default = true,
	},
	nerd_font_variant = "mono",
	accept = { auto_brackets = { enabled = true } },
	trigger = {
		keyword_range = "full",
		signature_help = { enabled = true },
	},
	keymap = {
		preset = "enter",
		["<Tab>"] = {
			function(cmp)
				if cmp.is_in_snippet() then
					return cmp.accept()
				else
					return require("blink.cmp").select_next()
				end
			end,
			"snippet_forward",
			"fallback",
		},
		["<S-Tab>"] = {
			"select_prev",
			"snippet_forward",
			"fallback",
		},
	},
	windows = {
		autocomplete = {
			min_width = 20,
			max_width = 60,
			max_height = 10,
			border = "rounded",
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
			scrolloff = 2,
			direction_priority = { "s", "n" },
			draw = render_item,
			selection = "auto_insert",
		},
		documentation = {
			min_width = 10,
			max_width = math.min(80, vim.o.columns),
			max_height = 20,
			border = "rounded",
			winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
			direction_priority = {
				autocomplete_north = { "e", "w", "n", "s" },
				autocomplete_south = { "e", "w", "s", "n" },
			},
			auto_show = true,
			auto_show_delay_ms = 100,
			update_delay_ms = 10,
		},
		signature_help = {
			min_width = 1,
			max_width = 100,
			max_height = 10,
			border = "rounded",
			winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
		},
	},
	kind_icons = {
		Snippet = "",
	},
})

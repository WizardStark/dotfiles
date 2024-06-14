require("luasnip").setup({
	load_ft_func = require("luasnip_snippets.common.snip_utils").load_ft_func,
	ft_func = require("luasnip_snippets.common.snip_utils").ft_func,
	enable_autosnippets = true,
	history = true,
	updateevents = "TextChanged,TextChangedI",
})
require("luasnip/loaders/from_vscode").lazy_load()
require("luasnip_snippets.common.snip_utils").setup()

local luasnip = require("luasnip")
local lspkind = require("lspkind")
local cmp = require("cmp")
local window_scroll_bordered = cmp.config.window.bordered({
	scrolloff = 3,
	scrollbar = true,
})

local function tab(fallback)
	if cmp.visible() then
		cmp.select_next_item()
	elseif luasnip.expand_or_jumpable() then
		luasnip.expand_or_jump()
	else
		fallback()
	end
end

local function shift_tab(fallback)
	if cmp.visible() then
		cmp.select_prev_item()
	elseif luasnip.jumpable(-1) then
		luasnip.jump(-1)
	else
		fallback()
	end
end

local function down(fallback)
	if cmp.visible() then
		cmp.select_next_item()
	else
		fallback()
	end
end

local function up(fallback)
	if cmp.visible() then
		cmp.select_prev_item()
	else
		fallback()
	end
end

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	mapping = {
		["<Tab>"] = cmp.mapping(tab, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(shift_tab, { "i", "s" }),
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
		["<CR>"] = cmp.mapping.confirm({
			select = false,
		}),
		["<C-a>"] = cmp.mapping.confirm({
			select = false,
		}),
		["<C-t>"] = cmp.mapping(up, { "i", "s" }),
		["<C-n>"] = cmp.mapping(down, { "i", "s" }),
		["<Up>"] = cmp.mapping(up, { "i", "s" }),
		["<Down>"] = cmp.mapping(down, { "i", "s" }),
	},
	window = {
		documentation = window_scroll_bordered,
		completion = window_scroll_bordered,
	},
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{
			name = "lazydev",
			group_index = 0, -- set group index to 0 to skip loading LuaLS completions
		},
		{ name = "luasnip" },
		{ name = "path" },
		{ name = "calc" },
		{ name = "nvim_lsp_signature_help" },
		{
			name = "spell",
			option = {
				keep_all_entries = true,
				enable_in_context = function()
					return true
				end,
			},
		},
	}, {
		{ name = "buffer" },
	}),
	formatting = {
		fields = { "kind", "abbr", "menu" },
		format = function(entry, vim_item)
			local kind = lspkind.cmp_format({
				mode = "symbol_text",
				maxwidth = 50,
			})(entry, vim_item)
			local strings = vim.split(kind.kind, "%s", { trimempty = true })
			kind.kind = " " .. (strings[1] or "") .. " "
			kind.menu = "    (" .. (strings[2] or "") .. ")"
			return kind
		end,
	},
})
-- `/` cmdline setup.
cmp.setup.cmdline("/", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})
-- `:` cmdline setup.
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{
			name = "cmdline",
			option = {
				ignore_cmds = { "Man", "!" },
			},
		},
	}),
})

local uv = vim.uv or vim.loop

local M = {}

local state = {
	specs = {},
	order = {},
	loaded = {},
}

local augroup = vim.api.nvim_create_augroup("UserPack", { clear = true })

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "vim.pack" })
end

local function spec_name(src)
	return src:gsub("%.git$", ""):match("/([^/]+)$")
end

local function spec_batch(spec)
	if spec.priority then
		return "startup"
	end
	if spec.event == "UiEnter" or spec.event == "UIEnter" then
		return "ui_enter"
	end
	return "post_ui"
end

local function normalize_spec(raw)
	if raw.enabled == false then
		return nil
	end

	if type(raw.enabled) == "function" then
		local ok, result = pcall(raw.enabled)
		if not ok then
			notify("Failed to evaluate enabled() for " .. tostring(raw.name or raw.src), vim.log.levels.ERROR)
			return nil
		end
		if not result then
			return nil
		end
	end

	if type(raw.src) ~= "string" or raw.src == "" then
		return nil
	end

	local spec = vim.tbl_extend("force", raw, {
		name = raw.name or spec_name(raw.src),
		batch = spec_batch(raw),
		dependencies = {},
	})

	spec.version = raw.version

	return spec
end

local function merge_spec(existing, incoming)
	for key, value in pairs(incoming) do
		if key ~= "dependencies" and value ~= nil then
			existing[key] = value
		end
	end
	return existing
end

local function import_modules(import_name)
	local config_path = vim.fn.stdpath("config")
	local root = config_path .. "/lua/" .. import_name:gsub("%.", "/")

	if uv.fs_stat(root .. ".lua") then
		return { import_name }
	end

	if not uv.fs_stat(root) then
		return {}
	end

	local modules = {}
	for entry, entry_type in vim.fs.dir(root) do
		if entry_type == "file" and entry:sub(-4) == ".lua" and entry ~= "init.lua" then
			table.insert(modules, import_name .. "." .. entry:sub(1, -5))
		end
	end

	table.sort(modules)
	return modules
end

local function register_spec(raw)
	local spec = normalize_spec(raw)
	if not spec then
		return
	end

	local existing = state.specs[spec.name]
		and merge_spec(state.specs[spec.name], spec)
		or spec

	if not state.specs[spec.name] then
		state.specs[spec.name] = existing
		table.insert(state.order, spec.name)
	else
		state.specs[spec.name] = existing
	end

	for _, dependency in ipairs(raw.dependencies or {}) do
		register_spec(dependency)
		local dep_spec = normalize_spec(dependency)
		if dep_spec then
			table.insert(existing.dependencies, dep_spec.name)
		end
	end
end

local function register_import(import_name)
	for _, module_name in ipairs(import_modules(import_name)) do
		local ok, imported = pcall(require, module_name)
		if ok then
			for _, spec in ipairs(imported) do
				register_spec(spec)
			end
		else
			notify("Failed to import " .. module_name .. ":\n" .. tostring(imported), vim.log.levels.ERROR)
		end
	end
end

local function install_specs()
	local specs = {}
	for _, name in ipairs(state.order) do
		local spec = state.specs[name]
		local pack_spec = {
			name = spec.name,
			src = spec.src,
		}
		if spec.version ~= nil then
			pack_spec.version = spec.version
		end
		table.insert(specs, pack_spec)
	end

	vim.pack.add(specs, { load = false, confirm = false })
end

local function run_init()
	for _, name in ipairs(state.order) do
		local init = state.specs[name].init
		if type(init) == "function" then
			local ok, err = pcall(init)
			if not ok then
				notify("Failed to run init() for " .. name .. ":\n" .. tostring(err), vim.log.levels.ERROR)
			end
		end
	end
end

local function run_build(spec)
	if type(spec.build) == "string" and vim.startswith(spec.build, ":") then
		pcall(vim.cmd, spec.build:sub(2))
	elseif type(spec.build) == "function" then
		pcall(spec.build)
	end
end

local function load_plugin(name)
	local spec = state.specs[name]
	if not spec or state.loaded[name] then
		return
	end

	for _, dependency_name in ipairs(spec.dependencies) do
		load_plugin(dependency_name)
	end

	local command = (spec.packadd_bang and "packadd! " or "packadd ") .. spec.name
	local ok, err = pcall(vim.cmd, command)
	if not ok then
		notify("Failed to load " .. spec.name .. ":\n" .. tostring(err), vim.log.levels.ERROR)
		return
	end

	state.loaded[name] = true

	if type(spec.config) == "function" then
		local config_ok, config_err = pcall(spec.config)
		if not config_ok then
			notify("Failed to configure " .. spec.name .. ":\n" .. tostring(config_err), vim.log.levels.ERROR)
		end
	end

	run_build(spec)
end

local function load_batch(batch)
	for _, name in ipairs(state.order) do
		if state.specs[name].batch == batch then
			load_plugin(name)
		end
	end
end

local function create_pack_commands()
	vim.api.nvim_create_user_command("PackDelete", function()
		local packages = vim.pack.get()
		local items = vim.tbl_map(function(pkg)
			return pkg.spec.name
		end, packages)

		vim.ui.select(items, {
			prompt = "Delete package:",
			format_item = function(item)
				return item
			end,
		}, function(choice)
			if not choice then
				return
			end

			local ok, err = pcall(vim.pack.del, { choice })
			if ok then
				vim.notify("Deleted: " .. choice, vim.log.levels.INFO, { title = "Package manager" })
			else
				vim.notify("Failed to delete: " .. choice .. "\n" .. tostring(err), vim.log.levels.ERROR, {
					title = "Package manager",
				})
			end
		end)
	end, {})

	vim.api.nvim_create_user_command("PackUpdate", function()
		vim.pack.update(nil, { force = true })
	end, {})
end

local function setup_batches()
	vim.api.nvim_create_autocmd("UIEnter", {
		group = augroup,
		once = true,
		callback = function()
			load_batch("ui_enter")
			vim.schedule(function()
				load_batch("post_ui")
				vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
			end)
		end,
	})
end

function M.setup(opts)
	for _, spec in ipairs(opts.spec or {}) do
		if spec.import then
			register_import(spec.import)
		else
			register_spec(spec)
		end
	end

	run_init()
	install_specs()
	create_pack_commands()
	load_batch("startup")
	setup_batches()
end

return M

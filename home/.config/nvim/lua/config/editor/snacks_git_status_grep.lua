local uv = vim.uv or vim.loop

local MATCH_SEP = "󰄊󱥳󱥰"

local M = {}

local function git(args, cwd)
	local result = vim.system(args, { cwd = cwd }):wait()
	if result.code ~= 0 then
		return nil, vim.trim(result.stderr or table.concat(args, " ") .. " failed")
	end
	return result.stdout or ""
end

local function unquote_git_path(path)
	if not path:match('^".*"$') then
		return path
	end

	local ret = {}
	local i = 2
	while i < #path do
		local char = path:sub(i, i)
		if char ~= "\\" then
			ret[#ret + 1] = char
			i = i + 1
		else
			local next_char = path:sub(i + 1, i + 1)
			local escaped = ({
				a = "\a",
				b = "\b",
				f = "\f",
				n = "\n",
				r = "\r",
				t = "\t",
				v = "\v",
				["\\"] = "\\",
				['"'] = '"',
			})[next_char]
			if escaped then
				ret[#ret + 1] = escaped
				i = i + 2
			else
				local octal = path:match("^([0-7][0-7][0-7])", i + 1)
				if octal then
					ret[#ret + 1] = string.char(tonumber(octal, 8))
					i = i + 4
				else
					ret[#ret + 1] = next_char
					i = i + 2
				end
			end
		end
	end
	return table.concat(ret)
end

local function ensure_spec(specs, file)
	local spec = specs[file]
	if not spec then
		spec = { file = file, full = false, ranges = {} }
		specs[file] = spec
	end
	return spec
end

local function add_range(specs, file, first, last)
	if first > last then
		return
	end
	local spec = ensure_spec(specs, file)
	spec.ranges[#spec.ranges + 1] = { first, last }
end

local function normalize_ranges(spec)
	if spec.full or #spec.ranges <= 1 then
		return
	end

	table.sort(spec.ranges, function(a, b)
		if a[1] == b[1] then
			return a[2] < b[2]
		end
		return a[1] < b[1]
	end)

	local merged = { spec.ranges[1] }
	for i = 2, #spec.ranges do
		local current = spec.ranges[i]
		local previous = merged[#merged]
		if current[1] <= previous[2] + 1 then
			previous[2] = math.max(previous[2], current[2])
		else
			merged[#merged + 1] = current
		end
	end
	spec.ranges = merged
end

local function parse_status(specs, cwd, all_files)
	local stdout, err = git({
		"git",
		"-c",
		"core.quotePath=false",
		"status",
		"-uall",
		"--porcelain=v1",
		"-z",
	}, cwd)
	if not stdout then
		return nil, err
	end

	local renamed
	for _, entry in ipairs(vim.split(stdout, "\0", { plain = true, trimempty = true })) do
		local status, file = entry:match("^(..) (.+)$")
		if status and file then
			renamed = status:find("R", 1, true) and status or nil
			if (all_files or status == "??") and uv.fs_stat(cwd .. "/" .. file) then
				ensure_spec(specs, file).full = true
			end
		elseif renamed then
			renamed = nil
		end
	end

	return true
end

local function has_head(cwd)
	return vim.system({ "git", "rev-parse", "--verify", "HEAD" }, { cwd = cwd }):wait().code == 0
end

local function parse_diff(specs, cwd)
	local stdout, err = git({
		"git",
		"-c",
		"core.quotePath=false",
		"diff",
		"HEAD",
		"--no-color",
		"--no-ext-diff",
		"--find-renames",
		"-U0",
	}, cwd)
	if not stdout then
		return nil, err
	end

	local file
	for _, line in ipairs(vim.split(stdout, "\n", { plain = true })) do
		local next_file = line:match("^%+%+%+ (.+)$")
		if next_file then
			next_file = unquote_git_path(next_file)
			file = next_file ~= "/dev/null" and next_file:gsub("^b/", "", 1) or nil
		else
			local start, count = line:match("^@@ %-%d+,?%d* %+([0-9]+),?([0-9]*) @@")
			if file and start then
				start = tonumber(start)
				count = tonumber(count ~= "" and count or "1")
				if count > 0 then
					add_range(specs, file, start, start + count - 1)
				end
			end
		end
	end

	return true
end

local function line_allowed(spec, line)
	if not spec then
		return false
	end
	if spec.full then
		return true
	end
	for _, range in ipairs(spec.ranges) do
		if line < range[1] then
			return false
		end
		if line <= range[2] then
			return true
		end
	end
	return false
end

local function get_state(opts, ctx)
	if not opts._git_status_grep_state then
		local base = opts.cwd or uv.cwd()
		local cwd = base and Snacks.git.get_root(base) or nil
		local state = {
			cwd = cwd,
			specs = {},
			files = {},
		}

		if not cwd then
			state.error = "Not in a git repository"
		else
			local ok, err = parse_status(state.specs, cwd, false)
			if ok then
				if has_head(cwd) then
					ok, err = parse_diff(state.specs, cwd)
				else
					ok, err = parse_status(state.specs, cwd, true)
				end
			end
			if not ok then
				state.error = err
			else
				for file, spec in pairs(state.specs) do
					normalize_ranges(spec)
					if spec.full or #spec.ranges > 0 then
						if uv.fs_stat(cwd .. "/" .. file) then
							state.files[#state.files + 1] = file
						else
							state.specs[file] = nil
						end
					else
						state.specs[file] = nil
					end
				end
				table.sort(state.files)
			end
		end

		opts._git_status_grep_state = state
	end

	local state = opts._git_status_grep_state
	if state.cwd then
		ctx.picker:set_cwd(state.cwd)
	end
	return state
end

function M.finder(opts, ctx)
	if opts.need_search ~= false and ctx.filter.search == "" then
		return function() end
	end

	local state = get_state(opts, ctx)
	if state.error then
		if not opts._git_status_grep_notified then
			opts._git_status_grep_notified = true
			Snacks.notify.warn(state.error)
		end
		return function() end
	end
	if #state.files == 0 then
		if not opts._git_status_grep_notified then
			opts._git_status_grep_notified = true
			Snacks.notify.info("No changed lines to grep")
		end
		return function() end
	end

	local args = require("snacks.picker.source.git").git("grep", "--line-number", "--column", "--no-color", "-I", opts)
	if opts.untracked then
		table.insert(args, "--untracked")
	elseif opts.submodules then
		table.insert(args, "--recurse-submodules")
	end
	if opts.ignorecase then
		table.insert(args, "-i")
	end

	local pattern = Snacks.picker.util.parse(ctx.filter.search)
	table.insert(args, pattern)
	args[#args + 1] = "--"
	vim.list_extend(args, state.files)

	return require("snacks.picker.source.proc").proc(
		ctx:opts({
			cmd = "git",
			cwd = state.cwd,
			args = args,
			notify = false,
			---@param item snacks.picker.finder.Item
			transform = function(item)
				item.cwd = state.cwd
				local file, line, col, text = item.text:match("^(.+):(%d+):(%d+):(.*)$")
				if not file then
					if not item.text:match("WARNING") then
						Snacks.notify.error("invalid grep output:\n" .. item.text)
					end
					return false
				end

				line = tonumber(line)
				if not line_allowed(state.specs[file], line) then
					return false
				end

				item.file = file
				item.pos = { line, tonumber(col) - 1 }
				item.text = string.format("%s:%d:%s:%s", file, line, col, text:gsub(MATCH_SEP, ""))
				item.resolve = function()
					local positions = {} ---@type number[]
					local from = tonumber(col)
					local offset = 0
					local in_match = false
					while from < #text do
						local idx = text:find(MATCH_SEP, from, true)
						if not idx then
							break
						end
						if in_match then
							for i = from, idx - 1 do
								positions[#positions + 1] = i - offset
							end
							item.end_pos = item.end_pos or { item.pos[1], idx - offset - 1 }
						end
						in_match = not in_match
						offset = offset + #MATCH_SEP
						from = idx + #MATCH_SEP
					end
					item.positions = #positions > 0 and positions or nil
					item.line = text:gsub(MATCH_SEP, "")
				end
			end,
		}),
		ctx
	)
end

return M

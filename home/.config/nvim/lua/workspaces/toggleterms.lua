local M = {}

local Terminal = require("toggleterm.terminal").Terminal
local state = require("workspaces.state")
require("toggleterm")

function M.get_session_terms()
	return state.get().current_session.toggleterms
end

---@param session_terms SessionTerminal[]
---@param local_id number
local function find_term_by_local_id(session_terms, local_id)
	for i, v in ipairs(session_terms) do
		if v.local_id == local_id then
			return { i, v }
		end
	end

	return nil
end

---@param session_terms SessionTerminal[]
---@param global_id number
function M.find_term_by_global_id(session_terms, global_id)
	for i, v in ipairs(session_terms) do
		if v.global_id == global_id then
			return { i, v }
		end
	end

	return nil
end

function M.delete_term(local_id)
	local toggleterms = M.get_session_terms()
	local target_term = find_term_by_local_id(toggleterms, local_id)
	if target_term then
		table.remove(toggleterms, target_term[1])
		state.get().current_session.toggleterms = toggleterms
	end
end

function M.has_visible_terms()
	local toggleterms = M.get_session_terms()

	for _, v in ipairs(toggleterms) do
		if v.should_display then
			return true
		end
	end

	return false
end

---@param target_term SessionTerminal
---@return number
local function get_term_size(target_term)
	local terms = require("toggleterm.terminal").get_all()
	local size

	for _, term in ipairs(terms) do
		if term.id == target_term.global_id then
			if target_term.term_direction == "horizontal" then
				size = vim.api.nvim_win_get_height(term.window)
			else
				size = vim.api.nvim_win_get_width(term.window)
			end
		end
	end

	return size
end

function M.get_largest_visible_term_size()
	local toggleterms = M.get_session_terms()
	local max_size = 0

	for _, v in ipairs(toggleterms) do
		if v.should_display then
			local ok, window_size = pcall(get_term_size, v)
			if ok and window_size then
				max_size = window_size > max_size and window_size or max_size
			end
		end
	end

	return max_size
end

---@param term SessionTerminal
---@param override_active boolean
---@param size number | nil
local function toggle_term(term, override_active, size)
	local has_visible_terms = M.has_visible_terms()
	if not size then
		if term.should_display then
			local ok, term_size = pcall(get_term_size, term)
			if ok and term_size then
				term.size = term_size
			end
		end

		if has_visible_terms then
			term.size = M.get_largest_visible_term_size()
		end
	else
		term.size = size
	end

	Terminal:new({
		count = term.global_id,
		direction = term.term_direction,
		size = term.size,
	}):toggle()

	if not has_visible_terms and term.term_pos == "left" and term.should_display == false then
		vim.cmd("wincmd H")
		vim.cmd("vert res " .. term.size)
	end

	term.should_display = not term.should_display

	if not override_active then
		term.active = not term.active
	end
end

---@param local_id number
---@param direction string | nil
---@param size number | nil
---@param term_pos string | nil
function M.toggle_term(local_id, direction, size, term_pos)
	local default_direction = "vertical"
	local default_size
	local default_pos

	if direction and direction == "horizontal" then
		default_size = vim.fn.min({ 20, vim.fn.round(vim.api.nvim_win_get_height(0) * 0.3) })
		default_pos = "bottom"
	else
		default_size = vim.fn.min({ 120, vim.fn.round(vim.api.nvim_win_get_width(0) * 0.4) })
		default_pos = "left"
	end

	if vim.g.workspaces_loaded then
		local toggleterms = M.get_session_terms()

		local target_term = find_term_by_local_id(toggleterms, local_id)

		if not target_term then
			state.get().term_count = state.get().term_count + 1

			---@type SessionTerminal
			local new_term = {
				term_direction = direction or default_direction,
				size = size or default_size,
				local_id = local_id,
				global_id = state.get().term_count,
				active = false,
				should_display = false,
				term_pos = term_pos or default_pos,
			}

			target_term = new_term
			table.insert(toggleterms, target_term)
		else
			target_term = target_term[2]
			target_term.term_pos = term_pos or target_term.term_pos or default_pos
			target_term.term_direction = direction or target_term.term_direction or default_direction
			target_term.size = size or target_term.size or default_size
		end

		toggle_term(target_term, false, nil)

		table.sort(toggleterms, function(a, b)
			return a.local_id < b.local_id
		end)

		state.get().current_session.toggleterms = toggleterms
	else
		vim.cmd(
			":" .. local_id .. "ToggleTerm direction=" .. direction
				or default_direction .. " size=" .. size
				or default_size
		)
	end
end

---toggle all terms that should be visible
---@param override_active boolean
function M.close_visible_terms(override_active)
	local toggleterms = M.get_session_terms()
	local first_term = true
	local size

	for _, v in ipairs(toggleterms) do
		if v.active and v.should_display then
			if first_term then
				size = get_term_size(v)
				first_term = false
			end

			toggle_term(v, override_active, size)
		end
	end
end

---toggle all terms that should be visible
---@param override_active boolean
function M.toggle_active_terms(override_active)
	local toggleterms = M.get_session_terms()
	local first_term = true
	local size

	for _, v in ipairs(toggleterms) do
		if v.active then
			if v.should_display then
				-- going from displayed to hidden
				toggle_term(v, override_active, nil)
			else
				if first_term then
					toggle_term(v, override_active, nil)
					size = get_term_size(v)
					if v.term_pos == "left" then
						vim.cmd("wincmd H")
						vim.cmd("vert res " .. v.size)
					end
					first_term = false
				else
					toggle_term(v, override_active, size)
				end
			end
		end
	end
end

return M

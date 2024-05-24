local M = {}

local state = require("workspaces.state")
require("toggleterm")

---@param session_terms SessionTerminal[]
---@param id number
local function find_term(session_terms, id)
	for i, v in ipairs(session_terms) do
		if v.local_id == id then
			return { i, v }
		end
	end

	return nil
end

function M.delete_term(local_id)
	local toggleterms = state.get().current_session.toggleterms
	local target_term = find_term(toggleterms, local_id)
	if target_term then
		table.remove(toggleterms, target_term[1])
		state.get().current_session.toggleterms = toggleterms
	end
end

---@param term SessionTerminal
---@param override_visible boolean
local function toggle_term(term, override_visible)
	vim.cmd(":" .. term.global_id .. "ToggleTerm direction=" .. term.term_direction .. " size=" .. term.size)
	if term.term_pos == "left" and term.visible and not override_visible then
		vim.cmd("wincmd H")
		vim.cmd("vert res " .. term.size)
	end
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

---@param local_id number
---@param direction string | nil
---@param size number | nil
---@param term_pos string | nil
function M.toggle_term(local_id, direction, size, term_pos)
	if vim.g.workspaces_loaded then
		local toggleterms = state.get().current_session.toggleterms
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

		local target_term = find_term(toggleterms, local_id)

		if not target_term then
			state.get().term_count = state.get().term_count + 1

			---@type SessionTerminal
			local new_term = {
				term_direction = direction or default_direction,
				size = size or default_size,
				local_id = local_id,
				global_id = state.get().term_count,
				visible = false,
				term_pos = term_pos or default_pos,
			}

			target_term = new_term
			table.insert(toggleterms, target_term)
		else
			target_term = target_term[2]
			target_term.term_pos = term_pos or target_term.term_pos
			target_term.term_direction = direction or target_term.term_direction
			target_term.size = size or target_term.size
		end

		if target_term.visible then
			target_term.size = get_term_size(target_term)
		end

		target_term.visible = not target_term.visible
		toggle_term(target_term, false)

		state.get().current_session.toggleterms = toggleterms
	else
		vim.cmd(":" .. local_id .. "ToggleTerm direction=" .. direction .. " size=" .. size)
	end
end

---toggle all terms that should be visible
---@param override_visible boolean
function M.toggle_visible_terms(override_visible)
	local toggleterms = state.get().current_session.toggleterms

	for _, v in ipairs(toggleterms) do
		if v.visible then
			toggle_term(v, override_visible)
		end
	end
end

function M.get_session_terms()
	return state.get().current_session.toggleterms
end

return M

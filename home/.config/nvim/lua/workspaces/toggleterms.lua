local M = {}

local state = require("workspaces.state")
require("toggleterm")

---@param session_terms SessionTerminal[]
---@param id number
local function find_term(session_terms, id)
	for _, v in ipairs(session_terms) do
		if v.local_id == id then
			return v
		end
	end

	return nil
end

---comment
---@param term SessionTerminal
---@param override_visible boolean
local function toggle_term(term, override_visible)
	vim.cmd(":" .. term.global_id .. "ToggleTerm direction=" .. term.term_direction .. " size=" .. term.size)
	if term.term_pos == "left" and term.visible and not override_visible then
		vim.cmd("wincmd H")
		vim.cmd("vert res " .. term.size)
	end
end

---comment
---@param local_id number
---@param direction string
---@param size number
---@param term_pos string
function M.toggle_term(local_id, direction, size, term_pos)
	local toggleterms = state.get().current_session.toggleterms

	local target_term = find_term(toggleterms, local_id)

	if not target_term then
		state.get().term_count = state.get().term_count + 1

		---@type SessionTerminal
		local new_term = {
			term_direction = direction,
			size = size,
			local_id = local_id,
			global_id = state.get().term_count,
			visible = false,
			term_pos = term_pos,
		}

		target_term = new_term
		table.insert(toggleterms, target_term)
	else
		target_term.term_pos = term_pos
		target_term.term_direction = direction
		target_term.size = size
	end

	target_term.visible = not target_term.visible
	toggle_term(target_term, false)

	state.get().current_session.toggleterms = toggleterms
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

local M = {}

local state = require("workspaces.state")

local function get_term_target()
	local target
	if next(vim.fn.argv()) ~= nil then
		target = "toggleterm"
	else
		target = state.get().current_workspace.name .. state.get().current_workspace.current_session_name
	end

	return target
end

function M.toggle_term(number, direction, size)
	local target = get_term_target()
	local toggleterms = state.get().toggleterms

	if not toggleterms[target] then
		toggleterms[target] = {}
	end

	if not toggleterms[target][number] then
		state.set("term_count", state.get().term_count + 1)
		toggleterms[target][number] = state.get().term_count
	end

	state.set("toggleterms", toggleterms)

	local target_term = toggleterms[target][number]

	vim.cmd(":" .. target_term .. "ToggleTerm direction=" .. direction .. " size=" .. size)
end

function M.get_session_terms()
	return state.get().toggleterms[get_term_target()]
end

return M

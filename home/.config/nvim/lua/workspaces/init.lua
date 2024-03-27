local M = {}

local function load_module(module_name)
	local module = require(module_name)
	for k, v in pairs(module) do
		M[k] = v
	end
end

load_module("workspaces.ui")
load_module("workspaces.toggleterms")
load_module("workspaces.workspaces")
load_module("workspaces.persistence")

return M

local M = {}

local modules = {
	"workspaces.ui",
	"workspaces.toggleterms",
	"workspaces.workspaces",
	"workspaces.persistence",
}

setmetatable(M, {
	__index = function(_, key)
		for _, module_name in ipairs(modules) do
			local module = require(module_name)
			if module[key] ~= nil then
				rawset(M, key, module[key])
				return module[key]
			end
		end
	end,
})

return M

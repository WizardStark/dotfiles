local M = {}

function M.get_breakpoints()
	local breakpoints = {}
	local breakpoints_by_buf = require("dap.breakpoints").get()
	for buf, buf_breakpoints in pairs(breakpoints_by_buf) do
		breakpoints[vim.api.nvim_buf_get_name(buf)] = buf_breakpoints
	end

	return breakpoints
end

function M.apply_breakpoints(breakpoints)
	if not breakpoints then
		return
	end
	local loaded_buffers = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local file_name = vim.api.nvim_buf_get_name(buf)
		loaded_buffers[file_name] = buf
	end

	for path, buf_bps in pairs(breakpoints) do
		for _, bp in pairs(buf_bps) do
			local line = bp.line
			local opts = {
				condition = bp.condition,
				log_message = bp.logMessage,
				hit_condition = bp.hitCondition,
			}
			require("dap.breakpoints").set(opts, tonumber(loaded_buffers[path]), line)
		end
	end
end

return M

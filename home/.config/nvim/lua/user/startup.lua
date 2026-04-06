local M = {}

local start_ns = vim.uv.hrtime()
local start_ms = nil
local ffi_ok, ffi = pcall(require, "ffi")
local ui_enter_done_ms = nil

local function cputime_ms()
	if ffi_ok then
		local ok, ret = pcall(function()
			ffi.cdef([[
				typedef int clockid_t;
				typedef struct timespec {
					int64_t tv_sec;
					long tv_nsec;
				} nanotime;
				int clock_gettime(clockid_t clk_id, struct timespec *tp);
			]])

			local pnano = ffi.new("nanotime[1]")
			local clock_process_cputime_id = jit.os == "OSX" and 12 or 2
			ffi.C.clock_gettime(clock_process_cputime_id, pnano)
			return tonumber(pnano[0].tv_sec) * 1e3 + tonumber(pnano[0].tv_nsec) / 1e6
		end)

		if ok then
			cputime_ms = function()
				local pnano = ffi.new("nanotime[1]")
				local clock_process_cputime_id = jit.os == "OSX" and 12 or 2
				ffi.C.clock_gettime(clock_process_cputime_id, pnano)
				return tonumber(pnano[0].tv_sec) * 1e3 + tonumber(pnano[0].tv_nsec) / 1e6
			end
			vim.g.startup_ui_enter_real_cputime = true
			return ret
		end
	end

	cputime_ms = function()
		return (vim.uv.hrtime() - start_ns) / 1e6
	end
	vim.g.startup_ui_enter_real_cputime = false
	return cputime_ms()
end

start_ms = cputime_ms()

function M.mark_ui_enter_done()
	if ui_enter_done_ms ~= nil then
		return ui_enter_done_ms
	end

	ui_enter_done_ms = cputime_ms() - start_ms
	vim.g.startup_ui_enter_ms = ui_enter_done_ms

	if package.loaded.lualine then
		pcall(require("lualine").refresh)
	end

	return ui_enter_done_ms
end

function M.get_ui_enter_ms()
	return ui_enter_done_ms
end

function M.statusline()
	if ui_enter_done_ms == nil then
		return nil
	end

	return string.format("UI %.1fms", ui_enter_done_ms)
end

vim.api.nvim_create_autocmd("UIEnter", {
	once = true,
	callback = M.mark_ui_enter_done,
})

return M

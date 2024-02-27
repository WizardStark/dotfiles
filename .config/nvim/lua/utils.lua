local M = {}

M.get_visual_selection_lines = function()
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")

    local line_start = vstart[2]
    local line_end = vend[2]

    return {line_start, line_end}
end

return M

require("toggleterm").setup(
	---@module 'toggleterm'
	{
		open_mapping = [[<c-~>]],
		on_exit = function(term, job, exit_code, name)
			local session_terms = require("workspaces.toggleterms").get_session_terms()
			for _, value in ipairs(session_terms) do
				if value.global_id == term.id then
					require("workspaces.toggleterms").delete_term(value.local_id)
				end
			end
		end,
	}
)

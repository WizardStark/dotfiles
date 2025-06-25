require("overseer").setup(
	---@module 'overseer'
	{
		task_list = {
			direction = "bottom",
			min_height = 25,
			max_height = 25,
			default_detail = 1,
			bindings = {
				["<C-h>"] = false,
				["<C-j>"] = false,
				["<C-k>"] = false,
				["<C-l>"] = false,
				["<C-M-l>"] = "IncreaseDetail",
				["<C-M-h>"] = "DecreaseDetail",
				["<C-M-k>"] = "ScrollOutputUp",
				["<C-M-j>"] = "ScrollOutputDown",
			},
		},
	}
)

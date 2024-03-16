return {
	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
		opts = {
			root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" },
		},
		config = function(_, opts)
			local resolve_opts = function()
				local root_dir = require("jdtls.setup").find_root(opts.root_markers)
				local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
				local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls/workspace-root/" .. project_name
				if vim.loop.fs_stat(workspace_dir) == nil then
					os.execute("mkdir " .. workspace_dir)
				end
				local install_path = require("mason-registry").get_package("jdtls"):get_install_path()
				local os
				if vim.fn.has("macunix") then
					os = "mac"
				else
					os = "linux"
				end

				return {
					cmd = {
						"java",
						"-Declipse.application=org.eclipse.jdt.ls.core.id1",
						"-Dosgi.bundles.defaultStartLevel=4",
						"-Declipse.product=org.eclipse.jdt.ls.core.product",
						"-Dlog.protocol=true",
						"-Dlog.level=ALL",
						"-javaagent:" .. install_path .. "/lombok.jar",
						"-Xmx1g",
						"--add-modules=ALL-SYSTEM",
						"--add-opens",
						"java.base/java.util=ALL-UNNAMED",
						"--add-opens",
						"java.base/java.lang=ALL-UNNAMED",
						"-jar",
						vim.fn.glob(install_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
						"-configuration",
						install_path .. "/config_" .. os,
						"-data",
						workspace_dir,
					},
					root_dir = root_dir,
				}
			end
			vim.api.nvim_create_autocmd("Filetype", {
				pattern = "java",
				callback = function()
					local start_opts = resolve_opts()
					if start_opts.root_dir and start_opts.root_dir ~= "" then
						require("jdtls").start_or_attach(start_opts)
					end
				end,
			})
		end,
	},
}

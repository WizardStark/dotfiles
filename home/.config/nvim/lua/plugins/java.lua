return {
	{
		"mfussenegger/nvim-jdtls",
		dependencies = {
			"mfussenegger/nvim-dap",
		},
		ft = "java",
		opts = {
			root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" },
		},
		config = function(_, opts)
			local resolve_opts = function()
				local jdtls = require("jdtls")
				local Path = require("plenary.path")
				local root_dir = require("jdtls.setup").find_root(opts.root_markers)
				local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
				local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls/workspace-root/" .. project_name
				if vim.loop.fs_stat(workspace_dir) == nil then
					Path:new(workspace_dir):mkdir({ parents = true })
				end
				local jdtls_path = require("mason-registry").get_package("jdtls"):get_install_path()
				local java_debug_path = vim.fn.stdpath("data")
					.. "mason/share/java_debug_adapter/com.microsoft.java.debug.plugin.jar"
				local java_test_path = vim.fn.stdpath("data") .. "mason/share/java-test"
				local os
				if vim.fn.has("macunix") then
					os = "mac"
				else
					os = "linux"
				end

				local bundles = {
					vim.fn.glob(java_debug_path, true),
				}
				vim.list_extend(bundles, vim.split(vim.fn.glob(java_test_path .. "/*.jar", true), "\n"))

				return {
					cmd = {
						"java",
						"-Declipse.application=org.eclipse.jdt.ls.core.id1",
						"-Dosgi.bundles.defaultStartLevel=4",
						"-Declipse.product=org.eclipse.jdt.ls.core.product",
						"-Dlog.protocol=true",
						"-Dlog.level=ALL",
						"-javaagent:" .. jdtls_path .. "/lombok.jar",
						"-Xmx4g",
						"--add-modules=ALL-SYSTEM",
						"--add-opens",
						"java.base/java.util=ALL-UNNAMED",
						"--add-opens",
						"java.base/java.lang=ALL-UNNAMED",
						"-jar",
						vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
						"-configuration",
						jdtls_path .. "/config_" .. os,
						"-data",
						workspace_dir,
					},
					root_dir = root_dir,
					init_options = {
						bundles = bundles,
					},
					settings = {
						java = {
							-- home = "/usr/lib/jvm/java-17-openjdk-amd64",
							-- configuration = {
							-- 	updateBuildConfiguration = "interactive",
							-- 	runtimes = {
							-- 		{
							-- 			name = "JavaSE-11",
							-- 			path = "/usr/lib/jvm/java-11-openjdk-amd64",
							-- 		},
							-- 		{
							-- 			name = "JavaSE-17",
							-- 			path = "/usr/lib/jvm/java-17-openjdk-amd64",
							-- 		},
							-- 		{
							-- 			name = "JavaSE-19",
							-- 			path = "/usr/lib/jvm/java-19-openjdk-amd64",
							-- 		},
							-- 	},
							-- },
							eclipse = {
								downloadSources = true,
							},
							maven = {
								downloadSources = true,
							},
							implementationsCodeLens = {
								enabled = true,
							},
							referencesCodeLens = {
								enabled = true,
							},
							references = {
								includeDecompiledSources = true,
							},
							signatureHelp = { enabled = true },
							format = {
								enabled = true,
								-- Formatting works by default, but you can refer to a specific file/URL if you choose
								-- settings = {
								--   url = "https://github.com/google/styleguide/blob/gh-pages/intellij-java-google-style.xml",
								--   profile = "GoogleStyle",
								-- },
							},
						},
						completion = {
							favoriteStaticMembers = {
								"org.hamcrest.MatcherAssert.assertThat",
								"org.hamcrest.Matchers.*",
								"org.hamcrest.CoreMatchers.*",
								"org.junit.jupiter.api.Assertions.*",
								"java.util.Objects.requireNonNull",
								"java.util.Objects.requireNonNullElse",
								"org.mockito.Mockito.*",
							},
							importOrder = {
								"java",
								"javax",
								"com",
								"org",
							},
						},
						extendedClientCapabilities = jdtls.extendedClientCapabilities,
						sources = {
							organizeImports = {
								starThreshold = 9999,
								staticStarThreshold = 9999,
							},
						},
						codeGeneration = {
							toString = {
								template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
							},
							useBlocks = true,
						},
					},
					-- Needed for auto-completion with method signatures and placeholders
					capabilities = require("cmp_nvim_lsp").default_capabilities(),
					flags = {
						allow_incremental_sync = true,
					},
					-- on_attach = function(client, bufnr)
					-- 	jdtls.setup_dap({ hotcodereplace = "auto" })
					-- 	require("jdtls.dap").setup_dap_main_class_configs()
					-- end,
				}
			end
			vim.api.nvim_create_autocmd("Filetype", {
				pattern = "java",
				callback = function()
					require("jdtls").start_or_attach(resolve_opts())
					if vim.g.extra_lsp_actions ~= nil then
						vim.g.extra_lsp_actions()
					end
				end,
			})
		end,
	},
}

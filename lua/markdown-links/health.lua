local utils = require("markdown-links.utils")
local is_cmp = false
local is_search = false
return {
	check = function()
		vim.health.start("Autocompletion engine")
		if utils.is_plugin_installed("blink.cmp") then
			vim.health.ok("blink.cmp - found")
			is_cmp = true
		else
			vim.health.warn("blink.cmp - not found")
		end

		if utils.is_plugin_installed("cmp") then
			vim.health.ok("cmp - found")
			is_cmp = true
		else
			vim.health.warn("cmp - not found")
		end

		if not is_cmp then
			vim.health.warn("No autocomplete engine found")
		else
			vim.health.ok("Autocompletion engine - ready")
		end

		vim.health.start("Picker / searcher engine")
		if utils.is_plugin_installed("fzf-lua") then
			vim.health.ok("fzf-lua - found")
			is_search = true
		else
			vim.health.warn("fzf-lua - not found")
		end

		if utils.is_plugin_installed("telescope") then
			vim.health.ok("telescope - found")
			is_search = true
		else
			vim.health.warn("telescope - not found")
		end

		if not is_search then
			vim.health.warn("No picker / searcher engine found")
		else
			vim.health.ok("Picker / searcher engine - ready")
		end

		vim.health.start("markdown-links")
		if not is_cmp and not is_search then
			vim.health.warn("No autocomplete engine and picker / searcher engine found")
			vim.health.info("Please install one of the engines to use markdown-links")
			vim.health.error("markdown-links - not ready")
		else
			vim.health.ok("Ready")
		end
	end,
}

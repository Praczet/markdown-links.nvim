local M = {}
local utils = require("markdown-links.utils")

-- Default configuration
M.config = {
	filetypes = { "markdown" }, -- Drfault filetypes (markdown)
	kind_hl_group = "#ffc777", -- Default color, you can override this when setting up the plugin
	excluded_files = {}, -- List of files to exclude
	excluded_folders = {}, -- List of folders to exclude
	notes_folder = nil,
	debug = true,
	search_engine = "auto", -- options: "telescope", "fzf-lua", "auto"
	autocomplete_engine = "auto", -- options: "cmp", "blink", "auto"
}

function M.setup(user_config)
	utils.debug = M.debug
	utils.log_message("init.M.setup", "Setting up markdown-links") -- Debug print
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	M.initialize()
end

function M.initialize()
	utils.log_message("init.M.initialize", "Initializing markdown-links") -- Debug print

	-- Notify user if configured plugins are missing
	if M.config.search_engine == "telescope" and not utils.is_plugin_installed("telescope") then
		vim.notify("Telescope is configured but not installed!", vim.log.levels.WARN)
	elseif M.config.search_engine == "fzf-lua" and not utils.is_plugin_installed("fzf-lua") then
		vim.notify("fzf-lua is configured but not installed!", vim.log.levels.WARN)
	end

	if M.config.autocomplete_engine == "cmp" and not utils.is_plugin_installed("cmp") then
		vim.notify("cmp is configured but not installed!", vim.log.levels.WARN)
	elseif M.config.autocomplete_engine == "blink" and not utils.is_plugin_installed("blink") then
		vim.notify("blink is configured but not installed!", vim.log.levels.WARN)
	end

	if utils.is_plugin_installed("blink.cmp") then
		M.config.autocomplete_engine = "blink"
		vim.notify("blink.cmp is installed but this is not implemented yet", vim.log.levels.WARN)
		-- require("markdown-links.autocomplete.blink").initialize(M.config)
		-- local blink = require("blink.cmp")
		-- blink.setup({
		-- 	sources = {
		-- 		completion = {
		-- 			enabled_providers = { "mdlinks" },
		-- 		},
		-- 		providers = {
		-- 			mdlinks = { name = "MD-Links", module = "markdown-links.autocomplete.blink" },
		-- 		},
		-- 	},
		-- })
	elseif utils.is_plugin_installed("cmp") then
		M.config.autocomplete_engine = "cmp"
		require("markdown-links.autocomplete.cmp").initialize(M.config)
	else
		vim.notify("No autocomplete engine found", vim.log.levels.WARN)
	end

	if utils.is_plugin_installed("telescope") then
		M.config.search_engine = "telescope"
		require("markdown-links.search.telescope").initialize(M.config)
	elseif utils.is_plugin_installed("fzf-lua") then
		M.config.search_engine = "fzf-lua"
		require("markdown-links.search.fzf").initialize(M.config)
	else
		vim.notify("No search engine found", vim.log.levels.WARN)
	end
end

return M

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
}

M.mdl_cmp = require("markdown-links.cmp")
M.mdl_telescope = require("markdown-links.telescope")

function M.setup(user_config)
	utils.debug = M.debug
	utils.log_message("init.M.setup", "Setting up markdown-links") -- Debug print
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	M.initialize()
end

function M.initialize()
	utils.log_message("init.M.initialize", "Initializing markdown-links") -- Debug print
	M.mdl_cmp.initialize(M.config)
	M.mdl_telescope.initialize(M.config)
end

return M

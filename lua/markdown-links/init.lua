local M = {}
local utils = require("markdown-links.utils")

-- Default configuration
M.config = {
	filetypes = { "markdown" },
}

M.md_cmp = require("markdown-links.markdown-links-cmp")

function M.setup(user_config)
	utils.log_message("init.M.setup", "Setting up markdown-links") -- Debug print
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	M.initialize()
end

function M.initialize()
	utils.log_message("init.M.initialize", "Initializing markdown-links") -- Debug print
	M.md_cmp.initialize(M.config)
end

return M

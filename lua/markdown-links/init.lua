local M = {}

-- Default configuration
M.config = {
  filetypes = { "markdown" },
}

M.md_cmp = require("markdown-links.markdown-links-cmp")

local function log_message(message)
  local log_file = vim.fn.expand("~/.config/nvim/nvim.log")
  local log_entry = os.date("%Y-%m-%d %H:%M:%S") .. "\t[markdown-links]\n" .. message .. "\n"
  local file = io.open(log_file, "a")
  if file then
    file:write(log_entry)
    file:close()
  end
end

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
  M.initialize()
end

function M.initialize()
  M.md_cmp.initialize(M.config)
end

return M

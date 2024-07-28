local M = {}

function M.log_message(module_name, message)
	local log_file = vim.fn.expand("~/.config/nvim/nvim-markdown-links.log")
	local log_entry = os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. module_name .. "\t" .. message .. "\n"
	local file = io.open(log_file, "a")
	if file then
		file:write(log_entry)
		file:close()
	end
end
return M

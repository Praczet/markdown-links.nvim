local M = {}
local lyaml_exists, lyaml = pcall(require, "lyaml")
M.debug = true

function M.log_message(module_name, message)
	if not M.debug then
		return
	end
	local log_file = vim.fn.expand("~/.config/nvim/nvim-markdown-links.log")
	local log_entry = os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. module_name .. "\t" .. message .. "\n"
	local file = io.open(log_file, "a")
	if file then
		file:write(log_entry)
		file:close()
	end
end

function M.parse_yaml_front_matter(content)
	if lyaml_exists then
		local front_matter = content:match("^%-%-%-(.-)%-%-%-")
		if front_matter then
			return lyaml.load(front_matter)
		end
	else
		M.log_message("utils.M.parse_yaml_front_matter", "lyaml not available, skipping YAML front matter parsing.")
	end
	return nil
end

function M.read_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return content
end

function M.extract_title(content, file_path)
	local yaml_data = M.parse_yaml_front_matter(content)
	if yaml_data and yaml_data.title then
		return yaml_data.title
	end

	local title = content:match("\ntitle:%s*(.-)\n") or content:match("^#%s*(.-)\n") or content:match("\n#%s*(.-)\n")
	if not title then
		local file_name = vim.fn.fnamemodify(file_path, ":t:r")
		title = file_name:gsub("-", " "):gsub("^%l", string.upper)
	end
	return title
end

---Read the file contet and extract the yaml tags
---@param content any
---@return table
function M.get_yaml_tags(content)
	local yaml_tags = {}
	if content then
		local yaml_data = M.parse_yaml_front_matter(content)
		if yaml_data and yaml_data.tags then
			for _, tag in ipairs(yaml_data.tags) do
				if tag and #tag > 0 then
					yaml_tags[#yaml_tags + 1] = tag
				end
			end
		end
	end
	return yaml_tags
end

function M.normalize_folder_path(folder_path)
	return folder_path:gsub("/$", "")
end

function M.get_markdown_files(config, fullPath)
	M.log_message(
		"utils.M.get_markdown_files",
		"config: " .. vim.inspect(config) .. ", fullPath: " .. vim.inspect(fullPath)
	)
	fullPath = fullPath == nil and true or fullPath
	local search_dir = vim.fn.expand("%:p:h")

	config = config or {}
	if config.notes_folder then
		search_dir = config.notes_folder
	end
	search_dir = search_dir or ""
	local files = vim.fn.globpath(search_dir, "**/*.md", false, true)
	local results = {}

	for _, file in ipairs(files) do
		if
			not M.is_excluded_folder(file, config.excluded_folders or {})
			and not M.is_excluded_file(file, config.excluded_files or {})
		then
			if fullPath then
				table.insert(results, file)
			else
				local filepath
				if config.notes_folder and #config.notes_folder > 0 then
					local normalized_notes_folder = M.normalize_folder_path(config.notes_folder)
					filepath =
						vim.fn.fnamemodify(file, ":p"):gsub("^" .. vim.fn.expand(normalized_notes_folder) .. "/", "")
				else
					filepath = vim.fn.fnamemodify(file, ":~:.")
				end
				table.insert(results, filepath)
			end
		end
	end
	return results
end

function M.is_excluded_folder(file_path, excluded_folders)
	for _, folder in ipairs(excluded_folders) do
		if file_path:find("^" .. folder .. "/") or file_path:find("/" .. folder .. "/") then
			return true
		end
	end
	return false
end

function M.is_excluded_file(file_path, excluded_files)
	local file_name = vim.fn.fnamemodify(file_path, ":t")
	for _, file in ipairs(excluded_files) do
		if file_name == file then
			return true
		end
	end
	return false
end

function M.escape_square_brackets(str)
	return str:gsub("%[", "\\["):gsub("%]", "\\]")
end

-- Check if a plugin is installed
-- @param name Plugin name
function M.is_plugin_installed(name)
	local ok, _ = pcall(require, name)
	return ok
end

return M

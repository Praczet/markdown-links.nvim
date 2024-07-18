-- Some file
local M = {}
local source = {}
local cmp = require("cmp")

local function read_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return content
end

local function extract_title(content, file_path)
	local title = content:match("title:%s*(.-)\n") or content:match("#%s*(.-)\n")
	if not title then
		-- Extract file name without extension
		local file_name = vim.fn.fnamemodify(file_path, ":t:r")
		-- Replace hyphens with spaces and capitalize the first word
		title = file_name:gsub("-", " "):gsub("^%l", string.upper)
	end
	return title
end

-- Helper function to calculate match score
local function calculate_score(query, text)
	local score = 0
	local query_len = #query
	local text_len = #text

	-- Exact match bonus
	if text:find(query) then
		score = score + 100
	end

	-- Prefix match bonus
	if text:sub(1, query_len) == query then
		score = score + 50
	end

	-- Substring match bonus
	local match_start, match_end = text:find(query)
	if match_start and match_end then
		score = score + (100 / (match_end - match_start + 1))
	end

	-- Character proximity bonus
	local last_pos = 0
	for i = 1, query_len do
		local pos = text:find(query:sub(i, i), last_pos + 1)
		if pos then
			score = score + (10 / (pos - last_pos))
			last_pos = pos
		else
			score = score - 10 -- Penalize missing characters
		end
	end

	return score
end

local function fuzzy_search(query, items)
	local results = {}
	query = query:lower()

	for _, item in ipairs(items) do
		local title_score = calculate_score(query, item.title:lower())
		local path_score = calculate_score(query, item.path:lower())
		local max_score = math.max(title_score, path_score)

		if max_score > 0 then
			table.insert(results, { item = item, score = max_score })
		end
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	-- Extract sorted items from results
	local sorted_items = {}
	for _, result in ipairs(results) do
		table.insert(sorted_items, result.item)
	end

	return sorted_items
end

function M.search_headers_or_titles(query)
	local files = vim.fn.glob("**/*.md", false, true) -- Get all Markdown files
	local titles = {}

	for _, file in ipairs(files) do
		local content = read_file(file)
		if content then
			local title = extract_title(content, file)
			if title then
				table.insert(titles, { title = title, path = file })
			end
		end
	end

	local matches = fuzzy_search(query, titles)
	return matches
end

function M.search_file_names(query)
	local files = vim.fn.glob("**/*.md", false, true) -- Get all Markdown files
	local matches = fuzzy_search(
		query,
		vim.tbl_map(function(file)
			return { title = vim.fn.fnamemodify(file, ":t"), path = file }
		end, files)
	)
	return matches
end

function source:complete(_, callback)
	local items = {}

	-- Logic to detect cursor position and suggest items
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local in_square_brackets = string.find(line:sub(1, col), "%[.-%]")
	local in_parentheses = string.find(line:sub(1, col), "%(.-%)")

	if in_square_brackets then
		-- Fuzzy search H1 headers and YAML titles
		local query = line:sub(in_square_brackets + 1, col)
		items = M.search_headers_or_titles(query)
	elseif in_parentheses then
		-- Fuzzy search file names
		local query = line:sub(in_parentheses + 1, col)
		items = M.search_file_names(query)
	end

	callback({
		items = vim.tbl_map(function(item)
			return {
				label = item.title,
				documentation = item.path,
			}
		end, items),
	})
end

function M.setup_cmp()
	local existing_sources = cmp.get_config().sources or {}
	table.insert(existing_sources, 1, { name = "markdown-links" }) -- Insert ytags at the first position

	cmp.setup.filetype("markdown", {
		sources = existing_sources,
	})
end

function M.on_buf_enter()
	cmp.setup.buffer({
		sources = {
			{ name = "markdown-links" },
		},
	})
end

function M.initialize(config)
	config = config or {}
	config.filetypes = config.filetypes or { "markdown" }
	vim.cmd([[
        augroup CmdMarkdownFiles
            autocmd!
            autocmd FileType ]] .. table.concat(config.filetypes, ",") .. [[ lua require('markdown-links.markdown-links-cmp').on_buf_enter()
        augroup END
    ]])

	M.setup_cmp()
	cmp.register_source("markdown-links", source)
end

return M

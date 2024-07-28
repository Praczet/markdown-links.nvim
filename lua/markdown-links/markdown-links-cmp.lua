local M = {}
local source = {}
local cmp = require("cmp")
local utils = require("markdown-links.utils")

local function read_file(file_path)
	-- print("read file")
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return content
end

local function extract_title(content, file_path)
	-- print("extract title")
	local title = content:match("\ntitle:%s*(.-)\n") or content:match("^#%s*(.-)\n") or content:match("\n#%s*(.-)\n")
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
	-- print("calculate score")
	local score = 0
	local query_len = #query

	-- Exact match bonus
	if text:find(query, 1, true) then
		score = score + 100
	end

	-- Prefix match bonus
	if text:sub(1, query_len) == query then
		score = score + 50
	end

	-- Substring match bonus
	local match_start, match_end = text:find(query, 1, true)
	if match_start and match_end then
		score = score + (100 / (match_end - match_start + 1))
	end

	-- Character proximity bonus
	local last_pos = 0
	for i = 1, query_len do
		local pos = text:find(query:sub(i, i), last_pos + 1, true)
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

function M.search_headers_titles_filenames(query, context)
	-- print("Searching headers, titles, and filenames for query: " .. vim.inspect(query))
	local files = vim.fn.glob("**/*.md", false, true) -- Get all Markdown files
	local results = {}

	for _, file in ipairs(files) do
		local content = read_file(file)
		local title = extract_title(content, file)
		local filepath = vim.fn.fnamemodify(file, ":.")

		if content then
			local display, insert, documentation

			if context == "brackets" then
				display = "[" .. title .. "](" .. filepath .. ")"
			else
				display = "(" .. filepath .. ")[" .. title .. "]"
			end
			documentation = "file: **" .. filepath .. "**"
			if title then
				documentation = documentation .. "\ntitle: **" .. title .. "**"
			end
			insert = file

			table.insert(
				results,
				{ display = display, insert = insert, documentation = documentation, path = file, title = title }
			)
		end
	end

	local matches = fuzzy_search(query, results)
	return matches
end

function source:complete(_, callback)
	utils.log_message("markdown-links-cmp.source.complete", "Complete called")
	local items = {}
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Lua is 1-based indexing
	local before_cursor = line:sub(1, col - 1)
	local after_cursor = line:sub(col)

	-- Check if cursor is within valid square brackets and parentheses
	local valid_scenario = false
	local in_square_brackets = before_cursor:match("()%[[^%[%]]*$")
	local in_parentheses = before_cursor:match("()%([^%(%)]*$")

	if in_square_brackets then
		local after_bracket = after_cursor:match("^%s*%]")
		if after_bracket then
			if after_cursor:match("^%s*%]$") then
				valid_scenario = true
			elseif after_cursor:match("^%s*%]%s+") then
				valid_scenario = true
			elseif after_cursor:match("^%s*%]%(%)") then
				valid_scenario = true
			end
		end
	elseif in_parentheses then
		local before_parentheses = before_cursor:match("%[.*%]%(%S*$")
		if before_parentheses and after_cursor:match("^%s*%)%s*") then
			valid_scenario = true -- Case for empty () preceded by valid []
		end
	end

	-- Feed CMP if the scenario is valid
	if valid_scenario then
		local query = line:sub((in_square_brackets or in_parentheses) + 1, col - 1):match("%S*")
		items = M.search_headers_titles_filenames(query or "", "brackets")
	end

	callback({
		items = vim.tbl_map(function(item)
			return {
				label = item.display, -- This is what shows up in the completion list.
				insertText = item.insert, -- This is what gets inserted into the buffer.
				documentation = item.documentation, -- This is the detailed info shown in a floating window.
				path = item.path, -- This is additional information for internal use.
				title = item.title,
			}
		end, items),
	})
end
function M.setup_cmp()
	utils.log_message("markdown-links-cmp.M.setup_cmp", "Setting up markdown-links cmp")
	local existing_sources = cmp.get_config().sources or {}
	table.insert(existing_sources, 1, { name = "markdownlinks", group_index = 1, option = {} }) -- Insert markdown-links at the first position
	vim.cmd([[
    highlight CmpItemKindMarkdownLink guifg=#569CD6
  ]])
	utils.log_message("markdown-links-cmp.M.setup_cmp", "before cmp.setup.filetype")
	utils.log_message("markdown-links-cmp.M.setup_cmp", vim.inspect(existing_sources))
	cmp.setup.filetype("markdown", {
		sources = existing_sources,
		formatting = {
			fields = { "abbr", "kind", "menu" },
			expandable_indicator = true,
			format = function(entry, vim_item)
				utils.log_message("markdown-links-cmp.M.setup_cmp", "Formatting entry from source: ")
				-- if entry.source.name == "markdown-links" then
				-- 	vim_item.kind = "" -- Markdown file icon from Nerd Font
				-- 	vim_item.kind_hl_group = "CmpItemKindMarkdownLink"
				-- 	vim_item.menu = "[MD-LNK]"
				-- 	utils.log_message("markdown-links-cmp.M.setup_cmp", "Set kind and menu for markdown-links")
				-- else
				-- 	vim_item.menu = ({
				-- 		buffer = "[Buffer]",
				-- 		nvim_lsp = "[LSP]",
				-- 		luasnip = "[Snippet]",
				-- 		path = "[Path]",
				-- 		codeium = "[Codeium]",
				-- 	})[entry.source.name]
				-- 	utils.log_message(
				-- 		"markdown-links-cmp.M.setup_cmp",
				-- 		"Set menu for other sources" .. entry.source.name
				-- 	)
				-- end
				-- -- vim_item.menu = ({
				-- -- 	["markdown-links"] = "[Link]",
				-- -- })[entry.source.name]
				-- ---- Add a debug print statement
				-- utils.log_message(
				-- 	"markdown-links-cmp.M.setup_cmp",
				-- 	"Source: " .. entry.source.name .. ", Kind: " .. vim_item.kind
				-- )

				return vim_item
			end,
		},
	})

	utils.log_message("markdown-links-cmp.M.setup_cmp", "before cmp.event:on")
	cmp.event:on("confirm_done", function(event)
		local entry = event.entry
		local item = entry:get_completion_item()
		if entry.source.name == "markdown-links" then
			local insert_text = item.insertText or item.label
			local path = item.path or ""
			local title = item.title or ""
			local cursor_pos = vim.api.nvim_win_get_cursor(0)
			local line = vim.api.nvim_get_current_line()
			local before_cursor = line:sub(1, cursor_pos[2])
			local after_cursor = line:sub(cursor_pos[2] + 1)
			local new_line
			local in_square_brackets_start, in_square_brackets_end = before_cursor:find("%[([^%[%]]*)$")
			local in_parentheses_start, in_parentheses_end = before_cursor:find("%(([^%(%)]*)$")

			-- Handle cases based on cursor position and context
			if in_square_brackets_start then
				-- print("-- Cursor is within []")
				local left = before_cursor:sub(1, in_square_brackets_start - 1)
				local right = after_cursor:match("^%s*%](.*)$") or ""

				if after_cursor:match("^%]%(%)") then
					-- print("-- Followed by empty ()")
					new_line = left .. "[" .. title .. "]" .. "(" .. path .. ")" .. right:sub(3) -- Remove `()` from after_cursor
				else
					if before_cursor:sub(in_square_brackets_start + 1):match("^%s*$") then
						-- print("-- Case 1 and Case 2: Empty [] or Non-empty []")
						new_line = left .. "[" .. title .. "]" .. "(" .. path .. ")" .. right
					else
						-- print("-- Case 4: Non-empty []")
						new_line = left .. "[" .. title .. "](" .. path .. ")" .. right
					end
				end
			elseif in_parentheses_start and after_cursor:match("^%s*%)%s*") then
				-- print("-- Cursor is within ()")
				local left = before_cursor:sub(1, in_parentheses_start - 1)
				local right = after_cursor:match("^%s*%)(.*)$") or ""

				if before_cursor:sub(in_parentheses_start + 1, in_parentheses_end - 1):match("^%s*$") then
					-- print("-- Case 3: Empty ()")
					local square_brackets_left_start, square_brackets_left_end = before_cursor:find("%[%s*%]")
					if square_brackets_left_start and square_brackets_left_end then
						new_line = before_cursor:sub(1, square_brackets_left_start - 1)
							.. "["
							.. title
							.. "]"
							.. "("
							.. path
							.. ")"
							.. right
					else
						new_line = left .. "(" .. path .. ")" .. right
					end
				else
					local square_brackets_left_start, square_brackets_left_end = before_cursor:find("%[%s*%]")
					-- print("-- Insert (path) after existing content in ()")
					-- print("left" .. left)
					-- print("right" .. right)
					if square_brackets_left_start and square_brackets_left_end then
						new_line = before_cursor:sub(1, square_brackets_left_start - 1)
							.. "["
							.. title
							.. "]"
							.. "("
							.. path
							.. ")"
							.. right
					else
						new_line = left .. "(" .. path .. ")" .. right
					end
				end
			else
				-- print("-- Default case")
				new_line = before_cursor .. insert_text .. after_cursor
			end

			vim.api.nvim_set_current_line(new_line)
			vim.api.nvim_win_set_cursor(0, { cursor_pos[1], cursor_pos[2] + #path })
		end
	end)
end

function M.on_buf_enter()
	utils.log_message("markdown-links-cmp.M.on_buf_enter", "Enter on buffer")
	local existing_sources = cmp.get_config().sources or {}
	table.insert(existing_sources, 1, { name = "markdownlinks" }) -- Insert ytags at the first position
	cmp.setup.buffer({
		sources = existing_sources,
	})
end

function M.initialize(config)
	utils.log_message("markdown-links-cmp.M.initialize", "Initializing markdown-links") -- Debug
	config = config or {}

	config.filetypes = config.filetypes or { "markdown" }
	vim.cmd([[
        augroup CmdMarkdownFiles
            autocmd!
            autocmd FileType ]] .. table.concat(config.filetypes, ",") .. [[ lua require('markdown-links.markdown-links-cmp').on_buf_enter()
        augroup END
    ]])

	M.setup_cmp()
	cmp.register_source("markdownlinks", source)
end

return M

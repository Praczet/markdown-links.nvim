local M = {}

-- WIll be override or filled by user form manin plugin config
M.config = {
	filetypes = { "markdown" }, -- allowed filetypes (not supported yet) for now just markdown
	kind_hl_group = "#ffc777", -- Default color, you can override this when setting up the plugin
	excluded_files = {}, -- list of files to exclude
	excluded_folders = {}, -- list of folders to exclude
	notes_folder = nil, -- default notes folder if not give current buffer folder will be taken
	search_engine = "auto", -- options: "telescope", "fzf-lua", "auto"
	autocomplete_engine = "cmp", -- options: "cmp", "blink", "auto"
}

local source = {}
local cmp = require("cmp")
local utils = require("markdown-links.utils")

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
	-- local search_dir = vim.fn.expand("%:p:h")
	-- if M.config.notes_folder then
	-- 	search_dir = M.config.notes_folder
	-- end
	-- search_dir = search_dir or ""
	-- local files = vim.fn.globpath(search_dir, "**/*.md", false, true)
	local files = utils.get_markdown_files(M.config)
	local results = {}

	for _, file in ipairs(files) do
		-- if
		-- 	not is_excluded_folder(file, M.config.excluded_folders)
		-- 	and not is_excluded_file(file, M.config.excluded_files)
		-- then
		local content = utils.read_file(file)
		local title = utils.extract_title(content, file)
		local tags = utils.get_yaml_tags(content)

		-- Make path relative to notes_folder if specified
		local filepath
		if M.config.notes_folder and #M.config.notes_folder > 0 then
			local normalized_notes_folder = utils.normalize_folder_path(M.config.notes_folder)
			filepath = vim.fn.fnamemodify(file, ":p"):gsub("^" .. vim.fn.expand(normalized_notes_folder) .. "/", "")
		else
			filepath = vim.fn.fnamemodify(file, ":~:.")
		end

		if content then
			local display, insert, documentation

			if context == "brackets" then
				display = "[" .. title .. "](" .. filepath .. ")"
			else
				display = "(" .. filepath .. ")[" .. title .. "]"
			end
			documentation = "# Markdown Links\n\nFile: **" .. filepath .. "**"
			if title then
				documentation = documentation .. "\nTitle: **" .. title .. "**"
			end
			if tags and #tags > 0 then
				documentation = documentation .. "\n\n\ntags: *" .. table.concat(tags, ", ") .. "*"
			end
			insert = filepath

			table.insert(results, {
				display = display,
				insert = insert,
				documentation = documentation,
				path = filepath,
				title = title,
			})
		end
		-- end
	end

	local matches = fuzzy_search(query, results)
	return matches
end

function source:complete(_, callback)
	utils.log_message("cmp.source.complete", "Complete called")
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

	-- icon = "",
	callback({
		items = vim.tbl_map(function(item)
			return {
				label = item.display, -- This is what shows up in the completion list.
				insertText = item.insert, -- This is what gets inserted into the buffer.
				documentation = item.documentation, -- This is the detailed info shown in a floating window.
				path = item.path, -- This is additional information for internal use.
				title = item.title,
				cmp = {
					kind_text = " MD-LNK",
					kind_hl_group = "CmpItemKindMarkdownLink",
				},
			}
		end, items),
	})
end
function M.setup_cmp()
	utils.log_message("cmp.M.setup_cmp", "Setting up markdown-links cmp")
	local existing_sources = cmp.get_config().sources or {}
	table.insert(existing_sources, 1, { name = "markdown-links", group_index = 1, option = {} }) -- Insert markdown-links at the first position

	local highlight_cmd = string.format("highlight CmpItemKindMarkdownLink guifg=%s", M.config.kind_hl_group)
	vim.cmd(highlight_cmd)

	utils.log_message("cmp.M.setup_cmp", "before cmp.setup.filetype")
	utils.log_message("cmp.M.setup_cmp", vim.inspect(existing_sources))
	cmp.setup.filetype("markdown", {
		sources = existing_sources,
		formatting = {
			fields = { "abbr", "kind", "menu" },
			expandable_indicator = true,
			format = function(entry, vim_item)
				return vim_item
			end,
		},
	})

	utils.log_message("cmp.M.setup_cmp", "before cmp.event:on")
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
			title = utils.escape_square_brackets(title)

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
	local filetype = vim.bo.filetype
	if filetype == "markdown" then
		utils.log_message("cmp.M.on_buf_enter", "Enter on buffer")
		local existing_sources = cmp.get_config().sources or {}
		table.insert(existing_sources, 1, { name = "markdown-links" })
		cmp.setup.buffer({
			sources = existing_sources,
		})
	end
end

function M.initialize(config)
	utils.log_message("cmp.M.initialize", "Initializing markdown-links") -- Debug
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	M.config.filetypes = M.config.filetypes or { "markdown" }
	vim.cmd([[
        augroup CmdMarkdownFiles
            autocmd!
            autocmd FileType ]] .. table.concat(M.config.filetypes, ",") .. [[ lua require('markdown-links.cmp').on_buf_enter()
        augroup END
    ]])

	M.setup_cmp()
	cmp.register_source("markdown-links", source)
end

return M

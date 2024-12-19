---@type blink.cmp.Source
local M = {}
M.config = {}

local utils = require("markdown-links.utils")

function M.initialize(config)
	utils.log_message("cmp.M.initialize", "Initializing markdown-links") -- Debug
	M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

-- Create a new source object
function M.new()
	return setmetatable({}, { __index = M })
end

-- Check if the source is enabled for the current file type
function M:enabled()
	local filetypes = { "markdown", "md" }
	return vim.tbl_contains(filetypes, vim.bo.filetype)
end

-- Get completions based on the current context
---@param ctx lsp.CompletionContext
---@param callback function
function M:get_completions(ctx, callback)
	-- Wrap the callback to match Blink's expectations
	local transformed_callback = function(items)
		callback({
			context = ctx,
			is_incomplete_forward = true,
			is_incomplete_backward = true,
			items = items,
		})
	end

	-- Fetch markdown files
	local files = utils.get_markdown_files(M.config)

	if not files or #files == 0 then
		transformed_callback({})
		return function() end
	end

	-- Get current line and cursor position
	local line = vim.api.nvim_get_current_line()
	local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
	local before_cursor = line:sub(1, cursor_col)
	local after_cursor = line:sub(cursor_col + 1)

	-- Detect cursor context
	local in_square_brackets = before_cursor:match("()%[[^%[%]]*$")
	local in_parentheses = before_cursor:match("()%([^%(%)]*$")
	vim.notify("Inside square brackets::" .. vim.inspect(in_square_brackets))
	vim.notify("Inside parentheses::" .. vim.inspect(in_parentheses))

	if not in_square_brackets and not in_parentheses then
		transformed_callback({})
		return function() end
	end
	vim.notify("ctx::" .. vim.inspect(ctx))

	-- Define completion items
	local items = {}

	for _, file in ipairs(files) do
		local content = utils.read_file(file)
		if content then
			local title = utils.extract_title(content, file)
			local filepath = vim.fn.fnamemodify(file, ":~:.") -- Relative path
			local insert_title = title or filepath

			if in_square_brackets then
				-- Inside square brackets: Replace text within `[]` and adjust following `()`
				local left_part = before_cursor:sub(1, in_square_brackets - 1)
				local right_part = after_cursor:match("^%](.*)$") or ""
				local following_parentheses = right_part:match("^%((.-)%)") or ""

				local display_text = "[" .. insert_title .. "](" .. filepath .. ")"
				local insert_text = left_part
					.. "["
					.. insert_title
					.. "]("
					.. filepath
					.. ")"
					.. right_part:sub(#following_parentheses + 3)

				table.insert(items, {
					label = display_text,
					insertText = insert_text,
					documentation = {
						kind = "markdown",
						value = "**File:** `" .. filepath .. "`\n\n**Title:** `" .. insert_title .. "`",
					},
				})
			elseif in_parentheses then
				-- Inside parentheses: Adjust surrounding `[]` or add if missing
				local left_part = before_cursor:sub(1, in_parentheses - 1)
				local right_part = after_cursor:match("^%)(.*)$") or ""
				local square_brackets = left_part:match("%[(.-)%]") or ""

				if square_brackets == "" then
					-- Add `[]` with title or filename if missing
					left_part = left_part .. "[" .. insert_title .. "]"
				end

				local display_text = "[" .. insert_title .. "](" .. filepath .. ")"
				local insert_text = left_part .. "(" .. filepath .. ")" .. right_part

				table.insert(items, {
					label = display_text,
					insertText = insert_text,
					documentation = {
						kind = "markdown",
						value = "**File:** `" .. filepath .. "`\n\n**Title:** `" .. insert_title .. "`",
					},
				})
			end
		end
	end

	transformed_callback(items)
	return function() end
end

return M

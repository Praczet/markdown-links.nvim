local M = {}
local utils = require("markdown-links.utils")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")

M.config = {
	filetypes = { "markdown" }, -- allowed filetypes (not supported yet) for now just markdown
	kind_hl_group = "#ffc777", -- Default color, you can override this when setting up the plugin
	excluded_files = {}, -- list of files to exclude
	excluded_folders = {}, -- list of folders to exclude
	notes_folder = nil, -- default notes folder if not give current buffer folder will be taken
}

function M.initialize(config)
	utils.log_message("telescope.M.initialize", "Initializing markdown-links.telescope") -- Debug
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	require("which-key").add({
		mode = "n",
		{
			"<leader>fl",
			'<cmd>lua require("markdown-links.telescope").insert_link()<CR>',
			desc = "Add Link to selected file (markdown)",
		},
		{
			"<leader>fm",
			'<cmd>lua require("markdown-links.telescope").live_grep_link()<CR>',
			desc = "Search markdown files and add link",
		},
	})
end

local function insert_link_at_cursor(link_text)
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. link_text .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #link_text })
end

function M.insert_link()
	local opts = {}
	local files = utils.get_markdown_files(M.config, false)

	pickers
		.new(opts, {
			prompt_title = "Select Markdown File",
			finder = finders.new_table({
				results = files,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, status)
					local filepath = entry.value
					local bufnr = self.state.bufnr
					vim.bo[bufnr].filetype = "markdown"
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
					local lines = utils.read_file(filepath)
					if lines then
						vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(lines, "\n"))
					else
						vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Error: could not read file " .. filepath })
					end
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				local function insert_selected()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					local content = utils.read_file(selection.value)
					local title = utils.extract_title(content, selection.value)
					local link_text = string.format("[%s](%s)", title, selection.value)
					insert_link_at_cursor(link_text)
				end
				map("i", "<CR>", insert_selected)
				map("n", "<CR>", insert_selected)
				return true
			end,
		})
		:find()
end

function M.live_grep_link()
	local opts = {}
	opts.search_dirs = { M.config.notes_folder or vim.fn.expand("%:p:h") }
	local exclude_flags = {}
	for _, folder in ipairs(M.config.excluded_folders) do
		table.insert(exclude_flags, "--glob")
		table.insert(exclude_flags, "!" .. folder .. "/*")
	end
	for _, file in ipairs(M.config.excluded_files) do
		table.insert(exclude_flags, "--glob")
		table.insert(exclude_flags, "!" .. file)
	end

	utils.log_message("telescope.M.live_grep_link", "Exclude_flags" .. vim.inspect(exclude_flags))

	require("telescope.builtin").live_grep({
		search_dirs = opts.search_dirs,
		additional_args = function()
			return exclude_flags
		end,
		attach_mappings = function(prompt_bufnr, map)
			local function insert_selected()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				local content = utils.read_file(selection.filename)
				local title = utils.extract_title(content, selection.filename)
				local filepath
				if M.config.notes_folder and #M.config.notes_folder > 0 then
					local normalized_notes_folder = utils.normalize_folder_path(M.config.notes_folder)
					filepath = vim.fn
						.fnamemodify(selection.filename, ":p")
						:gsub("^" .. vim.fn.expand(normalized_notes_folder) .. "/", "")
				else
					filepath = vim.fn.fnamemodify(selection.filename, ":~:.")
				end
				local link_text = string.format("[%s](%s)", title, filepath)
				insert_link_at_cursor(link_text)
			end
			map("i", "<CR>", insert_selected)
			map("n", "<CR>", insert_selected)
			return true
		end,
	})
end

return M

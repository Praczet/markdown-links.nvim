local M = {}
local utils = require("markdown-links.utils")
local fzf = require("fzf-lua")

M.config = {
	filetypes = { "markdown" }, -- allowed filetypes (not supported yet) for now just markdown
	kind_hl_group = "#ffc777", -- Default color, you can override this when setting up the plugin
	excluded_files = {}, -- list of files to exclude
	excluded_folders = {}, -- list of folders to exclude
	notes_folder = nil, -- default notes folder if not give current buffer folder will be taken
	search_engine = "fzf-lua", -- options: "telescope", "fzf-lua", "auto"
	autocomplete_engine = "auto", -- options: "cmp", "blink", "auto"
}

function M.initialize(config)
	utils.log_message("fzf.M.initialize", "Initializing markdown-links.search.fzf") -- Debug
	M.config = vim.tbl_deep_extend("force", M.config, config or {})
	fzf.setup({
		formatters = {
			my_custom_formatter = function(entry, opts)
				print(vim.inspect(entry))
				local filename = vim.fn.fnamemodify(entry, ":t") -- Extract filename
				local dirname = vim.fn.fnamemodify(entry, ":h") -- Extract directory
				return string.format("%s [%s]", filename, dirname) -- Customize format
			end,
		},
	})

	require("which-key").add({
		mode = "n",
		{
			"<leader>fl",
			'<cmd>lua require("markdown-links.search.fzf").insert_link()<CR>',
			desc = "Add Link to selected file (markdown)",
		},
		{
			"<leader>fm",
			'<cmd>lua require("markdown-links.search.fzf").live_grep_link()<CR>',
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

-- Get all markdown files and insert link of selected file
function M.insert_link()
	local files = utils.get_markdown_files(M.config, false)

	fzf.fzf_exec(files, {
		prompt = "Select Markdown File> ",
		previewer = {},
		actions = {
			default = function(selected)
				local filepath = selected[1]
				local content = utils.read_file(filepath)
				local title = utils.extract_title(content, filepath)
				local link_text = string.format("[%s](%s)", title, filepath)
				insert_link_at_cursor(link_text)
			end,
		},
	})
end

-- Search markdown files and add link
--
function M.live_grep_link()
	local opts = {}
	opts.search_dirs = { M.config.notes_folder or vim.fn.expand("%:p:h") }
	local exclude_flags = {}
	for _, folder in ipairs(M.config.excluded_folders) do
		table.insert(exclude_flags, "!" .. folder .. "/*")
	end
	for _, file in ipairs(M.config.excluded_files) do
		table.insert(exclude_flags, "!" .. file)
	end

	utils.log_message("fzf.M.live_grep_link", "Exclude_flags" .. vim.inspect(exclude_flags))

	fzf.live_grep({
		search_dirs = opts.search_dirs,
		extra_args = exclude_flags,
		prompt = "Search Markdown Files> ",
		file_icons = false,

		actions = {
			default = function(selected)
				local filepath = selected[1]
				filepath = filepath:match("^(.-):%d+:%d+")
				local content = utils.read_file(filepath)
				local title = utils.extract_title(content, filepath)
				local link_text = string.format("[%s](%s)", title, filepath)
				insert_link_at_cursor(link_text)
			end,
		},
	})
end

return M

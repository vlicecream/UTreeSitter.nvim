local M = {}

local defaults = {
	parser = {
		name = "unreal_cpp",
		repo = "https://github.com/vlicecream/UTreeSitter",
		branch = "main",
		files = { "src/parser.c", "src/scanner.c" },
		queries = "queries/unreal_cpp",
		use_bundled = true,
		bundled_path = nil,
		register_preload = true,
	},
	filetype = {
		enable = true,
		unreal_only = true,
		extensions = {
			"c",
			"cc",
			"cpp",
			"cxx",
			"h",
			"hh",
			"hpp",
			"hxx",
			"inl",
		},
	},
	install = {
		auto_install = true,
		retries = 120,
		retry_delay_ms = 500,
	},
	highlight = {
		auto_start = true,
		default_links = true,
	},
}

M.values = vim.deepcopy(defaults)

function M.setup(opts)
	M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	return M.values
end

return M

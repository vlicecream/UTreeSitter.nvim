-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/config.lua
-- Purpose: Store default UTreeSitter settings and merge user overrides.
-- License: MIT

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
	verse = {
		enable = true,
		parser = {
			name = "verse",
			repo = "https://github.com/verse-lang/tree-sitter-verse",
			branch = "master",
			files = { "src/parser.c" },
			queries = "queries/verse",
			use_bundled = false,
			bundled_path = nil,
			register_preload = true,
		},
		filetype = {
			enable = true,
			extensions = {
				"verse",
			},
		},
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

-- Merge user options into the default UTreeSitter configuration.
-- 将用户选项合并到默认的 UTreeSitter 配置中。
function M.setup(opts)
	M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	return M.values
end

return M

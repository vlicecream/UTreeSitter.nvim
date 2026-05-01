local config = require("utreesitter.config")

local M = {}

local function plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(source, ":p:h:h:h")
end

local function bundled_root()
	local parser = config.values.parser
	local root = parser.bundled_path or plugin_root()
	if parser.use_bundled == false then
		return nil
	end

	if vim.fn.filereadable(root .. "/src/parser.c") == 1 and vim.fn.filereadable(root .. "/src/scanner.c") == 1 then
		return root
	end
end

function M.install_source()
	local parser = config.values.parser
	return bundled_root() or parser.repo
end

local function install_info()
	local parser = config.values.parser
	local source = M.install_source()
	local info = {
		files = parser.files,
		queries = parser.queries,
		generate_requires_npm = false,
		requires_generate_from_grammar = false,
	}

	if source == parser.repo then
		info.url = source
		info.branch = parser.branch
	else
		info.path = source
	end

	return info
end

local function parser_definition()
	return {
		install_info = install_info(),
		filetype = config.values.parser.name,
		maintainers = { "@vlicecream" },
		tier = 2,
	}
end

local function augment(parsers)
	local name = config.values.parser.name
	parsers[name] = vim.tbl_deep_extend("force", parsers[name] or {}, parser_definition())
	return parsers
end

local function stock_parsers_path()
	return vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua"
end

local function build_from_stock()
	local module_path = stock_parsers_path()
	if not vim.uv.fs_stat(module_path) then
		return nil
	end

	return augment(dofile(module_path))
end

function M.register()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = parsers
	if type(parsers.get_parser_configs) == "function" then
		configs = parsers.get_parser_configs()
	end

	if type(configs) ~= "table" then
		return false
	end

	augment(configs)
	package.loaded["nvim-treesitter.parsers"] = parsers
	return true
end

function M.install_preload()
	if config.values.parser.register_preload == false then
		return
	end

	if package.preload["nvim-treesitter.parsers"] then
		return
	end

	package.preload["nvim-treesitter.parsers"] = function()
		if type(package.loaded["nvim-treesitter.parsers"]) == "table" then
			return package.loaded["nvim-treesitter.parsers"]
		end

		local parsers = build_from_stock()
		if not parsers then
			error("nvim-treesitter.parsers not available")
		end

		package.loaded["nvim-treesitter.parsers"] = parsers
		return parsers
	end
end

function M.is_registered()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[config.values.parser.name] ~= nil
end

function M.setup()
	M.install_preload()
	M.register()
	vim.schedule(M.register)
	vim.defer_fn(M.register, 100)
	vim.defer_fn(M.register, 500)
end

return M

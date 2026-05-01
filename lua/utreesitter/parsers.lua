local config = require("utreesitter.config")

local M = {}

local function parser_definition()
	local parser = config.values.parser
	return {
		install_info = {
			url = parser.repo,
			files = parser.files,
			branch = parser.branch,
			queries = parser.queries,
			generate_requires_npm = false,
			requires_generate_from_grammar = false,
		},
		filetype = parser.name,
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

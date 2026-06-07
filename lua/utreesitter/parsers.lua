-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/parsers.lua
-- Purpose: Register bundled parser definitions with nvim-treesitter.
-- License: MIT

local config = require("utreesitter.config")

local M = {}

-- Return the plugin root directory for UTreeSitter.nvim.
-- 返回 UTreeSitter.nvim 的插件根目录。
local function plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(source, ":p:h:h:h")
end

-- Return the bundled parser source directory shipped with the plugin.
-- 返回插件附带的捆绑解析器源目录。
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

-- Return the parser source directory that should be installed for unreal_cpp.
-- 返回应该为 unreal_cpp 安装的解析器源目录。
function M.install_source()
	local parser = config.values.parser
	return bundled_root() or parser.repo
end

-- Build the install-info table consumed by nvim-treesitter.
-- 构建 nvim-treesitter 使用的安装信息表。
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

-- Build the parser definition registered with nvim-treesitter.
-- 构建使用 nvim-treesitter 注册的解析器定义。
local function parser_definition()
	return {
		install_info = install_info(),
		filetype = config.values.parser.name,
		maintainers = { "@vlicecream" },
		tier = 2,
	}
end

-- Augment the nvim-treesitter parser table with bundled Unreal parsers.
-- 使用捆绑的 Unreal 解析器扩充 nvim-treesitter 解析器表。
local function augment(parsers)
	local name = config.values.parser.name
	parsers[name] = vim.tbl_deep_extend("force", parsers[name] or {}, parser_definition())
	return parsers
end

-- Return the path to the stock nvim-treesitter parsers table.
-- 返回库存 nvim-treesitter 解析器表的路径。
local function stock_parsers_path()
	return vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua"
end

-- Load the stock parser table and augment it with Unreal definitions.
-- 加载库存解析器表并使用虚幻定义对其进行扩充。
local function build_from_stock()
	local module_path = stock_parsers_path()
	if not vim.uv.fs_stat(module_path) then
		return nil
	end

	return augment(dofile(module_path))
end

-- Register the Unreal parser definitions with nvim-treesitter.
-- 使用 nvim-treesitter 注册 Unreal 解析器定义。
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

-- Preload parser definitions before install commands run.
-- 在运行安装命令之前预加载解析器定义。
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

-- Return whether the Unreal parser definition is already registered.
-- 返回 Unreal 解析器定义是否已注册。
function M.is_registered()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[config.values.parser.name] ~= nil
end

-- Register parser definitions as part of module setup.
-- 将解析器定义注册为模块设置的一部分。
function M.setup()
	M.install_preload()
	M.register()
	vim.schedule(M.register)
	vim.defer_fn(M.register, 100)
	vim.defer_fn(M.register, 500)
end

return M

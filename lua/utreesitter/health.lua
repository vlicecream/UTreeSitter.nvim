-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/health.lua
-- Purpose: Report UTreeSitter parser, query, and dependency health through :checkhealth.
-- License: MIT

local config = require("utreesitter.config")
local filetype = require("utreesitter.filetype")
local parsers = require("utreesitter.parsers")

local M = {}

local health = vim.health or {}
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local info = health.info or health.report_info

-- Return whether one Lua module can be required successfully.
-- 返回是否可以成功请求一个Lua模块。
local function has_module(name)
	return pcall(require, name)
end

-- Return whether one tree-sitter query kind is currently loaded.
-- 返回当前是否加载了一种树保姆查询类型。
local function query_loaded(kind)
	local parser = config.values.parser.name
	local loaded, query = pcall(vim.treesitter.query.get, parser, kind)
	return loaded and query ~= nil
end

-- Return whether one Verse query kind is currently loaded.
-- 返回当前是否加载了一种 Verse 查询类型。
local function verse_query_loaded(kind)
	local verse = config.values.verse
	if not verse or verse.enable == false or not verse.parser then
		return false
	end

	local loaded, query = pcall(vim.treesitter.query.get, verse.parser.name, kind)
	return loaded and query ~= nil
end

-- Check parser, query, and dependency health for UTreeSitter.
-- 检查 UTreeSitter 的解析器、查询和依赖项运行状况。
function M.check()
	start("UTreeSitter.nvim")

	ok("Plugin health module loaded")

	if has_module("nvim-treesitter.parsers") then
		ok("nvim-treesitter.parsers available")
	else
		warn("nvim-treesitter.parsers is not available", {
			"Install nvim-treesitter before installing the unreal_cpp parser.",
		})
	end

	parsers.register()
	if parsers.is_registered() then
		ok("unreal_cpp parser config registered")
		info("install source: " .. tostring(parsers.install_source()))
	else
		warn("unreal_cpp parser config is not registered")
	end

	local installed, install_path = require("utreesitter").parser_installed()
	if installed then
		ok("unreal_cpp parser installed: " .. install_path)
	else
		warn("unreal_cpp parser is not installed", {
			"Run :UTreeSitterInstall.",
		})
	end

	if query_loaded("highlights") then
		ok("highlights query loaded")
	else
		warn("highlights query cannot be loaded from runtimepath")
	end

	local verse = config.values.verse
	if verse and verse.enable ~= false and verse.parser then
		if parsers.is_registered(verse.parser.name) then
			ok("verse parser config registered")
			info("verse install source: " .. tostring(parsers.install_source(verse.parser.name)))
		else
			warn("verse parser config is not registered")
		end

		local verse_installed, verse_install_path = require("utreesitter").parser_installed(verse.parser.name)
		if verse_installed then
			ok("verse parser installed: " .. verse_install_path)
		else
			warn("verse parser is not installed", {
				"Run :UTreeSitterInstall.",
			})
		end

		if verse_query_loaded("highlights") then
			ok("verse highlights query loaded")
		else
			warn("verse highlights query cannot be loaded from runtimepath")
		end
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local ft = vim.bo[bufnr].filetype
	info("current filetype: " .. tostring(ft))

	if path == "" or path:match("^health://") then
		info("open an Unreal C++ file to validate filetype detection")
		return
	end

	if filetype.is_unreal_path(path) then
		ok("current buffer is inside an Unreal project")
	else
		info("current buffer is not detected as an Unreal project file")
	end

	if ft == config.values.parser.name then
		ok("current buffer uses filetype " .. config.values.parser.name)
	else
		info("current buffer filetype is " .. tostring(ft))
	end
end

return M

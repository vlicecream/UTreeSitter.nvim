local config = require("utreesitter.config")
local filetype = require("utreesitter.filetype")
local parsers = require("utreesitter.parsers")

local M = {}

local health = vim.health or {}
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local info = health.info or health.report_info

local function has_module(name)
	return pcall(require, name)
end

local function query_loaded(kind)
	local parser = config.values.parser.name
	local loaded, query = pcall(vim.treesitter.query.get, parser, kind)
	return loaded and query ~= nil
end

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

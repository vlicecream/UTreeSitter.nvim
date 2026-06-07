-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/filetype.lua
-- Purpose: Detect Unreal-oriented filetypes and attach them to matching buffers.
-- License: MIT

local config = require("utreesitter.config")

local M = {}

-- Return the supported Unreal shader file extensions as a lookup set.
-- 返回受支持的虚幻着色器文件扩展名作为查找集。
local function extension_set()
	local set = {}
	for _, ext in ipairs(config.values.filetype.extensions or {}) do
		set[ext] = true
	end
	return set
end

-- Normalize one filesystem path to forward-slash form.
-- 将一个文件系统路径规范为正斜杠形式。
local function normalize(path)
	if not path or path == "" then
		return ""
	end
	return vim.fs.normalize(path):gsub("\\", "/")
end

-- Return whether one runtime file exists in the current Neovim runtime path.
-- 返回当前 Neovim 运行时路径中是否存在一个运行时文件。
local function has_runtime_file(path)
	return #vim.api.nvim_get_runtime_file(path, true) > 0
end

-- Return whether the requested tree-sitter parser is already available.
-- 返回所请求的树守护者解析器是否已经可用。
local function has_treesitter_parser(name)
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[name] ~= nil
end

-- Return the preferred shader filetype based on installed parsers.
-- 根据已安装的解析器返回首选着色器文件类型。
local function preferred_shader_filetype()
	if has_treesitter_parser("hlsl")
		or has_runtime_file("syntax/hlsl.vim")
		or has_runtime_file("ftplugin/hlsl.vim")
		or has_runtime_file("indent/hlsl.vim")
		or has_runtime_file("queries/hlsl/highlights.scm")
		or #vim.api.nvim_get_runtime_file("parser/hlsl.*", true) > 0
	then
		return "hlsl"
	end

	return "cpp"
end

-- Return whether one path ends with a supported Unreal shader extension.
-- 返回一条路径是否以受支持的虚幻着色器扩展结尾。
local function has_supported_extension(path)
	local ext = path and path:match("%.([^.\\/]*)$")
	return ext and extension_set()[ext] == true
end

-- Return the parent directory for one normalized path.
-- 返回一个标准化路径的父目录。
local function dirname(path)
	if not path or path == "" then
		return nil
	end
	return vim.fs.dirname(vim.fs.normalize(path))
end

-- Detect special Unreal shader filetypes from path conventions.
-- 从路径约定中检测特殊的虚幻着色器文件类型。
local function detect_special(path)
	local normalized = normalize(path)
	if normalized:match("%.uproject$") or normalized:match("%.uplugin$") then
		return "json"
	end

	if normalized:match("%.Build%.cs$") or normalized:match("%.Target%.cs$") then
		return "cs"
	end

	if normalized:match("%.hlsl$") or normalized:match("%.hlsli$") or normalized:match("%.usf$") or normalized:match("%.ush$") then
		return preferred_shader_filetype()
	end
end

-- Return whether one path matches any pattern in the provided list.
-- 返回一个路径是否与提供的列表中的任何模式匹配。
local function match_any(path, patterns)
	for _, pattern in ipairs(patterns) do
		if path:match(pattern) then
			return true
		end
	end
	return false
end

-- Return whether one path sits inside a recognizable Unreal project layout.
-- 返回一条路径是否位于可识别的虚幻项目布局内。
local function path_has_unreal_layout(path)
	local normalized = normalize(path)
	return match_any(normalized, {
		"/Source/[^/]+/Public/",
		"/Source/[^/]+/Private/",
		"/Source/[^/]+/Classes/",
		"/Plugins/.+/Source/.+/Public/",
		"/Plugins/.+/Source/.+/Private/",
		"/Plugins/.+/Source/.+/Classes/",
		"/Engine/Source/.+/Public/",
		"/Engine/Source/.+/Private/",
		"/Engine/Source/.+/Classes/",
		"/Source/.+%.Build%.cs$",
		"/Source/.+%.Target%.cs$",
	})
end

-- Return whether one path belongs to an Unreal project or engine layout.
-- 返回一个路径是否属于虚幻项目或引擎布局。
function M.is_unreal_path(path)
	if detect_special(path) then
		return true
	end

	local dir = dirname(path)
	if not dir then
		return false
	end

	local markers = vim.fs.find(function(name)
		return name:match("%.uproject$")
			or name:match("%.uplugin$")
			or name:match("%.Build%.cs$")
			or name:match("%.Target%.cs$")
	end, {
		path = dir,
		upward = true,
		type = "file",
		limit = 1,
	})

	return #markers > 0 or path_has_unreal_layout(path)
end

-- Detect the filetype that should be applied to one path.
-- 检测应应用于一个路径的文件类型。
function M.detect(path)
	local special = detect_special(path)
	if special then
		return special
	end

	local values = config.values
	if not has_supported_extension(path) then
		return nil
	end

	if values.filetype.unreal_only == false or M.is_unreal_path(path) then
		return values.parser.name
	end
end

-- Apply the detected UTreeSitter filetype to one buffer.
-- 将检测到的 UTreeSitter 文件类型应用到一个缓冲区。
function M.apply_to_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local path = vim.api.nvim_buf_get_name(bufnr)
	local detected = M.detect(path)
	if detected and vim.bo[bufnr].filetype ~= detected then
		vim.bo[bufnr].filetype = detected
	end
end

-- Register the filetype autocmds used by UTreeSitter.
-- 注册 UTreeSitter 使用的文件类型自动命令。
function M.setup()
	local values = config.values
	if values.filetype.enable == false then
		return
	end

	local extension_map = {}
	for _, ext in ipairs(values.filetype.extensions or {}) do
		extension_map[ext] = function(path)
			return M.detect(path)
		end
	end

	vim.filetype.add({
		extension = extension_map,
		pattern = {
			[".*%.uproject"] = function(path)
				return M.detect(path)
			end,
			[".*%.uplugin"] = function(path)
				return M.detect(path)
			end,
			[".*%.Build%.cs"] = function(path)
				return M.detect(path)
			end,
			[".*%.Target%.cs"] = function(path)
				return M.detect(path)
			end,
			[".*%.hlsl"] = function(path)
				return M.detect(path)
			end,
			[".*%.hlsli"] = function(path)
				return M.detect(path)
			end,
			[".*%.usf"] = function(path)
				return M.detect(path)
			end,
			[".*%.ush"] = function(path)
				return M.detect(path)
			end,
		},
	})

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = vim.api.nvim_create_augroup("UTreeSitterFiletype", { clear = true }),
		callback = function(ev)
			M.apply_to_buffer(ev.buf)
		end,
	})
end

return M

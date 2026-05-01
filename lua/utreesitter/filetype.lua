local config = require("utreesitter.config")

local M = {}

local function extension_set()
	local set = {}
	for _, ext in ipairs(config.values.filetype.extensions or {}) do
		set[ext] = true
	end
	return set
end

local function normalize(path)
	if not path or path == "" then
		return ""
	end
	return vim.fs.normalize(path):gsub("\\", "/")
end

local function has_runtime_file(path)
	return #vim.api.nvim_get_runtime_file(path, true) > 0
end

local function has_treesitter_parser(name)
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[name] ~= nil
end

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

local function has_supported_extension(path)
	local ext = path and path:match("%.([^.\\/]*)$")
	return ext and extension_set()[ext] == true
end

local function dirname(path)
	if not path or path == "" then
		return nil
	end
	return vim.fs.dirname(vim.fs.normalize(path))
end

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

local function match_any(path, patterns)
	for _, pattern in ipairs(patterns) do
		if path:match(pattern) then
			return true
		end
	end
	return false
end

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

local config = require("utreesitter.config")

local M = {}

local function extension_set()
	local set = {}
	for _, ext in ipairs(config.values.filetype.extensions or {}) do
		set[ext] = true
	end
	return set
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

local function path_has_unreal_layout(path)
	local normalized = vim.fs.normalize(path):gsub("\\", "/")
	return normalized:match("/Source/[^/]+/Public/") ~= nil
		or normalized:match("/Source/[^/]+/Private/") ~= nil
		or normalized:match("/Source/[^/]+/Classes/") ~= nil
		or normalized:match("/Source/[^/]+/.+%.Build%.cs$") ~= nil
end

function M.is_unreal_path(path)
	local dir = dirname(path)
	if not dir then
		return false
	end

	local markers = vim.fs.find(function(name)
		return name:match("%.uproject$") or name:match("%.uplugin$") or name:match("%.Build%.cs$")
	end, {
		path = dir,
		upward = true,
		type = "file",
		limit = 1,
	})

	return #markers > 0 or path_has_unreal_layout(path)
end

function M.detect(path)
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
	})

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = vim.api.nvim_create_augroup("UTreeSitterFiletype", { clear = true }),
		callback = function(ev)
			M.apply_to_buffer(ev.buf)
		end,
	})
end

return M

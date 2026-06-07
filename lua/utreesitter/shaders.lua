-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/shaders.lua
-- Purpose: Install and attach the HLSL shader parser used by Unreal shader files.
-- License: MIT

local config = require("utreesitter.config")

local M = {}

local installing = false
local install_command_started = false
local pending_buffers = {}

-- Return the parser name configured for HLSL shader buffers.
-- 返回为 HLSL 着色器缓冲区配置的解析器名称。
local function parser_name()
	return "hlsl"
end

-- Return the retry budget used while waiting for shader parser installation.
-- 返回等待着色器解析器安装时使用的重试预算。
local function install_retries()
	return math.max(config.values.install.retries or 0, 600)
end

-- Send one shader-parser notification with the standard title.
-- 发送一个带有标准标题的着色器解析器通知。
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "UTreeSitter.nvim" })
end

-- Collect the filesystem paths where the shader parser binary may exist.
-- 收集着色器解析器二进制文件可能存在的文件系统路径。
local function parser_paths()
	local name = parser_name()
	local paths = {}
	local seen = {}

	-- Add one shader parser path candidate when it is non-empty and not duplicated.
	-- 当候选着色器解析器路径非空且不重复时，添加一个。
	local function add(path)
		if path and path ~= "" then
			local normalized = vim.fs.normalize(path)
			if not seen[normalized] then
				seen[normalized] = true
				table.insert(paths, normalized)
			end
		end
	end

	-- Add shader parser binary candidates from one parser install directory.
	-- 从一个解析器安装目录添加着色器解析器二进制候选。
	local function add_from_dir(dir)
		if not dir or dir == "" then
			return
		end
		add(dir .. "/" .. name .. ".so")
		add(dir .. "/" .. name .. ".dll")
		add(dir .. "/" .. name .. ".dylib")
	end

	add_from_dir(vim.fn.stdpath("data") .. "/site/parser")

	local ok_config, ts_config = pcall(require, "nvim-treesitter.config")
	if ok_config and type(ts_config.get_install_dir) == "function" then
		add_from_dir(ts_config.get_install_dir("parser"))
	end

	for _, path in ipairs(vim.api.nvim_get_runtime_file("parser/" .. name .. ".*", true)) do
		add(path)
	end

	return paths
end

-- Return whether the HLSL parser definition is already registered.
-- 返回 HLSL 解析器定义是否已注册。
local function parser_registered()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[parser_name()] ~= nil
end

-- Return whether the HLSL parser binary is already installed.
-- 返回 HLSL 解析器二进制文件是否已安装。
function M.parser_installed()
	for _, path in ipairs(parser_paths()) do
		if vim.fn.filereadable(path) == 1 then
			return true, path
		end
	end
	return false, nil
end

-- Register the HLSL parser binary with Neovim when it is installed.
-- 安装后，向 Neovim 注册 HLSL 解析器二进制文件。
local function ensure_language()
	local installed, path = M.parser_installed()
	if not installed then
		return false
	end

	local ok = pcall(vim.treesitter.language.add, parser_name(), { path = path })
	return ok
end

-- Return whether the HLSL parser can attach to one buffer right now.
-- 返回 HLSL 解析器现在是否可以附加到一个缓冲区。
function M.parser_can_attach(bufnr)
	ensure_language()
	local ok, parser_or_err = pcall(vim.treesitter.get_parser, bufnr or 0, parser_name())
	return ok and parser_or_err ~= nil, parser_or_err
end

-- Return whether nvim-treesitter is available for shader parser work.
-- 返回 nvim-treesitter 是否可用于着色器解析器工作。
local function treesitter_ready()
	local ok, ts = pcall(require, "nvim-treesitter")
	if not ok or type(ts.install) ~= "function" then
		return false
	end

	return parser_registered()
end

-- Start installing the HLSL parser once and avoid duplicate installs.
-- 开始安装 HLSL 解析器一次即可避免重复安装。
local function run_parser_install()
	if install_command_started then
		return true
	end

	install_command_started = true
	local ok = pcall(function()
		require("nvim-treesitter").install({ parser_name() }, { max_jobs = 1 })
	end)
	if not ok then
		install_command_started = false
	end
	return ok
end

-- Retry HLSL parser attachment for buffers that were waiting on installation.
-- 对等待安装的缓冲区重试 HLSL 解析器附件。
local function retry_pending()
	local pending = pending_buffers
	pending_buffers = {}
	for bufnr, _ in pairs(pending) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			M.activate_buffer(bufnr)
		end
	end

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == parser_name() then
			M.activate_buffer(bufnr)
		end
	end
end

-- Return whether any pending shader buffer can now attach to the parser.
-- 返回任何挂起的着色器缓冲区现在是否可以附加到解析器。
local function any_pending_can_attach()
	for bufnr, _ in pairs(pending_buffers) do
		if M.parser_can_attach(bufnr) then
			return true
		end
	end
	return false
end

-- Poll HLSL parser installation progress until it succeeds or times out.
-- 轮询 HLSL 解析器安装进度，直到成功或超时。
local function install_with_retry(remaining)
	-- Shader parser install uses the same retry pattern as unreal_cpp so newly
	-- opened shader buffers can start parsing without requiring a manual reopen.
	-- 着色器解析器安装沿用和 unreal_cpp 相同的重试模式，
	-- 这样新打开的着色器缓冲区无需手动重开也能开始解析。
	if remaining <= 0 then
		installing = false
		install_command_started = false
		notify("hlsl parser install did not finish before retries ended", vim.log.levels.WARN)
		return
	end

	if M.parser_installed() or any_pending_can_attach() then
		ensure_language()
		installing = false
		install_command_started = false
		retry_pending()
		return
	end

	if not treesitter_ready() then
		vim.defer_fn(function()
			install_with_retry(remaining - 1)
		end, config.values.install.retry_delay_ms)
		return
	end

	if not install_command_started then
		notify("Installing hlsl parser")
	end
	run_parser_install()

	if M.parser_installed() or any_pending_can_attach() then
		ensure_language()
		installing = false
		install_command_started = false
		retry_pending()
		return
	end

	vim.defer_fn(function()
		install_with_retry(remaining - 1)
	end, config.values.install.retry_delay_ms)
end

-- Attach the HLSL parser and highlights to one buffer when possible.
-- 如果可能，将 HLSL 解析器和突出显示附加到一个缓冲区。
function M.activate_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	if vim.bo[bufnr].filetype ~= parser_name() then
		return
	end

	if M.parser_can_attach(bufnr) then
		pcall(vim.treesitter.start, bufnr, parser_name())
		return
	end

	if config.values.install.auto_install == false then
		return
	end

	pending_buffers[bufnr] = true
	if installing then
		return
	end

	installing = true
	install_command_started = false
	install_with_retry(install_retries())
end

-- Activate shader parsing on every currently loaded matching buffer.
-- 在每个当前加载的匹配缓冲区上激活着色器解析。
function M.activate_existing_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == parser_name() then
			M.activate_buffer(bufnr)
		end
	end
end

-- Ensure shader parser installation starts when the parser is still missing.
-- 确保在解析器仍然丢失时开始着色器解析器安装。
function M.ensure_installed()
	if config.values.install.auto_install == false then
		return
	end

	if M.parser_installed() then
		ensure_language()
		M.activate_existing_buffers()
		return
	end

	if installing then
		return
	end

	installing = true
	install_command_started = false
	install_with_retry(install_retries())
end

-- Reset shader parser install state and pending buffers.
-- 重置着色器解析器安装状态和挂起的缓冲区。
function M.reset()
	installing = false
	install_command_started = false
	pending_buffers = {}
end

return M

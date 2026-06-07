-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/init.lua
-- Purpose: Install parsers, attach them to buffers, and manage the main UTreeSitter lifecycle.
-- License: MIT

local config = require("utreesitter.config")
local filetype = require("utreesitter.filetype")
local parsers = require("utreesitter.parsers")
local shaders = require("utreesitter.shaders")

local M = {}

local installing = false
local install_command_started = false
local pending_buffers = {}
local setup_done = false

-- Return the parser name configured for Unreal C++ buffers.
-- 返回为 Unreal C++ 缓冲区配置的解析器名称。
local function parser_name()
	return config.values.parser.name
end

-- Return the retry budget used while waiting for parser installation to finish.
-- 返回等待解析器安装完成时使用的重试预算。
local function install_retries()
	return math.max(config.values.install.retries or 0, 600)
end

-- Send one UTreeSitter notification with the standard title.
-- 发送一份带有标准标题的 UTreeSitter 通知。
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "UTreeSitter.nvim" })
end

-- Collect the filesystem paths where the Unreal parser binary may exist.
-- 收集 Unreal 解析器二进制文件可能存在的文件系统路径。
local function parser_paths()
	local name = parser_name()
	local paths = {}
	local seen = {}

	-- Add one parser path candidate when it is non-empty and not duplicated.
	-- 当候选解析器路径非空且不重复时，添加一个。
	local function add(path)
		if path and path ~= "" then
			local normalized = vim.fs.normalize(path)
			if not seen[normalized] then
				seen[normalized] = true
				table.insert(paths, normalized)
			end
		end
	end

	-- Add parser binary candidates from one parser install directory.
	-- 从一个解析器安装目录添加解析器二进制候选。
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

-- Return whether the Unreal parser binary is already installed.
-- 返回 Unreal 解析器二进制文件是否已安装。
function M.parser_installed()
	for _, path in ipairs(parser_paths()) do
		if vim.fn.filereadable(path) == 1 then
			return true, path
		end
	end
	return false, nil
end

-- Register the Unreal parser binary with Neovim when it is installed.
-- 安装时向 Neovim 注册 Unreal 解析器二进制文件。
local function ensure_language()
	local installed, path = M.parser_installed()
	if not installed then
		return false
	end

	local ok, err = pcall(vim.treesitter.language.add, parser_name(), { path = path })
	return ok
end

-- Return whether the Unreal parser can attach to one buffer right now.
-- 返回虚幻解析器现在是否可以附加到一个缓冲区。
function M.parser_can_attach(bufnr)
	ensure_language()
	local ok, parser_or_err = pcall(vim.treesitter.get_parser, bufnr or 0, parser_name())
	return ok and parser_or_err ~= nil, parser_or_err
end

-- Return whether nvim-treesitter is available and parser definitions are registered.
-- 返回 nvim-treesitter 是否可用以及解析器定义是否已注册。
local function treesitter_ready()
	local ok, ts = pcall(require, "nvim-treesitter")
	if not ok or type(ts.install) ~= "function" then
		return false
	end

	parsers.register()
	return parsers.is_registered()
end

-- Start parser installation once and avoid duplicate install commands.
-- 启动解析器安装一次并避免重复的安装命令。
local function run_parser_install()
	if install_command_started then
		return true
	end

	install_command_started = true
	local ok = pcall(function()
		require("nvim-treesitter").install({ parser_name(), "hlsl" }, { max_jobs = 1 })
	end)
	if not ok then
		install_command_started = false
	end
	return ok
end

-- Retry parser attachment for buffers that were waiting on installation.
-- 重试正在等待安装的缓冲区的解析器附件。
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

-- Return whether any pending buffer can now attach to the parser.
-- 返回任何挂起的缓冲区现在是否可以附加到解析器。
local function any_pending_can_attach()
	for bufnr, _ in pairs(pending_buffers) do
		if M.parser_can_attach(bufnr) then
			return true
		end
	end
	return false
end

-- Poll parser installation progress and retry attachment until it succeeds or times out.
-- 轮询解析器安装进度并重试附件，直到成功或超时。
local function install_with_retry(remaining)
	-- Keep retrying from the editor side because :TSInstall may finish after the
	-- initial request returns, and pending buffers should attach automatically.
	-- 这里在编辑器侧持续重试，因为 :TSInstall 可能会在初次请求返回后才完成，
	-- 等待中的缓冲区应该在安装完成后自动附加解析器。
	if remaining <= 0 then
		installing = false
		install_command_started = false
		notify("unreal_cpp parser install did not finish before retries ended", vim.log.levels.WARN)
		return
	end

	if M.parser_installed() then
		ensure_language()
		installing = false
		install_command_started = false
		retry_pending()
		shaders.ensure_installed()
		return
	end

	if any_pending_can_attach() then
		installing = false
		install_command_started = false
		retry_pending()
		shaders.ensure_installed()
		return
	end

	if not treesitter_ready() then
		vim.defer_fn(function()
			install_with_retry(remaining - 1)
		end, config.values.install.retry_delay_ms)
		return
	end

	if not install_command_started then
		notify("Installing unreal_cpp and hlsl parsers")
	end
	run_parser_install()

	if M.parser_installed() or any_pending_can_attach() then
		ensure_language()
		installing = false
		retry_pending()
		shaders.ensure_installed()
		return
	end

	vim.defer_fn(function()
		install_with_retry(remaining - 1)
	end, config.values.install.retry_delay_ms)
end

-- Start installing the Unreal parser and return whether it is already available.
-- 开始安装Unreal解析器并返回它是否已经可用。
function M.install()
	install_command_started = false
	parsers.register()
	if not run_parser_install() then
		notify("nvim-treesitter :TSInstall/:TSInstallSync is not available", vim.log.levels.WARN)
		return false
	end

	local installed = M.parser_installed()
	if installed then
		ensure_language()
	end
	return installed
end

-- Uninstall and then reinstall the Unreal parser.
-- 卸载并重新安装 Unreal 解析器。
function M.reinstall()
	parsers.register()
	if vim.fn.exists(":TSUninstall") == 2 then
		pcall(vim.cmd, "TSUninstall " .. parser_name())
	end
	return M.install()
end

-- Attach the Unreal parser and highlights to one buffer when possible.
-- 如果可能，将虚幻解析器和突出显示附加到一个缓冲区。
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
	install_with_retry(install_retries())
end

-- Activate UTreeSitter on every currently loaded matching buffer.
-- 在每个当前加载的匹配缓冲区上激活 UTreeSitter。
local function activate_existing_buffers()
	parsers.register()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == parser_name() then
			M.activate_buffer(bufnr)
		end
	end
end

-- Ensure parser installation starts when the parser is still missing.
-- 确保在解析器仍然丢失时开始解析器安装。
function M.ensure_installed()
	if config.values.install.auto_install == false then
		return
	end

	if M.parser_installed() then
		ensure_language()
		activate_existing_buffers()
		shaders.ensure_installed()
		return
	end

	if installing then
		return
	end

	installing = true
	install_command_started = false
	install_with_retry(install_retries())
end

-- Return whether one tree-sitter query kind is currently loaded.
-- 返回当前是否加载了一种树保姆查询类型。
local function query_loaded(kind)
	ensure_language()
	local ok, query = pcall(vim.treesitter.query.get, parser_name(), kind)
	return ok and query ~= nil
end

-- Return an information table that summarizes current parser and query state.
-- 返回总结当前解析器和查询状态的信息表。
function M.info()
	local bufnr = vim.api.nvim_get_current_buf()
	local buffer_path = vim.api.nvim_buf_get_name(bufnr)
	local installed, install_path = M.parser_installed()

	return {
		"parser: " .. parser_name(),
		"parser registered: " .. tostring(parsers.is_registered()),
		"install source: " .. tostring(parsers.install_source()),
		"parser installed: " .. tostring(installed) .. (install_path and " (" .. install_path .. ")" or ""),
		"highlights query: " .. tostring(query_loaded("highlights")),
		"current filetype: " .. tostring(vim.bo[bufnr].filetype),
		"current buffer: " .. (buffer_path ~= "" and buffer_path or "<none>"),
		"unreal project: " .. tostring(buffer_path ~= "" and filetype.is_unreal_path(buffer_path) or false),
	}
end

-- Notify the user with the current parser and query state summary.
-- 通知用户当前解析器和查询状态摘要。
function M.notify_info()
	notify(table.concat(M.info(), "\n"))
end

-- Open an inspection window for the current buffer parser state.
-- 打开当前缓冲区解析器状态的检查窗口。
function M.inspect_buffer()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype ~= parser_name() then
		notify("current buffer filetype is " .. tostring(vim.bo[bufnr].filetype) .. ", not " .. parser_name(), vim.log.levels.WARN)
		return
	end

	local ok, result = M.parser_can_attach(bufnr)
	if ok and result then
		notify("unreal_cpp parser can attach to the current buffer")
	else
		notify("unreal_cpp parser cannot attach: " .. tostring(result), vim.log.levels.WARN)
	end
end

-- Set up UTreeSitter configuration, commands, filetypes, and parser installation hooks.
-- 设置 UTreeSitter 配置、命令、文件类型和解析器安装挂钩。
function M.setup(opts)
	M.reset()
	setup_done = true
	config.setup(opts)
	parsers.setup()
	filetype.setup()
	require("utreesitter.highlights").setup()
	require("utreesitter.commands").setup()

	vim.api.nvim_create_autocmd("FileType", {
		pattern = parser_name(),
		group = vim.api.nvim_create_augroup("UTreeSitterUnrealCppActivate", { clear = true }),
		callback = function(ev)
			if config.values.highlight.auto_start then
				vim.schedule(function()
					M.activate_buffer(ev.buf)
				end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "hlsl",
		group = vim.api.nvim_create_augroup("UTreeSitterHlslActivate", { clear = true }),
		callback = function(ev)
			if config.values.highlight.auto_start then
				vim.schedule(function()
					shaders.activate_buffer(ev.buf)
				end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = { "LazyDone", "VeryLazy" },
		group = vim.api.nvim_create_augroup("UTreeSitterLazyRetry", { clear = true }),
		callback = function()
			vim.defer_fn(activate_existing_buffers, 100)
			vim.defer_fn(shaders.activate_existing_buffers, 100)
			vim.defer_fn(activate_existing_buffers, 500)
			vim.defer_fn(shaders.activate_existing_buffers, 500)
			vim.defer_fn(M.ensure_installed, 600)
		end,
	})

	activate_existing_buffers()
	shaders.activate_existing_buffers()
	vim.defer_fn(M.ensure_installed, 100)
	vim.defer_fn(M.ensure_installed, 500)
	vim.defer_fn(M.ensure_installed, 1500)
end

-- Return whether UTreeSitter setup has already completed.
-- 返回 UTreeSitter 设置是否已完成。
function M.is_setup()
	return setup_done
end

-- Reset UTreeSitter commands, autocmds, and internal install state.
-- 重置 UTreeSitter 命令、自动命令和内部安装状态。
function M.reset()
	installing = false
	install_command_started = false
	pending_buffers = {}
	setup_done = false

	pcall(function()
		require("utreesitter.commands").reset()
	end)
	pcall(function()
		require("utreesitter.shaders").reset()
	end)

	for _, group in ipairs({
		"UTreeSitterUnrealCppActivate",
		"UTreeSitterHlslActivate",
		"UTreeSitterLazyRetry",
		"UTreeSitterFiletype",
		"UTreeSitterHighlightLinks",
	}) do
		pcall(vim.api.nvim_del_augroup_by_name, group)
	end
end

return M

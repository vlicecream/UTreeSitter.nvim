local config = require("utreesitter.config")
local filetype = require("utreesitter.filetype")
local log = require("utreesitter.log")
local parsers = require("utreesitter.parsers")

local M = {}

local installing = false
local install_command_started = false
local pending_buffers = {}
local setup_done = false

local function parser_name()
	return config.values.parser.name
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "UTreeSitter.nvim" })
end

local function parser_paths()
	local name = parser_name()
	local paths = {}
	local seen = {}

	local function add(path)
		if path and path ~= "" then
			local normalized = vim.fs.normalize(path)
			if not seen[normalized] then
				seen[normalized] = true
				table.insert(paths, normalized)
			end
		end
	end

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

	log.write("parser.paths", paths)
	return paths
end

function M.parser_installed()
	for _, path in ipairs(parser_paths()) do
		if vim.fn.filereadable(path) == 1 then
			log.write("parser.installed.true", path)
			return true, path
		end
	end
	log.write("parser.installed.false", parser_paths())
	return false, nil
end

local function ensure_language()
	local installed, path = M.parser_installed()
	if not installed then
		return false
	end

	local ok, err = pcall(vim.treesitter.language.add, parser_name(), { path = path })
	log.write("parser.language.add", { ok = ok, path = path, err = err })
	return ok
end

function M.parser_can_attach(bufnr)
	ensure_language()
	local ok, parser_or_err = pcall(vim.treesitter.get_parser, bufnr or 0, parser_name())
	log.write("parser.can_attach", {
		bufnr = bufnr or 0,
		ok = ok,
		result = ok and "parser" or tostring(parser_or_err),
	})
	return ok, parser_or_err
end

local function treesitter_ready()
	if vim.fn.exists(":TSInstallSync") ~= 2 and vim.fn.exists(":TSInstall") ~= 2 then
		log.write("treesitter.ready.false", {
			TSInstall = vim.fn.exists(":TSInstall"),
			TSInstallSync = vim.fn.exists(":TSInstallSync"),
		})
		return false
	end

	parsers.register()
	local registered = parsers.is_registered()
	log.write("treesitter.ready", registered)
	return registered
end

local function run_parser_install()
	if install_command_started then
		log.write("install.command.skipped_already_started")
		return true
	end

	install_command_started = true

	if vim.fn.exists(":TSInstallSync") == 2 then
		log.write("install.command", "TSInstallSync! " .. parser_name())
		local ok, err = pcall(vim.cmd, "TSInstallSync! " .. parser_name())
		log.write("install.command.result", { ok = ok, err = err })
		return true
	end

	if vim.fn.exists(":TSInstall") == 2 then
		log.write("install.command", "TSInstall! " .. parser_name())
		local ok, err = pcall(vim.cmd, "TSInstall! " .. parser_name())
		log.write("install.command.result", { ok = ok, err = err })
		return true
	end

	log.write("install.command.missing")
	install_command_started = false
	return false
end

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

local function any_pending_can_attach()
	for bufnr, _ in pairs(pending_buffers) do
		if M.parser_can_attach(bufnr) then
			return true
		end
	end
	return false
end

local function install_with_retry(remaining)
	log.write("install.retry", { remaining = remaining, installing = installing })
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
		return
	end

	if any_pending_can_attach() then
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
		notify("Installing unreal_cpp parser")
	end
	run_parser_install()

	if M.parser_installed() or any_pending_can_attach() then
		ensure_language()
		installing = false
		retry_pending()
		return
	end

	vim.defer_fn(function()
		install_with_retry(remaining - 1)
	end, config.values.install.retry_delay_ms)
end

function M.install()
	log.write("install.manual")
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

function M.reinstall()
	parsers.register()
	if vim.fn.exists(":TSUninstall") == 2 then
		pcall(vim.cmd, "TSUninstall " .. parser_name())
	end
	return M.install()
end

function M.activate_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	log.write("buffer.activate.start", {
		bufnr = bufnr,
		valid = vim.api.nvim_buf_is_valid(bufnr),
		filetype = vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype or nil,
		name = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or nil,
	})
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
		log.write("buffer.activate.auto_install_disabled")
		return
	end

	pending_buffers[bufnr] = true
	if installing then
		return
	end

	installing = true
	install_with_retry(config.values.install.retries)
end

local function activate_existing_buffers()
	parsers.register()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == parser_name() then
			M.activate_buffer(bufnr)
		end
	end
end

function M.ensure_installed()
	log.write("install.ensure", {
		auto_install = config.values.install.auto_install,
		installing = installing,
	})

	if config.values.install.auto_install == false then
		return
	end

	if M.parser_installed() then
		ensure_language()
		activate_existing_buffers()
		return
	end

	if installing then
		return
	end

	installing = true
	install_command_started = false
	install_with_retry(config.values.install.retries)
end

local function query_loaded(kind)
	ensure_language()
	local ok, query = pcall(vim.treesitter.query.get, parser_name(), kind)
	log.write("query.loaded", { kind = kind, ok = ok, loaded = ok and query ~= nil or false, err = ok and nil or query })
	return ok and query ~= nil
end

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

function M.notify_info()
	notify(table.concat(M.info(), "\n"))
end

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

function M.setup(opts)
	setup_done = true
	config.setup(opts)
	log.write("setup.start", {
		install_source = parsers.install_source(),
		auto_install = config.values.install.auto_install,
		auto_start = config.values.highlight.auto_start,
	})
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

	vim.api.nvim_create_autocmd("User", {
		pattern = { "LazyDone", "VeryLazy" },
		group = vim.api.nvim_create_augroup("UTreeSitterLazyRetry", { clear = true }),
		callback = function()
			vim.defer_fn(activate_existing_buffers, 100)
			vim.defer_fn(activate_existing_buffers, 500)
			vim.defer_fn(M.ensure_installed, 600)
		end,
	})

	activate_existing_buffers()
	vim.defer_fn(M.ensure_installed, 100)
	vim.defer_fn(M.ensure_installed, 500)
	vim.defer_fn(M.ensure_installed, 1500)
end

function M.is_setup()
	return setup_done
end

return M

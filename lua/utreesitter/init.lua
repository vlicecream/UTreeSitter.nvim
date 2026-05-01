local config = require("utreesitter.config")
local filetype = require("utreesitter.filetype")
local parsers = require("utreesitter.parsers")

local M = {}

local installing = false
local pending_buffers = {}

local function parser_name()
	return config.values.parser.name
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "UTreeSitter.nvim" })
end

local function parser_paths()
	local parser_dir = vim.fn.stdpath("data") .. "/site/parser"
	local name = parser_name()
	return {
		parser_dir .. "/" .. name .. ".so",
		parser_dir .. "/" .. name .. ".dll",
		parser_dir .. "/" .. name .. ".dylib",
	}
end

function M.parser_installed()
	for _, path in ipairs(parser_paths()) do
		if vim.fn.filereadable(path) == 1 then
			return true, path
		end
	end
	return false, nil
end

function M.parser_can_attach(bufnr)
	return pcall(vim.treesitter.get_parser, bufnr or 0, parser_name())
end

local function treesitter_ready()
	if vim.fn.exists(":TSInstallSync") ~= 2 and vim.fn.exists(":TSInstall") ~= 2 then
		return false
	end

	parsers.register()
	return parsers.is_registered()
end

local function run_parser_install()
	if vim.fn.exists(":TSInstallSync") == 2 then
		pcall(vim.cmd, "TSInstallSync " .. parser_name())
		return true
	end

	if vim.fn.exists(":TSInstall") == 2 then
		pcall(vim.cmd, "TSInstall " .. parser_name())
		return true
	end

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
	if remaining <= 0 then
		installing = false
		notify("unreal_cpp parser install did not finish before retries ended", vim.log.levels.WARN)
		return
	end

	if any_pending_can_attach() then
		installing = false
		retry_pending()
		return
	end

	if not treesitter_ready() then
		vim.defer_fn(function()
			install_with_retry(remaining - 1)
		end, config.values.install.retry_delay_ms)
		return
	end

	notify("Installing unreal_cpp parser")
	run_parser_install()

	if M.parser_installed() or any_pending_can_attach() then
		installing = false
		retry_pending()
		return
	end

	vim.defer_fn(function()
		install_with_retry(remaining - 1)
	end, config.values.install.retry_delay_ms)
end

function M.install()
	parsers.register()
	if not run_parser_install() then
		notify("nvim-treesitter :TSInstall/:TSInstallSync is not available", vim.log.levels.WARN)
		return false
	end

	return M.parser_installed()
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

local function query_loaded(kind)
	local ok, query = pcall(vim.treesitter.query.get, parser_name(), kind)
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

	vim.api.nvim_create_autocmd("User", {
		pattern = { "LazyDone", "VeryLazy" },
		group = vim.api.nvim_create_augroup("UTreeSitterLazyRetry", { clear = true }),
		callback = function()
			vim.defer_fn(activate_existing_buffers, 100)
			vim.defer_fn(activate_existing_buffers, 500)
		end,
	})

	activate_existing_buffers()
end

return M

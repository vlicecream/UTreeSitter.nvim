local config = require("utreesitter.config")

local M = {}

local installing = false
local install_command_started = false
local pending_buffers = {}

local function parser_name()
	return "hlsl"
end

local function install_retries()
	return math.max(config.values.install.retries or 0, 600)
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

	return paths
end

local function parser_registered()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok or type(parsers) ~= "table" then
		return false
	end

	local configs = type(parsers.get_parser_configs) == "function" and parsers.get_parser_configs() or parsers
	return type(configs) == "table" and configs[parser_name()] ~= nil
end

function M.parser_installed()
	for _, path in ipairs(parser_paths()) do
		if vim.fn.filereadable(path) == 1 then
			return true, path
		end
	end
	return false, nil
end

local function ensure_language()
	local installed, path = M.parser_installed()
	if not installed then
		return false
	end

	local ok = pcall(vim.treesitter.language.add, parser_name(), { path = path })
	return ok
end

function M.parser_can_attach(bufnr)
	ensure_language()
	local ok, parser_or_err = pcall(vim.treesitter.get_parser, bufnr or 0, parser_name())
	return ok and parser_or_err ~= nil, parser_or_err
end

local function treesitter_ready()
	local ok, ts = pcall(require, "nvim-treesitter")
	if not ok or type(ts.install) ~= "function" then
		return false
	end

	return parser_registered()
end

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

function M.activate_existing_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == parser_name() then
			M.activate_buffer(bufnr)
		end
	end
end

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

function M.reset()
	installing = false
	install_command_started = false
	pending_buffers = {}
end

return M

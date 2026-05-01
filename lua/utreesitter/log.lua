local config = require("utreesitter.config")

local M = {}

local function stringify(value)
	if type(value) == "table" then
		return vim.inspect(value)
	end
	return tostring(value)
end

function M.path()
	return config.values.debug.log_file
end

function M.write(event, data)
	if config.values.debug.enable == false then
		return
	end

	local line = os.date("%Y-%m-%d %H:%M:%S") .. " " .. event
	if data ~= nil then
		line = line .. " " .. stringify(data)
	end

	local path = M.path()
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	vim.fn.writefile({ line }, path, "a")
end

function M.notify_path()
	vim.notify(M.path(), vim.log.levels.INFO, { title = "UTreeSitter log" })
end

return M

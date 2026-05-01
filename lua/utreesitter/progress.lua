local config = require("utreesitter.config")

local M = {}

local title = "UCore syntax highlight"
local completed = false

local function status()
	if config.values.integration.ucore_progress == false then
		return nil
	end

	local ok, ucore_status = pcall(require, "ucore.status")
	if not ok then
		return nil
	end

	return ucore_status
end

function M.progress(percent)
	local ucore_status = status()
	if not ucore_status then
		return
	end
	if completed and percent < 100 then
		return
	end

	ucore_status.progress(title, string.format("%s %d%%", title, percent))
end

function M.finish()
	local ucore_status = status()
	if not ucore_status then
		return
	end
	if completed then
		return
	end

	completed = true
	-- Keep the 100% line in UCore's status panel. UCore clears it with the
	-- rest of the initialization frame when boot finishes.
	ucore_status.progress(title, string.format("%s 100%%", title))
end

function M.fail(message)
	local ucore_status = status()
	if not ucore_status then
		return
	end

	completed = true
	if type(ucore_status.progress_fail) == "function" then
		ucore_status.progress_fail(title, string.format("%s failed: %s", title, tostring(message)))
	else
		ucore_status.progress(title, string.format("%s failed: %s", title, tostring(message)))
	end
end

return M

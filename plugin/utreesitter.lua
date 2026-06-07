-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: plugin/utreesitter.lua
-- Purpose: Reload and bootstrap the UTreeSitter plugin entrypoint.
-- License: MIT

-- Unload cached UTreeSitter modules so re-sourcing the plugin resets state cleanly.
-- 卸载缓存的 UTreeSitter 模块，以便重新配置插件以干净地重置状态。
local function unload_utreesitter()
	local ok, existing = pcall(require, "utreesitter")
	if ok and type(existing) == "table" and type(existing.reset) == "function" then
		pcall(existing.reset)
	end

	for name, _ in pairs(package.loaded) do
		if name == "utreesitter" or name:match("^utreesitter%.") then
			package.loaded[name] = nil
		end
	end
end

if vim.g.loaded_utreesitter == 1 then
	unload_utreesitter()
else
	vim.g.loaded_utreesitter = 1
end

vim.schedule(function()
	pcall(function()
		local utreesitter = require("utreesitter")
		utreesitter.setup()
	end)
end)

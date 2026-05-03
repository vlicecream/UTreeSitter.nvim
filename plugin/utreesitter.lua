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

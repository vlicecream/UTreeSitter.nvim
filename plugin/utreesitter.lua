if vim.g.loaded_utreesitter == 1 then
	return
end

vim.g.loaded_utreesitter = 1

vim.schedule(function()
	pcall(function()
		local utreesitter = require("utreesitter")
		if not utreesitter.is_setup() then
			utreesitter.setup()
		end
	end)
end)

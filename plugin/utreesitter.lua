if vim.g.loaded_utreesitter == 1 then
	return
end

vim.g.loaded_utreesitter = 1

pcall(function()
	require("utreesitter").setup()
end)

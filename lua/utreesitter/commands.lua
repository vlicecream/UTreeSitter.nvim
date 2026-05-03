local M = {}

function M.setup()
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInstall")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterReinstall")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInfo")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInspect")

	vim.api.nvim_create_user_command("UTreeSitterInstall", function()
		require("utreesitter").install({ sync = true })
	end, { desc = "Install the unreal_cpp tree-sitter parser" })

	vim.api.nvim_create_user_command("UTreeSitterReinstall", function()
		require("utreesitter").reinstall()
	end, { desc = "Reinstall the unreal_cpp tree-sitter parser" })

	vim.api.nvim_create_user_command("UTreeSitterInfo", function()
		require("utreesitter").notify_info()
	end, { desc = "Show Unreal tree-sitter integration status" })

	vim.api.nvim_create_user_command("UTreeSitterInspect", function()
		require("utreesitter").inspect_buffer()
	end, { desc = "Inspect the current buffer's Unreal tree-sitter state" })
end

function M.reset()
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInstall")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterReinstall")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInfo")
	pcall(vim.api.nvim_del_user_command, "UTreeSitterInspect")
end

return M

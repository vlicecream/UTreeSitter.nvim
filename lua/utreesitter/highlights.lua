local config = require("utreesitter.config")

local M = {}

local links = {
	["@keyword.unreal_cpp"] = "@keyword",
	["@keyword.directive.unreal_cpp"] = "@keyword.directive",
	["@keyword.function.unreal_cpp"] = "@keyword.function",
	["@type.unreal_cpp"] = "@type",
	["@type.enum.unreal_cpp"] = "@type",
	["@type.builtin.unreal_cpp"] = "@type.builtin",
	["@type.qualifier.unreal_cpp"] = "@type.qualifier",
	["@function.unreal_cpp"] = "@function",
	["@function.method.unreal_cpp"] = "@function.method",
	["@function.macro.unreal_cpp"] = "@function.macro",
	["@function.macro.delegate.unreal_cpp"] = "@function.macro",
	["@property.unreal_cpp"] = "@property",
	["@variable.unreal_cpp"] = "@variable",
	["@variable.builtin.unreal_cpp"] = "@variable.builtin",
	["@parameter.unreal_cpp"] = "@variable.parameter",
	["@string.unreal_cpp"] = "@string",
	["@string.special.unreal_cpp"] = "@string.special",
	["@number.unreal_cpp"] = "@number",
	["@comment.unreal_cpp"] = "@comment",
	["@constant.unreal_cpp"] = "@constant",
	["@constant.enum.unreal_cpp"] = "@constant",
	["@constant.builtin.unreal_cpp"] = "@constant.builtin",
	["@macro.unreal_cpp"] = "@function.macro",
}

function M.apply()
	if config.values.highlight.default_links == false then
		return
	end

	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
end

function M.setup()
	M.apply()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("UTreeSitterHighlightLinks", { clear = true }),
		callback = M.apply,
	})
end

return M

-- Author: Ame林汀
-- Website: vlicecream.github.io
-- File: lua/utreesitter/highlights.lua
-- Purpose: Define highlight groups used by UTreeSitter parser captures.
-- License: MIT

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
	["@attribute.verse"] = "@attribute",
	["@boolean.verse"] = "@boolean",
	["@comment.verse"] = "@comment",
	["@constant.verse"] = "@constant",
	["@constructor.verse"] = "@constructor",
	["@function.verse"] = "@function",
	["@function.method.verse"] = "@function.method",
	["@keyword.verse"] = "@keyword",
	["@keyword.operator.verse"] = "@keyword.operator",
	["@module.verse"] = "@module",
	["@number.verse"] = "@number",
	["@operator.verse"] = "@operator",
	["@parameter.verse"] = "@variable.parameter",
	["@property.verse"] = "@property",
	["@punctuation.bracket.verse"] = "@punctuation.bracket",
	["@punctuation.delimiter.verse"] = "@punctuation.delimiter",
	["@string.verse"] = "@string",
	["@string.escape.verse"] = "@string.escape",
	["@tag.verse"] = "@tag",
	["@type.verse"] = "@type",
	["@type.builtin.verse"] = "@type.builtin",
	["@variable.verse"] = "@variable",
}

-- Apply the highlight groups used by UTreeSitter captures.
-- 应用 UTreeSitter 捕获所使用的突出显示组。
function M.apply()
	if config.values.highlight.default_links == false then
		return
	end

	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
end

-- Apply highlights and return the highlight module API.
-- 应用高亮并返回高亮模块API。
function M.setup()
	M.apply()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("UTreeSitterHighlightLinks", { clear = true }),
		callback = M.apply,
	})
end

return M

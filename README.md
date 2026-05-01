# UTreeSitter.nvim

Neovim integration for the `UTreeSitter` Unreal C++ tree-sitter grammar.

`UTreeSitter.nvim` owns the editor-facing highlighting layer:

- registers the `unreal_cpp` parser with `nvim-treesitter`
- exposes `queries/unreal_cpp` on Neovim's runtimepath
- detects Unreal C++ files and assigns `ft=unreal_cpp`
- installs and starts the parser when an Unreal C++ buffer opens
- links Unreal-specific captures to standard tree-sitter highlight groups
- provides `:checkhealth utreesitter` and small debug commands

The grammar and query source lives in [`UTreeSitter`](https://github.com/vlicecream/UTreeSitter). `UCore.nvim` does not manage highlighting.

## Installation

### lazy.nvim

```lua
return {
  {
    "vlicecream/UTreeSitter.nvim",
    lazy = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {},
  },
}
```

### Local Development

```lua
return {
  {
    dir = "E:/Unreal-NVIM/UTreeSitter.nvim",
    name = "UTreeSitter.nvim",
    lazy = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {},
  },
}
```

## Configuration

Defaults are intended to work without user configuration:

```lua
require("utreesitter").setup({
  parser = {
    name = "unreal_cpp",
    repo = "https://github.com/vlicecream/UTreeSitter",
  },
  filetype = {
    enable = true,
    unreal_only = true,
  },
  install = {
    auto_install = true,
  },
  highlight = {
    auto_start = true,
    default_links = true,
  },
})
```

`unreal_only = true` avoids taking over every C++ file. A buffer becomes `unreal_cpp` when it is inside an Unreal project or plugin, detected by `.uproject`, `.uplugin`, `.Build.cs`, or standard `Source/<Module>/Public|Private|Classes` paths.

## Commands

```vim
:UTreeSitterInstall
:UTreeSitterReinstall
:UTreeSitterInfo
:UTreeSitterInspect
:checkhealth utreesitter
```

## Repository Split

```text
UTreeSitter          grammar + queries + parser tests
UTreeSitter.nvim     Neovim parser/filetype/highlight integration
UCore.nvim           Unreal project index, RPC, navigation, completion, VCS
```

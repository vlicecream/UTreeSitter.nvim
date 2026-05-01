# UTreeSitter.nvim

Neovim integration for the `UTreeSitter` Unreal C++ tree-sitter grammar.

`UTreeSitter.nvim` owns the editor-facing highlighting layer:

- registers the `unreal_cpp` parser with `nvim-treesitter`
- bundles the generated parser sources so parser installation does not need to download `UTreeSitter`
- exposes `queries/unreal_cpp` on Neovim's runtimepath
- detects Unreal C++ files and assigns `ft=unreal_cpp`
- detects Unreal project metadata and rule files, mapping `.uproject` / `.uplugin` to `json` and `.Build.cs` / `.Target.cs` to `cs`
- detects Unreal shader files, mapping `.usf` / `.ush` / `.hlsl` / `.hlsli` to `hlsl` when HLSL support exists, otherwise falling back to `cpp`
- installs and starts the parser when an Unreal C++ buffer opens
- links Unreal-specific captures to standard tree-sitter highlight groups
- provides `:checkhealth utreesitter` and small debug commands

The grammar and query source lives in [`UTreeSitter`](https://github.com/vlicecream/UTreeSitter). `UCore.nvim` does not manage highlighting.
`unreal_cpp` is intentionally a separate parser name even though the grammar extends upstream `tree-sitter-cpp`; that keeps stock `cpp` behavior intact while allowing Unreal-specific queries and captures.

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

No extra configuration is required for normal use.

### Advanced Options

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

The `dir = ...` form is only for developing this plugin from a local checkout.
Normal users should install `vlicecream/UTreeSitter.nvim` as shown above. The
plugin automatically uses its own installed directory as the parser source; no
user-provided local path is required.

```lua
require("utreesitter").setup({
  parser = {
    name = "unreal_cpp",
    repo = "https://github.com/vlicecream/UTreeSitter",
    use_bundled = true,
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

`unreal_only = true` avoids taking over every C++ file. A buffer becomes
`unreal_cpp` when it is inside an Unreal project or plugin, detected by
`.uproject`, `.uplugin`, `.Build.cs`, or standard
`Source/<Module>/Public|Private|Classes` paths. Unreal Engine source layouts
such as `Engine/Source/Runtime/.../Public` are also recognized.

Special Unreal files keep their native editor filetypes:

- `.uproject` / `.uplugin` -> `json`
- `.Build.cs` / `.Target.cs` -> `cs`
- `.usf` / `.ush` / `.hlsl` / `.hlsli` -> `hlsl` when available, otherwise `cpp`

## Commands

```vim
:UTreeSitterInstall
:UTreeSitterReinstall
:UTreeSitterInfo
:UTreeSitterInspect
:checkhealth utreesitter
```

If an earlier install tried to download `tree-sitter-unreal_cpp` from GitHub and failed, update this plugin and run:

```vim
:UTreeSitterReinstall
```

## Repository Split

```text
UTreeSitter          grammar + queries + parser tests
UTreeSitter.nvim     Neovim parser/filetype/highlight integration
UCore.nvim           Unreal project index, RPC, navigation, completion, VCS
```

# UTreeSitter.nvim

Neovim parser, filetype, and highlight integration for Unreal Engine source files.

[English](#english) | [中文](#中文)

---

## English

`UTreeSitter.nvim` is the user-facing highlight layer for the U-series stack.

It owns:

- `unreal_cpp` parser registration for `nvim-treesitter`
- runtime exposure of `queries/unreal_cpp`
- Unreal filetype detection
- automatic parser installation
- automatic highlight activation
- shader filetype integration

The grammar source itself lives in [`UTreeSitter`](https://github.com/vlicecream/UTreeSitter).

### What It Handles Automatically

- registers the bundled `unreal_cpp` parser before installation
- installs `unreal_cpp` automatically after the plugin is loaded
- installs upstream `hlsl` alongside `unreal_cpp`
- activates highlights without requiring a Neovim restart
- maps Unreal-specific files to the correct filetypes

### Supported Files

| File | Filetype |
| --- | --- |
| Unreal C/C++ source under Unreal project layout | `unreal_cpp` |
| `.uproject`, `.uplugin` | `json` |
| `.Build.cs`, `.Target.cs` | `cs` |
| `.hlsl`, `.hlsli`, `.usf`, `.ush` | `hlsl` when available, otherwise `cpp` |

### Requirements

- Neovim 0.10+
- `nvim-treesitter`

### Installation

#### Recommended Stack

```lua
return {
  {
    "vlicecream/UTreeSitter.nvim",
    main = "utreesitter",
    lazy = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = function(_, opts)
          opts = opts or {}
          opts.auto_install = true
          opts.indent = { enable = true }
          return opts
        end,
      },
    },
    opts = {},
  },

  {
    "vlicecream/UVersionControlSystem.nvim",
    main = "uvcs",
    lazy = false,
    opts = {
      enable = true,
      prompt_on_readonly_save = true,
      provider = "auto",
      p4 = {
        command = "p4",
        -- port = "127.0.0.1:1666",
        -- user = "YourUser",
        -- client = "YourWorkspace",
      },
    },
  },

  {
    "vlicecream/UCore.nvim",
    main = "ucore",
    lazy = false,
    build = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1",
    dependencies = {
      {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {},
      },

      {
        "saghen/blink.cmp",
        opts = function(_, opts)
          opts.sources = opts.sources or {}
          opts.sources.default = opts.sources.default or { "lsp", "path", "snippets", "buffer" }

          if not vim.tbl_contains(opts.sources.default, "ucore") then
            table.insert(opts.sources.default, "ucore")
          end

          opts.sources.providers = opts.sources.providers or {}
          opts.sources.providers.ucore = {
            name = "UCore",
            module = "ucore.completion.blink",
            async = true,
            timeout_ms = 2000,
            min_keyword_length = 0,
            score_offset = 50,
          }

          return opts
        end,
      },

      {
        "nvim-telescope/telescope.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          "nvim-tree/nvim-web-devicons",
        },
      },
    },
    opts = {
      auto_boot = true,
      completion = {
        enable = true,
        keymap = "<C-l>",
      },
      ui = {
        picker = "telescope",
      },
    },
  },
}
```

#### Standalone

```lua
return {
  {
    "vlicecream/UTreeSitter.nvim",
    main = "utreesitter",
    lazy = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = function(_, opts)
          opts = opts or {}
          opts.auto_install = true
          opts.indent = { enable = true }
          return opts
        end,
      },
    },
    opts = {},
  },
}
```

For normal use, `opts = {}` is enough.

### Quick Start

1. Install the plugin.
2. Open an Unreal C++ file.
3. Wait for the first parser install to finish.
4. Highlights attach automatically. No restart is required.

### Commands

```vim
:UTreeSitterInstall
:UTreeSitterReinstall
:UTreeSitterInfo
:UTreeSitterInspect
:checkhealth utreesitter
```

### Configuration

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
    retries = 120,
    retry_delay_ms = 500,
  },
  highlight = {
    auto_start = true,
    default_links = true,
  },
})
```

### Troubleshooting

```vim
:checkhealth utreesitter
:UTreeSitterInfo
:UTreeSitterInspect
```

Common cases:

- first install interrupted by network issues: run `:UTreeSitterInstall`
- parser downloaded but no color yet: keep the buffer open; the plugin retries attach automatically
- shader files are plain text: make sure `nvim-treesitter` can install `hlsl`

### Repository Split

```text
UTreeSitter                  grammar + queries + parser tests
UTreeSitter.nvim             Neovim parser/filetype/highlight integration
UVersionControlSystem.nvim   Unreal VCS dashboard and actions
UCore.nvim                   Unreal project index, RPC, navigation, completion
```

### License

MIT

---

## 中文

`UTreeSitter.nvim` 是 U 系列里真正面向用户的高亮层。

它负责：

- 向 `nvim-treesitter` 注册 `unreal_cpp` parser
- 把 `queries/unreal_cpp` 暴露到 runtimepath
- Unreal 文件的 filetype 检测
- parser 自动安装
- 高亮自动启动
- shader 文件类型集成

底层 grammar 源码在 [`UTreeSitter`](https://github.com/vlicecream/UTreeSitter)。

### 它会自动处理的事情

- 在安装前先注册 bundled `unreal_cpp` parser
- 插件加载后自动安装 `unreal_cpp`
- 安装 `unreal_cpp` 时顺带安装上游 `hlsl`
- 安装完成后自动附加高亮，不需要重启 Neovim
- 给 Unreal 特殊文件分配正确 filetype

### 支持的文件

| 文件 | filetype |
| --- | --- |
| Unreal 工程布局下的 C/C++ 源文件 | `unreal_cpp` |
| `.uproject`, `.uplugin` | `json` |
| `.Build.cs`, `.Target.cs` | `cs` |
| `.hlsl`, `.hlsli`, `.usf`, `.ush` | 优先 `hlsl`，否则回退到 `cpp` |

### 依赖

- Neovim 0.10+
- `nvim-treesitter`

### 安装

#### 推荐组合

```lua
return {
  {
    "vlicecream/UTreeSitter.nvim",
    main = "utreesitter",
    lazy = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = function(_, opts)
          opts = opts or {}
          opts.auto_install = true
          opts.indent = { enable = true }
          return opts
        end,
      },
    },
    opts = {},
  },

  {
    "vlicecream/UVersionControlSystem.nvim",
    main = "uvcs",
    lazy = false,
    opts = {
      enable = true,
      prompt_on_readonly_save = true,
      provider = "auto",
      p4 = {
        command = "p4",
        -- port = "127.0.0.1:1666",
        -- user = "YourUser",
        -- client = "YourWorkspace",
      },
    },
  },

  {
    "vlicecream/UCore.nvim",
    main = "ucore",
    lazy = false,
    build = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1",
    dependencies = {
      {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {},
      },

      {
        "saghen/blink.cmp",
        opts = function(_, opts)
          opts.sources = opts.sources or {}
          opts.sources.default = opts.sources.default or { "lsp", "path", "snippets", "buffer" }

          if not vim.tbl_contains(opts.sources.default, "ucore") then
            table.insert(opts.sources.default, "ucore")
          end

          opts.sources.providers = opts.sources.providers or {}
          opts.sources.providers.ucore = {
            name = "UCore",
            module = "ucore.completion.blink",
            async = true,
            timeout_ms = 2000,
            min_keyword_length = 0,
            score_offset = 50,
          }

          return opts
        end,
      },

      {
        "nvim-telescope/telescope.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          "nvim-tree/nvim-web-devicons",
        },
      },
    },
    opts = {
      auto_boot = true,
      completion = {
        enable = true,
        keymap = "<C-l>",
      },
      ui = {
        picker = "telescope",
      },
    },
  },
}
```

#### 单独使用

```lua
return {
  {
    "vlicecream/UTreeSitter.nvim",
    main = "utreesitter",
    lazy = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = function(_, opts)
          opts = opts or {}
          opts.auto_install = true
          opts.indent = { enable = true }
          return opts
        end,
      },
    },
    opts = {},
  },
}
```

正常使用时，`opts = {}` 就够了。

### 快速开始

1. 安装插件。
2. 打开 Unreal C++ 文件。
3. 等第一次 parser 安装完成。
4. 高亮会自动附加，不需要重启 Neovim。

### 命令

```vim
:UTreeSitterInstall
:UTreeSitterReinstall
:UTreeSitterInfo
:UTreeSitterInspect
:checkhealth utreesitter
```

### 配置

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
    retries = 120,
    retry_delay_ms = 500,
  },
  highlight = {
    auto_start = true,
    default_links = true,
  },
})
```

### 排查

```vim
:checkhealth utreesitter
:UTreeSitterInfo
:UTreeSitterInspect
```

常见情况：

- 第一次安装因为网络中断：执行 `:UTreeSitterInstall`
- parser 已经下载但还没上色：保持 buffer 打开，插件会自动重试附加
- shader 文件还是纯文本：确认 `nvim-treesitter` 能安装 `hlsl`

### 仓库拆分

```text
UTreeSitter                  grammar + queries + parser tests
UTreeSitter.nvim             Neovim parser/filetype/highlight integration
UVersionControlSystem.nvim   Unreal VCS dashboard and actions
UCore.nvim                   Unreal project index, RPC, navigation, completion
```

### 许可

MIT

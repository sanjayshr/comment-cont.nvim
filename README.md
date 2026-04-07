# comment-cont.nvim

A lightweight Neovim plugin that automatically continues line comments when pressing `Enter`, `o`, or `O` -- and stops when you want it to.

## Features

- **Auto-continue comments** -- press `Enter` in insert mode or `o`/`O` in normal mode on a comment line, and the next line gets the comment prefix automatically
- **Smart cancellation** -- press `Enter` on an empty comment line to end the comment block, keeping your indentation
- **Block comment support** -- continues `* ` inside `/* */` blocks
- **Preserves formatting** -- copies exact indentation and spacing from the current line
- **nvim-cmp integration** -- defers to nvim-cmp when the completion menu is visible
- **Configurable** -- supports `//`, `#`, `--`, `;;`, `%`, and more, with per-filetype overrides

## Demo

![comment-cont.nvim demo](demo.gif)

## Requirements

- Neovim >= 0.8

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "sanjayshr/comment-cont.nvim",
  event = "VeryLazy",
  opts = {},
}
```

## Configuration

The plugin works out of the box with zero configuration. Call `setup()` to override defaults:

```lua
require("comment-cont").setup({
  -- Set to false to disable default <CR>, o, O mappings
  -- and use the exported functions in your own keymaps
  default_mapping = true,

  -- Key to map in insert mode (default: "<CR>")
  mapping_key = "<CR>",

  -- Comment prefixes per filetype (merged with built-in defaults)
  filetypes = {
    -- Add or override filetypes
    custom_ft = "//",
  },

  -- Block comment styles (merged with defaults)
  block_comments = {
    default = { start = "/*", middle = " * ", finish = " */" },
  },
})
```

### Built-in filetype support

| Prefix | Filetypes |
|--------|-----------|
| `//` | c, cpp, cs, java, javascript, typescript, javascriptreact, typescriptreact, go, rust, swift, kotlin, dart, scala, zig, php |
| `#` | python, ruby, perl, bash, sh, zsh, fish, yaml, toml, make, dockerfile, r, elixir |
| `--` | lua, haskell, sql |
| `;;` | lisp, scheme, clojure |
| `%` | tex |
| `"` | vim |
| `;` | ini, dosini |

Block comments (`/* */`) are automatically supported for all filetypes that use `//` as their single-line prefix, plus `css`.

## Behavior Details

### Insert mode (`Enter`)

| Scenario | Result |
|----------|--------|
| Cursor on a comment line with content | New line with same prefix and indentation |
| Cursor on an empty comment line (`// `) | Comment prefix removed, cursor stays at indentation |
| Cursor in middle of comment text | Line splits at cursor, trailing text moves to new comment line |
| nvim-cmp menu visible | Confirms completion (defers to cmp) |
| Line is not a comment | Normal `Enter` behavior |

### Normal mode (`o` / `O`)

| Key | Behavior |
|-----|----------|
| `o` | Opens line below. If current line is a comment, continues it. |
| `O` | Opens line above. Checks the line **above** the insertion point -- only continues if that line is a comment. |

## Custom Keymaps

If you use nvim-cmp or other plugins that map `<CR>`, you can disable the default mapping and compose the functions yourself:

```lua
require("comment-cont").setup({
  default_mapping = false,
})

-- Then in your keymap config:
vim.keymap.set("i", "<CR>", function()
  -- your custom logic here, then call:
  require("comment-cont").continue_comment()
end, { noremap = true })
```

### Exported functions

| Function | Description |
|----------|-------------|
| `require("comment-cont").continue_comment()` | Insert-mode handler: continue, cancel, or passthrough |
| `require("comment-cont").open_below()` | Normal-mode `o` with comment continuation |
| `require("comment-cont").open_above()` | Normal-mode `O` with comment continuation |

## How It Works

The plugin uses pattern matching on the current line to detect comment prefixes. It does **not** depend on Treesitter or LSP -- it works everywhere, in any buffer.

When `setup()` is called, it removes the `r` and `o` flags from `formatoptions` to prevent Neovim's built-in comment continuation from conflicting (which would cause double prefixes).

## License

MIT

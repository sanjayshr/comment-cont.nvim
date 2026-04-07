local M = {}

M.defaults = {
  enabled = true,
  default_mapping = true,
  mapping_key = "<CR>",

  filetypes = {
    -- C-family
    c = "//",
    cpp = "//",
    cs = "//",
    java = "//",
    javascript = "//",
    typescript = "//",
    javascriptreact = "//",
    typescriptreact = "//",
    go = "//",
    rust = "//",
    swift = "//",
    kotlin = "//",
    dart = "//",
    scala = "//",
    zig = "//",
    php = "//",
    -- Scripting
    python = "#",
    ruby = "#",
    perl = "#",
    bash = "#",
    sh = "#",
    zsh = "#",
    fish = "#",
    yaml = "#",
    toml = "#",
    make = "#",
    dockerfile = "#",
    r = "#",
    elixir = "#",
    -- Lua / SQL / Haskell
    lua = "--",
    haskell = "--",
    sql = "--",
    -- Lisp family
    lisp = ";;",
    scheme = ";;",
    clojure = ";;",
    -- LaTeX
    tex = "%",
    -- Vim
    vim = '"',
    -- Config
    ini = ";",
    dosini = ";",
  },

  block_comments = {
    default = { start = "/*", middle = " * ", finish = " */" },
  },
}

M.options = nil

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})
  return M.options
end

function M.get()
  return M.options or M.defaults
end

function M.toggle()
  local opts = M.get()
  opts.enabled = not opts.enabled
  return opts.enabled
end

return M

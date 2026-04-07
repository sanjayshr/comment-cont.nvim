local config = require("comment-cont.config")
local comment = require("comment-cont.comment")

local M = {}

local function setup_formatoptions()
  local group = vim.api.nvim_create_augroup("CommentContFormatOpts", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = group,
    pattern = "*",
    callback = function()
      if not config.get().enabled then
        return
      end
      vim.opt_local.formatoptions:remove("r")
      vim.opt_local.formatoptions:remove("o")
    end,
  })
end

local function setup_keymaps(opts)
  -- Insert-mode <CR> (or custom key)
  vim.keymap.set("i", opts.mapping_key, function()
    if not config.get().enabled then
      if comment.try_bracket_expand() then
        return
      end
      local cr = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
      vim.api.nvim_feedkeys(cr, "n", false)
      return
    end
    comment.continue_comment()
  end, { noremap = true, desc = "comment-cont: continue or cancel comment" })

  -- Normal-mode o (expr mapping: return "o" for non-comment so Neovim runs
  -- the built-in key natively and insert mode persists)
  vim.keymap.set("n", "o", function()
    if not config.get().enabled then
      return "o"
    end
    local line = vim.api.nvim_get_current_line()
    local ft = vim.bo.filetype
    if not comment.parse_line(line, ft) then
      return "o"
    end
    comment.open_below()
    return ""
  end, { noremap = true, expr = true, desc = "comment-cont: open below with comment continuation" })

  -- Normal-mode O (expr mapping: same approach)
  vim.keymap.set("n", "O", function()
    if not config.get().enabled then
      return "O"
    end
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local ft = vim.bo.filetype
    if row <= 1 then
      return "O"
    end
    local line_above = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
    if not comment.parse_line(line_above, ft) then
      return "O"
    end
    comment.open_above()
    return ""
  end, { noremap = true, expr = true, desc = "comment-cont: open above with comment continuation" })
end

function M.setup(opts)
  config.setup(opts)
  local resolved = config.get()

  setup_formatoptions()

  if resolved.default_mapping then
    setup_keymaps(resolved)
  end

  vim.api.nvim_create_user_command("CommentContToggle", function()
    local enabled = config.toggle()
    local state = enabled and "enabled" or "disabled"
    vim.notify("comment-cont: " .. state, vim.log.levels.INFO)
  end, { desc = "Toggle comment-cont plugin on/off" })
end

-- Public API for power users to compose into their own keymaps
M.continue_comment = comment.continue_comment
M.open_below = comment.open_below
M.open_above = comment.open_above

return M

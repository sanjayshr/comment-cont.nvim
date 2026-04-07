local config = require("comment-cont.config")

local M = {}

local function escape_pattern(s)
  return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Check if filetype supports block comments.
-- Returns the block comment spec or nil.
local function get_block_spec(ft)
  local opts = config.get()
  local spec = opts.block_comments[ft]
  if spec then
    return spec
  end
  -- Use default block spec for filetypes that have // as single-line prefix
  -- (these languages universally support /* */ too), plus css
  local prefix = opts.filetypes[ft]
  if prefix == "//" or ft == "css" then
    return opts.block_comments["default"]
  end
  return nil
end

-- Parse a line to detect comment structure.
-- Returns a table with type, indent, prefix, spacing, is_empty, content
-- or nil if the line is not a comment.
function M.parse_line(line, ft)
  local opts = config.get()

  -- Try block comment patterns first (for filetypes that support them)
  local block_spec = get_block_spec(ft)
  if block_spec then
    -- Match block comment middle: lines like "  * text" or "  ** text"
    local indent, stars, spacing, content = line:match("^(%s+)(%*+)(%s)(.*)")
    if indent and stars then
      -- Make sure this isn't a closing */ line
      if not stars:match("%*/$") then
        local is_empty = content:match("^%s*$") ~= nil
        return {
          type = "block_middle",
          indent = indent,
          prefix = stars,
          spacing = spacing,
          content = content,
          is_empty = is_empty,
        }
      end
    end

    -- Also match " * " with no content (just stars and optional space, no trailing text)
    local indent2, stars2 = line:match("^(%s+)(%*+)%s*$")
    if indent2 and stars2 then
      if not stars2:match("%*/$") then
        return {
          type = "block_middle",
          indent = indent2,
          prefix = stars2,
          spacing = " ",
          content = "",
          is_empty = true,
        }
      end
    end

    -- Match block comment start: "  /* text" or "  /**"
    local bs_indent, bs_open, bs_spacing, bs_content = line:match(
      "^(%s*)(/%*+)(%s?)(.*)"
    )
    if bs_indent and bs_open then
      -- Ignore if the block is already closed on the same line: /* ... */
      if not bs_content:match("%*/") then
        local is_empty = bs_content:match("^%s*$") ~= nil
        return {
          type = "block_start",
          indent = bs_indent,
          prefix = bs_open,
          spacing = bs_spacing,
          content = bs_content,
          is_empty = is_empty,
        }
      end
    end
  end

  -- Try single-line comment prefix
  local prefix = opts.filetypes[ft]
  if not prefix then
    return nil
  end

  local escaped = escape_pattern(prefix)
  local indent, matched_prefix, spacing, content =
    line:match("^(%s*)(" .. escaped .. ")(%s?)(.*)")
  if not indent then
    return nil
  end

  local is_empty = content:match("^%s*$") ~= nil
  return {
    type = "single",
    indent = indent,
    prefix = matched_prefix,
    spacing = spacing,
    content = content,
    is_empty = is_empty,
  }
end

-- Build the continuation string (indent + prefix + spacing) for a new line.
function M.build_continuation(parsed)
  if parsed.type == "single" or parsed.type == "block_middle" then
    local spacing = parsed.spacing
    if spacing == "" then
      spacing = " "
    end
    return parsed.indent .. parsed.prefix .. spacing
  end

  if parsed.type == "block_start" then
    -- Align * under the * in /*
    -- "  /*" -> "   * "  (indent + one extra space + "* ")
    local new_indent = parsed.indent .. " "
    return new_indent .. "* "
  end

  return ""
end

-- Expand brackets when cursor is between matching pairs: {|}, (|), [|]
-- Returns true if expansion was performed.
local bracket_pairs = { ["{"] = "}", ["("] = ")", ["["] = "]" }

function M.try_bracket_expand()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local line = vim.api.nvim_get_current_line()

  local before_char = col > 0 and line:sub(col, col) or ""
  local after_char = line:sub(col + 1, col + 1)

  if not (bracket_pairs[before_char] and bracket_pairs[before_char] == after_char) then
    return false
  end

  local before = line:sub(1, col)
  local after = line:sub(col + 1)
  local base_indent = before:match("^(%s*)")
  local extra
  if vim.bo.expandtab then
    extra = string.rep(" ", vim.fn.shiftwidth())
  else
    extra = "\t"
  end

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
    before,
    base_indent .. extra,
    base_indent .. after,
  })
  vim.api.nvim_win_set_cursor(0, { row + 1, #base_indent + #extra })
  vim.cmd("startinsert!")
  return true
end

-- Insert-mode <CR> handler.
-- Uses direct buffer manipulation instead of expr mapping.
function M.continue_comment()
  -- Check nvim-cmp first
  local ok, cmp = pcall(require, "cmp")
  if ok and cmp.visible() then
    cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] -- 1-indexed
  local col = cursor[2] -- 0-indexed byte offset
  local line = vim.api.nvim_get_current_line()
  local ft = vim.bo.filetype

  local parsed = M.parse_line(line, ft)

  if not parsed then
    if M.try_bracket_expand() then
      return
    end
    local cr = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
    vim.api.nvim_feedkeys(cr, "n", false)
    return
  end

  if parsed.is_empty and parsed.type == "block_middle" then
    -- Block comment cancellation: replace empty " * " with " */" to close the block
    local close_line = parsed.indent:sub(1, #parsed.indent - 1) .. " */"
    local next_indent = parsed.indent:sub(1, #parsed.indent - 1)
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { close_line, next_indent })
    vim.api.nvim_win_set_cursor(0, { row + 1, #next_indent })
    vim.cmd("startinsert!")
    return
  end

  if parsed.is_empty and parsed.type == "single" then
    -- Single-line cancellation: replace current line with just indent
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { parsed.indent })
    vim.api.nvim_win_set_cursor(0, { row, #parsed.indent })
    vim.cmd("startinsert!")
    return
  end

  -- block_start: insert " * " cursor line and " */" closing line
  if parsed.type == "block_start" then
    local before = line:sub(1, col)
    local after = line:sub(col + 1)

    before = before:gsub("%s+$", "")
    after = after:gsub("^%s+", "")

    local continuation = M.build_continuation(parsed)
    local close_line = parsed.indent .. " */"

    local cursor_line = continuation .. after
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { before, cursor_line, close_line })
    vim.api.nvim_win_set_cursor(0, { row + 1, #continuation })
    vim.cmd("startinsert!")
    return
  end

  -- Continue the comment, splitting at cursor position
  local before = line:sub(1, col)
  local after = line:sub(col + 1)

  local continuation = M.build_continuation(parsed)

  -- Trim trailing whitespace from the before part
  before = before:gsub("%s+$", "")

  -- Trim leading whitespace from the after part (continuation provides the prefix)
  after = after:gsub("^%s+", "")

  local new_line = continuation .. after

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { before, new_line })
  vim.api.nvim_win_set_cursor(0, { row + 1, #continuation })
  vim.cmd("startinsert!")
end

-- Normal-mode 'o' handler: open line below with comment continuation.
function M.open_below()
  local line = vim.api.nvim_get_current_line()
  local ft = vim.bo.filetype
  local parsed = M.parse_line(line, ft)

  if not parsed then
    vim.cmd("normal! o")
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local continuation = M.build_continuation(parsed)

  vim.api.nvim_buf_set_lines(0, row, row, false, { continuation })
  vim.api.nvim_win_set_cursor(0, { row + 1, #continuation })
  vim.cmd("startinsert!")
end

-- Normal-mode 'O' handler: open line above.
-- Checks the line ABOVE the insertion point (not the current line).
function M.open_above()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local ft = vim.bo.filetype

  if row <= 1 then
    vim.cmd("normal! O")
    return
  end

  -- The line above the insertion point is row - 1
  local line_above = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  local parsed = M.parse_line(line_above, ft)

  if not parsed then
    vim.cmd("normal! O")
    return
  end

  local continuation = M.build_continuation(parsed)

  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { continuation })
  vim.api.nvim_win_set_cursor(0, { row, #continuation })
  vim.cmd("startinsert!")
end

return M

local geo = require("99.geo")
local Point = geo.Point
local editor = require("99.editor")
local Logger = require("99.logger.logger")

local nsid = vim.api.nvim_create_namespace("99.explanations")

local explanations = {}

local M = {}

local function cache_key(buffer, row)
  return buffer .. ":" .. row
end

function M.store(buffer, row, text)
  local existing = vim.api.nvim_buf_get_extmarks(
    buffer,
    nsid,
    { row, 0 },
    { row, -1 },
    {}
  )
  for _, mark in ipairs(existing) do
    vim.api.nvim_buf_del_extmark(buffer, nsid, mark[1])
  end

  explanations[cache_key(buffer, row)] = text
  vim.api.nvim_buf_set_extmark(buffer, nsid, row, 0, {
    virt_text = { { " [99: explained]", "Comment" } },
    virt_text_pos = "eol",
  })
end

function M.show_window()
  local buffer = vim.api.nvim_get_current_buf()
  local ts = editor.treesitter
  local cursor = Point:from_cursor()
  local file_type = vim.bo[buffer].ft
  if file_type == "typescriptreact" then
    file_type = "typescript"
  end

  local func = ts.containing_function({
    buffer = buffer,
    file_type = file_type,
    logger = Logger:set_id(0),
  }, cursor)

  if not func then
    return false
  end

  local func_start = func.function_range.start.row - 1
  local key = cache_key(buffer, func_start)
  local explanation = explanations[key]

  if not explanation then
    return false
  end

  local lines = vim.split(explanation, "\n")
  vim.lsp.util.open_floating_preview(lines, "markdown", {
    focus_id = "99_explanation",
    border = "rounded",
  })

  return true
end

function M.clear()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, nsid, 0, -1)
    end
  end
  explanations = {}
end

return M

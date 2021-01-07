local parsers = require'nvim-treesitter.parsers'
local queries = require'nvim-treesitter.query'
local utils = require'nvim-treesitter.ts_utils'

local M = {}

-- TODO(kiyan): move this in tsutils and document it
local function get_node_at_line(root, lnum)
  for node in root:iter_children() do
    local srow, _, erow = node:range()
    if srow == lnum then return node end

    if node:child_count() > 0 and srow < lnum and lnum <= erow then
      return get_node_at_line(node, lnum)
    end
  end
end

local function node_fmt(node)
  if not node then return nil end
  return tostring(node)
end

local get_queries = utils.memoize_by_buf_tick(function(bufnr)
  local indents = queries.get_capture_matches(bufnr, '@indent.node', 'indents') or {}
  local branches = queries.get_capture_matches(bufnr, '@branch.node', 'indents') or {}
  local ignores = queries.get_capture_matches(bufnr, '@ignore.node', 'indents') or {}

  local get_map = function(matches)
    local map = {}
    for _, node in ipairs(matches) do
      map[tostring(node)] = true
    end
    return map
  end

  return {
    indents = get_map(indents),
    branches = get_map(branches),
    ignores = get_map(ignores),
  }
end)

local function get_indent_size()
  return vim.bo.softtabstop < 0 and vim.bo.shiftwidth or vim.bo.tabstop
end

function M.get_indent(lnum)
  local parser = parsers.get_parser()
  if not parser or not lnum then return -1 end

  local q = get_queries(vim.api.nvim_get_current_buf())
  local root = parser:parse()[1]:root()
  local node = get_node_at_line(root, lnum-1)

  local indent = 0
  local indent_size = get_indent_size()

  -- if we are on a new line (for instance by typing `o` or `O`)
  -- we should get the node that wraps the line our cursor sits in
  -- and if the node is an indent node, we should set the indent level as the indent_size
  -- and we set the node as the first child of this wrapper node or the wrapper itself
  if not node then
    -- use indentation from last block if it ends before current line - allows
    -- to get correct indent for languages like Python where blocks don't end with @branch
    local prevnonblank = vim.fn.prevnonblank(lnum)
    if prevnonblank ~= lnum then
      local prev_node = get_node_at_line(root, prevnonblank - 1)
      print('prev_node', tostring(prev_node), prev_node:end_(), lnum-1)
      if prev_node and (prev_node:end_() < lnum-1) then
        node = prev_node
      end
    end

    if not node then
      local wrapper = root:descendant_for_range(lnum-1, 0, lnum-1, -1)
      node = wrapper:child(0) or wrapper
      print('wrapper', tostring(node))
      if q.indents[node_fmt(wrapper)] ~= nil and wrapper ~= root then
        print('wrapper indent', tostring(node))
        indent = indent_size
      end
    end
  end

  -- TODO: C/C++ multi-line comments?
  -- if last line is " */" it will not use comment but upper scope (e.g. namespace)?
  if q.ignores[node_fmt(node)] then
    return -1
  end

  while node and q.branches[node_fmt(node)] do
    node = node:parent()
  end

  local prev_row = node:start()

  while node do
    node = node:parent()
    local row = node and node:start() or prev_row
    if q.indents[node_fmt(node)] and prev_row ~= row then
      indent = indent + indent_size
      prev_row = row
    end
  end

  return indent
end

local indent_funcs = {}

function M.attach(bufnr)
  indent_funcs[bufnr] = vim.bo.indentexpr
  vim.bo.indentexpr = 'nvim_treesitter#indent()'
end

function M.detach(bufnr)
  vim.bo.indentexpr = indent_funcs[bufnr]
end

return M

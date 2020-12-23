local parsers = require'nvim-treesitter.parsers'
local queries = require'nvim-treesitter.query'
local utils = require'nvim-treesitter.ts_utils'

local M = {}

local function get_nodes_at_line(root, lnum, nodes)
  nodes = nodes or {}

  for node in root:iter_children() do
    local srow, _, erow = node:range()
    if srow == lnum then
      nodes[#nodes + 1] = node
    end

    if node:child_count() > 0 and srow < lnum and lnum <= erow then
      get_nodes_at_line(node, lnum, nodes)
    end
  end

  return nodes
end

local function get_wrapper_at_line(root, lnum)
  local wrapper = root:descendant_for_range(lnum, 0, lnum, -1)
  local child = wrapper:child(0)
  return child or wrapper
end

local get_indents = utils.memoize_by_buf_tick(function(bufnr)
  local indents = queries.get_capture_matches(bufnr, '@indent.node', 'indents') or {}
  local branches = queries.get_capture_matches(bufnr, '@branch.node', 'indents') or {}

  local indents_map = {}
  for _, node in ipairs(indents) do
    indents_map[tostring(node)] = true
  end

  local branches_map = {}
  for _, node in ipairs(branches) do
    branches_map[tostring(node)] = true
  end

  return { indents = indents_map, branches = branches_map }
end)

function M.get_indent(lnum)
  local parser = parsers.get_parser()
  if not parser or not lnum then return -1 end

  local indent_queries = get_indents(vim.api.nvim_get_current_buf())
  local indents = indent_queries.indents
  local branches = indent_queries.branches
  if not indents then return 0 end

  local root = parser:parse()[1]:root()
  local nodes = get_nodes_at_line(root, lnum-1)

  -- get a wrapper if there were no nodes at line
  if #nodes == 0 then
    nodes = {get_wrapper_at_line(root, lnum-1)}
  end

  -- use indentation from last block if it ends before current line
  local prevnonblank = vim.fn.prevnonblank(lnum)
  if prevnonblank ~= lnum then
    local prev_nodes = get_nodes_at_line(root, prevnonblank - 1)
    local prev_node = prev_nodes[1]
    if (prev_node and prev_node:end_()) < lnum-1 then
      nodes = prev_nodes
    end
  end

  -- jump out of branches from left to right
  local node = table.remove(nodes, 1)
  while node and branches[tostring(node)] do
    if #nodes > 0 then
      node = table.remove(nodes, 1)
    else
      node = node:parent()
    end
  end

  -- move up to calculate identation
  local prev_row
  local ind_size = vim.bo.softtabstop < 0 and vim.bo.shiftwidth or vim.bo.tabstop
  local ind = 0
  while node do
    node = node:parent()
    local row = node and node:start() or prev_row
    if indents[tostring(node)] and row ~= prev_row then
      ind = ind + ind_size
      prev_row = row
    end
  end

  return ind
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

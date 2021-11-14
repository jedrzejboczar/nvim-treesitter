local parsers = require "nvim-treesitter.parsers"
local queries = require "nvim-treesitter.query"
local tsutils = require "nvim-treesitter.ts_utils"

local M = {}

-- TODO(kiyan): move this in tsutils and document it
local function get_node_at_line(root, lnum)
  for node in root:iter_children() do
    local srow, _, erow = node:range()
    if srow == lnum then
      return node
    end

    if node:child_count() > 0 and srow < lnum and lnum <= erow then
      return get_node_at_line(node, lnum)
    end
  end
end

local function node_fmt(node)
  if not node then
    return nil
  end
  return node:id()
end

local get_indents = tsutils.memoize_by_buf_tick(function(bufnr, root, lang)
  local get_map = function(capture)
    local matches = queries.get_capture_matches(bufnr, capture, "indents", root, lang) or {}
    local map = {}
    for _, node in ipairs(matches) do
      map[node:id()] = node
    end
    return map
  end

  return {
    indents = get_map "@indent.node",
    branches = get_map "@branch.node",
    returns = get_map "@return.node",
    ignores = get_map "@ignore.node",
  }
end, {
  -- Memoize by bufnr and lang together.
  key = function(bufnr, _, lang)
    return tostring(bufnr) .. "_" .. lang
  end,
})

M.calls = 0
M.full_calls = 0
M.full_time = 0

local function get_indent(lnum)
  M.calls = M.calls + 1
  local starttime = vim.fn.reltime()

  local parser = parsers.get_parser()
  if not parser or not lnum then
    return -1
  end

  local root, _, lang_tree = tsutils.get_root_for_position(lnum, 0, parser)

  -- Not likely, but just in case...
  if not root then
    return 0
  end

  local q = get_indents(vim.api.nvim_get_current_buf(), root, lang_tree:lang())
  local node = get_node_at_line(root, lnum - 1)

  local indent = 0
  local indent_size = vim.fn.shiftwidth()

  -- to get correct indentation when we land on an empty line (for instance by typing `o`), we try
  -- to use indentation of previous nonblank line, this solves the issue also for languages that
  -- do not use @branch after blocks (e.g. Python)
  if not node then
    local prevnonblank = vim.fn.prevnonblank(lnum)
    if prevnonblank ~= lnum then
      local prev_node = get_node_at_line(root, prevnonblank - 1)
      -- get previous node in any case to avoid erroring
      while not prev_node and prevnonblank - 1 > 0 do
        prevnonblank = vim.fn.prevnonblank(prevnonblank - 1)
        prev_node = get_node_at_line(root, prevnonblank - 1)
      end

      -- nodes can be marked @return to prevent using them
      if prev_node and not q.returns[node_fmt(prev_node)] then
        local row = prev_node:start()
        local end_row = prev_node:end_()

        -- if the previous node is being constructed (like function() `o` in lua), or line is inside the node
        -- we indent one more from the start of node, else we indent default
        -- NOTE: this doesn't work for python which behave strangely
        if prev_node:has_error() or lnum <= end_row then
          return vim.fn.indent(row + 1) + indent_size
        end
        return vim.fn.indent(row + 1)
      end
    end
  end

  -- if the prevnonblank fails (prev_node wraps our line) we need to fall back to taking
  -- the first child of the node that wraps the current line, or the wrapper itself
  if not node then
    local wrapper = root:descendant_for_range(lnum - 1, 0, lnum - 1, -1)
    node = wrapper:child(0) or wrapper
    if q.indents[node_fmt(wrapper)] ~= nil and wrapper ~= root then
      indent = indent_size
    end
  end

  while node and q.branches[node_fmt(node)] do
    node = node:parent()
  end

  local first = true
  local prev_row = node:start()

  while node do
    -- do not indent if we are inside an @ignore block
    if q.ignores[node_fmt(node)] and node:start() < lnum - 1 and node:end_() > lnum - 1 then
      return -1
    end

    -- do not indent the starting node, do not add multiple indent levels on single line
    local row = node:start()
    if not first and q.indents[node_fmt(node)] and prev_row ~= row then
      indent = indent + indent_size
      prev_row = row
    end

    node = node:parent()
    first = false
  end

  M.full_calls = M.full_calls + 1
  M.full_time = M.full_time + vim.fn.reltimefloat(vim.fn.reltime(starttime))

  return indent
end

local function get_first_char_col(buf, lnum)
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, true)[1]
  local char_index = line:find('%S')
  return char_index and char_index - 1, char_index and line:sub(char_index, char_index)
end

local function get_first_char_wrapper(buf, lnum, root)
  local col = get_first_char_col(buf, lnum) or 0
  local wrapper = root:descendant_for_range(lnum - 1, col, lnum - 1, col)
  return wrapper
end

-- Example code:
-- ```
-- 1 fun_call(
-- 2     arg
-- 3 )
-- 4 fun_call(
-- 5     arg)
-- ```
--
-- Cases:
-- * on first line of something (1)
-- * inside something (2)
-- * on last, dedented line of something (3)
-- * on last, not-dedented line of something (5)
--
-- for C #defines with something like in preproc_func.c we could add @indent_always that would
-- make #define always add an indent, so that #define + { will result in double indent

local function get_node_and_parents_while(node, cond)
  local parents = {}
  while node and cond(node) do
    table.insert(parents, node)
    node = node:parent()
  end
  return parents
end

local function tbl_any(tbl, cond)
  for _, elem in ipairs(tbl) do
    if cond(elem) then
      return elem
    end
  end
  return false
end

M.debug_print = vim.fn.eval('$INDENTS_DBG') == '1'
local function dprint(...)
  if M.debug_print then
    print(...)
  end
end

function M.dbg_queries()
  local lnum = vim.fn.line('.')

  local parser = parsers.get_parser()
  if not parser or not lnum then
    return -1
  end

  local root, _, lang_tree = tsutils.get_root_for_position(lnum, 0, parser)

  local queries = get_indents(vim.api.nvim_get_current_buf(), root, lang_tree:lang())

  local entries = {}
  for qtype, q in pairs(queries) do
    for id, node in pairs(q) do
      table.insert(entries, {
        node=node,
        type=qtype,
      })
    end
  end

  table.sort(entries, function(a, b)
    local row_a, _ = a.node:start()
    local row_b, _ = b.node:start()
    return row_a < row_b
  end)

  for _, e in ipairs(entries) do
    local start_row, start_col = e.node:start()
    local end_row, end_col = e.node:end_()
    print(string.format('  @%-15s %-25s [%d, %d] - [%d, %d]',
      e.type, e.node:type(), start_row, start_col, end_row, end_col
    ))
  end

  return queries
end

local function dev_indent(lnum)
  dprint('dev_indent('..tostring(lnum)..')')
  M.calls = M.calls + 1
  local starttime = vim.fn.reltime()

  local parser = parsers.get_parser()
  if not parser or not lnum then
    return -1
  end

  local root, _, lang_tree = tsutils.get_root_for_position(lnum, 0, parser)

  -- Not likely, but just in case...
  if not root then
    dprint('no root')
    return -1
  end

  local q = get_indents(vim.api.nvim_get_current_buf(), root, lang_tree:lang())

  -- lnum = vim.fn.prevnonblank(lnum)
  if lnum == 0 then  -- first line
    dprint('lnum 0')
    return 0
  end

  local indent_size = vim.fn.shiftwidth()

  -- get wrapper for the first char of current line
  -- then get all its parents that are on the same line
  local wrapper = get_first_char_wrapper(buf, lnum, root)
  if not wrapper then
    dprint('no wrapper')
    return 0
  end

  local curr_line_nodes = {}  -- nodes on lnum starting from wrapper
  local prev_line_nodes = {}  -- nodes on the line of first wrapper parent that is before lnum

  -- collect all nodes on current line starting from wrapper
  local node = wrapper
  while node and node:start() == lnum - 1 do
    table.insert(curr_line_nodes, node)
    node = node:parent()
  end

  -- now node is before current line, so collect all nodes no that line
  local prev_lnum = node and node:start() + 1
  while node and node:start() == prev_lnum - 1 do
    table.insert(prev_line_nodes, node)
    node = node:parent()
  end

  local in_query = function(query)
    return function(node) return query[node_fmt(node)] end
  end

  -- indent when there is any @indent node in the nodes on prev line
  local is_indent = tbl_any(prev_line_nodes, in_query(q.indents))
  -- branch  when any node on current line is a branch
  local is_branch = tbl_any(curr_line_nodes, in_query(q.branches))
  -- ignore by checking nodes on previous line  (the ones that could cause indent)
  local is_ignore = tbl_any(prev_line_nodes, in_query(q.ignores))

  local prev_indent = prev_lnum and vim.fn.indent(prev_lnum) or 0
  local indent

  if is_ignore then
    indent = -1
  elseif is_branch then
    indent = prev_indent
  elseif is_indent then
    indent = prev_indent + indent_size
  else
    indent = -1
  end

  local fmt_short = function(node)
    return string.format('%s(%d)', node:type(), node:start())
  end
  local fmt_nodes_path = function(nodes)
    return table.concat(vim.tbl_map(fmt_short, nodes), '>')
  end

  dprint('prev:', fmt_nodes_path(prev_line_nodes))
  dprint('curr:', fmt_nodes_path(curr_line_nodes))

  dprint(string.format('ln=%d prv=%d ind=%d isind=%s isbr=%s isign=%s w=%s',
    lnum, prev_indent, indent, is_indent, is_branch, is_ignore, wrapper:type()
  ))

  M.full_calls = M.full_calls + 1
  M.full_time = M.full_time + vim.fn.reltimefloat(vim.fn.reltime(starttime))

  return indent
end

M.indent_dev = vim.fn.eval('$INDENTS_DEV') ~= '0'
if M.indent_dev then dprint('WARNING:\nUsing dev indents implementation') end

function M.get_indent(lnum)
  if M.indent_dev then
    return dev_indent(lnum)
  else
    return get_indent(lnum)
  end
end

local indent_funcs = {}

function M.attach(bufnr)
  indent_funcs[bufnr] = vim.bo.indentexpr
  vim.bo.indentexpr = "nvim_treesitter#indent()"
  vim.api.nvim_command("au Filetype " .. vim.bo.filetype .. " setlocal indentexpr=nvim_treesitter#indent()")
end

function M.detach(bufnr)
  vim.bo.indentexpr = indent_funcs[bufnr]
end

function M.indent_debugger_open(for_win, for_buf)
  local name = string.format('Indents[%d]', for_win)
  local height = 12
  vim.cmd(string.format('%d split new %s', height, name))

  -- configure scratch buffer
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.wo.signcolumn = 'no'
  vim.wo.number = false
  vim.wo.relativenumber = false

  vim.b.indent_debugger_for = for_win

  local dbg_win = vim.api.nvim_get_current_win()
  local dbg_buf = vim.api.nvim_win_get_buf(dbg_win)

  vim.cmd(string.format(
    'autocmd CursorMoved <buffer=%d> lua require"nvim-treesitter.indent".indent_debugger_update(%d)',
    for_buf, dbg_buf
  ))

  vim.api.nvim_set_current_win(for_win)
end


function M.indent_debugger_update(buf)
  local lines = {}

  local for_win = vim.b.indent_debugger_for
  if not vim.api.nvim_win_is_valid(for_win) then return end
  local for_buf = vim.api.nvim_win_get_buf(for_win)

  local parser = parsers.get_parser(for_buf)
  if not parser then return end

  local lnum, col = unpack(vim.api.nvim_win_get_cursor(for_win))
  local root, _, _ = tsutils.get_root_for_position(lnum, 0, parser)
  if not root then return end


  local fmt_node = function(header, node)
    if not node then
      table.insert(lines, header .. 'nil')
      return 'nil'
    end

    local start_row, start_col = node:start()
    local end_row, end_col = node:end_()
    table.insert(lines, header .. string.format('%s [%d, %d] - [%d, %d]',
      node:type(), start_row, start_col, end_row, end_col
    ))

    local fmt_short = function(node)
      return string.format('%s(%d)', node:type(), node:start())
    end
    local fmt_nodes_path = function(nodes)
      return table.concat(vim.tbl_map(fmt_short, nodes), '.')
    end

    -- parents at the same line
    local parents = {}
    local node_start = node:start()
    local n = node
    while n and n:start() == node_start do
      table.insert(parents, 1, n) -- insert at beginning
      n = n:parent()
    end
    table.insert(lines, '  line: ' .. fmt_nodes_path(parents))

    -- all parents
    local all_parents = {}
    n = node
    while n do
      table.insert(all_parents, 1, n) -- insert at beginning
      n = n:parent()
    end
    table.insert(lines, '  all: ' .. fmt_nodes_path(all_parents))
  end

  fmt_node('wrapper col=0,0: ', root:descendant_for_range(lnum - 1, 0, lnum - 1, 0))
  fmt_node('wrapper col=0,-1: ', root:descendant_for_range(lnum - 1, 0, lnum - 1, -1))
  local char_col, char = get_first_char_col(for_buf, lnum)
  fmt_node(
    string.format('wrapper col=%s,%s "%s": ', char_col, char_col, char),
    char_col and root:descendant_for_range(lnum - 1, char_col, lnum - 1, char_col)
  )

  table.insert(lines, string.format('calls: %d', M.calls))

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Create a debugger window
function M.indent_debugger(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)

  local success, for_buf = pcall(vim.api.nvim_buf_get_var, buf, 'indent_debugger_for')
  if success then
    M.indent_debugger_update(buf)
  else
    M.indent_debugger_open(win, buf)
  end
end

vim.cmd([[command! IndentDebug call luaeval('require("nvim-treesitter.indent").indent_debugger()') | TSPlaygroundToggle]])
vim.cmd([[command! IndentCalls lua print(require("nvim-treesitter.indent").calls)]])
vim.cmd([[command! IndentTimes lua print(require("nvim-treesitter.indent").full_time / require("nvim-treesitter.indent").full_calls * 1e6, 'us')]])

return M

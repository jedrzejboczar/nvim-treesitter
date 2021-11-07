--n map <buffer> <f9> <cmd>luafile ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/scratch.lua<cr>
-- P(vim.api.nvim_get_current_win())
-- local win = 1045
-- local win = 1290

function tsdebug(win)
  local buf = vim.api.nvim_win_get_buf(win)

  local parsers = require "nvim-treesitter.parsers"
  local ts_utils = require "nvim-treesitter.ts_utils"

  local parser = parsers.get_parser(buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local root, _, _ = ts_utils.get_root_for_position(row, 0, parser)
  local node = root:descendant_for_range(row - 1, 0, row - 1, -1)
  local node = root:descendant_for_range(row - 1, 0, row - 1, 0)
  -- local node = root:descendant_for_range(row - 1, 12, row - 1, 12)


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
  local node2 = get_node_at_line(root, row - 1)

  local start = node:start()
  local end_ = node:end_()
  -- print(node and node:type(), 'vs', node2 and node2:type(), ' | start=', start)
  print(string.format('%s vs %s | start=%d end=%d',
    node and node:type(),
    node2 and node2:type(),
    start, end_
  ))
end

vim.cmd('nmap <buffer> <f9> <cmd>lua tsdebug(vim.api.nvim_get_current_win())<cr>')

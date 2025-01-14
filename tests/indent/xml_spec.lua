local Runner = require("tests.indent.common").Runner
local runner = Runner:new(it, "tests/indent/xml", {
  tabstop = 2,
  shiftwidth = 2,
  expandtab = true,
})

describe("indent XML:", function()
  describe("whole file:", function()
    runner:whole_file "."
  end)

  describe("new line:", function()
    runner:new_line("basic.xml", { on_line = 13, text = "some text", indent = 6 })
    runner:new_line("multiline_tag.xml", { on_line = 3, text = "some text", indent = 4 })
    runner:new_line("multiline_prolog.xml", { on_line = 1, text = "some text", indent = 2 })
  end)
end)

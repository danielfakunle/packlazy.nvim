local expect, eq = MiniTest.expect, MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

before_each(function()
  child.setup()
end)

teardown(function()
  child.stop()
end)

describe("packlazy", function()
  it("exports public api", function()
    eq(child.lua_get("type(require('packlazy').setup)"), "function")
    eq(child.lua_get("type(require('packlazy').add)"), "function")
  end)
end)

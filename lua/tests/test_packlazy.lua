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

  it("continues loading other plugins when one fails", function()
    child.lua([[
      package.loaded.packlazy = nil
      package.loaded["packlazy.loader"] = {
        load = function(spec)
          if spec[1] == "owner/fail.nvim" then
            return false, "boom"
          end
          table.insert(loaded_specs, spec[1])
          return true
        end,
      }
      package.loaded["packlazy.handlers.lazy"] = { register = function(_) end }
      package.loaded["packlazy.handlers.event"] = { register = function(_) end }

      loaded_specs = {}
      notifications = {}
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      local state = require("packlazy.state")
      state.plugins = {}

      local packlazy = require("packlazy")
      packlazy.add({
        { "owner/fail.nvim", lazy = false },
        { "owner/ok.nvim", lazy = false },
      })
    ]])

    eq(child.lua_get("loaded_specs"), { "owner/ok.nvim" })
    eq(child.lua_get("#notifications"), 1)
  end)
end)

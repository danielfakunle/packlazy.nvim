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
        packdel = function(spec)
          table.insert(deleted_specs, spec[1])
          return true
        end,
      }
      package.loaded["packlazy.handlers.lazy"] = { register = function(_) end }
      package.loaded["packlazy.handlers.event"] = { register = function(_) end }
      package.loaded["packlazy.handlers.cmd"] = { register = function(_) end }
      package.loaded["packlazy.handlers.keys"] = { register = function(_) end }

      loaded_specs = {}
      deleted_specs = {}
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

  it("uninstalls and skips plugins with enabled=false", function()
    child.lua([[
      package.loaded.packlazy = nil
      package.loaded["packlazy.loader"] = {
        load = function(spec)
          table.insert(loaded_specs, spec[1])
          return true
        end,
        packdel = function(spec)
          table.insert(deleted_specs, spec[1])
          return true
        end,
      }

      lazy_registered = 0
      event_registered = 0
      cmd_registered = 0
      keys_registered = 0
      loaded_specs = {}
      deleted_specs = {}

      package.loaded["packlazy.handlers.lazy"] = {
        register = function(_)
          lazy_registered = lazy_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.event"] = {
        register = function(_)
          event_registered = event_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.cmd"] = {
        register = function(_)
          cmd_registered = cmd_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.keys"] = {
        register = function(_)
          keys_registered = keys_registered + 1
        end,
      }

      local state = require("packlazy.state")
      state.plugins = {}

      local packlazy = require("packlazy")
      packlazy.add({ "owner/disabled.nvim", enabled = false, lazy = false, event = "BufRead", cmd = "MyCmd" })
    ]])

    eq(child.lua_get("deleted_specs"), { "owner/disabled.nvim" })
    eq(child.lua_get("loaded_specs"), {})
    eq(child.lua_get("lazy_registered"), 0)
    eq(child.lua_get("event_registered"), 0)
    eq(child.lua_get("cmd_registered"), 0)
    eq(child.lua_get("keys_registered"), 0)
    eq(child.lua_get("next(require('packlazy.state').plugins) == nil"), true)
  end)

  it("skips plugins with cond=false without uninstalling", function()
    child.lua([[
      package.loaded.packlazy = nil
      package.loaded["packlazy.loader"] = {
        load = function(spec)
          table.insert(loaded_specs, spec[1])
          return true
        end,
        packdel = function(spec)
          table.insert(deleted_specs, spec[1])
          return true
        end,
      }

      lazy_registered = 0
      event_registered = 0
      cmd_registered = 0
      keys_registered = 0
      loaded_specs = {}
      deleted_specs = {}

      package.loaded["packlazy.handlers.lazy"] = {
        register = function(_)
          lazy_registered = lazy_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.event"] = {
        register = function(_)
          event_registered = event_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.cmd"] = {
        register = function(_)
          cmd_registered = cmd_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.keys"] = {
        register = function(_)
          keys_registered = keys_registered + 1
        end,
      }

      local state = require("packlazy.state")
      state.plugins = {}

      local packlazy = require("packlazy")
      packlazy.add({ "owner/conditional.nvim", cond = false, lazy = false, event = "BufRead", cmd = "MyCmd" })
    ]])

    eq(child.lua_get("deleted_specs"), {})
    eq(child.lua_get("loaded_specs"), {})
    eq(child.lua_get("lazy_registered"), 0)
    eq(child.lua_get("event_registered"), 0)
    eq(child.lua_get("cmd_registered"), 0)
    eq(child.lua_get("keys_registered"), 0)
    eq(child.lua_get("next(require('packlazy.state').plugins) == nil"), true)
  end)

  it("registers keys handler when keys are present", function()
    child.lua([[
      package.loaded.packlazy = nil
      package.loaded["packlazy.loader"] = {
        load = function(spec)
          table.insert(loaded_specs, spec[1])
          return true
        end,
        packdel = function(spec)
          table.insert(deleted_specs, spec[1])
          return true
        end,
      }

      lazy_registered = 0
      event_registered = 0
      cmd_registered = 0
      keys_registered = 0
      loaded_specs = {}
      deleted_specs = {}

      package.loaded["packlazy.handlers.lazy"] = {
        register = function(_)
          lazy_registered = lazy_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.event"] = {
        register = function(_)
          event_registered = event_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.cmd"] = {
        register = function(_)
          cmd_registered = cmd_registered + 1
        end,
      }
      package.loaded["packlazy.handlers.keys"] = {
        register = function(_)
          keys_registered = keys_registered + 1
        end,
      }

      local state = require("packlazy.state")
      state.plugins = {}

      local packlazy = require("packlazy")
      packlazy.add({ "owner/keys.nvim", keys = "<leader>ff" })
    ]])

    eq(child.lua_get("keys_registered"), 1)
    eq(child.lua_get("lazy_registered"), 1)
    eq(child.lua_get("event_registered"), 0)
    eq(child.lua_get("cmd_registered"), 0)
  end)
end)

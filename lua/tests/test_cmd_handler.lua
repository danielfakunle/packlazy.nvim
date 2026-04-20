local eq = MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

local setup_cmd_handler_env = function()
  child.lua([[
    package.loaded["packlazy.handlers.cmd"] = nil
    package.loaded["packlazy.loader"] = {
      load = function(spec)
        load_call_count = load_call_count + 1
        last_loaded_spec = spec
        return load_result_ok, load_result_err
      end,
    }
    package.loaded["packlazy.errors"] = {
      notify = function(msg)
        table.insert(notify_calls, msg)
      end,
    }

    load_call_count = 0
    last_loaded_spec = nil
    load_result_ok = true
    load_result_err = nil
    created_user_commands = {}
    deleted_user_commands = {}
    nvim_cmd_calls = {}
    notify_calls = {}

    vim.api.nvim_create_user_command = function(name, callback, opts)
      created_user_commands[name] = { callback = callback, opts = opts }
    end

    vim.api.nvim_del_user_command = function(name)
      table.insert(deleted_user_commands, name)
    end

    vim.api.nvim_cmd = function(cmd, opts)
      table.insert(nvim_cmd_calls, { cmd = cmd, opts = opts })
    end

    cmd_handler = require("packlazy.handlers.cmd")
  ]])
end

before_each(function()
  child.setup()
  setup_cmd_handler_env()
end)

teardown(function()
  child.stop()
end)

describe("packlazy.handlers.cmd", function()
  describe("register()", function()
    it("returns early when spec has no cmd", function()
      child.lua([[
        cmd_handler.register({ "owner/plugin.nvim" })
      ]])

      eq(child.lua_get("next(created_user_commands) == nil"), true)
    end)

    it("registers one command when cmd is a string", function()
      child.lua([[
        cmd_handler.register({ "owner/plugin.nvim", cmd = "MyCmd" })
      ]])

      eq(child.lua_get("type(created_user_commands.MyCmd.callback)"), "function")
      eq(child.lua_get("created_user_commands.MyCmd.opts.nargs"), "*")
      eq(child.lua_get("created_user_commands.MyCmd.opts.bang"), true)
    end)

    it("registers multiple commands when cmd is a list", function()
      child.lua([[
        cmd_handler.register({ "owner/plugin.nvim", cmd = { "MyCmd", "MyOtherCmd" } })
      ]])

      eq(child.lua_get("type(created_user_commands.MyCmd.callback)"), "function")
      eq(child.lua_get("type(created_user_commands.MyOtherCmd.callback)"), "function")
    end)

    it("registers commands returned from cmd function", function()
      child.lua([[
        cmd_handler.register({
          "owner/plugin.nvim",
          cmd = function()
            return { "DynCmd", "DynOtherCmd" }
          end,
        })
      ]])

      eq(child.lua_get("type(created_user_commands.DynCmd.callback)"), "function")
      eq(child.lua_get("type(created_user_commands.DynOtherCmd.callback)"), "function")
    end)

    it("loads plugin, removes wrappers, and re-runs invoked command", function()
      child.lua([[
        local spec = { "owner/plugin.nvim", cmd = { "MyCmd", "MyOtherCmd" } }
        cmd_handler.register(spec)

        created_user_commands.MyCmd.callback({
          name = "MyCmd",
          fargs = { "foo", "bar" },
          bang = true,
          range = 0,
          count = 0,
          reg = "",
          mods = "",
          smods = {},
        })
      ]])

      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec[1]"), "owner/plugin.nvim")
      eq(child.lua_get("#deleted_user_commands"), 2)
      eq(child.lua_get("deleted_user_commands[1]"), "MyCmd")
      eq(child.lua_get("deleted_user_commands[2]"), "MyOtherCmd")
      eq(child.lua_get("#nvim_cmd_calls"), 1)
      eq(child.lua_get("nvim_cmd_calls[1].cmd.cmd"), "MyCmd")
      eq(child.lua_get("nvim_cmd_calls[1].cmd.args"), { "foo", "bar" })
      eq(child.lua_get("nvim_cmd_calls[1].cmd.bang"), true)
    end)

    it("notifies and does not replay command when load fails", function()
      child.lua([[
        load_result_ok = false
        load_result_err = "boom"

        cmd_handler.register({ "owner/plugin.nvim", cmd = "MyCmd" })
        created_user_commands.MyCmd.callback({
          name = "MyCmd",
          fargs = {},
          bang = false,
          range = 0,
          count = 0,
          reg = "",
          mods = "",
          smods = {},
        })
      ]])

      eq(child.lua_get("#notify_calls"), 1)
      eq(child.lua_get("notify_calls[1]"), "boom")
      eq(child.lua_get("#deleted_user_commands"), 0)
      eq(child.lua_get("#nvim_cmd_calls"), 0)
    end)

    it("errors on invalid cmd specification", function()
      eq(child.lua_get("pcall(function() cmd_handler.register({ 'owner/plugin.nvim', cmd = 123 }) end)"), false)
    end)
  end)
end)

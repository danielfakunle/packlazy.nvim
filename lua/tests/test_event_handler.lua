local eq = MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

local setup_event_handler_env = function()
  child.lua([[
    package.loaded["packlazy.handlers.event"] = nil
    package.loaded["packlazy.loader"] = {
      load = function(spec)
        load_call_count = load_call_count + 1
        last_loaded_spec = spec
      end,
    }

    load_call_count = 0
    last_loaded_spec = nil
    created_autocmds = {}
    exec_autocmd_calls = {}
    scheduled_callbacks = {}

    vim.api.nvim_create_augroup = function(name, opts)
      augroup_name = name
      augroup_opts = opts
      return 101
    end

    vim.api.nvim_create_autocmd = function(events, opts)
      table.insert(created_autocmds, { events = events, opts = opts })
      return #created_autocmds
    end

    vim.api.nvim_exec_autocmds = function(event, opts)
      table.insert(exec_autocmd_calls, { event = event, opts = opts })
    end

    vim.schedule = function(cb)
      table.insert(scheduled_callbacks, cb)
    end

    event_handler = require("packlazy.handlers.event")
  ]])
end

before_each(function()
  child.setup()
  setup_event_handler_env()
end)

teardown(function()
  child.stop()
end)

describe("packlazy.handlers.event", function()
  describe("bridge_user_events()", function()
    it("registers a one-shot VimEnter bridge for VeryLazy", function()
      child.lua([[
        event_handler.bridge_user_events()

        bridge_autocmd = created_autocmds[1]
        bridge_event = bridge_autocmd.events
        bridge_once = bridge_autocmd.opts.once
        bridge_group = bridge_autocmd.opts.group

        bridge_autocmd.opts.callback()
        scheduled_callbacks[1]()
      ]])

      eq(child.lua_get("bridge_event"), "VimEnter")
      eq(child.lua_get("bridge_once"), true)
      eq(child.lua_get("bridge_group"), 101)
      eq(child.lua_get("#exec_autocmd_calls"), 1)
      eq(child.lua_get("exec_autocmd_calls[1].event"), "User")
      eq(child.lua_get("exec_autocmd_calls[1].opts.pattern"), "VeryLazy")
    end)

    it("is idempotent and does not register duplicate bridge autocmds", function()
      child.lua([[
        event_handler.bridge_user_events()
        event_handler.bridge_user_events()
      ]])

      eq(child.lua_get("#created_autocmds"), 1)
    end)
  end)

  describe("register()", function()
    it("returns early when spec has no event", function()
      child.lua([[
        event_handler.register({ "owner/plugin.nvim" })
      ]])

      eq(child.lua_get("#created_autocmds"), 0)
      eq(child.lua_get("load_call_count"), 0)
    end)

    it("registers event autocmd and loads plugin from callback", function()
      child.lua([[
        local spec = { "owner/plugin.nvim", event = "BufRead" }
        event_handler.register(spec)

        autocmd_event = created_autocmds[2].events
        autocmd_once = created_autocmds[2].opts.once
        autocmd_pattern = created_autocmds[2].opts.pattern

        created_autocmds[2].opts.callback()
      ]])

      eq(child.lua_get("autocmd_event"), { "BufRead" })
      eq(child.lua_get("autocmd_once"), true)
      eq(child.lua_get("autocmd_pattern == nil"), true)
      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec[1]"), "owner/plugin.nvim")
    end)

    it("supports event table with event list and pattern", function()
      child.lua([[
        local spec = {
          "owner/plugin.nvim",
          event = { event = { "BufRead", "BufNewFile" }, pattern = "*.lua" },
        }
        event_handler.register(spec)

        registered_events = created_autocmds[2].events
        registered_pattern = created_autocmds[2].opts.pattern
        registered_once = created_autocmds[2].opts.once
      ]])

      eq(child.lua_get("registered_events"), { "BufRead", "BufNewFile" })
      eq(child.lua_get("registered_pattern"), "*.lua")
      eq(child.lua_get("registered_once"), true)
    end)

    it("adds explicit User autocmd for VeryLazy and loads on callback", function()
      child.lua([[
        local spec = { "owner/plugin.nvim", event = { "VeryLazy", "BufRead" } }
        event_handler.register(spec)

        user_autocmd_event = created_autocmds[3].events
        user_autocmd_pattern = created_autocmds[3].opts.pattern
        user_autocmd_once = created_autocmds[3].opts.once

        created_autocmds[3].opts.callback()
      ]])

      eq(child.lua_get("user_autocmd_event"), "User")
      eq(child.lua_get("user_autocmd_pattern"), "VeryLazy")
      eq(child.lua_get("user_autocmd_once"), true)
      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec[1]"), "owner/plugin.nvim")
    end)
  end)
end)

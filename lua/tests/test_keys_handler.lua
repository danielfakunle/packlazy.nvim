local eq = MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

local setup_keys_handler_env = function()
  child.lua([[
    package.loaded["packlazy.handlers.keys"] = nil
    package.loaded["packlazy.loader"] = {
      load = function(spec)
        load_call_count = load_call_count + 1
        table.insert(loaded_specs, spec[1])
        return load_result_ok, load_result_err
      end,
    }
    package.loaded["packlazy.errors"] = {
      notify = function(msg)
        table.insert(notify_calls, msg)
      end,
    }

    load_call_count = 0
    loaded_specs = {}
    load_result_ok = true
    load_result_err = nil
    notify_calls = {}
    keymap_set_calls = {}
    keymap_del_calls = {}
    feedkeys_calls = {}

    vim.keymap.set = function(mode, lhs, rhs, opts)
      table.insert(keymap_set_calls, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
    end

    vim.keymap.del = function(mode, lhs)
      table.insert(keymap_del_calls, { mode = mode, lhs = lhs })
    end

    vim.keycode = function(lhs)
      return "KEYCODE:" .. lhs
    end

    vim.api.nvim_feedkeys = function(keys, mode, escape_ks)
      table.insert(feedkeys_calls, { keys = keys, mode = mode, escape_ks = escape_ks })
    end

    keys_handler = require("packlazy.handlers.keys")
  ]])
end

before_each(function()
  child.setup()
  setup_keys_handler_env()
end)

teardown(function()
  child.stop()
end)

describe("packlazy.handlers.keys", function()
  describe("register()", function()
    it("returns early when spec has no keys", function()
      child.lua([[
        keys_handler.register({ "owner/plugin.nvim" })
      ]])

      eq(child.lua_get("#keymap_set_calls"), 0)
    end)

    it("registers one keymap when keys is a string", function()
      child.lua([[
        keys_handler.register({ "owner/plugin.nvim", keys = "<leader>ff" })
      ]])

      eq(child.lua_get("#keymap_set_calls"), 1)
      eq(child.lua_get("keymap_set_calls[1].mode"), "n")
      eq(child.lua_get("keymap_set_calls[1].lhs"), "<leader>ff")
    end)

    it("treats two strings as a single keyspec", function()
      child.lua([[
        keys_handler.register({ "owner/plugin.nvim", keys = { "<leader>ff", "<leader>fg" } })
      ]])

      eq(child.lua_get("#keymap_set_calls"), 1)
      eq(child.lua_get("keymap_set_calls[1].lhs"), "<leader>ff")
    end)

    it("registers multiple keymaps from keyspec list", function()
      child.lua([[
        keys_handler.register({ "owner/plugin.nvim", keys = { { "<leader>ff" }, { "<leader>fg" } } })
      ]])

      eq(child.lua_get("#keymap_set_calls"), 2)
      eq(child.lua_get("keymap_set_calls[1].lhs"), "<leader>ff")
      eq(child.lua_get("keymap_set_calls[2].lhs"), "<leader>fg")
    end)

    it("supports keyspec with multiple modes", function()
      child.lua([[
        keys_handler.register({
          "owner/plugin.nvim",
          keys = { "<leader>ff", mode = { "n", "v" } },
        })
      ]])

      eq(child.lua_get("#keymap_set_calls"), 2)
      eq(child.lua_get("keymap_set_calls[1].mode"), "n")
      eq(child.lua_get("keymap_set_calls[2].mode"), "v")
    end)

    it("loads all specs sharing a key and replays keypress", function()
      child.lua([[
        keys_handler.register({ "owner/one.nvim", keys = "<leader>ff" })
        keys_handler.register({ "owner/two.nvim", keys = "<leader>ff" })

        keymap_set_calls[1].rhs()
      ]])

      eq(child.lua_get("#keymap_set_calls"), 1)
      eq(child.lua_get("load_call_count"), 2)
      eq(child.lua_get("loaded_specs"), { "owner/one.nvim", "owner/two.nvim" })
      eq(child.lua_get("#keymap_del_calls"), 1)
      eq(child.lua_get("keymap_del_calls[1].mode"), "n")
      eq(child.lua_get("keymap_del_calls[1].lhs"), "<leader>ff")
      eq(child.lua_get("#feedkeys_calls"), 1)
      eq(child.lua_get("feedkeys_calls[1].keys"), "KEYCODE:<leader>ff")
      eq(child.lua_get("feedkeys_calls[1].mode"), "m")
      eq(child.lua_get("feedkeys_calls[1].escape_ks"), false)
    end)

    it("notifies when loader returns an error", function()
      child.lua([[
        load_result_ok = false
        load_result_err = "boom"
        keys_handler.register({ "owner/plugin.nvim", keys = "<leader>ff" })

        keymap_set_calls[1].rhs()
      ]])

      eq(child.lua_get("#notify_calls"), 1)
      eq(child.lua_get("notify_calls[1]"), "boom")
    end)

    it("errors on invalid keys specification", function()
      eq(child.lua_get("pcall(function() keys_handler.register({ 'owner/plugin.nvim', keys = 123 }) end)"), false)
    end)
  end)
end)

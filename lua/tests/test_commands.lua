local eq = MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

local setup_commands_env = function()
  child.lua([[
    package.loaded["packlazy.commands"] = nil
    package.loaded["packlazy.state"] = nil

    state = require("packlazy.state")
    state.plugins = {}
    state.loaded = {}
    state.loading = {}
    state.failed = {}

    created_user_commands = {}
    notify_calls = {}
    pack_update_calls = {}
    pack_del_calls = {}
    pack_get_return = {}
    pack_get_calls = 0
    current_buf = nil
    created_buf = 0
    last_info_lines = nil

    vim.api.nvim_create_user_command = function(name, callback, opts)
      created_user_commands[name] = { callback = callback, opts = opts }
    end

    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = msg, level = level })
    end

    vim.pack = vim.pack or {}
    vim.pack.update = function(names, opts)
      table.insert(pack_update_calls, { names = names, opts = opts })
    end
    vim.pack.del = function(names)
      table.insert(pack_del_calls, names)
    end
    vim.pack.get = function(_names, _opts)
      pack_get_calls = pack_get_calls + 1
      return pack_get_return
    end

    vim.api.nvim_create_buf = function(_listed, _scratch)
      created_buf = created_buf + 1
      return created_buf
    end
    vim.api.nvim_set_current_buf = function(buf)
      current_buf = buf
    end
    vim.api.nvim_set_option_value = function(_name, _value, _opts)
    end
    vim.api.nvim_buf_set_lines = function(_buf, _start, _end, _strict, lines)
      last_info_lines = lines
    end

    commands = require("packlazy.commands")
    commands.setup()
  ]])
end

before_each(function()
  child.setup()
  setup_commands_env()
end)

teardown(function()
  child.stop()
end)

describe("packlazy.commands", function()
  it("registers PackInfo, PackUpdate, and PackClean commands", function()
    eq(child.lua_get("type(created_user_commands.PackInfo.callback)"), "function")
    eq(child.lua_get("type(created_user_commands.PackUpdate.callback)"), "function")
    eq(child.lua_get("type(created_user_commands.PackClean.callback)"), "function")
    eq(child.lua_get("created_user_commands.PackUpdate.opts.nargs"), "?")
    eq(child.lua_get("type(created_user_commands.PackUpdate.opts.complete)"), "function")
  end)

  it("updates all plugins when PackUpdate has no argument", function()
    child.lua([[ created_user_commands.PackUpdate.callback({ args = "" }) ]])

    eq(child.lua_get("#pack_update_calls"), 1)
    eq(child.lua_get("pack_update_calls[1].names == nil"), true)
  end)

  it("updates one plugin when PackUpdate receives a plugin name", function()
    child.lua([[
      state.plugins.mini = { "nvim-mini/mini.nvim" }
      created_user_commands.PackUpdate.callback({ args = "mini" })
    ]])

    eq(child.lua_get("#pack_update_calls"), 1)
    eq(child.lua_get("pack_update_calls[1].names[1]"), "mini")
  end)

  it("notifies and skips update for unknown plugin", function()
    child.lua([[ created_user_commands.PackUpdate.callback({ args = "missing" }) ]])

    eq(child.lua_get("#pack_update_calls"), 0)
    eq(child.lua_get("#notify_calls"), 1)
    eq(child.lua_get("notify_calls[1].msg:find('not found in spec', 1, true) ~= nil"), true)
  end)

  it("completes plugin names for PackUpdate", function()
    child.lua([[
      state.plugins.alpha = { "owner/alpha.nvim" }
      state.plugins.beta = { "owner/beta.nvim" }
      completion = created_user_commands.PackUpdate.opts.complete("al")
    ]])

    eq(child.lua_get("#completion"), 1)
    eq(child.lua_get("completion[1]"), "alpha")
  end)

  it("cleans only unused plugins", function()
    child.lua([[
      state.plugins.used = { "owner/used.nvim" }
      pack_get_return = {
        { spec = { name = "used" } },
        { spec = { name = "unused" } },
      }
      created_user_commands.PackClean.callback({})
    ]])

    eq(child.lua_get("#pack_del_calls"), 1)
    eq(child.lua_get("pack_del_calls[1][1]"), "unused")
  end)

  it("notifies when there are no unused plugins to clean", function()
    child.lua([[
      state.plugins.used = { "owner/used.nvim" }
      pack_get_return = {
        { spec = { name = "used" } },
      }
      created_user_commands.PackClean.callback({})
    ]])

    eq(child.lua_get("#pack_del_calls"), 0)
    eq(child.lua_get("#notify_calls"), 1)
    eq(child.lua_get("notify_calls[1].msg:find('no unused plugins to clean', 1, true) ~= nil"), true)
  end)

  it("opens an info buffer with plugin states", function()
    child.lua([[
      state.plugins.loaded_one = { "owner/loaded_one.nvim" }
      state.plugins.failed_one = { "owner/failed_one.nvim" }
      state.loaded.loaded_one = true
      state.failed.failed_one = "boom"
      pack_get_return = {
        { spec = { name = "loaded_one" } },
        { spec = { name = "unused_one" } },
      }

      created_user_commands.PackInfo.callback({})
      info_text = table.concat(last_info_lines, "\n")
    ]])

    eq(child.lua_get("current_buf"), 1)
    eq(child.lua_get("info_text:find('loaded_one | yes | yes | loaded', 1, true) ~= nil"), true)
    eq(child.lua_get("info_text:find('failed_one | yes | no | failed', 1, true) ~= nil"), true)
    eq(child.lua_get("info_text:find('unused_one | no | yes | unused', 1, true) ~= nil"), true)
  end)
end)

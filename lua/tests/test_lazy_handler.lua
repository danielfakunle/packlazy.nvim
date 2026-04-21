local eq = MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

local setup_lazy_handler_env = function()
  child.lua([[
    package.loaded["packlazy.handlers.lazy"] = nil
    package.loaded["packlazy.state"] = {
      plugins = {},
      loading = {},
      loaded = {},
      failed = {},
    }

    package.preload["plugin"] = function()
      return { name = "plugin" }
    end

    package.preload["plugin.config"] = function()
      return { name = "plugin.config" }
    end

    package.preload["custom"] = function()
      return { name = "custom" }
    end

    package.loaded["packlazy.loader"] = {
      load = function(spec)
        local plugin_name = spec.name or spec[1]:match(".*/(.*)")
        plugin_name = plugin_name:gsub("/+$", "")
        plugin_name = plugin_name:gsub("%.git$", "")
        plugin_name = plugin_name:gsub("%.nvim$", "")
        require("packlazy.state").loaded[plugin_name] = true
        load_call_count = load_call_count + 1
        last_loaded_spec = spec
      end,
    }

    load_call_count = 0
    last_loaded_spec = nil
    lazy_handler = require("packlazy.handlers.lazy")
  ]])
end

before_each(function()
  child.setup()
  setup_lazy_handler_env()
end)

teardown(function()
  child.stop()
end)

describe("packlazy.handlers.lazy", function()
  describe("register()", function()
    it("prepends a loader function to package.loaders", function()
      child.lua([[
        local n_before = #package.loaders
        local first_before = package.loaders[1]

        lazy_handler.register({ "owner/plugin.nvim" })

        prepend_assertions = {
          count_increased = (#package.loaders == n_before + 1),
          previous_first_shifted = (package.loaders[2] == first_before),
        }
      ]])

      eq(child.lua_get("prepend_assertions"), {
        count_increased = true,
        previous_first_shifted = true,
      })
    end)

    it("matches exact module name and loads plugin", function()
      child.lua([[
        local spec = { "owner/plugin.nvim" }
        lazy_handler.register(spec)

        local loader_fn = package.loaders[1]("plugin")
        loader_fn_type = type(loader_fn)
        loader_fn_result = loader_fn()
      ]])

      eq(child.lua_get("loader_fn_type"), "function")
      eq(child.lua_get("loader_fn_result.name"), "plugin")
      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec[1]"), "owner/plugin.nvim")
    end)

    it("matches plugin submodule names", function()
      child.lua([[
        local spec = { "owner/plugin.nvim" }
        lazy_handler.register(spec)

        local loader_fn = package.loaders[1]("plugin.config")
        loader_fn_type = type(loader_fn)
        loader_fn_result = loader_fn()
      ]])

      eq(child.lua_get("loader_fn_type"), "function")
      eq(child.lua_get("loader_fn_result.name"), "plugin.config")
      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec[1]"), "owner/plugin.nvim")
    end)

    it("skips interception when plugin is already loaded", function()
      child.lua([[
        require("packlazy.state").loaded.plugin = true
        lazy_handler.register({ "owner/plugin.nvim" })
        already_loaded_result = package.loaders[1]("plugin")
      ]])

      eq(child.lua_get("already_loaded_result == nil"), true)
      eq(child.lua_get("load_call_count"), 0)
    end)

    it("does not match unrelated modules", function()
      child.lua([[
        lazy_handler.register({ "owner/plugin.nvim" })
        non_match_result = package.loaders[1]("other.module")
      ]])

      eq(child.lua_get("non_match_result == nil"), true)
      eq(child.lua_get("load_call_count"), 0)
    end)

    it("does not match similar prefixes without dot boundary", function()
      child.lua([[
        lazy_handler.register({ "owner/plugin.nvim" })
        prefix_result = package.loaders[1]("pluginx")
      ]])

      eq(child.lua_get("prefix_result == nil"), true)
      eq(child.lua_get("load_call_count"), 0)
    end)

    it("uses explicit plugin name override for matching", function()
      child.lua([[
        lazy_handler.register({ "owner/repo.nvim", name = "custom" })

        local match_fn = package.loaders[1]("custom")
        local miss_fn = package.loaders[1]("repo")

        match_type = type(match_fn)
        miss_is_nil = miss_fn == nil
        match_fn()
      ]])

      eq(child.lua_get("match_type"), "function")
      eq(child.lua_get("miss_is_nil"), true)
      eq(child.lua_get("load_call_count"), 1)
      eq(child.lua_get("last_loaded_spec.name"), "custom")
    end)
  end)
end)

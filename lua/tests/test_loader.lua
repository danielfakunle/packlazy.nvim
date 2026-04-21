local expect, eq = MiniTest.expect, MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

---@param child MiniTest.child
local function setup_env(child)
  child.lua([[
    package.loaded["packlazy.loader"] = nil
    package.loaded["packlazy.state"] = nil

    pack_add_calls = {}
    pack_del_calls = {}
    notifications = {}
    events = {}
    setup_opts = nil
    setup_called = 0
    config_called = 0

    vim.pack = vim.pack or {}
    vim.pack.add = function(repos, opts)
      table.insert( pack_add_calls, { repos = repos, opts = opts })
      table.insert( events, "pack:" .. repos[1])
    end
    vim.pack.del = function(names)
      table.insert( pack_del_calls, names)
      table.insert( events, "del:" .. names[1])
    end

    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    state = require("packlazy.state")
    state.plugins = {}
    state.loading = {}
    state.loaded = {}
    state.failed = {}

    loader = require("packlazy.loader")
  ]])
end

before_each(function()
  child.setup()
  setup_env(child)
end)

teardown(function()
  child.stop()
end)

describe("packlazy.loader", function()
  describe("packadd()", function()
    it("adds normalized repo with confirm option", function()
      child.lua([[
        require("packlazy.config").defaults.confirm = false
        loader.packadd({ "nvim-mini/mini.nvim" })
      ]])

      eq(child.lua_get("#pack_add_calls"), 1)
      eq(child.lua_get("pack_add_calls[1].repos[1]"), "https://github.com/nvim-mini/mini.nvim")
      eq(child.lua_get("pack_add_calls[1].opts.confirm"), false)
    end)
  end)

  describe("packdel()", function()
    it("deletes by normalized plugin name", function()
      child.lua([[  loader.packdel({ "nvim-mini/mini.nvim" }) ]])

      eq(child.lua_get("#pack_del_calls"), 1)
      eq(child.lua_get("pack_del_calls[1][1]"), "mini")
    end)

    it("notifies at info level when plugin is not installed", function()
      child.lua([[
        vim.pack.del = function(_)
          error("Plugin `mini` is not installed")
        end

        del_ok = loader.packdel({ "nvim-mini/mini.nvim" })
      ]])

      eq(child.lua_get("del_ok"), true)
      eq(child.lua_get("#notifications"), 1)
      eq(child.lua_get("notifications[1].level"), child.lua_get("vim.log.levels.INFO"))
      eq(child.lua_get("notifications[1].msg:find('not installed', 1, true) ~= nil"), true)
    end)
  end)

  describe("load()", function()
    it("returns early when already loaded", function()
      child.lua([[
        local spec = { "nvim-mini/mini.nvim" }
         state.loaded.mini = true
         loader.load(spec)
      ]])

      eq(child.lua_get("#pack_add_calls"), 0)
    end)

    it("returns early when already loading", function()
      child.lua([[
        local spec = { "nvim-mini/mini.nvim" }
         state.loading.mini = true
         loader.load(spec)
      ]])

      eq(child.lua_get("#pack_add_calls"), 0)
    end)

    it("skips disabled dependency and uninstalls it", function()
      child.lua([[
        loader.load({
          "owner/main.nvim",
          dependencies = {
            { "owner/dep.nvim", enabled = false },
          },
        })
      ]])

      eq(child.lua_get("#pack_add_calls"), 1)
      eq(child.lua_get("#pack_del_calls"), 1)
      eq(child.lua_get("pack_del_calls[1][1]"), "dep")
      eq(child.lua_get("pack_add_calls[1].repos[1]"), "https://github.com/owner/main.nvim")
      eq(child.lua_get("state.loaded.dep == nil"), true)
      eq(child.lua_get("state.loaded.main"), true)
    end)

    it("skips dependency when cond is false without uninstalling", function()
      child.lua([[
        loader.load({
          "owner/main.nvim",
          dependencies = {
            { "owner/dep.nvim", cond = false },
          },
        })
      ]])

      eq(child.lua_get("#pack_add_calls"), 1)
      eq(child.lua_get("#pack_del_calls"), 0)
      eq(child.lua_get("pack_add_calls[1].repos[1]"), "https://github.com/owner/main.nvim")
      eq(child.lua_get("state.loaded.dep == nil"), true)
      eq(child.lua_get("state.loaded.main"), true)
    end)

    it("loads dependencies before parent and runs init before packadd", function()
      child.lua([[
        local spec = {
          "owner/main.nvim",
          dependencies = {
            {
              "owner/dep.nvim",
              init = function()
                table.insert( events, "dep_init")
              end,
            },
          },
          init = function()
            table.insert( events, "main_init")
          end,
        }

         loader.load(spec)
      ]])

      eq(child.lua_get(" events"), {
        "dep_init",
        "pack:https://github.com/owner/dep.nvim",
        "main_init",
        "pack:https://github.com/owner/main.nvim",
      })
      eq(child.lua_get("state.loaded.dep"), true)
      eq(child.lua_get("state.loaded.main"), true)
      eq(child.lua_get("state.loading.dep == nil"), true)
      eq(child.lua_get("state.loading.main == nil"), true)
    end)

    it("calls module setup when config is true", function()
      child.lua([[
        package.loaded.plugin = {
          setup = function(opts)
             setup_called =  setup_called + 1
             setup_opts = opts
          end,
        }

         loader.load({
          "owner/plugin.nvim",
          config = true,
          opts = { answer = 42 },
        })
      ]])

      eq(child.lua_get("setup_called"), 1)
      eq(child.lua_get("setup_opts.answer"), 42)
    end)

    it("evaluates function opts before module setup", function()
      child.lua([[
        package.loaded.plugin = {
          setup = function(opts)
             setup_called =  setup_called + 1
             setup_opts = opts
          end,
        }

         loader.load({
          "owner/plugin.nvim",
          config = true,
          opts = function()
            return { from_fn = true }
          end,
        })
      ]])

      eq(child.lua_get("setup_called"), 1)
      eq(child.lua_get("setup_opts.from_fn"), true)
    end)

    it("calls custom config function", function()
      child.lua([[
        package.loaded.plugin = {
          setup = function(_)
             setup_called =  setup_called + 1
          end,
        }

         loader.load({
          "owner/plugin.nvim",
          config = function()
             config_called =  config_called + 1
          end,
          opts = { ignored = true },
        })
      ]])

      eq(child.lua_get("config_called"), 1)
      eq(child.lua_get("setup_called"), 0)
    end)

    it("cleans loading state when init errors", function()
      child.lua([[
        load_ok, load_err = loader.load({
          "owner/fail.nvim",
          init = function()
            error("init exploded")
          end,
        })
      ]])

      eq(child.lua_get("load_ok"), false)
      eq(child.lua_get("type(load_err)"), "string")
      eq(child.lua_get("state.loading.fail == nil"), true)
      eq(child.lua_get("state.loaded.fail == nil"), true)
      eq(child.lua_get("type(state.failed.fail)"), "string")
      eq(child.lua_get("#pack_add_calls"), 0)
    end)

    it("cleans loading state when setup errors", function()
      child.lua([[
        package.loaded.plugin = {
          setup = function(_)
            error("setup exploded")
          end,
        }

        load_ok, load_err = loader.load({
          "owner/plugin.nvim",
          config = true,
        })
      ]])

      eq(child.lua_get("load_ok"), false)
      eq(child.lua_get("type(load_err)"), "string")
      eq(child.lua_get("state.loading.plugin == nil"), true)
      eq(child.lua_get("state.loaded.plugin == nil"), true)
      eq(child.lua_get("type(state.failed.plugin)"), "string")
    end)

    it("cleans loading state for parent when dependency init errors", function()
      child.lua([[
        load_ok, load_err = loader.load({
          "owner/main.nvim",
          dependencies = {
            {
              "owner/dep.nvim",
              init = function()
                error("dep init exploded")
              end,
            },
          },
        })
      ]])

      eq(child.lua_get("load_ok"), false)
      eq(child.lua_get("type(load_err)"), "string")
      eq(child.lua_get("state.loading.dep == nil"), true)
      eq(child.lua_get("state.loading.main == nil"), true)
      eq(child.lua_get("state.loaded.dep == nil"), true)
      eq(child.lua_get("state.loaded.main == nil"), true)
      eq(child.lua_get("type(state.failed.dep)"), "string")
      eq(child.lua_get("type(state.failed.main)"), "string")
      eq(child.lua_get("#pack_add_calls"), 0)
    end)
  end)
end)

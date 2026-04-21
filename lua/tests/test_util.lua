local expect, eq = MiniTest.expect, MiniTest.expect.equality
local util = require("packlazy.util")
local config = require("packlazy.config")

describe("packlazy.util", function()
  describe("create_plugin_spec_list()", function()
    it("wraps a string into a plugin spec list", function()
      eq(util.create_plugin_spec_list("nvim-mini/mini.nvim"), {
        { "nvim-mini/mini.nvim" },
      })
    end)

    it("wraps a plugin spec table into a list", function()
      local spec = { "nvim-mini/mini.nvim", lazy = true }
      eq(util.create_plugin_spec_list(spec), { spec })
    end)

    it("returns a plugin spec list as-is", function()
      local spec_list = {
        { "nvim-mini/mini.nvim" },
        { "folke/lazydev.nvim", lazy = false },
      }
      eq(util.create_plugin_spec_list(spec_list), spec_list)
    end)

    it("errors on invalid input", function()
      expect.error(function()
        util.create_plugin_spec_list(123)
      end)
    end)
  end)

  describe("is_enabled()", function()
    it("returns true when enabled is missing", function()
      eq(util.is_enabled({ "nvim-mini/mini.nvim" }), true)
    end)

    it("returns the boolean value when enabled is boolean", function()
      eq(util.is_enabled({ "nvim-mini/mini.nvim", enabled = true }), true)
      eq(util.is_enabled({ "nvim-mini/mini.nvim", enabled = false }), false)
    end)

    it("evaluates enabled callback", function()
      eq(util.is_enabled({ "nvim-mini/mini.nvim", enabled = function()
        return true
      end }), true)

      eq(util.is_enabled({ "nvim-mini/mini.nvim", enabled = function()
        return false
      end }), false)
    end)

    it("passes spec to enabled callback", function()
      local seen = nil
      local spec = {
        "nvim-mini/mini.nvim",
        enabled = function(plugin)
          seen = plugin[1]
          return true
        end,
      }

      eq(util.is_enabled(spec), true)
      eq(seen, "nvim-mini/mini.nvim")
    end)
  end)

  describe("is_cond()", function()
    it("returns true when cond is missing", function()
      eq(util.is_cond({ "nvim-mini/mini.nvim" }), true)
    end)

    it("returns the boolean value when cond is boolean", function()
      eq(util.is_cond({ "nvim-mini/mini.nvim", cond = true }), true)
      eq(util.is_cond({ "nvim-mini/mini.nvim", cond = false }), false)
    end)

    it("evaluates cond callback and passes spec", function()
      local seen = nil
      local spec = {
        "nvim-mini/mini.nvim",
        cond = function(plugin)
          seen = plugin[1]
          return false
        end,
      }

      eq(util.is_cond(spec), false)
      eq(seen, "nvim-mini/mini.nvim")
    end)
  end)

  describe("get_plugin_repo()", function()
    it("builds github url from owner/repo", function()
      eq(
        util.get_plugin_repo({ "nvim-mini/mini.nvim" }),
        "https://github.com/nvim-mini/mini.nvim"
      )
    end)

    it("keeps full http(s) url unchanged", function()
      eq(
        util.get_plugin_repo({ "https://github.com/nvim-mini/mini.nvim" }),
        "https://github.com/nvim-mini/mini.nvim"
      )

      eq(
        util.get_plugin_repo({ "http://github.com/nvim-mini/mini.nvim" }),
        "http://github.com/nvim-mini/mini.nvim"
      )
    end)
  end)

  describe("get_plugin_name()", function()
    it("uses explicit name override", function()
      eq(util.get_plugin_name({ "nvim-mini/mini.nvim", name = "mini" }), "mini")
    end)

    it("extracts repo name from owner/repo", function()
      eq(util.get_plugin_name({ "nvim-mini/mini.nvim" }), "mini")
    end)

    it("returns empty name for trailing slash edge case", function()
      eq(util.get_plugin_name({ "nvim-mini/mini.nvim/" }), "")
    end)

    it("strips .git suffix", function()
      eq(util.get_plugin_name({ "https://github.com/nvim-mini/mini.nvim.git" }), "mini")
    end)

    it("strips .nvim suffix", function()
      eq(util.get_plugin_name({ "nvim-mini/mini.nvim" }), "mini")
    end)
  end)

  describe("set_plugin_defaults()", function()
    it("applies defaults recursively and preserves explicit values", function()
      local old_lazy = config.defaults.lazy
      config.defaults.lazy = false

      local spec_list = {
        { "owner/first.nvim" },
        {
          "owner/second.nvim",
          lazy = true,
          enabled = false,
          dependencies = {
            { "owner/dep.nvim" },
          },
        },
      }

      local result = util.set_plugin_defaults(spec_list)

      eq(result, spec_list)
      eq(spec_list[1].lazy, false)
      eq(spec_list[1].enabled, true)

      eq(spec_list[2].lazy, true)
      eq(spec_list[2].enabled, false)
      eq(spec_list[2].dependencies[1].lazy, false)
      eq(spec_list[2].dependencies[1].enabled, true)

      config.defaults.lazy = old_lazy
    end)
  end)
end)

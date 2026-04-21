local setup = require("packlazy.config").setup
local util = require("packlazy.util")
local state = require("packlazy.state")
local loader = require("packlazy.loader")
local errors = require("packlazy.errors")
local commands = require("packlazy.commands")
local handlers = {
  lazy = require("packlazy.handlers.lazy"),
  event = require("packlazy.handlers.event"),
  cmd = require("packlazy.handlers.cmd"),
  keys = require("packlazy.handlers.keys"),
}

local M = {}

---@class PluginSpec
---@field [1] string The plugin repository, e.g. "nvim-telescope/telescope.nvim"
---@field lazy? boolean Whether to load the plugin lazily
---@field name? string Name for the plugin, defaults to the repository name
---@field version? string|vim.VersionRange Version to use for install and updates
---@field init? fun() Function to run before the plugin is loaded
---@field config? boolean|fun() Function to run after the plugin is loaded
---@field dependencies? PluginSpec[] List of plugin specifications that this plugin depends on
---@field opts? table|fun():table Options to pass to the plugin's config function
---@field enabled? boolean|fun(spec?:PluginSpec):boolean Whether to enable the plugin, defaults to true
---@field cond? boolean|fun(spec?:PluginSpec):boolean Like `enabled` but does not uninstall when false
---@field event? string|string[]|{event:string|string[],pattern?:string} Lazy load on event(s), e.g. "BufRead"
---@field cmd? string|string[]|fun():string[] Lazy load when command(s) are invoked
---@field keys? string|string[]|KeySpec|KeySpec[] Lazy load on key press

---@class KeySpec
---@field [1] string Left-hand side mapping
---@field [2]? string|fun() Right-hand side mapping
---@field mode? string|string[] Mapping mode(s)
---@field desc? string Mapping description
---@field remap? boolean Whether mapping is remapped
---@field nowait? boolean Whether mapping is nowait

M.setup = function(opts)
  setup(opts)
  commands.setup()
end

---@param plugins string|PluginSpec|PluginSpec[]
function M.add(plugins)
  local spec_list = util.create_plugin_spec_list(plugins)
  spec_list = util.set_plugin_defaults(spec_list)
  for _, spec in ipairs(spec_list) do
    local ok, err = xpcall(function()
      local plugin_name = util.get_plugin_name(spec)

      if not util.is_enabled(spec) then
        local deleted, delete_err = loader.packdel(spec)
        if deleted == false then
          errors.notify(delete_err)
        end
        return
      end

      if not util.is_cond(spec) then
        return
      end

      state.plugins[plugin_name] = spec
      if spec.lazy then
        handlers.lazy.register(spec)
      end
      if spec.event then
        handlers.event.register(spec)
      end
      if spec.cmd then
        handlers.cmd.register(spec)
      end
      if spec.keys then
        handlers.keys.register(spec)
      end
      if not spec.lazy then
        local loaded, load_err = loader.load(spec)
        if loaded == false then
          errors.notify(load_err)
        end
      end
    end, debug.traceback)

    if not ok then
      errors.report(spec, "add", err)
    end
  end
end

return M

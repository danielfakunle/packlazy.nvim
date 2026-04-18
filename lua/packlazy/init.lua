local setup = require("packlazy.config").setup
local util = require("packlazy.util")
local state = require("packlazy.state")
local loader = require("packlazy.loader")
local handlers = {
  lazy = require("packlazy.handlers.lazy"),
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
---@field enabled? boolean|fun():boolean Whether to enable the plugin, defaults to true

M.setup = setup

---@param plugins string|PluginSpec|PluginSpec[]
function M.add(plugins)
  local spec_list = util.create_plugin_spec_list(plugins)
  spec_list = util.set_plugin_defaults(spec_list)
  for _, spec in ipairs(spec_list) do
    local plugin_name = util.get_plugin_name(spec)
    if spec.lazy then
      state.plugins[plugin_name] = spec
      handlers.lazy.register(spec)
    end
    if not spec.lazy then
      loader.load(spec)
    end
  end
end

return M

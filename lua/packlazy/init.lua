local setup = require("packlazy.config").setup
local util = require("packlazy.util")
local config = require("packlazy.config").defaults

local M = {}

---@class PluginSpec
---@field [1] string The plugin repository, e.g. "nvim-telescope/telescope.nvim"
---@field lazy? boolean Whether to load the plugin lazily, defaults to true
---@field name? string Name for the plugin, defaults to the repository name
---@field version? string|vim.VersionRange Version to use for install and updates
---@field init? fun() Function to run before the plugin is loaded
---@field config? fun() Function to run after the plugin is loaded
---@field dependencies? PluginSpec[] List of plugin specifications that this plugin depends on
---@field opts? table|fun():table Options to pass to the plugin's config function
---@field enabled? boolean|fun():boolean Whether to enable the plugin, defaults to true

M.setup = setup

---@param plugins string|PluginSpec|PluginSpec[]
function M.add(plugins)
	local spec_list = util.create_plugin_spec_list(plugins)
	for _, spec in ipairs(spec_list) do
		local plugin_name = util.get_plugin_name(spec)
		if config.lazy or spec.lazy then
			require("packlazy.state").plugins[plugin_name] = spec
		else
			require("packlazy.loader").load(spec)
		end
	end
end

return M

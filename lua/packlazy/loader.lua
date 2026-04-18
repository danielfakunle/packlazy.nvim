local state = require("packlazy.state")
local util = require("packlazy.util")
local config = require("packlazy.config").defaults

local M = {}

function M.packadd(spec)
	local plugin_repo = util.get_plugin_repo(spec)
	vim.pack.add({ plugin_repo }, {
		confirm = config.confirm,
	})
end

---@param spec PluginSpec
M.load = function(spec)
	local plugin_name = util.get_plugin_name(spec)
	if state.loaded[plugin_name] or state.loading[plugin_name] or not util.is_enabled(spec) then
		return
	end
	state.loading[plugin_name] = true
	if spec.dependencies then
		for _, dep in ipairs(spec.dependencies) do
			M.load(dep)
		end
	end
	if spec.init then
		spec.init()
	end
	M.packadd(spec)
	state.loading[plugin_name] = nil
	state.loaded[plugin_name] = true
	local opts = (type(spec.opts) == "function" and spec.opts() or spec.opts) or {}
	if spec.config then
		if type(spec.config) == "boolean" then
			require(plugin_name).setup(opts)
		elseif type(spec.config) == "function" then
			spec.config()
		end
	end
end

return M

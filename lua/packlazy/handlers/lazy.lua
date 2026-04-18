local loader = require("packlazy.loader")
local util = require("packlazy.util")

local M = {}

---@param spec PluginSpec
function M.register(spec)
  local plugin_name = util.get_plugin_name(spec)
  table.insert(package.loaders, 1, function(name)
    if name == plugin_name or name:sub(1, #plugin_name + 1) == plugin_name .. "." then
      return function()
        loader.load(spec)
        return nil
      end
    end
  end)
end

return M

local loader = require("packlazy.loader")
local util = require("packlazy.util")
local errors = require("packlazy.errors")
local state = require("packlazy.state")

local M = {}

---@param spec PluginSpec
function M.register(spec)
  local plugin_name = util.get_plugin_name(spec)
  table.insert(package.loaders, 1, function(name)
    if name == plugin_name or name:sub(1, #plugin_name + 1) == plugin_name .. "." then
      if state.loaded[plugin_name] or state.loading[plugin_name] then
        return nil
      end

      return function()
        local ok, err = loader.load(spec)
        if ok == false then
          error(err, 0)
        end
        return require(name)
      end
    end
  end)
end

return M

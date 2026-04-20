local loader = require("packlazy.loader")
local util = require("packlazy.util")
local errors = require("packlazy.errors")

local M = {}

---@param spec PluginSpec
function M.register(spec)
  local plugin_name = util.get_plugin_name(spec)
  table.insert(package.loaders, 1, function(name)
    if name == plugin_name or name:sub(1, #plugin_name + 1) == plugin_name .. "." then
      return function()
        local ok, err = loader.load(spec)
        if ok == false then
          errors.notify(err)
        end
        return nil
      end
    end
  end)
end

return M

local state = require("packlazy.state")
local util = require("packlazy.util")
local errors = require("packlazy.errors")
local config = require("packlazy.config").defaults

local M = {}

function M.packadd(spec)
  local plugin_repo = util.get_plugin_repo(spec)
  vim.pack.add({ plugin_repo }, {
    confirm = config.confirm,
  })
end

function M.packdel(spec)
  local plugin_name = util.get_plugin_name(spec)
  vim.pack.del({ plugin_name })
end

---@param spec PluginSpec
M.load = function(spec)
  local plugin_name = util.get_plugin_name(spec)

  if state.loaded[plugin_name] or state.loading[plugin_name] then
    return true
  end

  state.loading[plugin_name] = true
  local should_mark_loaded = true

  local ok, err = xpcall(function()
    if not util.is_enabled(spec) then
      should_mark_loaded = false
      M.packdel(spec)
      return
    end

    if spec.dependencies then
      for _, dep in ipairs(spec.dependencies) do
        local dep_ok, dep_err = M.load(dep)
        if dep_ok == false then
          error(dep_err, 0)
        end
      end
    end

    if spec.init then
      spec.init()
    end

    M.packadd(spec)

    local opts = (type(spec.opts) == "function" and spec.opts() or spec.opts) or {}
    if spec.config then
      if type(spec.config) == "boolean" then
        require(plugin_name).setup(opts)
      elseif type(spec.config) == "function" then
        spec.config()
      end
    end
  end, debug.traceback)

  state.loading[plugin_name] = nil

  if not ok then
    state.loaded[plugin_name] = nil
    local formatted_err = errors.format(spec, "load", err)
    state.failed[plugin_name] = formatted_err
    return false, formatted_err
  end

  if should_mark_loaded then
    state.loaded[plugin_name] = true
  else
    state.loaded[plugin_name] = nil
  end

  state.failed[plugin_name] = nil
  return true
end

return M

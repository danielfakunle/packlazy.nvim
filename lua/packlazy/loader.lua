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
  local ok, err = pcall(vim.pack.del, { plugin_name })
  if not ok then
    if tostring(err):find("is not installed", 1, true) then
      errors.notify("plugin `" .. plugin_name .. "` is not installed", "INFO")
      return true
    end
    return false, errors.format(spec, "packdel", err)
  end
  return true
end

---@param spec PluginSpec
M.load = function(spec)
  local plugin_name = util.get_plugin_name(spec)

  if state.loaded[plugin_name] or state.loading[plugin_name] then
    return true
  end

  state.loading[plugin_name] = true

  local ok, err = xpcall(function()
    if spec.dependencies then
      for _, dep in ipairs(spec.dependencies) do
        if not util.is_enabled(dep) then
          local dep_deleted, dep_delete_err = M.packdel(dep)
          if dep_deleted == false then
            error(dep_delete_err, 0)
          end
        elseif util.is_cond(dep) then
          local dep_ok, dep_err = M.load(dep)
          if dep_ok == false then
            error(dep_err, 0)
          end
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

  state.loaded[plugin_name] = true

  state.failed[plugin_name] = nil
  return true
end

return M

local config = require("packlazy.config").defaults

local M = {}

---@param spec any
---@return PluginSpec
local function normalize_plugin_spec(spec)
  if type(spec) == "string" then
    return { spec }
  end

  if type(spec) == "table" and type(spec[1]) == "string" then
    return spec
  end

  error("Invalid plugin specification: " .. tostring(spec))
end

---@param input string | PluginSpec | PluginSpec[]
---@return PluginSpec[] spec_list list of plugin specifications
function M.create_plugin_spec_list(input)
  if type(input) == "string" then
    return { { input } }
  elseif type(input) == "table" then
    local has_named_keys = false
    for key, _ in pairs(input) do
      if type(key) ~= "number" then
        has_named_keys = true
        break
      end
    end

    if has_named_keys and type(input[1]) == "string" then
      return { input }
    end

    local spec_list = {}
    for _, spec in ipairs(input) do
      table.insert(spec_list, normalize_plugin_spec(spec))
    end
    return spec_list
  else
    error("Invalid plugin specification: " .. tostring(input))
  end
end

---@param spec PluginSpec
---@return boolean enabled Whether the plugin is enabled
function M.is_enabled(spec)
  if spec.enabled == nil then
    return true
  elseif type(spec.enabled) == "function" then
    return spec.enabled(spec)
  else
    return spec.enabled
  end
end

---@param spec PluginSpec
---@return boolean cond Whether plugin conditions pass
function M.is_cond(spec)
  if spec.cond == nil then
    return true
  elseif type(spec.cond) == "function" then
    return spec.cond(spec)
  else
    return spec.cond
  end
end

---@param spec PluginSpec
---@return string repo The full URL of the plugin repository
function M.get_plugin_repo(spec)
  if spec[1]:match("^https?://") then
    return spec[1]
  end
  return "https://github.com/" .. spec[1]
end

---@param spec PluginSpec
---@return string name The name of the plugin
function M.get_plugin_name(spec)
  if spec.name then
    return spec.name
  end
  local repo = spec[1]:match(".*/(.*)")
  repo = repo:gsub("/+$", "")
  repo = repo:gsub("%.git$", "")
  repo = repo:gsub("%.nvim$", "")
  return repo
end

---@param spec_list PluginSpec[]
---@return PluginSpec[] spec_list with defaults applied
function M.set_plugin_defaults(spec_list)
  for index, spec in ipairs(spec_list) do
    spec = normalize_plugin_spec(spec)
    spec_list[index] = spec

    if spec.lazy == nil then
      spec.lazy = config.lazy
    end
    if spec.opts ~= nil and spec.config == nil then
      spec.config = true
    end
    if spec.enabled == nil then
      spec.enabled = true
    end
    if spec.dependencies then
      spec.dependencies = M.set_plugin_defaults(M.create_plugin_spec_list(spec.dependencies))
    end
  end
  return spec_list
end

return M

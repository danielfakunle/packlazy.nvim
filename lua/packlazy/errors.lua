local M = {}
local util = require("packlazy.util")

local level_aliases = {
  ERROR = vim.log.levels.ERROR,
  WARN = vim.log.levels.WARN,
  INFO = vim.log.levels.INFO,
}

---@param msg string
---@param level? "ERROR"|"WARN"|"INFO"
function M.notify(msg, level)
  vim.notify("[packlazy] " .. msg, level_aliases[level] or vim.log.levels.ERROR)
end

---@param spec? PluginSpec
---@param stage? string
---@param err any
---@return string
function M.format(spec, stage, err)
  local plugin_name = "unknown"

  if type(spec) == "table" then
    local ok, resolved_name = pcall(util.get_plugin_name, spec)
    if ok and type(resolved_name) == "string" and resolved_name ~= "" then
      plugin_name = resolved_name
    end
  end

  local stage_suffix = stage and (" [" .. stage .. "]") or ""
  return plugin_name .. stage_suffix .. ": " .. tostring(err)
end

---@param spec? PluginSpec
---@param stage? string
---@param err any
---@param level? "ERROR"|"WARN"|"INFO"
function M.report(spec, stage, err, level)
  M.notify(M.format(spec, stage, err), level)
end

return M

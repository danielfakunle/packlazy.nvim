local loader = require("packlazy.loader")
local util = require("packlazy.util")
local errors = require("packlazy.errors")

local M = {}
local augroup = vim.api.nvim_create_augroup("packlazy", { clear = false })

local user_events = {
  VeryLazy = true,
}

local events_bridged = false

---@param pattern string
---@param data any
local function emit_user_event(pattern, data)
  vim.api.nvim_exec_autocmds("User", {
    pattern = pattern,
    data = data,
  })
end

function M.bridge_user_events()
  if events_bridged then
    return
  end
  events_bridged = true
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    once = true,
    callback = function()
      vim.schedule(function()
        emit_user_event("VeryLazy")
      end)
    end,
  })
end

---@param spec PluginSpec
---@return string[] events, string[]? user_events
local parse_events = function(spec)
  if type(spec.event) == "string" then
    if user_events[spec.event] then
      return { spec.event }, { spec.event }
    end
    return { spec.event }
  end
  if type(spec.event) == "table" and spec.event.event then
    ---@diagnostic disable-next-line: return-type-mismatch
    return type(spec.event.event) == "string" and { spec.event.event } or spec.event.event
  end
  if type(spec.event) == "table" then
    local user_evts = {}
    ---@diagnostic disable-next-line: param-type-mismatch
    for _, evt in ipairs(spec.event) do
      if user_events[evt] then
        table.insert(user_evts, evt)
      end
    end
    if #user_evts > 0 then
      ---@diagnostic disable-next-line: return-type-mismatch
      return spec.event, user_evts
    end
    ---@diagnostic disable-next-line: return-type-mismatch
    return spec.event
  end
  error("Invalid event specification for plugin " .. util.get_plugin_name(spec), 0)
end

---@param spec PluginSpec
function M.register(spec)
  if not spec.event then
    return
  end
  M.bridge_user_events()
  local events, user_events = parse_events(spec)
  local pattern = type(spec.event) == "table" and spec.event.pattern or nil
  vim.api.nvim_create_autocmd(events, {
    pattern = pattern,
    callback = function()
      local ok, err = loader.load(spec)
      if ok == false then
        errors.notify(err)
      end
    end,
    once = true,
  })
  if user_events then
    for _, evt in ipairs(user_events) do
      vim.api.nvim_create_autocmd("User", {
        pattern = evt,
        callback = function()
          local ok, err = loader.load(spec)
          if ok == false then
            errors.notify(err)
          end
        end,
        once = true,
      })
    end
  end
end

return M

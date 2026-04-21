local loader = require("packlazy.loader")
local util = require("packlazy.util")
local errors = require("packlazy.errors")

local M = {}

local key_to_entry = {}

---@param lhs string
---@param mode string
---@return string
local function create_key_id(lhs, mode)
  return lhs .. "\0" .. mode
end

---@param val string|string[]
---@return string[]
local function normalize_string_list(val)
  if type(val) == "string" then
    return { val }
  end
  return val
end

---@param keys string|string[]|KeySpec|KeySpec[]
---@param plugin_name string
---@return KeySpec[]
local function normalize_keys(keys, plugin_name)
  if type(keys) ~= "string" and type(keys) ~= "table" then
    error("Invalid keys specification for plugin " .. plugin_name, 0)
  end

  local is_string_input = type(keys) == "string"
  local is_keyspec_input = type(keys) == "table" and type(keys[1]) == "string"
  local key_list = (is_string_input or is_keyspec_input) and { keys } or keys

  local result = {}
  for _, key in ipairs(key_list) do
    if type(key) == "string" then
      table.insert(result, { key })
    elseif type(key) == "table" and type(key[1]) == "string" then
      table.insert(result, key)
    else
      error("Invalid keys specification for plugin " .. plugin_name, 0)
    end
  end
  return result
end

---@param split_mode string
---@param lhs string
---@param specs PluginSpec[]
local function create_keymap(split_mode, lhs, specs, desc)
  vim.keymap.set(split_mode, lhs, function()
    pcall(vim.keymap.del, split_mode, lhs)

    for _, spec in ipairs(specs) do
      local ok, err = loader.load(spec)
      if ok == false then
        errors.notify(err)
      end
    end

    vim.api.nvim_feedkeys(vim.keycode(lhs), "m", false)
  end, {
    desc = desc,
    remap = false,
    nowait = false,
  })
end

---@param spec PluginSpec
function M.register(spec)
  if not spec.keys then
    return
  end

  local plugin_name = util.get_plugin_name(spec)
  local keys = normalize_keys(spec.keys, plugin_name)
  for _, key in ipairs(keys) do
    local lhs = key[1]
    local modes = normalize_string_list(key.mode or "n")

    for _, split_mode in ipairs(modes) do
      local key_id = create_key_id(lhs, split_mode)
      local entry = key_to_entry[key_id]
      if not entry then
        entry = {
          lhs = lhs,
          split_mode = split_mode,
          desc = key.desc,
          specs = {},
        }
        key_to_entry[key_id] = entry
        create_keymap(split_mode, lhs, entry.specs, entry.desc)
      end
      table.insert(entry.specs, spec)
    end
  end
end

return M

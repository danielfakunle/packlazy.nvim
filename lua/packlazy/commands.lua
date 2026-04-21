local state = require("packlazy.state")
local errors = require("packlazy.errors")

local M = {}

local function canonical_plugin_name(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name:gsub("%.nvim$", "")
end

local function is_packlazy_plugin(pack)
  local spec = pack and pack.spec or {}
  local name = canonical_plugin_name(spec.name)
  if name == "packlazy" then
    return true
  end

  local src = type(spec.src) == "string" and spec.src:lower() or ""
  return src:find("packlazy", 1, true) ~= nil
end

local function create_command(name, callback, opts)
  local ok, err = pcall(vim.api.nvim_create_user_command, name, callback, opts)
  if not ok then
    errors.notify("failed to create command `" .. name .. "`: " .. tostring(err))
    return false
  end
  return true
end

local function get_registered_plugin_names()
  local names = vim.tbl_keys(state.plugins)
  table.sort(names, function(a, b)
    return a:lower() < b:lower()
  end)
  return names
end

local function filter_completions(list, prefix)
  if prefix == "" then
    return list
  end

  local lowered_prefix = prefix:lower()
  return vim.tbl_filter(function(name)
    return name:lower():find(lowered_prefix, 1, true) == 1
  end, list)
end

local function update_plugin(arg)
  local plugin_name = vim.trim(arg or "")
  local ok
  local err

  if plugin_name == "" then
    ok, err = pcall(vim.pack.update)
  else
    if not state.plugins[plugin_name] then
      errors.notify('plugin "' .. plugin_name .. '" not found in spec')
      return
    end
    ok, err = pcall(vim.pack.update, { plugin_name })
  end

  if not ok then
    errors.notify("update failed: " .. tostring(err))
  end
end

local function clean_unused()
  local installed = vim.pack.get(nil, { info = false }) or {}
  local to_delete = {}
  local registered_keys = {}

  for name, _ in pairs(state.plugins) do
    local key = canonical_plugin_name(name)
    if key then
      registered_keys[key] = true
    end
  end

  for _, pack in ipairs(installed) do
    local name = pack.spec and pack.spec.name
    local key = canonical_plugin_name(name)
    if key and not registered_keys[key] and not is_packlazy_plugin(pack) then
      table.insert(to_delete, name)
    end
  end

  if #to_delete == 0 then
    errors.notify("no unused plugins to clean", "INFO")
    return
  end

  local ok, err = pcall(vim.pack.del, to_delete)
  if not ok then
    errors.notify("clean failed: " .. tostring(err))
    return
  end

  errors.notify(("deleted %d unused plugin(s)"):format(#to_delete), "INFO")
end

local function set_buf_option(buf, name, value)
  pcall(vim.api.nvim_set_option_value, name, value, { buf = buf })
end

local function open_info_buffer()
  local installed = vim.pack.get(nil, { info = false }) or {}
  local entries_by_key = {}

  local function get_entry(key)
    if not entries_by_key[key] then
      entries_by_key[key] = {
        key = key,
        registered_name = nil,
        installed_name = nil,
        installed = false,
        is_self = false,
      }
    end
    return entries_by_key[key]
  end

  for _, name in ipairs(get_registered_plugin_names()) do
    local key = canonical_plugin_name(name)
    if key then
      get_entry(key).registered_name = name
    end
  end

  for _, pack in ipairs(installed) do
    local name = pack.spec and pack.spec.name
    local key = canonical_plugin_name(name)
    if key then
      local entry = get_entry(key)
      entry.installed = true
      entry.is_self = entry.is_self or is_packlazy_plugin(pack)
      if not entry.installed_name then
        entry.installed_name = name
      elseif entry.installed_name:sub(-5) ~= ".nvim" and name:sub(-5) == ".nvim" then
        entry.installed_name = name
      end
    end
  end

  local entries = vim.tbl_values(entries_by_key)
  table.sort(entries, function(a, b)
    local a_name = (a.installed_name or a.registered_name or a.key):lower()
    local b_name = (b.installed_name or b.registered_name or b.key):lower()
    return a_name < b_name
  end)

  local lines = {
    "packlazy plugin state",
    "",
    "name | registered | installed | load",
    "----------------------------------",
  }

  for _, entry in ipairs(entries) do
    local display_name = entry.installed_name or entry.registered_name or entry.key
    local load_state = "unused"
    if entry.is_self then
      load_state = "loaded"
    elseif entry.registered_name then
      load_state = "unloaded"
      if state.failed[entry.registered_name] then
        load_state = "failed"
      elseif state.loaded[entry.registered_name] then
        load_state = "loaded"
      end
    end

    table.insert(
      lines,
      ("%s | %s | %s | %s"):format(
        display_name,
        entry.registered_name and "yes" or "no",
        entry.installed and "yes" or "no",
        load_state
      )
    )
  end

  if #entries == 0 then
    table.insert(lines, "(no registered or installed plugins)")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  set_buf_option(buf, "bufhidden", "wipe")
  set_buf_option(buf, "buftype", "nofile")
  set_buf_option(buf, "swapfile", false)
  set_buf_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_option(buf, "modifiable", false)
  set_buf_option(buf, "filetype", "packinfo")
end

function M.setup()
  local complete_registered = function(arg_lead)
    return filter_completions(get_registered_plugin_names(), arg_lead)
  end

  create_command("PackInfo", function()
    open_info_buffer()
  end, {
    desc = "Open plugin state buffer",
  })

  create_command("PackUpdate", function(opts)
    update_plugin(opts.args)
  end, {
    nargs = "?",
    desc = "Update all plugins or a specific plugin",
    complete = complete_registered,
  })

  create_command("PackClean", function()
    clean_unused()
  end, {
    desc = "Delete all unused plugins",
  })
end

return M

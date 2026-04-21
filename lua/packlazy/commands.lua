local state = require("packlazy.state")
local errors = require("packlazy.errors")

local M = {}

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

  for _, pack in ipairs(installed) do
    local name = pack.spec and pack.spec.name
    if name and not state.plugins[name] then
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
  local installed_set = {}
  for _, pack in ipairs(installed) do
    local name = pack.spec and pack.spec.name
    if name then
      installed_set[name] = true
    end
  end

  local registered = get_registered_plugin_names()
  local lines = {
    "packlazy plugin state",
    "",
    "name | registered | installed | load",
    "----------------------------------",
  }

  for _, name in ipairs(registered) do
    local load_state = "unloaded"
    if state.failed[name] then
      load_state = "failed"
    elseif state.loaded[name] then
      load_state = "loaded"
    end

    table.insert(lines, ("%s | yes | %s | %s"):format(name, installed_set[name] and "yes" or "no", load_state))
    installed_set[name] = nil
  end

  local unused = vim.tbl_keys(installed_set)
  table.sort(unused, function(a, b)
    return a:lower() < b:lower()
  end)
  for _, name in ipairs(unused) do
    table.insert(lines, ("%s | no | yes | unused"):format(name))
  end

  if #registered == 0 and #unused == 0 then
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

local loader = require("packlazy.loader")
local util = require("packlazy.util")
local errors = require("packlazy.errors")

local M = {}

---@param spec PluginSpec
---@return string[]
local function parse_cmds(spec)
  if type(spec.cmd) == "string" then
    return { spec.cmd }
  end

  if type(spec.cmd) == "function" then
    local cmds = spec.cmd()
    if type(cmds) ~= "table" then
      error("Invalid cmd specification for plugin " .. util.get_plugin_name(spec), 0)
    end
    return cmds
  end

  if type(spec.cmd) == "table" then
    return spec.cmd
  end

  error("Invalid cmd specification for plugin " .. util.get_plugin_name(spec), 0)
end

---@param command_opts vim.api.keyset.create_user_command.command_args
---@return vim.api.keyset.cmd
local function command_opts_to_nvim_cmd(command_opts)
  return {
    cmd = command_opts.name,
    args = command_opts.fargs,
    bang = command_opts.bang,
    range = command_opts.range,
    count = command_opts.count,
    reg = command_opts.reg,
    mods = command_opts.mods,
    smods = command_opts.smods,
  }
end

---@param spec PluginSpec
function M.register(spec)
  if not spec.cmd then
    return
  end

  local cmds = parse_cmds(spec)
  local command_names = {}
  for _, cmd in ipairs(cmds) do
    if type(cmd) ~= "string" then
      error("Invalid cmd specification for plugin " .. util.get_plugin_name(spec), 0)
    end
    table.insert(command_names, cmd)
  end

  for _, cmd in ipairs(command_names) do
    vim.api.nvim_create_user_command(cmd, function(command_opts)
      local ok, err = loader.load(spec)
      if ok == false then
        errors.notify(err)
        return
      end

      for _, registered_cmd in ipairs(command_names) do
        pcall(vim.api.nvim_del_user_command, registered_cmd)
      end

      local replay_ok, replay_err = pcall(vim.api.nvim_cmd, command_opts_to_nvim_cmd(command_opts), {})
      if not replay_ok then
        errors.notify(replay_err)
      end
    end, {
      nargs = "*",
      bang = true,
    })
  end
end

return M

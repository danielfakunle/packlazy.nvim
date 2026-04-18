local M = {}

---@class Config
---@field confirm boolean Whether to ask for confirmation before installing a plugin
---@field lazy boolean Whether to load plugins lazily by default
M.defaults = {
  confirm = true,
  lazy = true,
}

M.setup = function(opts)
  M.defaults = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

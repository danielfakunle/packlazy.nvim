local M = {}

---@param input string | PluginSpec | PluginSpec[]
---@return PluginSpec[] spec_list list of plugin specifications
function M.create_plugin_spec_list(input)
	if type(input) == "string" then
		return { { input } }
	elseif type(input) == "table" and input[1] and type(input[1]) == "string" then
		return { input }
	elseif type(input) == "table" then
		return input
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
		return spec.enabled()
	else
		return spec.enabled
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

return M

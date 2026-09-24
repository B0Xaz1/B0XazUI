--[[
	B0XazUI / init.lua
	====================================================================
	Entry point. This is the ONLY file you load with loadstring(); it
	bootstraps the global namespace and then pulls down the rest of the
	engine from the module tree, in dependency order.

	Executor usage:

		local B0XazUI = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/B0Xaz1/B0XazUI/main/init.lua"
		))()

		local UI = B0XazUI:Load()
		local Window = UI:CreateWindow({ Title = "My UI" })

	Module contract
	--------------------------------------------------------------------
	Every file under Core/ returns a single function:

		return function(UI) ... end

	`UI` is the shared namespace (Theme, Util, Components, Elements...).
	init.lua injects it, so modules never touch globals and load order
	is the only thing that matters. See MODULES below.
	====================================================================
]]

local B0XazUI = {}

B0XazUI.Version = "1.1.0"
B0XazUI.Repo = "B0Xaz1/B0XazUI"
B0XazUI.Branch = "main"
B0XazUI.Loaded = false
B0XazUI.UI = nil
B0XazUI.BaseUrl = nil

-- Ordered manifest. Dependency order matters:
--   Env  ->  Theme  ->  Util  ->  Components  ->  Elements  ->  Library
local MODULES = {
	"Core/Env.lua",
	"Core/Theme.lua",

	"Core/Util/Color.lua",
	"Core/Util/Signal.lua",
	"Core/Util/Tween.lua",
	"Core/Util/Create.lua",
	"Core/Util/Draggable.lua",
	"Core/Util/Layout.lua",
	"Core/Util/Popup.lua",

	"Core/Components/Window.lua",
	"Core/Components/Tab.lua",
	"Core/Components/Section.lua",
	"Core/Components/Notification.lua",

	"Core/Elements/Label.lua",
	"Core/Elements/Button.lua",
	"Core/Elements/Toggle.lua",
	"Core/Elements/Slider.lua",
	"Core/Elements/Dropdown.lua",
	"Core/Elements/Textbox.lua",
	"Core/Elements/Keybind.lua",
	"Core/Elements/ColorPicker.lua",

	"Core/Library.lua",
}

B0XazUI.Modules = MODULES

----------------------------------------------------------------------
-- Bootstrap helpers (kept inline so we can fetch Core/Env.lua itself)
----------------------------------------------------------------------

local function genv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local function bootstrapHttpGet(url)
	-- Preferred: the engine-agnostic method on DataModel.
	if typeof(game) == "Instance" then
		local ok, res = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
	end

	-- Fallback: table-style request functions (Synapse X / Script-Ware /
	-- KRNL / Fluxus / Electron and friends).
	local requestImpls = {
		function()
			return syn and syn.request
		end,
		function()
			return http_request
		end,
		function()
			return request
		end,
		function()
			return fluxus and fluxus.request
		end,
		function()
			return (getgenv and getgenv().request) or nil
		end,
	}

	for i = 1, #requestImpls do
		local ok, fn = pcall(requestImpls[i])
		if ok and typeof(fn) == "function" then
			local ok2, res = pcall(function()
				return fn({ Url = url, Method = "GET" })
			end)
			if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
				return res.Body
			end
		end
	end

	return nil
end

local function compile(source, name)
	if typeof(loadstring) == "function" then
		return loadstring(source, "=" .. name)
	end
	return load(source, "=" .. name)
end

----------------------------------------------------------------------
-- Loader
----------------------------------------------------------------------

--- Fetch + build the engine. Returns the shared UI namespace.
-- @param options table|nil  { Branch, Repo, BaseUrl, Force, Silent }
function B0XazUI:Load(options)
	options = options or {}

	if self.Loaded and not options.Force then
		return self.UI
	end

	local g = genv()
	local branch = options.Branch or g.B0XAZUI_BRANCH or self.Branch
	local repo = options.Repo or g.B0XAZUI_REPO or self.Repo

	self.BaseUrl = options.BaseUrl
		or string.format("https://raw.githubusercontent.com/%s/%s/", repo, branch)

	local silent = options.Silent
	local function log(fmt, ...)
		if not silent then
			print(string.format("[B0XazUI] " .. fmt, ...))
		end
	end

	-- Shared namespace handed to every module.
	local UI = {
		Version = self.Version,
		BaseUrl = self.BaseUrl,

		Util = {},
		Components = {},
		Elements = {},

		Windows = {},
		Notifications = {},
		Connections = {},
		_ThemeBindings = {},
		ScreenGui = nil,
	}

	log("loading %d modules from %s", #self.Modules, self.BaseUrl)

	for i = 1, #self.Modules do
		local path = self.Modules[i]
		local url = self.BaseUrl .. path

		local source = bootstrapHttpGet(url)
		if not source then
			error(string.format(
				"[B0XazUI] Failed to fetch module %q\n  url: %s\n  Make sure the executor can reach raw.githubusercontent.com.",
				path,
				url
			), 0)
		end

		local chunk, compileErr = compile(source, path)
		if not chunk then
			error(string.format("[B0XazUI] Failed to compile module %q: %s", path, tostring(compileErr)), 0)
		end

		local moduleFn = chunk()
		if typeof(moduleFn) ~= "function" then
			error(string.format(
				"[B0XazUI] Module %q must return a function(UI). Got: %s",
				path,
				typeof(moduleFn)
			), 0)
		end

		local ok, err = pcall(moduleFn, UI)
		if not ok then
			error(string.format("[B0XazUI] Module %q threw while loading: %s", path, tostring(err)), 0)
		end
	end

	if typeof(UI.Initialize) ~= "function" then
		error("[B0XazUI] Core/Library.lua did not register UI.Initialize().", 0)
	end

	UI:Initialize()

	self.UI = UI
	self.Loaded = true

	log("ready (v%s)", self.Version)
	return UI
end

--- Returns the already-loaded namespace (or loads it on demand).
function B0XazUI:Get(options)
	if not self.Loaded then
		return self:Load(options)
	end
	return self.UI
end

--- Append extra module paths (your own elements, for example).
function B0XazUI:AddModule(path)
	table.insert(self.Modules, path)
	return self
end

return B0XazUI

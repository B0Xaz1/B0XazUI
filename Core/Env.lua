--[[
	Core/Env.lua
	====================================================================
	Executor environment detection.

	Nothing here is cheat-related: it only answers "where can I safely
	parent a ScreenGui?" and "how do I fetch a file on this executor?",
	with progressive fallbacks so the same build runs on Synapse X,
	Script-Ware, KRNL, Fluxus, Electron, Solara, Wave, plain JJSploit
	and anything else that exposes loadstring + game.

	Nothing is cached at load time other than service lookups, because
	services can be re-created (or cloneref'd) between executions.
	====================================================================
]]

return function(UI)
	local Env = {}

	local _genv
	local function G()
		if _genv then
			return _genv
		end
		if typeof(getgenv) == "function" then
			local ok, g = pcall(getgenv)
			if ok and type(g) == "table" then
				_genv = g
				return _genv
			end
		end
		_genv = _G
		return _genv
	end

	Env.Global = G

	--- Reads a global, optionally walking a path: Env.Get{"syn","request"}
	function Env.Get(path)
		local cur = G()
		if type(path) ~= "table" then
			return cur[path]
		end
		for i = 1, #path do
			if type(cur) ~= "table" then
				return nil
			end
			cur = cur[path[i]]
		end
		return cur
	end

	----------------------------------------------------------------------
	-- Services
	----------------------------------------------------------------------

	local serviceCache = {}

	function Env.Service(name)
		if serviceCache[name] then
			return serviceCache[name]
		end

		local svc
		local ok, res = pcall(function()
			return game:GetService(name)
		end)

		if ok and res then
			svc = res
			-- cloneref defeats trivial hook checks on the service object.
			if typeof(cloneref) == "function" then
				local ok2, cloned = pcall(cloneref, svc)
				if ok2 and cloned then
					svc = cloned
				end
			end
		end

		serviceCache[name] = svc
		return svc
	end

	Env.TweenService = Env.Service("TweenService")
	Env.UserInputService = Env.Service("UserInputService")
	Env.RunService = Env.Service("RunService")
	Env.TextService = Env.Service("TextService")
	Env.HttpService = Env.Service("HttpService")

	function Env.Players()
		return Env.Service("Players")
	end

	function Env.LocalPlayer()
		local players = Env.Players()
		return players and players.LocalPlayer
	end

	function Env.IsStudio()
		local rs = Env.RunService
		return rs and rs:IsStudio() or false
	end

	----------------------------------------------------------------------
	-- HTTP
	----------------------------------------------------------------------

	--- Fetch a URL as a string. Returns nil on failure (never throws).
	function Env.HttpGet(url)
		if typeof(game) == "Instance" then
			local ok, res = pcall(function()
				return game:HttpGet(url)
			end)
			if ok and type(res) == "string" and #res > 0 then
				return res
			end
		end

		local impls = {
			function()
				return Env.Get({ "syn", "request" })
			end,
			function()
				return Env.Get("http_request")
			end,
			function()
				return Env.Get("request")
			end,
			function()
				return Env.Get({ "fluxus", "request" })
			end,
		}

		for i = 1, #impls do
			local ok, fn = pcall(impls[i])
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

	----------------------------------------------------------------------
	-- GUI container
	----------------------------------------------------------------------

	--- Best available parent for our ScreenGui, most-hidden first.
	function Env.GetContainer()
		-- Synapse X / Script-Ware / modern executors.
		if typeof(gethui) == "function" then
			local ok, holder = pcall(gethui)
			if ok and holder then
				return holder
			end
		end

		-- Older Script-Ware.
		if typeof(get_hidden_gui) == "function" then
			local ok, holder = pcall(get_hidden_gui)
			if ok and holder then
				return holder
			end
		end

		-- CoreGui (protected where the executor supports it).
		local ok, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if ok and coreGui then
			local protect = Env.Get({ "syn", "protect_gui" })
			if typeof(protect) == "function" then
				pcall(protect, coreGui)
			end
			return coreGui
		end

		-- Last resort: PlayerGui. Visible to the server, and destroyed on
		-- respawn, but it exists everywhere.
		local lp = Env.LocalPlayer()
		if lp then
			return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
		end

		return nil
	end

	--- Marks a ScreenGui as protected where the executor exposes that.
	function Env.ProtectGui(screenGui)
		local protect = Env.Get({ "syn", "protect_gui" })
		if typeof(protect) == "function" then
			pcall(protect, screenGui)
		end

		-- Some executors expose per-instance protection through a method.
		if typeof(screenGui) == "Instance" then
			local ok = pcall(function()
				return screenGui.IgnoreGuiInset
			end)
			if ok then
				screenGui.IgnoreGuiInset = true
			end
		end

		return screenGui
	end

	----------------------------------------------------------------------
	-- Task helpers (task.* exists on Luau; wait/spawn on legacy envs)
	----------------------------------------------------------------------

	function Env.Wait(duration)
		if type(task) == "table" and typeof(task.wait) == "function" then
			return task.wait(duration)
		end
		if typeof(wait) == "function" then
			return wait(duration)
		end
	end

	function Env.Spawn(fn)
		if type(task) == "table" and typeof(task.spawn) == "function" then
			return task.spawn(fn)
		end
		if typeof(spawn) == "function" then
			return spawn(fn)
		end
		return coroutine.wrap(fn)()
	end

	function Env.Delay(duration, fn)
		if type(task) == "table" and typeof(task.delay) == "function" then
			return task.delay(duration, fn)
		end
		return Env.Spawn(function()
			Env.Wait(duration)
			fn()
		end)
	end

	----------------------------------------------------------------------
	-- Input helpers
	----------------------------------------------------------------------

	--- Current cursor position in screen-space pixels.
	function Env.MouseLocation()
		local uis = Env.UserInputService
		if uis and typeof(uis.GetMouseLocation) == "function" then
			local ok, pos = pcall(function()
				return uis:GetMouseLocation()
			end)
			if ok and typeof(pos) == "Vector2" then
				return pos
			end
		end

		local lp = Env.LocalPlayer()
		if lp then
			local ok, mouse = pcall(function()
				return lp:GetMouse()
			end)
			if ok and mouse then
				return Vector2.new(mouse.X, mouse.Y)
			end
		end

		return Vector2.new(0, 0)
	end

	--- True for mouse-button-1 or touch input (i.e. "the user clicked").
	function Env.IsPrimaryInput(input)
		if not input or not input.UserInputType then
			return false
		end
		local t = input.UserInputType
		return t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.MouseButton2
	end

	--- Human readable name for a KeyCode ("Enum.KeyCode.Q" -> "Q").
	function Env.KeyName(keyCode)
		if keyCode == nil then
			return "None"
		end
		local name = tostring(keyCode)
		name = string.gsub(name, "Enum.KeyCode.", "")
		name = string.gsub(name, "Enum.UserInputType.", "")
		return name
	end

	UI.Env = Env
end

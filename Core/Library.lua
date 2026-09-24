--[[
	Core/Library.lua
	====================================================================
	Assembles the namespace: wires up the shared ScreenGui + overlay,
	exposes the public API, installs the theme registry, and adds the
	Section:Add<Element>() convenience methods once every element module
	has registered itself.

	Everything below hangs off the `UI` table that init.lua injects
	into each module, so there are no globals to collide with.
	====================================================================
]]

return function(UI)
	local Env = UI.Env
	local Theme = UI.Theme
	local Create = UI.Util.Create

	----------------------------------------------------------------------
	-- Theme registry
	----------------------------------------------------------------------

	--- Records "instance[property] should always be Theme[key]".
	function UI:BindTheme(instance, property, key)
		if typeof(instance) ~= "Instance" then
			return
		end
		table.insert(self._ThemeBindings, {
			Instance = instance,
			Property = property,
			Key = key,
		})
		instance[property] = Theme[key]
	end

	--- Re-point an existing binding at a different theme key.
	function UI:RebindTheme(instance, property, key)
		for i = 1, #self._ThemeBindings do
			local binding = self._ThemeBindings[i]
			if binding.Instance == instance and binding.Property == property then
				binding.Key = key
				instance[property] = Theme[key]
				return
			end
		end
		self:BindTheme(instance, property, key)
	end

	--- Drops bindings for an instance and everything below it.
	function UI:UnbindTheme(instance)
		for i = #self._ThemeBindings, 1, -1 do
			local binding = self._ThemeBindings[i]
			if binding.Instance == instance or (function()
				local ok, descendant = pcall(function()
					return binding.Instance:IsDescendantOf(instance)
				end)
				return ok and descendant
			end)() then
				table.remove(self._ThemeBindings, i)
			end
		end
	end

	--- Repaints every live element from the (possibly edited) theme.
	function UI:RefreshTheme()
		for i = #self._ThemeBindings, 1, -1 do
			local binding = self._ThemeBindings[i]
			if typeof(binding.Instance) == "Instance" then
				pcall(function()
					binding.Instance[binding.Property] = Theme[binding.Key]
				end)
			else
				table.remove(self._ThemeBindings, i)
			end
		end
	end

	--- Merge overrides into the palette and repaint.
	function UI:SetTheme(overrides)
		if type(overrides) ~= "table" then
			return
		end
		for key, value in pairs(overrides) do
			Theme[key] = value
		end
		self:RefreshTheme()
	end

	----------------------------------------------------------------------
	-- Shared instances
	----------------------------------------------------------------------

	--- The one ScreenGui every window lives in.
	function UI:GetScreenGui()
		if self.ScreenGui and self.ScreenGui.Parent then
			return self.ScreenGui
		end

		local container = Env.GetContainer()
		if not container then
			error("[B0XazUI] Could not resolve a GUI container (CoreGui/PlayerGui unavailable).", 0)
		end

		local screenGui = Create("ScreenGui", {
			Name = "B0XazUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 100,
			Parent = container,
		})

		Env.ProtectGui(screenGui)

		self.ScreenGui = screenGui
		self.Overlay = nil
		return screenGui
	end

	--- Full-screen, non-clipping layer for popups.
	function UI:GetOverlay()
		if self.Overlay and self.Overlay.Parent then
			return self.Overlay
		end

		local overlay = Create("Frame", {
			Name = "Overlay",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			ZIndex = 150,
			Parent = self:GetScreenGui(),
		})

		self.Overlay = overlay
		return overlay
	end

	----------------------------------------------------------------------
	-- Public constructors
	----------------------------------------------------------------------

	function UI:CreateWindow(config)
		return UI.Components.Window.New(config)
	end

	UI.Window = UI.CreateWindow

	----------------------------------------------------------------------
	-- Introspection
	----------------------------------------------------------------------

	function UI:ListElements()
		local names = {}
		for key in pairs(UI.Elements) do
			table.insert(names, key)
		end
		table.sort(names)
		return names
	end

	function UI:ListComponents()
		local names = {}
		for key in pairs(UI.Components) do
			table.insert(names, key)
		end
		table.sort(names)
		return names
	end

	----------------------------------------------------------------------
	-- Teardown
	----------------------------------------------------------------------

	function UI:Destroy()
		for i = #UI.Windows, 1, -1 do
			UI.Windows[i]:Destroy()
		end

		UI:ClearNotifications()

		for i = #UI.Connections, 1, -1 do
			pcall(function()
				UI.Connections[i]:Disconnect()
			end)
			UI.Connections[i] = nil
		end

		self._ThemeBindings = {}

		if self.ScreenGui then
			self.ScreenGui:Destroy()
			self.ScreenGui = nil
			self.Overlay = nil
		end

		if Env.Global then
			Env.Global().B0XazUI_UI = nil
		end
	end

	----------------------------------------------------------------------
	-- Initialize (called by init.lua after every module is loaded)
	----------------------------------------------------------------------

	function UI:Initialize()
		-- Notifications + popup dismissal are namespace-level services.
		UI.Components.Notification.Install(self)
		UI.Util.Popup.InstallOutsideClick()

		-- Section:AddToggle(...) etc. for every registered element.
		local Section = UI.Components.Section
		for elementName, element in pairs(UI.Elements) do
			local methodName = "Add" .. elementName
			if not Section[methodName] then
				Section[methodName] = function(section, config)
					return element.New(section, config or {})
				end
			end
		end

		-- Element aliases that read better at the call site.
		if not Section.Label then
			function Section:Label(config)
				return UI.Elements.Label.New(self, config or {})
			end
		end

		-- Expose the live namespace for debugging / external modules.
		if Env.Global then
			Env.Global().B0XazUI_UI = self
		end

		self.NotificationCorner = "BottomRight"
	end
end

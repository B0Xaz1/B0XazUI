--[[
	Core/Components/Window.lua
	====================================================================
	The window shell:

		+------------------------------+---------+
		| Title            [ - ] [ x ] | topbar  |  draggable
		+------------------------------+---------+
		|  Main   Visuals   Settings   | tabbar  |  horizontal tabs
		+------------------------------+---------+
		|                              |         |
		|   ( active tab page )        | content |  per-tab scroll page
		|                              |         |
		+------------------------------+---------+

	One ScreenGui is shared by every window; each window is a Frame
	inside it, so Z-index and input behave predictably.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Draggable = UI.Util.Draggable
	local Layout = UI.Util.Layout
	local Env = UI.Env

	local Window = {}
	Window.__index = Window

	local function viewportSize()
		local ok, camera = pcall(function()
			return workspace.CurrentCamera
		end)
		if ok and camera then
			local ok2, size = pcall(function()
				return camera.ViewportSize
			end)
			if ok2 and typeof(size) == "Vector2" and size.X > 0 then
				return size
			end
		end
		return Vector2.new(1280, 720)
	end

	--- Creates a window and registers it on the namespace.
	function Window.New(config)
		config = config or {}

		local self = setmetatable({}, Window)

		self.UI = UI
		self.Config = config
		self.Tabs = {}
		self.ActiveTab = nil
		self.Minimized = false
		self.Visible = true
		self.Bin = UI.Util.Bin.new()
		self.Connections = {}

		local size = config.Size or Vector2.new(640, 460)
		self.Size = size

		local screenGui = UI:GetScreenGui()

		------------------------------------------------------------------
		-- Root
		------------------------------------------------------------------
		local Root = Create("Frame", {
			Name = "Window",
			BackgroundColor3 = Theme.Background,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(0, size.X, 0, size.Y),
			Position = config.Position or UDim2.new(0, 0, 0, 0),
			ZIndex = 1,
			Parent = screenGui,
		})

		Create.Corner(Theme.CornerRadius, Root)
		local stroke = Create.Stroke(Theme.Stroke, 1, Root)

		self.Root = Root
		UI:BindTheme(Root, "BackgroundColor3", "Background")
		UI:BindTheme(stroke, "Color", "Stroke")

		-- Default position: dead centre of the viewport.
		if not config.Position then
			local viewport = viewportSize()
			Root.Position = UDim2.new(
				0,
				math.floor((viewport.X - size.X) / 2),
				0,
				math.floor((viewport.Y - size.Y) / 2)
			)
		end

		------------------------------------------------------------------
		-- Topbar
		------------------------------------------------------------------
		local Topbar = Create("Frame", {
			Name = "Topbar",
			BackgroundColor3 = Theme.Topbar,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.TopbarHeight),
			Position = UDim2.new(0, 0, 0, 0),
			ZIndex = 2,
			Parent = Root,
		})
		UI:BindTheme(Topbar, "BackgroundColor3", "Topbar")

		local topbarLine = Create("Frame", {
			Name = "Divider",
			BackgroundColor3 = Theme.Divider,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			ZIndex = 2,
			Parent = Topbar,
		})
		UI:BindTheme(topbarLine, "BackgroundColor3", "Divider")

		-- Title + subtitle, auto-sized horizontally.
		local TitleArea = Create("Frame", {
			Name = "TitleArea",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			ZIndex = 2,
			Parent = Topbar,
		})
		Create.Row(6, TitleArea)

		self.TitleLabel = Create.Label({
			Name = "Title",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = config.Title or "B0XazUI",
			Font = Theme.FontSemibold,
			TextSize = Theme.TitleTextSize,
			TextColor3 = Theme.Text,
			ZIndex = 3,
			Parent = TitleArea,
		})
		UI:BindTheme(self.TitleLabel, "TextColor3", "Text")

		self.SubTitleLabel = Create.Label({
			Name = "SubTitle",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = config.SubTitle or (config.Subtitle or ""),
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.TextDim,
			ZIndex = 3,
			Parent = TitleArea,
		})
		UI:BindTheme(self.SubTitleLabel, "TextColor3", "TextDim")

		-- Window control buttons.
		local Controls = Create("Frame", {
			Name = "Controls",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 24),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			ZIndex = 3,
			Parent = Topbar,
		})
		Create.Row(6, Controls)

		self.MinimizeButton = self:_controlButton(Controls, "Minimize", Theme.Icons.Minimize, function()
			self:SetMinimized(not self.Minimized)
		end)

		self.CloseButton = self:_controlButton(Controls, "Close", Theme.Icons.Close, function()
			if typeof(config.OnClose) == "function" then
				local keepOpen = config.OnClose()
				if keepOpen == true then
					self:SetVisible(false)
					return
				end
			end

			if config.CloseDestroys == false then
				self:SetVisible(false)
			else
				self:Destroy()
			end
		end)

		------------------------------------------------------------------
		-- Tab bar
		------------------------------------------------------------------
		local TabBar = Create("Frame", {
			Name = "TabBar",
			BackgroundColor3 = Theme.TabBar,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.TabBarHeight),
			Position = UDim2.new(0, 0, 0, Theme.TopbarHeight),
			ZIndex = 2,
			Parent = Root,
		})
		UI:BindTheme(TabBar, "BackgroundColor3", "TabBar")

		local tabBarLine = Create("Frame", {
			Name = "Divider",
			BackgroundColor3 = Theme.Divider,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			ZIndex = 2,
			Parent = TabBar,
		})
		UI:BindTheme(tabBarLine, "BackgroundColor3", "Divider")

		local TabScroll = Create("ScrollingFrame", {
			Name = "TabScroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 0,
			ScrollBarImageColor3 = Theme.Scrollbar,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ZIndex = 2,
			Parent = TabBar,
		})
		Create.Padding(0, 8, 0, 0, TabScroll)

		local tabLayout = Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
			Parent = TabScroll,
		})
		Layout.BindCanvasSizeHorizontal(TabScroll, tabLayout, 16, self.Bin)

		------------------------------------------------------------------
		-- Content area
		------------------------------------------------------------------
		local Content = Create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -(Theme.TopbarHeight + Theme.TabBarHeight)),
			Position = UDim2.new(0, 0, 0, Theme.TopbarHeight + Theme.TabBarHeight),
			ZIndex = 1,
			Parent = Root,
		})

		self.Topbar = Topbar
		self.TabBar = TabBar
		self.TabScroll = TabScroll
		self.Content = Content
		self.TabLayout = tabLayout

		------------------------------------------------------------------
		-- Behaviour
		------------------------------------------------------------------
		if config.Draggable ~= false then
			self.Dragger = Draggable.new(Topbar, Root, {
				Enabled = true,
				Margin = config.Margin or 6,
			})
			self.Bin:Add(self.Dragger)
		end

		-- Toggle the whole window with a keybind.
		self.ToggleKey = config.ToggleKey
		if self.ToggleKey and Env.UserInputService then
			self.Bin:Add(Env.UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then
					return
				end
				if input.KeyCode == self.ToggleKey then
					self:Toggle()
				end
			end))
		end

		table.insert(UI.Windows, self)
		return self
	end

	Window.new = Window.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	--- Window chrome button. `icon` is an emoji (see Theme.Icons): Roblox's
	-- UI font has no glyph for the plain text symbols these used to use, so
	-- they came back as empty boxes. Emoji draw in colour and ignore
	-- TextColor3, so the button background carries the state instead.
	function Window:_controlButton(parent, name, icon, onClick)
		local button = Create.Button({
			Name = name,
			Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = Theme.Element,
			Text = icon,
			TextSize = 12,
			ZIndex = 4,
			Parent = parent,
		})
		Create.Corner(6, button)
		UI:BindTheme(button, "BackgroundColor3", "Element")

		table.insert(self.Connections, button.MouseEnter:Connect(function()
			Tween.Fast(button, { BackgroundColor3 = Theme.ElementHover })
		end))
		table.insert(self.Connections, button.MouseLeave:Connect(function()
			Tween.Fast(button, { BackgroundColor3 = Theme.Element })
		end))
		table.insert(self.Connections, button.MouseButton1Click:Connect(onClick))

		return button
	end

	----------------------------------------------------------------------
	-- Tabs
	----------------------------------------------------------------------

	function Window:AddTab(name, config)
		config = config or {}
		config.Name = name or config.Name or "Tab"

		local tab = UI.Components.Tab.New(self, config)
		table.insert(self.Tabs, tab)

		if not self.ActiveTab then
			self:SelectTab(tab)
		end

		return tab
	end

	--- Accepts a Tab object or a tab name.
	function Window:SelectTab(tab)
		if type(tab) == "string" then
			local found
			for i = 1, #self.Tabs do
				if self.Tabs[i].Name == tab then
					found = self.Tabs[i]
					break
				end
			end
			tab = found
		end

		if typeof(tab) ~= "table" then
			return
		end

		self.ActiveTab = tab

		for i = 1, #self.Tabs do
			self.Tabs[i]:SetActive(self.Tabs[i] == tab)
		end

		if self.OnTabChanged then
			self.OnTabChanged(tab)
		end
	end

	function Window:GetTab(name)
		for i = 1, #self.Tabs do
			if self.Tabs[i].Name == name then
				return self.Tabs[i]
			end
		end
		return nil
	end

	----------------------------------------------------------------------
	-- Appearance / state
	----------------------------------------------------------------------

	function Window:SetTitle(title, subtitle)
		self.TitleLabel.Text = tostring(title or "")
		if subtitle ~= nil then
			self.SubTitleLabel.Text = tostring(subtitle)
		end
	end

	function Window:SetSize(width, height)
		self.Size = Vector2.new(width, height)
		if not self.Minimized then
			Tween.Fast(self.Root, { Size = UDim2.new(0, width, 0, height) })
		end
	end

	--- Collapses the window down to just its topbar.
	function Window:SetMinimized(state)
		state = state and true or false
		if self.Minimized == state then
			return
		end
		self.Minimized = state

		self.MinimizeButton.Text = state and Theme.Icons.Restore or Theme.Icons.Minimize

		if state then
			Tween.Fast(self.Root, { Size = UDim2.new(0, self.Size.X, 0, Theme.TopbarHeight) }, function()
				if self.Minimized then
					self.TabBar.Visible = false
					self.Content.Visible = false
				end
			end)
		else
			self.TabBar.Visible = true
			self.Content.Visible = true
			Tween.Fast(self.Root, { Size = UDim2.new(0, self.Size.X, 0, self.Size.Y) })
		end
	end

	function Window:SetVisible(visible)
		self.Visible = visible and true or false
		self.Root.Visible = self.Visible
	end

	function Window:Toggle()
		self:SetVisible(not self.Visible)
	end

	function Window:IsVisible()
		return self.Visible
	end

	function Window:Center()
		local viewport = viewportSize()
		self.Root.Position = UDim2.new(
			0,
			math.floor((viewport.X - self.Root.AbsoluteSize.X) / 2),
			0,
			math.floor((viewport.Y - self.Root.AbsoluteSize.Y) / 2)
		)
	end

	--- Convenience passthrough to the notification system.
	function Window:Notify(options)
		options = options or {}
		options.Window = self
		return UI:Notify(options)
	end

	----------------------------------------------------------------------
	-- Teardown
	----------------------------------------------------------------------

	function Window:Destroy()
		for i = #self.Tabs, 1, -1 do
			self.Tabs[i]:Destroy()
		end
		self.Tabs = {}

		for i = #self.Connections, 1, -1 do
			pcall(function()
				self.Connections[i]:Disconnect()
			end)
		end
		self.Connections = {}

		self.Bin:Clean()
		UI:UnbindTheme(self.Root)

		if self.Root then
			self.Root:Destroy()
			self.Root = nil
		end

		for i = #UI.Windows, 1, -1 do
			if UI.Windows[i] == self then
				table.remove(UI.Windows, i)
				break
			end
		end
	end

	UI.Components.Window = Window
end

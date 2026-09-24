--[[
	Core/Components/Window.lua
	====================================================================
	The window shell, in the "Abyss" style:

		+-------------------------------------------------------------+
		| title | subtitle                                     -   x  |  24px title strip
		+-------------------------------------------------------------+
		|  [ main ]   rage                                            |  26px boxed tabs
		+-------------------------------------------------------------+
		|                                                             |
		|   ( active tab page )                                       |
		|                                                             |
		|  _________________________________________________________  |  accent glow
		|  =========================================================  |  2px accent strip
		+-------------------------------------------------------------+

	One ScreenGui is shared by every window; each window is a Frame
	inside it, so Z-index and input behave predictably.

	Everything is square: a one-pixel UIStroke does the bordering.
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

		local size = config.Size or Vector2.new(600, 480)
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

		if Theme.CornerRadius > 0 then
			Create.Corner(Theme.CornerRadius, Root)
		end
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
		-- Topbar: the title strip
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
			Position = UDim2.new(0, 0, 1, 0),
			ZIndex = 2,
			Parent = Topbar,
		})
		UI:BindTheme(topbarLine, "BackgroundColor3", "Divider")

		-- "title  |  subtitle" sits flush left, tiny and dim.
		local TitleArea = Create("Frame", {
			Name = "TitleArea",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			ZIndex = 2,
			Parent = Topbar,
		})
		Create.Row(4, TitleArea)

		self.TitleLabel = Create.Label({
			Name = "Title",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = config.Title or "B0XazUI",
			Font = Theme.Font,
			TextSize = Theme.TitleTextSize,
			TextColor3 = Theme.TextDim,
			ZIndex = 3,
			Parent = TitleArea,
		})
		UI:BindTheme(self.TitleLabel, "TextColor3", "TextDim")

		local subTitle = config.SubTitle or config.Subtitle or ""
		self.SubTitleLabel = Create.Label({
			Name = "SubTitle",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = subTitle ~= "" and ("|  " .. tostring(subTitle)) or "",
			Visible = subTitle ~= "",
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.TextFaint,
			ZIndex = 3,
			Parent = TitleArea,
		})
		UI:BindTheme(self.SubTitleLabel, "TextColor3", "TextFaint")

		-- Window controls: bare text glyphs, nothing more.
		local Controls = Create("Frame", {
			Name = "Controls",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 14),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			ZIndex = 3,
			Parent = Topbar,
		})
		Create.Row(10, Controls)

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
			Position = UDim2.new(0, 0, 1, 0),
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
		Create.Padding(8, 8, 0, 0, TabScroll)

		local tabLayout = Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
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

		-- The blurple strip along the bottom edge of the window, with a
		-- faint glow fading up from it. A quiet but defining detail of
		-- the original design.
		local Glow = Create("Frame", {
			Name = "AccentGlow",
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.AccentGlowHeight),
			Position = UDim2.new(0, 0, 1, -(Theme.AccentGlowHeight + Theme.AccentStripHeight)),
			ZIndex = 3,
			Parent = Content,
		})
		Create.New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.55),
			}),
			Parent = Glow,
		})
		UI:BindTheme(Glow, "BackgroundColor3", "Accent")

		local Strip = Create("Frame", {
			Name = "AccentStrip",
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.AccentStripHeight),
			Position = UDim2.new(0, 0, 1, -Theme.AccentStripHeight),
			ZIndex = 3,
			Parent = Content,
		})
		UI:BindTheme(Strip, "BackgroundColor3", "Accent")

		self.Topbar = Topbar
		self.TabBar = TabBar
		self.TabScroll = TabScroll
		self.Content = Content
		self.TabLayout = tabLayout
		self.AccentStrip = Strip
		self.AccentGlow = Glow

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

	--- Window chrome button: a bare text glyph ("-" / "x") that lights
	-- up on hover. No background, no box -- that is the original's way.
	function Window:_controlButton(parent, name, icon, onClick)
		local button = Create.Button({
			Name = name,
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundTransparency = 1,
			Text = icon,
			Font = Theme.Font,
			TextSize = Theme.TitleTextSize,
			TextColor3 = Theme.TextFaint,
			ZIndex = 4,
			Parent = parent,
		})
		UI:BindTheme(button, "TextColor3", "TextFaint")

		table.insert(self.Connections, button.MouseEnter:Connect(function()
			Tween.Fast(button, { TextColor3 = Theme.Text })
		end))
		table.insert(self.Connections, button.MouseLeave:Connect(function()
			Tween.Fast(button, { TextColor3 = Theme.TextFaint })
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
			local text = tostring(subtitle)
			self.SubTitleLabel.Text = text ~= "" and ("|  " .. text) or ""
			self.SubTitleLabel.Visible = text ~= ""
		end
	end

	function Window:SetSize(width, height)
		self.Size = Vector2.new(width, height)
		if not self.Minimized then
			Tween.Fast(self.Root, { Size = UDim2.new(0, width, 0, height) })
		end
	end

	--- Collapses the window down to just its title strip.
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

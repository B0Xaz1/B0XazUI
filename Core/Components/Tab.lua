--[[
	Core/Components/Tab.lua
	====================================================================
	A tab owns:
	  * a button in the window's horizontal tab bar
	  * a scrolling page inside the window's content area

	Pages are created eagerly and toggled with .Visible, which keeps
	scroll position per tab between switches.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Layout = UI.Util.Layout

	local Tab = {}
	Tab.__index = Tab

	function Tab.New(window, config)
		config = config or {}

		local self = setmetatable({}, Tab)

		self.UI = UI
		self.Window = window
		self.Name = config.Name or "Tab"
		self.Sections = {}
		self.Active = false
		self.Bin = UI.Util.Bin.new()

		local pageLayout

		------------------------------------------------------------------
		-- Tab button (lives in the window tab bar)
		------------------------------------------------------------------
		local textWidth = Layout.GetTextBounds(self.Name, Theme.FontMedium, Theme.TextSize).X
		local buttonWidth = math.max(72, math.ceil(textWidth + 28))

		local Button = Create.Button({
			Name = self.Name,
			LayoutOrder = #window.Tabs + 1,
			BackgroundColor3 = Theme.TabBar,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, buttonWidth, 1, 0),
			Text = "",
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			ZIndex = 3,
			Parent = window.TabScroll,
		})

		local ButtonLabel = Create.Label({
			Name = "Label",
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = self.Name,
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = Button,
		})

		local Underline = Create("Frame", {
			Name = "Underline",
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, buttonWidth - 24, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -2),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = Button,
		})
		Create.Corner(2, Underline)

		------------------------------------------------------------------
		-- Page (lives in the window content area)
		------------------------------------------------------------------
		local Page = Create("ScrollingFrame", {
			Name = self.Name .. "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Scrollbar,
			ScrollBarImageTransparency = 0.4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 1,
			Parent = window.Content,
		})
		Create.Padding(Theme.SectionPadding, Theme.SectionPadding + 4, Theme.SectionPadding, Theme.SectionPadding, Page)

		pageLayout = Create.List(Theme.SectionSpacing, Page)
		self.UpdateCanvas = Layout.BindCanvasSize(Page, pageLayout, Theme.SectionPadding, self.Bin)

		self.Button = Button
		self.ButtonLabel = ButtonLabel
		self.Underline = Underline
		self.Page = Page
		self.PageLayout = pageLayout

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Button.MouseButton1Click:Connect(function()
			window:SelectTab(self)
		end))

		self.Bin:Add(Button.MouseEnter:Connect(function()
			if self.Active then
				return
			end
			Tween.Fast(Button, { BackgroundColor3 = Theme.TabHover })
			Tween.Fast(ButtonLabel, { TextColor3 = Theme.Text })
		end))

		self.Bin:Add(Button.MouseLeave:Connect(function()
			if self.Active then
				return
			end
			Tween.Fast(Button, { BackgroundColor3 = Theme.TabBar })
			Tween.Fast(ButtonLabel, { TextColor3 = Theme.TextDim })
		end))

		self:SetActive(false)
		return self
	end

	Tab.new = Tab.New

	----------------------------------------------------------------------
	-- Sections
	----------------------------------------------------------------------

	function Tab:AddSection(title, config)
		config = config or {}
		config.Title = title or config.Title or "Section"

		local section = UI.Components.Section.New(self, config)
		table.insert(self.Sections, section)
		return section
	end

	function Tab:GetSection(title)
		for i = 1, #self.Sections do
			if self.Sections[i].Title == title then
				return self.Sections[i]
			end
		end
		return nil
	end

	----------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------

	function Tab:SetActive(active)
		self.Active = active and true or false
		self.Page.Visible = self.Active

		if self.Active then
			Tween.Fast(self.Button, { BackgroundColor3 = Theme.TabActive })
			Tween.Fast(self.ButtonLabel, { TextColor3 = Theme.Text })
			Tween.Fast(self.Underline, { BackgroundTransparency = 0 })
		else
			Tween.Fast(self.Button, { BackgroundColor3 = Theme.TabBar })
			Tween.Fast(self.ButtonLabel, { TextColor3 = Theme.TextDim })
			Tween.Fast(self.Underline, { BackgroundTransparency = 1 })
		end
	end

	function Tab:SetName(name)
		self.Name = tostring(name or "Tab")
		self.Button.Name = self.Name
		self.ButtonLabel.Text = self.Name
		self.Page.Name = self.Name .. "Page"

		local textWidth = Layout.GetTextBounds(self.Name, Theme.FontMedium, Theme.TextSize).X
		self.Button.Size = UDim2.new(0, math.max(72, math.ceil(textWidth + 28)), 1, 0)
		self.Underline.Size = UDim2.new(0, math.max(72, math.ceil(textWidth + 28)) - 24, 0, 2)
	end

	function Tab:Clear()
		for i = #self.Sections, 1, -1 do
			self.Sections[i]:Destroy()
		end
		self.Sections = {}
	end

	function Tab:Destroy()
		for i = #self.Sections, 1, -1 do
			self.Sections[i]:Destroy()
		end
		self.Sections = {}

		self.Bin:Clean()

		local window = self.Window
		if window then
			for i = #window.Tabs, 1, -1 do
				if window.Tabs[i] == self then
					table.remove(window.Tabs, i)
					break
				end
			end

			if window.ActiveTab == self then
				window.ActiveTab = nil
				if #window.Tabs > 0 then
					window:SelectTab(window.Tabs[1])
				end
			end
		end

		self.Button:Destroy()
		self.Page:Destroy()
	end

	UI.Components.Tab = Tab
end

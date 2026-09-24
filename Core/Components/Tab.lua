--[[
	Core/Components/Tab.lua
	====================================================================
	A tab owns:
	  * a button in the window's horizontal tab bar -- a flat box that
	    gets its outline only while selected
	  * a scrolling page inside the window's content area

	Pages hold N columns side by side (the original design uses two);
	sections choose a column with AddSection(title, { Column = n }).
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

	local function tabButtonWidth(name)
		local textWidth = Layout.GetTextBounds(name, Theme.Font, Theme.TextSize).X
		return math.ceil(textWidth + Theme.TabPadding * 2)
	end

	function Tab.New(window, config)
		config = config or {}

		local self = setmetatable({}, Tab)

		self.UI = UI
		self.Window = window
		self.Name = config.Name or "Tab"
		self.Sections = {}
		self.Active = false
		self.Bin = UI.Util.Bin.new()

		-- Two columns is the look the engine was designed around, but a
		-- tab can ask for any count (1 gives the classic stacked layout).
		local columnCount = tonumber(config.Columns) or 2
		columnCount = math.max(1, math.floor(columnCount))
		self.ColumnCount = columnCount

		------------------------------------------------------------------
		-- Tab button (lives in the window tab bar)
		------------------------------------------------------------------
		local buttonWidth = tabButtonWidth(self.Name)

		local Button = Create.Button({
			Name = self.Name,
			LayoutOrder = #window.Tabs + 1,
			BackgroundColor3 = Theme.TabBar,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, buttonWidth, 0, Theme.TabBarHeight - 10),
			Text = self.Name,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextFaint,
			ZIndex = 3,
			Parent = window.TabScroll,
		})

		-- The active tab earns its outline; nobody else draws one.
		local Outline = Create.Stroke(Theme.StrokeSoft, 1, Button, 1)

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
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Scrollbar,
			ScrollBarImageTransparency = 0.4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 1,
			Parent = window.Content,
		})
		Create.Padding(Theme.ContentPadding, Theme.ContentPadding, Theme.ContentPadding, Theme.ContentPadding, Page)

		-- A row frame whose only job is to hold the columns side by side.
		local Row = Create("Frame", {
			Name = "Columns",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			ZIndex = 1,
			Parent = Page,
		})

		local rowLayout = Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.ColumnSpacing),
			Parent = Row,
		})

		self.UpdateCanvas = Layout.BindCanvasSize(Page, rowLayout, Theme.ContentPadding * 2, self.Bin)

		local columns = {}
		local spacingShare = (Theme.ColumnSpacing * (columnCount - 1)) / columnCount
		for i = 1, columnCount do
			local column = Create("Frame", {
				Name = "Column" .. tostring(i),
				LayoutOrder = i,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1 / columnCount, -spacingShare, 0, 0),
				ZIndex = 1,
				Parent = Row,
			})
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.SectionSpacing),
				Parent = column,
			})
			columns[i] = column
		end

		self.Button = Button
		self.ButtonOutline = Outline
		self.Page = Page
		self.Row = Row
		self.Columns = columns

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
			Tween.Fast(Button, { BackgroundColor3 = Theme.TabHover, BackgroundTransparency = 0 })
			Tween.Fast(Button, { TextColor3 = Theme.TextDim })
		end))

		self.Bin:Add(Button.MouseLeave:Connect(function()
			if self.Active then
				return
			end
			Tween.Fast(Button, { BackgroundColor3 = Theme.TabBar, BackgroundTransparency = 1 })
			Tween.Fast(Button, { TextColor3 = Theme.TextFaint })
		end))

		self:SetActive(false)
		return self
	end

	Tab.new = Tab.New

	----------------------------------------------------------------------
	-- Sections
	----------------------------------------------------------------------

	--- config.Column picks the column (1-based, left to right).
	function Tab:AddSection(title, config)
		config = config or {}
		config.Title = title or config.Title or "Section"

		local column = tonumber(config.Column) or 1
		column = math.max(1, math.min(self.ColumnCount, math.floor(column)))
		config.Column = column

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

	function Tab:GetColumn(index)
		return self.Columns[index]
	end

	----------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------

	function Tab:SetActive(active)
		self.Active = active and true or false
		self.Page.Visible = self.Active

		if self.Active then
			Tween.Fast(self.Button, {
				BackgroundColor3 = Theme.TabActive,
				BackgroundTransparency = 0,
				TextColor3 = Theme.Text,
			})
			Tween.Fast(self.ButtonOutline, { Transparency = 0 })
		else
			Tween.Fast(self.Button, {
				BackgroundColor3 = Theme.TabBar,
				BackgroundTransparency = 1,
				TextColor3 = Theme.TextFaint,
			})
			Tween.Fast(self.ButtonOutline, { Transparency = 1 })
		end
	end

	function Tab:SetName(name)
		self.Name = tostring(name or "Tab")
		self.Button.Name = self.Name
		self.Button.Text = self.Name
		self.Page.Name = self.Name .. "Page"
		self.Button.Size = UDim2.new(0, tabButtonWidth(self.Name), 0, Theme.TabBarHeight - 10)
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

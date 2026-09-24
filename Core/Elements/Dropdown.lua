--[[
	Core/Elements/Dropdown.lua
	====================================================================
	Select (or multi-select) list that expands inline below its header,
	so nothing is clipped by the page's scrolling frame.

		Section:AddDropdown({
			Name     = "Mode",
			Options  = { "Fast", "Balanced", "Precise" },
			Default  = "Balanced",
			Multi    = false,
			Callback = function(value) end,
		})

	Options may be plain strings/numbers, or tables of the form
	{ Text = "Fast", Value = 1 } when you want a display name that
	differs from the value handed to the callback.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween

	local Dropdown = {}
	Dropdown.__index = Dropdown

	local OPTION_HEIGHT = 24

	--- Normalises an option entry into { Text, Value }.
	local function normalise(option, index)
		if type(option) == "table" then
			return {
				Text = tostring(option.Text or option.Name or option.Value or ""),
				Value = option.Value ~= nil and option.Value or option.Text,
			}
		end
		return { Text = tostring(option), Value = option, Index = index }
	end

	function Dropdown.New(section, config)
		config = config or {}

		local self = setmetatable({}, Dropdown)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Dropdown"
		self.Type = "Dropdown"
		self.Multi = config.Multi == true
		self.Callback = config.Callback
		self.Options = {}
		self.Open = false
		self.Bin = UI.Util.Bin.new()
		self.Changed = UI.Util.Signal.new()
		self.OptionButtons = {}

		self.MaxVisible = config.MaxVisible or 6

		if self.Multi then
			self.Value = {}
			if type(config.Default) == "table" then
				for i = 1, #config.Default do
					self.Value[tostring(config.Default[i])] = true
				end
			end
		else
			self.Value = config.Default
		end

		------------------------------------------------------------------
		-- Layout
		------------------------------------------------------------------
		local Frame = Create("Frame", {
			Name = self.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 1,
		})

		local Column = Create.List(4, Frame)

		local Header = Create.Button({
			Name = "Header",
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.ElementHeight),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Corner(Theme.ElementCornerRadius, Header)
		UI:BindTheme(Header, "BackgroundColor3", "Element")

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -80, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Text = self.Name,
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			ZIndex = 3,
			Parent = Header,
		})
		UI:BindTheme(TextLabel, "TextColor3", "Text")

		local Chevron = Create.Label({
			Name = "Chevron",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 18, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Text = Theme.Icons.Down,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = Header,
		})

		local ValueLabel = Create.Label({
			Name = "Value",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 46, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -28, 0, 0),
			Text = "",
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = Header,
		})

		------------------------------------------------------------------
		-- Option list (inline, collapsible)
		------------------------------------------------------------------
		local List = Create("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Scrollbar,
			ScrollBarImageTransparency = 0.5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 2,
			Parent = Frame,
		})

		local listLayout = Create.List(2, List)
		Create.Padding(4, 4, 4, 4, List)

		self.Frame = Frame
		self.Header = Header
		self.TextLabel = TextLabel
		self.ValueLabel = ValueLabel
		self.Chevron = Chevron
		self.List = List
		self.ListLayout = listLayout

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Header.MouseEnter:Connect(function()
			Tween.Fast(Header, { BackgroundColor3 = Theme.ElementHover })
		end))

		self.Bin:Add(Header.MouseLeave:Connect(function()
			Tween.Fast(Header, { BackgroundColor3 = Theme.Element })
		end))

		self.Bin:Add(Header.MouseButton1Click:Connect(function()
			self:SetOpen(not self.Open)
		end))

		self.RefreshList = self:_makeRefresher()

		self:SetOptions(config.Options or {}, true)
		self:_paintDisplay()

		section:AddElement(Frame, self)
		return self
	end

	Dropdown.new = Dropdown.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Dropdown:_makeRefresher()
		local function refresh(animate)
			if typeof(self.ListLayout) ~= "Instance" then
				return
			end

			local ok, content = pcall(function()
				return self.ListLayout.AbsoluteContentSize
			end)
			content = (ok and typeof(content) == "Vector2") and content.Y or 0

			local maxHeight = self.MaxVisible * OPTION_HEIGHT + 8
			local height = math.min(content, maxHeight)

			self.List.CanvasSize = UDim2.new(0, 0, 0, content)

			if not self.Open then
				self.List.Size = UDim2.new(1, 0, 0, 0)
				return
			end

			if animate then
				Tween.Play(self.List, Theme.TweenSpeed, { Size = UDim2.new(1, 0, 0, height) })
			else
				self.List.Size = UDim2.new(1, 0, 0, height)
			end
		end

		if typeof(self.ListLayout) == "Instance" then
			local ok, connection = pcall(function()
				return self.ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					refresh(true)
				end)
			end)
			if ok and connection then
				self.Bin:Add(connection)
			end
		end

		return refresh
	end

	function Dropdown:_isSelected(value)
		if self.Multi then
			return self.Value[tostring(value)] == true
		end
		return self.Value == value
	end

	function Dropdown:_paintOption(button, option)
		local selected = self:_isSelected(option.Value)

		button.BackgroundColor3 = selected and Theme.ElementActive or Theme.Element
		button.TextColor3 = selected and Theme.Text or Theme.TextDim

		local check = button:FindFirstChild("Check")
		if check then
			-- Emoji, so no TextColor3 tint: hidden outright when unselected.
			check.Text = selected and Theme.Icons.Check or ""
		end
	end

	function Dropdown:_buildOption(option)
		local button = Create.Button({
			Name = option.Text,
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
			Text = "",
			TextColor3 = Theme.TextDim,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			ZIndex = 3,
			Parent = self.List,
		})
		Create.Corner(Theme.ElementCornerRadius, button)

		Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -34, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Text = option.Text,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextDim,
			ZIndex = 4,
			Parent = button,
		})

		Create.Label({
			Name = "Check",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 24, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 0),
			Text = "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			Parent = button,
		})

		self:_paintOption(button, option)

		table.insert(self.OptionButtons, button)

		table.insert(self.OptionConnections, button.MouseEnter:Connect(function()
			if not self:_isSelected(option.Value) then
				Tween.Fast(button, { BackgroundColor3 = Theme.ElementHover })
			end
		end))

		table.insert(self.OptionConnections, button.MouseLeave:Connect(function()
			self:_paintOption(button, option)
		end))

		table.insert(self.OptionConnections, button.MouseButton1Click:Connect(function()
			self:_onOptionClicked(option)
		end))

		return button
	end

	function Dropdown:_onOptionClicked(option)
		if self.Multi then
			local key = tostring(option.Value)
			if self.Value[key] then
				self.Value[key] = nil
			else
				self.Value[key] = true
			end
		else
			if self.Value == option.Value then
				self:SetOpen(false)
				return
			end
			self.Value = option.Value
		end

		self:_paintDisplay()
		self:_paintOptions()

		if not self.Multi then
			self:SetOpen(false)
		end

		self:_fire()
	end

	function Dropdown:_paintOptions()
		for i = 1, #self.OptionButtons do
			local button = self.OptionButtons[i]
			local option = self.Options[i]
			if option then
				self:_paintOption(button, option)
			end
		end
	end

	function Dropdown:_paintDisplay()
		if self.Multi then
			local count = 0
			local first = nil
			for key in pairs(self.Value) do
				count = count + 1
				if not first then
					first = key
				end
			end

			if count == 0 then
				self.ValueLabel.Text = "None"
			elseif count == 1 then
				self.ValueLabel.Text = tostring(first)
			else
				self.ValueLabel.Text = string.format("%d selected", count)
			end
		else
			self.ValueLabel.Text = self.Value ~= nil and tostring(self.Value) or "None"
		end
	end

	function Dropdown:_fire()
		local value = self:GetValue()

		if typeof(self.Callback) == "function" then
			local ok, err = pcall(self.Callback, value, self)
			if not ok then
				warn(string.format("[B0XazUI] Dropdown %q callback error: %s", self.Name, tostring(err)))
			end
		end

		self.Changed:Fire(value, self)
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	function Dropdown:SetOptions(options, silent)
		self.Options = {}
		self.OptionButtons = {}
		self.OptionConnections = self.OptionConnections or {}

		-- Clear existing buttons and their connections.
		for i = 1, #self.OptionConnections do
			pcall(function()
				self.OptionConnections[i]:Disconnect()
			end)
		end
		self.OptionConnections = {}

		local children = self.List:GetChildren()
		for i = 1, #children do
			if children[i].ClassName ~= "UIListLayout" and children[i].ClassName ~= "UIPadding" then
				children[i]:Destroy()
			end
		end

		for i = 1, #options do
			local option = normalise(options[i], i)
			self.Options[i] = option
			self:_buildOption(option)
		end

		self.RefreshList(false)

		if not silent then
			self:_fire()
		end
	end

	function Dropdown:AddOption(option, silent)
		table.insert(self.Options, normalise(option, #self.Options + 1))
		self:SetOptions(self.Options, silent ~= false)
	end

	function Dropdown:RemoveOption(value)
		local filtered = {}
		for i = 1, #self.Options do
			if self.Options[i].Value ~= value then
				table.insert(filtered, self.Options[i])
			end
		end
		self:SetOptions(filtered, true)
	end

	--- For multi dropdowns pass a table of values.
	function Dropdown:SetValue(value, silent)
		if self.Multi then
			self.Value = {}
			if type(value) == "table" then
				for i = 1, #value do
					self.Value[tostring(value[i])] = true
				end
			elseif value ~= nil then
				self.Value[tostring(value)] = true
			end
		else
			self.Value = value
		end

		self:_paintDisplay()
		self:_paintOptions()

		if not silent then
			self:_fire()
		end
	end

	Dropdown.Set = Dropdown.SetValue

	function Dropdown:GetValue()
		if not self.Multi then
			return self.Value
		end

		local selected = {}
		for i = 1, #self.Options do
			if self.Value[tostring(self.Options[i].Value)] then
				table.insert(selected, self.Options[i].Value)
			end
		end
		return selected
	end

	function Dropdown:SetOpen(open)
		self.Open = open and true or false
		self.Chevron.Text = self.Open and Theme.Icons.Up or Theme.Icons.Down
		self.RefreshList(true)
	end

	function Dropdown:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Dropdown:SetCallback(callback)
		self.Callback = callback
	end

	function Dropdown:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Dropdown:Destroy()
		for i = 1, #(self.OptionConnections or {}) do
			pcall(function()
				self.OptionConnections[i]:Disconnect()
			end)
		end

		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Dropdown = Dropdown
end

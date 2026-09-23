--[[
	Core/Elements/Button.lua
	====================================================================
	A clickable row with a material-style ripple.

		Section:AddButton({
			Name     = "Do the thing",
			Callback = function() print("clicked") end,
		})

	:Fire() runs the callback programmatically (same path as a click).
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env

	local Button = {}
	Button.__index = Button

	function Button.New(section, config)
		config = config or {}

		local self = setmetatable({}, Button)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Button"
		self.Type = "Button"
		self.Callback = config.Callback
		self.Disabled = config.Disabled == true
		self.Bin = UI.Util.Bin.new()

		local height = config.Height or Theme.ElementHeight

		local Frame = Create("Frame", {
			Name = self.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			ZIndex = 1,
		})

		local HitArea = Create.Button({
			Name = "HitArea",
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 2,
			ClipsDescendants = true,
			Parent = Frame,
		})
		Create.Corner(Theme.ElementCornerRadius, HitArea)
		UI:BindTheme(HitArea, "BackgroundColor3", "Element")

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Text = self.Name,
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = HitArea,
		})
		UI:BindTheme(TextLabel, "TextColor3", "Text")

		-- Right-aligned optional detail text (e.g. a key name or count).
		if config.Detail then
			Create.Label({
				Name = "Detail",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Text = tostring(config.Detail),
				Font = Theme.Font,
				TextSize = Theme.SmallTextSize,
				TextColor3 = Theme.TextDim,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
				Parent = HitArea,
			})
		end

		self.Frame = Frame
		self.HitArea = HitArea
		self.TextLabel = TextLabel

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(HitArea.MouseEnter:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.ElementHover })
		end))

		self.Bin:Add(HitArea.MouseLeave:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.Element })
		end))

		self.Bin:Add(HitArea.MouseButton1Down:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.ElementActive })
		end))

		self.Bin:Add(HitArea.MouseButton1Up:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.ElementHover })
		end))

		self.Bin:Add(HitArea.InputBegan:Connect(function(input)
			if self.Disabled then
				return
			end
			if not Env.IsPrimaryInput(input) then
				return
			end
			self:_ripple(input.Position)
		end))

		self.Bin:Add(HitArea.MouseButton1Click:Connect(function()
			self:Fire()
		end))

		section:AddElement(Frame, self)
		return self
	end

	Button.new = Button.New

	----------------------------------------------------------------------
	-- Ripple
	----------------------------------------------------------------------

	function Button:_ripple(inputPosition)
		if typeof(self.HitArea) ~= "Instance" then
			return
		end

		local absolute = self.HitArea.AbsolutePosition
		local size = self.HitArea.AbsoluteSize

		local x = 0
		local y = 0
		if typeof(inputPosition) == "Vector2" or typeof(inputPosition) == "Vector3" then
			x = inputPosition.X - absolute.X
			y = inputPosition.Y - absolute.Y
		else
			x = size.X / 2
			y = size.Y / 2
		end

		local ripple = Create("Frame", {
			Name = "Ripple",
			BackgroundColor3 = Theme.Text,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, 0, 0, 0),
			ZIndex = 3,
			Parent = self.HitArea,
		})
		Create.Corner(UDim.new(1, 0), ripple)

		local target = math.max(size.X, size.Y) * 2.2
		Tween.Play(ripple, Tween.Info(0.45), {
			Size = UDim2.new(0, target, 0, target),
			BackgroundTransparency = 1,
		}, function()
			ripple:Destroy()
		end)
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	function Button:Fire()
		if self.Disabled then
			return
		end
		if typeof(self.Callback) == "function" then
			local ok, err = pcall(self.Callback, self)
			if not ok then
				warn(string.format("[B0XazUI] Button %q callback error: %s", self.Name, tostring(err)))
			end
		end
	end

	function Button:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Button:SetCallback(callback)
		self.Callback = callback
	end

	function Button:SetDisabled(disabled)
		self.Disabled = disabled and true or false
		Tween.Fast(self.HitArea, {
			BackgroundColor3 = self.Disabled and Theme.Element or Theme.Element,
		})
		Tween.Fast(self.TextLabel, {
			TextColor3 = self.Disabled and Theme.TextFaint or Theme.Text,
		})
	end

	function Button:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Button:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Button = Button
end

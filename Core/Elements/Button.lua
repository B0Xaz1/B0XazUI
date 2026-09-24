--[[
	Core/Elements/Button.lua
	====================================================================
	A clickable box -- the same silhouette as the dropdown/trigger
	boxes, one-pixel outline and all. Pressing it dips the fill; there
	is no ripple, the original design is quiet.

		Section:AddButton({
			Name     = "save config",
			Callback = function() print("clicked") end,
		})

	:Fire() runs the callback programmatically (same path as a click).
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween

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
			Parent = Frame,
		})
		if Theme.ElementCornerRadius > 0 then
			Create.Corner(Theme.ElementCornerRadius, HitArea)
		end
		UI:BindTheme(HitArea, "BackgroundColor3", "Element")
		local stroke = Create.Stroke(Theme.StrokeSoft, 1, HitArea)
		UI:BindTheme(stroke, "Color", "StrokeSoft")

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Text = self.Name,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = HitArea,
		})
		UI:BindTheme(TextLabel, "TextColor3", "TextDim")

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
				TextColor3 = Theme.TextFaint,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
				Parent = HitArea,
			})
		end

		self.Frame = Frame
		self.HitArea = HitArea
		self.TextLabel = TextLabel
		self.Stroke = stroke

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(HitArea.MouseEnter:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.ElementHover })
			Tween.Fast(TextLabel, { TextColor3 = Theme.Text })
			Tween.Fast(stroke, { Color = Theme.Stroke })
		end))

		self.Bin:Add(HitArea.MouseLeave:Connect(function()
			if self.Disabled then
				return
			end
			Tween.Fast(HitArea, { BackgroundColor3 = Theme.Element })
			Tween.Fast(TextLabel, { TextColor3 = Theme.TextDim })
			Tween.Fast(stroke, { Color = Theme.StrokeSoft })
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

		self.Bin:Add(HitArea.MouseButton1Click:Connect(function()
			self:Fire()
		end))

		section:AddElement(Frame, self)
		return self
	end

	Button.new = Button.New

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
		Tween.Fast(self.HitArea, { BackgroundColor3 = Theme.Element })
		Tween.Fast(self.TextLabel, {
			TextColor3 = self.Disabled and Theme.TextFaint or Theme.TextDim,
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

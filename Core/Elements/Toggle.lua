--[[
	Core/Elements/Toggle.lua
	====================================================================
	Boolean switch.

		Section:AddToggle({
			Name     = "Enabled",
			Default  = false,
			Callback = function(value) print(value) end,
		})

	The whole row is clickable, not just the switch.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween

	local Toggle = {}
	Toggle.__index = Toggle

	function Toggle.New(section, config)
		config = config or {}

		local self = setmetatable({}, Toggle)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Toggle"
		self.Type = "Toggle"
		self.Value = config.Default == true
		self.Callback = config.Callback
		self.Bin = UI.Util.Bin.new()
		self.Changed = UI.Util.Signal.new()

		local height = config.Height or Theme.ElementHeight

		local Frame = Create("Frame", {
			Name = self.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			ZIndex = 1,
		})

		local Row = Create.Button({
			Name = "Row",
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Corner(Theme.ElementCornerRadius, Row)
		UI:BindTheme(Row, "BackgroundColor3", "Element")

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -76, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Text = self.Name,
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			ZIndex = 3,
			Parent = Row,
		})
		UI:BindTheme(TextLabel, "TextColor3", "Text")

		------------------------------------------------------------------
		-- Switch
		------------------------------------------------------------------
		local Switch = Create("Frame", {
			Name = "Switch",
			BackgroundColor3 = self.Value and Theme.Accent or Theme.ToggleOff,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 40, 0, 20),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			ZIndex = 3,
			Parent = Row,
		})
		Create.Corner(10, Switch)

		local Knob = Create("Frame", {
			Name = "Knob",
			BackgroundColor3 = Theme.ToggleKnob,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 16, 0, 16),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, self.Value and 22 or 2, 0.5, 0),
			ZIndex = 4,
			Parent = Switch,
		})
		Create.Corner(8, Knob)

		self.Frame = Frame
		self.Row = Row
		self.TextLabel = TextLabel
		self.Switch = Switch
		self.Knob = Knob

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Row.MouseEnter:Connect(function()
			Tween.Fast(Row, { BackgroundColor3 = Theme.ElementHover })
		end))

		self.Bin:Add(Row.MouseLeave:Connect(function()
			Tween.Fast(Row, { BackgroundColor3 = Theme.Element })
		end))

		self.Bin:Add(Row.MouseButton1Click:Connect(function()
			self:SetValue(not self.Value)
		end))

		self:_paint(false)
		section:AddElement(Frame, self)
		return self
	end

	Toggle.new = Toggle.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Toggle:_paint(animate)
		local on = self.Value
		local speed = animate and Theme.TweenSpeed or 0

		Tween.Play(self.Switch, speed, { BackgroundColor3 = on and Theme.Accent or Theme.ToggleOff })
		Tween.Play(self.Knob, speed, {
			Position = UDim2.new(0, on and 22 or 2, 0.5, 0),
			BackgroundColor3 = on and Theme.ToggleKnob or Theme.ToggleKnob,
		})
	end

	function Toggle:_fire()
		if typeof(self.Callback) == "function" then
			local ok, err = pcall(self.Callback, self.Value, self)
			if not ok then
				warn(string.format("[B0XazUI] Toggle %q callback error: %s", self.Name, tostring(err)))
			end
		end

		self.Changed:Fire(self.Value, self)
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	--- @param skipCallback boolean when true, updates visuals only.
	function Toggle:SetValue(value, skipCallback)
		value = value and true or false

		local changed = self.Value ~= value
		self.Value = value
		self:_paint(true)

		if changed and not skipCallback then
			self:_fire()
		end
	end

	Toggle.Set = Toggle.SetValue

	function Toggle:GetValue()
		return self.Value
	end

	function Toggle:Toggle()
		self:SetValue(not self.Value)
	end

	function Toggle:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Toggle:SetCallback(callback)
		self.Callback = callback
	end

	function Toggle:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Toggle:Destroy()
		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Toggle = Toggle
end

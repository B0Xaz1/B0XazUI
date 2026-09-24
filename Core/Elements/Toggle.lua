--[[
	Core/Elements/Toggle.lua
	====================================================================
	A checkbox row in the original's style:

		[ ]  dim label
		/___ that fills with the accent, and the label lights up
	             in accent too, when it is on
	                                                       [ M2 ]
	            ^ optional key chip, click to bind a hotkey
	                                                       [======]
	            ^ optional colour swatch (config.Swatch)

		-- both are flames, not furniture: the chip captures a key with
		-- click-then-press (Escape clears) and the key toggles the
		-- toggle; the swatch opens the same colour picker popup the
		-- standalone element uses.

		Section:AddToggle({
			Name     = "aimbot",
			Default  = false,
			Bind     = Enum.UserInputType.MouseButton2, -- optional key chip
			Swatch   = { Default = Color3.fromRGB(150, 150, 220) }, -- optional
			Callback = function(value) print(value) end,
		})

	The whole row is clickable, not just the checkbox.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env

	local Toggle = {}
	Toggle.__index = Toggle

	-- Keys that clear the chip instead of being captured.
	local CLEAR_KEYS = {
		[Enum.KeyCode.Backspace] = true,
		[Enum.KeyCode.Delete] = true,
		[Enum.KeyCode.Escape] = true,
		[Enum.KeyCode.Unknown] = true,
	}

	--- "Enum.UserInputType.MouseButton2" -> "M2", key codes as-is.
	local function shortName(key)
		if key == nil then
			return "None"
		end
		local name = Env.KeyName(key)
		name = string.gsub(name, "MouseButton", "M")
		name = string.gsub(name, "MouseWheel", "Wheel")
		return name
	end

	local function isMouseInput(input)
		local t = input.UserInputType
		return t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.MouseButton2
			or t == Enum.UserInputType.MouseButton3
	end

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

		-- Key chip state.
		self.Bind = config.Bind or nil
		self.BindListening = false
		self.OnBind = config.OnBind -- fired with the new key when it changes

		local height = config.Height or Theme.ElementHeight

		local Frame = Create("Frame", {
			Name = self.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			ZIndex = 1,
		})

		-- The invisible click surface. Chips/swatches sit above it and
		-- swallow their own clicks first.
		local Row = Create.Button({
			Name = "Row",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})

		------------------------------------------------------------------
		-- Checkbox
		------------------------------------------------------------------
		local boxSize = Theme.CheckboxSize
		local Checkbox = Create("Frame", {
			Name = "Checkbox",
			BackgroundColor3 = Theme.ToggleOff,
			BorderSizePixel = 0,
			Size = UDim2.new(0, boxSize, 0, boxSize),
			Position = UDim2.new(0, 0, 0, math.floor((height - boxSize) / 2)),
			ZIndex = 3,
			Parent = Frame,
		})
		local checkboxStroke = Create.Stroke(Theme.StrokeSoft, 1, Checkbox)

		------------------------------------------------------------------
		-- Label
		------------------------------------------------------------------
		local labelX = boxSize + 9
		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -labelX, 1, 0),
			Position = UDim2.new(0, labelX, 0, 0),
			Text = self.Name,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = Frame,
		})

		self.Frame = Frame
		self.Row = Row
		self.Checkbox = Checkbox
		self.CheckboxStroke = checkboxStroke
		self.TextLabel = TextLabel
		self.LabelX = labelX
		self.ReservedRight = 0

		------------------------------------------------------------------
		-- Optional colour swatch (right-most control)
		------------------------------------------------------------------
		if config.Swatch then
			local swatchConfig = type(config.Swatch) == "table" and config.Swatch or {}
			self.SwatchPicker = UI.Elements.ColorPicker.NewSwatch(Frame, {
				Position = UDim2.new(1, -Theme.SwatchWidth, 0.5, -Theme.SwatchHeight / 2),
				Default = swatchConfig.Default,
				Callback = swatchConfig.Callback,
			})
			self.ReservedRight = Theme.SwatchWidth + 6
		end

		------------------------------------------------------------------
		-- Optional key chip
		------------------------------------------------------------------
		local Chip = Create.Button({
			Name = "Chip",
			BackgroundColor3 = Theme.Chip,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 0, Theme.ChipHeight),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -self.ReservedRight, 0.5, 0),
			Text = "",
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.ChipText,
			ZIndex = 5,
			Parent = Frame,
		})
		Create.Padding(Theme.ChipPaddingX, Theme.ChipPaddingX, 0, 0, Chip)
		local chipStroke = Create.Stroke(Theme.StrokeSoft, 1, Chip)
		self.Chip = Chip
		self.ChipStroke = chipStroke

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Row.MouseButton1Click:Connect(function()
			self:SetValue(not self.Value)
		end))

		self.Bin:Add(Row.MouseEnter:Connect(function()
			Tween.Fast(TextLabel, { TextColor3 = Theme.Text })
		end))

		self.Bin:Add(Row.MouseLeave:Connect(function()
			self:_paintLabel()
		end))

		-- Chip: click to listen, then the next key press is the bind.
		self.Bin:Add(Chip.MouseButton1Click:Connect(function()
			self.BindListening = true
			self:_paintChip(true)
		end))

		if Env.UserInputService then
			self.Bin:Add(Env.UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if self.BindListening then
					if gameProcessed then
						return
					end
					self:_captureBind(input)
					return
				end

				if gameProcessed or self.Bind == nil then
					return
				end

				local pressed = false
				if isMouseInput(input) then
					pressed = input.UserInputType == self.Bind
				else
					pressed = input.KeyCode == self.Bind
				end

				if pressed then
					self:SetValue(not self.Value)
				end
			end))
		end

		self:_paint(false)
		self:_paintChip(true)
		section:AddElement(Frame, self)
		return self
	end

	Toggle.new = Toggle.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Toggle:_captureBind(input)
		if CLEAR_KEYS[input.KeyCode] and not isMouseInput(input) then
			self.BindListening = false
			self:SetBind(nil)
			return
		end

		if isMouseInput(input) then
			self:SetBind(input.UserInputType)
		else
			self:SetBind(input.KeyCode)
		end
	end

	function Toggle:_paintLabel()
		Tween.Fast(self.TextLabel, {
			TextColor3 = self.Value and Theme.AccentSoft or Theme.TextDim,
		})
	end

	function Toggle:_paintChip(instant)
		local chip = self.Chip
		if not chip then
			return
		end

		local visible = self.Bind ~= nil or self.BindListening
		chip.Visible = visible

		if not visible then
			self:_reflow()
			return
		end

		local text = self.BindListening and "..." or shortName(self.Bind)
		chip.Text = text

		local width = UI.Util.Layout.GetTextBounds(text, Theme.Font, Theme.SmallTextSize).X
			+ Theme.ChipPaddingX * 2
		self._chipWidth = width
		chip.Size = UDim2.new(0, width, 0, Theme.ChipHeight)

		local speed = instant and 0 or Theme.TweenSpeedFast
		if self.BindListening then
			Tween.Play(chip, speed, { BackgroundColor3 = Theme.Chip, TextColor3 = Theme.AccentSoft })
			Tween.Play(self.ChipStroke, speed, { Color = Theme.Accent })
		else
			Tween.Play(chip, speed, { BackgroundColor3 = Theme.Chip, TextColor3 = Theme.ChipText })
			Tween.Play(self.ChipStroke, speed, { Color = Theme.StrokeSoft })
		end

		self:_reflow()
	end

	--- Keeps the label clear of whatever is parked on the right.
	function Toggle:_reflow()
		local reserve = 0
		if self.SwatchPicker then
			reserve = Theme.SwatchWidth + 6
		end
		if self.Chip and self.Chip.Visible then
			reserve = reserve + (self._chipWidth or 22) + 8
		end
		self.TextLabel.Size = UDim2.new(1, -(self.LabelX + reserve), 1, 0)
	end

	function Toggle:_paint(animate)
		local on = self.Value
		local speed = animate and Theme.TweenSpeedFast or 0

		Tween.Play(self.Checkbox, speed, {
			BackgroundColor3 = on and Theme.ToggleKnob or Theme.ToggleOff,
		})
		Tween.Play(self.CheckboxStroke, speed, {
			Color = on and Theme.AccentDark or Theme.StrokeSoft,
		})
		self:_paintLabel()
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

	--- Binds the key chip. Accepts a KeyCode, a mouse UserInputType, or
	-- nil to clear. Fires config.OnBind when it changed.
	function Toggle:SetBind(key)
		if typeof(key) == "string" then
			local parsed = Enum.KeyCode[key]
			if parsed then
				key = parsed
			end
		end

		local changed = self.Bind ~= key
		self.Bind = key
		self.BindListening = false
		self:_paintChip(false)

		if changed and typeof(self.OnBind) == "function" then
			pcall(self.OnBind, self.Bind, self)
		end
	end

	function Toggle:GetBind()
		return self.Bind
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
		if self.SwatchPicker then
			self.SwatchPicker:Destroy()
			self.SwatchPicker = nil
		end

		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Toggle = Toggle
end

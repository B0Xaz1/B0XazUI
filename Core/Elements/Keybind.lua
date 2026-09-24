--[[
	Core/Elements/Keybind.lua
	====================================================================
	Key capture + hotkey firing, drawn as a dim label with a key chip
	parked on the right edge -- the same chip toggles wear:

		toggle ui                                          [ enum ]

	Click the chip, then press a key. Backspace / Escape clears the
	bind. While a TextBox has focus, input is ignored so typing never
	accidentally rebinds or fires the hotkey.

		Section:AddKeybind({
			Name     = "toggle ui",
			Default  = Enum.KeyCode.RightShift,
			Callback = function() print("pressed") end,
		})
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env
	local Layout = UI.Util.Layout

	local Keybind = {}
	Keybind.__index = Keybind

	-- Keys used to clear/unbind instead of being captured.
	local CLEAR_KEYS = {
		[Enum.KeyCode.Backspace] = true,
		[Enum.KeyCode.Delete] = true,
		[Enum.KeyCode.Escape] = true,
		[Enum.KeyCode.Unknown] = true,
	}

	-- Mouse buttons can be bound too; they arrive as UserInputType.
	local function isMouseInput(input)
		local t = input.UserInputType
		return t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.MouseButton2
			or t == Enum.UserInputType.MouseButton3
	end

	local function shortName(keyName)
		if keyName == nil then
			return "None"
		end
		local name = Env.KeyName(keyName)
		name = string.gsub(name, "MouseButton", "M")
		name = string.gsub(name, "MouseWheel", "Wheel")
		return name
	end

	function Keybind.New(section, config)
		config = config or {}

		local self = setmetatable({}, Keybind)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Keybind"
		self.Type = "Keybind"
		self.Callback = config.Callback
		self.Listening = false
		self.Key = config.Default or nil
		self.MouseButton = nil
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

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = self.Name,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
			Parent = Frame,
		})
		UI:BindTheme(TextLabel, "TextColor3", "TextDim")

		local Chip = Create.Button({
			Name = "Chip",
			BackgroundColor3 = Theme.Chip,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 24, 0, Theme.ChipHeight),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Text = "",
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.ChipText,
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Padding(Theme.ChipPaddingX, Theme.ChipPaddingX, 0, 0, Chip)
		local chipStroke = Create.Stroke(Theme.StrokeSoft, 1, Chip)
		UI:BindTheme(Chip, "BackgroundColor3", "Chip")

		self.Frame = Frame
		self.TextLabel = TextLabel
		self.BindButton = Chip
		self.ChipStroke = chipStroke

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Chip.MouseButton1Click:Connect(function()
			self:StartListening()
		end))

		-- Global listener: captures while listening, fires otherwise.
		if Env.UserInputService then
			self.Bin:Add(Env.UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if self.Listening then
					-- Never steal input the game (or a TextBox) is already using.
					if gameProcessed then
						return
					end
					self:_capture(input)
					return
				end

				if gameProcessed then
					return
				end

				if self:Matches(input) then
					if typeof(self.Callback) == "function" then
						local ok, err = pcall(self.Callback, self)
						if not ok then
							warn(string.format("[B0XazUI] Keybind %q callback error: %s", self.Name, tostring(err)))
						end
					end
					self.Changed:Fire(self.Key, self)
				end
			end))
		end

		self:_paint()
		section:AddElement(Frame, self)
		return self
	end

	Keybind.new = Keybind.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Keybind:_capture(input)
		if CLEAR_KEYS[input.KeyCode] and not isMouseInput(input) then
			self:StopListening()
			self.Key = nil
			self.MouseButton = nil
			self:_paint()
			self.Changed:Fire(nil, self)
			return
		end

		if isMouseInput(input) then
			self.MouseButton = input.UserInputType
			self.Key = nil
		else
			self.Key = input.KeyCode
			self.MouseButton = nil
		end

		self:StopListening()

		if typeof(self.OnChanged) == "function" then
			pcall(self.OnChanged, self.Key or self.MouseButton, self)
		end

		self.Changed:Fire(self.Key or self.MouseButton, self)
	end

	function Keybind:_paint()
		local chip = self.BindButton

		local text
		if self.Listening then
			text = "..."
		else
			text = self:GetName()
		end
		chip.Text = text

		-- Size the chip to the key's name, never below a key's width.
		local width = math.max(24, Layout.GetTextBounds(text, Theme.Font, Theme.SmallTextSize).X + Theme.ChipPaddingX * 2)
		chip.Size = UDim2.new(0, width, 0, Theme.ChipHeight)

		if self.Listening then
			Tween.Fast(chip, { TextColor3 = Theme.AccentSoft })
			Tween.Fast(self.ChipStroke, { Color = Theme.Accent })
		else
			Tween.Fast(chip, {
				TextColor3 = self:IsBound() and Theme.ChipText or Theme.TextFaint,
			})
			Tween.Fast(self.ChipStroke, { Color = Theme.StrokeSoft })
		end
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	function Keybind:IsBound()
		return (self.Key ~= nil and self.Key ~= Enum.KeyCode.Unknown)
			or self.MouseButton ~= nil
	end

	function Keybind:GetName()
		if self.Listening then
			return "..."
		end
		if self.MouseButton then
			return shortName(self.MouseButton)
		end
		if self.Key and self.Key ~= Enum.KeyCode.Unknown then
			return shortName(self.Key)
		end
		return "None"
	end

	--- True when this input should trigger the keybind.
	function Keybind:Matches(input)
		if not self:IsBound() then
			return false
		end

		if self.MouseButton then
			return input.UserInputType == self.MouseButton
		end

		return input.KeyCode == self.Key
	end

	function Keybind:StartListening()
		if self.Listening then
			return
		end
		self.Listening = true
		self:_paint()
	end

	function Keybind:StopListening()
		if not self.Listening then
			return
		end
		self.Listening = false
		self:_paint()
	end

	function Keybind:SetKey(keyCode, silent)
		if typeof(keyCode) == "string" then
			local parsed = Enum.KeyCode[keyCode]
			if parsed then
				keyCode = parsed
			end
		end

		self.Key = keyCode
		self.MouseButton = nil
		self:_paint()

		if not silent then
			self.Changed:Fire(self.Key, self)
		end
	end

	Keybind.Set = Keybind.SetKey

	function Keybind:GetKey()
		return self.Key or self.MouseButton
	end

	Keybind.GetValue = Keybind.GetKey

	function Keybind:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Keybind:SetCallback(callback)
		self.Callback = callback
	end

	function Keybind:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Keybind:Destroy()
		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Keybind = Keybind
end

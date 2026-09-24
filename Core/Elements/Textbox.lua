--[[
	Core/Elements/Textbox.lua
	====================================================================
	Single-line text input, in the same shape the dropdown uses: a
	small dim label above a full-width inset box. The border lights
	up while typing.

		Section:AddTextbox({
			Name        = "player name",
			Default     = "",
			Placeholder = "who?",
			Numeric     = false,    -- digits and one decimal point only
			MaxLength   = 32,
			ClearOnFocus = false,
			Callback    = function(text, enterPressed) end,
		})

	The callback fires on focus loss and on Enter (enterPressed tells
	you which one it was).
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween

	local Textbox = {}
	Textbox.__index = Textbox

	function Textbox.New(section, config)
		config = config or {}

		local self = setmetatable({}, Textbox)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Textbox"
		self.Type = "Textbox"
		self.Numeric = config.Numeric == true
		self.Callback = config.Callback
		self.ClearOnFocus = config.ClearOnFocus == true
		self.EnterClears = config.EnterClears == true
		self.MaxLength = config.MaxLength
		self.Bin = UI.Util.Bin.new()
		self.Changed = UI.Util.Signal.new()

		self.Value = tostring(config.Default or config.Text or "")

		local height = config.Height or (Theme.LabelRowHeight + 3 + Theme.BoxHeight)

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
			Size = UDim2.new(1, 0, 0, Theme.LabelRowHeight),
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

		local Input = Create("TextBox", {
			Name = "Input",
			BackgroundColor3 = Theme.Input,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.BoxHeight),
			Position = UDim2.new(0, 0, 0, Theme.LabelRowHeight + 3),
			Text = self.Value,
			PlaceholderText = config.Placeholder or "",
			PlaceholderColor3 = Theme.TextFaint,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Padding(7, 7, 0, 0, Input)
		local stroke = Create.Stroke(Theme.StrokeSoft, 1, Input)
		UI:BindTheme(Input, "BackgroundColor3", "Input")

		self.Frame = Frame
		self.TextLabel = TextLabel
		self.Input = Input
		self.Stroke = stroke

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Input.Focused:Connect(function()
			Tween.Fast(stroke, { Color = Theme.Stroke })
			if self.ClearOnFocus then
				Input.Text = ""
			end
		end))

		self.Bin:Add(Input.FocusLost:Connect(function(enterPressed)
			Tween.Fast(stroke, { Color = Theme.StrokeSoft })

			self:_commit(enterPressed)

			if enterPressed and self.EnterClears then
				Input.Text = ""
				self.Value = ""
			end
		end))

		self.Bin:Add(Input:GetPropertyChangedSignal("Text"):Connect(function()
			self:_sanitise()
		end))

		section:AddElement(Frame, self)
		return self
	end

	Textbox.new = Textbox.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Textbox:_sanitise()
		local text = self.Input.Text

		if self.MaxLength and #text > self.MaxLength then
			text = string.sub(text, 1, self.MaxLength)
		end

		if self.Numeric then
			local filtered = string.gsub(text, "[^%d%.%-]", "")
			-- Keep only the first decimal point / minus sign.
			local seenDot = false
			local cleaned = ""
			for i = 1, #filtered do
				local char = string.sub(filtered, i, i)
				if char == "." then
					if not seenDot then
						seenDot = true
						cleaned = cleaned .. char
					end
				elseif char == "-" then
					if i == 1 then
						cleaned = cleaned .. char
					end
				else
					cleaned = cleaned .. char
				end
			end
			text = cleaned
		end

		if text ~= self.Input.Text then
			local cursor = #text
			self.Input.Text = text
			-- Roblox clamps the cursor for us; this just keeps it at the end.
			pcall(function()
				self.Input.CursorPosition = cursor + 1
			end)
		end

		self.Value = self.Input.Text
	end

	function Textbox:_commit(enterPressed)
		self:_sanitise()

		local changed = self.Value ~= self._lastCommitted
		self._lastCommitted = self.Value

		if typeof(self.Callback) == "function" then
			local ok, err = pcall(self.Callback, self.Value, enterPressed, self)
			if not ok then
				warn(string.format("[B0XazUI] Textbox %q callback error: %s", self.Name, tostring(err)))
			end
		end

		if changed then
			self.Changed:Fire(self.Value, self)
		end
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	function Textbox:SetValue(text, silent)
		self.Input.Text = tostring(text or "")
		self:_sanitise()

		if not silent then
			if typeof(self.Callback) == "function" then
				pcall(self.Callback, self.Value, false, self)
			end
			self.Changed:Fire(self.Value, self)
		end
	end

	Textbox.Set = Textbox.SetValue

	function Textbox:GetValue()
		return self.Input.Text
	end

	--- Numeric convenience: returns nil when the box is not a number.
	function Textbox:GetNumber()
		return tonumber(self.Input.Text)
	end

	function Textbox:SetPlaceholder(text)
		self.Input.PlaceholderText = tostring(text or "")
	end

	function Textbox:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Textbox:SetCallback(callback)
		self.Callback = callback
	end

	function Textbox:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Textbox:Destroy()
		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Textbox = Textbox
end

--[[
	Core/Elements/ColorPicker.lua
	====================================================================
	HSV colour picker. The row is just a dim label and a solid swatch
	block on the right; clicking the swatch opens a floating panel on
	the overlay (so the page's ScrollingFrame cannot clip it):

		+---------------------------+
		|                           |
		|      saturation /         |   drag anywhere
		|      value field          |
		|                           |
		+---------------------------+
		|  hue  ----------------o---|   drag
		+---------------------------+
		|          a1b2c3           |   editable hex
		+---------------------------+

	No image assets are used -- the gradients are pure UIGradients, so
	this works offline and on any executor.

	The swatch + popup are also exported as ColorPicker.NewSwatch, so
	other elements (the toggle's config.Swatch) can embed the same
	control without growing a row of their own.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env
	local Color = UI.Util.Color

	local ColorPicker = {}
	ColorPicker.__index = ColorPicker

	local POPUP_WIDTH = 200
	local POPUP_HEIGHT = 184
	local FIELD_HEIGHT = 110
	local HUE_HEIGHT = 12

	--- Full rainbow for the hue strip.
	local function rainbowSequence()
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
		})
	end

	--- Wires drag + click on `frame`; callback gets 0..1 coordinates.
	local function bindDrag(frame, callback, bin)
		local uis = Env.UserInputService
		if not uis then
			return
		end

		local dragging = false

		local function emit(input)
			local position = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			if size.X <= 0 or size.Y <= 0 then
				return
			end

			local x = Color.Clamp((input.Position.X - position.X) / size.X, 0, 1)
			local y = Color.Clamp((input.Position.Y - position.Y) / size.Y, 0, 1)
			callback(x, y)
		end

		bin:Add(frame.InputBegan:Connect(function(input)
			if not Env.IsPrimaryInput(input) then
				return
			end
			dragging = true
			emit(input)
		end))

		bin:Add(uis.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			emit(input)
		end))

		bin:Add(uis.InputEnded:Connect(function(input)
			if not dragging then
				return
			end
			if not Env.IsPrimaryInput(input) then
				return
			end
			dragging = false
		end))
	end

	----------------------------------------------------------------------
	-- Shared construction
	----------------------------------------------------------------------

	--- Initialises the picker state + swatch button on `self` and wires
	-- the click-to-open popup. Used by both constructors below.
	local function initialise(self, default, callback)
		if typeof(default) ~= "Color3" then
			default = Theme.Accent
		end

		self.UI = UI
		self.Type = "ColorPicker"
		self.Callback = callback
		self.Bin = UI.Util.Bin.new()
		self.Changed = UI.Util.Signal.new()

		local h, s, v = Color.ToHSV(default)
		self.H, self.S, self.V = h * 360, s, v
		self.Value = default
		self.Popup = nil -- built lazily on first open

		self.Bin:Add(self.SwatchButton.MouseButton1Click:Connect(function()
			self:_togglePopup()
		end))

		self:_paintField()
	end

	--- The full row element: label on the left, swatch on the right.
	function ColorPicker.New(section, config)
		config = config or {}

		local self = setmetatable({}, ColorPicker)

		self.Section = section
		self.Name = config.Name or config.Title or "Color"

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
			Size = UDim2.new(1, -(Theme.SwatchWidth + 14), 1, 0),
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

		self.SwatchButton = Create.Button({
			Name = "Swatch",
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, Theme.SwatchWidth, 0, Theme.SwatchHeight),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Stroke(Theme.StrokeSoft, 1, self.SwatchButton)

		self.Frame = Frame
		self.TextLabel = TextLabel

		initialise(self, config.Default, config.Callback)

		section:AddElement(Frame, self)
		return self
	end

	--- Bare swatch + popup for embedding into other elements' rows.
	-- @param container Instance    the row frame to draw inside
	-- @param config    table       { Position (UDim2), Default, Callback }
	function ColorPicker.NewSwatch(container, config)
		config = config or {}

		local self = setmetatable({}, ColorPicker)

		self.SwatchButton = Create.Button({
			Name = "Swatch",
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, Theme.SwatchWidth, 0, Theme.SwatchHeight),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = config.Position or UDim2.new(1, -Theme.SwatchWidth, 0.5, 0),
			Text = "",
			ZIndex = 5,
			Parent = container,
		})
		Create.Stroke(Theme.StrokeSoft, 1, self.SwatchButton)

		self.Frame = self.SwatchButton -- Destroy() target
		initialise(self, config.Default, config.Callback)
		return self
	end

	ColorPicker.new = ColorPicker.New

	----------------------------------------------------------------------
	-- Popup
	----------------------------------------------------------------------

	function ColorPicker:_buildPopup()
		if self.Popup then
			return self.Popup
		end

		local popup = UI.Util.Popup.new(self.SwatchButton, Vector2.new(POPUP_WIDTH, POPUP_HEIGHT), {
			Align = "Right",
			Offset = 6,
			ZIndex = 200,
		})

		local panel = popup.Frame
		local inset = 10
		local contentWidth = POPUP_WIDTH - inset * 2

		------------------------------------------------------------------
		-- Saturation / value field
		------------------------------------------------------------------
		local Field = Create("Frame", {
			Name = "Field",
			BackgroundColor3 = Color.FromHSV(self.H, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(0, contentWidth, 0, FIELD_HEIGHT),
			Position = UDim2.new(0, inset, 0, inset),
			ZIndex = 201,
			Parent = panel,
		})
		Create.Stroke(Theme.Stroke, 1, Field)

		-- White overlay, opaque on the left -> transparent on the right.
		local Saturation = Create("Frame", {
			Name = "Saturation",
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			ZIndex = 202,
			Parent = Field,
		})
		Create.New("UIGradient", {
			Rotation = 0,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = Saturation,
		})

		-- Black overlay, transparent at the top -> opaque at the bottom.
		-- (Roblox UIGradient rotation 90 runs top -> bottom.)
		local Value = Create("Frame", {
			Name = "Value",
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
			ZIndex = 203,
			Parent = Field,
		})
		Create.New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = Value,
		})

		local FieldCursor = Create("Frame", {
			Name = "Cursor",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 10, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0, 0),
			ZIndex = 204,
			Parent = Field,
		})
		Create.Corner(5, FieldCursor)
		Create.Stroke(Color3.fromRGB(0, 0, 0), 1, FieldCursor)

		------------------------------------------------------------------
		-- Hue strip
		------------------------------------------------------------------
		local hueY = inset + FIELD_HEIGHT + 8

		local Hue = Create("Frame", {
			Name = "Hue",
			BorderSizePixel = 0,
			Size = UDim2.new(0, contentWidth, 0, HUE_HEIGHT),
			Position = UDim2.new(0, inset, 0, hueY),
			ZIndex = 201,
			Parent = panel,
		})
		Create.Stroke(Theme.Stroke, 1, Hue)
		Create.New("UIGradient", {
			Rotation = 0,
			Color = rainbowSequence(),
			Parent = Hue,
		})

		local HueCursor = Create("Frame", {
			Name = "Cursor",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 0, HUE_HEIGHT + 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			ZIndex = 202,
			Parent = Hue,
		})
		Create.Stroke(Color3.fromRGB(0, 0, 0), 1, HueCursor)

		------------------------------------------------------------------
		-- Hex input
		------------------------------------------------------------------
		local hexY = hueY + HUE_HEIGHT + 10

		local HexBox = Create("TextBox", {
			Name = "HexBox",
			BackgroundColor3 = Theme.Input,
			BorderSizePixel = 0,
			Size = UDim2.new(0, contentWidth, 0, 22),
			Position = UDim2.new(0, inset, 0, hexY),
			Text = Color.ToHex(self.Value),
			PlaceholderText = "rrggbb",
			PlaceholderColor3 = Theme.TextFaint,
			Font = Theme.FontMono or Theme.Font,
			TextSize = Theme.SmallTextSize + 1,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			ClearTextOnFocus = false,
			ZIndex = 201,
			Parent = panel,
		})
		Create.Stroke(Theme.StrokeSoft, 1, HexBox)
		UI:BindTheme(HexBox, "BackgroundColor3", "Input")

		self.Field = Field
		self.FieldCursor = FieldCursor
		self.HueFrame = Hue
		self.HueCursor = HueCursor
		self.HexBox = HexBox
		self.Popup = popup

		------------------------------------------------------------------
		-- Drag wiring
		------------------------------------------------------------------
		local dragBin = self.Bin

		bindDrag(Field, function(x, y)
			self:_setFromField(x, y)
		end, dragBin)

		bindDrag(Hue, function(x)
			self:_setFromHue(x)
		end, dragBin)

		dragBin:Add(HexBox.FocusLost:Connect(function(enterPressed)
			local parsed = Color.FromHex(HexBox.Text)
			if parsed then
				self:SetValue(parsed)
				self:_commit()
			else
				HexBox.Text = Color.ToHex(self.Value)
			end
		end))

		self:_paintField()
		return popup
	end

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function ColorPicker:_setFromField(percentX, percentY)
		self.S = percentX
		self.V = 1 - percentY
		self:_recompute(false)
	end

	function ColorPicker:_setFromHue(percentX)
		self.H = percentX * 360
		self:_recompute(false)
	end

	function ColorPicker:_recompute(commit)
		self.Value = Color.FromHSV(self.H, self.S, self.V)
		self:_paintField()

		if commit then
			self:_commit()
		else
			self.Changed:Fire(self.Value, self)
		end
	end

	function ColorPicker:_paintField()
		local color = self.Value

		self.SwatchButton.BackgroundColor3 = color

		if not self.Popup then
			return
		end

		local hueColor = Color.FromHSV(self.H, 1, 1)

		self.Field.BackgroundColor3 = hueColor
		self.FieldCursor.Position = UDim2.new(self.S, 0, 1 - self.V, 0)
		self.FieldCursor.BackgroundColor3 = color
		self.HueFrame.BackgroundColor3 = hueColor
		self.HueCursor.Position = UDim2.new(Color.Clamp(self.H / 360, 0, 1), 0, 0.5, 0)

		if self.HexBox and not self.HexBox:IsFocused() then
			self.HexBox.Text = Color.ToHex(color)
		end
	end

	function ColorPicker:_commit()
		if typeof(self.Callback) == "function" then
			local ok, err = pcall(self.Callback, self.Value, self)
			if not ok then
				warn(string.format("[B0XazUI] ColorPicker %q callback error: %s", tostring(self.Name), tostring(err)))
			end
		end
		self.Changed:Fire(self.Value, self)
	end

	function ColorPicker:_togglePopup()
		self:_buildPopup()
		self.Popup:Toggle()
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	function ColorPicker:SetValue(color, silent)
		if typeof(color) ~= "Color3" then
			return
		end

		local h, s, v = Color.ToHSV(color)
		self.H, self.S, self.V = h * 360, s, v
		self.Value = color
		self:_paintField()

		if not silent then
			self:_commit()
		end
	end

	ColorPicker.Set = ColorPicker.SetValue

	function ColorPicker:GetValue()
		return self.Value
	end

	function ColorPicker:SetOpen(open)
		self:_buildPopup()
		self.Popup:SetOpen(open and true or false)
	end

	function ColorPicker:SetText(text)
		self.Name = tostring(text or "")
		if self.TextLabel then
			self.TextLabel.Text = self.Name
		end
		if self.Frame and self.Frame ~= self.SwatchButton then
			self.Frame.Name = self.Name
		end
	end

	function ColorPicker:SetCallback(callback)
		self.Callback = callback
	end

	function ColorPicker:SetVisible(visible)
		if self.Frame then
			self.Frame.Visible = visible and true or false
		end
	end

	function ColorPicker:Destroy()
		if self.Popup then
			self.Popup:Destroy()
			self.Popup = nil
		end

		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)

		-- Embedded swatches destroy their own button; row elements leave
		-- row teardown to the row frame.
		if self.Frame then
			if self.Frame == self.SwatchButton or self.Section ~= nil then
				self.Frame:Destroy()
			end
			self.Frame = nil
		end
	end

	UI.Elements.ColorPicker = ColorPicker
end

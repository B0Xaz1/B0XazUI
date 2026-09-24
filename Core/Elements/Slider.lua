--[[
	Core/Elements/Slider.lua
	====================================================================
	Numeric range control with drag + click-on-track support.

		Section:AddSlider({
			Name     = "Speed",
			Min      = 0,
			Max      = 100,
			Default  = 25,
			Step     = 1,        -- 0.1 gives one decimal place
			Suffix   = "%",
			Callback = function(value) end,
		})
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env
	local Color = UI.Util.Color

	local Slider = {}
	Slider.__index = Slider

	--- Number of decimal places implied by a step size (max 3).
	local function decimalsFor(step)
		if not step or step >= 1 then
			return 0
		end
		local text = string.format("%.6f", step)
		text = string.gsub(text, "0+$", "")
		local dot = string.find(text, "%.")
		if not dot then
			return 0
		end
		return math.min(3, #text - dot)
	end

	function Slider.New(section, config)
		config = config or {}

		local self = setmetatable({}, Slider)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or config.Title or "Slider"
		self.Type = "Slider"

		self.Min = tonumber(config.Min) or 0
		self.Max = tonumber(config.Max) or 100
		if self.Max <= self.Min then
			self.Max = self.Min + 1
		end

		self.Step = tonumber(config.Step) or 1
		if self.Step <= 0 then
			self.Step = 1
		end

		self.Suffix = config.Suffix or ""
		self.Decimals = config.Decimals or decimalsFor(self.Step)
		self.Callback = config.Callback
		self.Bin = UI.Util.Bin.new()
		self.Changed = UI.Util.Signal.new()
		self.Dragging = false

		local default = tonumber(config.Default)
		if default == nil then
			default = self.Min
		end
		self.Value = Color.Clamp(default, self.Min, self.Max)

		------------------------------------------------------------------
		-- Layout
		--   [ name                    ]  [ value ]   <- 18px header
		--   [ =================o--------------- ]   <- 6px  track
		------------------------------------------------------------------
		local height = config.Height or 42

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
			Size = UDim2.new(1, -100, 0, 18),
			Position = UDim2.new(0, 2, 0, 0),
			Text = self.Name,
			Font = Theme.FontMedium,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			ZIndex = 2,
			Parent = Frame,
		})
		UI:BindTheme(TextLabel, "TextColor3", "Text")

		local ValueLabel = Create.Label({
			Name = "Value",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 96, 0, 18),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, 0),
			Text = "",
			Font = Theme.FontSemibold,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
			Parent = Frame,
		})
		UI:BindTheme(ValueLabel, "TextColor3", "Accent")

		local TrackHit = Create.Button({
			Name = "TrackHit",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0, height - 20),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})

		local Track = Create("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme.SliderTrack,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 6),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			ZIndex = 3,
			Parent = TrackHit,
		})
		Create.Corner(3, Track)
		UI:BindTheme(Track, "BackgroundColor3", "SliderTrack")

		local Fill = Create("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 4,
			Parent = Track,
		})
		Create.Corner(3, Fill)
		UI:BindTheme(Fill, "BackgroundColor3", "Accent")

		local Knob = Create("Frame", {
			Name = "Knob",
			BackgroundColor3 = Theme.Text,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 12, 0, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			ZIndex = 5,
			Parent = Track,
		})
		Create.Corner(6, Knob)
		UI:BindTheme(Knob, "BackgroundColor3", "Text")

		self.Frame = Frame
		self.TextLabel = TextLabel
		self.ValueLabel = ValueLabel
		self.Track = Track
		self.TrackHit = TrackHit
		self.Fill = Fill
		self.Knob = Knob

		self:_bindInput()
		self:_paint(false)
		section:AddElement(Frame, self)
		return self
	end

	Slider.new = Slider.New

	----------------------------------------------------------------------
	-- Internals
	----------------------------------------------------------------------

	function Slider:_percent()
		local range = self.Max - self.Min
		if range <= 0 then
			return 0
		end
		return Color.Clamp((self.Value - self.Min) / range, 0, 1)
	end

	function Slider:_fromAbsoluteX(absoluteX)
		local trackPosition = self.Track.AbsolutePosition.X
		local trackWidth = self.Track.AbsoluteSize.X
		if trackWidth <= 0 then
			return self.Value
		end

		local percent = Color.Clamp((absoluteX - trackPosition) / trackWidth, 0, 1)
		local raw = self.Min + percent * (self.Max - self.Min)
		local steps = math.floor((raw - self.Min) / self.Step + 0.5)
		return Color.Clamp(self.Min + steps * self.Step, self.Min, self.Max)
	end

	function Slider:_format(value)
		return string.format("%." .. tostring(self.Decimals) .. "f", value) .. self.Suffix
	end

	function Slider:_paint(animate)
		local percent = self._percent and self:_percent() or 0

		self.ValueLabel.Text = self:_format(self.Value)
		self.Fill.Size = UDim2.new(percent, 0, 1, 0)
		self.Knob.Position = UDim2.new(percent, 0, 0.5, 0)
	end

	function Slider:_bindInput()
		local uis = Env.UserInputService
		if not uis then
			return
		end

		local dragging = false

		local function begin(input)
			dragging = true
			self.Dragging = true
			self:SetValue(self:_fromAbsoluteX(input.Position.X), false, true)
		end

		self.Bin:Add(self.TrackHit.InputBegan:Connect(function(input)
			if not Env.IsPrimaryInput(input) then
				return
			end
			begin(input)
		end))

		self.Bin:Add(uis.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			self:SetValue(self:_fromAbsoluteX(input.Position.X), false, true)
		end))

		self.Bin:Add(uis.InputEnded:Connect(function(input)
			if not dragging then
				return
			end
			if not Env.IsPrimaryInput(input) then
				return
			end

			dragging = false
			self.Dragging = false
			self.Value = Color.Clamp(self.Value, self.Min, self.Max)

			-- Commit: this is the "user finished dragging" callback.
			if typeof(self.Callback) == "function" then
				local ok, err = pcall(self.Callback, self.Value, self)
				if not ok then
					warn(string.format("[B0XazUI] Slider %q callback error: %s", self.Name, tostring(err)))
				end
			end
			self.Changed:Fire(self.Value, self)
		end))

		self.Bin:Add(self.TrackHit.MouseEnter:Connect(function()
			Tween.Fast(self.Knob, { Size = UDim2.new(0, 14, 0, 14) })
		end))

		self.Bin:Add(self.TrackHit.MouseLeave:Connect(function()
			Tween.Fast(self.Knob, { Size = UDim2.new(0, 12, 0, 12) })
		end))
	end

	----------------------------------------------------------------------
	-- API
	----------------------------------------------------------------------

	--- @param silent boolean  update visuals without firing the callback
	-- @param live    boolean  set while dragging (fires Live callback only)
	function Slider:SetValue(value, silent, live)
		value = tonumber(value) or self.Min
		value = Color.Clamp(value, self.Min, self.Max)

		local changed = value ~= self.Value
		self.Value = value
		self:_paint(true)

		if live then
			if typeof(self.LiveCallback) == "function" then
				pcall(self.LiveCallback, value, self)
			end
			self.Changed:Fire(value, self)
			return
		end

		if changed and not silent then
			if typeof(self.Callback) == "function" then
				local ok, err = pcall(self.Callback, value, self)
				if not ok then
					warn(string.format("[B0XazUI] Slider %q callback error: %s", self.Name, tostring(err)))
				end
			end
			self.Changed:Fire(value, self)
		end
	end

	Slider.Set = Slider.SetValue

	function Slider:GetValue()
		return self.Value
	end

	function Slider:SetRange(minValue, maxValue)
		self.Min = tonumber(minValue) or self.Min
		self.Max = tonumber(maxValue) or self.Max
		if self.Max <= self.Min then
			self.Max = self.Min + 1
		end
		self:SetValue(Color.Clamp(self.Value, self.Min, self.Max), true)
	end

	function Slider:SetText(text)
		self.Name = tostring(text or "")
		self.TextLabel.Text = self.Name
		self.Frame.Name = self.Name
	end

	function Slider:SetSuffix(suffix)
		self.Suffix = tostring(suffix or "")
		self:_paint(false)
	end

	function Slider:SetCallback(callback)
		self.Callback = callback
	end

	function Slider:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Slider:Destroy()
		self.Changed:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Slider = Slider
end

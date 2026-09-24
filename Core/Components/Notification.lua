--[[
	Core/Components/Notification.lua
	====================================================================
	Stacked toast notifications pinned to a screen corner.

		UI:Notify({
			Title    = "Saved",
			Content  = "Your settings were written to disk.",
			Duration = 4,
			Type     = "Success",   -- Info | Success | Warning | Error
		})

	Notifications animate in from the edge, stack away from the anchor
	corner, auto-dismiss, and can be dismissed by clicking.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Layout = UI.Util.Layout
	local Env = UI.Env

	local Notification = {}
	Notification.__index = Notification

	local TYPES = {
		Info = { Color = "Info", Glyph = "i" },
		Success = { Color = "Success", Glyph = "✓" },
		Warning = { Color = "Warning", Glyph = "!" },
		Error = { Color = "Error", Glyph = "✕" },
	}

	local CORNERS = {
		BottomRight = {
			Anchor = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Alignment = Enum.VerticalAlignment.Bottom,
			SlideFrom = 1,
		},
		BottomLeft = {
			Anchor = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Alignment = Enum.VerticalAlignment.Bottom,
			SlideFrom = -1,
		},
		TopRight = {
			Anchor = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Alignment = Enum.VerticalAlignment.Top,
			SlideFrom = 1,
		},
		TopLeft = {
			Anchor = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 12),
			Alignment = Enum.VerticalAlignment.Top,
			SlideFrom = -1,
		},
	}

	----------------------------------------------------------------------
	-- Container (created lazily, one per ScreenGui)
	----------------------------------------------------------------------

	function Notification.GetContainer(UI_)
		if UI_.NotificationContainer then
			return UI_.NotificationContainer
		end

		local corner = CORNERS[UI_.NotificationCorner or "BottomRight"]

		local container = Create("Frame", {
			Name = "Notifications",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, Theme.NotificationWidth, 1, -24),
			AnchorPoint = corner.Anchor,
			Position = corner.Position,
			ZIndex = 100,
			Parent = UI_:GetScreenGui(),
		})

		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = corner.Alignment,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = container,
		})

		UI_.NotificationContainer = container
		return container
	end

	----------------------------------------------------------------------
	-- Notification instance
	----------------------------------------------------------------------

	function Notification.New(options)
		options = options or {}

		local self = setmetatable({}, Notification)

		local typeKey = options.Type or "Info"
		local typeInfo = TYPES[typeKey] or TYPES.Info
		local accent = Theme[typeInfo.Color] or Theme.Info

		local container = Notification.GetContainer(UI)
		local corner = CORNERS[UI.NotificationCorner or "BottomRight"]
		local duration = options.Duration or 4

		self.UI = UI
		self.Closing = false
		self.Bin = UI.Util.Bin.new()

		------------------------------------------------------------------
		-- Frame
		------------------------------------------------------------------
		local Frame = Create("Frame", {
			Name = "Notification",
			BackgroundColor3 = Theme.Popup,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 101,
			Parent = container,
		})
		Create.Corner(Theme.CornerRadius, Frame)
		-- Bottom padding keeps the wrapped text clear of the progress bar.
		Create.Padding(0, 0, 0, 12, Frame)
		local stroke = Create.Stroke(Theme.Stroke, 1, Frame, 1)

		-- Left accent bar.
		local AccentBar = Create("Frame", {
			Name = "Accent",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, 5, 0, 6),
			ZIndex = 102,
			Parent = Frame,
		})
		Create.Corner(2, AccentBar)

		-- Glyph badge.
		local Glyph = Create.Label({
			Name = "Glyph",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 18, 0, 18),
			Position = UDim2.new(0, 16, 0, 12),
			Text = typeInfo.Glyph,
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 102,
			Parent = Frame,
		})

		local Title = Create.Label({
			Name = "Title",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -56, 0, 16),
			Position = UDim2.new(0, 40, 0, 10),
			Text = options.Title or "Notification",
			Font = Theme.FontSemibold,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 102,
			Parent = Frame,
		})

		local Content = Create.Label({
			Name = "Content",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -56, 0, 0),
			Position = UDim2.new(0, 40, 0, 30),
			Text = options.Content or options.Text or "",
			Font = Theme.Font,
			TextSize = Theme.SmallTextSize + 1,
			TextColor3 = Theme.TextDim,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 102,
			Parent = Frame,
		})

		-- Keep the content label glued under the (variable height) title.
		-- The frame itself is sized by AutomaticSize, so only the offset
		-- between the two labels needs maintaining here.
		local function reflow()
			Title.Size = UDim2.new(1, -56, 0, 0)
			Content.Position = UDim2.new(0, 40, 0, 10 + Title.AbsoluteSize.Y + 2)
		end

		self.Bin:Add(Title:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow))
		self.Bin:Add(Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow))
		reflow()

		-- Progress bar that drains over the notification's lifetime.
		local ProgressTrack = Create("Frame", {
			Name = "ProgressTrack",
			BackgroundColor3 = Theme.StrokeSoft,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -20, 0, 2),
			Position = UDim2.new(0, 10, 1, -6),
			ZIndex = 102,
			Parent = Frame,
		})
		Create.Corner(1, ProgressTrack)

		local ProgressBar = Create("Frame", {
			Name = "ProgressBar",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 103,
			Parent = ProgressTrack,
		})
		Create.Corner(1, ProgressBar)

		self.Frame = Frame
		self.Title = Title
		self.Content = Content

		------------------------------------------------------------------
		-- Animate in
		------------------------------------------------------------------
		Frame.Position = UDim2.new(0, 40 * corner.SlideFrom, 0, 0)
		Tween.Play(Frame, Tween.Info(0.28), {
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 0,
		})
		Tween.Play(stroke, Tween.Info(0.28), { Transparency = 0 })

		if duration > 0 then
			Tween.Play(ProgressBar, Tween.Info(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(0, 0, 1, 0),
			})

			self.Bin:Add(Env.Delay(duration, function()
				self:Dismiss()
			end))
		else
			ProgressBar.Visible = false
			ProgressTrack.Visible = false
		end

		-- Click to dismiss early.
		local hitArea = Create.Button({
			Name = "HitArea",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 104,
			Parent = Frame,
		})
		self.Bin:Add(hitArea.MouseButton1Click:Connect(function()
			self:Dismiss()
		end))

		table.insert(UI.Notifications, self)
		return self
	end

	Notification.new = Notification.New

	----------------------------------------------------------------------
	-- Dismissal
	----------------------------------------------------------------------

	function Notification:Dismiss()
		if self.Closing then
			return
		end
		self.Closing = true

		local corner = CORNERS[UI.NotificationCorner or "BottomRight"]

		Tween.Cancel(self.Frame)
		Tween.Play(self.Frame, Tween.Info(0.22), {
			Position = UDim2.new(0, 40 * corner.SlideFrom, 0, 0),
			BackgroundTransparency = 1,
		}, function()
			self:Destroy()
		end)
	end

	function Notification:SetTitle(text)
		self.Title.Text = tostring(text or "")
	end

	function Notification:SetContent(text)
		self.Content.Text = tostring(text or "")
	end

	function Notification:Destroy()
		self.Bin:Clean()

		if self.Frame then
			self.Frame:Destroy()
			self.Frame = nil
		end

		for i = #UI.Notifications, 1, -1 do
			if UI.Notifications[i] == self then
				table.remove(UI.Notifications, i)
				break
			end
		end
	end

	----------------------------------------------------------------------
	-- Namespace helpers
	----------------------------------------------------------------------

	function Notification.Install(namespace)
		function namespace:Notify(options)
			options = options or {}
			return Notification.New(options)
		end

		function namespace:SetNotificationCorner(corner)
			if not CORNERS[corner] then
				return
			end
			self.NotificationCorner = corner

			local container = self.NotificationContainer
			if container then
				local info = CORNERS[corner]
				container.AnchorPoint = info.Anchor
				container.Position = info.Position

				local layout = container:FindFirstChildOfClass("UIListLayout")
				if layout then
					layout.VerticalAlignment = info.Alignment
				end
			end
		end

		function namespace:ClearNotifications()
			for i = #self.Notifications, 1, -1 do
				self.Notifications[i]:Destroy()
			end
		end
	end

	UI.Components.Notification = Notification
end

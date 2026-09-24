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
	local Color = UI.Util.Color
	local Tween = UI.Util.Tween
	local Layout = UI.Util.Layout
	local Env = UI.Env

	local Notification = {}
	Notification.__index = Notification

	local TYPES = {
		Info = { Color = "Info", Icon = "Info" },
		Success = { Color = "Success", Icon = "Success" },
		Warning = { Color = "Warning", Icon = "Warning" },
		Error = { Color = "Error", Icon = "Error" },
	}

	-- Card geometry, in pixels.
	--
	-- Every size below is an offset. Nothing inside the card is sized with
	-- a scale: AutomaticSize measures its children to pick the card's
	-- height, so a child sized as a fraction of that height makes the two
	-- depend on each other and Roblox resolves the loop unpredictably --
	-- the status bar and the progress bar end up the wrong length and in
	-- the wrong place. Measuring the text ourselves keeps it deterministic.
	local METRICS = {
		Inset     = 12, -- left/right inset of the content column
		TopInset  = 11, -- card top -> content block
		Accent    = 3, -- status bar width
		AccentGap = 9, -- status bar -> icon badge
		Badge     = 22, -- tinted square behind the emoji
		BadgeGap  = 8, -- icon badge -> text column
		TitleGap  = 3, -- title -> content
		BarGap    = 9, -- content block -> progress bar
		BarHeight = 2,
		BottomPad = 8, -- progress bar -> card bottom
	}

	local TextService = Env.Service("TextService")

	--- Height of `text` in pixels once wrapped to `width`, measured the way
	-- Roblox lays it out. Falls back to a character estimate when
	-- TextService is unavailable, which some executors cause.
	local function measure(text, textSize, font, width)
		if type(text) ~= "string" or text == "" then
			return 0
		end

		if TextService then
			local ok, bounds = pcall(function()
				return TextService:GetTextSize(text, textSize, font, Vector2.new(width, 4096))
			end)
			if ok and bounds then
				return bounds.Y
			end
		end

		local perLine = math.max(1, math.floor(width / (textSize * 0.5)))
		local lines = math.ceil(#text / perLine)
		return lines * (textSize + 4)
	end

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
		-- Pixel width of the card. The container is a fixed-width column and
		-- the card fills it, so resolve it once here: text has to be measured
		-- against a real pixel width, and every child is then sized in
		-- offsets rather than as a fraction of a height we are still working
		-- out.
		local width = container.AbsoluteSize.X
		if not width or width <= 0 then
			width = Theme.NotificationWidth
		end

		local badgeX = METRICS.Inset + METRICS.Accent + METRICS.AccentGap
		local textX = badgeX + METRICS.Badge + METRICS.BadgeGap
		local textWidth = math.max(40, width - textX - METRICS.Inset)
		local titleSize = Theme.TextSize
		local contentSize = Theme.SmallTextSize + 1

		local Frame = Create("Frame", {
			Name = "Notification",
			BackgroundColor3 = Theme.Popup,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 101,
			Parent = container,
		})
		Create.Corner(Theme.CornerRadius, Frame)
		local stroke = Create.Stroke(Theme.Stroke, 1, Frame, 1)

		-- Status bar down the left edge. Spanning exactly the text block
		-- rather than "the card minus a margin" is what makes it line up
		-- with what it is labelling.
		local AccentBar = Create("Frame", {
			Name = "Accent",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, METRICS.Accent, 0, 0),
			Position = UDim2.new(0, METRICS.Inset, 0, METRICS.TopInset),
			ZIndex = 102,
			Parent = Frame,
		})
		Create.Corner(math.max(1, math.floor(METRICS.Accent / 2)), AccentBar)
		UI:BindTheme(AccentBar, "BackgroundColor3", typeInfo.Color)

		-- Tinted badge behind the emoji. Emoji are drawn in colour and
		-- ignore TextColor3, so the status colour has to come from the
		-- backdrop rather than from the glyph itself.
		local Badge = Create("Frame", {
			Name = "Badge",
			BackgroundColor3 = Color.Mix(Theme.Popup, accent, 0.24),
			BorderSizePixel = 0,
			Size = UDim2.new(0, METRICS.Badge, 0, METRICS.Badge),
			Position = UDim2.new(0, METRICS.Inset + METRICS.Accent + METRICS.AccentGap, 0, METRICS.TopInset),
			ZIndex = 102,
			Parent = Frame,
		})
		Create.Corner(math.floor(METRICS.Badge * 0.3), Badge)

		Create.Label({
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = Theme.Icons[typeInfo.Icon] or Theme.Icons.Info,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 103,
			Parent = Badge,
		})

		local Title = Create.Label({
			Name = "Title",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, textWidth, 0, 0),
			Position = UDim2.new(0, textX, 0, METRICS.TopInset),
			Text = options.Title or "Notification",
			Font = Theme.FontSemibold,
			TextSize = titleSize,
			TextColor3 = Theme.Text,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 102,
			Parent = Frame,
		})

		local Content = Create.Label({
			Name = "Content",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, textWidth, 0, 0),
			Position = UDim2.new(0, textX, 0, METRICS.TopInset),
			Text = options.Content or options.Text or "",
			Font = Theme.Font,
			TextSize = contentSize,
			TextColor3 = Theme.TextDim,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 102,
			Parent = Frame,
		})

		-- Progress bar that drains over the notification's lifetime. Inset to
		-- the same margin as the status bar so the two read as one frame.
		local ProgressTrack = Create("Frame", {
			Name = "ProgressTrack",
			BackgroundColor3 = Theme.StrokeSoft,
			BorderSizePixel = 0,
			Size = UDim2.new(0, width - METRICS.Inset * 2, 0, METRICS.BarHeight),
			Position = UDim2.new(0, METRICS.Inset, 0, 0),
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
		UI:BindTheme(ProgressBar, "BackgroundColor3", typeInfo.Color)

		-- Lay the card out from measured text. The title's first line is
		-- centred on the badge, so a title that wraps to two lines still
		-- sits correctly next to it.
		local function layout()
			local titleHeight = measure(Title.Text, titleSize, Theme.FontSemibold, textWidth)
			local contentHeight = measure(Content.Text, contentSize, Theme.Font, textWidth)
			local hasContent = contentHeight > 0

			local blockHeight = titleHeight
			if hasContent then
				blockHeight = blockHeight + METRICS.TitleGap + contentHeight
			end

			-- The title sits on the top inset and the badge is centred on the
			-- title's first line, which can lift it a pixel or two above the
			-- text. Whatever ends up highest is where the block starts.
			local titleY = METRICS.TopInset
			local lineHeight = titleSize + 3
			local badgeY = math.max(4, titleY + math.floor((lineHeight - METRICS.Badge) / 2))
			local blockTop = math.min(titleY, badgeY)
			local blockBottom = math.max(
				METRICS.TopInset + blockHeight,
				badgeY + METRICS.Badge
			)

			Title.Size = UDim2.new(0, textWidth, 0, titleHeight)
			Title.Position = UDim2.new(0, textX, 0, titleY)

			Badge.Position = UDim2.new(0, badgeX, 0, badgeY)

			Content.Visible = hasContent
			Content.Size = UDim2.new(0, textWidth, 0, contentHeight)
			Content.Position = UDim2.new(0, textX, 0, titleY + titleHeight + METRICS.TitleGap)

			-- The bar brackets the block: level with the badge at the top,
			-- flush with the last line of text at the bottom.
			AccentBar.Position = UDim2.new(0, METRICS.Inset, 0, blockTop)
			AccentBar.Size = UDim2.new(0, METRICS.Accent, 0, blockBottom - blockTop)

			local height = blockBottom + METRICS.BarGap + METRICS.BarHeight + METRICS.BottomPad
			Frame.Size = UDim2.new(1, 0, 0, height)
			ProgressTrack.Position = UDim2.new(0, METRICS.Inset, 0, height - METRICS.BottomPad - METRICS.BarHeight)
		end

		self._Layout = layout
		layout()

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
		self:_Layout()
	end

	function Notification:SetContent(text)
		self.Content.Text = tostring(text or "")
		self:_Layout()
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

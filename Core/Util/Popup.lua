--[[
	Core/Util/Popup.lua
	====================================================================
	Floating panels (dropdown lists, colour pickers).

	Popups are parented to a full-screen overlay instead of to the
	element that opened them, otherwise a ScrollingFrame would clip
	them. The popup tracks its host's AbsolutePosition while open, so
	scrolling the page keeps it glued in place, and it flips above the
	host when there is no room below.

	Only one popup is open at a time; clicking anywhere outside closes
	it.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Env = UI.Env

	local Popup = {}
	Popup.__index = Popup

	local openPopups = {}

	----------------------------------------------------------------------
	-- Screen-space helpers
	----------------------------------------------------------------------

	local function screenSize()
		local ok, camera = pcall(function()
			return workspace.CurrentCamera
		end)
		if ok and camera then
			local ok2, size = pcall(function()
				return camera.ViewportSize
			end)
			if ok2 and typeof(size) == "Vector2" and size.X > 0 then
				return size
			end
		end
		return Vector2.new(1920, 1080)
	end

	--- @param host   Instance the popup is anchored to
	-- @param size   Vector2 desired size
	-- @param options { Align = "Right"|"Left", Offset = number, ZIndex, OnOpen, OnClose }
	function Popup.new(host, size, options)
		options = options or {}

		local self = setmetatable({}, Popup)

		self.UI = UI
		self.Host = host
		self.Size = size
		self.Align = options.Align or "Right"
		self.Offset = options.Offset or 4
		self.Open = false
		self.OnOpen = options.OnOpen
		self.OnClose = options.OnClose

		local Frame = Create("Frame", {
			Name = "Popup",
			BackgroundColor3 = Theme.Popup,
			BorderSizePixel = 0,
			Size = UDim2.new(0, size.X, 0, size.Y),
			Position = UDim2.new(0, 0, 0, 0),
			Visible = false,
			BackgroundTransparency = 1,
			ZIndex = options.ZIndex or 200,
			Parent = UI:GetOverlay(),
		})
		Create.Corner(Theme.CornerRadius, Frame)
		local stroke = Create.Stroke(Theme.Stroke, 1, Frame, 1)
		UI:BindTheme(Frame, "BackgroundColor3", "Popup")
		UI:BindTheme(stroke, "Color", "Stroke")

		self.Frame = Frame
		self.Stroke = stroke

		-- Follow the host while the page scrolls or the window moves.
		self.FollowConnection = host:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if self.Open then
				self:Reposition()
			end
		end)

		return self
	end

	function Popup:Reposition()
		if typeof(self.Host) ~= "Instance" then
			return
		end

		local screen = screenSize()
		local hostPos = self.Host.AbsolutePosition
		local hostSize = self.Host.AbsoluteSize
		local width, height = self.Size.X, self.Size.Y

		local x
		if self.Align == "Right" then
			x = hostPos.X + hostSize.X - width
		else
			x = hostPos.X
		end

		x = math.max(8, math.min(x, screen.X - width - 8))

		local y = hostPos.Y + hostSize.Y + self.Offset
		if y + height > screen.Y - 8 then
			-- Not enough room below: flip above the host.
			y = hostPos.Y - height - self.Offset
		end
		y = math.max(8, math.min(y, math.max(8, screen.Y - height - 8)))

		self.Frame.Position = UDim2.new(0, math.floor(x), 0, math.floor(y))
	end

	function Popup:SetOpen(state)
		state = state and true or false
		if self.Open == state then
			return
		end
		self.Open = state

		if state then
			Popup.CloseAll(self)
			table.insert(openPopups, self)

			self:Reposition()
			self.Frame.Visible = true
			Tween.Cancel(self.Frame)
			Tween.Play(self.Frame, Tween.Info(0.16), { BackgroundTransparency = 0 })
			Tween.Play(self.Stroke, Tween.Info(0.16), { Transparency = 0 })

			if self.OnOpen then
				self.OnOpen()
			end
		else
			for i = #openPopups, 1, -1 do
				if openPopups[i] == self then
					table.remove(openPopups, i)
					break
				end
			end

			Tween.Cancel(self.Frame)
			Tween.Play(self.Frame, Tween.Info(0.14), { BackgroundTransparency = 1 }, function()
				if not self.Open then
					self.Frame.Visible = false
				end
			end)
			Tween.Play(self.Stroke, Tween.Info(0.14), { Transparency = 1 })

			if self.OnClose then
				self.OnClose()
			end
		end
	end

	function Popup:Toggle()
		self:SetOpen(not self.Open)
	end

	function Popup:Destroy()
		self:SetOpen(false)

		if self.FollowConnection then
			pcall(function()
				self.FollowConnection:Disconnect()
			end)
			self.FollowConnection = nil
		end

		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	----------------------------------------------------------------------
	-- Registry helpers
	----------------------------------------------------------------------

	function Popup.CloseAll(except)
		for i = #openPopups, 1, -1 do
			local popup = openPopups[i]
			if popup ~= except then
				popup:SetOpen(false)
			end
		end
	end

	function Popup.IsPointInside(frame, point)
		if typeof(frame) ~= "Instance" then
			return false
		end
		local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
		return point.X >= pos.X
			and point.X <= pos.X + size.X
			and point.Y >= pos.Y
			and point.Y <= pos.Y + size.Y
	end

	--- Closes any open popup when the user clicks outside of it.
	function Popup.InstallOutsideClick()
		local uis = Env.UserInputService
		if not uis then
			return
		end

		uis.InputBegan:Connect(function(input)
			if not Env.IsPrimaryInput(input) then
				return
			end
			if #openPopups == 0 then
				return
			end

			local point = Env.MouseLocation()

			for i = #openPopups, 1, -1 do
				local popup = openPopups[i]
				local insidePopup = Popup.IsPointInside(popup.Frame, point)
				local insideHost = Popup.IsPointInside(popup.Host, point)

				if not insidePopup and not insideHost then
					popup:SetOpen(false)
				end
			end
		end)
	end

	UI.Util.Popup = Popup
end

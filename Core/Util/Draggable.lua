--[[
	Core/Util/Draggable.lua
	====================================================================
	Drag behaviour for windows (and anything else with a handle).

	Uses UserInputService deltas rather than mouse-enter/leave so the
	drag survives the cursor leaving the window, keeps a configurable
	screen margin so a window can never be dragged fully off-screen,
	and optionally calls back with the live position.
	====================================================================
]]

return function(UI)
	local Env = UI.Env
	local Color = UI.Util.Color

	local Draggable = {}
	Draggable.__index = Draggable

	--- @param handle Instance  the thing you grab
	-- @param target Instance  the thing that moves
	-- @param options table    { Enabled, Margin, OnDragStart, OnDrag, OnDragEnd, Smooth }
	function Draggable.new(handle, target, options)
		options = options or {}

		local self = setmetatable({
			Handle = handle,
			Target = target,
			Enabled = options.Enabled ~= false,
			Margin = options.Margin or 4,
			Smooth = options.Smooth == true,
			OnDragStart = options.OnDragStart,
			OnDrag = options.OnDrag,
			OnDragEnd = options.OnDragEnd,
			Dragging = false,
			Connections = {},
		}, Draggable)

		self:_bind()
		return self
	end

	function Draggable:_bind()
		local uis = Env.UserInputService
		if not uis then
			return
		end

		local handle, target = self.Handle, self.Target
		local dragStart, startPosition

		table.insert(self.Connections, handle.InputBegan:Connect(function(input)
			if not self.Enabled then
				return
			end
			if not Env.IsPrimaryInput(input) then
				return
			end

			self.Dragging = true
			dragStart = input.Position
			startPosition = target.Position

			if self.OnDragStart then
				self.OnDragStart()
			end
		end))

		table.insert(self.Connections, uis.InputChanged:Connect(function(input)
			if not self.Dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local delta = input.Position - dragStart
			local viewport = self:_viewport()
			local absolute = target.AbsoluteSize

			-- Clamp so at least `Margin` pixels stay on screen.
			local maxX = viewport.X - absolute.X - self.Margin
			local maxY = viewport.Y - absolute.Y - self.Margin

			local x = Color.Clamp(startPosition.X.Offset + delta.X, self.Margin, math.max(self.Margin, maxX))
			local y = Color.Clamp(startPosition.Y.Offset + delta.Y, self.Margin, math.max(self.Margin, maxY))

			target.Position = UDim2.new(0, x, 0, y)

			if self.OnDrag then
				self.OnDrag(x, y)
			end
		end))

		table.insert(self.Connections, uis.InputEnded:Connect(function(input)
			if not self.Dragging then
				return
			end
			if not Env.IsPrimaryInput(input) then
				return
			end

			self.Dragging = false

			if self.OnDragEnd then
				self.OnDragEnd(target.Position)
			end
		end))
	end

	function Draggable:_viewport()
		local ok, size = pcall(function()
			local camera = workspace.CurrentCamera
			return camera and camera.ViewportSize or nil
		end)

		if ok and typeof(size) == "Vector2" and size.X > 0 then
			return size
		end

		local uis = Env.UserInputService
		if uis then
			local ok2, screen = pcall(function()
				return uis:GetScreenResolution()
			end)
			if ok2 and typeof(screen) == "Vector2" and screen.X > 0 then
				return screen
			end
		end

		return Vector2.new(1920, 1080)
	end

	function Draggable:SetEnabled(enabled)
		self.Enabled = enabled and true or false
		if not enabled then
			self.Dragging = false
		end
	end

	function Draggable:Destroy()
		for i = #self.Connections, 1, -1 do
			local connection = self.Connections[i]
			pcall(function()
				connection:Disconnect()
			end)
			self.Connections[i] = nil
		end
	end

	UI.Util.Draggable = Draggable
end

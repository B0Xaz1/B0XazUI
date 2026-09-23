--[[
	Core/Util/Layout.lua
	====================================================================
	Small helpers for the two problems every Roblox UI hits:

	  1. "make this frame as tall as its children"
	  2. "make this scrolling frame's canvas match its content"

	Both are solved by watching the UIListLayout's AbsoluteContentSize.
	====================================================================
]]

return function(UI)
	local Layout = {}

	--- Keeps `frame` sized to the content of `listLayout` (+ padding).
	-- Returns a function that forces an update, and registers the
	-- connection in `bin` if one is provided.
	function Layout.BindContentSize(listLayout, frame, extraPadding, bin)
		extraPadding = extraPadding or 0

		local function update()
			if typeof(listLayout) ~= "Instance" or typeof(frame) ~= "Instance" then
				return
			end

			local ok, contentSize = pcall(function()
				return listLayout.AbsoluteContentSize
			end)

			if not ok or typeof(contentSize) ~= "Vector2" then
				return
			end

			frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, contentSize.Y + extraPadding)
		end

		local connection
		if typeof(listLayout) == "Instance" then
			local ok = pcall(function()
				connection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
			end)
			if not ok then
				connection = nil
			end
		end

		if connection and bin then
			bin:Add(connection)
		end

		update()
		return update
	end

	--- Keeps a ScrollingFrame's CanvasSize in sync with its content.
	function Layout.BindCanvasSize(scrollingFrame, listLayout, extraPadding, bin)
		extraPadding = extraPadding or 0

		local function update()
			if typeof(listLayout) ~= "Instance" or typeof(scrollingFrame) ~= "Instance" then
				return
			end

			local ok, contentSize = pcall(function()
				return listLayout.AbsoluteContentSize
			end)

			if not ok or typeof(contentSize) ~= "Vector2" then
				return
			end

			scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + extraPadding)
		end

		local connection
		if typeof(listLayout) == "Instance" then
			local ok = pcall(function()
				connection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
			end)
			if not ok then
				connection = nil
			end
		end

		if connection and bin then
			bin:Add(connection)
		end

		update()
		return update
	end

	--- Horizontal counterpart of BindCanvasSize (used by the tab bar).
	function Layout.BindCanvasSizeHorizontal(scrollingFrame, listLayout, extraPadding, bin)
		extraPadding = extraPadding or 0

		local function update()
			if typeof(listLayout) ~= "Instance" or typeof(scrollingFrame) ~= "Instance" then
				return
			end

			local ok, contentSize = pcall(function()
				return listLayout.AbsoluteContentSize
			end)

			if not ok or typeof(contentSize) ~= "Vector2" then
				return
			end

			scrollingFrame.CanvasSize = UDim2.new(0, contentSize.X + extraPadding, 0, 0)
		end

		local connection
		if typeof(listLayout) == "Instance" then
			local ok = pcall(function()
				connection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
			end)
			if not ok then
				connection = nil
			end
		end

		if connection and bin then
			bin:Add(connection)
		end

		update()
		return update
	end

	--- Measures text so we can auto-size tab buttons and labels.
	-- Falls back to a per-character estimate when TextService is absent.
	function Layout.GetTextBounds(text, font, textSize, maxWidth)
		text = tostring(text or "")
		font = font or UI.Theme.Font
		textSize = textSize or UI.Theme.TextSize

		local textService = UI.Env.TextService
		if textService and typeof(textService.GetTextSize) == "function" then
			local ok, bounds = pcall(function()
				return textService:GetTextSize(
					text,
					textSize,
					font,
					maxWidth or Vector2.new(math.huge, math.huge)
				)
			end)
			if ok and typeof(bounds) == "Vector2" then
				return bounds
			end
		end

		-- Estimate: Roblox's default face averages ~0.52x the font size
		-- per character at these sizes.
		local width = math.ceil(#text * textSize * 0.52)
		if maxWidth and maxWidth.X and maxWidth.X < math.huge then
			width = math.min(width, maxWidth.X)
		end
		return Vector2.new(width, textSize + 4)
	end

	--- Rounds a UDim2 offset pair into a clean pixel size.
	function Layout.Pixels(width, height)
		return UDim2.new(0, math.floor(width or 0), 0, math.floor(height or 0))
	end

	UI.Util.Layout = Layout
end

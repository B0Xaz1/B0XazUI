--[[
	Core/Util/Create.lua
	====================================================================
	Instance factory. Roblox's Instance.new is slow and verbose, and
	setting Parent first forces the engine to lay out half-built
	instances. So: build the object, apply properties, attach children,
	parent LAST.

		Create("Frame", {
			Name = "Root",
			Size = UDim2.new(1, 0, 0, 30),
			Children = { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) },
		}, parent)
	====================================================================
]]

return function(UI)
	local Create = {}

	--- Creates an instance, applies props, attaches children, sets Parent.
	-- `props` may contain:
	--   Parent      - applied LAST
	--   Children    - array of instances, parented to the new instance
	--   Attributes  - table of instance attributes
	function Create.New(className, props, parent)
		props = props or {}

		local instance = Instance.new(className)

		local children = props.Children
		local attributes = props.Attributes

		for property, value in pairs(props) do
			if property ~= "Parent" and property ~= "Children" and property ~= "Attributes" then
				instance[property] = value
			end
		end

		if type(attributes) == "table" then
			for name, value in pairs(attributes) do
				pcall(function()
					instance:SetAttribute(name, value)
				end)
			end
		end

		if type(children) == "table" then
			for i = 1, #children do
				if typeof(children[i]) == "Instance" then
					children[i].Parent = instance
				end
			end
		end

		instance.Parent = props.Parent or parent
		return instance
	end

	-- Create is callable: Create("Frame", {...}) == Create.New("Frame", {...})
	setmetatable(Create, {
		__call = function(_, className, props, parent)
			return Create.New(className, props, parent)
		end,
	})

	----------------------------------------------------------------------
	-- Shorthand decorators
	----------------------------------------------------------------------

	function Create.Corner(radius, parent)
		return Create.New("UICorner", {
			CornerRadius = typeof(radius) == "number" and UDim.new(0, radius) or radius,
			Parent = parent,
		})
	end

	function Create.Stroke(color, thickness, parent, transparency)
		return Create.New("UIStroke", {
			Color = color,
			Thickness = thickness or 1,
			Transparency = transparency or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = parent,
		})
	end

	--- Create.Padding(8, parent) pads every side;
	-- Create.Padding(left, right, top, bottom, parent) pads per-side.
	function Create.Padding(left, right, top, bottom, parent)
		if right == nil and top == nil and bottom == nil then
			right, top, bottom = left, left, left
		end

		return Create.New("UIPadding", {
			PaddingLeft = UDim.new(0, tonumber(left) or 0),
			PaddingRight = UDim.new(0, tonumber(right) or 0),
			PaddingTop = UDim.new(0, tonumber(top) or 0),
			PaddingBottom = UDim.new(0, tonumber(bottom) or 0),
			Parent = parent,
		})
	end

	--- Vertical list layout with uniform spacing.
	function Create.List(spacing, parent, alignment)
		return Create.New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, spacing or 0),
			Parent = parent,
		})
	end

	--- Horizontal row layout.
	function Create.Row(spacing, parent, alignment)
		return Create.New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, spacing or 0),
			Parent = parent,
		})
	end

	----------------------------------------------------------------------
	-- Text helpers
	----------------------------------------------------------------------

	function Create.Label(props, parent)
		props = props or {}
		props.Text = props.Text or ""
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.Font = props.Font or UI.Theme.Font
		props.TextSize = props.TextSize or UI.Theme.TextSize
		props.TextColor3 = props.TextColor3 or UI.Theme.Text
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		return Create.New("TextLabel", props, parent)
	end

	function Create.Button(props, parent)
		props = props or {}
		props.Text = props.Text or ""
		props.Font = props.Font or UI.Theme.Font
		props.TextSize = props.TextSize or UI.Theme.TextSize
		props.TextColor3 = props.TextColor3 or UI.Theme.Text
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.AutoButtonColor = false
		return Create.New("TextButton", props, parent)
	end

	--- Applies the standard "clickable" interaction (hover in/out) to a
	-- button and returns the connections.
	function Create.Interactive(button, options)
		options = options or {}
		local normal = options.Normal
		local hover = options.Hover
		local onChange = options.OnChanged

		local function paint(color)
			if not color then
				return
			end
			if onChange then
				onChange(color)
			else
				button.BackgroundColor3 = color
			end
		end

		local connections = {}

		table.insert(connections, button.MouseEnter:Connect(function()
			paint(hover)
		end))

		table.insert(connections, button.MouseLeave:Connect(function()
			paint(normal)
		end))

		-- Covers the case where the pointer leaves while the button is
		-- removed, or a dropdown closes under the cursor.
		table.insert(connections, button.MouseButton1Up:Connect(function()
			paint(hover)
		end))

		paint(normal)
		return connections
	end

	UI.Util.Create = Create
end

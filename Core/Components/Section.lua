--[[
	Core/Components/Section.lua
	====================================================================
	A collapsible group of elements inside a tab page.

	+--------------------------------------------+
	|  SECTION TITLE                          v  |  header
	+--------------------------------------------+
	|  [ element ]                               |  body (auto height)
	|  [ element ]                               |
	+--------------------------------------------+

	Sections expose the element constructors. Every element module
	registers itself on UI.Elements, and Section forwards to it, so
	adding a new element type needs no change here -- see AddElement.
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Tween = UI.Util.Tween
	local Layout = UI.Util.Layout

	local Section = {}
	Section.__index = Section

	function Section.New(tab, config)
		config = config or {}

		local self = setmetatable({}, Section)

		self.UI = UI
		self.Tab = tab
		self.Title = config.Title or "Section"
		self.Elements = {}
		self.Expanded = config.Collapsed ~= true
		self.Bin = UI.Util.Bin.new()

		------------------------------------------------------------------
		-- Outer frame (auto height: header + body)
		------------------------------------------------------------------
		local Frame = Create("Frame", {
			Name = self.Title,
			BackgroundColor3 = Theme.Section,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 1,
			Parent = tab.Page,
		})
		Create.Corner(Theme.CornerRadius, Frame)
		local stroke = Create.Stroke(Theme.StrokeSoft, 1, Frame)
		UI:BindTheme(Frame, "BackgroundColor3", "Section")
		UI:BindTheme(stroke, "Color", "StrokeSoft")

		-- Column: header, then body.
		local Column = Create.List(0, Frame)

		------------------------------------------------------------------
		-- Header
		------------------------------------------------------------------
		local Header = Create.Button({
			Name = "Header",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Theme.SectionHeaderHeight),
			Text = "",
			ZIndex = 2,
			Parent = Frame,
		})

		local HeaderLabel = Create.Label({
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -34, 1, 0),
			Position = UDim2.new(0, Theme.ElementPadding, 0, 0),
			Text = self.Title,
			Font = Theme.FontSemibold,
			TextSize = Theme.SectionTextSize,
			TextColor3 = Theme.Text,
			ZIndex = 3,
			Parent = Header,
		})
		UI:BindTheme(HeaderLabel, "TextColor3", "Text")

		local Chevron = Create.Label({
			Name = "Chevron",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 24, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Text = self.Expanded and Theme.Icons.Expand or Theme.Icons.Collapse,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = Header,
		})

		------------------------------------------------------------------
		-- Body
		------------------------------------------------------------------
		local Body = Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Visible = self.Expanded,
			ZIndex = 2,
			Parent = Frame,
		})
		Create.Padding(
			Theme.ElementPadding,
			Theme.ElementPadding,
			0,
			Theme.ElementPadding,
			Body
		)

		local bodyLayout = Create.List(Theme.ElementSpacing, Body)

		self.Frame = Frame
		self.Header = Header
		self.HeaderLabel = HeaderLabel
		self.Chevron = Chevron
		self.Body = Body
		self.BodyLayout = bodyLayout

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Header.MouseButton1Click:Connect(function()
			self:SetExpanded(not self.Expanded)
		end))

		self.Bin:Add(Header.MouseEnter:Connect(function()
			Tween.Fast(HeaderLabel, { TextColor3 = Theme.Text })
			Tween.Fast(Chevron, { TextColor3 = Theme.Text })
		end))

		self.Bin:Add(Header.MouseLeave:Connect(function()
			Tween.Fast(HeaderLabel, { TextColor3 = Theme.Text })
			Tween.Fast(Chevron, { TextColor3 = Theme.TextDim })
		end))

		return self
	end

	Section.new = Section.New

	----------------------------------------------------------------------
	-- Element plumbing
	----------------------------------------------------------------------

	--- Parents an element frame into the section body and tracks the
	-- element object so the section can destroy / iterate them.
	function Section:AddElement(elementFrame, elementObject)
		elementFrame.Parent = self.Body

		if elementObject then
			table.insert(self.Elements, elementObject)
		end

		return elementObject or elementFrame
	end

	--- Generic constructor: Section:Add("Toggle", { Name = "..." })
	function Section:Add(elementType, config)
		local element = UI.Elements[elementType]
		if not element or typeof(element.New) ~= "function" then
			error(string.format(
				"[B0XazUI] Unknown element type %q. Available: %s",
				tostring(elementType),
				table.concat(UI:ListElements(), ", ")
			), 2)
		end
		return element.New(self, config or {})
	end

	----------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------

	function Section:SetExpanded(expanded)
		self.Expanded = expanded and true or false
		self.Body.Visible = self.Expanded
		self.Chevron.Text = self.Expanded and Theme.Icons.Expand or Theme.Icons.Collapse
	end

	function Section:SetTitle(title)
		self.Title = tostring(title or "Section")
		self.HeaderLabel.Text = self.Title
		self.Frame.Name = self.Title
	end

	function Section:Clear()
		for i = #self.Elements, 1, -1 do
			if typeof(self.Elements[i].Destroy) == "function" then
				self.Elements[i]:Destroy()
			end
		end
		self.Elements = {}
	end

	function Section:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Section:Destroy()
		for i = #self.Elements, 1, -1 do
			if typeof(self.Elements[i].Destroy) == "function" then
				pcall(function()
					self.Elements[i]:Destroy()
				end)
			end
		end
		self.Elements = {}

		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)

		local tab = self.Tab
		if tab then
			for i = #tab.Sections, 1, -1 do
				if tab.Sections[i] == self then
					table.remove(tab.Sections, i)
					break
				end
			end
		end

		self.Frame:Destroy()
	end

	UI.Components.Section = Section
end

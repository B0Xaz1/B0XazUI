--[[
	Core/Components/Section.lua
	====================================================================
	A collapsible group of elements inside a tab column, drawn the way
	the original design draws it: not a header bar but a fieldset. The
	box gets a one-pixel outline and its title sits ON the top border,
	a background-coloured patch cutting the line behind the text:

	     title                             <- patch covers the border
	  --+-------+--------------------------------------
	  |                                             |
	  |  [ element ]                                |  box (auto height)
	  |  [ element ]                                |
	  +---------------------------------------------+

	Layout trick, in case it needs touching: the section frame is a
	vertical list of [Strut, Box]. The Strut is exactly half the title
	height (7px), and the title button inside it is 14px tall starting
	at its top edge -- so the text straddles the box border below. The
	Strut has no list layout of its own, which is how the title gets to
	keep its hand-made position.

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

		local titleHalf = math.ceil(Theme.SectionTitleHeight / 2)

		-- Parent is the column the section was created for.
		local container = tab.Columns[config.Column or 1] or tab.Columns[1] or tab.Page

		------------------------------------------------------------------
		-- Outer frame: vertical list of [strut, box]
		------------------------------------------------------------------
		local Frame = Create("Frame", {
			Name = self.Title,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 1,
			Parent = container,
		})
		Create.List(0, Frame)

		------------------------------------------------------------------
		-- Strut + title patch (the legend on the border)
		------------------------------------------------------------------
		local Strut = Create("Frame", {
			Name = "Strut",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, titleHalf),
			ZIndex = 3,
			Parent = Frame,
		})

		-- Full title height (14) hanging off the top edge of the strut,
		-- so its lower half overlaps the box border.
		local Header = Create.Button({
			Name = "Header",
			BackgroundColor3 = Theme.Background,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, Theme.SectionTitleHeight),
			Position = UDim2.new(0, Theme.SectionInset - Theme.SectionPatchPad, 0, 0),
			Text = self.Title,
			Font = Theme.Font,
			TextSize = Theme.SectionTextSize,
			TextColor3 = Theme.TextDim,
			ZIndex = 6,
			Parent = Strut,
		})
		Create.Padding(Theme.SectionPatchPad, Theme.SectionPatchPad, 0, 0, Header)
		UI:BindTheme(Header, "BackgroundColor3", "Background")
		UI:BindTheme(Header, "TextColor3", "TextDim")

		------------------------------------------------------------------
		-- Box: the outlined fieldset body
		------------------------------------------------------------------
		local Box = Create("Frame", {
			Name = "Box",
			LayoutOrder = 2,
			BackgroundColor3 = Theme.Section,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 2,
			Parent = Frame,
		})
		if Theme.CornerRadius > 0 then
			Create.Corner(Theme.CornerRadius, Box)
		end
		local boxStroke = Create.Stroke(Theme.Stroke, 1, Box)
		UI:BindTheme(Box, "BackgroundColor3", "Section")
		UI:BindTheme(boxStroke, "Color", "Stroke")

		-- Top padding: the title's lower half + a little air.
		Create.Padding(
			Theme.SectionInset,
			Theme.SectionInset,
			titleHalf + 4,
			Theme.SectionInset - 1,
			Box
		)
		Create.List(0, Box)

		local Body = Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Visible = self.Expanded,
			ZIndex = 3,
			Parent = Box,
		})
		Create.List(Theme.ElementSpacing, Body, Enum.HorizontalAlignment.Left)

		self.Frame = Frame
		self.Strut = Strut
		self.Header = Header
		self.HeaderLabel = Header -- the button IS the title text
		self.Box = Box
		self.BoxStroke = boxStroke
		self.Body = Body

		------------------------------------------------------------------
		-- Interaction
		------------------------------------------------------------------
		self.Bin:Add(Header.MouseButton1Click:Connect(function()
			self:SetExpanded(not self.Expanded)
		end))

		self.Bin:Add(Header.MouseEnter:Connect(function()
			Tween.Fast(Header, { TextColor3 = Theme.Text })
		end))

		self.Bin:Add(Header.MouseLeave:Connect(function()
			Tween.Fast(Header, { TextColor3 = Theme.TextDim })
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
	end

	function Section:SetTitle(title)
		self.Title = tostring(title or "Section")
		self.Header.Text = self.Title
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

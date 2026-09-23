--[[
	Core/Elements/Label.lua
	====================================================================
	Static (or updated) text block. Wraps automatically and grows the
	section as needed.

		Section:AddLabel({
			Text  = "Explanatory copy goes here.",
			Style = "Dim",   -- Text | Dim | Faint | Accent
		})
	====================================================================
]]

return function(UI)
	local Theme = UI.Theme
	local Create = UI.Util.Create
	local Layout = UI.Util.Layout

	local Label = {}
	Label.__index = Label

	local STYLES = {
		Text = "Text",
		Default = "Text",
		Dim = "TextDim",
		Muted = "TextDim",
		Faint = "TextFaint",
		Accent = "Accent",
	}

	function Label.New(section, config)
		config = config or {}

		local self = setmetatable({}, Label)

		self.UI = UI
		self.Section = section
		self.Name = config.Name or "Label"
		self.Type = "Label"
		self.Bin = UI.Util.Bin.new()

		local styleKey = STYLES[config.Style or "Text"] or "Text"
		local bold = config.Bold == true

		local Frame = Create("Frame", {
			Name = self.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 1,
		})
		Create.Padding(0, 0, config.PaddingTop or 0, config.PaddingBottom or 0, Frame)

		local TextLabel = Create.Label({
			Name = "Text",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, config.Height or 0),
			Position = UDim2.new(0, 0, 0, 0),
			Text = tostring(config.Text or ""),
			Font = bold and Theme.FontSemibold or Theme.Font,
			TextSize = config.TextSize or Theme.TextSize,
			TextColor3 = Theme[styleKey],
			TextWrapped = config.Wrapped ~= false,
			TextXAlignment = config.Align or Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = config.RichText == true,
			ZIndex = 2,
			Parent = Frame,
		})
		UI:BindTheme(TextLabel, "TextColor3", styleKey)

		self.Frame = Frame
		self.TextLabel = TextLabel
		self.Value = TextLabel.Text

		section:AddElement(Frame, self)
		return self
	end

	Label.new = Label.New

	function Label:SetText(text)
		self.TextLabel.Text = tostring(text or "")
		self.Value = self.TextLabel.Text
	end

	function Label:GetText()
		return self.TextLabel.Text
	end

	--- Aliases so labels share the element vocabulary.
	Label.SetValue = Label.SetText
	Label.GetValue = Label.GetText

	function Label:SetStyle(style)
		local styleKey = STYLES[style or "Text"] or "Text"
		UI:RebindTheme(self.TextLabel, "TextColor3", styleKey)
	end

	function Label:SetVisible(visible)
		self.Frame.Visible = visible and true or false
	end

	function Label:Destroy()
		self.Bin:Clean()
		UI:UnbindTheme(self.Frame)
		self.Frame:Destroy()
	end

	UI.Elements.Label = Label
end

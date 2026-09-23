--[[
	Core/Theme.lua
	====================================================================
	Single source of truth for every colour, font and metric used by
	the engine. Edit this file (or call UI:SetTheme) to reskin
	everything at once -- no element hardcodes a colour.

	Colours are grouped:
		Surfaces   window / topbar / tabbar / section / element
		Borders    strokes and dividers
		Text       primary, dim, inverted
		Accent     the interactive highlight
		Status     notification semantics

	Metrics are in pixels and are used for sizing + padding.
	====================================================================
]]

return function(UI)
	local Theme = {
		Name = "Midnight",

		------------------------------------------------------------------
		-- Fonts
		------------------------------------------------------------------
		Font = Enum.Font.Gotham,
		FontMedium = Enum.Font.GothamMedium,
		FontSemibold = Enum.Font.GothamSemibold,
		FontBold = Enum.Font.GothamBold,
		FontMono = Enum.Font.Code,

		------------------------------------------------------------------
		-- Surfaces
		------------------------------------------------------------------
		Background = Color3.fromRGB(18, 18, 24),
		Topbar = Color3.fromRGB(24, 24, 32),
		TabBar = Color3.fromRGB(21, 21, 29),
		TabActive = Color3.fromRGB(30, 30, 41),
		TabHover = Color3.fromRGB(27, 27, 36),
		Section = Color3.fromRGB(25, 25, 33),
		SectionHeader = Color3.fromRGB(25, 25, 33),
		Element = Color3.fromRGB(32, 32, 43),
		ElementHover = Color3.fromRGB(40, 40, 54),
		ElementActive = Color3.fromRGB(46, 46, 62),
		Input = Color3.fromRGB(15, 15, 20),
		Popup = Color3.fromRGB(27, 27, 36),

		------------------------------------------------------------------
		-- Borders
		------------------------------------------------------------------
		Stroke = Color3.fromRGB(47, 47, 62),
		StrokeSoft = Color3.fromRGB(38, 38, 50),
		Divider = Color3.fromRGB(40, 40, 53),

		------------------------------------------------------------------
		-- Text
		------------------------------------------------------------------
		Text = Color3.fromRGB(226, 226, 238),
		TextDim = Color3.fromRGB(146, 146, 168),
		TextFaint = Color3.fromRGB(108, 108, 130),
		TextOnAccent = Color3.fromRGB(255, 255, 255),

		------------------------------------------------------------------
		-- Accent
		------------------------------------------------------------------
		Accent = Color3.fromRGB(88, 140, 255),
		AccentHover = Color3.fromRGB(104, 154, 255),
		AccentDark = Color3.fromRGB(62, 104, 200),
		AccentSoft = Color3.fromRGB(88, 140, 255),

		------------------------------------------------------------------
		-- Status (notifications + keybind states)
		------------------------------------------------------------------
		Info = Color3.fromRGB(88, 140, 255),
		Success = Color3.fromRGB(64, 196, 132),
		Warning = Color3.fromRGB(240, 178, 62),
		Error = Color3.fromRGB(232, 82, 82),

		------------------------------------------------------------------
		-- Misc surfaces
		------------------------------------------------------------------
		Scrollbar = Color3.fromRGB(58, 58, 76),
		SliderTrack = Color3.fromRGB(20, 20, 27),
		ToggleOff = Color3.fromRGB(58, 58, 76),
		ToggleKnob = Color3.fromRGB(238, 238, 246),
		Shadow = Color3.fromRGB(0, 0, 0),

		------------------------------------------------------------------
		-- Metrics
		------------------------------------------------------------------
		CornerRadius = 8,
		ElementCornerRadius = 6,

		WindowPadding = 0,
		TopbarHeight = 38,
		TabBarHeight = 36,
		TabPadding = 4,

		SectionPadding = 8,
		SectionHeaderHeight = 30,
		SectionSpacing = 8,

		ElementHeight = 30,
		ElementSpacing = 6,
		ElementPadding = 10,

		TextSize = 13,
		TitleTextSize = 14,
		SectionTextSize = 13,
		SmallTextSize = 11,

		TweenSpeed = 0.18,
		TweenSpeedFast = 0.1,

		NotificationWidth = 300,
		NotificationPadding = 12,
	}

	UI.Theme = Theme

	-- Fast, frictionless overrides: UI:SetTheme({ Accent = Color3.fromRGB(...) })
	-- Only touches the palette; call UI:RefreshTheme() to repaint live UI.
	UI.SetThemeDefaults = function(_, overrides)
		if type(overrides) ~= "table" then
			return
		end
		for key, value in pairs(overrides) do
			Theme[key] = value
		end
	end
end

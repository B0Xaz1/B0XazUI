--[[
	Core/Theme.lua
	====================================================================
	Single source of truth for every colour, font and metric used by
	the engine. Edit this file (or call UI:SetTheme) to reskin
	everything at once -- no element hardcodes a colour.

	The default skin is "Abyss": the classic skeet-inspired look the
	engine was designed for -- square corners, one-pixel borders in a
	muted indigo, tiny text, a blurple accent, and sections whose
	title sits on their top border.

	Colours are grouped:
		Surfaces   window / topbar / tabbar / section / element / input
		Borders    strokes and dividers
		Text       primary, dim, inverted
		Accent     the interactive highlight
		Status     notification semantics

	Metrics are in pixels and are used for sizing + padding.
	====================================================================
]]

return function(UI)
	local Theme = {
		Name = "Abyss",

		------------------------------------------------------------------
		-- Fonts
		------------------------------------------------------------------
		-- The reference design is set in a tiny bitmap face. Roblox has
		-- no pixel font, so the closest built-in is the monospace one:
		-- it keeps the measured, terminal-like rhythm of the original.
		Font = Enum.Font.Code,
		FontMedium = Enum.Font.Code,
		FontSemibold = Enum.Font.Code,
		FontBold = Enum.Font.Code,
		FontMono = Enum.Font.Code,

		------------------------------------------------------------------
		-- Icons
		------------------------------------------------------------------
		-- Window chrome and disclosure glyphs are plain ASCII: every
		-- Roblox font renders them, and "-"/"+" is exactly what the
		-- original design uses.
		--
		-- Notification type icons stay emoji: they draw in colour via
		-- the platform emoji font, and they sit on a tinted backdrop
		-- (TextColor3 cannot tint an emoji).
		Icons = {
			-- Notification types
			Info     = "ℹ️", -- U+2139 U+FE0F
			Success  = "✅", -- U+2705
			Warning  = "⚠️", -- U+26A0 U+FE0F
			Error    = "❌", -- U+274C

			-- Window controls
			Minimize = "-",
			Maximize = "+",
			Restore  = "+",
			Close    = "x",

			-- Disclosure / direction
			Expand   = "-",
			Collapse = "+",
			Up       = "-",
			Down     = "+",

			-- Selection
			Check    = "x",
		},

		------------------------------------------------------------------
		-- Surfaces
		------------------------------------------------------------------
		Background = Color3.fromRGB(20, 20, 24), -- window body + section interior
		Topbar = Color3.fromRGB(15, 15, 18),
		TabBar = Color3.fromRGB(16, 16, 20),
		TabActive = Color3.fromRGB(25, 25, 31),
		TabHover = Color3.fromRGB(21, 21, 26),
		Section = Color3.fromRGB(20, 20, 24), -- must match Background (title patch)
		SectionHeader = Color3.fromRGB(20, 20, 24),
		Element = Color3.fromRGB(26, 26, 32), -- button fill
		ElementHover = Color3.fromRGB(32, 32, 40),
		ElementActive = Color3.fromRGB(38, 38, 48),
		Input = Color3.fromRGB(12, 12, 15), -- inset boxes: dropdown, slider track, chips
		Popup = Color3.fromRGB(19, 19, 24),

		------------------------------------------------------------------
		-- Borders
		------------------------------------------------------------------
		Stroke = Color3.fromRGB(62, 60, 86), -- window / section / box outlines
		StrokeSoft = Color3.fromRGB(45, 44, 63), -- inputs, chips, checkboxes
		Divider = Color3.fromRGB(38, 37, 55),

		------------------------------------------------------------------
		-- Text
		------------------------------------------------------------------
		Text = Color3.fromRGB(207, 207, 222),
		TextDim = Color3.fromRGB(148, 148, 168),
		TextFaint = Color3.fromRGB(100, 100, 122),
		TextOnAccent = Color3.fromRGB(240, 240, 250),

		------------------------------------------------------------------
		-- Accent
		------------------------------------------------------------------
		Accent = Color3.fromRGB(122, 126, 214), -- the blurple of the reference
		AccentHover = Color3.fromRGB(138, 142, 228),
		AccentDark = Color3.fromRGB(93, 96, 172),
		AccentSoft = Color3.fromRGB(139, 143, 228), -- active label text

		------------------------------------------------------------------
		-- Status (notifications + keybind states)
		------------------------------------------------------------------
		Info = Color3.fromRGB(122, 126, 214),
		Success = Color3.fromRGB(95, 188, 135),
		Warning = Color3.fromRGB(236, 180, 82),
		Error = Color3.fromRGB(232, 90, 92),

		------------------------------------------------------------------
		-- Misc surfaces
		------------------------------------------------------------------
		Scrollbar = Color3.fromRGB(58, 58, 76),
		SliderTrack = Color3.fromRGB(12, 12, 15),
		ToggleOff = Color3.fromRGB(12, 12, 15), -- unchecked checkbox inset
		ToggleKnob = Color3.fromRGB(122, 126, 214), -- checked checkbox fill
		Chip = Color3.fromRGB(12, 12, 15), -- key chip background
		ChipText = Color3.fromRGB(154, 154, 176),
		Shadow = Color3.fromRGB(0, 0, 0),

		------------------------------------------------------------------
		-- Metrics
		------------------------------------------------------------------
		CornerRadius = 0,
		ElementCornerRadius = 0,

		WindowPadding = 0,
		TopbarHeight = 24, -- the title strip
		TabBarHeight = 26,
		TabPadding = 10, -- horizontal padding inside a tab button

		ContentPadding = 10, -- page edge -> columns
		ColumnSpacing = 10,

		SectionSpacing = 10, -- between sections in a column
		SectionTitleHeight = 14, -- title slot; half of it sits above the box
		SectionInset = 10, -- box border -> elements
		SectionPatchPad = 4, -- horizontal background patch around the title

		ElementHeight = 18, -- rows (toggle, keybind, colour row)
		ElementSpacing = 6,
		ElementPadding = 10,

		LabelRowHeight = 13, -- the dim label above sliders / dropdowns
		BoxHeight = 18, -- dropdown / textbox boxes
		SliderBarHeight = 14,
		CheckboxSize = 11,
		ChipHeight = 14, -- key-chip boxes like [ M2 ]
		ChipPaddingX = 5,
		SwatchWidth = 26, -- colour swatch block
		SwatchHeight = 12,

		TextSize = 12,
		TitleTextSize = 12,
		SectionTextSize = 12,
		SmallTextSize = 11,

		TweenSpeed = 0.12,
		TweenSpeedFast = 0.06,

		NotificationWidth = 260,
		NotificationPadding = 10,

		AccentStripHeight = 2, -- the blurple line along the window's bottom edge
		AccentGlowHeight = 8, -- faint glow that fades up from the strip
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

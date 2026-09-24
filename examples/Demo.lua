--[[
	examples/Demo.lua
	====================================================================
	Every element B0XazUI ships with, wired up the way a real script
	would use it. Runs as-is in an executor, and also runs inside the
	mocked environment (see tests/run.js) which is how we know the
	documented API is the API that actually works.

	Executor usage:

		loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/B0Xaz1/B0XazUI/main/examples/Demo.lua"
		))()
	====================================================================
]]

local B0XazUI = _G.B0XazUI

if not B0XazUI then
	B0XazUI = loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/B0Xaz1/B0XazUI/main/init.lua"
	))()
end

local UI = B0XazUI:Load()

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------

local Window = UI:CreateWindow({
	Title = "B0XazUI",
	SubTitle = "v" .. B0XazUI.Version,
	Size = Vector2.new(620, 460),
	ToggleKey = Enum.KeyCode.RightShift, -- hide / show the whole UI
})

----------------------------------------------------------------------
-- Home
----------------------------------------------------------------------

local Home = Window:AddTab("Home")

local welcome = Home:AddSection("Welcome")

welcome:AddLabel({
	Text = "A UI engine built out of Instances at runtime - no Studio, no "
		.. "place file, no pre-made ScreenGui. Everything below was created "
		.. "by this script.",
	Style = "Dim",
})

welcome:AddButton({
	Name = "Say hello",
	Callback = function()
		UI:Notify({
			Title = "Hello",
			Content = "Notifications stack in the corner and auto-dismiss.",
			Duration = 3,
			Type = "Success",
		})
	end,
})

welcome:AddButton({
	Name = "Fire all four notification types",
	Callback = function()
		for _, typeName in ipairs({ "Info", "Success", "Warning", "Error" }) do
			UI:Notify({
				Title = typeName,
				Content = "This is a " .. string.lower(typeName) .. " notification.",
				Duration = 4,
				Type = typeName,
			})
		end
	end,
})

local toggles = Home:AddSection("Behaviour")

toggles:AddToggle({
	Name = "Enabled",
	Default = true,
	Callback = function(value)
		print("[demo] Enabled ->", value)
	end,
})

toggles:AddToggle({
	Name = "Start minimized",
	Default = false,
	Callback = function(value)
		if value then
			Window:SetMinimized(true)
		end
	end,
})

local movement = Home:AddSection("Movement")

movement:AddSlider({
	Name = "Walk speed",
	Min = 16,
	Max = 200,
	Default = 16,
	Step = 1,
	Suffix = " studs",
	Callback = function(value)
		print("[demo] Walk speed ->", value)
	end,
})

movement:AddSlider({
	Name = "Gravity scale",
	Min = 0,
	Max = 3,
	Default = 1,
	Step = 0.05,
	Callback = function(value)
		print("[demo] Gravity ->", value)
	end,
})

movement:AddDropdown({
	Name = "Mode",
	Options = { "Walk", "Sprint", "Fly", "Noclip" },
	Default = "Walk",
	Callback = function(value)
		print("[demo] Mode ->", value)
	end,
})

movement:AddKeybind({
	Name = "Toggle mode",
	Default = Enum.KeyCode.F,
	Callback = function()
		print("[demo] Toggle mode pressed")
	end,
})

----------------------------------------------------------------------
-- Visuals
----------------------------------------------------------------------

local Visuals = Window:AddTab("Visuals")

local theme = Visuals:AddSection("Theme")

theme:AddColorPicker({
	Name = "Accent",
	Default = UI.Theme.Accent,
	Callback = function(color)
		UI:SetTheme({ Accent = color })
	end,
})

theme:AddColorPicker({
	Name = "Background",
	Default = UI.Theme.Background,
	Callback = function(color)
		UI:SetTheme({ Background = color })
	end,
})

theme:AddButton({
	Name = "Reset theme",
	Callback = function()
		UI:SetTheme({
			Accent = Color3.fromRGB(88, 140, 255),
			Background = Color3.fromRGB(18, 18, 24),
		})
		UI:Notify({ Title = "Theme reset", Duration = 2, Type = "Info" })
	end,
})

local filters = Visuals:AddSection("Filters")

filters:AddDropdown({
	Name = "Highlight",
	Options = { "None", "Team", "Enemies", "Everyone" },
	Default = "None",
	Callback = function(value)
		print("[demo] Highlight ->", value)
	end,
})

filters:AddDropdown({
	Name = "Tags",
	Options = { "Friendly", "Hostile", "Neutral", "Loot", "Quest" },
	Multi = true,
	Default = { "Friendly" },
	Callback = function(value)
		print("[demo] Tags ->", table.concat(value, ", "))
	end,
})

filters:AddSlider({
	Name = "Render distance",
	Min = 0,
	Max = 2000,
	Default = 500,
	Step = 50,
	Suffix = "m",
	Callback = function(value)
		print("[demo] Render distance ->", value)
	end,
})

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------

local Settings = Window:AddTab("Settings")

local identity = Settings:AddSection("Identity")

identity:AddTextbox({
	Name = "Display name",
	Placeholder = "your name",
	Default = "",
	MaxLength = 20,
	Callback = function(text)
		print("[demo] Display name ->", text)
	end,
})

identity:AddTextbox({
	Name = "Refresh rate",
	Placeholder = "60",
	Default = "60",
	Numeric = true,
	Callback = function(text)
		print("[demo] Refresh rate ->", text)
	end,
})

local session = Settings:AddSection("Session")

session:AddKeybind({
	Name = "Toggle UI",
	Default = Enum.KeyCode.RightShift,
	Callback = function()
		Window:Toggle()
	end,
})

session:AddLabel({
	Text = "The window keybind above mirrors the one passed to CreateWindow, "
		.. "so either binding hides the UI.",
	Style = "Faint",
})

session:AddButton({
	Name = "Minimize",
	Callback = function()
		Window:SetMinimized(true)
	end,
})

session:AddButton({
	Name = "Close UI",
	Callback = function()
		Window:Destroy()
	end,
})

----------------------------------------------------------------------
-- Ready
----------------------------------------------------------------------

Window:SelectTab(Home)

UI:Notify({
	Title = "B0XazUI ready",
	Content = "Press RightShift to hide or show the window.",
	Duration = 5,
	Type = "Info",
})

print(string.format(
	"[demo] built %d window(s), %d tab(s), %d element type(s)",
	#UI.Windows,
	#Window.Tabs,
	#UI:ListElements()
))

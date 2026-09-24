--[[
	examples/Demo.lua
	====================================================================
	Every element B0XazUI ships with, wired up the way a real script
	would use it, in the engine's native "Abyss" skin. Runs as-is in
	an executor, and also runs inside the mocked environment (see
	tests/run.js) which is how we know the documented API is the API
	that actually works.

	For an element-for-element recreation of the original reference
	screenshots, see examples/Abyss.lua.

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
	Title = "b0xaz ui",
	SubTitle = "v" .. B0XazUI.Version,
	Size = Vector2.new(560, 520),
	ToggleKey = Enum.KeyCode.RightShift, -- hide / show the whole UI
})

----------------------------------------------------------------------
-- main
----------------------------------------------------------------------

local Main = Window:AddTab("main")

local welcome = Main:AddSection("welcome", { Column = 1 })

welcome:AddLabel({
	Text = "A UI engine built out of Instances at runtime - no Studio, no "
		.. "place file, no pre-made ScreenGui. Everything below was created "
		.. "by this script.",
	Style = "Dim",
})

welcome:AddButton({
	Name = "say hello",
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
	Name = "fire all four notification types",
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

local movement = Main:AddSection("movement", { Column = 2 })

movement:AddSlider({
	Name = "walk speed",
	Min = 16,
	Max = 200,
	Default = 16,
	Step = 1,
	Callback = function(value)
		print("[demo] walk speed ->", value)
	end,
})

movement:AddSlider({
	Name = "gravity scale",
	Min = 0,
	Max = 3,
	Default = 1,
	Step = 0.05,
	Callback = function(value)
		print("[demo] gravity ->", value)
	end,
})

movement:AddDropdown({
	Name = "mode",
	Options = { "Walk", "Sprint", "Fly", "Noclip" },
	Default = "Walk",
	Callback = function(value)
		print("[demo] mode ->", value)
	end,
})

local behaviour = Main:AddSection("behaviour", { Column = 1 })

behaviour:AddToggle({
	Name = "enabled",
	Default = true,
	Bind = Enum.KeyCode.E, -- click the chip on the right to rebind
	Callback = function(value)
		print("[demo] enabled ->", value)
	end,
})

behaviour:AddToggle({
	Name = "fly",
	Default = false,
	Swatch = { Default = Color3.fromRGB(150, 155, 235) },
	Callback = function(value)
		print("[demo] fly ->", value)
	end,
})

----------------------------------------------------------------------
-- visuals
----------------------------------------------------------------------

local Visuals = Window:AddTab("visuals")

local theme = Visuals:AddSection("theme", { Column = 1 })

theme:AddColorPicker({
	Name = "accent",
	Default = UI.Theme.Accent,
	Callback = function(color)
		UI:SetTheme({ Accent = color })
	end,
})

theme:AddColorPicker({
	Name = "background",
	Default = UI.Theme.Background,
	Callback = function(color)
		UI:SetTheme({ Background = color })
	end,
})

theme:AddButton({
	Name = "reset theme",
	Callback = function()
		UI:SetTheme({
			Accent = Color3.fromRGB(122, 126, 214),
			Background = Color3.fromRGB(20, 20, 24),
		})
		UI:Notify({ Title = "Theme reset", Duration = 2, Type = "Info" })
	end,
})

local filters = Visuals:AddSection("filters", { Column = 2 })

filters:AddDropdown({
	Name = "highlight",
	Options = { "None", "Team", "Enemies", "Everyone" },
	Default = "None",
	Callback = function(value)
		print("[demo] highlight ->", value)
	end,
})

filters:AddDropdown({
	Name = "tags",
	Options = { "Friendly", "Hostile", "Neutral", "Loot", "Quest" },
	Multi = true,
	Default = { "Friendly" },
	Callback = function(value)
		print("[demo] tags ->", table.concat(value, ", "))
	end,
})

filters:AddSlider({
	Name = "render distance",
	Min = 0,
	Max = 2000,
	Default = 500,
	Step = 50,
	Suffix = "m",
	Callback = function(value)
		print("[demo] render distance ->", value)
	end,
})

----------------------------------------------------------------------
-- settings
----------------------------------------------------------------------

local Settings = Window:AddTab("settings")

local identity = Settings:AddSection("identity", { Column = 1 })

identity:AddTextbox({
	Name = "display name",
	Placeholder = "your name",
	Default = "",
	MaxLength = 20,
	Callback = function(text)
		print("[demo] display name ->", text)
	end,
})

identity:AddTextbox({
	Name = "refresh rate",
	Placeholder = "60",
	Default = "60",
	Numeric = true,
	Callback = function(text)
		print("[demo] refresh rate ->", text)
	end,
})

local session = Settings:AddSection("session", { Column = 2 })

session:AddKeybind({
	Name = "toggle ui",
	Default = Enum.KeyCode.RightShift,
	Callback = function()
		Window:Toggle()
	end,
})

session:AddLabel({
	Text = "the window keybind above mirrors the one passed to "
		.. "CreateWindow, so either binding hides the UI.",
	Style = "Faint",
})

session:AddButton({
	Name = "minimize",
	Callback = function()
		Window:SetMinimized(true)
	end,
})

session:AddButton({
	Name = "close ui",
	Callback = function()
		Window:Destroy()
	end,
})

----------------------------------------------------------------------
-- Ready
----------------------------------------------------------------------

Window:SelectTab(Main)

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

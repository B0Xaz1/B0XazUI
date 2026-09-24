--[[
	examples/Abyss.lua
	====================================================================
	The look the engine was built for: a recreation of the original
	"abyss" reference screenshots, element for element -- title strip,
	main/rage tabs, the two-column "main" page with its fieldset
	sections, key chips on the master toggles, colour swatches on the
	FOV rows, and "value/max" sliders.

	It is skin deep by design: every callback just prints. The engine
	ships no game logic of any kind.

	Executor usage:

		loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/B0Xaz1/B0XazUI/main/examples/Abyss.lua"
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

local Window = UI:CreateWindow({
	Title = "abyss dev access",
	SubTitle = "da hood",
	Size = Vector2.new(560, 520),
	ToggleKey = Enum.KeyCode.RightShift,
})

----------------------------------------------------------------------
-- main
----------------------------------------------------------------------

local Main = Window:AddTab("main")

-- Left column ------------------------------------------------------------

local legit = Main:AddSection("legit", { Column = 1 })

legit:AddToggle({
	Name = "aimbot",
	Default = true,
	Bind = Enum.UserInputType.MouseButton2, -- the [ M2 ] chip
	Callback = function(value)
		print("[abyss] aimbot ->", value)
	end,
})
legit:AddToggle({ Name = "visible check" })
legit:AddToggle({ Name = "apply prediction" })
legit:AddSlider({
	Name = "smoothing [mouse]",
	Min = 0,
	Max = 20,
	Default = 0,
})
legit:AddDropdown({
	Name = "hitbox priority",
	Options = { "Head", "Torso", "Arms", "Legs" },
	Default = "Head",
})
legit:AddDropdown({
	Name = "mode",
	Options = { "Camera", "Mouse" },
	Default = "Camera",
})

local redirect = Main:AddSection("bullet redirection", { Column = 1 })

redirect:AddToggle({
	Name = "silent aim",
	Default = true,
})
redirect:AddToggle({ Name = "apply prediction" })
redirect:AddToggle({ Name = "custom prediction" })
redirect:AddSlider({
	Name = "value",
	Min = 0,
	Max = 99,
	Default = 75,
})
redirect:AddToggle({ Name = "visible check" })
redirect:AddSlider({
	Name = "randomization",
	Min = 0,
	Max = 100,
	Default = 0,
	Suffix = "%",
})
redirect:AddDropdown({
	Name = "hitbox priority",
	Options = { "Head", "Torso", "Arms", "Legs" },
	Default = "Head",
})

local trigger = Main:AddSection("trigger bot", { Column = 1 })

trigger:AddToggle({
	Name = "enabled",
	Bind = Enum.KeyCode.M, -- the [ M ] chip
	Callback = function(value)
		print("[abyss] trigger bot ->", value)
	end,
})
trigger:AddSlider({
	Name = "delay",
	Min = 0,
	Max = 5,
	Default = 0,
	Suffix = "m",
})

-- Right column -----------------------------------------------------------

local fov = Main:AddSection("drawing field of view", { Column = 2 })

fov:AddToggle({
	Name = "aimbot fov",
	Default = true,
	Swatch = { Default = Color3.fromRGB(150, 155, 235) },
})
fov:AddSlider({
	Name = "size",
	Min = 0,
	Max = 250,
	Default = 100,
})
fov:AddToggle({
	Name = "silent aim fov",
	Default = true,
	Swatch = { Default = Color3.fromRGB(224, 84, 128) },
})
fov:AddSlider({
	Name = "size",
	Min = 0,
	Max = 250,
	Default = 100,
})
fov:AddDropdown({
	Name = "style",
	Options = { "Outline", "Filled", "Dotted" },
	Default = "Outline",
})
fov:AddDropdown({
	Name = "position",
	Options = { "Mouse", "Head", "Torso" },
	Default = "Mouse",
})

----------------------------------------------------------------------
-- rage
----------------------------------------------------------------------

local Rage = Window:AddTab("rage")

local rageMain = Rage:AddSection("rage bot", { Column = 1 })
rageMain:AddToggle({ Name = "enabled" })
rageMain:AddToggle({ Name = "double tap", Bind = Enum.KeyCode.N })
rageMain:AddSlider({ Name = "hit chance", Min = 0, Max = 100, Default = 0, Suffix = "%" })
rageMain:AddDropdown({
	Name = "resolver",
	Options = { "Off", "Delta", "Bruteforce" },
	Default = "Off",
})

local antiAim = Rage:AddSection("anti aimbot angles", { Column = 2 })
antiAim:AddToggle({ Name = "jitter" })
antiAim:AddSlider({ Name = "yaw", Min = -180, Max = 180, Default = 0 })
antiAim:AddDropdown({
	Name = "pitch",
	Options = { "Down", "Up", "Zero" },
	Default = "Down",
})

Window:SelectTab(Main)

print("[abyss] example ready - RightShift to hide/show")

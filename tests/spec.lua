--[[
	tests/spec.lua
	====================================================================
	Behavioural tests for B0XazUI, run inside tests/mock/roblox.lua.

	The point is not pixel-perfect layout (only Roblox can do that) but
	proving that:
	  * every module in the manifest loads and registers itself,
	  * the instance tree actually gets built,
	  * each element responds to simulated input and fires callbacks,
	  * nothing warns or errors along the way.
	====================================================================
]]

local Mock = _G.__MOCK
local Enum = _G.Enum
local Vector2 = _G.Vector2
local Vector3 = _G.Vector3
local Color3 = _G.Color3
local UDim2 = _G.UDim2

----------------------------------------------------------------------
-- Tiny test runner
----------------------------------------------------------------------

local passed, failed = 0, 0
local failures = {}

local function describe(name, fn)
	print(string.format("\n%s", name))
	fn()
end

local function it(name, fn)
	local ok, err = xpcall(fn, function(message)
		return debug.traceback(tostring(message), 2)
	end)
	if ok then
		passed = passed + 1
		print(string.format("  PASS  %s", name))
	else
		failed = failed + 1
		table.insert(failures, { name = name, err = err })
		print(string.format("  FAIL  %s\n        %s", name, tostring(err)))
	end
end

local function expect(condition, message)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

local function eq(actual, expected, message)
	if actual ~= expected then
		error(string.format(
			"%s (expected %s, got %s)",
			message or "values differ",
			tostring(expected),
			tostring(actual)
		), 2)
	end
end

local function near(actual, expected, tolerance, message)
	if math.abs(actual - expected) > (tolerance or 0.001) then
		error(string.format(
			"%s (expected ~%s, got %s)",
			message or "values differ",
			tostring(expected),
			tostring(actual)
		), 2)
	end
end

----------------------------------------------------------------------
-- 1. Loading
----------------------------------------------------------------------

local B0XazUI = _G.B0XazUI
local UI

describe("loader", function()
	it("returns a namespace table", function()
		expect(typeof(B0XazUI) == "table", "init.lua should return a table")
		eq(B0XazUI.Version, "1.0.0", "version")
	end)

	it("loads every module in the manifest", function()
		UI = B0XazUI:Load()
		expect(UI ~= nil, "UI namespace missing")
		eq(UI.Elements ~= nil, true, "UI.Elements missing")
		eq(UI.Components ~= nil, true, "UI.Components missing")
		eq(UI.Util ~= nil, true, "UI.Util missing")
	end)

	it("registers every element type", function()
		local names = UI:ListElements()
		local expected = {
			"Button", "ColorPicker", "Dropdown", "Keybind", "Label",
			"Slider", "Textbox", "Toggle",
		}
		for i = 1, #expected do
			expect(UI.Elements[expected[i]] ~= nil, "missing element: " .. expected[i])
		end
		eq(#names, #expected, "element count")
	end)

	it("registers every component", function()
		for _, name in ipairs({ "Window", "Tab", "Section", "Notification" }) do
			expect(UI.Components[name] ~= nil, "missing component: " .. name)
		end
	end)

	it("exposes Section:Add<Element>() helpers", function()
		local Section = UI.Components.Section
		for name in pairs(UI.Elements) do
			local method = "Add" .. name
			expect(typeof(Section[method]) == "function", "missing method: " .. method)
		end
	end)
end)

----------------------------------------------------------------------
-- 2. Window shell
----------------------------------------------------------------------

local Window, Tab, Section

describe("window", function()
	it("creates a window inside the shared ScreenGui", function()
		Window = UI:CreateWindow({
			Title = "Test Window",
			SubTitle = "v1.0.0",
			Size = Vector2.new(600, 400),
		})

		expect(Window ~= nil, "window is nil")
		expect(UI.ScreenGui ~= nil, "ScreenGui missing")
		expect(UI.ScreenGui.Parent ~= nil, "ScreenGui is not parented")
		eq(Window.Root.Parent, UI.ScreenGui, "window parent")
		eq(#UI.Windows, 1, "window registry")
	end)

	it("builds topbar, tab bar and content", function()
		expect(Window.Topbar ~= nil, "topbar missing")
		expect(Window.TabBar ~= nil, "tabbar missing")
		expect(Window.Content ~= nil, "content missing")
		eq(Window.TitleLabel.Text, "Test Window", "title")
		eq(Window.SubTitleLabel.Text, "v1.0.0", "subtitle")
		eq(Window.Root.Size.X.Offset, 600, "width")
		eq(Window.Root.Size.Y.Offset, 400, "height")
	end)

	it("centres itself in the viewport", function()
		local screen = Mock.SCREEN
		near(Window.Root.Position.X.Offset, (screen.X - 600) / 2, 1, "centred x")
		near(Window.Root.Position.Y.Offset, (screen.Y - 400) / 2, 1, "centred y")
	end)

	it("adds tabs and auto-selects the first", function()
		Tab = Window:AddTab("Main")
		local second = Window:AddTab("Settings")
		local third = Window:AddTab("About")

		eq(#Window.Tabs, 3, "tab count")
		eq(Window.ActiveTab, Tab, "first tab active")
		eq(Tab.Page.Visible, true, "active page visible")
		eq(second.Page.Visible, false, "inactive page hidden")
		eq(third.Button.Parent, Window.TabScroll, "tab button parent")
	end)

	it("switches tabs", function()
		Window:SelectTab("Settings")
		eq(Window.ActiveTab.Name, "Settings", "active tab by name")
		eq(Window:GetTab("Settings").Page.Visible, true, "page shown")
		eq(Tab.Page.Visible, false, "previous page hidden")

		Window:SelectTab(Tab)
		eq(Window.ActiveTab, Tab, "switched back")
	end)

	it("minimizes and restores", function()
		Window:SetMinimized(true)
		eq(Window.Root.Size.Y.Offset, UI.Theme.TopbarHeight, "collapsed height")
		eq(Window.TabBar.Visible, false, "tab bar hidden")
		eq(Window.Content.Visible, false, "content hidden")

		Window:SetMinimized(false)
		eq(Window.Root.Size.Y.Offset, 400, "restored height")
		eq(Window.Content.Visible, true, "content shown")
	end)

	it("hides and shows", function()
		Window:Toggle()
		eq(Window:IsVisible(), false, "hidden")
		Window:SetVisible(true)
		eq(Window:IsVisible(), true, "shown")
	end)
end)

----------------------------------------------------------------------
-- 3. Sections
----------------------------------------------------------------------

describe("section", function()
	it("creates a collapsible section", function()
		Section = Tab:AddSection("General")
		expect(Section ~= nil, "section is nil")
		eq(Section.Frame.Parent, Tab.Page, "section parent")
		eq(Section.HeaderLabel.Text, "General", "section title")
		eq(Section.Body.Visible, true, "expanded by default")
	end)

	it("collapses on header click", function()
		Mock.click(Section.Header)
		eq(Section.Expanded, false, "collapsed")
		eq(Section.Body.Visible, false, "body hidden")

		Mock.click(Section.Header)
		eq(Section.Expanded, true, "expanded again")
	end)
end)

----------------------------------------------------------------------
-- 4. Elements
----------------------------------------------------------------------

describe("Label", function()
	it("renders text and updates", function()
		local label = Section:AddLabel({ Text = "Hello world", Style = "Dim" })
		eq(label.TextLabel.Text, "Hello world", "text")
		eq(label.TextLabel.TextColor3, UI.Theme.TextDim, "dim style")

		label:SetText("Updated")
		eq(label:GetValue(), "Updated", "updated text")
	end)
end)

describe("Button", function()
	local fired = 0
	local button

	it("fires its callback on click", function()
		button = Section:AddButton({
			Name = "Press me",
			Callback = function()
				fired = fired + 1
			end,
		})

		eq(button.TextLabel.Text, "Press me", "label")
		Mock.click(button.HitArea)
		eq(fired, 1, "callback fired once")
	end)

	it("can be fired programmatically", function()
		button:Fire()
		eq(fired, 2, "programmatic fire")
	end)

	it("renames itself", function()
		button:SetText("Renamed")
		eq(button.TextLabel.Text, "Renamed", "renamed")
	end)
end)

describe("Toggle", function()
	local received = {}
	local toggle

	it("defaults off and switches on click", function()
		toggle = Section:AddToggle({
			Name = "Enabled",
			Default = false,
			Callback = function(value)
				table.insert(received, value)
			end,
		})

		eq(toggle:GetValue(), false, "default off")
		Mock.click(toggle.Row)
		eq(toggle:GetValue(), true, "toggled on")
		eq(#received, 1, "callback fired")
		eq(received[1], true, "callback value")
		eq(toggle.Switch.BackgroundColor3, UI.Theme.Accent, "switch accent when on")
	end)

	it("toggles back off", function()
		Mock.click(toggle.Row)
		eq(toggle:GetValue(), false, "toggled off")
		eq(#received, 2, "second callback")
	end)

	it("SetValue can skip the callback", function()
		toggle:SetValue(true, true)
		eq(toggle:GetValue(), true, "value set")
		eq(#received, 2, "no extra callback")

		toggle:SetValue(false)
		eq(#received, 3, "callback when not skipped")
	end)

	it("exposes a Changed signal", function()
		local seen = 0
		toggle.Changed:Connect(function()
			seen = seen + 1
		end)
		toggle:SetValue(true)
		eq(seen, 1, "changed fired")
	end)
end)

describe("Slider", function()
	local committed = {}
	local slider

	it("clamps and formats the default", function()
		slider = Section:AddSlider({
			Name = "Speed",
			Min = 0,
			Max = 100,
			Default = 25,
			Step = 1,
			Suffix = "%",
			Callback = function(value)
				table.insert(committed, value)
			end,
		})

		eq(slider:GetValue(), 25, "default")
		eq(slider.ValueLabel.Text, "25%", "formatted value")
	end)

	it("responds to a click on the track", function()
		local trackX = slider.Track.AbsolutePosition.X
		local trackWidth = slider.Track.AbsoluteSize.X

		slider.TrackHit.InputBegan:Fire({
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.new(trackX + trackWidth * 0.5, 0, 0),
		})

		near(slider:GetValue(), 50, 1, "clicked midpoint")
	end)

	it("responds to dragging", function()
		local trackX = slider.Track.AbsolutePosition.X
		local trackWidth = slider.Track.AbsoluteSize.X

		Mock.inputChanged({
			UserInputType = Enum.UserInputType.MouseMovement,
			Position = Vector3.new(trackX + trackWidth * 0.25, 0, 0),
		})

		near(slider:GetValue(), 25, 1, "dragged to 25%")
	end)

	it("commits the callback on release", function()
		Mock.inputEnded({ UserInputType = Enum.UserInputType.MouseButton1 })
		eq(#committed, 1, "committed once")
		near(committed[1], 25, 1, "committed value")
		eq(slider.Dragging, false, "drag released")
	end)

	it("respects min/max and step", function()
		slider:SetValue(500)
		eq(slider:GetValue(), 100, "clamped to max")

		slider:SetValue(-50)
		eq(slider:GetValue(), 0, "clamped to min")

		local precise = Section:AddSlider({ Name = "Precise", Min = 0, Max = 1, Step = 0.1, Default = 0.3 })
		eq(precise.ValueLabel.Text, "0.3", "one decimal place")
	end)
end)

describe("Dropdown", function()
	local picked = {}
	local dropdown

	it("builds one button per option", function()
		dropdown = Section:AddDropdown({
			Name = "Mode",
			Options = { "Fast", "Balanced", "Precise" },
			Default = "Fast",
			Callback = function(value)
				table.insert(picked, value)
			end,
		})

		eq(#dropdown.OptionButtons, 3, "option count")
		eq(dropdown.ValueLabel.Text, "Fast", "default display")
	end)

	it("expands and collapses the list", function()
		dropdown:SetOpen(true)
		eq(dropdown.Open, true, "open")
		expect(dropdown.List.Size.Y.Offset > 0, "list has height when open")

		dropdown:SetOpen(false)
		eq(dropdown.Open, false, "closed")
		eq(dropdown.List.Size.Y.Offset, 0, "collapsed to zero height")
	end)

	it("selects an option on click", function()
		Mock.click(dropdown.OptionButtons[2])
		eq(dropdown:GetValue(), "Balanced", "value updated")
		eq(#picked, 1, "callback fired")
		eq(picked[1], "Balanced", "callback value")
		eq(dropdown.Open, false, "closes after single select")
	end)

	it("supports multi-select", function()
		local multi = Section:AddDropdown({
			Name = "Tags",
			Options = { "A", "B", "C" },
			Multi = true,
			Default = { "A" },
		})

		multi:SetOpen(true)
		Mock.click(multi.OptionButtons[2])
		Mock.click(multi.OptionButtons[3])

		local selected = multi:GetValue()
		eq(#selected, 3, "three selected")
		eq(multi.ValueLabel.Text, "3 selected", "display count")
		eq(multi.Open, true, "stays open for multi-select")
	end)

	it("replaces options at runtime", function()
		dropdown:SetOptions({ "One", "Two" }, true)
		eq(#dropdown.OptionButtons, 2, "rebuilt")
		eq(dropdown.OptionButtons[1].Name, "One", "first option")
	end)
end)

describe("Textbox", function()
	local typed = {}
	local textbox

	it("commits on focus loss", function()
		textbox = Section:AddTextbox({
			Name = "Player",
			Placeholder = "username",
			Callback = function(text, enterPressed)
				table.insert(typed, { text = text, enter = enterPressed })
			end,
		})

		eq(textbox.Input.PlaceholderText, "username", "placeholder")

		textbox.Input.Text = "builderman"
		textbox.Input.FocusLost:Fire(true)

		eq(#typed, 1, "callback fired")
		eq(typed[1].text, "builderman", "committed text")
		eq(typed[1].enter, true, "enter pressed flag")
	end)

	it("strips non-numeric input when Numeric is set", function()
		local numeric = Section:AddTextbox({ Name = "Count", Numeric = true })
		numeric.Input.Text = "12a3.4.5"
		eq(numeric.Input.Text, "123.45", "filtered")
		eq(numeric:GetNumber(), 123.45, "as number")
	end)

	it("respects MaxLength", function()
		local limited = Section:AddTextbox({ Name = "Short", MaxLength = 4 })
		limited.Input.Text = "abcdefgh"
		eq(#limited.Input.Text, 4, "truncated")
	end)

	it("SetValue updates the box", function()
		textbox:SetValue("hello")
		eq(textbox:GetValue(), "hello", "value")
	end)
end)

describe("Keybind", function()
	local presses = 0
	local keybind

	it("captures a key while listening", function()
		keybind = Section:AddKeybind({
			Name = "Toggle UI",
			Default = Enum.KeyCode.RightControl,
			Callback = function()
				presses = presses + 1
			end,
		})

		eq(keybind:GetName(), "RightControl", "default key")

		Mock.click(keybind.BindButton)
		eq(keybind.Listening, true, "listening")

		Mock.inputBegan({
			KeyCode = Enum.KeyCode.G,
			UserInputType = Enum.UserInputType.Keyboard,
		})

		eq(keybind.Listening, false, "stopped listening")
		eq(keybind:GetName(), "G", "captured key")
	end)

	it("fires when the bound key is pressed", function()
		Mock.inputBegan({
			KeyCode = Enum.KeyCode.G,
			UserInputType = Enum.UserInputType.Keyboard,
		})
		eq(presses, 1, "callback fired on press")

		Mock.inputBegan({
			KeyCode = Enum.KeyCode.H,
			UserInputType = Enum.UserInputType.Keyboard,
		})
		eq(presses, 1, "ignores other keys")
	end)

	it("clears the bind with Escape", function()
		Mock.click(keybind.BindButton)
		Mock.inputBegan({
			KeyCode = Enum.KeyCode.Escape,
			UserInputType = Enum.UserInputType.Keyboard,
		})

		eq(keybind:GetName(), "None", "cleared")
		eq(keybind:IsBound(), false, "unbound")
	end)

	it("ignores input while the game is processing it", function()
		keybind:SetKey(Enum.KeyCode.P, true)
		Mock.Services.UserInputService.InputBegan:Fire({
			KeyCode = Enum.KeyCode.P,
			UserInputType = Enum.UserInputType.Keyboard,
		}, true)
		eq(presses, 1, "suppressed while typing")
	end)
end)

describe("ColorPicker", function()
	local picked = {}
	local picker

	it("opens its popup on the overlay", function()
		picker = Section:AddColorPicker({
			Name = "Accent",
			Default = Color3.fromRGB(255, 0, 0),
			Callback = function(color)
				table.insert(picked, color)
			end,
		})

		eq(picker.HexLabel.Text, "FF0000", "initial hex")
		eq(picker.SwatchButton.BackgroundColor3, Color3.fromRGB(255, 0, 0), "swatch colour")

		picker:SetOpen(true)
		expect(picker.Popup ~= nil, "popup missing")
		eq(picker.Popup.Open, true, "popup open")
		eq(picker.Popup.Frame.Visible, true, "popup visible")
		eq(picker.Popup.Frame.Parent, UI:GetOverlay(), "popup lives on the overlay")
	end)

	it("drags the saturation/value field", function()
		local field = picker.Field
		local position = field.AbsolutePosition
		local size = field.AbsoluteSize

		field.InputBegan:Fire({
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.new(position.X + size.X * 0.5, position.Y + size.Y * 0.5, 0),
		})

		near(picker.S, 0.5, 0.01, "saturation")
		near(picker.V, 0.5, 0.01, "value")
	end)

	it("drags the hue strip", function()
		local hue = picker.HueFrame
		local position = hue.AbsolutePosition
		local size = hue.AbsoluteSize

		hue.InputBegan:Fire({
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.new(position.X + size.X * 0.5, position.Y + size.Y * 0.5, 0),
		})

		near(picker.H, 180, 1, "hue")
	end)

	it("accepts a hex value", function()
		picker.HexBox.Text = "0080FF"
		picker.HexBox.FocusLost:Fire(true)

		eq(picker.HexLabel.Text, "0080FF", "hex label")
		eq(picker:GetValue(), Color3.fromRGB(0, 128, 255), "value")
		eq(picker.SwatchButton.BackgroundColor3, Color3.fromRGB(0, 128, 255), "swatch")
	end)

	it("SetValue repaints without firing the callback", function()
		local before = #picked
		picker:SetValue(Color3.fromRGB(10, 20, 30), true)
		eq(#picked, before, "silent")
		eq(picker.HexLabel.Text, "0A141E", "repainted")
	end)

	it("closes the popup", function()
		picker:SetOpen(false)
		eq(picker.Popup.Open, false, "closed")
	end)
end)

----------------------------------------------------------------------
-- 5. Notifications
----------------------------------------------------------------------

describe("notifications", function()
	it("creates a toast on the notification container", function()
		local notification = UI:Notify({
			Title = "Saved",
			Content = "Settings written",
			Duration = 3,
			Type = "Success",
		})

		expect(UI.NotificationContainer ~= nil, "container missing")
		eq(notification.Frame.Parent, UI.NotificationContainer, "parented to container")
		eq(#UI.Notifications, 1, "tracked")
	end)

	it("auto-dismisses after its duration", function()
		Mock.flush()
		eq(#UI.Notifications, 0, "dismissed after flush")
	end)

	it("supports all four types", function()
		for _, typeName in ipairs({ "Info", "Success", "Warning", "Error" }) do
			local notification = UI:Notify({ Title = typeName, Content = "x", Duration = 0 })
			expect(notification ~= nil, "created " .. typeName)
			notification:Dismiss()
			Mock.flush()
		end
	end)

	it("moves to a different screen corner", function()
		local container = UI.NotificationContainer
		UI:SetNotificationCorner("TopLeft")
		eq(container.AnchorPoint.X, 0, "anchored left")
		eq(container.AnchorPoint.Y, 0, "anchored top")
		UI:SetNotificationCorner("BottomRight")
	end)
end)

----------------------------------------------------------------------
-- 6. Theming
----------------------------------------------------------------------

describe("theming", function()
	it("repaints bound properties", function()
		local slider = Section:AddSlider({ Name = "Themed", Min = 0, Max = 10, Default = 1 })
		local old = slider.ValueLabel.TextColor3

		UI:SetTheme({ Accent = Color3.fromRGB(255, 0, 255) })

		eq(slider.ValueLabel.TextColor3, Color3.fromRGB(255, 0, 255), "accent applied")
		expect(old ~= slider.ValueLabel.TextColor3, "colour actually changed")
	end)

	it("rebinds a single property", function()
		local label = Section:AddLabel({ Text = "Rebind" })
		UI:RebindTheme(label.TextLabel, "TextColor3", "Error")
		eq(label.TextLabel.TextColor3, UI.Theme.Error, "rebound")
	end)
end)

----------------------------------------------------------------------
-- 7. Tree integrity + teardown
----------------------------------------------------------------------

describe("tree integrity", function()
	it("built a sane instance tree", function()
		local root = UI.ScreenGui
		local total = Mock.countAll(root)
		expect(total > 100, string.format("expected a populated tree, got %d instances", total))

		expect(Mock.countClass(root, "UICorner") > 5, "rounded corners present")
		expect(Mock.countClass(root, "UIListLayout") > 3, "layouts present")
		expect(Mock.countClass(root, "ScrollingFrame") >= 4, "scrolling frames present")
	end)

	it("destroying an element removes it from the tree", function()
		local before = Mock.countAll(UI.ScreenGui)
		local temporary = Section:AddButton({ Name = "Temporary" })
		temporary:Destroy()
		expect(Mock.countAll(UI.ScreenGui) < before + 5, "element removed")
	end)

	it("destroying a tab removes its page", function()
		local tab = Window:AddTab("Throwaway")
		tab:AddSection("Temp")
		local before = #Window.Tabs

		tab:Destroy()
		eq(#Window.Tabs, before - 1, "tab removed")
	end)

	it("destroys the window", function()
		Window:Destroy()
		eq(#UI.Windows, 0, "window registry cleared")
		eq(Window.Root, nil, "root released")
	end)

	it("destroys the whole library", function()
		UI:Destroy()
		eq(UI.ScreenGui, nil, "screen gui destroyed")
		eq(#UI._ThemeBindings, 0, "theme bindings cleared")
	end)
end)

describe("warnings", function()
	it("produced no warnings", function()
		local warnings = Mock.Warnings
		if #warnings > 0 then
			error("warnings emitted:\n        " .. table.concat(warnings, "\n        "), 2)
		end
	end)
end)

----------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))

if failed > 0 then
	print("\nFailures:")
	for i = 1, #failures do
		print(string.format("  - %s: %s", failures[i].name, tostring(failures[i].err)))
	end
	error("B0XazUI spec failed", 0)
end

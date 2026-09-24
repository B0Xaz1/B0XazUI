--[[
	tests/mock/roblox.lua
	====================================================================
	A deliberately small fake of the Roblox client API, just complete
	enough to boot B0XazUI outside of Roblox and assert that the tree
	it builds is correct.

	It is a *test double*, not an emulator:
	  * property assignment is validated against a per-class schema, so
	    a typo like `BackgroundColour3` throws instead of silently
	    doing nothing;
	  * UDim2/AbsoluteSize/AbsoluteContentSize are computed with
	    offset+scale maths so layout code exercises real numbers;
	  * tweens resolve instantly and queue their Completed callback;
	  * input, timers and delayed callbacks are driven manually by the
	    spec via the __MOCK table.

	Run with: node tests/run.js
	====================================================================
]]

local Mock = {}

----------------------------------------------------------------------
-- Datatypes
----------------------------------------------------------------------

local function class(name, methods, mt)
	mt = mt or {}
	mt.__type = name
	mt.__tostring = mt.__tostring or function(self)
		return string.format("%s(%s)", name, tostring(rawget(self, "_tostring") or ""))
	end
	if methods then
		mt.__index = mt.__index or methods
	end
	return { new = function(...) end }
end

-- UDim -----------------------------------------------------------------
local UDim = {}
UDim.__index = UDim
UDim.__type = "UDim"
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
end
function UDim.__add(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
function UDim.__eq(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
function UDim:__tostring()
	return string.format("{%g, %g}", self.Scale, self.Offset)
end

-- UDim2 ---------------------------------------------------------------
local UDim2 = {}
UDim2.__index = UDim2
UDim2.__type = "UDim2"
function UDim2.new(xScale, xOffset, yScale, yOffset)
	return setmetatable({
		X = UDim.new(xScale or 0, xOffset or 0),
		Y = UDim.new(yScale or 0, yOffset or 0),
	}, UDim2)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2:__tostring()
	return string.format("{%s, %s}", tostring(self.X), tostring(self.Y))
end

-- Vector2 -------------------------------------------------------------
local Vector2 = {}
Vector2.__index = Vector2
Vector2.__type = "Vector2"
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end
Vector2.zero = Vector2.new(0, 0)
function Vector2.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
function Vector2.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2.__mul(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
function Vector2.__div(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
function Vector2.__unm(a)
	return Vector2.new(-a.X, -a.Y)
end
function Vector2.__eq(a, b)
	return a.X == b.X and a.Y == b.Y
end
function Vector2:__tostring()
	return string.format("Vector2(%g, %g)", self.X, self.Y)
end
function Vector2:Magnitude()
	return math.sqrt(self.X * self.X + self.Y * self.Y)
end

-- Vector3 -------------------------------------------------------------
local Vector3 = {}
Vector3.__index = Vector3
Vector3.__type = "Vector3"
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3:__tostring()
	return string.format("Vector3(%g, %g, %g)", self.X, self.Y, self.Z)
end

-- Color3 --------------------------------------------------------------
local Color3 = {}
Color3.__index = Color3
Color3.__type = "Color3"
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	h = ((h or 0) % 1) * 6
	s = s or 0
	v = v or 0
	local i = math.floor(h)
	local f = h - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end
function Color3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h = 0
	local d = max - min
	if d > 0 then
		if max == r then
			h = ((g - b) / d) % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	local s = (max == 0) and 0 or (d / max)
	return h, s, max
end
function Color3:ToHex()
	return string.format(
		"%02X%02X%02X",
		math.floor(self.R * 255 + 0.5),
		math.floor(self.G * 255 + 0.5),
		math.floor(self.B * 255 + 0.5)
	)
end
function Color3.fromHex(hex)
	hex = tostring(hex):gsub("^#", "")
	local r, g, b = hex:match("(%x%x)(%x%x)(%x%x)")
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end
function Color3.__eq(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3:__tostring()
	return string.format("Color3(%g, %g, %g)", self.R, self.G, self.B)
end

-- Sequences -----------------------------------------------------------
local NumberSequenceKeypoint = {}
NumberSequenceKeypoint.__index = NumberSequenceKeypoint
NumberSequenceKeypoint.__type = "NumberSequenceKeypoint"
function NumberSequenceKeypoint.new(time, value, envelope)
	return setmetatable({ Time = time or 0, Value = value or 0, Envelope = envelope or 0 }, NumberSequenceKeypoint)
end

local NumberSequence = {}
NumberSequence.__index = NumberSequence
NumberSequence.__type = "NumberSequence"
function NumberSequence.new(...)
	local args = { ... }
	if type(args[1]) == "table" then
		return setmetatable({ Keypoints = args[1] }, NumberSequence)
	end
	return setmetatable({ Keypoints = args }, NumberSequence)
end

local ColorSequenceKeypoint = {}
ColorSequenceKeypoint.__index = ColorSequenceKeypoint
ColorSequenceKeypoint.__type = "ColorSequenceKeypoint"
function ColorSequenceKeypoint.new(time, color)
	return setmetatable({ Time = time or 0, Value = color or Color3.new(1, 1, 1) }, ColorSequenceKeypoint)
end

local ColorSequence = {}
ColorSequence.__index = ColorSequence
ColorSequence.__type = "ColorSequence"
function ColorSequence.new(...)
	local args = { ... }
	if type(args[1]) == "table" then
		return setmetatable({ Keypoints = args[1] }, ColorSequence)
	end
	if #args == 1 then
		return setmetatable({ Keypoints = { ColorSequenceKeypoint.new(0, args[1]), ColorSequenceKeypoint.new(1, args[1]) } }, ColorSequence)
	end
	return setmetatable({ Keypoints = args }, ColorSequence)
end

-- TweenInfo -----------------------------------------------------------
local TweenInfo_ = {}
TweenInfo_.__index = TweenInfo_
TweenInfo_.__type = "TweenInfo"
function TweenInfo_.new(duration, style, direction, repeatCount, reverses, delayTime)
	return setmetatable({
		Time = duration or 1,
		EasingStyle = style,
		EasingDirection = direction,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}, TweenInfo_)
end

----------------------------------------------------------------------
-- Enum
----------------------------------------------------------------------

local Enum = setmetatable({}, {
	__index = function(t, enumType)
		local items = {}
		local enum = setmetatable({}, {
			__index = function(_, name)
				if items[name] == nil then
					items[name] = setmetatable({
						Name = tostring(name),
						EnumType = tostring(enumType),
						Value = 0,
					}, {
						__tostring = function(self)
							return "Enum." .. self.EnumType .. "." .. self.Name
						end,
						__eq = function(a, b)
							return getmetatable(a) == getmetatable(b) and a.Name == b.Name and a.EnumType == b.EnumType
						end,
					})
				end
				return items[name]
			end,
			__call = function(_, name)
				local me = _
				return me[name]
			end,
		})
		rawset(t, enumType, enum)
		return enum
	end,
})

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ _handlers = {}, Name = name or "Signal" }, Signal)
end
function Signal:Connect(handler)
	local connection = setmetatable({ Connected = true, _handler = handler, _signal = self }, {
		__index = {
			Disconnect = function(self)
				self.Connected = false
				local handlers = self._signal._handlers
				for i = #handlers, 1, -1 do
					if handlers[i] == self then
						table.remove(handlers, i)
						break
					end
				end
			end,
		},
	})
	table.insert(self._handlers, connection)
	return connection
end
function Signal:Fire(...)
	local snapshot = {}
	for i = 1, #self._handlers do
		snapshot[i] = self._handlers[i]
	end
	for i = 1, #snapshot do
		if snapshot[i].Connected then
			snapshot[i]._handler(...)
		end
	end
end

----------------------------------------------------------------------
-- Instance
----------------------------------------------------------------------

local ALLOWED = {}

local GUI_COMMON = {
	"Name", "Parent", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel",
	"Size", "Position", "AnchorPoint", "ZIndex", "Visible", "ClipsDescendants",
	"AutomaticSize", "LayoutOrder", "Rotation", "Active", "Selectable", "SizeConstraint",
	"Transparency", "BackgroundTransparency",
}
local TEXT_COMMON = {
	"Text", "Font", "TextSize", "TextColor3", "TextTransparency", "TextWrapped",
	"TextXAlignment", "TextYAlignment", "TextTruncate", "RichText", "TextScaled",
	"LineHeight", "TextStrokeTransparency", "TextStrokeColor3", "MaxVisibleGraphemes",
}
local IMAGE_COMMON = {
	"Image", "ImageColor3", "ImageTransparency", "ScaleType", "ImageRectSize",
	"ImageRectOffset", "SliceCenter", "SliceScale", "TileSize",
}

local function merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		local list = select(i, ...)
		for j = 1, #list do
			out[list[j]] = true
		end
	end
	return out
end

ALLOWED.Frame = merge(GUI_COMMON)
ALLOWED.TextLabel = merge(GUI_COMMON, TEXT_COMMON)
ALLOWED.TextButton = merge(GUI_COMMON, TEXT_COMMON, { "AutoButtonColor", "Modal", "Selected", "Style" })
ALLOWED.TextBox = merge(GUI_COMMON, TEXT_COMMON, {
	"PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus", "CursorPosition",
	"MultiLine", "TextEditable", "ShowNativeInputBar", "ReturnKeyType", "TextInputType",
})
ALLOWED.ImageLabel = merge(GUI_COMMON, IMAGE_COMMON)
ALLOWED.ImageButton = merge(GUI_COMMON, IMAGE_COMMON, { "AutoButtonColor", "HoverImage", "PressedImage" })
ALLOWED.ScrollingFrame = merge(GUI_COMMON, {
	"CanvasSize", "CanvasPosition", "ScrollBarThickness", "ScrollBarImageColor3",
	"ScrollBarImageTransparency", "ScrollingDirection", "AutomaticCanvasSize",
	"ScrollingEnabled", "ElasticBehavior", "ScrollVelocity", "HorizontalScrollBarInset",
	"VerticalScrollBarInset", "BottomImage", "MidImage", "TopImage",
})
ALLOWED.ScreenGui = merge({
	"Name", "Parent", "Enabled", "ResetOnSpawn", "IgnoreGuiInset", "ZIndexBehavior",
	"DisplayOrder", "ClipToDeviceSafeArea", "SafeAreaCompatibility", "AutoLocalize",
})
ALLOWED.UICorner = merge({ "Name", "Parent", "CornerRadius" })
ALLOWED.UIStroke = merge({ "Name", "Parent", "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode", "Enabled" })
ALLOWED.UIPadding = merge({ "Name", "Parent", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" })
ALLOWED.UIListLayout = merge({ "Name", "Parent", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding", "Wraps", "ItemLineAlignment" })
ALLOWED.UIGridLayout = merge({ "Name", "Parent", "CellSize", "CellPadding", "FillDirectionMaxCells", "SortOrder", "StartCorner", "FillDirection" })
ALLOWED.UIGradient = merge({ "Name", "Parent", "Color", "Transparency", "Rotation", "Offset", "Enabled" })
ALLOWED.UIScale = merge({ "Name", "Parent", "Scale" })
ALLOWED.UISizeConstraint = merge({ "Name", "Parent", "MinSize", "MaxSize" })
ALLOWED.Folder = merge({ "Name", "Parent" })
ALLOWED.LocalScript = merge({ "Name", "Parent", "Source", "Enabled", "RunContext" })
ALLOWED.Camera = merge({ "Name", "Parent", "ViewportSize", "CFrame", "FieldOfView", "CameraType", "CameraSubject" })

local EVENTS = {
	MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseButton2Click = true, MouseButton2Down = true, MouseButton2Up = true,
	MouseEnter = true, MouseLeave = true, MouseMoved = true, MouseWheelForward = true,
	MouseWheelBackward = true,
	InputBegan = true, InputChanged = true, InputEnded = true,
	Focused = true, FocusLost = true, Changed = true,
	SelectionGained = true, SelectionLost = true, TouchTap = true, TouchLongPress = true,
	AncestryChanged = true, DescendantAdded = true, DescendantRemoving = true,
	Completed = true, Touched = true,
}

local READONLY = {
	ClassName = true, AbsoluteSize = true, AbsolutePosition = true,
	AbsoluteContentSize = true, AbsoluteRotation = true, TextBounds = true,
	ContentText = true, Parent = false,
}

local allInstances = {}

local Instance = {}

local InstanceLib = {}
local InstanceMethods = {}

local function isInstance(value)
	return type(value) == "table" and value.__ClassName ~= nil
end

--- Instances whose property set we do not validate (services, DataModel,
-- players). ALLOWED[className] == nil means "permissive".
local newInstance -- forward declaration

local function newLoose(className)
	return newInstance(className)
end

function newInstance(className)
	local instance = {
		__ClassName = className,
		__Children = {},
		__Properties = {},
		__Signals = {},
		__PropertySignals = {},
		__Destroyed = false,
	}

	instance.__Properties.Name = className
	instance.__Properties.Parent = nil
	instance.__Properties.Size = UDim2.new(0, 100, 0, 100)
	instance.__Properties.Position = UDim2.new(0, 0, 0, 0)
	instance.__Properties.AnchorPoint = Vector2.new(0, 0)
	instance.__Properties.AbsoluteSize = Vector2.new(100, 100)
	instance.__Properties.AbsolutePosition = Vector2.new(0, 0)
	instance.__Properties.Visible = true
	instance.__Properties.BackgroundColor3 = Color3.new(1, 1, 1)
	instance.__Properties.BackgroundTransparency = 0
	instance.__Properties.BorderSizePixel = 0
	instance.__Properties.ZIndex = 1
	instance.__Properties.AutomaticSize = Enum.AutomaticSize.None

	table.insert(allInstances, instance)
	return setmetatable(instance, InstanceLib)
end

----------------------------------------------------------------------
-- Layout maths (good enough to exercise the real code paths)
----------------------------------------------------------------------

local SCREEN = Vector2.new(1600, 900)

local function parentSize(instance)
	local parent = instance.__Properties.Parent
	if isInstance(parent) then
		if parent.ClassName == "ScreenGui" then
			return SCREEN
		end
		return Mock.absoluteSize(parent)
	end
	return SCREEN
end

-- AbsoluteSize is mutually recursive with content sizing (a parent that
-- auto-sizes depends on its children, which are measured against the
-- parent). Roblox resolves this lazily; we break the cycle by returning
-- the last known size for an instance we are already measuring.
local sizeInProgress = {}
local sizeCache = setmetatable({}, { __mode = "k" })

function Mock.absoluteSize(instance)
	if sizeInProgress[instance] then
		return sizeCache[instance] or Vector2.new(0, 0)
	end

	sizeInProgress[instance] = true
	local ok, result = pcall(Mock._computeAbsoluteSize, instance)
	sizeInProgress[instance] = nil

	if not ok then
		error(result, 2)
	end

	sizeCache[instance] = result
	return result
end

function Mock._computeAbsoluteSize(instance)
	local size = instance.__Properties.Size or UDim2.new(0, 100, 0, 100)
	local p = parentSize(instance)
	local w = (size.X.Scale or 0) * p.X + (size.X.Offset or 0)
	local h = (size.Y.Scale or 0) * p.Y + (size.Y.Offset or 0)

	-- AutomaticSize: grow to fit the content of a child UIListLayout.
	local automatic = instance.__Properties.AutomaticSize
	if automatic and automatic ~= Enum.AutomaticSize.None then
		local layout
		for i = 1, #instance.__Children do
			if instance.__Children[i].__ClassName == "UIListLayout" then
				layout = instance.__Children[i]
				break
			end
		end
		if layout then
			local content = Mock.contentSize(layout)
			if h == 0 then
				h = content.Y
			end
			if w == 0 then
				w = content.X
			end
		elseif instance.__ClassName == "TextLabel"
			or instance.__ClassName == "TextButton"
			or instance.__ClassName == "TextBox" then
			-- No layout: text elements measure their own text (+padding),
			-- the way Roblox's real AutomaticSize does.
			local text = tostring(instance.__Properties.Text or "")
			local textSize = instance.__Properties.TextSize or 12
			if automatic == Enum.AutomaticSize.X and w == 0 and text ~= "" then
				local padX = 0
				for i = 1, #instance.__Children do
					if instance.__Children[i].__ClassName == "UIPadding" then
						local pad = instance.__Children[i].__Properties
						padX = (pad.PaddingLeft and pad.PaddingLeft.Offset or 0)
							+ (pad.PaddingRight and pad.PaddingRight.Offset or 0)
					end
				end
				w = math.ceil(#text * textSize * 0.52) + padX
			end
			if (automatic == Enum.AutomaticSize.Y or automatic == Enum.AutomaticSize.XY)
				and h == 0
				and text ~= "" then
				local lines = 1
				local charWidth = textSize * 0.52
				if w > 0 and #text * charWidth > w then
					lines = math.ceil((#text * charWidth) / w)
				end
				h = math.ceil(lines * (textSize + 3))
			end
		end
	end

	return Vector2.new(w, h)
end

function Mock.contentSize(layout)
	if sizeInProgress[layout] then
		return sizeCache[layout] or Vector2.new(0, 0)
	end

	sizeInProgress[layout] = true
	local ok, result = pcall(Mock._computeContentSize, layout)
	sizeInProgress[layout] = nil

	if not ok then
		error(result, 2)
	end

	sizeCache[layout] = result
	return result
end

function Mock._computeContentSize(layout)
	local parent = layout.__Properties.Parent
	if not isInstance(parent) then
		return Vector2.new(0, 0)
	end

	local horizontal = layout.__Properties.FillDirection == Enum.FillDirection.Horizontal
	local padding = (layout.__Properties.Padding and layout.__Properties.Padding.Offset) or 0

	local padTop, padBottom, padLeft, padRight = 0, 0, 0, 0
	local totalMain, totalCross = 0, 0
	local count = 0

	for i = 1, #parent.__Children do
		local child = parent.__Children[i]
		if child.__ClassName == "UIPadding" then
			padTop = child.__Properties.PaddingTop and child.__Properties.PaddingTop.Offset or 0
			padBottom = child.__Properties.PaddingBottom and child.__Properties.PaddingBottom.Offset or 0
			padLeft = child.__Properties.PaddingLeft and child.__Properties.PaddingLeft.Offset or 0
			padRight = child.__Properties.PaddingRight and child.__Properties.PaddingRight.Offset or 0
		end
	end

	for i = 1, #parent.__Children do
		local child = parent.__Children[i]
		if child ~= layout and child.__ClassName ~= "UIPadding" then
			local size = Mock.absoluteSize(child)
			if horizontal then
				totalMain = totalMain + size.X
				totalCross = math.max(totalCross, size.Y)
			else
				totalMain = totalMain + size.Y
				totalCross = math.max(totalCross, size.X)
			end
			count = count + 1
		end
	end

	if count > 1 then
		totalMain = totalMain + padding * (count - 1)
	end

	if horizontal then
		return Vector2.new(totalMain + padLeft + padRight, totalCross + padTop + padBottom)
	end
	return Vector2.new(totalCross + padLeft + padRight, totalMain + padTop + padBottom)
end

--- Refresh every UIListLayout that could be affected by `instance`.
local function invalidateLayouts(instance)
	local current = instance
	local depth = 0
	while isInstance(current) and depth < 12 do
		for i = 1, #current.__Children do
			local child = current.__Children[i]
			if child.__ClassName == "UIListLayout" then
				local before = child.__Properties.AbsoluteContentSize or Vector2.new(0, 0)
				local after = Mock.contentSize(child)
				if before.X ~= after.X or before.Y ~= after.Y then
					child.__Properties.AbsoluteContentSize = after
					local signal = child.__PropertySignals.AbsoluteContentSize
					if signal then
						signal:Fire()
					end
				end
			end
		end
		current = current.__Properties.Parent
		depth = depth + 1
	end
end

function Mock.absolutePosition(instance)
	local parent = instance.__Properties.Parent
	local base = Vector2.new(0, 0)
	if isInstance(parent) then
		base = Mock.absolutePosition(parent)
	end

	local p = parentSize(instance)
	local size = Mock.absoluteSize(instance)
	local position = instance.__Properties.Position or UDim2.new(0, 0, 0, 0)
	local anchor = instance.__Properties.AnchorPoint or Vector2.new(0, 0)

	return Vector2.new(
		base.X + (position.X.Scale or 0) * p.X + (position.X.Offset or 0) - anchor.X * size.X,
		base.Y + (position.Y.Scale or 0) * p.Y + (position.Y.Offset or 0) - anchor.Y * size.Y
	)
end

----------------------------------------------------------------------
-- Instance metatable
----------------------------------------------------------------------

function InstanceLib:__index(key)
	if key == "ClassName" then
		return self.__ClassName
	end

	if key == "AbsoluteSize" then
		return Mock.absoluteSize(self)
	end

	if key == "AbsolutePosition" then
		return Mock.absolutePosition(self)
	end

	if key == "AbsoluteContentSize" then
		return Mock.contentSize(self)
	end

	if key == "TextBounds" then
		local text = tostring(self.__Properties.Text or "")
		local size = self.__Properties.TextSize or 12
		return Vector2.new(#text * size * 0.55, size + 4)
	end

	if InstanceMethods[key] then
		return InstanceMethods[key]
	end

	if EVENTS[key] then
		if not self.__Signals[key] then
			self.__Signals[key] = Signal.new(self.__ClassName .. "." .. key)
		end
		return self.__Signals[key]
	end

	local schema = ALLOWED[self.__ClassName]
	if schema and schema[key] then
		return self.__Properties[key]
	end

	if schema == nil then
		-- Untyped class (services etc.): fall through to the property table.
		return self.__Properties[key]
	end

	error(string.format("%s is not a valid member of %s", tostring(key), self.__ClassName), 2)
end

function InstanceLib:__newindex(key, value)
	if key == "Parent" then
		local old = self.__Properties.Parent

		if isInstance(old) then
			for i = 1, #old.__Children do
				if old.__Children[i] == self then
					table.remove(old.__Children, i)
					break
				end
			end
			invalidateLayouts(old)
		end

		self.__Properties.Parent = value

		if isInstance(value) then
			table.insert(value.__Children, self)
			invalidateLayouts(value)
		end

		local signal = self.__PropertySignals.Parent
		if signal then
			signal:Fire(value)
		end
		return
	end

	local schema = ALLOWED[self.__ClassName]
	if schema and not schema[key] then
		error(string.format("%s is not a valid member of %s", tostring(key), self.__ClassName), 2)
	end

	if schema and READONLY[key] and key ~= "Parent" then
		error(string.format("%s is read-only on %s", tostring(key), self.__ClassName), 2)
	end

	if self.__Properties[key] == value then
		return
	end

	self.__Properties[key] = value

	if key == "Size" or key == "Visible" or key == "Text" or key == "AutomaticSize" then
		invalidateLayouts(self)
	end

	local signal = self.__PropertySignals[key]
	if signal then
		signal:Fire(value)
	end

	local changed = self.__Signals.Changed
	if changed then
		changed:Fire(key)
	end
end

function InstanceLib:__tostring()
	return self.__Properties.Name or self.__ClassName
end

----------------------------------------------------------------------
-- Instance methods
----------------------------------------------------------------------

function InstanceMethods:Destroy()
	if self.__Destroyed then
		return
	end
	self.__Destroyed = true
	self.Parent = nil
	for i = #self.__Children, 1, -1 do
		self.__Children[i]:Destroy()
	end
	for i = #allInstances, 1, -1 do
		if allInstances[i] == self then
			table.remove(allInstances, i)
			break
		end
	end
end

function InstanceMethods:GetChildren()
	local out = {}
	for i = 1, #self.__Children do
		out[i] = self.__Children[i]
	end
	return out
end

function InstanceMethods:GetDescendants()
	local out = {}
	local function walk(node)
		for i = 1, #node.__Children do
			table.insert(out, node.__Children[i])
			walk(node.__Children[i])
		end
	end
	walk(self)
	return out
end

function InstanceMethods:FindFirstChild(name, recursive)
	for i = 1, #self.__Children do
		if self.__Children[i].Name == name then
			return self.__Children[i]
		end
	end
	if recursive then
		local descendants = self:GetDescendants()
		for i = 1, #descendants do
			if descendants[i].Name == name then
				return descendants[i]
			end
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildOfClass(className)
	for i = 1, #self.__Children do
		if self.__Children[i].ClassName == className then
			return self.__Children[i]
		end
	end
	return nil
end

function InstanceMethods:FindFirstAncestorOfClass(className)
	local current = self.__Properties.Parent
	while isInstance(current) do
		if current.ClassName == className then
			return current
		end
		current = current.__Properties.Parent
	end
	return nil
end

function InstanceMethods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	error(string.format("Infinite yield possible on WaitForChild(%q)", tostring(name)), 2)
end

-- Real IsA walks the class hierarchy; matching only on the exact class name
-- makes IsA("GuiObject") silently false and lets assertions that guard on
-- it pass without ever running.
local CLASS_ANCESTRY = {
	Frame          = { "GuiObject", "GuiBase2d" },
	TextLabel      = { "GuiObject", "GuiBase2d" },
	TextButton     = { "GuiObject", "GuiBase2d" },
	TextBox        = { "GuiObject", "GuiBase2d" },
	ImageLabel     = { "GuiObject", "GuiBase2d" },
	ImageButton    = { "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" },
	ScreenGui      = { "LayerCollector", "GuiBase2d" },
	UIListLayout   = { "UILayout", "UIComponent" },
	UIGridLayout   = { "UILayout", "UIComponent" },
	UICorner       = { "UIComponent" },
	UIStroke       = { "UIComponent" },
	UIPadding      = { "UIComponent" },
	UIGradient     = { "UIComponent" },
	UIScale        = { "UIComponent" },
	UISizeConstraint = { "UIComponent" },
}

function InstanceMethods:IsA(className)
	if self.__ClassName == className then
		return true
	end

	local ancestors = CLASS_ANCESTRY[self.__ClassName]
	if ancestors then
		for i = 1, #ancestors do
			if ancestors[i] == className then
				return true
			end
		end
	end

	return className == "Instance"
end

function InstanceMethods:IsDescendantOf(ancestor)
	local current = self.__Properties.Parent
	while isInstance(current) do
		if current == ancestor then
			return true
		end
		current = current.__Properties.Parent
	end
	return false
end

function InstanceMethods:IsAncestorOf(descendant)
	return isInstance(descendant) and descendant:IsDescendantOf(self)
end

function InstanceMethods:ClearAllChildren()
	for i = #self.__Children, 1, -1 do
		self.__Children[i]:Destroy()
	end
end

function InstanceMethods:GetPropertyChangedSignal(property)
	if not self.__PropertySignals[property] then
		self.__PropertySignals[property] = Signal.new(self.__ClassName .. "." .. property)
	end
	return self.__PropertySignals[property]
end

function InstanceMethods:GetAttributeChangedSignal(name)
	return Signal.new("AttributeChanged." .. tostring(name))
end

function InstanceMethods:SetAttribute(name, value)
	self.__Attributes = self.__Attributes or {}
	self.__Attributes[name] = value
end

function InstanceMethods:GetAttribute(name)
	self.__Attributes = self.__Attributes or {}
	return self.__Attributes[name]
end

function InstanceMethods:Clone()
	local clone = newInstance(self.__ClassName)
	for key, value in pairs(self.__Properties) do
		if key ~= "Parent" then
			clone.__Properties[key] = value
		end
	end
	for i = 1, #self.__Children do
		self.__Children[i]:Clone().Parent = clone
	end
	return clone
end

function InstanceMethods:IsFocused()
	return rawget(self, "__Focused") == true
end

function InstanceMethods:CaptureFocus()
	rawset(self, "__Focused", true)
	local signal = self.__Signals.Focused
	if signal then
		signal:Fire()
	end
end

function InstanceMethods:ReleaseFocus(submitted)
	rawset(self, "__Focused", false)
	if submitted then
		local signal = self.__Signals.FocusLost
		if signal then
			signal:Fire(true)
		end
	end
end

Instance.new = newInstance

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------

local function makeSignalHolder(names)
	local holder = newLoose("Service")
	holder.Name = "Service"
	for i = 1, #names do
		holder.__Signals[names[i]] = Signal.new(names[i])
	end
	return holder
end

local TweenService = newLoose("Service")
TweenService.Name = "TweenService"
function TweenService:Create(instance, info, properties)
	return {
		Instance = instance,
		TweenInfo = info,
		Properties = properties,
		Completed = Signal.new("Completed"),
		Play = function(tween)
			for property, value in pairs(tween.Properties) do
				instance[property] = value
			end
			table.insert(Mock.CompletedTweens, tween)
			Mock.TweenCount = Mock.TweenCount + 1
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end,
		Cancel = function() end,
	}
end

local UserInputService = newLoose("Service")
UserInputService.Name = "UserInputService"
UserInputService.__Signals.InputBegan = Signal.new("InputBegan")
UserInputService.__Signals.InputChanged = Signal.new("InputChanged")
UserInputService.__Signals.InputEnded = Signal.new("InputEnded")
UserInputService.__Properties.MouseLocation = Vector2.new(800, 450)
UserInputService.GetMouseLocation = function()
	return UserInputService.__Properties.MouseLocation
end
UserInputService.GetScreenResolution = function()
	return SCREEN
end

local RunService = newLoose("Service")
RunService.Name = "RunService"
RunService.__Signals.RenderStepped = Signal.new("RenderStepped")
RunService.__Signals.Heartbeat = Signal.new("Heartbeat")
RunService.IsStudio = function()
	return false
end

local TextService = newLoose("Service")
TextService.Name = "TextService"
-- Approximates TextService:GetTextSize closely enough to exercise layout
-- code: a fixed advance per character, wrapped against the given bounds.
TextService.GetTextSize = function(_, text, size, font, bounds)
	text = tostring(text)
	size = size or 12

	local charWidth = size * 0.55
	local lineHeight = size + 4
	local maxWidth = bounds and bounds.X or math.huge

	if text == "" then
		return Vector2.new(0, 0)
	end

	if maxWidth == math.huge or maxWidth <= 0 then
		return Vector2.new(#text * charWidth, lineHeight)
	end

	local perLine = math.max(1, math.floor(maxWidth / charWidth))
	local lines = 0
	for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
		lines = lines + math.max(1, math.ceil(#paragraph / perLine))
	end

	return Vector2.new(math.min(#text * charWidth, maxWidth), lines * lineHeight)
end

local HttpService = newLoose("Service")
HttpService.Name = "HttpService"

local Players = newLoose("Service")
Players.Name = "Players"

local camera = newInstance("Camera")
camera.Name = "Camera"
camera.__Properties.ViewportSize = SCREEN

local workspace = newLoose("Workspace")
workspace.Name = "workspace"
workspace.__Properties.CurrentCamera = camera

local LocalPlayer = newLoose("Player")
LocalPlayer.Name = "LocalPlayer"
LocalPlayer.GetMouse = function()
	return { X = 800, Y = 450 }
end

Players.__Properties.LocalPlayer = LocalPlayer

local PlayerGui = newLoose("PlayerGui")
PlayerGui.Name = "PlayerGui"
PlayerGui.Parent = LocalPlayer

local game = newLoose("DataModel")
game.Name = "game"
game.ClassName = "DataModel"

local SERVICES = {
	TweenService = TweenService,
	UserInputService = UserInputService,
	RunService = RunService,
	TextService = TextService,
	HttpService = HttpService,
	Players = Players,
	Workspace = workspace,
	CoreGui = nil,
}

function game:GetService(name)
	if name == "CoreGui" then
		-- Force the PlayerGui fallback path unless the test opts in.
		if not Mock.EnableCoreGui then
			error("CoreGui is not accessible", 2)
		end
		SERVICES.CoreGui = SERVICES.CoreGui or (function()
			local cg = newInstance("Folder")
			cg.Name = "CoreGui"
			return cg
		end)()
		return SERVICES.CoreGui
	end

	local service = SERVICES[name]
	if not service then
		error(string.format("Cannot get service %q", tostring(name)), 2)
	end
	return service
end

function game:HttpGet(url)
	return Mock.HttpGet(url)
end

function game:HttpGetAsync(url)
	return Mock.HttpGet(url)
end

function game:IsLoaded()
	return true
end

----------------------------------------------------------------------
-- Globals the engine expects
----------------------------------------------------------------------

Mock.CompletedTweens = {}
Mock.TweenCount = 0
Mock.DelayedCallbacks = {}
Mock.EnableCoreGui = false

function Mock.HttpGet(url)
	if type(__readFile) ~= "function" then
		error("[mock] __readFile is not wired up", 2)
	end

	-- https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>
	local path = string.match(tostring(url), "raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
	if not path then
		error("[mock] unrecognised URL: " .. tostring(url), 2)
	end

	local source = __readFile(path)
	if source == nil then
		error("[mock] no such module: " .. path, 2)
	end
	return source
end

local function typeOf(value)
	if value == nil then
		return "nil"
	end
	if isInstance(value) then
		if value.ClassName == "LocalPlayer" then
			return "Instance"
		end
		return "Instance"
	end

	local t = type(value)
	if t == "table" then
		if value.__type then
			return value.__type
		end
		if value.EnumType then
			return "EnumItem"
		end
		if value.Connected ~= nil and value._handler then
			return "RBXScriptConnection"
		end
		return "table"
	end
	if t == "function" then
		return "function"
	end
	if t == "string" then
		return "string"
	end
	if t == "number" then
		return "number"
	end
	if t == "boolean" then
		return "boolean"
	end
	if t == "userdata" then
		return "userdata"
	end
	return t
end

local function warn_(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(Mock.Warnings, table.concat(parts, " "))
end

local rawerror = error
local function error_(message, level)
	rawerror(message, 0)
end

----------------------------------------------------------------------
-- Install into globals
----------------------------------------------------------------------

local G = _G
G.Instance = Instance
G.Enum = Enum
G.UDim = UDim
G.UDim2 = UDim2
G.Vector2 = Vector2
G.Vector3 = Vector3
G.Color3 = Color3
G.Rect = { new = function(x0, y0, x1, y1)
	return setmetatable({ Min = Vector2.new(x0, y0), Max = Vector2.new(x1, y1) }, { __type = "Rect" })
end }
G.NumberSequence = NumberSequence
G.NumberSequenceKeypoint = NumberSequenceKeypoint
G.ColorSequence = ColorSequence
G.ColorSequenceKeypoint = ColorSequenceKeypoint
G.TweenInfo = TweenInfo_
G.game = game
G.workspace = workspace
G.typeof = typeOf
G.warn = warn_
G.error = error_
G.loadstring = load
G.getgenv = function()
	return G
end
G.Identifiers = nil

G.task = {
	wait = function(duration)
		return 0
	end,
	spawn = function(fn, ...)
		local args = { ... }
		table.insert(Mock.DelayedCallbacks, function()
			fn(table.unpack(args))
		end)
	end,
	delay = function(duration, fn, ...)
		local args = { ... }
		table.insert(Mock.DelayedCallbacks, function()
			fn(table.unpack(args))
		end)
	end,
	defer = function(fn, ...)
		local args = { ... }
		table.insert(Mock.DelayedCallbacks, function()
			fn(table.unpack(args))
		end)
	end,
	cancel = function() end,
}

G.wait = G.task.wait
G.spawn = G.task.spawn

Mock.Warnings = {}
Mock.Enum = Enum
Mock.newInstance = newInstance
Mock.isInstance = isInstance
Mock.Signal = Signal
Mock.Services = {
	TweenService = TweenService,
	UserInputService = UserInputService,
	RunService = RunService,
	TextService = TextService,
	Players = Players,
}
Mock.SCREEN = SCREEN

----------------------------------------------------------------------
-- Test helpers
----------------------------------------------------------------------

--- Simulates a mouse click on an instance that has click handlers.
function Mock.click(instance)
	assert(isInstance(instance), "Mock.click expects an Instance")
	if not instance.__Signals.MouseButton1Click then
		error("instance has no MouseButton1Click handlers", 2)
	end
	instance.__Signals.MouseButton1Click:Fire()
end

function Mock.hover(instance)
	if instance.__Signals.MouseEnter then
		instance.__Signals.MouseEnter:Fire()
	end
end

function Mock.unhover(instance)
	if instance.__Signals.MouseLeave then
		instance.__Signals.MouseLeave:Fire()
	end
end

--- Fires a global input event: { KeyCode, UserInputType, Position }
function Mock.inputBegan(input)
	input = input or {}
	input.Position = input.Position or Vector3.new(800, 450, 0)
	UserInputService.__Signals.InputBegan:Fire(input, false)
end

function Mock.inputChanged(input)
	input = input or {}
	input.Position = input.Position or Vector3.new(800, 450, 0)
	UserInputService.__Signals.InputChanged:Fire(input, false)
end

function Mock.inputEnded(input)
	input = input or {}
	input.Position = input.Position or Vector3.new(800, 450, 0)
	UserInputService.__Signals.InputEnded:Fire(input, false)
end

--- Runs everything queued by task.delay / task.spawn.
function Mock.flush()
	local iterations = 0
	while #Mock.DelayedCallbacks > 0 and iterations < 50 do
		local queue = Mock.DelayedCallbacks
		Mock.DelayedCallbacks = {}
		for i = 1, #queue do
			queue[i]()
		end
		iterations = iterations + 1
	end
end

--- Counts how many instances of a class exist in a tree.
function Mock.countClass(root, className)
	local count = 0
	local function walk(node)
		for i = 1, #node.__Children do
			local child = node.__Children[i]
			if child.ClassName == className then
				count = count + 1
			end
			walk(child)
		end
	end
	walk(root)
	return count
end

function Mock.countAll(root)
	local count = 0
	local function walk(node)
		for i = 1, #node.__Children do
			count = count + 1
			walk(node.__Children[i])
		end
	end
	walk(root)
	return count
end

function Mock.findByPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

_G.__MOCK = Mock
_G.Mock = Mock

return Mock

--[[
	tests/preview.lua
	====================================================================
	Serialises the live instance tree (built by whichever example ran
	before it -- tests/preview.js runs examples/Abyss.lua) into JSON,
	so tests/preview.js can file it under preview/ and the browser
	renderer in preview/ can paint the exact same layout the engine
	would draw in Roblox.

	Only layout-relevant properties make the trip. Runs at the end of
	the preview boot sequence; `_G.__PREVIEW__` carries the namespace.
	====================================================================
]]

local UI = _G.__PREVIEW__
assert(UI and UI.ScreenGui, "preview needs a built UI namespace")


-- Tiny JSON encoder
----------------------------------------------------------------------

local function encode(value)
	local kind = type(value)
	if kind == "nil" then
		return "null"
	end
	if kind == "boolean" then
		return value and "true" or "false"
	end
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "0"
		end
		if math.floor(value) == value and math.abs(value) < 2 ^ 31 then
			return tostring(value)
		end
		return string.format("%.4f", value)
	end
	if kind == "string" then
		return string.format("%q", value)
	end
	if kind == "table" then
		-- Array?
		local max = 0
		local count = 0
		for key in pairs(value) do
			if type(key) == "number" then
				max = math.max(max, key)
				count = count + 1
			else
				max = -1
				break
			end
		end

		local out = {}
		if max > 0 and count == max then
			for i = 1, max do
				out[i] = encode(value[i])
			end
			return "[" .. table.concat(out, ",") .. "]"
		end

		for key, item in pairs(value) do
			out[#out + 1] = encode(tostring(key)) .. ":" .. encode(item)
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "\"<" .. kind .. ">\""
end


-- Property helpers
----------------------------------------------------------------------

local function color3(value)
	return { r = math.floor(value.R * 255 + 0.5), g = math.floor(value.G * 255 + 0.5), b = math.floor(value.B * 255 + 0.5) }
end

local function udim(value)
	return { s = value.Scale, o = value.Offset }
end

local function udim2(value)
	return { x = udim(value.X), y = udim(value.Y) }
end

local function vector2(value)
	return { x = value.X, y = value.Y }
end

local TEXTUAL = { TextLabel = true, TextButton = true, TextBox = true }
local VISIBLE_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ScrollingFrame = true,
	ScreenGui = true,
}


-- Tree walker
----------------------------------------------------------------------

local function decorateGradient(node, instance)
	local colorSeq = instance.Color
	local transSeq = instance.Transparency

	if typeof(colorSeq) == "ColorSequence" then
		node.color = {}
		for _, keypoint in ipairs(colorSeq.Keypoints) do
			node.color[#node.color + 1] = {
				t = keypoint.Time,
				r = math.floor(keypoint.Value.R * 255 + 0.5),
				g = math.floor(keypoint.Value.G * 255 + 0.5),
				b = math.floor(keypoint.Value.B * 255 + 0.5),
			}
		end
	end

	if typeof(transSeq) == "NumberSequence" then
		node.alpha = {}
		for _, keypoint in ipairs(transSeq.Keypoints) do
			node.alpha[#node.alpha + 1] = { t = keypoint.Time, a = keypoint.Value }
		end
	end
	node.rotation = instance.Rotation or 0
end

local function serialise(instance)
	local className = instance.ClassName
	local node = { name = instance.Name, class = className }

	if className == "ScreenGui" then
		-- A ScreenGui spans the whole viewport; nothing to style.
		node.size = { x = { s = 1, o = 0 }, y = { s = 1, o = 0 } }
		node.position = { x = { s = 0, o = 0 }, y = { s = 0, o = 0 } }
		node.anchor = { x = 0, y = 0 }
		node.zIndex = 1
		node.visible = true
		node.layoutOrder = 0
		node.bg = { r = 0, g = 0, b = 0 }
		node.bgAlpha = 1
		node.clips = false
		node.autoSize = "Enum.AutomaticSize.None"

		local children = {}
		for _, child in ipairs(instance:GetChildren()) do
			local childNode = serialise(child)
			if childNode then
				children[#children + 1] = childNode
			end
		end
		if #children > 0 then
			node.children = children
		end
		return node
	end

	if className == "UICorner" then
		node.radius = instance.CornerRadius.Offset
		return node
	end

	if className == "UIStroke" then
		node.color = color3(instance.Color)
		node.thickness = instance.Thickness
		node.transparency = instance.Transparency
		return node
	end

	if className == "UIPadding" then
		node.left = instance.PaddingLeft.Offset
		node.right = instance.PaddingRight.Offset
		node.top = instance.PaddingTop.Offset
		node.bottom = instance.PaddingBottom.Offset
		return node
	end

	if className == "UIListLayout" then
		node.padding = instance.Padding.Offset
		node.horizontal = instance.FillDirection == Enum.FillDirection.Horizontal
		node.xAlign = tostring(instance.HorizontalAlignment)
		node.yAlign = tostring(instance.VerticalAlignment)
		return node
	end

	if className == "UIGradient" then
		decorateGradient(node, instance)
		return node
	end

	if not VISIBLE_CLASSES[className] then
		return nil
	end

	node.size = udim2(instance.Size)
	node.position = udim2(instance.Position)
	node.anchor = vector2(instance.AnchorPoint)
	node.zIndex = instance.ZIndex
	node.visible = instance.Visible
	node.layoutOrder = instance.LayoutOrder or 0
	node.bg = color3(instance.BackgroundColor3)
	node.bgAlpha = instance.BackgroundTransparency
	node.clips = instance.ClipsDescendants
	node.autoSize = tostring(instance.AutomaticSize)

	if TEXTUAL[className] then
		node.text = instance.Text
		node.textSize = instance.TextSize
		node.font = tostring(instance.Font)
		node.textColor = color3(instance.TextColor3)
		node.textAlpha = instance.TextTransparency or 0
		node.xAlign = tostring(instance.TextXAlignment)
		node.yAlign = tostring(instance.TextYAlignment)
		node.truncate = instance.TextTruncate ~= Enum.TextTruncate.None
		node.strokeAlpha = instance.TextStrokeTransparency or 1
	end

	if className == "ScrollingFrame" then
		node.scrollbar = instance.ScrollBarThickness
		node.scrollbarColor = color3(instance.ScrollBarImageColor3)
	end

	local children = {}
	for _, child in ipairs(instance:GetChildren()) do
		local childNode = serialise(child)
		if childNode then
			children[#children + 1] = childNode
		end
	end
	if #children > 0 then
		node.children = children
	end

	return node
end

----
-- Emit
----------------------------------------------------------------------

local root = UI.ScreenGui
local Mock = _G.__MOCK

local payload = {
	screen = { x = Mock.SCREEN.X, y = Mock.SCREEN.Y },
	screenGuiName = root.Name,
	tree = serialise(root),
}

return encode(payload)

--[[
	Core/Util/Color.lua
	====================================================================
	Colour maths: hex <-> RGB <-> HSV, lerping, and readable text
	picking. Written against plain Color3 methods so it works on every
	executor (no dependency on Color3.fromHex, which is newer).
	====================================================================
]]

return function(UI)
	local Color = {}

	function Color.Clamp(x, minValue, maxValue)
		if x < minValue then
			return minValue
		end
		if x > maxValue then
			return maxValue
		end
		return x
	end

	function Color.Lerp(a, b, t)
		return a + (b - a) * Color.Clamp(t, 0, 1)
	end

	--- Blend two Color3s. t = 0 returns a, t = 1 returns b.
	function Color.Mix(a, b, t)
		t = Color.Clamp(t, 0, 1)
		return Color3.new(
			Color.Lerp(a.R, b.R, t),
			Color.Lerp(a.G, b.G, t),
			Color.Lerp(a.B, b.B, t)
		)
	end

	--- Color3 -> "RRGGBB" (no leading #).
	function Color.ToHex(color)
		local r = math.floor(Color.Clamp(color.R, 0, 1) * 255 + 0.5)
		local g = math.floor(Color.Clamp(color.G, 0, 1) * 255 + 0.5)
		local b = math.floor(Color.Clamp(color.B, 0, 1) * 255 + 0.5)
		return string.format("%02X%02X%02X", r, g, b)
	end

	--- "RRGGBB" or "#RRGGBB" -> Color3. Returns nil if malformed.
	function Color.FromHex(hex)
		if type(hex) ~= "string" then
			return nil
		end

		hex = string.gsub(hex, "^#", "")
		hex = string.gsub(hex, "%s", "")

		if #hex == 3 then
			local r, g, b = string.match(hex, "(%x)(%x)(%x)")
			if not r then
				return nil
			end
			return Color3.fromRGB(tonumber(r .. r, 16), tonumber(g .. g, 16), tonumber(b .. b, 16))
		end

		if #hex ~= 6 then
			return nil
		end

		local r, g, b = string.match(hex, "(%x%x)(%x%x)(%x%x)")
		if not r then
			return nil
		end

		return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
	end

	--- Color3 -> h, s, v   (h in 0..360, s/v in 0..1)
	function Color.ToHSV(color)
		return color:ToHSV()
	end

	--- h (0..360), s (0..1), v (0..1) -> Color3
	function Color.FromHSV(h, s, v)
		return Color3.fromHSV(Color.Clamp(h, 0, 360) / 360, Color.Clamp(s, 0, 1), Color.Clamp(v, 0, 1))
	end

	--- Perceived brightness, 0..1. Used to decide black/white text.
	function Color.Brightness(color)
		return (color.R * 0.299 + color.G * 0.587 + color.B * 0.114)
	end

	--- Returns white or black text colour depending on the backdrop.
	function Color.ReadableOn(color)
		if Color.Brightness(color) > 0.6 then
			return Color3.fromRGB(16, 16, 20)
		end
		return Color3.fromRGB(255, 255, 255)
	end

	--- Darkens (amount < 0) or lightens (amount > 0) by a 0..1 factor.
	function Color.Shade(color, amount)
		if amount >= 0 then
			return Color.Mix(color, Color3.new(1, 1, 1), amount)
		end
		return Color.Mix(color, Color3.new(0, 0, 0), -amount)
	end

	UI.Util.Color = Color
end

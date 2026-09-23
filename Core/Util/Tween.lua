--[[
	Core/Util/Tween.lua
	====================================================================
	Thin wrapper over TweenService with sane defaults, plus a registry
	so we can cancel in-flight tweens on an instance before starting a
	new one (otherwise rapid hovering causes property fighting).
	====================================================================
]]

return function(UI)
	local Env = UI.Env
	local Tween = {}

	Tween.Easing = Enum.EasingStyle.Quad
	Tween.Direction = Enum.EasingDirection.Out

	local running = setmetatable({}, { __mode = "k" }) -- instance -> {tween}

	function Tween.Info(duration, style, direction)
		return TweenInfo.new(
			duration or 0.2,
			style or Tween.Easing,
			direction or Tween.Direction
		)
	end

	--- Play a tween. Returns the Tween object (already playing).
	function Tween.Play(instance, info, properties, callback)
		if typeof(instance) ~= "Instance" then
			return nil
		end

		Tween.Cancel(instance)

		local tweenService = Env.TweenService
		if not tweenService then
			-- No TweenService (mocked/edge env): apply instantly.
			for property, value in pairs(properties) do
				pcall(function()
					instance[property] = value
				end)
			end
			if callback then
				callback()
			end
			return nil
		end

		if typeof(info) == "number" then
			info = Tween.Info(info)
		end

		local ok, tween = pcall(function()
			return tweenService:Create(instance, info, properties)
		end)

		if not ok or not tween then
			for property, value in pairs(properties) do
				pcall(function()
					instance[property] = value
				end)
			end
			if callback then
				callback()
			end
			return nil
		end

		if callback then
			tween.Completed:Connect(function()
				callback()
			end)
		end

		running[instance] = tween
		tween:Play()
		return tween
	end

	--- Fast default tween (0.18s quad-out) used by almost everything.
	function Tween.Fast(instance, properties, callback)
		return Tween.Play(instance, Tween.Info(UI.Theme.TweenSpeed), properties, callback)
	end

	function Tween.Instant(instance, properties)
		return Tween.Play(instance, Tween.Info(0), properties)
	end

	--- Stop whatever tween is currently animating this instance.
	function Tween.Cancel(instance)
		local tween = running[instance]
		if tween then
			pcall(function()
				tween:Cancel()
			end)
			running[instance] = nil
		end
	end

	UI.Util.Tween = Tween
end

--[[
	Core/Util/Signal.lua
	====================================================================
	A minimal event implementation. Roblox's own events (BindableEvent
	wrappers) are heavier and leak instances; this is a plain table of
	functions and is what every element uses for its .Changed event.
	====================================================================
]]

return function(UI)
	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable({ _handlers = {}, _destroyed = false }, Signal)
	end

	function Signal:Connect(handler)
		assert(typeof(handler) == "function", "Signal:Connect expects a function")

		if self._destroyed then
			-- Already dead: hand back a no-op connection.
			return { Disconnect = function() end, Connected = false }
		end

		local connection = {
			Connected = true,
			_handler = handler,
			_signal = self,
		}

		function connection.Disconnect()
			if not connection.Connected then
				return
			end
			connection.Connected = false

			local handlers = self._handlers
			for i = #handlers, 1, -1 do
				if handlers[i] == connection then
					table.remove(handlers, i)
					break
				end
			end
		end

		table.insert(self._handlers, connection)
		return connection
	end

	-- Roblox-compatible spelling for people used to :connect()
	Signal.connect = Signal.Connect

	function Signal:Fire(...)
		if self._destroyed then
			return
		end

		-- Snapshot: handlers may disconnect themselves mid-fire.
		local snapshot = {}
		for i = 1, #self._handlers do
			snapshot[i] = self._handlers[i]
		end

		for i = 1, #snapshot do
			local connection = snapshot[i]
			if connection.Connected then
				local ok, err = pcall(connection._handler, ...)
				if not ok then
					warn(string.format("[B0XazUI] Signal handler error: %s", tostring(err)))
				end
			end
		end
	end

	function Signal:Wait()
		local thread = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			if connection then
				connection:Disconnect()
			end
			coroutine.resume(thread, ...)
		end)
		return coroutine.yield()
	end

	function Signal:DisconnectAll()
		for i = #self._handlers, 1, -1 do
			self._handlers[i].Connected = false
		end
		self._handlers = {}
	end

	function Signal:Destroy()
		self:DisconnectAll()
		self._destroyed = true
	end

	----------------------------------------------------------------------
	-- Bin: a bucket of connections / instances that cleans up in one call
	----------------------------------------------------------------------
	local Bin = {}
	Bin.__index = Bin

	function Bin.new()
		return setmetatable({ _items = {} }, Bin)
	end

	--- Accepts RBXScriptConnections (anything with :Disconnect), Signals,
	-- or Instances (anything with :Destroy).
	function Bin:Add(item)
		if item then
			table.insert(self._items, item)
		end
		return item
	end

	function Bin:Clean()
		for i = #self._items, 1, -1 do
			local item = self._items[i]
			self._items[i] = nil

			if typeof(item) == "RBXScriptConnection" then
				pcall(function()
					item:Disconnect()
				end)
			elseif typeof(item) == "Instance" then
				pcall(function()
					item:Destroy()
				end)
			elseif type(item) == "table" and type(item.Disconnect) == "function" then
				pcall(function()
					item:Disconnect()
				end)
			elseif type(item) == "table" and type(item.Destroy) == "function" then
				pcall(function()
					item:Destroy()
				end)
			end
		end
	end

	Bin.Destroy = Bin.Clean

	UI.Util.Signal = Signal
	UI.Util.Bin = Bin
end

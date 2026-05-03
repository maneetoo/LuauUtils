--@maneetoo

--!strict

local Safe = require(script.Parent.Safe)
local Stream = require(script.Parent.Stream)
local TSTypes = require(script.Parent.TSTypes)
local Task = require(script.Parent.Task)
local Trove = require(script.Parent.Trove)
local typeof = require(script.Parent.typeof)

--[=[
	@within Types
    @type Connection () -> ()
    Unsubscribe from the event. The call disables the listener
]=]
export type Connection = () -> ()

--[=[
	@within Types
    @class Signal<T...>
	An extended reactive signal with chained operators.
	Inherits all Event methods.
	@param T... Types of the source signal's arguments
]=]
export type Signal<T...> = {
	__type: "Signal",

	Connect: (callback: (T...) -> ()) -> Connection,
	Once: (callback: (T...) -> ()) -> Connection,
	Fire: (T...) -> (),
	FireDeferred: (T...) -> (),
	Wait: (timeout: number?) -> T...,
	GetListenerCount: () -> number,
	DisconnectAll: () -> (),
	Destroy: () -> (),

	Filter: (predicate: (T...) -> boolean) -> Signal<T...>,
	Map: <U...>(transform: (T...) -> U...) -> Signal<U...>,
	Take: (n: number) -> Signal<T...>,
	Skip: (n: number) -> Signal<T...>,
	Debounce: (seconds: number) -> Signal<T...>,
	Throttle: (seconds: number) -> Signal<T...>,
}

--[=[
	@within Types
    @type CreateSignalModule <T...>() -> Signal<T...>
]=]
export type CreateSignalModule = <T...>() -> Signal<T...>

--[=[
    @class CreateSignal
    
    Extended reactive signal with filtering, mapping.
    Built on `Signal` with automatic lifecycle management via `Trove`
    Inspired from: GoodSignal by stravant
    
    :::info Architecture
    - All chainable operators return new independent signals
    - Internal connections are tracked and cleaned automatically
    :::
]=]

-- Forward declaration to resolve recursive call type error:
-- "Unknown global 'CreateSignal'; consider assigning to it first"
local CreateSignal: CreateSignalModule
CreateSignal = function<T...>(): Signal<T...>
	local listeners: TSTypes.Array<(T...) -> ()> = {}
	local onceListeners: TSTypes.Array<(T...) -> ()> = {}
	local waitingThreads: TSTypes.Array<thread> = {}
	local trove = Trove.new()
	local signal = { __type = "Signal" }

	--[=[
        @within Event
        @param callback (...T) -> ()
        @return () -> () -- Disconnect function
    ]=]
	function signal:Connect(callback: (T...) -> ()): () -> ()
		typeof.assertType(callback, "function", "callback")
		table.insert(listeners, callback)

		return function()
			local idx: number? = table.find(listeners, callback)
			if idx then
				table.remove(listeners, idx)
			end
		end
	end

	--[=[
        @within Event
        @param callback (...T) -> ()
        @return () -> () -- Disconnect function
    ]=]
	function signal:Once(callback: (T...) -> ()): () -> ()
		typeof.assertType(callback, "function", "callback")
		table.insert(onceListeners, callback)

		return function()
			local idx: number? = table.find(onceListeners, callback)
			if idx then
				table.remove(onceListeners, idx)
			end
		end
	end

	--[=[
        @within Event
        @param ... T
        Fires synchronously. Listeners are isolated with `Safe`.
    ]=]
	function signal:Fire(...: T...): ()
		local currentListeners: TSTypes.Array<(T...) -> ()> = table.clone(listeners)
		local currentOnce: TSTypes.Array<(T...) -> ()> = table.clone(onceListeners)
		table.clear(onceListeners)

		local args: { n: number, [number]: any } = table.pack(...)
		Stream(currentListeners):forEach(function(cb)
			Safe({
				try = function()
					cb(table.unpack(args, 1, args.n))
				end,
				fallback = function(err: string)
					error(debug.traceback(`Callback Error: {err}`, 2))
				end,
			})
		end)
		Stream(currentOnce):forEach(function(cb)
			Safe({
				try = function()
					cb(table.unpack(args, 1, args.n))
				end,
				fallback = function(err: string)
					error(debug.traceback(`Callback Error: {err}`, 2))
				end,
			})
		end)

		local currentWaiting: TSTypes.Array<thread> = table.clone(waitingThreads)
		table.clear(waitingThreads)
		for _, thread in currentWaiting do
			task.spawn(thread, table.unpack(args, 1, args.n))
		end
	end

	--[=[
        @within Event
        @param ... T
        Fires asynchronously on next frame via `Concur.defer`.
    ]=]
	function signal:FireDeferred(...: T...): ()
		local args: { n: number, [number]: any } = table.pack(...)
		local tsk: Task.TaskType = Task.new(function()
			signal:Fire(table.unpack(args, 1, args.n))
		end)
		tsk:run()
		trove:Add(function()
			tsk:cancel()
		end)
	end

	--[=[
        @within Event
        @param timeout number?
        @yields
        Yields until fired or timeout. Uses `Concur` for precise timeout management.
    ]=]
	function signal:Wait(timeout: number?): T...
		local thread: thread = coroutine.running()
		table.insert(waitingThreads, thread)
		local timedOut: boolean = false

		local timeoutTask: Task.TaskType? = nil
		if timeout then
			timeoutTask = Task.new(function()
				task.wait(timeout)
				local idx: number? = table.find(waitingThreads, thread)
				if idx then
					table.remove(waitingThreads, idx)
					timedOut = true
					task.spawn(thread)
				end
			end)
			trove:Add(function()
				if timeoutTask and timeoutTask:get_status() ~= "completed" then
					timeoutTask:cancel()
				end
			end)
		end

		local result: { n: number, [number]: any } = table.pack(coroutine.yield())
		if timeoutTask and timeoutTask:get_status() ~= "completed" then
			timeoutTask:cancel()
		end

		if timedOut then
			return nil :: any
		end
		return table.unpack(result, 1, result.n)
	end

	--[=[
        @within Signal
        Disconnect all Listeners & Threads from Signal
    ]=]
	function signal:DisconnectAll(): ()
		table.clear(listeners)
		table.clear(onceListeners)

		for _, thread in waitingThreads do
			task.spawn(thread)
		end
		table.clear(waitingThreads)
	end

	--[=[
        @within Signal
        @param predicate (...T) -> boolean
        @return Signal<T...>
        
        Creates a filtered signal. Only fires when predicate returns true.
    ]=]
	function signal:Filter(predicate: (T...) -> boolean): Signal<T...>
		typeof.assertType(predicate, "function", "predicate")
		local filtered: Signal<T...> = CreateSignal()
		trove:Add(signal:Connect(function(...)
			if predicate(...) then
				filtered:Fire(...)
			end
		end))
		return filtered
	end

	--[=[
        @within Signal
        @param transform (...T) -> U...
        @return Signal<U...>
        
        Creates a mapped signal with transformed values.
        Supports changing argument types via generic <U...>.
    ]=]
	function signal:Map<U...>(transform: (T...) -> U...): Signal<U...>
		typeof.assertType(transform, "function", "transform")
		local mapped: Signal<U...> = CreateSignal()
		trove:Add(signal:Connect(function(...)
			mapped:Fire(transform(...))
		end))
		return mapped
	end

	--[=[
        @within Signal
        @param n number
        @return Signal<T...>
    ]=]
	function signal:Take(n: number): Signal<T...>
		typeof.assertType(n, "number", "n")
		local takeSig: Signal<T...> = CreateSignal()
		local count: number = 0
		trove:Add(signal:Connect(function(...)
			if count < n then
				count += 1
				takeSig:Fire(...)
			end
		end))
		return takeSig
	end

	--[=[
        @within Signal
        @param n number
        @return Signal<T...>
    ]=]
	function signal:Skip(n: number): Signal<T...>
		typeof.assertType(n, "number", "n")
		local skipSig: Signal<T...> = CreateSignal()
		local count: number = 0
		trove:Add(signal:Connect(function(...)
			count += 1
			if count > n then
				skipSig:Fire(...)
			end
		end))
		return skipSig
	end

	--[=[
        @within Signal
        Destroys signal and cleans up all internal connections.
        Uses `Table.Lock` for deep immutability.
    ]=]
	function signal:Destroy(): ()
		trove:Clean()
		table.clear(listeners)
		table.clear(onceListeners)
		table.clear(waitingThreads)
		table.freeze(signal)
	end

	return signal :: Signal<T...>
end

return CreateSignal :: CreateSignalModule

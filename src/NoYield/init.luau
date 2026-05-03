--@maneetoo

--!strict

--[=[
	@class NoYield
	
	A strict runtime guard that prevents coroutine yields inside wrapped functions.
	
	Wraps any function so that if it attempts to yield (task.wait, coroutine.yield, etc.),
	it throws an immediate error with a stack trace instead of silently suspending.
	
	Useful for enforcing synchronous execution in __newindex proxies, reactive state
	handlers, and other contexts where yielding would cause subtle bugs.
]=]

local no_yield = {}

--[=[
	@within no_yield
	@function wrap
	
	Wraps a function so that yielding inside it throws an error.
	Returns the function's results directly on success.
	
	```lua
	local safe = no_yield.wrap(function(x) return x * 2 end)
	print(safe(21)) -- 42
	```
	
	@param func The function to wrap. Must be synchronous (no yields).
	@return A wrapped function with the same signature.
]=]
function no_yield.wrap<T..., V...>(func: (T...) -> V...): (T...) -> V...
	if type(func) ~= "function" then
		error("Argument #1 to no_yield.wrap must be a function")
	end

	return function(...)
		local co: thread = coroutine.create(func)
		local co_result: boolean = coroutine.resume(co, ...)
		if not co_result then
			error(debug.traceback(co, ..., 2))
		end

		if coroutine.status(co) ~= "dead" then
			error(debug.traceback(co, "attempt to yield", 2))
		end

		return ...
	end
end

--[=[
	@within no_yield
	@function wrap_result
	
	Wraps a function so that yielding inside it throws an error.
	Returns a boolean success flag followed by the function's results.
	
	```lua
	local safe = no_yield.wrap_result(riskyOperation)
	local ok, result = safe(...)
	if not ok then
		warn("Operation yielded unexpectedly")
	end
	```
	
	@param func The function to wrap. Must be synchronous (no yields).
	@return A wrapped function returning (boolean, ...results).
]=]
function no_yield.wrap_result<T..., V...>(func: (T...) -> V...): (T...) -> (boolean, V...)
	return function(...)
		local co: thread = coroutine.create(func)
		local co_result: boolean = coroutine.resume(co, ...)
		if not co_result then
			error(debug.traceback(co, ..., 2))
		end

		if coroutine.status(co) ~= "dead" then
			error(debug.traceback(co, "attempt to yield", 2))
		end

		return co_result, ...
	end
end

return setmetatable(no_yield, {
	__call = function<T..., V...>(func: (T...) -> V...): (T...) -> V...
		return no_yield.wrap(func)
	end,
})

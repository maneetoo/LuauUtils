--@maneetoo

--!strict

local typeof = require(script.Parent.typeof)
local TSTypes = require(script.Parent.TSTypes)

--[=[
	@class Switch

	Pattern-matching dispatcher — mirrors Selene's `switch(o, funcs…)`.
	Dispatches a value to the first handler whose predicate returns `true`.

	:::info Behavior
	- Handlers are evaluated **in order**; the first match wins.
	- If no handler matches and no `default` is provided, returns `nil`.
	- A `default` handler always matches (its predicate is `function() return true end`).
	- `Switch.case` and `Switch.default` are pure helpers — they allocate no state.
	:::

	```lua
	local result = Switch(score, {
		Switch.case(function(s) return s >= 90 end, function(_) return "A" end),
		Switch.case(function(s) return s >= 75 end, function(_) return "B" end),
		Switch.default(function(_) return "F" end),
	})
	-- result == "A"  (when score == 95)
	```
]=]


--[=[
	@type SwitchHandler<T, R>
	@within Switch

	A handler pairing a predicate with an action.
	Produced by `Switch.case` and `Switch.default`.
]=]
export type SwitchHandler<T, R> = {
	applies: (T) -> boolean,
	call: (T) -> R,
}


--[=[
	@within Switch
	@param pred (T) -> boolean
	@param fn (T) -> R
	@return SwitchHandler<T, R>

	Creates a conditional handler that fires only when `pred(value)` is `true`.

	```lua
	Switch.case(function(x) return x > 0 end, function(x) return "positive" end)
	```
]=]
local case = function<T, R>(pred: (T) -> boolean, fn: (T) -> R): SwitchHandler<T, R>
	typeof.assertType(pred, "function", "pred")
	typeof.assertType(fn, "function", "fn")
	return { applies = pred, call = fn }
end


--[=[
	@within Switch
	@param fn (T) -> R
	@return SwitchHandler<T, R>

	Creates a fallback handler that always matches.
	Equivalent to `Switch.case(function() return true end, fn)`.

	```lua
	Switch.default(function(_) return "unknown" end)
	```
]=]
local default = function<T, R>(fn: (T) -> R): SwitchHandler<T, R>
	typeof.assertType(fn, "function", "fn")
	return {
		applies = function(_: T): boolean return true end,
		call = fn,
	}
end


--[=[
	@within Switch
	@param value T
	@param handlers { SwitchHandler<T, R> }
	@return R?

	Dispatches `value` to the first matching handler.
	Returns `nil` if no handler matches.

	```lua
	local label = Switch(42, {
		Switch.case(function(n) return n < 0  end, function(_) return "negative" end),
		Switch.case(function(n) return n == 0 end, function(_) return "zero" end),
		Switch.default(function(_) return "positive" end),
	})
	-- label == "positive"
	```
]=]
local switchFn = function<T, R>(value: T, handlers: TSTypes.Array<SwitchHandler<T, R>>): R?
	typeof.assertType(handlers, "table", "handlers")
	if #handlers == 0 then
        error(debug.traceback(`'handlers' must be provided, got nil`))
		return nil
	end

	for _, handler in handlers do
		if handler.applies(value) then
			return handler.call(value)
		end
	end

	return nil
end

local Switch = {
	case = case,
	default = default,
}

return setmetatable(Switch, {
	__call = function<T, R>(_self: any, value: T, handlers: TSTypes.Array<SwitchHandler<T, R>>): R?
		return switchFn(value, handlers)
	end,
})
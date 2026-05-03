--@maneetoo

--!strict

local typeof = require(script.Parent.typeof)

--[=[
    @class Pipe

    Functional left-to-right composition — threads a value through
    an ordered sequence of unary transforms.

    :::info Behavior
    - Transforms are applied **left-to-right** (first argument first).
    - Each function receives the **return value** of the previous one.
    - If the transforms list is empty the original value is returned unchanged.
    - All transforms must be functions; any violation raises an error.
    :::

    ```lua
    local result = Pipe(5,
        function(x) return x * 2  end,  -- 10
        function(x) return x + 3  end,  -- 13
        function(x) return x .. "!" end -- "13!"
    )
    -- result == "13!"
    ```

    :::caution Type Safety
    Luau's type system cannot fully verify heterogeneous pipelines at
    compile time. Cast the result with `:: YourType` when the final type
    is known statically.
    :::
]=]
local Pipe = function<T>(value: T, ...: (any) -> any): any
	local fns = { ... }
	local n: number = select("#", ...)

	for i = 1, n do
		local fn = fns[i]
		if typeof.nativeType(fn) ~= "function" then
			error(debug.traceback(`'transforms[{i}]' must be 'function', got ({typeof.nativeType(fn)}`))
		end
	end

	local result: any = value
	for i = 1, n do
		result = fns[i](result)
	end

	return result
end

return Pipe

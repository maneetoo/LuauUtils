--@maneetoo

--!strict

local TSTypes = require(script.Parent.TSTypes)

--[=[
    @class Assign
    
    A Luau implementation of JavaScript's `Object.assign()`
    Copies all enumerable own properties from one or more source tables
    to a target table and returns the modified target.

    Learn more: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign
    
    :::info Behavior
    - Later sources override earlier ones for the same keys.
    - Only shallow copy (nested tables are copied by reference).
    - Modifies and returns the target table.
    - nil values in sources will NOT override existing keys (Lua behavior).
    :::
    
    :::caution Shallow Copy
    Nested tables are NOT deep copied. Use `Table.DeepCopy` for deep cloning.
    ```lua
    local source = { nested = { value = 1 } }
    local result = Assign({}, source)
    source.nested.value = 999
    print(result.nested.value) --> 999 (same reference!)
    ```
    :::
]=]
local Assign = function<T, V, K>(target: T, ...: TSTypes.Table<V, K>?): T
	local target_table = target :: TSTypes.Table<V, K>

	for i = 1, select("#", ...) do
		local source: any = select(i, ...)
		if source ~= nil and type(source) == "table" then
			for key, value in source do
				target_table[key] = value
			end
		end
	end

	return target
end

return Assign

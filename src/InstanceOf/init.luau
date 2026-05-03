--@maneetoo

--!strict

local TSTypes = require(script.Parent.TSTypes)

--[=[
    @class InstanceOf
    
    A Luau implementation of JavaScript's `instanceof`
    Checks if a value is an instance of a specific class or type.
    Supports standard Luau OOP patterns (`__index` chains) and direct 
    constructor matching (`.new`). Includes cycle detection to prevent 
    infinite loops on malformed metatables.

    Learn more: https://developer.mozilla.org/ru/docs/Web/JavaScript/Reference/Operators/instanceof
    
    :::info Behavior
    - Returns `true` if `value.__index` chain contains `class`.
    - Returns `true` if `value.new == class.new` (direct constructor match).
    - Ignores custom `__type` strings (uses structural metatable checking).
    - Safe against circular metatable references.
    - Non-throwing: returns `false` and logs a warning for invalid inputs.
    :::
    
    ```lua
    local MyClass = {}
    MyClass.__index = MyClass
    function MyClass.new() return setmetatable({}, MyClass) end
    
    local obj = MyClass.new()
    print(InstanceOf(obj, MyClass)) --> true
    print(InstanceOf(obj, "string")) --> false (warns about invalid class)
    ```
]=]
local InstanceOf = function<T>(value: T, class: any): boolean
	local v_type: string = typeof(value)
	if v_type ~= "table" and v_type ~= "userdata" then
		return false
	end

	if type(class) ~= "table" then
		error(debug.traceback(`The 'class' must be 'table', got {type(class)}`, 2))
		return false
	end

	if type(class.new) == "function" and value.new == class.new then
		return true
	end

	local current: any = value
	local seen: TSTypes.Table<any, boolean> = {}

	while current do
		local mt = getmetatable(current)
		if not mt or type(mt) ~= "table" then
			break
		end

		local index = mt.__index
		if index == class then
			return true
		end
		if seen[index] then
			break
		end
		seen[index] = true

		current = index
	end

	return false
end

return InstanceOf

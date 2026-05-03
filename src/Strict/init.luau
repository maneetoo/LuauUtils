--@maneetoo

--!strict

--[=[
    @class strict
    
    Makes a table strict by preventing access to undefined keys.
    Any attempt to read or write to a key that doesn't exist will throw an error.
    Useful for catching typos and enforcing structure in configuration tables.
    
    :::info Behavior
    - Existing keys can be read and modified normally.
    - Accessing undefined keys throws an error.
    - Writing to undefined keys throws an error.
    - The original table is modified (metatable is set).
    :::
    
    :::caution Frozen Tables
    If you want to also prevent modification of existing keys, 
    use `table.freeze()` after `strict()`:
    ```lua
    local ReadOnly = table.freeze(strict({ value = 42 }, "ReadOnly"))
    ReadOnly.value = 0  --> ERROR: cannot modify frozen table
    ```
    :::
]=]
local strict = function<T>(tbl: T, name: string?): T
	local table_name: string = name or tostring(tbl)

	return setmetatable(tbl :: any, {
		__index = function(_self: any, key: any): never
			error(`{key} ({typeof(key)} is not valid member of {table_name}`)
		end,

		__newindex = function(_self: any, key: any, _value: any): never
			error(`{key} ({typeof(key)} is not valid member of {table_name}`)
		end,
	}) :: T
end

return strict

--@maneetoo

--!strict

local Cache = require(script.Parent.Cache)
local Safe = require(script.Parent.Safe)

--[=[
	@within typeof
	@type metatable { __type: string? | ((self: T) -> string) | { name: string }, [string]: any }
	Simple metatable type
]=]
type metatable<T> = {
	__type: string | ((self: T) -> string) | { name: string }?,
	[string]: any,
}

--[=[
	@class typeof
	
	Enhanced `typeof` function that supports custom types via metatables.
	- Detects `__type` field in metatables
	- Supports `__type` as string or function
	- Caches results for performance
	- Provides type checking utilities
	
	```lua
	local typeof = require(path.to.Typeof)
	
	local MyClass = {}
	MyClass.__index = MyClass
	MyClass.__type = "MyClass"
	
	local obj = setmetatable({}, MyClass)
	print(typeof(obj)) -- "MyClass"
	```
]=]

local nativeTypeof = typeof
local typeCache: Cache.CacheType<any, string> = Cache.new(100)

local typeOf = {}

--[=[
	@within typeOf
	@param value T — Any value to check
	@return string — Type name

	Enhanced typeof function.
	
	Checks for custom `__type` in metatables:
	- `__type: string` — returns the string directly
	- `__type: (self) -> string` — calls function with the value
	- `__type: { name: string }` — returns `name` field
]=]
local getType = function<T>(value: T): string
	local nativeType: string = nativeTypeof(value)
	if nativeType ~= "table" and nativeType ~= "userdata" then
		return nativeType
	end

	local cached: string? = typeCache:get(value)
	if cached then
		return cached
	end

	if nativeType == "table" then
		local tbl = value :: any
		if tbl.__type and nativeTypeof(tbl.__type) == "string" then
			nativeType = tbl.__type :: string
			typeCache:set(value, nativeType)
			return nativeType
		end
	end

	local mt: metatable<T>? = getmetatable(value)
	if not mt then
		typeCache:set(value, nativeType)
		return nativeType
	end

	local customType = mt.__type
	if not customType then
		typeCache:set(value, nativeType)
		return nativeType
	end

	local result: string = Safe({
		try = function()
			local customTypeKind: string = nativeTypeof(customType)

			if customTypeKind == "string" then
				return customType :: string
			elseif customTypeKind == "function" then
				local callResult = (customType :: (T) -> string)(value)
				if nativeTypeof(callResult) == "string" then
					return callResult
				else
					error(debug.traceback(`__type function returned non-string value`, 2))
					return nativeType
				end
			elseif customTypeKind == "table" then
				local typeTable = customType :: { name: string }
				if nativeTypeof(typeTable.name) == "string" then
					return typeTable.name
				else
					error(debug.traceback(`__type function returned non-string value`, 2))
					return nativeType
				end
			else
				error(debug.traceback(`'CustomType' must be 'string/function/table/metatable', got {customTypeKind}`))
				return nativeType
			end
		end,
		fallback = function(err: string)
			warn(err)
			return nativeType
		end,
	})

	if nativeType ~= "userdata" then
		typeCache:set(value, result)
	end
	return result
end

--[=[
	@within typeof
	@param value any
	@param typeName string
	@return boolean

	Type checking: `is(value, "typename")`
]=]
function typeOf.is<T>(value: T, typeName: string): boolean
	return getType(value) == typeName
end

--[=[
	@within typeof
	@param value any
	@param ... string — Type names
	@return boolean

	Multiple type check: `isAny(value, "string", "number")`
]=]
function typeOf.isAny<T>(value: T, ...: string): boolean
	local valueType: string = getType(value)
	for i = 1, select("#", ...) do
		if valueType == select(i, ...) then
			return true
		end
	end
	return false
end

--[=[
	@within typeof
	@param value any
	@param expected string
	@param name string? — Variable name for error message

	Asserts type or throws error.
]=]
function typeOf.assertType<T>(value: T, expected: string, name: string?): ()
	if not expected or (expected and nativeTypeof(expected) ~= "string") then
		error(debug.traceback(`'Expected' must be 'string', got {getType(expected)}`, 2))
	end
	local actual = getType(value)
	if actual ~= expected then
		local varName = name or "value"
		error(debug.traceback(`'{varName}' must be '{expected}', got {actual}`, 2))
	end
end

--[=[
	@within typeof
	@param value any
	@return string

	Gets the native type (ignoring custom __type).
]=]
function typeOf.nativeType<T>(value: T): string
	return nativeTypeof(value)
end

return setmetatable(typeOf, {
	__call = function<T>(_, value: T): string
		return getType(value)
	end,
})

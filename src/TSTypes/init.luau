--@maneetoo

--!strict

--[=[
	@class Types
	@package
	
	Some TS Types for fullfil Luau Types
	
	:::info Why
	Luau's type system benefits from explicit type annotations.
	These types serve as documentation and enable better autocompletion.
	:::
	
	:::caution Usage
	These types are structural, not nominal. Two tables with the same shape
	will be assignable to the same type, even if they represent different concepts.
	:::
]=]

--[=[
	@within Types
	@type Object
	
	A dictionary with string keys and any values.
	The default type for most JSON-like data structures.
	
	```lua
	local data: Object = { name = "John", age = 30 }
	```
]=]
export type Object = { [string]: any }

--[=[
	@within Types
	@type Array<T>
	
	An array (list) with numeric keys and elements of type T.
	Use ipairs for iteration, # for length.
	
	```lua
	local numbers: Array<number> = { 1, 2, 3 }
	local strings: Array<string> = { "a", "b" }
	```
]=]
export type Array<T> = { [number]: T }

--[=[
	@within Types
	@type Function
	
	A generic function type accepting any arguments and returning any values.
	Use this as a base type, then refine with specific signatures.
	
	```lua
	local callback: Function = function(...) return ... end
	```
]=]
export type Function = (...any) -> ...any

--[=[
	@within Types
	@type Table<K, V>
	
	A generic table (map) with keys of type K and values of type V.
	More flexible than Object when you need non-string keys.
	
	```lua
	local sym = Symbol("key")
	local data: Table<Symbol, number> = { [sym] = 42 }
	```
]=]
export type Table<K, V> = { [K]: V }

--[=[
	@within Types
	@type Tuple<T, V>
	
	A fixed-length array of exactly two elements, with types T and V.
	Useful for representing pairs, results, or key-value tuples.
	
	```lua
	local pair: Tuple<string, number> = { "age", 30 }
	local result: Tuple<boolean, string> = { true, "success" }
	```
]=]
export type Tuple<T, V> = Array<T | V>

--[=[
	@within Types
	@type Symbol
	
	Represents a Symbol instance created by the Symbol module.
	
	:::info Methods
	- `toString()` - Returns "Symbol(description)" or "Symbol()"
	- `valueOf()` - Returns the symbol itself
	- `description` - Returns the description string, or nil
	:::
	
	:::caution Identity
	Symbols are compared by reference, not by value.
	Use `rawequal` or `Symbol.isSymbol()` for checking.
	:::
	
	```lua
	local sym = Symbol("test")
	print(typeof(sym)) -- "table"
	print(Symbol.isSymbol(sym)) -- true
	```
]=]
export type Symbol = {
	__type: "Symbol",
	toString: (self: Symbol) -> string,
	valueOf: (self: Symbol) -> Symbol,
	description: (self: Symbol) -> string?,
}

return {}

--@maneetoo

--!strict

--[=[
    @class Symbol

    A Luau implementation of JavaScript's `Symbol` primitive.
    Creates unique, immutable identifiers that can be used as table keys
    or to implement well-known protocols (iterator, toPrimitive, etc.).

    Learn more: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Symbol

    :::info Behavior
    - Each call to `Symbol(description?)` creates a **unique** symbol.
    - Symbols are compared by reference (`rawequal`), not by value.
    - `Symbol.for(key)` creates or retrieves a **global** symbol by key.
    - `Symbol.key_for(sym)` returns the key for a globally registered symbol.
    - Symbols cannot be converted to strings via concatenation or arithmetic.
    :::

    :::caution Weak References
    Internal description and reverse-registry tables use weak keys.
    Symbols with no strong references may be garbage collected.
    ```lua
    local sym = Symbol("temporary")
    print(tostring(sym)) --> Symbol(temporary)
    ```
    :::
]=]

local TSTypes = require(script.Parent.TSTypes)

export type Symbol = TSTypes.Symbol
type SymbolDescriptions = TSTypes.Table<Symbol, string?>
type GlobalRegistry = TSTypes.Table<string, Symbol>
type GlobalRegistryRev = TSTypes.Table<Symbol, string>

local symbol_descriptions: SymbolDescriptions = setmetatable({}, { __mode = "k" }) :: any
local global_registry: GlobalRegistry = {}
local global_registry_rev: GlobalRegistryRev = setmetatable({}, { __mode = "k" }) :: any

local symbol_meta = {}
symbol_meta.__index = symbol_meta

symbol_meta.__tostring = function(self: Symbol): string
	local desc: string? = symbol_descriptions[self]
	if desc ~= nil and desc ~= "" then
		return "Symbol(" .. desc .. ")"
	end
	return "Symbol()"
end
symbol_meta.__concat = function(_: any, _2: any): string
	error(debug.traceback("Cannot convert a Symbol value to a string", 2))
end
symbol_meta.__add = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__sub = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__mul = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__div = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__mod = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__pow = function(_: any, _2: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__unm = function(_: any): number
	error(debug.traceback("Cannot convert a Symbol value to a number", 2))
end
symbol_meta.__lt = function(_: any, _2: any): boolean
	error(debug.traceback("Cannot compare Symbol values with relational operators", 2))
end
symbol_meta.__le = function(_: any, _2: any): boolean
	error(debug.traceback("Cannot compare Symbol values with relational operators", 2))
end
symbol_meta.__eq = function(self: Symbol, other: Symbol): boolean
	--> Strict identity comparison — each symbol is unique
	return rawequal(self, other)
end

symbol_meta.__metatable = "Symbol" --> Locks the metatable from external access

--[=[
    @within Symbol
    @private

    Creates a new unique symbol with an optional description.
    This is the internal factory and should not be called directly.
]=]
local create_symbol = function(description: string?): Symbol
	local symbol: TSTypes.Table<any, any> = {}
	setmetatable(symbol, symbol_meta)
	symbol_descriptions[symbol :: any] = description
	return (symbol :: any) :: Symbol
end

--[=[
    @within Symbol
    @private

    Returns `true` if the given value is a Symbol created by this module.
]=]
local is_symbol = function(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	return getmetatable(value) == "Symbol"
end

--[[ Well-Known Symbols ]]

local iterator: Symbol = create_symbol("Symbol.iterator")
local async_iterator: Symbol = create_symbol("Symbol.asyncIterator")
local has_instance: Symbol = create_symbol("Symbol.hasInstance")
local is_concat_spreadable: Symbol = create_symbol("Symbol.isConcatSpreadable")
local species: Symbol = create_symbol("Symbol.species")
local match: Symbol = create_symbol("Symbol.match")
local match_all: Symbol = create_symbol("Symbol.matchAll")
local replace: Symbol = create_symbol("Symbol.replace")
local search: Symbol = create_symbol("Symbol.search")
local split: Symbol = create_symbol("Symbol.split")
local to_primitive: Symbol = create_symbol("Symbol.toPrimitive")
local to_string_tag: Symbol = create_symbol("Symbol.toStringTag")
local unscopables: Symbol = create_symbol("Symbol.unscopables")
local dispose: Symbol = create_symbol("Symbol.dispose")
local async_dispose: Symbol = create_symbol("Symbol.asyncDispose")

--[=[
    @within Symbol

    Retrieves an existing symbol from the global registry by `key`,
    or creates and registers a new one if none exists.

    Mirrors `Symbol.for()` in JavaScript

    @param key string? -- The registry key (defaults to `"undefined"` if nil)
    @return Symbol
]=]
local symbol_for = function(key: string?): Symbol
	local actual_key: string = if key == nil then "undefined" else tostring(key)

	if global_registry[actual_key] ~= nil then
		return global_registry[actual_key]
	end

	local sym: Symbol = create_symbol(actual_key)
	global_registry[actual_key] = sym
	global_registry_rev[sym] = actual_key

	return sym
end

--[=[
    @within Symbol

    Returns the global registry key associated with a symbol,
    or `nil` if the symbol was not created via `Symbol.for()`.

    @param sym Symbol -- Must be a valid Symbol
    @return string?
]=]
local symbol_key_for = function(sym: Symbol): string?
	if not is_symbol(sym) then
		error(debug.traceback("Symbol.key_for requires a symbol argument", 2))
	end
	return global_registry_rev[sym]
end

--[=[
    @within Symbol

    Returns the description string of a symbol, or `nil` if none was provided.

    @param sym Symbol
    @return string?
]=]
local get_description = function(sym: Symbol): string?
	if not is_symbol(sym) then
		return nil
	end
	return symbol_descriptions[sym]
end

local prototype = {}

--[=[
    @within Symbol

    Returns the string representation of the symbol.
    Equivalent to JavaScript's `Symbol.prototype.toString()`.
]=]
function prototype.to_string(self: Symbol): string
	if not is_symbol(self) then
		error(debug.traceback("Symbol.prototype.to_string requires a Symbol", 2))
	end
	return tostring(self)
end

--[=[
    @within Symbol

    Returns the symbol itself.
    Equivalent to JavaScript's `Symbol.prototype.valueOf()`.
]=]
function prototype.value_of(self: Symbol): Symbol
	if not is_symbol(self) then
		error(debug.traceback("Symbol.prototype.value_of requires a Symbol", 2))
	end
	return self
end

--[=[
    @within Symbol

    Returns the description of the symbol.
    Equivalent to JavaScript's `Symbol.prototype.description` getter.
]=]
function prototype.description(self: Symbol): string?
	if not is_symbol(self) then
		error(debug.traceback("Symbol.prototype.description requires a Symbol", 2))
	end
	return symbol_descriptions[self]
end

prototype[to_primitive] = function(self: Symbol): Symbol
	if not is_symbol(self) then
		error(debug.traceback("Symbol.prototype[@@toPrimitive] requires a Symbol", 2))
	end
	return self
end

prototype[to_string_tag] = "Symbol"

export type SymbolModule = {
	--> Static Methods
	for_: (key: string?) -> Symbol,
	["for"]: (key: string?) -> Symbol,
	key_for: (sym: Symbol) -> string?,
	is_symbol: (value: any) -> boolean,
	get_description: (sym: Symbol) -> string?,

	--> Well-Known Symbols
	iterator: Symbol,
	async_iterator: Symbol,
	has_instance: Symbol,
	is_concat_spreadable: Symbol,
	species: Symbol,
	match: Symbol,
	match_all: Symbol,
	replace: Symbol,
	search: Symbol,
	split: Symbol,
	to_primitive: Symbol,
	to_string_tag: Symbol,
	unscopables: Symbol,
	dispose: Symbol,
	async_dispose: Symbol,

	--> Prototype
	prototype: typeof(prototype),
}

local symbol_module: SymbolModule = {
	["for"] = symbol_for,
	for_ = symbol_for, --> Luau does not support using `for` as a variable
	key_for = symbol_key_for,
	is_symbol = is_symbol,
	get_description = get_description,

	iterator = iterator,
	async_iterator = async_iterator,
	has_instance = has_instance,
	is_concat_spreadable = is_concat_spreadable,
	species = species,
	match = match,
	match_all = match_all,
	replace = replace,
	search = search,
	split = split,
	to_primitive = to_primitive,
	to_string_tag = to_string_tag,
	unscopables = unscopables,
	dispose = dispose,
	async_dispose = async_dispose,

	prototype = prototype,
}

return setmetatable(symbol_module, {
	__call = function(_: any, description: string?): Symbol
		return create_symbol(description)
	end,
	__tostring = function(): string
		return "function Symbol() { [native code] }"
	end,
	__metatable = "SymbolConstructor",
})

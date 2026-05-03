--@maneetoo

--!strict

local TSTypes = require(script.Parent.TSTypes)
local typeof = require(script.Parent.typeof)

--[=[
    @class Stream

    Lazy, chainable sequence wrapper for array processing.
    All transforms return a new Stream; `.collect()` materialises the result.

    :::info Chaining
    Every method except `.collect()`, `.concat()`, `.forEach()`, `.fold()`,
    `.find()`, `.every()`, `.some()` and `.isEmpty()` returns a new `Stream`,
    so calls can be chained freely without mutating the original data.

    ```lua
    local result = Stream({ 1, 2, 3, 4, 5 })
        :filter(function(x) return x % 2 == 0 end)
        :map(function(x) return x * 10 end)
        :collect()
    -- result == { 20, 40 }
    ```
    :::

    :::caution Materialisation
    The underlying array is only cloned on `.collect()`. All intermediate
    transforms allocate new tables — avoid building very long chains over
    large datasets in hot paths.
    :::
]=]
local StreamClass = {}
StreamClass.__index = StreamClass
StreamClass.__type = "Stream"

export type StreamObject<T> = typeof(setmetatable({} :: { _data: TSTypes.Array<T>, _len: number }, StreamClass))

--[=[
    @within Stream
    @param arr { T }
    @return StreamObject<T>

    Internal constructor — wraps an array into a Stream object.
    Caches the length to avoid repeated `#` calls in tight loops.
]=]
local stream = function<T>(arr: TSTypes.Array<T>): StreamObject<T>
	return setmetatable({ _data = arr, _len = #arr }, StreamClass) :: StreamObject<T>
end

--[=[
    @within Stream
    @param f (T) -> U
    @return StreamObject<U>

    Transforms every element with `f` and returns a new Stream.

    ```lua
    Stream({ 1, 2, 3 }):map(function(x) return x * 2 end):collect()
    -- { 2, 4, 6 }
    ```
]=]
function StreamClass:map<T, U>(f: (T) -> U): StreamObject<U>
	typeof.assertType(f, "function", "f")
	local len: number = self._len
	local out: TSTypes.Array<U> = table.create(len)
	local data = self._data
	for i = 1, len do
		out[i] = f(data[i])
	end
	return stream(out)
end

--[=[
    @within Stream
    @param pred (T) -> boolean
    @return StreamObject<T>

    Keeps only elements satisfying `pred`.

    ```lua
    Stream({ 1, 2, 3, 4 }):filter(function(x) return x > 2 end):collect()
    -- { 3, 4 }
    ```
]=]
function StreamClass:filter<T>(pred: (T) -> boolean): StreamObject<T>
	typeof.assertType(pred, "function", "pred")
	local out: TSTypes.Array<T> = table.create(self._len)
	local n = 0
	local data = self._data
	for i = 1, self._len do
		local v = data[i]
		if pred(v) then
			n += 1
			out[n] = v
		end
	end
	return stream(out)
end

--[=[
    @within Stream
    @param n number
    @return StreamObject<T>

    Returns a new Stream containing only the first `n` elements.

    ```lua
    Stream({ 1, 2, 3, 4, 5 }):take(3):collect()
    -- { 1, 2, 3 }
    ```
]=]
function StreamClass:take<T>(n: number): StreamObject<T>
	typeof.assertType(n, "number", "n")
	if n < 0 then
		error(debug.traceback(`'n' must be positive`))
	end
	local count: number = math.min(n, self._len)
	local out: TSTypes.Array<T> = table.create(count)
	local data = self._data
	for i = 1, count do
		out[i] = data[i]
	end
	return stream(out)
end

--[=[
    @within Stream
    @param n number
    @return StreamObject<T>

    Returns a new Stream skipping the first `n` elements.

    ```lua
    Stream({ 1, 2, 3, 4, 5 }):skip(2):collect()
    -- { 3, 4, 5 }
    ```
]=]
function StreamClass:skip<T>(n: number): StreamObject<T>
	typeof.assertType(n, "number", "n")
	if n < 0 then
		error(debug.traceback(`'n' must be positive`))
	end
	local start: number = math.min(n, self._len) + 1
	local count: number = self._len - start + 1
	local out: TSTypes.Array<T> = table.create(math.max(0, count))
	local data = self._data
	local j = 0
	for i = start, self._len do
		j += 1
		out[j] = data[i]
	end
	return stream(out)
end

--[=[
    @within Stream
    @param f (T) -> ()
    @return ()

    Iterates for side-effects only. Does **not** return a Stream.

    ```lua
    Stream({ "a", "b", "c" }):forEach(function(s) print(s) end)
    ```
]=]
function StreamClass:forEach<T>(f: (T) -> ()): ()
	typeof.assertType(f, "function", "f")
	local data = self._data
	for i = 1, self._len do
		f(data[i])
	end
end

--[=[
    @within Stream
    @param init A
    @param f (A, T) -> A
    @return A

    Left-fold (reduce) the stream into a single accumulated value.

    ```lua
    Stream({ 1, 2, 3, 4 }):fold(0, function(acc, x) return acc + x end)
    -- 10
    ```
]=]
function StreamClass:fold<T, A>(init: A, f: (A, T) -> A): A
	typeof.assertType(f, "function", "f")
	local acc: A = init
	local data = self._data
	for i = 1, self._len do
		acc = f(acc, data[i])
	end
	return acc
end

--[=[
    @within Stream
    @param pred (T) -> boolean
    @return T?

    Returns the first element satisfying `pred`, or `nil`.

    ```lua
    Stream({ 1, 2, 3 }):find(function(x) return x > 1 end)
    -- 2
    ```
]=]
function StreamClass:find<T>(pred: (T) -> boolean): T?
	typeof.assertType(pred, "function", "pred")
	local data = self._data
	for i = 1, self._len do
		if pred(data[i]) then
			return data[i]
		end
	end
	return nil
end

--[=[
    @within Stream
    @param pred (T) -> boolean
    @return boolean

    Returns `true` if **every** element satisfies `pred`.
    Returns `true` vacuously for empty streams.

    ```lua
    Stream({ 2, 4, 6 }):every(function(x) return x % 2 == 0 end)
    -- true

    Stream({ 2, 3, 6 }):every(function(x) return x % 2 == 0 end)
    -- false
    ```
]=]
function StreamClass:every<T>(pred: (T) -> boolean): boolean
	typeof.assertType(pred, "function", "pred")
	local data = self._data
	for i = 1, self._len do
		if not pred(data[i]) then
			return false
		end
	end
	return true
end

--[=[
    @within Stream
    @param pred (T) -> boolean
    @return boolean

    Returns `true` if **at least one** element satisfies `pred`.
    Returns `false` for empty streams.

    ```lua
    Stream({ 1, 3, 4 }):some(function(x) return x % 2 == 0 end)
    -- true

    Stream({ 1, 3, 5 }):some(function(x) return x % 2 == 0 end)
    -- false
    ```
]=]
function StreamClass:some<T>(pred: (T) -> boolean): boolean
	typeof.assertType(pred, "function", "pred")
	local data = self._data
	for i = 1, self._len do
		if pred(data[i]) then
			return true
		end
	end
	return false
end

--[=[
    @within Stream
    @return boolean

    Returns `true` if the stream contains no elements.

    ```lua
    Stream({}):isEmpty()    -- true
    Stream({ 1 }):isEmpty() -- false
    ```
]=]
function StreamClass:isEmpty(): boolean
	return self._len == 0
end

--[=[
    @within Stream
    @return { T }

    Materialises the stream into a plain Lua array (shallow clone).

    ```lua
    Stream({ 1, 2, 3 }):collect()
    -- { 1, 2, 3 }
    ```
]=]
function StreamClass:collect<T>(): { T }
	return table.clone(self._data)
end

--[=[
    @within Stream
    @param sep string?
    @return string

    Joins a string stream with an optional separator.

    :::caution String-only
    The underlying array must contain only strings. Passing a numeric or
    mixed stream will raise a runtime error from `table.concat`.
    :::

    ```lua
    Stream({ "Hello", "World" }):concat(", ")
    -- "Hello, World"
    ```
]=]
function StreamClass:concat(sep: string?): string
	return table.concat(self._data :: TSTypes.Array<string>, sep or "")
end

--[=[
    @within Stream
    @param arr { T }
    @return StreamObject<T>

    Wraps an array into a Stream.

    ```lua
    local s = Stream({ 1, 2, 3, 4, 5 })
    ```
]=]
local Stream = function<T>(arr: TSTypes.Array<T>): StreamObject<T>
	typeof.assertType(arr, "table", "arr")
	return stream(arr)
end

return Stream

--@maneetoo

--!strict

--[=[
	@within Types
	@type CacheClass { new: <K, V>(size: number?) -> CacheType<K, V> }
]=]
export type CacheClass = {
	new: <K, V>(size: number?) -> CacheType<K, V>,
}

--[=[
	@within Types
	@type CacheType<K, V> CacheFields<K, V> & CacheMethods<K, V>
	Full cache instance type combining fields and methods
]=]
export type CacheType<K, V> = CacheFields<K, V> & CacheMethods<K, V>

--[=[
	@within Types
	@type CacheEntry<K, V> { key: K, value: V }
	Individual cache entry structure
]=]
export type CacheEntry<K, V> = {
	key: K,
	value: V,
}

--[=[
	@within Types
	@type CacheFields<K, V> { _size: number, _cache: { CacheEntry<K, V> }, _lookup: { [K]: number }, _hits: number, _misses: number }
	Internal fields of a cache instance
]=]
export type CacheFields<K, V> = {
	_size: number,
	_cache: { CacheEntry<K, V> },
	_lookup: { [K]: number },
	_hits: number,
	_misses: number,
}

--[=[
	@within Types
	@type CacheMethods<K, V> { get: (self: CacheType<K, V>, key: K) -> (V?, number?), set: (self: CacheType<K, V>, key: K, value: V?) -> (), contains: (self: CacheType<K, V>, key: K) -> boolean, get_count: (self: CacheType<K, V>) -> number, get_capacity: (self: CacheType<K, V>) -> number, is_full: (self: CacheType<K, V>) -> boolean, clear: (self: CacheType<K, V>) -> (), get_keys: (self: CacheType<K, V>) -> { K }, for_each: (self: CacheType<K, V>, callback: (key: K, value: V) -> ()) -> (), evict_oldest: (self: CacheType<K, V>) -> (K?, V?), resize: (self: CacheType<K, V>, new_size: number) -> () }
	Methods available on a cache instance
]=]
export type CacheMethods<K, V> = {
	get: (self: CacheType<K, V>, key: K) -> (V?, number?),
	set: (self: CacheType<K, V>, key: K, value: V?) -> (),
	contains: (self: CacheType<K, V>, key: K) -> boolean,
	get_count: (self: CacheType<K, V>) -> number,
	get_capacity: (self: CacheType<K, V>) -> number,
	is_full: (self: CacheType<K, V>) -> boolean,
	clear: (self: CacheType<K, V>) -> (),
	get_keys: (self: CacheType<K, V>) -> { K },
	for_each: (self: CacheType<K, V>, callback: (key: K, value: V) -> ()) -> (),
	evict_oldest: (self: CacheType<K, V>) -> (K?, V?),
	resize: (self: CacheType<K, V>, new_size: number) -> (),
}

--[=[
	@class CacheClass
	A simple full-typed LRU (Least Recently Used) cache with a pre-defined maximum size.
	Uses a lookup table for O(1) key access and maintains insertion order
	for efficient eviction of the oldest entries.
]=]
local CacheClass: CacheClass = {}

--[=[
	@within CacheClass
	@class MT
	OOP Holder for CacheClass
]=]
local MT = {}
MT.__index = MT
MT.__newindex = function()
	error(debug.traceback(`Unable to set a new value directly in CacheType object`, 2))
end

--[=[
	@within MT
	@param self The cache instance
	@param start_index The index to start updating from

	Updates the lookup mapping for all cache entries starting at start_index.
	Called after removing an entry to maintain correct index references.
]=]
local update_lookup_from = function<K, V>(self: CacheType<K, V>, start_index: number)
	for i = start_index, #self._cache do
		local entry = self._cache[i]
		if entry and entry.key ~= nil then
			self._lookup[entry.key] = i
		end
	end
end

--[=[
	@within MT
	@param size Maximum number of entries (default: 100)
	@return A new CacheType instance

	Creates a new LRU cache with the specified maximum size.
	
	```lua
	local cache = CacheClass.new(500)
	cache:set("key", "value")
	```
]=]
function CacheClass.new<K, V>(size: number?): CacheType<K, V>
	local actual_size = size or 100
	if actual_size <= 0 then
		error(debug.traceback(`CacheSize must be positive`, 2))
	end

	local self: CacheFields<K, V> = {
		_size = actual_size,
		_cache = table.create(actual_size),
		_lookup = {},
		_hits = 0,
		_misses = 0,
		__type = "CacheClass",
	}

	return setmetatable(self, MT) :: CacheType<K, V>
end

--[=[
	@within MT
	@param key The key to look up (must be non-nil)
	@return value The cached value, or nil if not found
	@return index The index in the cache array, or nil if not found

	Retrieves a value from the cache by key.
	
	```lua
	local value, index = cache:get("myKey")
	if value then
		print("Found:", value)
	end
	```
]=]
function MT.get<K, V>(self: CacheType<K, V>, key: K): (V?, number?)
	if not key then
		error(debug.traceback(`The CacheKey must be provided, got nil`, 2))
	end

	local index: number = self._lookup[key]
	if index then
		self._hits += 1
		local entry: CacheEntry<K, V> = self._cache[index]
		if index < #self._cache then
			table.remove(self._cache, index)
			table.insert(self._cache, entry)
			update_lookup_from(self, index)
			self._lookup[key] = #self._cache
		end

		return entry.value, #self._cache
	end

	self._misses += 1
	return nil, nil
end

--[=[
	@within MT
	@param key The key to set (must be non-nil)
	@param value The value to cache, or nil to remove

	Sets or updates a value in the cache.
	If the key exists, updates the value and moves it to the end (most recent)
	If the key is new and cache is at capacity, evicts the oldest entry
	Passing nil as value removes the entry from the cache
	
	```lua
	cache:set("player1", { hp = 100 })
	cache:set("player1", nil)  -- Remove from cache
	```
]=]
function MT.set<K, V>(self: CacheType<K, V>, key: K, value: V?): ()
	if not key then
		error(debug.traceback(`The CacheKey must be provided, got nil`, 2))
	end

	local is_nil_value: boolean = (value == nil)
	local existing_index: number? = self._lookup[key]

	if existing_index then
		-- Key exists: remove from current position
		local entry: CacheEntry<K, V>? = table.remove(self._cache, existing_index)
		self._lookup[key] = nil
		update_lookup_from(self, existing_index)

		-- Re-add at end if value is not nil (updates position to most recent)
		if not is_nil_value and entry then
			entry.value = value :: V
			table.insert(self._cache, entry)
			self._lookup[key] = #self._cache
		end
	elseif not is_nil_value then
		-- New key with value: add to cache
		local entry: CacheEntry<K, V> = {
			key = key,
			value = value :: V,
		}

		-- Evict oldest if at capacity
		if #self._cache >= self._size then
			local removed = table.remove(self._cache, 1)
			if removed then
				self._lookup[removed.key] = nil
				update_lookup_from(self, 1)
			end
		end

		table.insert(self._cache, entry)
		self._lookup[key] = #self._cache
	end
	-- If is_nil_value and key doesn't exist, do nothing
end

--[=[
	@within MT
	@param key The key to check
	@return true if the key exists, false otherwise

	Checks if a key exists in the cache.
	Does NOT update the entry's position (no LRU side effect).
	
	```lua
	if cache:contains("player1") then
		print("Player 1 is cached")
	end
	```
]=]
function MT.contains<K, V>(self: CacheType<K, V>, key: K): boolean
	if not key then
		error(debug.traceback(`The CacheKey must be provided, got nil`, 2))
	end
	return self._lookup[key] ~= nil
end

--[=[
	@within MT
	@return The number of cached entries

	Returns the current number of entries in the cache.
]=]
function MT.get_count<K, V>(self: CacheType<K, V>): number
	return #self._cache
end

--[=[
	@within MT
	@return The maximum number of entries

	Returns the maximum capacity of the cache.
]=]
function MT.get_capacity<K, V>(self: CacheType<K, V>): number
	return self._size
end

--[=[
	@within MT
	@return true if full, false otherwise

	Checks if the cache is at maximum capacity.
]=]
function MT.is_full<K, V>(self: CacheType<K, V>): boolean
	return #self._cache >= self._size
end

--[=[
	@within MT

	Clears all entries from the cache.
	Resets hit/miss statistics.
	
	```lua
	cache:clear()
	```
]=]
function MT.clear<K, V>(self: CacheType<K, V>)
	table.clear(self._cache)
	table.clear(self._lookup)
	self._hits = 0
	self._misses = 0
end

--[=[
	@within MT
	@return An array of keys

	Returns all keys currently in the cache.
	Keys are returned in order from oldest to newest.
	
	```lua
	for _, key in ipairs(cache:get_keys()) do
		print("Cached key:", key)
	end
	```
]=]
function MT.get_keys<K, V>(self: CacheType<K, V>): { K }
	local keys = table.create(#self._cache)
	for i, entry in ipairs(self._cache) do
		keys[i] = entry.key
	end
	return keys
end

--[=[
	@within MT
	@param callback Function called with (key, value) for each entry

	Iterates over all entries in the cache.
	Entries are visited from oldest to newest.
	
	```lua
	cache:for_each(function(key, value)
		print(key, "=", value)
	end)
	```
]=]
function MT.for_each<K, V>(self: CacheType<K, V>, callback: (key: K, value: V) -> ())
	for _, entry in ipairs(self._cache) do
		callback(entry.key, entry.value)
	end
end

--[=[
	@within MT
	@return key The key of the evicted entry, or nil if empty
	@return value The value of the evicted entry, or nil if empty

	Removes and returns the oldest entry from the cache.
	Useful for manual eviction.
	
	```lua
	local key, value = cache:evict_oldest()
	if key then
		print("Evicted:", key, value)
	end
	```
]=]
function MT.evict_oldest<K, V>(self: CacheType<K, V>): (K?, V?)
	if #self._cache == 0 then
		return nil, nil
	end

	local entry = table.remove(self._cache, 1)
	if entry then
		self._lookup[entry.key] = nil
		update_lookup_from(self, 1)
		return entry.key, entry.value
	end

	return nil, nil
end

--[=[
	@within MT
	@param new_size The new maximum capacity (must be positive)

	Resizes the cache to a new maximum capacity.
	If the new size is smaller, evicts oldest entries until within capacity.
	
	```lua
	cache:resize(1000) -- Increase capacity
	cache:resize(50) -- Decrease (may evict entries)
	```
]=]
function MT.resize<K, V>(self: CacheType<K, V>, new_size: number)
	assert(typeof(new_size) == "number", "new_size must be number")
	if new_size <= 0 then
		error(debug.traceback(`new_size must be positive, got {new_size}`, 2))
	end

	-- Evict entries if shrinking
	while #self._cache > new_size do
		self:evict_oldest()
	end

	self._size = new_size
end

table.freeze(CacheClass)
return CacheClass :: CacheClass

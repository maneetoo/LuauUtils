# LuauUtils
This is a set of useful utilities/libraries written in pure [Luau](https://luau.org/). This repository offers maximum convenience, with installation available either through [Wally](https://wally.run/). All [Pull Requests](https://github.com/maneetoo/LuauUtils/pulls) and [Issues](https://github.com/maneetoo/LuauUtils/issues) are reviewed and listened to, so we would love to see them in this repository!

# Documentation
Will be soon :(

# Modules
| Module | Dependency | Description |
| -- | -- | -- |
| Assign | `Assign = "maneetoo/assign@0.1.1"` | Object.assign() for Luau — shallow copy properties from sources to target |
| Cache | `Cache = "maneetoo/cache@0.1.0"` | Generic LRU cache with O(1) lookup, hit/miss tracking, and eviction |
| InstanceOf | `InstanceOf = "maneetoo/instance-of@0.1.0"` | instanceof operator for Luau — checks metatable __index chains |
| NoYield | `NoYield = "maneetoo/no-yield@0.1.0"` | Runtime guard that prevents coroutine yields inside wrapped functions |
| Pipe | `Pipe = "maneetoo/pipe@0.1.0"` | Left-to-right function composition — threads a value through transforms |
| Safe | `Safe = "maneetoo/safe@0.1.0"` | Inline xpcall wrapper with fallback values for error handling |
| Signal | `Signal = "maneetoo/signal@0.1.0"` | Reactive signal with Filter, Map, Take, Skip, Debounce, Throttle |
| Stream | `Stream = "maneetoo/stream@0.1.0"` | Lazy chainable array processing — map, filter, fold, collect |
| strict | `Strict = "maneetoo/strict@0.1.0"` | Makes tables strict — throws on read/write of undefined keys |
| Switch | `Switch = "maneetoo/switch@0.1.0"` | Pattern-matching dispatcher — Selene-style switch/case/default |
| Symbol | `Symbol = "maneetoo/symbol@0.1.0"` | JavaScript-style Symbol primitive with global registry and well-known symbols |
| Task | `Task = "maneetoo/task@0.1.0"` | Coroutine wrapper with lifecycle, priority, timeout, and retry logic |
| TSTypes | `TSTypes = "maneetoo/tstypes@0.1.2"` | Core Luau type definitions — Array, Table, Object, Tuple, Symbol |
| typeof | `TypeOf = "maneetoo/type-of@0.1.0"` | Enhanced typeof with custom __type support and type checking utilities |
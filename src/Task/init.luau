--@maneetoo

--!strict

--[=[
	@class Types
	Type definitions for the Task module
]=]

--[=[
	@within Types
	@type TaskStatus "pending" | "running" | "completed" | "failed" | "cancelled"
	Represents the current lifecycle state of a task
]=]
export type TaskStatus = "pending" | "running" | "completed" | "failed" | "cancelled"

--[=[
	@within Types
	@type TaskPriority "low" | "normal" | "high" | "critical"
	Determines the execution priority of a task in the scheduler
]=]
export type TaskPriority = "low" | "normal" | "high" | "critical"

--[=[
	@within Types
	@type TaskCallback (...any) -> ...any
	The function signature for a task's main coroutine body
]=]
export type TaskCallback = (...any) -> ...any

--[=[
	@within Types
	@type TaskClass { new: (callback: TaskCallback, options: TaskOptions?) -> TaskType, compare_priority: (a: TaskType, b: TaskType) -> boolean }
	The constructor interface for creating new task instances
]=]
export type TaskClass = {
	new: (callback: TaskCallback, options: TaskOptions?) -> TaskType,
	compare_priority: (a: TaskType, b: TaskType) -> boolean,
}

--[=[
	@within Types
	@type TaskOptions { priority: TaskPriority?, timeout: number?, name: string?, retry_limit: number?, on_complete: ((...any) -> ())?, on_fail: ((err: string) -> ())?, on_cancel: (() -> ())? }
	Configuration options provided at task creation time
]=]
export type TaskOptions = {
	priority: TaskPriority?,
	timeout: number?,
	name: string?,
	retry_limit: number?,
	on_complete: ((...any) -> ())?,
	on_fail: ((err: string) -> ())?,
	on_cancel: (() -> ())?,
}

--[=[
	@within Types
	@type TaskType TaskFields & TaskMethods
	Full task instance type combining internal fields and public methods
]=]
export type TaskType = TaskFields & TaskMethods

--[=[
	@within Types
	@type TaskFields { _coroutine: thread, _status: TaskStatus, _priority: TaskPriority, _name: string, _timeout: number?, _retry_limit: number, _retry_count: number, _result: { any }?, _error: string?, _on_complete: ((...any) -> ())?, _on_fail: ((err: string) -> ())?, _on_cancel: (() -> ())? }
	Internal state fields of a task instance
]=]
export type TaskFields = {
	_coroutine: thread,
	_status: TaskStatus,
	_priority: TaskPriority,
	_name: string,
	_timeout: number?,
	_retry_limit: number,
	_retry_count: number,
	_result: { any }?,
	_error: string?,
	_started_at: number?,
	_on_complete: ((...any) -> ())?,
	_on_fail: ((err: string) -> ())?,
	_on_cancel: (() -> ())?,
}

--[=[
	@within Types
	@type TaskMethods { run: (self: TaskType, ...any) -> boolean, resume: (self: TaskType, ...any) -> boolean, cancel: (self: TaskType) -> boolean, retry: (self: TaskType, ...any) -> boolean, await: (self: TaskType) -> ...any, get_status: (self: TaskType) -> TaskStatus, get_result: (self: TaskType) -> { any }?, get_error: (self: TaskType) -> string?, get_name: (self: TaskType) -> string, get_priority: (self: TaskType) -> TaskPriority, set_priority: (self: TaskType, priority: TaskPriority) -> (), is_done: (self: TaskType) -> boolean, is_alive: (self: TaskType) -> boolean }
	Public methods available on a task instance
]=]
export type TaskMethods = {
	run: (self: TaskType, ...any) -> boolean,
	resume: (self: TaskType, ...any) -> boolean,
	cancel: (self: TaskType) -> boolean,
	retry: (self: TaskType, ...any) -> boolean,
	await: (self: TaskType) -> ...any,
	get_status: (self: TaskType) -> TaskStatus,
	get_result: (self: TaskType) -> { any }?,
	get_error: (self: TaskType) -> string?,
	get_name: (self: TaskType) -> string,
	get_priority: (self: TaskType) -> TaskPriority,
	set_priority: (self: TaskType, priority: TaskPriority) -> (),
	is_done: (self: TaskType) -> boolean,
	is_alive: (self: TaskType) -> boolean,
}

local PRIORITY_WEIGHT: { [TaskPriority]: number } = {
	low = 1,
	normal = 2,
	high = 3,
	critical = 4,
}

--[=[
	@class TaskClass
	A coroutine-based task primitive for flexible and safe asynchronous execution.

	Wraps a Lua coroutine with lifecycle management, priority, timeout awareness,
	automatic retry logic, and structured result/error propagation.

	Unlike raw coroutines, a TaskType tracks its own status and exposes hooks
	for completion, failure, and cancellation.

	:::info
	Tasks begin in the `"pending"` state and must be explicitly started
	with `:run()`. Calling `:resume()` on a pending task is equivalent to `:run()`.
	:::

	```lua
	local my_task = TaskClass.new(function(value)
		coroutine.yield(value * 2)
		return value * 4
	end, {
		name = "doubler",
		priority = "high",
		on_complete = function(...) print("done", ...) end,
	})

	my_task:run(10)
	my_task:resume()
	```
]=]
local TaskClass: TaskClass = {} :: TaskClass

--[=[
	@within TaskClass
	@class MT
	Metatable and method container for TaskType instances
]=]
local MT = {}
MT.__index = MT

MT.__newindex = function()
	error(debug.traceback("Unable to set a new value directly on a TaskType object", 2))
end

MT.__tostring = function(self: TaskType): string
	return string.format(
		"Task(%s)[%s | %s | retries: %d/%d]",
		self._name,
		self._status,
		self._priority,
		self._retry_count,
		self._retry_limit
	)
end

local raw_set = function(self: TaskType, key: string, value: any)
	rawset(self, key, value)
end

--[=[
	@within MT
	@param self TaskType
	@param status TaskStatus

	Transitions the task into a new status.
]=]
local set_status = function(self: TaskType, status: TaskStatus)
	raw_set(self, "_status", status)
end

--[=[
	@within MT
	@param self TaskType
	@param ok boolean
	@param result any

	Handles the result of a coroutine resume call.
	Transitions to `"completed"` or `"failed"` depending on outcome
	and fires the appropriate lifecycle hook.
]=]
local handle_resume_result = function(self: TaskType, ok: boolean, result: any)
	if not ok then
		raw_set(self, "_error", tostring(result))
		set_status(self, "failed")

		if self._on_fail then
			self._on_fail(self._error :: string)
		end

		return
	end

	if coroutine.status(self._coroutine) == "dead" then
		raw_set(self, "_result", { result })
		set_status(self, "completed")

		if self._on_complete then
			self._on_complete(result)
		end
	end
end

--[=[
	@within TaskClass
	@param callback TaskCallback -- The coroutine body to execute
	@param options TaskOptions? -- Optional configuration
	@return TaskType

	Creates a new task wrapping the provided callback inside a coroutine.
	The task starts in `"pending"` state and is not executed until `:run()` is called.

	```lua
	local my_task = TaskClass.new(function(x, y)
		return x + y
	end, {
		name = "adder",
		priority = "normal",
		retry_limit = 3,
	})
	```
]=]
function TaskClass.new(callback: TaskCallback, options: TaskOptions?): TaskType
	if typeof(callback) ~= "function" then
		error(debug.traceback("TaskCallback must be a function, got " .. typeof(callback), 2))
	end

	local opts: TaskOptions = options or {}

	local priority: TaskPriority = opts.priority or "normal"
	if not PRIORITY_WEIGHT[priority] then
		error(debug.traceback("Invalid TaskPriority: " .. tostring(priority), 2))
	end

	local retry_limit: number = opts.retry_limit or 0
	if typeof(retry_limit) ~= "number" or retry_limit < 0 then
		error(debug.traceback("retry_limit must be a non-negative number", 2))
	end

	local timeout = opts.timeout
	if timeout ~= nil and (typeof(timeout) ~= "number" or timeout <= 0) then
		error(debug.traceback("timeout must be a positive number", 2))
	end

	local self: TaskFields = {
		_coroutine = coroutine.create(callback),
		_status = "pending",
		_priority = priority,
		_name = opts.name or "task_" .. tostring(math.random(100000, 999999)),
		_timeout = timeout,
		_retry_limit = retry_limit,
		_retry_count = 0,
		_result = nil,
		_error = nil,
		_started_at = nil,
		_on_complete = opts.on_complete,
		_on_fail = opts.on_fail,
		_on_cancel = opts.on_cancel,
	}

	local instance = setmetatable(self, MT) :: TaskType
	rawset(instance, "_callback", callback)

	return instance
end

--[=[
	@within MT
	@param self TaskType
	@param ... any -- Arguments forwarded to the coroutine on first resume
	@return boolean -- `true` if the coroutine was successfully started

	Starts a `"pending"` task by performing the first coroutine resume.
	Returns `false` without error if the task is not in `"pending"` state.

	```lua
	local started = my_task:run(arg1, arg2)
	```
]=]
function MT.run(self: TaskType, ...: any): boolean
	if self._status ~= "pending" then
		return false
	end

	raw_set(self, "_started_at", os.clock())
	set_status(self, "running")

	local ok, result = coroutine.resume(self._coroutine, ...)
	handle_resume_result(self, ok, result)

	return ok
end

--[=[
	@within MT
	@param self TaskType
	@param ... any -- Values sent into the coroutine at the yield point
	@return boolean -- `true` if the resume succeeded

	Resumes a `"running"` (or `"pending"`) task, sending values into the
	coroutine at the current yield point.

	- If the task is `"pending"`, delegates to `:run(...)`.
	- If the task is in a terminal state, returns `false` immediately.
	- Respects the configured timeout; if elapsed time exceeds it the task
	  is cancelled before resuming.

	```lua
	my_task:run()
	my_task:resume("next_value")
	```
]=]
function MT.resume(self: TaskType, ...: any): boolean
	if self._status == "pending" then
		return self:run(...)
	end

	if self._status ~= "running" then
		return false
	end

	if self._timeout and self._started_at then
		local elapsed = os.clock() - self._started_at
		if elapsed >= self._timeout then
			raw_set(self, "_error", string.format("Task '%s' timed out after %.4fs", self._name, elapsed))
			set_status(self, "cancelled")

			if self._on_cancel then
				self._on_cancel()
			end

			return false
		end
	end

	if coroutine.status(self._coroutine) == "dead" then
		return false
	end

	local ok, result = coroutine.resume(self._coroutine, ...)
	handle_resume_result(self, ok, result)

	return ok
end

--[=[
	@within MT
	@param self TaskType
	@return boolean -- `true` if the task was successfully cancelled

	Cancels a task that is in `"pending"` or `"running"` state.
	Closes the underlying coroutine and transitions the task to `"cancelled"`.
	Has no effect on tasks already in a terminal state.

	```lua
	my_task:cancel()
	print(my_task:get_status()) -- "cancelled"
	```
]=]
function MT.cancel(self: TaskType): boolean
	if self._status ~= "pending" and self._status ~= "running" then
		return false
	end

	local co = self._coroutine
	if coroutine.status(co) ~= "dead" then
		local closed_ok, close_err = coroutine.close(co)
		if not closed_ok then
			raw_set(self, "_error", tostring(close_err))
		end
	end

	set_status(self, "cancelled")

	if self._on_cancel then
		self._on_cancel()
	end

	return true
end

--[=[
	@within MT
	@param self TaskType
	@param ... any -- Arguments forwarded to the fresh coroutine
	@return boolean -- `true` if the retry was initiated successfully

	Retries a `"failed"` or `"cancelled"` task by rebuilding its coroutine
	and calling `:run(...)` again. Each retry increments `_retry_count`.

	Returns `false` if:
	- The task is not in a retryable state.
	- The retry limit has been reached.

	```lua
	local my_task = TaskClass.new(fetch_data, { retry_limit = 3 })
	my_task:run()

	if my_task:get_status() == "failed" then
		my_task:retry()
	end
	```
]=]
function MT.retry(self: TaskType, ...: any): boolean
	if self._status ~= "failed" and self._status ~= "cancelled" then
		return false
	end

	if self._retry_count >= self._retry_limit then
		return false
	end

	local callback = rawget(self, "_callback")
	if typeof(callback) ~= "function" then
		error(debug.traceback("Cannot retry: internal callback reference is missing", 2))
	end

	raw_set(self, "_retry_count", self._retry_count + 1)
	raw_set(self, "_coroutine", coroutine.create(callback))
	raw_set(self, "_status", "pending")
	raw_set(self, "_result", nil)
	raw_set(self, "_error", nil)
	raw_set(self, "_started_at", nil)

	return self:run(...)
end

--[=[
	@within MT
	@param self TaskType
	@return ...any -- The values returned by the coroutine

	Blocks the **calling coroutine** by yielding until this task reaches a
	terminal state (`"completed"`, `"failed"`, or `"cancelled"`).

	Returns the unpacked result table on completion, or raises an error
	on failure/cancellation so the caller can handle it with `pcall`.

	:::warning
	`:await()` must be called from within another coroutine.
	Calling it from the main thread will raise a "cannot yield" error.
	:::

	```lua
	coroutine.wrap(function()
		local result = my_task:await()
		print("Result:", result)
	end)()
	```
]=]
function MT.await(self: TaskType): ...any
	while not self:is_done() do
		coroutine.yield()
	end

	if self._status == "completed" and self._result then
		return table.unpack(self._result)
	end

	error(
		string.format(
			"Task '%s' ended with status '%s': %s",
			self._name,
			self._status,
			self._error or "no error message"
		),
		2
	)
end

--[=[
	@within MT
	@param self TaskType
	@return TaskStatus

	Returns the current lifecycle status of the task.
]=]
function MT.get_status(self: TaskType): TaskStatus
	return self._status
end

--[=[
	@within MT
	@param self TaskType
	@return { any }? -- Packed result table, or nil if not yet completed

	Returns the result table from a completed task, or `nil` if the task
	has not finished or did not complete successfully.
]=]
function MT.get_result(self: TaskType): { any }?
	return self._result
end

--[=[
	@within MT
	@param self TaskType
	@return string? -- The error message, or nil if no error occurred

	Returns the error string recorded on failure or timeout, or `nil`.
]=]
function MT.get_error(self: TaskType): string?
	return self._error
end

--[=[
	@within MT
	@param self TaskType
	@return string

	Returns the human-readable name of the task.
]=]
function MT.get_name(self: TaskType): string
	return self._name
end

--[=[
	@within MT
	@param self TaskType
	@return TaskPriority

	Returns the current priority level of the task.
]=]
function MT.get_priority(self: TaskType): TaskPriority
	return self._priority
end

--[=[
	@within MT
	@param self TaskType
	@param priority TaskPriority -- The new priority level

	Updates the task's priority. Useful for scheduler re-ordering before
	the task has been picked up for execution.

	```lua
	my_task:set_priority("critical")
	```
]=]
function MT.set_priority(self: TaskType, priority: TaskPriority)
	if not PRIORITY_WEIGHT[priority] then
		error(debug.traceback("Invalid TaskPriority: " .. tostring(priority), 2))
	end
	raw_set(self, "_priority", priority)
end

--[=[
	@within MT
	@param self TaskType
	@return boolean

	Returns `true` if the task has reached any terminal state:
	`"completed"`, `"failed"`, or `"cancelled"`.
]=]
function MT.is_done(self: TaskType): boolean
	return self._status == "completed" or self._status == "failed" or self._status == "cancelled"
end

--[=[
	@within MT
	@param self TaskType
	@return boolean

	Returns `true` if the underlying coroutine is still alive.
]=]
function MT.is_alive(self: TaskType): boolean
	return coroutine.status(self._coroutine) ~= "dead"
end

--[=[
	@within TaskClass
	@param a TaskType
	@param b TaskType
	@return boolean -- `true` if task `a` has strictly higher priority than task `b`

	Utility comparator for sorting tasks by priority weight descending.

	```lua
	table.sort(task_queue, TaskClass.compare_priority)
	```
]=]
function TaskClass.compare_priority(a: TaskType, b: TaskType): boolean
	return PRIORITY_WEIGHT[a._priority] > PRIORITY_WEIGHT[b._priority]
end

table.freeze(PRIORITY_WEIGHT)
table.freeze(TaskClass)
return TaskClass :: TaskClass

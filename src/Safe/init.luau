--@maneetoo

--!strict

--[=[
	@within Types
	@type SafeCallbacks<Success, Fail> { try: () -> Success, fallback: (err: any) -> Fail }
]=]
export type SafeCallbacks<Success, Fail> = {
	try: () -> Success,
	fallback: (err: any) -> Fail,
}

--[=[
    @class Safe
    A variant of xpcall() designed for inline usage, letting you define fallback
	values based on caught errors.
    Inspired from: Fusion v0.3-beta

    ```lua
    -- Example
    local result = Safe({
        try = function()
            return 5*8
        end,
        fallback = function(err: string)
            error(err)
        end
    })

    print(result) --> 40
    ```
]=]
local Safe = function<Success, Fail>(callbacks: SafeCallbacks<Success, Fail>): Success | Fail
	local _, value = xpcall(callbacks.try, function(err)
		return callbacks.fallback(err)
	end)

	return value
end

return Safe

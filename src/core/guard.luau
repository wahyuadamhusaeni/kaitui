local function threadLowered()
    local window = Library.Windows[#Library.Windows]
    local probe = window and window.Gui
    if typeof(probe) ~= "Instance" then
        return false
    end
    return not pcall(function()
        return probe.Name
    end)
end

local trustedQueue = {}
-- Kept on Library so Library:Destroy can drop it; runTrusted connects it again if needed.
function Library._connectTrusted()
    if Library._trustedHeartbeat then
        return
    end
    Library._trustedHeartbeat = RunService.Heartbeat:Connect(function()
        if #trustedQueue == 0 then
            return
        end
        local queue = trustedQueue
        trustedQueue = {}
        for _, job in ipairs(queue) do
            job()
        end
    end)
end
Library._connectTrusted()

-- Drops the heartbeat once nothing is waiting on it, so a queued call
-- (a toggle switching off during unload) still runs first.
function Library._disconnectTrusted()
    if #trustedQueue > 0 then
        task.delay(0.5, Library._disconnectTrusted)
        return
    end
    if Library._trustedHeartbeat and #Library.Windows == 0 then
        Library._trustedHeartbeat:Disconnect()
        Library._trustedHeartbeat = nil
    end
end

local function runTrusted(fn, ...)
    Library._connectTrusted()
    local args = table.pack(...)
    local result = nil
    local timedOut = false
    table.insert(trustedQueue, function()
        if not timedOut then
            result = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
        end
    end)
    local deadline = os.clock() + 5
    while result == nil do
        if os.clock() > deadline then
            timedOut = true
            error("[KaitUI] trusted call timed out", 0)
        end
        task.wait()
    end
    if not result[1] then
        error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
end

local guardedObjects = setmetatable({}, { __mode = "k" })
local guardObject

local function guarded(fn)
    return function(...)
        if threadLowered() then
            if setIdentity then
                pcall(setIdentity, loadIdentity or 8)
            end
            if threadLowered() then
                return guardObject(runTrusted(fn, ...))
            end
        end
        return guardObject(fn(...))
    end
end

-- Elements carry their methods as closures, so each returned object gets its
-- public functions wrapped too; windows and tabs share the guarded metatables.
function guardObject(...)
    for index = 1, select("#", ...) do
        local object = select(index, ...)
        if type(object) == "table" and not guardedObjects[object] then
            local meta = getmetatable(object)
            if meta ~= Window and meta ~= Tab then
                guardedObjects[object] = true
                for key, value in pairs(object) do
                    if type(key) == "string" and type(value) == "function" and key:sub(1, 1) ~= "_" then
                        object[key] = guarded(value)
                    elseif type(key) == "number" and type(value) == "table" then
                        guardObject(value)
                    end
                end
            end
        end
    end
    return ...
end

for _, class in ipairs({ Library, Window, Tab }) do
    for key, value in pairs(class) do
        if type(key) == "string" and type(value) == "function" and key:sub(1, 1) ~= "_" then
            class[key] = guarded(value)
        end
    end
end

return Library

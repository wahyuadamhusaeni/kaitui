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
-- Wrappers already made, so an object seen again only gets its new methods
-- wrapped (a Confirm button replaces SetText and Disarm after creation).
local guardWrappers = setmetatable({}, { __mode = "k" })
local function guardOne(object, seen)
    if type(object) ~= "table" or seen[object] then
        return
    end
    seen[object] = true
    local meta = getmetatable(object)
    if meta == Window or meta == Tab then
        return
    end
    guardedObjects[object] = true
    for key, value in pairs(object) do
        if type(key) == "string" and type(value) == "function" and key:sub(1, 1) ~= "_" and not guardWrappers[value] then
            -- Handle.Set(true) (a dot instead of a colon) works like Handle:Set(true).
            local method = value
            local wrapper = guarded(function(first, ...)
                if first ~= object then
                    return method(object, first, ...)
                end
                return method(first, ...)
            end)
            guardWrappers[wrapper] = true
            object[key] = wrapper
        elseif type(key) == "number" and type(value) == "table" then
            guardOne(value, seen)
        end
    end
end

function guardObject(...)
    local seen = {}
    for index = 1, select("#", ...) do
        guardOne((select(index, ...)), seen)
    end
    return ...
end

-- Library has one instance, so KaitUI.CreateWindow({...}) can be called with a
-- dot too. A window or tab can't be guessed, so a dot there gets a clear error.
for key, value in pairs(Library) do
    if type(key) == "string" and type(value) == "function" and key:sub(1, 1) ~= "_" then
        local method = guarded(value)
        Library[key] = function(first, ...)
            if first ~= Library then
                return method(Library, first, ...)
            end
            return method(first, ...)
        end
    end
end
for _, entry in ipairs({ { Window, "Window" }, { Tab, "Tab" } }) do
    local class, className = entry[1], entry[2]
    for key, value in pairs(class) do
        if type(key) == "string" and type(value) == "function" and key:sub(1, 1) ~= "_" then
            local method = guarded(value)
            class[key] = function(self, ...)
                if type(self) ~= "table" or getmetatable(self) ~= class then
                    error(("[KaitUI] %s.%s was called with a dot. Use a colon: %s:%s(...)"):format(className, key, className, key), 2)
                end
                -- A closed window's methods do nothing, so a script loop that
                -- keeps calling Window:Notify after the player closed it is fine.
                if class == Window and rawget(self, "_destroyed") and key ~= "Destroy" and key ~= "Unload" and key ~= "Close" then
                    if key == "Notify" then
                        return Library._inertToast()
                    end
                    return nil
                end
                return method(self, ...)
            end
        end
    end
end

return Library

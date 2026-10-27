local function pruneTable(map, counted)
    for object in pairs(map) do
        if object.Parent == nil then
            if orphanMarks[object] then
                map[object] = nil
                orphanMarks[object] = nil
                if counted then
                    bindingCount -= 1
                end
            else
                orphanMarks[object] = true
            end
        else
            orphanMarks[object] = nil
        end
    end
end

local function sweepBindings()
    pruneTable(themeBindings, true)
    pruneTable(themeHooks, false)
    sweepAt = math.max(4000, bindingCount * 2)
end

-- One number per 8-bit colour, so binding a colour allocates no string.
local function colorKey(color)
    return math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
end

local function rebuildThemeLookup()
    table.clear(themeLookup)
    for index = #THEME_KEYS, 1, -1 do
        local name = THEME_KEYS[index]
        themeLookup[colorKey(Library.Theme[name])] = name
    end
end
rebuildThemeLookup()

local function bindColors(object, props)
    for property, value in pairs(props) do
        if typeof(value) == "Color3" then
            local name = themeLookup[colorKey(value)]
            local bound = themeBindings[object]
            if name then
                if not bound then
                    bound = {}
                    themeBindings[object] = bound
                    bindingCount += 1
                    if bindingCount >= sweepAt then
                        sweepBindings()
                    end
                end
                bound[property] = name
            elseif bound then
                bound[property] = nil
            end
        end
    end
end

-- Repaints every bound property from the colours on screen to the new theme.
-- One Heartbeat loop lerps each theme key once per frame and assigns the
-- result, instead of creating a tween per object, which hitched the frame the
-- theme changed on large UIs. A change mid-fade picks up from what is shown.
local shownTheme = table.clone(Library.Theme)
local themeDriver = nil

local function paintBinding(object, bound, colors)
    for property, name in pairs(bound) do
        local color = colors[name]
        if color then
            object[property] = color
        end
    end
end

local function paintBindings(colors)
    for object, bound in pairs(themeBindings) do
        pcall(paintBinding, object, bound, colors)
    end
end

local function driveTheme(duration)
    if themeDriver then
        themeDriver:Disconnect()
        themeDriver = nil
    end
    local from, colors = {}, {}
    for _, name in ipairs(THEME_KEYS) do
        local target = Library.Theme[name]
        local current = shownTheme[name] or target
        if current ~= target then
            from[name] = current
            colors[name] = current
        end
    end
    local function finish()
        for _, name in ipairs(THEME_KEYS) do
            colors[name] = Library.Theme[name]
            shownTheme[name] = Library.Theme[name]
        end
        paintBindings(colors)
    end
    if duration <= 0 or next(from) == nil then
        finish()
        return
    end
    -- The fade frames only touch properties bound to keys that change, gathered
    -- once, and run them under one pcall per frame (resuming past a bad object)
    -- instead of a pcall and a table walk per bound object.
    local targets = {}
    for object, bound in pairs(themeBindings) do
        for property, name in pairs(bound) do
            if from[name] then
                table.insert(targets, { object, property, name })
            end
        end
    end
    local function paintTargets()
        local index = 1
        while index <= #targets do
            local ok = pcall(function()
                while index <= #targets do
                    local target = targets[index]
                    target[1][target[2]] = colors[target[3]]
                    index += 1
                end
            end)
            if not ok then
                index += 1
            end
        end
    end
    local elapsed = 0
    themeDriver = RunService.Heartbeat:Connect(function(deltaTime)
        elapsed += deltaTime
        if elapsed >= duration then
            themeDriver:Disconnect()
            themeDriver = nil
            finish()
            return
        end
        local alpha = 1 - (1 - elapsed / duration) ^ 5
        for name, start in pairs(from) do
            local color = start:Lerp(Library.Theme[name], alpha)
            colors[name] = color
            shownTheme[name] = color
        end
        paintTargets()
    end)
end

-- Runs fn now and again whenever the theme changes, while owner exists.
local function onTheme(owner, fn)
    themeHooks[owner] = fn
    fn()
end


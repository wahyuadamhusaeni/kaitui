-- Themes

Library._themeListeners = {}

local function toColor(value)
    if typeof(value) == "Color3" then
        return value
    elseif type(value) == "string" then
        local r, g, b = value:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
        if r then
            return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
        end
    elseif type(value) == "table" then
        local r, g, b = value[1] or value.R, value[2] or value.G, value[3] or value.B
        if tonumber(r) and tonumber(g) and tonumber(b) then
            return Color3.fromRGB(r, g, b)
        end
    end
    return nil
end

local function hexOf(color)
    return string.format("#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
end

-- Coloured text for statuses, metrics, table cells and labels. A theme key
-- used as a tag, <Success>online</Success>, follows theme changes; plain
-- rich text such as <font color="#ff5a5a"> works too. Library.Colorize wraps
-- text for you. Table fields, not locals: the chunk is at Luau's 200 limit.
Library._toneTags = {}
for _, name in ipairs(THEME_KEYS) do
    Library._toneTags[string.lower(name)] = name
end

-- DependsOn rules: "Flag" (its value is on: true, a non-empty pick, a
-- non-zero number), { Flag, Value, Not } (Value may be a list of accepted
-- values; a multi dropdown passes when it holds any of them), a list of rules
-- that must all pass, or a function returning true.
function Library._dependsMet(rule)
    if type(rule) == "function" then
        local ok, result = pcall(rule)
        return ok and result and true or false
    end
    if type(rule) == "string" then
        rule = { Flag = rule }
    end
    if type(rule) ~= "table" then
        return true
    end
    if rule.Flag == nil then
        for _, sub in ipairs(rule) do
            if not Library._dependsMet(sub) then
                return false
            end
        end
        return true
    end
    local element = Library.Flags[rule.Flag]
    local met = false
    if element and type(element.Get) == "function" then
        local ok, value = pcall(element.Get, element)
        if ok then
            if rule.Value ~= nil then
                local wanted = type(rule.Value) == "table" and rule.Value or { rule.Value }
                local values = type(value) == "table" and value or { value }
                -- Instances (a player picker's Players) also match by name.
                for index = 1, #values do
                    if typeof(values[index]) == "Instance" then
                        table.insert(values, values[index].Name)
                    end
                end
                for _, item in ipairs(wanted) do
                    if table.find(values, item) then
                        met = true
                        break
                    end
                end
            else
                met = value == true
                    or (type(value) == "number" and value ~= 0)
                    or (type(value) == "string" and value ~= "")
                    or (type(value) == "table" and next(value) ~= nil)
                    or typeof(value) == "EnumItem"
                    or typeof(value) == "Color3"
                    or typeof(value) == "Instance"
            end
        end
    end
    if rule.Not then
        met = not met
    end
    return met
end

function Library._applyDepends(element, force)
    local met = element._dependsOn == nil or Library._dependsMet(element._dependsOn)
    if met == element._dependsMet and not force then
        return
    end
    element._dependsMet = met
    local mode = string.lower(tostring(element._dependsMode or "Hide"))
    if mode == "disable" then
        if element._dependHidden then
            Library._setDependHidden(element, false)
        end
        element._dependDisabled = not met
        Library._setDisabled(element, element._frame, element.Disabled)
    else
        if element._dependDisabled then
            element._dependDisabled = false
            Library._setDisabled(element, element._frame, element.Disabled)
        end
        Library._setDependHidden(element, not met)
    end
end

function Library._setDependHidden(element, hidden)
    hidden = hidden == true
    if hidden == (element._dependHidden == true) then
        return
    end
    element._dependHidden = hidden
    if hidden then
        if element._onHide then
            element._onHide()
        end
        if element.Open and type(element.SetOpen) == "function" then
            element:SetOpen(false)
        end
    end
    local frame = element._frame
    if frame then
        frame:SetAttribute("Revealing", nil)
        frame.Visible = element._userVisible ~= false and not hidden
    end
    if element._window then
        element._window._controlsDirty = true
    end
end

-- Rules are checked ten times a second, so they follow config loads and
-- changes made from code as well as clicks. Not at all while the window is
-- hidden (the first frame after it opens catches up), twice a second while
-- minimized (popped-out panels stay up), four times in Performance Mode.
function Library._watchDepends(window, element)
    if not window._dependents then
        window._dependents = {}
        local last = 0
        window:_listen("Render", function()
            if not window.Open then
                return
            end
            local now = os.clock()
            local interval = window.Minimized and 0.5 or (Library.PerformanceMode and 0.25 or 0.1)
            if now - last < interval then
                return
            end
            last = now
            local list = window._dependents
            for index = #list, 1, -1 do
                local item = list[index]
                if item._destroyed then
                    table.remove(list, index)
                elseif item._dependsOn ~= nil then
                    Library._applyDepends(item)
                end
            end
        end)
    end
    if not table.find(window._dependents, element) then
        table.insert(window._dependents, element)
    end
    Library._applyDepends(element, true)
end

-- SetDisabled(true) or a DependsOn rule in "Disable" mode dims the element
-- under a cover that swallows clicks; either one keeps it disabled.
function Library._setDisabled(element, frame, disabled)
    element.Disabled = disabled == true
    if not frame then
        return
    end
    local off = element.Disabled or element._dependDisabled == true
    if off == (element._covered == true) then
        return
    end
    element._covered = off
    if off then
        if element._onHide then
            element._onHide()
        end
        if element.Open and type(element.SetOpen) == "function" then
            element:SetOpen(false)
        end
    end
    local cover = element._cover
    if not cover then
        cover = create("TextButton", {
            Name = "DisabledCover",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 20,
            Visible = false,
            Parent = frame,
        })
        cover:SetAttribute("NoDrag", true)
        corner(cover)
        element._cover = cover
    end
    element._coverGeneration = (element._coverGeneration or 0) + 1
    local generation = element._coverGeneration
    if off then
        cover.Visible = true
        tween(cover, { BackgroundTransparency = 0.4 }, 0.15)
    else
        tween(cover, { BackgroundTransparency = 1 }, 0.15)
        task.delay(0.16, function()
            if element._coverGeneration == generation then
                cover.Visible = false
            end
        end)
    end
end

-- Confirm = true (or the text to show): the first click arms the button and
-- a second one within ConfirmTimeout seconds runs it. HoldToConfirm = true
-- (one second) or a number of seconds: the button fills while held and runs
-- when full.
function Library._gateButton(tab, opts)
    local real = opts.Callback
    local holdTime = opts.HoldToConfirm == true and 1 or tonumber(opts.HoldToConfirm)
    local gated = table.clone(opts)
    gated._gated = true
    local handle
    local name = tostring(opts.Name or "Button")
    local armed, generation = false, 0
    local function setArmed(value)
        armed = value
        generation += 1
        if not handle then
            return
        end
        handle._title.Text = value and tostring(type(opts.Confirm) == "string" and opts.Confirm or "Click again to confirm") or name
        tween(handle._title, { TextColor3 = value and Theme.Warning or handle._titleColor }, 0.15)
    end
    gated.Callback = function()
        if holdTime then
            return
        end
        if armed then
            setArmed(false)
            safeCall(real)
            return
        end
        setArmed(true)
        local current = generation
        task.delay(tonumber(opts.ConfirmTimeout) or 3, function()
            if armed and generation == current then
                setArmed(false)
            end
        end)
    end
    handle = tab:Button(gated)
    local setText = handle.SetText
    handle.SetText = function(self_, value)
        name = tostring(value)
        if not armed then
            setText(self_, value)
        end
    end
    function handle:Disarm()
        if armed then
            setArmed(false)
        end
    end
    if holdTime then
        local host = handle._fillHost
        local fill = create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            ZIndex = 0,
            Parent = host,
        })
        local holding = 0
        local function release()
            holding += 1
            tween(fill, { Size = UDim2.fromScale(0, 1) }, 0.2, Enum.EasingStyle.Quint)
        end
        local frame = handle._frame
        frame.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if handle.Disabled or handle._dependDisabled then
                return
            end
            holding += 1
            local current = holding
            fill.Size = UDim2.fromScale(0, 1)
            tween(fill, { Size = UDim2.fromScale(1, 1) }, holdTime, Enum.EasingStyle.Linear)
            task.delay(holdTime, function()
                if holding == current and not handle._destroyed and not handle.Disabled and not handle._dependDisabled then
                    holding += 1
                    tween(fill, { BackgroundTransparency = 0.45 }, 0.08)
                    task.delay(0.12, function()
                        fill.BackgroundTransparency = 0.7
                        tween(fill, { Size = UDim2.fromScale(0, 1) }, 0.25, Enum.EasingStyle.Quint)
                    end)
                    safeCall(real)
                end
            end)
        end)
        frame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                release()
            end
        end)
        frame.MouseLeave:Connect(release)
        -- Hidden or disabled mid-hold: the hold is dropped.
        local hideBefore = handle._onHide
        handle._onHide = function()
            release()
            if hideBefore then
                hideBefore()
            end
        end
    end
    return handle
end

-- A theme key, a Color3, "#rrggbb" or { r, g, b } as a Color3.
function Library._color(value)
    if type(value) == "string" then
        local key = Library._toneTags[string.lower(value)]
        if key then
            return Theme[key]
        end
    end
    return toColor(value)
end

function Library._rich(text)
    text = tostring(text == nil and "" or text)
    if not string.find(text, "<", 1, true) then
        return text
    end
    return (string.gsub(text, "<(/?)(%a+%d*)>", function(slash, name)
        local key = Library._toneTags[string.lower(name)]
        if not key then
            return nil
        end
        if slash == "/" then
            return "</font>"
        end
        return '<font color="' .. hexOf(Theme[key]) .. '">'
    end))
end

-- Library.Colorize("12 ms", "Success") or Library:Colorize(text, Color3).
function Library.Colorize(...)
    local args = { ... }
    if args[1] == Library then
        table.remove(args, 1)
    end
    local text, color = tostring(args[1] == nil and "" or args[1]), args[2]
    local key = type(color) == "string" and Library._toneTags[string.lower(color)]
    if key then
        return "<" .. key .. ">" .. text .. "</" .. key .. ">"
    end
    local resolved = toColor(color)
    if not resolved then
        return text
    end
    return '<font color="' .. hexOf(resolved) .. '">' .. text .. "</font>"
end

-- Performance Mode: fewer effects for low-end devices. Weather particles,
-- ripples, the dropdown marquee, the island meter and the tab and theme fades
-- are dropped, and DependsOn checks slow down. Off by default.
Library.PerformanceMode = false
-- Called with the new state, so switches showing it (the theme manager's) follow.
Library._performanceHooks = {}
function Library:SetPerformanceMode(enabled)
    enabled = enabled == true
    if enabled == Library.PerformanceMode then
        return enabled
    end
    Library.PerformanceMode = enabled
    for _, window in ipairs(Library.Windows) do
        -- Settle any running page fade so pages don't stay inside a fade layer.
        pcall(window._settleTransition, window)
    end
    for _, hook in ipairs(table.clone(Library._performanceHooks)) do
        pcall(hook, enabled)
    end
    return enabled
end

function Library:GetPerformanceMode()
    return Library.PerformanceMode == true
end

-- The window's corner radius in pixels, 0 (square) to 20; every other
-- rounded corner scales with it. The default is 10. Corners ease to the new
-- radius instead of jumping. Returns the radius it settled on.
function Library:SetCornerRadius(pixels, instant)
    pixels = math.clamp(math.floor((tonumber(pixels) or 10) + 0.5), 0, 20)
    Library.Roundness = pixels / 10
    for object, base in pairs(Library._cornerBases) do
        if not object.Parent then
            Library._cornerBases[object] = nil
        else
            local radius = UDim.new(0, math.floor(base * Library.Roundness + 0.5))
            if instant then
                object.CornerRadius = radius
            else
                tween(object, { CornerRadius = radius }, 0.25, Enum.EasingStyle.Quint)
            end
        end
    end
    return pixels
end

function Library:GetCornerRadius()
    return math.floor(Library.Roundness * 10 + 0.5)
end

function Library:SetTheme(theme, instant)
    if type(theme) == "string" then
        local found = Library.ThemePresets[theme]
        if not found then
            Library._warn(('SetTheme: no preset called "%s". Use a preset name such as "KaitUI" or "Midnight", or a table of colours.'):format(theme))
            return false
        end
        Library.ThemeName = theme
        theme = found
    elseif type(theme) ~= "table" then
        return false
    end
    local changed = false
    for _, name in ipairs(THEME_KEYS) do
        local color = toColor(theme[name])
        if color and color ~= Theme[name] then
            Theme[name] = color
            changed = true
        end
    end
    if not changed then
        return true
    end
    rebuildThemeLookup()
    sweepBindings()
    driveTheme((instant or Library.PerformanceMode) and 0 or 0.3)
    for owner, fn in pairs(themeHooks) do
        if owner.Parent then
            pcall(fn)
        end
    end
    for _, fn in ipairs(Library._themeListeners) do
        pcall(fn)
    end
    return true
end

function Library:GetTheme()
    local copy = {}
    for _, name in ipairs(THEME_KEYS) do
        copy[name] = Theme[name]
    end
    return copy
end

-- The script's starting theme: a preset name or a colour table. A default the
-- player picked in the theme manager still wins over it.
function Library:SetDefaultTheme(theme)
    Library.DefaultTheme = theme
    if theme == nil then
        return true
    end
    local live = false
    for _, window in ipairs(Library.Windows) do
        if not window._destroyed then
            if window:GetDefaultTheme() then
                return true
            end
            live = true
        end
    end
    return Library:SetTheme(theme, not live)
end

function Library:GetDefaultTheme()
    return Library.DefaultTheme
end

local function themeFolder(self)
    return self.ConfigFolder .. "/themes"
end

function Window:SaveTheme(name)
    if not fileApiAvailable() then
        return false, "file API unavailable"
    end
    if type(name) ~= "string" or name == "" then
        return false, "theme needs a name"
    end
    -- LoadTheme looks presets up first, so a saved theme with a preset's name could never load.
    if Library.ThemePresets[name] then
        return false, name .. " is a preset name"
    end
    if not validConfigName(name) then
        return false, "invalid theme name"
    end
    ensureFolder(self.ConfigFolder)
    ensureFolder(themeFolder(self))
    local data = {}
    for _, key in ipairs(THEME_KEYS) do
        data[key] = hexOf(Theme[key])
    end
    return pcall(function()
        writefile(themeFolder(self) .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
end

function Window:LoadTheme(name, instant)
    if Library.ThemePresets[name] then
        return Library:SetTheme(name, instant)
    end
    local text = readText(themeFolder(self) .. "/" .. tostring(name) .. ".json")
    if not text then
        return false, "no theme named " .. tostring(name)
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if not ok or type(data) ~= "table" then
        return false, "theme is not valid JSON"
    end
    Library.ThemeName = name
    return Library:SetTheme(data, instant)
end

function Window:DeleteTheme(name)
    if not fileApiAvailable() or type(delfile) ~= "function" then
        return false, "file API unavailable"
    end
    local path = themeFolder(self) .. "/" .. tostring(name) .. ".json"
    if not isfile(path) then
        return false, "no theme named " .. tostring(name)
    end
    local ok, err = pcall(delfile, path)
    if not ok then
        return false, tostring(err)
    end
    if self:GetDefaultTheme() == name then
        self:SetDefaultTheme(nil)
    end
    return true
end

function Window:ListThemes()
    local names = {}
    if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(themeFolder(self)) then
        return names
    end
    for _, path in ipairs(listfiles(themeFolder(self))) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    -- Same order as ListConfigs: case doesn't decide it.
    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    return names
end

function Window:GetDefaultTheme()
    return readText(themeFolder(self) .. "/default.txt")
end

function Window:SetDefaultTheme(name)
    if not fileApiAvailable() then
        return false, "file API unavailable"
    end
    ensureFolder(self.ConfigFolder)
    ensureFolder(themeFolder(self))
    local path = themeFolder(self) .. "/default.txt"
    if name == nil or name == "" then
        if isfile(path) and type(delfile) == "function" then
            pcall(delfile, path)
        end
        return true
    end
    return pcall(writefile, path, tostring(name))
end

function Window:_applyDefaultTheme()
    local name = self:GetDefaultTheme()
    if name then
        local ok, loaded = pcall(self.LoadTheme, self, name, true)
        if ok and loaded then
            return
        end
    end
    if Library.DefaultTheme ~= nil then
        pcall(Library.SetTheme, Library, Library.DefaultTheme, true)
    end
end


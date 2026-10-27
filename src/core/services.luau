local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

local Library = {}

Library.Flags = {}
Library.Windows = {}

local function normalize(source, map)
    local opts = {}
    if type(source) == "string" then
        opts.Name = source
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            opts[key] = value
        end
    end
    for from, to in pairs(map or {}) do
        if opts[to] == nil and opts[from] ~= nil then
            opts[to] = opts[from]
        end
    end
    if opts.Range then
        opts.Min = opts.Min or opts.Range[1]
        opts.Max = opts.Max or opts.Range[2]
    end
    -- A reversed range would make every math.clamp(value, Min, Max) throw.
    if type(opts.Min) == "number" and type(opts.Max) == "number" and opts.Min > opts.Max then
        opts.Min, opts.Max = opts.Max, opts.Min
    end
    return opts
end

-- Whether a page (tab, sub tab, groupbox) is shown by the script. A tabbox tab that
-- just isn't selected still counts, so search and the feature list can reach it.
function Library._pageShown(page)
    if page == nil then
        return true
    end
    if page.Tabbox then
        return page.Tabbox._userVisible ~= false
    end
    return page._userVisible ~= false
end

local function finishElement(tab, opts, element, frame, kind)
    element._type = kind
    element._frame = frame
    element._window = tab and tab.Window
    element._listeners = element._listeners or {}
    local window = tab and tab.Window
    local searchText = opts.Name or opts.Text or opts.Title
    element._searchName = type(searchText) == "string" and searchText or ""
    element._searchKey = string.lower(element._searchName)
    if tab and tab._items then
        table.insert(tab._items, element)
    end
    if opts.Flag then
        Library.Flags[opts.Flag] = element
        if window then
            window:_flagCreated(opts.Flag, element)
        end
    end
    -- Every toggle, flagged or not, so Window:Destroy can switch them all off.
    if window and kind == "Toggle" then
        window._toggles = window._toggles or {}
        table.insert(window._toggles, element)
    end
    element._userVisible = opts.Visible ~= false
    function element:IsVisible()
        return element._userVisible
    end
    function element:_isShown()
        return element._userVisible and not element._dependHidden and Library._pageShown(tab)
    end
    function element:SetVisible(visible)
        visible = visible and true or false
        if visible == element._userVisible or element._destroyed then
            return
        end
        element._userVisible = visible
        if not visible then
            if element._onHide then
                element._onHide()
            end
            if element.Open and type(element.SetOpen) == "function" then
                element:SetOpen(false)
            end
        end
        if frame then
            frame.Visible = visible and not element._dependHidden
        end
        if window then
            window._controlsDirty = true
        end
    end
    if frame and not element._userVisible then
        frame.Visible = false
    end
    -- Disabled: dimmed under a cover that swallows input.
    function element:SetDisabled(disabled)
        Library._setDisabled(element, frame, disabled)
    end
    function element:IsDisabled()
        return element.Disabled == true
    end
    if opts.Disabled == true then
        element:SetDisabled(true)
    end
    -- DependsOn: shown (or enabled, with DependsMode = "Disable") only while
    -- other flags allow it. See Library._dependsMet for the rule forms.
    function element:SetDependsOn(rule, mode)
        element._dependsOn = rule
        element._dependsMode = mode or element._dependsMode
        element._dependsMet = nil
        if rule == nil then
            Library._applyDepends(element, true)
        elseif window then
            Library._watchDepends(window, element)
        end
    end
    if opts.DependsOn ~= nil then
        element._dependsMode = opts.DependsMode
        element:SetDependsOn(opts.DependsOn)
    end
    -- Tooltip: a string, or { Title, Text, Icon }. nil, false or "" hides it.
    function element:SetTooltip(tip)
        element._tooltip = tip
        if frame and window and not element._tooltipBound then
            element._tooltipBound = true
            window:_attachTooltip(element, frame)
        end
    end
    function element:GetTooltip()
        return element._tooltip
    end
    if opts.Tooltip ~= nil and opts.Tooltip ~= false then
        element:SetTooltip(opts.Tooltip)
    end
    function element:Destroy()
        if element._destroyed then
            return
        end
        element._destroyed = true
        if window and window._toggles then
            local at = table.find(window._toggles, element)
            if at then
                table.remove(window._toggles, at)
            end
        end
        if window and window._tipOwner == element then
            window:_hideTooltip()
        end
        for _, disconnect in ipairs(element._listeners) do
            disconnect()
        end
        element._listeners = {}
        if tab and tab._items then
            local index = table.find(tab._items, element)
            if index then
                table.remove(tab._items, index)
            end
        end
        if opts.Flag and Library.Flags[opts.Flag] == element then
            Library.Flags[opts.Flag] = nil
        end
        if window then
            window._controlsDirty = true
        end
        if frame then
            frame:Destroy()
        end
    end
    return element
end

Library.Theme = {
    Background = Color3.fromRGB(15, 15, 15),
    Surface = Color3.fromRGB(20, 20, 20),
    Surface2 = Color3.fromRGB(25, 25, 25),
    Surface3 = Color3.fromRGB(50, 50, 50),
    Stroke = Color3.fromRGB(40, 40, 40),
    StrokeHover = Color3.fromRGB(70, 70, 70),
    Accent = Color3.fromRGB(128, 160, 246),
    AccentDark = Color3.fromRGB(12, 12, 12),
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(140, 140, 140),
    Warning = Color3.fromRGB(240, 176, 108),
    Success = Color3.fromRGB(150, 220, 170),
    Error = Color3.fromRGB(240, 120, 120),
}

-- Order decides which key wins when two theme colors are identical.
local THEME_KEYS = {
    "Accent", "AccentDark", "Background", "Surface", "Surface2", "Surface3",
    "Stroke", "StrokeHover", "Text", "Muted", "Warning", "Success", "Error",
}

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

-- Muted text is drawn small, so lift it toward Text until it clears WCAG AA
-- (4.5:1) against Surface2, the lightest surface it usually sits on.
function Library._readableMuted(muted, text, surface)
    local function luminance(color)
        local function channel(v)
            return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
        end
        return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
    end
    local back = luminance(surface)
    for step = 0, 20 do
        local candidate = muted:Lerp(text, step / 20)
        local front = luminance(candidate)
        if (math.max(front, back) + 0.05) / (math.min(front, back) + 0.05) >= 4.6 then
            return candidate
        end
    end
    return text
end

local function preset(background, surface, surface2, surface3, strokeColor, strokeHover, accent, accentDark, text, muted)
    return {
        Background = rgb(table.unpack(background)),
        Surface = rgb(table.unpack(surface)),
        Surface2 = rgb(table.unpack(surface2)),
        Surface3 = rgb(table.unpack(surface3)),
        Stroke = rgb(table.unpack(strokeColor)),
        StrokeHover = rgb(table.unpack(strokeHover)),
        Accent = rgb(table.unpack(accent)),
        AccentDark = rgb(table.unpack(accentDark)),
        Text = rgb(table.unpack(text)),
        Muted = Library._readableMuted(rgb(table.unpack(muted)), rgb(table.unpack(text)), rgb(table.unpack(surface2))),
    }
end

Library.ThemePresets = {
    -- Colours here must not be pure white, pure black or any other colour the
    -- library hard-codes, or those objects would get bound to the theme.
    -- KaitUI's own look: teal on a deep blue-green night. The default theme.
    KaitUI = preset({ 9, 15, 18 }, { 12, 19, 23 }, { 15, 24, 29 }, { 28, 43, 49 }, { 25, 39, 45 }, { 50, 90, 96 }, { 45, 212, 191 }, { 5, 26, 23 }, { 226, 242, 240 }, { 104, 136, 138 }),
    Midnight = preset({ 15, 18, 26 }, { 18, 22, 31 }, { 22, 26, 37 }, { 37, 44, 60 }, { 34, 40, 55 }, { 70, 84, 112 }, { 128, 160, 246 }, { 14, 18, 30 }, { 228, 232, 242 }, { 116, 126, 148 }),
    Ocean = preset({ 12, 20, 24 }, { 15, 24, 29 }, { 18, 29, 35 }, { 31, 48, 56 }, { 29, 44, 52 }, { 58, 92, 104 }, { 110, 214, 222 }, { 10, 24, 28 }, { 226, 238, 240 }, { 108, 134, 140 }),
    Rose = preset({ 21, 21, 21 }, { 26, 26, 26 }, { 31, 31, 31 }, { 48, 48, 48 }, { 44, 44, 44 }, { 92, 116, 50 }, { 183, 243, 74 }, { 21, 21, 21 }, { 243, 243, 238 }, { 134, 134, 128 }),
    Emerald = preset({ 13, 20, 17 }, { 16, 24, 20 }, { 20, 29, 24 }, { 33, 47, 40 }, { 30, 44, 37 }, { 62, 96, 78 }, { 132, 226, 170 }, { 12, 26, 18 }, { 228, 240, 233 }, { 110, 136, 122 }),
    Amber = preset({ 22, 18, 13 }, { 27, 22, 16 }, { 32, 26, 19 }, { 49, 41, 31 }, { 46, 38, 28 }, { 100, 82, 58 }, { 246, 196, 120 }, { 30, 22, 10 }, { 242, 236, 226 }, { 140, 126, 106 }),
    Mono = preset({ 16, 16, 17 }, { 20, 20, 21 }, { 25, 25, 26 }, { 40, 40, 42 }, { 38, 38, 40 }, { 84, 84, 88 }, { 236, 236, 240 }, { 20, 20, 22 }, { 234, 234, 236 }, { 122, 122, 128 }),
    Nebula = preset({ 14, 12, 28 }, { 18, 15, 35 }, { 23, 19, 43 }, { 39, 32, 68 }, { 35, 29, 62 }, { 84, 68, 140 }, { 199, 125, 255 }, { 22, 10, 40 }, { 236, 230, 252 }, { 124, 114, 160 }),
    Synthwave = preset({ 20, 12, 30 }, { 25, 15, 37 }, { 31, 18, 45 }, { 52, 30, 72 }, { 47, 27, 66 }, { 110, 58, 150 }, { 255, 94, 198 }, { 38, 8, 30 }, { 250, 232, 246 }, { 150, 118, 160 }),
    Sakura = preset({ 24, 14, 20 }, { 29, 17, 24 }, { 35, 20, 29 }, { 54, 32, 45 }, { 50, 29, 41 }, { 112, 66, 92 }, { 255, 158, 200 }, { 36, 12, 24 }, { 248, 232, 240 }, { 150, 112, 132 }),
    Velvet = preset({ 20, 10, 16 }, { 25, 12, 20 }, { 31, 15, 25 }, { 50, 25, 40 }, { 46, 23, 37 }, { 104, 52, 82 }, { 222, 110, 170 }, { 30, 8, 20 }, { 244, 228, 238 }, { 142, 106, 126 }),
    Crimson = preset({ 18, 10, 12 }, { 23, 12, 15 }, { 28, 14, 18 }, { 46, 24, 29 }, { 42, 22, 27 }, { 104, 46, 56 }, { 244, 74, 94 }, { 32, 8, 12 }, { 244, 230, 232 }, { 142, 106, 112 }),
    Sunset = preset({ 22, 13, 14 }, { 27, 16, 17 }, { 33, 19, 21 }, { 52, 31, 32 }, { 48, 28, 30 }, { 112, 62, 58 }, { 255, 138, 92 }, { 34, 14, 8 }, { 248, 234, 228 }, { 150, 118, 110 }),
    Gold = preset({ 14, 13, 11 }, { 18, 17, 14 }, { 23, 21, 17 }, { 38, 35, 28 }, { 35, 32, 26 }, { 92, 80, 54 }, { 232, 196, 122 }, { 30, 22, 8 }, { 240, 234, 222 }, { 136, 126, 106 }),
    Cyber = preset({ 13, 13, 15 }, { 17, 17, 19 }, { 21, 21, 24 }, { 36, 36, 40 }, { 33, 33, 37 }, { 86, 84, 70 }, { 250, 226, 72 }, { 30, 26, 4 }, { 240, 240, 232 }, { 126, 124, 118 }),
    Toxic = preset({ 11, 14, 11 }, { 14, 18, 14 }, { 18, 23, 18 }, { 31, 39, 30 }, { 28, 36, 28 }, { 74, 98, 60 }, { 184, 255, 74 }, { 18, 30, 6 }, { 232, 242, 228 }, { 116, 134, 110 }),
    Matcha = preset({ 16, 19, 14 }, { 20, 23, 17 }, { 24, 28, 21 }, { 40, 46, 34 }, { 37, 42, 31 }, { 84, 98, 70 }, { 176, 214, 140 }, { 18, 26, 10 }, { 236, 240, 228 }, { 128, 136, 116 }),
    Aurora = preset({ 10, 20, 22 }, { 12, 25, 27 }, { 15, 30, 33 }, { 26, 50, 53 }, { 24, 45, 48 }, { 50, 104, 104 }, { 94, 240, 180 }, { 6, 30, 22 }, { 224, 246, 240 }, { 102, 142, 134 }),
    Frost = preset({ 13, 17, 23 }, { 16, 21, 28 }, { 20, 26, 34 }, { 34, 43, 56 }, { 31, 40, 52 }, { 72, 92, 118 }, { 164, 214, 255 }, { 12, 22, 34 }, { 230, 238, 246 }, { 114, 128, 146 }),
    Abyss = preset({ 7, 11, 22 }, { 9, 14, 28 }, { 12, 18, 35 }, { 22, 31, 58 }, { 20, 28, 52 }, { 44, 64, 120 }, { 72, 148, 255 }, { 6, 14, 34 }, { 226, 234, 250 }, { 100, 116, 152 }),
    -- Seasonal and themed palettes.
    Halloween = preset({ 18, 12, 20 }, { 23, 15, 25 }, { 28, 18, 30 }, { 46, 30, 48 }, { 43, 28, 44 }, { 104, 62, 40 }, { 255, 138, 36 }, { 36, 16, 4 }, { 246, 234, 224 }, { 146, 120, 128 }),
    Haunted = preset({ 14, 12, 20 }, { 18, 15, 26 }, { 22, 18, 32 }, { 38, 31, 54 }, { 35, 29, 50 }, { 70, 96, 64 }, { 156, 255, 110 }, { 14, 30, 8 }, { 232, 240, 228 }, { 120, 116, 140 }),
    Christmas = preset({ 12, 20, 15 }, { 15, 25, 19 }, { 19, 30, 23 }, { 32, 50, 38 }, { 30, 46, 35 }, { 100, 54, 56 }, { 236, 72, 80 }, { 34, 8, 10 }, { 240, 244, 236 }, { 120, 142, 128 }),
    Valentine = preset({ 24, 12, 17 }, { 30, 14, 21 }, { 36, 17, 25 }, { 58, 27, 40 }, { 54, 25, 37 }, { 130, 56, 84 }, { 255, 92, 140 }, { 40, 8, 20 }, { 252, 232, 240 }, { 160, 112, 132 }),
    Lunar = preset({ 22, 10, 10 }, { 28, 12, 12 }, { 34, 15, 14 }, { 54, 24, 22 }, { 50, 22, 20 }, { 130, 92, 40 }, { 246, 196, 84 }, { 38, 16, 6 }, { 250, 236, 222 }, { 160, 120, 108 }),
    Tropical = preset({ 10, 22, 24 }, { 12, 27, 30 }, { 15, 33, 36 }, { 26, 54, 58 }, { 24, 50, 54 }, { 44, 110, 110 }, { 255, 170, 90 }, { 36, 18, 6 }, { 232, 246, 244 }, { 104, 144, 142 }),
    Dracula = preset({ 24, 25, 33 }, { 29, 30, 40 }, { 34, 36, 47 }, { 52, 55, 70 }, { 48, 50, 64 }, { 98, 114, 164 }, { 189, 147, 249 }, { 26, 18, 44 }, { 246, 246, 238 }, { 126, 132, 168 }),
    Coffee = preset({ 20, 16, 13 }, { 25, 20, 16 }, { 30, 24, 19 }, { 48, 39, 31 }, { 45, 36, 29 }, { 104, 82, 62 }, { 214, 170, 124 }, { 32, 22, 12 }, { 240, 230, 218 }, { 142, 124, 108 }),
}

Library.ThemeName = "KaitUI"
for key, value in pairs(Library.ThemePresets.KaitUI) do
    Library.Theme[key] = value
end

Library.Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow = "rbxassetid://8992230677",
    Logo = "rbxassetid://103859712365480",
}

local LUCIDE_URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
local lucideSet = nil


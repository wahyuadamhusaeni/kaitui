-- Misuse test: wrong types, missing options and common scripting mistakes.
-- None of it may crash; warnings that explain the mistake are expected.
local KaitUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/wahyuadamhusaeni/kaitui/refs/heads/main/dist/KaitUI.luau"))()
local H = HARNESS

local function try(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        H.fail("misuse " .. label, err)
    end
    return ok and err or nil
end

-- Library calls before any window exists.
try("Notify before window", function() KaitUI:Notify({ Title = "early" }):Dismiss() end)
try("Confirm before window", function() KaitUI:Confirm({ Title = "early" }) end)
try("SetTheme bad name", function() KaitUI:SetTheme("NoSuchTheme") end)
try("SetTheme number", function() KaitUI:SetTheme(123) end)
try("SetTheme bad colours", function() KaitUI:SetTheme({ Accent = "not a colour", Text = 5 }) end)
try("dot CreateWindow", function() KaitUI.CreateWindow({ Name = "Dot" }):Destroy() end)

local Window = KaitUI:CreateWindow({
    Name = 12345,                         -- not a string
    ToggleUIKeybind = "Ctrl",             -- not a key name
    Size = "big",                         -- not a UDim2
    UIScale = "huge",
    ConfigurationSaving = { Enabled = true, FolderName = "Misuse/Sub" },
    Home = { Discord = 123, Stats = "FPS" },
})
local Tab = Window:CreateTab({ Name = "Main" })
local Box = Tab:CreateGroupbox({ Name = "Box", Side = "Middle" })

local constructors = {
    "Toggle", "Slider", "Stepper", "Segmented", "Dropdown", "PlayerPicker", "OrderList", "Input", "Textarea", "Keybind",
    "ColorPicker", "Label", "Paragraph", "Section", "Divider", "Button", "ButtonRow", "Status", "StatusList", "Progress",
    "Table", "Log", "Image", "Graph",
}
local bad = {
    "nil",
    "string",
    "number",
    "empty",
    "name number",
    "callback string",
    "options string",
    "options mixed",
    "default instance",
    "flag number",
    "range strings",
    "range short",
    "increment string",
    "min max strings",
    "columns string",
    "rows string",
    "items string",
    "tooltip number",
    "dependson number",
    "icon boolean",
    "desc number",
    "default wrong type",
}
local function badOptions(kind)
    if kind == "nil" then return nil end
    if kind == "string" then return "Just a name" end
    if kind == "number" then return 42 end
    if kind == "empty" then return {} end
    if kind == "name number" then return { Name = 123 } end
    if kind == "callback string" then return { Name = "X", Callback = "print" } end
    if kind == "options string" then return { Name = "X", Options = "a,b,c" } end
    if kind == "options mixed" then return { Name = "X", Options = { 1, true, "b", { 1 } } } end
    if kind == "default instance" then return { Name = "X", Default = game } end
    if kind == "flag number" then return { Name = "X", Flag = 77 } end
    if kind == "range strings" then return { Name = "X", Range = { "a", "b" } } end
    if kind == "range short" then return { Name = "X", Range = { 5 } } end
    if kind == "increment string" then return { Name = "X", Increment = "2" } end
    if kind == "min max strings" then return { Name = "X", Min = "10", Max = "20" } end
    if kind == "columns string" then return { Name = "X", Columns = "a" } end
    if kind == "rows string" then return { Name = "X", Rows = "a" } end
    if kind == "items string" then return { Name = "X", Items = "a" } end
    if kind == "tooltip number" then return { Name = "X", Tooltip = 5 } end
    if kind == "dependson number" then return { Name = "X", DependsOn = 5 } end
    if kind == "icon boolean" then return { Name = "X", Icon = true } end
    if kind == "desc number" then return { Name = "X", Desc = 9 } end
    if kind == "default wrong type" then return { Name = "X", Default = { nope = true }, CurrentValue = "yes" } end
end

local made = {}
for _, target in ipairs({ Box, Tab }) do
    for _, ctor in ipairs(constructors) do
        for _, kind in ipairs(bad) do
            local handle = try(ctor .. " / " .. kind, function()
                return target["Create" .. ctor](target, badOptions(kind))
            end)
            if type(handle) == "table" then table.insert(made, handle) end
        end
    end
end
print("misuse elements made:", #made)

-- Handles used the wrong way.
local values = { n = 8, nil, "x", 5, true, {}, { 1, 2 }, Color3.new(1, 0, 0), Enum.KeyCode.F }
for index, handle in ipairs(made) do
    for v = 1, values.n do
        try("Set #" .. index .. " " .. tostring(handle._type), function() if handle.Set then handle:Set(values[v]) end end)
    end
    try("Get", function() if handle.Get then handle:Get() end end)
    try("SetVisible string", function() if handle.SetVisible then handle:SetVisible("yes") end end)
    try("SetDependsOn junk", function() if handle.SetDependsOn then handle:SetDependsOn(123) end end)
    if index % 7 == 0 then H.step(1 / 30) end
end

-- Dot instead of colon on handles.
local T = Box:CreateToggle({ Name = "Dot toggle", Flag = "DotToggle" })
try("Toggle.Set dot", function() T.Set(true) end)
if T:Get() ~= true then H.fail("misuse", "Toggle.Set(true) with a dot did not set the toggle") end
try("Toggle.Get dot", function() T.Get() end)
local S = Box:CreateSlider({ Name = "Dot slider", Range = { 0, 10 } })
try("Slider.Set dot", function() S.Set(5) end)
if S:Get() ~= 5 then H.fail("misuse", "Slider.Set(5) with a dot did not set the slider") end

-- Dot instead of colon on the window and tabs: an error that says what to write.
for label, call in pairs({
    ["Window.CreateTab"] = function() Window.CreateTab({ Name = "Dot tab" }) end,
    ["Tab.CreateGroupbox"] = function() Tab.CreateGroupbox({ Name = "Dot box" }) end,
    ["Window.Notify"] = function() Window.Notify({ Title = "dot" }) end,
}) do
    local ok, err = pcall(call)
    if ok or not tostring(err):find("Use a colon", 1, true) then
        H.fail("misuse " .. label, "expected a clear 'Use a colon' error, got " .. tostring(err))
    end
end

Box:CreateKeybind({ Name = "Bad key", CurrentKeybind = "NotAKey" })

-- Duplicate flags and callbacks that error.
Box:CreateToggle({ Name = "First", Flag = "Same" })
Box:CreateToggle({ Name = "Second", Flag = "Same" })
local Boom = Box:CreateToggle({ Name = "Boom", Callback = function() error("user code failed") end })
try("callback error", function() Boom:Set(true) end)

-- Destroyed handles.
local D = Box:CreateDropdown({ Name = "Gone", Options = { "a", "b" } })
D:Destroy()
try("Destroy twice", function() D:Destroy() end)
try("Set after destroy", function() D:Set("a") end)
try("SetOptions after destroy", function() D:SetOptions({ "c" }) end)

-- Window API with bad arguments.
try("SelectTab missing", function() Window:SelectTab("No such tab") end)
try("SelectTab nil", function() Window:SelectTab(nil) end)
try("Notify string", function() Window:Notify("just text") end)
try("Notify nil", function() Window:Notify(nil) end)
try("Confirm nil", function() Window:Confirm(nil) end)
try("Dialog nil", function() Window:Dialog(nil) end)
try("SaveConfig nil", function() Window:SaveConfig(nil) end)
try("SaveConfig bad name", function() Window:SaveConfig("a/b:c") end)
try("LoadConfig missing", function() Window:LoadConfig("missing") end)
try("LoadConfig number", function() Window:LoadConfig(123) end)
try("ImportConfig garbage", function() Window:ImportConfig("garbage") end)
try("DeleteConfig missing", function() Window:DeleteConfig("missing") end)
try("SetKeybind number", function() Window:SetKeybind(123) end)
try("SetUIScale string", function() Window:SetUIScale("big") end)
try("SetSize nil", function() Window:SetSize(nil) end)
try("SetDensity bad", function() Window:SetDensity("Huge") end)
try("SetBackground bad", function() Window:SetBackground(true) end)
try("SetWeather bad", function() Window:SetWeather("Lava") end)
try("CreateTab nil", function() Window:CreateTab(nil) end)
try("CreateTab string", function() Window:CreateTab("Named") end)
try("CreateGroupbox nil", function() Tab:CreateGroupbox(nil) end)
try("AddLeftGroupbox string", function() Tab:AddLeftGroupbox("Left by name") end)
local Paged = Window:CreateTab({ Name = "Paged" })
Paged:CreateSubTab({ Name = "One" })
try("element on tab with sub tabs", function() Paged:CreateToggle({ Name = "Misplaced" }) end)
try("Watermark nil", function() Window:CreateWatermark(nil) end)
try("KeybindList string", function() Window:CreateKeybindList("x") end)
try("ConfigManager twice", function() Tab:CreateConfigManager({ Side = "Left" }) Tab:CreateConfigManager({ Side = "Left" }) end)
try("ThemeManager nil", function() Tab:CreateThemeManager(nil) end)
try("Colorize nil", function() KaitUI.Colorize(nil, nil) end)
try("SetPerformanceMode string", function() KaitUI:SetPerformanceMode("yes") end)

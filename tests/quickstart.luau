-- Smoke test: the llms.txt skeleton plus every newer feature, edge cases included.
local KaitUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/wahyuadamhusaeni/kaitui/refs/heads/main/dist/KaitUI.luau"))()
local Window = KaitUI:CreateWindow({
    Name = "My Hub",                       -- title, also names the ScreenGui
    LoadingSubtitle = "by Me",
    ToggleUIKeybind = "RightControl",      -- hides and shows the window
    ConfigurationSaving = { Enabled = true, FolderName = "MyHub" },
    Home = { Discord = "dsc.gg/myhub" },   -- built-in first tab; false removes it
    PerformanceMode = "Auto",              -- lighter on slow phones
    OnClose = function()                   -- the × (or Window:Destroy) unloads; stop your loops here
        getgenv().MyHubRunning = false
    end,
})

local Main = Window:CreateTab({ Name = "Main", Icon = "swords" })     -- Icon: any lucide name
local Farm = Main:CreateGroupbox({ Name = "Farming", Side = "Left" })  -- or Main:AddLeftGroupbox("Farming", "sprout")
local Info = Main:CreateGroupbox({ Name = "Info", Side = "Right" })

local AutoFarm = Farm:CreateToggle({
    Name = "Auto Farm",
    Flag = "AutoFarm",                     -- unique; makes it saveable and reachable as KaitUI.Flags.AutoFarm
    CurrentValue = false,
    Callback = function(On)
        -- runs on every change, and once at creation when CurrentValue is true
    end,
})

Farm:CreateSlider({ Name = "Range", Range = { 5, 50 }, Increment = 1, CurrentValue = 20, Suffix = " studs", Flag = "Range", Callback = function(V) end })
Farm:CreateDropdown({ Name = "Mobs", Options = { "Bandit", "Wolf" }, MultipleOptions = true, Flag = "Mobs", Callback = function(List) end })

Info:CreateStatus({ Name = "State", Style = "Row", Pin = true, Update = function()
    return AutoFarm.Value and "<Success>Farming</Success>" or "<Muted>Idle</Muted>"
end })

local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })
Settings:CreateConfigManager({ Side = "Left" })
Settings:CreateThemeManager({ Side = "Right" })

Window:LoadAutoload()                      -- apply the player's autoload config, if any

-- New features, as documented
local Extra = Main:CreateGroupbox({ Name = "Extra", Side = "Right" })
Extra:CreateSegmented({ Name = "Mode", Options = { "A", "B", "C" }, Flag = "Mode", Callback = function() end })
Extra:CreateSegmented({ Name = "Rate", Options = { 30, 60, 120 }, CurrentOption = 60, Flag = "Rate" })
Extra:CreateTextarea({ Name = "Notes", Lines = 3, MaxLength = 50, Flag = "Notes" })
Extra:CreateTextarea({ Desc = "only a hint" })
Extra:CreatePlayerPicker({ Name = "Target", Flag = "Target", Callback = function() end })
local Picker = Extra:CreatePlayerPicker({ Name = "Many", Multi = true, IncludeSelf = true, Flag = "Many" })
Extra:CreateToggle({ Name = "Needs target", DependsOn = "Target" })
Extra:CreateGraph({ Name = "G", Update = function() return math.random(1, 100) end, UpdateRate = 0.2 })
local Fly = Extra:CreateToggle({ Name = "Fly", Flag = "Fly" })
Extra:CreateKeybind({ Name = "Fly key", CurrentKeybind = "F", Linked = Fly, Flag = "FlyKey" })
Extra:CreateSlider({ Name = "WalkSpeed", Range = { 16, 200 }, Increment = 5, CurrentValue = 50, Flag = "WS" })
Extra:CreateSlider({ Name = "Reversed", Min = 200, Increment = 0, Flag = "Rev" })
Extra:CreateStepper({ Name = "Step", Range = { 1, 10 }, Increment = 0.1, Flag = "Step" })
Extra:CreateDropdown({ Name = "Icons", Options = { "sword", "shield" }, OptionIcon = function(o) return o end, Flag = "Icons" })
Window:CreateWatermark({})
Window:CreateKeybindList({ ShowAll = true })
local Toast = KaitUI:Notify({ Title = "Hi", Buttons = { { Title = "Ok" } }, Progress = 0 })
Toast:SetProgress(1)
KaitUI:SetPerformanceMode(true)
KaitUI:SetPerformanceMode(false)
assert(KaitUI.Flags.Rate:Get() == 60, "numeric segmented option")
assert(KaitUI.Flags.WS:Get() == 50, "slider snapping kept 50")

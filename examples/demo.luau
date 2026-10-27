--[[
    Example script

    A reference build that shows every part of the library in a realistic
    layout. Each section is self-contained: copy the parts you need.

    Structure
      Window      the main frame, Home tab and global options
      Main        a typical feature tab: sub tabs, groupboxes and controls
      Status      live readouts: statuses, status lists and dependent controls
      Elements    one of every element as a full-width card
      Popups      notifications, confirms and dialogs
      Settings    interface options, config manager and theme manager
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/wahyuadamhusaeni/kaitui/refs/heads/main/dist/KaitUI.luau"))()
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

Library:LoadFont({ Name = "ValleySans" }) -- downloaded once and used everywhere
-- Library:SetDefaultTheme("Nebula") -- any preset name or a colour table; a theme the player picks wins

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local Window = Library:CreateWindow({
    Name = "KaitUI",
    LoadingSubtitle = "Loading",
    ToggleUIKeybind = "RightControl", -- a KeyCode name or Enum.KeyCode
    ConfigurationSaving = { Enabled = true, FolderName = "Example" },
    ToggleButton = { Platform = "Mobile", Icon = "layout-grid" }, -- "Both" also shows it on PC
    Backdrop = { Weather = "None", Tint = 0.45 }, -- "Snow", "Rain", "Hell Fire", "Sakura", "Fireflies", "Matrix" or "None"
    -- UIScale = 1,           -- 0.6 to 1.5, on top of the automatic fit
    -- Density = "Default",   -- "Compact", "Default" or "Comfortable"
    -- SidebarWidth = 188,    -- starting sidebar width; players can drag the divider
    -- Disclaimer = { Title = "Terms", Text = "By continuing you accept the terms.", Id = "terms-v1" },
    PerformanceMode = "Auto", -- true, false, or "Auto": on for touch devices under 40 fps
    -- CloseButton = true,    -- the × in the top-right; false leaves only minimize
    -- CloseConfirm = true,   -- false closes on the first click
    OnClose = function()
        -- Runs once before the window unloads (the ×, Window:Destroy, or re-running the script).
        print("[Example] closing")
    end,
    Home = {
        Tier = "Free",
        Expiry = os.time() + 30 * 86400, -- a timestamp, a string, or a function returning either
        Discord = "discord.gg/example",
        Website = "example.com",
        Stats = { "Players", "Execs", "Session", "FPS", "Ping" },
        -- Features = { List = { { Name = "Main", Items = { "Automation", { Name = "Targeting", Tag = "New" } } } } },
    },
})

--------------------------------------------------------------------------------
-- Main: tabs hold sub tabs, sub tabs hold groupboxes, groupboxes hold elements
--------------------------------------------------------------------------------

local Main = Window:CreateTab({ Name = "Main", Icon = "zap" })

local General = Main:CreateSubTab({ Name = "General" })

local Automation = General:AddLeftGroupbox({ Name = "Automation", Icon = "repeat" })

Automation:CreateToggle({
    Name = "Enabled",
    Desc = "Runs the selected tasks on a loop",
    CurrentValue = false,
    Flag = "AutomationEnabled",
    Callback = function(Value)
        print("[Example] automation", Value)
    end,
})

Automation:CreateDropdown({
    Name = "Tasks",
    Options = { "Collect", "Upgrade", "Sell", "Claim Rewards" },
    MultipleOptions = true,
    CurrentOption = { "Collect" },
    Flag = "AutomationTasks",
    Callback = function(Options)
        print("[Example] tasks", table.concat(Options, ", "))
    end,
})

-- Picks too long for the chip scroll past in a loop.
Automation:CreateDropdown({
    Name = "Zones",
    Options = { "Spawn", "Forest", "Desert", "Volcano", "Tundra", "Ocean", "Sky Island" },
    MultipleOptions = true,
    CurrentOption = { "Forest", "Desert", "Volcano", "Tundra", "Ocean" },
    Flag = "AutomationZones",
    Callback = function(Options)
        print("[Example] zones", table.concat(Options, ", "))
    end,
})

Automation:CreateSlider({
    Name = "Interval",
    Range = { 1, 60 },
    Increment = 1,
    Suffix = "s",
    CurrentValue = 5,
    Flag = "AutomationInterval",
    Callback = function(Value)
        print("[Example] interval", Value)
    end,
})

local Targeting = General:AddRightGroupbox({ Name = "Targeting", Icon = "crosshair" })

Targeting:CreateDropdown({
    Name = "Mode",
    Options = { "Nearest", "Lowest Health", "Highest Value" },
    CurrentOption = "Nearest",
    Flag = "TargetMode",
    Callback = function(Option)
        print("[Example] target mode", Option)
    end,
})

Targeting:CreateSlider({
    Name = "Range",
    Range = { 0, 500 },
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 150,
    Flag = "TargetRange",
    Callback = function(Value)
        print("[Example] range", Value)
    end,
})

Targeting:CreateToggle({
    Name = "Ignore Friends",
    CurrentValue = true,
    Flag = "IgnoreFriends",
    Callback = function(Value)
        print("[Example] ignore friends", Value)
    end,
})

local Controls = General:AddRightGroupbox({ Name = "Controls", Icon = "sliders-horizontal", Collapsed = true })

Controls:CreateStepper({
    Name = "Speed",
    Range = { 1, 10 },
    Increment = 1,
    CurrentValue = 5,
    Flag = "Speed",
    Callback = function(Value)
        print("[Example] speed", Value)
    end,
})

Controls:CreateKeybind({
    Name = "Stop",
    CurrentKeybind = "X",
    Flag = "StopKey",
    Callback = function()
        print("[Example] stop")
    end,
})

local Advanced = Main:CreateSubTab({ Name = "Advanced" })

local Profiles = Advanced:AddLeftGroupbox({ Name = "Profile", Icon = "user-cog" })

Profiles:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "https://",
    Flag = "WebhookUrl",
    Callback = function(Text)
        print("[Example] webhook", Text)
    end,
})

Profiles:CreateColorPicker({
    Name = "Highlight Color",
    Color = Color3.fromRGB(128, 160, 246),
    Flag = "HighlightColor",
    Callback = function(Color)
        print("[Example] color", Color)
    end,
})

Profiles:CreateButton({
    Name = "Apply",
    Style = "Primary",
    Callback = function()
        print("[Example] applied")
    end,
})

-- Order lists are always open: drag a row (by its grip on touch) or use the arrows.
local Priority = Advanced:AddRightGroupbox({ Name = "Priority", Icon = "list-ordered" })

Priority:CreateOrderList({
    Name = "Task Order",
    Desc = "The top task runs first",
    Items = { "Collect", "Upgrade", "Sell", "Claim Rewards" },
    Flag = "TaskOrder",
    Callback = function(Order)
        print("[Example] order", table.concat(Order, " > "))
    end,
})

local Steps = {}
for Index = 1, 12 do
    Steps[Index] = "Step " .. Index
end
Priority:CreateOrderList({
    Name = "Steps",
    Items = Steps,
    MaxRows = 5, -- more rows than MaxRows scroll inside the list
    Flag = "StepOrder",
})

-- Tabboxes: a groupbox with tabs in its header; each tab holds its own rows
local Filters = Advanced:AddLeftTabbox({ Name = "Filters" })
local Include = Filters:AddTab({ Name = "Include", Icon = "plus" })
Include:CreateToggle({ Name = "Rare Items", CurrentValue = true, Flag = "IncludeRare" })
Include:CreateToggle({ Name = "Event Items", CurrentValue = false, Flag = "IncludeEvent" })
local Exclude = Filters:AddTab({ Name = "Exclude", Icon = "minus" })
Exclude:CreateToggle({ Name = "Common Items", CurrentValue = false, Flag = "ExcludeCommon" })
Exclude:CreateSlider({ Name = "Below Value", Range = { 0, 1000 }, Increment = 10, CurrentValue = 100, Flag = "ExcludeBelow" })

Main:CreateSubTab({ Name = "Queue" }) -- an empty sub tab shows the empty state

--------------------------------------------------------------------------------
-- Status: live readouts. Pin = true also shows a value on the minimized island
--------------------------------------------------------------------------------

local Status = Window:CreateTab({ Name = "Status", Icon = "activity" })

local Session = Status:AddLeftGroupbox({ Name = "Session", Icon = "timer" })
local Cycles = 0
Session:CreateStatuses({
    { Name = "Cycles", Pin = true, Update = function()
        Cycles += 1
        return Cycles
    end },
    { Name = "Collected", Value = 0 },
    { Name = "Errors", Value = 0 },
    { Name = "Region", Value = "-" },
}, { Style = "Plain" })

local Progress = Status:AddRightGroupbox({ Name = "Progress", Icon = "trending-up" })
Progress:CreateStatus({ Name = "Level", Value = 42, Style = "Stat" })
Progress:CreateStatus({ Name = "Experience", Value = "6200/10000", Style = "Bar" })
Progress:CreateStatus({ Name = "Balance", Value = 125000, Style = "Row", Pin = true })

local Health = Status:AddLeftGroupbox({ Name = "Health", Icon = "heart-pulse" })
local States = { { "Running", "Success" }, { "Waiting", "Warning" }, { "Stopped", "Error" } }
Health:CreateStatus({ Name = "State", Style = "Dot", Update = function()
    local State = States[math.floor(os.clock() / 3) % #States + 1]
    return State[1], State[2] -- a second string return sets the tone
end })
Health:CreateStatus({ Name = "Service", Value = "Online", Style = "Badge", Tone = "Success" })
Health:CreateStatus({ Name = "Load", Style = "Bar", Tone = "Warning", UpdateRate = 0.5, Update = function()
    return (os.clock() * 100) % 100, 100 -- a number second return sets the max
end })
-- Coloured text: theme tags follow the theme, Colorize wraps any colour.
Health:CreateStatus({ Name = "Ping", Style = "Row", Pin = true, Update = function()
    local Ms = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    local Tone = Ms < 90 and "Success" or Ms < 180 and "Warning" or "Error"
    return Library.Colorize(Ms .. " ms", Tone)
end })
Health:CreateStatus({ Name = "Summary", Style = "Row", Value = "<Accent>3</Accent> active · <Muted>9 idle</Muted>" })

-- Status lists grow with their rows up to MaxRows, then scroll inside.
local Jobs = Status:AddRightGroupbox({ Name = "Jobs", Icon = "list-checks" })
Jobs:CreateStatusList({
    Name = "Queue",
    MaxRows = 5,
    EmptyText = "Nothing queued",
    UpdateRate = 0.5,
    Update = function()
        local Rows = {}
        for Index = 1, 8 do
            local Remaining = math.floor((os.clock() + Index * 3) % 15)
            Rows[Index] = {
                Text = "Job " .. Index,
                Value = Remaining == 0 and "done" or (Remaining .. "s left"),
                Tone = Remaining == 0 and "Success" or nil,
            }
        end
        return Rows
    end,
})

-- Dependent controls: the slider only shows while the toggle is on.
local Limit -- declared first so the toggle's callback can reach it
Jobs:CreateToggle({
    Name = "Limit Jobs",
    CurrentValue = false,
    Flag = "LimitJobs",
    Callback = function(Value)
        Limit:SetVisible(Value)
    end,
})
Limit = Jobs:CreateSlider({
    Name = "Max Jobs",
    Range = { 1, 20 },
    Increment = 1,
    CurrentValue = 5,
    Visible = false, -- hidden at start, still saved with the config
    Flag = "MaxJobs",
})

--------------------------------------------------------------------------------
-- Elements: added straight to a tab, every element is a full-width card
--------------------------------------------------------------------------------

local Elements = Window:CreateTab({ Name = "Elements", Desc = "Every element, full width", Icon = "layout-grid" })

Elements:CreateSection("Controls")

Elements:CreateButton({
    Name = "Button",
    Desc = "With a description and a tooltip",
    Icon = "mouse-pointer-click",
    Tooltip = "Any element accepts a Tooltip", -- a string, or { Title, Text, Icon }
    Callback = function()
        print("[Example] button")
    end,
})

Elements:CreateToggle({
    Name = "Toggle",
    Desc = "Tooltips can carry a title and an icon",
    Tooltip = { Title = "Toggle", Text = "Saved with the config through its Flag.", Icon = "info" },
    CurrentValue = false,
    Flag = "ElementToggle",
})

Elements:CreateSlider({
    Name = "Slider",
    Range = { 0, 100 },
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "ElementSlider",
})

Elements:CreateProgress({ Name = "Progress", CurrentValue = 0.65 })

Elements:CreateParagraph({
    Title = "Paragraph",
    Content = "Longer text wraps across as many lines as it needs.",
})

Elements:CreateSection("Media and tables")

Elements:CreateImage({
    Name = "Image",
    Image = "Deep Violet", -- an asset id, rbxassetid:// or rbxthumb:// link, a web link, a background preset or "Avatar"
    Height = 140,
    Caption = "Images fade in once loaded",
})

do
    local Board = Elements:CreateTable({
        Name = "Leaderboard",
        Rank = true, -- a # column with medals for the top three
        Columns = {
            "Player",
            { Name = "Score", Align = "Right", Width = 0.2 },
            { Name = "Balance", Align = "Right", Width = 0.25, Format = function(Value) return "$" .. Value end },
        },
        Rows = {
            { "Player One", 42, 12500 },
            { "Player Two", 57, 9800 },
            { LocalPlayer.DisplayName, 31, 15200, Highlight = true },
            { "Player Four", 12, 300 },
            { "Player Five", 5, 150 },
        },
        SortBy = "Score", -- click a header to sort, again to flip, a third time to reset
        MaxRows = 6,
        Callback = function(Row, Index)
            print("[Example] row", Row[1], Index)
        end,
    })
    task.spawn(function()
        while task.wait(3) do
            local Row = Board.Rows[3]
            if not Row or not Window.Gui.Parent then
                break
            end
            Board:UpdateRow(3, { Row[1], Row[2] + math.random(0, 2), Row[3] + math.random(0, 400), Highlight = true })
        end
    end)
end

local Activity = Elements:CreateLog({
    Name = "Activity",
    MaxEntries = 50, -- the oldest lines drop off past this
    MaxRows = 5,
})

local Rules = Elements:CreateTable({
    Name = "Price Rules",
    Desc = "Typed columns make a table editable",
    Columns = {
        { Name = "Item", Type = "Text", Placeholder = "Item name" },
        { Name = "Sell", Type = "Number", Min = 0, Integer = true, Align = "Right", Width = 0.22 },
        { Name = "Buy", Type = "Toggle", Align = "Center", Width = 0.14 },
        { Name = "Mode", Type = "Dropdown", Options = { "Market", "Auction", "Trade" }, Searchable = true, Width = 0.24 },
    },
    Rows = {
        { Item = "Golden Egg", Sell = 500, Buy = false, Mode = "Market" },
    },
    Flag = "PriceRules", -- saved with the config like any other flag
    OnChanged = function(Rows)
        Activity:Push(("%d price rule(s)"):format(#Rows), "Muted")
    end,
})

Activity:Push("Bought <Accent>Golden Egg</Accent> for 480", "Success")
Activity:Push("Listed Silver Egg for 1,200")
Activity:Push("Trade declined", "Warning")

Elements:CreateDropdown({
    Name = "Price Mode",
    Options = { "Fixed", "Undercut" },
    CurrentOption = "Fixed",
    AllowNone = false,
    Flag = "PriceMode",
})

Elements:CreateSlider({
    Name = "Undercut %",
    Range = { 1, 50 },
    Increment = 1,
    Suffix = "%",
    CurrentValue = 5,
    Flag = "UndercutPercent",
    DependsOn = { Flag = "PriceMode", Value = "Undercut" }, -- only shown in Undercut mode
})

Elements:CreateToggle({ Name = "Auto Bid", CurrentValue = false, Flag = "AutoBid" })

Elements:CreateSlider({
    Name = "Max Bid",
    Range = { 100, 10000 },
    Increment = 100,
    CurrentValue = 1000,
    Flag = "MaxBid",
    DependsOn = "AutoBid",
    DependsMode = "Disable", -- dimmed instead of hidden while Auto Bid is off
})

Elements:CreateButton({
    Name = "Clear All Rules",
    Icon = "trash-2",
    Confirm = true, -- first click arms it, the second runs it
    Callback = function()
        Rules:SetRows({})
        Activity:Push("Cleared every price rule", "Warning")
    end,
})

Elements:CreateButton({
    Name = "Spend 1,000 Gold",
    Icon = "coins",
    HoldToConfirm = 1.5, -- seconds to hold
    Callback = function()
        Activity:Push("Spent 1,000 gold", "Accent")
    end,
})

--------------------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------------------

local Popups = Window:CreateTab({ Name = "Popups", Desc = "Notifications and dialogs", Icon = "bell" })

local Notifications = Popups:AddLeftGroupbox({ Name = "Notifications", Icon = "bell" })

for _, Kind in ipairs({ "Success", "Warning", "Error" }) do
    Notifications:CreateButton({
        Name = Kind,
        Callback = function()
            Library:Notify({
                Title = Kind,
                Content = "This is a " .. Kind:lower() .. " notification.",
                Type = Kind,
                Duration = 3,
            })
        end,
    })
end

local Dialogs = Popups:AddRightGroupbox({ Name = "Dialogs", Icon = "message-square" })

Dialogs:CreateButton({
    Name = "Confirm",
    Callback = function()
        Library:Confirm({
            Title = "Reset progress?",
            Content = "This cannot be undone.",
            ConfirmText = "Reset",
            CancelText = "Cancel",
            Callback = function()
                print("[Example] confirmed")
            end,
        })
    end,
})

Dialogs:CreateButton({
    Name = "Dialog",
    Callback = function()
        Library:Dialog({
            Title = "Choose a mode",
            Content = "You can change this later in Settings.",
            Buttons = {
                { Title = "Basic", Callback = function() print("[Example] basic") end },
                { Title = "Balanced", Callback = function() print("[Example] balanced") end },
                { Title = "Full", Variant = "Primary", Callback = function() print("[Example] full") end },
            },
        })
    end,
})

--------------------------------------------------------------------------------
-- New in KaitUI: segmented, textarea, player picker, graph and overlays
--------------------------------------------------------------------------------

Automation:CreateSegmented({
    Name = "Speed",
    Options = { "Slow", "Normal", "Fast" },
    CurrentOption = "Normal",
    Flag = "AutomationSpeed",
    Callback = function(Option)
        print("[Example] speed", Option)
    end,
})

-- Options too wide for the row stack under the name.
Automation:CreateSegmented({
    Name = "Priority",
    Options = { "Closest First", "Richest First", "Random" },
    CurrentOption = 1,
    Flag = "AutomationPriority",
    Callback = function(Option)
        print("[Example] priority", Option)
    end,
})

Automation:CreateTextarea({
    Name = "Notes",
    Desc = "Saved with your config",
    PlaceholderText = "Write anything...",
    Lines = 4,
    MaxLength = 300,
    Flag = "AutomationNotes",
    Callback = function(Text)
        print("[Example] notes", Text)
    end,
})

Elements:CreatePlayerPicker({
    Name = "Spectate",
    Desc = "Sorted by display name, updates as players join and leave",
    Display = "Both",
    Flag = "SpectateTarget",
    Callback = function(Player)
        print("[Example] spectate", Player and Player.Name or "none")
    end,
})

Elements:CreatePlayerPicker({
    Name = "Whitelist",
    Multi = true,
    IncludeSelf = true,
    Flag = "Whitelist",
    Callback = function(List)
        local names = {}
        for index, Player in ipairs(List) do
            names[index] = Player.DisplayName
        end
        print("[Example] whitelist", table.concat(names, ", "))
    end,
})

-- Graphs poll their Update only while their tab is showing.
do
    local frames = 0
    game:GetService("RunService").Heartbeat:Connect(function()
        frames += 1
    end)
    Elements:CreateGraph({
        Name = "Frame Rate",
        Desc = "Live, sampled twice a second",
        Suffix = " fps",
        Min = 0,
        Color = "Success",
        UpdateRate = 0.5,
        Update = function()
            local fps = frames * 2
            frames = 0
            return fps
        end,
    })
end

Elements:CreateGraph({
    Name = "Ping",
    Suffix = " ms",
    Height = 70,
    Color = "Warning",
    Fill = false, -- just the line
    Update = function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end,
})

local Watermark = Window:CreateWatermark({ Fields = { "FPS", "Ping", "Time" }, Position = "TopRight" })
local KeybindList = Window:CreateKeybindList({ Title = "Keybinds", Position = "Right", Visible = false })

local Overlays = Popups:AddRightGroupbox({ Name = "Overlays", Icon = "layers" })

local Flying = Overlays:CreateToggle({
    Name = "Fly",
    Flag = "Fly",
    Callback = function(Value)
        print("[Example] fly", Value)
    end,
})

Overlays:CreateKeybind({
    Name = "Fly",
    CurrentKeybind = "F",
    Flag = "FlyKey",
    Linked = Flying, -- F flips the toggle; the keybind list lights up while it is on
})

Overlays:CreateToggle({
    Name = "Watermark",
    CurrentValue = true,
    Callback = function(Value)
        Watermark:SetVisible(Value)
    end,
})

Overlays:CreateToggle({
    Name = "Keybind list",
    CurrentValue = false,
    Callback = function(Value)
        KeybindList:SetVisible(Value)
    end,
})

Notifications:CreateButton({
    Name = "With buttons",
    Callback = function()
        Library:Notify({
            Title = "Item sold",
            Content = "Sold 12 apples for 240 coins.",
            Icon = "coins",
            Buttons = {
                { Title = "Undo", Variant = "Primary", Callback = function() print("[Example] undo") end },
                { Title = "OK" },
            },
            Duration = 6,
        })
    end,
})

Notifications:CreateButton({
    Name = "Progress",
    Callback = function()
        local Toast = Library:Notify({ Title = "Downloading", Content = "0%", Progress = 0 })
        for Step = 1, 10 do
            task.wait(0.25)
            Toast:SetProgress(Step / 10)
            Toast:SetContent(Step * 10 .. "%")
        end
        Toast:SetTitle("Download complete")
        task.wait(1.5)
        Toast:Close()
    end,
})

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })

local Menu = Settings:AddLeftGroupbox({ Name = "Menu", Icon = "monitor" })

Menu:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightControl",
    OnChanged = function(Key)
        Window:SetKeybind(Key)
    end,
})

Menu:CreateMinimizeOnStart()

Menu:CreateDropdown({
    Name = "Toggle Button",
    Options = { "Mobile only", "Mobile & PC" },
    CurrentOption = "Mobile only",
    AllowNone = false,
    Flag = "ToggleButtonPlatform",
    Callback = function(Option)
        Window:SetToggleButtonPlatform(Option == "Mobile & PC" and "Both" or "Mobile")
    end,
})

Menu:CreateToggle({
    Name = "Backdrop",
    CurrentValue = true,
    Flag = "Backdrop",
    Callback = function(Value)
        Window:SetBackdrop(Value)
    end,
})

Menu:CreateSlider({
    Name = "Backdrop Tint",
    Range = { 0, 90 },
    Increment = 5,
    Suffix = "%",
    CurrentValue = 45,
    Flag = "BackdropTint",
    Callback = function(Value)
        Window:SetBackdropTint(Value / 100)
    end,
})

Menu:CreateButton({
    Name = "Unload",
    Icon = "power",
    Callback = function()
        Window:Close() -- same as the × in the top-right: asks, then unloads; Close(true) skips the question
    end,
})

Settings:CreateConfigManager({ Name = "Configs", Side = "Left" }) -- builds its own groupbox
Settings:CreateThemeManager({ Name = "Themes", Side = "Right" })

Window:LoadAutoload() -- loads the config marked as autoload, if any

-- A text box with an action button beside it, for naming new configs and themes.
-- Without buttonText the box spans the row on its own.
local function actionInput(tab, placeholder, buttonText, callback)
    local boxHeight = TOUCH and 34 or 30
    local frame = card(tab, "Frame", boxHeight + 4, {})
    local inset = metricsOf(tab).Compact and 14 or 7
    local box
    local button = buttonText and softButton(frame, buttonText, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -inset, 0, 2),
        Size = UDim2.fromOffset(0, boxHeight),
        AutomaticSize = Enum.AutomaticSize.X,
    }, function()
        safeCall(callback, box.Text)
    end)
    local holder = create("Frame", {
        Position = UDim2.fromOffset(inset, 2),
        Size = UDim2.new(1, -(inset * 2 + (button and 70 or 0)), 0, boxHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(holder, UDim.new(0, 6))
    local holderStroke = stroke(holder)
    box = create("TextBox", {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = holder,
    })
    box.Focused:Connect(function()
        tween(holderStroke, { Color = Theme.StrokeHover }, 0.15)
    end)
    box.FocusLost:Connect(function(enterPressed)
        tween(holderStroke, { Color = Theme.Stroke }, 0.2)
        if enterPressed and box.Text ~= "" then
            safeCall(callback, box.Text)
        end
    end)
    if button then
        local function fit()
            local width = button.AbsoluteSize.X / tab.Window.Scale.Scale
            holder.Size = UDim2.new(1, -(inset * 2 + width + 6), 0, boxHeight)
        end
        button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
        task.defer(fit)
    end
    return finishElement(tab, { Name = placeholder }, {
        Get = function()
            return box.Text
        end,
        Set = function(_, value)
            box.Text = tostring(value or "")
        end,
    }, frame, "ActionInput")
end

local function trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

-- An always-open single-pick list, for the config manager's saved configs.
-- tagsOf(name) returns short markers drawn at the row's right edge.
local function pickList(tab, names, default, rows, tagsOf, onPick, onOpen)
    local ROW = TOUCH and 30 or 24
    local listHeight = ROW * (rows or 5) + 8
    local frame = card(tab, "Frame", listHeight + 4, {})
    local inset = metricsOf(tab).Compact and 14 or 7
    local holder = create("Frame", {
        Position = UDim2.fromOffset(inset, 2),
        Size = UDim2.new(1, -inset * 2, 0, listHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(holder, UDim.new(0, 6))
    stroke(holder)
    local scroll = create("ScrollingFrame", {
        Position = UDim2.fromOffset(4, 4),
        Size = UDim2.new(1, -8, 1, -8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Stroke,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = holder,
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
    local empty = label({
        Size = UDim2.new(1, 0, 0, ROW),
        Text = "no configs yet",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = holder,
    })
    local selected, buttons = nil, {}

    local function paint(instant)
        for name, entry in pairs(buttons) do
            local on = name == selected
            tween(entry.Button, { BackgroundTransparency = on and 0.82 or 1 }, instant and 0 or 0.15)
            tween(entry.Label, { TextColor3 = on and Theme.Accent or Theme.Text }, instant and 0 or 0.15)
            entry.Bar.Visible = on
            local tags = tagsOf and tagsOf(name) or ""
            entry.Tags.Text = tags
            entry.Label.Size = UDim2.new(1, -(18 + entry.Tags.TextBounds.X + (tags ~= "" and 6 or 0)), 1, 0)
        end
    end

    local function pick(name)
        if selected == name then
            return
        end
        selected = name
        paint()
        safeCall(onPick, name)
    end

    local handle = {}
    function handle:Refresh(list)
        for _, entry in pairs(buttons) do
            entry.Button:Destroy()
        end
        buttons = {}
        for index, name in ipairs(list or {}) do
            local button = create("TextButton", {
                Size = UDim2.new(1, -4, 0, ROW),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                Parent = scroll,
            })
            corner(button, UDim.new(0, 4))
            local bar = create("Frame", {
                Position = UDim2.new(0, 0, 0.5, -6),
                Size = UDim2.fromOffset(2, 12),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Visible = false,
                Parent = button,
            })
            local text = label({
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -18, 1, 0),
                Text = name,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = button,
            })
            local tags = label({
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 0),
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = button,
            })
            local lastClick = 0
            button.MouseButton1Click:Connect(function()
                -- A second click on the picked row loads it.
                if selected == name and os.clock() - lastClick < 0.35 then
                    lastClick = 0
                    safeCall(onOpen, name)
                    return
                end
                lastClick = os.clock()
                pick(name)
            end)
            button.MouseEnter:Connect(function()
                if selected ~= name then
                    tween(button, { BackgroundTransparency = 0.93 }, 0.1)
                end
            end)
            button.MouseLeave:Connect(function()
                if selected ~= name then
                    tween(button, { BackgroundTransparency = 1 }, 0.15)
                end
            end)
            buttons[name] = { Button = button, Label = text, Tags = tags, Bar = bar }
        end
        if selected and not buttons[selected] then
            pick(nil)
        end
        empty.Visible = next(buttons) == nil
        paint(true)
    end
    function handle:Get()
        return selected
    end
    function handle:Set(name)
        pick(name and buttons[name] and name or nil)
    end
    function handle:Repaint()
        paint(true)
    end
    handle:Refresh(names)
    handle:Set(default)
    return finishElement(tab, { Name = "Configs" }, handle, frame, "PickList")
end

-- Managers go in their own groupbox when added straight to a tab.
local function managerHost(tab, opts, name, icon)
    if tab._groupbox then
        return tab
    end
    local host = tab:Groupbox({ Name = opts.Name or name, Icon = opts.Icon or icon, Side = opts.Side })
    -- Library chrome, not a script feature: the feature list skips it.
    host._manager = true
    return host
end

function Tab:ConfigManager(opts)
    opts = normalize(opts, { Title = "Name" })
    local host = managerHost(self, opts, "Configs", "folder")
    local window = self.Window
    local manager = {}
    local list, status, modeList

    local function notify(ok, title, detail)
        window:Notify({ Title = title, Content = detail, Type = ok and "Success" or "Error", Duration = 3 })
    end

    local autoToggle
    local function refreshStatus()
        if not status then
            return
        end
        local count = #window:ListConfigs()
        status:Set(("%d saved  ·  loaded: %s  ·  auto: %s"):format(count, window.LoadedConfig or "none", window:GetAutoload() or "none"))
        list:Repaint()
        if autoToggle then
            local picked = list:Get()
            autoToggle:Set(picked ~= nil and window:GetAutoload() == picked, true)
        end
    end

    local function pickedName()
        local name = list:Get()
        if not name then
            notify(false, "No config selected", "Pick one from the list first")
        end
        return name
    end

    local names = window:ListConfigs()
    local initial = window.LoadedConfig or window:GetAutoload()
    local nameInput
    list = pickList(host, names, table.find(names, initial) and initial or nil, opts.Rows, function(name)
        local tags = {}
        if name == window.LoadedConfig then
            table.insert(tags, "loaded")
        end
        if name == window:GetAutoload() then
            table.insert(tags, "auto")
        end
        return table.concat(tags, " · ")
    end, function(name)
        if nameInput then
            nameInput:Set(name or "")
        end
        refreshStatus()
    end, function(name)
        manager:Load(name)
    end)
    status = host:Label("0 saved")
    host:Label("Config Name:")
    nameInput = actionInput(host, opts.Placeholder or "Type config name here...", nil, function(text)
        manager:Create(text)
    end)
    host:ButtonRow({
        { Name = "Save", Callback = function() manager:Save() end },
        { Name = "Load", Callback = function() manager:Load() end },
    })
    host:ButtonRow({
        { Name = "Delete", Style = "Danger", Callback = function() manager:Delete() end },
        { Name = "Refresh", Callback = function() manager:Refresh() end },
    })
    autoToggle = host:Toggle({
        Name = "Auto Load Config",
        Desc = "Loads the selected config on launch",
        Callback = function(value)
            local picked = list:Get()
            if not picked then
                notify(false, "No config selected", "Pick one from the list first")
            elseif value ~= (window:GetAutoload() == picked) then
                if value then
                    manager:SetAutoload(picked)
                else
                    manager:ClearAutoload()
                end
            end
            refreshStatus()
        end,
    })
    host:Divider({ Text = "more" })
    host:ButtonRow({
        { Name = "Rename", Callback = function() manager:Rename(nil, nameInput:Get()) end },
        { Name = "Reset", Style = "Danger", Callback = function() manager:Reset() end },
    })
    modeList = host:Dropdown({
        Name = "Autoload mode",
        Stacked = true,
        Options = { "All accounts", "This account" },
        Default = window:GetAutoloadMode() == "Account" and "This account" or "All accounts",
        AllowNone = false,
        Callback = function(choice)
            manager:SetAutoloadMode(choice == "This account" and "Account" or "Global")
        end,
    })
    host:Divider({ Text = "share" })
    host:Button({ Name = "Copy code", Callback = function() manager:Export() end })
    local codeInput = actionInput(host, "paste a config code...", nil, function(text)
        manager:Import(text)
    end)
    host:Button({ Name = "Import code", Callback = function() manager:Import(codeInput:Get()) end })

    function manager:Refresh()
        local names = window:ListConfigs()
        local keep = list:Get()
        list:Refresh(names, true)
        if keep and not table.find(names, keep) then
            list:Set(window.LoadedConfig and table.find(names, window.LoadedConfig) and window.LoadedConfig or nil, true)
        end
        refreshStatus()
    end

    local function select(name)
        manager:Refresh()
        list:Set(name, true)
    end

    function manager:Create(name)
        name = trim(name)
        if name == "" then
            notify(false, "Name the config", "Type a name before creating it")
            return
        end
        if not validConfigName(name) then
            notify(false, "Invalid name", 'Names cannot contain \\ / : * ? " < > |')
            return
        end
        local ok, err = window:SaveConfig(name)
        if ok then
            window.LoadedConfig = name
            nameInput:Set("")
            select(name)
        end
        notify(ok, ok and "Config created" or "Create failed", ok and name or tostring(err))
    end

    function manager:Save(name)
        local typed = trim(nameInput:Get())
        if not name and typed ~= "" and typed ~= list:Get() then
            return manager:Create(typed)
        end
        name = name or list:Get()
        if not name then
            local typed = trim(nameInput:Get())
            if typed == "" then
                notify(false, "No config selected", "Pick one from the list or type a name")
                return
            end
            return manager:Create(typed)
        end
        local ok, err = window:SaveConfig(name)
        if ok then
            window.LoadedConfig = name
            refreshStatus()
        end
        notify(ok, ok and "Config saved" or "Save failed", ok and name or tostring(err))
    end

    function manager:Load(name)
        name = name or pickedName()
        if not name then
            return
        end
        local ok, err = window:LoadConfig(name)
        refreshStatus()
        notify(ok, ok and "Config loaded" or "Load failed", ok and name or tostring(err))
    end

    function manager:Delete(name)
        name = name or pickedName()
        if not name then
            return
        end
        window:Confirm({
            Title = "Delete config",
            Content = "Remove " .. name .. "? This cannot be undone.",
            Icon = "trash-2",
            ConfirmText = "Delete",
            Callback = function()
                local ok, err = window:DeleteConfig(name)
                if ok then
                    if window:GetAutoload("Account") == name then
                        window:SetAutoload(nil, "Account")
                    end
                    if window:GetAutoload("Global") == name then
                        window:SetAutoload(nil, "Global")
                    end
                    list:Set(nil, true)
                end
                manager:Refresh()
                notify(ok, ok and "Config deleted" or "Delete failed", ok and name or tostring(err))
            end,
        })
    end

    function manager:Rename(name, newName)
        name = name or pickedName()
        if not name then
            return
        end
        newName = trim(newName)
        if newName == "" then
            notify(false, "Name the config", "Type the new name in the name box")
            return
        end
        if not validConfigName(newName) then
            notify(false, "Invalid name", 'Names cannot contain \\ / : * ? " < > |')
            return
        end
        local ok, err = window:RenameConfig(name, newName)
        if ok then
            nameInput:Set("")
            select(newName)
        end
        notify(ok, ok and "Config renamed" or "Rename failed", ok and (name .. " -> " .. newName) or tostring(err))
    end

    function manager:Reset()
        window:Confirm({
            Title = "Reset settings",
            Content = "Put every setting back to its default and delete this script's folder? Saved configs, themes and autoload are removed for good.",
            Icon = "rotate-ccw",
            ConfirmText = "Reset",
            Callback = function()
                window:ResetConfig()
                local wiped = window:ClearWorkspace()
                window:_applyDefaultTheme()
                list:Set(nil, true)
                manager:Refresh()
                modeList:Set("All accounts", true)
                notify(wiped, wiped and "Settings reset" or "Reset incomplete",
                    wiped and "Everything is back to its default" or "Some files in " .. window.ConfigFolder .. " could not be deleted")
            end,
        })
    end

    function manager:SetAutoload(name)
        name = name or pickedName()
        if not name then
            return
        end
        local ok, err = window:SetAutoload(name)
        refreshStatus()
        notify(ok, ok and "Autoload set" or "Autoload failed", ok and name or tostring(err))
    end

    function manager:ClearAutoload()
        local current = window:GetAutoload()
        if not current then
            notify(false, "No autoload", "Nothing is set to autoload")
            return
        end
        local ok, err = window:SetAutoload(nil)
        refreshStatus()
        notify(ok, ok and "Autoload cleared" or "Clear failed", ok and current or tostring(err))
    end

    function manager:ToggleAutoload(name)
        name = name or pickedName()
        if not name then
            return
        end
        if window:GetAutoload() == name then
            manager:ClearAutoload()
        else
            manager:SetAutoload(name)
        end
    end

    function manager:SetAutoloadMode(mode)
        local ok, err = window:SetAutoloadMode(mode)
        local label_ = mode == "Account" and "This account" or "All accounts"
        if modeList:Get() ~= label_ then
            modeList:Set(label_, true)
        end
        notify(ok ~= false, ok ~= false and "Autoload mode" or "Mode change failed", ok ~= false and label_ or tostring(err))
    end

    function manager:Export(name)
        local code, err = window:ExportConfig(name)
        if not code then
            notify(false, "Export failed", tostring(err))
            return nil
        end
        window:CopyToClipboard(code, "Config code")
        return code
    end

    function manager:Import(code)
        code = trim(code)
        if code == "" then
            notify(false, "Nothing to import", "Paste a config code first")
            return
        end
        local data, info = window:DecodeConfig(code)
        if not data then
            notify(false, "Import failed", "Invalid config code")
            return
        end
        -- The typed name wins; otherwise the code's own name, never overwriting a config.
        local saveAs = trim(nameInput:Get())
        local typedName = saveAs ~= ""
        if saveAs == "" then
            saveAs = nil
            if validConfigName(info.Name) then
                saveAs = info.Name
                local index = 2
                while window:ConfigExists(saveAs) do
                    saveAs = ("%s (%d)"):format(info.Name, index)
                    index += 1
                end
            end
        elseif not validConfigName(saveAs) then
            notify(false, "Invalid name", 'Names cannot contain \\ / : * ? " < > |')
            return
        end
        local function run()
            local ok, err = window:ImportConfig(code, saveAs, true)
            if ok then
                codeInput:Set("")
                if saveAs then
                    nameInput:Set("")
                    select(saveAs)
                end
            end
            notify(ok, ok and "Config imported" or "Import failed", ok and (saveAs or "Applied to current settings") or tostring(err))
        end
        -- Picking a config fills the name box, so a typed name that exists is asked about first.
        local function checkOverwrite()
            if typedName and window:ConfigExists(saveAs) then
                window:Confirm({
                    Title = "Overwrite config?",
                    Content = ("%s already exists. Replace it with the imported settings?"):format(saveAs),
                    Icon = "triangle-alert",
                    ConfirmText = "Overwrite",
                    Callback = run,
                })
                return
            end
            run()
        end
        if info.Folder and info.Folder ~= window.ConfigFolder then
            window:Confirm({
                Title = "Different script",
                Content = ("This config was made for %s. Import it anyway? Only matching settings are applied."):format(info.Folder),
                Icon = "triangle-alert",
                ConfirmText = "Import",
                -- Deferred so the next confirm opens after this one has closed.
                Callback = function()
                    task.defer(checkOverwrite)
                end,
            })
            return
        end
        checkOverwrite()
    end

    local disconnect = window:OnConfigChanged(function()
        -- Configs can arrive from elsewhere, so the list is reread.
        manager:Refresh()
        if window.LoadedConfig and list:Get() == nil then
            list:Set(window.LoadedConfig, true)
        end
    end)
    status._listeners = status._listeners or {}
    table.insert(status._listeners, disconnect)

    refreshStatus()
    return manager
end

local PRESET_ORDER = {
    "KaitUI", "Midnight", "Nebula", "Synthwave", "Sakura", "Velvet", "Rose", "Crimson", "Sunset", "Amber", "Gold",
    "Cyber", "Toxic", "Matcha", "Emerald", "Aurora", "Ocean", "Frost", "Abyss", "Mono",
    "Halloween", "Haunted", "Christmas", "Valentine", "Lunar", "Tropical", "Dracula", "Coffee",
}


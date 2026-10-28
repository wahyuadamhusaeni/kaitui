-- Floating overlays that live in the window's ScreenGui beside the window, so
-- they stay up while it is hidden or minimized: a watermark pill and a list of
-- keybinds. Both drag with mouse or touch, stay on screen and follow the UI scale.

-- Places an overlay at a named corner or edge. Dragging switches it to a plain
-- offset position (AnchorPoint zero) that is kept on screen.
function Window:_placeOverlay(frame, where)
    local inset = GuiService:GetGuiInset()
    local top = inset.Y + 8
    local spots = {
        TopLeft = { Vector2.new(0, 0), UDim2.new(0, 12, 0, top) },
        TopRight = { Vector2.new(1, 0), UDim2.new(1, -12, 0, top) },
        BottomLeft = { Vector2.new(0, 1), UDim2.new(0, 12, 1, -12) },
        BottomRight = { Vector2.new(1, 1), UDim2.new(1, -12, 1, -12) },
        Left = { Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0) },
        Right = { Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0) },
    }
    local spot = spots[where] or spots.TopLeft
    frame.AnchorPoint = spot[1]
    frame.Position = spot[2]
end

function Window:_clampOverlay(frame)
    local gui = self.Gui
    if not frame.Parent or frame.AnchorPoint ~= Vector2.zero then
        return
    end
    local viewport = gui.AbsoluteSize
    local position = frame.AbsolutePosition - gui.AbsolutePosition
    frame.Position = UDim2.fromOffset(
        math.clamp(position.X, 0, math.max(viewport.X - frame.AbsoluteSize.X, 0)),
        math.clamp(position.Y, 0, math.max(viewport.Y - frame.AbsoluteSize.Y, 0))
    )
end

-- Shared setup: UI scale, dragging, clamping on screen size changes and the
-- common handle methods. handle._listeners is cleared by handle:Destroy.
function Window:_setupOverlay(handle, frame, slot)
    local gui = self.Gui
    handle._listeners = handle._listeners or {}
    handle._frameObject = frame
    handle._scale = create("UIScale", { Scale = self._uiScale or 1, Parent = frame })

    local dragging = false
    local grab = Vector2.zero
    frame.InputBegan:Connect(function(input)
        if handle.Draggable and isPress(input) then
            dragging = true
            grab = pointerPosition() - frame.AbsolutePosition
        end
    end)
    self:_listen("Changed", function(input)
        if not dragging or not isMove(input) then
            return
        end
        local point = pointerPosition() - grab - gui.AbsolutePosition
        frame.AnchorPoint = Vector2.zero
        frame.Position = UDim2.fromOffset(
            math.clamp(point.X, 0, math.max(gui.AbsoluteSize.X - frame.AbsoluteSize.X, 0)),
            math.clamp(point.Y, 0, math.max(gui.AbsoluteSize.Y - frame.AbsoluteSize.Y, 0))
        )
    end, handle)
    self:_listen("Ended", function(input)
        if dragging and isPress(input) then
            dragging = false
        end
    end, handle)

    -- Back on screen when the screen shrinks, and when the overlay itself grows
    -- (more fields, more keybinds, a bigger UI scale) after being dragged.
    local function reclamp()
        task.defer(function()
            if not handle._destroyed then
                self:_clampOverlay(frame)
            end
        end)
    end
    handle._sizeConnection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(reclamp)
    table.insert(self._connections, handle._sizeConnection)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(reclamp)

    -- Called from the overlay's own refresh tick, so no extra connection.
    function handle._syncScale()
        local wanted = self._uiScale or 1
        if handle._scale.Scale ~= wanted then
            handle._scale.Scale = wanted
        end
    end
    function handle:SetVisible(visible)
        if handle._destroyed then
            return
        end
        handle._visible = visible ~= false
        frame.Visible = handle._visible
        if handle._visible and handle._refresh then
            handle._refresh()
        end
    end
    function handle:IsVisible()
        return handle._visible == true and not handle._destroyed
    end
    -- Inside handle methods `self` is the handle, so they close over the window.
    local window = self
    function handle:SetPosition(where)
        if not handle._destroyed then
            window:_placeOverlay(frame, where)
        end
    end
    function handle:SetDraggable(enabled)
        handle.Draggable = enabled ~= false
    end
    function handle:Destroy()
        if handle._destroyed then
            return
        end
        handle._destroyed = true
        for _, disconnect in ipairs(handle._listeners) do
            disconnect()
        end
        handle._listeners = {}
        pcall(function()
            handle._sizeConnection:Disconnect()
        end)
        local at = table.find(window._connections, handle._sizeConnection)
        if at then
            table.remove(window._connections, at)
        end
        frame:Destroy()
        if window[slot] == handle then
            window[slot] = nil
        end
    end
end

function Window:_pingMs()
    local ok, ping = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if not ok or type(ping) ~= "number" then
        ok, ping = pcall(function()
            return LocalPlayer:GetNetworkPing() * 1000
        end)
    end
    return (ok and type(ping) == "number") and math.floor(ping + 0.5) or 0
end

-- Watermark: a small pill with the script name and live stats.
function Window:CreateWatermark(opts)
    if type(opts) == "string" then
        opts = { Text = opts }
    end
    opts = type(opts) == "table" and opts or {}
    local existing = self._watermark
    if existing and not existing._destroyed then
        if opts.Text ~= nil then
            existing:SetText(opts.Text)
        end
        if opts.Fields ~= nil then
            existing:SetFields(opts.Fields)
        end
        if opts.Position ~= nil then
            existing:SetPosition(opts.Position)
        end
        if opts.Draggable ~= nil then
            existing:SetDraggable(opts.Draggable)
        end
        if opts.Visible ~= nil then
            existing:SetVisible(opts.Visible)
        end
        return existing
    end

    local handle = {
        Draggable = opts.Draggable ~= false,
        _visible = opts.Visible ~= false,
        _text = opts.Text ~= nil and tostring(opts.Text) or self.Title,
        _fields = type(opts.Fields) == "table" and opts.Fields or { "FPS", "Ping", "Time" },
        _fps = 0,
    }
    local pill = create("TextButton", {
        Name = "Watermark",
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Selectable = false,
        Visible = handle._visible,
        ZIndex = 25,
        Parent = self.Gui,
    })
    corner(pill, UDim.new(0, 8))
    stroke(pill, Theme.Stroke)
    padding(pill, 10, 12)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        Parent = pill,
    })
    local dot = create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 26,
        Parent = pill,
    })
    corner(dot, UDim.new(1, 0))
    local titleLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = handle._text,
        TextSize = 13,
        FontFace = Fonts.Bold,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        ZIndex = 26,
        Parent = pill,
    })
    local divider = create("Frame", {
        Size = UDim2.fromOffset(1, 12),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        ZIndex = 26,
        Parent = pill,
    })
    local statsLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        TextSize = 13,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 4,
        ZIndex = 26,
        Parent = pill,
    })
    self:_placeOverlay(pill, opts.Position or "TopLeft")
    self:_setupOverlay(handle, pill, "_watermark")
    self._watermark = handle

    local window = self
    function handle._refresh()
        if handle._destroyed then
            return
        end
        local parts = {}
        for _, field in ipairs(handle._fields) do
            if type(field) == "function" then
                local ok, value = pcall(field)
                if ok and value ~= nil then
                    table.insert(parts, tostring(value))
                end
            else
                local name = string.lower(tostring(field))
                if name == "fps" then
                    table.insert(parts, handle._fps .. " fps")
                elseif name == "ping" then
                    table.insert(parts, window:_pingMs() .. " ms")
                elseif name == "time" then
                    table.insert(parts, os.date("%H:%M"))
                else
                    table.insert(parts, tostring(field))
                end
            end
        end
        statsLabel.Text = table.concat(parts, "  |  ")
        statsLabel.Visible = #parts > 0
        divider.Visible = #parts > 0
        handle._syncScale()
    end
    function handle:SetText(text)
        if handle._destroyed then
            return
        end
        handle._text = text == nil and window.Title or tostring(text)
        titleLabel.Text = handle._text
    end
    function handle:SetFields(fields)
        if handle._destroyed then
            return
        end
        handle._fields = type(fields) == "table" and fields or {}
        handle._refresh()
    end

    -- Frames are counted every render step; the text changes twice a second.
    local frames, elapsed = 0, 0
    self:_listen("Render", function(deltaTime)
        frames += 1
        elapsed += deltaTime
        if elapsed >= 0.5 then
            handle._fps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
            if handle._visible then
                handle._refresh()
            end
        end
    end, handle)
    handle._refresh()
    return handle
end

-- Keybind list: keybind elements of this window with their keys. Entries
-- with a Linked toggle light up while that toggle is on.
function Window:CreateKeybindList(opts)
    opts = type(opts) == "table" and opts or {}
    local existing = self._keybindList
    if existing and not existing._destroyed then
        if opts.Title ~= nil then
            existing:SetTitle(opts.Title)
        end
        if opts.ShowAll ~= nil then
            existing.ShowAll = opts.ShowAll == true
            existing._refresh()
        end
        if opts.Position ~= nil then
            existing:SetPosition(opts.Position)
        end
        if opts.Draggable ~= nil then
            existing:SetDraggable(opts.Draggable)
        end
        if opts.Visible ~= nil then
            existing:SetVisible(opts.Visible)
        end
        return existing
    end

    local handle = {
        Draggable = opts.Draggable ~= false,
        ShowAll = opts.ShowAll == true,
        _visible = opts.Visible ~= false,
    }
    local panel = create("Frame", {
        Name = "KeybindList",
        Size = UDim2.fromOffset(200, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Active = true,
        Visible = handle._visible,
        ZIndex = 25,
        Parent = self.Gui,
    })
    corner(panel, UDim.new(0, 8))
    stroke(panel, Theme.Stroke)
    padding(panel, 12, 12, 10, 10)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = panel,
    })
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        ZIndex = 26,
        Parent = panel,
    })
    local headerIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 26,
        Parent = header,
    })
    applyIcon(headerIcon, "keyboard")
    local titleLabel = label({
        Position = UDim2.fromOffset(22, 0),
        Size = UDim2.new(1, -22, 1, 0),
        Text = tostring(opts.Title or "Keybinds"),
        TextSize = 13,
        FontFace = Fonts.Bold,
        ZIndex = 26,
        Parent = header,
    })
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 26,
        Parent = panel,
    })
    local rows = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        ZIndex = 26,
        Parent = panel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = rows,
    })
    self:_placeOverlay(panel, opts.Position == "Left" and "Left" or (opts.Position or "Right"))
    self:_setupOverlay(handle, panel, "_keybindList")
    self._keybindList = handle

    local window = self
    local signature = nil
    function handle._refresh()
        if handle._destroyed then
            return
        end
        handle._syncScale()
        -- Drop destroyed keybinds from the window's list as well.
        local live, entries, keys = {}, {}, {}
        for _, element in ipairs(window._keybindElements or {}) do
            if not element._destroyed then
                table.insert(live, element)
                if handle.ShowAll or element.Value ~= nil then
                    local linked = element.Linked
                    local active = type(linked) == "table" and not linked._destroyed and linked.Value == true
                    local name = tostring(element.Name or "Keybind")
                    local key = keyName(element.Value)
                    table.insert(entries, { Name = name, Key = key, Active = active })
                    table.insert(keys, name .. "\0" .. key .. "\0" .. tostring(active))
                end
            end
        end
        window._keybindElements = live
        local nextSignature = table.concat(keys, "\1")
        if nextSignature == signature then
            return
        end
        signature = nextSignature
        for _, child in ipairs(rows:GetChildren()) do
            if not child:IsA("UIListLayout") then
                child:Destroy()
            end
        end
        if #entries == 0 then
            label({
                Size = UDim2.new(1, 0, 0, 18),
                Text = "No keybinds",
                TextSize = 12,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                ZIndex = 26,
                Parent = rows,
            })
            return
        end
        for index, entry in ipairs(entries) do
            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                LayoutOrder = index,
                ZIndex = 26,
                Parent = rows,
            })
            local keyLabel = label({
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Text = "[" .. entry.Key .. "]",
                TextSize = 12,
                TextColor3 = entry.Active and Theme.Accent or Theme.Muted,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.None,
                ZIndex = 26,
                Parent = row,
            })
            local nameLabel = label({
                Size = UDim2.new(1, -64, 1, 0),
                Text = entry.Name,
                TextSize = 12,
                FontFace = entry.Active and Fonts.Medium or Fonts.Regular,
                TextColor3 = entry.Active and Theme.Accent or Theme.Text,
                ZIndex = 26,
                Parent = row,
            })
            -- Long key names ([KeypadEight]) take more room: the name gives way.
            local function fitName()
                nameLabel.Size = UDim2.new(1, -(keyLabel.TextBounds.X + 10), 1, 0)
            end
            keyLabel:GetPropertyChangedSignal("TextBounds"):Connect(fitName)
            fitName()
        end
    end
    function handle:SetTitle(text)
        if not handle._destroyed then
            titleLabel.Text = tostring(text == nil and "Keybinds" or text)
        end
    end
    function handle:SetShowAll(enabled)
        handle.ShowAll = enabled == true
        handle._refresh()
    end

    -- Polled four times a second: keys, destroyed keybinds and linked toggles.
    local elapsed = 0
    self:_listen("Render", function(deltaTime)
        elapsed += deltaTime
        if elapsed >= 0.25 then
            elapsed = 0
            if handle._visible then
                handle._refresh()
            end
        end
    end, handle)
    handle._refresh()
    return handle
end

-- The morph is carried by a plain "ghost" panel drawn over the window. The
-- window body itself never moves or fades, so nothing has to be laid out
-- again mid-animation: the ghost covers it, the window is hidden underneath,
-- and on the way back the window is shown under the ghost before it clears.
local function makeGhost(window, position, size, radius)
    if window._ghost then
        window._ghost:Destroy()
    end
    local ghost = create("Frame", {
        Position = UDim2.fromOffset(position.X, position.Y),
        Size = UDim2.fromOffset(size.X, size.Y),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 29,
        Parent = window.Gui,
    })
    local ghostCorner = Library._fixedCorner(ghost, UDim.new(0, radius))
    local ghostStroke = stroke(ghost, Theme.Stroke, 1)
    window._ghost = ghost
    return ghost, ghostStroke, ghostCorner
end

local function morphGhost(ghost, ghostCorner, position, size, radius, duration)
    tween(ghost, {
        Position = UDim2.fromOffset(position.X, position.Y),
        Size = UDim2.fromOffset(size.X, size.Y),
    }, duration, Enum.EasingStyle.Quint)
    tween(ghostCorner, { CornerRadius = UDim.new(0, radius) }, duration, Enum.EasingStyle.Quint)
end

local function dissolve(window, ghost, ghostStroke, duration)
    tween(ghost, { BackgroundTransparency = 1 }, duration, Enum.EasingStyle.Quad)
    tween(ghostStroke, { Transparency = 1 }, duration, Enum.EasingStyle.Quad)
    task.delay(duration + 0.02, function()
        if window._ghost == ghost then
            window._ghost = nil
        end
        ghost:Destroy()
    end)
end

function Window:_buildMiniBar()
    if self.MiniBar then
        return self.MiniBar
    end
    local gui = self.Gui

    -- The island itself: a themed pill hanging from the top of the screen. It
    -- is a canvas so its rounded shape clips whatever layer is showing.
    local island = create("CanvasGroup", {
        Name = "Island",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, Mini.Top),
        Size = UDim2.fromOffset(Mini.Width, Mini.Height),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = 30,
        Parent = gui,
    })
    local islandCorner = Library._fixedCorner(island, UDim.new(0, Mini.Height / 2))
    local islandScale = create("UIScale", { Parent = island })
    self._miniScale = islandScale
    -- How far the split bubble is out of the pill: drawn back in while the
    -- island is open, budded off again once it settles to the pill.
    local merge = create("NumberValue", { Value = 1 })
    local mergeTween
    self._miniOrb = island

    -- The wide layers keep a fixed width, so nothing reflows while the island
    -- grows around them.
    local function layer(name)
        return create("CanvasGroup", {
            Name = name,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(0, Mini.Wide, 0, 400),
            BackgroundTransparency = 1,
            GroupTransparency = 1,
            Parent = island,
        })
    end

    -- Compact: the logo leading, a live meter of running toggles trailing.
    -- A raised theme surface, lit from the top, so the pill isn't a flat
    -- slab; it fades with the layer, leaving the open card on Background.
    local compact = create("CanvasGroup", {
        Name = "Compact",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Parent = island,
    })
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 120)),
        Parent = compact,
    })
    -- The logo sits in a soft accent disc, like an app glyph.
    local logoDisc = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.fromOffset(Mini.Height - 10, Mini.Height - 10),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        Parent = compact,
    })
    corner(logoDisc, UDim.new(1, 0))
    local logo = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        Parent = logoDisc,
    })
    applyIcon(logo, self._logoIcon, true)
    -- The script's name beside the logo, so the pill reads at a glance.
    local miniTitle = label({
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, Mini.Height + 2, 0.5, 0),
        Size = UDim2.new(1, -Mini.Height - 2 - 72, 0, 18),
        Text = self.Title,
        TextSize = 13,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Text,
        Parent = compact,
    })
    local meter = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Parent = compact,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
        Parent = meter,
    })
    local barsHolder = create("Frame", {
        Size = UDim2.fromOffset(Mini.Bars * 3 + (Mini.Bars - 1) * 2, 16),
        BackgroundTransparency = 1,
        Visible = false,
        LayoutOrder = 1,
        Parent = meter,
    })
    local bars = {}
    for index = 1, Mini.Bars do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, (index - 1) * 5, 0.5, 0),
            Size = UDim2.fromOffset(3, 3),
            BackgroundColor3 = Theme.Muted,
            BorderSizePixel = 0,
            Parent = barsHolder,
        })
        corner(bar, UDim.new(1, 0))
        bars[index] = bar
    end
    local countLabel = label({
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        TextSize = 13,
        FontFace = Fonts.Bold,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        LayoutOrder = 2,
        Parent = meter,
    })
    -- Idle (nothing running): a health dot tinted by frame rate and the
    -- session clock, so the pill never sits empty.
    local idleDot = create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        LayoutOrder = -1,
        Parent = meter,
    })
    corner(idleDot, UDim.new(1, 0))
    local idleLabel = label({
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "0s",
        TextSize = 12,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 0,
        Parent = meter,
    })

    -- Expanded, on hover: the player's session.
    local expanded = layer("Expanded")
    local expandedList = create("Frame", {
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = expanded,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = expandedList,
    })
    -- The open card is the player's session, like a now-playing card: who
    -- and where on top with the session clock, two wide meters for frame
    -- rate and ping, then chips for the server and what's running.
    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = expandedList,
    })
    local face = create("ImageLabel", {
        Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150",
        Parent = top,
    })
    corner(face, UDim.new(0, 12))
    local facePlaceholder = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Parent = face,
    })
    applyIcon(facePlaceholder, "user")
    self:_trackAvatar(face, facePlaceholder)
    local nameLabel = label({
        Position = UDim2.fromOffset(60, 5),
        Size = UDim2.new(1, -150, 0, 20),
        TextSize = 15,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Text,
        Parent = top,
    })
    self:_trackName(nameLabel, "Display")
    local tabLabel = label({
        Position = UDim2.fromOffset(60, 26),
        Size = UDim2.new(1, -150, 0, 15),
        Text = "",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = top,
    })
    task.spawn(function()
        tabLabel.Text = detectGameName()
    end)
    local sessionLabel = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 3),
        Size = UDim2.fromOffset(90, 24),
        Text = "0s",
        TextSize = 20,
        FontFace = Fonts.Bold,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = top,
    })
    label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 27),
        Size = UDim2.fromOffset(90, 14),
        Text = "session",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = top,
    })

    -- Two readouts: a large number with its unit, a caption, and a thin
    -- line under them that fills and tints with how healthy it is.
    local meters = create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = expandedList,
    })
    local function meterPill(position, caption)
        local cell = create("Frame", {
            Position = position,
            Size = UDim2.new(0.5, -10, 1, 0),
            BackgroundTransparency = 1,
            Parent = meters,
        })
        local value = label({
            Size = UDim2.new(1, -70, 0, 24),
            Text = "",
            TextSize = 20,
            FontFace = Fonts.Bold,
            TextColor3 = Theme.Text,
            RichText = true,
            Parent = cell,
        })
        label({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 6),
            Size = UDim2.fromOffset(70, 14),
            Text = caption,
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = cell,
        })
        local track = create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -4),
            Size = UDim2.new(1, 0, 0, 3),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            Parent = cell,
        })
        corner(track, UDim.new(1, 0))
        local fill = create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Success,
            BorderSizePixel = 0,
            Parent = track,
        })
        corner(fill, UDim.new(1, 0))
        return fill, value
    end
    local fpsFill, fpsValue = meterPill(UDim2.fromScale(0, 0), "FRAME RATE")
    local pingFill, pingValue = meterPill(UDim2.new(0.5, 10, 0, 0), "PING")

    -- Chips: a muted name and a bold value, the running count in accent.
    local chips = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = expandedList,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = chips,
    })
    local function chipOf(order, name, color)
        local chipFrame = create("Frame", {
            Size = UDim2.fromOffset(0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            LayoutOrder = order,
            Parent = chips,
        })
        corner(chipFrame, UDim.new(1, 0))
        padding(chipFrame, 14, 14)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 7),
            Parent = chipFrame,
        })
        label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = name,
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            LayoutOrder = 1,
            Parent = chipFrame,
        })
        return label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "",
            TextSize = 12,
            FontFace = Fonts.Bold,
            TextColor3 = color or Theme.Text,
            TextTruncate = Enum.TextTruncate.None,
            LayoutOrder = 2,
            Parent = chipFrame,
        })
    end
    local playersValue = chipOf(1, "Players")
    local bigCount = chipOf(2, "Running", Theme.Accent)
    local tabValue = chipOf(3, "Tab")

    -- Pinned statuses are no longer shown here; the holder stays so the
    -- refresh below has somewhere to keep its rows.
    local rowsHolder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        LayoutOrder = 4,
        Parent = expandedList,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = rowsHolder,
    })
    -- What's running, by name, so the count above has something behind it.
    local runningNames = label({
        Size = UDim2.new(1, 0, 0, 15),
        Text = "",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        RichText = true,
        Visible = false,
        LayoutOrder = 4,
        Parent = expandedList,
    })
    local hint = label({
        Size = UDim2.new(1, 0, 0, 14),
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        LayoutOrder = 5,
        Parent = expandedList,
    })

    -- Frame rate is counted every frame; the card's values refresh twice a
    -- second while it's open.
    local sessionStart = self._sessionStart or os.clock()
    local frames, frameClock, fps = 0, os.clock(), 60
    self:_listen("Render", function()
        frames += 1
        local now = os.clock()
        if now - frameClock >= 0.5 then
            fps = math.floor(frames / (now - frameClock) + 0.5)
            frames, frameClock = 0, now
        end
    end)
    local function refreshSession()
        sessionLabel.Text = formatDuration(os.clock() - sessionStart)
        idleLabel.Text = sessionLabel.Text
        tween(idleDot, { BackgroundColor3 = Library._healthColor(fps, 50, 30) }, 0.4)
        local unit = '<font size="12" color="#8A8A93"> %s</font>'
        fpsValue.Text = fps .. string.format(unit, "fps")
        tween(fpsFill, {
            Size = UDim2.fromScale(math.clamp(fps / 60, 0.05, 1), 1),
            BackgroundColor3 = Library._healthColor(fps, 50, 30),
        }, 0.4, Enum.EasingStyle.Quint)
        local ping = self:_pingMs()
        pingValue.Text = ping .. string.format(unit, "ms")
        -- Lower ping fills more: 60ms or less is full, 600ms and up is low.
        tween(pingFill, {
            Size = UDim2.fromScale(math.clamp(1 - (ping - 60) / 540, 0.05, 1), 1),
            BackgroundColor3 = Library._healthColor(ping, 150, 300, true),
        }, 0.4, Enum.EasingStyle.Quint)
        playersValue.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        local tab = self.CurrentTab
        tabValue.Text = tab and tab.Name or "-"
    end
    task.spawn(function()
        while island.Parent do
            if island.Visible and self.Minimized then
                refreshSession()
            end
            task.wait(0.5)
        end
    end)

    -- Activity: a notification that arrives while minimized drops in here.
    local activity = layer("Activity")
    local activityList = create("Frame", {
        Position = UDim2.fromOffset(16, 13),
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = activity,
    })
    local activityChip = create("Frame", {
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Parent = activityList,
    })
    corner(activityChip, UDim.new(1, 0))
    local activityIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(17, 17),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        Parent = activityChip,
    })
    local activityText = create("Frame", {
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.new(1, -46, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = activityList,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = activityText,
    })
    local activityTitle = label({
        Size = UDim2.new(1, 0, 0, 18),
        TextSize = 14,
        FontFace = Fonts.Bold,
        LayoutOrder = 1,
        Parent = activityText,
    })
    local activityBody = label({
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        MaxVisibleGraphemes = 140,
        LayoutOrder = 2,
        Parent = activityText,
    })

    local hit = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 10,
        Parent = island,
    })

    -- Morphing between shapes: the island springs to its new size while the
    -- old layer fades out and the new one fades in just behind it.
    local layers = { Compact = compact, Expanded = expanded, Activity = activity }
    local mode = "Compact"
    local modeToken = 0
    local sizeTween, cornerTween
    local hovered, pressed = false, false
    local hoverToken = 0
    local dragFrom, dragAnchor, dragging, dragged = nil, nil, false, false
    local activityToken = 0
    local activityLive = false

    local function shapeFor(name)
        if name == "Expanded" then
            return Vector2.new(Mini.Wide, math.floor(expandedList.AbsoluteSize.Y + 28 + 0.5)), Mini.Radius
        elseif name == "Activity" then
            return Vector2.new(Mini.Wide, math.floor(math.max(activityList.AbsoluteSize.Y, 34) + 26 + 0.5)), Mini.Radius
        end
        return Vector2.new(Mini.Width, Mini.Height), Mini.Height / 2
    end

    -- Where the island hangs: the top centre of its shape, as fractions of
    -- the screen so it keeps its spot across resolutions. Dragging moves it;
    -- each shape is clamped on screen, so the wide card slides in from an edge
    -- and the pill goes back to its spot when it folds.
    -- A locked island (IslandDraggable = false) stays at the top centre, whatever was saved.
    local saved = self:_readConfigSettings().IslandPosition
    if not self._islandLocked and type(saved) == "table" and tonumber(saved.X) and tonumber(saved.Y) then
        self._islandAnchor = Vector2.new(math.clamp(tonumber(saved.X), 0, 1), math.clamp(tonumber(saved.Y), 0, 1))
    end
    local positionTween
    local function anchorPixels()
        local view = gui.AbsoluteSize
        local anchor = not self._islandLocked and self._islandAnchor or nil
        if not anchor then
            return Vector2.new(view.X / 2, Mini.Top)
        end
        return Vector2.new(anchor.X * view.X, anchor.Y * view.Y)
    end
    local function islandSpot(size, from)
        local view = gui.AbsoluteSize
        local spot = from or anchorPixels()
        local margin = 6
        local x = math.clamp(spot.X, size.X / 2 + margin, math.max(view.X - size.X / 2 - margin, size.X / 2 + margin))
        local y = math.clamp(spot.Y, margin, math.max(view.Y - size.Y - margin, margin))
        return Vector2.new(x, y)
    end
    local function placeIsland(size, duration, style)
        local spot = islandSpot(size)
        if positionTween then
            positionTween:Cancel()
            positionTween = nil
        end
        if duration and duration > 0 then
            positionTween = tween(island, { Position = UDim2.fromOffset(spot.X, spot.Y) }, duration, style or Enum.EasingStyle.Quint)
        else
            island.Position = UDim2.fromOffset(spot.X, spot.Y)
        end
    end
    self._islandReset = function()
        self._islandAnchor = nil
        if island.Visible then
            placeIsland(Vector2.new(island.Size.X.Offset, island.Size.Y.Offset), 0.35)
        end
    end

    local function setMode(name, instant)
        local size, radius = shapeFor(name)
        local changed = name ~= mode
        mode = name
        modeToken += 1
        local token = modeToken
        local current = Vector2.new(island.Size.X.Offset, island.Size.Y.Offset)
        local growing = size.X > current.X + 1 or size.Y > current.Y + 1
        local duration = instant and 0 or (growing and 0.5 or 0.38)
        -- A snap must stop a morph still in flight, or it keeps writing the
        -- old shape over the new one.
        if sizeTween then
            sizeTween:Cancel()
        end
        if cornerTween then
            cornerTween:Cancel()
        end
        placeIsland(size, duration)
        sizeTween = tween(island, { Size = UDim2.fromOffset(size.X, size.Y) }, duration, growing and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
        cornerTween = tween(islandCorner, { CornerRadius = UDim.new(0, radius) }, duration, Enum.EasingStyle.Quint)
        -- The iOS island gives a soft squeeze as it swells open, then springs
        -- back, so the morph reads as one elastic body rather than a resize.
        if changed and not instant and not pressed and not dragging then
            islandScale.Scale = growing and 0.96 or 1.03
            tween(islandScale, { Scale = 1 }, growing and 0.55 or 0.4, Enum.EasingStyle.Back)
        end
        if changed or instant then
            if mergeTween then
                mergeTween:Cancel()
                mergeTween = nil
            end
            if instant then
                merge.Value = name == "Compact" and 1 or 0
            elseif name == "Compact" then
                -- Wait for the pill to shrink most of the way, then bud off.
                task.delay(duration * 0.55, function()
                    if modeToken == token then
                        mergeTween = tween(merge, { Value = 1 }, 0.6, Enum.EasingStyle.Back)
                    end
                end)
            else
                mergeTween = tween(merge, { Value = 0 }, 0.2, Enum.EasingStyle.Quint)
            end
        end
        if not changed and not instant then
            -- A refit (same shape, new height) bumps the token, which cancels
            -- a fade-in still waiting from the morph; finish it here or the
            -- card stays black until the next hover.
            local target = layers[name]
            if target.GroupTransparency > 0 then
                tween(target, { GroupTransparency = 0 }, 0.22, Enum.EasingStyle.Quad)
            end
            if target ~= compact and target.Position ~= UDim2.fromScale(0.5, 0) then
                tween(target, { Position = UDim2.fromScale(0.5, 0) }, 0.32, Enum.EasingStyle.Quint)
            end
            return
        end
        for key, group in pairs(layers) do
            if key ~= name then
                tween(group, { GroupTransparency = 1 }, instant and 0 or 0.14, Enum.EasingStyle.Quad)
            end
        end
        local target = layers[name]
        if instant then
            target.GroupTransparency = 0
            -- Compact fills the island from its corner; only the wide
            -- layers hang from the centre.
            if target ~= compact then
                target.Position = UDim2.fromScale(0.5, 0)
            end
        else
            -- The new layer rises a few pixels into place as it fades in, so
            -- the content reads as arriving with the shape, not popping in.
            if target ~= compact then
                target.Position = UDim2.new(0.5, 0, 0, 6)
            end
            task.delay(0.1, function()
                if modeToken == token then
                    tween(target, { GroupTransparency = 0 }, 0.22, Enum.EasingStyle.Quad)
                    if target ~= compact then
                        tween(target, { Position = UDim2.fromScale(0.5, 0) }, 0.32, Enum.EasingStyle.Quint)
                    end
                end
            end)
        end
    end

    local function settleMode()
        if hovered and not TOUCH and not dragging then
            setMode("Expanded")
        elseif activityLive then
            setMode("Activity")
        elseif self.IslandStyle == "Always Show" and not dragging then
            self:_refreshMini()
            refreshSession()
            setMode("Expanded")
        else
            setMode("Compact")
        end
    end

    self._islandSettle = function()
        if self.Minimized and island.Visible and not dragging then
            settleMode()
        end
    end

    -- Called by Minimize once the window is out of the way: the island is
    -- reset to its compact pill and its spot handed back for the ghost.
    function self:_miniLand()
        hovered, activityLive = false, false
        activityToken += 1
        islandScale.Scale = 1
        setMode("Compact", true)
        local size = Vector2.new(Mini.Width, Mini.Height)
        local spot = islandSpot(size)
        return Vector2.new(spot.X - size.X / 2, spot.Y), size
    end

    hit.MouseEnter:Connect(function()
        if usingTouch() or dragging then
            return
        end
        hovered = true
        hoverToken += 1
        local token = hoverToken
        -- Already open (the pointer left and came back within the grace):
        -- just stay. Otherwise lean in a touch, and only open once the
        -- pointer rests, so sweeping past the island doesn't burst it open.
        if mode == "Expanded" then
            return
        end
        if not pressed then
            tween(islandScale, { Scale = 1.04 }, 0.18, Enum.EasingStyle.Quint)
        end
        task.delay(0.12, function()
            if hoverToken == token and hovered and self.Minimized and not dragging then
                self:_refreshMini()
                refreshSession()
                setMode("Expanded")
            end
        end)
    end)
    hit.MouseLeave:Connect(function()
        hovered = false
        hoverToken += 1
        local token = hoverToken
        if not pressed then
            tween(islandScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Quint)
        end
        -- A grace period: the card shifts while it morphs and clamps on
        -- screen, so a pointer grazing its edge shouldn't snap it shut.
        task.delay(mode == "Expanded" and 0.28 or 0.1, function()
            if hoverToken == token and not hovered and self.Minimized then
                settleMode()
            end
        end)
    end)
    -- Press and pull to move the island anywhere on screen. It folds to the
    -- pill while carried, lifts a little, and a drop near its home at the top
    -- centre snaps back there. A drag never counts as the click that restores.
    hit.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        pressed = true
        dragged = false
        tween(islandScale, { Scale = 0.95 }, 0.12, Enum.EasingStyle.Quad)
        if not self._islandLocked then
            dragFrom = Vector2.new(input.Position.X, input.Position.Y)
            dragAnchor = islandSpot(Vector2.new(Mini.Width, Mini.Height))
        end
    end)
    self:_listen("Changed", function(input)
        if not dragFrom or not isMove(input) or not self.Minimized then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragFrom
        if not dragging then
            if delta.Magnitude < (TOUCH and 10 or 6) then
                return
            end
            dragging, dragged = true, true
            hovered = false
            setMode("Compact")
            tween(islandScale, { Scale = 1.06 }, 0.2, Enum.EasingStyle.Quint)
        end
        local spot = islandSpot(Vector2.new(Mini.Width, Mini.Height), dragAnchor + delta)
        local view = gui.AbsoluteSize
        self._islandAnchor = Vector2.new(spot.X / math.max(view.X, 1), spot.Y / math.max(view.Y, 1))
        if positionTween then
            positionTween:Cancel()
            positionTween = nil
        end
        island.Position = UDim2.fromOffset(spot.X, spot.Y)
    end)
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not isPress(input) then
            return
        end
        dragFrom = nil
        if pressed then
            pressed = false
            tween(islandScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
        end
        if dragging then
            dragging = false
            local home = Vector2.new(gui.AbsoluteSize.X / 2, Mini.Top)
            local spot = islandSpot(Vector2.new(Mini.Width, Mini.Height))
            if (spot - home).Magnitude < 28 then
                self._islandAnchor = nil
                placeIsland(Vector2.new(Mini.Width, Mini.Height), 0.35, Enum.EasingStyle.Back)
            end
            local anchor = self._islandAnchor
            self:_writeConfigSettings({ IslandPosition = anchor and { X = anchor.X, Y = anchor.Y } or false })
            hovered = not usingTouch() and pointInside(pointerPosition(), island)
            task.delay(0.1, function()
                if self.Minimized and not dragging then
                    settleMode()
                end
            end)
        end
    end))
    -- Keeps the island on screen when the viewport changes size.
    table.insert(self._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if island.Visible and not dragging then
            placeIsland(Vector2.new(island.Size.X.Offset, island.Size.Y.Offset), 0)
        end
    end))
    hit.MouseButton1Click:Connect(function()
        if dragged then
            dragged = false
            return
        end
        if self.Minimized then
            self:Restore()
        end
    end)
    -- Restore hides the island under the pointer, so MouseLeave never fires.
    self._miniUnhover = function()
        hovered, pressed, activityLive = false, false, false
        dragFrom, dragging = nil, false
        activityToken += 1
        islandScale.Scale = 1
        -- Clicked open while expanded: once the island has faded out, fold it
        -- back to the pill so the next minimize starts from it.
        task.delay(0.15, function()
            if not self.Minimized then
                setMode("Compact", true)
            end
        end)
    end

    -- A notification while minimized: the island opens to show it for a few
    -- seconds, then folds back.
    self._islandActivity = function(opts)
        if not self.Minimized or not island.Visible then
            return
        end
        local color = NOTIFY_COLORS[opts.Type] or Theme.Accent
        activityTitle.Text = tostring(opts.Title or "Notification")
        activityTitle.TextColor3 = NOTIFY_COLORS[opts.Type] or Theme.Text
        activityBody.Text = tostring(opts.Content or "")
        activityBody.Visible = activityBody.Text ~= ""
        local icon = opts.Icon
        if icon == nil then
            icon = ({ Success = "circle-check", Warning = "triangle-alert", Error = "circle-x" })[opts.Type] or "bell"
        end
        applyIcon(activityIcon, icon)
        if not activityIcon:GetAttribute("CustomIcon") then
            activityIcon.ImageColor3 = color
        end
        activityChip.BackgroundColor3 = color
        activityLive = true
        activityToken += 1
        local token = activityToken
        task.defer(function()
            if activityToken == token and not hovered and not dragging then
                setMode("Activity")
                islandScale.Scale = 0.96
                tween(islandScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
            end
        end)
        task.delay(math.clamp(tonumber(opts.Duration) or 3, 1.5, 5), function()
            if activityToken == token then
                activityLive = false
                if self.Minimized and not hovered then
                    settleMode()
                end
            end
        end)
    end

    -- The meter dances while anything runs and lies flat when nothing does.
    -- The bars sit inside two CanvasGroups, so every write re-renders both:
    -- they step at ~12 Hz, only write heights that changed, and hold still
    -- in Performance Mode.
    local running = 0
    local meterAt = 0
    self:_listen("Render", function()
        if island.Visible and running > 0 and mode == "Compact" and not Library.PerformanceMode then
            local now = os.clock()
            if now - meterAt < 0.08 then
                return
            end
            meterAt = now
            for index, bar in ipairs(bars) do
                local wave = 0.5 + 0.5 * math.sin(now * (6 + index * 1.4) + index * 1.9)
                local height = math.floor(4 + wave * 11 + 0.5)
                if bar.Size.Y.Offset ~= height then
                    bar.Size = UDim2.fromOffset(3, height)
                end
            end
        end
    end)

    -- Split, like iOS with two Live Activities: when toggles are running and
    -- a status is pinned, the pill keeps the status (logo leading, value
    -- trailing) and the running meter buds off into its own little circle
    -- beside it. One activity alone stays in the single pill.
    local pinValue = label({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(1, -52, 0, 18),
        TextSize = 13,
        FontFace = Fonts.Bold,
        TextXAlignment = Enum.TextXAlignment.Right,
        RichText = true,
        TextTransparency = 1,
        Parent = compact,
    })
    local bubble = create("TextButton", {
        Name = "IslandBubble",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 30,
        Parent = gui,
    })
    corner(bubble, UDim.new(1, 0))
    local split = create("NumberValue", { Value = 0 })
    local splitOn = false
    local pinnedLead = nil
    local function setSplit(on)
        if on == splitOn then
            return
        end
        splitOn = on
        barsHolder.Parent = on and bubble or meter
        barsHolder.AnchorPoint = on and Vector2.new(0.5, 0.5) or Vector2.new(0, 0)
        barsHolder.Position = on and UDim2.fromScale(0.5, 0.5) or UDim2.new()
        meter.Visible = not on
        tween(pinValue, { TextTransparency = on and 0 or 1 }, 0.2, Enum.EasingStyle.Quad)
        -- Buds off with a spring, and is drawn back in quicker.
        tween(split, { Value = on and 1 or 0 }, on and 0.55 or 0.3, on and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
        if on then
            islandScale.Scale = 0.96
            tween(islandScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
        end
    end
    self:_listen("Render", function()
        local t = split.Value * merge.Value
        local shown = island.Visible and t > 0.02 and island.GroupTransparency < 0.5
        bubble.Visible = shown
        if not shown then
            return
        end
        local origin = gui.AbsolutePosition
        local pos, size = island.AbsolutePosition - origin, island.AbsoluteSize
        local d = math.min(size.Y, Mini.Height)
        local gap = 6
        -- Buds off the side with room to spare: the right, or the left near
        -- the right edge of the screen.
        local right = pos.X + size.X + gap + d <= gui.AbsoluteSize.X
        local edge = right and pos.X + size.X or pos.X
        local dir = right and 1 or -1
        local inner = edge - dir * d * 0.6
        local outer = edge + dir * (gap + d / 2)
        local x = inner + (outer - inner) * t
        local scale = math.clamp(0.35 + 0.65 * t, 0, 1.2)
        -- Liquid: mid-flight the drop stretches along its path and thins,
        -- then rounds back into a circle as it settles.
        local stretch = math.sin(math.clamp(t, 0, 1) * math.pi)
        bubble.Position = UDim2.fromOffset(x, pos.Y + d / 2)
        bubble.Size = UDim2.fromOffset(d * scale * (1 + 0.4 * stretch), d * scale * (1 - 0.18 * stretch))
        bubble.BackgroundTransparency = island.GroupTransparency
    end)
    bubble.MouseButton1Click:Connect(function()
        if self.Minimized then
            self:Restore()
        end
    end)

    local cardRows = {}
    function self:_refreshMini()
        local count = 0
        for _, element in pairs(Library.Flags) do
            if element._type == "Toggle" and element.Value == true then
                count += 1
            end
        end
        if count ~= running then
            local rising = count > running
            running = count
            countLabel.Text = tostring(count)
            for _, bar in ipairs(bars) do
                tween(bar, { BackgroundColor3 = count > 0 and Theme.Accent or Theme.Muted }, 0.25)
                if count == 0 then
                    tween(bar, { Size = UDim2.fromOffset(3, 3) }, 0.25)
                end
            end
            -- A small bump, like a live activity updating.
            if rising and mode == "Compact" and island.Visible then
                islandScale.Scale = 1.06
                tween(islandScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
            end
        end
        bigCount.Text = tostring(count)
        local names = {}
        for _, element in pairs(Library.Flags) do
            if element._type == "Toggle" and element.Value == true and element._searchName ~= "" then
                table.insert(names, element._searchName)
            end
        end
        table.sort(names)
        local shownNames = {}
        for index = 1, math.min(#names, 3) do
            shownNames[index] = Library._rich(names[index])
        end
        local extra = #names - #shownNames
        runningNames.Text = '<font color="#8A8A93">Running </font>' .. table.concat(shownNames, '<font color="#8A8A93"> · </font>')
            .. (extra > 0 and string.format('<font color="#8A8A93">  +%d</font>', extra) or "")
        runningNames.Visible = #names > 0
        pinnedLead = nil
        for _, handle in ipairs(self._pinned) do
            if not handle._isShown or handle:_isShown() then
                pinnedLead = handle
                break
            end
        end
        if pinnedLead then
            local text = tostring(pinnedLead:Text() or "")
            -- A status with nothing to show yet doesn't take the pill.
            if text:gsub("<[^>]*>", ""):match("%S") then
                pinValue.Text = text
                local color = pinnedLead._shownColor and pinnedLead._shownColor() or Theme.Text
                -- Too dark to read on the black pill: fall back to text colour.
                local _, _, value = color:ToHSV()
                pinValue.TextColor3 = value < 0.35 and Theme.Text or color
            else
                pinnedLead = nil
            end
        end
        setSplit(running > 0 and pinnedLead ~= nil)
        -- The pill's own meter: the clock when idle or when the bars budded
        -- off without a status to keep, the bars and count otherwise.
        local barsHere = running > 0 and not splitOn
        idleDot.Visible = not barsHere
        idleLabel.Visible = not barsHere
        countLabel.Visible = barsHere
        barsHolder.Visible = running > 0
        meter.Visible = not splitOn
        miniTitle.Visible = not splitOn
        local key = typeof(self.Keybind) == "EnumItem" and keyName(self.Keybind)
        hint.Text = TOUCH and "Tap to open" or (key and ("Click or press " .. key .. " to open") or "Click to open")

        local list = {}
        for _, handle in ipairs(self._pinned) do
            if (not handle._isShown or handle:_isShown()) and #list < Mini.Pinned then
                table.insert(list, handle)
            end
        end
        rowsHolder.Visible = false
        for index = 1, math.max(#list, #cardRows) do
            local handle = list[index]
            local row = cardRows[index]
            if handle then
                if not row then
                    local frame = create("Frame", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        LayoutOrder = index,
                        Parent = rowsHolder,
                    })
                    row = {
                        Frame = frame,
                        Key = label({
                            Size = UDim2.new(0.5, -4, 1, 0),
                            TextSize = 12,
                            FontFace = Fonts.Regular,
                            TextColor3 = Theme.Muted,
                            RichText = true,
                            Parent = frame,
                        }),
                        Value = label({
                            AnchorPoint = Vector2.new(1, 0),
                            Position = UDim2.fromScale(1, 0),
                            Size = UDim2.new(0.5, -4, 1, 0),
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            RichText = true,
                            Parent = frame,
                        }),
                    }
                    cardRows[index] = row
                end
                row.Frame.Visible = true
                row.Key.Text = Library._rich(handle.Name)
                row.Value.Text = handle:Text()
                -- Carries the status's own colour: its Color, or its tone
                -- for the tinted styles (badge, dot, bar).
                local color = handle._shownColor and handle._shownColor() or Theme.Text
                if row.Value.TextColor3 ~= color then
                    tween(row.Value, { TextColor3 = color }, 0.2)
                end
            elseif row then
                row.Frame.Visible = false
            end
        end
        -- Rows coming and going change the expanded height.
        if mode == "Expanded" and (hovered or self.IslandStyle == "Always Show") then
            task.defer(function()
                if mode == "Expanded" and (hovered or self.IslandStyle == "Always Show") and self.Minimized then
                    local size = shapeFor("Expanded")
                    if math.abs(size.Y - island.Size.Y.Offset) > 1 then
                        setMode("Expanded")
                    end
                end
            end)
        end
    end

    self.MiniBar = island
    self.Island = island
    return island
end

function Window:Minimize()
    if not self._introDone and not self._destroyed then
        self._pendingShow = "minimized"
        return
    end
    if self.Minimized or not self.Open or self._destroyed then
        return
    end
    self.Minimized = true
    self._minimizeGeneration = (self._minimizeGeneration or 0) + 1
    local generation = self._minimizeGeneration
    self:_closePopups()
    self:_refreshToggleButton()
    self:_refreshBackdrop()
    local bar = self:_buildMiniBar()
    self:_refreshMini()
    local gui = self.Gui

    -- Starts from whatever is on screen: the window, or a ghost still
    -- mid-flight if a restore was interrupted.
    local fromPosition = self.Root.AbsolutePosition - gui.AbsolutePosition
    local fromSize = self.Root.AbsoluteSize
    local fromAlpha = 1
    if self._ghost then
        fromPosition = self._ghost.AbsolutePosition - gui.AbsolutePosition
        fromSize = self._ghost.AbsoluteSize
        fromAlpha = self._ghost.BackgroundTransparency
    end

    -- 1. The ghost fades in over the window while it eases back a touch.
    local ghost, ghostStroke, ghostCorner = makeGhost(self, fromPosition, fromSize, Library._radius(10))
    ghost.BackgroundTransparency = fromAlpha
    ghostStroke.Transparency = fromAlpha
    tween(ghost, { BackgroundTransparency = 0 }, 0.11, Enum.EasingStyle.Quad)
    tween(ghostStroke, { Transparency = 0 }, 0.11, Enum.EasingStyle.Quad)
    tween(self.Scale, { Scale = (self._fitScale or 1) * 0.985 }, 0.11, Enum.EasingStyle.Quad)
    tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
    bar.Visible = true
    bar.GroupTransparency = 1

    task.delay(0.11, function()
        if self._minimizeGeneration ~= generation or self._destroyed then
            return
        end
        -- 2. Covered by the ghost, the window is hidden and the ghost folds
        -- down into the island.
        self.Root.Visible = false
        self.Scale.Scale = self._fitScale or 1
        local target, size = self:_miniLand(fromPosition + fromSize / 2)
        morphGhost(ghost, ghostCorner, target, size, math.floor(size.Y / 2), 0.36)
        task.delay(0.3, function()
            if self._minimizeGeneration ~= generation or self._destroyed then
                return
            end
            -- 3. The island fades in on top as the ghost lands.
            self._miniScale.Scale = 0.9
            tween(self._miniScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Quint)
            tween(bar, { GroupTransparency = 0 }, 0.18, Enum.EasingStyle.Quad)
            dissolve(self, ghost, ghostStroke, 0.2)
            -- Always Show: once landed as the pill, swell open into the card.
            if self.IslandStyle == "Always Show" then
                task.delay(0.22, function()
                    if self._minimizeGeneration == generation and self._islandSettle then
                        self._islandSettle()
                    end
                end)
            end
        end)
    end)

    task.spawn(function()
        while self.Minimized and self._minimizeGeneration == generation and not self._destroyed do
            self:_refreshMini()
            task.wait(0.5)
        end
    end)
end

function Window:Restore()
    if not self._introDone then
        self._pendingShow = nil
        return
    end
    if not self.Minimized or self._destroyed then
        return
    end
    self.Minimized = false
    self._minimizeGeneration = (self._minimizeGeneration or 0) + 1
    local generation = self._minimizeGeneration
    self:_refreshToggleButton()
    self:_refreshBackdrop(true)
    local gui = self.Gui
    local bar = self.MiniBar
    local fit = self._fitScale or 1
    local size = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset) * fit
    local centre = self.Root.AbsolutePosition + self.Root.AbsoluteSize / 2 - gui.AbsolutePosition
    local target = centre - size / 2

    -- Picks up from whatever is on screen: a ghost still mid-flight if
    -- minimize was interrupted, otherwise the island.
    local fromPosition, fromSize = target, size
    local fromAlpha = 1
    if self._ghost then
        fromPosition = self._ghost.AbsolutePosition - gui.AbsolutePosition
        fromSize = self._ghost.AbsoluteSize
        fromAlpha = self._ghost.BackgroundTransparency
    elseif bar and bar.Visible then
        fromPosition = self._miniOrb.AbsolutePosition - gui.AbsolutePosition
        fromSize = self._miniOrb.AbsoluteSize
    end
    if bar and bar.Visible then
        if self._miniUnhover then
            self._miniUnhover()
        end
        tween(bar, { GroupTransparency = 1 }, 0.12, Enum.EasingStyle.Quad)
        -- Hidden whenever the window isn't minimized by then, even if a quick
        -- Toggle bumped the generation: a see-through island would still catch clicks.
        task.delay(0.12, function()
            if self._minimizeGeneration == generation or not self.Minimized then
                bar.Visible = false
            end
        end)
    end

    local ghost, ghostStroke, ghostCorner = makeGhost(self, fromPosition, fromSize, math.floor(math.min(fromSize.X, fromSize.Y) / 2))
    ghost.BackgroundTransparency = fromAlpha
    ghostStroke.Transparency = fromAlpha
    tween(ghost, { BackgroundTransparency = 0 }, 0.1, Enum.EasingStyle.Quad)
    tween(ghostStroke, { Transparency = 0 }, 0.1, Enum.EasingStyle.Quad)
    morphGhost(ghost, ghostCorner, target, size, Library._radius(10), 0.4)
    tween(self.Shadow, { ImageTransparency = self._shadowRest }, 0.45)

    -- Shown under the ghost a little early so its first frames are drawn
    -- while still covered, then the ghost clears to reveal it.
    task.delay(0.3, function()
        if self._minimizeGeneration ~= generation or self._destroyed then
            return
        end
        self.Scale.Scale = fit
        self.BodyStroke.Transparency = 0
        self.Root.Visible = true
    end)
    task.delay(0.4, function()
        if self._ghost == ghost and self._minimizeGeneration == generation then
            dissolve(self, ghost, ghostStroke, 0.22)
        end
    end)
end

-- The minimized island can be dragged anywhere; its spot is remembered in
-- the config folder. These lock it in place or send it back to the top.
function Window:SetIslandDraggable(enabled)
    self._islandLocked = enabled == false
end

function Window:ResetIslandPosition()
    self._islandAnchor = nil
    if self._islandReset then
        self._islandReset()
    end
    self:_writeConfigSettings({ IslandPosition = false })
end

function Window:SetMinimized(minimized)
    if minimized then
        self:Minimize()
    else
        self:Restore()
    end
end

function Window:Toggle(open)
    -- During the loader the request is kept and applied when the window appears.
    if not self._introDone then
        self._pendingShow = (open == true) and "open" or (open == false and "hidden" or (self._pendingShow == "hidden" and "open" or "hidden"))
        return
    end
    if self.Minimized then
        if open ~= false then
            self:Restore()
        end
        return
    end
    if open == nil then
        open = not self.Open
    end
    if open == self.Open then
        return
    end
    self.Open = open
    self:_refreshToggleButton()
    self:_refreshBackdrop(open)
    -- Like minimize, a plain ghost panel carries the scale and fade. The body
    -- is never reparented into the fader or rescaled, which relaid out the
    -- whole window and stuttered on the keypress frame.
    self._minimizeGeneration = (self._minimizeGeneration or 0) + 1
    local generation = self._minimizeGeneration
    local gui = self.Gui
    local fit = self._fitScale or 1
    local size = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset) * fit
    local centre = self.Root.AbsolutePosition + self.Root.AbsoluteSize / 2 - gui.AbsolutePosition
    local shrunk = size * 0.94
    local fromPosition, fromSize, fromAlpha
    if self._ghost then
        fromPosition = self._ghost.AbsolutePosition - gui.AbsolutePosition
        fromSize = self._ghost.AbsoluteSize
        fromAlpha = self._ghost.BackgroundTransparency
    end
    if open then
        local ghost, ghostStroke, ghostCorner = makeGhost(self, fromPosition or centre - shrunk / 2, fromSize or shrunk, Library._radius(10))
        ghost.BackgroundTransparency = fromAlpha or 1
        ghostStroke.Transparency = fromAlpha or 1
        tween(ghost, { BackgroundTransparency = 0 }, 0.12, Enum.EasingStyle.Quad)
        tween(ghostStroke, { Transparency = 0 }, 0.12, Enum.EasingStyle.Quad)
        morphGhost(ghost, ghostCorner, centre - size / 2, size, Library._radius(10), 0.3)
        tween(self.Shadow, { ImageTransparency = self._shadowRest }, 0.3)
        -- Shown under the ghost once it covers the spot, then revealed.
        task.delay(0.2, function()
            if self._minimizeGeneration ~= generation or self._destroyed then
                return
            end
            self.Scale.Scale = fit
            self.BodyStroke.Transparency = 0
            self.Root.Visible = true
        end)
        task.delay(0.3, function()
            if self._ghost == ghost and self._minimizeGeneration == generation then
                dissolve(self, ghost, ghostStroke, 0.18)
            end
        end)
    else
        self:_closePopups()
        local position = fromPosition or self.Root.AbsolutePosition - gui.AbsolutePosition
        local current = fromSize or self.Root.AbsoluteSize
        local ghost, ghostStroke, ghostCorner = makeGhost(self, position, current, Library._radius(10))
        ghost.BackgroundTransparency = fromAlpha or 1
        ghostStroke.Transparency = fromAlpha or 1
        tween(ghost, { BackgroundTransparency = 0 }, 0.08, Enum.EasingStyle.Quad)
        tween(ghostStroke, { Transparency = 0 }, 0.08, Enum.EasingStyle.Quad)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.16)
        task.delay(0.08, function()
            if self._minimizeGeneration ~= generation or self._destroyed then
                return
            end
            self.Root.Visible = false
            morphGhost(ghost, ghostCorner, centre - shrunk / 2, shrunk, Library._radius(10), 0.2)
            dissolve(self, ghost, ghostStroke, 0.16)
        end)
    end
end

function Window:SetKeepOnScreen(enabled)
    self.KeepOnScreen = enabled ~= false
    if self.KeepOnScreen then
        self:_clampToScreen()
    end
end

function Window:SetKeybind(keyCode)
    -- false and "None" clear the hide key, as nil does; unknown names are ignored.
    if keyCode == false or keyCode == "None" then
        keyCode = nil
    elseif keyCode ~= nil then
        keyCode = Library._keyCode(keyCode)
        if not keyCode then
            return
        end
    end
    self.Keybind = keyCode
    if self._keyChipLabel then
        self._keyChipLabel.Text = keyName(keyCode)
    end
end


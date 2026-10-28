-- Segmented: a pill track of 2-5 options with an accent thumb that slides to
-- the picked one. Beside the name like a Stepper, or stacked full width under
-- it when the options don't fit the row.
-- No top-level locals here: the library function is close to Luau's limit.
function Tab:Segmented(opts)
    local frame, frameStroke, baseHeight
    opts, frame, frameStroke, baseHeight = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentOption = "Default", CurrentValue = "Default", Value = "Default", Values = "Options" }, "Frame")
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local window = self.Window
    local textSize = compact and 12 or 13
    local chipHeight = metrics.Chip
    local stackChip = TOUCH and 34 or 30

    local name = opts.Name
    if name == nil then
        name = "Segmented"
    end
    name = tostring(name)
    local title = name ~= "" and label({
        Text = name,
        TextSize = metrics.TextSize,
        Parent = frame,
    }) or nil
    local descLabel = opts.Desc and label({
        Text = tostring(opts.Desc),
        TextSize = metrics.DescSize,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = frame,
    }) or nil

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(120, chipHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(track, UDim.new(1, 0))
    local trackStroke = stroke(track)
    hoverStroke(track, trackStroke)
    local slots = create("Frame", {
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -4, 1, -4),
        BackgroundTransparency = 1,
        Parent = track,
    })
    local thumb = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
        Parent = slots,
    })
    corner(thumb, UDim.new(1, 0))
    -- Widths are read off a hidden label, as the dropdown chip does.
    local measure = label({
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = textSize,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = track,
    })

    local handle = {}
    -- options are the labels (strings, for display and matching); values keep what
    -- the script gave, so numeric options come back as numbers.
    local options, values, buttons = {}, {}, {}
    local index = 0
    local hovered = nil
    local stackedNow = false

    local function sanitize(list)
        local out, raw = {}, {}
        if type(list) == "table" then
            for _, option in ipairs(list) do
                table.insert(out, tostring(option))
                table.insert(raw, option)
            end
        end
        return out, raw
    end

    -- Option text first, so numeric options ({ 30, 60, 120 }) match by value;
    -- a number that isn't an option's text is taken as an index.
    local function resolve(value)
        if value == nil then
            return nil
        end
        local found = table.find(options, tostring(value))
        if found then
            return found
        end
        if type(value) == "number" then
            local i = math.floor(value)
            return options[i] and i or nil
        end
        return nil
    end

    local function colorFor(i)
        if i == index then
            return Theme.AccentDark
        elseif i == hovered then
            return Theme.Text
        end
        return Theme.Muted
    end

    local function paint(duration)
        for i, button in ipairs(buttons) do
            tween(button, { TextColor3 = colorFor(i) }, duration)
        end
    end

    local function moveThumb(duration)
        local count = #options
        if count == 0 or not options[index] then
            thumb.Visible = false
            return
        end
        local size = UDim2.fromScale(1 / count, 1)
        local position = UDim2.fromScale((index - 1) / count, 0)
        if duration == 0 or not thumb.Visible then
            thumb.Size = size
            thumb.Position = position
            thumb.Visible = true
        else
            tween(thumb, { Size = size, Position = position }, duration or 0.35, Enum.EasingStyle.Quint)
        end
    end

    local function segmentWidth()
        local widest = 0
        for _, option in ipairs(options) do
            measure.Text = option
            local width = measure.TextBounds.X
            if width <= 0 then
                width = #option * textSize * 0.55
            end
            widest = math.max(widest, width)
        end
        return math.max(math.ceil(widest) + (TOUCH and 26 or 22), TOUCH and 44 or 34)
    end

    -- Places the name, description and track. Decides stacking when the
    -- script left Stacked unset: in a groupbox row the track stacks once it
    -- would take more than ~55% of the row; on a card once it would crowd the
    -- name.
    local lastWidth = 0
    local function layout()
        if handle._destroyed or not frame.Parent then
            return
        end
        local scale = window and window.Scale and window.Scale.Scale or 1
        local rowWidth = frame.AbsoluteSize.X / scale
        local width = #options * segmentWidth() + 4
        local stack
        if opts.Stacked ~= nil then
            stack = opts.Stacked == true
        elseif rowWidth <= 0 then
            stack = stackedNow
        elseif compact then
            stack = width > rowWidth * 0.55
        else
            stack = width > rowWidth - 14 - 110 - 20
        end
        stackedNow = stack

        if stack then
            local y = compact and 1 or 10
            if title then
                title.Position = UDim2.fromOffset(14, y)
                title.Size = UDim2.new(1, -28, 0, metrics.TitleHeight)
                y += metrics.TitleHeight + 3
            end
            if descLabel then
                descLabel.Position = UDim2.fromOffset(14, y - 2)
                descLabel.Size = UDim2.new(1, -28, 0, metrics.DescLine)
                y += metrics.DescLine + 1
            end
            track.AnchorPoint = Vector2.zero
            track.Position = UDim2.fromOffset(14, y)
            track.Size = UDim2.new(1, -28, 0, stackChip)
            frame.Size = UDim2.new(1, 0, 0, y + stackChip + (compact and 4 or 10))
            return
        end

        frame.Size = UDim2.new(1, 0, 0, baseHeight)
        if rowWidth > 0 then
            width = math.min(width, math.max(rowWidth - 14 - 60 - 20, 80))
        end
        local reserve = width + (compact and 24 or 20)
        if descLabel then
            local top = math.floor((metrics.DescHeight - (metrics.DescGap + metrics.DescLine)) / 2)
            if title then
                title.Position = UDim2.fromOffset(14, top)
                title.Size = UDim2.new(1, -(14 + reserve), 0, metrics.TitleHeight)
            end
            descLabel.Position = UDim2.fromOffset(14, top + metrics.DescGap)
            descLabel.Size = UDim2.new(1, -(14 + reserve), 0, metrics.DescLine)
        elseif title then
            title.Position = UDim2.fromOffset(14, 0)
            title.Size = UDim2.new(1, -(14 + reserve), 1, 0)
        end
        track.AnchorPoint = Vector2.new(1, 0.5)
        track.Position = UDim2.new(1, compact and -14 or -10, 0.5, 0)
        track.Size = UDim2.fromOffset(width, chipHeight)
    end

    local function pick(i, silent, fromClick)
        if i == index or not options[i] then
            return
        end
        index = i
        handle.Value = values[i]
        moveThumb()
        paint(0.2)
        if not fromClick then
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, values[i])
        end
    end

    local function build()
        for _, button in ipairs(buttons) do
            button:Destroy()
        end
        table.clear(buttons)
        hovered = nil
        local count = #options
        for i, option in ipairs(options) do
            local button = create("TextButton", {
                Position = UDim2.fromScale((i - 1) / count, 0),
                Size = UDim2.fromScale(1 / count, 1),
                BackgroundTransparency = 1,
                Text = option,
                TextSize = textSize,
                FontFace = Fonts.Medium,
                TextColor3 = colorFor(i),
                TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false,
                ZIndex = 2,
                Parent = slots,
            })
            padding(button, 6, 6)
            button.MouseEnter:Connect(function()
                if usingTouch() then
                    return
                end
                hovered = i
                if i ~= index then
                    tween(button, { TextColor3 = Theme.Text }, 0.12)
                end
            end)
            button.MouseLeave:Connect(function()
                if hovered == i then
                    hovered = nil
                end
                if i ~= index then
                    tween(button, { TextColor3 = Theme.Muted }, 0.2)
                end
            end)
            -- A swipe that scrolls the page is not a pick.
            local isTap = tapGuard(button, function()
                return frame:FindFirstAncestorWhichIsA("ScrollingFrame")
            end)
            button.MouseButton1Click:Connect(function()
                if i == index or not isTap() then
                    return
                end
                pick(i, false, true)
                tween(trackStroke, { Color = Theme.StrokeHover }, 0.08)
                task.delay(0.12, function()
                    tween(trackStroke, { Color = Theme.Stroke }, 0.2)
                end)
            end)
            buttons[i] = button
        end
        moveThumb(0)
        layout()
    end

    -- A value that isn't an option yet (a config loaded before SetOptions) is
    -- kept and picked once SetOptions offers it.
    local waiting = nil
    function handle:Set(value, silent)
        local i = resolve(value)
        if i then
            waiting = nil
            pick(i, silent)
        elseif value ~= nil then
            waiting = value
        end
    end

    function handle:Get()
        return values[index]
    end

    function handle:GetOptions()
        return table.clone(values)
    end

    -- Replaces the options. The value stays if it is still offered, otherwise
    -- the first option is picked (and the callback runs unless silent).
    function handle:SetOptions(list, silent)
        local current = options[index]
        options, values = sanitize(list)
        local keep = current ~= nil and table.find(options, current) or nil
        index = keep or 0
        handle.Value = values[index]
        build()
        -- A value set before its option existed is picked now, like any other pick.
        local pending = waiting ~= nil and resolve(waiting) or nil
        waiting = nil
        if pending then
            pick(pending, silent)
        elseif not keep and options[1] then
            pick(1, silent)
        end
    end
    handle.Refresh = handle.SetOptions

    options, values = sanitize(opts.Options)
    index = resolve(opts.Default) or (options[1] and 1 or 0)
    handle.Value = values[index]
    build()

    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if frame.AbsoluteSize.X ~= lastWidth then
            lastWidth = frame.AbsoluteSize.X
            layout()
        end
    end)
    task.defer(layout)
    -- Measure again when a late font load changes text widths. The probe's
    -- text never changes, so its bounds only move when the font does.
    local probe = label({
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "Segment",
        TextSize = textSize,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = track,
    })
    probe:GetPropertyChangedSignal("TextBounds"):Connect(function()
        task.defer(layout)
    end)
    return finishElement(self, opts, handle, frame, "Segmented")
end

Tab.CreateSegmented = Tab.Segmented

-- Log: a capped, scrolling list of timestamped lines, newest at the bottom.
-- It follows new lines while scrolled to the end and stays put otherwise.
function Tab:Log(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", Max = "MaxEntries", Limit = "MaxEntries" })
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local inset = compact and 14 or 8
    local hasHead = type(opts.Name) == "string" and opts.Name ~= ""
    local titleTop = compact and 4 or 10
    local lineHeight = TOUCH and 22 or 20
    local textSize = compact and 12 or 13
    local maxLines = math.max(math.floor(tonumber(opts.MaxRows or opts.Lines) or 6), 1)
    local maxEntries = math.max(math.floor(tonumber(opts.MaxEntries) or 100), 1)
    local listTop = hasHead and (titleTop + (opts.Desc and 38 or 22)) or (compact and 4 or inset)
    local bottom = compact and 6 or inset
    local listHeight = maxLines * lineHeight + 8
    local timestamps = opts.Timestamps ~= false

    local frame, frameStroke = card(self, "Frame", listTop + listHeight + bottom, opts)
    hoverStroke(frame, frameStroke)
    local title
    if hasHead then
        title = label({
            Position = UDim2.fromOffset(14, titleTop),
            Size = UDim2.new(1, -28, 0, metrics.TitleHeight),
            Text = opts.Name,
            TextSize = metrics.TextSize,
            Parent = frame,
        })
        if opts.Desc then
            label({
                Position = UDim2.fromOffset(14, titleTop + metrics.TitleHeight + 1),
                Size = UDim2.new(1, -28, 0, metrics.DescLine),
                Text = opts.Desc,
                TextSize = metrics.DescSize,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                Parent = frame,
            })
        end
    end
    local holder = create("Frame", {
        Position = UDim2.fromOffset(inset, listTop),
        Size = UDim2.new(1, -inset * 2, 0, listHeight),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(holder, UDim.new(0, 6))
    stroke(holder, Theme.Stroke)
    local list = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = holder,
    })
    padding(list, 8, 8, 4, 4)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })
    local empty = label({
        Size = UDim2.fromScale(1, 1),
        Text = opts.EmptyText or "Nothing logged yet",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = holder,
    })

    local handle = { Entries = {} }
    local lines = {}
    local counter = 0

    local function paint(entry)
        local line = lines[entry]
        if not line then
            return
        end
        local text = Library._rich(entry.Text)
        if timestamps then
            text = ('<font color="#%s">%s</font>  %s'):format(Theme.Muted:ToHex(), os.date(opts.TimeFormat or "%H:%M:%S", entry.Time), text)
        end
        line.Text = text
        line.TextColor3 = Library._color(entry.Color) or Theme.Text
    end

    local function trimTo(count)
        while #handle.Entries > count do
            local old = table.remove(handle.Entries, 1)
            if lines[old] then
                lines[old]:Destroy()
                lines[old] = nil
            end
        end
        empty.Visible = #handle.Entries == 0
    end

    local function atEnd()
        return list.CanvasPosition.Y >= list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y - 4
    end

    -- Push(text, color?): color is a Color3, "#rrggbb" or a theme key ("Success").
    function handle:Push(text, color)
        local follow = atEnd()
        counter += 1
        local entry = { Text = tostring(text == nil and "" or text), Color = color, Time = os.time() }
        table.insert(handle.Entries, entry)
        lines[entry] = label({
            Size = UDim2.new(1, 0, 0, lineHeight),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextSize = textSize,
            FontFace = Fonts.Regular,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            RichText = true,
            LayoutOrder = counter,
            Parent = list,
        })
        paint(entry)
        trimTo(maxEntries)
        if follow then
            task.defer(function()
                list.CanvasPosition = Vector2.new(0, 1e7)
            end)
        end
        return entry
    end
    handle.Add = handle.Push
    handle.Log = handle.Push

    function handle:Clear()
        trimTo(0)
    end

    -- Copies of the entries, oldest first: { Text, Color, Time }.
    function handle:Get()
        local copy = {}
        for index, entry in ipairs(handle.Entries) do
            copy[index] = { Text = entry.Text, Color = entry.Color, Time = entry.Time }
        end
        return copy
    end

    function handle:SetTitle(text)
        if title then
            title.Text = tostring(text)
        end
    end

    function handle:SetMaxEntries(count)
        maxEntries = math.max(math.floor(tonumber(count) or maxEntries), 1)
        trimTo(maxEntries)
    end

    onTheme(holder, function()
        for _, entry in ipairs(handle.Entries) do
            paint(entry)
        end
    end)
    return finishElement(self, opts, handle, frame, "Log")
end

Tab.CreateLog = Tab.Log
Tab.AddLog = Tab.Log
Tab.Feed = Tab.Log
Tab.CreateFeed = Tab.Log
Tab.AddFeed = Tab.Log

Tab.CreateImage = Tab.Image
Tab.AddImage = Tab.Image
Tab.CreateTable = Tab.Table
Tab.AddTable = Tab.Table
Tab.CreateLeaderboard = Tab.Table


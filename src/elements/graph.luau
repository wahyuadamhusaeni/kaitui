-- Graph: a live line chart of the last N values. Roblox has no line primitive,
-- so each segment is a thin rotated frame; frames are pooled and reused, and
-- the chart redraws only when a value arrives or the plot changes size.
-- Everything lives inside Tab:Graph: the library function is near Luau's
-- 200-local limit, so this file adds no top-level locals.
function Tab:Graph(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", Values = "Default", Data = "Default" })
    -- A graph has nothing worth saving, so it never registers a flag.
    opts.Flag = nil
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local window = self.Window
    local page = self
    local plotHeight = math.max(math.floor(tonumber(opts.Height) or 90), 30)
    local maxPoints = math.clamp(math.floor(tonumber(opts.Points) or 40), 2, 500)
    local decimals = math.clamp(math.floor(tonumber(opts.Decimals) or 0), 0, 6)
    local suffix = tostring(opts.Suffix or "")
    local showLabels = opts.Labels ~= false
    local fillEnabled = opts.Fill ~= false
    local inset = 14
    local top = compact and 4 or 10
    local hasDesc = type(opts.Desc) == "string" and opts.Desc ~= ""
    local plotTop = top + metrics.TitleHeight + (hasDesc and (metrics.DescLine + 2) or 0) + 6
    local bottom = compact and 6 or 12
    -- Keeps the line and its head dot off the plot's edges.
    local padY = 4
    local padX = 4

    local frame, frameStroke = card(self, "Frame", plotTop + plotHeight + bottom, opts)
    hoverStroke(frame, frameStroke)

    local title = label({
        Position = UDim2.fromOffset(inset, top),
        Size = UDim2.new(1, -(inset * 2 + 96), 0, metrics.TitleHeight),
        Text = tostring(opts.Name or "Graph"),
        TextSize = metrics.TextSize,
        Parent = frame,
    })
    local valueLabel = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -inset, 0, top),
        Size = UDim2.fromOffset(96, metrics.TitleHeight),
        Text = "-",
        TextSize = 13,
        FontFace = Fonts.Bold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = frame,
    })
    if hasDesc then
        label({
            Position = UDim2.fromOffset(inset, top + metrics.TitleHeight + 1),
            Size = UDim2.new(1, -inset * 2, 0, metrics.DescLine),
            Text = opts.Desc,
            TextSize = metrics.DescSize,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = frame,
        })
    end

    local plot = create("Frame", {
        Position = UDim2.fromOffset(inset, plotTop),
        Size = UDim2.new(1, -inset * 2, 0, plotHeight),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(plot, UDim.new(0, 6))
    stroke(plot, Theme.Stroke)
    -- Faint gridlines at a quarter, half and three quarters of the drawn range.
    for _, fraction in ipairs({ 0.25, 0.5, 0.75 }) do
        create("Frame", {
            Position = UDim2.new(0, 0, fraction, math.floor(padY * (1 - 2 * fraction) + 0.5)),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.Stroke,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ZIndex = 1,
            Parent = plot,
        })
    end
    -- Separate layers keep the draw order fixed however the pools grow.
    local fillLayer = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = plot,
    })
    local lineLayer = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = plot,
    })
    local head = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(5, 5),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 4,
        Parent = plot,
    })
    corner(head, UDim.new(1, 0))
    local maxLabel, minLabel
    if showLabels then
        maxLabel = label({
            Position = UDim2.fromOffset(5, 2),
            Size = UDim2.new(0.5, 0, 0, 12),
            Text = "",
            TextSize = 10,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            ZIndex = 5,
            Parent = plot,
        })
        minLabel = label({
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 5, 1, -2),
            Size = UDim2.new(0.5, 0, 0, 12),
            Text = "",
            TextSize = 10,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            ZIndex = 5,
            Parent = plot,
        })
    end

    local handle = { Color = opts.Color or "Accent", Value = nil, _listeners = {} }
    local values = {}
    local segments, bars = {}, {}
    local fixedMin = type(opts.Min) == "number" and opts.Min or nil
    local fixedMax = type(opts.Max) == "number" and opts.Max or nil
    local pending = false

    local function lineColor()
        return Library._color(handle.Color) or Theme.Accent
    end

    local function format(value)
        return string.format("%." .. decimals .. "f", value)
    end

    -- tween(..., 0) assigns the colour and keeps its theme binding in step,
    -- so theme keys follow a theme change and custom colours stay put.
    local function paintObject(object, property, color)
        tween(object, { [property] = color }, 0)
    end

    local function newSegment()
        local segment = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BorderSizePixel = 0,
            Visible = false,
            Parent = lineLayer,
        })
        paintObject(segment, "BackgroundColor3", lineColor())
        return segment
    end

    local function newBar()
        local bar = create("Frame", {
            BorderSizePixel = 0,
            Visible = false,
            Parent = fillLayer,
        })
        -- Fades from a faint tint under the line to nothing at the bottom.
        create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new(0.8, 1),
            Parent = bar,
        })
        paintObject(bar, "BackgroundColor3", lineColor())
        return bar
    end

    local function paint()
        local color = lineColor()
        paintObject(valueLabel, "TextColor3", color)
        paintObject(head, "BackgroundColor3", color)
        for _, segment in ipairs(segments) do
            paintObject(segment, "BackgroundColor3", color)
        end
        for _, bar in ipairs(bars) do
            paintObject(bar, "BackgroundColor3", color)
        end
    end

    -- The drawn range: fixed ends where given, the data's range (plus a little
    -- headroom) otherwise. Never returns an empty span.
    local function range()
        local low, high = fixedMin, fixedMax
        if low == nil or high == nil then
            local dataLow, dataHigh = math.huge, -math.huge
            for _, value in ipairs(values) do
                dataLow = math.min(dataLow, value)
                dataHigh = math.max(dataHigh, value)
            end
            if dataLow > dataHigh then
                dataLow, dataHigh = 0, 1
            end
            local span = dataHigh - dataLow
            local room = span > 1e-9 and span * 0.1 or math.max(math.abs(dataHigh) * 0.1, 1)
            low = low or (dataLow - room)
            high = high or (dataHigh + room)
        end
        if low > high then
            low, high = high, low
        end
        if high - low < 1e-9 then
            low, high = low - 1, high + 1
        end
        return low, high
    end

    local function redraw()
        pending = false
        if handle._destroyed or not plot.Parent then
            return
        end
        local count = #values
        local latest = values[count]
        handle.Value = latest
        valueLabel.Text = latest ~= nil and (format(latest) .. suffix) or "-"
        local low, high = range()
        if maxLabel then
            maxLabel.Text = count > 0 and format(high) or ""
            minLabel.Text = count > 0 and format(low) or ""
        end
        -- Offsets inside the plot are in unscaled units, like every other size.
        local scale = window and window.Scale and window.Scale.Scale or 1
        if scale <= 0 then
            scale = 1
        end
        local width = plot.AbsoluteSize.X / scale
        local height = plot.AbsoluteSize.Y / scale
        if width < 2 or height < 2 * padY + 2 then
            -- Not laid out yet; the AbsoluteSize change draws it.
            return
        end
        local usable = height - padY * 2
        local step = (width - padX * 2) / (maxPoints - 1)
        local offset = maxPoints - count
        local xs, ys = {}, {}
        for index = 1, count do
            xs[index] = padX + (offset + index - 1) * step
            local fraction = (values[index] - low) / (high - low)
            ys[index] = padY + (1 - math.clamp(fraction, 0, 1)) * usable
        end

        for index = 1, count - 1 do
            local segment = segments[index]
            if not segment then
                segment = newSegment()
                segments[index] = segment
            end
            local x1, y1, x2, y2 = xs[index], ys[index], xs[index + 1], ys[index + 1]
            local dx, dy = x2 - x1, y2 - y1
            -- One extra pixel of length closes the gaps at the joints.
            segment.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
            segment.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 2)
            segment.Rotation = math.deg(math.atan2(dy, dx))
            segment.Visible = true
        end
        for index = math.max(count, 1), #segments do
            segments[index].Visible = false
        end

        if fillEnabled then
            for index = 1, count - 1 do
                local bar = bars[index]
                if not bar then
                    bar = newBar()
                    bars[index] = bar
                end
                -- Whole-pixel edges so neighbouring bars neither gap nor overlap.
                local left = math.floor(xs[index] + 0.5)
                local right = math.floor(xs[index + 1] + 0.5)
                local barTop = math.floor((ys[index] + ys[index + 1]) / 2 + 0.5)
                bar.Position = UDim2.fromOffset(left, barTop)
                bar.Size = UDim2.fromOffset(math.max(right - left, 1), math.max(math.ceil(height) - barTop, 0))
                bar.Visible = true
            end
        end
        for index = fillEnabled and math.max(count, 1) or 1, #bars do
            bars[index].Visible = false
        end

        if count > 0 then
            head.Position = UDim2.fromOffset(xs[count], ys[count])
            head.Visible = true
        else
            head.Visible = false
        end
    end

    -- Several changes in one frame draw once.
    local function schedule()
        if pending then
            return
        end
        pending = true
        task.defer(redraw)
    end

    local function clean(value)
        value = tonumber(value)
        -- NaN and infinities would wreck the scale.
        if value == nil or value ~= value or math.abs(value) == math.huge then
            return nil
        end
        return value
    end

    function handle:Push(value)
        value = clean(value)
        if value == nil or handle._destroyed then
            return
        end
        table.insert(values, value)
        while #values > maxPoints do
            table.remove(values, 1)
        end
        handle.Value = value
        schedule()
    end
    handle.Set = handle.Push
    handle.Add = handle.Push

    -- Replaces every value; only the last Points numbers are kept.
    function handle:SetValues(list)
        if type(list) ~= "table" or handle._destroyed then
            return
        end
        local nextValues = {}
        for _, value in ipairs(list) do
            value = clean(value)
            if value ~= nil then
                table.insert(nextValues, value)
            end
        end
        while #nextValues > maxPoints do
            table.remove(nextValues, 1)
        end
        values = nextValues
        handle.Value = values[#values]
        schedule()
    end

    function handle:Clear()
        values = {}
        handle.Value = nil
        schedule()
    end

    function handle:Get()
        return table.clone(values)
    end

    function handle:SetColor(color)
        handle.Color = color or "Accent"
        paint()
    end

    -- nil for either end scales that end to the data.
    function handle:SetRange(min, max)
        fixedMin = type(min) == "number" and min or nil
        fixedMax = type(max) == "number" and max or nil
        schedule()
    end

    function handle:SetName(text)
        text = tostring(text or "")
        title.Text = text
        handle._searchName = text
        handle._searchKey = string.lower(text)
    end

    local rate = math.max(tonumber(opts.UpdateRate) or 1, 0.05)
    function handle:SetUpdateRate(seconds)
        rate = math.max(tonumber(seconds) or rate, 0.05)
    end

    onTheme(plot, paint)
    local sizeConnection = plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
    table.insert(handle._listeners, function()
        sizeConnection:Disconnect()
    end)

    -- Polls only while someone can see it: window open and not minimized, its
    -- tab and sub tab showing, and neither it nor its groupbox hidden.
    local function onScreen()
        if not window or window._destroyed or not window.Open or not handle._userVisible or handle._dependHidden then
            return false
        end
        -- A folded groupbox hides the graph as surely as another tab does.
        if page._groupbox and type(page.IsCollapsed) == "function" and page:IsCollapsed() then
            return false
        end
        -- A popped-out groupbox floats over every tab and stays up while minimized.
        if page._groupbox and page._popped then
            return page._userVisible ~= false
        end
        if window.Minimized then
            return false
        end
        local current = page
        if current._groupbox then
            if current._userVisible == false then
                return false
            end
            current = current.Parent
        end
        if current._isSubTab then
            if current.Parent.CurrentSubTab ~= current then
                return false
            end
            current = current.Parent
        end
        return window.CurrentTab == current
    end

    if type(opts.Update) == "function" then
        local alive = true
        local warned = false
        table.insert(handle._listeners, function()
            alive = false
        end)
        task.defer(function()
            local first = true
            while alive and frame.Parent do
                if first or onScreen() then
                    first = false
                    local ok, result = isolatedCall(opts.Update)
                    if ok then
                        if result ~= nil and alive then
                            handle:Push(result)
                        end
                    elseif not warned then
                        warned = true
                        warn("[KaitUI] graph update error: " .. tostring(result))
                    end
                end
                task.wait(rate)
            end
        end)
    end

    if type(opts.Default) == "table" then
        handle:SetValues(opts.Default)
    else
        schedule()
    end
    return finishElement(self, opts, handle, frame, "Graph")
end

Tab.CreateGraph = Tab.Graph

-- Textarea: a multi-line text box under the name. It shows Lines rows and
-- scrolls past them, keeping the caret in view while typing.
-- No top-level locals here: the library function is close to Luau's limit.
function Tab:Textarea(opts)
    local frame, frameStroke
    opts, frame, frameStroke = beginElement(self, opts, { Title = "Name", Description = "Desc", PlaceholderText = "Placeholder", CurrentValue = "Default", Value = "Default", Text = "Default", Rows = "Lines", MaxLines = "Lines", Max = "MaxLength", CharacterLimit = "MaxLength" }, "Frame")
    -- Text is only an alias for the starting text; left set, search would use it as the name.
    opts.Text = nil
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local inset = compact and 14 or 8
    local hasName = type(opts.Name) == "string" and opts.Name ~= ""
    local hasHead = hasName or opts.Desc ~= nil
    local titleTop = compact and 4 or 10
    local textSize = compact and 13 or 14
    local LINE_HEIGHT = 1.15
    local lineStep = textSize * LINE_HEIGHT
    local lines = math.clamp(math.floor(tonumber(opts.Lines) or 4), 1, 30)
    local padX, padY = 8, 6
    local viewHeight = math.ceil(lines * lineStep) + padY * 2
    local maxLength = tonumber(opts.MaxLength)
    if maxLength then
        maxLength = math.max(math.floor(maxLength), 1)
    end
    local font = opts.Monospace and Font.fromEnum(Enum.Font.Code) or Fonts.Regular
    local headHeight = (hasName and 22 or 0) + (opts.Desc and (hasName and 16 or 20) or 0)
    local boxTop = hasHead and (titleTop + headHeight) or (compact and 4 or inset)
    local counterHeight = maxLength and 16 or 0
    local bottom = compact and 6 or inset
    frame.Size = UDim2.new(1, 0, 0, boxTop + viewHeight + counterHeight + bottom)

    local title
    if hasHead then
        if hasName then
            title = label({
                Position = UDim2.fromOffset(14, titleTop),
                Size = UDim2.new(1, -28, 0, metrics.TitleHeight),
                Text = opts.Name,
                TextSize = metrics.TextSize,
                Parent = frame,
            })
        end
        if opts.Desc then
            label({
                Position = UDim2.fromOffset(14, hasName and (titleTop + metrics.TitleHeight + 1) or titleTop),
                Size = UDim2.new(1, -28, 0, metrics.DescLine),
                Text = tostring(opts.Desc),
                TextSize = metrics.DescSize,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                Parent = frame,
            })
        end
    end

    local holder = create("Frame", {
        Position = UDim2.fromOffset(inset, boxTop),
        Size = UDim2.new(1, -inset * 2, 0, viewHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(holder, UDim.new(0, 6))
    local holderStroke = stroke(holder)
    local scroller = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = holder,
    })
    padding(scroller, padX, padX, padY, padY)

    -- Trims to MaxLength characters (UTF-8 aware).
    local function clip(text)
        text = tostring(text == nil and "" or text)
        if not maxLength then
            return text
        end
        local count = utf8.len(text)
        if not count then
            return #text > maxLength and string.sub(text, 1, maxLength) or text
        end
        if count <= maxLength then
            return text
        end
        local cut = utf8.offset(text, maxLength + 1)
        return cut and string.sub(text, 1, cut - 1) or text
    end

    local lastText = clip(opts.Default)
    -- The box grows with its text (never below the visible area, so a click
    -- anywhere in it focuses) and the scroller's canvas follows.
    local box = create("TextBox", {
        Size = UDim2.new(1, 0, 0, viewHeight - padY * 2),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = lastText,
        PlaceholderText = tostring(opts.Placeholder or ""),
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = textSize,
        FontFace = font,
        MultiLine = true,
        ClearTextOnFocus = false,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = LINE_HEIGHT,
        Parent = scroller,
    })
    -- Same width, font and wrapping as the box: the text before the caret is
    -- laid out here to find how far down the caret sits.
    local measure = label({
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = textSize,
        FontFace = font,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = LINE_HEIGHT,
        Visible = false,
        Parent = scroller,
    })

    local counter = maxLength and label({
        Position = UDim2.fromOffset(inset, boxTop + viewHeight + 2),
        Size = UDim2.new(1, -inset * 2, 0, 14),
        TextSize = 11,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = frame,
    }) or nil
    local function updateCounter(text)
        if not counter then
            return
        end
        local count = utf8.len(text) or #text
        counter.Text = count .. "/" .. maxLength
        tween(counter, { TextColor3 = count >= maxLength and Theme.Warning or Theme.Muted }, 0.15)
    end

    local handle = { Value = lastText }
    local focused = false

    -- Scrolls just enough to show the caret's line. TextBounds are read in
    -- layout units and the canvas in screen pixels, as the dropdown list does.
    local function followCaret()
        if not focused or handle._destroyed or not box:IsFocused() then
            return
        end
        local cursor = box.CursorPosition
        if cursor < 1 then
            return
        end
        measure.Text = "|"
        local oneLine = measure.TextBounds.Y
        measure.Text = string.sub(box.Text, 1, cursor - 1) .. "|"
        local upto = measure.TextBounds.Y
        if oneLine <= 0 or upto <= 0 then
            return
        end
        local view = scroller.AbsoluteWindowSize.Y
        local unit = view / viewHeight
        if unit <= 0 then
            return
        end
        local caretBottom = (padY + upto) * unit
        local caretTop = caretBottom - oneLine * unit
        local y = scroller.CanvasPosition.Y
        if caretTop < y + padY * unit then
            y = caretTop - padY * unit
        elseif caretBottom > y + view - padY * unit then
            y = caretBottom - view + padY * unit
        end
        local maxScroll = math.max(scroller.AbsoluteCanvasSize.Y - view, 0)
        y = math.clamp(y, 0, maxScroll)
        if math.abs(y - scroller.CanvasPosition.Y) > 0.5 then
            scroller.CanvasPosition = Vector2.new(0, y)
        end
    end
    local followQueued = false
    local function queueFollow()
        if followQueued then
            return
        end
        followQueued = true
        task.defer(function()
            followQueued = false
            followCaret()
        end)
    end

    -- Property signals may run deferred, so changes made here or by Set are
    -- told apart by comparing with lastText rather than with a flag.
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local raw = box.Text
        local text = clip(raw)
        if raw ~= text then
            local cursor = box.CursorPosition
            box.Text = text
            box.CursorPosition = math.min(cursor, #text + 1)
        end
        if text == lastText then
            return
        end
        lastText = text
        handle.Value = text
        updateCounter(text)
        queueFollow()
        safeCall(opts.OnChanged, text)
    end)
    box:GetPropertyChangedSignal("CursorPosition"):Connect(queueFollow)
    box:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueFollow)

    box.Focused:Connect(function()
        focused = true
        tween(holderStroke, { Color = Theme.Accent }, 0.15)
        queueFollow()
    end)
    box.FocusLost:Connect(function()
        focused = false
        tween(holderStroke, { Color = Theme.Stroke }, 0.15)
        safeCall(opts.Callback, clip(box.Text))
    end)
    holder.MouseEnter:Connect(function()
        if not focused then
            tween(holderStroke, { Color = Theme.StrokeHover }, 0.12)
        end
    end)
    holder.MouseLeave:Connect(function()
        if not focused then
            tween(holderStroke, { Color = Theme.Stroke }, 0.25)
        end
    end)

    function handle:Set(value, silent)
        local text = clip(value)
        local before = lastText
        lastText = text
        handle.Value = text
        box.Text = text
        updateCounter(text)
        flashStroke(frameStroke)
        -- Configs load through here, so the script hears the loaded text.
        if not silent and text ~= before then
            safeCall(opts.OnChanged, text)
            safeCall(opts.Callback, text)
        end
    end

    function handle:Get()
        return clip(box.Text)
    end

    function handle:SetPlaceholder(text)
        box.PlaceholderText = tostring(text == nil and "" or text)
    end

    function handle:SetTitle(text)
        if title then
            title.Text = tostring(text)
        end
    end

    function handle:Focus()
        box:CaptureFocus()
    end

    -- Hiding (or a collapsing groupbox) lets go of the keyboard.
    handle._onHide = function()
        if box:IsFocused() then
            box:ReleaseFocus()
        end
    end

    updateCounter(lastText)
    return finishElement(self, opts, handle, frame, "Textarea")
end

Tab.CreateTextarea = Tab.Textarea
Tab.TextArea = Tab.Textarea
Tab.CreateTextArea = Tab.Textarea

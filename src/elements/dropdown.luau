function Tab:Dropdown(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentOption = "Default", Value = "Default", MultipleOptions = "Multi", Values = "Options" })
    if opts.Multi and type(opts.Default) ~= "table" and opts.Default ~= nil then
        opts.Default = { opts.Default }
    elseif not opts.Multi and type(opts.Default) == "table" then
        opts.Default = opts.Default[1]
    end
    local multi = opts.Multi == true
    local options = opts.Options or {}
    local frame, frameStroke, height
    opts, frame, frameStroke, height = beginElement(self, opts, {}, "Frame")
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local chipHeight = metrics.Chip
    local window = self.Window
    local ROW = TOUCH and 34 or 22
    local MAX_ROWS = math.max(tonumber(opts.MaxRows) or 6, 1)
    -- Stacked (the default in compact rows): the chip spans the whole row,
    -- with the name (if any) above it.
    local stacked = compact and opts.Stacked ~= false
    local stackTop = 2
    if stacked then
        stackTop = (opts.Name or "") ~= "" and 20 or 2
        chipHeight = TOUCH and 34 or 30
        height = stackTop + chipHeight + 4
        frame.Size = UDim2.new(1, 0, 0, height)
    end

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    local titleLabel, descLabel
    if not stacked then
        titleLabel, descLabel = titleDesc(header, opts.Name or "Dropdown", opts.Desc, 180, metrics)
    elseif stackTop > 2 then
        titleLabel = label({
            Position = UDim2.fromOffset(14, 1),
            Size = UDim2.new(1, -28, 0, 16),
            Text = opts.Name,
            TextSize = metrics.TextSize,
            Parent = header,
        })
    end

    local chip = create("Frame", {
        AnchorPoint = stacked and Vector2.zero or Vector2.new(1, 0.5),
        Position = stacked and UDim2.fromOffset(14, stackTop) or UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(60, chipHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = header,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    local valueLabel = label({
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = chip,
    })
    local arrow = arrowIndicator(chip, 1, -6)
    local measure = label({
        Size = UDim2.fromOffset(0, chipHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 13,
        Visible = false,
        Parent = chip,
    })
    local fullText = ""
    local function trimmed()
        local maxText = (stacked and frame.AbsoluteSize.X / window.Scale.Scale - 28 or compact and rowControlWidth(frame, window) or 190) - 10 - 34
        measure.Text = fullText
        if measure.TextBounds.X <= maxText then
            return fullText
        end
        local text = fullText
        while #text > 1 do
            text = text:sub(1, -2)
            measure.Text = text .. ".."
            if measure.TextBounds.X <= maxText then
                return text .. ".."
            end
        end
        return ".."
    end
    -- Multi picks that overflow the chip scroll sideways in a loop instead
    -- of truncating, so every selected value comes past.
    local marqueeText = label({
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = valueLabel,
    })
    local marqueeStep, marqueeOffset, marqueeWanted = nil, 0, false
    local marqueeLoop = 1
    local function updateMarquee(scroll)
        -- Performance Mode keeps the plain truncated text.
        local overflowing = scroll and valueLabel.Text ~= fullText and not Library.PerformanceMode
        if not overflowing then
            if marqueeStep then
                marqueeStep:Disconnect()
                marqueeStep = nil
            end
            marqueeText.Visible = false
            valueLabel.TextTransparency = 0
            return
        end
        local gap = "     •     "
        marqueeText.Text = fullText .. gap .. fullText
        marqueeText.TextColor3 = valueLabel.TextColor3
        marqueeText.Visible = true
        valueLabel.TextTransparency = 1
        -- Measured once per text change, not every frame.
        measure.Text = fullText .. gap
        marqueeLoop = math.max(measure.TextBounds.X, 1)
        if not marqueeStep then
            marqueeOffset = 0
            marqueeStep = RunService.Heartbeat:Connect(function(deltaTime)
                if not marqueeText.Parent then
                    marqueeStep:Disconnect()
                    marqueeStep = nil
                    return
                end
                -- Nothing to scroll for while the window is hidden or minimized.
                if not window.Open or window.Minimized then
                    return
                end
                marqueeOffset = (marqueeOffset + deltaTime * 28) % marqueeLoop
                marqueeText.Position = UDim2.fromOffset(-marqueeOffset, 0)
                if marqueeText.TextColor3 ~= valueLabel.TextColor3 then
                    marqueeText.TextColor3 = valueLabel.TextColor3
                end
            end)
        end
    end
    local function fitChip(instant)
        if stacked then
            chip.Size = UDim2.new(1, -28, 0, chipHeight)
            return
        end
        local width
        if compact then
            width = rowControlWidth(frame, window)
        else
            width = math.clamp(valueLabel.TextBounds.X + 10 + 34, 60, 190)
        end
        reserveRight(titleLabel, descLabel, width + (compact and 24 or 20))
        if instant then
            chip.Size = UDim2.fromOffset(width, chipHeight)
        else
            tween(chip, { Size = UDim2.fromOffset(width, chipHeight) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not compact then
            fitChip(false)
        end
    end)
    if compact then
        -- The chip follows the row every frame; re-measuring the text waits
        -- until the width stops changing so resizing stays cheap.
        local lastWidth, pending = 0, false
        frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            local width = frame.AbsoluteSize.X
            if width == lastWidth then
                return
            end
            lastWidth = width
            fitChip(true)
            if not pending then
                pending = true
                task.delay(0.12, function()
                    pending = false
                    valueLabel.Text = trimmed()
                    updateMarquee(marqueeWanted)
                end)
            end
        end)
    end

    -- Popup: floats over the window under the chip, with search, bulk
    -- actions for multi selection and a scrolling list of checkbox rows.
    -- The popup is a plain clipped frame that unfolds out of the chip, so text
    -- stays crisp. The shadow sits outside the clip.
    local popup = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(220, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 45,
        Parent = window.Body,
    })
    popup:SetAttribute("NoDrag", true)
    local popupShadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-18, -12),
        Size = UDim2.new(1, 36, 1, 36),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Parent = popup,
    })
    local panel = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = popup,
    })
    corner(panel, UDim.new(0, 10))
    local panelStroke = stroke(panel, Theme.Stroke, 1)
    edgeHighlight(panel)
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundTransparency = 1,
        Parent = panel,
    })
    padding(inner, 8, 8, 8, 8)

    local searchHolder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = inner,
    })
    corner(searchHolder, UDim.new(0, 7))
    local searchStroke = stroke(searchHolder)
    local searchIconHolder, searchIcon = glowIcon(searchHolder, "search", Theme.Muted, UDim2.new(0, 10, 0.5, 0))
    searchIconHolder.Size = UDim2.fromOffset(14, 14)
    local searchBox = create("TextBox", {
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = opts.SearchPlaceholder or "Search",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })
    searchBox.Focused:Connect(function()
        tween(searchStroke, { Color = Theme.StrokeHover }, 0.15)
        tween(searchIcon, { ImageColor3 = Theme.Accent }, 0.15)
    end)
    searchBox.FocusLost:Connect(function()
        tween(searchStroke, { Color = Theme.Stroke }, 0.2)
        tween(searchIcon, { ImageColor3 = Theme.Muted }, 0.2)
    end)

    local actions = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Visible = multi,
        Parent = inner,
    })
    local function actionButton(text, position)
        local button = create("TextButton", {
            Position = position,
            Size = UDim2.new(0.5, -3, 1, 0),
            BackgroundColor3 = Theme.Surface3,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            Parent = actions,
        })
        corner(button, UDim.new(0, 6))
        local buttonStroke = stroke(button)
        label({
            Size = UDim2.fromScale(1, 1),
            Text = text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = button,
        })
        button.MouseEnter:Connect(function()
            tween(button, { BackgroundTransparency = 0.05 }, 0.15)
            tween(buttonStroke, { Color = Theme.StrokeHover }, 0.15)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { BackgroundTransparency = 0.35 }, 0.25)
            tween(buttonStroke, { Color = Theme.Stroke }, 0.25)
        end)
        button.MouseButton1Click:Connect(function()
            ripple(button)
        end)
        return button
    end
    local selectAll = actionButton(opts.SelectAllText or "Select all", UDim2.fromOffset(0, 0))
    local clearAll = actionButton(opts.ClearAllText or "Clear all", UDim2.new(0.5, 3, 0, 0))

    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 100),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        -- Sized by hand: AutomaticCanvasSize under the window's UIScale
        -- sometimes leaves the canvas short, so the list would not scroll.
        CanvasSize = UDim2.new(),
        Parent = inner,
    })
    local noResults = label({
        Size = UDim2.new(1, 0, 0, ROW),
        Text = opts.NoResultsText or "No results",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 0,
        Visible = false,
        Parent = list,
    })

    local self_ = { Open = false }
    local selected = {}
    local filter = ""
    -- The list is virtual: only the rows in view exist, and they are reused
    -- as it scrolls, so thousands of options cost the same as a handful.
    local pool = {}
    local shown = {}
    local lowerKeys = {}
    local STEP = ROW + 2

    -- CanvasPosition is in screen pixels while rows are laid out in unscaled
    -- units, so under a UIScale the visible slice has to be scaled back.
    local function canvasScale()
        local logical = list.CanvasSize.Y.Offset
        return logical > 0 and list.AbsoluteCanvasSize.Y / logical or 1
    end

    local function lowerOf(option)
        local key = lowerKeys[option]
        if key == nil then
            -- OptionSearch(option) can add text the search matches but the row doesn't show.
            local extra = type(opts.OptionSearch) == "function" and opts.OptionSearch(option) or nil
            key = string.lower(tostring(option) .. (extra ~= nil and (" " .. tostring(extra)) or ""))
            lowerKeys[option] = key
        end
        return key
    end

    local function matches(option)
        return filter == "" or string.find(lowerOf(option), filter, 1, true) ~= nil
    end

    -- Option labels are rich text, so the part matching the search can light up.
    local function escapeRich(text)
        return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end
    local function optionText(option)
        local text = tostring(option)
        local at = filter ~= "" and string.find(string.lower(text), filter, 1, true)
        if not at then
            return escapeRich(text)
        end
        local stop = at + #filter - 1
        return escapeRich(text:sub(1, at - 1))
            .. '<font color="#' .. Theme.Accent:ToHex() .. '"><b>' .. escapeRich(text:sub(at, stop)) .. "</b></font>"
            .. escapeRich(text:sub(stop + 1))
    end

    if multi then
        for _, value in ipairs(opts.Default or {}) do
            selected[value] = true
        end
    elseif opts.Default ~= nil then
        selected[opts.Default] = true
    end

    local function currentValue()
        if multi then
            local picked = {}
            for _, option in ipairs(options) do
                if selected[option] then
                    table.insert(picked, option)
                end
            end
            return picked
        end
        for _, option in ipairs(options) do
            if selected[option] then
                return option
            end
        end
        return nil
    end

    -- Rows are plain text: the pick reads in the accent, hovering lifts any row.
    local function restRow(entry, duration)
        local on, hover = entry.On == true, entry.Hover == true
        tween(entry.Frame, { BackgroundTransparency = hover and 0.6 or 1 }, duration)
        tween(entry.Label, { TextColor3 = on and Theme.Accent or Theme.Text }, duration)
    end

    local function paintOption(button, animate)
        local on = selected[button.Option] == true
        if button.On == on and animate then
            return
        end
        button.On = on
        local duration = animate and 0.18 or 0
        restRow(button, duration)
        if multi then
            tween(button.Box, { BackgroundColor3 = on and Theme.Accent or Theme.Surface2 }, duration)
            tween(button.BoxStroke, { Color = on and Theme.Accent or Theme.Stroke }, duration)
        else
            tween(button.Bar, {
                BackgroundTransparency = on and 0 or 1,
                Size = UDim2.fromOffset(3, on and ROW - 10 or 4),
            }, animate and 0.3 or 0, Enum.EasingStyle.Quint)
        end
        tween(button.Check, { ImageTransparency = on and 0 or 1 }, duration)
        if animate and on then
            button.CheckScale.Scale = 0.5
            tween(button.CheckScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
        else
            button.CheckScale.Scale = 1
        end
    end

    local function renderValue(animate)
        local value = currentValue()
        if #options == 0 then
            fullText = opts.EmptyText or "None"
        elseif multi then
            local names = {}
            for index, item in ipairs(value) do
                names[index] = tostring(item)
            end
            fullText = #value > 0 and table.concat(names, ", ") or (opts.NoneText or "None")
        else
            fullText = value ~= nil and tostring(value) or (opts.NoneText or "None")
        end
        valueLabel.Text = trimmed()
        marqueeWanted = multi and #options > 0 and #value > 1
        updateMarquee(marqueeWanted)
        -- A picked value reads in full colour; "None" stays muted.
        local picked = #options > 0 and (if multi then #value > 0 else value ~= nil)
        tween(valueLabel, { TextColor3 = picked and Theme.Text or Theme.Muted }, animate and 0.15 or 0)
        for _, button in ipairs(pool) do
            if button.Option ~= nil then
                paintOption(button, animate)
            end
        end
    end

    local renderRows

    local function visibleCount()
        return #shown
    end

    local searchShown = true
    local targetSize = Vector2.new(220, 120)
    local opened = false
    local function layoutPopup(instant)
        searchShown = opts.Searchable ~= false and #options > (opts.SearchAfter or 0)
        searchHolder.Visible = searchShown
        local top = 0
        if searchShown then
            top += 38
        end
        actions.Position = UDim2.fromOffset(0, top)
        if multi and #options > 0 then
            actions.Visible = true
            top += 34
        else
            actions.Visible = false
        end
        local count = visibleCount()
        noResults.Visible = count == 0
        local rows = math.clamp(count, 1, MAX_ROWS)
        local listHeight = rows * ROW + (rows - 1) * 2
        list.CanvasSize = UDim2.fromOffset(0, math.max(count, 1) * (ROW + 2) - 2)
        local scale = window.Scale.Scale
        -- Shrink the list to whichever side of the chip has more room, so the
        -- popup never runs off a short window (phones in landscape).
        local host = window:_popupHost(frame)
        local bodyHeight = host.AbsoluteSize.Y / scale
        local chipTop = (chip.AbsolutePosition.Y - host.AbsolutePosition.Y) / scale
        local room = math.max(bodyHeight - (chipTop + chip.AbsoluteSize.Y / scale) - 14, chipTop - 14) - top - 16
        if room >= ROW then
            listHeight = math.min(listHeight, room)
        end
        list.Position = UDim2.fromOffset(0, top)
        list.Size = UDim2.new(1, 0, 0, listHeight)
        renderRows()
        local width = math.max(math.floor(chip.AbsoluteSize.X / scale), opts.PopupWidth or 210)
        local bodyWidth = host.AbsoluteSize.X / scale
        width = math.min(width, math.max(bodyWidth - 16, 120))
        targetSize = Vector2.new(width, top + listHeight + 16)
        inner.Size = UDim2.new(1, 0, 0, targetSize.Y)
        if not opened then
            return
        end
        if instant then
            popup.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
        else
            tween(popup, { Size = UDim2.fromOffset(targetSize.X, targetSize.Y) }, 0.22, Enum.EasingStyle.Quint)
        end
    end

    local function applyFilter()
        if filter == "" then
            shown = options
        else
            shown = {}
            for _, option in ipairs(options) do
                if matches(option) then
                    table.insert(shown, option)
                end
            end
        end
        renderRows()
    end

    local scroller = nil
    local function place()
        local body = window:_popupHost(frame)
        local scale = window.Scale.Scale
        if scroller then
            local centre = chip.AbsolutePosition + chip.AbsoluteSize / 2
            if not pointInside(centre, scroller) then
                self_:SetOpen(false)
                return
            end
        end
        local bodySize = body.AbsoluteSize / scale
        local chipPosition = (chip.AbsolutePosition - body.AbsolutePosition) / scale
        local chipSize = chip.AbsoluteSize / scale
        local right = math.clamp(chipPosition.X + chipSize.X, targetSize.X + 8, math.max(bodySize.X - 8, targetSize.X + 8))
        local below = chipPosition.Y + chipSize.Y + 2
        -- Opening upward pins the content to the bottom edge so it unfolds from the chip.
        if below + targetSize.Y > bodySize.Y - 8 and chipPosition.Y - 2 - targetSize.Y >= 8 then
            popup.AnchorPoint = Vector2.new(1, 1)
            popup.Position = UDim2.fromOffset(right, chipPosition.Y - 2)
            inner.AnchorPoint = Vector2.new(0, 1)
            inner.Position = UDim2.fromScale(0, 1)
        else
            popup.AnchorPoint = Vector2.new(1, 0)
            popup.Position = UDim2.fromOffset(right, below)
            inner.AnchorPoint = Vector2.zero
            inner.Position = UDim2.fromScale(0, 0)
        end
    end

    local stopFollowing = nil
    local closeGeneration = 0
    -- The page behind stops scrolling while the popup is open, so wheel and
    -- swipe input always reach the list instead of dragging the page away.
    local lockedScroller = nil
    local function unlockScroller()
        if lockedScroller then
            lockedScroller.ScrollingEnabled = true
            lockedScroller = nil
        end
    end
    local function scrollToSelected()
        list.CanvasPosition = Vector2.zero
        if multi then
            return
        end
        local value = currentValue()
        if value == nil then
            return
        end
        local index = table.find(shown, value)
        if index then
            list.CanvasPosition = Vector2.new(0, math.max(0, (index - 2) * STEP) * canvasScale())
        end
    end
    local function setOpen(open)
        if open == self_.Open then
            return
        end
        self_.Open = open
        arrow:Set(open)
        tween(chipStroke, { Color = open and Theme.Accent or Theme.Stroke, Transparency = open and 0.35 or 0 }, 0.2)
        tween(chip, { BackgroundColor3 = open and Theme.Surface or Theme.Background }, 0.2)
        closeGeneration += 1
        if open then
            if window._closePopup and window._closePopup ~= self_._close then
                window._closePopup()
            end
            window._closePopup = self_._close
            scroller = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
            if scroller and scroller.ScrollingEnabled then
                lockedScroller = scroller
                scroller.ScrollingEnabled = false
            end
            -- Drawn over a floating panel when the dropdown lives in one.
            popup.Parent = window:_popupHost(frame)
            filter = ""
            searchBox.Text = ""
            searchBox.PlaceholderText = opts.SearchPlaceholder or (#options > 6 and ("Search " .. #options .. " options") or "Search")
            applyFilter()
            layoutPopup(true)
            renderValue(false)
            scrollToSelected()
            opened = true
            popup.Size = UDim2.fromOffset(targetSize.X, 0)
            place()
            popup.Visible = true
            tween(popup, { Size = UDim2.fromOffset(targetSize.X, targetSize.Y) }, 0.3, Enum.EasingStyle.Quint)
            tween(panelStroke, { Transparency = 0 }, 0.12)
            tween(popupShadow, { ImageTransparency = 0.4 }, 0.3)
            if not stopFollowing then
                stopFollowing = window:_listen("Render", place)
            end
        else
            if window._closePopup == self_._close then
                window._closePopup = nil
            end
            unlockScroller()
            if searchBox:IsFocused() then
                searchBox:ReleaseFocus()
            end
            opened = false
            tween(popup, { Size = UDim2.fromOffset(targetSize.X, 0) }, 0.2, Enum.EasingStyle.Quint)
            tween(popupShadow, { ImageTransparency = 1 }, 0.16)
            local generation = closeGeneration
            task.delay(0.14, function()
                if closeGeneration == generation and not self_.Open then
                    tween(panelStroke, { Transparency = 1 }, 0.06)
                end
            end)
            task.delay(0.21, function()
                if closeGeneration == generation and not self_.Open then
                    popup.Visible = false
                    if stopFollowing then
                        stopFollowing()
                        stopFollowing = nil
                    end
                end
            end)
        end
    end
    self_._close = function()
        setOpen(false)
    end

    local function commit()
        renderValue(true)
        safeCall(opts.Callback, currentValue())
    end

    local function newEntry()
        local row = create("TextButton", {
            Size = UDim2.new(1, -6, 0, ROW),
            BackgroundColor3 = Theme.Surface3,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Visible = false,
            Parent = list,
        })
        corner(row, UDim.new(0, 7))
        -- Multi selection ticks a checkbox on the left. A single pick
        -- gets an accent bar on the left edge.
        local box, boxStroke, bar, check
        if multi then
            box = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = Theme.Surface2,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(box, UDim.new(0, 5))
            boxStroke = stroke(box, Theme.Stroke)
            check = create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(12, 12),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.AccentDark,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = box,
            })
        else
            bar = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.fromOffset(3, 4),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(bar, UDim.new(1, 0))
            check = create("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Accent,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Visible = false,
                Parent = row,
            })
        end
        applyIcon(check, "check")
        local checkScale = create("UIScale", { Parent = check })
        -- OptionIcon(option) puts a small image before each option's text (an
        -- avatar, an item icon). Round, since most of these are headshots.
        local textLeft = multi and 36 or 14
        local optionIcon
        if type(opts.OptionIcon) == "function" then
            optionIcon = create("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, textLeft, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = Theme.Surface3,
                BackgroundTransparency = 0.4,
                ScaleType = Enum.ScaleType.Crop,
                Parent = row,
            })
            corner(optionIcon, UDim.new(1, 0))
            textLeft += 24
        end
        local text_ = label({
            Position = UDim2.fromOffset(textLeft, 0),
            Size = UDim2.new(1, -(textLeft + (multi and 8 or 32)), 1, 0),
            Text = "",
            TextSize = 13,
            TextColor3 = Theme.Text,
            RichText = true,
            Parent = row,
        })
        local entry = { Option = nil, Frame = row, Box = box, BoxStroke = boxStroke, Bar = bar, Check = check, CheckScale = checkScale, Label = text_, Icon = optionIcon, On = nil, Hover = false }
        local isTap = tapGuard(row, function()
            return list
        end)
        row.MouseEnter:Connect(function()
            -- Touch fires enter without a matching leave; skip the hover.
            if usingTouch() then
                return
            end
            entry.Hover = true
            restRow(entry, 0.15)
            if boxStroke and not selected[entry.Option] then
                tween(boxStroke, { Color = Theme.StrokeHover }, 0.15)
            end
        end)
        row.MouseLeave:Connect(function()
            entry.Hover = false
            restRow(entry, 0.25)
            if boxStroke and not selected[entry.Option] then
                tween(boxStroke, { Color = Theme.Stroke }, 0.25)
            end
        end)
        row.MouseButton1Click:Connect(function()
            local option = entry.Option
            if option == nil or not isTap() then
                return
            end
            if selected[option] then
                if not multi and opts.AllowNone == false then
                    setOpen(false)
                    return
                end
                selected[option] = nil
            else
                if not multi then
                    selected = {}
                end
                selected[option] = true
            end
            commit()
            if not multi then
                setOpen(false)
            end
        end)
        return entry
    end

    -- Binds the pool to the rows in view: row i of the filtered list sits at
    -- (i - 1) * STEP in the canvas.
    renderRows = function()
        if not self_.Open then
            return
        end
        -- Each index keeps the same pool slot while it stays in view (slot =
        -- index mod count), so scrolling only rebinds rows entering the edge
        -- instead of reshuffling every row each step.
        local first = math.max(math.floor(list.CanvasPosition.Y / canvasScale() / STEP), 1)
        local count = math.ceil(list.Size.Y.Offset / STEP) + 3
        for slot = 1, math.max(count, #pool) do
            local index = slot <= count and first + (slot - first) % count or 0
            local option = slot <= count and shown[index] or nil
            local entry = pool[slot]
            if option == nil then
                if entry then
                    entry.Frame.Visible = false
                    entry.Option = nil
                end
            else
                if not entry then
                    entry = newEntry()
                    pool[slot] = entry
                end
                entry.Frame.Position = UDim2.fromOffset(0, (index - 1) * STEP)
                local text = optionText(option)
                local fresh = entry.Option ~= option
                if fresh or entry.Text ~= text then
                    entry.Text = text
                    entry.Label.Text = text
                end
                if fresh then
                    entry.Option = option
                    entry.On = nil
                    paintOption(entry, false)
                    if entry.Icon then
                        local ok, icon = pcall(opts.OptionIcon, option)
                        entry.Icon.Image = ""
                        if ok and icon ~= nil then
                            if typeof(icon) ~= "table" and assetId(icon) then
                                -- Scale 1: pictures fill their round slot, unlike padded uploads.
                                icon = { Image = icon, Scale = 1 }
                            end
                            -- A lucide name stays themed; pictures keep their own colours.
                            tween(entry.Icon, { ImageColor3 = Theme.Muted }, 0)
                            applyIcon(entry.Icon, icon)
                        end
                    end
                end
                entry.Frame.Visible = true
            end
        end
    end
    list:GetPropertyChangedSignal("CanvasPosition"):Connect(renderRows)

    local function buildOptions()
        table.clear(lowerKeys)
        for _, entry in ipairs(pool) do
            entry.Option = nil
        end
        applyFilter()
        if self_.Open then
            layoutPopup(false)
        end
    end

    selectAll.MouseButton1Click:Connect(function()
        for _, option in ipairs(shown) do
            selected[option] = true
        end
        commit()
    end)
    clearAll.MouseButton1Click:Connect(function()
        selected = {}
        commit()
    end)

    function self_:Set(value, silent)
        selected = {}
        if multi then
            for _, item in ipairs(type(value) == "table" and value or { value }) do
                selected[item] = true
            end
        elseif value ~= nil then
            selected[value] = true
        end
        renderValue(self_.Open)
        flashStroke(frameStroke)
        if not silent then
            safeCall(opts.Callback, currentValue())
        end
    end

    function self_:Get()
        return currentValue()
    end

    local function sameValue(a, b)
        if type(a) ~= "table" or type(b) ~= "table" then
            return a == b
        end
        if #a ~= #b then
            return false
        end
        for index, item in ipairs(a) do
            if b[index] ~= item then
                return false
            end
        end
        return true
    end

    -- A kept pick only counts once its option exists, so a list filled in after a
    -- config load changes the value; the callback runs so scripts see it.
    function self_:Refresh(newOptions, keepSelection, silent)
        local before = currentValue()
        options = newOptions or {}
        if not keepSelection then
            selected = {}
        end
        buildOptions()
        renderValue(false)
        if not silent and not sameValue(before, currentValue()) then
            safeCall(opts.Callback, currentValue())
        end
    end

    -- SetOptions(list, { KeepSelection = true, Silent = false }): replace the
    -- options. Picks are kept by default; a boolean works as KeepSelection.
    function self_:SetOptions(newOptions, settings)
        local keep, silent = true, false
        if type(settings) == "boolean" then
            keep = settings
        elseif type(settings) == "table" then
            local wanted = settings.KeepSelection
            if wanted == nil then
                wanted = settings.keepSelection
            end
            if wanted ~= nil then
                keep = wanted ~= false
            end
            silent = settings.Silent == true or settings.silent == true
        end
        self_:Refresh(newOptions, keep, silent)
    end

    function self_:GetOptions()
        return table.clone(options)
    end

    -- Every pick, including ones whose option isn't in the list right now, so
    -- saving never drops them.
    function self_:_saveValue()
        local picked = currentValue()
        if multi then
            local seen = {}
            for _, item in ipairs(picked) do
                seen[item] = true
            end
            for item in pairs(selected) do
                if not seen[item] then
                    table.insert(picked, item)
                end
            end
            return picked
        end
        if picked == nil then
            picked = next(selected)
        end
        return picked
    end

    function self_:SetOpen(open)
        setOpen(open == true)
    end

    local headerTap = tapGuard(header, function()
        return frame:FindFirstAncestorWhichIsA("ScrollingFrame")
    end)
    header.MouseButton1Click:Connect(function()
        if headerTap() then
            setOpen(not self_.Open)
        end
    end)
    -- The chip answers the pointer before it is opened.
    header.MouseEnter:Connect(function()
        if not self_.Open and not usingTouch() then
            tween(chipStroke, { Color = Theme.StrokeHover }, 0.15)
            tween(chip, { BackgroundColor3 = Theme.Surface }, 0.15)
        end
    end)
    header.MouseLeave:Connect(function()
        if not self_.Open then
            tween(chipStroke, { Color = Theme.Stroke }, 0.25)
            tween(chip, { BackgroundColor3 = Theme.Background }, 0.25)
        end
    end)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        filter = string.lower(searchBox.Text)
        list.CanvasPosition = Vector2.zero
        applyFilter()
        if self_.Open then
            layoutPopup(false)
        end
    end)
    self_._listeners = {
        function()
            setOpen(false)
            unlockScroller()
            if stopFollowing then
                stopFollowing()
                stopFollowing = nil
            end
            popup:Destroy()
        end,
    }
    window:_listen("Began", function(input)
        if not self_.Open then
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            setOpen(false)
        elseif isPress(input) then
            local point = pointerPosition()
            if not pointInside(point, popup) and not pointInside(point, header) then
                setOpen(false)
            end
        end
    end, self_)

    buildOptions()
    renderValue(false)
    task.defer(fitChip, true)
    return finishElement(self, opts, self_, frame, "Dropdown")
end

Library._amountSuffixes = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }


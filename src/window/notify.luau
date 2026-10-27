function Window:Notify(opts)
    -- Image used to be only another name for Icon. On its own it still is; next
    -- to an explicit Icon it becomes the larger picture on the left.
    local explicitIcon = type(opts) == "table" and opts.Icon or nil
    opts = normalize(opts, { Text = "Content", Message = "Content", Image = "Icon" })
    if self.Minimized and self._islandActivity then
        self._islandActivity(opts)
    end
    local duration = tonumber(opts.Duration) or 4
    local timed = opts.Duration ~= nil
    local titleColor = NOTIFY_COLORS[opts.Type] or Theme.Text
    local thumbnail = opts.Thumbnail
    if thumbnail == nil and explicitIcon ~= nil and opts.Image ~= nil and opts.Image ~= explicitIcon then
        thumbnail = opts.Image
    end

    self._notifyOrder = self._notifyOrder + 1
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = self._notifyOrder,
        Parent = self.NotifyHolder,
    })
    local slide = create("Frame", {
        Position = UDim2.fromOffset(320, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = outer,
    })
    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-20, -20),
        Size = UDim2.new(1, 40, 1, 40),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = slide,
    })
    local toast = create("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = slide,
    })
    corner(toast, UDim.new(0, 10))
    local toastStroke = stroke(toast, Theme.Stroke)
    edgeHighlight(toast)
    glow(toast, UDim2.fromOffset(260, 120), UDim2.new(1, -10, 0, -10), 0.86, 90)

    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = toast,
    })
    padding(inner, 16, 16, 14, 24)

    local leftOffset = 0
    if thumbnail ~= nil then
        local thumb = create("ImageLabel", {
            Size = UDim2.fromOffset(40, 40),
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Crop,
            Parent = inner,
        })
        corner(thumb, UDim.new(0, 8))
        applyIcon(thumb, thumbnail, true)
        leftOffset = 50
    end
    local titleOffset = leftOffset
    if opts.Icon then
        glowIcon(inner, opts.Icon, titleColor == Theme.Text and Theme.Accent or titleColor, UDim2.new(0, leftOffset, 0, 8))
        titleOffset = leftOffset + 24
    end
    local titleLabel = label({
        Position = UDim2.fromOffset(titleOffset, 0),
        Size = UDim2.new(1, -28 - titleOffset, 0, 16),
        Text = opts.Title or "Notification",
        TextSize = 14,
        TextColor3 = titleColor,
        Parent = inner,
    })
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 6, 0, -5),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 22,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        Parent = inner,
    })
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Text }, 0.15)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { TextColor3 = Theme.Muted }, 0.2)
    end)

    -- Content and buttons stack in one column under the title.
    local column, contentLabel = nil, nil
    local function ensureColumn()
        if column then
            return column
        end
        column = create("Frame", {
            Position = UDim2.fromOffset(titleOffset, 21),
            Size = UDim2.new(1, -titleOffset, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = inner,
        })
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = column,
        })
        return column
    end
    local function ensureContent()
        if contentLabel then
            return contentLabel
        end
        contentLabel = label({
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 1,
            Parent = ensureColumn(),
        })
        return contentLabel
    end
    if opts.Content then
        ensureContent().Text = tostring(opts.Content)
    end

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -8),
        Size = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Visible = opts.Progress ~= false,
        Parent = toast,
    })
    corner(track, UDim.new(1, 0))
    local progress = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(progress, UDim.new(1, 0))

    -- Manual progress (SetProgress, or a number for Progress) replaces the
    -- countdown on the bar and stops the auto close unless Duration was given.
    local manual = false
    if type(opts.Progress) == "number" then
        manual = true
        track.Visible = true
        progress.Size = UDim2.fromScale(math.clamp(opts.Progress, 0, 1), 1)
    end

    local entered = false
    local dismissed = false
    task.defer(function()
        -- A toast closed in its first frame (pushed out, or Close() right away) never grows.
        if outer.Parent and not dismissed then
            entered = true
            tween(outer, { Size = UDim2.new(1, 0, 0, toast.AbsoluteSize.Y) }, 0.3, Enum.EasingStyle.Quint)
        end
    end)
    tween(slide, { Position = UDim2.fromOffset(0, 0) }, 0.5, Enum.EasingStyle.Back)
    tween(toast, { GroupTransparency = 0 }, 0.3)
    tween(shadow, { ImageTransparency = 0.6 }, 0.4)

    local stopTimer = nil
    local function dismiss()
        if dismissed then
            return
        end
        dismissed = true
        if stopTimer then
            -- Deferred: this can run from inside the render dispatch loop.
            task.defer(stopTimer)
        end
        for index, entry in ipairs(self._toasts) do
            if entry == dismiss then
                table.remove(self._toasts, index)
                break
            end
        end
        tween(slide, { Position = UDim2.fromOffset(320, 0) }, 0.3, Enum.EasingStyle.Quint)
        tween(toast, { GroupTransparency = 1 }, 0.2)
        tween(toastStroke, { Transparency = 1 }, 0.15)
        tween(shadow, { ImageTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            outer.ClipsDescendants = true
            tween(outer, { Size = UDim2.new(1, 0, 0, -4) }, 0.22, Enum.EasingStyle.Quint)
            task.delay(0.24, function()
                outer:Destroy()
            end)
        end)
    end

    -- Text or buttons changed after it slid in: follow the new height.
    toast:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if entered and not dismissed then
            tween(outer, { Size = UDim2.new(1, 0, 0, toast.AbsoluteSize.Y) }, 0.2, Enum.EasingStyle.Quint)
        end
    end)

    -- The countdown runs on the window's render step so hovering can pause it.
    -- Hover is read from the pointer each tick rather than MouseEnter/Leave, which
    -- miss a toast sliding out from under a still cursor. The bar is redrawn at
    -- 15 Hz: it lives in a CanvasGroup, so each write re-renders the whole toast.
    local remaining = duration
    local sinceDraw = 0
    stopTimer = self:_listen("Render", function(deltaTime)
        if dismissed or (manual and not timed) then
            return
        end
        if not usingTouch() and pointInside(pointerPosition(), toast) then
            return
        end
        remaining -= deltaTime
        sinceDraw += deltaTime
        if not manual and sinceDraw >= (Library.PerformanceMode and 0.25 or 1 / 15) then
            sinceDraw = 0
            local fraction = (duration > 0 and duration < math.huge) and math.clamp(remaining / duration, 0, 1) or 1
            progress.Size = UDim2.fromScale(fraction, 1)
        end
        if remaining <= 0 then
            dismiss()
        end
    end)
    closeButton.MouseButton1Click:Connect(dismiss)

    if type(opts.Buttons) == "table" and #opts.Buttons > 0 then
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, TOUCH and 32 or 26),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Parent = ensureColumn(),
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = row,
        })
        local clicked = false
        for index = 1, math.min(#opts.Buttons, 3) do
            local spec = opts.Buttons[index]
            if type(spec) == "table" then
                local primary = (spec.Variant or spec.Style) == "Primary"
                local button = create("TextButton", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = primary and Theme.Accent or Theme.Surface3,
                    BackgroundTransparency = primary and 0.12 or 0.45,
                    BorderSizePixel = 0,
                    Text = tostring(spec.Title or spec.Name or spec.Text or "Button"),
                    TextColor3 = primary and Theme.AccentDark or Theme.Text,
                    TextSize = 13,
                    FontFace = Fonts.Medium,
                    AutoButtonColor = false,
                    LayoutOrder = index,
                    Parent = row,
                })
                corner(button, UDim.new(0, 6))
                stroke(button, primary and Theme.Accent or Theme.Stroke, primary and 0.4 or 0)
                padding(button, 10, 10)
                local rest = primary and 0.12 or 0.45
                button.MouseEnter:Connect(function()
                    tween(button, { BackgroundTransparency = math.max(rest - 0.15, 0) }, 0.15)
                end)
                button.MouseLeave:Connect(function()
                    tween(button, { BackgroundTransparency = rest }, 0.2)
                end)
                button.MouseButton1Click:Connect(function()
                    if clicked or dismissed then
                        return
                    end
                    clicked = true
                    dismiss()
                    safeCall(spec.Callback)
                end)
            end
        end
    end

    table.insert(self._toasts, dismiss)
    while #self._toasts > self.MaxNotifications do
        local oldest = table.remove(self._toasts, 1)
        oldest()
    end

    -- Every method works with both handle.Method(x) and handle:Method(x).
    local handle = {}
    local function argument(first, second)
        if first == handle then
            return second
        end
        return first
    end
    function handle.Dismiss()
        dismiss()
    end
    handle.Close = handle.Dismiss
    function handle.SetTitle(first, second)
        local text = argument(first, second)
        titleLabel.Text = tostring(text == nil and "" or text)
    end
    function handle.SetContent(first, second)
        local text = argument(first, second)
        text = tostring(text == nil and "" or text)
        if text == "" and not contentLabel then
            return
        end
        local target = ensureContent()
        target.Text = text
        target.Visible = text ~= ""
        -- An empty column (no text, no button row) would still push the toast down.
        column.Visible = text ~= "" or column:FindFirstChildWhichIsA("Frame") ~= nil
    end
    function handle.SetProgress(first, second)
        local fraction = tonumber(argument(first, second)) or 0
        manual = true
        track.Visible = true
        tween(progress, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }, 0.2)
    end
    function handle.IsOpen()
        return not dismissed
    end
    return handle
end

function Tab:Slider(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default", Increment = "Step" })
    local min = tonumber(opts.Min) or 0
    local max = tonumber(opts.Max) or 100
    -- Also covers Min = 200 with the default Max of 100.
    if min > max then
        min, max = max, min
    end
    local suffix = opts.Suffix or ""
    local numbers = numberFormat(min, max, opts.Step or 1)

    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local height = metrics.Slider
    local frame, frameStroke = card(self, "Frame", height, opts)
    hoverStroke(frame, frameStroke)

    label({
        Position = UDim2.fromOffset(14, compact and 5 or 12),
        Size = UDim2.new(1, -120, 0, 18),
        Text = opts.Name or "Slider",
        TextSize = metrics.TextSize,
        Parent = frame,
    })

    local valueChip = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, compact and -14 or -10, 0, compact and 2 or 9),
        Size = UDim2.fromOffset(40, 24),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(valueChip, UDim.new(0, 6))
    local chipStroke = stroke(valueChip)
    local valueLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = valueChip,
    })
    local valueBox = create("TextBox", {
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false,
        Parent = valueChip,
    })
    create("UISizeConstraint", { MinSize = Vector2.new(14, 0), Parent = valueBox })
    local suffixLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = suffix,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = valueChip,
    })
    local chipButton = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
        Parent = valueChip,
    })
    local editing = false
    local function fitChip(instant)
        local width
        if editing then
            width = 9 + valueBox.AbsoluteSize.X / (self.Window.Scale.Scale) + suffixLabel.TextBounds.X + 9
            suffixLabel.Position = UDim2.fromOffset(9 + valueBox.AbsoluteSize.X / (self.Window.Scale.Scale), 0)
        else
            width = valueLabel.TextBounds.X + 18
        end
        width = math.max(width, 36)
        if instant then
            valueChip.Size = UDim2.fromOffset(width, 24)
        else
            tween(valueChip, { Size = UDim2.fromOffset(width, 24) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not editing then
            fitChip(false)
        end
    end)
    valueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if editing then
            fitChip(false)
        end
    end)

    local track = create("Frame", {
        Position = UDim2.new(0, 14, 0, height - (compact and 13 or 18)),
        Size = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(track, UDim.new(1, 0))
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, UDim.new(1, 0))

    local knobGlow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.85,
        ZIndex = 2,
        Parent = track,
    })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    corner(knob, UDim.new(1, 0))

    local hit = create("TextButton", {
        Position = UDim2.new(0, 8, 0, height - (compact and 13 or 18) - (TOUCH and 19 or 13)),
        Size = UDim2.new(1, -16, 0, TOUCH and 40 or 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = frame,
    })

    local self_ = { Value = math.clamp(opts.Default or min, min, max) }
    local dragging = false
    chipButton.MouseEnter:Connect(function()
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    chipButton.MouseLeave:Connect(function()
        if not valueBox:IsFocused() then
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        end
    end)
    chipButton.MouseButton1Click:Connect(function()
        editing = true
        valueBox.Text = numbers.format(self_.Value)
        valueLabel.Visible = false
        valueBox.Visible = true
        suffixLabel.Visible = suffix ~= ""
        chipButton.Visible = false
        tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
        valueBox:CaptureFocus()
        task.defer(fitChip, false)
    end)
    valueBox.FocusLost:Connect(function()
        local typed = tonumber(valueBox.Text)
        editing = false
        valueBox.Visible = false
        suffixLabel.Visible = false
        valueLabel.Visible = true
        chipButton.Visible = true
        tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        if typed then
            self_:Set(typed)
        end
        fitChip(false)
    end)
    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.78, Size = UDim2.fromOffset(34, 34) }, 0.15)
        end
    end)
    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(knobGlow, { ImageTransparency = 0.85, Size = UDim2.fromOffset(28, 28) }, 0.2)
        end
    end)

    local snap = numbers.snap

    local function fraction()
        return (max - min) == 0 and 0 or (self_.Value - min) / (max - min)
    end

    local function moveTo(frac, duration, style)
        style = style or Enum.EasingStyle.Linear
        tween(fill, { Size = UDim2.new(frac, 0, 1, 0) }, duration, style)
        tween(knob, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
        tween(knobGlow, { Position = UDim2.new(frac, 0, 0.5, 0) }, duration, style)
    end

    local function render(duration, style)
        moveTo(fraction(), duration, style)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function settleTo(previousFrac)
        local target = fraction()
        local width = math.max(track.AbsoluteSize.X, 1)
        local overshoot = (target >= previousFrac and 1 or -1) * (5 / width)
        moveTo(math.clamp(target + overshoot, 0, 1), 0.22, Enum.EasingStyle.Quint)
        task.delay(0.22, function()
            if not dragging then
                moveTo(fraction(), 0.18, Enum.EasingStyle.Quint)
            end
        end)
        valueLabel.Text = numbers.format(self_.Value) .. suffix
    end

    local function bounceKnob()
        tween(knob, { Size = UDim2.fromOffset(14, 12) }, 0.08)
        tween(knobGlow, { Size = UDim2.fromOffset(32, 32), ImageTransparency = 0.78 }, 0.12)
        task.delay(0.1, function()
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25, Enum.EasingStyle.Quint)
            tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.25)
        end)
    end

    function self_:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == self_.Value then
            return
        end
        local previousFrac = fraction()
        self_.Value = value
        if dragging then
            render(0.05)
        else
            settleTo(previousFrac)
            bounceKnob()
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function self_:Get()
        return self_.Value
    end

    local function updateFromX(x)
        local frac = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        self_:Set(min + (max - min) * frac)
    end

    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            self_.Dragging = true
            tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15, Enum.EasingStyle.Back)
            tween(knobGlow, { Size = UDim2.fromOffset(44, 44), ImageTransparency = 0.7 }, 0.15)
            updateFromX(pointerPosition().X)
        end
    end)

    self.Window:_listen("Changed", function(input)
        if dragging and isMove(input) then
            updateFromX(pointerPosition().X)
        end
    end, self_)

    local function endDrag()
        dragging = false
        self_.Dragging = false
        tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.2)
        tween(knobGlow, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.2)
        safeCall(opts.OnRelease, self_.Value)
    end
    self.Window:_listen("Ended", function(input)
        if dragging and isPress(input) then
            endDrag()
        end
    end, self_)
    -- Hiding or disabling the slider mid-drag ends the drag, so it stops following the pointer.
    self_._onHide = function()
        if dragging then
            endDrag()
        end
    end

    self_.Value = snap(self_.Value)
    render(0)
    task.defer(fitChip, true)
    return finishElement(self, opts, self_, frame, "Slider")
end


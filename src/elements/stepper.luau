function Tab:Stepper(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default", Increment = "Step" }, "Frame", 150, "Stepper")
    local min = tonumber(opts.Min) or 0
    local max = tonumber(opts.Max) or 100
    -- Also covers Min = 200 with the default Max of 100.
    if min > max then
        min, max = max, min
    end
    local suffix = opts.Suffix or ""
    local numbers = numberFormat(min, max, opts.Step or 1)
    -- The cleaned step: 0 or a negative step falls back to 1.
    local step = numbers.step
    local compact = metricsOf(self).Compact
    local chipHeight = metricsOf(self).Chip

    local group = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(0, chipHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(group, UDim.new(0, 6))
    local groupStroke = stroke(group)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = group,
    })

    local function stepButton(text, order)
        local button = create("TextButton", {
            Size = UDim2.fromOffset(chipHeight, chipHeight),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.Muted,
            TextSize = 18,
            FontFace = Fonts.Medium,
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = group,
        })
        button.MouseEnter:Connect(function()
            tween(button, { TextColor3 = Theme.Accent }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { TextColor3 = Theme.Muted }, 0.2)
        end)
        return button
    end
    local minus = stepButton("−", 1)
    local valueLabel = label({
        Size = UDim2.new(0, 30, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = group,
    })
    local plus = stepButton("+", 3)
    local function fitValue(instant)
        local width = math.max(valueLabel.TextBounds.X + 12, 30)
        if instant then
            valueLabel.Size = UDim2.new(0, width, 1, 0)
        else
            tween(valueLabel, { Size = UDim2.new(0, width, 1, 0) }, 0.2)
        end
    end
    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitValue(false)
    end)
    group:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        reserveRight(titleLabel, descLabel, group.AbsoluteSize.X / self.Window.Scale.Scale + (compact and 24 or 20))
    end)

    local snap = numbers.snap
    local self_ = { Value = snap(tonumber(opts.Default) or min) }
    local fromButton = false
    local function render()
        valueLabel.Text = numbers.format(self_.Value) .. suffix
        tween(minus, { TextTransparency = self_.Value <= min and 0.6 or 0 }, 0.15)
        tween(plus, { TextTransparency = self_.Value >= max and 0.6 or 0 }, 0.15)
    end
    function self_:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == self_.Value then
            return
        end
        self_.Value = value
        render()
        if not fromButton then
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.Callback, value)
        end
    end
    function self_:Get()
        return self_.Value
    end

    local function bump(direction)
        fromButton = true
        self_:Set(self_.Value + direction * step)
        fromButton = false
        tween(groupStroke, { Color = Theme.StrokeHover }, 0.08)
        task.delay(0.12, function()
            tween(groupStroke, { Color = Theme.Stroke }, 0.2)
        end)
    end
    -- Each press bumps a generation; a repeat loop only runs while its own press is
    -- still held, so a quick release-and-press can't start a second loop.
    local holdGeneration = 0
    local function holdRepeat(button, direction)
        button.InputBegan:Connect(function(input)
            if not isPress(input) then
                return
            end
            holdGeneration += 1
            local generation = holdGeneration
            bump(direction)
            task.delay(0.4, function()
                while generation == holdGeneration and not self_._destroyed and not self_.Disabled and not self_._dependDisabled and frame.Parent do
                    bump(direction)
                    task.wait(0.07)
                end
            end)
        end)
        local function release()
            holdGeneration += 1
        end
        button.InputEnded:Connect(function(input)
            if isPress(input) then
                release()
            end
        end)
        button.MouseLeave:Connect(release)
    end
    holdRepeat(minus, -1)
    holdRepeat(plus, 1)

    render()
    task.defer(fitValue, true)
    return finishElement(self, opts, self_, frame, "Stepper")
end


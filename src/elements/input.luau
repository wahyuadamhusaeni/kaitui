function Library._parseAmount(text)
    text = string.lower(tostring(text)):gsub("[%s,_%$]", "")
    text = text:gsub("kg$", ""):gsub("/s$", "")
    local number = tonumber(text)
    if number then
        return number
    end
    local digits, suffix = text:match("^(.-)(%a+)$")
    local scale = suffix and Library._amountSuffixes[suffix]
    number = digits and tonumber(digits)
    if number and scale then
        return number * scale
    end
    return nil
end

function Tab:Input(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", PlaceholderText = "Placeholder", CurrentValue = "Default", Value = "Default" }, "Frame", 160, "Input")
    local compact = metricsOf(self).Compact
    local boxHeight = compact and metricsOf(self).Chip + 2 or 30

    local boxHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(170, boxHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(boxHolder, UDim.new(0, 6))
    local boxStroke = stroke(boxHolder)

    local boxIcon = opts.Icon
    if boxIcon then
        glowIcon(boxHolder, boxIcon, Theme.Muted, UDim2.new(0, 8, 0.5, 0))
    end
    local box = create("TextBox", {
        Position = UDim2.fromOffset(boxIcon and 30 or 8, 0),
        Size = UDim2.new(1, boxIcon and -38 or -16, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = compact and 13 or 14,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = boxHolder,
    })
    boxHolder.ClipsDescendants = true

    local lastText = box.Text
    local value = opts.Numeric and Library._parseAmount(lastText) or nil
    if opts.Numeric and not value then
        lastText = ""
        box.Text = ""
    end
    local focused = false
    local textInset = (boxIcon and 30 or 8) + 8
    local function fitBox(instant)
        local width
        if compact then
            width = rowControlWidth(frame, self.Window)
        else
            local cardWidth = frame.AbsoluteSize.X / self.Window.Scale.Scale
            local maxWidth = math.clamp(cardWidth - 14 - 110 - 20, 100, 200)
            local measured = box.TextBounds.X
            if #box.Text == 0 then
                measured = math.min(box.TextBounds.X, 90)
            end
            width = math.clamp(measured + textInset + 12, 90, maxWidth) + (focused and 8 or 0)
            width = math.min(width, maxWidth + 8)
        end
        reserveRight(titleLabel, descLabel, width + (compact and 24 or 20))
        if instant then
            boxHolder.Size = UDim2.fromOffset(width, boxHeight)
        else
            tween(boxHolder, { Size = UDim2.fromOffset(width, boxHeight) }, 0.18)
        end
    end
    local lastWidth = 0
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if frame.AbsoluteSize.X ~= lastWidth then
            lastWidth = frame.AbsoluteSize.X
            fitBox(true)
        end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        fitBox(false)
    end)
    box:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitBox(false)
    end)
    task.defer(fitBox, true)

    box.Focused:Connect(function()
        focused = true
        tween(boxStroke, { Color = Theme.StrokeHover }, 0.15)
        fitBox(false)
    end)
    box.FocusLost:Connect(function(enterPressed)
        focused = false
        tween(boxStroke, { Color = Theme.Stroke }, 0.15)
        fitBox(false)
        if opts.Numeric then
            local number = Library._parseAmount(box.Text)
            if not number then
                box.Text = lastText
                return
            end
            lastText, value = box.Text, number
            safeCall(opts.Callback, number, enterPressed)
            return
        end
        safeCall(opts.Callback, box.Text, enterPressed)
    end)

    return finishElement(self, opts, {
        Set = function(_, newValue, silent)
            local before = box.Text
            box.Text = tostring(newValue == nil and "" or newValue)
            if opts.Numeric then
                local number = Library._parseAmount(box.Text)
                if number then
                    lastText, value = box.Text, number
                else
                    box.Text = lastText
                    return
                end
            end
            flashStroke(frameStroke)
            -- Configs load through here, so the script hears the loaded text.
            if not silent and box.Text ~= before then
                safeCall(opts.Callback, opts.Numeric and value or box.Text, false)
            end
        end,
        Get = function()
            if opts.Numeric then
                return value
            end
            return box.Text
        end,
        _saveValue = opts.Numeric and function()
            return lastText
        end or nil,
    }, frame, "Input")
end


function Tab:ColorPicker(opts)
    local PANEL_HEIGHT = 194
    local frame, frameStroke, height
    opts, frame, frameStroke, height = beginElement(self, opts, { Title = "Name", Description = "Desc", Color = "Default", CurrentValue = "Default", Value = "Default" }, "Frame")
    frame.ClipsDescendants = true
    local metrics = metricsOf(self)
    local compact = metrics.Compact

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = frame,
    })
    titleDesc(header, opts.Name or "Color", opts.Desc, 140, metrics)

    -- Closed, the row shows the hex code beside a rounded swatch.
    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -38 or -34, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BorderSizePixel = 0,
        Parent = header,
    })
    corner(swatch, UDim.new(0, 6))
    stroke(swatch, Theme.Stroke)
    local swatchHex = label({
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -68 or -64, 0.5, 0),
        Size = UDim2.fromOffset(64, 16),
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = header,
    })
    local arrow = arrowIndicator(header, 1, compact and -14 or -12)

    local panel = create("Frame", {
        Position = UDim2.fromOffset(14, height + 2),
        Size = UDim2.new(1, -28, 0, PANEL_HEIGHT - 12),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = frame,
    })

    -- Saturation runs left to right, brightness top to bottom.
    local svBox = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 118),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = panel,
    })
    corner(svBox, UDim.new(0, 8))
    stroke(svBox, Theme.Stroke)
    local svHueGradient = create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 0, 0)),
        Parent = svBox,
    })
    local svDark = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Parent = svBox,
    })
    corner(svDark, UDim.new(0, 8))
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = svDark,
    })

    -- Both handles are a white ring filled with the colour under them, with a
    -- faint dark edge so they read on light and dark spots alike.
    local function knob(parent, size)
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = parent,
        })
        corner(ring, UDim.new(1, 0))
        stroke(ring, Color3.new(0, 0, 0), 0.7)
        local fill = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -4, 1, -4),
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = ring,
        })
        corner(fill, UDim.new(1, 0))
        return ring, fill
    end
    local svCursor, svFill = knob(svBox, 14)

    -- Hue is a slim horizontal track under the square.
    local hueBar = create("TextButton", {
        Position = UDim2.fromOffset(0, 132),
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = panel,
    })
    corner(hueBar, UDim.new(1, 0))
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
        Parent = hueBar,
    })
    local hueCursor, hueFill = knob(hueBar, 16)
    hueCursor.Position = UDim2.fromScale(0, 0.5)

    -- Bottom row: a preview chip and hex field on the left, RGB on the right.
    local hexHolder = create("Frame", {
        Position = UDim2.fromOffset(0, 154),
        Size = UDim2.fromOffset(compact and 110 or 124, 28),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = panel,
    })
    corner(hexHolder, UDim.new(0, 7))
    local hexStroke = stroke(hexHolder)
    local preview = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 6, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        Parent = hexHolder,
    })
    corner(preview, UDim.new(0, 4))
    stroke(preview, Theme.Stroke)
    local hexBox = create("TextBox", {
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(1, -38, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = false,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = hexHolder,
    })
    local rgbLabel = label({
        Position = UDim2.fromOffset(compact and 118 or 134, 154),
        Size = UDim2.new(1, compact and -118 or -134, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = panel,
    })

    local self_ = { Open = false }
    -- Any colour form the library knows: Color3, "#rrggbb", a theme key or { r, g, b }.
    local function asColor(value, what)
        local color = Library._color(value)
        if value ~= nil and not color then
            Library._warn(('ColorPicker "%s": %s should be a Color3, "#rrggbb", a theme key or { r, g, b }, got %s. It was ignored.'):format(
                tostring(opts.Name or "Color"), what, Library._describe(value)))
        end
        return color
    end
    local hue, sat, val = Color3.toHSV(asColor(opts.Default, "Color") or Theme.Accent)
    local dragTarget = nil

    local function toHex(color)
        return string.format("#%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function render(duration)
        local color = Color3.fromHSV(hue, sat, val)
        self_.Value = color
        swatch.BackgroundColor3 = color
        preview.BackgroundColor3 = color
        svFill.BackgroundColor3 = color
        hueFill.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        swatchHex.Text = toHex(color)
        svHueGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
        tween(svCursor, { Position = UDim2.fromScale(sat, 1 - val) }, duration, Enum.EasingStyle.Quint)
        tween(hueCursor, { Position = UDim2.fromScale(hue, 0.5) }, duration, Enum.EasingStyle.Quint)
        if not hexBox:IsFocused() then
            hexBox.Text = toHex(color)
        end
        rgbLabel.Text = string.format("%d  %d  %d",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function commit(duration, silent)
        render(duration)
        if not silent then
            safeCall(opts.Callback, self_.Value)
        end
    end

    function self_:Set(color, silent)
        color = asColor(color, "Set")
        if not color then
            return
        end
        hue, sat, val = Color3.toHSV(color)
        commit(0.25, silent)
        flashStroke(frameStroke)
    end

    function self_:Get()
        return self_.Value
    end

    local function setOpen(open)
        self_.Open = open
        tween(frame, { Size = UDim2.new(1, 0, 0, open and (height + PANEL_HEIGHT) or height) }, 0.35, Enum.EasingStyle.Quint)
        arrow:Set(open)
        if open then
            panel.Visible = true
        else
            task.delay(0.35, function()
                if not self_.Open then
                    panel.Visible = false
                end
            end)
        end
    end

    function self_:SetOpen(open)
        setOpen(open == true)
    end

    header.MouseButton1Click:Connect(function()
        setOpen(not self_.Open)
    end)

    local function updateSV(position)
        sat = math.clamp((position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
        val = 1 - math.clamp((position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
        commit(0.04)
    end
    local function updateHue(position)
        hue = math.clamp((position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
        commit(0.04)
    end

    svBox.InputBegan:Connect(function(input)
        if isPress(input) then
            dragTarget = "sv"
            tween(svCursor, { Size = UDim2.fromOffset(18, 18) }, 0.2, Enum.EasingStyle.Quint)
            updateSV(pointerPosition())
        end
    end)
    hueBar.InputBegan:Connect(function(input)
        if isPress(input) then
            dragTarget = "hue"
            tween(hueCursor, { Size = UDim2.fromOffset(20, 20) }, 0.2, Enum.EasingStyle.Quint)
            updateHue(pointerPosition())
        end
    end)
    self.Window:_listen("Changed", function(input)
        if not dragTarget or not isMove(input) then
            return
        end
        local position = pointerPosition()
        if dragTarget == "sv" then
            updateSV(position)
        else
            updateHue(position)
        end
    end, self_)
    local function endDrag()
        dragTarget = nil
        tween(svCursor, { Size = UDim2.fromOffset(14, 14) }, 0.25, Enum.EasingStyle.Quint)
        tween(hueCursor, { Size = UDim2.fromOffset(16, 16) }, 0.25, Enum.EasingStyle.Quint)
    end
    self.Window:_listen("Ended", function(input)
        if dragTarget and isPress(input) then
            endDrag()
        end
    end, self_)
    -- Hiding or disabling the picker mid-drag ends the drag.
    self_._onHide = function()
        if dragTarget then
            endDrag()
        end
    end

    hexBox.Focused:Connect(function()
        tween(hexStroke, { Color = Theme.StrokeHover }, 0.15)
    end)
    hexBox.FocusLost:Connect(function()
        tween(hexStroke, { Color = Theme.Stroke }, 0.15)
        local r, g, b = hexBox.Text:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
        if r then
            -- Focusing the box and leaving it as it was is not a change.
            local color = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
            if toHex(color) ~= toHex(self_.Value) then
                self_:Set(color)
            end
        else
            hexBox.Text = toHex(self_.Value)
        end
    end)

    render(0)
    return finishElement(self, opts, self_, frame, "ColorPicker")
end


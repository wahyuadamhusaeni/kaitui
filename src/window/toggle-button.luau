function Window:_createOpenButton(opts)
    local gui = self.Gui
    local pill = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(0, 40),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 30,
        Visible = false,
        Parent = gui,
    })
    corner(pill, UDim.new(1, 0))
    stroke(pill, Theme.Stroke)
    padding(pill, 12, 16)
    local icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 31,
        Parent = pill,
    })
    applyIcon(icon, opts.Icon or Assets.Logo, true)
    label({
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = opts.Title or "KaitUI",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        ZIndex = 31,
        Parent = pill,
    })
    self.OpenButton = pill

    local dragging, moved = false, false
    local grab = Vector2.zero
    pill.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            moved = false
            grab = pointerPosition() - pill.AbsolutePosition
        end
    end)
    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if isMove(input) then
            local point = pointerPosition() - grab - gui.AbsolutePosition
            if (point - (pill.AbsolutePosition - gui.AbsolutePosition)).Magnitude > 3 then
                moved = true
            end
            pill.AnchorPoint = Vector2.new(0, 0)
            pill.Position = UDim2.fromOffset(
                math.clamp(point.X, 0, math.max(gui.AbsoluteSize.X - pill.AbsoluteSize.X, 0)),
                math.clamp(point.Y, 0, math.max(gui.AbsoluteSize.Y - pill.AbsoluteSize.Y, 0))
            )
        end
    end))
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            if not moved then
                self:Toggle()
            end
        end
    end))
end

-- Square floating button that minimizes and restores the window. Shown on
-- touch devices only, or everywhere with Platform = "Both".
function Window:_toggleButtonAllowed()
    return self._toggleEnabled and (TOUCH or self._togglePlatform == "Both")
end

function Window:_refreshToggleButton()
    -- The open pill brings back a hidden window, so it shows only then: not
    -- during the loader, not over an open window, not under the island.
    if self.OpenButton then
        self.OpenButton.Visible = self._introDone == true and not self._destroyed and not self.Open
    end
    local button = self.ToggleButton
    if not button then
        return
    end
    local shown = self._introDone and not self._destroyed and self:_toggleButtonAllowed()
    if shown and not button.Visible then
        button.Visible = true
        button.Size = UDim2.fromOffset(0, 0)
        tween(button, { Size = UDim2.fromOffset(self._toggleSize, self._toggleSize) }, 0.45, Enum.EasingStyle.Quint)
    elseif not shown then
        button.Visible = false
    end
    -- Folded (window minimized or hidden): the outline takes the accent.
    local folded = self.Minimized or not self.Open
    tween(self._toggleStroke, { Color = folded and Theme.Accent or Theme.Stroke, Transparency = folded and 0.3 or 0 }, 0.35)
    local icon = self._toggleIcon
    tween(icon, { Rotation = folded and 180 or 0 }, 0.5, Enum.EasingStyle.Quint)
    if not icon:GetAttribute("CustomIcon") then
        tween(icon, { ImageColor3 = folded and Theme.Text or Theme.Accent }, 0.35)
    end
end

function Window:_createToggleButton(opts)
    local gui = self.Gui
    local size = tonumber(opts.Size) or (TOUCH and 56 or 50)
    local iconSize = math.floor(size * 0.46)
    self._toggleEnabled = opts.Enabled ~= false
    self._togglePlatform = opts.Platform == "Both" and "Both" or "Mobile"
    self._toggleSize = size
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = opts.Position or UDim2.new(0, 18 + size / 2, 0.5, 0),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 30,
        Parent = gui,
    })
    corner(button, UDim.new(0, 12))
    local buttonStroke = stroke(button, Theme.Stroke)
    local icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(iconSize, iconSize),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 31,
        Parent = button,
    })
    local buttonScale = create("UIScale", { Parent = button })
    self.ToggleButton = button
    self._toggleStroke = buttonStroke
    self._toggleIcon = icon
    self:SetToggleButtonIcon(opts.Icon or "layout-grid")

    local dragging, moved = false, false
    local grab = Vector2.zero
    button.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            moved = false
            grab = pointerPosition() - button.AbsolutePosition
            tween(buttonScale, { Scale = 0.94 }, 0.18, Enum.EasingStyle.Quint)
        end
    end)
    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging or not isMove(input) then
            return
        end
        local point = pointerPosition() - grab - gui.AbsolutePosition
        if (point - (button.AbsolutePosition - gui.AbsolutePosition)).Magnitude > 3 then
            moved = true
        end
        if moved then
            button.AnchorPoint = Vector2.zero
            button.Position = UDim2.fromOffset(
                math.clamp(point.X, 0, math.max(gui.AbsoluteSize.X - button.AbsoluteSize.X, 0)),
                math.clamp(point.Y, 0, math.max(gui.AbsoluteSize.Y - button.AbsoluteSize.Y, 0))
            )
        end
    end))
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging or not isPress(input) then
            return
        end
        dragging = false
        tween(buttonScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Quint)
        if moved then
            return
        end
        ripple(button)
        if not self.Open then
            self:Toggle(true)
        elseif self.Minimized then
            self:Restore()
        else
            self:Minimize()
        end
    end))
end

-- After the screen changes size (rotation, fullscreen), pull a dragged open or
-- toggle button back inside it; on touch it may be the only way to restore the window.
function Window:_clampFloatingButtons()
    local viewport = self.Gui.AbsoluteSize
    for _, button in ipairs({ self.OpenButton, self.ToggleButton }) do
        if button and button.Parent and button.AnchorPoint == Vector2.zero then
            local position = button.AbsolutePosition - self.Gui.AbsolutePosition
            button.Position = UDim2.fromOffset(
                math.clamp(position.X, 0, math.max(viewport.X - button.AbsoluteSize.X, 0)),
                math.clamp(position.Y, 0, math.max(viewport.Y - button.AbsoluteSize.Y, 0))
            )
        end
    end
end

function Window:SetToggleButton(enabled)
    self._toggleEnabled = enabled ~= false
    self:_refreshToggleButton()
end

function Window:SetToggleButtonPlatform(platform)
    self._togglePlatform = platform == "Both" and "Both" or "Mobile"
    self:_refreshToggleButton()
end

function Window:SetToggleButtonIcon(icon)
    local image = self._toggleIcon
    if not image then
        return
    end
    image.Image = ""
    applyIcon(image, icon)
    if image.Image == "" then
        applyIcon(image, Assets.Logo)
    end
    if not image:GetAttribute("CustomIcon") then
        tween(image, { ImageColor3 = (self.Minimized or not self.Open) and Theme.Text or Theme.Accent }, 0)
    end
end


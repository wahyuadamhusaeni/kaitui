local function makeSkeleton(window)
    local root = window.Root
    local style = window.DragStyle or "Outline"
    local skeleton = create("Frame", {
        AnchorPoint = root.AnchorPoint,
        -- In pixels: the step below reads Position.Offset, and the window may still sit at a scale position.
        Position = UDim2.fromOffset(
            root.AbsolutePosition.X + root.AbsoluteSize.X * root.AnchorPoint.X - window.Gui.AbsolutePosition.X,
            root.AbsolutePosition.Y + root.AbsoluteSize.Y * root.AnchorPoint.Y - window.Gui.AbsolutePosition.Y
        ),
        Size = UDim2.fromOffset(root.AbsoluteSize.X, root.AbsoluteSize.Y),
        BackgroundColor3 = style == "Ghost" and Theme.Background or Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 40,
        Parent = window.Gui,
    })
    corner(skeleton, UDim.new(0, 10))
    -- Each part fades from hidden to its shown values, and back on release.
    local parts = {}
    local function part(object, shown)
        local hidden = {}
        for key in pairs(shown) do
            hidden[key] = 1
        end
        table.insert(parts, { Object = object, Shown = shown, Hidden = hidden })
    end
    local function brackets(length, inset)
        for _, spot in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
            local at = UDim2.new(spot.X, spot.X == 0 and inset or -inset, spot.Y, spot.Y == 0 and inset or -inset)
            for _, size in ipairs({ UDim2.fromOffset(length, 2), UDim2.fromOffset(2, length) }) do
                local bracket = create("Frame", {
                    AnchorPoint = spot,
                    Position = at,
                    Size = size,
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Parent = skeleton,
                })
                corner(bracket, UDim.new(1, 0))
                part(bracket, { BackgroundTransparency = 0 })
            end
        end
    end
    if style == "Brackets" then
        -- Just the four corners of the window, a little longer.
        brackets(22, 0)
    elseif style == "Ghost" then
        -- A see-through copy of the window's panel.
        part(skeleton, { BackgroundTransparency = 0.35 })
        part(stroke(skeleton, Theme.Stroke, 1, 1), { Transparency = 0 })
    elseif style == "Frame" then
        -- A single quiet line, nothing else.
        part(stroke(skeleton, Theme.StrokeHover, 1, 1), { Transparency = 0 })
    else
        -- Outline: a faint accent wash, an outline and corner brackets.
        part(skeleton, { BackgroundTransparency = 0.92 })
        part(stroke(skeleton, Theme.Accent, 1, 1.5), { Transparency = 0.2 })
        brackets(16, 6)
    end
    local scale = create("UIScale", { Scale = 1.02, Parent = skeleton })
    for _, item in ipairs(parts) do
        tween(item.Object, item.Shown, 0.15, Enum.EasingStyle.Quad)
    end
    tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Quint)
    local function fade()
        for _, item in ipairs(parts) do
            tween(item.Object, item.Hidden, 0.2, Enum.EasingStyle.Quad)
        end
        task.delay(0.22, function()
            skeleton:Destroy()
        end)
    end
    return skeleton, fade
end

function Window:_enableDrag()
    local dragging, moved = false, false
    local grabOffset, pressPoint = Vector2.zero, Vector2.zero
    local target = nil
    local skeleton, fadeSkeleton = nil, nil

    local function centre()
        local root = self.Root
        return root.AbsolutePosition + root.AbsoluteSize * root.AnchorPoint - self.Gui.AbsolutePosition
    end

    local function dropSkeleton()
        if not skeleton then
            return
        end
        local spot = Vector2.new(skeleton.Position.X.Offset, skeleton.Position.Y.Offset)
        if self.KeepOnScreen then
            spot = self:_clampedCentre(spot)
        end
        if self._clampTween then
            self._clampTween:Cancel()
        end
        self._clampTween = tween(self.Root, { Position = UDim2.fromOffset(spot.X, spot.Y) }, 0.3, Enum.EasingStyle.Quint)
        fadeSkeleton()
        skeleton, fadeSkeleton = nil, nil
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        if not self.Open or not self.Root.Visible then
            return
        end
        local point = pointerPosition()
        if self._resizeActive or (self._grip and pointInside(point, self._grip)) then
            return
        end
        if not pointInside(point, self.Body) or self:_overControl(point) then
            return
        end
        if self._clampTween then
            self._clampTween:Cancel()
            self._clampTween = nil
        end
        dragging, moved = true, false
        pressPoint = point
        grabOffset = point - centre()
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging then
            return
        end
        if isPress(input) then
            dragging = false
            target = nil
            if skeleton then
                dropSkeleton()
            else
                self:_clampToScreen()
            end
        end
    end))

    table.insert(self._frameSteps, function(deltaTime)
        if not dragging then
            return
        end
        local point = pointerPosition()
        if not moved and (point - pressPoint).Magnitude > 3 then
            moved = true
            if self.DragSkeleton then
                skeleton, fadeSkeleton = makeSkeleton(self)
            end
        end
        if not moved then
            return
        end
        -- Hidden or minimized mid-drag: land it where the outline is.
        if skeleton and (not self.Open or not self.Root.Visible) then
            dragging = false
            dropSkeleton()
            return
        end
        target = point - grabOffset
        local alpha = 1 - math.exp(-deltaTime * 45)
        if skeleton then
            local current = Vector2.new(skeleton.Position.X.Offset, skeleton.Position.Y.Offset)
            local step = current:Lerp(target, alpha)
            skeleton.Position = UDim2.fromOffset(step.X, step.Y)
        else
            local step = centre():Lerp(target, alpha)
            self.Root.Position = UDim2.fromOffset(step.X, step.Y)
        end
    end)
end

-- One of Library.DragStyles; anything else falls back to "Outline".
-- Returns the style it settled on.
function Window:SetDragStyle(style)
    style = table.find(Library.DragStyles, style) and style or "Outline"
    self.DragStyle = style
    self.DragSkeleton = style ~= "Off"
    return style
end

function Window:GetDragStyle()
    return self.DragStyle
end

-- How the minimized island shows the session card: opening it while
-- hovered, or keeping it open the whole time it's minimized.
Library.IslandStyles = { "Show on Hover", "Always Show" }

-- One of Library.IslandStyles; anything else falls back to "Show on Hover".
-- Returns the style it settled on.
function Window:SetIslandStyle(style)
    style = table.find(Library.IslandStyles, style) and style or "Show on Hover"
    self.IslandStyle = style
    if self._islandSettle then
        self._islandSettle()
    end
    return style
end

function Window:GetIslandStyle()
    return self.IslandStyle
end

-- The older on/off switch: off is the "Off" style, on brings back the
-- default style if it was off.
function Window:SetDragSkeleton(enabled)
    if enabled == false then
        self:SetDragStyle("Off")
    elseif self.DragStyle == "Off" or not self.DragStyle then
        self:SetDragStyle("Outline")
    end
end

-- The sidebar's divider is a grab strip: dragging it sets the rail's width,
-- kept between a usable minimum and enough room for the content.
function Window:_sidebarResize(sidebar, width)
    local divider = sidebar:FindFirstChild("Divider")
    local want = width
    local function apply(value, remember)
        if remember ~= false then
            want = value
        end
        local room = self.Body.AbsoluteSize.X / self.Scale.Scale - 300
        value = math.floor(math.clamp(value, 150, math.max(math.min(300, room), 150)))
        self.SidebarWidth = value
        sidebar.Size = UDim2.new(0, value, 1, 0)
        self.Content.Position = UDim2.fromOffset(value + 1, 0)
        self.Content.Size = UDim2.new(1, -(value + 1), 1, 0)
    end
    self.SetSidebarWidth = function(_, value)
        apply(tonumber(value) or SIDEBAR_WIDTH)
    end
    apply(width)
    local grip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 6, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
        Parent = sidebar,
    })
    grip:SetAttribute("NoDrag", true)
    local dragging, startX, startWidth = false, 0, width
    local function light(on)
        if divider then
            tween(divider, { BackgroundColor3 = on and Theme.Accent or Theme.Stroke }, 0.15)
        end
    end
    grip.MouseEnter:Connect(function()
        light(true)
    end)
    grip.MouseLeave:Connect(function()
        if not dragging then
            light(false)
        end
    end)
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startX, startWidth = true, input.Position.X, self.SidebarWidth
            want = startWidth
            light(true)
        end
    end)
    self:_listen("Changed", function(input)
        if dragging and isMove(input) then
            apply(startWidth + (input.Position.X - startX) / self.Scale.Scale)
        end
    end)
    self:_listen("Ended", function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            light(false)
        end
    end)
    -- Shrinking the window pulls an over-wide rail back in.
    self.Body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not dragging then
            apply(want, false)
        end
    end)
end


function Window:_enableResize(minSize)
    -- MaxSize below MinSize would make math.clamp throw on every resize frame.
    local maxSize = (self.MaxSize or Vector2.new(math.huge, math.huge)):Max(minSize)
    self.MaxSize = maxSize
    self._minSize = minSize
    local root = self.Root
    local grip = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 4, 1, 4),
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 20,
        Parent = root,
    })
    self._grip = grip
    -- An arc that traces the window's own rounded corner: a rounded square
    -- laid over the corner whose outline fades out away from it, so only the
    -- curve and a short run of each edge show. Faint at rest, accent in use.
    local gripArc = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        ZIndex = 20,
        Parent = grip,
    })
    corner(gripArc, UDim.new(0, 10))
    local gripStroke = create("UIStroke", {
        Color = Theme.Muted,
        Thickness = 2,
        Transparency = 0.55,
        Parent = gripArc,
    })
    create("UIGradient", {
        Rotation = 45,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.55, 1),
            NumberSequenceKeypoint.new(0.85, 0),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = gripStroke,
    })
    local function lightGrip(on)
        tween(gripStroke, {
            Color = on and Theme.Accent or Theme.Muted,
            Transparency = on and 0 or 0.55,
        }, on and 0.15 or 0.3, Enum.EasingStyle.Quint)
    end

    -- The size follows the pointer through a critically damped spring, so it
    -- glides after the cursor and eases to rest when released instead of
    -- snapping. While resizing, the window is anchored at its top-left corner
    -- so only the right and bottom edges move and nothing jitters on half pixels.
    local STIFFNESS = 20
    local resizing = false
    local startSize = Vector2.zero
    local startPointer = Vector2.zero
    local current = Vector2.zero
    local velocity = Vector2.zero
    local target = Vector2.zero
    local applied = Vector2.zero

    local function readSize()
        return Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
    end

    local function pin()
        if root.AnchorPoint == Vector2.zero then
            return
        end
        -- A clamp tween still writing centre coordinates would fight the new anchor.
        if self._clampTween then
            self._clampTween:Cancel()
            self._clampTween = nil
        end
        local topLeft = root.AbsolutePosition - self.Gui.AbsolutePosition
        root.AnchorPoint = Vector2.zero
        root.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
    end

    local function unpin()
        local topLeft = root.AbsolutePosition - self.Gui.AbsolutePosition
        local half = root.AbsoluteSize / 2
        root.AnchorPoint = Vector2.new(0.5, 0.5)
        root.Position = UDim2.fromOffset(topLeft.X + half.X, topLeft.Y + half.Y)
    end

    local function clampSize(size)
        return Vector2.new(
            math.floor(math.clamp(size.X, minSize.X, maxSize.X) + 0.5),
            math.floor(math.clamp(size.Y, minSize.Y, maxSize.Y) + 0.5)
        )
    end

    grip.InputBegan:Connect(function(input)
        if not isPress(input) or not self.Open then
            return
        end
        if not self._resizeActive then
            pin()
            current = readSize()
            velocity = Vector2.zero
            applied = current
        end
        self._resizeActive = true
        resizing = true
        startSize = current
        startPointer = pointerPosition()
        target = clampSize(startSize)
        lightGrip(true)
    end)
    grip.MouseEnter:Connect(function()
        if not resizing then
            lightGrip(true)
        end
    end)
    grip.MouseLeave:Connect(function()
        if not resizing then
            lightGrip(false)
        end
    end)
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if resizing and isPress(input) then
            resizing = false
            lightGrip(false)
        end
    end))

    table.insert(self._frameSteps, function(deltaTime)
        if not self._resizeActive then
            return
        end
        if resizing then
            local delta = (pointerPosition() - startPointer) / self.Scale.Scale
            target = clampSize(startSize + delta)
        end
        local dt = math.min(deltaTime, 1 / 30)
        local decay = math.exp(-STIFFNESS * dt)
        local offset = current - target
        local drift = (velocity + offset * STIFFNESS) * dt
        velocity = (velocity - drift * STIFFNESS) * decay
        current = target + (offset + drift) * decay

        local rounded = Vector2.new(math.floor(current.X + 0.5), math.floor(current.Y + 0.5))
        if rounded ~= applied then
            applied = rounded
            root.Size = UDim2.fromOffset(rounded.X, rounded.Y)
        end

        if not resizing and (current - target).Magnitude < 0.3 and velocity.Magnitude < 3 then
            current = target
            velocity = Vector2.zero
            applied = target
            root.Size = UDim2.fromOffset(target.X, target.Y)
            unpin()
            self._resizeActive = false
            self:_fitToScreen()
            self:_clampToScreen()
        end
    end)
end

-- The window's own size in pixels, before the UI scale and screen fit.
function Window:GetSize()
    return Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
end

-- Resizes to an exact size, kept within MinSize and MaxSize. Ignored while the
-- player is dragging the grip.
function Window:SetSize(size, instant)
    if typeof(size) == "UDim2" then
        size = Vector2.new(size.X.Offset, size.Y.Offset)
    end
    if typeof(size) ~= "Vector2" or self._resizeActive then
        return
    end
    local minSize = self._minSize or Vector2.zero
    local maxSize = self.MaxSize or Vector2.new(math.huge, math.huge)
    size = Vector2.new(
        math.floor(math.clamp(size.X, minSize.X, maxSize.X) + 0.5),
        math.floor(math.clamp(size.Y, minSize.Y, maxSize.Y) + 0.5)
    )
    if size == self:GetSize() then
        return
    end
    local duration = (instant or not self.Root.Visible) and 0 or 0.3
    tween(self.Root, { Size = UDim2.fromOffset(size.X, size.Y) }, duration, Enum.EasingStyle.Quint)
    task.delay(duration + 0.02, function()
        if not self._destroyed then
            self:_fitToScreen()
            self:_clampToScreen()
        end
    end)
end

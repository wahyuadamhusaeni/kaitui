function Window:_listen(kind, handler, owner)
    local list = self._inputListeners[kind]
    table.insert(list, handler)
    local function disconnect()
        for index, entry in ipairs(list) do
            if entry == handler then
                table.remove(list, index)
                break
            end
        end
    end
    if owner then
        owner._listeners = owner._listeners or {}
        table.insert(owner._listeners, disconnect)
    end
    return disconnect
end

function Window:_indicatorY(tab)
    local stack = self._tabStack
    return (tab._button.AbsolutePosition.Y - stack.AbsolutePosition.Y) / self.Scale.Scale + stack.Position.Y.Offset
end

function Window:_placeIndicator(tab)
    local indicator = self.Indicator
    local targetY = self:_indicatorY(tab)
    if not indicator.Visible then
        indicator.Visible = true
        indicator.Position = UDim2.fromOffset(8, targetY)
        indicator.BackgroundTransparency = 1
        tween(indicator, { BackgroundTransparency = 0.35 }, 0.3)
    end
    tween(indicator, { Position = UDim2.fromOffset(8, targetY) }, 0.45, Enum.EasingStyle.Quint)
end

-- While a tab list or sub tab strip runs past an end, that end gets a fade
-- and a small chip with a chevron and how many tabs are out of sight there.
-- Pressing the chip scrolls most of a view toward them.
function Window:_overflowHint(host, scroller, items, vertical, fadeColor)
    local overlay = create("Frame", {
        AnchorPoint = scroller.AnchorPoint,
        Position = scroller.Position,
        Size = scroller.Size,
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = host,
    })
    local function mirror()
        overlay.Position = scroller.Position
        overlay.Size = scroller.Size
        overlay.Visible = scroller.Visible
    end
    for _, property in ipairs({ "Position", "Size", "Visible" }) do
        scroller:GetPropertyChangedSignal(property):Connect(mirror)
    end

    local function axis(vector)
        return vertical and vector.Y or vector.X
    end
    local function scale()
        return self.Scale and self.Scale.Scale or 1
    end
    local function scrollBy(direction)
        local view = axis(scroller.AbsoluteWindowSize) / scale()
        local limit = math.max(axis(scroller.AbsoluteCanvasSize) / scale() - view, 0)
        local target = math.clamp(axis(scroller.CanvasPosition) + direction * view * 0.75, 0, limit)
        tween(scroller, { CanvasPosition = vertical and Vector2.new(0, target) or Vector2.new(target, 0) }, 0.35, Enum.EasingStyle.Quint)
    end

    local hints = {}
    for _, direction in ipairs({ -1, 1 }) do
        local far = direction > 0
        local fade = create("Frame", {
            AnchorPoint = vertical and Vector2.new(0, far and 1 or 0) or Vector2.new(far and 1 or 0, 0),
            Position = vertical and UDim2.fromScale(0, far and 1 or 0) or UDim2.fromScale(far and 1 or 0, 0),
            Size = vertical and UDim2.new(1, 0, 0, 34) or UDim2.new(0, 48, 1, 0),
            BackgroundColor3 = fadeColor,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            Parent = overlay,
        })
        create("UIGradient", {
            Rotation = vertical and (far and 270 or 90) or (far and 180 or 0),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.4, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = fade,
        })
        local home = vertical and UDim2.new(0.5, 0, far and 1 or 0, far and -5 or 5) or UDim2.new(far and 1 or 0, far and -2 or 2, 0.5, 0)
        local chip = create("TextButton", {
            AnchorPoint = vertical and Vector2.new(0.5, far and 1 or 0) or Vector2.new(far and 1 or 0, 0.5),
            Position = home,
            Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Surface3,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 2,
            Parent = overlay,
        })
        corner(chip, UDim.new(1, 0))
        local chipStroke = stroke(chip, Theme.Stroke, 1)
        padding(chip, 7, 7)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 3),
            Parent = chip,
        })
        local arrow = create("ImageLabel", {
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            LayoutOrder = 1,
            ZIndex = 2,
            Parent = chip,
        })
        applyIcon(arrow, vertical and (far and "chevron-down" or "chevron-up") or (far and "chevron-right" or "chevron-left"))
        local arrowFade = "ImageTransparency"
        if arrow.Image == "" then
            arrow:Destroy()
            arrow = label({
                Size = UDim2.fromOffset(10, 20),
                Text = "›",
                TextSize = 16,
                TextColor3 = Theme.Accent,
                TextTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.None,
                Rotation = vertical and (far and 90 or -90) or (far and 0 or 180),
                LayoutOrder = 1,
                ZIndex = 2,
                Parent = chip,
            })
            arrowFade = "TextTransparency"
        end
        local count = label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "",
            TextSize = 12,
            TextColor3 = Theme.Text,
            TextTransparency = 1,
            TextTruncate = Enum.TextTruncate.None,
            Visible = false,
            LayoutOrder = 2,
            ZIndex = 2,
            Parent = chip,
        })
        chip.MouseEnter:Connect(function()
            if not usingTouch() then
                tween(chipStroke, { Color = Theme.StrokeHover }, 0.12)
            end
        end)
        chip.MouseLeave:Connect(function()
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        end)
        chip.MouseButton1Click:Connect(function()
            scrollBy(direction)
        end)
        hints[direction] = {
            Direction = direction,
            Fade = fade,
            Chip = chip,
            Stroke = chipStroke,
            Arrow = arrow,
            ArrowFade = arrowFade,
            Count = count,
            Home = home,
            Shown = false,
            Generation = 0,
        }
    end

    local function show(hint, on)
        if hint.Shown == on then
            return
        end
        hint.Shown = on
        hint.Generation += 1
        local away = hint.Home + (vertical and UDim2.fromOffset(0, hint.Direction * 6) or UDim2.fromOffset(hint.Direction * 6, 0))
        local value = on and 0 or 1
        if on then
            hint.Fade.Visible = true
            hint.Chip.Visible = true
            hint.Chip.Position = away
            tween(hint.Chip, { Position = hint.Home, BackgroundTransparency = 0.08 }, 0.3, Enum.EasingStyle.Quint)
        else
            tween(hint.Chip, { Position = away, BackgroundTransparency = 1 }, 0.2, Enum.EasingStyle.Quint)
            local generation = hint.Generation
            task.delay(0.21, function()
                if hint.Generation == generation then
                    hint.Fade.Visible = false
                    hint.Chip.Visible = false
                end
            end)
        end
        tween(hint.Fade, { BackgroundTransparency = value }, 0.2)
        tween(hint.Stroke, { Transparency = value }, 0.2)
        tween(hint.Arrow, { [hint.ArrowFade] = value }, 0.2)
        tween(hint.Count, { TextTransparency = value }, 0.2)
    end

    local function refresh()
        local view = axis(scroller.AbsoluteWindowSize)
        local overflow = (axis(scroller.AbsoluteCanvasSize) - view) / scale()
        local position = axis(scroller.CanvasPosition)
        local start = axis(scroller.AbsolutePosition)
        local before, after = 0, 0
        for _, item in ipairs(items:GetChildren()) do
            if item:IsA("GuiObject") and item.Visible and axis(item.AbsoluteSize) > 0 then
                local centre = axis(item.AbsolutePosition) + axis(item.AbsoluteSize) / 2 - start
                if centre < 0 then
                    before += 1
                elseif centre > view then
                    after += 1
                end
            end
        end
        for direction, hint in pairs(hints) do
            local hidden = direction < 0 and before or after
            hint.Count.Text = tostring(hidden)
            hint.Count.Visible = hidden > 0
            show(hint, overflow > 1 and (direction < 0 and position > 1 or direction > 0 and position < overflow - 1))
        end
    end
    for _, property in ipairs({ "CanvasPosition", "AbsoluteCanvasSize", "AbsoluteWindowSize" }) do
        scroller:GetPropertyChangedSignal(property):Connect(refresh)
    end
    task.defer(refresh)
end

function Window:_scrollTabIntoView(tab)
    local list = self.TabList
    local scale = self.Scale.Scale
    local top = (tab._button.AbsolutePosition.Y - list.AbsolutePosition.Y) / scale + list.CanvasPosition.Y
    local bottom = top + tab._button.AbsoluteSize.Y / scale
    local view = list.AbsoluteWindowSize.Y / scale
    local y = list.CanvasPosition.Y
    if top - 8 < y then
        y = top - 8
    elseif bottom + 8 > y + view then
        y = bottom + 8 - view
    else
        return
    end
    tween(list, { CanvasPosition = Vector2.new(0, math.max(0, y)) }, 0.35, Enum.EasingStyle.Quint)
end

function Window:_closePopups()
    if self._closePopup then
        self._closePopup()
    end
end

-- Popped-out groupboxes float on one screen-wide layer above the window. It
-- carries the window's scale, so a panel keeps the size it had in its column,
-- and it shows while the window is open (minimized included).
function Window:_popoutLayer()
    if self._popLayer then
        return self._popLayer
    end
    local layer = create("Frame", {
        Name = "PopOuts",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 20,
        Parent = self.Gui,
    })
    local layerScale = create("UIScale", { Parent = layer })
    self._popLayer = layer
    self._popPanels = {}
    self:_listen("Render", function()
        local scale = math.max(self.Scale.Scale, 0.05)
        if math.abs(layerScale.Scale - scale) > 1e-4 then
            layerScale.Scale = scale
            layer.Size = UDim2.fromScale(1 / scale, 1 / scale)
        end
        local shown = self.Open == true and not self._destroyed
        if layer.Visible ~= shown then
            layer.Visible = shown
        end
    end)
    return layer
end

-- Where a control's popup is drawn: the pop-out layer for one inside a
-- floating panel, otherwise the window body.
function Window:_popupHost(object)
    local layer = self._popLayer
    if layer and object and object:IsDescendantOf(layer) then
        return layer
    end
    return self.Body
end

-- A floating panel under the point counts as a control, so pressing it never
-- starts a window drag.
function Window:_overPopout(point)
    local layer = self._popLayer
    if not layer or not layer.Visible then
        return false
    end
    for _, panel in ipairs(self._popPanels) do
        if panel.Parent and panel.Visible and pointInside(point, panel) then
            return true
        end
    end
    return false
end

-- Fades the whole body by lending it to the fader CanvasGroup, then hands it
-- back to the root once fully shown so it renders directly again.
function Window:_fade(target, duration)
    local fader, body = self._fader, self.Body
    self._fadeGeneration = (self._fadeGeneration or 0) + 1
    local generation = self._fadeGeneration
    if body.Parent ~= fader then
        fader.GroupTransparency = self._bodyAlpha
        body.Parent = fader
    end
    fader.Visible = true
    self._bodyAlpha = target
    tween(fader, { GroupTransparency = target }, duration)
    task.delay(duration + 0.03, function()
        if self._fadeGeneration == generation and target <= 0 and not self._destroyed then
            body.Parent = self.Root
            fader.Visible = false
        end
    end)
end

function Window:SelectTab(tab)
    -- A tab handle, its name or its position in the sidebar.
    if type(tab) ~= "table" or getmetatable(tab) ~= Tab then
        local wanted = tab
        tab = nil
        for index, entry in ipairs(self.Tabs) do
            if entry.Name == wanted or index == wanted then
                tab = entry
                break
            end
        end
        if not tab then
            Library._warn(("SelectTab: no tab %s. Pass a tab, its name or its number."):format(Library._describe(wanted)))
            return
        end
    end
    if self.CurrentTab == tab or not tab._page then
        return
    end
    local previous = self.CurrentTab
    self:_resetSearch()
    self:_closePopups()
    self.CurrentTab = tab

    self:_settleTransition()
    local generation = (self._transitionGeneration or 0) + 1
    self._transitionGeneration = generation

    -- Performance Mode swaps pages in place: no page-sized CanvasGroup fades,
    -- which cost GPU memory and a reparent of every descendant.
    local light = Library.PerformanceMode
    if previous then
        tween(previous._label, { TextColor3 = Theme.Muted }, 0.3)
        if previous._icon then
            tintIcon(previous._icon, Theme.Muted, false, 0.3)
        end
    end
    if previous and light then
        previous._page.Visible = false
    elseif previous then
        local outLayer = self._outLayer
        previous._page.Parent = outLayer
        self._outPage = previous._page
        outLayer.GroupTransparency = 0
        outLayer.Position = UDim2.fromOffset(0, 0)
        outLayer.Visible = true
        tween(outLayer, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -6) }, 0.2, Enum.EasingStyle.Quint)
        task.delay(0.18, function()
            if self._transitionGeneration == generation then
                self:_settleOut()
            end
        end)
    end

    tween(tab._button, { BackgroundTransparency = 1 }, 0.2)
    tween(tab._stroke, { Transparency = 1 }, 0.2)
    tween(tab._label, { TextColor3 = Theme.Text }, 0.3)
    if tab._icon then
        tintIcon(tab._icon, Theme.Text, true, 0.3)
    end

    self:_placeIndicator(tab)
    self:_scrollTabIntoView(tab)

    local page = tab._page
    page.Position = UDim2.fromOffset(0, 0)
    page.Visible = true
    if light then
        return
    end
    page.Parent = self._inLayer
    self._inPage = page
    fadeSlideIn(self._inLayer)
    task.delay(0.32, function()
        if self._transitionGeneration == generation then
            self:_settleIn()
        end
    end)
end

function Window:_settleOut()
    local page = self._outPage
    -- A transition can still be pending when the window is destroyed; its pages
    -- are locked then.
    if self._destroyed then
        self._outPage = nil
        return
    end
    if page then
        page.Parent = self.Content
        page.Visible = false
        self._outPage = nil
    end
    self._outLayer.Visible = false
end

function Window:_settleIn()
    local page = self._inPage
    if self._destroyed then
        self._inPage = nil
        return
    end
    if page then
        page.Parent = self.Content
        page.Position = UDim2.fromOffset(0, 0)
        self._inPage = nil
    end
    self._inLayer.Visible = false
end

function Window:_settleTransition()
    self:_settleOut()
    self:_settleIn()
end


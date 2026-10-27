local function buildContainer(owner, parent, top, emptyIcon, emptyText)
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 1, -top),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = parent,
    })
    Library._space(padding(list, 24, 24, 2, 24), { 24, 24, 2, 24 })
    Library._space(create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = list,
    }), 8)
    owner.List = list
    owner._items = {}
    owner._groupboxes = {}
    owner._childCount = 0
    owner._emptyText = emptyText
    owner._empty, owner._emptyCaption = emptyState(parent, emptyIcon, emptyText)
    list.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            owner._childCount += 1
            owner:_refreshEmpty()
        end
    end)
    list.ChildRemoved:Connect(function(child)
        if child:IsA("GuiObject") then
            owner._childCount = math.max(owner._childCount - 1, 0)
            owner:_refreshEmpty()
        end
    end)
    owner:_refreshEmpty()
    return list
end

function Tab:_refreshEmpty()
    local empty = self._empty
    if not empty then
        return
    end
    if self._subTabs then
        empty.Visible = false
    else
        empty.Visible = self._childCount == 0
    end
end

function Tab:_columns()
    if self._columnSet then
        return self._columnSet
    end
    local holder = create("Frame", {
        Name = "Columns",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 100000,
        Parent = self.List,
    })
    local layout = Library._space(create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = holder,
    }), 10)
    local function column(order)
        local frame = create("Frame", {
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = holder,
        })
        Library._space(create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
            Parent = frame,
        }), 10)
        return frame
    end
    local set = { Holder = holder, Left = column(1), Right = column(2), Counts = { 0, 0 }, Stacked = false }
    local window = self.Window
    -- Narrow windows stack the right column under the left one.
    local function relayout()
        local width = holder.AbsoluteSize.X / window.Scale.Scale
        if width <= 0 then
            return
        end
        local stacked = width < STACK_BELOW
        local gap = layout.Padding.Offset
        if stacked == set.Stacked and gap == set.Gap then
            return
        end
        set.Stacked = stacked
        set.Gap = gap
        layout.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
        local size = stacked and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -gap / 2, 0, 0)
        set.Left.Size = size
        set.Right.Size = size
    end
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
    layout:GetPropertyChangedSignal("Padding"):Connect(relayout)
    task.defer(relayout)
    self._columnSet = set
    return set
end

function Tab:Groupbox(opts, icon)
    if self._groupbox then
        return self.Parent:Groupbox(opts, icon)
    end
    opts = normalize(opts, { Title = "Name" })
    if icon ~= nil and opts.Icon == nil then
        opts.Icon = icon
    end
    local window = self.Window
    local set = self:_columns()
    local side = opts.Side
    if side == "Left" or side == 1 then
        side = 1
    elseif side == "Right" or side == 2 then
        side = 2
    else
        side = set.Counts[1] <= set.Counts[2] and 1 or 2
    end
    set.Counts[side] += 1

    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = set.Counts[side],
        Parent = side == 1 and set.Left or set.Right,
    })
    box:SetAttribute("NoDrag", true)
    corner(box, UDim.new(0, 10))
    stroke(box)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = box,
    })

    -- The header is a filled strip: icon and bold title on the left, a
    -- chevron on the right. Pressing anywhere on it folds the box.
    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = box,
    })
    corner(header, UDim.new(0, 10))
    -- Squares the strip's lower corners so it meets the body flat.
    local headerFill = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = header,
    })
    local titleX = 14
    if opts.Icon then
        local headerIcon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Accent,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
            Parent = header,
        })
        applyIcon(headerIcon, opts.Icon)
        titleX = 37
    end
    local collapseButton = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 2,
        Parent = header,
    })
    applyIcon(collapseButton, "chevron-down")
    -- Beside the chevron, a button that pops the box out into a floating
    -- panel (and docks it back once it's out). PopOut = false leaves it off.
    local canPop = opts.PopOut ~= false
    local popButton, popIcon
    if canPop then
        popButton = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -34, 0.5, 0),
            Size = UDim2.fromOffset(24, 24),
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 3,
            Parent = header,
        })
        corner(popButton, UDim.new(0, 6))
        popIcon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(13, 13),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Muted,
            ImageTransparency = TOUCH and 0 or 0.45,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 3,
            Parent = popButton,
        })
        applyIcon(popIcon, "picture-in-picture-2")
    end
    local title = label({
        Position = UDim2.fromOffset(titleX, 0),
        Size = UDim2.new(1, -(titleX + (canPop and 66 or 40)), 1, 0),
        Text = opts.Name or "Groupbox",
        TextSize = 13,
        FontFace = Fonts.Bold,
        ZIndex = 2,
        Parent = header,
    })

    local rule = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = box,
    })
    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 3,
        Parent = box,
    })
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = body,
    })
    Library._space(padding(inner, 0, 0, 6, 8), { 0, 0, 6, 8 })
    Library._space(create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = inner,
    }), 2)

    local group = setmetatable({
        Name = opts.Name or "Groupbox",
        Window = window,
        Parent = self,
        List = inner,
        Frame = box,
        _frame = box,
        _order = 0,
        _groupbox = true,
        _metrics = METRICS.Row,
        _items = {},
    }, Tab)
    table.insert(self._groupboxes, group)
    -- A groupbox named "Menu" gets the built-in "Minimize UI on Start" toggle,
    -- so existing scripts pick it up without calling CreateMinimizeOnStart.
    -- It lands above the first button (usually Unload), or at the end.
    if type(group.Name) == "string" and string.lower(group.Name:match("^%s*(.-)%s*$")) == "menu" then
        task.defer(function()
            if window._destroyed or window._minimizeOnStartToggle or not box.Parent then
                return
            end
            local toggle = group:CreateMinimizeOnStart()
            local frame = toggle and toggle._frame
            if not frame then
                return
            end
            local before
            for _, element in ipairs(group._items) do
                local other = element._frame
                if element._type == "Button" and other and other.Parent == frame.Parent
                    and (not before or other.LayoutOrder < before.LayoutOrder) then
                    before = other
                end
            end
            if before then
                local order = before.LayoutOrder
                for _, child in ipairs(frame.Parent:GetChildren()) do
                    if child:IsA("GuiObject") and child ~= frame and child.LayoutOrder >= order then
                        child.LayoutOrder += 1
                    end
                end
                frame.LayoutOrder = order
                group._order += 1
            end
        end)
    end

    local collapsed = false
    local generation = 0
    local function setCollapsed(value, instant)
        value = value == true
        if value == collapsed then
            return
        end
        collapsed = value
        generation += 1
        local current = generation
        local duration = instant and 0 or 0.32
        -- Anything open inside the box (a dropdown list, a picker, a focused
        -- box) closes with it, rather than floating over a folded header.
        if value then
            for _, element in ipairs(group._items) do
                if element._onHide then
                    element._onHide()
                end
                if element.Open and type(element.SetOpen) == "function" then
                    element:SetOpen(false)
                end
            end
        end
        window._controlsDirty = true
        local scale = window.Scale.Scale
        if value then
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y / scale)
            tween(body, { Size = UDim2.new(1, 0, 0, 0) }, duration, Enum.EasingStyle.Quint)
        else
            tween(body, { Size = UDim2.new(1, 0, 0, inner.AbsoluteSize.Y / scale) }, duration, Enum.EasingStyle.Quint)
            local function settle()
                if generation == current and not collapsed then
                    body.AutomaticSize = Enum.AutomaticSize.Y
                    body.Size = UDim2.new(1, 0, 0, 0)
                end
            end
            if duration > 0 then
                task.delay(duration, settle)
            else
                settle()
            end
        end
        local motion = instant and 0 or 0.3
        -- Folded, the strip is the whole box: the hairline under it drops out
        -- of the layout once the body has closed, so the box ends exactly at
        -- the strip and both share the same rounded corners.
        if value then
            local function fold()
                if generation == current and collapsed then
                    rule.Visible = false
                    headerFill.Visible = false
                end
            end
            if duration > 0 then
                task.delay(duration, fold)
            else
                fold()
            end
        else
            rule.Visible = true
            headerFill.Visible = true
        end
        tween(collapseButton, { Rotation = value and -90 or 0 }, motion, Enum.EasingStyle.Quint)
    end

    local function hover(on)
        local duration = on and 0.15 or 0.25
        tween(collapseButton, { ImageColor3 = on and Theme.Text or Theme.Muted }, duration)
        if popIcon and not TOUCH then
            tween(popIcon, { ImageTransparency = on and 0 or 0.45 }, duration)
        end
    end
    header.MouseEnter:Connect(function()
        hover(true)
    end)
    header.MouseLeave:Connect(function()
        hover(false)
    end)
    local isTap = tapGuard(header, function()
        return box:FindFirstAncestorWhichIsA("ScrollingFrame")
    end)
    -- Popping out: the box itself is lifted out of its column into a panel
    -- on the window's pop-out layer, and a slot holds its place in the column
    -- (pressing the slot docks it back). The header drags the panel; a drop
    -- is clamped on screen and the spot is remembered for the next pop-out.
    local popped, popGeneration = false, 0
    local panel, panelScale, panelShadow, slot, stopPanel
    local dragStart, dragOrigin, dragMoved, suppressClick = nil, nil, false, false
    -- PC only: dragging a docked header pops it out under the cursor.
    local pendingPop
    -- The panel's bottom-right grip resizes it; a set height scrolls the box.
    local resizeStart, resizeOrigin, resizeHeight
    local MIN_POP_WIDTH, MIN_POP_HEIGHT = 200, 80
    local animating = false

    local function layerScale()
        return math.max(window.Scale.Scale, 0.05)
    end
    local function toLayer(point)
        return (point - window._popLayer.AbsolutePosition) / layerScale()
    end
    -- Keeps a panel's top-centre spot on screen, header always reachable.
    local function clampSpot(spot, width, height)
        local view = window._popLayer.AbsoluteSize / layerScale()
        local margin = 8
        local x = math.clamp(spot.X, width / 2 + margin, math.max(view.X - width / 2 - margin, width / 2 + margin))
        local y = math.clamp(spot.Y, margin, math.max(view.Y - math.min(height, 120) - margin, margin))
        return Vector2.new(x, y)
    end
    local function closeInner()
        for _, element in ipairs(group._items) do
            if element._onHide then
                element._onHide()
            end
            if element.Open and type(element.SetOpen) == "function" then
                element:SetOpen(false)
            end
        end
    end
    local function setPopIcon(out)
        if popIcon then
            applyIcon(popIcon, out and "minimize-2" or "picture-in-picture-2")
        end
    end

    local finishPop
    local function popOut(fromDrag)
        if popped or not canPop or not box.Parent or group._destroyed then
            return
        end
        -- A dock still in flight lands first, so the box is back in its column.
        if group._settleDock then
            group._settleDock()
        end
        local layer = window:_popoutLayer()
        popped = true
        group._popped = true
        popGeneration += 1
        local current = popGeneration
        closeInner()
        window:_closePopups()
        local scale = layerScale()
        local column = box.Parent
        local from = toLayer(box.AbsolutePosition)
        local width = box.AbsoluteSize.X / scale
        local height = box.AbsoluteSize.Y / scale

        -- The slot left behind: starts at the box's height so nothing below
        -- jumps, then eases down to a slim bar.
        slot = create("TextButton", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = box.LayoutOrder,
            Parent = column,
        })
        slot:SetAttribute("NoDrag", true)
        corner(slot, UDim.new(0, 10))
        stroke(slot, Theme.Stroke, 1).Transparency = 0.3
        local slotLabel = label({
            Size = UDim2.new(1, -24, 0, 40),
            Position = UDim2.fromOffset(12, 0),
            Text = Library._rich(group.Name) .. '<font transparency="0.4">  ·  popped out, click to dock</font>',
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            RichText = true,
            TextTransparency = 1,
            Parent = slot,
        })
        local thisSlot = slot
        slot.MouseEnter:Connect(function()
            tween(thisSlot, { BackgroundTransparency = 0.35 }, 0.15)
        end)
        slot.MouseLeave:Connect(function()
            tween(thisSlot, { BackgroundTransparency = 0.6 }, 0.25)
        end)
        slot.MouseButton1Click:Connect(function()
            if slot == thisSlot then
                group:Dock()
            end
        end)
        tween(slot, { Size = UDim2.new(1, 0, 0, 40) }, 0.42, Enum.EasingStyle.Quint)
        tween(slotLabel, { TextTransparency = 0 }, 0.3)
        slot.Visible = box.Visible

        panel = create("Frame", {
            Name = "PopOut",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromOffset(from.X + width / 2, from.Y),
            Size = UDim2.fromOffset(width, height),
            BackgroundTransparency = 1,
            Parent = layer,
        })
        panel:SetAttribute("NoDrag", true)
        panelScale = create("UIScale", { Parent = panel })
        panelShadow = create("ImageLabel", {
            Position = UDim2.fromOffset(-24, -18),
            Size = UDim2.new(1, 48, 1, 44),
            BackgroundTransparency = 1,
            Image = Assets.Shadow,
            ImageColor3 = Color3.new(0, 0, 0),
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(49, 49, 450, 450),
            ZIndex = 0,
            Parent = panel,
        })
        -- The box sits in a scroller, so a panel resized shorter than the
        -- box still reaches every row.
        local holder = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Muted,
            VerticalScrollBarInset = Enum.ScrollBarInset.None,
            ElasticBehavior = Enum.ElasticBehavior.Never,
            ZIndex = 1,
            Parent = panel,
        })
        holder:SetAttribute("NoDrag", true)
        -- Edges and corners all resize: each handle carries the sides it
        -- moves (-1 left/top, 1 right/bottom, 0 untouched).
        local edge = TOUCH and 12 or 7
        local handles = {
            { -1, -1 }, { 0, -1 }, { 1, -1 },
            { -1, 0 }, { 1, 0 },
            { -1, 1 }, { 0, 1 }, { 1, 1 },
        }
        local gripIcon
        for _, dir in ipairs(handles) do
            local dx, dy = dir[1], dir[2]
            local handle = create("TextButton", {
                AnchorPoint = Vector2.new((dx + 1) / 2, (dy + 1) / 2),
                Position = UDim2.new((dx + 1) / 2, dx * edge / 2, (dy + 1) / 2, dy * edge / 2),
                Size = UDim2.new(dx == 0 and 1 or 0, dx == 0 and -edge * 2 or edge * 2, dy == 0 and 1 or 0, dy == 0 and -edge * 2 or edge * 2),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = (dx ~= 0 and dy ~= 0) and 21 or 20,
                Parent = panel,
            })
            handle:SetAttribute("NoDrag", true)
            if dx == 1 and dy == 1 then
                gripIcon = create("ImageLabel", {
                    AnchorPoint = Vector2.new(1, 1),
                    Position = UDim2.new(1, -edge - 2, 1, -edge - 2),
                    Size = UDim2.fromOffset(11, 11),
                    BackgroundTransparency = 1,
                    ImageColor3 = Theme.Muted,
                    ImageTransparency = 0.35,
                    Rotation = 90,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 21,
                    Parent = handle,
                })
                applyIcon(gripIcon, "move-diagonal-2")
            end
            handle.MouseEnter:Connect(function()
                tween(gripIcon, { ImageColor3 = Theme.Text, ImageTransparency = 0 }, 0.15)
            end)
            handle.MouseLeave:Connect(function()
                tween(gripIcon, { ImageColor3 = Theme.Muted, ImageTransparency = 0.35 }, 0.25)
            end)
            handle.InputBegan:Connect(function(input)
                if not popped or not isPress(input) or not panel then
                    return
                end
                local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
                local left = panel.Position.X.Offset - w / 2
                local top = panel.Position.Y.Offset
                resizeStart = Vector2.new(input.Position.X, input.Position.Y)
                resizeOrigin = { left, top, left + w, top + h, dx, dy }
                animating = false
                closeInner()
                window:_closePopups()
            end)
        end
        table.insert(window._popPanels, panel)
        box.Parent = holder
        if group._popWidth then
            width = math.max(group._popWidth, MIN_POP_WIDTH)
            panel.Size = UDim2.fromOffset(width, height)
        end
        resizeHeight = group._popHeight
        window._controlsDirty = true
        setPopIcon(true)

        -- Lifts off the column: a spring up and out to its float spot, with
        -- the shadow deepening under it.
        if fromDrag then
            -- Picked up by a drag: no flight, it stays under the cursor.
            panelScale.Scale = 1.025
            panelShadow.ImageTransparency = 0.15
            finishPop(current)
            return
        end
        local spot = clampSpot(group._popSpot or Vector2.new(from.X + width / 2 + 22, from.Y - 14), width, height)
        animating = true
        panelScale.Scale = 0.97
        tween(panel, { Position = UDim2.fromOffset(spot.X, spot.Y) }, 0.5, Enum.EasingStyle.Quint)
        tween(panelScale, { Scale = 1 }, 0.55, Enum.EasingStyle.Back)
        tween(panelShadow, { ImageTransparency = 0.35 }, 0.4)
        finishPop(current)
    end

    function finishPop(current)
        task.delay(0.5, function()
            if popGeneration == current then
                animating = false
            end
        end)

        -- Each frame: the panel follows the box's height (folding, rows
        -- coming and going), mirrors its visibility, and stays on screen.
        local thisPanel = panel
        stopPanel = window:_listen("Render", function()
            -- The pop-out layer is hidden with the window; nothing to follow then.
            if panel ~= thisPanel or not thisPanel.Parent or not window.Open then
                return
            end
            -- A set height is the panel's height: a taller box scrolls in it,
            -- a shorter one stretches to fill it (unless folded).
            local fixed = not collapsed and resizeHeight or nil
            local minSize = UDim2.new(1, 0, 0, fixed or 0)
            if box.Size ~= minSize then
                box.Size = minSize
            end
            local boxHeight = box.AbsoluteSize.Y / layerScale()
            local panelHeight = fixed or boxHeight
            if not resizeStart and math.abs(thisPanel.Size.Y.Offset - panelHeight) > 0.5 then
                thisPanel.Size = UDim2.fromOffset(thisPanel.Size.X.Offset, panelHeight)
            end
            if thisPanel.Visible ~= box.Visible then
                thisPanel.Visible = box.Visible
            end
            if slot and slot.Visible ~= box.Visible then
                slot.Visible = box.Visible
            end
            if not animating and not dragStart and not resizeStart then
                local position = Vector2.new(thisPanel.Position.X.Offset, thisPanel.Position.Y.Offset)
                local clamped = clampSpot(position, thisPanel.Size.X.Offset, panelHeight)
                if (clamped - position).Magnitude > 0.5 then
                    thisPanel.Position = UDim2.fromOffset(clamped.X, clamped.Y)
                end
            end
        end)
    end

    local function dock(instant)
        if not popped then
            return
        end
        popped = false
        group._popped = false
        popGeneration += 1
        dragStart, dragMoved, suppressClick = nil, false, false
        resizeStart, pendingPop = nil, nil
        box.Size = UDim2.new(1, 0, 0, 0)
        closeInner()
        window:_closePopups()
        local oldPanel, oldSlot, oldStop, oldScale, oldShadow = panel, slot, stopPanel, panelScale, panelShadow
        panel, slot, stopPanel = nil, nil, nil
        setPopIcon(false)
        group._popSpot = Vector2.new(oldPanel.Position.X.Offset, oldPanel.Position.Y.Offset)
        local settled = false
        local function settle()
            if settled then
                return
            end
            settled = true
            if group._settleDock == settle then
                group._settleDock = nil
            end
            if oldStop then
                oldStop()
            end
            local index = table.find(window._popPanels, oldPanel)
            if index then
                table.remove(window._popPanels, index)
            end
            -- Back into the column, unless it was popped again meanwhile.
            if box:IsDescendantOf(oldPanel) then
                if oldSlot and oldSlot.Parent and not group._destroyed then
                    box.Parent = oldSlot.Parent
                    box.LayoutOrder = oldSlot.LayoutOrder
                end
            end
            if oldSlot then
                oldSlot:Destroy()
            end
            if not box:IsDescendantOf(oldPanel) then
                oldPanel:Destroy()
            end
            animating = false
            window._controlsDirty = true
        end
        group._settleDock = settle
        -- Flies home only when its slot is on screen; otherwise (another tab,
        -- the window hidden) it just drops back into place.
        local canFly = not instant and oldSlot and oldSlot.Parent and window.Root.Visible and box.Visible
            and oldSlot.AbsoluteSize.X > 0 and isShown(oldSlot, window.Body, oldSlot.AbsolutePosition + oldSlot.AbsoluteSize / 2)
        if not canFly then
            settle()
            return
        end
        animating = true
        local scale = layerScale()
        local height = box.AbsoluteSize.Y / scale
        local width = oldSlot.AbsoluteSize.X / scale
        tween(oldSlot, { Size = UDim2.new(1, 0, 0, height) }, 0.36, Enum.EasingStyle.Quint)
        local oldLabel = oldSlot:FindFirstChildWhichIsA("TextLabel")
        if oldLabel then
            tween(oldLabel, { TextTransparency = 1 }, 0.12)
        end
        -- The slot's top stays put as it grows, so its spot is the landing.
        local target = toLayer(oldSlot.AbsolutePosition)
        tween(oldPanel, {
            Position = UDim2.fromOffset(target.X + width / 2, target.Y),
            Size = UDim2.fromOffset(width, height),
        }, 0.36, Enum.EasingStyle.Quint)
        tween(oldScale, { Scale = 1 }, 0.2)
        tween(oldShadow, { ImageTransparency = 1 }, 0.3)
        task.delay(0.37, settle)
    end

    -- Dragging the floating panel by its header.
    header.InputBegan:Connect(function(input)
        if not popped and canPop and not TOUCH and isPress(input) then
            pendingPop = Vector2.new(input.Position.X, input.Position.Y)
            return
        end
        if not popped or not isPress(input) or not panel then
            return
        end
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        dragOrigin = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
        dragMoved = false
        suppressClick = false
    end)
    window:_listen("Changed", function(input)
        if not isMove(input) then
            return
        end
        if resizeStart and panel then
            local delta = (Vector2.new(input.Position.X, input.Position.Y) - resizeStart) / layerScale()
            local view = window._popLayer.AbsoluteSize / layerScale()
            local boxHeight = box.AbsoluteSize.Y / layerScale()
            local left, top, right, bottom, dx, dy = table.unpack(resizeOrigin)
            local maxWidth = math.max(view.X - 16, MIN_POP_WIDTH)
            local minHeight = MIN_POP_HEIGHT
            local maxHeight = math.max(view.Y - 16, MIN_POP_HEIGHT)
            -- The dragged side moves; the opposite one stays put.
            if dx == 1 then
                right = left + math.clamp(right - left + delta.X, MIN_POP_WIDTH, maxWidth)
            elseif dx == -1 then
                left = right - math.clamp(right - left - delta.X, MIN_POP_WIDTH, maxWidth)
            end
            if dy == 1 then
                bottom = top + math.clamp(bottom - top + delta.Y, minHeight, maxHeight)
            elseif dy == -1 then
                top = bottom - math.clamp(bottom - top - delta.Y, minHeight, maxHeight)
            end
            local newHeight = bottom - top
            if dy ~= 0 then
                resizeHeight = newHeight
            end
            panel.Size = UDim2.fromOffset(right - left, newHeight)
            panel.Position = UDim2.fromOffset((left + right) / 2, top)
            window._controlsDirty = true
            return
        end
        if pendingPop and not popped then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - pendingPop
            if delta.Magnitude < 2 then
                return
            end
            local start = pendingPop
            pendingPop = nil
            window:_popoutLayer()
            local origin = toLayer(box.AbsolutePosition) + Vector2.new(box.AbsoluteSize.X / layerScale() / 2, 0)
            popOut(true)
            if not popped or not panel then
                return
            end
            dragStart, dragOrigin = start, origin
            dragMoved, suppressClick = true, true
            animating = false
        end
        if not dragStart or not panel then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        if not dragMoved then
            if delta.Magnitude < (TOUCH and 8 or 5) then
                return
            end
            dragMoved, suppressClick = true, true
            animating = false
            closeInner()
            window:_closePopups()
            tween(panelScale, { Scale = 1.025 }, 0.18, Enum.EasingStyle.Quint)
            tween(panelShadow, { ImageTransparency = 0.15 }, 0.18)
        end
        local spot = clampSpot(dragOrigin + delta / layerScale(), panel.Size.X.Offset, panel.Size.Y.Offset)
        panel.Position = UDim2.fromOffset(spot.X, spot.Y)
    end, group)
    window:_listen("Ended", function(input)
        if not isPress(input) then
            return
        end
        pendingPop = nil
        if resizeStart then
            resizeStart = nil
            if panel then
                group._popWidth = panel.Size.X.Offset
                group._popHeight = resizeHeight
                group._popSpot = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
            end
        end
        if not dragStart then
            return
        end
        dragStart = nil
        if dragMoved and panel then
            dragMoved = false
            tween(panelScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
            tween(panelShadow, { ImageTransparency = 0.35 }, 0.3)
            group._popSpot = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
        end
    end, group)
    if popButton then
        popButton.MouseEnter:Connect(function()
            tween(popButton, { BackgroundTransparency = 0 }, 0.15)
            tween(popIcon, { ImageColor3 = Theme.Text }, 0.15)
        end)
        popButton.MouseLeave:Connect(function()
            tween(popButton, { BackgroundTransparency = 1 }, 0.25)
            tween(popIcon, { ImageColor3 = Theme.Muted }, 0.25)
        end)
        popButton.MouseButton1Click:Connect(function()
            if popped then
                dock()
            else
                popOut()
            end
        end)
    end

    header.MouseButton1Click:Connect(function()
        if suppressClick then
            suppressClick = false
            return
        end
        if isTap() then
            setCollapsed(not collapsed)
        end
    end)

    function group:PopOut()
        popOut()
    end
    function group:Dock()
        dock()
    end
    function group:IsPoppedOut()
        return popped
    end
    function group:SetCollapsed(value)
        setCollapsed(value)
    end
    function group:Collapse()
        setCollapsed(true)
    end
    function group:Expand()
        setCollapsed(false)
    end
    function group:IsCollapsed()
        return collapsed
    end
    function group:SetTitle(text)
        group.Name = tostring(text)
        title.Text = group.Name
    end
    group._userVisible = opts.Visible ~= false
    function group:IsVisible()
        return group._userVisible
    end
    function group:SetVisible(visible)
        visible = visible and true or false
        if visible == group._userVisible then
            return
        end
        group._userVisible = visible
        if not visible then
            for _, element in ipairs(group._items) do
                if element._onHide then
                    element._onHide()
                end
                if element.Open and type(element.SetOpen) == "function" then
                    element:SetOpen(false)
                end
            end
        end
        box.Visible = visible
        window._controlsDirty = true
    end
    if not group._userVisible then
        box.Visible = false
    end
    function group:Destroy()
        for index = #group._items, 1, -1 do
            local element = group._items[index]
            if type(element.Destroy) == "function" then
                element:Destroy()
            end
        end
        local owner = group.Parent
        local index = table.find(owner._groupboxes, group)
        if index then
            table.remove(owner._groupboxes, index)
        end
        set.Counts[side] = math.max(set.Counts[side] - 1, 0)
        dock(true)
        group._destroyed = true
        -- The box's own window input listeners (pop-out drag and the like).
        for _, disconnect in ipairs(group._listeners or {}) do
            disconnect()
        end
        group._listeners = {}
        window._controlsDirty = true
        box:Destroy()
    end

    if opts.Collapsed then
        setCollapsed(true, true)
    end
    if opts.PoppedOut then
        task.defer(popOut)
    end
    return group
end

local function sideGroupbox(side)
    return function(self, opts, icon)
        opts = normalize(opts, { Title = "Name" })
        opts.Side = side
        return self:Groupbox(opts, icon)
    end
end

-- Built-in "Minimize UI on Start" toggle; not a config flag, it saves itself.
function Tab:CreateMinimizeOnStart(opts)
    opts = opts or {}
    local window = self.Window
    if window._minimizeOnStartToggle then
        return window._minimizeOnStartToggle
    end
    window._minimizeOnStartToggle = self:CreateToggle({
        Name = opts.Name or "Minimize UI on Start",
        CurrentValue = window:GetMinimizeOnStart(),
        Callback = function(value)
            window:SetMinimizeOnStart(value)
        end,
    })
    return window._minimizeOnStartToggle
end

Tab.CreateGroupbox = Tab.Groupbox
Tab.AddGroupbox = Tab.Groupbox
Tab.AddLeftGroupbox = sideGroupbox("Left")
Tab.AddRightGroupbox = sideGroupbox("Right")

-- Tabboxes: a groupbox whose header is a row of tabs. Each tab is its own
-- page of rows and only the selected one shows (Obsidian's AddLeftTabbox).
function Tab:Tabbox(opts)
    if self._groupbox then
        return self.Parent:Tabbox(opts)
    end
    opts = normalize(opts, { Title = "Name" })
    local owner = self
    local window = self.Window
    local set = self:_columns()
    local side = opts.Side
    if side == "Left" or side == 1 then
        side = 1
    elseif side == "Right" or side == 2 then
        side = 2
    else
        side = set.Counts[1] <= set.Counts[2] and 1 or 2
    end
    set.Counts[side] += 1

    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = set.Counts[side],
        Parent = side == 1 and set.Left or set.Right,
    })
    box:SetAttribute("NoDrag", true)
    corner(box, UDim.new(0, 10))
    stroke(box)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = box,
    })
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = box,
    })
    corner(header, UDim.new(0, 10))
    create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = header,
    })
    local strip = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = header,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = strip,
    })
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = box,
    })
    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 3,
        Parent = box,
    })

    local tabbox = {
        Name = opts.Name or "Tabbox",
        Window = window,
        Parent = owner,
        Frame = box,
        Tabs = {},
        _frame = box,
        _userVisible = opts.Visible ~= false,
    }

    local function closeOpen(page)
        for _, element in ipairs(page._items) do
            if element._onHide then
                element._onHide()
            end
            if element.Open and type(element.SetOpen) == "function" then
                element:SetOpen(false)
            end
        end
    end

    -- Buttons share the strip evenly; the selected one takes the body's fill
    -- and an accent underline, so it reads as joined to the page below.
    local function relayoutButtons()
        local count = math.max(#tabbox.Tabs, 1)
        for _, page in ipairs(tabbox.Tabs) do
            page._button.Size = UDim2.new(1 / count, 0, 1, 0)
        end
    end
    local function paint(page, instant)
        local on = tabbox.Current == page
        local duration = instant and 0 or 0.2
        tween(page._button, { BackgroundTransparency = on and 0 or 1 }, duration)
        tween(page._label, { TextColor3 = on and Theme.Text or Theme.Muted }, duration)
        tween(page._bar, { BackgroundTransparency = on and 0 or 1 }, duration)
        if page._icon then
            tween(page._icon, { ImageColor3 = on and Theme.Accent or Theme.Muted }, duration)
        end
    end

    function tabbox:SelectTab(page)
        if type(page) == "string" or type(page) == "number" then
            local found
            for index, other in ipairs(tabbox.Tabs) do
                if other.Title == page or index == page then
                    found = other
                end
            end
            page = found
        end
        if not page or page._destroyed or tabbox.Current == page then
            return
        end
        local previous = tabbox.Current
        if previous then
            closeOpen(previous)
            previous._userVisible = false
            previous.List.Visible = false
        end
        tabbox.Current = page
        page._userVisible = tabbox._userVisible
        page.List.Visible = true
        for _, other in ipairs(tabbox.Tabs) do
            paint(other, previous == nil)
        end
        window._controlsDirty = true
    end

    function tabbox:AddTab(name, icon)
        local tabOpts = normalize(name, { Title = "Name" })
        if icon ~= nil and tabOpts.Icon == nil then
            tabOpts.Icon = icon
        end
        local tabName = tabOpts.Name or ("Tab " .. (#tabbox.Tabs + 1))
        local button = create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = #tabbox.Tabs + 1,
            ZIndex = 2,
            Parent = strip,
        })
        local content = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -12, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 2,
            Parent = button,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = content,
        })
        local tabIcon
        if tabOpts.Icon then
            tabIcon = create("ImageLabel", {
                Size = UDim2.fromOffset(13, 13),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Muted,
                ScaleType = Enum.ScaleType.Fit,
                LayoutOrder = 1,
                ZIndex = 2,
                Parent = content,
            })
            applyIcon(tabIcon, tabOpts.Icon)
        end
        local tabLabel = label({
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = tabName,
            TextSize = 13,
            FontFace = Fonts.Bold,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            LayoutOrder = 2,
            ZIndex = 2,
            Parent = content,
        })
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 1),
            Size = UDim2.new(1, -16, 0, 2),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = button,
        })
        corner(bar, UDim.new(1, 0))

        local inner = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
            Parent = body,
        })
        Library._space(padding(inner, 0, 0, 6, 8), { 0, 0, 6, 8 })
        Library._space(create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
            Parent = inner,
        }), 2)

        local page = setmetatable({
            Name = tabbox.Name .. " › " .. tabName,
            Title = tabName,
            Window = window,
            Parent = owner,
            Tabbox = tabbox,
            List = inner,
            Frame = box,
            _frame = box,
            _order = 0,
            _groupbox = true,
            _metrics = METRICS.Row,
            _items = {},
            _userVisible = false,
            _button = button,
            _label = tabLabel,
            _icon = tabIcon,
            _bar = bar,
        }, Tab)
        -- Search treats an unselected tab as folded: expanding it selects it.
        function page:IsCollapsed()
            return tabbox.Current ~= page
        end
        function page:Expand()
            tabbox:SelectTab(page)
        end
        function page:Collapse() end
        function page:Select()
            tabbox:SelectTab(page)
        end
        function page:SetTitle(text)
            page.Title = tostring(text)
            page.Name = tabbox.Name .. " › " .. page.Title
            tabLabel.Text = page.Title
        end
        function page:Destroy()
            for index = #page._items, 1, -1 do
                local element = page._items[index]
                if type(element.Destroy) == "function" then
                    element:Destroy()
                end
            end
            page._destroyed = true
            for _, disconnect in ipairs(page._listeners or {}) do
                disconnect()
            end
            page._listeners = {}
            local at = table.find(tabbox.Tabs, page)
            if at then
                table.remove(tabbox.Tabs, at)
            end
            at = table.find(owner._groupboxes, page)
            if at then
                table.remove(owner._groupboxes, at)
            end
            button:Destroy()
            inner:Destroy()
            relayoutButtons()
            if tabbox.Current == page then
                tabbox.Current = nil
                if tabbox.Tabs[1] then
                    tabbox:SelectTab(tabbox.Tabs[1])
                end
            end
            window._controlsDirty = true
        end

        button.MouseEnter:Connect(function()
            if tabbox.Current ~= page then
                tween(tabLabel, { TextColor3 = Theme.Text }, 0.15)
            end
        end)
        button.MouseLeave:Connect(function()
            if tabbox.Current ~= page then
                tween(tabLabel, { TextColor3 = Theme.Muted }, 0.15)
            end
        end)
        button.Activated:Connect(function()
            tabbox:SelectTab(page)
        end)

        table.insert(tabbox.Tabs, page)
        table.insert(owner._groupboxes, page)
        relayoutButtons()
        if not tabbox.Current then
            tabbox:SelectTab(page)
        else
            paint(page, true)
        end
        return page
    end
    tabbox.CreateTab = tabbox.AddTab
    tabbox.Tab = tabbox.AddTab

    function tabbox:SetTitle(text)
        tabbox.Name = tostring(text)
        for _, page in ipairs(tabbox.Tabs) do
            page.Name = tabbox.Name .. " › " .. page.Title
        end
    end
    function tabbox:IsVisible()
        return tabbox._userVisible
    end
    function tabbox:SetVisible(visible)
        visible = visible and true or false
        if visible == tabbox._userVisible then
            return
        end
        tabbox._userVisible = visible
        if tabbox.Current then
            if not visible then
                closeOpen(tabbox.Current)
            end
            tabbox.Current._userVisible = visible
        end
        box.Visible = visible
        window._controlsDirty = true
    end
    if not tabbox._userVisible then
        box.Visible = false
    end
    function tabbox:Destroy()
        for index = #tabbox.Tabs, 1, -1 do
            tabbox.Tabs[index]:Destroy()
        end
        set.Counts[side] = math.max(set.Counts[side] - 1, 0)
        tabbox._destroyed = true
        window._controlsDirty = true
        box:Destroy()
    end

    for _, entry in ipairs(opts.Tabs or {}) do
        tabbox:AddTab(entry)
    end
    return tabbox
end

Tab.CreateTabbox = Tab.Tabbox
Tab.AddTabbox = Tab.Tabbox
function Tab:AddLeftTabbox(opts)
    opts = normalize(opts, { Title = "Name" })
    opts.Side = "Left"
    return self:Tabbox(opts)
end
function Tab:AddRightTabbox(opts)
    opts = normalize(opts, { Title = "Name" })
    opts.Side = "Right"
    return self:Tabbox(opts)
end

-- Button rows: equal-width buttons side by side.


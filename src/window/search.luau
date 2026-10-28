function Window:_searchResults(query)
    local results = {}
    local function consider(name, entry)
        if type(name) ~= "string" or name == "" then
            return
        end
        local at = string.find(string.lower(name), query, 1, true)
        if not at then
            return
        end
        entry.Name = name
        entry.At = at
        -- Name starts first, then word starts, then anywhere inside a word.
        entry.Rank = at == 1 and 0 or (string.find(string.sub(name, at - 1, at - 1), "[%s%p]") and 1 or 2)
        entry.Order = #results + 1
        table.insert(results, entry)
    end
    local function shown(element)
        return not element._destroyed
            and element._type ~= "Section" and element._type ~= "Divider"
            and (element._isShown == nil or element:_isShown())
    end
    for _, tab in ipairs(self.Tabs) do
        consider(tab.Name, { Kind = "Tab", Tab = tab, Icon = tab._iconName })
        for _, page in ipairs(tab._subTabs or { tab }) do
            local sub = page._isSubTab and page or nil
            local path = tab.Name
            if sub then
                consider(sub.Name, { Kind = "Page", Tab = tab, Sub = sub, Path = tab.Name })
                path = tab.Name .. "  ›  " .. sub.Name
            end
            if not page._noSearch then
                for _, element in ipairs(page._items or {}) do
                    if shown(element) then
                        consider(element._searchName, { Kind = element._type, Tab = tab, Sub = sub, Target = element, Path = path })
                    end
                end
                for _, group in ipairs(page._groupboxes or {}) do
                    if Library._pageShown(group) then
                        consider(group.Name, { Kind = "Groupbox", Tab = tab, Sub = sub, Target = group, Path = path })
                        local groupPath = path .. "  ›  " .. group.Name
                        for _, element in ipairs(group._items) do
                            if shown(element) then
                                consider(element._searchName, { Kind = element._type, Tab = tab, Sub = sub, Target = element, Group = group, Path = groupPath })
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(results, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank < b.Rank
        end
        return a.Order < b.Order
    end)
    return results
end

-- Marks a found control: it pops, a soft accent glow blooms around it, a
-- sheen of light sweeps across it and a bright spot runs round its border,
-- then everything breathes once more and fades.
function Window:_flash(frame, radius)
    for _, name in ipairs({ "SearchFlash", "SearchGlow" }) do
        local old = frame:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
    radius = radius or 8
    local accent = Theme.Accent
    local bright = accent:Lerp(Color3.new(1, 1, 1), 0.65)

    -- Outer glow: a wide, faint stroke around a second outline.
    local halo = create("Frame", {
        Name = "SearchGlow",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
        Parent = frame,
    })
    corner(halo, UDim.new(0, radius))
    local haloStroke = create("UIStroke", {
        Color = accent,
        Thickness = 1,
        Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = halo,
    })

    -- Wash with a moving sheen: a brighter diagonal band crosses it once.
    local wash = create("Frame", {
        Name = "SearchFlash",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = frame,
    })
    corner(wash, UDim.new(0, radius))
    local sheen = create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.7),
            NumberSequenceKeypoint.new(0.4, 0.55),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.6, 0.55),
            NumberSequenceKeypoint.new(1, 0.7),
        }),
        Rotation = 18,
        Offset = Vector2.new(-1, 0),
        Parent = wash,
    })

    -- Border light: the ring's gradient turns, so a bright spot runs round it.
    local ring = create("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 1.6,
        Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = wash,
    })
    local runner = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accent),
            ColorSequenceKeypoint.new(0.5, bright),
            ColorSequenceKeypoint.new(1, accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.45),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 0.45),
        }),
        Parent = ring,
    })

    -- Groupboxes clip their rows, so anything drawn outside a control is cut
    -- off at its corners. The strokes go on the inside of the control where
    -- the engine supports it; otherwise everything is inset by its width.
    local inside = pcall(function()
        haloStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
        ring.BorderStrokePosition = Enum.BorderStrokePosition.Inner
    end)
    local glowWidth = inside and 6 or 3
    if not inside then
        halo.Position = UDim2.fromOffset(glowWidth + 1, glowWidth + 1)
        halo.Size = UDim2.new(1, -(glowWidth + 1) * 2, 1, -(glowWidth + 1) * 2)
        wash.Position = UDim2.fromOffset(2, 2)
        wash.Size = UDim2.new(1, -4, 1, -4)
    end

    -- A small pop, unless something else is scaling the control already. It
    -- never grows past full size, which would be clipped as well.
    local pop
    if not frame:FindFirstChildOfClass("UIScale") then
        pop = create("UIScale", { Scale = 0.975, Parent = frame })
        tween(pop, { Scale = 1 }, 0.4, Enum.EasingStyle.Quint)
    end

    tween(wash, { BackgroundTransparency = 0.8 }, 0.2, Enum.EasingStyle.Quad)
    tween(ring, { Transparency = 0 }, 0.2, Enum.EasingStyle.Quad)
    tween(haloStroke, { Thickness = glowWidth, Transparency = 0.72 }, 0.35, Enum.EasingStyle.Quint)
    tween(sheen, { Offset = Vector2.new(1, 0) }, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    tween(runner, { Rotation = 540 }, 2.2, Enum.EasingStyle.Quad)
    task.spawn(function()
        task.wait(0.75)
        -- One softer breath, then fade out.
        tween(wash, { BackgroundTransparency = 0.9 }, 0.35, Enum.EasingStyle.Sine)
        tween(haloStroke, { Thickness = glowWidth / 2, Transparency = 0.85 }, 0.35, Enum.EasingStyle.Sine)
        task.wait(0.35)
        tween(wash, { BackgroundTransparency = 0.84 }, 0.3, Enum.EasingStyle.Sine)
        tween(haloStroke, { Thickness = glowWidth * 0.85, Transparency = 0.76 }, 0.3, Enum.EasingStyle.Sine)
        task.wait(0.4)
        tween(wash, { BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quad)
        tween(ring, { Transparency = 1 }, 0.65, Enum.EasingStyle.Quad)
        tween(haloStroke, { Thickness = glowWidth, Transparency = 1 }, 0.65, Enum.EasingStyle.Quad)
        task.wait(0.7)
        wash:Destroy()
        halo:Destroy()
        if pop then
            pop:Destroy()
        end
    end)
end

function Window:_revealResult(result)
    local tab, sub, target, group = result.Tab, result.Sub, result.Target, result.Group
    if self.CurrentTab ~= tab then
        self:SelectTab(tab)
    end
    if sub then
        tab:SelectSubTab(sub)
    end
    if not target then
        local button = sub and sub._button or tab._button
        task.delay(0.1, function()
            if button.Parent then
                self:_flash(button, sub and 8 or 10)
            end
        end)
        return
    end
    local expanding = group ~= nil and group:IsCollapsed()
    if expanding then
        group:Expand()
    end
    local list = (sub or tab).List
    task.spawn(function()
        -- Let the freshly shown page lay out before measuring it.
        task.wait()
        task.wait()
        if expanding then
            task.wait(0.3)
        end
        local frame = target._frame
        if self._destroyed or target._destroyed or not frame or not frame.Parent or not list then
            return
        end
        local scale = self.Scale.Scale
        local top = (frame.AbsolutePosition.Y - list.AbsolutePosition.Y) / scale + list.CanvasPosition.Y
        local height = frame.AbsoluteSize.Y / scale
        local view = list.AbsoluteWindowSize.Y / scale
        local limit = math.max(list.AbsoluteCanvasSize.Y / scale - view, 0)
        local y = math.clamp(top + height / 2 - view / 2, 0, limit)
        if math.abs(y - list.CanvasPosition.Y) > 2 then
            tween(list, { CanvasPosition = Vector2.new(0, y) }, 0.45, Enum.EasingStyle.Quint)
            task.wait(0.25)
        end
        if frame.Parent then
            self:_flash(frame, target._groupbox and 10 or 8)
        end
    end)
end

function Window:_resetSearch()
    if self.SearchBox and self.SearchBox.Text ~= "" then
        self.SearchBox.Text = ""
    end
end

-- Page titles stop short of the search box and close button.
function Window:_fitTitle(tab)
    local controls = self._headerRight or 56
    local right = self.SearchBox and (self._searchWidth or SEARCH_WIDTH) + controls + 16 or controls
    local reserve = tab._titleX + right
    tab._title.Size = UDim2.new(1, -reserve, 0, 24)
    if tab._desc then
        tab._desc.Size = UDim2.new(1, -reserve, 0, 16)
    end
end

function Window:_buildSearch(content)
    -- A recessed field: darker than the header, hairline stroke, icon
    -- inset left and a clear button that only shows while there is text.
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -(self._headerRight or 56), 0, 14),
        Size = UDim2.fromOffset(SEARCH_WIDTH, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = content,
    })
    holder:SetAttribute("NoDrag", true)
    local field = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = holder,
    })
    corner(field, UDim.new(0, 6))
    local fieldStroke = stroke(field, Theme.Stroke, 0, 1)
    local _, icon = glowIcon(field, "search", Theme.Muted, UDim2.new(0, 9, 0.5, 0))
    icon.Parent.AnchorPoint = Vector2.new(0, 0.5)
    icon.Parent.Size = UDim2.fromOffset(13, 13)
    local clear = create("ImageButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        Visible = false,
        Parent = field,
    })
    applyIcon(clear, "x")
    local box = create("TextBox", {
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.new(1, -52, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = field,
    })
    clear.MouseEnter:Connect(function()
        tween(clear, { ImageColor3 = Theme.Text }, 0.1)
    end)
    clear.MouseLeave:Connect(function()
        tween(clear, { ImageColor3 = Theme.Muted }, 0.15)
    end)
    clear.MouseButton1Click:Connect(function()
        box.Text = ""
        box:CaptureFocus()
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        clear.Visible = box.Text ~= ""
    end)
    holder.MouseEnter:Connect(function()
        if not box:IsFocused() then
            tween(fieldStroke, { Color = Theme.StrokeHover }, 0.15)
        end
    end)
    holder.MouseLeave:Connect(function()
        if not box:IsFocused() then
            tween(fieldStroke, { Color = Theme.Stroke }, 0.25)
        end
    end)
    self.SearchBox = box

    -- Results float over the window under the box, like a dropdown popup.
    local rowHeight = TOUCH and 40 or 34
    local maxRows = 8
    local popup = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(300, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 45,
        Parent = self.Body,
    })
    popup:SetAttribute("NoDrag", true)
    local popupShadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-18, -12),
        Size = UDim2.new(1, 36, 1, 36),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Parent = popup,
    })
    local panel = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = popup,
    })
    corner(panel, UDim.new(0, 10))
    local panelStroke = stroke(panel, Theme.Stroke, 1)
    edgeHighlight(panel)
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = TOUCH and 4 or 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(),
        Parent = panel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = list,
    })
    local noResults = label({
        Size = UDim2.new(1, 0, 0, rowHeight),
        Text = "No results",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 0,
        Visible = false,
        Parent = list,
    })

    local rows = {}
    local results = {}
    local selected = 1
    local open = false
    local generation = 0
    local shownSize = Vector2.new(300, 0)
    local stopFollowing = nil
    local closeResults

    local function place()
        local scale = self.Scale.Scale
        local bodyPosition = self.Body.AbsolutePosition
        local bodyWidth = self.Body.AbsoluteSize.X / scale
        local right = (holder.AbsolutePosition.X + holder.AbsoluteSize.X - bodyPosition.X) / scale
        local top = (holder.AbsolutePosition.Y + holder.AbsoluteSize.Y - bodyPosition.Y) / scale + 6
        right = math.clamp(right, shownSize.X + 8, math.max(bodyWidth - 8, shownSize.X + 8))
        popup.Position = UDim2.fromOffset(right, top)
    end

    local function measure()
        local scale = self.Scale.Scale
        local bodySize = self.Body.AbsoluteSize / scale
        local below = (holder.AbsolutePosition.Y + holder.AbsoluteSize.Y - self.Body.AbsolutePosition.Y) / scale + 6
        local count = math.max(#rows, 1)
        local height = math.min(count, maxRows) * (rowHeight + 2) - 2 + 12
        height = math.max(math.min(height, bodySize.Y - below - 12), rowHeight + 12)
        local width = math.min(math.max(holder.AbsoluteSize.X / scale, 300), math.max(bodySize.X - 16, 160))
        shownSize = Vector2.new(width, height)
    end

    local function paintSelection()
        for index, row in ipairs(rows) do
            local on = index == selected
            tween(row.Button, { BackgroundTransparency = on and 0.35 or 1 }, 0.12)
            tintIcon(row.Icon, on and Theme.Accent or Theme.Muted, on, 0.12)
        end
    end

    local function keepSelectionInView()
        local rowTop = (selected - 1) * (rowHeight + 2)
        local view = list.AbsoluteWindowSize.Y / self.Scale.Scale
        local y = list.CanvasPosition.Y
        if rowTop < y then
            y = rowTop
        elseif rowTop + rowHeight > y + view then
            y = rowTop + rowHeight - view
        else
            return
        end
        list.CanvasPosition = Vector2.new(0, math.max(y, 0))
    end

    local function setOpen(value)
        if value == open then
            return
        end
        open = value
        generation += 1
        local current = generation
        if value then
            if self._closePopup and self._closePopup ~= closeResults then
                self._closePopup()
            end
            self._closePopup = closeResults
            place()
            popup.Size = UDim2.fromOffset(shownSize.X, 0)
            popup.Visible = true
            tween(popup, { Size = UDim2.fromOffset(shownSize.X, shownSize.Y) }, 0.26, Enum.EasingStyle.Quint)
            tween(panelStroke, { Transparency = 0 }, 0.12)
            tween(popupShadow, { ImageTransparency = 0.55 }, 0.26)
            if not stopFollowing then
                stopFollowing = self:_listen("Render", place)
            end
        else
            if self._closePopup == closeResults then
                self._closePopup = nil
            end
            tween(popup, { Size = UDim2.fromOffset(shownSize.X, 0) }, 0.18, Enum.EasingStyle.Quint)
            tween(popupShadow, { ImageTransparency = 1 }, 0.14)
            task.delay(0.19, function()
                if generation == current and not open then
                    popup.Visible = false
                    panelStroke.Transparency = 1
                    if stopFollowing then
                        stopFollowing()
                        stopFollowing = nil
                    end
                end
            end)
        end
    end
    closeResults = function()
        setOpen(false)
    end

    local function choose(result)
        if not result then
            return
        end
        setOpen(false)
        box.Text = ""
        if box:IsFocused() then
            box:ReleaseFocus()
        end
        self:_revealResult(result)
    end

    local function escape(text)
        return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
    end

    local function render(query)
        for _, row in ipairs(rows) do
            row.Button:Destroy()
        end
        table.clear(rows)
        results = self:_searchResults(query)
        selected = 1
        local accent = colorToHex(Theme.Accent)
        for index, result in ipairs(results) do
            if index > 50 then
                break
            end
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, rowHeight),
                BackgroundColor3 = Theme.Surface3,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                Parent = list,
            })
            corner(button, UDim.new(0, 7))
            -- One line of breadcrumbs: tab, sub tab and groupbox in muted
            -- text, each split by a chevron, ending on the match in accent.
            local crumbs = create("Frame", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -20, 1, 0),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Parent = button,
            })
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 5),
                Parent = crumbs,
            })
            local part = 0
            local firstIcon = nil
            local function crumbIcon(icon)
                if not icon then
                    return
                end
                part += 1
                local image = create("ImageLabel", {
                    Size = UDim2.fromOffset(14, 14),
                    BackgroundTransparency = 1,
                    ImageColor3 = Theme.Muted,
                    ScaleType = Enum.ScaleType.Fit,
                    LayoutOrder = part,
                    Parent = crumbs,
                })
                applyIcon(image, icon)
                firstIcon = firstIcon or image
            end
            local function crumbText(text, color, rich)
                part += 1
                return label({
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Text = text,
                    RichText = rich == true,
                    TextSize = 13,
                    FontFace = color and Fonts.Medium or Fonts.Regular,
                    TextColor3 = color or Theme.Muted,
                    TextTruncate = Enum.TextTruncate.None,
                    LayoutOrder = part,
                    Parent = crumbs,
                })
            end
            local function chevron()
                crumbText(">")
            end
            local tab, sub, group = result.Tab, result.Sub, result.Group
            local onTab = result.Kind == "Tab"
            local onSub = result.Kind == "Page"
            local onGroup = result.Kind == "Groupbox"
            crumbIcon(tab._iconName or "layout-grid")
            if not onTab then
                crumbText(tab.Name)
                if sub then
                    chevron()
                    crumbIcon(sub._iconName or "layers")
                    if not onSub then
                        crumbText(sub.Name)
                    end
                end
                if group and not onGroup then
                    chevron()
                    crumbText(group.Name)
                end
                if not onSub then
                    chevron()
                end
            end
            -- The match itself: accent, with the typed part in bold.
            local name = result.Name
            local stop = result.At + #query
            local marked = escape(string.sub(name, 1, result.At - 1))
                .. "<b>" .. escape(string.sub(name, result.At, stop - 1)) .. "</b>"
                .. escape(string.sub(name, stop))
            crumbText(marked, Theme.Accent, true)
            local image = firstIcon
            local isTap = tapGuard(button, function()
                return list
            end)
            button.MouseEnter:Connect(function()
                if not usingTouch() then
                    selected = index
                    paintSelection()
                end
            end)
            button.MouseButton1Click:Connect(function()
                if isTap() then
                    choose(result)
                end
            end)
            table.insert(rows, { Button = button, Icon = image })
        end
        noResults.Visible = #rows == 0
        list.CanvasSize = UDim2.fromOffset(0, math.max(#rows, 1) * (rowHeight + 2) - 2)
        list.CanvasPosition = Vector2.zero
        paintSelection()
        measure()
        if open then
            place()
            tween(popup, { Size = UDim2.fromOffset(shownSize.X, shownSize.Y) }, 0.2, Enum.EasingStyle.Quint)
        end
    end

    local function update()
        local query = string.match(string.lower(box.Text), "^%s*(.-)%s*$")
        if query == "" then
            setOpen(false)
            return
        end
        render(query)
        setOpen(true)
    end

    box.Focused:Connect(function()
        tween(fieldStroke, { Color = Theme.Accent }, 0.15)
        tween(field, { BackgroundTransparency = 0 }, 0.15)
        tween(icon, { ImageColor3 = Theme.Text }, 0.15)
        if box.Text ~= "" then
            update()
        end
    end)
    -- Results rebuild a few dozen rows, so fast typing waits for a short pause;
    -- clearing the box still closes the list right away.
    local typedGeneration, updatePending = 0, false
    box.FocusLost:Connect(function(enterPressed)
        tween(fieldStroke, { Color = Theme.Stroke }, 0.2)
        tween(field, { BackgroundTransparency = 0.2 }, 0.2)
        tween(icon, { ImageColor3 = Theme.Muted }, 0.2)
        -- Enter right after typing: catch the results up first, so it opens
        -- the match for what was typed rather than the previous one.
        if enterPressed and updatePending then
            typedGeneration += 1
            updatePending = false
            update()
        end
        if enterPressed and open then
            choose(results[selected])
        end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        typedGeneration += 1
        local generation = typedGeneration
        if string.match(box.Text, "^%s*$") then
            updatePending = false
            update()
            return
        end
        updatePending = true
        task.delay(0.08, function()
            if generation == typedGeneration and not self._destroyed then
                updatePending = false
                update()
            end
        end)
    end)
    self:_listen("Began", function(input)
        if not open then
            return
        end
        if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down then
            if #rows > 0 then
                local step = input.KeyCode == Enum.KeyCode.Up and -1 or 1
                selected = math.clamp(selected + step, 1, #rows)
                paintSelection()
                keepSelectionInView()
            end
        elseif input.KeyCode == Enum.KeyCode.Escape then
            setOpen(false)
        elseif isPress(input) then
            local point = pointerPosition()
            if not pointInside(point, popup) and not pointInside(point, holder) then
                setOpen(false)
            end
        end
    end)

    local function fit()
        local width = content.AbsoluteSize.X / self.Scale.Scale
        local searchWidth = math.clamp(math.floor(width * 0.32), 110, SEARCH_WIDTH)
        holder.Size = UDim2.fromOffset(searchWidth, 34)
        if searchWidth ~= self._searchWidth then
            self._searchWidth = searchWidth
            for _, tab in ipairs(self.Tabs) do
                self:_fitTitle(tab)
            end
        end
    end
    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    task.defer(fit)
end

-- Identity: the player's name and headshot shown in the sidebar and on the
-- home tab. The privacy switches hide them everywhere at once.


-- Both run late (task.delay); once the tab or window is destroyed its frames
-- are locked, so there is nothing to put back.
local function settleSubOut(ui)
    if not ui.Area.Parent then
        ui.OutFrame = nil
        return
    end
    if ui.OutFrame then
        ui.OutFrame.Parent = ui.Area
        ui.OutFrame.Visible = false
        ui.OutFrame = nil
    end
    ui.Out.Visible = false
end

local function settleSubIn(ui)
    if not ui.Area.Parent then
        ui.InFrame = nil
        return
    end
    if ui.InFrame then
        ui.InFrame.Parent = ui.Area
        ui.InFrame.Position = UDim2.fromOffset(0, 0)
        ui.InFrame = nil
    end
    ui.In.Visible = false
end

function Tab:_setupSubTabs()
    if #(self._items or {}) > 0 or #(self._groupboxes or {}) > 0 then
        Library._warn(('Tab "%s" already has elements, and adding a sub tab hides them. Put everything in sub tabs, or create the sub tabs first.'):format(tostring(self.Name)))
    end
    local top = self._headerBottom
    local page = self._page
    local strip = create("ScrollingFrame", {
        Name = "SubTabs",
        Position = UDim2.fromOffset(24, top - 4),
        Size = UDim2.new(1, -48, 0, 32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        Parent = page,
    })
    strip:SetAttribute("NoDrag", true)
    local highlight = create("Frame", {
        Size = UDim2.fromOffset(0, 32),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
        Parent = strip,
    })
    corner(highlight, UDim.new(0, 8))
    stroke(highlight, Theme.Stroke)
    local row = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = strip,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = row,
    })
    self.Window:_overflowHint(page, strip, row, false, Theme.Background)
    local areaTop = top + 36
    local area = create("Frame", {
        Name = "SubPages",
        Position = UDim2.fromOffset(0, areaTop),
        Size = UDim2.new(1, 0, 1, -areaTop),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = page,
    })
    local ui = {
        Strip = strip,
        Row = row,
        Highlight = highlight,
        Area = area,
        Out = create("CanvasGroup", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 2,
            Parent = area,
        }),
        In = create("CanvasGroup", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 3,
            Parent = area,
        }),
        Generation = 0,
    }
    self._sub = ui
    self._subTabs = {}
    self.List.Visible = false
    self:_refreshEmpty()
    -- Keep the pill under the selected tab when widths change after layout.
    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if self.CurrentSubTab and not ui.Moving then
            self:_placeSubHighlight(self.CurrentSubTab, true)
        end
    end)
end

function Tab:_placeSubHighlight(sub, instant)
    local ui = self._sub
    local scale = self.Window.Scale.Scale
    local button = sub._button
    local width = button.AbsoluteSize.X / scale
    if width <= 0 then
        return
    end
    local x = (button.AbsolutePosition.X - ui.Row.AbsolutePosition.X) / scale
    local props = { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(width, 32) }
    if instant or not ui.Highlight.Visible then
        ui.Highlight.Visible = true
        ui.Highlight.Position = props.Position
        ui.Highlight.Size = props.Size
    else
        ui.Moving = true
        tween(ui.Highlight, props, 0.35, Enum.EasingStyle.Quint)
        task.delay(0.36, function()
            ui.Moving = false
        end)
    end
    local view = ui.Strip.AbsoluteSize.X / scale
    local canvasX = ui.Strip.CanvasPosition.X
    if x < canvasX then
        tween(ui.Strip, { CanvasPosition = Vector2.new(math.max(x - 8, 0), 0) }, 0.3, Enum.EasingStyle.Quint)
    elseif x + width > canvasX + view then
        tween(ui.Strip, { CanvasPosition = Vector2.new(x + width - view + 8, 0) }, 0.3, Enum.EasingStyle.Quint)
    end
end

function Tab:SubTab(opts, icon)
    if self._groupbox or self._isSubTab then
        return self.Parent:SubTab(opts, icon)
    end
    opts = normalize(opts, { Title = "Name", Description = "Desc" })
    if icon ~= nil and opts.Icon == nil then
        opts.Icon = icon
    end
    if not self._subTabs then
        self:_setupSubTabs()
    end
    local ui = self._sub
    local index = #self._subTabs + 1
    local sub = setmetatable({
        Name = opts.Name or ("Page " .. index),
        Window = self.Window,
        Parent = self,
        _order = 0,
        _isSubTab = true,
        _index = index,
        _iconName = opts.Icon,
    }, Tab)
    local frame = create("Frame", {
        Name = sub.Name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = ui.Area,
    })
    sub._frame = frame
    buildContainer(sub, frame, 0, opts.Icon or self._iconName or "layout-grid", opts.EmptyText or "Nothing here yet")

    local button = create("TextButton", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = index,
        Parent = ui.Row,
    })
    padding(button, 14, 14)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = button,
    })
    if opts.Icon then
        local image = create("ImageLabel", {
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Muted,
            ScaleType = Enum.ScaleType.Fit,
            LayoutOrder = 1,
            Parent = button,
        })
        applyIcon(image, opts.Icon)
        if image:GetAttribute("CustomIcon") then
            image.ImageTransparency = 0.4
        end
        sub._iconImage = image
    end
    sub._label = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = sub.Name,
        TextSize = 13,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = button,
    })
    sub._button = button
    button.MouseEnter:Connect(function()
        if self.CurrentSubTab ~= sub then
            tween(sub._label, { TextColor3 = Theme.Text }, 0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        if self.CurrentSubTab ~= sub then
            tween(sub._label, { TextColor3 = Theme.Muted }, 0.2)
        end
    end)
    -- A swipe that scrolls the strip on touch is not a pick (as on the main tabs).
    local isTap = tapGuard(button, function()
        return self._sub and self._sub.Strip
    end)
    button.MouseButton1Click:Connect(function()
        if isTap() then
            self:SelectSubTab(sub)
        end
    end)

    table.insert(self._subTabs, sub)
    if index == 1 then
        self:SelectSubTab(sub, true)
    end
    return sub
end

Tab.CreateSubTab = Tab.SubTab
Tab.AddSubTab = Tab.SubTab

function Tab:SelectSubTab(sub, instant)
    if type(sub) ~= "table" then
        for index, entry in ipairs(self._subTabs or {}) do
            if entry.Name == sub or index == sub then
                sub = entry
                break
            end
        end
    end
    if type(sub) ~= "table" or not self._sub then
        return
    end
    local previous = self.CurrentSubTab
    if previous == sub then
        return
    end
    self.Window:_resetSearch()
    self.Window:_closePopups()
    self.CurrentSubTab = sub
    local ui = self._sub
    settleSubOut(ui)
    settleSubIn(ui)
    ui.Generation += 1
    local generation = ui.Generation

    local fade = instant and 0 or 0.2
    if previous then
        tween(previous._label, { TextColor3 = Theme.Muted }, fade)
        if previous._iconImage then
            tintIcon(previous._iconImage, Theme.Muted, false, fade)
        end
    end
    tween(sub._label, { TextColor3 = Theme.Text }, fade)
    if sub._iconImage then
        tintIcon(sub._iconImage, Theme.Accent, true, fade)
    end
    self:_placeSubHighlight(sub, instant)

    -- Performance Mode swaps in place too, without the CanvasGroup slide.
    if instant or not previous or Library.PerformanceMode then
        if previous then
            previous._frame.Visible = false
        end
        sub._frame.Visible = true
        return
    end

    local direction = sub._index > previous._index and 1 or -1
    ui.OutFrame = previous._frame
    previous._frame.Parent = ui.Out
    ui.Out.GroupTransparency = 0
    ui.Out.Position = UDim2.fromOffset(0, 0)
    ui.Out.Visible = true
    tween(ui.Out, { GroupTransparency = 1, Position = UDim2.fromOffset(-direction * 28, 0) }, 0.2)

    ui.InFrame = sub._frame
    sub._frame.Visible = true
    sub._frame.Parent = ui.In
    ui.In.GroupTransparency = 1
    ui.In.Position = UDim2.fromOffset(direction * 28, 0)
    ui.In.Visible = true
    tween(ui.In, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.34, Enum.EasingStyle.Quint)

    task.delay(0.2, function()
        if ui.Generation == generation then
            settleSubOut(ui)
        end
    end)
    task.delay(0.34, function()
        if ui.Generation == generation then
            settleSubIn(ui)
        end
    end)
end

-- Search: one box over the whole window. Typing lists matching tabs, pages,
-- groupboxes and controls from every tab; picking one opens its tab and page,
-- scrolls it into view and flashes it.

Window._searchIcons = {
    Tab = "app-window",
    Page = "panels-top-left",
    Groupbox = "layout-grid",
    Button = "mouse-pointer-click",
    ButtonRow = "mouse-pointer-click",
    Toggle = "toggle-right",
    Slider = "sliders-horizontal",
    Dropdown = "list",
    Input = "text-cursor-input",
    Keybind = "keyboard",
    ColorPicker = "palette",
    Stepper = "chevrons-up-down",
    Progress = "activity",
    Status = "activity",
    StatusList = "activity",
    Label = "type",
    Paragraph = "type",
    OrderList = "list-ordered",
    Segmented = "rows-3",
    Textarea = "text",
    Graph = "chart-line",
}


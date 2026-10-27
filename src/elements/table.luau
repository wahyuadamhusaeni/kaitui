function Tab:Table(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", Data = "Rows", OnRowClick = "Callback" })
    local window = self.Window
    local metrics = metricsOf(self)
    local compact = metrics.Compact
    local rowHeight = tonumber(opts.RowHeight) or (TOUCH and 32 or 26)
    local maxRows = math.max(math.floor(tonumber(opts.MaxRows) or 8), 1)
    local headerHeight = TOUCH and 28 or 24
    local textSize = compact and 12 or 13
    local inset = compact and 14 or 8
    local hasHead = type(opts.Name) == "string" and opts.Name ~= ""
    local titleTop = compact and 4 or 10
    local searchable = opts.Search ~= false
    local searchHeight = TOUCH and 30 or 26
    local searchTop = hasHead and (titleTop + (opts.Desc and 38 or 22)) or (compact and 4 or inset)
    local gridTop = searchTop + (searchable and searchHeight + 6 or 0)
    local bottom = compact and 6 or inset
    -- Editable: typed columns get editors in their cells, an Add row button
    -- sits under the grid and a remove column ends each row.
    local editable = opts.Editable == true
    if not editable and type(opts.Columns) == "table" then
        for _, column in ipairs(opts.Columns) do
            if type(column) == "table" and column.Type ~= nil then
                editable = true
                break
            end
        end
    end
    local canAdd = editable and opts.AllowAdd ~= false
    local canRemove = editable and opts.AllowRemove ~= false
    local addHeight = canAdd and (TOUCH and 30 or 26) + 6 or 0

    local frame, frameStroke = card(self, "Frame", gridTop + headerHeight + rowHeight + addHeight + bottom, opts)
    hoverStroke(frame, frameStroke)
    local title
    if hasHead then
        title = label({
            Position = UDim2.fromOffset(14, titleTop),
            Size = UDim2.new(1, -28, 0, metrics.TitleHeight),
            Text = opts.Name,
            TextSize = metrics.TextSize,
            Parent = frame,
        })
        if opts.Desc then
            label({
                Position = UDim2.fromOffset(14, titleTop + metrics.TitleHeight + 1),
                Size = UDim2.new(1, -28, 0, metrics.DescLine),
                Text = opts.Desc,
                TextSize = metrics.DescSize,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                Parent = frame,
            })
        end
    end
    -- Search: filters rows by any cell's text as you type. A count of what
    -- matches shows on the right while it filters.
    local query = ""
    local searchBox, searchCount
    if searchable then
        local holder = create("Frame", {
            Position = UDim2.fromOffset(inset, searchTop),
            Size = UDim2.new(1, -inset * 2, 0, searchHeight),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Parent = frame,
        })
        holder:SetAttribute("NoDrag", true)
        corner(holder, UDim.new(0, 6))
        local searchStroke = stroke(holder)
        local iconHolder, searchIcon = glowIcon(holder, "search", Theme.Muted, UDim2.new(0, 9, 0.5, 0))
        iconHolder.Size = UDim2.fromOffset(13, 13)
        searchCount = label({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -9, 0, 0),
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "",
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            Visible = false,
            Parent = holder,
        })
        searchBox = create("TextBox", {
            Position = UDim2.fromOffset(29, 0),
            Size = UDim2.new(1, -90, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = opts.SearchPlaceholder or "Search",
            PlaceholderColor3 = Theme.Muted,
            TextColor3 = Theme.Text,
            TextSize = 12,
            FontFace = Fonts.Regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ClearTextOnFocus = false,
            Parent = holder,
        })
        searchBox.Focused:Connect(function()
            tween(searchStroke, { Color = Theme.StrokeHover }, 0.15)
            tween(searchIcon, { ImageColor3 = Theme.Accent }, 0.15)
        end)
        searchBox.FocusLost:Connect(function()
            tween(searchStroke, { Color = Theme.Stroke }, 0.2)
            tween(searchIcon, { ImageColor3 = Theme.Muted }, 0.2)
        end)
    end

    local grid = create("Frame", {
        Position = UDim2.fromOffset(inset, gridTop),
        Size = UDim2.new(1, -inset * 2, 0, headerHeight + rowHeight),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(grid, UDim.new(0, 6))
    stroke(grid, Theme.Stroke)
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, headerHeight),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = grid,
    })
    create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = header,
    })
    local body = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, headerHeight),
        Size = UDim2.new(1, 0, 1, -headerHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = grid,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = body,
    })
    local empty = label({
        Position = UDim2.fromOffset(0, headerHeight),
        Size = UDim2.new(1, 0, 0, rowHeight),
        Text = opts.EmptyText or "Nothing here yet",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = grid,
    })
    local addButton
    if canAdd then
        addButton = create("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, inset, 1, -bottom),
            Size = UDim2.new(1, -inset * 2, 0, addHeight - 6),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = frame,
        })
        addButton:SetAttribute("NoDrag", true)
        corner(addButton, UDim.new(0, 6))
        local addStroke = stroke(addButton)
        local addLabel = label({
            Size = UDim2.fromScale(1, 1),
            Text = "+  " .. tostring(opts.AddText or "Add row"),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = addButton,
        })
        addButton.MouseEnter:Connect(function()
            tween(addLabel, { TextColor3 = Theme.Text }, 0.12)
            tween(addStroke, { Color = Theme.StrokeHover }, 0.12)
        end)
        addButton.MouseLeave:Connect(function()
            tween(addLabel, { TextColor3 = Theme.Muted }, 0.2)
            tween(addStroke, { Color = Theme.Stroke }, 0.2)
        end)
    end

    local handle = { Rows = {} }
    local shownCount = nil
    local columns, headerCells = {}, {}
    local pool = {}
    local sortKey, sortDescending = nil, false
    local shownHeight = nil
    local MEDALS = {
        Color3.fromRGB(245, 200, 90),
        Color3.fromRGB(200, 206, 218),
        Color3.fromRGB(214, 146, 96),
    }

    local function alignment(column)
        local align = type(column.Align) == "string" and column.Align:lower() or nil
        if align == "right" then
            return Enum.TextXAlignment.Right
        elseif align == "center" or align == "centre" then
            return Enum.TextXAlignment.Center
        end
        return Enum.TextXAlignment.Left
    end

    -- Widths: a number above 1 is pixels, up to 1 is a share of what the pixel
    -- columns leave, and the rest split whatever share is left.
    local function layoutColumns()
        local pixels, shares, autos = 0, 0, 0
        for _, column in ipairs(columns) do
            local width = tonumber(column.Width)
            if width and width > 1 then
                pixels += width
            elseif width and width > 0 then
                shares += width
            else
                autos += 1
            end
        end
        local left = math.max(1 - shares, 0)
        for _, column in ipairs(columns) do
            local width = tonumber(column.Width)
            local share
            if width and width > 1 then
                column.UDim = UDim.new(0, width)
            else
                share = (width and width > 0) and width or (autos > 0 and left / autos or 0)
                column.UDim = UDim.new(share, -pixels * share)
            end
        end
    end

    local function columnValue(row, column)
        if column.Rank or column.Remove then
            return nil
        end
        if row[1] ~= nil or column.Key == nil then
            return row[column.Index]
        end
        return row[column.Key]
    end

    local function display(value, column, row)
        if type(column.Format) == "function" then
            local ok, text = pcall(column.Format, value, row)
            if ok and text ~= nil then
                return tostring(text)
            end
        end
        if type(value) == "number" then
            local whole = value == math.floor(value)
            local text = whole and string.format("%d", value) or string.format("%.2f", value)
            -- Thousands separators on the whole part.
            local sign, int, rest = text:match("^(%-?)(%d+)(.*)$")
            if int then
                int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                return sign .. int .. rest
            end
            return text
        end
        if value == nil then
            return ""
        end
        return tostring(value)
    end

    local function paintHeader()
        for _, cell in ipairs(headerCells) do
            local column = cell.Column
            local active = sortKey ~= nil and sortKey == column
            tween(cell.Label, { TextColor3 = active and Theme.Text or Theme.Muted }, 0.15)
            cell.Arrow.Visible = active
            if active then
                tween(cell.Arrow, { Rotation = sortDescending and 0 or 180 }, 0.2, Enum.EasingStyle.Quint)
            end
        end
    end

    local function sortedRows()
        local list = {}
        for index, row in ipairs(handle.Rows) do
            list[index] = { Row = row, Index = index }
        end
        if sortKey then
            local column = sortKey
            -- Keys are worked out once per row. Numbers (including "1.5k" shorthand) sort
            -- before text, so a column mixing both still has one consistent order.
            local values, numbers = {}, {}
            for _, item in ipairs(list) do
                local value = columnValue(item.Row, column)
                values[item] = value
                numbers[item] = value ~= nil and (tonumber(value) or (type(value) == "string" and Library._parseAmount(value))) or nil
            end
            table.sort(list, function(a, b)
                local x, y = values[a], values[b]
                local nx, ny = numbers[a], numbers[b]
                if nx and ny then
                    if nx ~= ny then
                        if sortDescending then
                            return nx > ny
                        end
                        return nx < ny
                    end
                elseif (nx ~= nil) ~= (ny ~= nil) and x ~= nil and y ~= nil then
                    return nx ~= nil
                elseif x ~= nil and y ~= nil then
                    local sx, sy = string.lower(tostring(x)), string.lower(tostring(y))
                    if sx ~= sy then
                        if sortDescending then
                            return sx > sy
                        end
                        return sx < sy
                    end
                elseif x ~= y then
                    -- Empty cells sink to the bottom either way.
                    return x ~= nil
                end
                return a.Index < b.Index
            end)
        end
        -- Ranks come from the full order, so filtering never renumbers them.
        for position, item in ipairs(list) do
            item.Rank = position
        end
        if query == "" then
            return list
        end
        local shown = {}
        for _, item in ipairs(list) do
            for _, column in ipairs(columns) do
                if not column.Rank and not column.Remove then
                    local text = display(columnValue(item.Row, column), column, item.Row)
                    text = string.lower((string.gsub(text, "<[^>]->", "")))
                    if string.find(text, query, 1, true) then
                        table.insert(shown, item)
                        break
                    end
                end
            end
        end
        return shown
    end

    local function setCell(row, column, value)
        if row[1] ~= nil or column.Key == nil then
            row[column.Index] = value
        else
            row[column.Key] = value
        end
    end

    local function columnKind(column)
        local kind = string.lower(tostring(column.Type or ""))
        if kind == "boolean" or kind == "bool" or kind == "switch" then
            return "toggle"
        elseif kind == "select" or kind == "option" then
            return "dropdown"
        end
        return kind
    end

    -- One option list per table, opened under a dropdown cell.
    local picker, pickerList, pickerAnchor, pickerSearch, pickerSearchHolder, pickerEmpty
    -- The option list is virtual like the dropdown's: a small pool of
    -- buttons is rebound to whichever options are in view.
    local pickerPool, pickerShown, pickerFit, pickerPick, pickerRender = {}, {}, nil, nil, nil
    local function closePicker()
        if picker then
            picker.Visible = false
            if pickerSearch:IsFocused() then
                pickerSearch:ReleaseFocus()
            end
        end
        pickerAnchor = nil
        if window._closePopup == closePicker then
            window._closePopup = nil
        end
    end
    local function placePicker()
        if not picker or not picker.Visible or not pickerAnchor then
            return
        end
        if not pickerAnchor.Parent or not pickerAnchor:IsDescendantOf(frame) then
            closePicker()
            return
        end
        local host = picker.Parent
        local scale = math.max(window.Scale.Scale, 0.01)
        local position = (pickerAnchor.AbsolutePosition - host.AbsolutePosition) / scale
        local size = pickerAnchor.AbsoluteSize / scale
        local hostSize = host.AbsoluteSize / scale
        local width, height = picker.Size.X.Offset, picker.Size.Y.Offset
        local y = position.Y + size.Y + 4
        if y + height > hostSize.Y - 8 and position.Y - 4 - height >= 8 then
            y = position.Y - 4 - height
        end
        picker.Position = UDim2.fromOffset(math.clamp(position.X, 8, math.max(hostSize.X - width - 8, 8)), y)
    end
    local function openPicker(anchor, row, column)
        if window._closePopup and window._closePopup ~= closePicker then
            window._closePopup()
        end
        if not picker then
            picker = create("Frame", {
                BackgroundColor3 = Theme.Surface2,
                BorderSizePixel = 0,
                ZIndex = 45,
                Visible = false,
            })
            picker:SetAttribute("NoDrag", true)
            corner(picker, UDim.new(0, 6))
            stroke(picker, Theme.Stroke)
            -- Search row, shown for Searchable columns.
            pickerSearchHolder = create("Frame", {
                Position = UDim2.fromOffset(4, 4),
                Size = UDim2.new(1, -8, 0, TOUCH and 28 or 24),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel = 0,
                ZIndex = 46,
                Visible = false,
                Parent = picker,
            })
            corner(pickerSearchHolder, UDim.new(0, 4))
            local searchStroke = stroke(pickerSearchHolder)
            local searchIconHolder, searchIcon = glowIcon(pickerSearchHolder, "search", Theme.Muted, UDim2.new(0, 8, 0.5, 0))
            searchIconHolder.Size = UDim2.fromOffset(12, 12)
            searchIconHolder.ZIndex = 47
            pickerSearch = create("TextBox", {
                Position = UDim2.fromOffset(26, 0),
                Size = UDim2.new(1, -32, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                PlaceholderText = "Search",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                TextSize = 12,
                FontFace = Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ClearTextOnFocus = false,
                ZIndex = 47,
                Parent = pickerSearchHolder,
            })
            pickerSearch.Focused:Connect(function()
                tween(searchStroke, { Color = Theme.StrokeHover }, 0.15)
                tween(searchIcon, { ImageColor3 = Theme.Accent }, 0.15)
            end)
            pickerSearch.FocusLost:Connect(function(enterPressed)
                tween(searchStroke, { Color = Theme.Stroke }, 0.2)
                tween(searchIcon, { ImageColor3 = Theme.Muted }, 0.2)
                -- Enter picks the first match.
                if enterPressed and picker.Visible and pickerPick and pickerShown[1] ~= nil then
                    pickerPick(pickerShown[1])
                end
            end)
            pickerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                if pickerFit then
                    pickerFit()
                end
            end)
            pickerEmpty = label({
                Size = UDim2.new(1, 0, 0, TOUCH and 28 or 24),
                Text = "No matches",
                TextSize = 12,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 47,
                Visible = false,
                Parent = picker,
            })
            pickerList = create("ScrollingFrame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.Accent,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                CanvasSize = UDim2.new(),
                ZIndex = 45,
                Parent = picker,
            })
            padding(pickerList, 4, 4, 4, 4)
            pickerList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if pickerRender and picker.Visible then
                    pickerRender()
                end
            end)
            window:_listen("Began", function(input)
                if not picker.Visible then
                    return
                end
                if input.KeyCode == Enum.KeyCode.Escape then
                    closePicker()
                elseif isPress(input) and not pointInside(pointerPosition(), picker) then
                    closePicker()
                end
            end, handle)
            window:_listen("Render", placePicker, handle)
        end
        pickerPick = function(option)
            closePicker()
            if columnValue(row, column) ~= option then
                setCell(row, column, option)
                handle:_edited()
            end
        end
        local options = column.Options
        if type(options) == "function" then
            local ok, result = pcall(options, row)
            options = ok and result or nil
        end
        options = type(options) == "table" and options or {}
        local current = columnValue(row, column)
        local itemHeight = TOUCH and 28 or 24
        local step = itemHeight + 2
        local keys = {}
        -- Searchable = true always shows the search row; SearchAfter = n shows
        -- it once there are more than n options.
        local searchable = column.Searchable == true
            or (column.Searchable ~= false and tonumber(column.SearchAfter) ~= nil and #options > tonumber(column.SearchAfter))
        local searchHeight = searchable and (TOUCH and 28 or 24) + 4 or 0
        pickerSearchHolder.Visible = searchable
        pickerSearch.Text = ""
        pickerSearch.PlaceholderText = column.SearchPlaceholder or (#options > 6 and ("Search " .. #options .. " options") or "Search")
        local scale = math.max(window.Scale.Scale, 0.01)
        local width = math.max(anchor.AbsoluteSize.X / scale, searchable and 160 or 120)
        local maxShown = math.max(math.floor(tonumber(column.MaxRows) or 6), 1)

        local function poolEntry()
            local entry = {}
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, itemHeight),
                BackgroundColor3 = Theme.Surface3,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                ZIndex = 46,
                Visible = false,
                Parent = pickerList,
            })
            corner(button, UDim.new(0, 4))
            entry.Button = button
            entry.Label = label({
                Position = UDim2.fromOffset(8, 0),
                Size = UDim2.new(1, -16, 1, 0),
                TextSize = 12,
                FontFace = Fonts.Regular,
                ZIndex = 47,
                Parent = button,
            })
            button.MouseEnter:Connect(function()
                tween(button, { BackgroundTransparency = 0.25 }, 0.1)
            end)
            button.MouseLeave:Connect(function()
                tween(button, { BackgroundTransparency = entry.Selected and 0.4 or 1 }, 0.2)
            end)
            button.MouseButton1Click:Connect(function()
                if entry.Option ~= nil and pickerPick then
                    pickerPick(entry.Option)
                end
            end)
            return entry
        end

        pickerRender = function()
            -- CanvasPosition is in screen pixels; undo any UIScale first.
            local logical = pickerList.CanvasSize.Y.Offset
            local scale = logical > 0 and pickerList.AbsoluteCanvasSize.Y / logical or 1
            -- Indices keep a stable slot (index mod count) so scrolling only
            -- rebinds rows at the edges rather than every row each step.
            local first = math.max(math.floor(pickerList.CanvasPosition.Y / scale / step), 1)
            local count = maxShown + 3
            for slot = 1, math.max(count, #pickerPool) do
                local index = slot <= count and first + (slot - first) % count or 0
                local option = slot <= count and pickerShown[index] or nil
                local entry = pickerPool[slot]
                if option == nil then
                    if entry then
                        entry.Button.Visible = false
                        entry.Option = nil
                    end
                else
                    if not entry then
                        entry = poolEntry()
                        pickerPool[slot] = entry
                    end
                    entry.Button.Position = UDim2.fromOffset(0, (index - 1) * step)
                    if entry.Option ~= option then
                        local selected = option == current
                        entry.Option = option
                        entry.Selected = selected
                        entry.Label.Text = tostring(option)
                        entry.Label.TextColor3 = selected and Theme.Accent or Theme.Text
                        entry.Button.BackgroundTransparency = selected and 0.4 or 1
                    end
                    entry.Button.Visible = true
                end
            end
        end

        pickerFit = function()
            local query = string.lower(trim(pickerSearch.Text))
            if query == "" then
                pickerShown = options
            else
                pickerShown = {}
                for _, option in ipairs(options) do
                    local key = keys[option]
                    if key == nil then
                        key = string.lower(tostring(option))
                        keys[option] = key
                    end
                    if string.find(key, query, 1, true) then
                        table.insert(pickerShown, option)
                    end
                end
            end
            local count = #pickerShown
            pickerEmpty.Visible = count == 0
            pickerEmpty.Position = UDim2.fromOffset(0, searchHeight + 4)
            pickerList.Position = UDim2.fromOffset(0, searchHeight)
            pickerList.Size = UDim2.new(1, 0, 1, -searchHeight)
            pickerList.CanvasSize = UDim2.fromOffset(0, math.max(count * step - 2, 0) + 8)
            pickerList.CanvasPosition = Vector2.zero
            picker.Size = UDim2.fromOffset(width, searchHeight + math.clamp(count, 1, maxShown) * step + 6)
            for _, entry in ipairs(pickerPool) do
                entry.Option = nil
            end
            pickerRender()
        end
        pickerFit()
        picker.Parent = window:_popupHost(frame)
        pickerAnchor = anchor
        picker.Visible = true
        window._closePopup = closePicker
        placePicker()
        if searchable and not TOUCH then
            task.defer(function()
                if picker.Visible and pickerAnchor == anchor then
                    pickerSearch:CaptureFocus()
                end
            end)
        end
    end

    local function editorBox(cell)
        local box = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.new(1, -6, 1, -6),
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Parent = cell,
        })
        box:SetAttribute("NoDrag", true)
        corner(box, UDim.new(0, 4))
        return box, stroke(box)
    end

    local function makeEditor(entry, column, cell)
        local kind = columnKind(column)
        if kind == "toggle" then
            local align = alignment(column)
            local anchorX = align == Enum.TextXAlignment.Right and 1 or (align == Enum.TextXAlignment.Center and 0.5 or 0)
            local switch = create("TextButton", {
                AnchorPoint = Vector2.new(anchorX, 0.5),
                Position = UDim2.new(anchorX, anchorX == 1 and -6 or 0, 0.5, 0),
                Size = UDim2.fromOffset(28, 16),
                BackgroundColor3 = Theme.Surface3,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                Parent = cell,
            })
            switch:SetAttribute("NoDrag", true)
            corner(switch, UDim.new(1, 0))
            local knob = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.fromOffset(12, 12),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                Parent = switch,
            })
            corner(knob, UDim.new(1, 0))
            switch.MouseButton1Click:Connect(function()
                local row = entry.Data
                if row then
                    setCell(row, column, columnValue(row, column) ~= true)
                    handle:_edited()
                end
            end)
            return { Kind = "Toggle", Switch = switch, Knob = knob }
        elseif kind == "dropdown" then
            local box = editorBox(cell)
            local chip = create("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Parent = box,
            })
            local valueLabel = label({
                Position = UDim2.fromOffset(6, 0),
                Size = UDim2.new(1, -24, 1, 0),
                TextSize = textSize - 1,
                FontFace = Fonts.Regular,
                Parent = chip,
            })
            local arrow = create("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -5, 0.5, 0),
                Size = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Muted,
                ScaleType = Enum.ScaleType.Fit,
                Parent = chip,
            })
            applyIcon(arrow, "chevron-down")
            chip.MouseButton1Click:Connect(function()
                if entry.Data then
                    if pickerAnchor == box and picker and picker.Visible then
                        closePicker()
                    else
                        openPicker(box, entry.Data, column)
                    end
                end
            end)
            return { Kind = "Dropdown", Label = valueLabel }
        end
        local numeric = kind == "number"
        local box, boxStroke = editorBox(cell)
        local input = create("TextBox", {
            Position = UDim2.fromOffset(6, 0),
            Size = UDim2.new(1, -12, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = column.Placeholder or "",
            PlaceholderColor3 = Theme.Muted,
            TextColor3 = Theme.Text,
            TextSize = textSize - 1,
            FontFace = Fonts.Regular,
            TextXAlignment = alignment(column),
            TextTruncate = Enum.TextTruncate.AtEnd,
            ClearTextOnFocus = false,
            Parent = box,
        })
        local editing, editingIndex = nil, nil
        input.Focused:Connect(function()
            tween(boxStroke, { Color = Theme.Accent }, 0.15)
            editing, editingIndex = entry.Data, entry.Index
            if editing then
                local value = columnValue(editing, column)
                input.Text = value == nil and "" or tostring(value)
            end
        end)
        input.FocusLost:Connect(function()
            tween(boxStroke, { Color = Theme.Stroke }, 0.2)
            local row = editing
            editing = nil
            if not row then
                return
            end
            -- SetRows during the edit swaps every row for a new table; then write to
            -- the row now at the same index. A row that only moved (AddRow,
            -- RemoveRow) is still in the list and keeps the edit.
            if not table.find(handle.Rows, row) then
                row = handle.Rows[editingIndex]
                if not row then
                    handle:_redraw()
                    return
                end
            end
            local value = input.Text
            if numeric then
                value = Library._parseAmount(value)
                if value == nil then
                    handle:_redraw()
                    return
                end
                if column.Integer then
                    value = math.floor(value + 0.5)
                end
                value = math.clamp(value, tonumber(column.Min) or -math.huge, tonumber(column.Max) or math.huge)
            end
            if value ~= columnValue(row, column) then
                setCell(row, column, value)
                handle:_edited()
            else
                handle:_redraw()
            end
        end)
        return { Kind = "Input", Input = input, Numeric = numeric }
    end

    local function makeRemove(entry, cell)
        local button = create("ImageButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Muted,
            ScaleType = Enum.ScaleType.Fit,
            Parent = cell,
        })
        button:SetAttribute("NoDrag", true)
        applyIcon(button, "x")
        button.MouseEnter:Connect(function()
            tween(button, { ImageColor3 = Theme.Error }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { ImageColor3 = Theme.Muted }, 0.2)
        end)
        button.MouseButton1Click:Connect(function()
            local index = entry.Index
            if index and entry.Data and handle.Rows[index] == entry.Data then
                table.remove(handle.Rows, index)
                handle:_edited()
            end
        end)
        return { Kind = "Remove" }
    end

    local function updateEditor(editor, value, column, row)
        if editor.Kind == "Toggle" then
            local on = value == true
            tween(editor.Switch, { BackgroundColor3 = on and Theme.Accent or Theme.Surface3 }, 0.15)
            tween(editor.Knob, { Position = on and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, 0.15, Enum.EasingStyle.Quint)
        elseif editor.Kind == "Dropdown" then
            editor.Label.Text = value == nil and (column.Placeholder or "Select") or tostring(value)
            editor.Label.TextColor3 = value == nil and Theme.Muted or Theme.Text
        elseif editor.Kind == "Input" and not editor.Input:IsFocused() then
            if value == nil then
                editor.Input.Text = ""
            else
                editor.Input.Text = editor.Numeric and display(value, column, row) or tostring(value)
            end
        end
    end

    local function newRow()
        local rowFrame = create("TextButton", {
            Size = UDim2.new(1, 0, 0, rowHeight),
            BackgroundColor3 = Theme.Surface3,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = body,
        })
        -- The accent bar on a highlighted row sits beside the cells, outside
        -- their layout.
        local marker = create("Frame", {
            Position = UDim2.new(0, 3, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 2, 1, -10),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = rowFrame,
        })
        corner(marker, UDim.new(1, 0))
        local cellsFrame = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Parent = rowFrame,
        })
        padding(cellsFrame, 10, 10)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = cellsFrame,
        })
        local entry = { Frame = rowFrame, Marker = marker, Cells = {}, Hover = false }
        for order, column in ipairs(columns) do
            local cell = create("Frame", {
                Size = UDim2.new(column.UDim.Scale, column.UDim.Offset, 1, 0),
                BackgroundTransparency = 1,
                LayoutOrder = order,
                Parent = cellsFrame,
            })
            local text = label({
                Size = UDim2.new(1, -6, 1, 0),
                TextSize = textSize,
                FontFace = column.Rank and Fonts.Bold or Fonts.Regular,
                TextColor3 = Theme.Text,
                TextXAlignment = alignment(column),
                RichText = not column.Rank,
                Parent = cell,
            })
            local badge
            if column.Rank then
                text.Size = UDim2.fromScale(1, 1)
                text.TextXAlignment = Enum.TextXAlignment.Center
                badge = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromOffset(rowHeight - 8, rowHeight - 8),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ZIndex = 0,
                    Parent = cell,
                })
                corner(badge, UDim.new(1, 0))
            end
            local editor
            if column.Remove then
                text.Visible = false
                editor = makeRemove(entry, cell)
            elseif editable and column.Type ~= nil then
                text.Visible = false
                editor = makeEditor(entry, column, cell)
            end
            entry.Cells[order] = { Label = text, Badge = badge, Editor = editor }
        end
        local canTap = tapGuard(rowFrame, function()
            return body
        end)
        rowFrame.MouseEnter:Connect(function()
            entry.Hover = true
            tween(rowFrame, { BackgroundTransparency = 0.35 }, 0.1)
        end)
        rowFrame.MouseLeave:Connect(function()
            entry.Hover = false
            tween(rowFrame, {
                BackgroundColor3 = entry.Highlighted and Theme.Accent or Theme.Surface3,
                BackgroundTransparency = entry.Rest or 1,
            }, 0.2)
        end)
        rowFrame.MouseButton1Click:Connect(function()
            if entry.Data and canTap() then
                safeCall(opts.Callback, entry.Data, entry.Index)
            end
        end)
        return entry
    end

    local function fitHeight(instant)
        local count = shownCount or #handle.Rows
        local visible = math.clamp(count, 1, maxRows)
        local gridHeight = headerHeight + visible * rowHeight
        local total = gridTop + gridHeight + addHeight + bottom
        if shownHeight == total then
            return
        end
        local duration = (instant or shownHeight == nil) and 0 or 0.25
        shownHeight = total
        tween(grid, { Size = UDim2.new(1, -inset * 2, 0, gridHeight) }, duration, Enum.EasingStyle.Quint)
        tween(frame, { Size = UDim2.new(1, 0, 0, total) }, duration, Enum.EasingStyle.Quint)
    end

    local function render()
        local list = sortedRows()
        for position, item in ipairs(list) do
            local entry = pool[position]
            if not entry then
                entry = newRow()
                pool[position] = entry
            end
            local row = item.Row
            entry.Data = row
            entry.Index = item.Index
            entry.Frame.LayoutOrder = position
            entry.Frame.Visible = true
            local highlighted = row.Highlight == true
            if not highlighted and type(opts.Highlight) == "function" then
                local ok, result = pcall(opts.Highlight, row, item.Index)
                highlighted = ok and result == true
            end
            entry.Highlighted = highlighted
            entry.Rest = highlighted and 0.86 or (position % 2 == 0 and 0.78 or 1)
            if not entry.Hover then
                entry.Frame.BackgroundColor3 = highlighted and Theme.Accent or Theme.Surface3
                entry.Frame.BackgroundTransparency = entry.Rest
                bindColors(entry.Frame, { BackgroundColor3 = entry.Frame.BackgroundColor3 })
            end
            entry.Marker.BackgroundTransparency = highlighted and 0 or 1
            for order, column in ipairs(columns) do
                local cell = entry.Cells[order]
                if column.Rank then
                    local medal = MEDALS[item.Rank]
                    cell.Label.Text = tostring(item.Rank)
                    cell.Label.TextColor3 = medal and Color3.fromRGB(28, 22, 18) or Theme.Muted
                    bindColors(cell.Label, { TextColor3 = cell.Label.TextColor3 })
                    cell.Badge.BackgroundColor3 = medal or Theme.Surface3
                    cell.Badge.BackgroundTransparency = medal and 0.05 or 1
                elseif column.Remove then
                    -- The remove button needs no per-row state.
                else
                    local value = columnValue(row, column)
                    cell.Label.Text = Library._rich(display(value, column, row))
                    -- Column Color: a colour, a theme key or a function(value, row)
                    -- returning either. A row's Colors[key or index] beats it.
                    local wanted = column.Color
                    if type(wanted) == "function" then
                        local ok, result = pcall(wanted, value, row)
                        wanted = ok and result or nil
                    end
                    if type(row.Colors) == "table" then
                        local own = row.Colors[column.Key or column.Index]
                        if own == nil then
                            own = row.Colors[column.Index]
                        end
                        if own ~= nil then
                            wanted = own
                        end
                    end
                    local color = Library._color(wanted) or (highlighted and Theme.Accent or Theme.Text)
                    cell.Label.TextColor3 = color
                    bindColors(cell.Label, { TextColor3 = color })
                    if cell.Editor then
                        updateEditor(cell.Editor, value, column, row)
                    end
                end
            end
        end
        for position = #list + 1, #pool do
            pool[position].Frame.Visible = false
            pool[position].Data = nil
        end
        shownCount = #list
        empty.Visible = #list == 0
        empty.Text = (#list == 0 and query ~= "" and #handle.Rows > 0) and (opts.NoMatchText or "No rows match")
            or (opts.EmptyText or "Nothing here yet")
        if searchCount then
            searchCount.Visible = query ~= ""
            searchCount.Text = #list .. " / " .. #handle.Rows
        end
        fitHeight()
    end

    local function buildHeader()
        for _, cell in ipairs(headerCells) do
            cell.Frame:Destroy()
        end
        table.clear(headerCells)
        for _, entry in ipairs(pool) do
            entry.Frame:Destroy()
        end
        table.clear(pool)
        local row = header:FindFirstChild("Cells") or create("Frame", {
            Name = "Cells",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Parent = header,
        })
        if not row:FindFirstChildOfClass("UIListLayout") then
            padding(row, 10, 10)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = row,
            })
        end
        for order, column in ipairs(columns) do
            local cell = create("TextButton", {
                Size = UDim2.new(column.UDim.Scale, column.UDim.Offset, 1, 0),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = order,
                Parent = row,
            })
            local align = column.Rank and Enum.TextXAlignment.Center or alignment(column)
            local right = align == Enum.TextXAlignment.Right
            local text = label({
                Size = UDim2.new(1, align == Enum.TextXAlignment.Center and 0 or -16, 1, 0),
                Position = UDim2.fromOffset(right and 16 or 0, 0),
                Text = string.upper(column.Name),
                TextSize = 12,
                FontFace = Fonts.Bold,
                TextColor3 = Theme.Muted,
                TextXAlignment = align,
                Parent = cell,
            })
            local arrow = create("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.fromOffset(12, 12),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Accent,
                ScaleType = Enum.ScaleType.Fit,
                Visible = false,
                Parent = cell,
            })
            applyIcon(arrow, "chevron-down")
            -- The arrow sits just after the header text (before it when the
            -- column is right aligned).
            local function placeArrow()
                local width = text.TextBounds.X
                if right then
                    arrow.Position = UDim2.new(1, -(width + 15), 0.5, 0)
                elseif align == Enum.TextXAlignment.Center then
                    arrow.Position = UDim2.new(0.5, width / 2 + 3, 0.5, 0)
                else
                    local cellWidth = cell.AbsoluteSize.X / math.max(window.Scale.Scale, 0.01)
                    arrow.Position = UDim2.new(0, math.clamp(width + 4, 0, math.max(cellWidth - 12, 0)), 0.5, 0)
                end
            end
            text:GetPropertyChangedSignal("TextBounds"):Connect(placeArrow)
            cell:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeArrow)
            task.defer(placeArrow)
            local sortable = column.Sortable and not column.Rank
            if sortable then
                cell.MouseEnter:Connect(function()
                    if sortKey ~= column then
                        tween(text, { TextColor3 = Theme.Text }, 0.12)
                    end
                end)
                cell.MouseLeave:Connect(function()
                    if sortKey ~= column then
                        tween(text, { TextColor3 = Theme.Muted }, 0.2)
                    end
                end)
                cell.MouseButton1Click:Connect(function()
                    -- Numbers sort high to low first, text A to Z; the second
                    -- click flips it and the third goes back to the given order.
                    if sortKey ~= column then
                        local numeric = false
                        for _, data in ipairs(handle.Rows) do
                            local value = columnValue(data, column)
                            if value ~= nil then
                                numeric = tonumber(value) ~= nil
                                break
                            end
                        end
                        sortKey, sortDescending = column, numeric
                        column.FirstDescending = numeric
                    elseif sortDescending == column.FirstDescending then
                        sortDescending = not sortDescending
                    else
                        sortKey = nil
                    end
                    paintHeader()
                    render()
                end)
            end
            table.insert(headerCells, { Frame = cell, Label = text, Arrow = arrow, Column = column })
        end
        paintHeader()
    end

    function handle:SetColumns(list)
        table.clear(columns)
        if opts.Rank then
            table.insert(columns, { Name = "#", Rank = true, Width = TOUCH and 40 or 36, Sortable = false })
        end
        for index, column in ipairs(type(list) == "table" and list or {}) do
            if type(column) ~= "table" then
                column = { Name = tostring(column) }
            end
            local name = column.Name or column.Title or ("Column " .. index)
            table.insert(columns, {
                Name = name,
                Key = column.Key or name,
                Index = index,
                Width = column.Width,
                Align = column.Align,
                Format = column.Format,
                Color = column.Color,
                Sortable = column.Sortable ~= false and opts.Sortable ~= false,
                Type = column.Type,
                Options = column.Options,
                Min = column.Min,
                Max = column.Max,
                Integer = column.Integer,
                Default = column.Default,
                Placeholder = column.Placeholder,
                Searchable = column.Searchable,
                SearchAfter = column.SearchAfter,
                SearchPlaceholder = column.SearchPlaceholder,
                MaxRows = column.MaxRows,
            })
        end
        if canRemove then
            table.insert(columns, { Name = "", Remove = true, Width = TOUCH and 30 or 26, Sortable = false })
        end
        closePicker()
        sortKey = nil
        layoutColumns()
        buildHeader()
        render()
    end

    local function findColumn(key)
        if type(key) == "number" then
            return columns[key + (opts.Rank and 1 or 0)]
        end
        for _, column in ipairs(columns) do
            if not column.Rank and (column.Key == key or column.Name == key) then
                return column
            end
        end
        return nil
    end

    local function changed()
        if editable then
            safeCall(opts.OnChanged, handle.Rows)
        end
    end

    -- An edit made in a cell: redraw, then tell the script.
    function handle:_edited()
        render()
        changed()
    end

    function handle:_redraw()
        render()
    end

    -- Saved through the config as plain copies of the rows.
    function handle:_saveValue()
        local list = {}
        for index, row in ipairs(handle.Rows) do
            list[index] = table.clone(row)
        end
        return list
    end

    function handle:SetRows(rows, silent)
        handle.Rows = {}
        for index, row in ipairs(type(rows) == "table" and rows or {}) do
            row = type(row) == "table" and row or { row }
            handle.Rows[index] = editable and table.clone(row) or row
        end
        render()
        if not silent then
            changed()
        end
    end
    handle.Set = handle.SetRows

    function handle:GetRows()
        return handle.Rows
    end
    handle.Get = handle.GetRows

    function handle:AddRow(row, position)
        row = type(row) == "table" and row or { row }
        local index = #handle.Rows + 1
        if tonumber(position) then
            index = math.clamp(math.floor(position), 1, index)
        end
        table.insert(handle.Rows, index, row)
        render()
        return index
    end

    -- Replaces a row (by its index in the list you gave) and flashes it.
    function handle:UpdateRow(index, row)
        if not handle.Rows[index] then
            return false
        end
        handle.Rows[index] = type(row) == "table" and row or { row }
        render()
        for _, entry in ipairs(pool) do
            if entry.Index == index and entry.Frame.Visible then
                local restColor = entry.Highlighted and Theme.Accent or Theme.Surface3
                tween(entry.Frame, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.7 }, 0.08)
                task.delay(0.1, function()
                    if not entry.Hover then
                        tween(entry.Frame, { BackgroundColor3 = restColor, BackgroundTransparency = entry.Rest }, 0.5)
                    end
                end)
                break
            end
        end
        return true
    end

    function handle:RemoveRow(index)
        if not handle.Rows[index] then
            return false
        end
        table.remove(handle.Rows, index)
        render()
        return true
    end

    function handle:Clear()
        handle:SetRows({})
    end

    -- Sort(nil) goes back to the given order.
    function handle:Sort(key, descending)
        sortKey = key ~= nil and findColumn(key) or nil
        sortDescending = descending == true
        if sortKey then
            sortKey.FirstDescending = sortDescending
        end
        paintHeader()
        render()
    end

    function handle:SetTitle(text)
        if title then
            title.Text = tostring(text)
        end
    end

    function handle:SetMaxRows(count)
        maxRows = math.max(math.floor(tonumber(count) or maxRows), 1)
        fitHeight()
    end

    handle:SetColumns(opts.Columns or {})
    handle:SetRows(opts.Rows or {}, true)
    -- A new row: NewRow (a table or a function returning one), or each
    -- column's Default, falling back to off, Min or 0, the first option or "".
    function handle:NewRow()
        if type(opts.NewRow) == "function" then
            local ok, row = pcall(opts.NewRow)
            if ok and type(row) == "table" then
                return row
            end
        elseif type(opts.NewRow) == "table" then
            return table.clone(opts.NewRow)
        end
        local row = {}
        for _, column in ipairs(columns) do
            if not column.Rank and not column.Remove then
                local value = column.Default
                if value == nil then
                    local kind = columnKind(column)
                    if kind == "toggle" then
                        value = false
                    elseif kind == "number" then
                        value = tonumber(column.Min) or 0
                    elseif kind == "dropdown" then
                        value = type(column.Options) == "table" and column.Options[1] or nil
                    else
                        value = ""
                    end
                end
                row[column.Key] = value
            end
        end
        return row
    end
    if addButton then
        addButton.MouseButton1Click:Connect(function()
            if searchBox then
                searchBox.Text = ""
            end
            table.insert(handle.Rows, handle:NewRow())
            handle:_edited()
            task.defer(function()
                body.CanvasPosition = Vector2.new(0, 1e7)
            end)
        end)
    end
    if opts.SortBy ~= nil then
        handle:Sort(opts.SortBy, opts.SortDescending ~= false)
    end
    fitHeight(true)
    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local text = string.lower(trim(searchBox.Text))
            if text ~= query then
                query = text
                body.CanvasPosition = Vector2.zero
                render()
            end
        end)
    end
    function handle:SetSearch(text)
        if searchBox then
            searchBox.Text = tostring(text or "")
        end
    end
    -- Theme tags in cells are baked to colours; repaint them on theme change.
    onTheme(grid, render)
    -- The cell picker lives in the popup host, outside the table's frame, so
    -- hiding or destroying the table has to close and remove it explicitly.
    handle._onHide = closePicker
    handle._listeners = handle._listeners or {}
    table.insert(handle._listeners, function()
        closePicker()
        if picker then
            picker:Destroy()
            picker = nil
        end
    end)
    return finishElement(self, opts, handle, frame, "Table")
end



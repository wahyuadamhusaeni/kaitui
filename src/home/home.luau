-- Home

-- Home reads top to bottom: a banner greeting the player, a performance card
-- with live graphs, the server and links side by side, and a status line.

-- A Home card that grows with its stacked contents.
function Window:_homeCard(parent, order)
    local card = panelCard(parent, 0, order)
    card.AutomaticSize = Enum.AutomaticSize.Y
    padding(card, 16, 16, 14, 14)
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
    return card
end

-- A small caps heading at the top of a Home card.
function Window:_homeCaption(parent, text, order)
    return label({
        Size = UDim2.new(1, 0, 0, 22),
        Text = string.upper(text),
        TextSize = 12,
        TextColor3 = Theme.Muted,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = order,
        Parent = parent,
    })
end

-- A rounded chip of an icon and short text. Returns the chip, its label and
-- its icon so callers can recolour them.
function Window:_homeChip(parent, order, icon, text, color)
    local chip = create("TextButton", {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    padding(chip, 8, 9)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = chip,
    })
    local image = create("ImageLabel", {
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        ImageColor3 = color or Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        LayoutOrder = 1,
        Parent = chip,
    })
    applyIcon(image, icon)
    local text_ = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = text,
        TextSize = 12,
        TextColor3 = color or Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = chip,
    })
    return chip, text_, image, chipStroke
end

-- A chip that flips on press: on, it takes the accent; off, it sits muted.
function Window:_homeToggleChip(parent, order, icon, text, initial, callback)
    local chip, text_, image, chipStroke = self:_homeChip(parent, order, icon, text)
    local on = initial == true
    local function paint(duration)
        tween(chip, { BackgroundColor3 = on and Theme.Accent or Theme.Surface3, BackgroundTransparency = on and 0.85 or 0.2 }, duration)
        tween(chipStroke, { Color = on and Theme.Accent or Theme.Stroke, Transparency = on and 0.6 or 0 }, duration)
        tween(text_, { TextColor3 = on and Theme.Accent or Theme.Muted }, duration)
        tween(image, { ImageColor3 = on and Theme.Accent or Theme.Muted }, duration)
    end
    paint(0)
    chip.MouseButton1Click:Connect(function()
        on = not on
        paint(0.2)
        safeCall(callback, on)
    end)
    -- Repaints the chip when its setting is changed from elsewhere (a script call).
    local function set(state)
        state = state == true
        if state ~= on then
            on = state
            paint(0.2)
        end
    end
    return chip, set
end

function Window:_homeProfile(list, opts, order)
    local banner = panelCard(list, 140, order)
    banner.ClipsDescendants = true

    -- The avatar bust stands on the banner's right edge and fades in from
    -- the left, so it reads as part of the card rather than a framed photo.
    local bust = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, 0),
        Size = UDim2.fromOffset(140, 140),
        BackgroundTransparency = 1,
        Image = "rbxthumb://type=AvatarBust&id=" .. tostring(LocalPlayer.UserId) .. "&w=420&h=420",
        ScaleType = Enum.ScaleType.Fit,
        Parent = banner,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 0),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = bust,
    })
    local bustPlaceholder = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.6, 0.55),
        Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Parent = bust,
    })
    applyIcon(bustPlaceholder, "user")
    self:_trackAvatar(bust, bustPlaceholder)

    local textWidth = UDim2.new(1, -190, 0, 0)
    label({
        Position = UDim2.fromOffset(22, 20),
        Size = textWidth + UDim2.fromOffset(0, 14),
        Text = string.upper(opts.Welcome or "Welcome back"),
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = banner,
    })
    local nameLabel = label({
        Position = UDim2.fromOffset(22, 35),
        Size = textWidth + UDim2.fromOffset(0, 32),
        TextSize = 26,
        FontFace = Fonts.Bold,
        Parent = banner,
    })
    self:_trackName(nameLabel, "Display")
    local userLabel = label({
        Position = UDim2.fromOffset(22, 67),
        Size = textWidth + UDim2.fromOffset(0, 16),
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = banner,
    })
    self:_trackName(userLabel, "User")

    -- Chips along the bottom: tier, time left, then the privacy toggles.
    local chips = create("Frame", {
        Position = UDim2.new(0, 22, 1, -40),
        Size = UDim2.new(1, -44, 0, 24),
        BackgroundTransparency = 1,
        Parent = banner,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = chips,
    })
    local tier = opts.Tier
    if tier == nil then
        tier = "Free"
    end
    if tier then
        local tierChip, tierText, tierIcon = self:_homeChip(chips, 1, opts.TierIcon or self._logoIcon, tostring(tier), Theme.Accent)
        tierChip.Active = false
        tierText.FontFace = Fonts.Bold
        tierIcon.Size = UDim2.fromOffset(13, 13)
        self.TierLabel = tierText
    end
    local expiryChip, expiryText = self:_homeChip(chips, 2, "clock", "")
    expiryChip.Active = false
    expiryChip.Visible = false
    local _, setNameChip = self:_homeToggleChip(chips, 3, "eye-off", "Name", self._hideName, function(on)
        self:SetHideName(on)
    end)
    local _, setAvatarChip = self:_homeToggleChip(chips, 4, "user-x", "Avatar", self._hideAvatar, function(on)
        self:SetHideAvatar(on)
    end)
    self._syncPrivacyChips = function()
        setNameChip(self._hideName)
        setAvatarChip(self._hideAvatar)
    end

    return function()
        local value = opts.Expiry
        if type(value) == "function" then
            local ok, result = pcall(value)
            value = ok and result or nil
        end
        if type(value) == "number" then
            local left = value - os.time()
            expiryText.Text = left > 0 and (formatDuration(left) .. " left") or "Expired"
        elseif value ~= nil then
            expiryText.Text = tostring(value)
        else
            -- A function that stops returning a value hides the chip.
            expiryText.Text = ""
        end
        expiryChip.Visible = expiryText.Text ~= ""
    end
end

-- A large live readout with a short bar history under it. Returns the value
-- label and a push(value, color) that adds a sample.
function Window:_homeGraph(parent, order, icon, title, ceiling, unit)
    -- Reads like a perf overlay: name and min/avg/max on one line, the
    -- reading under it, and a dense history strip tinted by health.
    local cell = create("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = parent,
    })
    label({
        Size = UDim2.new(0.4, 0, 0, 14),
        Text = title,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = cell,
    })
    local range = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.6, 0, 0, 14),
        Text = "",
        TextSize = 12,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        RichText = true,
        Parent = cell,
    })
    local value = label({
        Position = UDim2.fromOffset(0, 15),
        Size = UDim2.new(1, 0, 0, 26),
        Text = "…",
        TextSize = 22,
        FontFace = Fonts.Bold,
        RichText = true,
        Parent = cell,
    })
    local track = create("Frame", {
        Position = UDim2.fromOffset(0, 46),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = cell,
    })
    create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = track,
    })
    local columns = create("Frame", {
        Size = UDim2.new(1, 0, 1, -1),
        BackgroundTransparency = 1,
        Parent = track,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = columns,
    })
    local COUNT = 48
    local bars, samples = {}, {}
    for index = 1, COUNT do
        bars[index] = create("Frame", {
            Size = UDim2.new(1 / COUNT, -1, 0, 0),
            BackgroundColor3 = Theme.Muted,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Parent = columns,
        })
    end
    -- The unit's colour is read each time, so it follows a theme change.
    local function setValue(sample)
        value.Text = ('%d<font size="13" color="#%s"> %s</font>'):format(sample, Theme.Muted:ToHex(), unit or "")
    end
    local function push(sample, color)
        setValue(sample)
        table.insert(samples, sample)
        if #samples > COUNT then
            table.remove(samples, 1)
        end
        local top, low, sum = ceiling or 1, math.huge, 0
        for _, s in ipairs(samples) do
            top = math.max(top, s)
            low = math.min(low, s)
            sum += s
        end
        local text = Theme.Text:ToHex()
        range.Text = ('min <font color="#%s">%d</font>   avg <font color="#%s">%d</font>   max <font color="#%s">%d</font>'):format(
            text, low, text, math.floor(sum / #samples + 0.5), text, math.max(table.unpack(samples)))
        local offset = COUNT - #samples
        for index, bar in ipairs(bars) do
            local s = samples[index - offset]
            local age = COUNT - index
            -- Only the newest bar animates; the rest shift into place directly,
            -- which saves a tween per bar per second.
            tween(bar, {
                Size = UDim2.new(1 / COUNT, -1, s and math.max(s / top, 0.04) or 0, 0),
                BackgroundColor3 = color,
                -- Older samples fade so the strip reads left-to-right as time.
                BackgroundTransparency = s and (age == 0 and 0 or 0.45 + 0.35 * age / COUNT) or 1,
            }, age == 0 and 0.3 or 0, Enum.EasingStyle.Quint)
        end
    end
    return value, push
end

-- A small figure: value over a quiet caption.
function Window:_homeFigure(parent, order, title)
    local cell = create("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = parent,
    })
    local value = label({
        Size = UDim2.new(1, -8, 0, 20),
        Text = "…",
        TextSize = 15,
        FontFace = Fonts.Bold,
        RichText = true,
        Parent = cell,
    })
    label({
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, -8, 0, 14),
        Text = title,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = cell,
    })
    return value
end

-- A square tile button: an icon over a short label.
function Window:_homeAction(parent, order, icon, text, callback)
    local button = create("TextButton", {
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(button, UDim.new(0, 8))
    local buttonStroke = stroke(button)
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 11),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        Parent = button,
    })
    applyIcon(image, icon)
    label({
        Position = UDim2.new(0, 4, 0, 32),
        Size = UDim2.new(1, -8, 0, 14),
        Text = text,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = button,
    })
    button.MouseEnter:Connect(function()
        tween(button, { BackgroundTransparency = 0 }, 0.15, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.StrokeHover }, 0.15)
        tween(image, { ImageColor3 = Theme.Accent }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundTransparency = 0.5 }, 0.25, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.Stroke }, 0.25)
        tween(image, { ImageColor3 = Theme.Text }, 0.25)
    end)
    button.MouseButton1Click:Connect(function()
        ripple(button)
        safeCall(callback)
    end)
    return button
end

function Window:_homeGame(parent, order)
    local card = self:_homeCard(parent, order)
    local head = create("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = card,
    })
    local icon = create("ImageLabel", {
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
        Parent = head,
    })
    corner(icon, UDim.new(0, 10))
    stroke(icon)
    local gameName = label({
        Position = UDim2.fromOffset(56, 3),
        Size = UDim2.new(1, -56, 0, 20),
        Text = "Loading",
        TextSize = 15,
        FontFace = Fonts.Bold,
        Parent = head,
    })
    local detail = label({
        Position = UDim2.fromOffset(56, 24),
        Size = UDim2.new(1, -56, 0, 16),
        Text = "",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = head,
    })
    local owner = nil
    task.spawn(function()
        local info = fetchGameInfo()
        gameName.Text = info and info.Name or detectGameName()
        owner = info and type(info.Creator) == "table" and info.Creator.Name or nil
    end)

    local actions = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = card,
    })
    padding(actions, 0, 0, 12, 0)
    create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(6, 6),
        CellSize = UDim2.new(0.25, -5, 0, 54),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = actions,
    })
    self:_homeAction(actions, 1, "refresh-cw", "Rejoin", function()
        self:Rejoin()
    end)
    self:_homeAction(actions, 2, "shuffle", "Hop", function()
        self:ServerHop()
    end)
    self:_homeAction(actions, 3, "users", "Lowest", function()
        self:JoinLowestServer()
    end)
    self:_homeAction(actions, 4, "copy", "Job ID", function()
        self:CopyToClipboard(game.JobId, "Job ID")
    end)

    label({
        Size = UDim2.new(1, 0, 0, 26),
        Text = "Job " .. shortId(game.JobId) .. "  ·  Place " .. tostring(game.PlaceId),
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        LayoutOrder = 3,
        Parent = card,
    })

    -- The detail line keeps the player count live.
    return function()
        local count = #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players"
        detail.Text = owner and ("by " .. owner .. "  ·  " .. count) or count
    end
end

-- One row of the links card: icon, title and text, and a round icon button.
function Window:_homeLink(card, order, icon, title, text, buttonIcon, callback)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = card,
    })
    create("Frame", {
        Name = "Rule",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = row,
    })
    local holder = glowIcon(row, icon, Theme.Accent, UDim2.new(0, 0, 0.5, 0))
    holder.Size = UDim2.fromOffset(16, 16)
    local titleLabel = label({
        Position = UDim2.fromOffset(28, 6),
        Size = UDim2.new(1, -68, 0, 18),
        Text = title,
        TextSize = 13,
        Parent = row,
    })
    local textLabel = label({
        Position = UDim2.fromOffset(28, 24),
        Size = UDim2.new(1, -68, 0, 15),
        Text = text,
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = row,
    })
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })
    corner(button, UDim.new(0, 8))
    local buttonStroke = stroke(button)
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        Parent = button,
    })
    applyIcon(image, buttonIcon)
    button.MouseEnter:Connect(function()
        tween(button, { BackgroundTransparency = 0 }, 0.15, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.StrokeHover }, 0.15)
        tween(image, { ImageColor3 = Theme.Accent }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundTransparency = 0.5 }, 0.25, Enum.EasingStyle.Quint)
        tween(buttonStroke, { Color = Theme.Stroke }, 0.25)
        tween(image, { ImageColor3 = Theme.Muted }, 0.25)
    end)
    button.MouseButton1Click:Connect(function()
        safeCall(callback)
    end)
    return row, titleLabel, textLabel
end

-- Builds the links card into parent, or nothing when there are no links and
-- the feature list is off. Returns the card (or nil) and the feature refresh.
function Window:_homeLinks(parent, opts, order)
    local links = {}
    if opts.Discord then
        table.insert(links, {
            Icon = opts.DiscordIcon or "message-circle",
            Title = opts.DiscordTitle or "Community",
            Text = opts.Discord,
        })
    end
    if opts.Website then
        table.insert(links, {
            Icon = opts.WebsiteIcon or "globe",
            Title = opts.WebsiteTitle or "Website",
            Text = opts.Website,
        })
    end
    for _, link in ipairs(opts.Links or {}) do
        table.insert(links, link)
    end
    local features = opts.Features
    if #links == 0 and features == false then
        return nil, function() end
    end
    local card = self:_homeCard(parent, order)
    self:_homeCaption(card, "Links", 0)
    for index, link in ipairs(links) do
        local action = type(link.Callback) == "function"
        self:_homeLink(card, index, link.Icon or "link", link.Title or "", link.Text or "", action and "arrow-up-right" or "copy", function()
            if action then
                safeCall(link.Callback)
            else
                self:CopyToClipboard(link.Copy or link.Text, link.Title)
            end
        end)
    end
    local refresh = function() end
    if features ~= false then
        if type(features) == "table" then
            self._featuresTitle = features.Title
            self._features = features.List or (#features > 0 and features or nil)
        end
        local _, _, text_ = self:_homeLink(card, 100,
            type(features) == "table" and features.Icon or "list-checks",
            type(features) == "table" and features.Title or "Feature list",
            "", "chevron-right", function()
                self:ShowFeatures()
            end)
        refresh = function()
            local desc = type(features) == "table" and features.Desc
            text_.Text = desc or (self:_featureSummary())
        end
        task.defer(refresh)
    end
    -- The first row needs no rule above it.
    local first = nil
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("Frame") and child:FindFirstChild("Rule") and (not first or child.LayoutOrder < first.LayoutOrder) then
            first = child
        end
    end
    if first then
        first.Rule.Visible = false
    end
    return card, refresh
end

-- A quiet status line under the cards: executor support on the left, the
-- hide key on the right.
function Window:_homeExecutor(list, opts, order)
    local line = create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = list,
    })
    local executor, supported, message = executorReport(opts)
    local dot = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = supported and Theme.Success or Theme.Warning,
        BorderSizePixel = 0,
        Parent = line,
    })
    corner(dot, UDim.new(1, 0))
    local left = create("Frame", {
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -170, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = line,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = left,
    })
    label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = executor,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 1,
        Parent = left,
    })
    label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = message,
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = supported and Theme.Muted or Theme.Warning,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = left,
    })

    local hint = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Parent = line,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = hint,
    })
    label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = TOUCH and "Tap the pill or" or "Hide with",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 1,
        Parent = hint,
    })
    local chip = create("Frame", {
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = hint,
    })
    corner(chip, UDim.new(0, 5))
    stroke(chip)
    padding(chip, 6, 6)
    self._keyChipLabel = label({
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = keyName(self.Keybind),
        TextSize = 12,
        FontFace = Fonts.Bold,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip,
    })
end

-- Feature list: every control the script adds, grouped by tab, or a list the
-- script writes itself. Items that match a control jump to it when picked.

Window._featureKinds = {
    Toggle = true,
    Slider = true,
    Dropdown = true,
    Input = true,
    Keybind = true,
    ColorPicker = true,
    Stepper = true,
    Button = true,
    ButtonRow = true,
    OrderList = true,
    Segmented = true,
    Textarea = true,
}

function Window:_featureGroups()
    local found, byName = {}, {}
    for _, tab in ipairs(self.Tabs) do
        if tab ~= self.Home and tab._userVisible ~= false then
            local group = { Name = tab.Name, Icon = tab._iconName, Items = {} }
            for _, page in ipairs(tab._subTabs or { tab }) do
                local sub = page._isSubTab and page or nil
                local function add(name, element, box, path)
                    if type(name) ~= "string" or name == "" then
                        return
                    end
                    local item = {
                        Name = name,
                        Kind = element._type == "ButtonRow" and "Button" or element._type,
                        Path = path,
                        Result = { Tab = tab, Sub = sub, Target = element, Group = box },
                    }
                    table.insert(group.Items, item)
                    byName[string.lower(name)] = byName[string.lower(name)] or item
                end
                local function addElement(element, box, path)
                    if element._destroyed or not self._featureKinds[element._type] or (element._isShown and not element:_isShown()) then
                        return
                    end
                    if element._type == "ButtonRow" and element.Buttons then
                        for _, button in ipairs(element.Buttons) do
                            add(button.Label.Text, element, box, path)
                        end
                    else
                        add(element._searchName, element, box, path)
                    end
                end
                if not page._noSearch then
                    for _, element in ipairs(page._items or {}) do
                        addElement(element, nil, sub and sub.Name or nil)
                    end
                    for _, box in ipairs(page._groupboxes or {}) do
                        if Library._pageShown(box) and not box._manager then
                            for _, element in ipairs(box._items) do
                                addElement(element, box, sub and (sub.Name .. "  ›  " .. box.Name) or box.Name)
                            end
                        end
                    end
                end
            end
            if #group.Items > 0 then
                table.insert(found, group)
            end
        end
    end
    local custom = self._features
    if type(custom) ~= "table" then
        return found
    end
    -- A written list: groups of items, or bare items, which gather into one
    -- group where the first one appears.
    local function customItem(entry)
        if type(entry) ~= "table" then
            entry = { Name = entry }
        end
        local name = tostring(entry.Name or entry.Title or entry[1] or "")
        local link = byName[string.lower(name)]
        return {
            Name = name,
            Desc = entry.Desc or entry.Description,
            Tag = entry.Tag,
            Icon = entry.Icon,
            Kind = link and link.Kind,
            Path = link and link.Path,
            Result = link and link.Result,
            Callback = entry.Callback,
        }
    end
    local groups, loose = {}, nil
    for _, entry in ipairs(custom) do
        if type(entry) == "table" and type(entry.Items) == "table" then
            local group = { Name = tostring(entry.Name or entry.Title or "Features"), Icon = entry.Icon, Items = {} }
            for _, item in ipairs(entry.Items) do
                table.insert(group.Items, customItem(item))
            end
            table.insert(groups, group)
        else
            if not loose then
                loose = { Name = self._featuresTitle or "Features", Items = {} }
                table.insert(groups, loose)
            end
            table.insert(loose.Items, customItem(entry))
        end
    end
    return groups
end

function Window:_featureSummary()
    local groups = self:_featureGroups()
    local count = 0
    for _, group in ipairs(groups) do
        count += #group.Items
    end
    local text = count .. (count == 1 and " feature" or " features")
    if type(self._features) ~= "table" and #groups > 0 then
        text ..= " across " .. #groups .. (#groups == 1 and " tab" or " tabs")
    end
    return text, groups, count
end

-- Opens the feature list over the window. Search filters it; picking an item
-- linked to a control closes the list and jumps to that control.
function Window:ShowFeatures()
    if self._dialog then
        (self._dialog.Cancel or self._dialog.Close)()
    end
    local summary, groups, total = self:_featureSummary()
    local PAD = 16
    local ROW = TOUCH and 44 or 38
    local body = self.Body

    local overlay = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = body,
    })
    -- A canvas group so the whole list fades as one on open and close.
    local card_ = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10),
        Size = UDim2.fromOffset(420, 460),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Active = true,
        Parent = overlay,
    })
    corner(card_, UDim.new(0, 12))
    local cardStroke = stroke(card_, Theme.Stroke, 1)
    local cardScale = create("UIScale", { Scale = 0.94, Parent = card_ })
    local function fit()
        local scale = self.Scale.Scale
        local size = body.AbsoluteSize / scale
        card_.Size = UDim2.fromOffset(math.min(440, size.X - 24), math.min(480, size.Y - 24))
    end
    fit()
    local fitConnection = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

    local iconHolder = glowIcon(card_, "list-checks", Theme.Accent, UDim2.new(0, PAD, 0, PAD + 10))
    iconHolder.Size = UDim2.fromOffset(18, 18)
    label({
        Position = UDim2.fromOffset(PAD + 28, PAD),
        Size = UDim2.new(1, -(PAD * 2 + 28 + 36), 0, 18),
        Text = self._featuresTitle or "Features",
        TextSize = 15,
        Parent = card_,
    })
    label({
        Position = UDim2.fromOffset(PAD + 28, PAD + 19),
        Size = UDim2.new(1, -(PAD * 2 + 28 + 36), 0, 14),
        Text = summary,
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = card_,
    })
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -(PAD - 6), 0, PAD - 6),
        Size = TOUCH and UDim2.fromOffset(40, 40) or UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = card_,
    })
    corner(closeButton, UDim.new(0, 8))
    local closeIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        Parent = closeButton,
    })
    applyIcon(closeIcon, "x")
    if closeIcon.Image == "" then
        closeIcon:Destroy()
        label({ Size = UDim2.fromScale(1, 1), Text = "×", TextSize = 20, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = closeButton })
    end
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { BackgroundTransparency = 0.5 }, 0.12)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { BackgroundTransparency = 1 }, 0.2)
    end)

    local top = PAD + 44
    local searchHolder = create("Frame", {
        Position = UDim2.fromOffset(PAD, top),
        Size = UDim2.new(1, -PAD * 2, 0, TOUCH and 36 or 32),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = card_,
    })
    corner(searchHolder, UDim.new(0, 7))
    local searchStroke = stroke(searchHolder)
    local _, searchIcon = glowIcon(searchHolder, "search", Theme.Muted, UDim2.new(0, 10, 0.5, 0))
    searchIcon.Parent.Size = UDim2.fromOffset(14, 14)
    local searchBox = create("TextBox", {
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search features",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })
    searchBox.Focused:Connect(function()
        tween(searchStroke, { Color = Theme.StrokeHover }, 0.15)
        tween(searchIcon, { ImageColor3 = Theme.Accent }, 0.15)
    end)
    searchBox.FocusLost:Connect(function()
        tween(searchStroke, { Color = Theme.Stroke }, 0.2)
        tween(searchIcon, { ImageColor3 = Theme.Muted }, 0.2)
    end)
    top += (TOUCH and 36 or 32) + 10

    local scroller = create("ScrollingFrame", {
        Position = UDim2.fromOffset(PAD, top),
        Size = UDim2.new(1, -PAD * 2 + 6, 1, -(top + PAD - 4)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = TOUCH and 4 or 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(),
        Parent = card_,
    })
    local content = create("Frame", {
        Size = UDim2.new(1, -10, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = scroller,
    })
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = content,
    })
    -- Canvas sized by hand, as elsewhere, so it scrolls under UIScale.
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / self.Scale.Scale + 4)
    end)
    local noResults = label({
        Size = UDim2.new(1, 0, 0, 60),
        Text = total == 0 and "No features yet" or "No matches",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 0,
        Visible = total == 0,
        Parent = content,
    })

    local dialog = {}
    local closed = false
    local stopEscape = nil
    function dialog.Close()
        if closed then
            return
        end
        closed = true
        if self._dialog == dialog then
            self._dialog = nil
        end
        fitConnection:Disconnect()
        if stopEscape then
            -- Deferred: Close can run from inside the input dispatch loop.
            task.defer(stopEscape)
        end
        if searchBox:IsFocused() then
            searchBox:ReleaseFocus()
        end
        tween(overlay, { BackgroundTransparency = 1 }, 0.18)
        tween(card_, { Position = UDim2.new(0.5, 0, 0.5, 8), GroupTransparency = 1 }, 0.18, Enum.EasingStyle.Quint)
        tween(cardScale, { Scale = 0.96 }, 0.18, Enum.EasingStyle.Quint)
        tween(cardStroke, { Transparency = 1 }, 0.12)
        task.delay(0.2, function()
            overlay:Destroy()
        end)
    end

    local sections = {}
    local order = 0
    for _, group in ipairs(groups) do
        order += 1
        local header = create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = content,
        })
        local headIcon = glowIcon(header, group.Icon or "layout-grid", Theme.Accent, UDim2.new(0, 2, 0, 18))
        headIcon.Size = UDim2.fromOffset(14, 14)
        label({
            Position = UDim2.fromOffset(24, 10),
            Size = UDim2.new(1, -70, 0, 16),
            Text = string.upper(group.Name),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            Parent = header,
        })
        local countLabel = label({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -4, 0, 10),
            Size = UDim2.new(0, 40, 0, 16),
            Text = tostring(#group.Items),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = header,
        })
        local section = { Header = header, Count = countLabel, Rows = {} }
        for _, item in ipairs(group.Items) do
            order += 1
            local sub = item.Desc or item.Path
            local clickable = item.Result ~= nil or type(item.Callback) == "function"
            local row = create("TextButton", {
                Size = UDim2.new(1, 0, 0, sub and ROW + 4 or ROW - 4),
                BackgroundColor3 = Theme.Surface2,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = order,
                Parent = content,
            })
            corner(row, UDim.new(0, 8))
            local rowIcon = glowIcon(row, item.Icon or self._searchIcons[item.Kind] or "check", Theme.Muted, UDim2.new(0, 10, 0.5, 0))
            rowIcon.Size = UDim2.fromOffset(14, 14)
            local right = 12 + (clickable and 22 or 0)
            local tag
            if item.Tag then
                tag = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -(clickable and 30 or 10), 0.5, 0),
                    Size = UDim2.fromOffset(0, 20),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 0.85,
                    BorderSizePixel = 0,
                    Parent = row,
                })
                corner(tag, UDim.new(0, 5))
                padding(tag, 7, 7)
                label({
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Text = tostring(item.Tag),
                    TextSize = 12,
                    TextColor3 = Theme.Accent,
                    TextTruncate = Enum.TextTruncate.None,
                    Parent = tag,
                })
            end
            local nameLabel = label({
                Position = UDim2.fromOffset(34, sub and 5 or 0),
                Size = UDim2.new(1, -(34 + right), 0, sub and 18 or ROW - 4),
                Text = item.Name,
                TextSize = 13,
                Parent = row,
            })
            local subLabel
            if sub then
                subLabel = label({
                    Position = UDim2.fromOffset(34, 23),
                    Size = UDim2.new(1, -(34 + right), 0, 14),
                    Text = sub,
                    TextSize = 12,
                    FontFace = Fonts.Regular,
                    TextColor3 = Theme.Muted,
                    Parent = row,
                })
            end
            if tag then
                local function reserveTag()
                    local width = 34 + right + tag.AbsoluteSize.X / self.Scale.Scale + 8
                    nameLabel.Size = UDim2.new(1, -width, 0, nameLabel.Size.Y.Offset)
                    if subLabel then
                        subLabel.Size = UDim2.new(1, -width, 0, 14)
                    end
                end
                tag:GetPropertyChangedSignal("AbsoluteSize"):Connect(reserveTag)
                task.defer(reserveTag)
            end
            if clickable then
                local go = create("ImageLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    BackgroundTransparency = 1,
                    ImageColor3 = Theme.Muted,
                    ImageTransparency = 0.4,
                    ScaleType = Enum.ScaleType.Fit,
                    Parent = row,
                })
                applyIcon(go, "arrow-up-right")
            end
            local isTap = tapGuard(row, function()
                return scroller
            end)
            row.MouseEnter:Connect(function()
                if not usingTouch() then
                    tween(row, { BackgroundTransparency = 0.3 }, 0.12)
                end
            end)
            row.MouseLeave:Connect(function()
                tween(row, { BackgroundTransparency = 1 }, 0.2)
            end)
            row.MouseButton1Click:Connect(function()
                if closed or not clickable or not isTap() then
                    return
                end
                dialog.Close()
                if item.Result then
                    self:_revealResult(item.Result)
                end
                safeCall(item.Callback)
            end)
            table.insert(section.Rows, { Frame = row, Key = string.lower(item.Name .. " " .. (sub or "")) })
        end
        table.insert(sections, section)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(searchBox.Text)
        local any = false
        for _, section in ipairs(sections) do
            local shown = 0
            for _, row in ipairs(section.Rows) do
                local match = query == "" or string.find(row.Key, query, 1, true) ~= nil
                row.Frame.Visible = match
                if match then
                    shown += 1
                end
            end
            section.Header.Visible = shown > 0
            section.Count.Text = tostring(shown)
            any = any or shown > 0
        end
        noResults.Visible = not any
        scroller.CanvasPosition = Vector2.zero
    end)
    closeButton.MouseButton1Click:Connect(dialog.Close)
    overlay.MouseButton1Click:Connect(dialog.Close)
    stopEscape = self:_listen("Began", function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            dialog.Close()
        end
    end)

    self._dialog = dialog
    tween(overlay, { BackgroundTransparency = 0.45 }, 0.25)
    tween(card_, { Position = UDim2.fromScale(0.5, 0.5), GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quint)
    tween(cardScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
    return dialog
end

function Window:_homeStats(list, opts, order, tab)
    local show = opts.Stats or { "Players", "Execs", "Session", "FPS", "Ping" }
    -- FPS and ping get large readouts with a bar history; every other stat
    -- is a small figure in the row under them.
    local card = self:_homeCard(list, order)
    local graphs = create("Frame", {
        Size = UDim2.new(1, 0, 0, 76),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = card,
    })
    create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(28, 0),
        CellSize = UDim2.new(0.5, -14, 0, 76),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = graphs,
    })
    local rule = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = card,
    })
    local figures = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = card,
    })
    padding(figures, 0, 0, 12, 0)
    local figureGrid = create("UIGridLayout", {
        CellPadding = UDim2.fromOffset(0, 8),
        CellSize = UDim2.new(0.25, 0, 0, 36),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = figures,
    })
    local values, sparks = {}, {}
    local graphCount, figureCount = 0, 0
    for index, name in ipairs(show) do
        local kind = STAT_TYPES[name]
        if kind and not values[name] then
            if name == "FPS" or name == "Ping" then
                graphCount += 1
                values[name], sparks[name] = self:_homeGraph(graphs, index, kind[1], kind[2], name == "FPS" and 60 or 100, name == "FPS" and "fps" or "ms")
            else
                figureCount += 1
                values[name] = self:_homeFigure(figures, index, kind[2])
            end
        end
    end
    graphs.Visible = graphCount > 0
    figures.Visible = figureCount > 0
    rule.Visible = graphCount > 0 and figureCount > 0
    if graphCount == 0 then
        padding(figures, 0, 0, 0, 0)
    end
    local function fitFigures()
        local width = figures.AbsoluteSize.X / self.Scale.Scale
        local columns = math.clamp(figureCount, 1, width >= 440 and 5 or 3)
        figureGrid.CellSize = UDim2.new(1 / columns, 0, 0, 36)
    end
    figures:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitFigures)
    task.defer(fitFigures)

    if values.Executor then
        values.Executor.Text = detectExecutor()
    end
    if values.Game then
        values.Game.Text = "Loading"
        task.spawn(function()
            values.Game.Text = detectGameName()
        end)
    end
    if values.Region then
        values.Region.Text = "Loading"
        detectRegion(function(region)
            values.Region.Text = region
        end)
    end
    if values.Execs then
        local executions = bumpExecutions(opts.StatsFolder or self.ConfigFolder)
        values.Execs.Text = executions and tostring(executions) or "—"
    end
    if values.Friends then
        local friends = {}
        local function recount()
            local total = 0
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local known = friends[player.UserId]
                    if known == nil then
                        local ok, result = pcall(function()
                            return LocalPlayer:IsFriendsWith(player.UserId)
                        end)
                        known = ok and result == true
                        friends[player.UserId] = known
                    end
                    if known then
                        total += 1
                    end
                end
            end
            values.Friends.Text = tostring(total)
        end
        task.spawn(recount)
        table.insert(self._connections, Players.PlayerAdded:Connect(function()
            task.spawn(recount)
        end))
        table.insert(self._connections, Players.PlayerRemoving:Connect(function()
            task.defer(recount)
        end))
    end

    local session = values.Session or values.Uptime
    local started = os.clock()
    local frames = 0
    self:_listen("Render", function()
        frames += 1
    end)
    -- FPS, ping and memory are tinted by how healthy they are, unless the
    -- script turns that off with StatColors = false.
    local tinted = opts.StatColors ~= false
    local function tint(valueLabel, color)
        if tinted and valueLabel.TextColor3 ~= color then
            tween(valueLabel, { TextColor3 = color }, 0.3)
        end
    end
    return function()
        if values.FPS then
            sparks.FPS(frames, tinted and Library._healthColor(frames, 50, 30) or Theme.Muted)
        end
        frames = 0
        if values.Ping then
            -- Same reading as the watermark, so both show one number.
            local ping = self:_pingMs()
            sparks.Ping(ping, tinted and Library._healthColor(ping, 150, 300, true) or Theme.Muted)
        end
        if values.Players then
            values.Players.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        end
        if session then
            session.Text = formatDuration(os.clock() - started)
        end
        if values.Time then
            values.Time.Text = os.date(opts.TimeFormat or "%H:%M")
        end
        if values.ServerAge then
            values.ServerAge.Text = formatDuration(workspace.DistributedGameTime)
        end
        if values.Memory then
            local ok, memory = pcall(function()
                return StatsService:GetTotalMemoryUsageMb()
            end)
            values.Memory.Text = ok and string.format("%d MB", memory) or "—"
            tint(values.Memory, ok and Library._healthColor(memory, 1500, 3000, true) or Theme.Text)
        end
    end, function()
        frames = 0
    end
end

local function homePage(sub, page)
    local list = sub.List
    if type(page.Content) == "string" then
        local card_ = panelCard(list, 0, 1)
        card_.AutomaticSize = Enum.AutomaticSize.Y
        padding(card_, 16, 16, 14, 16)
        label({
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = page.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = card_,
        })
    end
    if type(page.Entries) == "table" then
        for index, entry in ipairs(page.Entries) do
            local card_ = panelCard(list, 0, index + 1)
            card_.AutomaticSize = Enum.AutomaticSize.Y
            padding(card_, 16, 16, 14, 16)
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = card_,
            })
            local head = create("Frame", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Parent = card_,
            })
            label({
                Size = UDim2.new(1, -90, 1, 0),
                Text = entry.Title or entry.Version or "Update",
                TextSize = 15,
                Parent = head,
            })
            if entry.Date or entry.Tag then
                local chip = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(0, 20),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Theme.Surface,
                    BorderSizePixel = 0,
                    Parent = head,
                })
                corner(chip, UDim.new(0, 5))
                stroke(chip)
                padding(chip, 8, 8)
                label({
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Text = entry.Tag or entry.Date,
                    TextSize = 12,
                    TextColor3 = Theme.Muted,
                    TextTruncate = Enum.TextTruncate.None,
                    Parent = chip,
                })
            end
            local body = entry.Content or entry.Body
            if type(entry.Changes) == "table" then
                body = "• " .. table.concat(entry.Changes, "\n• ")
            end
            if body then
                label({
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Text = body,
                    TextSize = 13,
                    FontFace = Fonts.Regular,
                    TextColor3 = Theme.Muted,
                    TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.None,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = 2,
                    Parent = card_,
                })
            end
        end
    end
    if type(page.Build) == "function" then
        safeCall(page.Build, sub, list)
    else
        sub._noSearch = true
    end
end

function Window:_buildHome(opts)
    Library._validate("CreateWindow.Home", opts, {
        Name = "string", Desc = "string", Title = "string", Welcome = "string", Tier = "string|boolean", TierIcon = "string|number|table",
        Expiry = "number|string|function", Stats = "table", StatColors = "boolean", StatsFolder = "string", TimeFormat = "string",
        SupportedExecutors = "table", Discord = "string", Website = "string", DiscordTitle = "string", WebsiteTitle = "string",
        Links = "table", HideName = "boolean", HideAvatar = "boolean", Features = "table|boolean", OverviewName = "string",
        TabIcon = "string|number|table", Pages = "table",
    })
    self._hideName = opts.HideName == true
    self._hideAvatar = opts.HideAvatar == true
    self:_renderIdentity(true)
    local tab = self:Tab({
        Name = opts.Name or "Home",
        Desc = opts.Desc,
        Icon = opts.Icon or "house",
        PageTitle = opts.Title or "Home",
    })
    tab._order = 100
    self.Home = tab

    local pages = opts.Pages or opts.Tabs
    local overview = tab
    if type(pages) == "table" and #pages > 0 then
        overview = tab:SubTab({ Name = opts.OverviewName or "Overview", Icon = opts.TabIcon or "layout-grid" })
    end
    overview._noSearch = true
    overview._order = 100
    local list = overview.List

    local refreshExpiry = self:_homeProfile(list, opts, 1)
    local refreshStats, resetStats = self:_homeStats(list, opts, 2, tab)

    -- Server and links side by side, stacked when narrow.
    local split = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = list,
    })
    local splitLayout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = split,
    })
    local function column(order_)
        local frame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order_,
            Parent = split,
        })
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
        return frame
    end
    local leftColumn, rightColumn = column(1), column(2)
    local refreshGame = self:_homeGame(leftColumn, 1)
    local linksCard, refreshFeatures = self:_homeLinks(rightColumn, opts, 1)
    if not linksCard then
        rightColumn:Destroy()
    end
    local function fitSplit()
        local wide = linksCard ~= nil and split.AbsoluteSize.X / self.Scale.Scale >= 540
        splitLayout.FillDirection = wide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
        local size = wide and UDim2.new(0.5, -5, 0, 0) or UDim2.new(1, 0, 0, 0)
        leftColumn.Size = size
        if linksCard then
            rightColumn.Size = size
        end
    end
    split:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSplit)
    task.defer(fitSplit)

    self:_homeExecutor(list, opts, 4)

    if type(pages) == "table" then
        for _, page in ipairs(pages) do
            homePage(tab:SubTab({ Name = page.Name or page.Title or "Page", Icon = page.Icon }), page)
        end
    end

    refreshExpiry()
    refreshStats()
    refreshGame()
    task.spawn(function()
        -- The feature summary walks every element in every tab, so it refreshes
        -- every 5 s rather than every tick.
        local ticks = 0
        while not self._destroyed and tab._page.Parent do
            task.wait(1)
            if self.Open and not self.Minimized and self.CurrentTab == tab then
                ticks += 1
                refreshStats()
                refreshExpiry()
                refreshGame()
                if ticks % 5 == 1 then
                    refreshFeatures()
                end
            else
                ticks = 0
                resetStats()
            end
        end
    end)
    return tab
end


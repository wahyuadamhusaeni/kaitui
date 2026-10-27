local function emptyState(parent, icon, text)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -10),
        Size = UDim2.fromOffset(200, 70),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local image = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder,
    })
    applyIcon(image, icon)
    local caption = label({
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 16),
        Text = text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = holder,
    })
    return holder, caption, image
end

local function fadeSlideIn(group, restY)
    restY = restY or 0
    group.GroupTransparency = 1
    group.Position = UDim2.fromOffset(0, restY + 14)
    group.Visible = true
    tween(group, { GroupTransparency = 0, Position = UDim2.fromOffset(0, restY) }, 0.32, Enum.EasingStyle.Quint)
end

local function formatDuration(seconds)
    seconds = math.max(math.floor(seconds), 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds / 3600) % 24
    local minutes = math.floor(seconds / 60) % 60
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds % 60)
    end
    return string.format("%ds", seconds)
end

local function shortId(id)
    if type(id) ~= "string" or id == "" then
        return "Studio"
    end
    if #id > 16 then
        return id:sub(1, 8) .. "..." .. id:sub(-4)
    end
    return id
end

local function copyToClipboard(text)
    local setter = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if type(setter) ~= "function" then
        return false
    end
    return (pcall(setter, tostring(text)))
end

local function fetchServers(order)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true",
        game.PlaceId,
        order
    )
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
        return nil
    end
    return data.data
end

local function softButton(parent, text, props, callback)
    local button = create("TextButton", {
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = parent,
    })
    for key, value in pairs(props) do
        button[key] = value
    end
    corner(button, UDim.new(0, 6))
    local buttonStroke = stroke(button)
    local text_ = label({
        Size = UDim2.fromScale(1, 1),
        Text = text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = button,
    })
    if button.AutomaticSize == Enum.AutomaticSize.X then
        text_.Size = UDim2.new(0, 0, 1, 0)
        text_.AutomaticSize = Enum.AutomaticSize.X
        text_.TextTruncate = Enum.TextTruncate.None
        padding(button, 14, 14)
    end
    -- Styled buttons (a Primary fill) set their own resting and hover transparency.
    button.MouseEnter:Connect(function()
        tween(button, { BackgroundTransparency = button:GetAttribute("HoverTransparency") or 0.15 }, 0.12)
        tween(buttonStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundTransparency = button:GetAttribute("RestTransparency") or 0.45 }, 0.25)
        tween(buttonStroke, { Color = Theme.Stroke }, 0.25)
    end)
    button.MouseButton1Click:Connect(function()
        ripple(button)
        safeCall(callback)
    end)
    return button, text_
end

local function panelCard(parent, height, order)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent,
    })
    frame:SetAttribute("NoDrag", true)
    corner(frame, UDim.new(0, 10))
    stroke(frame)
    return frame
end

local STAT_TYPES = {
    Players = { "users", "Players" },
    Friends = { "user-check", "Friends" },
    Execs = { "zap", "Execs" },
    Session = { "timer", "Session" },
    Uptime = { "timer", "Session" },
    FPS = { "gauge", "FPS" },
    Ping = { "wifi", "Ping" },
    Executor = { "terminal", "Executor" },
    Game = { "gamepad-2", "Game" },
    Region = { "globe", "Region" },
    Time = { "clock", "Time" },
    ServerAge = { "server", "Server age" },
    Memory = { "cpu", "Memory" },
}

-- Health colour for a live metric: Success under good, Warning under bad,
-- Error past it. lowerIsBetter flips the scale (ping, memory).
function Library._healthColor(value, good, bad, lowerIsBetter)
    if type(value) ~= "number" then
        return Theme.Text
    end
    if lowerIsBetter then
        return value <= good and Theme.Success or value <= bad and Theme.Warning or Theme.Error
    end
    return value >= good and Theme.Success or value >= bad and Theme.Warning or Theme.Error
end

local function bumpExecutions(folder)
    if not fileApiAvailable() then
        return nil
    end
    local path = folder .. "/executions.txt"
    local count = 0
    pcall(function()
        ensureFolder(folder)
        if isfile(path) then
            count = tonumber(readfile(path)) or 0
        end
    end)
    count += 1
    pcall(writefile, path, tostring(count))
    return count
end

-- Containers: a tab or sub tab owns a scrolling list. Elements added straight
-- to it stack full width, groupboxes go into two columns underneath.


-- Server actions

-- On the client most teleport failures arrive later through TeleportInitFailed
-- rather than as an error from the call. Runs each attempt in turn, moving on
-- to the next one when the previous fails either way.
function Window:_teleport(title, attempts)
    -- Only the newest session reacts: a second click (or the game's own
    -- teleport failing) must not set off retries in an older one.
    local session = {}
    self._teleportSession = session
    local index = 0
    local connection
    local function finish()
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end
    local function try()
        index += 1
        local attempt = attempts[index]
        if not attempt or self._destroyed or self._teleportSession ~= session then
            finish()
            return
        end
        if attempt.Notice then
            self:Notify(attempt.Notice)
        end
        local ok, err = pcall(attempt.Run)
        if not ok then
            self:Notify({ Title = title .. " failed", Content = tostring(err), Type = "Error", Duration = 4 })
            try()
        end
    end
    connection = TeleportService.TeleportInitFailed:Connect(function(player, result, message)
        if player ~= LocalPlayer then
            return
        end
        if self._teleportSession ~= session then
            finish()
            return
        end
        local reason = (type(message) == "string" and message ~= "") and message or tostring(result)
        local more = attempts[index + 1] ~= nil
        self:Notify({
            Title = title .. " failed",
            Content = more and (reason .. ". Trying another server…") or reason,
            Type = "Error",
            Duration = 4,
        })
        try()
    end)
    table.insert(self._connections, connection)
    -- Stop listening once a teleport had plenty of time to fail.
    task.delay(30, finish)
    try()
end

function Window:Rejoin()
    if game.PrivateServerId ~= "" then
        self:Notify({ Title = "Rejoin unavailable", Content = "Rejoining a private server isn't supported", Type = "Warning", Duration = 4 })
        return
    end
    self:_teleport("Rejoin", {
        {
            Notice = { Title = "Rejoining", Content = "Teleporting back into this server", Icon = "refresh-cw", Duration = 3 },
            Run = function()
                if #Players:GetPlayers() <= 1 or game.JobId == "" then
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                else
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                end
            end,
        },
    })
end

local function hopServers(window, order, pick, title)
    task.spawn(function()
        local servers = fetchServers(order)
        if not servers then
            window:Notify({ Title = title .. " failed", Content = "Could not load the server list", Type = "Error", Duration = 4 })
            return
        end
        local candidates = {}
        for _, server in ipairs(servers) do
            if type(server) == "table" and server.id ~= game.JobId then
                local playing, capacity = tonumber(server.playing), tonumber(server.maxPlayers)
                if playing and capacity and playing < capacity then
                    table.insert(candidates, server)
                end
            end
        end
        local target = #candidates > 0 and pick(candidates) or nil
        if not target then
            window:Notify({ Title = title .. " failed", Content = "No other open server found", Type = "Warning", Duration = 4 })
            return
        end
        -- The picked server first, then up to two others in case it fills up meanwhile.
        local queue = { target }
        for _, server in ipairs(candidates) do
            if #queue >= 3 then
                break
            end
            if server ~= target then
                table.insert(queue, server)
            end
        end
        local attempts = {}
        for _, server in ipairs(queue) do
            table.insert(attempts, {
                Notice = {
                    Title = title,
                    Content = string.format("Joining a server with %d/%d players", server.playing, server.maxPlayers),
                    Icon = "server",
                    Duration = 3,
                },
                Run = function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                end,
            })
        end
        window:_teleport(title, attempts)
    end)
end

function Window:ServerHop()
    hopServers(self, "Desc", function(list)
        return list[math.random(1, #list)]
    end, "Server hop")
end

function Window:JoinLowestServer()
    hopServers(self, "Asc", function(list)
        table.sort(list, function(a, b)
            return a.playing < b.playing
        end)
        return list[1]
    end, "Lowest server")
end

function Window:CopyToClipboard(text, what)
    local ok = copyToClipboard(text)
    self:Notify({
        Title = ok and "Copied" or "Clipboard unavailable",
        Content = ok and (what or tostring(text)) or "Your executor has no setclipboard",
        Type = ok and "Success" or "Error",
        Icon = ok and "clipboard-check" or nil,
        Duration = 2.5,
    })
    return ok
end


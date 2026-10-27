-- Player picker: a dropdown whose rows are the players in the server. Built on
-- Tab:Dropdown. Each row is a small proxy table whose __tostring is the label,
-- so the dropdown draws and searches it like a string while the picker maps it
-- back to the Player. Callbacks, Get and Set speak Players; configs store names.
function Tab:PlayerPicker(opts)
    opts = normalize(opts, { Title = "Name", Description = "Desc", CurrentOption = "Default", Value = "Default", MultipleOptions = "Multi" })
    local multi = opts.Multi == true
    local includeSelf = opts.IncludeSelf == true
    local display = opts.Display or "Both"
    local flag = opts.Flag
    local userCallback = opts.Callback
    local window = self.Window

    -- Strong on purpose: the dropdown keys its picks by option object, and an
    -- Instance's Lua handle can be collected while the player is still here,
    -- which would mint a new proxy and lose the pick. Leavers are removed below.
    local proxies = {}
    local proxyMeta = {
        __tostring = function(proxy)
            local player = proxy.Player
            local ok, name, displayName = pcall(function()
                return player.Name, player.DisplayName
            end)
            if not ok then
                return "?"
            end
            if display == "Name" then
                return name
            elseif display == "DisplayName" then
                return displayName
            end
            if displayName == name then
                return name
            end
            return displayName .. " (@" .. name .. ")"
        end,
    }
    local function proxyOf(player)
        local proxy = proxies[player]
        if not proxy then
            proxy = setmetatable({ Player = player }, proxyMeta)
            proxies[player] = proxy
        end
        return proxy
    end

    -- Current players, sorted by display name; `leaving` is skipped because
    -- PlayerRemoving fires while that player is still listed.
    local function playerList(leaving)
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= leaving and (includeSelf or player ~= LocalPlayer) then
                table.insert(list, player)
            end
        end
        table.sort(list, function(a, b)
            local da, db = string.lower(a.DisplayName), string.lower(b.DisplayName)
            if da ~= db then
                return da < db
            end
            return string.lower(a.Name) < string.lower(b.Name)
        end)
        return list
    end

    local function buildProxies(leaving)
        local list = {}
        for index, player in ipairs(playerList(leaving)) do
            list[index] = proxyOf(player)
        end
        return list
    end

    -- A Player, a name, or a proxy -> the proxy of a player in the list, or nil.
    local function resolve(value, current)
        if type(value) == "table" and getmetatable(value) == proxyMeta then
            value = value.Player
        end
        if typeof(value) == "Instance" then
            for _, proxy in ipairs(current) do
                if proxy.Player == value then
                    return proxy
                end
            end
            return nil
        end
        if type(value) ~= "string" or value == "" then
            return nil
        end
        local lowered = string.lower(value)
        local loose = nil
        for _, proxy in ipairs(current) do
            local name = proxy.Player.Name
            if name == value then
                return proxy
            elseif not loose and string.lower(name) == lowered then
                loose = proxy
            end
        end
        return loose
    end

    local function resolveAll(value, current)
        local items
        if value == nil then
            items = {}
        elseif type(value) == "table" and getmetatable(value) ~= proxyMeta then
            items = value
        else
            items = { value }
        end
        local picked, seen = {}, {}
        for _, item in ipairs(items) do
            local proxy = resolve(item, current)
            if proxy and not seen[proxy] then
                seen[proxy] = true
                table.insert(picked, proxy)
            end
        end
        return picked
    end

    local function inGame(player)
        return typeof(player) == "Instance" and player.Parent == Players
    end

    -- Dropdown value (proxy or proxies) -> Player or Players still in game.
    local function toPlayers(value)
        if multi then
            local list = {}
            for _, proxy in ipairs(type(value) == "table" and value or {}) do
                if inGame(proxy.Player) then
                    table.insert(list, proxy.Player)
                end
            end
            return list
        end
        if type(value) == "table" and inGame(value.Player) then
            return value.Player
        end
        return nil
    end

    local initial = buildProxies()
    local default = nil
    if opts.Default ~= nil then
        local picked = resolveAll(opts.Default, initial)
        if multi then
            default = picked
        else
            default = picked[1]
        end
    end

    local dropdownOpts = {}
    for key, value in pairs(opts) do
        dropdownOpts[key] = value
    end
    -- Aliases are cleared so the dropdown can't map raw names back in.
    for _, key in ipairs({ "Flag", "Display", "IncludeSelf", "Avatars", "CurrentOption", "Value", "Values", "MultipleOptions" }) do
        dropdownOpts[key] = nil
    end
    dropdownOpts.Name = opts.Name or "Player"
    dropdownOpts.Multi = multi
    dropdownOpts.Options = initial
    -- A single pick goes in wrapped: the dropdown unwraps a table Default to
    -- its first item, and a proxy is itself a table.
    if multi then
        dropdownOpts.Default = default
    else
        dropdownOpts.Default = default and { default } or nil
    end
    -- Headshots next to each name; rbxthumb URLs need no yielding thumbnail call.
    if opts.Avatars ~= false then
        dropdownOpts.OptionIcon = function(proxy)
            local ok, userId = pcall(function()
                return proxy.Player.UserId
            end)
            if ok and type(userId) == "number" and userId > 0 then
                return ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(userId)
            end
            return nil
        end
    end
    -- Search finds a player by display name and username, whatever Display shows.
    dropdownOpts.OptionSearch = function(proxy)
        local ok, text = pcall(function()
            return proxy.Player.DisplayName .. " " .. proxy.Player.Name
        end)
        return ok and text or nil
    end
    dropdownOpts.EmptyText = opts.EmptyText or "No players"
    dropdownOpts.SearchPlaceholder = opts.SearchPlaceholder or "Search players"
    dropdownOpts.Callback = function(value)
        safeCall(userCallback, toPlayers(value))
    end

    local handle = self:Dropdown(dropdownOpts)
    local current = initial
    local baseSet, baseGet, baseRefresh = handle.Set, handle.Get, handle.Refresh

    function handle:Get()
        return toPlayers(baseGet(handle))
    end

    function handle:GetName()
        local value = handle:Get()
        if multi then
            local names = {}
            for index, player in ipairs(value) do
                names[index] = player.Name
            end
            return names
        end
        return value and value.Name or nil
    end
    handle.GetNames = handle.GetName

    -- Accepts a Player, a name, or a list of either. Names of players who
    -- aren't in the server are dropped.
    function handle:Set(value, silent)
        if handle._destroyed then
            return
        end
        local picked = resolveAll(value, current)
        if multi then
            baseSet(handle, picked, silent)
        else
            baseSet(handle, picked[1], silent)
        end
    end

    -- Configs store names, never Player instances.
    function handle:_saveValue()
        return handle:GetName()
    end

    -- Rebuilds the rows from the server. The callback runs if a pick left.
    local function rebuild(leaving, silent)
        if handle._destroyed then
            return
        end
        current = buildProxies(leaving)
        baseRefresh(handle, current, true, silent)
        if leaving then
            -- The dropdown keeps picks that left the list; drop the leaver's so the
            -- Player isn't held on to. Silent: the refresh already ran the callback.
            local picked = baseGet(handle)
            if multi then
                local kept = {}
                for _, proxy in ipairs(type(picked) == "table" and picked or {}) do
                    if proxy.Player ~= leaving then
                        table.insert(kept, proxy)
                    end
                end
                baseSet(handle, kept, true)
            elseif type(picked) == "table" and picked.Player == leaving then
                baseSet(handle, nil, true)
            end
            proxies[leaving] = nil
        end
    end

    function handle:Refresh()
        rebuild(nil, false)
    end
    function handle:SetOptions()
        rebuild(nil, false)
    end
    function handle:GetOptions()
        local list = {}
        for index, proxy in ipairs(current) do
            list[index] = proxy.Player
        end
        return list
    end

    local added = Players.PlayerAdded:Connect(function()
        rebuild(nil, true)
    end)
    local removing = Players.PlayerRemoving:Connect(function(player)
        rebuild(player, false)
    end)
    table.insert(handle._listeners, function()
        added:Disconnect()
        removing:Disconnect()
        if flag and Library.Flags[flag] == handle then
            Library.Flags[flag] = nil
        end
    end)

    -- Registered here rather than by the dropdown, so the default entry and
    -- any pending config value go through the name-based Get/Set above.
    if flag then
        Library.Flags[flag] = handle
        if window and type(window._flagCreated) == "function" then
            window:_flagCreated(flag, handle)
        end
    end
    return handle
end

Tab.CreatePlayerPicker = Tab.PlayerPicker

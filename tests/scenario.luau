--!nolint
-- Drives the demo like a player would and fails on any error or warning.
local H = HARNESS
local Library = H.Library
assert(Library, "library was not loaded by the demo")
local W = Library.Windows[#Library.Windows]
assert(W, "demo created no window")

local function phase(name)
    H.phase = name
    print("== " .. name)
end
local function step(seconds) H.run(seconds or 0.5) end

local function guis(root)
    local out = {}
    for _, d in ipairs(H.descendants(root)) do
        if d:IsA("GuiButton") then table.insert(out, d) end
    end
    return out
end
local function textOf(inst)
    local ok, t = pcall(function() return inst.Text end)
    return ok and t or ""
end
local function isDangerous(button)
    -- Buttons that end the session are clicked last, on purpose.
    local p = button
    for _ = 1, 4 do
        if not p then break end
        local t = string.lower(textOf(p))
        if t:find("unload") or t:find("rejoin") or t:find("hop") or t:find("lowest") or t:find("clear workspace") or t:find("reset all") then return true end
        p = p.Parent
    end
    if W.CloseButton and (button == W.CloseButton) then return true end
    return false
end

phase("intro")
step(8)

phase("home stats tick")
-- The home FPS/ping figures must keep changing.
local function homeTexts()
    local out = {}
    for _, d in ipairs(H.descendants(W.Gui)) do
        if d:IsA("TextLabel") then
            local t = textOf(d)
            if t:find("fps") or t:find("ms") then table.insert(out, t) end
        end
    end
    return table.concat(out, "|")
end
local before = homeTexts()
step(4)
local after = homeTexts()
if before == after then H.fail("home", "home FPS/ping text never changed: " .. before) end

phase("tabs")
for _, tab in ipairs(W.Tabs) do
    W:SelectTab(tab)
    step(0.6)
    for _, sub in ipairs(tab._subTabs or {}) do
        tab:SelectSubTab(sub)
        step(0.5)
    end
end

phase("minimize/restore")
W:Minimize()
step(2)
if not W.Minimized then H.fail("minimize", "Minimize() left the window unminimized") end
W:Restore()
step(2)
if W.Minimized then H.fail("restore", "Restore() left the window minimized") end
H.click(W.MinimizeButton)
step(2)
W:Restore()
step(1.5)
H.key("RightControl")
step(1)
H.key("RightControl")
step(1.5)
W:Minimize()
step(1)
W:SetMinimized(false)
step(1)

phase("click every button")
local clicked = {}
for round = 1, 4 do
    for _, tab in ipairs(W.Tabs) do
        W:SelectTab(tab)
        step(0.4)
        local pages = tab._subTabs and #tab._subTabs > 0 and tab._subTabs or { false }
        for _, sub in ipairs(pages) do
            if sub then tab:SelectSubTab(sub) step(0.3) end
            for _, button in ipairs(guis(W.Gui)) do
                if not clicked[button] and not isDangerous(button) and button.Parent then
                    clicked[button] = true
                    H.click(button)
                    H.step(1 / 30)
                    -- close dialogs a click may have opened
                    if W._dialog and round < 4 then
                        W._dialog.Close()
                    end
                end
            end
            step(0.3)
            W:_closePopups()
        end
    end
end
print("clicked", (function() local n = 0 for _ in pairs(clicked) do n += 1 end return n end)(), "buttons")
step(2)

phase("element handles")
local elements = {}
local function collect(page)
    for _, e in ipairs(page._items or {}) do table.insert(elements, e) end
    for _, g in ipairs(page._groupboxes or {}) do collect(g) end
end
for _, tab in ipairs(W.Tabs) do
    collect(tab)
    for _, sub in ipairs(tab._subTabs or {}) do collect(sub) end
end
print("elements:", #elements)
for _, e in ipairs(elements) do
    for _, call in ipairs({
        { "SetVisible", false }, { "SetVisible", true }, { "SetDisabled", true }, { "SetDisabled", false },
        { "SetTooltip", "tip" }, { "SetTooltip", nil }, { "IsVisible" }, { "GetTooltip" },
    }) do
        local fn = e[call[1]]
        if type(fn) == "function" then
            local ok, err = pcall(fn, e, call[2])
            if not ok then H.fail("element " .. tostring(e._type) .. ":" .. call[1], err) end
        end
    end
    H.step(1 / 30)
end
step(1)

phase("text boxes")
for _, d in ipairs(H.descendants(W.Gui)) do
    if d:IsA("TextBox") and d.Parent then
        H.type(d, "12", true)
        H.type(d, "hello world", true)
        H.type(d, "", false)
    end
end
step(1)

phase("search")
if W.SearchBox then
    for _, q in ipairs({ "auto", "a", "zzzzz", "speed", "" }) do
        W.SearchBox:CaptureFocus()
        W.SearchBox.Text = q
        step(0.3)
    end
    W.SearchBox:ReleaseFocus(false)
end
step(0.5)

phase("flags round trip")
for flag, element in pairs(Library.Flags) do
    if type(element.Get) == "function" and type(element.Set) == "function" then
        local ok, value = pcall(element.Get, element)
        if not ok then H.fail("flag get " .. flag, value) else
            local ok2, err = pcall(element.Set, element, value, true)
            if not ok2 then H.fail("flag set " .. flag, err) end
        end
    end
end
step(1)

phase("configs")
local function check(label, ok, err) if not ok then H.fail(label, err) end end
check("SaveConfig", W:SaveConfig("Alpha"))
check("SaveConfig2", W:SaveConfig("beta"))
check("LoadConfig", W:LoadConfig("Alpha"))
local code = W:ExportConfig()
if type(code) ~= "string" then H.fail("ExportConfig", tostring(code)) else
    check("ImportConfig", W:ImportConfig(code, "Gamma"))
end
check("RenameConfig", W:RenameConfig("beta", "Beta2"))
check("SetAutoload", W:SetAutoload("Alpha"))
check("DeleteConfig", W:DeleteConfig("Alpha"))
if W:GetAutoload() ~= nil then H.fail("autoload", "deleted config still autoloads") end
local list = W:ListConfigs()
print("configs:", table.concat(list, ","))
step(1)

phase("themes")
-- Theme colours bind by value, so two keys with one colour in a preset would
-- bind objects to the wrong key.
for name, preset in pairs(Library.ThemePresets) do
    local seen = {}
    for key, color in pairs(preset) do
        local id = color:ToHex()
        if seen[id] then H.fail("theme " .. name, key .. " and " .. seen[id] .. " share the colour #" .. id) end
        seen[id] = key
    end
end
for name in pairs(Library.ThemePresets) do
    Library:SetTheme(name)
    step(0.4)
end
Library:SetTheme("KaitUI")
check("SaveTheme", W:SaveTheme("Mine"))
check("LoadTheme", W:LoadTheme("Mine"))
step(1)

phase("performance mode")
Library:SetPerformanceMode(true)
for _, tab in ipairs(W.Tabs) do W:SelectTab(tab) step(0.3) end
W:Minimize() step(1) W:Restore() step(1)
Library:SetPerformanceMode(false)
step(1)

phase("players")
local p = H.addPlayer("Joiner", 3003)
step(1)
H.removePlayer(p)
step(1)

phase("notifications")
local n = Library:Notify({ Title = "T", Content = "C", Buttons = { { Title = "OK" } }, Progress = 0 })
n:SetProgress(0.5) n:SetContent("x") n:SetContent("") n:SetTitle("y")
step(1)
n:Close()
Library:Notify({ Title = "Forever", Duration = math.huge })
step(1)

phase("overlays")
local wm = W:CreateWatermark({ Position = "TopRight" })
local kl = W:CreateKeybindList({ ShowAll = true })
step(2)
wm:SetFields({ "FPS", "Ping", "Time", function() return "x" end })
kl:SetShowAll(false)
step(1)

phase("resize screen")
H.VIEWPORT = Vector2.new(800, 600)
step(1)

phase("dangerous buttons")
-- Server buttons and unload last.
W:Rejoin()
step(1)

phase("toggles before close")
local onBefore = 0
for _, t in ipairs(W._toggles or {}) do if t.Value == true then onBefore += 1 end end
print("toggles on before close:", onBefore)

phase("close")
W:Close()
step(0.5)
if not W._dialog then H.fail("close", "the close button asked nothing") else
    -- confirm it: the button whose own text, or a label inside it, says Close
    local confirmed = false
    for _, b in ipairs(guis(W.Gui)) do
        local label = string.lower(textOf(b))
        for _, d in ipairs(H.descendants(b)) do
            if d:IsA("TextLabel") then label = label .. string.lower(textOf(d)) end
        end
        if label == "close" and not confirmed then
            confirmed = true
            H.click(b)
        end
    end
    if not confirmed then H.fail("close", "no Close button in the confirm dialog") end
end
step(3)
if not W._destroyed then H.fail("close", "window not destroyed after confirming close") end
step(2)
for _, t in ipairs(W._toggles or {}) do
    if t.Value == true and not t._destroyed then H.fail("close", "toggle still on after close: " .. tostring(t._searchName)) end
end
if W.Gui.Parent ~= nil then H.fail("close", "ScreenGui still parented after close") end

phase("done")
local unknown = {}
for k in pairs(H.Unknown) do table.insert(unknown, k) end
table.sort(unknown)
if #unknown > 0 then print("unknown members read (some may be swallowed by pcall): " .. table.concat(unknown, ", ")) end

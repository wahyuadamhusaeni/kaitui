-- Boundary cases that previously escaped the interaction smoke tests.
local KaitUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/wahyuadamhusaeni/kaitui/refs/heads/main/dist/KaitUI.luau"))()
local Window = KaitUI:CreateWindow({
    Name = "Regression tests",
    ConfigurationSaving = { Enabled = true, FolderName = "RegressionTests" },
})
local Tab = Window:CreateTab({ Name = "Regressions" })

local function check(name, test)
    local ok, err = pcall(test)
    if not ok then HARNESS.fail(name, err) end
end

check("numeric input rejects suffix overflow", function()
    local input = Tab:CreateInput({ Name = "Amount", Numeric = true, Default = "42" })
    input:Set("1e308k")
    assert(input:Get() == 42, "overflowing amount replaced the last valid value")
    input:Set("2.5k")
    assert(input:Get() == 2500, "valid suffix stopped working")
    input:Destroy()
end)

check("numeric input clear callback matches Get", function()
    local calls, received = 0, "unset"
    local input = Tab:CreateInput({ Name = "Clear amount", Numeric = true, Default = "42", Callback = function(value)
        calls += 1
        received = value
    end })
    input:Set("")
    assert(input:Get() == nil, "empty numeric input should have no value")
    assert(calls == 1 and received == nil, "clear callback received text instead of nil")
    input:Destroy()
end)

check("segmented keeps pending value across intermediate refreshes", function()
    local control = Tab:CreateSegmented({ Name = "Late options", Options = { "A" } })
    control:Set("C")
    control:SetOptions({ "A", "B" })
    control:SetOptions({ "A", "B", "C" })
    assert(control:Get() == "C", "intermediate options discarded the pending selection")
    control:Destroy()
end)

check("segmented reports removal of final option", function()
    local calls, received = 0, "unset"
    local control = Tab:CreateSegmented({ Name = "Empty options", Options = { "A" }, Callback = function(value)
        calls += 1
        received = value
    end })
    control:SetOptions({})
    assert(control:Get() == nil, "empty options should clear the selection")
    assert(calls == 1 and received == nil, "clearing options did not notify the script")
    control:SetOptions({ "B" }, true)
    assert(calls == 1 and control:Get() == "B", "silent refresh called the callback")
    control:Destroy()
end)

check("progress rejects NaN before rendering or callback", function()
    local received
    local control = Tab:CreateProgress({ Name = "Invalid progress", Default = 0.5, Callback = function(value)
        received = value
    end })
    control:Set(0 / 0)
    assert(control:Get() == 0, "NaN was stored as the progress fraction")
    assert(received == 0, "NaN reached the progress callback")
    control:Set(2)
    assert(control:Get() == 1, "finite progress no longer clamps to the maximum")
    control:Destroy()
end)

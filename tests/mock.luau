--!nolint
-- Headless mock of the Roblox client API, enough to run KaitUI and its demo in
-- the luau CLI. Records every error and warning so a scenario can assert none.

local realos = os
local realtypeof = typeof
local rawtype = type
local realprint = print

local H = { VT = 0, Errors = {}, Warnings = {}, Unknown = {} }
HARNESS = H

os = setmetatable({
    clock = function() return H.VT end,
    time = function() return 1760000000 + math.floor(H.VT) end,
}, { __index = realos })
tick = function() return 1760000000 + H.VT end
time = function() return H.VT end
elapsedTime = time

local function fail(kind, message)
    table.insert(H.Errors, kind .. ": " .. tostring(message))
    realprint("[ERROR] " .. kind .. ": " .. tostring(message))
end
H.fail = fail

warn = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    local text = table.concat(parts, " ")
    table.insert(H.Warnings, text)
    realprint("[warn] " .. text)
end
print = function(...)
    if H.Quiet then return end
    realprint(...)
end

typeof = function(value)
    if rawtype(value) == "table" then
        local mt = getmetatable(value)
        if rawtype(mt) == "table" and rawget(mt, "__type") then
            return rawget(mt, "__type")
        end
    end
    return realtypeof(value)
end

---------------------------------------------------------------------------
-- Scheduler
---------------------------------------------------------------------------
local sleepers = {}   -- { thread, wake, args }
local deferred = {}
local function resume(thread, ...)
    if coroutine.status(thread) == "dead" then return end
    local ok, err = coroutine.resume(thread, ...)
    if not ok then
        fail("thread", debug.traceback(thread, tostring(err)))
    end
end
H.resume = resume

task = {}
function task.spawn(fn, ...)
    local thread = rawtype(fn) == "thread" and fn or coroutine.create(fn)
    resume(thread, ...)
    return thread
end
function task.defer(fn, ...)
    local thread = rawtype(fn) == "thread" and fn or coroutine.create(fn)
    table.insert(deferred, { thread, table.pack(...) })
    return thread
end
function task.delay(seconds, fn, ...)
    local thread = rawtype(fn) == "thread" and fn or coroutine.create(fn)
    table.insert(sleepers, { thread = thread, wake = H.VT + (tonumber(seconds) or 0), args = table.pack(...) })
    return thread
end
function task.wait(seconds)
    local thread = coroutine.running()
    local start = H.VT
    table.insert(sleepers, { thread = thread, wake = H.VT + math.max(tonumber(seconds) or 0, 1 / 60), args = nil, start = start })
    coroutine.yield()
    return H.VT - start
end
function task.cancel(thread)
    for i = #sleepers, 1, -1 do
        if sleepers[i].thread == thread then table.remove(sleepers, i) end
    end
    for i = #deferred, 1, -1 do
        if deferred[i][1] == thread then table.remove(deferred, i) end
    end
    pcall(coroutine.close, thread)
end
function task.synchronize() end
function task.desynchronize() end
wait = function(s) return task.wait(s) end
spawn = function(f) return task.defer(f) end
delay = function(s, f) return task.delay(s, f) end

local function runDeferred()
    local guard = 0
    while #deferred > 0 do
        guard += 1
        if guard > 100000 then fail("scheduler", "deferred loop runaway") return end
        local item = table.remove(deferred, 1)
        resume(item[1], table.unpack(item[2], 1, item[2].n))
    end
end
H.runDeferred = runDeferred

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"
local Connection = { __type = "RBXScriptConnection" }
Connection.__index = Connection
function Connection:Disconnect()
    self.Connected = false
    local list = self._signal._handlers
    for i, c in ipairs(list) do
        if c == self then table.remove(list, i) break end
    end
end
local function newSignal(name)
    return setmetatable({ _handlers = {}, _name = name }, Signal)
end
function Signal:Connect(fn)
    if rawtype(fn) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
    local c = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
    table.insert(self._handlers, c)
    return c
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
    local c
    c = self:Connect(function(...)
        c:Disconnect()
        fn(...)
    end)
    return c
end
function Signal:Wait()
    local thread = coroutine.running()
    local c
    c = self:Connect(function(...)
        c:Disconnect()
        resume(thread, ...)
    end)
    return coroutine.yield()
end
function Signal:Fire(...)
    for _, c in ipairs(table.clone(self._handlers)) do
        if c.Connected then
            resume(coroutine.create(c._fn), ...)
        end
    end
end
H.newSignal = newSignal

---------------------------------------------------------------------------
-- Datatypes
---------------------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end

Vector2 = {}
local V2 = { __type = "Vector2" }
local V2m = {}
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y)
    elseif k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y); return m > 0 and v2(t.X / m, t.Y / m) or v2(0, 0)
    elseif k == "x" then return t.X elseif k == "y" then return t.Y end
    local m = V2m[k]
    if m then return m end
    error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
    if rawtype(a) == "number" then return v2(a * b.X, a * b.Y) end
    if rawtype(b) == "number" then return v2(a.X * b, a.Y * b) end
    return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
    if rawtype(b) == "number" then return v2(a.X / b, a.Y / b) end
    return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a) return v2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(a) return a.X .. ", " .. a.Y end
function V2m.Lerp(a, b, t) return v2(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t)) end
function V2m.Max(a, b) return v2(math.max(a.X, b.X), math.max(a.Y, b.Y)) end
function V2m.Min(a, b) return v2(math.min(a.X, b.X), math.min(a.Y, b.Y)) end
function V2m.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2m.Abs(a) return v2(math.abs(a.X), math.abs(a.Y)) end
function V2m.Floor(a) return v2(math.floor(a.X), math.floor(a.Y)) end
Vector2.new = function(x, y) return v2(tonumber(x) or 0, tonumber(y) or 0) end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
Vector2.xAxis = v2(1, 0)
Vector2.yAxis = v2(0, 1)

Vector3 = {}
local V3 = { __type = "Vector3" }
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
    error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.new = function(x, y, z) return v3(x or 0, y or 0, z or 0) end
Vector3.zero = v3()

UDim = {}
local UD = { __type = "UDim" }
local function udim(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end
UD.__index = function(_, k) error(tostring(k) .. " is not a valid member of UDim", 2) end
UD.__add = function(a, b) return udim(a.Scale + b.Scale, a.Offset + b.Offset) end
UD.__sub = function(a, b) return udim(a.Scale - b.Scale, a.Offset - b.Offset) end
UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UD.__tostring = function(a) return a.Scale .. ", " .. a.Offset end
UDim.new = function(s, o) return udim(tonumber(s) or 0, tonumber(o) or 0) end

UDim2 = {}
local UD2 = { __type = "UDim2" }
local UD2m = {}
local function udim2(xs, xo, ys, yo) return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2) end
UD2.__index = function(t, k)
    if k == "Width" then return t.X elseif k == "Height" then return t.Y end
    local m = UD2m[k]
    if m then return m end
    error(tostring(k) .. " is not a valid member of UDim2", 2)
end
UD2.__add = function(a, b) return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UD2.__sub = function(a, b) return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UD2.__tostring = function(a) return "{" .. tostring(a.X) .. "}, {" .. tostring(a.Y) .. "}" end
function UD2m.Lerp(a, b, t)
    return udim2(lerp(a.X.Scale, b.X.Scale, t), lerp(a.X.Offset, b.X.Offset, t), lerp(a.Y.Scale, b.Y.Scale, t), lerp(a.Y.Offset, b.Y.Offset, t))
end
local function num(v, name)
    if v ~= nil and rawtype(v) ~= "number" then
        error("invalid argument to UDim2 (" .. name .. "): number expected, got " .. typeof(v), 3)
    end
    return v or 0
end
UDim2.new = function(a, b, c, d)
    if typeof(a) == "UDim" then return udim2(a.Scale, a.Offset, b.Scale, b.Offset) end
    return udim2(num(a, "1"), num(b, "2"), num(c, "3"), num(d, "4"))
end
UDim2.fromOffset = function(x, y) return udim2(0, num(x, "x"), 0, num(y, "y")) end
UDim2.fromScale = function(x, y) return udim2(num(x, "x"), 0, num(y, "y"), 0) end

Color3 = {}
local C3 = { __type = "Color3" }
local C3m = {}
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
C3.__index = function(t, k)
    if k == "r" then return t.R elseif k == "g" then return t.G elseif k == "b" then return t.B end
    local m = C3m[k]
    if m then return m end
    error(tostring(k) .. " is not a valid member of Color3", 2)
end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(a) return a.R .. ", " .. a.G .. ", " .. a.B end
function C3m.Lerp(a, b, t)
    if typeof(b) ~= "Color3" then error("Color3:Lerp expects a Color3", 2) end
    return c3(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end
function C3m.ToHex(a)
    return string.format("%02x%02x%02x", math.floor(math.clamp(a.R, 0, 1) * 255 + 0.5), math.floor(math.clamp(a.G, 0, 1) * 255 + 0.5), math.floor(math.clamp(a.B, 0, 1) * 255 + 0.5))
end
function C3m.ToHSV(c)
    local r, g, b = c.R, c.G, c.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, max
    local d = max - min
    s = max == 0 and 0 or d / max
    if d ~= 0 then
        if max == r then h = (g - b) / d % 6 elseif max == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end
Color3.new = function(r, g, b) return c3(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0) end
Color3.toHSV = function(c) return C3m.ToHSV(c) end
Color3.fromRGB = function(r, g, b) return c3((tonumber(r) or 0) / 255, (tonumber(g) or 0) / 255, (tonumber(b) or 0) / 255) end
Color3.fromHSV = function(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
    elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
end
Color3.fromHex = function(hex)
    hex = tostring(hex):gsub("#", "")
    if #hex ~= 6 then error("Unable to convert characters to hex value", 2) end
    return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
end

local function simple(typeName, ctor)
    local mt = { __type = typeName }
    mt.__index = mt
    return mt, function(...) return setmetatable(ctor(...), mt) end
end
local _, csk = simple("ColorSequenceKeypoint", function(t, c) return { Time = t, Value = c } end)
ColorSequenceKeypoint = { new = csk }
local _, cs = simple("ColorSequence", function(a, b)
    if rawtype(a) == "table" and typeof(a) ~= "Color3" then return { Keypoints = a } end
    return { Keypoints = { csk(0, a), csk(1, b or a) } }
end)
ColorSequence = { new = cs }
local _, nsk = simple("NumberSequenceKeypoint", function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end)
NumberSequenceKeypoint = { new = nsk }
local _, ns = simple("NumberSequence", function(a, b)
    if rawtype(a) == "table" then return { Keypoints = a } end
    return { Keypoints = { nsk(0, a), nsk(1, b or a) } }
end)
NumberSequence = { new = ns }
local _, nr = simple("NumberRange", function(a, b) return { Min = a, Max = b or a } end)
NumberRange = { new = nr }
local _, rect = simple("Rect", function(a, b, c, d)
    if typeof(a) == "Vector2" then return { Min = a, Max = b, Width = b.X - a.X, Height = b.Y - a.Y } end
    return { Min = v2(a, b), Max = v2(c, d), Width = (c or 0) - (a or 0), Height = (d or 0) - (b or 0) }
end)
Rect = { new = rect }
local _, ti = simple("TweenInfo", function(t, s, d, r, rev, delay)
    return { Time = t or 1, EasingStyle = s, EasingDirection = d, RepeatCount = r or 0, Reverses = rev or false, DelayTime = delay or 0 }
end)
TweenInfo = { new = ti }
local FontMt, newFont = simple("Font", function(family, weight, style)
    return { Family = family, Weight = weight, Style = style, Bold = false }
end)
Font = {
    new = function(family, weight, style)
        if rawtype(family) ~= "string" then error("Font.new expects a string family", 2) end
        return newFont(family, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
    end,
    fromEnum = function(e) return newFont("rbxasset://fonts/families/" .. tostring(e and e.Name) .. ".json", Enum.FontWeight.Regular, Enum.FontStyle.Normal) end,
    fromName = function(n, w, s) return newFont("rbxasset://fonts/families/" .. n .. ".json", w, s) end,
    fromId = function(id, w, s) return newFont("rbxassetid://" .. id, w, s) end,
}
local RandomMt = { __type = "Random" }
RandomMt.__index = RandomMt
function RandomMt:NextNumber(a, b) a, b = a or 0, b or 1; return a + math.random() * (b - a) end
function RandomMt:NextInteger(a, b) return math.random(a, b) end
Random = { new = function() return setmetatable({}, RandomMt) end }

DateTime = { now = function() return { UnixTimestamp = 1760000000 + math.floor(H.VT), UnixTimestampMillis = (1760000000 + H.VT) * 1000, FormatLocalTime = function() return "12:00" end } end }

---------------------------------------------------------------------------
-- Enum
---------------------------------------------------------------------------
local EnumItemMt = { __type = "EnumItem" }
EnumItemMt.__index = function(t, k)
    if k == "IsA" then return function(self, n) return rawget(self, "EnumType").Name == n end end
    error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
EnumItemMt.__tostring = function(t) return "Enum." .. tostring(rawget(t, "TypeName")) .. "." .. rawget(t, "Name") end
local KEYS = {}
for _, n in ipairs({ "Unknown", "Backspace", "Tab", "Clear", "Return", "Pause", "Escape", "Space", "QuotedDouble", "Hash", "Dollar", "Percent", "Ampersand", "Quote", "LeftParenthesis", "RightParenthesis", "Asterisk", "Plus", "Comma", "Minus", "Period", "Slash",
    "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Colon", "Semicolon", "LessThan", "Equals", "GreaterThan", "Question", "At", "LeftBracket", "BackSlash", "RightBracket", "Caret", "Underscore", "Backquote",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "LeftCurly", "Pipe", "RightCurly", "Tilde", "Delete",
    "KeypadZero", "KeypadOne", "KeypadTwo", "KeypadThree", "KeypadFour", "KeypadFive", "KeypadSix", "KeypadSeven", "KeypadEight", "KeypadNine", "KeypadPeriod", "KeypadDivide", "KeypadMultiply", "KeypadMinus", "KeypadPlus", "KeypadEnter", "KeypadEquals",
    "Up", "Down", "Right", "Left", "Insert", "Home", "End", "PageUp", "PageDown", "LeftShift", "RightShift", "LeftMeta", "RightMeta", "LeftAlt", "RightAlt", "LeftControl", "RightControl", "CapsLock", "NumLock", "ScrollLock", "LeftSuper", "RightSuper",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "Print", "Menu", "ButtonA", "ButtonB", "ButtonX", "ButtonY", "ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2", "ButtonStart", "ButtonSelect", "DPadUp", "DPadDown", "DPadLeft", "DPadRight", "Thumbstick1", "Thumbstick2" }) do
    KEYS[n] = true
end
local enumTypes = {}
local function enumType(typeName)
    local et = enumTypes[typeName]
    if et then return et end
    local items, list, count = {}, {}, 0
    et = setmetatable({}, {
        __type = "Enum",
        __index = function(_, name)
            if name == "GetEnumItems" then
                return function()
                    if typeName == "KeyCode" then
                        local out = {}
                        for n in pairs(KEYS) do table.insert(out, et[n]) end
                        return out
                    end
                    return table.clone(list)
                end
            end
            if rawtype(name) ~= "string" then error(tostring(name) .. " is not a valid member of \"Enum." .. typeName .. "\"", 2) end
            if typeName == "KeyCode" and not KEYS[name] then
                error(name .. " is not a valid member of \"Enum.KeyCode\"", 2)
            end
            local item = items[name]
            if not item then
                count += 1
                item = setmetatable({ Name = name, Value = count, EnumType = nil, TypeName = typeName }, EnumItemMt)
                items[name] = item
                table.insert(list, item)
            end
            return item
        end,
    })
    enumTypes[typeName] = et
    return et
end
-- items need EnumType set after creation
local oldEnumType = enumType
enumType = function(typeName)
    local et = oldEnumType(typeName)
    return et
end
Enum = setmetatable({}, { __index = function(_, k) return enumType(k) end })
-- patch EnumType field lazily
EnumItemMt.__index = function(t, k)
    if k == "EnumType" then return nil end
    if k == "IsA" then return function() return true end end
    error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
do
    local base = getmetatable(Enum).__index
    getmetatable(Enum).__index = function(_, typeName)
        local et = base(_, typeName)
        local mt = getmetatable(et)
        if not mt.__patched then
            local inner = mt.__index
            mt.__index = function(t, name)
                local item = inner(t, name)
                if rawtype(item) == "table" and getmetatable(item) == EnumItemMt and rawget(item, "EnumType") == nil then
                    rawset(item, "EnumType", et)
                end
                return item
            end
            mt.__patched = true
        end
        return et
    end
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local PARENT_OF = {
    Instance = nil, GuiBase = "Instance", GuiBase2d = "GuiBase", GuiObject = "GuiBase2d", LayerCollector = "GuiBase2d",
    ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector",
    Frame = "GuiObject", ScrollingFrame = "GuiObject", CanvasGroup = "GuiObject", ViewportFrame = "GuiObject",
    TextLabel = "GuiObject", ImageLabel = "GuiObject", GuiButton = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", TextBox = "GuiObject", VideoFrame = "GuiObject",
    UIBase = "Instance", UIComponent = "UIBase", UICorner = "UIComponent", UIStroke = "UIComponent", UIPadding = "UIComponent", UIScale = "UIComponent", UIGradient = "UIComponent",
    UIConstraint = "UIComponent", UISizeConstraint = "UIConstraint", UITextSizeConstraint = "UIConstraint", UIAspectRatioConstraint = "UIConstraint",
    UILayout = "UIComponent", UIGridStyleLayout = "UILayout", UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout", UIPageLayout = "UIGridStyleLayout", UITableLayout = "UIGridStyleLayout", UIFlexItem = "UIComponent",
    Folder = "Instance", Player = "Instance", Players = "Instance", Camera = "Instance", Workspace = "Instance", Sound = "Instance", Configuration = "Instance",
    ValueBase = "Instance", StringValue = "ValueBase", BoolValue = "ValueBase", NumberValue = "ValueBase", ObjectValue = "ValueBase", BindableEvent = "Instance", RemoteEvent = "Instance",
    CoreGui = "Instance", PlayerGui = "Instance", Model = "Instance", Part = "Instance", Humanoid = "Instance", LocalScript = "Instance", ModuleScript = "Instance",
}
local function isA(className, wanted)
    local c = className
    while c do
        if c == wanted then return true end
        c = PARENT_OF[c]
    end
    return wanted == "Instance"
end

local EVENTS = {}
for _, n in ipairs({ "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "AttributeChanged",
    "InputBegan", "InputChanged", "InputEnded", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward", "SelectionGained", "SelectionLost", "TouchTap", "TouchLongPress", "TouchPan", "TouchSwipe",
    "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up", "Activated",
    "Focused", "FocusLost", "ReturnPressedFromOnScreenKeyboard", "CharacterAdded", "CharacterRemoving", "Chatted", "Idled", "PlayerAdded", "PlayerRemoving" }) do
    EVENTS[n] = true
end

local Instance_ = {}
local InstMt = { __type = "Instance" }
local allInstances = setmetatable({}, { __mode = "k" })

local function defaults(className)
    local d = { Name = className, Archivable = true }
    if isA(className, "GuiObject") then
        d.Visible = true; d.Size = udim2(0, 100, 0, 100); d.Position = udim2(0, 0, 0, 0); d.AnchorPoint = v2(0, 0)
        d.BackgroundTransparency = 0; d.BackgroundColor3 = c3(163 / 255, 162 / 255, 165 / 255); d.BorderSizePixel = 1; d.BorderColor3 = c3(0, 0, 0)
        d.ZIndex = 1; d.LayoutOrder = 0; d.Rotation = 0; d.ClipsDescendants = false; d.Active = false; d.Selectable = false
        d.AutomaticSize = Enum.AutomaticSize.None; d.SizeConstraint = Enum.SizeConstraint.RelativeXY; d.Interactable = true
    end
    if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
        d.Text = className == "TextBox" and "" or (className == "TextButton" and "Button" or "Label"); d.TextSize = 14; d.TextColor3 = c3(0, 0, 0); d.TextTransparency = 0
        d.RichText = false; d.TextWrapped = false; d.TextScaled = false; d.FontFace = newFont("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        d.Font = Enum.Font.SourceSans; d.TextXAlignment = Enum.TextXAlignment.Center; d.TextYAlignment = Enum.TextYAlignment.Center; d.TextTruncate = Enum.TextTruncate.None
        d.LineHeight = 1; d.TextStrokeTransparency = 1; d.MaxVisibleGraphemes = -1
    end
    if className == "TextBox" then
        d.PlaceholderText = ""; d.PlaceholderColor3 = c3(0.7, 0.7, 0.7); d.ClearTextOnFocus = true; d.MultiLine = false; d.CursorPosition = -1; d.SelectionStart = -1; d.TextEditable = true
    end
    if className == "ImageLabel" or className == "ImageButton" then
        d.Image = ""; d.ImageColor3 = c3(1, 1, 1); d.ImageTransparency = 0; d.ImageRectOffset = v2(0, 0); d.ImageRectSize = v2(0, 0)
        d.IsLoaded = true; d.ScaleType = Enum.ScaleType.Stretch; d.SliceCenter = rect(0, 0, 0, 0); d.SliceScale = 1; d.ResampleMode = Enum.ResamplerMode.Default; d.TileSize = udim2(1, 0, 1, 0)
    end
    if isA(className, "GuiButton") then d.AutoButtonColor = true; d.Modal = false; d.Selected = false end
    if className == "ScrollingFrame" then
        d.CanvasSize = udim2(0, 0, 2, 0); d.CanvasPosition = v2(0, 0); d.ScrollBarThickness = 12; d.ScrollingEnabled = true; d.AutomaticCanvasSize = Enum.AutomaticSize.None
        d.ScrollingDirection = Enum.ScrollingDirection.XY; d.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable; d.ScrollBarImageColor3 = c3(1, 1, 1); d.ScrollBarImageTransparency = 0
        d.VerticalScrollBarInset = Enum.ScrollBarInset.None; d.TopImage = ""; d.MidImage = ""; d.BottomImage = ""
    end
    if className == "CanvasGroup" then d.GroupTransparency = 0; d.GroupColor3 = c3(1, 1, 1) end
    if className == "ScreenGui" then d.Enabled = true; d.IgnoreGuiInset = false; d.ResetOnSpawn = true; d.DisplayOrder = 0; d.ZIndexBehavior = Enum.ZIndexBehavior.Global; d.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end
    if className == "UICorner" then d.CornerRadius = udim(0, 8) end
    if className == "UIStroke" then d.Color = c3(0, 0, 0); d.Thickness = 1; d.Transparency = 0; d.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; d.LineJoinMode = Enum.LineJoinMode.Round; d.Enabled = true end
    if className == "UIPadding" then d.PaddingTop = udim(0, 0); d.PaddingBottom = udim(0, 0); d.PaddingLeft = udim(0, 0); d.PaddingRight = udim(0, 0) end
    if className == "UIScale" then d.Scale = 1 end
    if className == "UIGradient" then d.Rotation = 0; d.Offset = v2(0, 0); d.Enabled = true; d.Color = cs(c3(1, 1, 1)); d.Transparency = ns(0) end
    if className == "UIListLayout" or className == "UIGridLayout" then
        d.Padding = udim(0, 0); d.SortOrder = Enum.SortOrder.Name; d.FillDirection = Enum.FillDirection.Vertical; d.HorizontalAlignment = Enum.HorizontalAlignment.Left; d.VerticalAlignment = Enum.VerticalAlignment.Top
        d.CellPadding = udim2(0, 5, 0, 5); d.CellSize = udim2(0, 100, 0, 100); d.Wraps = false; d.HorizontalFlex = Enum.UIFlexAlignment.None; d.VerticalFlex = Enum.UIFlexAlignment.None
    end
    if className == "UISizeConstraint" then d.MinSize = v2(0, 0); d.MaxSize = v2(math.huge, math.huge) end
    if className == "UIAspectRatioConstraint" then d.AspectRatio = 1 end
    if className == "UITextSizeConstraint" then d.MaxTextSize = 100; d.MinTextSize = 1 end
    if className == "Folder" or className == "Configuration" then end
    return d
end

local VIEWPORT = v2(1366, 768)
H.VIEWPORT = VIEWPORT

local function stripRich(text)
    return (tostring(text):gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
local function textBounds(inst)
    local p = inst._props
    local text = p.Text or ""
    if p.RichText then text = stripRich(text) end
    if text == "" then return v2(0, 0) end
    local size = p.TextSize or 14
    local lines = 1
    for _ in text:gmatch("\n") do lines += 1 end
    local longest = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do longest = math.max(longest, utf8.len(line) or #line) end
    return v2(math.floor(longest * size * 0.5 + 0.5), math.floor(size * 1.2 * lines + 0.5))
end

local absSize, absPos
local function parentFrame(inst)
    local parent = inst._parent
    while parent and not (isA(parent.ClassName, "GuiBase2d")) do
        parent = parent._parent
    end
    return parent
end
local function padOf(inst)
    for _, child in ipairs(inst._children) do
        if child.ClassName == "UIPadding" then
            local p = child._props
            return p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom
        end
    end
    return nil
end
absSize = function(inst, depth)
    depth = (depth or 0) + 1
    if depth > 80 then return v2(0, 0) end
    if inst.ClassName == "ScreenGui" then return VIEWPORT end
    if not isA(inst.ClassName, "GuiObject") then return v2(0, 0) end
    local parent = parentFrame(inst)
    local ps = parent and absSize(parent, depth) or VIEWPORT
    if parent then
        local l, r, t, b = padOf(parent)
        if l then
            ps = v2(ps.X - (l.Scale * ps.X + l.Offset) - (r.Scale * ps.X + r.Offset), ps.Y - (t.Scale * ps.Y + t.Offset) - (b.Scale * ps.Y + b.Offset))
        end
    end
    local s = inst._props.Size
    local x, y = s.X.Scale * ps.X + s.X.Offset, s.Y.Scale * ps.Y + s.Y.Offset
    local auto = inst._props.AutomaticSize
    if auto and auto.Name ~= "None" then
        local bx, by = 0, 0
        if inst._props.Text ~= nil then
            local tb = textBounds(inst)
            bx, by = tb.X, tb.Y
        end
        for _, child in ipairs(inst._children) do
            if isA(child.ClassName, "GuiObject") and child._props.Visible then
                local cs_ = child._props.Size
                bx = math.max(bx, cs_.X.Offset)
                by = by + math.max(cs_.Y.Offset, 0)
            end
        end
        if auto.Name == "X" or auto.Name == "XY" then x = math.max(x, bx) end
        if auto.Name == "Y" or auto.Name == "XY" then y = math.max(y, by) end
    end
    return v2(math.max(x, 0), math.max(y, 0))
end
absPos = function(inst, depth)
    depth = (depth or 0) + 1
    if depth > 80 then return v2(0, 0) end
    if inst.ClassName == "ScreenGui" or not isA(inst.ClassName, "GuiObject") then return v2(0, 0) end
    local parent = parentFrame(inst)
    local pp = parent and absPos(parent, depth) or v2(0, 0)
    local ps = parent and absSize(parent, depth) or VIEWPORT
    local p = inst._props.Position
    local me = absSize(inst, depth)
    local a = inst._props.AnchorPoint
    local off = v2(0, 0)
    if parent and parent.ClassName == "ScrollingFrame" then off = parent._props.CanvasPosition end
    return v2(pp.X + p.X.Scale * ps.X + p.X.Offset - a.X * me.X - off.X, pp.Y + p.Y.Scale * ps.Y + p.Y.Offset - a.Y * me.Y - off.Y)
end
H.absSize, H.absPos = absSize, absPos

local METHODS = {}
local function inst_new(className, parent)
    local self = setmetatable({ ClassName = className, _props = defaults(className), _children = {}, _events = {}, _attrs = {}, _propSignals = {}, _attrSignals = {}, _destroyed = false, _parent = nil }, InstMt)
    allInstances[self] = true
    if parent ~= nil then self.Parent = parent end
    return self
end
H.newInstance = inst_new

local function fireEvent(inst, name, ...)
    local s = rawget(inst, "_events")[name]
    if s then s:Fire(...) end
end
H.fireEvent = fireEvent

local COMPUTED = {
    AbsoluteSize = function(i) return absSize(i) end,
    AbsolutePosition = function(i) return absPos(i) end,
    AbsoluteRotation = function(i) return i._props.Rotation or 0 end,
    TextBounds = function(i) return textBounds(i) end,
    TextFits = function() return true end,
    AbsoluteContentSize = function(i)
        local parent = i._parent
        if not parent then return v2(0, 0) end
        local horizontal = i._props.FillDirection and i._props.FillDirection.Name == "Horizontal"
        local total, cross = 0, 0
        local count = 0
        for _, child in ipairs(parent._children) do
            if isA(child.ClassName, "GuiObject") and child._props.Visible then
                local s = absSize(child)
                count += 1
                if horizontal then total += s.X; cross = math.max(cross, s.Y) else total += s.Y; cross = math.max(cross, s.X) end
            end
        end
        local pad = (i._props.Padding and i._props.Padding.Offset or 0) * math.max(count - 1, 0)
        return horizontal and v2(total + pad, cross) or v2(cross, total + pad)
    end,
    AbsoluteCanvasSize = function(i)
        local s = i._props.CanvasSize
        local me = absSize(i)
        return v2(s.X.Scale * me.X + s.X.Offset, s.Y.Scale * me.Y + s.Y.Offset)
    end,
    AbsoluteWindowSize = function(i) return absSize(i) end,
    ContentText = function(i) local t = i._props.Text or ""; return i._props.RichText and stripRich(t) or t end,
    Parent = function(i) return i._parent end,
    ViewportSize = function() return VIEWPORT end,
    GuiState = function() return Enum.GuiState.Idle end,
}

InstMt.__index = function(self, key)
    local props = rawget(self, "_props")
    local v = props[key]
    if v ~= nil then return v end
    local computed = COMPUTED[key]
    if computed then return computed(self) end
    local m = METHODS[key]
    if m then return m end
    if EVENTS[key] then
        local events = rawget(self, "_events")
        local s = events[key]
        if not s then s = newSignal(key); events[key] = s end
        return s
    end
    -- children by name
    for _, child in ipairs(rawget(self, "_children")) do
        if child._props.Name == key then return child end
    end
    local extra = rawget(self, "_extra")
    if extra and extra[key] ~= nil then return extra[key] end
    if rawtype(key) == "string" and key:match("^%u") then
        local id = self.ClassName .. "." .. key
        if not H.Unknown[id] then
            H.Unknown[id] = true
        end
        error(key .. " is not a valid member of " .. self.ClassName .. " \"" .. tostring(props.Name) .. "\"", 2)
    end
    return nil
end

local function descendants(inst, out)
    for _, child in ipairs(inst._children) do
        table.insert(out, child)
        descendants(child, out)
    end
    return out
end

local function fireDescendantAdded(newParent, inst)
    local list = { inst }
    descendants(inst, list)
    local ancestor = newParent
    while ancestor do
        for _, d in ipairs(list) do fireEvent(ancestor, "DescendantAdded", d) end
        ancestor = ancestor._parent
    end
end
local function fireDescendantRemoving(oldParent, inst)
    local list = { inst }
    descendants(inst, list)
    local ancestor = oldParent
    while ancestor do
        for _, d in ipairs(list) do fireEvent(ancestor, "DescendantRemoving", d) end
        ancestor = ancestor._parent
    end
end

local function setParent(self, parent)
    if rawget(self, "_destroyed") then
        error("The Parent property of " .. tostring(self._props.Name) .. " is locked, current parent: NULL, new parent " .. tostring(parent and parent._props.Name), 3)
    end
    if parent ~= nil and typeof(parent) ~= "Instance" then error("Unable to set Parent: Instance expected", 3) end
    local old = rawget(self, "_parent")
    if old == parent then return end
    -- cycle check
    local p = parent
    while p do
        if p == self then error("Attempt to set parent of " .. self._props.Name .. " to itself or a descendant", 3) end
        p = p._parent
    end
    if parent and rawget(parent, "_destroyed") then
        error("The Parent property of " .. tostring(self._props.Name) .. " is locked", 3)
    end
    if old then
        local kids = old._children
        for i, c in ipairs(kids) do if c == self then table.remove(kids, i) break end end
        fireDescendantRemoving(old, self)
        fireEvent(old, "ChildRemoved", self)
    end
    rawset(self, "_parent", parent)
    if parent then
        table.insert(parent._children, self)
        fireEvent(parent, "ChildAdded", self)
        fireDescendantAdded(parent, self)
    end
    fireEvent(self, "AncestryChanged", self, parent)
    local ps = self._propSignals.Parent
    if ps then ps:Fire() end
    fireEvent(self, "Changed", "Parent")
end

local function checkType(className, key, value)
    local current = defaults(className)[key]
    if current ~= nil and value ~= nil then
        local want, got = typeof(current), typeof(value)
        if want ~= got and not (want == "number" and got == "number") then
            -- Roblox coerces a few (e.g. string Text from numbers)
            if want == "string" and got == "number" then return tostring(value) end
            if want == "EnumItem" and got == "string" then return value end
            error("Unable to assign property " .. key .. ". " .. want .. " expected, got " .. got, 3)
        end
    end
    if key == "Text" and value == nil then
        error("Unable to assign property Text. string expected, got nil", 3)
    end
    return value
end

InstMt.__newindex = function(self, key, value)
    if key == "Parent" then return setParent(self, value) end
    if COMPUTED[key] then error("Unable to assign property " .. key .. ". Property is read only", 2) end
    if METHODS[key] or EVENTS[key] then error(key .. " is not a valid member of " .. self.ClassName .. " or cannot be assigned", 2) end
    value = checkType(self.ClassName, key, value)
    local props = rawget(self, "_props")
    local old = props[key]
    if old == value then return end
    props[key] = value
    local ps = rawget(self, "_propSignals")[key]
    if ps then ps:Fire() end
    fireEvent(self, "Changed", key)
    if key == "Text" or key == "TextSize" or key == "RichText" or key == "FontFace" then
        local tb = rawget(self, "_propSignals").TextBounds
        if tb then tb:Fire() end
    end
    if key == "Size" or key == "AutomaticSize" then
        local as = rawget(self, "_propSignals").AbsoluteSize
        if as then as:Fire() end
    end
    if key == "Position" then
        local ap = rawget(self, "_propSignals").AbsolutePosition
        if ap then ap:Fire() end
    end
    if key == "Text" then
        local ct = rawget(self, "_propSignals").ContentText
        if ct then ct:Fire() end
    end
end
InstMt.__tostring = function(self) return tostring(self._props.Name) end

function METHODS:IsA(name) return isA(self.ClassName, name) end
function METHODS:GetChildren() return table.clone(self._children) end
function METHODS:GetDescendants() return descendants(self, {}) end
function METHODS:FindFirstChild(name, recursive)
    for _, c in ipairs(self._children) do if c._props.Name == name then return c end end
    if recursive then
        for _, c in ipairs(self._children) do local f = c:FindFirstChild(name, true); if f then return f end end
    end
    return nil
end
function METHODS:FindFirstChildOfClass(cls)
    for _, c in ipairs(self._children) do if c.ClassName == cls then return c end end
    return nil
end
function METHODS:FindFirstChildWhichIsA(cls, recursive)
    for _, c in ipairs(self._children) do if isA(c.ClassName, cls) then return c end end
    if recursive then
        for _, c in ipairs(self._children) do local f = c:FindFirstChildWhichIsA(cls, true); if f then return f end end
    end
    return nil
end
function METHODS:FindFirstAncestor(name)
    local p = self._parent
    while p do if p._props.Name == name then return p end p = p._parent end
end
function METHODS:FindFirstAncestorOfClass(cls)
    local p = self._parent
    while p do if p.ClassName == cls then return p end p = p._parent end
end
function METHODS:FindFirstAncestorWhichIsA(cls)
    local p = self._parent
    while p do if isA(p.ClassName, cls) then return p end p = p._parent end
end
function METHODS:WaitForChild(name)
    local c = self:FindFirstChild(name)
    if c then return c end
    local deadline = H.VT + 5
    while H.VT < deadline do
        task.wait()
        c = self:FindFirstChild(name)
        if c then return c end
    end
    warn("Infinite yield possible on WaitForChild(" .. name .. ")")
    return nil
end
function METHODS:IsDescendantOf(ancestor)
    local p = self._parent
    while p do if p == ancestor then return true end p = p._parent end
    return false
end
function METHODS:IsAncestorOf(d) return d:IsDescendantOf(self) end
function METHODS:Destroy()
    if rawget(self, "_destroyed") then return end
    fireEvent(self, "Destroying")
    for _, c in ipairs(table.clone(self._children)) do c:Destroy() end
    if self._parent then setParent(self, nil) end
    rawset(self, "_destroyed", true)
    for _, s in pairs(self._events) do s._handlers = {} end
    for _, s in pairs(self._propSignals) do s._handlers = {} end
end
METHODS.Remove = METHODS.Destroy
function METHODS:ClearAllChildren() for _, c in ipairs(table.clone(self._children)) do c:Destroy() end end
function METHODS:Clone()
    local c = inst_new(self.ClassName)
    for k, v in pairs(self._props) do c._props[k] = v end
    for k, v in pairs(self._attrs) do c._attrs[k] = v end
    for _, child in ipairs(self._children) do child:Clone().Parent = c end
    return c
end
function METHODS:SetAttribute(name, value)
    if rawtype(name) ~= "string" then error("Attribute name must be a string", 2) end
    local t = typeof(value)
    if value ~= nil and t ~= "string" and t ~= "number" and t ~= "boolean" and t ~= "Color3" and t ~= "Vector2" and t ~= "UDim2" and t ~= "UDim" and t ~= "Vector3" and t ~= "Rect" and t ~= "EnumItem" and t ~= "Font" and t ~= "NumberRange" then
        error("SetAttribute: type " .. t .. " is not supported", 2)
    end
    if self._attrs[name] == value then return end
    self._attrs[name] = value
    local s = self._attrSignals[name]
    if s then s:Fire() end
    fireEvent(self, "AttributeChanged", name)
end
function METHODS:GetAttribute(name) return self._attrs[name] end
function METHODS:GetAttributes() return table.clone(self._attrs) end
function METHODS:GetPropertyChangedSignal(prop)
    local s = self._propSignals[prop]
    if not s then s = newSignal(prop); self._propSignals[prop] = s end
    return s
end
function METHODS:GetAttributeChangedSignal(name)
    local s = self._attrSignals[name]
    if not s then s = newSignal(name); self._attrSignals[name] = s end
    return s
end
function METHODS:GetFullName()
    local parts, p = {}, self
    while p do table.insert(parts, 1, tostring(p._props.Name)); p = p._parent end
    return table.concat(parts, ".")
end
-- TextBox
local focusedBox = nil
function METHODS:IsFocused() return focusedBox == self end
function METHODS:CaptureFocus()
    if focusedBox == self then return end
    if focusedBox then focusedBox:ReleaseFocus() end
    focusedBox = self
    if self._props.ClearTextOnFocus then self.Text = "" end
    fireEvent(self, "Focused")
end
function METHODS:ReleaseFocus(submitted)
    if focusedBox ~= self then return end
    focusedBox = nil
    fireEvent(self, "FocusLost", submitted == true, nil)
end
H.focused = function() return focusedBox end
-- Legacy tween helpers
function METHODS:TweenSize(size) self.Size = size return true end
function METHODS:TweenPosition(pos) self.Position = pos return true end
function METHODS:TweenSizeAndPosition(s, p) self.Size = s; self.Position = p return true end
-- ScrollingFrame helpers none
function METHODS:GetPlayers() return H.players() end

Instance = {
    new = function(className, parent)
        if rawtype(className) ~= "string" then error("Instance.new expects a class name", 2) end
        return inst_new(className, parent)
    end,
    fromExisting = function(i) return i:Clone() end,
}

---------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------
local function service(className, extra)
    local s = inst_new(className)
    rawset(s, "_extra", extra or {})
    s._props.Name = className
    return s
end

local TweenService = service("TweenService")
local TweenMt = { __type = "Instance" }
TweenMt.__index = TweenMt
function TweenMt:Play()
    if self._played then return end
    self._played = true
    local obj, props = self.Instance, self._goal
    if rawget(obj, "_destroyed") then return end
    for k, v in pairs(props) do obj[k] = v end
    self.PlaybackState = Enum.PlaybackState.Playing
    task.delay(self.TweenInfo.Time or 0, function()
        self.PlaybackState = Enum.PlaybackState.Completed
        self.Completed:Fire(Enum.PlaybackState.Completed)
    end)
end
function TweenMt:Cancel() self.PlaybackState = Enum.PlaybackState.Cancelled end
function TweenMt:Pause() end
function TweenMt:Destroy() end
rawget(TweenService, "_extra").Create = function(_, obj, info, goal)
    if typeof(obj) ~= "Instance" then error("TweenService:Create: Instance expected, got " .. typeof(obj), 2) end
    if typeof(info) ~= "TweenInfo" then error("TweenService:Create: TweenInfo expected", 2) end
    if rawtype(goal) ~= "table" then error("TweenService:Create: property table expected", 2) end
    for k, v in pairs(goal) do
        local cur = obj[k] -- errors on invalid property
        if cur ~= nil and typeof(cur) ~= typeof(v) then
            error("TweenService:Create property named '" .. k .. "' cannot be tweened due to type mismatch (property is a '" .. typeof(cur) .. "', but given type is '" .. typeof(v) .. "')", 2)
        end
        local t = typeof(v)
        if t == "string" or t == "boolean" or t == "EnumItem" then
            error("TweenService:Create no property named '" .. k .. "' for object '" .. tostring(obj) .. "' that can be tweened", 2)
        end
    end
    return setmetatable({ Instance = obj, TweenInfo = info, _goal = goal, Completed = newSignal("Completed"), PlaybackState = Enum.PlaybackState.Begin }, TweenMt)
end

local RunService = service("RunService", {
    Heartbeat = newSignal("Heartbeat"), RenderStepped = newSignal("RenderStepped"), Stepped = newSignal("Stepped"),
    PreRender = newSignal("PreRender"), PostSimulation = newSignal("PostSimulation"), PreSimulation = newSignal("PreSimulation"),
    IsStudio = function() return false end, IsClient = function() return true end, IsServer = function() return false end,
    IsRunning = function() return true end,
    BindToRenderStep = function(_, name, prio, fn) H.renderBinds = H.renderBinds or {}; H.renderBinds[name] = fn end,
    UnbindFromRenderStep = function(_, name) if H.renderBinds then H.renderBinds[name] = nil end end,
})

local mouse = v2(683, 384)
H.setMouse = function(x, y) mouse = v2(x, y) end
H.getMouse = function() return mouse end
local UserInputService = service("UserInputService", {
    TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false, AccelerometerEnabled = false, GyroscopeEnabled = false, VREnabled = false,
    MouseBehavior = Enum.MouseBehavior.Default, MouseIconEnabled = true, OnScreenKeyboardVisible = false, ModalEnabled = false,
    InputBegan = newSignal("InputBegan"), InputChanged = newSignal("InputChanged"), InputEnded = newSignal("InputEnded"),
    TouchStarted = newSignal("TouchStarted"), TouchMoved = newSignal("TouchMoved"), TouchEnded = newSignal("TouchEnded"), TouchTap = newSignal("TouchTap"),
    LastInputTypeChanged = newSignal("LastInputTypeChanged"), WindowFocused = newSignal("WindowFocused"), WindowFocusReleased = newSignal("WindowFocusReleased"),
    TextBoxFocused = newSignal("TextBoxFocused"), TextBoxFocusReleased = newSignal("TextBoxFocusReleased"),
    GetMouseLocation = function() return mouse end,
    GetMouseDelta = function() return v2(0, 0) end,
    GetFocusedTextBox = function() return focusedBox end,
    IsKeyDown = function() return false end,
    IsMouseButtonPressed = function() return false end,
    GetLastInputType = function() return Enum.UserInputType.MouseMovement end,
    GetKeysPressed = function() return {} end,
    GetStringForKeyCode = function(_, k) return k.Name end,
    GetPlatform = function() return Enum.Platform.Windows end,
})
H.UIS = UserInputService

local GuiService = service("GuiService", {
    GetGuiInset = function() return v2(0, 58), v2(0, 0) end,
    TopbarInset = rect(0, 0, 1366, 58),
    SelectedObject = nil, AutoSelectGuiEnabled = true, MenuIsOpen = false,
    IsTenFootInterface = function() return false end,
    MenuOpened = newSignal("MenuOpened"), MenuClosed = newSignal("MenuClosed"),
})

local function jsonEncode(v, seen)
    local t = rawtype(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        if math.floor(v) == v and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.14g", v)
    end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return map[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    if t == "table" then
        if typeof(v) ~= "table" then error("Can't convert to JSON: " .. typeof(v)) end
        seen = seen or {}
        if seen[v] then error("Can't convert to JSON: cycle") end
        seen[v] = true
        local n = #v
        local isArray = n > 0 or next(v) == nil
        if isArray then
            for k in pairs(v) do if rawtype(k) ~= "number" then isArray = false break end end
        end
        local parts = {}
        if isArray then
            for i = 1, n do parts[i] = jsonEncode(v[i], seen) end
            seen[v] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, val in pairs(v) do
            if rawtype(k) ~= "string" and rawtype(k) ~= "number" then error("Can't convert to JSON: key type") end
            table.insert(parts, jsonEncode(tostring(k)) .. ":" .. jsonEncode(val, seen))
        end
        seen[v] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("Can't convert to JSON: " .. t)
end
local function jsonDecode(s)
    local i = 1
    local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
    local value
    local function str()
        i += 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == "" then error("Can't parse JSON: unterminated string") end
            if c == '"' then i += 1 break end
            if c == "\\" then
                local e = s:sub(i + 1, i + 1)
                local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
                if e == "u" then
                    table.insert(out, utf8.char(tonumber(s:sub(i + 2, i + 5), 16)))
                    i += 6
                else
                    table.insert(out, map[e] or e)
                    i += 2
                end
            else
                table.insert(out, c)
                i += 1
            end
        end
        return table.concat(out)
    end
    value = function()
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            i += 1
            local obj = {}
            ws()
            if s:sub(i, i) == "}" then i += 1 return obj end
            while true do
                ws()
                if s:sub(i, i) ~= '"' then error("Can't parse JSON: key expected") end
                local k = str()
                ws()
                if s:sub(i, i) ~= ":" then error("Can't parse JSON: colon expected") end
                i += 1
                obj[k] = value()
                ws()
                local d = s:sub(i, i)
                i += 1
                if d == "}" then return obj end
                if d ~= "," then error("Can't parse JSON: , or } expected") end
            end
        elseif c == "[" then
            i += 1
            local arr = {}
            ws()
            if s:sub(i, i) == "]" then i += 1 return arr end
            while true do
                table.insert(arr, value())
                ws()
                local d = s:sub(i, i)
                i += 1
                if d == "]" then return arr end
                if d ~= "," then error("Can't parse JSON: , or ] expected") end
            end
        elseif c == '"' then
            return str()
        elseif s:sub(i, i + 3) == "true" then i += 4 return true
        elseif s:sub(i, i + 4) == "false" then i += 5 return false
        elseif s:sub(i, i + 3) == "null" then i += 4 return nil
        else
            local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if not n or n == "" then error("Can't parse JSON") end
            i += #n
            return tonumber(n)
        end
    end
    local ok, result = pcall(value)
    if not ok then error(result, 0) end
    ws()
    if i <= #s then error("Can't parse JSON: trailing data", 0) end
    return result
end
H.jsonDecode, H.jsonEncode = jsonDecode, jsonEncode
local guidCount = 0
local HttpService = service("HttpService", {
    JSONEncode = function(_, v) return jsonEncode(v) end,
    JSONDecode = function(_, s)
        if rawtype(s) ~= "string" then error("Can't parse JSON", 2) end
        return jsonDecode(s)
    end,
    GenerateGUID = function(_, braces) guidCount += 1; local g = string.format("00000000-0000-0000-0000-%012d", guidCount); return braces == false and g or "{" .. g .. "}" end,
    UrlEncode = function(_, s) return (tostring(s):gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end)) end,
    HttpEnabled = false,
})

local TextService = service("TextService", {
    GetTextSize = function(_, text, size, font, frame)
        local lines, longest = 1, 0
        for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do longest = math.max(longest, #line); end
        for _ in tostring(text):gmatch("\n") do lines += 1 end
        return v2(math.min(longest * size * 0.5, frame and frame.X or math.huge), size * 1.2 * lines)
    end,
    GetTextBoundsAsync = function(_, params)
        local text = params.Text or ""
        local size = params.Size or 14
        local width = params.Width or math.huge
        return v2(math.min(#text * size * 0.5, width), size * 1.2)
    end,
})
GetTextBoundsParams = { new = function() return {} end }

local MarketplaceService = service("MarketplaceService", {
    GetProductInfo = function(_, id) return { Name = "Mock Game", Description = "", Creator = { Name = "MockDev", CreatorType = "User" }, IconImageAssetId = 0 } end,
    UserOwnsGamePassAsync = function() return false end,
})
local TeleportService = service("TeleportService", {
    TeleportInitFailed = newSignal("TeleportInitFailed"),
    Teleport = function() H.teleports = (H.teleports or 0) + 1 end,
    TeleportToPlaceInstance = function() H.teleports = (H.teleports or 0) + 1 end,
    TeleportAsync = function() end,
})

local statsItem = { GetValue = function() return 55 + (math.floor(H.VT) % 9) end, GetValueString = function() return "62.5 ms" end }
local Stats = service("Stats", {
    Network = { ServerStatsItem = setmetatable({}, { __index = function() return statsItem end }) },
    GetTotalMemoryUsageMb = function() return 812.4 end,
    HeartbeatTimeMs = 2, RenderCPUFrameTime = 0.005,
    Workspace = { Heartbeat = { GetValue = function() return 60 end } },
})

local CoreGui = service("CoreGui")
local Players = service("Players")
local Workspace = service("Workspace")
local Lighting = service("Lighting")
local StarterGui = service("StarterGui", { SetCore = function() end, GetCore = function() return nil end, SetCoreGuiEnabled = function() end })
local ContentProvider = service("ContentProvider", { PreloadAsync = function() end, RequestQueueSize = 0 })
local SoundService = service("SoundService")
local LocalizationService = service("LocalizationService", { RobloxLocaleId = "en-us", GetCountryRegionForPlayerAsync = function() return "ID" end })

local camera = inst_new("Camera", Workspace)
rawset(Workspace, "_extra", { CurrentCamera = camera, GetRealPhysicsFPS = function() return 60 end, DistributedGameTime = 0 })

local function makePlayer(name, userId, display)
    local p = inst_new("Player")
    p._props.Name = name
    rawset(p, "_extra", {
        UserId = userId, DisplayName = display or name, AccountAge = 400, MembershipType = Enum.MembershipType.None, Character = nil,
        GetNetworkPing = function() return 0.031 end,
        Kick = function() H.kicked = true end,
        IsFriendsWith = function() return false end,
        GetMouse = function() return { X = mouse.X, Y = mouse.Y, Hit = nil, Target = nil } end,
        GetRankInGroup = function() return 0 end,
        IsInGroup = function() return false end,
    })
    p.Parent = Players
    return p
end
local LocalPlayer = makePlayer("KaitTester", 1001, "Kait")
local playerGui = inst_new("PlayerGui", LocalPlayer)
playerGui._props.Name = "PlayerGui"
rawget(Players, "_extra").LocalPlayer = LocalPlayer
rawget(Players, "_extra").MaxPlayers = 12
rawget(Players, "_extra").GetPlayers = function()
    local out = {}
    for _, c in ipairs(Players._children) do if c.ClassName == "Player" then table.insert(out, c) end end
    return out
end
rawget(Players, "_extra").GetPlayerByUserId = function(_, id)
    for _, c in ipairs(Players._children) do if c.ClassName == "Player" and c.UserId == id then return c end end
end
rawget(Players, "_extra").GetUserThumbnailAsync = function(_, id) return "rbxthumb://type=AvatarHeadShot&id=" .. id .. "&w=150&h=150", true end
rawget(Players, "_extra").GetNameFromUserIdAsync = function() return "Someone" end
H.players = rawget(Players, "_extra").GetPlayers
H.addPlayer = function(name, id)
    local p = makePlayer(name, id)
    fireEvent(Players, "PlayerAdded", p)
    return p
end
H.removePlayer = function(p)
    fireEvent(Players, "PlayerRemoving", p)
    p.Parent = nil
end
H.addPlayer("Builderman", 156)
H.addPlayer("Noob123", 2002)

local SERVICES = {
    TweenService = TweenService, RunService = RunService, UserInputService = UserInputService, GuiService = GuiService, HttpService = HttpService,
    TextService = TextService, MarketplaceService = MarketplaceService, TeleportService = TeleportService, Stats = Stats, CoreGui = CoreGui,
    Players = Players, Workspace = Workspace, Lighting = Lighting, StarterGui = StarterGui, ContentProvider = ContentProvider, SoundService = SoundService,
    LocalizationService = LocalizationService,
}
H.services = SERVICES

local DIST = nil
H.setDist = function(src) DIST = src end
local LUCIDE = [[
local icons = {}
return setmetatable({ Icons = setmetatable({}, { __index = function(_, name)
    return { Image = 10723434557, ImageRectPosition = Vector2.new(0, 0), ImageRectSize = Vector2.new(24, 24) }
end }), Spritesheets = {} }, {})
]]
game = service("DataModel", {
    PlaceId = 920587237, GameId = 333444, JobId = "11111111-2222-3333-4444-555555555555", PrivateServerId = "", PrivateServerOwnerId = 0,
    CreatorId = 1, CreatorType = Enum.CreatorType.User, PlaceVersion = 1, Name = "Mock Place",
    GetService = function(_, name)
        local s = SERVICES[name]
        if not s then error("'" .. tostring(name) .. "' is not a valid Service name", 2) end
        return s
    end,
    FindService = function(_, name) return SERVICES[name] end,
    HttpGet = function(_, url)
        H.httpGets = (H.httpGets or 0) + 1
        if tostring(url):find("Icons") or tostring(url):find("lucide") then return LUCIDE end
        if tostring(url):find("KaitUI.luau") then return DIST end
        if tostring(url):find("%.json") then return "{}" end
        return ""
    end,
    HttpGetAsync = function(self, url) return self:HttpGet(url) end,
    IsLoaded = function() return true end,
    Loaded = newSignal("Loaded"),
    BindToClose = function() end,
})
Workspace.Parent = game
CoreGui.Parent = game
Players.Parent = game
workspace = Workspace
Game = game

---------------------------------------------------------------------------
-- Executor API
---------------------------------------------------------------------------
local FS = { files = {}, folders = {} }
H.FS = FS
local function norm(path) return (tostring(path):gsub("\\", "/"):gsub("/+$", "")) end
local function parentOf(path) return path:match("^(.*)/[^/]+$") end
function writefile(path, content)
    path = norm(path)
    if rawtype(content) ~= "string" then error("writefile: string expected", 2) end
    local parent = parentOf(path)
    if parent and not FS.folders[parent] then error("writefile: folder " .. parent .. " does not exist", 2) end
    FS.files[path] = content
end
function appendfile(path, content) path = norm(path); FS.files[path] = (FS.files[path] or "") .. content end
function readfile(path)
    path = norm(path)
    local c = FS.files[path]
    if c == nil then error("readfile: file " .. path .. " does not exist", 2) end
    return c
end
function isfile(path) return FS.files[norm(path)] ~= nil end
function isfolder(path) return FS.folders[norm(path)] == true end
function makefolder(path)
    path = norm(path)
    local acc = nil
    for part in path:gmatch("[^/]+") do
        acc = acc and (acc .. "/" .. part) or part
        FS.folders[acc] = true
    end
end
function delfile(path)
    path = norm(path)
    if FS.files[path] == nil then error("delfile: file does not exist", 2) end
    FS.files[path] = nil
end
function delfolder(path)
    path = norm(path)
    for f in pairs(table.clone(FS.files)) do if f == path or f:sub(1, #path + 1) == path .. "/" then FS.files[f] = nil end end
    for f in pairs(table.clone(FS.folders)) do if f == path or f:sub(1, #path + 1) == path .. "/" then FS.folders[f] = nil end end
end
function listfiles(path)
    path = norm(path)
    if not FS.folders[path] then error("listfiles: folder does not exist", 2) end
    local out = {}
    for f in pairs(FS.files) do if parentOf(f) == path then table.insert(out, f) end end
    for f in pairs(FS.folders) do if parentOf(f) == path then table.insert(out, f) end end
    table.sort(out)
    return out
end
function getcustomasset(path)
    path = norm(path)
    if FS.files[path] == nil then error("getcustomasset: file does not exist", 2) end
    return "rbxasset://custom/" .. path
end
getsynasset = nil
function setclipboard(text) H.clipboard = tostring(text) end
toclipboard = setclipboard
function identifyexecutor() return "MockExec", "1.0" end
getexecutorname = identifyexecutor
local genv = {}
function getgenv() return genv end
shared = {}
function gethui() return CoreGui end
function getthreadidentity() return 8 end
function setthreadidentity() end
getidentity, setidentity = getthreadidentity, setthreadidentity
function request(opts)
    H.requests = (H.requests or 0) + 1
    return { StatusCode = 200, Success = true, Body = "", Headers = {} }
end
http_request = request
function cloneref(x) return x end
function hookmetamethod() end
function getconnections() return {} end
function checkcaller() return true end
function iscclosure() return false end
function newcclosure(f) return f end

---------------------------------------------------------------------------
-- Frame stepping and input
---------------------------------------------------------------------------
H.step = function(dt)
    dt = dt or 1 / 60
    H.VT += dt
    RunService.PreRender:Fire(dt)
    RunService.RenderStepped:Fire(dt)
    if H.renderBinds then for _, fn in pairs(H.renderBinds) do local ok, e = pcall(fn, dt) if not ok then fail("renderbind", e) end end end
    RunService.Stepped:Fire(H.VT, dt)
    RunService.Heartbeat:Fire(dt)
    -- wake sleepers in time order
    local guard = 0
    while true do
        guard += 1
        if guard > 100000 then fail("scheduler", "sleeper loop runaway") break end
        local best, bi = nil, nil
        for i, s in ipairs(sleepers) do
            if s.wake <= H.VT and (not best or s.wake < best.wake) then best, bi = s, i end
        end
        if not best then break end
        table.remove(sleepers, bi)
        if best.args then
            resume(best.thread, table.unpack(best.args, 1, best.args.n))
        else
            resume(best.thread, H.VT - (best.start or H.VT))
        end
        runDeferred()
    end
    runDeferred()
end
H.run = function(seconds, dt)
    dt = dt or 1 / 30
    local steps = math.ceil(seconds / dt)
    for _ = 1, steps do H.step(dt) end
end

local function inputObject(kind, x, y, keyCode, state)
    local obj = setmetatable({
        UserInputType = Enum.UserInputType[kind], UserInputState = Enum.UserInputState[state or "Begin"],
        KeyCode = keyCode or Enum.KeyCode.Unknown, Position = Vector3.new(x or mouse.X, y or mouse.Y, 0), Delta = Vector3.new(0, 0, 0),
    }, { __type = "Instance" })
    return obj
end
H.inputObject = inputObject

-- Clicks a GuiButton (or any GuiObject) the way a mouse does, at its centre.
H.click = function(gui)
    if rawget(gui, "_destroyed") then return end
    local inset = 58
    local pos, size = absPos(gui), absSize(gui)
    local x, y = pos.X + size.X / 2, pos.Y + size.Y / 2 + inset
    mouse = v2(x, y)
    local down = inputObject("MouseButton1", x, y, nil, "Begin")
    fireEvent(gui, "MouseEnter", x, y)
    UserInputService.InputBegan:Fire(down, false)
    fireEvent(gui, "InputBegan", down)
    fireEvent(gui, "MouseButton1Down", x, y)
    H.runDeferred()
    local up = inputObject("MouseButton1", x, y, nil, "End")
    UserInputService.InputEnded:Fire(up, false)
    fireEvent(gui, "InputEnded", up)
    fireEvent(gui, "MouseButton1Up", x, y)
    fireEvent(gui, "MouseButton1Click")
    fireEvent(gui, "Activated", up, 1)
    fireEvent(gui, "MouseLeave", x, y)
    H.runDeferred()
end
H.key = function(name, processed)
    local kc = Enum.KeyCode[name]
    local i = inputObject("Keyboard", nil, nil, kc, "Begin")
    UserInputService.InputBegan:Fire(i, processed == true)
    local e = inputObject("Keyboard", nil, nil, kc, "End")
    UserInputService.InputEnded:Fire(e, processed == true)
    H.runDeferred()
end
H.drag = function(gui, dx, dy)
    local pos, size = absPos(gui), absSize(gui)
    local x, y = pos.X + size.X / 2, pos.Y + size.Y / 2 + 58
    mouse = v2(x, y)
    local down = inputObject("MouseButton1", x, y, nil, "Begin")
    UserInputService.InputBegan:Fire(down, false)
    fireEvent(gui, "InputBegan", down)
    fireEvent(gui, "MouseButton1Down", x, y)
    for i = 1, 6 do
        mouse = v2(x + dx * i / 6, y + dy * i / 6)
        local mv = inputObject("MouseMovement", mouse.X, mouse.Y, nil, "Change")
        UserInputService.InputChanged:Fire(mv, false)
        fireEvent(gui, "InputChanged", mv)
        H.step(1 / 60)
    end
    local up = inputObject("MouseButton1", mouse.X, mouse.Y, nil, "End")
    UserInputService.InputEnded:Fire(up, false)
    fireEvent(gui, "InputEnded", up)
    fireEvent(gui, "MouseButton1Up", mouse.X, mouse.Y)
    H.runDeferred()
end
H.type = function(box, text, enter)
    box:CaptureFocus()
    box.Text = text
    H.runDeferred()
    box:ReleaseFocus(enter ~= false)
    H.runDeferred()
end

type = function(v)
    if rawtype(v) == "table" then
        local mt = getmetatable(v)
        if rawtype(mt) == "table" and rawget(mt, "__type") then return "userdata" end
    end
    return rawtype(v)
end
__mocktype = type
__mocktypeof = typeof
H.allInstances = allInstances
H.descendants = function(i) return descendants(i, {}) end
return H

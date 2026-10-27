local function loadLucide()
    if lucideSet ~= nil then
        return lucideSet
    end
    local ok, result = pcall(function()
        local source = game:HttpGet(LUCIDE_URL)
        return loadstring(source)()
    end)
    if ok and type(result) == "table" then
        lucideSet = result
    else
        lucideSet = false
        warn("[KaitUI] lucide icons unavailable: " .. tostring(result))
    end
    return lucideSet
end

local FONT_PRESETS = {
    ValleySans = {
        Regular = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Regular.ttf",
        Medium = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Medium.ttf",
        SemiBold = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-SemiBold.ttf",
    },
}

local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular },
    Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold },
    Bold = { 700, Enum.FontWeight.Bold },
}

function Library:LoadFont(opts)
    opts = normalize(opts, {})
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[KaitUI] custom fonts need writefile, isfile and getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights or FONT_PRESETS[name]
    if type(weights) ~= "table" then
        warn("[KaitUI] no font weights for " .. name)
        return false
    end
    local folder = opts.Folder or "KaitUIFonts"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    writefile(path, game:HttpGet(url))
                end)
            end
            if ok then
                table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = getcustomasset(path) })
            else
                warn("[KaitUI] could not download " .. weightName .. " weight of " .. name)
            end
        end
    end
    if #faces == 0 then
        return false
    end
    local familyPath = folder .. "/" .. name .. ".json"
    local okWrite = pcall(function()
        writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces }))
    end)
    if not okWrite then
        return false
    end
    local family = getcustomasset(familyPath)
    local function face(weightName, fallback)
        local info = FONT_WEIGHTS[weightName]
        if info and weights[weightName] then
            return Font.new(family, info[2])
        end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("SemiBold", face("Bold", Library.Fonts.Bold))
    return true
end

function Library:PreloadIcons()
    return loadLucide() ~= false
end

-- Numbers, digit strings and asset URLs are custom images; anything else is
-- a lucide name.
local function assetId(value)
    if type(value) == "number" then
        return "rbxassetid://" .. string.format("%.0f", value)
    end
    if type(value) == "string" then
        if value:match("^%d+$") then
            return "rbxassetid://" .. value
        end
        if value:find("^rbxassetid://") or value:find("^rbxasset://") or value:find("^rbxthumb://") or value:find("^http") then
            return value
        end
    end
    return nil
end

-- Returns image, rect offset, rect size, whether it is a custom image, and
-- whether that custom image should still take the theme tint.
local function resolveIcon(icon)
    if typeof(icon) == "table" then
        return assetId(icon.Image) or icon.Image, icon.RectOffset, icon.RectSize, true, icon.Tint == true
    end
    local asset = assetId(icon)
    if asset then
        return asset, nil, nil, true, false
    end
    if type(icon) ~= "string" then
        return nil
    end
    local name = icon:gsub("^lucide:", "")
    local set = loadLucide()
    if not set then
        return nil
    end
    local entry = (set.Icons and set.Icons[name]) or set[name]
    if type(entry) == "table" then
        local image = entry.Image
        if type(image) == "number" then
            image = "rbxassetid://" .. tostring(image)
        end
        local sheet = (set.Spritesheets and set.Spritesheets[tostring(image)]) or image
        return sheet, entry.ImageRectPosition, entry.ImageRectSize
    elseif type(entry) == "string" then
        return entry
    end
    warn("[KaitUI] unknown lucide icon: " .. name)
    return nil
end

local BUTTON_HINT_ICON = "chevron-right"

local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Library.Fonts = {
    Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
    Medium = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
    Bold = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
}

local Theme = Library.Theme
local Assets = Library.Assets

-- The KaitUI mark, embedded as a 256px grayscale PNG so it needs no upload.
-- It is written to the workspace once and loaded with getcustomasset; the
-- white-to-grey shading is multiplied by the theme accent like the old logo.
-- Without file functions the uploaded asset above stays in use.
local EMBEDDED_LOGO = "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"

local function decodeBase64(data)
    local lookup = {}
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #alphabet do
        lookup[alphabet:byte(i)] = i - 1
    end
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        local n = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
        local x, y, z = n // 65536, n // 256 % 256, n % 256
        if d ~= 61 then
            out[#out + 1] = string.char(x, y, z)
        elseif c ~= 61 then
            out[#out + 1] = string.char(x, y)
        else
            out[#out + 1] = string.char(x)
        end
    end
    return table.concat(out)
end

pcall(function()
    if type(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
        return
    end
    local folder = "KaitUIAssets"
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
        makefolder(folder)
    end
    local path = folder .. "/KaitUILogo.png"
    local png = decodeBase64(EMBEDDED_LOGO)
    local fresh = type(isfile) == "function" and type(readfile) == "function" and isfile(path) and readfile(path) == png
    if not fresh then
        writefile(path, png)
    end
    local asset = getcustomasset(path)
    if type(asset) == "string" and asset ~= "" then
        Assets.Logo = asset
    end
end)
local Fonts = Library.Fonts

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Library.Touch = TOUCH

local SIDEBAR_WIDTH = 188
local HEADER_HEIGHT = 62
local TAB_TILE_HEIGHT = 34
local CARD_HEIGHT = TOUCH and 54 or 48
local CARD_HEIGHT_DESC = TOUCH and 70 or 64
local DROPDOWN_OPTION_HEIGHT = TOUCH and 40 or 34
local CHIP_HEIGHT = TOUCH and 34 or 28
local PROFILE_HEIGHT = 64
local SEARCH_WIDTH = 176
local STACK_BELOW = 440

-- Elements read their geometry from one of these. Cards stand alone on a tab,
-- rows sit flush inside a groupbox.
local METRICS = {
    Card = {
        Compact = false,
        Height = CARD_HEIGHT,
        DescHeight = CARD_HEIGHT_DESC,
        Chip = CHIP_HEIGHT,
        Option = DROPDOWN_OPTION_HEIGHT,
        TextSize = 14,
        DescSize = 13,
        TitleHeight = 18,
        DescGap = 20,
        DescLine = 17,
        Slider = CARD_HEIGHT_DESC,
    },
    Row = {
        Compact = true,
        Height = TOUCH and 40 or 32,
        DescHeight = TOUCH and 54 or 46,
        Chip = TOUCH and 30 or 24,
        Option = TOUCH and 34 or 28,
        TextSize = 13,
        DescSize = 12,
        TitleHeight = 16,
        DescGap = 17,
        DescLine = 15,
        Slider = TOUCH and 54 or 46,
    },
}

local tweenInfoCache = {}

-- Theme bindings: every instance property painted with a theme color is
-- remembered by theme key, so SetTheme can repaint the whole UI live.
-- Held strongly: an Instance's Lua handle can be collected while the Instance
-- still exists, which would silently drop it from a weak table. Destroyed
-- objects are pruned instead, once they have been parentless for two sweeps.
local themeBindings = {}
local themeHooks = {}
local themeLookup = {}
local orphanMarks = {}
local bindingCount = 0
local sweepAt = 4000


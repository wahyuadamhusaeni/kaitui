-- Background images

-- Image assets anyone can use, from Fluent-modded's themes.
Library.BackgroundPresets = {
    ["Deep Violet"] = "rbxassetid://136310484943077",
    ["Blood Red"] = "rbxassetid://121343473918667",
    ["Cyanic"] = "rbxassetid://95656189244173",
    ["Amber Glow"] = "rbxassetid://107795771598485",
    ["Bloomings"] = "rbxassetid://133541508207801",
    ["Lavender Pink"] = "rbxassetid://126107479485287",
}
Library.BackgroundPresetOrder = { "Deep Violet", "Blood Red", "Cyanic", "Amber Glow", "Bloomings", "Lavender Pink" }

-- Table fields, not locals: the library chunk is at Luau's 200 local limit.
Library._imageExtensions = { png = true, jpg = true, jpeg = true, webp = true, gif = true, bmp = true }

function Window:_backgroundFolder()
    return self.ConfigFolder .. "/backgrounds"
end

function Window:_trimBackground(source)
    return (tostring(source or ""):match("^%s*(.-)%s*$"))
end

-- Turns a background source into something ImageLabel.Image takes. Web images
-- are downloaded once into backgrounds/cache and loaded with getcustomasset,
-- so this yields the first time a URL is used.
function Window:_resolveBackground(source)
    source = self:_trimBackground(source)
    local preset = Library.BackgroundPresets[source]
    if preset then
        return preset
    end
    if source:match("^%d+$") then
        return "rbxassetid://" .. source
    end
    if source:match("^rbxassetid://%d+") or source:match("^rbxasset://") or source:match("^rbxthumb://")
        or source:match("^https?://www%.roblox%.com/asset") then
        return source
    end
    local canLoad = fileApiAvailable() and typeof(getcustomasset) == "function"
    if source:match("^https?://") then
        if not canLoad then
            return nil, "web images need writefile and getcustomasset"
        end
        local clean = source:match("^[^?#]+") or source
        local ext = (clean:match("%.(%w+)$") or "png"):lower()
        if not Library._imageExtensions[ext] then
            ext = "png"
        end
        local key = (clean:gsub("^https?://", ""):gsub("[^%w]", "_")):sub(-60)
        local folder = self:_backgroundFolder() .. "/cache"
        local path = folder .. "/" .. key .. "_" .. #source .. "." .. ext
        if not isfile(path) then
            local ok, body = pcall(function()
                local request = (syn and syn.request) or http_request or request
                if request then
                    local response = request({ Url = source, Method = "GET" })
                    return response and response.Body
                end
                return game:HttpGet(source, true)
            end)
            if not ok or type(body) ~= "string" or #body < 128 then
                return nil, "could not download the image"
            end
            local head = body:sub(1, 64):lower()
            if head:find("<!doctype") or head:find("<html") then
                return nil, "that link is a web page, not an image"
            end
            ensureFolder(folder)
            if not pcall(writefile, path, body) then
                return nil, "could not save the image"
            end
        end
        local ok, asset = pcall(getcustomasset, path)
        if ok and type(asset) == "string" and asset ~= "" then
            return asset
        end
        pcall(delfile, path)
        return nil, "the downloaded file is not an image"
    end
    -- A file in the backgrounds folder, or any path in the workspace.
    if canLoad then
        for _, path in ipairs({ self:_backgroundFolder() .. "/" .. source, source }) do
            if isfile(path) then
                local ok, asset = pcall(getcustomasset, path)
                if ok and type(asset) == "string" and asset ~= "" then
                    return asset
                end
                return nil, "could not load " .. source
            end
        end
    end
    return nil, "no image called " .. source
end

-- source: a preset name, an image asset id, an rbxassetid:// link, an http(s)
-- image URL, or an image file in <ConfigFolder>/backgrounds. nil or "None"
-- removes it. May yield while a web image downloads.
function Window:SetBackground(source)
    self._backgroundGeneration += 1
    local generation = self._backgroundGeneration
    local image = self._backgroundImage
    source = source ~= false and self:_trimBackground(source) or ""
    if source == "" or source == "None" then
        self.Background = nil
        tween(image, { ImageTransparency = 1 }, 0.25)
        task.delay(0.25, function()
            if self._backgroundGeneration == generation then
                image.Visible = false
                image.Image = ""
            end
        end)
        self:SetTransparent(self.Transparent)
        return true
    end
    local asset, err = self:_resolveBackground(source)
    if self._backgroundGeneration ~= generation or self._destroyed then
        return false, "replaced by a newer background"
    end
    if not asset then
        return false, err
    end
    self.Background = source
    image.Image = asset
    image.Visible = true
    tween(image, { ImageTransparency = self.BackgroundTransparency }, 0.3)
    self:SetTransparent(self.Transparent)
    return true
end

function Window:GetBackground()
    return self.Background
end

-- 0 shows the image fully, 1 hides it behind the theme background colour.
function Window:SetBackgroundTransparency(value)
    self.BackgroundTransparency = math.clamp(tonumber(value) or 0.35, 0, 1)
    if self.Background then
        tween(self._backgroundImage, { ImageTransparency = self.BackgroundTransparency }, 0.15)
    end
end

-- Preset names, then the image files in <ConfigFolder>/backgrounds.
function Window:ListBackgrounds()
    local names = table.clone(Library.BackgroundPresetOrder)
    local folder = self:_backgroundFolder()
    if type(listfiles) == "function" and type(isfolder) == "function" and isfolder(folder) then
        local files = {}
        for _, path in ipairs(listfiles(folder)) do
            local name = path:match("([^/\\]+)$")
            local ext = name and name:match("%.(%w+)$")
            if ext and Library._imageExtensions[ext:lower()] then
                table.insert(files, name)
            end
        end
        table.sort(files)
        for _, name in ipairs(files) do
            table.insert(names, name)
        end
    end
    return names
end


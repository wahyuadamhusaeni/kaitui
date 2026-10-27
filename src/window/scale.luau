function Window:_fitToScreen(instant)
    local viewport = self.Gui.AbsoluteSize
    if viewport.X == 0 or viewport.Y == 0 then
        return
    end
    local size = self.Root.Size
    -- The player's UI scale, times the adaptive factor for this screen, shrunk
    -- further when the window wouldn't fit.
    local wanted = (self._uiScale or 1) * (self._adaptive ~= false and Library._adaptiveFactor(viewport) or 1)
    local scale = math.min(wanted, (viewport.X - 24) / math.max(size.X.Offset, 1), (viewport.Y - 24) / math.max(size.Y.Offset, 1))
    self._fitScale = math.max(scale, 0.45)
    if self._introDone and self.Open then
        if instant then
            self.Scale.Scale = self._fitScale
        else
            tween(self.Scale, { Scale = self._fitScale }, 0.2)
        end
    end
end

-- Adaptive size: the window is drawn for a 1080p screen and grows on larger
-- ones (up to 1.75x on 4K) or shrinks a little on small laptops, so it covers
-- about the same share of any screen. 1080p-class screens, windowed or with
-- the topbar inset, stay at exactly 1. Touch screens only use the fit.
function Library._adaptiveFactor(viewport)
    if TOUCH then
        return 1
    end
    local factor = math.min(viewport.X / 1920, viewport.Y / 1020)
    if factor > 0.9 and factor < 1.15 then
        return 1
    end
    return math.clamp(math.floor(factor * 20 + 0.5) / 20, 0.85, 1.75)
end

function Window:SetAdaptiveSize(enabled)
    self._adaptive = enabled ~= false
    self:_fitToScreen()
    task.delay(0.22, function()
        if not self._destroyed then
            self:_clampToScreen()
        end
    end)
end

function Window:GetAdaptiveSize()
    return self._adaptive ~= false
end

-- UI scale: 0.6 to 1.5 on top of the automatic fit to small screens.
function Window:SetUIScale(value)
    value = math.clamp(tonumber(value) or 1, 0.6, 1.5)
    self.UIScale = value
    self._uiScale = value
    self:_fitToScreen()
    task.delay(0.22, function()
        if not self._destroyed then
            self:_clampToScreen()
        end
    end)
end

function Window:GetUIScale()
    return self._uiScale or 1
end

-- Density: the spacing between cards, groupboxes and rows. Shared by every
-- window, like the theme. Anything built with Library._space follows it.
Library.DensityModes = { Compact = 0.55, Default = 1, Comfortable = 1.45 }
Library.Density = "Default"

-- Small gaps (a groupbox's 2px rows) still move visibly between modes.
function Library._spaced(base, factor)
    if base <= 0 then
        return 0
    end
    return math.max(math.floor(base * factor + (factor - 1) * 4 + 0.5), 0)
end

function Library._space(object, base)
    local factor = Library.DensityModes[Library.Density] or 1
    if object:IsA("UIListLayout") or object:IsA("UIGridLayout") then
        object:SetAttribute("Space", base)
        object.Padding = UDim.new(0, Library._spaced(base, factor))
    elseif object:IsA("UIPadding") then
        -- base is { left, right, top, bottom }
        object:SetAttribute("SpaceL", base[1])
        object:SetAttribute("SpaceR", base[2])
        object:SetAttribute("SpaceT", base[3])
        object:SetAttribute("SpaceB", base[4])
        object.PaddingLeft = UDim.new(0, math.floor(base[1] * math.sqrt(factor) + 0.5))
        object.PaddingRight = UDim.new(0, math.floor(base[2] * math.sqrt(factor) + 0.5))
        object.PaddingTop = UDim.new(0, Library._spaced(base[3], factor))
        object.PaddingBottom = UDim.new(0, Library._spaced(base[4], factor))
    end
    return object
end

function Library:SetDensity(mode)
    if type(mode) == "string" then
        for name in pairs(Library.DensityModes) do
            if name:lower() == mode:lower() then
                mode = name
                break
            end
        end
    end
    if not Library.DensityModes[mode] then
        mode = "Default"
    end
    Library.Density = mode
    for _, window in ipairs(Library.Windows) do
        if window.Gui and window.Gui.Parent then
            for _, object in ipairs(window.Gui:GetDescendants()) do
                local base = object:GetAttribute("Space")
                if base then
                    Library._space(object, base)
                elseif object:GetAttribute("SpaceL") then
                    Library._space(object, {
                        object:GetAttribute("SpaceL"), object:GetAttribute("SpaceR"),
                        object:GetAttribute("SpaceT"), object:GetAttribute("SpaceB"),
                    })
                end
            end
        end
    end
    return mode
end

function Window:SetDensity(mode)
    return Library:SetDensity(mode)
end

function Window:GetDensity()
    return Library.Density
end

-- Nearest centre that keeps the whole window inside the viewport.
function Window:_clampedCentre(centre)
    local viewport = self.Gui.AbsoluteSize
    local half = self.Root.AbsoluteSize / 2
    return Vector2.new(
        math.clamp(centre.X, math.min(half.X, viewport.X / 2), math.max(viewport.X - half.X, viewport.X / 2)),
        math.clamp(centre.Y, math.min(half.Y, viewport.Y / 2), math.max(viewport.Y - half.Y, viewport.Y / 2))
    )
end

function Window:_clampToScreen()
    if not self.KeepOnScreen or self._resizeActive then
        return
    end
    local root = self.Root
    local centre = root.AbsolutePosition + root.AbsoluteSize / 2 - self.Gui.AbsolutePosition
    local clamped = self:_clampedCentre(centre)
    if (clamped - centre).Magnitude > 0.5 then
        self._clampTween = tween(root, { Position = UDim2.fromOffset(clamped.X, clamped.Y) }, 0.25, Enum.EasingStyle.Quint)
    end
end


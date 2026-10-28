function Tab:ButtonRow(opts)
    local specs = type(opts) == "table" and (opts.Buttons or opts) or {}
    local compact = metricsOf(self).Compact
    local boxHeight = TOUCH and 34 or 30
    local frame = card(self, "Frame", boxHeight + (compact and 4 or 14), {})
    local inset = compact and 14 or 7
    local holder = create("Frame", {
        Position = UDim2.fromOffset(inset, compact and 2 or 7),
        Size = UDim2.new(1, -inset * 2, 0, boxHeight),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    local count = math.max(#specs, 1)
    local handle = { Buttons = {} }
    local names = {}
    for index, spec in ipairs(specs) do
        if type(spec) == "string" then
            spec = { Name = spec }
        end
        local text = spec.Name or spec.Title or "Button"
        table.insert(names, text)
        local button, text_ = softButton(holder, text, {
            Position = UDim2.new((index - 1) / count, (index - 1) * 6 / count, 0, 0),
            Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0),
        }, function()
            safeCall(spec.Callback)
        end)
        text_.TextSize = 13
        if spec.Style == "Primary" then
            button:SetAttribute("RestTransparency", 0.12)
            button:SetAttribute("HoverTransparency", 0)
            tween(button, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.12 }, 0)
            tween(text_, { TextColor3 = Theme.AccentDark }, 0)
        elseif spec.Style == "Danger" then
            tween(text_, { TextColor3 = Theme.Error }, 0)
        end
        handle.Buttons[index] = { Button = button, Label = text_ }
    end
    function handle:SetText(index, text)
        local entry = handle.Buttons[index]
        if entry then
            entry.Label.Text = tostring(text)
        end
    end
    -- The row takes the options every element takes, next to its list of buttons.
    local shared = type(opts) == "table" and opts or {}
    return finishElement(self, {
        Name = table.concat(names, " "),
        Visible = shared.Visible ~= false,
        Disabled = shared.Disabled,
        DependsOn = shared.DependsOn,
        DependsMode = shared.DependsMode,
        Tooltip = shared.Tooltip,
    }, handle, frame, "ButtonRow")
end


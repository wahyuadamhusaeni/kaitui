function Tab:Keybind(opts)
    local frame, frameStroke, _, titleLabel, descLabel
    opts, frame, frameStroke, _, titleLabel, descLabel = beginElement(self, opts, { Title = "Name", Description = "Desc", CurrentKeybind = "Default", Value = "Default" }, "Frame", 110, "Keybind")
    opts.Default = Library._keyCode(opts.Default)
    local compact = metricsOf(self).Compact
    local chipHeight = metricsOf(self).Chip

    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, compact and -14 or -10, 0.5, 0),
        Size = UDim2.fromOffset(44, chipHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = frame,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)
    local chipLabel = label({
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 13,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip,
    })

    local self_ = { Value = opts.Default, Listening = false, Name = opts.Name or "Keybind", Linked = opts.Linked }

    local function fitChip(instant)
        local width = math.max(chipLabel.TextBounds.X + 20, TOUCH and 44 or 36)
        reserveRight(titleLabel, descLabel, width + (compact and 24 or 20))
        if instant then
            chip.Size = UDim2.fromOffset(width, chipHeight)
        else
            tween(chip, { Size = UDim2.fromOffset(width, chipHeight) }, 0.2)
        end
    end
    chipLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        fitChip(false)
    end)

    local function render()
        chipLabel.Text = self_.Listening and "..." or keyName(self_.Value)
        tween(chipStroke, { Color = self_.Listening and Theme.StrokeHover or Theme.Stroke }, 0.15)
        tween(chipLabel, { TextColor3 = self_.Listening and Theme.Accent or Theme.Muted }, 0.15)
    end

    function self_:Set(keyCode, silent)
        local wasListening = self_.Listening
        keyCode = Library._keyCode(keyCode)
        self_.Value = keyCode
        self_.Listening = false
        render()
        if not wasListening then
            flashStroke(frameStroke)
        end
        if not silent then
            safeCall(opts.OnChanged, keyCode)
        end
    end

    chip.MouseButton1Click:Connect(function()
        self_.Listening = not self_.Listening
        render()
    end)

    self.Window:_listen("Began", function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if self_.Listening then
            self.Window._consumedKey = input.KeyCode
            self.Window._consumedAt = os.clock()
            if input.KeyCode == Enum.KeyCode.Escape then
                self_.Listening = false
                render()
            else
                self_:Set(input.KeyCode)
            end
            return
        end
        -- Disabled (directly or by DependsOn) blocks the key as well as clicks.
        if self_.Disabled or self_._dependDisabled then
            return
        end
        -- A press that another keybind is capturing as its new key isn't a use of this one.
        local window = self.Window
        if window._consumedKey == input.KeyCode and os.clock() - (window._consumedAt or 0) < 0.1 then
            return
        end
        for _, other in ipairs(window._keybindElements or {}) do
            if other ~= self_ and other.Listening then
                return
            end
        end
        if not gameProcessed and self_.Value ~= nil and input.KeyCode == self_.Value then
            -- Linked: the key also flips that toggle (shown lit in the keybind list),
            -- unless the toggle is locked by SetDisabled or DependsOn.
            local linked = self_.Linked
            if type(linked) == "table" and not linked._destroyed and type(linked.Set) == "function"
                and not linked.Disabled and not linked._dependDisabled then
                task.spawn(pcall, linked.Set, linked, not linked.Value)
            end
            safeCall(opts.Callback, input.KeyCode)
        end
    end, self_)

    render()
    task.defer(fitChip, true)
    function self_:Get()
        return self_.Value
    end
    self_._onHide = function()
        if self_.Listening then
            self_.Listening = false
            render()
        end
    end
    -- Listed by Window:CreateKeybindList; destroyed entries are dropped here and by the list.
    local window = self.Window
    if window then
        local registered = {}
        for _, entry in ipairs(window._keybindElements or {}) do
            if not entry._destroyed then
                table.insert(registered, entry)
            end
        end
        table.insert(registered, self_)
        window._keybindElements = registered
    end
    return finishElement(self, opts, self_, frame, "Keybind")
end


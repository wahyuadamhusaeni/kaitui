-- See-through window: the body and sidebar let the game show through, and the
-- shadow lightens so it doesn't smudge behind them.
function Window:SetTransparent(enabled)
    self.Transparent = enabled == true
    local on = self.Transparent
    self._shadowRest = on and 0.85 or 0.6
    tween(self.Body, { BackgroundTransparency = on and 0.35 or 0 }, 0.25)
    -- See-through, the rail stays a touch more solid than the body so the
    -- tabs keep their contrast; over a background image it lets more through.
    local railAlpha = on and 0.5 or (self.Background and 0.45 or 0)
    tween(self.SidebarFill, { BackgroundTransparency = railAlpha }, 0.25)
    if self.Open and not self.Minimized and self.Root.Visible then
        tween(self.Shadow, { ImageTransparency = self._shadowRest }, 0.25)
    end
end

local function orderedChildren(parent)
    local children = {}
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(children, child)
        end
    end
    table.sort(children, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    return children
end

-- The reveal hides each card for a moment and marks it; showing or hiding an
-- element from a script (SetVisible, DependsOn) clears the mark, so a card the
-- script hid during the reveal stays hidden.
local function popIn(object, delay, force)
    if not object.Visible and not force then
        return
    end
    object.Visible = false
    object:SetAttribute("Revealing", true)
    task.delay(delay, function()
        if not object.Parent or not object:GetAttribute("Revealing") then
            return
        end
        object:SetAttribute("Revealing", nil)
        local scaleObject = create("UIScale", { Scale = 0.94, Parent = object })
        object.Visible = true
        tween(scaleObject, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        task.delay(0.4, function()
            scaleObject:Destroy()
        end)
    end)
end

function Window:_revealCards(tab, baseDelay)
    local container = tab.CurrentSubTab or tab
    if container._revealed then
        return
    end
    container._revealed = true
    local index = 0
    local function reveal(object)
        popIn(object, (baseDelay or 0) + index * 0.035)
        index += 1
    end
    local columns = container._columnSet
    for _, child in ipairs(orderedChildren(container.List)) do
        if columns and child == columns.Holder then
            local left, right = orderedChildren(columns.Left), orderedChildren(columns.Right)
            for row = 1, math.max(#left, #right) do
                if left[row] then
                    reveal(left[row])
                end
                if right[row] then
                    reveal(right[row])
                end
            end
        else
            reveal(child)
        end
    end
end

function Window:_playIntro(morph)
    if self._introDone or self._destroyed then
        return
    end
    self._introDone = true
    self:_refreshBackdrop(true)
    task.delay(0.4, function()
        self:_refreshToggleButton()
    end)
    -- Build the minimized bar ahead of time so the first minimize doesn't
    -- pay for it mid-click.
    task.delay(1.5, function()
        if not self._destroyed and not self.MiniBar then
            self:_buildMiniBar()
        end
    end)
    -- Toggle or Minimize called while the loader ran: applied now.
    local pending = self._pendingShow
    self._pendingShow = nil
    if pending == "hidden" or pending == "minimized" then
        task.delay(0.6, function()
            if self._destroyed or not self.Open or self.Minimized then
                return
            end
            if pending == "hidden" then
                self:Toggle(false)
            else
                self:Minimize()
            end
        end)
    elseif self:GetMinimizeOnStart() then
        task.delay(0.6, function()
            if not self._destroyed and self.Open and not self.Minimized then
                self:Minimize()
            end
        end)
    end
    local root, shadow, scale = self.Root, self.Shadow, self.Scale
    if self.CurrentTab then
        self:_revealCards(self.CurrentTab, morph and 0.15 or 0.25)
    end
    root.Visible = true
    if morph then
        scale.Scale = self._fitScale or 1
        root.Position = UDim2.fromScale(0.5, 0.5)
        self:_fade(0, 0.3)
        tween(self.BodyStroke, { Transparency = 0 }, 0.3)
        tween(shadow, { ImageTransparency = 0.6 }, 0.3)
    else
        root.Position = UDim2.new(0.5, 0, 0.5, 24)
        tween(scale, { Scale = self._fitScale or 1 }, 0.5, Enum.EasingStyle.Back)
        tween(root, { Position = UDim2.fromScale(0.5, 0.5) }, 0.5, Enum.EasingStyle.Quint)
        self:_fade(0, 0.35)
        tween(self.BodyStroke, { Transparency = 0 }, 0.35)
    end
    if not morph then
        tween(shadow, { ImageTransparency = 0.6 }, 0.5)
    end

    for index, tab in ipairs(self.Tabs) do
        popIn(tab._button, 0.1 + index * 0.05, true)
    end
    self.Indicator.Visible = false
    task.delay(0.15 + #self.Tabs * 0.05, function()
        if self.CurrentTab then
            self:_placeIndicator(self.CurrentTab)
        end
    end)
end

function Window:_showLoader(opts)
    local duration = opts.LoadingDuration or 1.6
    local gui = self.Gui
    -- A compact card: logo, title and subtitle on top, a checklist of the
    -- loading steps under a hairline, and a thin progress line along the
    -- bottom edge. Everything but the prompt cards lives in one canvas group
    -- so it can fade as a unit.
    local steps = opts.LoadingSteps or { "Preparing interface", "Loading icons", "Almost there" }
    local WIDTH, PAD, STEP = 340, 22, 24
    local listTop = 80
    local height = listTop + #steps * STEP + 18
    local loader = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10),
        Size = UDim2.fromOffset(WIDTH, height),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 10,
        Parent = gui,
    })
    local loaderCorner = corner(loader, UDim.new(0, 12))
    local loaderStroke = stroke(loader, Theme.Stroke, 1)
    local loaderScale = create("UIScale", { Scale = 0.97, Parent = loader })
    local loaderShadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25, -25),
        Size = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = loader,
    })
    local content = create("CanvasGroup", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = loader,
    })

    local logo = create("ImageLabel", {
        Position = UDim2.fromOffset(PAD, PAD),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        Parent = content,
    })
    applyIcon(logo, opts.Icon or Assets.Logo, true)
    local TEXT_X = PAD + 42
    local titleLabel = label({
        Position = UDim2.fromOffset(TEXT_X, PAD - 2),
        Size = UDim2.new(1, -(TEXT_X + 70), 0, 18),
        Text = opts.LoadingTitle or opts.Title or "KaitUI",
        TextSize = 15,
        FontFace = Fonts.Bold,
        Parent = content,
    })
    local statusLabel = label({
        Position = UDim2.fromOffset(TEXT_X, PAD + 17),
        Size = UDim2.new(1, -(TEXT_X + 70), 0, 15),
        Text = opts.LoadingText or opts.Subtitle or "Loading",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = content,
    })
    local percentLabel = label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -PAD, 0, PAD + 6),
        Size = UDim2.fromOffset(56, 16),
        Text = "0%",
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = content,
    })
    create("Frame", {
        Position = UDim2.fromOffset(PAD, listTop - 14),
        Size = UDim2.new(1, -PAD * 2, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = content,
    })

    -- Each step: a marker and its text. Pending is a dim dot, the running
    -- step a turning arc, and a finished one a check.
    local rows = {}
    for index, text in ipairs(steps) do
        local row = create("Frame", {
            Position = UDim2.fromOffset(PAD, listTop + (index - 1) * STEP),
            Size = UDim2.new(1, -PAD * 2, 0, STEP),
            BackgroundTransparency = 1,
            Parent = content,
        })
        local dot = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 7, 0.5, 0),
            Size = UDim2.fromOffset(6, 6),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(dot, UDim.new(1, 0))
        local spinner = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 7, 0.5, 0),
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = row,
        })
        corner(spinner, UDim.new(1, 0))
        local spinnerStroke = create("UIStroke", {
            Color = Theme.Accent,
            Thickness = 2,
            Parent = spinner,
        })
        create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(0.501, 1),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = spinnerStroke,
        })
        local check = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 7, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            Parent = row,
        })
        applyIcon(check, "check")
        local stepLabel = label({
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -24, 1, 0),
            Text = tostring(text),
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextTransparency = 1,
            Parent = row,
        })
        rows[index] = { Dot = dot, Spinner = spinner, Check = check, Label = stepLabel, State = "pending" }
        -- The rows fade in one after another once the card is up.
        task.delay(0.15 + index * 0.06, function()
            if loader.Parent and rows[index].State == "pending" then
                tween(stepLabel, { TextTransparency = 0.45 }, 0.3)
            end
        end)
    end
    local function setStep(index, state)
        local row = rows[index]
        if not row or row.State == state then
            return
        end
        row.State = state
        row.Dot.Visible = state == "pending"
        row.Spinner.Visible = state == "active"
        tween(row.Check, { ImageTransparency = state == "done" and 0 or 1 }, 0.2)
        tween(row.Label, {
            TextTransparency = state == "pending" and 0.45 or 0,
            TextColor3 = state == "active" and Theme.Text or Theme.Muted,
        }, 0.2)
    end

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = content,
    })
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })

    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.45, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Quint)
    tween(loaderShadow, { ImageTransparency = 0.55 }, 0.4)
    tween(fill, { Size = UDim2.fromScale(0.85, 1) }, duration * 0.8, Enum.EasingStyle.Quart)
    -- The percentage follows the bar and the running step's arc turns.
    local percentStep
    percentStep = RunService.RenderStepped:Connect(function(deltaTime)
        if not loader.Parent then
            percentStep:Disconnect()
            return
        end
        percentLabel.Text = math.floor(fill.Size.X.Scale * 100 + 0.5) .. "%"
        for _, row in ipairs(rows) do
            if row.State == "active" then
                row.Spinner.Rotation = (row.Spinner.Rotation + deltaTime * 360) % 360
            end
        end
    end)

    task.spawn(loadLucide)

    for index in ipairs(steps) do
        task.delay(duration * (index - 1) / #steps, function()
            if not loader.Parent then
                return
            end
            if index > 1 then
                setStep(index - 1, "done")
            end
            setStep(index, "active")
        end)
    end
    local function completeSteps()
        for index in ipairs(rows) do
            setStep(index, "done")
        end
    end

    local function finish()
        completeSteps()
        tween(content, { GroupTransparency = 1 }, 0.18)

        local fit = self._fitScale or 1
        local target = self.Root.Size
        tween(loader, {
            Size = UDim2.fromOffset(target.X.Offset * fit, target.Y.Offset * fit),
            Position = UDim2.fromScale(0.5, 0.5),
        }, 0.5, Enum.EasingStyle.Quint)
        tween(loaderCorner, { CornerRadius = UDim.new(0, Library._radius(10)) }, 0.5, Enum.EasingStyle.Quint)
        tween(loaderScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint)

        task.delay(0.28, function()
            self:_playIntro(true)
            tween(loader, { GroupTransparency = 1 }, 0.25)
            tween(loaderStroke, { Transparency = 1 }, 0.2)
            tween(loaderShadow, { ImageTransparency = 1 }, 0.2)
        end)
        task.delay(0.6, function()
            loader:Destroy()
        end)
    end

    -- Prompt cards (unsupported executor, custom disclaimers): the checklist
    -- gives way to one card at a time, each with Exit and Continue, before
    -- the window opens.
    local function hideBar()
        completeSteps()
        tween(content, { GroupTransparency = 1 }, 0.18)
    end

    local function showCard(info, onContinue)
        local WIDTH, PAD, MAX_BODY = 360, 24, 220
        local tone = info.Color or Theme.Accent
        -- Fixed width from the start, so the body wraps at its final width
        -- while the loader is still resizing.
        local warnCard = create("CanvasGroup", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(0, WIDTH, 1, 0),
            BackgroundTransparency = 1,
            GroupTransparency = 1,
            ZIndex = 5,
            Parent = loader,
        })
        local badge = create("Frame", {
            Position = UDim2.fromOffset(PAD, PAD),
            Size = UDim2.fromOffset(44, 44),
            BackgroundColor3 = tone,
            BackgroundTransparency = 0.86,
            BorderSizePixel = 0,
            Parent = warnCard,
        })
        corner(badge, UDim.new(0, 12))
        stroke(badge, tone, 1).Transparency = 0.6
        local badgeIcon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(22, 22),
            BackgroundTransparency = 1,
            ImageColor3 = tone,
            ScaleType = Enum.ScaleType.Fit,
            Parent = badge,
        })
        applyIcon(badgeIcon, info.Icon or "info")
        label({
            Position = UDim2.fromOffset(PAD + 58, info.Subtitle and PAD + 3 or PAD + 12),
            Size = UDim2.new(1, -(PAD * 2 + 58), 0, 20),
            Text = info.Title,
            TextSize = 17,
            Parent = warnCard,
        })
        if info.Subtitle then
            label({
                Position = UDim2.fromOffset(PAD + 58, PAD + 25),
                Size = UDim2.new(1, -(PAD * 2 + 58), 0, 16),
                Text = tostring(info.Subtitle),
                TextSize = 13,
                TextColor3 = tone,
                Parent = warnCard,
            })
        end
        -- Long text scrolls past MAX_BODY instead of pushing the card off screen.
        local scroller = create("ScrollingFrame", {
            Position = UDim2.fromOffset(PAD, PAD + 60),
            Size = UDim2.new(1, -PAD * 2, 0, 16),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = TOUCH and 4 or 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.4,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(),
            Parent = warnCard,
        })
        local body = label({
            Size = UDim2.new(1, -8, 0, 0),
            Text = tostring(info.Text),
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = scroller,
        })
        local row = create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, PAD, 1, -PAD + 4),
            Size = UDim2.new(1, -PAD * 2, 0, 34),
            BackgroundTransparency = 1,
            Parent = warnCard,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = row,
        })

        -- Don't ask again: only offered when Continue is, and the executor
        -- can write the file that remembers it.
        local remember = false
        local rememberRow = nil
        if not info.Block and info.RememberText and UnsupportedSkip.Available() then
            local boxSize = TOUCH and 20 or 16
            rememberRow = create("TextButton", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new(0, PAD, 1, -PAD + 4 - 34 - 12),
                Size = UDim2.new(1, -PAD * 2, 0, TOUCH and 28 or 22),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = warnCard,
            })
            local box = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(boxSize, boxSize),
                BackgroundColor3 = Theme.Surface2,
                BorderSizePixel = 0,
                Parent = rememberRow,
            })
            corner(box, UDim.new(0, 4))
            local boxStroke = stroke(box, Theme.Stroke, 1)
            local check = create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(boxSize - 4, boxSize - 4),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.AccentDark,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = box,
            })
            applyIcon(check, "check")
            local rememberLabel = label({
                Position = UDim2.fromOffset(boxSize + 8, 0),
                Size = UDim2.new(1, -(boxSize + 8), 1, 0),
                Text = info.RememberText,
                TextSize = 12,
                FontFace = Fonts.Regular,
                TextColor3 = Theme.Muted,
                Parent = rememberRow,
            })
            rememberRow.MouseEnter:Connect(function()
                tween(boxStroke, { Color = remember and Theme.Accent or Theme.StrokeHover }, 0.12)
                tween(rememberLabel, { TextColor3 = Theme.Text }, 0.12)
            end)
            rememberRow.MouseLeave:Connect(function()
                tween(boxStroke, { Color = remember and Theme.Accent or Theme.Stroke }, 0.2)
                tween(rememberLabel, { TextColor3 = remember and Theme.Text or Theme.Muted }, 0.2)
            end)
            rememberRow.MouseButton1Click:Connect(function()
                remember = not remember
                tween(box, { BackgroundColor3 = remember and Theme.Accent or Theme.Surface2 }, 0.15)
                tween(boxStroke, { Color = remember and Theme.Accent or Theme.Stroke }, 0.15)
                tween(check, { ImageTransparency = remember and 0 or 1 }, 0.15)
                tween(rememberLabel, { TextColor3 = remember and Theme.Text or Theme.Muted }, 0.15)
            end)
        end

        local chosen = false
        local function button(text, primary, order, callback)
            local frame = create("TextButton", {
                Size = UDim2.fromOffset(0, 34),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = primary and Theme.Accent or Theme.Surface2,
                BackgroundTransparency = primary and 0.12 or 0,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = order,
                Parent = row,
            })
            corner(frame, UDim.new(0, 7))
            local frameStroke = stroke(frame, primary and Theme.Accent or Theme.Stroke, 1)
            frameStroke.Transparency = primary and 0.4 or 0
            padding(frame, 14, 14)
            label({
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Text = text,
                TextSize = 13,
                TextColor3 = primary and Theme.AccentDark or Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = frame,
            })
            frame.MouseEnter:Connect(function()
                if primary then
                    tween(frame, { BackgroundTransparency = 0 }, 0.12)
                    tween(frameStroke, { Transparency = 0 }, 0.12)
                else
                    tween(frameStroke, { Color = Theme.StrokeHover }, 0.12)
                end
            end)
            frame.MouseLeave:Connect(function()
                if primary then
                    tween(frame, { BackgroundTransparency = 0.12 }, 0.2)
                    tween(frameStroke, { Transparency = 0.4 }, 0.2)
                else
                    tween(frameStroke, { Color = Theme.Stroke }, 0.2)
                end
            end)
            frame.MouseButton1Click:Connect(function()
                if chosen then
                    return
                end
                chosen = true
                callback()
            end)
        end
        -- A blocking card always keeps Exit, or it would have no button at all.
        if info.ExitText ~= false or info.Block then
            button(info.ExitText or "Exit", info.Block, 1, function()
                if info.Callback then
                    task.spawn(info.Callback, false)
                end
                tween(loader, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 12) }, 0.25, Enum.EasingStyle.Quint)
                tween(loaderShadow, { ImageTransparency = 1 }, 0.2)
                task.delay(0.25, function()
                    self:Destroy()
                end)
            end)
        end
        if not info.Block then
            button(info.ContinueText or "Continue", true, 2, function()
                if remember and info.Remember then
                    info.Remember()
                end
                if info.Callback then
                    task.spawn(info.Callback, true)
                end
                tween(warnCard, { GroupTransparency = 1 }, 0.15)
                task.delay(0.15, function()
                    warnCard:Destroy()
                    onContinue()
                end)
            end)
        end

        -- The card grows to fit the message, then it fades in. The wrapped
        -- height can land a few frames late (font loading, the scroller's
        -- layout), so the card refits whenever it changes.
        local laidOut = false
        -- TextBounds of wrapped text stops at the label's current height, so
        -- the card would fit to its own clipped text; the full wrapped height
        -- is measured at the body's width instead.
        local function measure()
            local ok, size = pcall(function()
                local params = Instance.new("GetTextBoundsParams")
                params.Text = body.Text
                params.Font = body.FontFace
                params.Size = body.TextSize
                params.Width = WIDTH - PAD * 2 - 8
                return game:GetService("TextService"):GetTextBoundsAsync(params)
            end)
            return ok and size and math.ceil(size.Y) + 2 or body.TextBounds.Y
        end
        local function fit(duration)
            local textHeight = math.max(measure(), 16)
            local bodyHeight = math.min(textHeight, MAX_BODY)
            body.Size = UDim2.new(1, -8, 0, textHeight)
            scroller.Size = UDim2.new(1, -PAD * 2, 0, bodyHeight)
            scroller.CanvasSize = UDim2.fromOffset(0, textHeight)
            local height = PAD + 60 + bodyHeight + 18 + 34 + PAD - 4
            if rememberRow then
                height += rememberRow.Size.Y.Offset + 10
            end
            tween(loader, { Size = UDim2.fromOffset(WIDTH, height) }, duration, Enum.EasingStyle.Quint)
        end
        body:GetPropertyChangedSignal("TextBounds"):Connect(function()
            if laidOut and loader.Parent and warnCard.Parent then
                fit(0.2)
            end
        end)
        task.delay(0.15, function()
            if not loader.Parent then
                return
            end
            laidOut = true
            fit(0.35)
            task.delay(0.12, function()
                tween(warnCard, { GroupTransparency = 0 }, 0.3)
                badge.Size = UDim2.fromOffset(34, 34)
                badge.Position = UDim2.fromOffset(PAD + 5, PAD + 5)
                tween(badge, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(PAD, PAD) }, 0.45, Enum.EasingStyle.Back)
            end)
        end)
    end

    local function runPrompts(queue, index)
        if not loader.Parent then
            return
        end
        local info = queue[index]
        if not info then
            finish()
            return
        end
        showCard(info, function()
            runPrompts(queue, index + 1)
        end)
    end

    task.delay(duration, function()
        tween(fill, { Size = UDim2.fromScale(1, 1) }, 0.25, Enum.EasingStyle.Quint)
        task.delay(0.25, function()
            if not loader.Parent then
                return
            end
            if opts._prompts then
                hideBar()
                runPrompts(opts._prompts, 1)
            else
                finish()
            end
        end)
    end)
end


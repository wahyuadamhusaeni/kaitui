-- The close button: asks first (unless CloseConfirm = false or `force`), then unloads.
function Window:Close(force)
    if self._destroyed then
        return
    end
    if force or not self._closeConfirm then
        self:Destroy()
        return
    end
    self:Confirm({
        Title = "Close " .. tostring(self.Title or "KaitUI") .. "?",
        Content = "The window closes, every toggle switches off and the script stops listening.",
        Icon = "power",
        ConfirmText = "Close",
        CancelText = "Keep open",
        Callback = function()
            self:Destroy()
        end,
    })
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    -- OnClose runs first, once, while everything still exists, however the window
    -- goes (the close button, a script's Destroy, or re-executing the script).
    -- _closing stops an OnClose that unloads (Destroy, KaitUI:Destroy) from recursing.
    if self._closing then
        return
    end
    self._closing = true
    if type(self._onClose) == "function" then
        safeCall(self._onClose)
    end
    self._destroyed = true
    for index, entry in ipairs(Library.Windows) do
        if entry == self then
            table.remove(Library.Windows, index)
            break
        end
    end
    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self._connections = {}
    self._inputListeners = { Began = {}, Changed = {}, Ended = {}, Render = {} }
    self._frameSteps = {}
    if self._pendingFlags then
        self._pendingFlags = {}
    end
    -- Switch this window's toggles off so their feature loops stop with it,
    -- instead of running on beside a re-executed copy.
    for _, element in ipairs(self._toggles or {}) do
        if not element._destroyed and element.Value == true then
            task.spawn(pcall, element.Set, element, false)
        end
    end
    -- The window's flags go with it, so a script can't switch a feature back on
    -- through KaitUI.Flags after unload, and a re-run registers them afresh.
    for flag, element in pairs(Library.Flags) do
        if element._window == self then
            Library.Flags[flag] = nil
        end
    end
    -- Overlays live outside the window body, so they go explicitly.
    for _, slot in ipairs({ "_watermark", "_keybindList" }) do
        local overlay = self[slot]
        if overlay then
            pcall(overlay.Destroy, overlay)
        end
    end
    local registry = Library._registry()
    if registry and registry[self._registryKey] == self then
        registry[self._registryKey] = nil
    end

    local gui = self.Gui
    local removed = false
    local function remove()
        if removed then
            return
        end
        removed = true
        if not pcall(gui.Destroy, gui) then
            pcall(function()
                gui.Enabled = false
            end)
        end
    end
    -- The fade out is decoration only. Input is already cut at this point, so
    -- if any of it fails the gui is removed straight away instead of being
    -- left frozen on screen.
    local ok, err = pcall(function()
        -- An open Confirm counts as cancelled, so a script waiting on it hears back.
        if self._dialog then
            (self._dialog.Cancel or self._dialog.Close)()
        end
        self:_closePopups()
        local fit = self._fitScale or 1
        tween(self.Scale, { Scale = fit * 0.92 }, 0.22, Enum.EasingStyle.Quint)
        self:_fade(1, 0.2)
        tween(self.BodyStroke, { Transparency = 1 }, 0.12)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
        if self.MiniBar and self.MiniBar.Visible then
            tween(self.MiniBar, { GroupTransparency = 1 }, 0.18)
        end
        if self._backdrop then
            -- Frame steps are already cut, so the weather stops where it is.
            self._weatherField.Visible = false
            tween(self._backdropTintFrame, { BackgroundTransparency = 1 }, 0.2)
            tween(self._backdropHeat, { BackgroundTransparency = 1 }, 0.2)
        end
        for _, button in ipairs({ self.ToggleButton or false, self.OpenButton or false }) do
            if typeof(button) == "Instance" and button:IsA("GuiObject") then
                tween(button, { Size = UDim2.fromOffset(0, 0) }, 0.2, Enum.EasingStyle.Quint)
            end
        end
    end)
    -- The last window gone: the trusted-call heartbeat goes too, so a closed or
    -- re-run script doesn't keep the old library alive through it.
    if #Library.Windows == 0 and Library._disconnectTrusted then
        Library._disconnectTrusted()
    end
    if not ok then
        warn("[KaitUI] unload animation failed, removing the window directly: " .. tostring(err))
        remove()
        return
    end
    task.delay(0.24, remove)
end

Window.Unload = Window.Destroy

-- Unloads every window the library created.
function Library:Destroy()
    for index = #Library.Windows, 1, -1 do
        local window = Library.Windows[index]
        if window then
            window:Destroy()
        end
    end
    if Library._disconnectTrusted then
        Library._disconnectTrusted()
    end
end

Library.Unload = Library.Destroy

-- A script thread that yielded inside an engine call (InvokeServer and the
-- like) resumes at game identity and can no longer touch the GUI in CoreGui.
-- Every public call checks for that: it raises the thread back to the identity
-- the library loaded at, or, when the executor cannot, runs the call on a
-- trusted Heartbeat thread and waits for its result.
local getIdentity = getthreadidentity or getidentity or get_thread_identity or (syn and syn.get_thread_identity)
local setIdentity = setthreadidentity or setidentity or set_thread_identity or (syn and syn.set_thread_identity)
local loadIdentity = nil
if getIdentity then
    local ok, identity = pcall(getIdentity)
    if ok and type(identity) == "number" then
        loadIdentity = identity
    end
end


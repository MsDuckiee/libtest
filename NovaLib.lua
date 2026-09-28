--[[
    ✦ NovaLib v2.0 — "Aurora"
    A ground-up rewrite. Not an Orion clone.

    What's different:
      • Spring/tween animation core — everything eases, presses, ripples
      • Glass UI with animated accent gradient + sliding tab pill
      • Real notification system (types, progress, swipe-to-dismiss, actions, queue)
      • First-class mobile: touch drag, auto-scale, launcher button, bottom-sheet dropdowns
      • Command Palette (Ctrl+K / palette button) — search & jump to any element
      • Live accent + theme switching, config PROFILES (save / load / delete)
      • Dialogs, MultiDropdown, ProgressBar, Stepper, Keybind list, HUD watermark,
        element Lock / Hide / Tooltip / Badge, and more

    Public API kept compatible with the old example:
      NovaLib:MakeWindow / Window:MakeTab / Tab:AddSection / Section:AddToggle ...
]]

--// Services
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local GuiService       = game:GetService("GuiService")
local Stats            = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

--// Library table
local NovaLib = {
    Version   = "2.0.0",
    Flags     = {},
    Themes    = {},
    Connections = {},
    Windows   = {},
    Folder    = "NovaLib",
    SaveCfg   = false,
    ToggleKey = Enum.KeyCode.RightShift,
    Accent    = Color3.fromRGB(120, 140, 255),
    Accent2   = Color3.fromRGB(190, 120, 255),
    IsMobile  = false,
}

--// ------------------------------------------------------------------
--//  THEMES
--// ------------------------------------------------------------------
NovaLib.Themes = {
    Default = {
        Background = Color3.fromRGB(14, 14, 20),
        Surface    = Color3.fromRGB(22, 22, 31),
        Elevated   = Color3.fromRGB(30, 30, 42),
        Stroke     = Color3.fromRGB(52, 52, 72),
        Text       = Color3.fromRGB(240, 241, 250),
        SubText    = Color3.fromRGB(150, 152, 175),
        Accent     = Color3.fromRGB(120, 140, 255),
        Accent2    = Color3.fromRGB(190, 120, 255),
    },
    Midnight = {
        Background = Color3.fromRGB(8, 8, 13),
        Surface    = Color3.fromRGB(15, 15, 22),
        Elevated   = Color3.fromRGB(23, 23, 33),
        Stroke     = Color3.fromRGB(40, 40, 58),
        Text       = Color3.fromRGB(232, 234, 246),
        SubText    = Color3.fromRGB(130, 132, 155),
        Accent     = Color3.fromRGB(90, 170, 255),
        Accent2    = Color3.fromRGB(120, 110, 255),
    },
    Ocean = {
        Background = Color3.fromRGB(10, 18, 30),
        Surface    = Color3.fromRGB(17, 28, 44),
        Elevated   = Color3.fromRGB(25, 40, 62),
        Stroke     = Color3.fromRGB(46, 72, 105),
        Text       = Color3.fromRGB(230, 242, 252),
        SubText    = Color3.fromRGB(135, 162, 190),
        Accent     = Color3.fromRGB(60, 200, 230),
        Accent2    = Color3.fromRGB(70, 130, 255),
    },
    Rose = {
        Background = Color3.fromRGB(22, 13, 20),
        Surface    = Color3.fromRGB(33, 20, 30),
        Elevated   = Color3.fromRGB(46, 29, 42),
        Stroke     = Color3.fromRGB(82, 52, 74),
        Text       = Color3.fromRGB(252, 240, 248),
        SubText    = Color3.fromRGB(178, 148, 170),
        Accent     = Color3.fromRGB(255, 110, 165),
        Accent2    = Color3.fromRGB(255, 160, 110),
    },
    Forest = {
        Background = Color3.fromRGB(11, 20, 15),
        Surface    = Color3.fromRGB(18, 31, 23),
        Elevated   = Color3.fromRGB(26, 44, 33),
        Stroke     = Color3.fromRGB(48, 80, 60),
        Text       = Color3.fromRGB(236, 247, 240),
        SubText    = Color3.fromRGB(140, 168, 150),
        Accent     = Color3.fromRGB(90, 220, 140),
        Accent2    = Color3.fromRGB(170, 230, 90),
    },
    Sunset = {
        Background = Color3.fromRGB(22, 14, 16),
        Surface    = Color3.fromRGB(34, 21, 23),
        Elevated   = Color3.fromRGB(48, 30, 32),
        Stroke     = Color3.fromRGB(86, 54, 56),
        Text       = Color3.fromRGB(252, 242, 238),
        SubText    = Color3.fromRGB(180, 152, 148),
        Accent     = Color3.fromRGB(255, 130, 80),
        Accent2    = Color3.fromRGB(255, 200, 80),
    },
    Light = {
        Background = Color3.fromRGB(244, 245, 250),
        Surface    = Color3.fromRGB(255, 255, 255),
        Elevated   = Color3.fromRGB(236, 238, 246),
        Stroke     = Color3.fromRGB(205, 208, 224),
        Text       = Color3.fromRGB(28, 30, 44),
        SubText    = Color3.fromRGB(110, 114, 140),
        Accent     = Color3.fromRGB(88, 104, 240),
        Accent2    = Color3.fromRGB(160, 92, 240),
    },
}
NovaLib.ThemeName = "Default"

--// Notification type palette
local TypeColors = {
    Info    = Color3.fromRGB(96, 150, 255),
    Success = Color3.fromRGB(80, 214, 140),
    Warning = Color3.fromRGB(255, 190, 70),
    Error   = Color3.fromRGB(255, 92, 100),
}
local TypeIcons = {
    Info    = "rbxassetid://7072706796",  -- info
    Success = "rbxassetid://7072706620",  -- check
    Warning = "rbxassetid://7072717857",  -- alert
    Error   = "rbxassetid://7072725342",  -- x
}

--// ------------------------------------------------------------------
--//  ENVIRONMENT DETECTION
--// ------------------------------------------------------------------
NovaLib.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function ProtectedParent(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
        gui.Parent = game:GetService("CoreGui")
    elseif gethui then
        gui.Parent = gethui()
    else
        local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not ok or not gui.Parent then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end

--// ------------------------------------------------------------------
--//  ICONS (lucide) — with safe fallback
--// ------------------------------------------------------------------
local Icons = {}
pcall(function()
    Icons = HttpService:JSONDecode(game:HttpGetAsync(
        "https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json"
    )).icons
end)

local function ResolveIcon(name)
    if not name or name == "" then return "" end
    if Icons[name] then return Icons[name] end
    if tostring(name):find("rbxassetid") or tostring(name):find("http") then return name end
    if tonumber(name) then return "rbxassetid://" .. tostring(name) end
    return ""
end

--// ------------------------------------------------------------------
--//  ROOT GUI
--// ------------------------------------------------------------------
local Root = Instance.new("ScreenGui")
Root.Name = "NovaLib_Aurora"
Root.ResetOnSpawn = false
Root.IgnoreGuiInset = true
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.DisplayOrder = 999
ProtectedParent(Root)

do
    local parent = Root.Parent
    if parent then
        for _, g in ipairs(parent:GetChildren()) do
            if g.Name == "NovaLib_Aurora" and g ~= Root then g:Destroy() end
        end
    end
end

local Alive = true
function NovaLib:IsRunning() return Alive and Root.Parent ~= nil end

--// ------------------------------------------------------------------
--//  CORE HELPERS
--// ------------------------------------------------------------------
local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(NovaLib.Connections, c)
    return c
end

local function Tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local EASE = {
    Fast   = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Med    = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Slow   = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Spring = TweenInfo.new(0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
    Pop    = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out, 0, false, 0),
    In     = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
    Linear = function(t) return TweenInfo.new(t, Enum.EasingStyle.Linear) end,
}

local function New(class, props, children)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then o[k] = v end
        end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = o end
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function Corner(r, parent)
    return New("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = parent})
end

local function Stroke(color, thick, transp, parent)
    return New("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thick or 1,
        Transparency = transp or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Padding(t, r, b, l, parent)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
        Parent = parent,
    })
end

local function List(pad, parent, dir, ha, va)
    return New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, pad or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
        VerticalAlignment = va or Enum.VerticalAlignment.Top,
        Parent = parent,
    })
end

local function Gradient(c1, c2, rot, parent)
    return New("UIGradient", {
        Color = ColorSequence.new(c1, c2),
        Rotation = rot or 0,
        Parent = parent,
    })
end

local function Text(props)
    local p = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = true,
        BorderSizePixel = 0,
    }
    for k, v in pairs(props) do p[k] = v end
    return New("TextLabel", p)
end

local function Clamp(n, a, b) return math.max(a, math.min(b, n)) end
local function Snap(n, inc)
    if not inc or inc <= 0 then return n end
    return math.floor(n / inc + 0.5) * inc
end
local function Round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end
local function Lerp(a, b, t) return a + (b - a) * t end

local function IsPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end
local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

--// ------------------------------------------------------------------
--//  THEME BINDING (reactive)
--// ------------------------------------------------------------------
local Bindings = {}   -- { {obj=, prop=, key=, [transform]=} }

local function ThemeColor(key)
    return NovaLib.Themes[NovaLib.ThemeName][key] or Color3.new(1, 1, 1)
end

local function Bind(obj, prop, key, transform)
    table.insert(Bindings, {obj = obj, prop = prop, key = key, fn = transform})
    local v = ThemeColor(key)
    if transform then v = transform(v) end
    obj[prop] = v
    return obj
end

local function ApplyTheme(animated)
    for i = #Bindings, 1, -1 do
        local b = Bindings[i]
        -- Alive check: an instance is live if it is Root itself or still inside Root.
        -- (gethui() containers are not always under `game`, so don't test against game.)
        if not b.obj or not (b.obj == Root or b.obj:IsDescendantOf(Root)) then
            table.remove(Bindings, i)
        else
            local v = ThemeColor(b.key)
            if b.fn then v = b.fn(v) end
            local ok = pcall(function()
                if animated then
                    Tween(b.obj, EASE.Med, {[b.prop] = v})
                else
                    b.obj[b.prop] = v
                end
            end)
            if not ok then table.remove(Bindings, i) end
        end
    end
end

-- Accent-bound gradients need their own tracking
local AccentGradients = {}
local function AccentGrad(parent, rot)
    local g = Gradient(ThemeColor("Accent"), ThemeColor("Accent2"), rot or 0, parent)
    table.insert(AccentGradients, g)
    return g
end

local function RefreshAccents()
    for i = #AccentGradients, 1, -1 do
        local g = AccentGradients[i]
        if g and g.Parent then
            g.Color = ColorSequence.new(NovaLib.Accent, NovaLib.Accent2)
        else
            table.remove(AccentGradients, i)
        end
    end
end

-- Accent-bound solid colors
local AccentObjs = {}
local function BindAccent(obj, prop, which)
    table.insert(AccentObjs, {obj = obj, prop = prop, which = which or 1})
    obj[prop] = (which == 2) and NovaLib.Accent2 or NovaLib.Accent
    return obj
end

local function RefreshAccentObjs(animated)
    for i = #AccentObjs, 1, -1 do
        local a = AccentObjs[i]
        if a.obj and a.obj.Parent then
            local c = (a.which == 2) and NovaLib.Accent2 or NovaLib.Accent
            if animated then Tween(a.obj, EASE.Med, {[a.prop] = c}) else a.obj[a.prop] = c end
        else
            table.remove(AccentObjs, i)
        end
    end
end

function NovaLib:SetTheme(name)
    if not NovaLib.Themes[name] then return end
    NovaLib.ThemeName = name
    local t = NovaLib.Themes[name]
    NovaLib.Accent  = t.Accent
    NovaLib.Accent2 = t.Accent2
    ApplyTheme(true)
    RefreshAccents()
    RefreshAccentObjs(true)
end

function NovaLib:SetAccent(c1, c2)
    NovaLib.Accent = c1
    NovaLib.Accent2 = c2 or c1
    RefreshAccents()
    RefreshAccentObjs(true)
end

function NovaLib:GetThemes()
    local list = {}
    for n in pairs(NovaLib.Themes) do table.insert(list, n) end
    table.sort(list)
    return list
end

function NovaLib:AddTheme(name, data)
    -- fill missing keys from Default so partial themes still work
    local base = NovaLib.Themes.Default
    for k, v in pairs(base) do
        if data[k] == nil then data[k] = v end
    end
    NovaLib.Themes[name] = data
end

--// ------------------------------------------------------------------
--//  RIPPLE + PRESS FEEDBACK
--// ------------------------------------------------------------------
local function Ripple(button, x, y)
    if not button or not button.Parent then return end
    local abs = button.AbsolutePosition
    local size = button.AbsoluteSize
    local rx = (x and (x - abs.X)) or size.X / 2
    local ry = (y and (y - abs.Y)) or size.Y / 2
    local maxDim = math.max(size.X, size.Y) * 2.2

    local holder = button:FindFirstChild("_RippleHolder")
    if not holder then
        holder = New("Frame", {
            Name = "_RippleHolder", BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true,
            ZIndex = button.ZIndex + 5, Parent = button,
        })
        local cr = button:FindFirstChildOfClass("UICorner")
        if cr then Corner(cr.CornerRadius.Offset, holder) end
    end

    local r = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.82,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(rx, ry),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = holder.ZIndex, Parent = holder,
    })
    Corner(1000, r)
    Tween(r, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {
        Size = UDim2.fromOffset(maxDim, maxDim),
        BackgroundTransparency = 1,
    })
    task.delay(0.6, function() if r then r:Destroy() end end)
end

--// Clickable area with hover / press hooks that work for mouse AND touch
local function Interactive(button, hooks)
    hooks = hooks or {}
    local hovering, pressing = false, false

    Connect(button.MouseEnter, function()
        hovering = true
        if hooks.Hover then hooks.Hover(true) end
    end)
    Connect(button.MouseLeave, function()
        hovering = false
        if pressing then pressing = false; if hooks.Press then hooks.Press(false) end end
        if hooks.Hover then hooks.Hover(false) end
    end)
    Connect(button.InputBegan, function(input)
        if IsPointer(input) then
            pressing = true
            if hooks.Press then hooks.Press(true, input) end
            if hooks.Ripple ~= false then Ripple(button, input.Position.X, input.Position.Y) end
        end
    end)
    Connect(button.InputEnded, function(input)
        if IsPointer(input) then
            if pressing then
                pressing = false
                if hooks.Press then hooks.Press(false, input) end
            end
            if input.UserInputType == Enum.UserInputType.Touch then
                if hooks.Hover then hooks.Hover(false) end
            end
        end
    end)
    Connect(button.Activated, function()
        if hooks.Click then hooks.Click() end
    end)
end

--// ------------------------------------------------------------------
--//  DRAGGING (mouse + touch, smoothed)
--// ------------------------------------------------------------------
local function MakeDraggable(handle, target, opts)
    opts = opts or {}
    local dragging, startPos, startFrame, dragInput = false, nil, nil, nil
    local goal = target.Position
    local smooth = opts.Smooth ~= false

    Connect(handle.InputBegan, function(input)
        if IsPointer(input) then
            dragging = true
            startPos = input.Position
            startFrame = target.Position
            goal = startFrame
            if opts.OnStart then opts.OnStart() end
            local ended
            ended = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if ended then ended:Disconnect() end
                    if opts.OnEnd then opts.OnEnd() end
                end
            end)
        end
    end)
    Connect(handle.InputChanged, function(input)
        if IsMove(input) then dragInput = input end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startPos
            goal = UDim2.new(
                startFrame.X.Scale, startFrame.X.Offset + d.X,
                startFrame.Y.Scale, startFrame.Y.Offset + d.Y
            )
        end
    end)

    -- smooth follow
    Connect(RunService.RenderStepped, function(dt)
        if not target.Parent then return end
        if smooth then
            local a = 1 - math.exp(-22 * dt)
            local cur = target.Position
            target.Position = UDim2.new(
                cur.X.Scale + (goal.X.Scale - cur.X.Scale) * a,
                cur.X.Offset + (goal.X.Offset - cur.X.Offset) * a,
                cur.Y.Scale + (goal.Y.Scale - cur.Y.Scale) * a,
                cur.Y.Offset + (goal.Y.Offset - cur.Y.Offset) * a
            )
        elseif dragging then
            target.Position = goal
        end
    end)

    return function() return dragging end
end

--// ------------------------------------------------------------------
--//  SHADOW
--// ------------------------------------------------------------------
local function Shadow(parent, radius, transp)
    local s = New("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = transp or 0.55,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 4),
        Size = UDim2.new(1, radius or 40, 1, radius or 40),
        ZIndex = math.max(0, parent.ZIndex - 1),
        Parent = parent,
    })
    return s
end

--// ------------------------------------------------------------------
--//  NOTIFICATION SYSTEM  (the big one)
--// ------------------------------------------------------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.new(0, 340, 1, -32),
    ZIndex = 200,
    Parent = Root,
})
local NotifLayout = List(10, NotifHolder, Enum.FillDirection.Vertical,
    Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder

local NotifCount = 0
local ActiveNotifs = {}
local NotifQueue = {}
local MAX_NOTIFS = 5

local function UpdateNotifPlacement()
    if NovaLib.IsMobile then
        NotifHolder.AnchorPoint = Vector2.new(0.5, 0)
        NotifHolder.Position = UDim2.new(0.5, 0, 0, 12)
        NotifHolder.Size = UDim2.new(1, -24, 1, -24)
        NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    end
end
UpdateNotifPlacement()

local ShowNotification -- forward

local function DismissNotif(n, instant)
    if n.Dead then return end
    n.Dead = true
    for i, v in ipairs(ActiveNotifs) do
        if v == n then table.remove(ActiveNotifs, i) break end
    end
    local goalX = NovaLib.IsMobile and 0 or 380
    local goalY = NovaLib.IsMobile and -120 or 0
    if instant then
        n.Wrapper:Destroy()
    else
        Tween(n.Card, EASE.In, {
            Position = UDim2.new(0, goalX, 0, goalY),
            GroupTransparency = 1,
        })
        Tween(n.Wrapper, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0.12), {
            Size = UDim2.new(1, 0, 0, 0),
        })
        task.delay(0.55, function()
            if n.Wrapper then n.Wrapper:Destroy() end
        end)
    end
    if n.OnClose then task.spawn(n.OnClose) end
    -- pull from queue
    task.defer(function()
        local nextCfg = table.remove(NotifQueue, 1)
        if nextCfg then ShowNotification(nextCfg) end
    end)
end

ShowNotification = function(cfg)
    local ntype = cfg.Type or "Info"
    local accent = cfg.Color or TypeColors[ntype] or TypeColors.Info
    local duration = cfg.Time or cfg.Duration or 5
    local sticky = (duration <= 0) or cfg.Sticky

    NotifCount += 1
    local n = {Dead = false, Paused = false, OnClose = cfg.OnClose}

    -- wrapper collapses smoothly so siblings glide into place
    local wrapper = New("Frame", {
        Name = "Notif_" .. NotifCount,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        LayoutOrder = NotifCount,
        ClipsDescendants = false,
        ZIndex = 201,
        Parent = NotifHolder,
    })
    n.Wrapper = wrapper

    local card = New("CanvasGroup", {
        Name = "Card",
        BackgroundColor3 = ThemeColor("Surface"),
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, NovaLib.IsMobile and 0 or 380, 0, NovaLib.IsMobile and -80 or 0),
        GroupTransparency = 1,
        ZIndex = 202,
        Parent = wrapper,
    })
    n.Card = card
    Corner(14, card)
    Stroke(accent, 1.2, 0.55, card)
    Bind(card, "BackgroundColor3", "Surface")

    -- soft accent glow behind the card edge
    local glow = New("Frame", {
        Name = "Glow", BackgroundColor3 = accent, BackgroundTransparency = 0.88,
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 202, Parent = card,
    })
    Gradient(Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0, glow).Transparency =
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.55, 0.85),
            NumberSequenceKeypoint.new(1, 1),
        })

    -- accent rail
    local rail = New("Frame", {
        Name = "Rail", BackgroundColor3 = accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 4, 1, 0), ZIndex = 205, Parent = card,
    })

    -- icon badge
    local badge = New("Frame", {
        Name = "Badge", BackgroundColor3 = accent, BackgroundTransparency = 0.82,
        Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(18, 14),
        BorderSizePixel = 0, ZIndex = 205, Parent = card,
    })
    Corner(10, badge)
    local iconImg = cfg.Image and ResolveIcon(cfg.Image) or TypeIcons[ntype]
    if iconImg == "" then iconImg = TypeIcons[ntype] end
    local icon = New("ImageLabel", {
        BackgroundTransparency = 1, Image = iconImg, ImageColor3 = accent,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0), ZIndex = 206, Parent = badge,
    })

    -- title
    local title = Text({
        Name = "Title", Text = cfg.Name or cfg.Title or ntype,
        Font = Enum.Font.GothamBold, TextSize = 15,
        Position = UDim2.fromOffset(62, 12), Size = UDim2.new(1, -108, 0, 18),
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 205, Parent = card,
    })
    Bind(title, "TextColor3", "Text")

    -- content
    local content = Text({
        Name = "Content", Text = cfg.Content or cfg.Message or "",
        Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(62, 32),
        Size = UDim2.new(1, -78, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 205, Parent = card,
    })
    Bind(content, "TextColor3", "SubText")

    -- close button
    local closeBtn = New("TextButton", {
        Name = "Close", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0, 10), ZIndex = 207, Parent = card,
    })
    local closeIco = New("ImageLabel", {
        BackgroundTransparency = 1, Image = "rbxassetid://7072725342",
        ImageTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
        ZIndex = 208, Parent = closeBtn,
    })
    Bind(closeIco, "ImageColor3", "Text")
    Connect(closeBtn.MouseEnter, function() Tween(closeIco, EASE.Fast, {ImageTransparency = 0, Size = UDim2.fromOffset(16, 16)}) end)
    Connect(closeBtn.MouseLeave, function() Tween(closeIco, EASE.Fast, {ImageTransparency = 0.5, Size = UDim2.fromOffset(14, 14)}) end)
    Connect(closeBtn.Activated, function() DismissNotif(n) end)

    -- action buttons
    local actionsY = 0
    local hasActions = cfg.Actions and #cfg.Actions > 0
    local actionRow
    if hasActions then
        actionRow = New("Frame", {
            Name = "Actions", BackgroundTransparency = 1,
            Size = UDim2.new(1, -78, 0, 30), ZIndex = 205, Parent = card,
        })
        List(8, actionRow, Enum.FillDirection.Horizontal)
        for _, act in ipairs(cfg.Actions) do
            local b = New("TextButton", {
                Text = act.Name or act.Text or "Action", AutoButtonColor = false,
                Font = Enum.Font.GothamBold, TextSize = 12,
                BackgroundColor3 = accent, BackgroundTransparency = 0.82,
                TextColor3 = accent, Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X, ZIndex = 206, Parent = actionRow,
            })
            Corner(8, b); Padding(0, 14, 0, 14, b)
            Connect(b.MouseEnter, function() Tween(b, EASE.Fast, {BackgroundTransparency = 0.6}) end)
            Connect(b.MouseLeave, function() Tween(b, EASE.Fast, {BackgroundTransparency = 0.82}) end)
            Connect(b.Activated, function()
                Ripple(b)
                if act.Callback then task.spawn(act.Callback) end
                if act.Dismiss ~= false then DismissNotif(n) end
            end)
        end
    end

    -- progress bar (time remaining)
    local progress
    if not sticky then
        local pTrack = New("Frame", {
            Name = "ProgressTrack", BackgroundColor3 = accent, BackgroundTransparency = 0.9,
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), ZIndex = 206, Parent = card,
        })
        progress = New("Frame", {
            Name = "Progress", BackgroundColor3 = accent, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 207, Parent = pTrack,
        })
        AccentGrad(progress, 0)
        progress.BackgroundColor3 = Color3.new(1, 1, 1)
        local gr = progress:FindFirstChildOfClass("UIGradient")
        if gr then gr.Color = ColorSequence.new(accent, accent:Lerp(Color3.new(1, 1, 1), 0.35)) end
        n.Progress = progress
    end

    -- measure + size the card once layout settles
    local function Resize()
        -- Single source of truth: everything hangs off where the body text ends.
        local bodyBottom = 32 + content.AbsoluteSize.Y          -- content starts at y=32
        local h = bodyBottom + 14
        if hasActions then
            actionRow.Position = UDim2.fromOffset(62, bodyBottom + 10)
            h = bodyBottom + 10 + 30 + 14                       -- gap + button row + padding
        end
        h = math.max(h, 64)
        card.Size = UDim2.new(1, 0, 0, h)
        Tween(wrapper, EASE.Spring, {Size = UDim2.new(1, 0, 0, h)})
        return h
    end

    task.defer(function()
        RunService.RenderStepped:Wait()
        if n.Dead then return end
        Resize()
        -- entrance
        Tween(card, EASE.Spring, {
            Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0,
        })
        Tween(icon, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.1), {
            Size = UDim2.fromOffset(18, 18),
        })
        -- gentle badge pulse
        task.delay(0.35, function()
            if n.Dead then return end
            Tween(badge, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
                BackgroundTransparency = 0.7,
            })
        end)
    end)

    -- hover pause + swipe to dismiss
    local swiping, swipeStart, swipeInput = false, nil, nil
    Connect(card.MouseEnter, function()
        n.Paused = true
        Tween(card, EASE.Fast, {BackgroundTransparency = 0})
    end)
    Connect(card.MouseLeave, function()
        n.Paused = false
        Tween(card, EASE.Fast, {BackgroundTransparency = 0.04})
    end)
    Connect(card.InputBegan, function(input)
        if IsPointer(input) then
            swiping = true
            swipeStart = input.Position
            n.Paused = true
            local e; e = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    e:Disconnect()
                    swiping = false
                    n.Paused = false
                    local dx = (swipeInput and swipeStart) and (swipeInput.Position.X - swipeStart.X) or 0
                    local dy = (swipeInput and swipeStart) and (swipeInput.Position.Y - swipeStart.Y) or 0
                    local far = NovaLib.IsMobile and (math.abs(dy) > 45 and dy < 0 or math.abs(dx) > 90) or dx > 90
                    if far and not n.Dead then
                        DismissNotif(n)
                    elseif not n.Dead then
                        Tween(card, EASE.Spring, {Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0})
                    end
                end
            end)
        end
    end)
    Connect(card.InputChanged, function(input)
        if IsMove(input) then swipeInput = input end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if swiping and swipeStart and input == swipeInput and not n.Dead then
            local dx = input.Position.X - swipeStart.X
            local dy = input.Position.Y - swipeStart.Y
            if NovaLib.IsMobile and math.abs(dy) > math.abs(dx) then
                local off = math.min(dy, 0)
                card.Position = UDim2.new(0, 0, 0, off)
                card.GroupTransparency = Clamp(-off / 100, 0, 0.8)
            else
                local off = math.max(dx, 0)
                card.Position = UDim2.new(0, off, 0, 0)
                card.GroupTransparency = Clamp(off / 240, 0, 0.8)
            end
        end
    end)

    -- countdown
    if not sticky then
        task.spawn(function()
            local elapsed = 0
            while elapsed < duration and not n.Dead and Alive do
                local dt = RunService.Heartbeat:Wait()
                if not n.Paused then
                    elapsed += dt
                    if progress then
                        progress.Size = UDim2.new(Clamp(1 - elapsed / duration, 0, 1), 0, 1, 0)
                    end
                end
            end
            if not n.Dead then DismissNotif(n) end
        end)
    end

    -- click-to-run
    if cfg.Callback then
        Connect(card.InputEnded, function(input)
            if IsPointer(input) and not n.Dead and swipeInput then
                local moved = swipeStart and (swipeInput.Position - swipeStart).Magnitude or 0
                if moved < 6 then task.spawn(cfg.Callback) end
            end
        end)
    end

    table.insert(ActiveNotifs, n)

    -- Handle for the caller (update / dismiss live)
    local handle = {}
    function handle:Dismiss() DismissNotif(n) end
    function handle:SetTitle(t) title.Text = t end
    function handle:SetContent(t) content.Text = t; task.defer(Resize) end
    function handle:SetProgress(p)
        if n.Progress then n.Progress.Size = UDim2.new(Clamp(p, 0, 1), 0, 1, 0) end
    end
    return handle
end

function NovaLib:MakeNotification(cfg)
    cfg = cfg or {}
    if #ActiveNotifs >= MAX_NOTIFS then
        table.insert(NotifQueue, cfg)
        return nil
    end
    return ShowNotification(cfg)
end
function NovaLib:Notify(cfg) return NovaLib:MakeNotification(cfg) end
function NovaLib:SetMaxNotifications(n) MAX_NOTIFS = math.max(1, n) end
function NovaLib:ClearNotifications()
    table.clear(NotifQueue)
    for i = #ActiveNotifs, 1, -1 do DismissNotif(ActiveNotifs[i]) end
end

--// ------------------------------------------------------------------
--//  DIALOG (modal)
--// ------------------------------------------------------------------
function NovaLib:Dialog(cfg)
    cfg = cfg or {}
    local accent = cfg.Color or NovaLib.Accent

    local dim = New("TextButton", {
        Name = "DialogDim", Text = "", AutoButtonColor = false,
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = Root,
    })
    Tween(dim, EASE.Med, {BackgroundTransparency = 0.45})

    local box = New("CanvasGroup", {
        BackgroundColor3 = ThemeColor("Surface"),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(NovaLib.IsMobile and 300 or 360, 0),
        AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1,
        BorderSizePixel = 0, ZIndex = 301, Parent = dim,
    })
    Corner(16, box); Stroke(ThemeColor("Stroke"), 1.2, 0.2, box)
    Bind(box, "BackgroundColor3", "Surface")
    local scale = New("UIScale", {Scale = 0.86, Parent = box})
    Padding(20, 20, 18, 20, box)
    List(10, box)

    local top = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 3), LayoutOrder = 0, ZIndex = 302, Parent = box})
    -- (spacer rail)
    local title = Text({
        Text = cfg.Title or cfg.Name or "Confirm", Font = Enum.Font.GothamBold, TextSize = 18,
        Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, ZIndex = 302, Parent = box,
    })
    Bind(title, "TextColor3", "Text")
    local body = Text({
        Text = cfg.Content or "", Font = Enum.Font.Gotham, TextSize = 14, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2, ZIndex = 302, Parent = box,
    })
    Bind(body, "TextColor3", "SubText")

    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3, ZIndex = 302, Parent = box})
    List(10, row, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

    local closed = false
    local function Close()
        if closed then return end
        closed = true
        Tween(box, EASE.In, {GroupTransparency = 1})
        Tween(scale, EASE.In, {Scale = 0.92})
        Tween(dim, EASE.In, {BackgroundTransparency = 1})
        task.delay(0.3, function() dim:Destroy() end)
    end

    local buttons = cfg.Buttons or {{Name = "OK", Primary = true}}
    for _, bd in ipairs(buttons) do
        local b = New("TextButton", {
            Text = bd.Name or "OK", AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 13,
            Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = 303, Parent = row,
        })
        Corner(10, b); Padding(0, 20, 0, 20, b)
        if bd.Primary then
            b.BackgroundColor3 = Color3.new(1, 1, 1)
            b.TextColor3 = Color3.new(1, 1, 1)
            AccentGrad(b, 25)
        else
            b.BackgroundTransparency = 0
            Bind(b, "BackgroundColor3", "Elevated")
            Bind(b, "TextColor3", "Text")
        end
        Connect(b.MouseEnter, function() Tween(b, EASE.Fast, {Size = UDim2.new(0, b.AbsoluteSize.X, 1, 2)}) end)
        Connect(b.MouseLeave, function() Tween(b, EASE.Fast, {Size = UDim2.new(0, 0, 1, 0)}) end)
        Connect(b.Activated, function()
            Ripple(b)
            if bd.Callback then task.spawn(bd.Callback) end
            Close()
        end)
    end

    Connect(dim.Activated, function() if cfg.DismissOutside ~= false then Close() end end)
    Tween(box, EASE.Spring, {GroupTransparency = 0})
    Tween(scale, EASE.Spring, {Scale = 1})
    return {Close = Close}
end

--// ------------------------------------------------------------------
--//  TOOLTIP (single shared instance)
--// ------------------------------------------------------------------
local Tooltip = New("CanvasGroup", {
    Name = "Tooltip", BackgroundColor3 = ThemeColor("Elevated"),
    Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X,
    GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 400, Visible = false, Parent = Root,
})
Corner(8, Tooltip); Stroke(ThemeColor("Stroke"), 1, 0.2, Tooltip)
Bind(Tooltip, "BackgroundColor3", "Elevated")
Padding(0, 10, 0, 10, Tooltip)
local TooltipLabel = Text({
    Text = "", Font = Enum.Font.Gotham, TextSize = 12,
    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 401, Parent = Tooltip,
})
Bind(TooltipLabel, "TextColor3", "Text")

local tipToken = 0
local function AttachTooltip(gui, text)
    if not text or text == "" or NovaLib.IsMobile then return end
    Connect(gui.MouseEnter, function()
        tipToken += 1
        local my = tipToken
        task.delay(0.45, function()
            if my ~= tipToken then return end
            TooltipLabel.Text = text
            Tooltip.Visible = true
            Tween(Tooltip, EASE.Fast, {GroupTransparency = 0})
        end)
    end)
    Connect(gui.MouseLeave, function()
        tipToken += 1
        Tween(Tooltip, EASE.Fast, {GroupTransparency = 1})
        task.delay(0.2, function() if Tooltip.GroupTransparency >= 0.99 then Tooltip.Visible = false end end)
    end)
end
Connect(UserInputService.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and Tooltip.Visible then
        Tooltip.Position = UDim2.fromOffset(input.Position.X + 16, input.Position.Y + 20)
    end
end)

--// ------------------------------------------------------------------
--//  CONFIG SYSTEM (profiles)
--// ------------------------------------------------------------------
local function Pack(v)
    if typeof(v) == "Color3" then
        return {__t = "C3", R = math.floor(v.R * 255 + 0.5), G = math.floor(v.G * 255 + 0.5), B = math.floor(v.B * 255 + 0.5)}
    elseif typeof(v) == "EnumItem" then
        return {__t = "Enum", Type = tostring(v.EnumType), Name = v.Name}
    elseif typeof(v) == "table" then
        local out = {}
        for k, x in pairs(v) do out[k] = Pack(x) end
        return out
    end
    return v
end
local function Unpack(v)
    if type(v) == "table" then
        if v.__t == "C3" then return Color3.fromRGB(v.R, v.G, v.B) end
        if v.__t == "Enum" then
            local ok, r = pcall(function() return Enum[v.Type:gsub("Enum%.", "")][v.Name] end)
            return ok and r or nil
        end
        local out = {}
        for k, x in pairs(v) do out[k] = Unpack(x) end
        return out
    end
    return v
end

local function CfgPath(name) return NovaLib.Folder .. "/" .. name .. ".json" end

function NovaLib:SaveConfig(name)
    if not writefile then return false, "writefile unavailable" end
    local data = {}
    for flag, obj in pairs(NovaLib.Flags) do
        if obj.Save == true and obj.Value ~= nil then data[flag] = Pack(obj.Value) end
    end
    local ok, err = pcall(function()
        if not isfolder(NovaLib.Folder) then makefolder(NovaLib.Folder) end
        writefile(CfgPath(name), HttpService:JSONEncode(data))
    end)
    return ok, err
end

function NovaLib:LoadConfig(name)
    if not (isfile and readfile) then return false, "readfile unavailable" end
    local ok, raw = pcall(readfile, CfgPath(name))
    if not ok then return false, "config not found" end
    local dec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not dec then return false, "corrupt config" end
    for flag, val in pairs(data) do
        local obj = NovaLib.Flags[flag]
        if obj and obj.Set then
            -- silent=false on purpose: loading a config must re-fire callbacks so the script's
            -- state (walkspeed, esp, ...) actually matches what the UI now shows.
            task.spawn(function() pcall(obj.Set, obj, Unpack(val), false) end)
        end
    end
    return true
end

function NovaLib:DeleteConfig(name)
    if not delfile then return false end
    return pcall(delfile, CfgPath(name))
end

function NovaLib:ListConfigs()
    local out = {}
    if not (listfiles and isfolder) then return out end
    pcall(function()
        if not isfolder(NovaLib.Folder) then return end
        for _, f in ipairs(listfiles(NovaLib.Folder)) do
            local n = f:match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end)
    table.sort(out)
    return out
end

function NovaLib:Init()
    if NovaLib.SaveCfg then
        local ok = NovaLib:LoadConfig("autoload")
        if ok then
            NovaLib:MakeNotification({
                Name = "Config Loaded", Content = "Restored your last session.",
                Type = "Success", Time = 3,
            })
        end
    end
end

function NovaLib:Destroy()
    Alive = false
    for _, c in ipairs(NovaLib.Connections) do pcall(function() c:Disconnect() end) end
    table.clear(NovaLib.Connections)
    Root:Destroy()
end

--// ------------------------------------------------------------------
--//  KEY NAME HELPERS
--// ------------------------------------------------------------------
local function KeyName(k)
    if typeof(k) == "EnumItem" then
        local n = k.Name
        n = n:gsub("^MouseButton1$", "M1"):gsub("^MouseButton2$", "M2"):gsub("^MouseButton3$", "M3")
        return n
    end
    return tostring(k)
end

local BadKeys = {
    [Enum.KeyCode.Unknown] = true, [Enum.KeyCode.Return] = true,
}

--// ------------------------------------------------------------------
--//  WINDOW
--// ------------------------------------------------------------------
function NovaLib:MakeWindow(cfg)
    cfg = cfg or {}
    cfg.Name          = cfg.Name or "NovaLib"
    cfg.Subtitle      = cfg.Subtitle or ""
    cfg.ConfigFolder  = cfg.ConfigFolder or cfg.Name
    cfg.SaveConfig    = cfg.SaveConfig or false
    cfg.IntroEnabled  = cfg.IntroEnabled ~= false
    cfg.IntroText     = cfg.IntroText or cfg.Name
    cfg.IntroIcon     = cfg.IntroIcon or ""
    cfg.Icon          = cfg.Icon or cfg.IntroIcon or ""
    cfg.ShowIcon      = cfg.ShowIcon ~= false
    cfg.ToggleKey     = cfg.ToggleKey or Enum.KeyCode.RightShift
    cfg.CloseCallback = cfg.CloseCallback or function() end
    cfg.Watermark     = cfg.Watermark ~= false
    cfg.Palette       = cfg.Palette ~= false
    cfg.Theme         = cfg.Theme
    cfg.Accent        = cfg.Accent
    cfg.Accent2       = cfg.Accent2

    NovaLib.Folder    = cfg.ConfigFolder
    NovaLib.SaveCfg   = cfg.SaveConfig
    NovaLib.ToggleKey = cfg.ToggleKey

    if cfg.Theme and NovaLib.Themes[cfg.Theme] then NovaLib:SetTheme(cfg.Theme) end
    if cfg.Accent then NovaLib:SetAccent(cfg.Accent, cfg.Accent2) end

    if cfg.SaveConfig and makefolder and isfolder then
        pcall(function() if not isfolder(cfg.ConfigFolder) then makefolder(cfg.ConfigFolder) end end)
    end

    local mobile = NovaLib.IsMobile
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

    local baseW = cfg.Width  or (mobile and 470 or 640)
    local baseH = cfg.Height or (mobile and 300 or 400)
    local sidebarW = mobile and 64 or 172

    local Window = {Tabs = {}, Elements = {}, Hidden = false, Minimized = false}
    local firstTab = true
    local tabIndex = 0
    local searchIndex = {}        -- for command palette
    local keybinds = {}           -- for keybind overlay
    table.insert(NovaLib.Windows, Window)

    -- Main frame ----------------------------------------------------
    local Main = New("CanvasGroup", {
        Name = "Main", BackgroundColor3 = ThemeColor("Background"),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(baseW, baseH),
        BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 10, Parent = Root,
    })
    Corner(16, Main)
    Bind(Main, "BackgroundColor3", "Background")
    local MainStroke = Stroke(ThemeColor("Stroke"), 1.4, 0.15, Main)
    Bind(MainStroke, "Color", "Stroke")
    Window.Main = Main

    -- Shadow lives on a wrapper because CanvasGroup clips descendants
    local Shell = New("Frame", {
        Name = "Shell", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(baseW, baseH), ZIndex = 9, Parent = Root,
    })
    Main.Parent = Shell
    Main.AnchorPoint = Vector2.new(0, 0); Main.Position = UDim2.fromScale(0, 0); Main.Size = UDim2.fromScale(1, 1)
    Shadow(Shell, 60, 0.5)
    Window.Shell = Shell

    local scaleObj = New("UIScale", {Scale = 0.85, Parent = Shell})
    Window.Scale = scaleObj

    -- fit to small screens
    local userScale = 1
    local function FitToScreen()
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or viewport
        local fit = math.min((vp.X - 24) / baseW, (vp.Y - 24) / baseH, 1)
        return math.max(fit, 0.5) * userScale
    end
    local targetScale = FitToScreen()
    if workspace.CurrentCamera then
        Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function()
            targetScale = FitToScreen()
            if not Window.Hidden and not Window.Minimized then Tween(scaleObj, EASE.Med, {Scale = targetScale}) end
        end)
    end

    -- ambient accent glow along the top edge
    local AmbientGlow = New("Frame", {
        Name = "Ambient", BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.86, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 130), ZIndex = 11, Parent = Main,
    })
    AccentGrad(AmbientGlow, 90)
    do
        local g = AmbientGlow:FindFirstChildOfClass("UIGradient")
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.7),
            NumberSequenceKeypoint.new(1, 1),
        })
    end

    -- Top bar ----------------------------------------------------------
    local TopBar = New("Frame", {
        Name = "TopBar", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, mobile and 52 or 48), ZIndex = 12, Parent = Main,
    })

    local iconOffset = 16
    if cfg.ShowIcon and cfg.Icon ~= "" then
        local logoBack = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 14, 0.5, -15),
            BorderSizePixel = 0, ZIndex = 13, Parent = TopBar,
        })
        Corner(9, logoBack); AccentGrad(logoBack, 45)
        New("ImageLabel", {
            BackgroundTransparency = 1, Image = ResolveIcon(cfg.Icon),
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(18, 18), ZIndex = 14, Parent = logoBack,
        })
        iconOffset = 54
    end

    local TitleLabel = Text({
        Name = "Title", Text = cfg.Name, Font = Enum.Font.GothamBold, TextSize = 16,
        Position = UDim2.new(0, iconOffset, 0, cfg.Subtitle ~= "" and 8 or 0),
        Size = UDim2.new(0.5, 0, cfg.Subtitle ~= "" and 0, cfg.Subtitle ~= "" and 18 or 1, 0),
        ZIndex = 13, Parent = TopBar,
    })
    if cfg.Subtitle == "" then TitleLabel.Size = UDim2.new(0.5, 0, 1, 0); TitleLabel.Position = UDim2.new(0, iconOffset, 0, 0) end
    Bind(TitleLabel, "TextColor3", "Text")

    if cfg.Subtitle ~= "" then
        local Sub = Text({
            Name = "Subtitle", Text = cfg.Subtitle, Font = Enum.Font.Gotham, TextSize = 11,
            Position = UDim2.new(0, iconOffset, 0, 27), Size = UDim2.new(0.5, 0, 0, 13),
            ZIndex = 13, Parent = TopBar,
        })
        Bind(Sub, "TextColor3", "SubText")
    end

    -- window control buttons
    local function ControlButton(icon, offsetX, hoverColor)
        local b = New("TextButton", {
            Text = "", AutoButtonColor = false,
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            Size = UDim2.fromOffset(mobile and 34 or 28, mobile and 34 or 28),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -offsetX, 0.5, 0),
            ZIndex = 14, Parent = TopBar,
        })
        Corner(9, b)
        local ico = New("ImageLabel", {
            BackgroundTransparency = 1, Image = icon, ImageTransparency = 0.25,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(15, 15), ZIndex = 15, Parent = b,
        })
        Bind(ico, "ImageColor3", "Text")
        Connect(b.MouseEnter, function()
            Tween(b, EASE.Fast, {BackgroundTransparency = 0.82, BackgroundColor3 = hoverColor})
            Tween(ico, EASE.Fast, {ImageTransparency = 0, Size = UDim2.fromOffset(17, 17)})
        end)
        Connect(b.MouseLeave, function()
            Tween(b, EASE.Fast, {BackgroundTransparency = 1})
            Tween(ico, EASE.Fast, {ImageTransparency = 0.25, Size = UDim2.fromOffset(15, 15)})
        end)
        return b, ico
    end

    local ctrlStep = mobile and 40 or 34
    local CloseBtn = ControlButton("rbxassetid://7072725342", 10, Color3.fromRGB(255, 80, 90))
    local MinBtn, MinIco = ControlButton("rbxassetid://7072719338", 10 + ctrlStep, Color3.fromRGB(255, 190, 70))
    local PaletteBtn
    if cfg.Palette then
        PaletteBtn = ControlButton("rbxassetid://7072721039", 10 + ctrlStep * 2, NovaLib.Accent)
    end

    -- animated accent line under top bar
    local TopLine = New("Frame", {
        Name = "TopLine", BackgroundColor3 = Color3.new(1, 1, 1),
        Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -1),
        BorderSizePixel = 0, ZIndex = 13, Parent = TopBar,
    })
    local lineGrad = AccentGrad(TopLine, 0)
    TopLine.BackgroundTransparency = 0.15
    Connect(RunService.RenderStepped, function()
        if lineGrad and lineGrad.Parent and not Window.Hidden then
            lineGrad.Offset = Vector2.new(math.sin(os.clock() * 0.8) * 0.5, 0)
        end
    end)

    -- Sidebar ----------------------------------------------------------
    local Sidebar = New("Frame", {
        Name = "Sidebar", BackgroundColor3 = ThemeColor("Surface"),
        BackgroundTransparency = 0.35, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, TopBar.Size.Y.Offset + 6),
        Size = UDim2.new(0, sidebarW - 10, 1, -(TopBar.Size.Y.Offset + 16)),
        ZIndex = 12, Parent = Main,
    })
    Corner(12, Sidebar)
    Bind(Sidebar, "BackgroundColor3", "Surface")
    local sbStroke = Stroke(ThemeColor("Stroke"), 1, 0.5, Sidebar)
    Bind(sbStroke, "Color", "Stroke")

    local TabScroll = New("ScrollingFrame", {
        Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, mobile and 0 or -40), Position = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 13, Parent = Sidebar,
    })
    Padding(8, 6, 8, 6, TabScroll)
    List(4, TabScroll)

    -- sliding selection pill
    local Pill = New("Frame", {
        Name = "Pill", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
        BorderSizePixel = 0, Size = UDim2.new(1, -12, 0, 0), Position = UDim2.fromOffset(6, 8),
        ZIndex = 12, Visible = false, Parent = Sidebar,
    })
    Corner(10, Pill)
    AccentGrad(Pill, 20)
    local pillBar = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 0.55, 0), AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0), ZIndex = 13, Parent = Pill,
    })
    Corner(3, pillBar); AccentGrad(pillBar, 90)

    -- Sidebar footer (desktop): user chip
    if not mobile then
        local footer = New("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 40), ZIndex = 13, Parent = Sidebar,
        })
        local sep = New("Frame", {BorderSizePixel = 0, Size = UDim2.new(1, -20, 0, 1), Position = UDim2.fromOffset(10, 0), ZIndex = 13, Parent = footer})
        Bind(sep, "BackgroundColor3", "Stroke")
        local avatar = New("ImageLabel", {
            BackgroundColor3 = ThemeColor("Elevated"), Size = UDim2.fromOffset(24, 24),
            Position = UDim2.new(0, 10, 0.5, 1), AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 14, Parent = footer,
        })
        Corner(12, avatar); Bind(avatar, "BackgroundColor3", "Elevated")
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and avatar.Parent then avatar.Image = img end
        end)
        local nameLbl = Text({
            Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 12,
            Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, -46, 1, 2),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = footer,
        })
        Bind(nameLbl, "TextColor3", "SubText")
    end

    -- Content area ----------------------------------------------------
    local Content = New("Frame", {
        Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.new(0, sidebarW + 4, 0, TopBar.Size.Y.Offset + 6),
        Size = UDim2.new(1, -(sidebarW + 14), 1, -(TopBar.Size.Y.Offset + 16)),
        ClipsDescendants = true, ZIndex = 12, Parent = Main,
    })
    Window.Content = Content

    -- Drag -----------------------------------------------------------------
    MakeDraggable(TopBar, Shell, {Smooth = true})

    -- Window open / close animation ------------------------------------
    local function Show()
        Window.Hidden = false
        Shell.Visible = true
        Tween(Main, EASE.Slow, {GroupTransparency = 0})
        Tween(scaleObj, EASE.Spring, {Scale = targetScale})
    end
    local function Hide()
        Window.Hidden = true
        Tween(Main, EASE.In, {GroupTransparency = 1})
        Tween(scaleObj, EASE.In, {Scale = 0.88})
        task.delay(0.28, function() if Window.Hidden then Shell.Visible = false end end)
    end
    Window.Show, Window.Hide = Show, Hide
    function Window:Toggle() if Window.Hidden then Show() else Hide() end end

    -- Launcher (mobile + fallback) ---------------------------------------
    local Launcher = New("TextButton", {
        Name = "Launcher", Text = "", AutoButtonColor = false,
        BackgroundColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 34, 0.5, 0),
        Size = UDim2.fromOffset(mobile and 50 or 44, mobile and 50 or 44),
        ZIndex = 250, Visible = false, Parent = Root,
    })
    Corner(100, Launcher); AccentGrad(Launcher, 45)
    Stroke(Color3.new(1, 1, 1), 1.5, 0.75, Launcher)
    Shadow(Launcher, 24, 0.55)
    New("ImageLabel", {
        BackgroundTransparency = 1,
        Image = (cfg.Icon ~= "" and ResolveIcon(cfg.Icon)) or "rbxassetid://7072719338",
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.5), ZIndex = 251, Parent = Launcher,
    })
    local lScale = New("UIScale", {Scale = 0, Parent = Launcher})

    local launcherDragging = false
    local lDragMoved = false
    local startLPos
    MakeDraggable(Launcher, Launcher, {
        Smooth = false,
        OnStart = function() startLPos = Launcher.AbsolutePosition; lDragMoved = false end,
        OnEnd = function()
            if startLPos and (Launcher.AbsolutePosition - startLPos).Magnitude > 6 then lDragMoved = true end
        end,
    })

    local function ShowLauncher(v)
        if v then
            Launcher.Visible = true
            Tween(lScale, EASE.Spring, {Scale = 1})
        else
            Tween(lScale, EASE.In, {Scale = 0})
            task.delay(0.25, function() if lScale.Scale < 0.05 then Launcher.Visible = false end end)
        end
    end
    Connect(Launcher.Activated, function()
        if lDragMoved then lDragMoved = false; return end
        Show(); ShowLauncher(false)
    end)

    local function HideWindow(userClosed)
        Hide()
        if mobile or userClosed then ShowLauncher(true) end
    end

    Connect(CloseBtn.Activated, function()
        HideWindow(true)
        NovaLib:MakeNotification({
            Name = "Interface hidden",
            Content = mobile and "Tap the floating button to bring it back."
                or ("Press " .. cfg.ToggleKey.Name .. " or the floating button to reopen."),
            Type = "Info", Time = 3,
        })
        task.spawn(cfg.CloseCallback)
    end)

    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == cfg.ToggleKey then
            if Window.Hidden then Show(); ShowLauncher(false) else HideWindow(false) end
        end
    end)

    -- Minimize --------------------------------------------------------
    local expandedH = baseH
    Connect(MinBtn.Activated, function()
        Window.Minimized = not Window.Minimized
        if Window.Minimized then
            Tween(Shell, EASE.Med, {Size = UDim2.fromOffset(baseW, TopBar.Size.Y.Offset)})
            Tween(Sidebar, EASE.Fast, {BackgroundTransparency = 1})
            Content.Visible = false; Sidebar.Visible = false
            Tween(MinIco, EASE.Fast, {Rotation = 180})
        else
            Sidebar.Visible = true; Content.Visible = true
            Tween(Shell, EASE.Spring, {Size = UDim2.fromOffset(baseW, expandedH)})
            Tween(Sidebar, EASE.Med, {BackgroundTransparency = 0.35})
            Tween(MinIco, EASE.Fast, {Rotation = 0})
        end
    end)

    -- Watermark / HUD -------------------------------------------------
    local HUD
    if cfg.Watermark then
        HUD = New("CanvasGroup", {
            Name = "HUD", BackgroundColor3 = ThemeColor("Surface"),
            AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(14, 14),
            Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
            GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 100, Visible = false, Parent = Root,
        })
        Corner(9, HUD); Bind(HUD, "BackgroundColor3", "Surface")
        Stroke(NovaLib.Accent, 1, 0.6, HUD)
        Padding(0, 12, 0, 12, HUD)
        local hudLabel = Text({
            Text = cfg.Name, Font = Enum.Font.GothamMedium, TextSize = 12,
            Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 101, Parent = HUD,
        })
        Bind(hudLabel, "TextColor3", "Text")
        local acc = 0
        local frames, fpsShown = 0, 60
        Connect(RunService.RenderStepped, function(dt)
            if not HUD.Visible then return end
            frames += 1; acc += dt
            if acc >= 0.5 then
                fpsShown = math.floor(frames / acc + 0.5)
                frames = 0; acc = 0
                local ping = 0
                pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
                hudLabel.Text = string.format('%s  <font transparency="0.5">•</font>  %d fps  <font transparency="0.5">•</font>  %d ms',
                    cfg.Name, fpsShown, ping)
            end
        end)
        function Window:SetHUD(v)
            if v then HUD.Visible = true; Tween(HUD, EASE.Med, {GroupTransparency = 0})
            else Tween(HUD, EASE.Med, {GroupTransparency = 1}); task.delay(0.35, function() HUD.Visible = false end) end
        end
        function Window:SetHUDText(t) hudLabel.Text = t end
    else
        function Window:SetHUD() end
        function Window:SetHUDText() end
    end

    -- Keybind overlay -------------------------------------------------
    local KeyOverlay = New("CanvasGroup", {
        Name = "KeyOverlay", BackgroundColor3 = ThemeColor("Surface"),
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(170, 0), AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 100, Visible = false, Parent = Root,
    })
    Corner(12, KeyOverlay); Bind(KeyOverlay, "BackgroundColor3", "Surface")
    Stroke(NovaLib.Accent, 1, 0.65, KeyOverlay)
    Padding(10, 12, 10, 12, KeyOverlay); List(4, KeyOverlay)
    local koTitle = Text({Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 10, Size = UDim2.new(1, 0, 0, 14), ZIndex = 101, Parent = KeyOverlay})
    Bind(koTitle, "TextColor3", "SubText")
    local koRows = {}
    local function RefreshKeyOverlay()
        for _, r in pairs(koRows) do r:Destroy() end
        table.clear(koRows)
        for i, kb in ipairs(keybinds) do
            local row = Text({
                Text = string.format('%s  <font color="rgb(%d,%d,%d)"><b>%s</b></font>', kb.Name,
                    NovaLib.Accent.R * 255, NovaLib.Accent.G * 255, NovaLib.Accent.B * 255, KeyName(kb.Get())),
                Font = Enum.Font.Gotham, TextSize = 12, Size = UDim2.new(1, 0, 0, 16),
                LayoutOrder = i, ZIndex = 101, Parent = KeyOverlay,
            })
            Bind(row, "TextColor3", "Text")
            table.insert(koRows, row)
        end
    end
    function Window:SetKeybindList(v)
        if v then
            RefreshKeyOverlay(); KeyOverlay.Visible = true
            Tween(KeyOverlay, EASE.Med, {GroupTransparency = 0})
        else
            Tween(KeyOverlay, EASE.Med, {GroupTransparency = 1})
            task.delay(0.35, function() KeyOverlay.Visible = false end)
        end
    end

    -- Command palette -----------------------------------------------------
    local Palette = {Open = false}
    local PaletteFrame, PaletteDim, PaletteBox, PaletteResults
    local function BuildPalette()
        PaletteDim = New("TextButton", {
            Name = "PaletteDim", Text = "", AutoButtonColor = false,
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), ZIndex = 320, Visible = false, Parent = Root,
        })
        PaletteFrame = New("CanvasGroup", {
            BackgroundColor3 = ThemeColor("Surface"),
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0),
            Size = UDim2.fromOffset(mobile and 320 or 460, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 321, Parent = PaletteDim,
        })
        Corner(16, PaletteFrame); Bind(PaletteFrame, "BackgroundColor3", "Surface")
        local pfs = Stroke(NovaLib.Accent, 1.2, 0.5, PaletteFrame)
        List(0, PaletteFrame)
        local ps = New("UIScale", {Scale = 0.94, Name = "S", Parent = PaletteFrame})

        local inputRow = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 1, ZIndex = 322, Parent = PaletteFrame})
        local sIco = New("ImageLabel", {
            BackgroundTransparency = 1, Image = "rbxassetid://7072721039", ImageTransparency = 0.3,
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 18, 0.5, -9), ZIndex = 323, Parent = inputRow,
        })
        Bind(sIco, "ImageColor3", "Text")
        PaletteBox = New("TextBox", {
            BackgroundTransparency = 1, Text = "", PlaceholderText = "Search features…  (try 'speed', 'esp')",
            ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 46, 0, 0),
            Size = UDim2.new(1, -60, 1, 0), ZIndex = 323, Parent = inputRow,
        })
        Bind(PaletteBox, "TextColor3", "Text")
        Bind(PaletteBox, "PlaceholderColor3", "SubText")
        local divider = New("Frame", {BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, ZIndex = 322, Parent = PaletteFrame})
        Bind(divider, "BackgroundColor3", "Stroke")

        PaletteResults = New("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 3,
            Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ZIndex = 322, Parent = PaletteFrame,
        })
        Padding(6, 6, 6, 6, PaletteResults); List(2, PaletteResults)

        Connect(PaletteDim.Activated, function() Palette:Close() end)
    end

    local paletteRows = {}
    local function RunSearch(q)
        for _, r in pairs(paletteRows) do r:Destroy() end
        table.clear(paletteRows)
        q = (q or ""):lower()
        local matches = {}
        for _, item in ipairs(searchIndex) do
            local hay = (item.Name .. " " .. item.Tab .. " " .. (item.Kind or "")):lower()
            if q == "" or hay:find(q, 1, true) then
                table.insert(matches, item)
            end
            if #matches >= 7 then break end
        end
        for i, item in ipairs(matches) do
            local row = New("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 40),
                LayoutOrder = i, ZIndex = 323, Parent = PaletteResults,
            })
            Corner(10, row)
            local nm = Text({
                Text = item.Name, Font = Enum.Font.GothamMedium, TextSize = 14,
                Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 324, Parent = row,
            })
            Bind(nm, "TextColor3", "Text")
            local meta = Text({
                Text = item.Tab .. "  ·  " .. (item.Kind or ""), Font = Enum.Font.Gotham, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -12, 0, 0),
                AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 110, 1, 0), ZIndex = 324, Parent = row,
            })
            Bind(meta, "TextColor3", "SubText")
            Connect(row.MouseEnter, function() Tween(row, EASE.Fast, {BackgroundTransparency = 0.9}) end)
            Connect(row.MouseLeave, function() Tween(row, EASE.Fast, {BackgroundTransparency = 1}) end)
            Connect(row.Activated, function()
                Palette:Close()
                if Window.Hidden then Show(); ShowLauncher(false) end
                item.Go()
            end)
            table.insert(paletteRows, row)
        end
        if #matches == 0 then
            local none = Text({
                Text = "No results", Font = Enum.Font.Gotham, TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), ZIndex = 323, Parent = PaletteResults,
            })
            Bind(none, "TextColor3", "SubText")
            table.insert(paletteRows, none)
        end
        local h = math.min(#matches, 7) * 42 + (#matches == 0 and 42 or 0) + 12
        PaletteResults.Size = UDim2.new(1, 0, 0, h)
    end

    function Palette:Open_()
        if not PaletteFrame then BuildPalette() end
        Palette.Open = true
        PaletteDim.Visible = true
        PaletteBox.Text = ""
        RunSearch("")
        Tween(PaletteDim, EASE.Med, {BackgroundTransparency = 0.55})
        Tween(PaletteFrame, EASE.Spring, {GroupTransparency = 0})
        Tween(PaletteFrame.S, EASE.Spring, {Scale = 1})
        task.delay(0.05, function() if PaletteBox then PaletteBox:CaptureFocus() end end)
        Connect(PaletteBox:GetPropertyChangedSignal("Text"), function() RunSearch(PaletteBox.Text) end)
    end
    function Palette:Close()
        if not Palette.Open then return end
        Palette.Open = false
        Tween(PaletteDim, EASE.In, {BackgroundTransparency = 1})
        Tween(PaletteFrame, EASE.In, {GroupTransparency = 1})
        Tween(PaletteFrame.S, EASE.In, {Scale = 0.94})
        task.delay(0.28, function() if not Palette.Open then PaletteDim.Visible = false end end)
    end
    function Window:OpenPalette() Palette:Open_() end
    function Window:ClosePalette() Palette:Close() end

    if PaletteBtn then
        Connect(PaletteBtn.Activated, function() if Palette.Open then Palette:Close() else Palette:Open_() end end)
    end
    Connect(UserInputService.InputBegan, function(input, gpe)
        if input.KeyCode == Enum.KeyCode.K
            and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
            and cfg.Palette then
            if Palette.Open then Palette:Close() else Palette:Open_() end
        elseif input.KeyCode == Enum.KeyCode.Escape and Palette.Open then
            Palette:Close()
        end
    end)

    -- Tab selection --------------------------------------------------
    local currentTab

    local function SelectTab(t, instant)
        if currentTab == t then return end
        local prev = currentTab
        currentTab = t

        for _, tb in ipairs(Window.Tabs) do
            local active = (tb == t)
            Tween(tb.Icon, EASE.Med, {ImageTransparency = active and 0 or 0.45})
            if tb.Label then Tween(tb.Label, EASE.Med, {TextTransparency = active and 0 or 0.4}) end
        end

        -- move pill
        Pill.Visible = true
        -- Pill is parented to Sidebar (outside the scrolling list), so measure in Sidebar space.
        local y = t.Button.AbsolutePosition.Y - Sidebar.AbsolutePosition.Y
        local goal = {Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, t.Button.AbsoluteSize.Y)}
        if instant then
            Pill.Position, Pill.Size = goal.Position, goal.Size
        else
            Tween(Pill, EASE.Spring, goal)
        end

        -- crossfade content (slide direction based on tab order)
        local dir = (prev and prev.Index < t.Index) and 1 or -1
        if prev then
            local pc = prev.Container
            Tween(pc, EASE.Fast, {GroupTransparency = 1, Position = UDim2.new(0, 0, 0, -12 * dir)})
            task.delay(0.16, function() if currentTab ~= prev then pc.Visible = false end end)
        end
        local c = t.Container
        c.Visible = true
        if not instant then
            c.GroupTransparency = 1
            c.Position = UDim2.new(0, 0, 0, 14 * dir)
        end
        Tween(c, EASE.Med, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)})
    end

    -- Intro ------------------------------------------------------------
    local function PlayIntro()
        local dim = New("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), ZIndex = 500, Parent = Root,
        })
        Tween(dim, EASE.Med, {BackgroundTransparency = 0.35})

        local holder = New("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 120), ZIndex = 501, Parent = dim,
        })

        local ring = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(0, 0), ZIndex = 502, Parent = holder,
        })
        Corner(100, ring); AccentGrad(ring, 45)
        local ringStroke = Stroke(Color3.new(1, 1, 1), 0, 0.5, ring)

        local logo = New("ImageLabel", {
            BackgroundTransparency = 1, Image = ResolveIcon(cfg.IntroIcon ~= "" and cfg.IntroIcon or cfg.Icon),
            ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(0, 0), ZIndex = 503, Parent = holder,
        })

        local name = Text({
            Text = cfg.IntroText, Font = Enum.Font.GothamBold, TextSize = 26,
            TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1,
            Position = UDim2.new(0, 0, 0, 68), Size = UDim2.new(1, 0, 0, 30), ZIndex = 502, Parent = holder,
        })
        AccentGrad(name, 0); name.TextColor3 = Color3.new(1, 1, 1)
        local nameScale = New("UIScale", {Scale = 0.9, Parent = name})

        local bar = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108),
            Size = UDim2.fromOffset(140, 3), ZIndex = 502, Parent = holder,
        })
        Corner(3, bar)
        local fill = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 503, Parent = bar})
        Corner(3, fill); AccentGrad(fill, 0)

        Tween(ring, EASE.Spring, {Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 0})
        Tween(logo, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.12), {
            Size = UDim2.fromOffset(32, 32), ImageTransparency = 0,
        })
        task.wait(0.25)
        Tween(name, EASE.Med, {TextTransparency = 0})
        Tween(nameScale, EASE.Spring, {Scale = 1})
        Tween(fill, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)})
        task.wait(1.25)

        Tween(holder, EASE.In, {Position = UDim2.fromScale(0.5, 0.46)})
        Tween(name, EASE.In, {TextTransparency = 1})
        Tween(logo, EASE.In, {ImageTransparency = 1})
        Tween(ring, EASE.In, {BackgroundTransparency = 1, Size = UDim2.fromOffset(90, 90)})
        Tween(bar, EASE.In, {BackgroundTransparency = 1})
        Tween(fill, EASE.In, {BackgroundTransparency = 1})
        Tween(dim, EASE.Med, {BackgroundTransparency = 1})
        task.wait(0.3)
        dim:Destroy()
    end

    task.spawn(function()
        if cfg.IntroEnabled then PlayIntro() end
        Show()
    end)

    ----------------------------------------------------------------------
    --  TABS
    ----------------------------------------------------------------------
    function Window:MakeTab(tcfg)
        tcfg = tcfg or {}
        tcfg.Name = tcfg.Name or "Tab"
        tcfg.Icon = tcfg.Icon or ""
        tabIndex += 1

        local Tab = {Index = tabIndex, Name = tcfg.Name}

        local btn = New("TextButton", {
            Name = "Tab_" .. tcfg.Name, Text = "", AutoButtonColor = false,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, mobile and 44 or 38),
            LayoutOrder = tabIndex, ZIndex = 14, Parent = TabScroll,
        })
        Corner(10, btn)
        Tab.Button = btn

        local iconImg = ResolveIcon(tcfg.Icon)
        local ico = New("ImageLabel", {
            BackgroundTransparency = 1, Image = iconImg, ImageTransparency = 0.45,
            AnchorPoint = Vector2.new(mobile and 0.5 or 0, 0.5),
            Position = mobile and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(mobile and 22 or 18, mobile and 22 or 18), ZIndex = 15, Parent = btn,
        })
        Bind(ico, "ImageColor3", "Text")

        local lbl
        if not mobile then
            lbl = Text({
                Text = tcfg.Name, Font = Enum.Font.GothamMedium, TextSize = 14, TextTransparency = 0.4,
                Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -74, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = btn,
            })
            Bind(lbl, "TextColor3", "Text")
        end

        -- badge (e.g. "NEW", count)
        local badgeLbl
        if tcfg.Badge then
            local bf = New("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = mobile and UDim2.new(1, -2, 0, 8) or UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 16, Parent = btn,
            })
            Corner(8, bf); AccentGrad(bf, 30); Padding(0, 6, 0, 6, bf)
            badgeLbl = Text({
                Text = tostring(tcfg.Badge), Font = Enum.Font.GothamBold, TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Center,
                Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 17, Parent = bf,
            })
            badgeLbl.TextColor3 = Color3.new(1, 1, 1)
            Tab.BadgeFrame = bf
        end
        function Tab:SetBadge(t)
            if badgeLbl then badgeLbl.Text = tostring(t); Tab.BadgeFrame.Visible = t ~= nil and t ~= "" end
        end

        Connect(btn.MouseEnter, function()
            if currentTab ~= Tab then
                Tween(btn, EASE.Fast, {BackgroundTransparency = 0.92, BackgroundColor3 = Color3.new(1, 1, 1)})
                Tween(ico, EASE.Fast, {ImageTransparency = 0.2})
            end
        end)
        Connect(btn.MouseLeave, function()
            Tween(btn, EASE.Fast, {BackgroundTransparency = 1})
            if currentTab ~= Tab then Tween(ico, EASE.Fast, {ImageTransparency = 0.45}) end
        end)

        -- page container (CanvasGroup so we can crossfade)
        local Container = New("CanvasGroup", {
            Name = "Page_" .. tcfg.Name, BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, ZIndex = 13, Parent = Content,
        })
        local Scroll = New("ScrollingFrame", {
            Name = "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = mobile and 3 or 4, ScrollBarImageTransparency = 0.4,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 13, Parent = Container,
        })
        Bind(Scroll, "ScrollBarImageColor3", "Stroke")
        Padding(2, 8, 12, 2, Scroll); List(8, Scroll)
        Tab.Container, Tab.Scroll = Container, Scroll

        Tab.Icon, Tab.Label = ico, lbl
        Window.Tabs[tabIndex] = Tab

        Connect(btn.Activated, function() Ripple(btn); SelectTab(Tab) end)

        if firstTab then
            firstTab = false
            task.defer(function()
                RunService.RenderStepped:Wait()
                SelectTab(Tab, true)
            end)
        end

        ------------------------------------------------------------------
        --  ELEMENT FACTORY
        ------------------------------------------------------------------
        local function ElementFactory(parent, sectionName)
            local E = {}

            local function Card(height, hoverable)
                local c = New("TextButton", {
                    Text = "", AutoButtonColor = false,
                    BackgroundColor3 = ThemeColor("Surface"), BackgroundTransparency = 0.2,
                    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 42),
                    ClipsDescendants = true, ZIndex = 14, Parent = parent,
                })
                Corner(11, c)
                Bind(c, "BackgroundColor3", "Surface")
                local st = Stroke(ThemeColor("Stroke"), 1, 0.45, c)
                Bind(st, "Color", "Stroke")
                if hoverable then
                    Connect(c.MouseEnter, function()
                        Tween(c, EASE.Fast, {BackgroundTransparency = 0})
                        Tween(st, EASE.Fast, {Transparency = 0.1})
                    end)
                    Connect(c.MouseLeave, function()
                        Tween(c, EASE.Fast, {BackgroundTransparency = 0.2})
                        Tween(st, EASE.Fast, {Transparency = 0.45})
                    end)
                end
                return c, st
            end

            local function NameLabel(card, name, offX)
                local l = Text({
                    Name = "Name", Text = name, Font = Enum.Font.GothamMedium, TextSize = 14,
                    Position = UDim2.new(0, offX or 14, 0, 0), Size = UDim2.new(1, -(offX or 14) - 70, 1, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = card,
                })
                Bind(l, "TextColor3", "Text")
                return l
            end

            -- locking + visibility wrappers
            local function Decorate(obj, card, cfgE, kind, goFocus)
                local locked = false
                local lockOverlay = New("Frame", {
                    Name = "Lock", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
                    Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 40, Parent = card,
                })
                Corner(11, lockOverlay)
                local lockIco = New("ImageLabel", {
                    BackgroundTransparency = 1, Image = "rbxassetid://7072718362", ImageTransparency = 0.2,
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromOffset(16, 16), ZIndex = 41, Parent = lockOverlay,
                })
                local sink = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 42, Parent = lockOverlay})

                function obj:Lock(v)
                    if v == nil then v = true end
                    locked = v
                    lockOverlay.Visible = v
                end
                function obj:IsLocked() return locked end
                function obj:SetVisible(v) card.Visible = v end
                function obj:Destroy() card:Destroy() end
                function obj:SetTooltip(t) AttachTooltip(card, t) end

                if cfgE.Locked then obj:Lock(true) end
                if cfgE.Tooltip then AttachTooltip(card, cfgE.Tooltip) end
                if cfgE.Visible == false then card.Visible = false end

                -- register with command palette
                table.insert(searchIndex, {
                    Name = cfgE.Name or kind, Tab = tcfg.Name, Kind = kind,
                    Go = function()
                        SelectTab(Tab)
                        task.delay(0.15, function()
                            pcall(function()
                                local y = card.AbsolutePosition.Y - Scroll.AbsolutePosition.Y + Scroll.CanvasPosition.Y - 8
                                Tween(Scroll, EASE.Med, {CanvasPosition = Vector2.new(0, math.max(0, y))})
                            end)
                            -- flash highlight
                            local flash = New("Frame", {
                                BackgroundColor3 = NovaLib.Accent, BackgroundTransparency = 0.6,
                                BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 39, Parent = card,
                            })
                            Corner(11, flash)
                            Tween(flash, TweenInfo.new(1.1, Enum.EasingStyle.Quint), {BackgroundTransparency = 1})
                            task.delay(1.2, function() flash:Destroy() end)
                        end)
                    end,
                })

                obj.Card = card
                return obj
            end

            local function Register(flag, obj, cfgE, type_)
                obj.Type = type_
                obj.Save = cfgE.Save == true   -- opt-in, matches the original API
                if flag then NovaLib.Flags[flag] = obj end
            end

            ------------------------------------------------------------------
            -- LABEL
            ------------------------------------------------------------------
            function E:AddLabel(text)
                local cfgL = type(text) == "table" and text or {Name = text}
                local c = Card(34, false)
                local l = NameLabel(c, cfgL.Name or "", 14)
                l.Size = UDim2.new(1, -28, 1, 0)
                Bind(l, "TextColor3", "SubText")
                local L = {}
                function L:Set(t) l.Text = t end
                function L:Get() return l.Text end
                return Decorate(L, c, cfgL, "Label")
            end

            ------------------------------------------------------------------
            -- PARAGRAPH
            ------------------------------------------------------------------
            function E:AddParagraph(pc)
                pc = pc or {}
                local title = pc.Title or pc[1] or "Title"
                local body = pc.Content or pc[2] or ""
                local c = Card(60, false)
                c.AutomaticSize = Enum.AutomaticSize.Y
                c.Size = UDim2.new(1, 0, 0, 0)
                Padding(12, 14, 12, 14, c)
                List(4, c)
                local t = Text({
                    Name = "T", Text = title, Font = Enum.Font.GothamBold, TextSize = 14,
                    Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, ZIndex = 15, Parent = c,
                })
                Bind(t, "TextColor3", "Text")
                local b = Text({
                    Name = "B", Text = body, Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = 2, ZIndex = 15, Parent = c,
                })
                Bind(b, "TextColor3", "SubText")
                local P = {}
                function P:Set(x) b.Text = x end
                function P:SetTitle(x) t.Text = x end
                pc.Name = pc.Name or title
                return Decorate(P, c, pc, "Paragraph")
            end

            ------------------------------------------------------------------
            -- BUTTON
            ------------------------------------------------------------------
            function E:AddButton(bc)
                bc = bc or {}
                bc.Name = bc.Name or "Button"
                bc.Callback = bc.Callback or function() end
                local c, st = Card(42, true)
                local nl = NameLabel(c, bc.Name, 14)

                local right = New("ImageLabel", {
                    BackgroundTransparency = 1, Image = ResolveIcon(bc.Icon ~= nil and bc.Icon or "mouse-pointer"),
                    ImageTransparency = 0.35, AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(17, 17), ZIndex = 15, Parent = c,
                })
                Bind(right, "ImageColor3", "Text")

                local sc = New("UIScale", {Scale = 1, Parent = c})
                local B = {}
                Interactive(c, {
                    Hover = function(h) Tween(right, EASE.Fast, {ImageTransparency = h and 0 or 0.35, Position = UDim2.new(1, h and -12 or -14, 0.5, 0)}) end,
                    Press = function(p) Tween(sc, EASE.Fast, {Scale = p and 0.975 or 1}) end,
                    Click = function()
                        if B:IsLocked() then return end
                        task.spawn(bc.Callback)
                    end,
                })
                function B:Set(name) nl.Text = name end
                function B:Fire() task.spawn(bc.Callback) end
                return Decorate(B, c, bc, "Button")
            end

            ------------------------------------------------------------------
            -- TOGGLE
            ------------------------------------------------------------------
            function E:AddToggle(tc)
                tc = tc or {}
                tc.Name = tc.Name or "Toggle"
                tc.Default = tc.Default or false
                tc.Callback = tc.Callback or function() end

                local c, st = Card(42, true)
                NameLabel(c, tc.Name, 14)

                local track = New("Frame", {
                    BackgroundColor3 = ThemeColor("Elevated"), BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
                    Size = UDim2.fromOffset(44, 24), ZIndex = 15, Parent = c,
                })
                Corner(12, track); Bind(track, "BackgroundColor3", "Elevated")
                local tStroke = Stroke(ThemeColor("Stroke"), 1, 0.3, track)
                Bind(tStroke, "Color", "Stroke")

                local fill = New("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
                    Size = UDim2.fromScale(1, 1), ZIndex = 16, Parent = track,
                })
                Corner(12, fill); AccentGrad(fill, 25)

                local knob = New("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18), ZIndex = 18, Parent = track,
                })
                Corner(9, knob)
                Shadow(knob, 10, 0.6)
                local kScale = New("UIScale", {Scale = 1, Parent = knob})

                local T = {Value = false}
                function T:Set(v, silent)
                    v = v and true or false
                    T.Value = v
                    Tween(fill, EASE.Med, {BackgroundTransparency = v and 0 or 1})
                    Tween(knob, EASE.Spring, {Position = UDim2.new(0, v and 23 or 3, 0.5, 0)})
                    Tween(tStroke, EASE.Med, {Transparency = v and 1 or 0.3})
                    if not silent then task.spawn(tc.Callback, v) end
                end
                function T:Get() return T.Value end
                function T:Toggle() T:Set(not T.Value) end

                Interactive(c, {
                    Press = function(p)
                        Tween(kScale, EASE.Fast, {Scale = p and 1.18 or 1})
                        Tween(knob, EASE.Fast, {Size = UDim2.fromOffset(p and 22 or 18, 18)})
                    end,
                    Click = function() if not T:IsLocked() then T:Set(not T.Value) end end,
                })

                Register(tc.Flag, T, tc, "Toggle")
                Decorate(T, c, tc, "Toggle")
                T:Set(tc.Default, true)
                if tc.Default then task.spawn(tc.Callback, true) end
                return T
            end

            ------------------------------------------------------------------
            -- SLIDER
            ------------------------------------------------------------------
            function E:AddSlider(sc)
                sc = sc or {}
                sc.Name = sc.Name or "Slider"
                sc.Min = sc.Min or 0
                sc.Max = sc.Max or 100
                sc.Increment = sc.Increment or 1
                sc.Default = Clamp(sc.Default or sc.Min, sc.Min, sc.Max)
                sc.ValueName = sc.ValueName or ""
                sc.Callback = sc.Callback or function() end

                local c, st = Card(mobile and 62 or 58, true)
                local sliderName = NameLabel(c, sc.Name, 14)
                sliderName.Position = UDim2.new(0, 14, 0, 8)
                sliderName.Size = UDim2.new(0.6, 0, 0, 20)

                local valueBox = New("TextBox", {
                    BackgroundTransparency = 1, Text = "", ClearTextOnFocus = true,
                    Font = Enum.Font.GothamBold, TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -14, 0, 8), Size = UDim2.new(0.4, 0, 0, 20), ZIndex = 16, Parent = c,
                })
                BindAccent(valueBox, "TextColor3", 1)

                local track = New("TextButton", {
                    Text = "", AutoButtonColor = false,
                    BackgroundColor3 = ThemeColor("Elevated"), BorderSizePixel = 0,
                    Position = UDim2.new(0, 14, 1, mobile and -20 or -18), Size = UDim2.new(1, -28, 0, mobile and 8 or 6),
                    ZIndex = 16, Parent = c,
                })
                Corner(8, track); Bind(track, "BackgroundColor3", "Elevated")
                local fill = New("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                    Size = UDim2.new(0, 0, 1, 0), ZIndex = 17, Parent = track,
                })
                Corner(8, fill); AccentGrad(fill, 0)
                local knob = New("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(mobile and 20 or 16, mobile and 20 or 16), ZIndex = 19, Parent = track,
                })
                Corner(10, knob); Shadow(knob, 10, 0.55)
                local kS = New("UIScale", {Scale = 1, Parent = knob})

                local S = {Value = sc.Default}
                local function Format(v)
                    local s = (sc.Increment < 1) and tostring(Round(v, 2)) or tostring(math.floor(v + 0.5))
                    return sc.ValueName ~= "" and (s .. " " .. sc.ValueName) or s
                end

                local function Render(v, animate)
                    local a = (v - sc.Min) / math.max(sc.Max - sc.Min, 1e-9)
                    a = Clamp(a, 0, 1)
                    if animate then
                        Tween(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {Size = UDim2.new(a, 0, 1, 0)})
                        Tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {Position = UDim2.new(a, 0, 0.5, 0)})
                    else
                        fill.Size = UDim2.new(a, 0, 1, 0)
                        knob.Position = UDim2.new(a, 0, 0.5, 0)
                    end
                    valueBox.Text = Format(v)
                end

                function S:Set(v, silent)
                    v = Clamp(Snap(tonumber(v) or sc.Min, sc.Increment), sc.Min, sc.Max)
                    S.Value = v
                    Render(v, true)
                    if not silent then task.spawn(sc.Callback, v) end
                end
                function S:Get() return S.Value end

                local dragging = false
                local function FromInput(pos)
                    local a = Clamp((pos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    local v = Clamp(Snap(sc.Min + (sc.Max - sc.Min) * a, sc.Increment), sc.Min, sc.Max)
                    if v ~= S.Value then
                        S.Value = v
                        Render(v, true)
                        task.spawn(sc.Callback, v)
                    end
                end
                Connect(track.InputBegan, function(input)
                    if IsPointer(input) and not S:IsLocked() then
                        dragging = true
                        Tween(kS, EASE.Fast, {Scale = 1.3})
                        FromInput(input.Position)
                        local e; e = input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                dragging = false; e:Disconnect()
                                Tween(kS, EASE.Fast, {Scale = 1})
                            end
                        end)
                    end
                end)
                Connect(UserInputService.InputChanged, function(input)
                    if dragging and IsMove(input) then FromInput(input.Position) end
                end)

                Connect(valueBox.FocusLost, function()
                    local n = tonumber(valueBox.Text:match("-?%d+%.?%d*"))
                    if n then S:Set(n) else Render(S.Value, false) end
                end)

                Register(sc.Flag, S, sc, "Slider")
                Decorate(S, c, sc, "Slider")
                Render(sc.Default, false)
                task.spawn(sc.Callback, sc.Default)
                return S
            end

            ------------------------------------------------------------------
            -- PROGRESS BAR (display only)
            ------------------------------------------------------------------
            function E:AddProgress(pc)
                pc = pc or {}
                pc.Name = pc.Name or "Progress"
                pc.Default = pc.Default or 0
                local c = Card(52, false)
                local nl = NameLabel(c, pc.Name, 14)
                nl.Position = UDim2.new(0, 14, 0, 6); nl.Size = UDim2.new(0.6, 0, 0, 20)
                local pct = Text({
                    Text = "0%", Font = Enum.Font.GothamBold, TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -14, 0, 6), Size = UDim2.new(0.4, 0, 0, 20), ZIndex = 16, Parent = c,
                })
                BindAccent(pct, "TextColor3", 1)
                local track = New("Frame", {
                    BackgroundColor3 = ThemeColor("Elevated"), BorderSizePixel = 0,
                    Position = UDim2.new(0, 14, 1, -18), Size = UDim2.new(1, -28, 0, 8), ZIndex = 16, Parent = c,
                })
                Corner(8, track); Bind(track, "BackgroundColor3", "Elevated")
                local fill = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 17, Parent = track})
                Corner(8, fill); AccentGrad(fill, 0)
                local P = {Value = 0}
                function P:Set(v)
                    v = Clamp(v, 0, 1); P.Value = v
                    Tween(fill, EASE.Med, {Size = UDim2.new(v, 0, 1, 0)})
                    pct.Text = math.floor(v * 100 + 0.5) .. "%"
                end
                P:Set(pc.Default)
                return Decorate(P, c, pc, "Progress")
            end

            ------------------------------------------------------------------
            -- STEPPER (− value +)
            ------------------------------------------------------------------
            function E:AddStepper(stc)
                stc = stc or {}
                stc.Name = stc.Name or "Stepper"
                stc.Min = stc.Min or 0
                stc.Max = stc.Max or 100
                stc.Step = stc.Step or 1
                stc.Default = Clamp(stc.Default or stc.Min, stc.Min, stc.Max)
                stc.Callback = stc.Callback or function() end
                local c = Card(42, true)
                NameLabel(c, stc.Name, 14)
                local holder = New("Frame", {
                    BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(112, 28), ZIndex = 15, Parent = c,
                })
                local function Btn(sym, x)
                    local b = New("TextButton", {
                        Text = sym, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 16,
                        BackgroundColor3 = ThemeColor("Elevated"), Position = UDim2.fromOffset(x, 0),
                        Size = UDim2.fromOffset(28, 28), ZIndex = 16, Parent = holder,
                    })
                    Corner(8, b); Bind(b, "BackgroundColor3", "Elevated"); Bind(b, "TextColor3", "Text")
                    Connect(b.MouseEnter, function() Tween(b, EASE.Fast, {BackgroundTransparency = 0.4}) end)
                    Connect(b.MouseLeave, function() Tween(b, EASE.Fast, {BackgroundTransparency = 0}) end)
                    return b
                end
                local minus, plus = Btn("−", 0), Btn("+", 84)
                local val = Text({
                    Text = "", Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
                    Position = UDim2.fromOffset(28, 0), Size = UDim2.fromOffset(56, 28), ZIndex = 16, Parent = holder,
                })
                BindAccent(val, "TextColor3", 1)
                local S = {Value = stc.Default}
                function S:Set(v, silent)
                    v = Clamp(Snap(v, stc.Step), stc.Min, stc.Max)
                    S.Value = v; val.Text = tostring(Round(v, 2))
                    if not silent then task.spawn(stc.Callback, v) end
                end
                local function Hold(btn, dir)
                    Connect(btn.InputBegan, function(input)
                        if IsPointer(input) and not S:IsLocked() then
                            S:Set(S.Value + dir * stc.Step)
                            local held = true
                            local e; e = input.Changed:Connect(function()
                                if input.UserInputState == Enum.UserInputState.End then held = false; e:Disconnect() end
                            end)
                            task.spawn(function()
                                task.wait(0.4)
                                while held do S:Set(S.Value + dir * stc.Step); task.wait(0.06) end
                            end)
                        end
                    end)
                end
                Hold(minus, -1); Hold(plus, 1)
                Register(stc.Flag, S, stc, "Stepper")
                Decorate(S, c, stc, "Stepper")
                S:Set(stc.Default, true)
                return S
            end

            ------------------------------------------------------------------
            -- DROPDOWN (single) + MULTI DROPDOWN  — shared builder
            ------------------------------------------------------------------
            local function BuildDropdown(dc, multi)
                dc = dc or {}
                dc.Name = dc.Name or (multi and "Multi Dropdown" or "Dropdown")
                dc.Options = dc.Options or {}
                dc.Callback = dc.Callback or function() end
                dc.Searchable = dc.Searchable ~= false

                local c, st = Card(42, true)
                c.ClipsDescendants = false
                NameLabel(c, dc.Name, 14).Size = UDim2.new(0.5, -14, 1, 0)

                local valLbl = Text({
                    Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0),
                    Size = UDim2.new(0.5, -50, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = c,
                })
                BindAccent(valLbl, "TextColor3", 1)
                local arrow = New("ImageLabel", {
                    BackgroundTransparency = 1, Image = "rbxassetid://7072706796",
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16), ImageTransparency = 0.3, ZIndex = 15, Parent = c,
                })
                Bind(arrow, "ImageColor3", "Text")
                arrow.Image = "rbxassetid://6031091004" -- chevron down

                -- popup lives at Root so it never gets clipped by scroll frames
                local popup = New("CanvasGroup", {
                    Name = "DropdownPopup", BackgroundColor3 = ThemeColor("Surface"),
                    BorderSizePixel = 0, GroupTransparency = 1, Visible = false,
                    ZIndex = 350, Parent = Root,
                })
                Corner(12, popup); Bind(popup, "BackgroundColor3", "Surface")
                local ps = Stroke(NovaLib.Accent, 1.2, 0.55, popup)
                local popScale = New("UIScale", {Scale = 0.94, Parent = popup})
                List(0, popup)

                local searchBox
                if dc.Searchable and not multi then
                    -- search only meaningful when many options
                end
                local searchHolder = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, ZIndex = 351, Visible = #dc.Options > 6, Parent = popup})
                searchBox = New("TextBox", {
                    BackgroundColor3 = ThemeColor("Elevated"), Text = "", PlaceholderText = "Search…",
                    ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13,
                    Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -8), ZIndex = 352, Parent = searchHolder,
                })
                Corner(8, searchBox); Padding(0, 10, 0, 10, searchBox)
                Bind(searchBox, "BackgroundColor3", "Elevated"); Bind(searchBox, "TextColor3", "Text"); Bind(searchBox, "PlaceholderColor3", "SubText")

                local list = New("ScrollingFrame", {
                    BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 2,
                    Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ZIndex = 351, Parent = popup,
                })
                Padding(4, 4, 4, 4, list); List(2, list)

                local D = {Options = dc.Options, Value = multi and {} or nil, Open = false}
                local optionBtns = {}

                local function Summary()
                    if multi then
                        local n = 0
                        local names = {}
                        for k, v in pairs(D.Value) do if v then n += 1; table.insert(names, k) end end
                        table.sort(names)
                        if n == 0 then return "None" end
                        if n <= 2 then return table.concat(names, ", ") end
                        return n .. " selected"
                    end
                    return D.Value or "None"
                end

                local function Selected(opt)
                    if multi then return D.Value[opt] == true end
                    return D.Value == opt
                end

                local function Restyle()
                    for opt, o in pairs(optionBtns) do
                        local sel = Selected(opt)
                        Tween(o.Btn, EASE.Fast, {BackgroundTransparency = sel and 0.86 or 1})
                        Tween(o.Check, EASE.Fast, {ImageTransparency = sel and 0 or 1})
                        Tween(o.Lbl, EASE.Fast, {TextTransparency = sel and 0 or 0.15})
                    end
                    valLbl.Text = Summary()
                end

                local function Reposition()
                    local abs, size = c.AbsolutePosition, c.AbsoluteSize
                    local vp = Root.AbsoluteSize
                    local rows = 0
                    for _, o in pairs(optionBtns) do if o.Btn.Visible then rows += 1 end end
                    local h = math.min(rows, 6) * 34 + 8 + (searchHolder.Visible and 36 or 0)
                    local w = math.max(size.X, 180)
                    local x = Clamp(abs.X + size.X - w, 8, vp.X - w - 8)
                    local y = abs.Y + size.Y + 6
                    local upward = y + h > vp.Y - 8
                    if upward then y = abs.Y - h - 6 end
                    popup.Position = UDim2.fromOffset(x, y)
                    popup.Size = UDim2.fromOffset(w, h)
                    list.Size = UDim2.new(1, 0, 0, h - (searchHolder.Visible and 36 or 0))
                    popup.AnchorPoint = Vector2.new(0, 0)
                end

                local function Build()
                    for _, o in pairs(optionBtns) do o.Btn:Destroy() end
                    table.clear(optionBtns)
                    for i, opt in ipairs(D.Options) do
                        local b = New("TextButton", {
                            Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1),
                            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, ZIndex = 352, Parent = list,
                        })
                        Corner(8, b); AccentGrad(b, 0)
                        local l = Text({
                            Text = tostring(opt), Font = Enum.Font.GothamMedium, TextSize = 13,
                            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), ZIndex = 353, Parent = b,
                        })
                        Bind(l, "TextColor3", "Text")
                        local ck = New("ImageLabel", {
                            BackgroundTransparency = 1, Image = "rbxassetid://7072706620", ImageTransparency = 1,
                            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                            Size = UDim2.fromOffset(15, 15), ZIndex = 353, Parent = b,
                        })
                        BindAccent(ck, "ImageColor3", 1)
                        Connect(b.MouseEnter, function()
                            if not Selected(opt) then Tween(b, EASE.Fast, {BackgroundTransparency = 0.94}) end
                        end)
                        Connect(b.MouseLeave, function()
                            if not Selected(opt) then Tween(b, EASE.Fast, {BackgroundTransparency = 1}) end
                        end)
                        Connect(b.Activated, function()
                            Ripple(b)
                            if multi then
                                D.Value[opt] = not D.Value[opt] or nil
                                Restyle()
                                task.spawn(dc.Callback, D:Get())
                            else
                                D:Set(opt)
                                D:Close()
                            end
                        end)
                        optionBtns[opt] = {Btn = b, Lbl = l, Check = ck}
                    end
                    Restyle()
                end

                Connect(searchBox:GetPropertyChangedSignal("Text"), function()
                    local q = searchBox.Text:lower()
                    for opt, o in pairs(optionBtns) do
                        o.Btn.Visible = q == "" or tostring(opt):lower():find(q, 1, true) ~= nil
                    end
                    Reposition()
                end)

                function D:Open_()
                    if D.Open then return end
                    -- close others
                    NovaLib._ActiveDropdown = NovaLib._ActiveDropdown
                    if NovaLib._ActiveDropdown and NovaLib._ActiveDropdown ~= D then NovaLib._ActiveDropdown:Close() end
                    NovaLib._ActiveDropdown = D
                    D.Open = true
                    searchBox.Text = ""
                    for _, o in pairs(optionBtns) do o.Btn.Visible = true end
                    Reposition()
                    popup.Visible = true
                    Tween(popup, EASE.Spring, {GroupTransparency = 0})
                    Tween(popScale, EASE.Spring, {Scale = 1})
                    Tween(arrow, EASE.Med, {Rotation = 180})
                end
                function D:Close()
                    if not D.Open then return end
                    D.Open = false
                    Tween(popup, EASE.In, {GroupTransparency = 1})
                    Tween(popScale, EASE.In, {Scale = 0.94})
                    Tween(arrow, EASE.Med, {Rotation = 0})
                    task.delay(0.26, function() if not D.Open then popup.Visible = false end end)
                    if NovaLib._ActiveDropdown == D then NovaLib._ActiveDropdown = nil end
                end

                -- Click-away
                Connect(UserInputService.InputBegan, function(input)
                    if D.Open and IsPointer(input) then
                        local p = input.Position
                        local a, s = popup.AbsolutePosition, popup.AbsoluteSize
                        local ca, cs = c.AbsolutePosition, c.AbsoluteSize
                        local inPopup = p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
                        local inCard = p.X >= ca.X and p.X <= ca.X + cs.X and p.Y >= ca.Y and p.Y <= ca.Y + cs.Y
                        if not inPopup and not inCard then D:Close() end
                    end
                end)
                -- reposition on scroll / resize
                Connect(Scroll:GetPropertyChangedSignal("CanvasPosition"), function() if D.Open then Reposition() end end)

                Interactive(c, {Click = function()
                    if D:IsLocked() then return end
                    if D.Open then D:Close() else D:Open_() end
                end})

                function D:Get()
                    if multi then
                        local out = {}
                        for k, v in pairs(D.Value) do if v then table.insert(out, k) end end
                        table.sort(out)
                        return out
                    end
                    return D.Value
                end
                function D:Set(v, silent)
                    if multi then
                        D.Value = {}
                        if type(v) == "table" then
                            for k, x in pairs(v) do
                                if type(k) == "number" then D.Value[x] = true
                                elseif x then D.Value[k] = true end
                            end
                        end
                        Restyle()
                        if not silent then task.spawn(dc.Callback, D:Get()) end
                    else
                        if table.find(D.Options, v) then
                            D.Value = v
                            Restyle()
                            if not silent then task.spawn(dc.Callback, v) end
                        end
                    end
                end
                function D:Refresh(opts, keep)
                    D.Options = opts
                    if not keep then D.Value = multi and {} or nil end
                    searchHolder.Visible = #opts > 6
                    Build()
                    if D.Open then Reposition() end
                end

                Register(dc.Flag, D, dc, multi and "MultiDropdown" or "Dropdown")
                Decorate(D, c, dc, multi and "Multi Dropdown" or "Dropdown")
                Build()
                if multi then
                    D:Set(dc.Default or {}, true)
                else
                    D:Set(dc.Default or D.Options[1], true)
                    task.spawn(dc.Callback, D.Value)
                end
                return D
            end
            function E:AddDropdown(dc) return BuildDropdown(dc, false) end
            function E:AddMultiDropdown(dc) return BuildDropdown(dc, true) end

            ------------------------------------------------------------------
            -- KEYBIND
            ------------------------------------------------------------------
            function E:AddBind(bc)
                bc = bc or {}
                bc.Name = bc.Name or "Keybind"
                bc.Default = bc.Default or Enum.KeyCode.Unknown
                bc.Hold = bc.Hold or false
                bc.Callback = bc.Callback or function() end
                local c = Card(42, true)
                NameLabel(c, bc.Name, 14)

                local chip = New("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundColor3 = ThemeColor("Elevated"),
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(60, 26), ZIndex = 16, Parent = c,
                })
                Corner(8, chip); Bind(chip, "BackgroundColor3", "Elevated")
                local cs = Stroke(ThemeColor("Stroke"), 1, 0.3, chip)
                Bind(cs, "Color", "Stroke")
                local chipLbl = Text({
                    Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
                    Size = UDim2.fromScale(1, 1), ZIndex = 17, Parent = chip,
                })
                Bind(chipLbl, "TextColor3", "Text")

                local B = {Value = bc.Default, Binding = false}
                local function Refresh()
                    local t = B.Binding and "…" or KeyName(B.Value)
                    if t == "Unknown" then t = "None" end
                    chipLbl.Text = t
                    local w = math.max(48, #t * 8 + 22)
                    Tween(chip, EASE.Spring, {Size = UDim2.fromOffset(w, 26)})
                end
                function B:Set(k, silent)
                    B.Value = k; B.Binding = false
                    Tween(cs, EASE.Fast, {Color = ThemeColor("Stroke"), Transparency = 0.3})
                    Refresh()
                    if KeyOverlay.Visible then RefreshKeyOverlay() end
                end
                function B:Get() return B.Value end

                Connect(chip.Activated, function()
                    if B:IsLocked() then return end
                    B.Binding = true
                    Tween(cs, EASE.Fast, {Color = NovaLib.Accent, Transparency = 0})
                    Refresh()
                end)
                Connect(UserInputService.InputBegan, function(input, gpe)
                    if B.Binding then
                        local key
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then B:Set(Enum.KeyCode.Unknown) return end
                            if not BadKeys[input.KeyCode] then key = input.KeyCode end
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.MouseButton2
                            or input.UserInputType == Enum.UserInputType.MouseButton3 then
                            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then key = input.UserInputType end
                        end
                        if key then B:Set(key) end
                    elseif not gpe and B.Value ~= Enum.KeyCode.Unknown and not B:IsLocked() then
                        if input.KeyCode == B.Value or input.UserInputType == B.Value then
                            if bc.Hold then task.spawn(bc.Callback, true) else task.spawn(bc.Callback) end
                        end
                    end
                end)
                Connect(UserInputService.InputEnded, function(input)
                    if bc.Hold and not B.Binding and B.Value ~= Enum.KeyCode.Unknown then
                        if input.KeyCode == B.Value or input.UserInputType == B.Value then task.spawn(bc.Callback, false) end
                    end
                end)

                Register(bc.Flag, B, bc, "Bind")
                Decorate(B, c, bc, "Keybind")
                table.insert(keybinds, {Name = bc.Name, Get = function() return B.Value end})
                B:Set(bc.Default, true)
                return B
            end

            ------------------------------------------------------------------
            -- TEXTBOX
            ------------------------------------------------------------------
            function E:AddTextbox(tc)
                tc = tc or {}
                tc.Name = tc.Name or "Textbox"
                tc.Default = tc.Default or ""
                tc.Placeholder = tc.Placeholder or "Type here…"
                tc.Callback = tc.Callback or function() end
                local c = Card(42, true)
                NameLabel(c, tc.Name, 14).Size = UDim2.new(0.45, 0, 1, 0)
                local box = New("TextBox", {
                    BackgroundColor3 = ThemeColor("Elevated"), Text = tc.Default,
                    PlaceholderText = tc.Placeholder, ClearTextOnFocus = false,
                    Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0.5, -12, 0, 28), ZIndex = 16, Parent = c,
                })
                Corner(8, box); Padding(0, 10, 0, 10, box)
                Bind(box, "BackgroundColor3", "Elevated"); Bind(box, "TextColor3", "Text"); Bind(box, "PlaceholderColor3", "SubText")
                local bs = Stroke(NovaLib.Accent, 1.2, 1, box)
                Connect(box.Focused, function() Tween(bs, EASE.Fast, {Transparency = 0.2}) end)
                local T = {Value = tc.Default}
                Connect(box.FocusLost, function(enter)
                    Tween(bs, EASE.Fast, {Transparency = 1})
                    T.Value = box.Text
                    task.spawn(tc.Callback, box.Text)
                    if tc.TextDisappear then box.Text = "" end
                end)
                function T:Set(v, silent) box.Text = tostring(v); T.Value = box.Text; if not silent then task.spawn(tc.Callback, T.Value) end end
                function T:Get() return T.Value end
                Register(tc.Flag, T, tc, "Textbox")
                return Decorate(T, c, tc, "Textbox")
            end

            ------------------------------------------------------------------
            -- COLORPICKER (HSV, touch friendly, popup at root)
            ------------------------------------------------------------------
            function E:AddColorpicker(cc)
                cc = cc or {}
                cc.Name = cc.Name or "Color"
                cc.Default = cc.Default or Color3.fromRGB(255, 0, 0)
                cc.Callback = cc.Callback or function() end

                local c = Card(42, true)
                c.ClipsDescendants = false
                NameLabel(c, cc.Name, 14)

                local swatch = New("Frame", {
                    BackgroundColor3 = cc.Default, BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
                    Size = UDim2.fromOffset(38, 22), ZIndex = 16, Parent = c,
                })
                Corner(7, swatch); Stroke(Color3.new(1, 1, 1), 1, 0.7, swatch)

                local popup = New("CanvasGroup", {
                    Name = "ColorPopup", BackgroundColor3 = ThemeColor("Surface"), BorderSizePixel = 0,
                    Size = UDim2.fromOffset(mobile and 230 or 250, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    GroupTransparency = 1, Visible = false, ZIndex = 350, Parent = Root,
                })
                Corner(14, popup); Bind(popup, "BackgroundColor3", "Surface")
                Stroke(NovaLib.Accent, 1.2, 0.55, popup)
                Padding(12, 12, 12, 12, popup); List(10, popup)
                local pScale = New("UIScale", {Scale = 0.94, Parent = popup})

                local h, s, v = cc.Default:ToHSV()

                local sv = New("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                    Size = UDim2.new(1, 0, 0, 130), LayoutOrder = 1, ZIndex = 351, Parent = popup,
                })
                Corner(10, sv)
                local white = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 352, Parent = sv})
                Corner(10, white)
                New("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = white})
                local black = New("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 353, Parent = sv})
                Corner(10, black)
                New("UIGradient", {Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black})
                local svKnob = New("Frame", {
                    BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.fromOffset(16, 16), ZIndex = 355, Parent = sv,
                })
                Corner(8, svKnob); Stroke(Color3.new(1, 1, 1), 2, 0, svKnob)

                local hue = New("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, ZIndex = 351, Parent = popup,
                })
                Corner(7, hue)
                New("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
                    }), Parent = hue,
                })
                local hueKnob = New("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 20), ZIndex = 353, Parent = hue,
                })
                Corner(3, hueKnob); Stroke(Color3.new(0, 0, 0), 1, 0.6, hueKnob)

                local hexRow = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 3, ZIndex = 351, Parent = popup})
                local hexBox = New("TextBox", {
                    BackgroundColor3 = ThemeColor("Elevated"), Text = "", ClearTextOnFocus = false,
                    PlaceholderText = "#RRGGBB", Font = Enum.Font.GothamMedium, TextSize = 13,
                    Size = UDim2.new(1, 0, 1, 0), ZIndex = 352, Parent = hexRow,
                })
                Corner(8, hexBox); Bind(hexBox, "BackgroundColor3", "Elevated"); Bind(hexBox, "TextColor3", "Text"); Bind(hexBox, "PlaceholderColor3", "SubText")

                local C = {Value = cc.Default, Open = false}
                local function Apply(silent)
                    local col = Color3.fromHSV(h, s, v)
                    C.Value = col
                    swatch.BackgroundColor3 = col
                    sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svKnob.Position = UDim2.fromScale(s, 1 - v)
                    hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
                    hexBox.Text = "#" .. col:ToHex():upper()
                    if not silent then task.spawn(cc.Callback, col) end
                end

                local dragMode
                local function FromPos(pos)
                    if dragMode == "sv" then
                        s = Clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
                        v = 1 - Clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
                    elseif dragMode == "hue" then
                        h = Clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
                    end
                    Apply()
                end
                local function Grab(btn, mode)
                    Connect(btn.InputBegan, function(input)
                        if IsPointer(input) then
                            dragMode = mode; FromPos(input.Position)
                            local e; e = input.Changed:Connect(function()
                                if input.UserInputState == Enum.UserInputState.End then dragMode = nil; e:Disconnect() end
                            end)
                        end
                    end)
                end
                Grab(sv, "sv"); Grab(hue, "hue")
                Connect(UserInputService.InputChanged, function(input)
                    if dragMode and IsMove(input) then FromPos(input.Position) end
                end)
                Connect(hexBox.FocusLost, function()
                    local hex = hexBox.Text:gsub("#", "")
                    if #hex == 6 then
                        local ok, col = pcall(Color3.fromHex, hex)
                        if ok then h, s, v = col:ToHSV(); Apply() end
                    end
                    hexBox.Text = "#" .. C.Value:ToHex():upper()
                end)

                local function Reposition()
                    local abs, size = c.AbsolutePosition, c.AbsoluteSize
                    local vp = Root.AbsoluteSize
                    local pw, ph = popup.AbsoluteSize.X, math.max(popup.AbsoluteSize.Y, 240)
                    local x = Clamp(abs.X + size.X - pw, 8, vp.X - pw - 8)
                    local y = abs.Y + size.Y + 6
                    if y + ph > vp.Y - 8 then y = math.max(8, abs.Y - ph - 6) end
                    popup.Position = UDim2.fromOffset(x, y)
                end

                function C:Open_()
                    if C.Open then return end
                    if NovaLib._ActiveColor and NovaLib._ActiveColor ~= C then NovaLib._ActiveColor:Close() end
                    NovaLib._ActiveColor = C
                    C.Open = true
                    popup.Visible = true; Reposition()
                    Tween(popup, EASE.Spring, {GroupTransparency = 0})
                    Tween(pScale, EASE.Spring, {Scale = 1})
                end
                function C:Close()
                    if not C.Open then return end
                    C.Open = false
                    Tween(popup, EASE.In, {GroupTransparency = 1}); Tween(pScale, EASE.In, {Scale = 0.94})
                    task.delay(0.26, function() if not C.Open then popup.Visible = false end end)
                    if NovaLib._ActiveColor == C then NovaLib._ActiveColor = nil end
                end
                Connect(UserInputService.InputBegan, function(input)
                    if C.Open and IsPointer(input) then
                        local p = input.Position
                        local a, s2 = popup.AbsolutePosition, popup.AbsoluteSize
                        local ca, cs = c.AbsolutePosition, c.AbsoluteSize
                        local inP = p.X >= a.X and p.X <= a.X + s2.X and p.Y >= a.Y and p.Y <= a.Y + s2.Y
                        local inC = p.X >= ca.X and p.X <= ca.X + cs.X and p.Y >= ca.Y and p.Y <= ca.Y + cs.Y
                        if not inP and not inC then C:Close() end
                    end
                end)
                Connect(Scroll:GetPropertyChangedSignal("CanvasPosition"), function() if C.Open then Reposition() end end)
                Interactive(c, {Click = function()
                    if C:IsLocked() then return end
                    if C.Open then C:Close() else C:Open_() end
                end})

                function C:Set(col, silent)
                    if typeof(col) ~= "Color3" then return end
                    h, s, v = col:ToHSV(); Apply(silent)
                end
                function C:Get() return C.Value end

                Register(cc.Flag, C, cc, "Colorpicker")
                Decorate(C, c, cc, "Colorpicker")
                Apply(true)
                task.spawn(cc.Callback, C.Value)
                return C
            end

            return E
        end

        ------------------------------------------------------------------
        --  SECTION
        ------------------------------------------------------------------
        local TabAPI = ElementFactory(Scroll, nil)

        function TabAPI:AddSection(sc)
            sc = sc or {}
            sc.Name = sc.Name or "Section"

            local holder = New("Frame", {
                Name = "Section", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 13, Parent = Scroll,
            })
            List(6, holder)

            local head = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, ZIndex = 14, Parent = holder})
            local bar = New("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.fromOffset(3, 12), ZIndex = 15, Parent = head,
            })
            Corner(2, bar); AccentGrad(bar, 90)
            local lbl = Text({
                Text = string.upper(sc.Name), Font = Enum.Font.GothamBold, TextSize = 11,
                Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 15, Parent = head,
            })
            Bind(lbl, "TextColor3", "SubText")

            -- collapse chevron
            local collapsible = sc.Collapsible ~= false
            local chev
            local body = New("Frame", {
                Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ClipsDescendants = false,
                ZIndex = 14, Parent = holder,
            })
            List(6, body)

            local Section = ElementFactory(body, sc.Name)

            if collapsible then
                local hb = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 16, Parent = head})
                chev = New("ImageLabel", {
                    BackgroundTransparency = 1, Image = "rbxassetid://6031091004", ImageTransparency = 0.4,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14), ZIndex = 16, Parent = head,
                })
                Bind(chev, "ImageColor3", "Text")
                local collapsed = false
                local fullSize
                Connect(hb.Activated, function()
                    collapsed = not collapsed
                    if collapsed then
                        fullSize = body.AbsoluteSize.Y
                        body.AutomaticSize = Enum.AutomaticSize.None
                        body.Size = UDim2.new(1, 0, 0, fullSize)
                        body.ClipsDescendants = true
                        Tween(chev, EASE.Med, {Rotation = -90})
                        local t = Tween(body, EASE.Med, {Size = UDim2.new(1, 0, 0, 0)})
                    else
                        Tween(chev, EASE.Med, {Rotation = 0})
                        local t = Tween(body, EASE.Med, {Size = UDim2.new(1, 0, 0, fullSize or 0)})
                        t.Completed:Connect(function()
                            if not collapsed then
                                body.AutomaticSize = Enum.AutomaticSize.Y
                                body.ClipsDescendants = false
                            end
                        end)
                    end
                end)
                Connect(hb.MouseEnter, function() Tween(chev, EASE.Fast, {ImageTransparency = 0}) end)
                Connect(hb.MouseLeave, function() Tween(chev, EASE.Fast, {ImageTransparency = 0.4}) end)
            end

            function Section:SetName(n) lbl.Text = string.upper(n) end
            return Section
        end

        return TabAPI
    end

    ----------------------------------------------------------------------
    --  Built-in Settings tab helper (themes, accent, configs, HUD, etc.)
    ----------------------------------------------------------------------
    function Window:AddSettingsTab(opts)
        opts = opts or {}
        local tab = Window:MakeTab({Name = opts.Name or "Settings", Icon = opts.Icon or "settings"})

        local appearance = tab:AddSection({Name = "Appearance"})
        appearance:AddDropdown({
            Name = "Theme", Options = NovaLib:GetThemes(), Default = NovaLib.ThemeName,
            Callback = function(v) NovaLib:SetTheme(v) end, Save = false,
        })
        appearance:AddColorpicker({
            Name = "Accent", Default = NovaLib.Accent, Save = false,
            Callback = function(col)
                NovaLib:SetAccent(col, col:Lerp(Color3.fromRGB(255, 120, 255), 0.35))
            end,
        })
        appearance:AddSlider({
            Name = "UI Scale", Min = 60, Max = 130, Default = 100, Increment = 5, ValueName = "%", Save = false,
            Callback = function(v)
                userScale = v / 100
                targetScale = FitToScreen()
                if not Window.Hidden and not Window.Minimized then Tween(scaleObj, EASE.Med, {Scale = targetScale}) end
            end,
        })

        local hud = tab:AddSection({Name = "Overlays"})
        hud:AddToggle({Name = "Watermark (FPS / Ping)", Default = false, Save = false, Callback = function(v) Window:SetHUD(v) end})
        hud:AddToggle({Name = "Keybind List", Default = false, Save = false, Callback = function(v) Window:SetKeybindList(v) end})

        local cfgSec = tab:AddSection({Name = "Config Profiles"})
        local nameBox = cfgSec:AddTextbox({Name = "Profile Name", Placeholder = "my-config", Save = false})
        local profileDD
        profileDD = cfgSec:AddDropdown({
            Name = "Profiles", Options = (#NovaLib:ListConfigs() > 0) and NovaLib:ListConfigs() or {"(none)"},
            Save = false, Callback = function() end,
        })
        local function RefreshProfiles()
            local l = NovaLib:ListConfigs()
            profileDD:Refresh(#l > 0 and l or {"(none)"})
        end
        cfgSec:AddButton({Name = "Save Profile", Icon = "save", Callback = function()
            local n = nameBox:Get() ~= "" and nameBox:Get() or profileDD:Get()
            if not n or n == "" or n == "(none)" then
                NovaLib:MakeNotification({Name = "Enter a name", Content = "Type a profile name first.", Type = "Warning"})
                return
            end
            local ok, err = NovaLib:SaveConfig(n)
            NovaLib:MakeNotification({
                Name = ok and "Profile saved" or "Save failed",
                Content = ok and ('Saved "' .. n .. '"') or tostring(err),
                Type = ok and "Success" or "Error",
            })
            RefreshProfiles()
        end})
        cfgSec:AddButton({Name = "Load Profile", Icon = "download", Callback = function()
            local n = profileDD:Get()
            if not n or n == "(none)" then return end
            local ok, err = NovaLib:LoadConfig(n)
            NovaLib:MakeNotification({
                Name = ok and "Profile loaded" or "Load failed",
                Content = ok and ('Applied "' .. n .. '"') or tostring(err),
                Type = ok and "Success" or "Error",
            })
        end})
        cfgSec:AddButton({Name = "Delete Profile", Icon = "trash-2", Callback = function()
            local n = profileDD:Get()
            if not n or n == "(none)" then return end
            NovaLib:Dialog({
                Title = "Delete profile?", Content = 'This permanently removes "' .. n .. '".',
                Buttons = {
                    {Name = "Cancel"},
                    {Name = "Delete", Primary = true, Callback = function()
                        NovaLib:DeleteConfig(n); RefreshProfiles()
                        NovaLib:MakeNotification({Name = "Deleted", Content = n, Type = "Warning"})
                    end},
                },
            })
        end})
        cfgSec:AddToggle({Name = "Auto-load on start", Default = false, Save = false, Callback = function(v)
            if v then NovaLib:SaveConfig("autoload") end
        end})

        local misc = tab:AddSection({Name = "Interface"})
        misc:AddBind({Name = "Toggle UI", Default = cfg.ToggleKey, Save = false, Callback = function() end})
        misc:AddButton({Name = "Destroy UI", Icon = "trash-2", Callback = function()
            NovaLib:Dialog({
                Title = "Destroy interface?", Content = "This removes the UI and stops all its connections.",
                Buttons = {{Name = "Cancel"}, {Name = "Destroy", Primary = true, Callback = function() NovaLib:Destroy() end}},
            })
        end})
        return tab
    end

    function Window:SelectTab(idx)
        local t = Window.Tabs[idx]
        if t then SelectTab(t) end
    end
    function Window:Notify(c) return NovaLib:MakeNotification(c) end
    function Window:SetScale(s) userScale = s; targetScale = FitToScreen(); Tween(scaleObj, EASE.Med, {Scale = targetScale}) end

    return Window
end

return NovaLib

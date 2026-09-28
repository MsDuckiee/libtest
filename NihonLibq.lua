--[[
    Nihon Lib  |  v3.0
    Mobile + PC interface library.
    Minimalistic Dark Theme + Key System + Top Tabs
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

if type(env.NihonLibInstance) == "table" and type(env.NihonLibInstance.Destroy) == "function" then
    pcall(env.NihonLibInstance.Destroy, env.NihonLibInstance)
end

local Nihon = {
    Version = "3.0.0",
    Flags = {},
    Windows = {},
    Folder = "NihonLib",
    Profile = "default",
    SaveConfig = false,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    -- New Config Options
    ShowKeySystem = false,
    KeySystemAnswer = "",
    ShowTabsOnTop = false,
}
env.NihonLibInstance = Nihon

local conns = {}
local function keep(c)
    conns[#conns + 1] = c
    return c
end

-- =========================================================
-- THEMES (Minimalistic Dark Default)
-- =========================================================
local Themes = {
    Dark = {
        Bg = Color3.fromRGB(18, 18, 20),
        Surface = Color3.fromRGB(24, 24, 28),
        Elevated = Color3.fromRGB(32, 32, 38),
        Stroke = Color3.fromRGB(48, 48, 56),
        Text = Color3.fromRGB(240, 240, 245),
        Sub = Color3.fromRGB(140, 140, 150),
        Accent = Color3.fromRGB(255, 70, 90), -- Red/Pink default
        Accent2 = Color3.fromRGB(255, 130, 100),
    },
    Light = {
        Bg = Color3.fromRGB(245, 245, 248),
        Surface = Color3.fromRGB(255, 255, 255),
        Elevated = Color3.fromRGB(235, 235, 240),
        Stroke = Color3.fromRGB(210, 210, 220),
        Text = Color3.fromRGB(20, 20, 25),
        Sub = Color3.fromRGB(100, 100, 110),
        Accent = Color3.fromRGB(220, 50, 80),
        Accent2 = Color3.fromRGB(255, 120, 100),
    },
    Midnight = {
        Bg = Color3.fromRGB(10, 10, 15),
        Surface = Color3.fromRGB(15, 15, 22),
        Elevated = Color3.fromRGB(22, 22, 32),
        Stroke = Color3.fromRGB(40, 40, 55),
        Text = Color3.fromRGB(230, 230, 240),
        Sub = Color3.fromRGB(130, 130, 150),
        Accent = Color3.fromRGB(90, 130, 255),
        Accent2 = Color3.fromRGB(160, 110, 255),
    },
    Ocean = {
        Bg = Color3.fromRGB(10, 18, 28),
        Surface = Color3.fromRGB(15, 25, 38),
        Elevated = Color3.fromRGB(22, 35, 52),
        Stroke = Color3.fromRGB(45, 65, 90),
        Text = Color3.fromRGB(225, 240, 255),
        Sub = Color3.fromRGB(130, 160, 190),
        Accent = Color3.fromRGB(50, 190, 220),
        Accent2 = Color3.fromRGB(70, 120, 255),
    },
}
local ThemeOrder = {"Dark", "Light", "Midnight", "Ocean"}
local Pal = {}
local themeName = "Dark"

local function loadPalette(name)
    local base = Themes.Dark
    local src = Themes[name] or base
    for k, v in pairs(base) do
        Pal[k] = src[k] or v
    end
end
loadPalette("Dark")

-- =========================================================
-- CORE UTILS
-- =========================================================
local Status = {
    Info = Color3.fromRGB(96, 156, 255),
    Success = Color3.fromRGB(78, 214, 140),
    Warning = Color3.fromRGB(255, 192, 72),
    Error = Color3.fromRGB(255, 90, 102),
}

local Fonts = {
    Modern = {Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold},
    Rounded = {Enum.Font.Nunito, Enum.Font.Nunito, Enum.Font.FredokaOne},
    Mono = {Enum.Font.RobotoMono, Enum.Font.RobotoMono, Enum.Font.RobotoMono},
}
local FontOrder = {"Modern", "Rounded", "Mono"}
local currentFont = "Modern"
local animSpeed = 1
local currentScale = 1

local Root = Instance.new("ScreenGui")
Root.Name = "NihonLib"
Root.ResetOnSpawn = false
Root.IgnoreGuiInset = true
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.DisplayOrder = 9999

do
    local mounted = false
    if syn and syn.protect_gui then pcall(syn.protect_gui, Root) end
    if gethui then mounted = pcall(function() Root.Parent = gethui() end) and Root.Parent ~= nil end
    if not mounted then mounted = pcall(function() Root.Parent = game:GetService("CoreGui") end) and Root.Parent ~= nil end
    if not mounted then Root.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local function viewport()
    local v = Root.AbsoluteSize
    if v.X < 50 or v.Y < 50 then
        local cam = workspace.CurrentCamera
        if cam then return cam.ViewportSize end
        return Vector2.new(1280, 720)
    end
    return v
end

local binds = setmetatable({}, {__mode = "k"})
local fontObjs = setmetatable({}, {__mode = "k"})
local themeHooks = {}
local tweens = setmetatable({}, {__mode = "k"})

local function play(obj, dur, props, style, dir)
    local names = {}
    for k in pairs(props) do names[#names + 1] = k end
    table.sort(names)
    local key = table.concat(names, ",")
    local slot = tweens[obj]
    if not slot then slot = {} tweens[obj] = slot end
    if slot[key] then slot[key]:Cancel() end
    local info = TweenInfo.new(math.max(dur / animSpeed, 0.001), style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    slot[key] = tw
    tw:Play()
    return tw
end

local function after(tw, fn)
    local c
    c = tw.Completed:Connect(function(state)
        c:Disconnect()
        if state == Enum.PlaybackState.Completed then fn() end
    end)
end

local function mk(class, props, kids)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
    if class == "TextButton" then
        inst.Text = ""
        inst.AutoButtonColor = false
    elseif class == "TextLabel" then
        inst.Text = ""
    end
    local parent
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
    end
    if kids then for _, c in ipairs(kids) do c.Parent = inst end end
    if parent then inst.Parent = parent end
    return inst
end

local function bind(obj, prop, key, fn)
    local list = binds[obj]
    if not list then list = {} binds[obj] = list end
    list[#list + 1] = {prop = prop, key = key, fn = fn}
    local v = Pal[key]
    if fn then v = fn(v, Pal) end
    obj[prop] = v
    return obj
end

local function refreshTheme(animated, accentOnly)
    for obj, list in pairs(binds) do
        for _, rec in ipairs(list) do
            if not accentOnly or rec.key == "Accent" or rec.key == "Accent2" then
                local v = Pal[rec.key]
                if rec.fn then v = rec.fn(v, Pal) end
                if animated and typeof(v) == "Color3" and obj.Parent then
                    play(obj, 0.35, {[rec.prop] = v})
                else
                    obj[rec.prop] = v
                end
            end
        end
    end
    for _, hook in ipairs(themeHooks) do pcall(hook, animated) end
end

local function onTheme(fn) themeHooks[#themeHooks + 1] = fn end

local function round(parent, r) return mk("UICorner", {CornerRadius = UDim.new(0, r), Parent = parent}) end

local function outline(parent, key, thick, trans)
    local s = mk("UIStroke", {Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent})
    bind(s, "Color", key or "Stroke")
    return s
end

local function inset(parent, t, r, b, l)
    return mk("UIPadding", {PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0), Parent = parent})
end

local function stack(parent, gap, dir)
    return mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 0), FillDirection = dir or Enum.FillDirection.Vertical, Parent = parent})
end

local function accentGradient(parent, rot)
    local g = mk("UIGradient", {Rotation = rot or 0, Parent = parent})
    bind(g, "Color", "Accent", function(_, p) return ColorSequence.new(p.Accent, p.Accent2) end)
    return g
end

local function tx(class, props, weight, tone)
    local o = Instance.new(class)
    o.BackgroundTransparency = 1
    o.BorderSizePixel = 0
    o.Font = Fonts[currentFont][weight or 2]
    o.TextSize = 13
    o.TextXAlignment = Enum.TextXAlignment.Left
    o.Text = ""
    if class == "TextButton" then o.AutoButtonColor = false
    elseif class == "TextBox" then
        o.ClearTextOnFocus = false
        bind(o, "PlaceholderColor3", "Sub")
    end
    local parent
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else o[k] = v end
        end
    end
    bind(o, "TextColor3", tone or "Text")
    fontObjs[o] = weight or 2
    if parent then o.Parent = parent end
    return o
end

local function setFont(name)
    if not Fonts[name] then return end
    currentFont = name
    for obj, w in pairs(fontObjs) do obj.Font = Fonts[name][w] end
end

-- =========================================================
-- ICON SYSTEM (Using basic glyphs for minimalism)
-- =========================================================
local Glyphs = {
    ["info"] = "i", ["check-circle"] = "+", ["check"] = "+", ["alert-triangle"] = "!", ["alert-circle"] = "!",
    ["x-circle"] = "x", ["x"] = "x", ["minus"] = "-", ["chevron-down"] = "v", ["chevron-up"] = "^",
    ["chevron-right"] = ">", ["search"] = "o", ["menu"] = "=", ["activity"] = "~", ["lock"] = "#",
    ["settings"] = "*", ["user"] = "u", ["shield"] = "s", ["sword"] = "!", ["zap"] = "z", ["globe"] = "g",
    ["home"] = "h", ["eye"] = "e", ["star"] = "*", ["bell"] = "b", ["list"] = "l", ["palette"] = "p",
    ["layers"] = "L", ["cpu"] = "c", ["map"] = "m", ["wrench"] = "w", ["flag"] = "f", ["help-circle"] = "?"
}

local function makeIcon(parent, name, size, tone, props)
    local holder = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size)})
    if props then for k, v in pairs(props) do holder[k] = v end end
    holder.Parent = parent
    local glyph = tx("TextLabel", {
        Size = UDim2.fromScale(1, 1), TextSize = math.floor(size * 0.95),
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = holder,
    }, 3, (tone or "Text"))
    local api = {Holder = holder, Glyph = glyph}
    function api.Set(n)
        local key = tostring(n or "")
        glyph.Text = Glyphs[key] or key:sub(1, 1):upper()
    end
    function api.Color(c, animated)
        if animated then play(glyph, 0.2, {TextColor3 = c}) else glyph.TextColor3 = c end
    end
    api.Set(name)
    return api
end

-- =========================================================
-- INPUT & DRAGGING
-- =========================================================
local function isPointer(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function samePointer(a, b) return a.UserInputType == Enum.UserInputType.Touch and a == b or b.UserInputType == a.UserInputType end
local function v2(input) return Vector2.new(input.Position.X, input.Position.Y) end

local function trackPointer(gui, onDown, onMove, onUp)
    return gui.InputBegan:Connect(function(input)
        if not isPointer(input) then return end
        if onDown and onDown(input) == false then return end
        local mover, ender
        mover = UserInputService.InputChanged:Connect(function(moved)
            local mouseMove = input.UserInputType == Enum.UserInputType.MouseButton1 and moved.UserInputType == Enum.UserInputType.MouseMovement
            if mouseMove or moved == input then if onMove then onMove(v2(moved), moved) end end
        end)
        ender = UserInputService.InputEnded:Connect(function(done)
            if isPointer(done) and samePointer(input, done) then
                mover:Disconnect() ender:Disconnect()
                if onUp then onUp(v2(done)) end
            end
        end)
    end)
end

local function makeDraggable(handles, target, opts)
    opts = opts or {}
    local startInput, startPos, goal, current
    local dragging, moved = false, false
    local beat
    local function apply() target.Position = UDim2.fromOffset(current.X, current.Y) end
    local function step(dt)
        local a = 1 - math.exp(-dt * (opts.speed or 26))
        current = current:Lerp(goal, a)
        apply()
        if not dragging and (goal - current).Magnitude < 0.35 then
            current = goal apply() beat:Disconnect() beat = nil
        end
    end
    for _, h in ipairs(handles) do
        trackPointer(h, function(input)
            if opts.canDrag and not opts.canDrag() then return false end
            startInput = v2(input) startPos = target.AbsolutePosition
            goal = startPos current = startPos dragging, moved = true, false
            if opts.onBegin then opts.onBegin() end
            if beat then beat:Disconnect() end
            beat = RunService.RenderStepped:Connect(step)
        end, function(pos)
            local d = pos - startInput
            if not moved and d.Magnitude < 4 then return end
            moved = true
            local want = startPos + d
            goal = opts.clamp and opts.clamp(want) or want
        end, function()
            dragging = false
            if not moved and opts.onClick then opts.onClick() end
            if opts.onEnd then opts.onEnd(moved) end
        end)
    end
end

-- =========================================================
-- NOTIFICATIONS (Redesigned to match reference image)
-- =========================================================
local Notes = {active = {}, queue = {}, byKey = {}, queuedKey = {}, max = 5, duration = 4, position = "TopRight"}
local noteLayer = mk("Frame", {Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = Root})
local corners = {
    TopRight = {ax = 1, ay = 0}, TopLeft = {ax = 0, ay = 0}, TopCenter = {ax = 0.5, ay = 0},
    BottomRight = {ax = 1, ay = 1}, BottomLeft = {ax = 0, ay = 1}, BottomCenter = {ax = 0.5, ay = 1},
}
local noteLoop
local spawnNote

local function noteWidth() return math.clamp(math.floor(viewport().X - 28), 240, 360) end

local function notePos(slot, dx)
    local c = corners[Notes.position] or corners.TopRight
    local mx = c.ax == 0.5 and 0 or (c.ax == 1 and -14 or 14)
    local my = c.ay == 0 and (14 + slot) or -(14 + slot)
    return UDim2.new(c.ax, mx + (dx or 0), c.ay, my)
end

local function relayout()
    local c = corners[Notes.position] or corners.TopRight
    local cum = 0
    for _, n in ipairs(Notes.active) do
        n.slot = cum
        n.frame.AnchorPoint = Vector2.new(c.ax, c.ay)
        if not n.dragging then play(n.frame, 0.5, {Position = notePos(cum, 0)}) end
        cum = cum + n.height + 8
    end
end

local function promoteQueue()
    while #Notes.active < Notes.max and #Notes.queue > 0 do
        local entry = table.remove(Notes.queue, 1)
        Notes.queuedKey[entry.key] = nil
        spawnNote(entry)
    end
end

local function dismissNote(n)
    if n.dying then return end
    n.dying = true
    for i, x in ipairs(Notes.active) do if x == n then table.remove(Notes.active, i) break end end
    if Notes.byKey[n.key] == n then Notes.byKey[n.key] = nil end
    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax == 1 and (noteWidth() + 40) or (c.ax == 0 and -(noteWidth() + 40) or 0)
    play(n.frame, 0.35, {GroupTransparency = 1})
    if out ~= 0 then play(n.frame, 0.4, {Position = notePos(n.slot, out)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    else play(n.frame, 0.35, {Position = notePos(n.slot - 40)}) end
    task.delay(0.5, function() if n.frame then n.frame:Destroy() end end)
    relayout() promoteQueue()
end

local function bumpNote(n, extra)
    n.count = n.count + 1
    n.badge.Text = n.count .. "x"
    n.badge.Visible = true
    n.expires = os.clock() + (extra or n.time)
    n.pop.Scale = 1.45
    play(n.pop, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
    if not n.dragging then
        n.frame.Position = notePos(n.slot, 12)
        play(n.frame, 0.5, {Position = notePos(n.slot, 0)}, Enum.EasingStyle.Back)
    end
end

local function ensureNoteLoop()
    if noteLoop then return end
    noteLoop = RunService.Heartbeat:Connect(function(dt)
        local now = os.clock()
        for i = #Notes.active, 1, -1 do
            local n = Notes.active[i]
            if n and not n.dying and not n.sticky then
                if n.hover or n.dragging then n.expires = n.expires + dt end
                local left = n.expires - now
                if not n.custom then n.bar.Size = UDim2.new(math.clamp(left / n.time, 0, 1), 0, 0, 2) end
                if left <= 0 then dismissNote(n) end
            end
        end
        if #Notes.active == 0 and noteLoop then noteLoop:Disconnect() noteLoop = nil end
    end)
end

function spawnNote(entry)
    local cfg, handle = entry.cfg, entry.handle
    local color = Status[entry.kind]
    local w = noteWidth()
    local n = {
        key = entry.key, count = entry.count, handle = handle, height = 64, slot = 0,
        time = math.max(1, tonumber(cfg.Time) or Notes.duration), sticky = cfg.Sticky == true,
    }
    n.expires = os.clock() + n.time
    local content = tostring(cfg.Content or "")

    -- Minimalistic Card Design
    local frame = mk("CanvasGroup", {
        Name = "Note", Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1, Parent = noteLayer,
    })
    bind(frame, "BackgroundColor3", "Surface")
    round(frame, 6) -- Slightly rounded, not too much
    outline(frame, "Stroke", 1, 0.2)
    mk("UISizeConstraint", {MinSize = Vector2.new(0, 60), Parent = frame})

    -- Thin colored accent line on the left
    local accentStrip = mk("Frame", {
        Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 3, Parent = frame,
    })

    -- Title
    n.title = tx("TextLabel", {
        Text = tostring(cfg.Name or cfg.Title or "Notification"), 
        TextSize = 14, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 8),
        TextWrapped = true, TextColor3 = color, ZIndex = 3, Parent = frame,
    }, 3)

    -- Body
    n.body = tx("TextLabel", {
        Text = content, Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, 
        Position = UDim2.fromOffset(12, 28), TextWrapped = true, TextSize = 12, 
        TextColor3 = Pal.Text, Visible = content ~= "", ZIndex = 3, Parent = frame,
    }, 1)

    local est = TextService:GetTextSize(content, 12, Fonts[currentFont][1], Vector2.new(w - 24, 1000))
    n.height = math.max(50, 36 + est.Y + 14)

    -- Actions
    if type(cfg.Actions) == "table" and #cfg.Actions > 0 then
        local row = mk("Frame", {Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 36 + est.Y), BackgroundTransparency = 1, ZIndex = 3, Parent = frame})
        mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})
        n.height = n.height + 36
        for i, act in ipairs(cfg.Actions) do
            local label = tostring(act.Name or "OK")
            local size = TextService:GetTextSize(label, 12, Fonts[currentFont][3], Vector2.new(400, 30))
            local b = tx("TextButton", {
                Text = label, TextSize = 12, Size = UDim2.fromOffset(size.X + 20, 24), LayoutOrder = i,
                TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, Parent = row,
            }, 3)
            round(b, 4)
            if i == 1 then
                b.BackgroundColor3 = color
                b.TextColor3 = Color3.fromRGB(14, 14, 20)
            else
                bind(b, "BackgroundColor3", "Elevated")
                b.TextColor3 = Pal.Text
            end
            b.Activated:Connect(function()
                if act.Callback then pcall(act.Callback) end
                dismissNote(n)
            end)
        end
    end

    n.badge = tx("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, -2), Size = UDim2.fromOffset(0, 18), ZIndex = 6,
        AutomaticSize = Enum.AutomaticSize.X, Text = n.count .. "x", TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.78, BackgroundColor3 = color,
        TextColor3 = color, Visible = n.count > 1, Parent = frame,
    }, 3)
    round(n.badge, 10)
    inset(n.badge, 0, 8, 0, 8)
    n.pop = mk("UIScale", {Parent = n.badge})

    n.bar = mk("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = color, BackgroundTransparency = 0.25, Visible = not n.sticky, ZIndex = 5, Parent = frame,
    })

    n.frame = frame
    frame.MouseEnter:Connect(function() n.hover = true end)
    frame.MouseLeave:Connect(function() n.hover = false end)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local h = frame.AbsoluteSize.Y
        if h > 4 and math.abs(h - n.height) > 0.5 then n.height = h if not n.dying then task.defer(relayout) end end
    end)

    local startX, swiped = 0, false
    trackPointer(frame, function(input) startX = input.Position.X swiped = false n.dragging = true end, function(pos)
        local dx = pos.X - startX
        if math.abs(dx) > 6 then swiped = true end
        if swiped then n.frame.Position = notePos(n.slot, dx) end
    end, function(pos)
        n.dragging = false
        local dx = pos.X - startX
        if math.abs(dx) > 70 or (not swiped and cfg.ClickDismiss ~= false) then dismissNote(n) else relayout() end
    end)

    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax == 1 and (w + 40) or (c.ax == 0 and -(w + 40) or 0)
    frame.AnchorPoint = Vector2.new(c.ax, c.ay)
    frame.Position = out ~= 0 and notePos(0, out) or notePos(-50, 0)

    table.insert(Notes.active, 1, n)
    if entry.dedupe then Notes.byKey[n.key] = n end
    handle.n = n
    relayout()
    play(frame, 0.4, {GroupTransparency = 0})
    task.defer(function() if not n.dying and frame.Parent then frame.GroupTransparency = 0 relayout() end end)
    ensureNoteLoop()
    return n
end

function Nihon:MakeNotification(cfg)
    if type(cfg) ~= "table" then cfg = {Content = tostring(cfg)} end
    local kind = Status[cfg.Type] and cfg.Type or "Info"
    local name = tostring(cfg.Name or cfg.Title or "Notification")
    local content = tostring(cfg.Content or "")
    local key = kind .. "|" .. name .. "|" .. content
    local dedupe = not cfg.Sticky and not (type(cfg.Actions) == "table" and #cfg.Actions > 0)

    if dedupe then
        local live = Notes.byKey[key]
        if live and not live.dying then bumpNote(live, tonumber(cfg.Time)) return live.handle end
        local waiting = Notes.queuedKey[key]
        if waiting then waiting.count = waiting.count + 1 return waiting.handle end
    end

    local handle = {}
    function handle:Dismiss() if handle.n then dismissNote(handle.n) end end
    function handle:SetTitle(t) if handle.n then handle.n.title.Text = tostring(t) end end
    function handle:SetContent(t) if handle.n then handle.n.body.Text = tostring(t) handle.n.body.Visible = tostring(t) ~= "" end end
    function handle:SetProgress(p) local n = handle.n if not n then return end n.custom = true n.bar.Visible = true play(n.bar, 0.18, {Size = UDim2.new(math.clamp(p, 0, 1), 0, 0, 2)}) end

    local entry = {cfg = cfg, kind = kind, key = key, count = 1, handle = handle, dedupe = dedupe}
    if #Notes.active >= Notes.max then
        Notes.queue[#Notes.queue + 1] = entry
        if dedupe then Notes.queuedKey[key] = entry end
    else
        spawnNote(entry)
    end
    return handle
end

function Nihon:Notify(cfg) return Nihon:MakeNotification(cfg) end
function Nihon:SetNotificationLimit(n) Notes.max = math.clamp(math.floor(tonumber(n) or 5), 1, 10) end
function Nihon:SetNotificationTime(s) Notes.duration = math.clamp(tonumber(s) or 4, 1, 30) end
function Nihon:SetNotificationPosition(name)
    if not corners[name] then return end
    Notes.position = name
    for _, n in ipairs(Notes.active) do n.frame.AnchorPoint = Vector2.new(corners[name].ax, corners[name].ay) end
    relayout()
end
function Nihon:ClearNotifications()
    Notes.queue = {} Notes.queuedKey = {}
    for i = #Notes.active, 1, -1 do dismissNote(Notes.active[i]) end
end

-- =========================================================
-- KEY SYSTEM (Matches sketch)
-- =========================================================
local function createKeySystem(cfg)
    if not Nihon.ShowKeySystem then return true end
    
    local keyLayer = mk("Frame", {
        Name = "KeySystem", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), 
        BackgroundTransparency = 0.5, ZIndex = 500, Parent = Root,
    })
    
    -- Sidebar-style card, positioned where the player chip normally is
    local card = mk("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), 
        Size = UDim2.fromOffset(220, 170), BackgroundColor3 = Pal.Surface, ZIndex = 501, Parent = keyLayer,
    })
    round(card, 8)
    outline(card, "Stroke", 1, 0.1)
    
    tx("TextLabel", {
        Text = "Key System", TextSize = 14, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 8),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 502, Parent = card,
    }, 3)
    
    -- Math Problem Display
    local mathLabel = tx("TextLabel", {
        Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 34),
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Pal.Accent, ZIndex = 502, Parent = card,
    }, 3)
    
    local input = tx("TextBox", {
        Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 64), 
        PlaceholderText = "Enter Answer...", TextSize = 12, ZIndex = 502, Parent = card,
    }, 2)
    bind(input, "BackgroundColor3", "Elevated")
    input.BackgroundTransparency = 0
    round(input, 6)
    inset(input, 0, 8, 0, 8)
    
    local btnRow = mk("Frame", {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 100), BackgroundTransparency = 1, ZIndex = 502, Parent = card})
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = btnRow})
    
    local getKeyBtn = tx("TextButton", {
        Text = "Get Key", TextSize = 11, Size = UDim2.fromOffset(80, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 503, Parent = btnRow,
    }, 3)
    bind(getKeyBtn, "BackgroundColor3", "Accent")
    getKeyBtn.BackgroundTransparency = 0
    round(getKeyBtn, 6)
    
    local helpBtn = tx("TextButton", {
        Text = "Help", TextSize = 11, Size = UDim2.fromOffset(80, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 503, Parent = btnRow,
    }, 3)
    bind(helpBtn, "BackgroundColor3", "Elevated")
    helpBtn.BackgroundTransparency = 0
    round(helpBtn, 6)
    
    local status = tx("TextLabel", {
        Text = "", TextSize = 10, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 134),
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Status.Error, ZIndex = 502, Parent = card,
    }, 1)
    
    -- Generate Math Problem
    local num1 = math.random(1, 10)
    local num2 = math.random(1, 10)
    local answer = num1 + num2
    local correctKey = tostring(answer)
    
    mathLabel.Text = num1 .. " + " .. num2 .. " = ?"
    
    getKeyBtn.Activated:Connect(function()
        local put = setclipboard or toclipboard
        if put then
            put(correctKey)
            status.Text = "Key copied!"
            status.TextColor3 = Status.Success
        else
            status.Text = "Clipboard not available."
            status.TextColor3 = Status.Error
        end
    end)
    
    helpBtn.Activated:Connect(function()
        Nihon:Dialog({
            Title = "Key System Help",
            Content = "Solve the math problem shown above. Click 'Get Key' to copy the answer, then paste it into the input box.",
            Buttons = {{Name = "Got it", Primary = true}}
        })
    end)
    
    local verified = false
    local function checkKey()
        if input.Text == correctKey then
            verified = true
            keyLayer:Destroy()
            Nihon:MakeNotification({Name = "Success", Content = "Key accepted!", Type = "Success"})
        else
            status.Text = "Invalid key, try again."
            status.TextColor3 = Status.Error
            input.Text = ""
            -- Simple shake
            local base = card.Position
            task.spawn(function()
                for _, dx in ipairs({6, -6, 4, -4, 2, 0}) do
                    if not card.Parent then return end
                    card.Position = base + UDim2.fromOffset(dx, 0)
                    task.wait(0.03)
                end
                card.Position = base
            end)
        end
    end
    
    input.FocusLost:Connect(function(enter) if enter then checkKey() end end)
    
    local start = os.clock()
    while not verified and os.clock() - start < 60 do task.wait(0.1) end
    if not verified then Nihon:Destroy() return false end
    return true
end

-- =========================================================
-- DIALOGS & POPUPS
-- =========================================================
local Popup = {}
local catcher = mk("TextButton", {Name = "PopupCatcher", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 60, Parent = Root})
catcher.Activated:Connect(function() Popup.close() end)

function Popup.close(instant)
    local cur = Popup.current
    if not cur then return end
    Popup.current = nil
    catcher.Visible = false
    if cur.follow then cur.follow:Disconnect() end
    if cur.onClose then task.spawn(cur.onClose) end
    if instant then cur.frame:Destroy() return end
    local tw = play(cur.frame, 0.16, {Size = UDim2.fromOffset(cur.w, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    after(tw, function() cur.frame:Destroy() end)
    task.delay(0.5, function() if cur.frame.Parent then cur.frame:Destroy() end end)
end

function Popup.open(anchor, o)
    Popup.close(true)
    local sc = currentScale
    local w = o.width or math.max(120, anchor.AbsoluteSize.X / sc)
    local view = viewport()
    local a, s = anchor.AbsolutePosition, anchor.AbsoluteSize
    local gap = 6
    local below = view.Y - (a.Y + s.Y) - gap - 8
    local above = a.Y - gap - 8
    local h = o.height
    local up = false
    if h * sc > below then
        if below >= 130 or below >= above then h = math.max(70, below / sc)
        else up = true h = math.min(h, math.max(70, above / sc)) end
    end
    local frame = mk("Frame", {Name = "Popup", AnchorPoint = Vector2.new(0, up and 1 or 0), Size = UDim2.fromOffset(w, 0), ClipsDescendants = true, ZIndex = 61, Parent = Root})
    bind(frame, "BackgroundColor3", "Surface")
    round(frame, 8)
    outline(frame, "Stroke", 1, 0.1)
    mk("UIScale", {Scale = sc, Parent = frame})
    local function place()
        local v = viewport()
        local pa, ps = anchor.AbsolutePosition, anchor.AbsoluteSize
        local x = pa.X
        if o.align == "right" then x = pa.X + ps.X - w * sc end
        x = math.clamp(x, 6, math.max(6, v.X - w * sc - 6))
        local y = up and (pa.Y - gap) or (pa.Y + ps.Y + gap)
        frame.Position = UDim2.fromOffset(x, y)
    end
    place()
    o.build(frame, w, h)
    catcher.Visible = true
    local cur = {frame = frame, w = w, owner = o.owner, onClose = o.onClose}
    cur.follow = RunService.RenderStepped:Connect(function()
        if not anchor.Parent then Popup.close(true) return end
        place()
    end)
    Popup.current = cur
    play(frame, 0.26, {Size = UDim2.fromOffset(w, h)})
    return frame
end

function Nihon:Dialog(cfg)
    cfg = cfg or {}
    local layer = mk("TextButton", {Name = "Dialog", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200, Parent = Root})
    local w = math.clamp(viewport().X - 32, 240, 350)
    local box = mk("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ZIndex = 201, Parent = layer})
    bind(box, "BackgroundColor3", "Surface")
    round(box, 12)
    outline(box, "Stroke", 1, 0.1)
    local sc = mk("UIScale", {Scale = 0.9, Parent = box})
    local col = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = box})
    inset(col, 18, 18, 16, 18)
    stack(col, 8)
    tx("TextLabel", {Text = tostring(cfg.Title or "Confirm"), TextSize = 16, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 1, Parent = col}, 3)
    if cfg.Content and cfg.Content ~= "" then
        tx("TextLabel", {Text = tostring(cfg.Content), TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 2, Parent = col}, 1, "Sub")
    end
    local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 3, Parent = col})
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})

    local dialog = {}
    local closed = false
    function dialog:Close()
        if closed then return end
        closed = true
        play(layer, 0.2, {BackgroundTransparency = 1})
        play(box, 0.2, {GroupTransparency = 1})
        play(sc, 0.2, {Scale = 0.94})
        task.delay(0.3, function() layer:Destroy() end)
    end

    local buttons = cfg.Buttons or {{Name = "OK", Primary = true}}
    for i, b in ipairs(buttons) do
        local label = tostring(b.Name or "OK")
        local size = TextService:GetTextSize(label, 13, Fonts[currentFont][3], Vector2.new(400, 34))
        local btn = tx("TextButton", {Text = label, Size = UDim2.fromOffset(math.max(80, size.X + 30), 36), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, ZIndex = 202, Parent = row}, 3)
        round(btn, 8)
        if b.Primary then
            if b.Danger then btn.BackgroundColor3 = Status.Error btn.TextColor3 = Color3.new(1, 1, 1)
            else bind(btn, "BackgroundColor3", "Accent") btn.TextColor3 = Color3.new(1, 1, 1) end
        else
            bind(btn, "BackgroundColor3", "Elevated")
        end
        btn.Activated:Connect(function()
            dialog:Close()
            if b.Callback then task.spawn(function() pcall(b.Callback) end) end
        end)
    end
    layer.Activated:Connect(function() if cfg.Dismissable ~= false then dialog:Close() end end)
    play(layer, 0.25, {BackgroundTransparency = 0.55})
    play(box, 0.25, {GroupTransparency = 0})
    play(sc, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
    return dialog
end

-- =========================================================
-- CONFIG SYSTEM
-- =========================================================
local flagRefs = {}
local flagOrder = {}
local initFires = {}
local saveToken = 0

local function encode(v)
    local t = typeof(v)
    if t == "Color3" then return {t = "c", r = v.R, g = v.G, b = v.B}
    elseif t == "EnumItem" then return {t = "k", n = v.Name}
    elseif t == "table" then local list = {} for i, x in ipairs(v) do list[i] = x end return {t = "l", v = list}
    elseif v == nil then return {t = "k"} end
    return v
end

local function decode(v)
    if type(v) ~= "table" then return v end
    if v.t == "c" then return Color3.new(v.r, v.g, v.b)
    elseif v.t == "k" then return v.n and Enum.KeyCode[v.n] or nil
    elseif v.t == "l" then return v.v end
    return v
end

local function fsReady() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" and type(makefolder) == "function" and type(isfolder) == "function" end
local function cfgPath(name) return Nihon.Folder .. "/" .. name .. ".json" end
local function ensureFolder() if not isfolder(Nihon.Folder) then makefolder(Nihon.Folder) end end

local function snapshot()
    local data = {}
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]
        if ref.save then data[flag] = encode(ref.get()) end
    end
    return data
end

function Nihon:SaveProfile(name)
    name = name or Nihon.Profile
    if not fsReady() then return false end
    local ok = pcall(function() ensureFolder() writefile(cfgPath(name), HttpService:JSONEncode(snapshot())) end)
    return ok
end

function Nihon:LoadProfile(name)
    name = name or Nihon.Profile
    if not fsReady() then return false end
    local ok, data = pcall(function()
        if not isfile(cfgPath(name)) then return nil end
        return HttpService:JSONDecode(readfile(cfgPath(name)))
    end)
    if not ok or type(data) ~= "table" then return false end
    Nihon.Profile = name
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]
        if ref.save and data[flag] ~= nil then pcall(ref.set, decode(data[flag])) end
    end
    return true
end

function Nihon:DeleteProfile(name)
    if not fsReady() or not delfile then return false end
    return pcall(function() if isfile(cfgPath(name)) then delfile(cfgPath(name)) end end)
end

function Nihon:ListProfiles()
    local out = {}
    if not fsReady() or not listfiles then return out end
    pcall(function()
        ensureFolder()
        for _, p in ipairs(listfiles(Nihon.Folder)) do
            local n = p:match("([^/\\]+)%.json$")
            if n and n:sub(1, 1) ~= "_" then out[#out + 1] = n end
        end
    end)
    table.sort(out)
    return out
end

function Nihon:SetAutoload(name)
    if not fsReady() then return end
    pcall(function() ensureFolder() writefile(Nihon.Folder .. "/_meta.json", HttpService:JSONEncode({autoload = name})) end)
end

function Nihon:GetAutoload()
    if not fsReady() then return nil end
    local ok, data = pcall(function()
        local p = Nihon.Folder .. "/_meta.json"
        if not isfile(p) then return nil end
        return HttpService:JSONDecode(readfile(p))
    end)
    return ok and data and data.autoload or nil
end

function Nihon:ExportConfig() return HttpService:JSONEncode(snapshot()) end
function Nihon:ImportConfig(str)
    local ok, data = pcall(function() return HttpService:JSONDecode(str) end)
    if not ok or type(data) ~= "table" then return false end
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]
        if ref.save and data[flag] ~= nil then pcall(ref.set, decode(data[flag])) end
    end
    return true
end

local function queueSave()
    if not Nihon.SaveConfig or not Nihon._ready then return end
    saveToken = saveToken + 1
    local mine = saveToken
    task.delay(0.8, function() if mine == saveToken then Nihon:SaveProfile() end end)
end

-- =========================================================
-- WINDOW & UI LOGIC
-- =========================================================
local Hooks = {}
local Sizes = {
    desktop = {w = 640, h = 420, side = 168, top = 46},
    mobile = {w = 520, h = 300, side = 62, top = 42},
}

function Nihon:MakeWindow(cfg)
    cfg = cfg or {}
    local title = tostring(cfg.Name or "Nihon Lib")
    local subtitle = cfg.Subtitle ~= nil and tostring(cfg.Subtitle) or ("v" .. Nihon.Version)
    local mobile = Nihon.IsMobile
    local size = mobile and Sizes.mobile or Sizes.desktop
    local baseW = tonumber(cfg.Width) or size.w
    local baseH = tonumber(cfg.Height) or size.h
    local sideW = size.side
    local topH = size.top
    local footH = 44

    Nihon.Folder = tostring(cfg.ConfigFolder or Nihon.Folder)
    Nihon.SaveConfig = cfg.SaveConfig == true
    
    -- Apply new config options
    Nihon.ShowKeySystem = cfg.ShowKeySystem == true
    Nihon.ShowTabsOnTop = cfg.ShowTabsOnTop == true
    Nihon.KeySystemAnswer = cfg.KeySystemAnswer or ""

    if cfg.Theme and Themes[cfg.Theme] then setTheme(cfg.Theme, false) end
    if cfg.Font and Fonts[cfg.Font] then setFont(cfg.Font) end
    if cfg.Accent then setAccent(cfg.Accent, cfg.Accent2) end

    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    local Window = {Tabs = {}, Name = title, Hidden = false, Minimized = false, Selected = nil, Scale = 1, ToggleKey = toggleKey, Cfg = cfg}
    Nihon.Windows[#Nihon.Windows + 1] = Window

    local searchIndex = {}
    
    local shell = mk("Frame", {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(baseW, baseH), ClipsDescendants = false, Visible = false, ZIndex = 10, Parent = Root})
    bind(shell, "BackgroundColor3", "Bg")
    round(shell, 8)
    outline(shell, "Stroke", 1, 0.1)
    local uiScale = mk("UIScale", {Scale = 0.9, Parent = shell})
    Window.Shell = shell

    local clip = mk("Frame", {Name = "Clip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 10, Parent = shell})
    round(clip, 8)

    local header = mk("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, topH), BackgroundTransparency = 1, ZIndex = 12, Parent = clip})
    local logo = mk("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13, Parent = header})
    round(logo, 6)
    accentGradient(logo, 45)
    local logoIcon = makeIcon(logo, "zap", 12, false, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 14})
    logoIcon.Color(Color3.new(1, 1, 1))
    Window.LogoIcon = logoIcon

    local titleLbl = tx("TextLabel", {Text = title, TextSize = 14, Position = UDim2.new(0, 46, 0, subtitle ~= "" and 6 or 0), Size = UDim2.new(1, -200, 0, subtitle ~= "" and 18 or topH), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13, Parent = header}, 3)
    local subLbl = tx("TextLabel", {Text = subtitle, TextSize = 10, Position = UDim2.new(0, 46, 0, 24), Size = UDim2.new(1, -200, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Visible = subtitle ~= "", ZIndex = 13, Parent = header}, 1, "Sub")
    Window.TitleLabel, Window.SubtitleLabel = titleLbl, subLbl

    local controls = mk("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 14, Parent = header})
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = controls})

    local function ctrlButton(order, icon, hover)
        local btn = mk("TextButton", {Size = UDim2.fromOffset(mobile and 32 or 28, mobile and 32 or 28), BackgroundColor3 = hover or Color3.new(1, 1, 1), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 15, Parent = controls})
        round(btn, 6)
        local ico = makeIcon(btn, icon, 14, "Sub", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 16})
        btn.MouseEnter:Connect(function() play(btn, 0.15, {BackgroundTransparency = 0.85}) end)
        btn.MouseLeave:Connect(function() play(btn, 0.2, {BackgroundTransparency = 1}) end)
        return btn, ico
    end

    local helpBtn = ctrlButton(1, "help-circle")
    local searchBtn, searchIco = ctrlButton(2, "search")
    local minBtn, minIco = ctrlButton(3, "minus")
    local closeBtn = ctrlButton(4, "x", Status.Error)
    local sideBtn, sideIco = ctrlButton(5, "menu")

    local headLine = mk("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13, Parent = header})
    bind(headLine, "BackgroundColor3", "Stroke")

    local grab = mk("TextButton", {Name = "GrabBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(mobile and 64 or 48, mobile and 16 or 10), BackgroundTransparency = 1, ZIndex = 20, Parent = clip})
    local grabPill = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(mobile and 38 or 30, 4), BackgroundTransparency = 0.55, ZIndex = 21, Parent = grab})
    bind(grabPill, "BackgroundColor3", "Sub")
    round(grabPill, 2)
    grab.MouseEnter:Connect(function() play(grabPill, 0.15, {BackgroundTransparency = 0.1, Size = UDim2.fromOffset(mobile and 46 or 38, 4)}) end)
    grab.MouseLeave:Connect(function() play(grabPill, 0.2, {BackgroundTransparency = 0.55, Size = UDim2.fromOffset(mobile and 38 or 30, 4)}) end)

    local body = mk("Frame", {Name = "Body", Position = UDim2.fromOffset(0, topH), Size = UDim2.new(1, 0, 1, -topH), BackgroundTransparency = 1, ZIndex = 11, Parent = clip})

    -- Layout: Tabs on Top or Sidebar
    local side, tabScroll
    if Nihon.ShowTabsOnTop then
        side = mk("Frame", {Name = "TopTabs", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(1, -16, 0, 36), ZIndex = 12, Parent = body})
        bind(side, "BackgroundColor3", "Surface")
        side.BackgroundTransparency = 0.25
        round(side, 8)
        outline(side, "Stroke", 1, 0.5)
        tabScroll = mk("ScrollingFrame", {Name = "Tabs", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 13, Parent = side})
        inset(tabScroll, 4, 4, 4, 4)
        stack(tabScroll, 4, Enum.FillDirection.Horizontal)
        footH = 0
    else
        side = mk("Frame", {Name = "Sidebar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.new(0, sideW - 10, 1, -16), ZIndex = 12, Parent = body})
        bind(side, "BackgroundColor3", "Surface")
        side.BackgroundTransparency = 0.25
        round(side, 8)
        outline(side, "Stroke", 1, 0.5)
        tabScroll = mk("ScrollingFrame", {Name = "Tabs", Size = UDim2.new(1, 0, 1, -footH - 4), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 13, Parent = side})
        inset(tabScroll, 8, 6, 8, 6)
        stack(tabScroll, 4)
    end

    local pill = mk("Frame", {Name = "Pill", Size = UDim2.new(1, -12, 0, 0), Position = UDim2.fromOffset(6, 8), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Visible = false, ZIndex = 12, Parent = side})
    round(pill, 6)
    accentGradient(pill, 20)

    local footer = mk("TextButton", {Name = "PlayerChip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(1, -12, 0, footH - 4), ZIndex = 14, Parent = side, Visible = not Nihon.ShowTabsOnTop})
    bind(footer, "BackgroundColor3", "Elevated")
    footer.BackgroundTransparency = 0.2
    round(footer, 8)
    outline(footer, "Stroke", 1, 0.55)
    
    -- Player chip content
    local avatar = mk("ImageLabel", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(24, 24), ZIndex = 15, Parent = footer})
    bind(avatar, "BackgroundColor3", "Surface")
    round(avatar, 12)
    -- We'll load avatar later in attachStats
    
    local chipName = tx("TextLabel", {Text = LocalPlayer.DisplayName, TextSize = 11, Position = UDim2.new(0, 36, 0, 6), Size = UDim2.new(1, -50, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Visible = not mobile, ZIndex = 15, Parent = footer}, 3)
    local chipSub = tx("TextLabel", {Text = "@" .. LocalPlayer.Name, TextSize = 9, Position = UDim2.new(0, 36, 0, 20), Size = UDim2.new(1, -50, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd, Visible = not mobile, ZIndex = 15, Parent = footer}, 1, "Sub")
    
    local content = mk("Frame", {Name = "Content", Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -(sideW + 20), 1, -16), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 12, Parent = body})
    if Nihon.ShowTabsOnTop then
        content.Position = UDim2.fromOffset(10, 48)
        content.Size = UDim2.new(1, -20, 1, -54)
    end
    Window.Content = content

    -- Resize Grip
    local resizeGrip = mk("TextButton", {Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Size = UDim2.fromOffset(mobile and 28 or 22, mobile and 28 or 22), BackgroundTransparency = 1, ZIndex = 30, Parent = clip})
    local resizeGlyph = makeIcon(resizeGrip, "chevron-right", 14, "Sub", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), ZIndex = 31})
    resizeGlyph.Glyph.Rotation = 45
    local resizing = false
    local resizeStart, resizeShellPos, resizeShellSize
    trackPointer(resizeGrip, function(input)
        if Window.Hidden or Window.Minimized then return false end
        resizing = true
        resizeStart = v2(input)
        resizeShellPos = shell.AbsolutePosition
        resizeShellSize = shell.AbsoluteSize
        play(resizeGlyph.Glyph, 0.12, {TextColor3 = Pal.Accent})
    end, function(pos)
        if not resizing then return end
        local d = pos - resizeStart
        local sc = math.max(uiScale.Scale, 0.01)
        local newW = math.max(math.floor((baseW * sc) + d.X), math.floor(baseW * 0.55 * sc))
        local newH = math.max(math.floor((fullH * sc) + d.Y), math.floor((topH + 120) * sc))
        shell.Size = UDim2.fromOffset(math.floor(newW / sc), math.floor(newH / sc))
    end, function()
        resizing = false
        play(resizeGlyph.Glyph, 0.2, {TextColor3 = Pal.Sub})
    end)

    -- Dragging logic
    local function dragClamp(topLeft)
        local v = viewport()
        local s = shell.AbsoluteSize
        local hh = topH * uiScale.Scale
        return Vector2.new(math.clamp(topLeft.X, -s.X + 90, v.X - 90), math.clamp(topLeft.Y, 0, v.Y - math.min(hh, s.Y) - 4))
    end
    local function reanchor()
        if shell.AnchorPoint == Vector2.new(0, 0) then return end
        local p = shell.AbsolutePosition
        shell.AnchorPoint = Vector2.new(0, 0)
        shell.Position = UDim2.fromOffset(p.X, p.Y)
    end
    local function centerTopLeft()
        local v = viewport()
        local s = Vector2.new(baseW, shell.Size.Y.Offset) * uiScale.Scale
        shell.AnchorPoint = Vector2.new(0, 0)
        shell.Position = UDim2.fromOffset(math.floor((v.X - s.X) / 2), math.floor((v.Y - s.Y) / 2))
    end

    local dragHandles = {grab, header}
    makeDraggable(dragHandles, shell, {
        speed = 30, clamp = dragClamp,
        onBegin = function() reanchor() play(grabPill, 0.12, {BackgroundTransparency = 0}) end,
        onEnd = function() play(grabPill, 0.25, {BackgroundTransparency = 0.55}) end,
        canDrag = function() return not Window.Hidden end,
    })

    -- Scaling
    local function fitScale()
        local v = viewport()
        local fit = math.min((v.X - 20) / baseW, (v.Y - 20) / baseH, 1)
        return math.max(fit, 0.5) * Window.Scale
    end
    local activeScale = 1
    local function applyScale(animated)
        activeScale = fitScale()
        currentScale = activeScale
        if animated then play(uiScale, 0.3, {Scale = activeScale}) else uiScale.Scale = activeScale end
    end
    local cam = workspace.CurrentCamera
    if cam then keep(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() if not Window.Hidden then applyScale(true) end end)) end

    -- Launcher
    local launcher = mk("TextButton", {Name = "Launcher", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0), Size = UDim2.fromOffset(mobile and 50 or 44, mobile and 50 or 44), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 250, Parent = Root})
    round(launcher, 25)
    accentGradient(launcher, 45)
    outline(launcher, "Text", 1.5, 0.75)
    local launcherIcon = makeIcon(launcher, cfg.Icon or "zap", 22, false, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 251})
    launcherIcon.Color(Color3.new(1, 1, 1))
    local launcherScale = mk("UIScale", {Scale = 0, Parent = launcher})
    Window.LauncherIcon = launcherIcon

    local launcherMoved = false
    makeDraggable({launcher}, launcher, {
        speed = 32, clamp = function(p) local v = viewport() local s = launcher.AbsoluteSize return Vector2.new(math.clamp(p.X, 0, v.X - s.X), math.clamp(p.Y, 0, v.Y - s.Y)) end,
        onBegin = function() launcher.AnchorPoint = Vector2.new(0, 0) play(launcherScale, 0.12, {Scale = 0.92}) end,
        onEnd = function(moved) launcherMoved = moved play(launcherScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end,
    })

    local function showLauncher(on)
        if on then launcher.Visible = true play(launcherScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
        else local tw = play(launcherScale, 0.2, {Scale = 0}, Enum.EasingStyle.Quint, Enum.EasingDirection.In) after(tw, function() launcher.Visible = false end) end
    end

    -- Show/Hide/Minimize
    local fullH = baseH
    local closeToken = 0
    local placed = false
    local function show()
        Window.Hidden = false
        applyScale(false)
        if not placed then placed = true uiScale.Scale = activeScale centerTopLeft() end
        closeToken = closeToken + 1
        controls.Position = UDim2.new(1, -8, 0.5, 0)
        titleLbl.TextTransparency = 0
        subLbl.TextTransparency = 0
        body.Visible = not Window.Minimized
        shell.Size = UDim2.fromOffset(shell.Size.X.Offset > topH + 10 and shell.Size.X.Offset or baseW, Window.Minimized and (topH + 4) or fullH)
        shell.Visible = true
        uiScale.Scale = activeScale * 0.9
        play(uiScale, 0.5, {Scale = activeScale}, Enum.EasingStyle.Back)
        showLauncher(false)
    end

    local function hide(toLauncher)
        Window.Hidden = true
        Popup.close(true)
        closeToken = closeToken + 1
        local mine = closeToken
        if not toLauncher then
            local tw = play(uiScale, 0.22, {Scale = activeScale * 0.9}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            after(tw, function() if Window.Hidden and mine == closeToken then shell.Visible = false end end)
            return
        end
        local w0 = shell.Size.X.Offset
        local lift = topH + 4
        if not Window.Minimized then body.Visible = false play(shell, 0.28, {Size = UDim2.fromOffset(w0, lift)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut) end
        task.delay(0.22, function()
            if mine ~= closeToken or not Window.Hidden then return end
            local sp = shell.AbsolutePosition
            local sc = math.max(uiScale.Scale, 0.01)
            play(shell, 0.3, {Size = UDim2.fromOffset(lift, lift)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
            play(header, 0.18, {BackgroundTransparency = 1})
            play(controls, 0.12, {Position = UDim2.new(1, 30, 0.5, 0)})
            play(titleLbl, 0.12, {TextTransparency = 1})
            play(subLbl, 0.12, {TextTransparency = 1})
            Window._lastClosePos = Vector2.new(sp.X, sp.Y)
        end)
        task.delay(0.5, function()
            if mine ~= closeToken or not Window.Hidden then return end
            local tw = play(uiScale, 0.22, {Scale = activeScale * 0.4}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            after(tw, function()
                if Window.Hidden and mine == closeToken then
                    shell.Visible = false
                    shell.Size = UDim2.fromOffset(w0, fullH)
                    body.Visible = true
                    controls.Position = UDim2.new(1, -8, 0.5, 0)
                    titleLbl.TextTransparency = 0
                    subLbl.TextTransparency = 0
                    header.BackgroundTransparency = 1
                    Window.Minimized = false
                    play(minIco.Glyph, 0.01, {Rotation = 0})
                end
            end)
            local lp = Window._lastClosePos
            if lp then
                launcher.AnchorPoint = Vector2.new(0, 0)
                local v = viewport()
                local ls = launcher.AbsoluteSize
                launcher.Position = UDim2.fromOffset(math.clamp(lp.X, 0, v.X - ls.X), math.clamp(lp.Y, 0, v.Y - ls.Y))
            end
            showLauncher(true)
        end)
    end

    Window.Show, Window.Hide = show, hide
    function Window:Toggle() if Window.Hidden then show() else hide(mobile) end end
    launcher.Activated:Connect(function() if launcherMoved then launcherMoved = false return end show() end)
    closeBtn.Activated:Connect(function() hide(true) Nihon:MakeNotification({Name = "Menu hidden", Content = "Tap the floating button to bring it back.", Type = "Info", Time = 3}) end)

    keep(UserInputService.InputBegan:Connect(function(input, gpe) if gpe then return end if input.KeyCode == Window.ToggleKey then Window:Toggle() end end))

    local minTween
    function Window:SetMinimized(state)
        state = state and true or false
        if Window.Minimized == state then return end
        Window.Minimized = state
        Popup.close(true)
        if minTween then minTween:Cancel() end
        local lift = topH + 4
        if state then
            fullH = shell.Size.Y.Offset
            minTween = play(shell, 0.38, {Size = UDim2.fromOffset(shell.Size.X.Offset, lift)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
            play(body, 0.22, {Position = UDim2.fromOffset(0, topH - 12)})
            play(minIco.Glyph, 0.3, {Rotation = 180})
            task.delay(0.16, function() if Window.Minimized then body.Visible = false end end)
        else
            body.Visible = true
            body.Position = UDim2.fromOffset(0, topH - 12)
            minTween = play(shell, 0.45, {Size = UDim2.fromOffset(shell.Size.X.Offset, fullH)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
            play(body, 0.4, {Position = UDim2.fromOffset(0, topH)})
            play(minIco.Glyph, 0.3, {Rotation = 0})
        end
    end
    minBtn.Activated:Connect(function() Window:SetMinimized(not Window.Minimized) end)

    Window.RequestOpen = function() if Window.Hidden then show() end end
    Window._parts = {
        shell = shell, clip = clip, header = header, body = body, side = side, tabScroll = tabScroll, pill = pill,
        content = content, footer = footer, searchBtn = searchBtn, helpBtn = helpBtn, uiScale = uiScale, applyScale = applyScale,
        topH = topH, sideW = sideW, mobile = mobile, searchIndex = searchIndex,
        avatar = avatar, chipName = chipName, chipSub = chipSub,
        closeBtn = closeBtn, minBtn = minBtn, sideBtn = sideBtn, sideIco = sideIco,
        searchIco = searchIco, minIco = minIco, resizeGrip = resizeGrip, resizeGlyph = resizeGlyph,
    }

    -- Sidebar visibility toggle
    local function setSidebarVisible(on)
        on = on and true or false
        side.Visible = on
        if Nihon.ShowTabsOnTop then
            content.Size = on and UDim2.new(1, -20, 1, -54) or UDim2.new(1, -20, 1, -16)
            content.Position = on and UDim2.fromOffset(10, 48) or UDim2.fromOffset(10, 6)
        else
            content.Size = on and UDim2.new(1, -(sideW + 20), 1, -16) or UDim2.new(1, -20, 1, -16)
        end
        if Window.Selected then task.defer(function() TabImpl.select(Window, Window.Selected, true) end) end
    end
    sideBtn.Activated:Connect(function() setSidebarVisible(not side.Visible) end)
    Window._parts.setSidebarVisible = setSidebarVisible

    Hooks.attach(Window)
    return Window
end

-- =========================================================
-- TAB & ELEMENT FACTORY
-- =========================================================
local function registerFlag(flag, ref)
    if not flag then return end
    if not flagRefs[flag] then flagOrder[#flagOrder + 1] = flag end
    flagRefs[flag] = ref
end

local function flashCard(card, color, seconds)
    local sheet = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.55, ZIndex = 44, Parent = card})
    round(sheet, 8)
    local stroke = card:FindFirstChildOfClass("UIStroke")
    local oldTrans = stroke and stroke.Transparency
    if stroke then stroke.Color = color stroke.Transparency = 0 end
    local dur = seconds or 0.9
    local tw = play(sheet, dur, {BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
    after(tw, function() sheet:Destroy() end)
    task.delay(dur, function()
        if stroke and stroke.Parent then play(stroke, 0.3, {Color = Pal.Stroke, Transparency = oldTrans}) end
        if sheet.Parent then sheet:Destroy() end
    end)
end

local function shake(card)
    local base = card.Position
    task.spawn(function()
        for _, dx in ipairs({6, -6, 4, -4, 2, 0}) do
            if not card.Parent then return end
            card.Position = base + UDim2.fromOffset(dx, 0)
            task.wait(0.03)
        end
        card.Position = base
    end)
end

local ElementFactory
local TabImpl = {}

function TabImpl.make(Window, tcfg)
    local P = Window._parts
    local mobile = P.mobile
    tcfg = tcfg or {}
    local name = tostring(tcfg.Name or "Tab")
    local Tab = {Name = name, Sections = {}, Window = Window}
    local index = #Window.Tabs + 1
    Tab.Index = index

    local isTopTabs = Nihon.ShowTabsOnTop
    local btn = mk("TextButton", {
        Name = "Tab_" .. name, 
        Size = isTopTabs and UDim2.fromOffset(100, 28) or UDim2.new(1, 0, 0, mobile and 40 or 34),
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, LayoutOrder = index, ZIndex = 14, Parent = P.tabScroll,
    })
    round(btn, 6)
    Tab.Button = btn

    local ico = makeIcon(btn, tcfg.Icon or name, mobile and 18 or 16, "Sub", {
        AnchorPoint = isTopTabs and Vector2.new(0, 0.5) or Vector2.new(mobile and 0.5 or 0, 0.5),
        Position = isTopTabs and UDim2.new(0, 8, 0.5, 0) or (mobile and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 10, 0.5, 0)),
        ZIndex = 15,
    })
    Tab.IconObj = ico

    local label
    if not mobile or isTopTabs then
        label = tx("TextLabel", {
            Text = name, TextSize = 12, 
            Position = isTopTabs and UDim2.fromOffset(26, 0) or UDim2.new(0, 30, 0, 0),
            Size = isTopTabs and UDim2.new(1, -30, 1, 0) or UDim2.new(1, -60, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = btn,
        }, 2, "Sub")
    end
    Tab.Label = label

    local badgeFrame, badgeText
    local function buildBadge(text)
        if badgeFrame then badgeText.Text = tostring(text) badgeFrame.Visible = text ~= nil and text ~= "" return end
        if text == nil or text == "" then return end
        badgeFrame = mk("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), 
            Position = isTopTabs and UDim2.new(1, -4, 0.5, 0) or (mobile and UDim2.new(1, -1, 0, 9) or UDim2.new(1, -6, 0.5, 0)),
            Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 17, Parent = btn,
        })
        round(badgeFrame, 8)
        accentGradient(badgeFrame, 30)
        inset(badgeFrame, 0, 6, 0, 6)
        badgeText = tx("TextLabel", {Text = tostring(text), TextSize = 9, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 18, Parent = badgeFrame}, 3)
        badgeText.TextColor3 = Color3.new(1, 1, 1)
    end
    buildBadge(tcfg.Badge)
    function Tab:SetBadge(t) buildBadge(t) end
    function Tab:SetIcon(id) ico.Set(id) end

    local page = mk("CanvasGroup", {Name = "Page_" .. name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 13, Parent = P.content})
    local scroll = mk("ScrollingFrame", {
        Name = "Scroll", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = mobile and 3 or 4,
        ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 13, Parent = page,
    })
    bind(scroll, "ScrollBarImageColor3", "Stroke")
    inset(scroll, 2, 8, 12, 2)
    stack(scroll, 6)
    local pageOffset = mk("UIScale", {Scale = 1, Parent = page})
    Tab.Page, Tab.Scroll, Tab.PageScale = page, scroll, pageOffset

    local scrollMemory = 0
    Tab.Remember = function() scrollMemory = scroll.CanvasPosition.Y end
    Tab.Restore = function() scroll.CanvasPosition = Vector2.new(0, scrollMemory) end
    Window.Tabs[index] = Tab

    btn.MouseEnter:Connect(function()
        if Window.Selected ~= Tab then play(btn, 0.15, {BackgroundTransparency = 0.9}) ico.Color(Pal.Text, true) end
    end)
    btn.MouseLeave:Connect(function()
        play(btn, 0.2, {BackgroundTransparency = 1})
        if Window.Selected ~= Tab then ico.Color(Pal.Sub, true) end
    end)
    btn.Activated:Connect(function() Window:SelectTab(Tab) end)

    if #Window.Tabs == 1 then task.defer(function() task.wait() Window:SelectTab(Tab, true) end) end

    local tabApi = ElementFactory(Window, Tab, scroll, nil)

    function tabApi:AddSection(sc)
        sc = type(sc) == "table" and sc or {Name = sc}
        local secName = tostring(sc.Name or "Section")
        local holder = mk("Frame", {Name = "Section_" .. secName, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = #Tab.Sections + 1, ZIndex = 13, Parent = scroll})
        stack(holder, 6)

        local head = mk("TextButton", {Size = UDim2.new(1, 0, 0, mobile and 28 or 24), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 14, Parent = holder})
        local bar = mk("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(2, 10), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 15, Parent = head})
        round(bar, 2)
        accentGradient(bar, 90)
        local secLabel = tx("TextLabel", {Text = string.upper(secName), TextSize = 10, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -50, 1, 0), ZIndex = 15, Parent = head}, 3, "Sub")
        local chev = makeIcon(head, "chevron-down", 12, "Sub", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), ZIndex = 15})

        local bodyClip = mk("Frame", {Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 14, Parent = holder})
        stack(bodyClip, 4)

        local section = ElementFactory(Window, Tab, bodyClip, secName)
        section.Holder = holder
        Tab.Sections[#Tab.Sections + 1] = section

        local collapsed = false
        local fullSize = 0
        local collapseTween
        local function setCollapsed(state)
            if collapsed == state then return end
            collapsed = state
            Popup.close(true)
            if collapseTween then collapseTween:Cancel() end
            if state then
                fullSize = bodyClip.AbsoluteSize.Y / math.max(currentScale, 0.01)
                bodyClip.AutomaticSize = Enum.AutomaticSize.None
                bodyClip.ClipsDescendants = true
                bodyClip.Size = UDim2.new(1, 0, 0, fullSize)
                collapseTween = play(bodyClip, 0.32, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
                play(chev.Glyph, 0.25, {Rotation = -90})
            else
                play(chev.Glyph, 0.25, {Rotation = 0})
                collapseTween = play(bodyClip, 0.34, {Size = UDim2.new(1, 0, 0, fullSize)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
                after(collapseTween, function() if not collapsed then bodyClip.AutomaticSize = Enum.AutomaticSize.Y bodyClip.ClipsDescendants = false end end)
            end
        end
        head.Activated:Connect(function() if sc.Collapsible == false then return end setCollapsed(not collapsed) end)
        if sc.Collapsible == false then chev.Holder.Visible = false end
        if sc.Collapsed then task.defer(function() setCollapsed(true) end) end

        function section:SetName(n) secLabel.Text = string.upper(tostring(n)) end
        function section:Collapse(state) setCollapsed(state ~= false) end
        return section
    end

    return tabApi
end

function TabImpl.select(Window, target, instant)
    local P = Window._parts
    if type(target) == "number" then target = Window.Tabs[target] end
    if type(target) == "string" then for _, t in ipairs(Window.Tabs) do if t.Name == target then target = t break end end end
    if type(target) ~= "table" or not target.Button then return end
    local prev = Window.Selected
    if prev == target then return end
    Popup.close(true)
    Window.Selected = target

    local forward = not prev or target.Index > prev.Index
    if instant or not prev then
        for _, t in ipairs(Window.Tabs) do t.Page.Visible = t == target t.Page.GroupTransparency = t == target and 0 or 1 end
        target.Restore()
    else
        if prev then
            prev.Remember()
            play(prev.Page, 0.16, {GroupTransparency = 1})
            task.delay(0.18, function() if Window.Selected ~= prev then prev.Page.Visible = false end end)
        end
        target.Page.Visible = true
        target.Page.GroupTransparency = 1
        target.Page.Position = UDim2.fromOffset(0, 14 * (forward and 1 or -1))
        target.Restore()
        play(target.Page, 0.34, {GroupTransparency = 0})
        play(target.Page, 0.42, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
    end

    for _, t in ipairs(Window.Tabs) do
        local active = t == target
        t.IconObj.Color(active and Pal.Accent or Pal.Sub, not instant)
        if t.Label then play(t.Label, 0.2, {TextColor3 = active and Pal.Text or Pal.Sub}) end
    end

    task.defer(function()
        local b = target.Button
        local pill = P.pill
        pill.Visible = true
        local y = b.AbsolutePosition.Y - P.side.AbsolutePosition.Y
        local x = b.AbsolutePosition.X - P.side.AbsolutePosition.X
        local scale = math.max(currentScale, 0.01)
        local targetPos = Nihon.ShowTabsOnTop and UDim2.fromOffset(x / scale, 4) or UDim2.fromOffset(6, y / scale)
        local targetSize = Nihon.ShowTabsOnTop and UDim2.new(0, b.AbsoluteSize.X / scale, 0, b.AbsoluteSize.Y / scale) or UDim2.new(1, -12, 0, b.AbsoluteSize.Y / scale)
        if instant or not prev then pill.Position, pill.Size = targetPos, targetSize
        else play(pill, 0.42, {Position = targetPos, Size = targetSize}, Enum.EasingStyle.Back) end
    end)
end

-- =========================================================
-- ELEMENTS (Buttons, Toggles, Sliders, etc.)
-- =========================================================
local function numFormat(v, step, suffix)
    local s
    if step < 1 then
        local frac = (tostring(step):gsub("^0%.", ""))
        local places = math.min(3, math.max(1, #frac))
        s = string.format("%." .. places .. "f", v)
        s = (s:gsub("0+$", "")) s = (s:gsub("%.$", ""))
    else s = tostring(math.floor(v + 0.5)) end
    if suffix and suffix ~= "" then return s .. " " .. suffix end
    return s
end

local function snapTo(v, step, min)
    if step <= 0 then return v end
    return min + math.floor((v - min) / step + 0.5) * step
end

function ElementFactory(Window, Tab, parent, sectionName)
    local P = Window._parts
    local mobile = P.mobile
    local E = {_count = 0}
    local rowH = mobile and 40 or 36

    local function card(height, hover)
        local c = mk("TextButton", {Size = UDim2.new(1, 0, 0, height or rowH), BackgroundTransparency = 0.15, ZIndex = 14, LayoutOrder = E._count + 1, Parent = parent})
        bind(c, "BackgroundColor3", "Surface")
        round(c, 6)
        local st = outline(c, "Stroke", 1, 0.45)
        c:SetAttribute("NihonCard", true)
        if hover ~= false and not mobile then
            c.MouseEnter:Connect(function() play(c, 0.15, {BackgroundTransparency = 0}) play(st, 0.15, {Transparency = 0.1}) end)
            c.MouseLeave:Connect(function() play(c, 0.2, {BackgroundTransparency = 0.15}) play(st, 0.2, {Transparency = 0.45}) end)
        end
        return c, st
    end

    local function nameLabel(c, text, width)
        return tx("TextLabel", {Name = "Name", Text = tostring(text), TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = width or UDim2.new(1, -80, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15, Parent = c}, 2)
    end

    local function decorate(obj, c, opts, kind)
        E._count = E._count + 1
        local locked = false
        local veil = mk("Frame", {Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, ZIndex = 40, Parent = c})
        round(veil, 6)
        local lockIco = makeIcon(veil, "lock", 15, "Sub", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 41})
        mk("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 42, Parent = veil})

        function obj:Lock(v) if v == nil then v = true end locked = v and true or false veil.Visible = locked end
        function obj:IsLocked() return locked end
        function obj:SetVisible(v) c.Visible = v and true or false end
        function obj:Destroy()
            c:Destroy()
            for i, e in ipairs(P.searchIndex) do if e.owner == obj then table.remove(P.searchIndex, i) break end end
        end
        function obj:SetName(n) local l = c:FindFirstChild("Name") if l then l.Text = tostring(n) end end
        obj.Card = c
        obj.Kind = kind

        if opts.Locked then obj:Lock(true) end
        if opts.Visible == false then c.Visible = false end

        P.searchIndex[#P.searchIndex + 1] = {
            owner = obj, name = tostring(opts.Name or kind), tab = Tab.Name, section = sectionName, kind = kind,
            go = function()
                if Window.RequestOpen then Window.RequestOpen() end
                Window:SelectTab(Tab)
                task.delay(0.22, function()
                    if not c.Parent then return end
                    local sc = Tab.Scroll
                    local y = c.AbsolutePosition.Y - sc.AbsolutePosition.Y + sc.CanvasPosition.Y - 10
                    play(sc, 0.35, {CanvasPosition = Vector2.new(0, math.max(0, y))})
                    flashCard(c, Pal.Accent, 1.1)
                end)
            end,
        }
        return obj
    end

    local function register(flag, obj, opts, get, set)
        if not flag then return end
        registerFlag(flag, {get = get, set = set, save = opts.Save == true, obj = obj})
        Nihon.Flags[flag] = obj
    end

    local function fail(c, label, err)
        flashCard(c, Status.Error, 1.1)
        shake(c)
        Nihon:MakeNotification({Name = (label or "Action") .. " failed", Content = tostring(err), Type = "Error", Time = 5})
    end

    -- Elements
    function E:AddLabel(o)
        o = type(o) == "table" and o or {Name = o}
        local c = card(rowH - 6, false)
        c.Active = false
        local l = nameLabel(c, o.Name or "", UDim2.new(1, -20, 1, 0))
        bind(l, "TextColor3", "Sub")
        local obj = {}
        function obj:Set(t) l.Text = tostring(t) end
        function obj:Get() return l.Text end
        return decorate(obj, c, o, "Label")
    end

    function E:AddParagraph(o)
        o = o or {}
        local c = card(0, false)
        c.AutomaticSize = Enum.AutomaticSize.Y
        c.Size = UDim2.new(1, 0, 0, 0)
        c.Active = false
        inset(c, 10, 12, 10, 12)
        stack(c, 4)
        local head = tx("TextLabel", {Text = tostring(o.Title or o.Name or "Note"), TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, ZIndex = 15, Parent = c}, 3)
        local text = tx("TextLabel", {Text = tostring(o.Content or ""), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 15, Parent = c}, 1, "Sub")
        local obj = {}
        function obj:Set(t) text.Text = tostring(t) end
        function obj:SetTitle(t) head.Text = tostring(t) end
        o.Name = o.Name or o.Title
        return decorate(obj, c, o, "Paragraph")
    end

    function E:AddButton(o)
        o = o or {}
        local label = tostring(o.Name or "Button")
        local cooldown = tonumber(o.Cooldown) or 0.35
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1, -50, 1, 0))
        local arrow = makeIcon(c, o.Icon or "chevron-right", 14, "Sub", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 15})

        local timer = mk("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, Visible = false, ZIndex = 20, Parent = c})
        accentGradient(timer, 0)
        c.ClipsDescendants = true

        local obj = {}
        local ready = true
        local running = false

        function obj:Fire(...)
            if obj:IsLocked() or not ready or running then if not ready then shake(c) end return false end
            running = true ready = cooldown <= 0
            play(c, 0.08, {BackgroundTransparency = 0.35})
            task.delay(0.08, function() play(c, 0.25, {BackgroundTransparency = 0.15}) end)
            if cooldown > 0 then
                timer.Visible = true timer.Size = UDim2.new(1, 0, 0, 2)
                local tw = play(timer, cooldown, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)
                after(tw, function() timer.Visible = false end)
                task.delay(cooldown, function() ready = true end)
            end
            local args = table.pack(...)
            task.spawn(function()
                local cb = o.Callback
                if type(cb) ~= "function" then running = false fail(c, label, "no callback attached") return end
                local ok, err = pcall(cb, table.unpack(args, 1, args.n))
                running = false
                if not ok then fail(c, label, err) else flashCard(c, Status.Success, 0.55) end
            end)
            return true
        end
        c.Activated:Connect(function() obj:Fire() end)
        function obj:SetCallback(fn) o.Callback = fn end
        function obj:SetCooldown(s) cooldown = tonumber(s) or 0 end
        return decorate(obj, c, o, "Button")
    end

    function E:AddToggle(o)
        o = o or {}
        local label = tostring(o.Name or "Toggle")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1, -60, 1, 0))

        local track = mk("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(36, 20), ZIndex = 15, Parent = c})
        bind(track, "BackgroundColor3", "Elevated")
        round(track, 10)
        local trackStroke = outline(track, "Stroke", 1, 0.25)
        local fill = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 16, Parent = track})
        round(fill, 10)
        accentGradient(fill, 25)
        local knob = mk("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 18, Parent = track})
        round(knob, 8)

        local state = {value = false, shown = false}
        local obj = {Value = false}

        local function paint(v, animated)
            state.shown = v
            local dur = animated and 0.28 or 0.001
            play(fill, dur, {BackgroundTransparency = v and 0 or 1})
            play(knob, dur, {Position = UDim2.new(0, v and 20 or 2, 0.5, 0)}, Enum.EasingStyle.Back)
            play(trackStroke, dur, {Transparency = v and 1 or 0.25})
        end

        local firer = makeFirer(function() return state.value end, function(v)
            local ok, err = pcall(o.Callback or function() end, v)
            if not ok then fail(c, label, err) end
        end)

        function obj:Set(v, silent)
            v = v and true or false
            state.value = v obj.Value = v
            paint(v, true)
            if silent then firer.Sync(v) else firer.Fire() queueSave() end
        end
        function obj:Get() return state.value end
        function obj:Toggle() obj:Set(not state.value) end

        c.Activated:Connect(function() if obj:IsLocked() then return end obj:Set(not state.value) end)
        register(o.Flag, obj, o, function() return state.value end, function(v) obj:Set(v) end)
        decorate(obj, c, o, "Toggle")
        local start = o.Default and true or false
        state.value = start obj.Value = start
        paint(start, false)
        if start then initFires[#initFires + 1] = function() firer.Fire() end else firer.Sync(false) end
        return obj
    end

    function E:AddSlider(o)
        o = o or {}
        local label = tostring(o.Name or "Slider")
        local min, max = tonumber(o.Min) or 0, tonumber(o.Max) or 100
        if max <= min then max = min + 1 end
        local step = tonumber(o.Increment) or 1
        local suffix = o.ValueName or ""
        local c = card(mobile and 54 or 50, true)
        local nm = nameLabel(c, label, UDim2.new(0.55, 0, 0, 20))
        nm.Position = UDim2.fromOffset(10, 6)

        local valBox = tx("TextBox", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0.45, 0, 0, 20), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 16, Parent = c}, 3, "Accent")
        valBox.ClearTextOnFocus = true

        local rail = mk("TextButton", {Position = UDim2.new(0, 10, 1, mobile and -20 or -18), Size = UDim2.new(1, -20, 0, mobile and 8 or 6), ZIndex = 16, Parent = c})
        bind(rail, "BackgroundColor3", "Elevated")
        round(rail, 4)
        local fillBar = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 17, Parent = rail})
        round(fillBar, 4)
        accentGradient(fillBar, 0)
        local knob = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(mobile and 16 or 12, mobile and 16 or 12), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 19, Parent = rail})
        round(knob, 8)

        local value = math.clamp(tonumber(o.Default) or min, min, max)
        local obj = {Value = value}
        local dragging = false
        local shownFrac = 0
        local goalFrac = 0
        local runner

        local function fracOf(v) return math.clamp((v - min) / (max - min), 0, 1) end
        local function draw(frac) fillBar.Size = UDim2.new(frac, 0, 1, 0) knob.Position = UDim2.new(frac, 0, 0.5, 0) end
        local function ensureRunner()
            if runner then return end
            runner = RunService.RenderStepped:Connect(function(dt)
                local a = 1 - math.exp(-dt * 22)
                shownFrac = shownFrac + (goalFrac - shownFrac) * a
                if math.abs(goalFrac - shownFrac) < 0.0005 and not dragging then shownFrac = goalFrac runner:Disconnect() runner = nil end
                draw(shownFrac)
            end)
        end

        local firer = makeFirer(function() return obj.Value end, function(v)
            local ok, err = pcall(o.Callback or function() end, v)
            if not ok then fail(c, label, err) end
        end)

        local function commit(v, silent, jump)
            v = math.clamp(snapTo(v, step, min), min, max)
            if v == obj.Value and not jump then return end
            obj.Value = v
            goalFrac = fracOf(v)
            if jump then shownFrac = goalFrac draw(goalFrac) else ensureRunner() end
            valBox.Text = numFormat(v, step, suffix)
            if silent then firer.Sync(v) else firer.Fire() queueSave() end
        end

        function obj:Set(v, silent) commit(tonumber(v) or min, silent) end
        function obj:Get() return obj.Value end

        local function fromX(x)
            local rel = (x - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1)
            commit(min + (max - min) * math.clamp(rel, 0, 1))
        end

        trackPointer(rail, function(input)
            if obj:IsLocked() then return false end
            dragging = true
            play(knob, 0.15, {Size = UDim2.fromOffset(mobile and 20 or 16, mobile and 20 or 16)})
            ensureRunner()
            fromX(input.Position.X)
        end, function(pos) fromX(pos.X) end, function()
            dragging = false
            play(knob, 0.25, {Size = UDim2.fromOffset(mobile and 16 or 12, mobile and 16 or 12)}, Enum.EasingStyle.Back)
        end)

        valBox.FocusLost:Connect(function()
            local n = tonumber(valBox.Text:match("-?%d+%.?%d*"))
            if n then obj:Set(n) else valBox.Text = numFormat(obj.Value, step, suffix) end
        end)

        register(o.Flag, obj, o, function() return obj.Value end, function(v) obj:Set(v) end)
        decorate(obj, c, o, "Slider")
        valBox.Text = numFormat(value, step, suffix)
        goalFrac = fracOf(value) shownFrac = goalFrac
        draw(goalFrac)
        initFires[#initFires + 1] = function() firer.Fire() end
        return obj
    end

    function E:AddTextbox(o)
        o = o or {}
        local label = tostring(o.Name or "Textbox")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(0.42, 0, 1, 0))
        local box = tx("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.52, -6, 0, 26), Text = tostring(o.Default or ""), PlaceholderText = o.Placeholder or "type here", TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 16, Parent = c}, 2)
        bind(box, "BackgroundColor3", "Elevated")
        box.BackgroundTransparency = 0
        round(box, 6)
        inset(box, 0, 8, 0, 8)
        local ring = outline(box, "Accent", 1.2, 1)
        box.Focused:Connect(function() play(ring, 0.15, {Transparency = 0.1}) end)
        local obj = {Value = box.Text}
        local firer = makeFirer(function() return obj.Value end, function(v)
            local ok, err = pcall(o.Callback or function() end, v)
            if not ok then fail(c, label, err) end
        end)
        box.FocusLost:Connect(function()
            play(ring, 0.2, {Transparency = 1})
            obj.Value = box.Text
            firer.Sync(nil) firer.Fire() queueSave()
            if o.TextDisappear then box.Text = "" end
        end)
        function obj:Set(v, silent)
            box.Text = tostring(v) obj.Value = box.Text
            if silent then firer.Sync(obj.Value) else firer.Sync(nil) firer.Fire() queueSave() end
        end
        function obj:Get() return obj.Value end
        register(o.Flag, obj, o, function() return obj.Value end, function(v) obj:Set(v) end)
        return decorate(obj, c, o, "Textbox")
    end

    local function buildDropdown(o, multi)
        o = o or {}
        local label = tostring(o.Name or (multi and "Multi Select" or "Dropdown"))
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(0.45, 0, 1, 0))
        local valLbl = tx("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2.new(0.5, -36, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 11, ZIndex = 15, Parent = c}, 3, "Accent")
        local arrow = makeIcon(c, "chevron-down", 12, "Sub", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 15})

        local obj = {Options = o.Options or {}, Value = multi and {} or nil, IsOpen = false}
        local firer
        local function selected(opt) if multi then return obj.Value[opt] == true end return obj.Value == opt end
        local function orderedSelection() local out = {} for _, opt in ipairs(obj.Options) do if obj.Value[opt] then out[#out + 1] = opt end end return out end
        local function summary()
            if multi then local list = orderedSelection() if #list == 0 then return "None" end if #list <= 2 then return table.concat(list, ", ") end return #list .. " selected" end
            return obj.Value ~= nil and tostring(obj.Value) or "None"
        end
        local function current() if multi then return orderedSelection() end return obj.Value end

        firer = makeFirer(function() if multi then return table.concat(orderedSelection(), "\0") end return obj.Value end, function()
            local ok, err = pcall(o.Callback or function() end, current())
            if not ok then fail(c, label, err) end
        end)

        local live
        local rows = {}
        local function restyle()
            valLbl.Text = summary()
            for opt, r in pairs(rows) do
                if r.btn.Parent then
                    local on = selected(opt)
                    play(r.btn, 0.15, {BackgroundTransparency = on and 0.86 or 1})
                    play(r.check, 0.15, {ImageTransparency = on and 0 or 1})
                    r.label.TextColor3 = on and Pal.Text or Pal.Sub
                end
            end
        end

        function obj:Close()
            if live then local f = live live = nil if Popup.current and Popup.current.frame == f then Popup.close() end end
            obj.IsOpen = false
            play(arrow.Glyph, 0.25, {Rotation = 0})
        end

        function obj:Open()
            if obj.IsOpen or obj:IsLocked() then return end
            local count = #obj.Options
            local wantSearch = count > 7
            local rowsH = math.min(count, 6) * 28 + 8
            local total = rowsH + (wantSearch and 36 or 0)
            local width = math.max(c.AbsoluteSize.X / math.max(currentScale, 0.01), 180)
            obj.IsOpen = true
            play(arrow.Glyph, 0.25, {Rotation = 180})
            live = Popup.open(c, {
                width = width, height = total, owner = obj, align = "right",
                onClose = function() obj.IsOpen = false live = nil rows = {} play(arrow.Glyph, 0.25, {Rotation = 0}) end,
                build = function(frame, w, h)
                    local top = 0
                    local filter = ""
                    local scrollHolder
                    local function layoutRows()
                        for i, opt in ipairs(obj.Options) do
                            local r = rows[opt]
                            if r then r.btn.Visible = filter == "" or tostring(opt):lower():find(filter, 1, true) ~= nil end
                        end
                    end
                    if wantSearch then
                        local sb = tx("TextBox", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 26), PlaceholderText = "search", TextSize = 11, ZIndex = 63, Parent = frame}, 2)
                        bind(sb, "BackgroundColor3", "Elevated")
                        sb.BackgroundTransparency = 0
                        round(sb, 6)
                        inset(sb, 0, 8, 0, 8)
                        sb:GetPropertyChangedSignal("Text"):Connect(function() filter = sb.Text:lower() layoutRows() end)
                        top = 36
                    end
                    scrollHolder = mk("ScrollingFrame", {Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62, Parent = frame})
                    bind(scrollHolder, "ScrollBarImageColor3", "Accent")
                    inset(scrollHolder, 4, 4, 4, 4)
                    stack(scrollHolder, 2)
                    for i, opt in ipairs(obj.Options) do
                        local b = mk("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 63, Parent = scrollHolder})
                        round(b, 4)
                        accentGradient(b, 0)
                        local l = tx("TextLabel", {Text = tostring(opt), TextSize = 11, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 64, Parent = b}, 2, "Sub")
                        local ck = makeIcon(b, "check", 12, "Accent", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 64})
                        ck.Glyph.TextTransparency = selected(opt) and 0 or 1
                        rows[opt] = {btn = b, label = l, check = ck.Glyph}
                        b.MouseEnter:Connect(function() if not selected(opt) then play(b, 0.1, {BackgroundTransparency = 0.94}) end end)
                        b.MouseLeave:Connect(function() if not selected(opt) then play(b, 0.15, {BackgroundTransparency = 1}) end end)
                        b.Activated:Connect(function()
                            if multi then obj.Value[opt] = (not obj.Value[opt]) or nil restyle() firer.Fire() queueSave()
                            else obj:Set(opt) obj:Close() end
                        end)
                    end
                    restyle()
                end,
            })
        end

        function obj:Get() return current() end
        function obj:Set(v, silent)
            if multi then
                obj.Value = {}
                if type(v) == "table" then
                    for k, x in pairs(v) do if type(k) == "number" then obj.Value[x] = true elseif x then obj.Value[k] = true end end
                end
            else
                if v ~= nil and not table.find(obj.Options, v) then return end
                obj.Value = v
            end
            restyle()
            if silent then firer.Sync(multi and table.concat(orderedSelection(), "\0") or obj.Value)
            else firer.Fire() queueSave() end
        end
        function obj:Refresh(list, keepValue)
            obj.Options = list or {}
            if not keepValue then obj.Value = multi and {} or nil
            elseif not multi and obj.Value ~= nil and not table.find(obj.Options, obj.Value) then obj.Value = nil end
            if obj.IsOpen then obj:Close() end
            valLbl.Text = summary()
        end
        function obj:Add(opt) obj.Options[#obj.Options + 1] = opt end

        c.Activated:Connect(function() if obj.IsOpen then obj:Close() else obj:Open() end end)
        register(o.Flag, obj, o, current, function(v) obj:Set(v) end)
        decorate(obj, c, o, multi and "Multi Dropdown" or "Dropdown")
        if multi then obj:Set(o.Default or {}, true)
        else local first = o.Default if first == nil and o.AllowNone ~= true then first = obj.Options[1] end obj:Set(first, true) end
        valLbl.Text = summary()
        initFires[#initFires + 1] = function() firer.Fire() end
        return obj
    end

    function E:AddDropdown(o) return buildDropdown(o, false) end
    function E:AddMultiDropdown(o) return buildDropdown(o, true) end

    function E:AddColorpicker(o)
        o = o or {}
        local label = tostring(o.Name or "Color")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1, -60, 1, 0))
        local swatch = mk("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 20), ZIndex = 15, Parent = c})
        round(swatch, 6)
        outline(swatch, "Text", 1, 0.75)

        local start = typeof(o.Default) == "Color3" and o.Default or Color3.fromRGB(255, 70, 90)
        local h, s, v = start:ToHSV()
        local obj = {Value = start, IsOpen = false, Rainbow = false}
        local firer = makeFirer(function() return obj.Value end, function(col)
            local ok, err = pcall(o.Callback or function() end, col)
            if not ok then fail(c, label, err) end
        end)

        local ui = {}
        local function apply(silent)
            local col = Color3.fromHSV(h, s, v)
            obj.Value = col
            swatch.BackgroundColor3 = col
            if ui.sv and ui.sv.Parent then
                ui.sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                ui.svKnob.Position = UDim2.fromScale(s, 1 - v)
                ui.svKnob.BackgroundColor3 = col
                ui.hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
                if not ui.hex:IsFocused() then ui.hex.Text = "#" .. col:ToHex():upper() end
            end
            if silent then firer.Sync(col) else firer.Fire() queueSave() end
        end

        function obj:Close() if obj.IsOpen and Popup.current and Popup.current.owner == obj then Popup.close() end obj.IsOpen = false end
        function obj:Open()
            if obj.IsOpen or obj:IsLocked() then return end
            obj.IsOpen = true
            local w = mobile and 226 or 246
            Popup.open(c, {
                width = w, height = 236, owner = obj, align = "right",
                onClose = function() obj.IsOpen = false ui = {} end,
                build = function(frame)
                    inset(frame, 10, 10, 10, 10)
                    local sv = mk("TextButton", {Size = UDim2.new(1, 0, 0, 122), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 62, Parent = frame})
                    round(sv, 6)
                    local white = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = sv})
                    round(white, 6)
                    mk("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = white})
                    local black = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 64, Parent = sv})
                    round(black, 6)
                    mk("UIGradient", {Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black})
                    local svKnob = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = obj.Value, ZIndex = 66, Parent = sv})
                    round(svKnob, 8)
                    mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svKnob})

                    local hue = mk("TextButton", {Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62, Parent = frame})
                    round(hue, 6)
                    local keys = {}
                    for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)) end
                    mk("UIGradient", {Color = ColorSequence.new(keys), Parent = hue})
                    local hueKnob = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(h, 0, 0.5, 0), Size = UDim2.fromOffset(6, 20), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 64, Parent = hue})
                    round(hueKnob, 3)
                    mk("UIStroke", {Color = Color3.new(0, 0, 0), Transparency = 0.5, Parent = hueKnob})

                    local hex = tx("TextBox", {Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, -86, 0, 28), PlaceholderText = "#RRGGBB", TextSize = 12, ZIndex = 62, Parent = frame}, 2)
                    bind(hex, "BackgroundColor3", "Elevated")
                    hex.BackgroundTransparency = 0
                    round(hex, 6)
                    inset(hex, 0, 8, 0, 8)
                    local rb = tx("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 156), Size = UDim2.fromOffset(78, 28), Text = "Rainbow", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62, Parent = frame}, 3)
                    bind(rb, "BackgroundColor3", "Elevated")
                    rb.BackgroundTransparency = 0
                    round(rb, 6)

                    local swatchRow = mk("Frame", {Position = UDim2.fromOffset(0, 192), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, ZIndex = 62, Parent = frame})
                    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = swatchRow})
                    local presets = {Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 220, 70), Color3.fromRGB(90, 220, 140), Color3.fromRGB(70, 200, 240), Color3.fromRGB(110, 140, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 255, 255)}
                    for i, pc in ipairs(presets) do
                        local p = mk("TextButton", {Size = UDim2.fromOffset(mobile and 22 or 24, 22), BackgroundColor3 = pc, LayoutOrder = i, ZIndex = 63, Parent = swatchRow})
                        round(p, 4)
                        p.Activated:Connect(function() h, s, v = pc:ToHSV() obj.Rainbow = false apply() end)
                    end

                    ui = {sv = sv, svKnob = svKnob, hueKnob = hueKnob, hex = hex}
                    local mode
                    local function fromPos(pos)
                        if mode == "sv" then s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1) v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
                        elseif mode == "hue" then h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999) end
                        obj.Rainbow = false apply()
                    end
                    trackPointer(sv, function(input) mode = "sv" fromPos(input.Position) end, function(p) fromPos(p) end, function() mode = nil end)
                    trackPointer(hue, function(input) mode = "hue" fromPos(input.Position) end, function(p) fromPos(p) end, function() mode = nil end)
                    hex.FocusLost:Connect(function()
                        local txt = hex.Text:gsub("#", "")
                        if #txt == 6 then local ok, col = pcall(Color3.fromHex, txt) if ok then h, s, v = col:ToHSV() apply() end end
                        hex.Text = "#" .. obj.Value:ToHex():upper()
                    end)
                    rb.Activated:Connect(function() obj.Rainbow = not obj.Rainbow rb.TextColor3 = obj.Rainbow and Pal.Accent or Pal.Text end)
                    hex.Text = "#" .. obj.Value:ToHex():upper()
                    svKnob.Position = UDim2.fromScale(s, 1 - v)
                end,
            })
        end

        keep(RunService.Heartbeat:Connect(function() if obj.Rainbow then h = (os.clock() * 0.2) % 1 apply() end end))
        function obj:Set(col, silent) if typeof(col) ~= "Color3" then return end h, s, v = col:ToHSV() apply(silent) end
        function obj:Get() return obj.Value end
        c.Activated:Connect(function() if obj.IsOpen then obj:Close() else obj:Open() end end)
        register(o.Flag, obj, o, function() return obj.Value end, function(col) obj:Set(col) end)
        decorate(obj, c, o, "Colorpicker")
        apply(true)
        initFires[#initFires + 1] = function() firer.Fire() end
        return obj
    end

    return E
end

-- =========================================================
-- LOADING & SETTINGS
-- =========================================================
local function loadingScreen(cfg, title, done)
    if cfg.IntroEnabled == false then done() return end
    local layer = mk("Frame", {Name = "Loading", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 400, Parent = Root})
    local card = mk("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 150), GroupTransparency = 1, ZIndex = 401, Parent = layer})
    bind(card, "BackgroundColor3", "Bg")
    round(card, 8)
    outline(card, "Stroke", 1, 0.05)
    local cardScale = mk("UIScale", {Scale = 0.88, Parent = card})

    local orb = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 402, Parent = card})
    round(orb, 23)
    local orbGrad = accentGradient(orb, 0)
    local orbIcon = makeIcon(orb, cfg.Icon or "zap", 22, false, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 403})
    orbIcon.Color(Color3.new(1, 1, 1))

    tx("TextLabel", {Text = tostring(cfg.IntroText or title), TextSize = 16, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.new(1, -30, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 402, Parent = card}, 3)
    local status = tx("TextLabel", {Text = "starting", TextSize = 11, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.new(1, -30, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 402, Parent = card}, 1, "Sub")
    local rail = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.new(1, -60, 0, 4), ZIndex = 402, Parent = card})
    bind(rail, "BackgroundColor3", "Elevated")
    round(rail, 2)
    local bar = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 403, Parent = rail})
    round(bar, 2)
    accentGradient(bar, 0)

    play(layer, 0.3, {BackgroundTransparency = 0.45})
    play(card, 0.3, {GroupTransparency = 0})
    play(cardScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
    local spin = RunService.RenderStepped:Connect(function() orbGrad.Rotation = (os.clock() * 220) % 360 end)

    local steps = {{"reading theme", 0.22}, {"building interface", 0.5}, {"loading config", 0.78}, {"ready", 1}}
    task.spawn(function()
        for _, st in ipairs(steps) do
            status.Text = st[1]
            play(bar, 0.35, {Size = UDim2.new(st[2], 0, 1, 0)}, Enum.EasingStyle.Quint)
            task.wait(0.28)
        end
        task.wait(0.15)
        spin:Disconnect()
        play(card, 0.25, {GroupTransparency = 1})
        play(cardScale, 0.3, {Scale = 1.06}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        play(layer, 0.3, {BackgroundTransparency = 1})
        task.wait(0.3)
        layer:Destroy()
        done()
    end)
end

local function attachSettings(Window)
    function Window:AddSettingsTab(opts)
        opts = opts or {}
        local tab = Window:MakeTab({Name = opts.Name or "Settings", Icon = opts.Icon or "settings"})
        local P = Window._parts

        local look = tab:AddSection({Name = "Appearance"})
        look:AddDropdown({Name = "Theme", Options = ThemeOrder, Default = themeName, Flag = "_theme", Save = true, Callback = function(v) setTheme(v, true) end})
        look:AddDropdown({Name = "Font", Options = FontOrder, Default = currentFont, Flag = "_font", Save = true, Callback = function(v) setFont(v) end})
        look:AddColorpicker({Name = "Accent color", Default = Pal.Accent, Flag = "_accent", Save = true, Callback = function(col) if col == Pal.Accent then return end if rainbowConn then setRainbow(false) end setAccent(col) end})
        look:AddToggle({Name = "Rainbow accent", Default = false, Flag = "_rainbow", Save = true, Callback = function(v) setRainbow(v) end})
        look:AddSlider({Name = "UI scale", Min = 60, Max = 130, Default = 100, Increment = 5, ValueName = "%", Flag = "_scale", Save = true, Callback = function(v) Window:SetScale(v / 100) end})
        look:AddSlider({Name = "Animation speed", Min = 50, Max = 200, Default = 100, Increment = 10, ValueName = "%", Flag = "_anim", Save = true, Callback = function(v) animSpeed = v / 100 end})
        look:AddToggle({Name = "Tabs on top", Default = Nihon.ShowTabsOnTop, Flag = "_tabsOnTop", Save = true, Callback = function(v) Nihon.ShowTabsOnTop = v Nihon:MakeNotification({Name = "Layout Changed", Content = "Restart the script to apply this layout change.", Type = "Warning"}) end})

        local alerts = tab:AddSection({Name = "Notifications"})
        alerts:AddDropdown({Name = "Position", Options = {"TopRight", "TopLeft", "TopCenter", "BottomRight", "BottomLeft", "BottomCenter"}, Default = Notes.position, Flag = "_notePos", Save = true, Callback = function(v) Nihon:SetNotificationPosition(v) end})
        alerts:AddSlider({Name = "Visible at once", Min = 1, Max = 8, Default = Notes.max, Flag = "_noteMax", Save = true, Callback = function(v) Nihon:SetNotificationLimit(v) end})
        alerts:AddSlider({Name = "Duration", Min = 1, Max = 12, Default = Notes.duration, ValueName = "s", Flag = "_noteTime", Save = true, Callback = function(v) Nihon:SetNotificationTime(v) end})
        alerts:AddButton({Name = "Send test", Icon = "bell", Callback = function() Nihon:MakeNotification({Name = "Test", Content = "This is what alerts look like.", Type = "Info"}) end})
        alerts:AddButton({Name = "Clear all", Icon = "trash-2", Callback = function() Nihon:ClearNotifications() end})

        local cfgSec = tab:AddSection({Name = "Config"})
        local nameBox = cfgSec:AddTextbox({Name = "Profile name", Placeholder = "my-config"})
        local profiles = cfgSec:AddDropdown({Name = "Profiles", Options = Nihon:ListProfiles(), AllowNone = true})
        local function refreshProfiles() profiles:Refresh(Nihon:ListProfiles()) end
        cfgSec:AddButton({Name = "Save profile", Icon = "save", Callback = function()
            local n = nameBox:Get() if n == "" then n = profiles:Get() or "" end
            if n == "" then error("type a profile name first") end
            if not Nihon:SaveProfile(n) then error("could not write the file") end
            refreshProfiles() Nihon:MakeNotification({Name = "Saved", Content = n, Type = "Success"})
        end})
        cfgSec:AddButton({Name = "Load profile", Icon = "download", Callback = function()
            local n = profiles:Get() if not n then error("choose a profile first") end
            if not Nihon:LoadProfile(n) then error("that profile could not be read") end
            Nihon:MakeNotification({Name = "Loaded", Content = n, Type = "Success"})
        end})
        cfgSec:AddButton({Name = "Delete profile", Icon = "trash-2", Callback = function()
            local n = profiles:Get() if not n then error("choose a profile first") end
            Nihon:Dialog({Title = "Delete profile", Content = "This permanently removes " .. n .. ".", Buttons = {{Name = "Cancel"}, {Name = "Delete", Primary = true, Danger = true, Callback = function() Nihon:DeleteProfile(n) refreshProfiles() end}}})
        end})
        cfgSec:AddButton({Name = "Set as autoload", Icon = "star", Callback = function()
            local n = profiles:Get() if not n then error("choose a profile first") end
            Nihon:SetAutoload(n) Nihon:MakeNotification({Name = "Autoload set", Content = n, Type = "Success"})
        end})
        cfgSec:AddButton({Name = "Copy config", Icon = "copy", Callback = function()
            local text = Nihon:ExportConfig() local put = setclipboard or toclipboard
            if not put then error("clipboard is not available here") end
            put(text) Nihon:MakeNotification({Name = "Copied", Content = "Config copied to clipboard", Type = "Success"})
        end})
        local importBox = cfgSec:AddTextbox({Name = "Paste config", Placeholder = "paste json", TextDisappear = true})
        cfgSec:AddButton({Name = "Import pasted config", Icon = "upload", Callback = function()
            local raw = importBox:Get() if raw == "" then error("paste a config into the box first") end
            if not Nihon:ImportConfig(raw) then error("that text is not a valid config") end
            Nihon:MakeNotification({Name = "Imported", Content = "Config applied", Type = "Success"})
        end})

        local ui = tab:AddSection({Name = "Interface"})
        ui:AddBind({Name = "Toggle menu", Default = Window.ToggleKey, Flag = "_toggleKey", Save = true, Callback = function() end})
        ui:AddButton({Name = "Player stats", Icon = "user", Callback = function() Window:OpenStats() end})
        ui:AddButton({Name = "Reset position", Icon = "refresh-cw", Callback = function()
            local shell = P.shell local v = viewport() local s = shell.AbsoluteSize
            shell.Position = UDim2.fromOffset(math.floor((v.X - s.X) / 2), math.floor((v.Y - s.Y) / 2))
        end})
        ui:AddButton({Name = "Destroy menu", Icon = "trash-2", Callback = function()
            Nihon:Dialog({Title = "Destroy menu", Content = "This removes everything and stops all connections.", Buttons = {{Name = "Cancel"}, {Name = "Destroy", Primary = true, Danger = true, Callback = function() Nihon:Destroy() end}}})
        end})

        local about = tab:AddSection({Name = "About"})
        about:AddParagraph({Title = "Nihon Lib " .. Nihon.Version, Content = "Tap the search button or press Ctrl+K to jump to any option."})

        local toggleRef = flagRefs._toggleKey
        if toggleRef then
            local orig = toggleRef.set
            toggleRef.set = function(k) if typeof(k) == "EnumItem" then Window.ToggleKey = k end orig(k) end
        end
        return tab
    end
end

-- =========================================================
-- SEARCH & STATS
-- =========================================================
local function fuzzy(query, text)
    query, text = query:lower(), text:lower()
    if query == "" then return 1 end
    local at = text:find(query, 1, true)
    if at then return 100 - at end
    local qi, score = 1, 0
    for i = 1, #text do
        if text:sub(i, i) == query:sub(qi, qi) then qi = qi + 1 score = score + 1 if qi > #query then return score end end
    end
    return nil
end

local function attachSearch(Window)
    local P = Window._parts
    local mobile = P.mobile
    local layer = mk("TextButton", {Name = "Search", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 180, Parent = Root})
    local w = math.clamp(viewport().X - 32, 260, 440)
    local box = mk("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, mobile and 16 or 70), Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ZIndex = 181, Parent = layer})
    bind(box, "BackgroundColor3", "Surface")
    round(box, 8)
    outline(box, "Stroke", 1, 0.1)
    local boxScale = mk("UIScale", {Scale = 0.94, Parent = box})
    stack(box, 0)

    local top = mk("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 182, Parent = box})
    local glass = makeIcon(top, "search", 14, "Sub", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), ZIndex = 183})
    local input = tx("TextBox", {Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -80, 1, 0), PlaceholderText = "search features", TextSize = 13, ZIndex = 183, Parent = top}, 2)
    input.ClearTextOnFocus = false
    local hint = tx("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 16), Text = mobile and "tap" or "esc", TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 183, Parent = top}, 3, "Sub")
    bind(hint, "BackgroundColor3", "Elevated")
    hint.BackgroundTransparency = 0
    round(hint, 4)

    local list = mk("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, LayoutOrder = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 182, Parent = box})
    inset(list, 6, 6, 6, 6)
    stack(list, 2)

    local open = false
    local buttons = {}
    local picked = 1
    local shown = {}

    local function highlight() for i, b in ipairs(buttons) do play(b, 0.1, {BackgroundTransparency = i == picked and 0.84 or 1}) end end

    local function render()
        for _, b in ipairs(buttons) do b:Destroy() end
        buttons = {} shown = {}
        local q = input.Text
        local scored = {}
        for _, e in ipairs(P.searchIndex) do
            local sc = fuzzy(q, e.name .. " " .. e.tab .. " " .. e.kind)
            if sc then scored[#scored + 1] = {e = e, s = sc} end
        end
        table.sort(scored, function(a, b) return a.s > b.s end)
        for i = 1, math.min(#scored, 30) do shown[i] = scored[i].e end
        for i, e in ipairs(shown) do
            local b = mk("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 183, Parent = list})
            round(b, 6)
            accentGradient(b, 0)
            tx("TextLabel", {Text = e.name, TextSize = 12, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -80, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 184, Parent = b}, 2)
            tx("TextLabel", {Text = e.tab .. (e.section and (" / " .. e.section) or ""), TextSize = 9, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -80, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 184, Parent = b}, 1, "Sub")
            b.Activated:Connect(function() Window:CloseSearch() e.go() end)
            buttons[i] = b
        end
        if #shown == 0 then
            local none = tx("TextLabel", {Text = "nothing matches", TextSize = 11, Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 183, Parent = list}, 1, "Sub")
            buttons[1] = none
        end
        picked = 1
        list.Size = UDim2.new(1, 0, 0, math.min(math.max(#shown, 1) * 38 + 12, mobile and 170 or 300))
        highlight()
    end

    input:GetPropertyChangedSignal("Text"):Connect(function() if open then render() end end)

    function Window:OpenSearch()
        if open then return end
        open = true
        Popup.close(true)
        input.Text = ""
        layer.Visible = true
        render()
        play(layer, 0.25, {BackgroundTransparency = 0.6})
        play(box, 0.25, {GroupTransparency = 0})
        play(boxScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
        if not mobile then task.delay(0.05, function() if open then input:CaptureFocus() end end) end
    end

    function Window:CloseSearch()
        if not open then return end
        open = false
        input:ReleaseFocus()
        play(layer, 0.2, {BackgroundTransparency = 1})
        play(box, 0.18, {GroupTransparency = 1})
        play(boxScale, 0.2, {Scale = 0.96})
        task.delay(0.24, function() if not open then layer.Visible = false end end)
    end

    layer.Activated:Connect(function() Window:CloseSearch() end)
    box.Active = true
    input.FocusLost:Connect(function(enter) if enter and shown[picked] then local e = shown[picked] Window:CloseSearch() e.go() end end)
    top.InputBegan:Connect(function(i) if isPointer(i) and open then input:CaptureFocus() end end)

    keep(UserInputService.InputBegan:Connect(function(i, gpe)
        if i.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if open then Window:CloseSearch() else Window:OpenSearch() end
            return
        end
        if not open then return end
        if i.KeyCode == Enum.KeyCode.Escape then Window:CloseSearch()
        elseif i.KeyCode == Enum.KeyCode.Down then picked = math.min(picked + 1, #shown) highlight()
        elseif i.KeyCode == Enum.KeyCode.Up then picked = math.max(picked - 1, 1) highlight() end
    end))

    P.searchBtn.Activated:Connect(function() if open then Window:CloseSearch() else Window:OpenSearch() end end)
end

local function attachStats(Window)
    local P = Window._parts
    local mobile = P.mobile
    local layer = mk("TextButton", {Name = "Stats", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 170, Parent = Root})
    local w = mobile and 300 or 340
    local sheet = mk("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ZIndex = 171, Parent = layer})
    bind(sheet, "BackgroundColor3", "Surface")
    round(sheet, 12)
    outline(sheet, "Stroke", 1, 0.1)
    local sheetScale = mk("UIScale", {Scale = 0.92, Parent = sheet})
    stack(sheet, 0)

    local hero = mk("Frame", {Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, ZIndex = 172, Parent = sheet})
    local hg = accentGradient(hero, 30)
    hero.BackgroundTransparency = 0.72
    local bigAvatar = mk("ImageLabel", {Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(50, 50), ZIndex = 173, Parent = hero})
    bind(bigAvatar, "BackgroundColor3", "Elevated")
    round(bigAvatar, 25)
    outline(bigAvatar, "Text", 2, 0.6)
    Stat.avatar(function(img) if bigAvatar.Parent then bigAvatar.Image = img end end)
    tx("TextLabel", {Text = LocalPlayer.DisplayName, TextSize = 15, Position = UDim2.fromOffset(76, 18), Size = UDim2.new(1, -90, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 173, Parent = hero}, 3)
    tx("TextLabel", {Text = "@" .. LocalPlayer.Name, TextSize = 11, Position = UDim2.fromOffset(76, 38), Size = UDim2.new(1, -90, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 173, Parent = hero}, 1, "Sub")

    local rowsBox = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 172, Parent = sheet})
    inset(rowsBox, 8, 12, 4, 12)
    stack(rowsBox, 0)
    local valueLabels = {}

    local footer = mk("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 172, Parent = sheet})
    local done = tx("TextButton", {Text = "Close", TextSize = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.new(0.5, -16, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 173, Parent = footer}, 3)
    bind(done, "BackgroundColor3", "Accent")
    done.BackgroundTransparency = 0
    round(done, 6)
    done.TextColor3 = Color3.new(1, 1, 1)

    local open = false
    local ticker

    local function build()
        for _, c in ipairs(rowsBox:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        valueLabels = {}
        local rows = Stat.rows()
        for i, r in ipairs(rows) do
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 172, Parent = rowsBox})
            tx("TextLabel", {Text = r[1], TextSize = 11, Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 173, Parent = row}, 1, "Sub")
            valueLabels[r[1]] = tx("TextLabel", {Text = r[2], TextSize = 11, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.58, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 173, Parent = row}, 2)
            if i < #rows then
                local sep = mk("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.7, ZIndex = 172, Parent = row})
                bind(sep, "BackgroundColor3", "Stroke")
            end
        end
    end

    function Window:OpenStats()
        if open then return end
        open = true
        Popup.close(true)
        build()
        layer.Visible = true
        play(layer, 0.25, {BackgroundTransparency = 0.55})
        play(sheet, 0.25, {GroupTransparency = 0})
        play(sheetScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
        local acc = 0
        ticker = RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.5 then return end
            acc = 0
            for _, r in ipairs(Stat.rows()) do local l = valueLabels[r[1]] if l and l.Text ~= r[2] then l.Text = r[2] end end
        end)
    end

    function Window:CloseStats()
        if not open then return end
        open = false
        if ticker then ticker:Disconnect() ticker = nil end
        play(layer, 0.2, {BackgroundTransparency = 1})
        play(sheet, 0.18, {GroupTransparency = 1})
        play(sheetScale, 0.2, {Scale = 0.94})
        task.delay(0.24, function() if not open then layer.Visible = false end end)
    end

    layer.Activated:Connect(function() Window:CloseStats() end)
    sheet.Active = true
    done.Activated:Connect(function() Window:CloseStats() end)

    P.footer.Activated:Connect(function() if open then Window:CloseStats() else Window:OpenStats() end end)
    keep(RunService.Heartbeat:Connect(function()
        local hum = Stat.humanoid()
        local col = Status.Success
        if hum then local f = hum.Health / math.max(hum.MaxHealth, 1) col = f > 0.6 and Status.Success or (f > 0.3 and Status.Warning or Status.Error) end
        if P.avatar and P.avatar.BackgroundColor3 ~= col then P.avatar.BackgroundColor3 = col end
    end))
end

-- =========================================================
-- FINAL INIT
-- =========================================================
Hooks.attach = function(Window)
    function Window:MakeTab(cfg) return TabImpl.make(Window, cfg) end
    function Window:SelectTab(tab, instant) TabImpl.select(Window, tab, instant) end
    function Window:Notify(cfg) return Nihon:MakeNotification(cfg) end
    function Window:SetScale(s) Window.Scale = math.clamp(tonumber(s) or 1, 0.5, 1.4) Window._parts.applyScale(true) end
    function Window:SetTitle(t) Window.TitleLabel.Text = tostring(t) Hud.title = tostring(t) end
    function Window:SetSubtitle(t) Window.SubtitleLabel.Text = tostring(t) Window.SubtitleLabel.Visible = tostring(t) ~= "" end
    function Window:SetIcon(id) Window.LogoIcon.Set(id) Window.LauncherIcon.Set(id) end
    function Window:SetTabIcon(name, id) for _, t in ipairs(Window.Tabs) do if t.Name == name then t:SetIcon(id) end end end
    attachSearch(Window)
    attachStats(Window)
    attachSettings(Window)
end

function Nihon:Init()
    if Nihon._ready then return end
    local window = Nihon.Windows[1]
    local cfg = window and window.Cfg or {}
    
    -- Key System Check
    if not createKeySystem(cfg) then return end
    
    local function finish()
        if Nihon.SaveConfig then
            local auto = Nihon:GetAutoload()
            Nihon:LoadProfile(auto or "default")
        end
        for _, fn in ipairs(initFires) do task.spawn(pcall, fn) end
        table.clear(initFires)
        Nihon._ready = true
        if window then window.Show() end
    end
    loadingScreen(cfg, window and window.Name or "Nihon Lib", finish)
end

function Nihon:Destroy()
    Nihon._ready = false
    Popup.close(true)
    if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end
    if noteLoop then noteLoop:Disconnect() noteLoop = nil end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    for _, w in ipairs(Nihon.Windows) do pcall(function() w._parts.launcher:Destroy() end) end
    Nihon.Windows = {}
    pcall(function() Root:Destroy() end)
    if env.NihonLibInstance == Nihon then env.NihonLibInstance = nil end
end

return Nihon

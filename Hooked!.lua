--[[
    Nihon Lib  |  v5.0 "Glass"
    Transparent, dashboard-grade UI. Backward compatible with v3 API.
]]

local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService")
local Stats               = game:GetService("Stats")
local MarketplaceService  = game:GetService("MarketplaceService")
local TextService         = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
if type(env.NihonLibInstance) == "table" and type(env.NihonLibInstance.Destroy) == "function" then
    pcall(env.NihonLibInstance.Destroy, env.NihonLibInstance)
end

local Nihon = {
    Version     = "5.0.0",
    Flags       = {},
    Windows     = {},
    Folder      = "NihonLib",
    Profile     = "default",
    SaveConfig  = false,
    IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    ShowLauncher = true, ShowResize = true, ShowSearch = true, ShowHelp = true,
    ShowMinimize = true, ShowClose = true, SidebarVisible = true,
}
env.NihonLibInstance = Nihon

local conns = {}
local function keep(c) conns[#conns+1] = c; return c end

local Themes = {
    Glass = {
        Bg = Color3.fromRGB(14, 15, 22), Surface = Color3.fromRGB(24, 25, 34), Elevated = Color3.fromRGB(32, 34, 46),
        Card = Color3.fromRGB(28, 30, 42), Stroke = Color3.fromRGB(56, 60, 78), Text = Color3.fromRGB(242, 242, 250),
        Sub = Color3.fromRGB(152, 155, 178), Accent = Color3.fromRGB(140, 120, 255), Accent2 = Color3.fromRGB(120, 200, 255),
    },
    Nihon = {
        Bg = Color3.fromRGB(11, 12, 17), Surface = Color3.fromRGB(20, 21, 28), Elevated = Color3.fromRGB(28, 30, 40),
        Card = Color3.fromRGB(24, 26, 34), Stroke = Color3.fromRGB(44, 47, 62), Text = Color3.fromRGB(240, 240, 248),
        Sub = Color3.fromRGB(150, 152, 172), Accent = Color3.fromRGB(140, 90, 255), Accent2 = Color3.fromRGB(90, 170, 255),
    },
    Midnight = {
        Bg = Color3.fromRGB(8, 9, 16), Surface = Color3.fromRGB(16, 18, 28), Elevated = Color3.fromRGB(24, 27, 42),
        Card = Color3.fromRGB(20, 22, 34), Stroke = Color3.fromRGB(38, 42, 66), Text = Color3.fromRGB(230, 234, 248),
        Sub = Color3.fromRGB(128, 136, 168), Accent = Color3.fromRGB(105, 135, 255), Accent2 = Color3.fromRGB(170, 115, 255),
    },
    Sakura = {
        Bg = Color3.fromRGB(22, 14, 20), Surface = Color3.fromRGB(34, 22, 30), Elevated = Color3.fromRGB(46, 30, 40),
        Card = Color3.fromRGB(40, 25, 35), Stroke = Color3.fromRGB(80, 52, 72), Text = Color3.fromRGB(253, 240, 246),
        Sub = Color3.fromRGB(180, 148, 170), Accent = Color3.fromRGB(255, 130, 175), Accent2 = Color3.fromRGB(255, 180, 205),
    },
    Ocean = {
        Bg = Color3.fromRGB(8, 15, 27), Surface = Color3.fromRGB(16, 28, 45), Elevated = Color3.fromRGB(24, 40, 62),
        Card = Color3.fromRGB(20, 34, 52), Stroke = Color3.fromRGB(40, 66, 98), Text = Color3.fromRGB(226, 240, 250),
        Sub = Color3.fromRGB(130, 158, 186), Accent = Color3.fromRGB(54, 195, 230), Accent2 = Color3.fromRGB(70, 125, 250),
    },
    Sunset = {
        Bg = Color3.fromRGB(19, 12, 14), Surface = Color3.fromRGB(34, 20, 24), Elevated = Color3.fromRGB(48, 30, 34),
        Card = Color3.fromRGB(42, 24, 28), Stroke = Color3.fromRGB(78, 48, 52), Text = Color3.fromRGB(250, 240, 236),
        Sub = Color3.fromRGB(178, 148, 145), Accent = Color3.fromRGB(255, 125, 75), Accent2 = Color3.fromRGB(255, 200, 80),
    },
    Amoled = {
        Bg = Color3.fromRGB(0, 0, 0), Surface = Color3.fromRGB(11, 11, 13), Elevated = Color3.fromRGB(20, 20, 24),
        Card = Color3.fromRGB(14, 14, 17), Stroke = Color3.fromRGB(36, 36, 44), Text = Color3.fromRGB(245, 245, 248),
        Sub = Color3.fromRGB(138, 138, 150), Accent = Color3.fromRGB(105, 195, 255), Accent2 = Color3.fromRGB(165, 135, 255),
    },
}
local ThemeOrder = {"Glass", "Nihon", "Midnight", "Sakura", "Ocean", "Sunset", "Amoled"}
local Pal, themeName = {}, "Glass"

local function loadPalette(name)
    local base = Themes.Glass; local src = Themes[name] or base
    for k, v in pairs(base) do Pal[k] = src[k] or v end
end
loadPalette("Glass")

local Status = {
    Info=Color3.fromRGB(96,156,255), Success=Color3.fromRGB(78,214,140),
    Warning=Color3.fromRGB(255,192,72), Error=Color3.fromRGB(255,90,102),
}
local Glyphs = {
    ["info"]="i",["check-circle"]="+",["check"]="+",["alert-triangle"]="!",["alert-circle"]="!",
    ["x-circle"]="x",["x"]="x",["minus"]="-",["chevron-down"]="v",["chevron-up"]="^",
    ["chevron-right"]=">",["search"]="o",["menu"]="=",["activity"]="~",["lock"]="#",
}
local Fonts = {
    Modern  = {Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold},
    Rounded = {Enum.Font.Nunito, Enum.Font.Nunito, Enum.Font.FredokaOne},
    Mono    = {Enum.Font.RobotoMono, Enum.Font.RobotoMono, Enum.Font.RobotoMono},
    Classic = {Enum.Font.SourceSans, Enum.Font.SourceSansSemibold, Enum.Font.SourceSansBold},
    Clean   = {Enum.Font.Ubuntu, Enum.Font.Ubuntu, Enum.Font.Ubuntu},
}
local FontOrder = {"Modern", "Rounded", "Mono", "Classic", "Clean"}
local currentFont, animSpeed, currentScale = "Modern", 1, 1

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

local binds, fontObjs, themeHooks = setmetatable({},{__mode="k"}), setmetatable({},{__mode="k"}), {}
local tweens = setmetatable({},{__mode="k"})

local function play(obj, dur, props, style, dir)
    local names = {}; for k in pairs(props) do names[#names+1]=k end
    table.sort(names)
    local key = table.concat(names, ",")
    local slot = tweens[obj]; if not slot then slot={}; tweens[obj]=slot end
    if slot[key] then slot[key]:Cancel() end
    local info = TweenInfo.new(math.max(dur/animSpeed,0.001), style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props); slot[key]=tw; tw:Play(); return tw
end

local function after(tw, fn)
    local c; c = tw.Completed:Connect(function(s) c:Disconnect(); if s==Enum.PlaybackState.Completed then fn() end end)
end

local function mk(class, props, kids)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
    if class == "TextButton" then inst.Text=""; inst.AutoButtonColor=false
    elseif class == "TextLabel" then inst.Text="" end
    local parent
    if props then for k,v in pairs(props) do if k=="Parent" then parent=v else inst[k]=v end end end
    if kids then for _,c in ipairs(kids) do c.Parent=inst end end
    if parent then inst.Parent=parent end
    return inst
end

local function bind(obj, prop, key, fn)
    local list = binds[obj]; if not list then list={}; binds[obj]=list end
    list[#list+1] = {prop=prop, key=key, fn=fn}
    local v = Pal[key]; if fn then v = fn(v, Pal) end
    obj[prop] = v; return obj
end

local function refreshTheme(animated, accentOnly)
    for obj, list in pairs(binds) do
        for _, rec in ipairs(list) do
            if not accentOnly or rec.key=="Accent" or rec.key=="Accent2" then
                local v = Pal[rec.key]; if rec.fn then v = rec.fn(v, Pal) end
                if animated and typeof(v)=="Color3" and obj.Parent then play(obj,0.35,{[rec.prop]=v})
                else obj[rec.prop]=v end
            end
        end
    end
    for _, hook in ipairs(themeHooks) do pcall(hook, animated) end
end

local function round(parent, r) return mk("UICorner", {CornerRadius=UDim.new(0,r), Parent=parent}) end
local function outline(parent, key, thick, trans)
    local s = mk("UIStroke", {Thickness=thick or 1, Transparency=trans or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=parent})
    bind(s, "Color", key or "Stroke"); return s
end
local function inset(parent, t, r, b, l)
    return mk("UIPadding", {PaddingTop=UDim.new(0,t or 0), PaddingRight=UDim.new(0,r or 0), PaddingBottom=UDim.new(0,b or 0), PaddingLeft=UDim.new(0,l or 0), Parent=parent})
end
local function stack(parent, gap, dir)
    return mk("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,gap or 0), FillDirection=dir or Enum.FillDirection.Vertical, Parent=parent})
end
local function accentGradient(parent, rot)
    local g = mk("UIGradient", {Rotation=rot or 0, Parent=parent})
    bind(g, "Color", "Accent", function(_, p) return ColorSequence.new(p.Accent, p.Accent2) end)
    return g
end

local function tx(class, props, weight, tone)
    local o = Instance.new(class)
    o.BackgroundTransparency=1; o.BorderSizePixel=0
    o.Font = Fonts[currentFont][weight or 2]; o.TextSize=13
    o.TextXAlignment = Enum.TextXAlignment.Left; o.Text=""
    if class=="TextButton" then o.AutoButtonColor=false
    elseif class=="TextBox" then o.ClearTextOnFocus=false; bind(o,"PlaceholderColor3","Sub") end
    local parent
    if props then for k,v in pairs(props) do if k=="Parent" then parent=v else o[k]=v end end end
    bind(o, "TextColor3", tone or "Text"); fontObjs[o] = weight or 2
    if parent then o.Parent=parent end
    return o
end

local function setFont(name)
    if not Fonts[name] then return end
    currentFont = name
    for obj, w in pairs(fontObjs) do obj.Font = Fonts[name][w] end
end
local function setTheme(name, animated)
    if not Themes[name] then return end
    themeName = name; loadPalette(name); refreshTheme(animated)
end
local function setAccent(c1, c2)
    Pal.Accent = c1; Pal.Accent2 = c2 or c1:Lerp(Color3.new(1,1,1), 0.25)
    refreshTheme(true, true)
end

local IconMap = {}
pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")
    IconMap = HttpService:JSONDecode(raw).icons or {}
end)
local function resolveIcon(name)
    if name == nil then return nil end
    local s = tostring(name); if s=="" then return nil end
    if IconMap[s] then return IconMap[s] end
    if s:find("^rbxassetid://") or s:find("^rbxasset://") or s:find("^rbxthumb://") then return s end
    if tonumber(s) then return "rbxassetid://"..s end
    return nil
end
local function makeIcon(parent, name, size, tone, props)
    local holder = mk("Frame", {BackgroundTransparency=1, Size=UDim2.fromOffset(size, size)})
    if props then for k,v in pairs(props) do holder[k]=v end end
    holder.Parent = parent
    local img = mk("ImageLabel", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ScaleType=Enum.ScaleType.Fit, Parent=holder})
    local glyph = tx("TextLabel", {Size=UDim2.fromScale(1,1), TextSize=math.floor(size*0.95), TextXAlignment=Enum.TextXAlignment.Center, Visible=false, Parent=holder}, 3, (tone or "Text"))
    if tone ~= false then bind(img, "ImageColor3", tone or "Text") end
    local api = {Holder=holder, Image=img, Glyph=glyph}
    function api.Set(n)
        local id = resolveIcon(n)
        if id then img.Image=id; img.Visible=true; glyph.Visible=false
        else img.Visible=false; glyph.Visible=true
            local key = tostring(n or ""); glyph.Text = Glyphs[key] or key:sub(1,1):upper()
        end
    end
    function api.Color(c, animated)
        if animated then play(img,0.2,{ImageColor3=c}); play(glyph,0.2,{TextColor3=c})
        else img.ImageColor3=c; glyph.TextColor3=c end
    end
    api.Set(name); return api
end

local function isPointer(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
local function samePointer(a,b) if a.UserInputType==Enum.UserInputType.Touch then return a==b end; return b.UserInputType==a.UserInputType end
local function v2(i) return Vector2.new(i.Position.X, i.Position.Y) end

local function trackPointer(gui, onDown, onMove, onUp)
    return gui.InputBegan:Connect(function(input)
        if not isPointer(input) then return end
        if onDown and onDown(input)==false then return end
        local mover, ender
        mover = UserInputService.InputChanged:Connect(function(moved)
            local mouseMove = input.UserInputType==Enum.UserInputType.MouseButton1 and moved.UserInputType==Enum.UserInputType.MouseMovement
            if mouseMove or moved==input then if onMove then onMove(v2(moved), moved) end end
        end)
        ender = UserInputService.InputEnded:Connect(function(done)
            if isPointer(done) and samePointer(input, done) then
                mover:Disconnect(); ender:Disconnect()
                if onUp then onUp(v2(done)) end
            end
        end)
    end)
end

-- FIXED drag: no teleport, tracks start position once.
local function makeDraggable(handles, target, opts)
    opts = opts or {}
    for _, h in ipairs(handles) do
        local dragging, moved = false, false
        local startInput, startPos, goal, current
        local beat
        local function apply() target.Position = UDim2.fromOffset(current.X, current.Y) end
        local function step(dt)
            local a = 1 - math.exp(-dt * (opts.speed or 22))
            current = current:Lerp(goal, a)
            apply()
            if not dragging and (goal-current).Magnitude < 0.35 then
                current = goal; apply()
                if beat then beat:Disconnect(); beat = nil end
            end
        end
        trackPointer(h, function(input)
            if opts.canDrag and not opts.canDrag() then return false end
            dragging, moved = true, false
            startInput = v2(input)
            startPos = Vector2.new(target.AbsolutePosition.X, target.AbsolutePosition.Y)
            goal, current = startPos, startPos
            if opts.onBegin then opts.onBegin() end
            if beat then beat:Disconnect() end
            beat = RunService.RenderStepped:Connect(step)
        end, function(pos)
            if not dragging then return end
            local d = pos - startInput
            if not moved and d.Magnitude < 3 then return end
            moved = true
            local want = startPos + d
            goal = opts.clamp and opts.clamp(want) or want
        end, function()
            if not dragging then return end
            dragging = false
            if not moved and opts.onClick then opts.onClick() end
            if opts.onEnd then opts.onEnd(moved) end
            task.delay(0.1, function() if beat then beat:Disconnect(); beat = nil end end)
        end)
    end
end

local function makeFirer(getValue, run)
    local last, busy, api = {}, false, {}
    function api.Fire()
        if busy then return end
        busy = true
        task.spawn(function()
            while true do local v = getValue(); if v==last then break end; last=v; pcall(run, v) end
            busy = false
        end)
    end
    function api.Sync(v) last = v end
    return api
end

local function onAccent()
    local c = Pal.Accent
    if (c.R*0.299+c.G*0.587+c.B*0.114) > 0.62 then return Color3.fromRGB(16,16,22) end
    return Color3.new(1,1,1)
end

local Metrics = {fps=60, ping=0, mem=0}
do
    local frames, clock, sample = 0, 0, 0
    keep(RunService.RenderStepped:Connect(function(dt)
        frames=frames+1; clock=clock+dt; sample=sample+dt
        if clock>=0.5 then Metrics.fps = math.floor(frames/clock+0.5); frames,clock=0,0 end
        if sample>=1 then
            sample=0
            local ok,v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if ok and v then Metrics.ping = math.floor(v+0.5) end
            local okm,m = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
            if okm and m then Metrics.mem = math.floor(m+0.5) end
        end
    end))
end

------------------------------------------------------------------------
-- NOTIFICATIONS (glassy)
------------------------------------------------------------------------
local Notes = {active={}, queue={}, byKey={}, queuedKey={}, max=5, duration=4, position="TopRight"}
local noteLayer = mk("Frame", {Name="Notifications", BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=100, Parent=Root})
local corners = {
    TopRight={ax=1,ay=0}, TopLeft={ax=0,ay=0}, TopCenter={ax=0.5,ay=0},
    BottomRight={ax=1,ay=1}, BottomLeft={ax=0,ay=1}, BottomCenter={ax=0.5,ay=1},
}
local noteLoop, spawnNote
local function noteWidth() return math.clamp(math.floor(viewport().X-28), 210, 320) end
local function notePos(slot, dx)
    local c = corners[Notes.position] or corners.TopRight
    local mx = c.ax==0.5 and 0 or (c.ax==1 and -14 or 14)
    local my = c.ay==0 and (14+slot) or -(14+slot)
    return UDim2.new(c.ax, mx+(dx or 0), c.ay, my)
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
        local entry = table.remove(Notes.queue, 1); Notes.queuedKey[entry.key] = nil; spawnNote(entry)
    end
end
local function dismissNote(n)
    if n.dying then return end
    n.dying = true
    for i, x in ipairs(Notes.active) do if x==n then table.remove(Notes.active, i); break end end
    if Notes.byKey[n.key] == n then Notes.byKey[n.key] = nil end
    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax==1 and (noteWidth()+40) or (c.ax==0 and -(noteWidth()+40) or 0)
    play(n.frame, 0.35, {GroupTransparency=1})
    if out ~= 0 then play(n.frame, 0.4, {Position = notePos(n.slot, out)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    else play(n.frame, 0.35, {Position = notePos(n.slot-40)}) end
    task.delay(0.5, function() if n.frame then n.frame:Destroy() end end)
    relayout(); promoteQueue()
end
local function bumpNote(n, extra)
    n.count = n.count + 1; n.badge.Text = n.count .. "x"; n.badge.Visible = true
    n.expires = os.clock() + (extra or n.time)
    n.pop.Scale = 1.45; play(n.pop, 0.45, {Scale=1}, Enum.EasingStyle.Back)
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
                if not n.custom then n.bar.Size = UDim2.new(math.clamp(left/n.time, 0, 1), 0, 0, 2) end
                if left <= 0 then dismissNote(n) end
            end
        end
        if #Notes.active == 0 and noteLoop then noteLoop:Disconnect(); noteLoop = nil end
    end)
end
function spawnNote(entry)
    local cfg, handle = entry.cfg, entry.handle
    local color = Status[entry.kind]
    local w = noteWidth()
    local n = {key=entry.key, count=entry.count, handle=handle, height=64, slot=0,
        time=math.max(1, tonumber(cfg.Time) or Notes.duration), sticky=cfg.Sticky==true}
    n.expires = os.clock() + n.time
    local content = tostring(cfg.Content or "")

    -- Glassy notification: transparency 0.12 + backdrop blur feel
    local frame = mk("CanvasGroup", {Name="Note", Size=UDim2.fromOffset(w, 0), AutomaticSize=Enum.AutomaticSize.Y, GroupTransparency=1, BackgroundTransparency=0.15, Parent=noteLayer})
    bind(frame, "BackgroundColor3", "Surface")
    round(frame, 14); outline(frame, "Stroke", 1, 0.5)
    mk("UISizeConstraint", {MinSize=Vector2.new(0, 60), Parent=frame})

    mk("Frame", {Size=UDim2.new(0,3,1,0), BackgroundColor3=color, BackgroundTransparency=0.1, ZIndex=3, Parent=frame})

    local disc = mk("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-14,0.5,0), Size=UDim2.fromOffset(34,34), BackgroundColor3=color, BackgroundTransparency=0.82, ZIndex=3, Parent=frame})
    round(disc, 17); outline(disc, "Text", 1, 0.9)
    local ico = makeIcon(disc, cfg.Icon or (entry.kind=="Success" and "check" or entry.kind=="Error" and "x" or "info"), 17, false,
        {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=4})
    ico.Color(color)

    local col = mk("Frame", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=2, Parent=frame})
    inset(col, 12, 62, 14, 16); stack(col, 3)
    n.title = tx("TextLabel", {Text=tostring(cfg.Name or cfg.Title or "Notification"), Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true, LayoutOrder=1, ZIndex=3, Parent=col}, 3)
    n.body = tx("TextLabel", {Text=content, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true, TextSize=12, LayoutOrder=2, Visible=content~="", ZIndex=3, Parent=col}, 1, "Sub")

    local est = TextService:GetTextSize(content, 12, Fonts[currentFont][1], Vector2.new(w-76, 1000))
    n.height = math.max(60, 40+est.Y+14)

    n.badge = tx("TextLabel", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-4,0,-2), Size=UDim2.fromOffset(0,18), ZIndex=6, AutomaticSize=Enum.AutomaticSize.X, Text=n.count.."x", TextSize=11, TextXAlignment=Enum.TextXAlignment.Center, BackgroundTransparency=0.78, BackgroundColor3=color, TextColor3=color, Visible=n.count>1, Parent=frame}, 3)
    round(n.badge, 10); inset(n.badge, 0, 8, 0, 8)
    n.pop = mk("UIScale", {Parent=n.badge})

    n.bar = mk("Frame", {AnchorPoint=Vector2.new(0,1), Position=UDim2.fromScale(0,1), Size=UDim2.new(1,0,0,2), BackgroundColor3=color, BackgroundTransparency=0.25, Visible=not n.sticky, ZIndex=5, Parent=frame})

    n.frame = frame
    frame.MouseEnter:Connect(function() n.hover=true end)
    frame.MouseLeave:Connect(function() n.hover=false end)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local h = frame.AbsoluteSize.Y
        if h > 4 and math.abs(h-n.height) > 0.5 then n.height = h; if not n.dying then task.defer(relayout) end end
    end)

    local startX, swiped = 0, false
    trackPointer(frame, function(input) startX=input.Position.X; swiped=false; n.dragging=true end,
        function(pos)
            local dx = pos.X - startX
            if math.abs(dx) > 6 then swiped = true end
            if swiped then n.frame.Position = notePos(n.slot, dx) end
        end, function(pos)
            n.dragging = false
            local dx = pos.X - startX
            if math.abs(dx) > 70 or (not swiped and cfg.ClickDismiss ~= false) then dismissNote(n) else relayout() end
        end)

    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax==1 and (w+40) or (c.ax==0 and -(w+40) or 0)
    frame.AnchorPoint = Vector2.new(c.ax, c.ay)
    frame.Position = out ~= 0 and notePos(0, out) or notePos(-50, 0)

    table.insert(Notes.active, 1, n)
    if entry.dedupe then Notes.byKey[n.key] = n end
    handle.n = n
    relayout()
    play(frame, 0.4, {GroupTransparency=0})
    task.defer(function() if not n.dying and frame.Parent then frame.GroupTransparency=0; relayout() end end)
    ensureNoteLoop()
    return n
end

function Nihon:MakeNotification(cfg)
    if type(cfg) ~= "table" then cfg = {Content=tostring(cfg)} end
    local kind = Status[cfg.Type] and cfg.Type or "Info"
    local name = tostring(cfg.Name or cfg.Title or "Notification")
    local content = tostring(cfg.Content or "")
    local key = kind.."|"..name.."|"..content
    local dedupe = not cfg.Sticky
    if dedupe then
        local live = Notes.byKey[key]
        if live and not live.dying then bumpNote(live, tonumber(cfg.Time)); return live.handle end
        local waiting = Notes.queuedKey[key]
        if waiting then waiting.count = waiting.count + 1; return waiting.handle end
    end
    local handle = {}
    function handle:Dismiss() if handle.n then dismissNote(handle.n) end end
    function handle:SetTitle(t) if handle.n then handle.n.title.Text = tostring(t) end end
    function handle:SetContent(t) if handle.n then handle.n.body.Text = tostring(t); handle.n.body.Visible = tostring(t)~="" end end
    local entry = {cfg=cfg, kind=kind, key=key, count=1, handle=handle, dedupe=dedupe}
    if #Notes.active >= Notes.max then Notes.queue[#Notes.queue+1] = entry; if dedupe then Notes.queuedKey[key] = entry end
    else spawnNote(entry) end
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
    Notes.queue = {}; Notes.queuedKey = {}
    for i = #Notes.active, 1, -1 do dismissNote(Notes.active[i]) end
end

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local flagRefs, flagOrder, initFires = {}, {}, {}
local saveToken = 0
local function encode(v)
    local t = typeof(v)
    if t=="Color3" then return {t="c", r=v.R, g=v.G, b=v.B}
    elseif t=="EnumItem" then return {t="k", n=v.Name}
    elseif t=="table" then local l={}; for i,x in ipairs(v) do l[i]=x end; return {t="l", v=l}
    elseif v==nil then return {t="k"} end
    return v
end
local function decode(v)
    if type(v)~="table" then return v end
    if v.t=="c" then return Color3.new(v.r,v.g,v.b)
    elseif v.t=="k" then return v.n and Enum.KeyCode[v.n] or nil
    elseif v.t=="l" then return v.v end
    return v
end
local function fsReady() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function" and type(isfolder)=="function" end
local function cfgPath(name) return Nihon.Folder.."/"..name..".json" end
local function ensureFolder() if not isfolder(Nihon.Folder) then makefolder(Nihon.Folder) end end
local function snapshot()
    local data = {}
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]; if ref.save then data[flag] = encode(ref.get()) end
    end
    return data
end
function Nihon:SaveProfile(name)
    name = name or Nihon.Profile; if not fsReady() then return false end
    return pcall(function() ensureFolder(); writefile(cfgPath(name), HttpService:JSONEncode(snapshot())) end)
end
function Nihon:LoadProfile(name)
    name = name or Nihon.Profile; if not fsReady() then return false end
    local ok, data = pcall(function()
        if not isfile(cfgPath(name)) then return nil end
        return HttpService:JSONDecode(readfile(cfgPath(name)))
    end)
    if not ok or type(data)~="table" then return false end
    Nihon.Profile = name
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]
        if ref.save and data[flag]~=nil then pcall(ref.set, decode(data[flag])) end
    end
    return true
end
function Nihon:ListProfiles()
    local out = {}
    if not fsReady() or not listfiles then return out end
    pcall(function()
        ensureFolder()
        for _, p in ipairs(listfiles(Nihon.Folder)) do
            local n = p:match("([^/\\]+)%.json$")
            if n and n:sub(1,1)~="_" then out[#out+1]=n end
        end
    end)
    table.sort(out); return out
end
function Nihon:ExportConfig() return HttpService:JSONEncode(snapshot()) end
function Nihon:ImportConfig(str)
    local ok, data = pcall(function() return HttpService:JSONDecode(str) end)
    if not ok or type(data)~="table" then return false end
    for _, flag in ipairs(flagOrder) do
        local ref = flagRefs[flag]
        if ref.save and data[flag]~=nil then pcall(ref.set, decode(data[flag])) end
    end
    return true
end
local function queueSave()
    if not Nihon.SaveConfig or not Nihon._ready then return end
    saveToken = saveToken+1; local mine = saveToken
    task.delay(0.8, function() if mine==saveToken then Nihon:SaveProfile() end end)
end

------------------------------------------------------------------------
-- STATS
------------------------------------------------------------------------
local Stat = {}
function Stat.avatar(cb)
    task.spawn(function()
        local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
        if ok and img then cb(img) end
    end)
end

Nihon.Started = os.clock()
local Hooks = {}

local Sizes = {
    desktop = {w=760, h=520, side=76, top=68},
    mobile  = {w=560, h=380, side=64, top=60},
}

------------------------------------------------------------------------
-- LIBRARY INFO TAB (replaces the showcase popup)
------------------------------------------------------------------------
local function buildLibraryInfoTab(Window)
    local tab = Window:MakeTab({Name="Library Info", Icon="sparkles"})

    local about = tab:AddSection({Name="About"})
    about:AddParagraph({
        Title = "Nihon Lib v" .. Nihon.Version,
        Content = "A modern, glassy UI library built for Roblox scripts. Fully backward compatible with the v3 API.",
    })

    local feat = tab:AddSection({Name="Features"})
    local features = {
        {name="Dashboard UI", desc="Modern card-based interface", icon="zap"},
        {name="Tab System", desc="Smooth tab switching animations", icon="layers"},
        {name="Search (Ctrl+K)", desc="Fast feature search", icon="search"},
        {name="Config Management", desc="Save / load profiles", icon="save"},
        {name="Theme Engine", desc="7 themes + custom accent", icon="palette"},
        {name="Notifications", desc="Glassy toasts", icon="bell"},
        {name="Keybind System", desc="Custom shortcuts", icon="keyboard"},
        {name="HUD Overlay", desc="Real-time stats widget", icon="activity"},
    }
    for _, f in ipairs(features) do
        local holder = tab:AddParagraph({Title = f.name, Content = f.desc})
        holder:SetTitle(f.name)
    end

    local credits = tab:AddSection({Name="Credits"})
    credits:AddLabel({Name="Made by Nihon"})
    credits:AddLabel({Name="Press Ctrl+K to search features."})
end

------------------------------------------------------------------------
-- MAIN WINDOW
------------------------------------------------------------------------
function Nihon:MakeWindow(cfg)
    cfg = cfg or {}
    local title = tostring(cfg.Name or "Nihon Lib")
    local subtitle = cfg.Subtitle ~= nil and tostring(cfg.Subtitle) or ("v"..Nihon.Version)
    local mobile = Nihon.IsMobile
    local size = mobile and Sizes.mobile or Sizes.desktop
    local baseW = tonumber(cfg.Width) or size.w
    local baseH = tonumber(cfg.Height) or size.h
    local sideW, topH = size.side, size.top

    Nihon.Folder = tostring(cfg.ConfigFolder or Nihon.Folder)
    Nihon.SaveConfig = cfg.SaveConfig == true
    Nihon.ShowLauncher = cfg.ShowLauncher ~= false
    Nihon.ShowResize = cfg.ShowResize ~= false
    Nihon.ShowSearch = cfg.ShowSearch ~= false
    Nihon.ShowHelp = cfg.ShowHelp ~= false
    Nihon.ShowMinimize = cfg.ShowMinimize ~= false
    Nihon.ShowClose = cfg.ShowClose ~= false

    if cfg.Theme and Themes[cfg.Theme] then setTheme(cfg.Theme, false) end
    if cfg.Font and Fonts[cfg.Font] then setFont(cfg.Font) end
    if cfg.Accent then setAccent(cfg.Accent, cfg.Accent2) end

    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    local Window = {Tabs={}, Name=title, Hidden=false, Minimized=false, Selected=nil, Scale=1, ToggleKey=toggleKey, Cfg=cfg}
    Nihon.Windows[#Nihon.Windows+1] = Window

    local searchIndex = {}

    -- Outer shell: transparent glass
    local shell = mk("Frame", {
        Name="Window", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(baseW, baseH), ClipsDescendants=false, Visible=false, ZIndex=10,
        BackgroundTransparency=0.15, Parent=Root,
    })
    bind(shell, "BackgroundColor3", "Bg")
    round(shell, 20); outline(shell, "Stroke", 1, 0.55)
    local uiScale = mk("UIScale", {Scale=0.9, Parent=shell})
    Window.Shell = shell

    local clip = mk("Frame", {Name="Clip", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ClipsDescendants=true, ZIndex=10, Parent=shell})
    round(clip, 20)

    local fullH = baseH
    local closeToken = 0

    -- Ambient glow
    local glow = mk("Frame", {Size=UDim2.new(1,0,0,140), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=0.85, ZIndex=10, Parent=clip})
    local glowGrad = accentGradient(glow, 90)
    glowGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1)})
    keep(RunService.RenderStepped:Connect(function()
        if not Window.Hidden and glowGrad.Parent then
            glowGrad.Offset = Vector2.new(math.sin(os.clock() * 0.5) * 0.35, 0)
        end
    end))

    -- HEADER (glassy)
    local header = mk("Frame", {Name="Header", Size=UDim2.new(1,0,0,topH), BackgroundTransparency=0.4, ZIndex=12, Parent=clip})
    bind(header, "BackgroundColor3", "Surface")

    local logo = mk("Frame", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,16,0.5,0), Size=UDim2.fromOffset(38,38), BackgroundColor3=Color3.new(1,1,1), ZIndex=13, Parent=header})
    round(logo, 12); accentGradient(logo, 45)
    local logoIcon = makeIcon(logo, cfg.Icon or "zap", 20, false, {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=14})
    logoIcon.Color(Color3.new(1,1,1))
    Window.LogoIcon = logoIcon

    local titleLbl = tx("TextLabel", {Text=title, TextSize=16, Position=UDim2.new(0,66,0,subtitle~="" and 13 or 0), Size=UDim2.new(1,-280,0,subtitle~="" and 22 or topH), TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=13, Parent=header}, 3)
    local subLbl = tx("TextLabel", {Text=subtitle, TextSize=11, Position=UDim2.new(0,66,0,35), Size=UDim2.new(1,-280,0,14), TextTruncate=Enum.TextTruncate.AtEnd, Visible=subtitle~="", ZIndex=13, Parent=header}, 1, "Sub")
    Window.TitleLabel, Window.SubtitleLabel = titleLbl, subLbl

    -- User card (pill)
    local userCard = mk("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-130,0.5,0), Size=UDim2.fromOffset(mobile and 46 or 210, 42), BackgroundTransparency=0.35, ZIndex=13, Parent=header})
    bind(userCard, "BackgroundColor3", "Elevated")
    round(userCard, 21); outline(userCard, "Stroke", 1, 0.55)

    local avatar = mk("ImageLabel", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,5,0.5,0), Size=UDim2.fromOffset(32,32), ZIndex=14, Parent=userCard})
    bind(avatar, "BackgroundColor3", "Card")
    round(avatar, 16); outline(avatar, "Stroke", 1, 0.5)
    Stat.avatar(function(img) if avatar.Parent then avatar.Image = img end end)
    local dot = mk("Frame", {AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,1,1,1), Size=UDim2.fromOffset(9,9), BackgroundColor3=Status.Success, ZIndex=15, Parent=avatar})
    round(dot, 5); outline(dot, "Bg", 2, 0)

    if not mobile then
        tx("TextLabel", {Text="Hello, "..LocalPlayer.DisplayName, TextSize=13, Position=UDim2.new(0,46,0,6), Size=UDim2.new(1,-56,0,16), TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=14, Parent=userCard}, 3)
        tx("TextLabel", {Text="@"..LocalPlayer.Name, TextSize=10, Position=UDim2.new(0,46,0,23), Size=UDim2.new(1,-56,0,13), TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=14, Parent=userCard}, 1, "Sub")
    end

    -- Controls cluster
    local controls = mk("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-14,0.5,0), Size=UDim2.fromOffset(0,34), AutomaticSize=Enum.AutomaticSize.X, BackgroundTransparency=1, ZIndex=15, Parent=header})
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder, Parent=controls})

    local function ctrlButton(order, icon, hover)
        local btn = mk("TextButton", {Size=UDim2.fromOffset(32,32), BackgroundColor3=hover or Color3.new(1,1,1), BackgroundTransparency=1, LayoutOrder=order, ZIndex=15, Parent=controls})
        round(btn, 10)
        local ico = makeIcon(btn, icon, 16, "Sub", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=16})
        btn.MouseEnter:Connect(function() play(btn,0.15,{BackgroundTransparency=0.85}) end)
        btn.MouseLeave:Connect(function() play(btn,0.2,{BackgroundTransparency=1}) end)
        return btn, ico
    end

    local helpBtn   = ctrlButton(1, "help-circle")
    local searchBtn = ctrlButton(2, "search")
    local minBtn, minIco = ctrlButton(3, "minus")
    local closeBtn  = ctrlButton(4, "x", Status.Error)

    local headLine = mk("Frame", {AnchorPoint=Vector2.new(0,1), Position=UDim2.fromScale(0,1), Size=UDim2.new(1,0,0,1), BackgroundColor3=Color3.new(1,1,1), ZIndex=13, Parent=header})
    local lineGrad = accentGradient(headLine, 0)
    keep(RunService.RenderStepped:Connect(function()
        if not Window.Hidden and lineGrad.Parent then lineGrad.Offset = Vector2.new(math.sin(os.clock()*0.9)*0.45, 0) end
    end))

    -- BODY
    local body = mk("Frame", {Name="Body", Position=UDim2.fromOffset(0,topH), Size=UDim2.new(1,0,1,-topH), BackgroundTransparency=1, ZIndex=11, Parent=clip})

    local side = mk("Frame", {Name="Sidebar", AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,0,0,0), Size=UDim2.new(0,sideW,1,0), BackgroundTransparency=0.7, ZIndex=12, Parent=body})
    bind(side, "BackgroundColor3", "Surface")
    outline(side, "Stroke", 1, 0.75)

    local tabScroll = mk("ScrollingFrame", {Name="Tabs", Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, ScrollBarThickness=0, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ZIndex=13, Parent=side})
    inset(tabScroll, 12, 8, 12, 8); stack(tabScroll, 8)

    local pill = mk("Frame", {Name="Pill", Size=UDim2.new(1,-16,0,0), Position=UDim2.fromOffset(8,8), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=0.82, Visible=false, ZIndex=12, Parent=side})
    round(pill, 12); accentGradient(pill, 20)

    local content = mk("Frame", {Name="Content", Position=UDim2.fromOffset(sideW+10, 10), Size=UDim2.new(1,-(sideW+20), 1,-20), BackgroundTransparency=1, ClipsDescendants=true, ZIndex=12, Parent=body})
    Window.Content = content

    -- Watermark
    local watermark = tx("TextLabel", {Text="Powered by NihonLib", TextSize=10, AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-14,1,-10), Size=UDim2.fromOffset(200,14), TextXAlignment=Enum.TextXAlignment.Right, ZIndex=20, Parent=clip}, 1, "Sub")
    watermark.TextTransparency = 0.55

    -- Resize grip
    local resizeGrip = mk("TextButton", {Name="ResizeGrip", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-4,1,-4), Size=UDim2.fromOffset(mobile and 28 or 22, mobile and 28 or 22), BackgroundTransparency=1, ZIndex=30, Parent=clip})
    local resizeGlyph = makeIcon(resizeGrip, "chevron-right", 14, "Sub", {AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-2,1,-2), Rotation=45, ZIndex=31})
    resizeGlyph.Image.Rotation = 45; resizeGlyph.Glyph.Rotation = 45

    local resizing, resizeStart = false, nil
    trackPointer(resizeGrip, function(input)
        if Window.Hidden or Window.Minimized then return false end
        resizing = true; resizeStart = v2(input)
        play(resizeGlyph.Image, 0.12, {ImageColor3=Pal.Accent})
        play(resizeGlyph.Glyph, 0.12, {TextColor3=Pal.Accent})
    end, function(pos)
        if not resizing then return end
        local d = pos - resizeStart
        local sc = math.max(uiScale.Scale, 0.01)
        local newW = math.max(math.floor((baseW*sc)+d.X), math.floor(baseW*0.55*sc))
        local newH = math.max(math.floor((fullH*sc)+d.Y), math.floor((topH+120)*sc))
        shell.Size = UDim2.fromOffset(math.floor(newW/sc), math.floor(newH/sc))
    end, function()
        resizing = false
        play(resizeGlyph.Image, 0.2, {ImageColor3=Pal.Sub})
        play(resizeGlyph.Glyph, 0.2, {TextColor3=Pal.Sub})
    end)

    local function dragClamp(topLeft)
        local v = viewport(); local s = shell.AbsoluteSize
        return Vector2.new(math.clamp(topLeft.X, -s.X+90, v.X-90), math.clamp(topLeft.Y, 0, v.Y-math.min(topH*uiScale.Scale, s.Y)-4))
    end
    local function reanchor()
        if shell.AnchorPoint == Vector2.new(0,0) then return end
        local p = shell.AbsolutePosition
        shell.AnchorPoint = Vector2.new(0,0)
        shell.Position = UDim2.fromOffset(p.X, p.Y)
    end
    local function centerTopLeft()
        local v = viewport()
        local s = Vector2.new(baseW, shell.Size.Y.Offset) * uiScale.Scale
        shell.AnchorPoint = Vector2.new(0,0)
        shell.Position = UDim2.fromOffset(math.floor((v.X-s.X)/2), math.floor((v.Y-s.Y)/2))
    end

    makeDraggable({header}, shell, {
        speed = 26,
        clamp = dragClamp,
        onBegin = function() reanchor() end,
        canDrag = function() return not Window.Hidden end,
    })

    local function fitScale()
        local v = viewport()
        local fit = math.min((v.X-20)/baseW, (v.Y-20)/baseH, 1)
        return math.max(fit, 0.5) * Window.Scale
    end
    local activeScale = 1
    local function applyScale(animated)
        activeScale = fitScale(); currentScale = activeScale
        if animated then play(uiScale, 0.3, {Scale=activeScale}) else uiScale.Scale = activeScale end
    end

    local cam = workspace.CurrentCamera
    if cam then
        keep(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() if not Window.Hidden then applyScale(true) end end))
    end

    -- Launcher
    local launcher = mk("TextButton", {Name="Launcher", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,34,0.5,0), Size=UDim2.fromOffset(mobile and 50 or 46, mobile and 50 or 46), BackgroundColor3=Color3.new(1,1,1), Visible=false, ZIndex=250, Parent=Root})
    round(launcher, 23); accentGradient(launcher, 45); outline(launcher, "Text", 1.5, 0.75)
    local launcherIcon = makeIcon(launcher, cfg.Icon or "zap", 22, false, {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=251})
    launcherIcon.Color(Color3.new(1,1,1))
    local launcherScale = mk("UIScale", {Scale=0, Parent=launcher})
    Window.LauncherIcon = launcherIcon

    local launcherMoved = false
    makeDraggable({launcher}, launcher, {
        speed = 32,
        clamp = function(p)
            local v = viewport(); local s = launcher.AbsoluteSize
            return Vector2.new(math.clamp(p.X, 0, v.X-s.X), math.clamp(p.Y, 0, v.Y-s.Y))
        end,
        onBegin = function() launcher.AnchorPoint = Vector2.new(0,0); play(launcherScale, 0.12, {Scale=0.92}) end,
        onEnd = function(moved) launcherMoved = moved; play(launcherScale, 0.3, {Scale=1}, Enum.EasingStyle.Back) end,
    })

    local function showLauncher(on)
        if on then launcher.Visible = true; play(launcherScale, 0.45, {Scale=1}, Enum.EasingStyle.Back)
        else
            local tw = play(launcherScale, 0.2, {Scale=0}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            after(tw, function() launcher.Visible = false end)
        end
    end

    local placed = false
    local function show()
        Window.Hidden = false
        applyScale(false)
        if not placed then placed = true; uiScale.Scale = activeScale; centerTopLeft() end
        closeToken = closeToken+1
        body.Visible = not Window.Minimized
        local targetW = shell.Size.X.Offset > topH+10 and shell.Size.X.Offset or baseW
        shell.Size = UDim2.fromOffset(targetW, Window.Minimized and (topH+4) or fullH)
        shell.Visible = true
        uiScale.Scale = activeScale*0.9
        play(uiScale, 0.5, {Scale=activeScale}, Enum.EasingStyle.Back)
        if Nihon.ShowLauncher then showLauncher(false) end
    end

    local function hide()
        Window.Hidden = true
        closeToken = closeToken+1
        local mine = closeToken
        local tw = play(uiScale, 0.22, {Scale=activeScale*0.9}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        after(tw, function() if Window.Hidden and mine==closeToken then shell.Visible = false end end)
        if Nihon.ShowLauncher then
            task.delay(0.18, function() if mine==closeToken and Window.Hidden then showLauncher(true) end end)
        end
    end

    Window.Show, Window.Hide = show, hide
    function Window:Toggle() if Window.Hidden then show() else hide() end end

    launcher.Activated:Connect(function() if launcherMoved then launcherMoved=false; return end; show() end)

    closeBtn.Activated:Connect(function()
        hide()
        Nihon:MakeNotification({Name="Menu hidden", Content="Press "..Window.ToggleKey.Name.." to reopen.", Type="Info", Time=3})
    end)

    keep(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Window.ToggleKey then Window:Toggle() end
    end))

    -- FIXED minimize toggle: state is now correctly propagated
    minBtn.Activated:Connect(function()
        local toggled = not Window.Minimized
        Window.Minimized = toggled
        play(minIco.Image, 0.25, {Rotation = toggled and 180 or 0})
        play(minIco.Glyph, 0.25, {Rotation = toggled and 180 or 0})
        body.Visible = not toggled
        play(shell, 0.4, {
            Size = UDim2.fromOffset(shell.Size.X.Offset, toggled and (topH+4) or fullH)
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    end)

    Window.RequestOpen = function() if Window.Hidden then show() end end

    Window._parts = {
        shell=shell, clip=clip, header=header, body=body, side=side, tabScroll=tabScroll, pill=pill,
        content=content, searchBtn=searchBtn, helpBtn=helpBtn, uiScale=uiScale, applyScale=applyScale,
        topH=topH, sideW=sideW, mobile=mobile, searchIndex=searchIndex,
        avatar=avatar, dot=dot, baseW=baseW, baseH=baseH,
        launcher=launcher, fullH=function() return fullH end,
        closeBtn=closeBtn, minBtn=minBtn, minIco=minIco, resizeGrip=resizeGrip,
    }

    if not Nihon.ShowLauncher then launcher.Visible = false end
    if not Nihon.ShowResize then resizeGrip.Visible = false end
    if not Nihon.ShowSearch then searchBtn.Visible = false end
    if not Nihon.ShowHelp then helpBtn.Visible = false end
    if not Nihon.ShowMinimize then minBtn.Visible = false end
    if not Nihon.ShowClose then closeBtn.Visible = false end

    Hooks.attach(Window)
    return Window
end

------------------------------------------------------------------------
-- FLAGS & helpers
------------------------------------------------------------------------
local function registerFlag(flag, ref)
    if not flag then return end
    if not flagRefs[flag] then flagOrder[#flagOrder+1] = flag end
    flagRefs[flag] = ref
end
local function errorText(err)
    local s = tostring(err or "unknown error")
    s = s:gsub("^[%w_%.%-%/:]+:%d+:%s*", ""); if #s>90 then s=s:sub(1,87).."..." end; return s
end
local function flashCard(card, color, seconds)
    local sheet = mk("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=color, BackgroundTransparency=0.55, ZIndex=44, Parent=card})
    round(sheet, 11)
    local stroke = card:FindFirstChildOfClass("UIStroke")
    local oldTrans = stroke and stroke.Transparency
    if stroke then stroke.Color = color; stroke.Transparency = 0 end
    local tw = play(sheet, seconds or 0.9, {BackgroundTransparency=1}, Enum.EasingStyle.Quint)
    after(tw, function() sheet:Destroy() end)
    task.delay(seconds or 0.9, function()
        if stroke and stroke.Parent then play(stroke, 0.3, {Color=Pal.Stroke, Transparency=oldTrans}) end
        if sheet.Parent then sheet:Destroy() end
    end)
end
local function shake(card)
    local base = card.Position
    task.spawn(function()
        for _, dx in ipairs({6,-6,4,-4,2,0}) do
            if not card.Parent then return end
            card.Position = base + UDim2.fromOffset(dx, 0); task.wait(0.03)
        end
        card.Position = base
    end)
end

------------------------------------------------------------------------
-- TABS
------------------------------------------------------------------------
local ElementFactory, TabImpl = nil, {}

function TabImpl.make(Window, tcfg)
    local P = Window._parts; local mobile = P.mobile
    tcfg = tcfg or {}
    local name = tostring(tcfg.Name or "Tab")
    local Tab = {Name=name, Sections={}, Window=Window}
    local index = #Window.Tabs+1; Tab.Index = index

    local btn = mk("TextButton", {Name="Tab_"..name, Size=UDim2.new(1,0,0,mobile and 44 or 42), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=1, LayoutOrder=index, ZIndex=14, Parent=P.tabScroll})
    round(btn, 12); Tab.Button = btn

    local ico = makeIcon(btn, tcfg.Icon or name, mobile and 22 or 20, "Sub", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=15})
    Tab.IconObj = ico

    local page = mk("CanvasGroup", {Name="Page_"..name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, GroupTransparency=1, Visible=false, ZIndex=13, Parent=P.content})
    local scroll = mk("ScrollingFrame", {Name="Scroll", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=mobile and 3 or 4, ScrollBarImageTransparency=0.5, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ElasticBehavior=Enum.ElasticBehavior.Never, ZIndex=13, Parent=page})
    bind(scroll, "ScrollBarImageColor3", "Stroke")
    inset(scroll, 2, 8, 12, 2); stack(scroll, 10)
    Tab.Page, Tab.Scroll = page, scroll

    local scrollMemory = 0
    Tab.Remember = function() scrollMemory = scroll.CanvasPosition.Y end
    Tab.Restore = function() scroll.CanvasPosition = Vector2.new(0, scrollMemory) end

    Window.Tabs[index] = Tab

    btn.MouseEnter:Connect(function()
        if Window.Selected ~= Tab then
            play(btn, 0.15, {BackgroundTransparency=0.9}); ico.Color(Pal.Text, true)
        end
    end)
    btn.MouseLeave:Connect(function()
        play(btn, 0.2, {BackgroundTransparency=1})
        if Window.Selected ~= Tab then ico.Color(Pal.Sub, true) end
    end)
    btn.Activated:Connect(function() Window:SelectTab(Tab) end)

    if #Window.Tabs == 1 then task.defer(function() task.wait(); Window:SelectTab(Tab, true) end) end

    local tabApi = ElementFactory(Window, Tab, scroll, nil)

    function tabApi:AddSection(sc)
        sc = type(sc) == "table" and sc or {Name=sc}
        local secName = tostring(sc.Name or "Section")
        local holder = mk("Frame", {Name="Section_"..secName, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=#Tab.Sections+1, ZIndex=13, Parent=scroll})
        stack(holder, 8)

        local head = mk("TextButton", {Size=UDim2.new(1,0,0,mobile and 30 or 26), BackgroundTransparency=1, LayoutOrder=0, ZIndex=14, Parent=holder})
        local bar = mk("Frame", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,2,0.5,0), Size=UDim2.fromOffset(3,12), BackgroundColor3=Color3.new(1,1,1), ZIndex=15, Parent=head})
        round(bar, 2); accentGradient(bar, 90)
        local secLabel = tx("TextLabel", {Text=string.upper(secName), TextSize=11, Position=UDim2.fromOffset(12,0), Size=UDim2.new(1,-60,1,0), ZIndex=15, Parent=head}, 3, "Sub")
        local chev = makeIcon(head, "chevron-down", 14, "Sub", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-4,0.5,0), ZIndex=15})

        local bodyClip = mk("Frame", {Name="Body", Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=1, ZIndex=14, Parent=holder})
        stack(bodyClip, 8)

        local section = ElementFactory(Window, Tab, bodyClip, secName)
        section.Holder = holder
        Tab.Sections[#Tab.Sections+1] = section

        local collapsed, fullSize = false, 0
        head.Activated:Connect(function()
            if sc.Collapsible == false then return end
            collapsed = not collapsed
            if collapsed then
                fullSize = bodyClip.AbsoluteSize.Y / math.max(currentScale, 0.01)
                bodyClip.AutomaticSize = Enum.AutomaticSize.None
                bodyClip.ClipsDescendants = true
                bodyClip.Size = UDim2.new(1,0,0,fullSize)
                play(bodyClip, 0.32, {Size=UDim2.new(1,0,0,0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
                play(chev.Image, 0.25, {Rotation=-90}); play(chev.Glyph, 0.25, {Rotation=-90})
            else
                play(chev.Image, 0.25, {Rotation=0}); play(chev.Glyph, 0.25, {Rotation=0})
                local tw = play(bodyClip, 0.34, {Size=UDim2.new(1,0,0,fullSize)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
                after(tw, function()
                    if not collapsed then
                        bodyClip.AutomaticSize = Enum.AutomaticSize.Y
                        bodyClip.ClipsDescendants = false
                    end
                end)
            end
        end)
        if sc.Collapsible == false then chev.Holder.Visible = false end
        return section
    end

    return tabApi
end

local function flipTabs(Window, from, to, forward)
    local P = Window._parts
    local dir = forward and 1 or -1
    if from and from ~= to then
        from.Remember()
        play(from.Page, 0.16, {GroupTransparency=1})
        task.delay(0.18, function() if Window.Selected ~= from then from.Page.Visible = false end end)
    end
    to.Page.Visible = true
    to.Page.GroupTransparency = 1
    to.Page.Position = UDim2.fromOffset(0, 14*dir)
    to.Restore()
    play(to.Page, 0.34, {GroupTransparency=0})
    play(to.Page, 0.42, {Position=UDim2.fromOffset(0,0)}, Enum.EasingStyle.Quint)

    local cards = {}
    for _, child in ipairs(to.Scroll:GetDescendants()) do
        if child:GetAttribute("NihonCard") then cards[#cards+1] = child end
    end
    table.sort(cards, function(a,b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
    for i, card in ipairs(cards) do
        if i <= 12 then
            local rest = card.Position
            card.Position = rest + UDim2.fromOffset(0, 12*dir)
            task.delay((i-1)*0.028, function() if card.Parent then play(card, 0.4, {Position=rest}, Enum.EasingStyle.Quint) end end)
        end
    end
end

function TabImpl.select(Window, target, instant)
    local P = Window._parts
    if type(target) == "number" then target = Window.Tabs[target] end
    if type(target) == "string" then for _, t in ipairs(Window.Tabs) do if t.Name == target then target = t; break end end end
    if type(target) ~= "table" or not target.Button then return end
    local prev = Window.Selected
    if prev == target then return end
    Window.Selected = target

    local forward = not prev or target.Index > prev.Index
    if instant or not prev then
        for _, t in ipairs(Window.Tabs) do
            t.Page.Visible = t == target
            t.Page.GroupTransparency = t == target and 0 or 1
        end
        target.Restore()
    else flipTabs(Window, prev, target, forward) end

    for _, t in ipairs(Window.Tabs) do
        t.IconObj.Color(t == target and Pal.Accent or Pal.Sub, not instant)
    end

    task.defer(function()
        local b = target.Button
        local y = b.AbsolutePosition.Y - P.side.AbsolutePosition.Y
        local scale = math.max(currentScale, 0.01)
        local targetPos = UDim2.fromOffset(8, y/scale)
        local targetSize = UDim2.new(1,-16,0, b.AbsoluteSize.Y/scale)
        P.pill.Visible = true
        if instant or not prev then P.pill.Position, P.pill.Size = targetPos, targetSize
        else play(P.pill, 0.42, {Position=targetPos, Size=targetSize}, Enum.EasingStyle.Back) end
    end)
end

------------------------------------------------------------------------
-- ELEMENTS
------------------------------------------------------------------------
local function numFormat(v, step, suffix)
    local s
    if step < 1 then
        local frac = (tostring(step):gsub("^0%.", ""))
        local places = math.min(3, math.max(1, #frac))
        s = string.format("%."..places.."f", v); s = (s:gsub("0+$","")); s = (s:gsub("%.$",""))
    else s = tostring(math.floor(v+0.5)) end
    if suffix and suffix ~= "" then return s.." "..suffix end
    return s
end
local function snapTo(v, step, min)
    if step <= 0 then return v end
    return min + math.floor((v-min)/step + 0.5) * step
end

local function extendElements(E, ctx)
    local Window, Tab, P = ctx.Window, ctx.Tab, ctx.P
    local card, nameLabel, decorate, register, fail = ctx.card, ctx.nameLabel, ctx.decorate, ctx.register, ctx.fail
    local mobile, rowH = ctx.mobile, ctx.rowH

    function E:AddSlider(o)
        o = o or {}
        local label = tostring(o.Name or "Slider")
        local min, max = tonumber(o.Min) or 0, tonumber(o.Max) or 100
        if max <= min then max = min+1 end
        local step = tonumber(o.Increment) or 1
        local suffix = o.ValueName or ""
        local c = card(mobile and 62 or 58, true)
        local nm = nameLabel(c, label, UDim2.new(0.55,0,0,22)); nm.Position = UDim2.fromOffset(16,8)

        local valBox = tx("TextBox", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0,8), Size=UDim2.new(0.45,0,0,22), TextSize=12, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=16, Parent=c}, 3, "Accent")
        valBox.ClearTextOnFocus = true

        local rail = mk("TextButton", {Position=UDim2.new(0,16,1,mobile and -22 or -20), Size=UDim2.new(1,-32,0,mobile and 10 or 8), ZIndex=16, Parent=c})
        bind(rail, "BackgroundColor3", "Elevated")
        round(rail, 5)
        local fillBar = mk("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=Color3.new(1,1,1), ZIndex=17, Parent=rail})
        round(fillBar, 5); accentGradient(fillBar, 0)
        local knob = mk("Frame", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.fromOffset(mobile and 18 or 14, mobile and 18 or 14), BackgroundColor3=Color3.new(1,1,1), ZIndex=19, Parent=rail})
        round(knob, 9)
        local knobScale = mk("UIScale", {Parent=knob})

        local value = math.clamp(tonumber(o.Default) or min, min, max)
        local obj = {Value=value}
        local dragging, shownFrac, goalFrac, runner = false, 0, 0, nil

        local function fracOf(v) return math.clamp((v-min)/(max-min), 0, 1) end
        local function draw(frac)
            fillBar.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, 0, 0.5, 0)
        end
        local function ensureRunner()
            if runner then return end
            runner = RunService.RenderStepped:Connect(function(dt)
                local a = 1 - math.exp(-dt*22)
                shownFrac = shownFrac + (goalFrac-shownFrac)*a
                if math.abs(goalFrac-shownFrac) < 0.0005 and not dragging then
                    shownFrac = goalFrac; runner:Disconnect(); runner = nil
                end
                draw(shownFrac)
            end)
        end

        local firer = makeFirer(function() return obj.Value end, function(v) pcall(o.Callback or function() end, v) end)
        local function commit(v, silent, jump)
            v = math.clamp(snapTo(v, step, min), min, max)
            if v == obj.Value and not jump then return end
            obj.Value = v; goalFrac = fracOf(v)
            if jump then shownFrac = goalFrac; draw(goalFrac) else ensureRunner() end
            valBox.Text = numFormat(v, step, suffix)
            if silent then firer.Sync(v) else firer.Fire(); queueSave() end
        end

        function obj:Set(v, silent) commit(tonumber(v) or min, silent) end
        function obj:Get() return obj.Value end

        local function fromX(x)
            local rel = (x-rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1)
            commit(min + (max-min)*math.clamp(rel, 0, 1))
        end
        trackPointer(rail, function(input)
            if obj:IsLocked() then return false end
            dragging = true; play(knobScale, 0.15, {Scale=1.25}); ensureRunner(); fromX(input.Position.X)
        end, function(pos) fromX(pos.X) end, function()
            dragging = false; play(knobScale, 0.25, {Scale=1}, Enum.EasingStyle.Back)
        end)
        valBox.FocusLost:Connect(function()
            local n = tonumber(valBox.Text:match("-?%d+%.?%d*"))
            if n then obj:Set(n) else valBox.Text = numFormat(obj.Value, step, suffix) end
        end)

        register(o.Flag, obj, o, function() return obj.Value end, function(v) obj:Set(v) end)
        decorate(obj, c, o, "Slider")
        valBox.Text = numFormat(value, step, suffix)
        goalFrac = fracOf(value); shownFrac = goalFrac; draw(goalFrac)
        initFires[#initFires+1] = function() firer.Fire() end
        return obj
    end

    function E:AddToggle(o)
        o = o or {}
        local label = tostring(o.Name or "Toggle")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1,-80,1,0))

        local track = mk("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-14,0.5,0), Size=UDim2.fromOffset(44,24), ZIndex=15, Parent=c})
        bind(track, "BackgroundColor3", "Elevated")
        round(track, 12)
        local trackStroke = outline(track, "Stroke", 1, 0.25)
        local fill = mk("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=1, ZIndex=16, Parent=track})
        round(fill, 12); accentGradient(fill, 25)
        local knob = mk("Frame", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,3,0.5,0), Size=UDim2.fromOffset(18,18), BackgroundColor3=Color3.new(1,1,1), ZIndex=18, Parent=track})
        round(knob, 9)

        local state = {value=false}
        local obj = {Value=false}
        local function paint(v, animated)
            local dur = animated and 0.28 or 0.001
            play(fill, dur, {BackgroundTransparency = v and 0 or 1})
            play(knob, dur, {Position = UDim2.new(0, v and 23 or 3, 0.5, 0)}, Enum.EasingStyle.Back)
            play(trackStroke, dur, {Transparency = v and 1 or 0.25})
        end
        local firer = makeFirer(function() return state.value end, function(v) pcall(o.Callback or function() end, v) end)
        function obj:Set(v, silent)
            v = v and true or false
            state.value = v; obj.Value = v; paint(v, true)
            if silent then firer.Sync(v) else firer.Fire(); queueSave() end
        end
        function obj:Get() return state.value end
        function obj:Toggle() obj:Set(not state.value) end

        c.Activated:Connect(function() obj:Set(not state.value) end)

        register(o.Flag, obj, o, function() return state.value end, function(v) obj:Set(v) end)
        decorate(obj, c, o, "Toggle")
        local start = o.Default and true or false
        state.value = start; obj.Value = start; paint(start, false)
        if start then initFires[#initFires+1] = function() firer.Fire() end else firer.Sync(false) end
        return obj
    end

    function E:AddButton(o)
        o = o or {}
        local label = tostring(o.Name or "Button")
        local cooldown = tonumber(o.Cooldown) or 0.35
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1,-60,1,0))
        makeIcon(c, o.Icon or "chevron-right", 16, "Sub", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-16,0.5,0), ZIndex=15})

        local timer = mk("Frame", {AnchorPoint=Vector2.new(0,1), Position=UDim2.fromScale(0,1), Size=UDim2.new(0,0,0,2), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=0.2, Visible=false, ZIndex=20, Parent=c})
        accentGradient(timer, 0); c.ClipsDescendants = true

        local obj, ready, running = {}, true, false
        function obj:Fire(...)
            if not ready or running then if not ready then shake(c) end; return false end
            running = true; ready = cooldown <= 0
            play(c, 0.08, {BackgroundTransparency=0.35})
            task.delay(0.08, function() play(c, 0.25, {BackgroundTransparency=0.15}) end)
            if cooldown > 0 then
                timer.Visible = true; timer.Size = UDim2.new(1,0,0,2)
                local tw = play(timer, cooldown, {Size=UDim2.new(0,0,0,2)}, Enum.EasingStyle.Linear)
                after(tw, function() timer.Visible = false end)
                task.delay(cooldown, function() ready = true end)
            end
            local args = table.pack(...)
            task.spawn(function()
                local cb = o.Callback
                if type(cb) ~= "function" then running = false; fail(c, label, "no callback"); return end
                local ok, err = pcall(cb, table.unpack(args, 1, args.n))
                running = false
                if not ok then fail(c, label, err) else flashCard(c, Status.Success, 0.55) end
            end)
            return true
        end
        c.Activated:Connect(function() obj:Fire() end)
        return decorate(obj, c, o, "Button")
    end

    function E:AddLabel(o)
        o = type(o)=="table" and o or {Name=o}
        local c = card(rowH-6, false); c.Active = false
        local l = nameLabel(c, o.Name or "", UDim2.new(1,-28,1,0))
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
        c.Size = UDim2.new(1,0,0,0); c.Active = false
        inset(c, 14, 16, 14, 16); stack(c, 4)
        local head = tx("TextLabel", {Text=tostring(o.Title or o.Name or "Note"), TextSize=13, Size=UDim2.new(1,0,0,18), LayoutOrder=1, ZIndex=15, Parent=c}, 3)
        local text = tx("TextLabel", {Text=tostring(o.Content or ""), TextSize=12, TextWrapped=true, TextYAlignment=Enum.TextYAlignment.Top, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, LayoutOrder=2, ZIndex=15, Parent=c}, 1, "Sub")
        local obj = {}
        function obj:Set(t) text.Text = tostring(t) end
        function obj:SetTitle(t) head.Text = tostring(t) end
        o.Name = o.Name or o.Title
        return decorate(obj, c, o, "Paragraph")
    end

    function E:AddTextbox(o)
        o = o or {}
        local label = tostring(o.Name or "Textbox")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(0.42,0,1,0))
        local box = tx("TextBox", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-10,0.5,0), Size=UDim2.new(0.52,-6,0,28), Text=tostring(o.Default or ""), PlaceholderText=o.Placeholder or "type here", TextSize=12, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=16, Parent=c}, 2)
        bind(box, "BackgroundColor3", "Elevated")
        box.BackgroundTransparency = 0
        round(box, 8); inset(box, 0, 10, 0, 10)
        local ring = outline(box, "Accent", 1.2, 1)
        box.Focused:Connect(function() play(ring, 0.15, {Transparency=0.1}) end)
        local obj = {Value=box.Text}
        local firer = makeFirer(function() return obj.Value end, function(v) pcall(o.Callback or function() end, v) end)
        box.FocusLost:Connect(function()
            play(ring, 0.2, {Transparency=1})
            obj.Value = box.Text
            firer.Sync(nil); firer.Fire(); queueSave()
            if o.TextDisappear then box.Text = "" end
        end)
        function obj:Set(v, silent)
            box.Text = tostring(v); obj.Value = box.Text
            if silent then firer.Sync(obj.Value) else firer.Sync(nil); firer.Fire(); queueSave() end
        end
        function obj:Get() return obj.Value end
        register(o.Flag, obj, o, function() return obj.Value end, function(v) obj:Set(v) end)
        return decorate(obj, c, o, "Textbox")
    end

    local function buildDropdown(o, multi)
        o = o or {}
        local label = tostring(o.Name or (multi and "Multi Select" or "Dropdown"))
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(0.45,0,1,0))
        local valLbl = tx("TextLabel", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-36,0.5,0), Size=UDim2.new(0.5,-44,1,0), TextXAlignment=Enum.TextXAlignment.Right, TextTruncate=Enum.TextTruncate.AtEnd, TextSize=12, ZIndex=15, Parent=c}, 3, "Accent")
        makeIcon(c, "chevron-down", 14, "Sub", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-14,0.5,0), ZIndex=15})

        local obj = {Options=o.Options or {}, Value=multi and {} or nil}
        local function selected(opt) if multi then return obj.Value[opt]==true end; return obj.Value==opt end
        local function orderedSelection()
            local out = {}
            for _, opt in ipairs(obj.Options) do if obj.Value[opt] then out[#out+1] = opt end end
            return out
        end
        local function summary()
            if multi then
                local list = orderedSelection()
                if #list == 0 then return "None" end
                if #list <= 2 then return table.concat(list, ", ") end
                return #list.." selected"
            end
            return obj.Value ~= nil and tostring(obj.Value) or "None"
        end
        local function current() if multi then return orderedSelection() end; return obj.Value end

        local firer = makeFirer(function() if multi then return table.concat(orderedSelection(), "\0") end; return obj.Value end,
            function() pcall(o.Callback or function() end, current()) end)

        function obj:Get() return current() end
        function obj:Set(v, silent)
            if multi then
                obj.Value = {}
                if type(v) == "table" then
                    for k, x in pairs(v) do if type(k)=="number" then obj.Value[x]=true elseif x then obj.Value[k]=true end end
                end
            else
                if v ~= nil and not table.find(obj.Options, v) then return end
                obj.Value = v
            end
            valLbl.Text = summary()
            if silent then firer.Sync(multi and table.concat(orderedSelection(), "\0") or obj.Value)
            else firer.Fire(); queueSave() end
        end

        c.Activated:Connect(function()
            local wrap = mk("Frame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ZIndex=90, Parent=Root})
            local list = mk("Frame", {Size=UDim2.new(0, math.max(c.AbsoluteSize.X, 160), 0, math.min(#obj.Options, 6)*32+10), BackgroundTransparency=0.1, ZIndex=91, Parent=wrap})
            bind(list, "BackgroundColor3", "Surface")
            round(list, 12); outline(list, "Stroke", 1, 0.4)
            local listScale = mk("UIScale", {Scale=0.9, Parent=list})
            local ap = c.AbsolutePosition
            local vp = viewport()
            local lw = math.max(c.AbsoluteSize.X, 160)
            local lh = math.min(#obj.Options, 6)*32+10
            local px = math.clamp(ap.X + c.AbsoluteSize.X - lw, 6, math.max(6, vp.X - lw - 6))
            local py = math.clamp(ap.Y + c.AbsoluteSize.Y + 4, 6, math.max(6, vp.Y - lh - 6))
            list.Position = UDim2.fromOffset(px, py)
            local sc = mk("ScrollingFrame", {Size=UDim2.new(1,-10,1,-10), Position=UDim2.fromOffset(5,5), BackgroundTransparency=1, ScrollBarThickness=2, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=list})
            stack(sc, 2)
            for i, opt in ipairs(obj.Options) do
                local row = mk("TextButton", {Size=UDim2.new(1,0,0,28), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=selected(opt) and 0.85 or 1, LayoutOrder=i, Parent=sc})
                round(row, 6); accentGradient(row, 0)
                tx("TextLabel", {Text=tostring(opt), TextSize=12, Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-30,1,0), Parent=row}, 2, "Sub")
                if selected(opt) then makeIcon(row, "check", 12, "Accent", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0)}) end
                row.Activated:Connect(function()
                    if multi then obj.Value[opt] = (not obj.Value[opt]) or nil; valLbl.Text = summary(); firer.Fire(); queueSave()
                    else obj:Set(opt) end
                    wrap:Destroy()
                end)
            end
            play(listScale, 0.3, {Scale=1}, Enum.EasingStyle.Back)
            local catcher = mk("TextButton", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ZIndex=89, Parent=wrap})
            catcher.Activated:Connect(function() wrap:Destroy() end)
        end)

        register(o.Flag, obj, o, current, function(v) obj:Set(v) end)
        decorate(obj, c, o, multi and "Multi Dropdown" or "Dropdown")
        if multi then obj:Set(o.Default or {}, true) else obj:Set(o.Default or obj.Options[1], true) end
        valLbl.Text = summary()
        initFires[#initFires+1] = function() firer.Fire() end
        return obj
    end

    function E:AddDropdown(o) return buildDropdown(o, false) end
    function E:AddMultiDropdown(o) return buildDropdown(o, true) end

    function E:AddBind(o)
        o = o or {}
        local label = tostring(o.Name or "Keybind")
        local c = card(rowH, true)
        nameLabel(c, label, UDim2.new(1,-110,1,0))
        local chip = tx("TextButton", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-12,0.5,0), Size=UDim2.fromOffset(56,26), TextSize=12, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=16, Parent=c}, 3)
        bind(chip, "BackgroundColor3", "Elevated")
        chip.BackgroundTransparency = 0; round(chip, 8)
        local ring = outline(chip, "Stroke", 1, 0.3)
        local obj = {Value=o.Default, Binding=false}
        local function refresh()
            local t = obj.Binding and "..." or (obj.Value and tostring(obj.Value.Name) or "None")
            chip.Text = t
            local w = math.max(50, #t*8+22)
            play(chip, 0.25, {Size=UDim2.fromOffset(w, 26)}, Enum.EasingStyle.Back)
        end
        function obj:Set(k, silent)
            obj.Value = k; obj.Binding = false
            ring.Color = Pal.Stroke; play(ring, 0.15, {Transparency=0.3}); refresh()
            if not silent then queueSave() end
        end
        function obj:Get() return obj.Value end
        chip.Activated:Connect(function()
            if obj:IsLocked() then return end
            obj.Binding = true; ring.Color = Pal.Accent; play(ring, 0.15, {Transparency=0}); refresh()
        end)
        keep(UserInputService.InputBegan:Connect(function(input)
            if obj.Binding then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then obj:Set(nil)
                    elseif input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.Tab then obj:Set(input.KeyCode) end
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    obj:Set(input.UserInputType)
                end
                return
            end
            if not obj.Value then return end
            if input.KeyCode == obj.Value or input.UserInputType == obj.Value then
                task.spawn(function() pcall(o.Callback or function() end, true) end)
            end
        end))
        register(o.Flag, obj, o, function() return obj.Value end, function(v) obj:Set(v, true) end)
        decorate(obj, c, o, "Keybind")
        obj:Set(o.Default, true)
        return obj
    end
end

function ElementFactory(Window, Tab, parent, sectionName)
    local P = Window._parts; local mobile = P.mobile
    local E = {_count=0}
    local rowH = mobile and 46 or 42

    local function card(height, hover)
        local c = mk("TextButton", {Size=UDim2.new(1,0,0,height or rowH), BackgroundTransparency=0.15, ZIndex=14, LayoutOrder=E._count+1, Parent=parent})
        bind(c, "BackgroundColor3", "Card")
        round(c, 12)
        local st = outline(c, "Stroke", 1, 0.55)
        c:SetAttribute("NihonCard", true)
        if hover ~= false then
            c.MouseEnter:Connect(function() play(c, 0.18, {BackgroundTransparency=0}); play(st, 0.18, {Transparency=0.15}) end)
            c.MouseLeave:Connect(function() play(c, 0.22, {BackgroundTransparency=0.15}); play(st, 0.22, {Transparency=0.55}) end)
        end
        return c, st
    end

    local function nameLabel(c, text, width)
        return tx("TextLabel", {Name="Name", Text=tostring(text), TextSize=13, Position=UDim2.fromOffset(16,0), Size=width or UDim2.new(1,-90,1,0), TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=15, Parent=c}, 2)
    end

    local function decorate(obj, c, opts, kind)
        E._count = E._count+1
        function obj:Lock(v) end
        function obj:IsLocked() return false end
        function obj:SetVisible(v) c.Visible = v and true or false end
        function obj:Destroy()
            c:Destroy()
            for i, e in ipairs(P.searchIndex) do if e.owner == obj then table.remove(P.searchIndex, i); break end end
        end
        obj.Card = c
        obj.Kind = kind
        if opts.Visible == false then c.Visible = false end
        P.searchIndex[#P.searchIndex+1] = {
            owner=obj, name=tostring(opts.Name or kind), tab=Tab.Name, section=sectionName, kind=kind,
            go=function()
                if Window.RequestOpen then Window.RequestOpen() end
                Window:SelectTab(Tab)
                task.delay(0.22, function()
                    if not c.Parent then return end
                    local sc = Tab.Scroll
                    local y = c.AbsolutePosition.Y - sc.AbsolutePosition.Y + sc.CanvasPosition.Y - 10
                    play(sc, 0.35, {CanvasPosition=Vector2.new(0, math.max(0, y))})
                    flashCard(c, Pal.Accent, 1.1)
                end)
            end,
        }
        return obj
    end

    local function register(flag, obj, opts, get, set)
        if not flag then return end
        registerFlag(flag, {get=get, set=set, save=opts.Save==true, obj=obj})
        Nihon.Flags[flag] = obj
    end

    local function fail(c, label, err)
        flashCard(c, Status.Error, 1.1); shake(c)
        Nihon:MakeNotification({Name=(label or "Action").." failed", Content=errorText(err), Type="Error", Time=5})
    end

    extendElements(E, {Window=Window, Tab=Tab, P=P, card=card, nameLabel=nameLabel, decorate=decorate, register=register, fail=fail, mobile=mobile, rowH=rowH})

    return E
end

------------------------------------------------------------------------
-- LOADING SCREEN
------------------------------------------------------------------------
local function loadingScreen(cfg, title, done)
    if cfg.IntroEnabled == false then done(); return end
    local layer = mk("Frame", {Name="Loading", Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=1, ZIndex=400, Parent=Root})
    local card = mk("CanvasGroup", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(320,160), GroupTransparency=1, BackgroundTransparency=0.15, ZIndex=401, Parent=layer})
    bind(card, "BackgroundColor3", "Bg")
    round(card, 20); outline(card, "Stroke", 1, 0.5)
    local cardScale = mk("UIScale", {Scale=0.88, Parent=card})

    local orb = mk("Frame", {AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,22), Size=UDim2.fromOffset(50,50), BackgroundColor3=Color3.new(1,1,1), ZIndex=402, Parent=card})
    round(orb, 25)
    local orbGrad = accentGradient(orb, 0)
    local orbIcon = makeIcon(orb, cfg.Icon or "zap", 24, false, {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), ZIndex=403})
    orbIcon.Color(Color3.new(1,1,1))

    tx("TextLabel", {Text=tostring(cfg.IntroText or title), TextSize=18, AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,78), Size=UDim2.new(1,-30,0,22), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=402, Parent=card}, 3)
    local status = tx("TextLabel", {Text="starting", TextSize=11, AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,102), Size=UDim2.new(1,-30,0,14), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=402, Parent=card}, 1, "Sub")
    local rail = mk("Frame", {AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,128), Size=UDim2.new(1,-60,0,4), ZIndex=402, Parent=card})
    bind(rail, "BackgroundColor3", "Elevated"); round(rail, 2)
    local bar = mk("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=Color3.new(1,1,1), ZIndex=403, Parent=rail})
    round(bar, 2); accentGradient(bar, 0)

    play(layer, 0.3, {BackgroundTransparency=0.45})
    play(card, 0.3, {GroupTransparency=0})
    play(cardScale, 0.5, {Scale=1}, Enum.EasingStyle.Back)

    local spin = RunService.RenderStepped:Connect(function() orbGrad.Rotation = (os.clock()*220)%360 end)

    local steps = {{"reading theme",0.22},{"building interface",0.5},{"loading config",0.78},{"ready",1}}
    task.spawn(function()
        for _, st in ipairs(steps) do
            status.Text = st[1]
            play(bar, 0.35, {Size=UDim2.new(st[2],0,1,0)}, Enum.EasingStyle.Quint)
            task.wait(0.24)
        end
        task.wait(0.15); spin:Disconnect()
        play(card, 0.25, {GroupTransparency=1})
        play(cardScale, 0.3, {Scale=1.06}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        play(layer, 0.3, {BackgroundTransparency=1})
        task.wait(0.3); layer:Destroy(); done()
    end)
end

------------------------------------------------------------------------
-- SETTINGS TAB
------------------------------------------------------------------------
local function attachSettings(Window)
    function Window:AddSettingsTab(opts)
        opts = opts or {}
        local tab = Window:MakeTab({Name=opts.Name or "Settings", Icon=opts.Icon or "settings"})
        local look = tab:AddSection({Name="Appearance"})
        look:AddDropdown({Name="Theme", Options=ThemeOrder, Default=themeName, Flag="_theme", Save=true, Callback=function(v) setTheme(v, true) end})
        look:AddDropdown({Name="Font", Options=FontOrder, Default=currentFont, Flag="_font", Save=true, Callback=function(v) setFont(v) end})
        look:AddColorpicker({Name="Accent color", Default=Pal.Accent, Flag="_accent", Save=true, Callback=function(col) setAccent(col) end})
        look:AddSlider({Name="UI scale", Min=60, Max=130, Default=100, Increment=5, ValueName="%", Flag="_scale", Save=true, Callback=function(v) Window:SetScale(v/100) end})
        look:AddSlider({Name="Animation speed", Min=50, Max=200, Default=100, Increment=10, ValueName="%", Flag="_anim", Save=true, Callback=function(v) animSpeed = v/100 end})

        local cfgSec = tab:AddSection({Name="Config"})
        local nameBox = cfgSec:AddTextbox({Name="Profile name", Placeholder="my-config"})
        local profiles = cfgSec:AddDropdown({Name="Profiles", Options=Nihon:ListProfiles(), AllowNone=true})
        local function refresh() profiles:Refresh(Nihon:ListProfiles()) end
        cfgSec:AddButton({Name="Save profile", Icon="save", Callback=function()
            local n = nameBox:Get(); if n == "" then n = profiles:Get() or "" end
            if n == "" then error("type a name") end
            Nihon:SaveProfile(n); refresh()
            Nihon:MakeNotification({Name="Saved", Content=n, Type="Success"})
        end})
        cfgSec:AddButton({Name="Load profile", Icon="download", Callback=function()
            local n = profiles:Get(); if not n then error("choose one") end
            Nihon:LoadProfile(n)
            Nihon:MakeNotification({Name="Loaded", Content=n, Type="Success"})
        end})

        local about = tab:AddSection({Name="About"})
        about:AddLabel({Name="Nihon Lib "..Nihon.Version})
    end
end

------------------------------------------------------------------------
-- SEARCH
------------------------------------------------------------------------
local function fuzzy(query, text)
    query, text = query:lower(), text:lower()
    if query == "" then return 1 end
    local at = text:find(query, 1, true)
    if at then return 100-at end
    local qi, score = 1, 0
    for i = 1, #text do
        if text:sub(i,i) == query:sub(qi,qi) then
            qi = qi+1; score = score+1
            if qi > #query then return score end
        end
    end
    return nil
end

local function attachSearch(Window)
    local P = Window._parts; local mobile = P.mobile
    local layer = mk("TextButton", {Name="Search", Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=1, Visible=false, ZIndex=180, Parent=Root})
    local w = math.clamp(viewport().X - 32, 260, 460)
    local box = mk("CanvasGroup", {AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,mobile and 16 or 70), Size=UDim2.fromOffset(w,0), AutomaticSize=Enum.AutomaticSize.Y, GroupTransparency=1, BackgroundTransparency=0.15, ZIndex=181, Parent=layer})
    bind(box, "BackgroundColor3", "Surface")
    round(box, 16); outline(box, "Stroke", 1, 0.4)
    local boxScale = mk("UIScale", {Scale=0.94, Parent=box})

    local top = mk("Frame", {Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, Parent=box})
    makeIcon(top, "search", 16, "Sub", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,18,0.5,0)})
    local input = tx("TextBox", {Position=UDim2.fromOffset(44,0), Size=UDim2.new(1,-90,1,0), PlaceholderText="search features", TextSize=14, Parent=top}, 2)
    input.ClearTextOnFocus = false

    local list = mk("ScrollingFrame", {Size=UDim2.new(1,0,0,0), BackgroundTransparency=1, ScrollBarThickness=2, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=box})
    inset(list, 6, 6, 6, 6); stack(list, 2)

    local open, buttons, shown = false, {}, {}
    local function render()
        for _, b in ipairs(buttons) do b:Destroy() end
        buttons, shown = {}, {}
        local q = input.Text
        local scored = {}
        for _, e in ipairs(P.searchIndex) do
            local sc = fuzzy(q, e.name.." "..e.tab.." "..e.kind)
            if sc then scored[#scored+1] = {e=e, s=sc} end
        end
        table.sort(scored, function(a,b) return a.s > b.s end)
        for i = 1, math.min(#scored, 30) do shown[i] = scored[i].e end
        for i, e in ipairs(shown) do
            local b = mk("TextButton", {Size=UDim2.new(1,0,0,40), BackgroundTransparency=1, LayoutOrder=i, Parent=list})
            round(b, 8); accentGradient(b, 0)
            tx("TextLabel", {Text=e.name, TextSize=13, Position=UDim2.fromOffset(12,5), Size=UDim2.new(1,-90,0,16), TextTruncate=Enum.TextTruncate.AtEnd, Parent=b}, 2)
            tx("TextLabel", {Text=e.tab..(e.section and (" / "..e.section) or ""), TextSize=10, Position=UDim2.fromOffset(12,22), Size=UDim2.new(1,-90,0,13), TextTruncate=Enum.TextTruncate.AtEnd, Parent=b}, 1, "Sub")
            b.Activated:Connect(function() Window:CloseSearch(); e.go() end)
            buttons[i] = b
        end
        list.Size = UDim2.new(1,0,0, math.min(math.max(#shown,1)*42+12, mobile and 170 or 300))
    end

    input:GetPropertyChangedSignal("Text"):Connect(function() if open then render() end end)

    function Window:OpenSearch()
        if open then return end
        open = true; input.Text = ""; layer.Visible = true; render()
        play(layer, 0.25, {BackgroundTransparency=0.6})
        play(box, 0.25, {GroupTransparency=0})
        play(boxScale, 0.4, {Scale=1}, Enum.EasingStyle.Back)
        if not mobile then task.delay(0.05, function() if open then input:CaptureFocus() end end) end
    end
    function Window:CloseSearch()
        if not open then return end
        open = false; input:ReleaseFocus()
        play(layer, 0.2, {BackgroundTransparency=1})
        play(box, 0.18, {GroupTransparency=1})
        play(boxScale, 0.2, {Scale=0.96})
        task.delay(0.24, function() if not open then layer.Visible = false end end)
    end

    layer.Activated:Connect(function() Window:CloseSearch() end)
    input.FocusLost:Connect(function(enter) if enter and shown[1] then local e = shown[1]; Window:CloseSearch(); e.go() end end)

    keep(UserInputService.InputBegan:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if open then Window:CloseSearch() else Window:OpenSearch() end
        elseif open and i.KeyCode == Enum.KeyCode.Escape then Window:CloseSearch() end
    end))

    P.searchBtn.Activated:Connect(function() if open then Window:CloseSearch() else Window:OpenSearch() end end)
end

------------------------------------------------------------------------
-- PUBLIC HELPERS
------------------------------------------------------------------------
function Nihon:SetTheme(name) setTheme(name, true) end
function Nihon:SetAccent(c1, c2) setAccent(c1, c2) end
function Nihon:SetFont(name) setFont(name) end
function Nihon:GetThemes() local out = {}; for _, n in ipairs(ThemeOrder) do out[#out+1] = n end; return out end
function Nihon:SetAnimationSpeed(s) animSpeed = math.clamp(tonumber(s) or 1, 0.1, 60) end

------------------------------------------------------------------------
-- WINDOW METHODS
------------------------------------------------------------------------
local function attachWindowMethods(Window)
    function Window:MakeTab(cfg) return TabImpl.make(Window, cfg) end
    function Window:SelectTab(tab, instant) TabImpl.select(Window, tab, instant) end
    function Window:Notify(cfg) return Nihon:MakeNotification(cfg) end
    function Window:SetScale(s) Window.Scale = math.clamp(tonumber(s) or 1, 0.5, 1.4); Window._parts.applyScale(true) end
    function Window:SetTitle(t) Window.TitleLabel.Text = tostring(t) end
    function Window:SetSubtitle(t) Window.SubtitleLabel.Text = tostring(t); Window.SubtitleLabel.Visible = tostring(t) ~= "" end
    function Window:SetIcon(id) Window.LogoIcon.Set(id); Window.LauncherIcon.Set(id) end
    function Window:SetTabIcon(name, id) for _, t in ipairs(Window.Tabs) do if t.Name == name then t:SetIcon(id) end end end
    attachSearch(Window)
    attachSettings(Window)
end

Hooks.attach = attachWindowMethods

------------------------------------------------------------------------
-- INIT / DESTROY
------------------------------------------------------------------------
function Nihon:Init()
    if Nihon._ready then return end
    local window = Nihon.Windows[1]
    local cfg = window and window.Cfg or {}
    local function finish()
        if Nihon.SaveConfig then
            local auto = Nihon:GetAutoload and Nihon:GetAutoload() or nil
            if auto then Nihon:LoadProfile(auto) end
        end
        for _, fn in ipairs(initFires) do task.spawn(pcall, fn) end
        table.clear(initFires)
        Nihon._ready = true
        if window then
            buildLibraryInfoTab(window)
            window.Show()
            task.delay(0.4, function()
                Nihon:MakeNotification({
                    Name = "✨ Nihon Lib Aurora",
                    Content = "Modern, glassy UI. Press Ctrl+K to search.",
                    Type = "Info",
                    Time = 6,
                })
            end)
        end
    end
    loadingScreen(cfg, window and window.Name or "Nihon Lib", finish)
end

function Nihon:Destroy()
    Nihon._ready = false
    if noteLoop then noteLoop:Disconnect(); noteLoop = nil end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    for _, w in ipairs(Nihon.Windows) do pcall(function() w._parts.launcher:Destroy() end) end
    Nihon.Windows = {}
    pcall(function() Root:Destroy() end)
    if env.NihonLibInstance == Nihon then env.NihonLibInstance = nil end
end

return Nihon

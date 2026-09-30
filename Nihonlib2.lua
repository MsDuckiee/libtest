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

-- NOTIFICATIONS
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

    local frame = mk("CanvasGrou

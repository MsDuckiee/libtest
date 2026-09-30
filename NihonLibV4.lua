--[[
    Nihon Lib | v7.0 "Blueprint"
    Built exactly to the reference: horizontal tabs, user dropdown,
    settings popup, page nav, add dropdown, tab manager (Tabs/Groups),
    action buttons, create-tab window.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TextService      = game:GetService("TextService")
local SoundService     = game:GetService("SoundService")
local Stats            = nil

local LocalPlayer = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
if type(env.NihonLibInstance) == "table" and type(env.NihonLibInstance.Destroy) == "function" then
    pcall(env.NihonLibInstance.Destroy, env.NihonLibInstance)
end

local SOUND_ID = "rbxassetid://72132563016981"

local Nihon = {
    Version     = "7.0.0",
    Flags       = {},
    Windows     = {},
    Folder      = "NihonLib",
    Profile     = "default",
    SaveConfig  = false,
    IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    SoundEnabled = true, SoundVolume = 0.4,
    ShowLauncher = true, ShowResize = true, ShowClose = true, ShowMinimize = true,
}
env.NihonLibInstance = Nihon

local conns = {}
local function keep(c) conns[#conns+1] = c; return c end

local function playSound(volume, pitch)
    if not Nihon.SoundEnabled then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = SOUND_ID
        s.Volume = (volume or 0.3) * Nihon.SoundVolume
        s.PlaybackSpeed = pitch or 1
        s.Parent = SoundService
        s:Play()
        task.delay(3, function() s:Destroy() end)
    end)
end

-- Palette (blueprint blues)
local Themes = {
    Blueprint = {
        Bg=Color3.fromRGB(28,52,110), Surface=Color3.fromRGB(38,68,138), Elevated=Color3.fromRGB(50,86,168),
        Card=Color3.fromRGB(46,80,156), Stroke=Color3.fromRGB(96,140,220), Text=Color3.fromRGB(235,242,255),
        Sub=Color3.fromRGB(168,196,240), Accent=Color3.fromRGB(80,140,240), Accent2=Color3.fromRGB(120,180,255),
    },
    Glass = {
        Bg=Color3.fromRGB(16,18,26), Surface=Color3.fromRGB(26,28,38), Elevated=Color3.fromRGB(36,38,52),
        Card=Color3.fromRGB(30,32,44), Stroke=Color3.fromRGB(60,64,84), Text=Color3.fromRGB(242,242,250),
        Sub=Color3.fromRGB(152,155,178), Accent=Color3.fromRGB(140,120,255), Accent2=Color3.fromRGB(120,200,255),
    },
    Amoled = {
        Bg=Color3.fromRGB(0,0,0), Surface=Color3.fromRGB(11,11,13), Elevated=Color3.fromRGB(20,20,24),
        Card=Color3.fromRGB(14,14,17), Stroke=Color3.fromRGB(36,36,44), Text=Color3.fromRGB(245,245,248),
        Sub=Color3.fromRGB(138,138,150), Accent=Color3.fromRGB(105,195,255), Accent2=Color3.fromRGB(165,135,255),
    },
}
local ThemeOrder = {"Blueprint","Glass","Amoled"}
local Pal, themeName = {}, "Blueprint"

local Status = {
    Info=Color3.fromRGB(96,156,255), Success=Color3.fromRGB(78,214,140),
    Warning=Color3.fromRGB(255,192,72), Error=Color3.fromRGB(255,90,102),
}

local function loadPalette(name)
    local base = Themes.Glass; local src = Themes[name] or base
    for k,v in pairs(base) do Pal[k] = src[k] or v end
    for k,v in pairs(Status) do Pal[k] = v end
end
loadPalette("Blueprint")

local Status = {
    Info=Color3.fromRGB(96,156,255), Success=Color3.fromRGB(78,214,140),
    Warning=Color3.fromRGB(255,192,72), Error=Color3.fromRGB(255,90,102),
}
local Glyphs = {
    ["info"]="i",["check"]="+",["check-circle"]="+",["alert-triangle"]="!",["alert-circle"]="!",
    ["x"]="x",["x-circle"]="x",["minus"]="-",["plus"]="+",["chevron-down"]="v",["chevron-up"]="^",
    ["chevron-left"]="<",["chevron-right"]=">",["search"]="o",["settings"]="*",["volume"]="◉",["volume-x"]="○",
    ["folder"]="▤",["file"]="▢",["save"]="⌸",["exit"]="⇥",["filter"]="▽",["user"]="●",["home"]="⌂",
    ["info2"]="i",["trash"]="⌫",["refresh"]="↻",["window"]="▣",["layers"]="▤",["grid"]="▦",
}
local Fonts = {
    Modern  = {Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold},
    Rounded = {Enum.Font.Nunito, Enum.Font.Nunito, Enum.Font.FredokaOne},
    Mono    = {Enum.Font.RobotoMono, Enum.Font.RobotoMono, Enum.Font.RobotoMono},
    Classic = {Enum.Font.SourceSans, Enum.Font.SourceSansSemibold, Enum.Font.SourceSansBold},
}
local FontOrder = {"Modern","Rounded","Mono","Classic"}
local currentFont = "Modern"

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
        return Vector2.new(1280,720)
    end
    return v
end

local binds, fontObjs = setmetatable({},{__mode="k"}), setmetatable({},{__mode="k"})
local tweens = setmetatable({},{__mode="k"})
local function play(obj, dur, props, style, dir)
    local names = {}; for k in pairs(props) do names[#names+1]=k end; table.sort(names)
    local key = table.concat(names, ",")
    local slot = tweens[obj]; if not slot then slot={}; tweens[obj]=slot end
    if slot[key] then slot[key]:Cancel() end
    local info = TweenInfo.new(math.max(dur,0.001), style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props); slot[key]=tw; tw:Play(); return tw
end
local function after(tw, fn)
    local c; c = tw.Completed:Connect(function(s) c:Disconnect(); if s==Enum.PlaybackState.Completed then fn() end end)
end
local function mk(class, props, kids)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
    if class=="TextButton" then inst.Text=""; inst.AutoButtonColor=false
    elseif class=="TextLabel" then inst.Text="" end
    local parent
    if props then for k,v in pairs(props) do if k=="Parent" then parent=v else inst[k]=v end end end
    if kids then for _,c in ipairs(kids) do c.Parent=inst end end
    if parent then inst.Parent=parent end
    return inst
end
local function bind(obj, prop, key, fn)
    local list = binds[obj]; if not list then list={}; binds[obj]=list end
    list[#list+1] = {prop=prop, key=key, fn=fn}
    local v = Pal[key]
    if v == nil then v = Pal.Text end
    if fn then v = fn(v,Pal) end
    obj[prop] = v; return obj
end
local function refreshTheme()
    for obj, list in pairs(binds) do
        for _, rec in ipairs(list) do
            local v = Pal[rec.key]; if rec.fn then v = rec.fn(v,Pal) end
            if typeof(v)=="Color3" and obj.Parent then play(obj,0.3,{[rec.prop]=v}) else obj[rec.prop]=v end
        end
    end
end
local function round(p,r) return mk("UICorner",{CornerRadius=UDim.new(0,r),Parent=p}) end
local function outline(p,key,t,tr)
    local s = mk("UIStroke",{Thickness=t or 1, Transparency=tr or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p})
    bind(s,"Color",key or "Stroke"); return s
end
local function inset(p,t,r,b,l)
    return mk("UIPadding",{PaddingTop=UDim.new(0,t or 0),PaddingRight=UDim.new(0,r or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0),Parent=p})
end
local function stack(p,gap,dir)
    return mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,gap or 0),FillDirection=dir or Enum.FillDirection.Vertical,Parent=p})
end
local function tx(class,props,weight,tone)
    local o = Instance.new(class)
    o.BackgroundTransparency=1; o.BorderSizePixel=0
    o.Font = Fonts[currentFont][weight or 2]; o.TextSize=13
    o.TextXAlignment = Enum.TextXAlignment.Left; o.Text=""
    if class=="TextButton" then o.AutoButtonColor=false
    elseif class=="TextBox" then o.ClearTextOnFocus=false; bind(o,"PlaceholderColor3","Sub") end
    local parent
    if props then for k,v in pairs(props) do if k=="Parent" then parent=v else o[k]=v end end end
    bind(o,"TextColor3",tone or "Text"); fontObjs[o]=weight or 2
    if parent then o.Parent=parent end
    return o
end
local function setFont(n)
    if not Fonts[n] then return end
    currentFont = n
    for o,w in pairs(fontObjs) do o.Font = Fonts[n][w] end
end
local function setTheme(n)
    if not Themes[n] then return end
    themeName = n; loadPalette(n); refreshTheme()
end

local IconMap = {}
pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")
    IconMap = HttpService:JSONDecode(raw).icons or {}
end)
local function resolveIcon(n)
    if n==nil then return nil end
    local s = tostring(n); if s=="" then return nil end
    if IconMap[s] then return IconMap[s] end
    if s:find("^rbxasset") then return s end
    if tonumber(s) then return "rbxassetid://"..s end
    return nil
end
local function makeIcon(parent, name, size, tone, props)
    local holder = mk("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(size,size)})
    if props then for k,v in pairs(props) do holder[k]=v end end
    holder.Parent = parent
    local img = mk("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Fit,Parent=holder})
    local glyph = tx("TextLabel",{Size=UDim2.fromScale(1,1),TextSize=math.floor(size*0.8),TextXAlignment=Enum.TextXAlignment.Center,Visible=false,Parent=holder},3,(tone or "Text"))
    if tone ~= false then bind(img,"ImageColor3",tone or "Text") end
    local api = {Holder=holder, Image=img, Glyph=glyph}
    function api.Set(n)
        local id = resolveIcon(n)
        if id then img.Image=id; img.Visible=true; glyph.Visible=false
        else img.Visible=false; glyph.Visible=true
            local k = tostring(n or ""); glyph.Text = Glyphs[k] or k:sub(1,1):upper()
        end
    end
    function api.Color(c, animated)
        if animated then play(img,0.2,{ImageColor3=c}); play(glyph,0.2,{TextColor3=c})
        else img.ImageColor3=c; glyph.TextColor3=c end
    end
    api.Set(name); return api
end

-- pointer helpers
local function isPointer(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
local function samePointer(a,b) if a.UserInputType==Enum.UserInputType.Touch then return a==b end; return b.UserInputType==a.UserInputType end
local function v2(i) return Vector2.new(i.Position.X, i.Position.Y) end
local function trackPointer(gui, onDown, onMove, onUp)
    return gui.InputBegan:Connect(function(input)
        if not isPointer(input) then return end
        if onDown and onDown(input)==false then return end
        local mover,ender
        mover = UserInputService.InputChanged:Connect(function(m)
            local mm = input.UserInputType==Enum.UserInputType.MouseButton1 and m.UserInputType==Enum.UserInputType.MouseMovement
            if mm or m==input then if onMove then onMove(v2(m),m) end end
        end)
        ender = UserInputService.InputEnded:Connect(function(d)
            if isPointer(d) and samePointer(input,d) then
                mover:Disconnect(); ender:Disconnect()
                if onUp then onUp(v2(d)) end
            end
        end)
    end)
end
local function makeDraggable(handles, target, opts)
    opts = opts or {}
    for _,h in ipairs(handles) do
        local dragging, moved, startInput, startPos, goal, current, beat = false,false,nil,nil,nil,nil,nil
        local function apply() target.Position = UDim2.fromOffset(current.X, current.Y) end
        local function step(dt)
            local a = 1 - math.exp(-dt*(opts.speed or 22))
            current = current:Lerp(goal, a); apply()
            if not dragging and (goal-current).Magnitude < 0.35 then
                current = goal; apply()
                if beat then beat:Disconnect(); beat=nil end
            end
        end
        trackPointer(h, function(input)
            if opts.canDrag and not opts.canDrag() then return false end
            dragging, moved = true, false
            startInput = v2(input)
            startPos = Vector2.new(target.AbsolutePosition.X, target.AbsolutePosition.Y)
            goal, current = startPos, startPos
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
            task.delay(0.1, function() if beat then beat:Disconnect(); beat=nil end end)
        end)
    end
end

-- NOTIFICATIONS
local Notes = {active={}, queue={}, byKey={}, queuedKey={}, max=5, duration=4, position="TopRight"}
local noteLayer = mk("Frame",{Name="Notes",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=500,Parent=Root})
local corners = {TopRight={ax=1,ay=0},TopLeft={ax=0,ay=0},TopCenter={ax=0.5,ay=0},BottomRight={ax=1,ay=1},BottomLeft={ax=0,ay=1},BottomCenter={ax=0.5,ay=1}}
local noteLoop, spawnNote
local function noteWidth() return math.clamp(math.floor(viewport().X-28),240,340) end
local function notePos(slot,dx)
    local c = corners[Notes.position] or corners.TopRight
    local mx = c.ax==0.5 and 0 or (c.ax==1 and -14 or 14)
    local my = c.ay==0 and (14+slot) or -(14+slot)
    return UDim2.new(c.ax, mx+(dx or 0), c.ay, my)
end
local function relayout()
    local c = corners[Notes.position] or corners.TopRight
    local cum = 0
    for _,n in ipairs(Notes.active) do
        n.slot = cum
        n.frame.AnchorPoint = Vector2.new(c.ax,c.ay)
        if not n.dragging then play(n.frame,0.5,{Position=notePos(cum,0)}) end
        cum = cum + n.height + 8
    end
end
local function promoteQueue()
    while #Notes.active < Notes.max and #Notes.queue > 0 do
        local e = table.remove(Notes.queue,1); Notes.queuedKey[e.key]=nil; spawnNote(e)
    end
end
local function dismissNote(n)
    if n.dying then return end
    n.dying = true
    for i,x in ipairs(Notes.active) do if x==n then table.remove(Notes.active,i); break end end
    if Notes.byKey[n.key]==n then Notes.byKey[n.key]=nil end
    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax==1 and (noteWidth()+40) or (c.ax==0 and -(noteWidth()+40) or 0)
    play(n.frame,0.35,{GroupTransparency=1})
    if out~=0 then play(n.frame,0.4,{Position=notePos(n.slot,out)},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
    else play(n.frame,0.35,{Position=notePos(n.slot-40)}) end
    task.delay(0.5, function() if n.frame then n.frame:Destroy() end end)
    relayout(); promoteQueue()
end
local function bumpNote(n, extra)
    n.count = n.count + 1; n.badge.Text = n.count.."x"; n.badge.Visible = true
    n.expires = os.clock() + (extra or n.time)
    n.pop.Scale = 1.45; play(n.pop,0.45,{Scale=1},Enum.EasingStyle.Back)
    if not n.dragging then
        n.frame.Position = notePos(n.slot,12)
        play(n.frame,0.5,{Position=notePos(n.slot,0)},Enum.EasingStyle.Back)
    end
end
local function ensureNoteLoop()
    if noteLoop then return end
    noteLoop = RunService.Heartbeat:Connect(function(dt)
        local now = os.clock()
        for i = #Notes.active,1,-1 do
            local n = Notes.active[i]
            if n and not n.dying and not n.sticky then
                if n.hover or n.dragging then n.expires = n.expires + dt end
                local left = n.expires - now
                if not n.custom then n.bar.Size = UDim2.new(math.clamp(left/n.time,0,1),0,0,2) end
                if left <= 0 then dismissNote(n) end
            end
        end
        if #Notes.active==0 and noteLoop then noteLoop:Disconnect(); noteLoop=nil end
    end)
end
function spawnNote(entry)
    local cfg, handle = entry.cfg, entry.handle
    local color = Status[entry.kind]
    local w = noteWidth()
    local n = {key=entry.key,count=entry.count,handle=handle,height=64,slot=0,
        time=math.max(1,tonumber(cfg.Time) or Notes.duration), sticky=cfg.Sticky==true}
    n.expires = os.clock() + n.time
    local content = tostring(cfg.Content or "")
    if cfg.Silent ~= true then
        if entry.kind=="Success" then playSound(0.35,1.2)
        elseif entry.kind=="Error" then playSound(0.4,0.8)
        elseif entry.kind=="Warning" then playSound(0.35,1)
        else playSound(0.25,1) end
    end
    local frame = mk("CanvasGroup",{Name="Note",Size=UDim2.fromOffset(w,0),AutomaticSize=Enum.AutomaticSize.Y,GroupTransparency=1,BackgroundTransparency=0.1,Parent=noteLayer})
    bind(frame,"BackgroundColor3","Surface")
    round(frame,14); outline(frame,"Stroke",1,0.4)
    mk("UISizeConstraint",{MinSize=Vector2.new(0,60),Parent=frame})
    mk("Frame",{Size=UDim2.new(0,4,1,0),BackgroundColor3=color,BackgroundTransparency=0.05,ZIndex=3,Parent=frame})
    local disc = mk("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,14),Size=UDim2.fromOffset(30,30),BackgroundColor3=color,BackgroundTransparency=0.8,ZIndex=3,Parent=frame})
    round(disc,15); outline(disc,"Text",1,0.85)
    local ico = makeIcon(disc, cfg.Icon or (entry.kind=="Success" and "check" or entry.kind=="Error" and "x" or "info"), 16, false,
        {AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=4})
    ico.Color(color)
    local col = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=2,Parent=frame})
    inset(col,14,56,14,18); stack(col,4)
    n.title = tx("TextLabel",{Text=tostring(cfg.Name or cfg.Title or "Notification"),TextSize=14,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=1,ZIndex=3,Parent=col},3)
    n.body = tx("TextLabel",{Text=content,TextSize=12,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=2,Visible=content~="",ZIndex=3,Parent=col},1,"Sub")
    local est = TextService:GetTextSize(content,12,Fonts[currentFont][1],Vector2.new(w-90,1000))
    n.height = math.max(64, 42+est.Y+16)
    n.badge = tx("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,-2),Size=UDim2.fromOffset(0,18),ZIndex=6,AutomaticSize=Enum.AutomaticSize.X,Text=n.count.."x",TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=0.78,BackgroundColor3=color,TextColor3=color,Visible=n.count>1,Parent=frame},3)
    round(n.badge,10); inset(n.badge,0,8,0,8)
    n.pop = mk("UIScale",{Parent=n.badge})
    n.bar = mk("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,2),BackgroundColor3=color,BackgroundTransparency=0.25,Visible=not n.sticky,ZIndex=5,Parent=frame})
    n.frame = frame
    frame.MouseEnter:Connect(function() n.hover=true end)
    frame.MouseLeave:Connect(function() n.hover=false end)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local h = frame.AbsoluteSize.Y
        if h > 4 and math.abs(h-n.height)>0.5 then n.height = h; if not n.dying then task.defer(relayout) end end
    end)
    local startX, swiped = 0, false
    trackPointer(frame, function(input) startX=input.Position.X; swiped=false; n.dragging=true end,
        function(pos)
            local dx = pos.X - startX
            if math.abs(dx)>6 then swiped=true end
            if swiped then n.frame.Position = notePos(n.slot,dx) end
        end, function(pos)
            n.dragging = false
            local dx = pos.X - startX
            if math.abs(dx)>70 or (not swiped and cfg.ClickDismiss ~= false) then dismissNote(n) else relayout() end
        end)
    local c = corners[Notes.position] or corners.TopRight
    local out = c.ax==1 and (w+40) or (c.ax==0 and -(w+40) or 0)
    frame.AnchorPoint = Vector2.new(c.ax,c.ay)
    frame.Position = out~=0 and notePos(0,out) or notePos(-50,0)
    table.insert(Notes.active,1,n)
    if entry.dedupe then Notes.byKey[n.key]=n end
    handle.n = n
    relayout()
    play(frame,0.4,{GroupTransparency=0})
    task.defer(function() if not n.dying and frame.Parent then frame.GroupTransparency=0; relayout() end end)
    ensureNoteLoop()
    return n
end
function Nihon:MakeNotification(cfg)
    if type(cfg)~="table" then cfg={Content=tostring(cfg)} end
    local kind = Status[cfg.Type] and cfg.Type or "Info"
    local name = tostring(cfg.Name or cfg.Title or "Notification")
    local content = tostring(cfg.Content or "")
    local key = kind.."|"..name.."|"..content
    local dedupe = not cfg.Sticky
    if dedupe then
        local live = Notes.byKey[key]
        if live and not live.dying then bumpNote(live,tonumber(cfg.Time)); return live.handle end
        local waiting = Notes.queuedKey[key]
        if waiting then waiting.count = waiting.count+1; return waiting.handle end
    end
    local handle = {}
    function handle:Dismiss() if handle.n then dismissNote(handle.n) end end
    local entry = {cfg=cfg,kind=kind,key=key,count=1,handle=handle,dedupe=dedupe}
    if #Notes.active >= Notes.max then Notes.queue[#Notes.queue+1]=entry; if dedupe then Notes.queuedKey[key]=entry end
    else spawnNote(entry) end
    return handle
end
Nihon.Notify = Nihon.MakeNotification

-- DIALOG
function Nihon:Dialog(cfg)
    cfg = cfg or {}
    local layer = mk("TextButton",{Name="Dialog",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,ZIndex=400,Parent=Root})
    local w = math.clamp(viewport().X-32,260,380)
    local box = mk("CanvasGroup",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(w,0),AutomaticSize=Enum.AutomaticSize.Y,GroupTransparency=1,BackgroundTransparency=0.1,ZIndex=401,Parent=layer})
    bind(box,"BackgroundColor3","Surface")
    round(box,16); outline(box,"Stroke",1,0.4)
    local sc = mk("UIScale",{Scale=0.9,Parent=box})
    local col = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=box})
    inset(col,20,20,18,20); stack(col,10)
    tx("TextLabel",{Text=tostring(cfg.Title or "Confirm"),TextSize=16,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=1,Parent=col},3)
    if cfg.Content and cfg.Content~="" then
        tx("TextLabel",{Text=tostring(cfg.Content),TextSize=13,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=2,Parent=col},1,"Sub")
    end
    local row = mk("Frame",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,LayoutOrder=3,Parent=col})
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Bottom,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,Parent=row})
    local dialog = {}; local closed=false
    function dialog:Close()
        if closed then return end
        closed = true
        play(layer,0.2,{BackgroundTransparency=1}); play(box,0.2,{GroupTransparency=1}); play(sc,0.2,{Scale=0.94})
        task.delay(0.3,function() layer:Destroy() end)
    end
    for i,b in ipairs(cfg.Buttons or {{Name="OK",Primary=true}}) do
        local label = tostring(b.Name or "OK")
        local sz = TextService:GetTextSize(label,13,Fonts[currentFont][3],Vector2.new(400,34))
        local btn = tx("TextButton",{Text=label,Size=UDim2.fromOffset(math.max(80,sz.X+30),36),LayoutOrder=i,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=0,ZIndex=402,Parent=row},3)
        round(btn,9)
        if b.Primary then
            if b.Danger then btn.BackgroundColor3 = Status.Error; btn.TextColor3 = Color3.new(1,1,1)
            else bind(btn,"BackgroundColor3","Accent"); btn.TextColor3 = Color3.new(1,1,1) end
        else bind(btn,"BackgroundColor3","Elevated") end
        btn.Activated:Connect(function()
            dialog:Close()
            if b.Callback then task.spawn(function() pcall(b.Callback) end) end
        end)
    end
    layer.Activated:Connect(function() if cfg.Dismissable ~= false then dialog:Close() end end)
    play(layer,0.25,{BackgroundTransparency=0.55}); play(box,0.25,{GroupTransparency=0}); play(sc,0.4,{Scale=1},Enum.EasingStyle.Back)
    return dialog
end

-- CONFIG
local flagRefs, flagOrder = {}, {}
local function encode(v)
    local t = typeof(v)
    if t=="Color3" then return {t="c",r=v.R,g=v.G,b=v.B}
    elseif t=="EnumItem" then return {t="k",n=v.Name}
    elseif v==nil then return {t="k"} end
    return v
end
local function decode(v)
    if type(v)~="table" then return v end
    if v.t=="c" then return Color3.new(v.r,v.g,v.b)
    elseif v.t=="k" then return v.n and Enum.KeyCode[v.n] or nil end
    return v
end
local function fsReady() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function" and type(isfolder)=="function" end
local function cfgPath(n) return Nihon.Folder.."/"..n..".json" end
local function ensureFolder() if not isfolder(Nihon.Folder) then makefolder(Nihon.Folder) end end
local function snapshot()
    local d = {}
    for _,f in ipairs(flagOrder) do local r = flagRefs[f]; if r.save then d[f] = encode(r.get()) end end
    return d
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
    for _,f in ipairs(flagOrder) do
        local r = flagRefs[f]
        if r.save and data[f]~=nil then pcall(r.set, decode(data[f])) end
    end
    return true
end
local function registerFlag(flag, ref)
    if not flag then return end
    if not flagRefs[flag] then flagOrder[#flagOrder+1]=flag end
    flagRefs[flag] = ref
end

-- WINDOW
local Sizes = {
    desktop = {w=980, h=620, top=54},
    mobile  = {w=580, h=400, top=48},
}

function Nihon:MakeWindow(cfg)
    cfg = cfg or {}
    local title = tostring(cfg.Name or "Tab Content")
    local subtitle = cfg.Subtitle ~= nil and tostring(cfg.Subtitle) or ("v"..Nihon.Version)
    local mobile = Nihon.IsMobile
    local size = mobile and Sizes.mobile or Sizes.desktop
    local baseW = tonumber(cfg.Width) or size.w
    local baseH = tonumber(cfg.Height) or size.h
    local topH = size.top

    Nihon.Folder = tostring(cfg.ConfigFolder or Nihon.Folder)
    Nihon.SaveConfig = cfg.SaveConfig == true
    if cfg.Theme and Themes[cfg.Theme] then setTheme(cfg.Theme) end
    if cfg.Font and Fonts[cfg.Font] then setFont(cfg.Font) end

    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    local Window = {Tabs={},Groups={},Name=title,Hidden=false,Minimized=false,Selected=nil,ToggleKey=toggleKey,Cfg=cfg,PageIndex=1}
    Nihon.Windows[#Nihon.Windows+1] = Window

    local searchIndex = {}
    local tabManager = {rows={}, groups={}}  -- groups = {[name]={tabs={}}}

    -- SHELL
    local shell = mk("Frame",{Name="Window",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(baseW,baseH),Visible=false,ZIndex=10,BackgroundTransparency=0.05,Parent=Root})
    bind(shell,"BackgroundColor3","Bg")
    round(shell,18); outline(shell,"Stroke",1,0.4)
    local uiScale = mk("UIScale",{Scale=0.9,Parent=shell})
    Window.Shell = shell

    local clip = mk("Frame",{Name="Clip",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=10,Parent=shell})
    round(clip,18)

    local fullH = baseH
    local closeToken = 0

    -- TOP BAR
    local topBar = mk("Frame",{Name="TopBar",Size=UDim2.new(1,0,0,topH),BackgroundTransparency=0.35,ZIndex=12,Parent=clip})
    bind(topBar,"BackgroundColor3","Surface")

    -- Brand label (left)
    tx("TextLabel",{Text=title,TextSize=13,Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(220,topH),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=15,Parent=topBar},3)

    -- Centered horizontal tabs
    local tabBar = mk("Frame",{Name="TabBar",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,500,1,-10),BackgroundTransparency=1,ZIndex=14,Parent=topBar})
    local tabScroll = mk("ScrollingFrame",{Name="Tabs",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ZIndex=14,Parent=tabBar})
    stack(tabScroll,4,Enum.FillDirection.Horizontal); inset(tabScroll,0,4,0,4)
    Window.TabScroll = tabScroll
    Window.TabBar = tabBar

    -- User dropdown (right)
    local userChip = mk("TextButton",{Name="UserChip",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-120,0.5,0),Size=UDim2.fromOffset(110,32),BackgroundTransparency=0,ZIndex=15,Parent=topBar})
    bind(userChip,"BackgroundColor3","Elevated")
    round(userChip,8); outline(userChip,"Stroke",1,0.5)
    local av = mk("ImageLabel",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,4,0.5,0),Size=UDim2.fromOffset(24,24),ZIndex=16,Parent=userChip})
    bind(av,"BackgroundColor3","Card"); round(av,12); outline(av,"Stroke",1,0.5)
    task.spawn(function()
        local ok,img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end)
        if ok and img and av.Parent then av.Image = img end
    end)
    tx("TextLabel",{Text=(LocalPlayer.DisplayName or "Guest"),TextSize=12,Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-56,1,0),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=16,Parent=userChip},2)
    local udc = makeIcon(userChip,"chevron-down",10,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),ZIndex=16})

    -- Window controls (right, outside user chip)
    local winCtl = mk("Frame",{Name="WinControls",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),Size=UDim2.fromOffset(0,32),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,ZIndex=15,Parent=topBar})
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,Parent=winCtl})
    local function winBtn(order, icon, hover)
        local b = mk("TextButton",{Size=UDim2.fromOffset(30,30),BackgroundColor3=hover or Color3.new(1,1,1),BackgroundTransparency=1,LayoutOrder=order,ZIndex=15,Parent=winCtl})
        round(b,7)
        local ic = makeIcon(b,icon,13,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=16})
        b.MouseEnter:Connect(function() play(b,0.15,{BackgroundTransparency=0.8}) end)
        b.MouseLeave:Connect(function() play(b,0.2,{BackgroundTransparency=1}) end)
        return b, ic
    end
    local minBtn, minIco = winBtn(1,"minus")
    local maxBtn = winBtn(2,"window")
    local closeBtn = winBtn(3,"x",Status.Error)

    local headLine = mk("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=13,Parent=topBar})
    bind(headLine,"BackgroundColor3","Stroke")

    -- BODY
    local body = mk("Frame",{Name="Body",Position=UDim2.fromOffset(0,topH),Size=UDim2.new(1,0,1,-topH),BackgroundTransparency=1,ZIndex=11,Parent=clip})

    -- Main content (center)
    local contentCard = mk("Frame",{Name="ContentCard",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,10),Size=UDim2.new(1,-340,1,-20),BackgroundTransparency=0.1,ZIndex=12,Parent=body})
    bind(contentCard,"BackgroundColor3","Surface")
    round(contentCard,14); outline(contentCard,"Stroke",1,0.4)

    -- Content header
    local contentHead = mk("Frame",{Name="Head",Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,ZIndex=13,Parent=contentCard})
    local chIco = makeIcon(contentHead,"window",16,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,14,0.5,0),ZIndex=14})
    Window.ContentTitle = tx("TextLabel",{Text="Tab Content",TextSize=14,Position=UDim2.fromOffset(40,0),Size=UDim2.new(1,-80,1,0),ZIndex=14,Parent=contentHead},3)
    local closeTabBtn = mk("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1,ZIndex=14,Parent=contentHead})
    local ctc = makeIcon(closeTabBtn,"x",14,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=15})
    closeTabBtn.MouseEnter:Connect(function() ctc.Color(Status.Error,true) end)
    closeTabBtn.MouseLeave:Connect(function() ctc.Color(Pal.Sub,true) end)
    closeTabBtn.Activated:Connect(function() hide() end)

    local contentLine = mk("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=13,Parent=contentHead})
    bind(contentLine,"BackgroundColor3","Stroke")

    -- Scroll container
    local content = mk("Frame",{Name="Content",Position=UDim2.fromOffset(0,40),Size=UDim2.new(1,0,1,-40),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=12,Parent=contentCard})
    Window.Content = content

    -- Empty state (icon + title, exactly like diagram)
    local empty = mk("Frame",{Name="Empty",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=13,Parent=content})
    local emptyIcon = mk("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-40),Size=UDim2.fromOffset(70,70),BackgroundColor3=Color3.new(1,1,1),ZIndex=14,Parent=empty})
    round(emptyIcon,16); bind(emptyIcon,"BackgroundColor3","Accent")
    makeIcon(emptyIcon,"window",36,false,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=15}).Color(Color3.new(1,1,1))
    tx("TextLabel",{Text="Tab Content",TextSize=22,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,30),Size=UDim2.new(1,-40,0,30),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=14,Parent=empty},3)
    tx("TextLabel",{Text="Main content area",TextSize=12,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,60),Size=UDim2.new(1,-40,0,20),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=14,Parent=empty},1,"Sub")
    tx("TextLabel",{Text="Changing with tabs",TextSize=12,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,80),Size=UDim2.new(1,-40,0,20),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=14,Parent=empty},1,"Sub")
    Window.Empty = empty

    -- LEFT COLUMN (File / Filter / Search)
    local leftCol = mk("Frame",{Name="LeftCol",Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(260,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=12,Parent=body})
    stack(leftCol,10)

    -- FILE group
    local fileCard = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.1,LayoutOrder=1,ZIndex=12,Parent=leftCol})
    bind(fileCard,"BackgroundColor3","Surface")
    round(fileCard,12); outline(fileCard,"Stroke",1,0.4)
    local fHead = mk("TextButton",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,ZIndex=13,Parent=fileCard})
    makeIcon(fHead,"folder",14,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,12,0.5,0),ZIndex=14})
    tx("TextLabel",{Text="File",TextSize=13,Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-60,1,0),ZIndex=14,Parent=fHead},3)
    makeIcon(fHead,"chevron-down",12,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),ZIndex=14})
    local fBody = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=13,Parent=fileCard})
    stack(fBody,2); inset(fBody,0,6,8,6)
    local function fileRow(order, icon, label, cb)
        local r = mk("TextButton",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=order,ZIndex=14,Parent=fBody})
        round(r,6)
        makeIcon(r,icon,14,"Sub",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=15})
        tx("TextLabel",{Text=label,TextSize=12,Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-40,1,0),ZIndex=15,Parent=r},2,"Sub")
        r.MouseEnter:Connect(function() play(r,0.12,{BackgroundTransparency=0.85}) end)
        r.MouseLeave:Connect(function() play(r,0.15,{BackgroundTransparency=1}) end)
        r.Activated:Connect(function() if cb then cb() end end)
        return r
    end
    fileRow(1,"file","New",function() Nihon:MakeNotification({Name="New",Content="Created a new file",Type="Success"}) end)
    fileRow(2,"folder","Open",function() Nihon:MakeNotification({Name="Open",Content="Open dialog",Type="Info"}) end)
    fileRow(3,"save","Save",function() Nihon:SaveProfile(); Nihon:MakeNotification({Name="Saved",Type="Success"}) end)
    fileRow(4,"save","Save As",function() Nihon:MakeNotification({Name="Save As",Type="Info"}) end)
    fileRow(5,"exit","Exit",function() hide() end)

    -- FILTER group
    local filterCard = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.1,LayoutOrder=2,ZIndex=12,Parent=leftCol})
    bind(filterCard,"BackgroundColor3","Surface")
    round(filterCard,12); outline(filterCard,"Stroke",1,0.4)
    local fltHead = mk("TextButton",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,ZIndex=13,Parent=filterCard})
    makeIcon(fltHead,"filter",14,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,12,0.5,0),ZIndex=14})
    tx("TextLabel",{Text="Filter",TextSize=13,Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-60,1,0),ZIndex=14,Parent=fltHead},3)
    makeIcon(fltHead,"chevron-down",12,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),ZIndex=14})
    local fltBody = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=13,Parent=filterCard})
    stack(fltBody,2); inset(fltBody,0,6,8,6)
    local filterOpts = {"All","Active","Inactive","Deleted"}
    local filterState = {}
    for i,name in ipairs(filterOpts) do
        local r = mk("TextButton",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=i,ZIndex=14,Parent=fltBody})
        round(r,6)
        local box = mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),Size=UDim2.fromOffset(16,16),BackgroundTransparency=0.1,ZIndex=15,Parent=r})
        bind(box,"BackgroundColor3","Elevated"); round(box,4); outline(box,"Stroke",1,0.4)
        local check = makeIcon(box,"check",10,"Accent",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Visible=false,ZIndex=16})
        tx("TextLabel",{Text=name,TextSize=12,Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-44,1,0),ZIndex=15,Parent=r},2,"Sub")
        filterState[name] = false
        r.MouseEnter:Connect(function() play(r,0.12,{BackgroundTransparency=0.85}) end)
        r.MouseLeave:Connect(function() play(r,0.15,{BackgroundTransparency=1}) end)
        r.Activated:Connect(function()
            filterState[name] = not filterState[name]
            check.Holder.Visible = filterState[name]
            play(box,0.15,{BackgroundTransparency=filterState[name] and 0 or 0.1})
        end)
    end

    -- SEARCH group
    local searchCard = mk("Frame",{Size=UDim2.new(1,0,0,42),BackgroundTransparency=0.1,LayoutOrder=3,ZIndex=12,Parent=leftCol})
    bind(searchCard,"BackgroundColor3","Surface")
    round(searchCard,10); outline(searchCard,"Stroke",1,0.4)
    local searchIcon = makeIcon(searchCard,"search",14,"Sub",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=14})
    local sInput = tx("TextBox",{Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-70,1,0),PlaceholderText="Search...",TextSize=12,ZIndex=14,Parent=searchCard},2)
    sInput.ClearTextOnFocus = false
    local sClear = mk("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1,ZIndex=14,Parent=searchCard})
    local scIco = makeIcon(sClear,"x",12,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=15})
    sClear.Activated:Connect(function() sInput.Text = "" end)
    sInput:GetPropertyChangedSignal("Text"):Connect(function()
        local q = sInput.Text:lower()
        for _,t in ipairs(Window.Tabs) do
            local vis = q=="" or t.Name:lower():find(q,1,true) ~= nil
            t.Button.Visible = vis
        end
    end)

    -- RIGHT COLUMN (Settings popup, page nav, Add dropdown, tab manager, action buttons)
    local rightCol = mk("Frame",{Name="RightCol",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,10),Size=UDim2.fromOffset(260,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=12,Parent=body})
    stack(rightCol,10)

    -- SETTINGS CARD
    local setCard = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.1,LayoutOrder=1,ZIndex=12,Parent=rightCol})
    bind(setCard,"BackgroundColor3","Surface")
    round(setCard,12); outline(setCard,"Stroke",1,0.4)
    local setHead = mk("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,ZIndex=13,Parent=setCard})
    makeIcon(setHead,"settings",14,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,12,0.5,0),ZIndex=14})
    tx("TextLabel",{Text="Settings",TextSize=13,Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-60,1,0),ZIndex=14,Parent=setHead},3)
    local setBody = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=13,Parent=setCard})
    stack(setBody,4); inset(setBody,0,8,8,8)
    -- Sound row
    local soundRow = mk("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,LayoutOrder=1,ZIndex=14,Parent=setBody})
    makeIcon(soundRow,"volume",14,"Sub",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,4,0.5,0),ZIndex=15})
    tx("TextLabel",{Text="Sound",TextSize=12,Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-80,1,0),ZIndex=15,Parent=soundRow},2,"Sub")
    local sTrack = mk("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-4,0.5,0),Size=UDim2.fromOffset(38,20),ZIndex=15,Parent=soundRow})
    bind(sTrack,"BackgroundColor3","Elevated"); round(sTrack,10)
    local sFill = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=16,Parent=sTrack})
    round(sFill,10); bind(sFill,"BackgroundColor3","Accent")
    local sKnob = mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),Size=UDim2.fromOffset(16,16),BackgroundColor3=Color3.new(1,1,1),ZIndex=18,Parent=sTrack})
    round(sKnob,8)
    local soundOn = true
    local function paintSound()
        play(sFill,0.2,{BackgroundTransparency = soundOn and 0 or 1})
        play(sKnob,0.2,{Position = UDim2.new(0, soundOn and 20 or 2, 0.5, 0)},Enum.EasingStyle.Back)
    end
    local soundBtnOverlay = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=17,Parent=sTrack})
    soundBtnOverlay.Activated:Connect(function()
        soundOn = not soundOn
        Nihon.SoundEnabled = soundOn
        paintSound()
    end)
    paintSound()
    -- Theme row
    local themeRow = mk("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,LayoutOrder=2,ZIndex=14,Parent=setBody})
    tx("TextLabel",{Text="Theme",TextSize=12,Position=UDim2.fromOffset(4,0),Size=UDim2.new(1,-110,1,0),ZIndex=15,Parent=themeRow},2,"Sub")
    local themeChip = mk("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-4,0.5,0),Size=UDim2.fromOffset(110,26),BackgroundTransparency=0,ZIndex=15,Parent=themeRow})
    bind(themeChip,"BackgroundColor3","Elevated"); round(themeChip,6); outline(themeChip,"Stroke",1,0.5)
    local themeLbl = tx("TextLabel",{Text=themeName,TextSize=12,Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-30,1,0),ZIndex=16,Parent=themeChip},2)
    makeIcon(themeChip,"chevron-down",10,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),ZIndex=16})
    themeChip.Activated:Connect(function()
        local wrap = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=300,Parent=Root})
        local catcher = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=299,Parent=wrap})
        catcher.Activated:Connect(function() wrap:Destroy() end)
        local ap = themeChip.AbsolutePosition
        local list = mk("Frame",{Position=UDim2.fromOffset(ap.X, ap.Y + themeChip.AbsoluteSize.Y + 4),Size=UDim2.fromOffset(themeChip.AbsoluteSize.X, #ThemeOrder*26+12),BackgroundTransparency=0.05,ZIndex=301,Parent=wrap})
        bind(list,"BackgroundColor3","Surface"); round(list,8); outline(list,"Stroke",1,0.4)
        stack(list,2); inset(list,6,6,6,6)
        for i,name in ipairs(ThemeOrder) do
            local row = mk("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,LayoutOrder=i,Parent=list})
            round(row,6)
            tx("TextLabel",{Text=name,TextSize=12,Size=UDim2.fromScale(1,1),Parent=row},2,"Sub")
            row.MouseEnter:Connect(function() play(row,0.12,{BackgroundTransparency=0.85}) end)
            row.MouseLeave:Connect(function() play(row,0.15,{BackgroundTransparency=1}) end)
            row.Activated:Connect(function()
                setTheme(name); themeLbl.Text = name; wrap:Destroy()
            end)
        end
    end)

    -- PAGE NAV (floating vertical)
    local pageNav = mk("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,180),Size=UDim2.fromOffset(44,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.1,ZIndex=13,Parent=body})
    bind(pageNav,"BackgroundColor3","Surface"); round(pageNav,10); outline(pageNav,"Stroke",1,0.4)
    stack(pageNav,2); inset(pageNav,6,6,6,6)
    local function pnavBtn(icon, cb)
        local b = mk("TextButton",{Size=UDim2.fromOffset(32,26),BackgroundTransparency=1,Parent=pageNav})
        round(b,6)
        local ic = makeIcon(b,icon,14,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=15})
        b.MouseEnter:Connect(function() play(b,0.12,{BackgroundTransparency=0.85}); ic.Color(Pal.Accent,true) end)
        b.MouseLeave:Connect(function() play(b,0.15,{BackgroundTransparency=1}); ic.Color(Pal.Sub,true) end)
        b.Activated:Connect(cb)
        return b
    end
    pnavBtn("plus",function() addTabPrompt() end)
    pnavBtn("minus",function() end)
    pnavBtn("chevron-up",function()
        local i = Window.Selected and Window.Selected.Index or 1
        if i > 1 then Window:SelectTab(Window.Tabs[i-1]) end
    end)
    local pNum = tx("TextLabel",{Text="1/1",TextSize=11,Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Center,Parent=pageNav},2,"Sub")
    pnavBtn("chevron-down",function()
        local i = Window.Selected and Window.Selected.Index or 1
        if i < #Window.Tabs then Window:SelectTab(Window.Tabs[i+1]) end
    end)
    Window.PageNav = pageNav
    Window.PageNum = pNum
    pnavBtn("chevron-down",function() end)

    -- ADD DROPDOWN
    local addCard = mk("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=0.1,LayoutOrder=2,ZIndex=12,Parent=rightCol})
    bind(addCard,"BackgroundColor3","Surface"); round(addCard,10); outline(addCard,"Stroke",1,0.4)
    local addBtn = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=13,Parent=addCard})
    makeIcon(addBtn,"plus",14,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=14})
    tx("TextLabel",{Text="Add",TextSize=13,Position=UDim2.fromOffset(30,0),Size=UDim2.new(1,-50,1,0),ZIndex=14,Parent=addBtn},3)
    makeIcon(addBtn,"chevron-down",12,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),ZIndex=14})

    local function addOptRow(parent, order, icon, label, cb)
        local r = mk("TextButton",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=order,Parent=parent})
        round(r,6)
        makeIcon(r,icon,14,"Sub",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=15})
        tx("TextLabel",{Text=label,TextSize=12,Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-40,1,0),ZIndex=15,Parent=r},2,"Sub")
        r.MouseEnter:Connect(function() play(r,0.12,{BackgroundTransparency=0.85}) end)
        r.MouseLeave:Connect(function() play(r,0.15,{BackgroundTransparency=1}) end)
        r.Activated:Connect(cb)
        return r
    end

    local function addTabPrompt()
        Nihon:Dialog({
            Title = "Create Tab",
            Content = "Open the Create Tab window below.",
            Buttons = {{Name="OK",Primary=true}}
        })
    end

    addBtn.Activated:Connect(function()
        local wrap = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=300,Parent=Root})
        local catcher = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=299,Parent=wrap})
        catcher.Activated:Connect(function() wrap:Destroy() end)
        local ap = addBtn.AbsolutePosition
        local list = mk("Frame",{Position=UDim2.fromOffset(ap.X - 60, ap.Y + addBtn.AbsoluteSize.Y + 4),Size=UDim2.fromOffset(170, 5*28+12),BackgroundTransparency=0.05,ZIndex=301,Parent=wrap})
        bind(list,"BackgroundColor3","Surface"); round(list,10); outline(list,"Stroke",1,0.4)
        stack(list,2); inset(list,6,6,6,6)
        addOptRow(list,1,"plus","Add Tab",function()
            wrap:Destroy()
            Window:OpenCreateTab()
        end)
        addOptRow(list,2,"layers","Add Group",function()
            wrap:Destroy()
            Nihon:Dialog({Title="Add Group",Content="Create a new group.",Buttons={{Name="OK",Primary=true}}})
        end)
        addOptRow(list,3,"minus","Add Separator",function() wrap:Destroy() end)
        addOptRow(list,4,"trash","Delete",function()
            wrap:Destroy()
            if Window.Selected then
                Nihon:Dialog({
                    Title = "Delete this Tab?",
                    Content = Window.Selected.Name,
                    Buttons = {
                        {Name="No"},
                        {Name="Yes",Primary=true,Danger=true,Callback=function()
                            local t = Window.Selected
                            pcall(function() t.Button:Destroy(); t.Page:Destroy() end)
                            for i,x in ipairs(Window.Tabs) do if x==t then table.remove(Window.Tabs,i); break end end
                            if #Window.Tabs > 0 then Window:SelectTab(Window.Tabs[1]) end
                            Window:RebuildTabManager()
                        end}
                    }
                })
            end
        end)
    end)

    -- TAB MANAGER
    local mgrCard = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.1,LayoutOrder=3,ZIndex=12,Parent=rightCol})
    bind(mgrCard,"BackgroundColor3","Surface"); round(mgrCard,12); outline(mgrCard,"Stroke",1,0.4)
    local mgrHead = mk("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,ZIndex=13,Parent=mgrCard})
    local tabsBtn = mk("TextButton",{Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(60,24),BackgroundTransparency=0,ZIndex=14,Parent=mgrHead})
    bind(tabsBtn,"BackgroundColor3","Accent"); round(tabsBtn,6)
    tx("TextLabel",{Text="Tabs",TextSize=12,Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Parent=tabsBtn},3)
    local groupsBtn = mk("TextButton",{Position=UDim2.fromOffset(74,6),Size=UDim2.fromOffset(70,24),BackgroundTransparency=1,ZIndex=14,Parent=mgrHead})
    round(groupsBtn,6)
    tx("TextLabel",{Text="Groups",TextSize=12,Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Parent=groupsBtn},2,"Sub")
    local mgrBody = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=13,Parent=mgrCard})
    stack(mgrBody,2); inset(mgrBody,0,8,8,8)

    function Window:RebuildTabManager()
        for _,r in ipairs(tabManager.rows) do r:Destroy() end
        tabManager.rows = {}
        for i,t in ipairs(Window.Tabs) do
            local r = mk("TextButton",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=i,ZIndex=14,Parent=mgrBody})
            round(r,6)
            local active = Window.Selected == t
            if active then r.BackgroundColor3 = Pal.Accent; r.BackgroundTransparency = 0 end
            makeIcon(r, t.IconName or "window", 14, active and "Text" or "Sub", {AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=15})
            local lbl = tx("TextLabel",{Text=t.Name,TextSize=12,Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-60,1,0),ZIndex=15,Parent=r},2, active and "Text" or "Sub")
            local del = mk("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=16,Parent=r})
            local dic = makeIcon(del,"x",12,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=17})
            r.MouseEnter:Connect(function() if Window.Selected ~= t then play(r,0.12,{BackgroundTransparency=0.85}) end end)
            r.MouseLeave:Connect(function() if Window.Selected ~= t then play(r,0.15,{BackgroundTransparency=1}) end end)
            r.Activated:Connect(function() Window:SelectTab(t) end)
            del.Activated:Connect(function()
                pcall(function() t.Button:Destroy(); t.Page:Destroy() end)
                for k,x in ipairs(Window.Tabs) do if x==t then table.remove(Window.Tabs,k); break end end
                if Window.Selected == t and #Window.Tabs > 0 then Window:SelectTab(Window.Tabs[1]) end
                Window:RebuildTabManager()
            end)
            tabManager.rows[i] = r
        end
        Window.PageNum.Text = (Window.Selected and Window.Selected.Index or 1) .. "/" .. math.max(#Window.Tabs,1)
    end

    -- ACTION BUTTONS
    local actionCard = mk("Frame",{Size=UDim2.new(1,0,0,80),BackgroundTransparency=0.1,LayoutOrder=4,ZIndex=12,Parent=rightCol})
    bind(actionCard,"BackgroundColor3","Surface"); round(actionCard,12); outline(actionCard,"Stroke",1,0.4)
    local actionGrid = mk("Frame",{Size=UDim2.new(1,-12,1,-12),Position=UDim2.fromOffset(6,6),BackgroundTransparency=1,ZIndex=13,Parent=actionCard})
    mk("UIGridLayout",{CellSize=UDim2.new(0.5,-4,0.5,-4),CellPadding=UDim2.fromOffset(6,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=actionGrid})
    local function actionBtn(order, icon, label, cb, danger)
        local b = mk("TextButton",{BackgroundTransparency=0,LayoutOrder=order,ZIndex=14,Parent=actionGrid})
        bind(b,"BackgroundColor3", danger and "Elevated" or "Elevated"); round(b,8); outline(b,"Stroke",1,0.5)
        local ic = makeIcon(b,icon,16,danger and "Error" or "Sub",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,6),ZIndex=15})
        tx("TextLabel",{Text=label,TextSize=11,AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-5),Size=UDim2.new(1,0,0,14),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=15,Parent=b},2, danger and "Error" or "Sub")
        b.MouseEnter:Connect(function() play(b,0.15,{BackgroundTransparency=0}) end)
        b.MouseLeave:Connect(function() play(b,0.2,{BackgroundTransparency=0}) end)
        b.Activated:Connect(cb)
        return b
    end
    actionBtn(1,"save","Save",function() Nihon:SaveProfile(); Nihon:MakeNotification({Name="Saved",Type="Success"}) end)
    actionBtn(2,"check","Apply",function() Nihon:MakeNotification({Name="Applied",Type="Success"}) end)
    actionBtn(3,"trash","Destroy",function()
        Nihon:Dialog({
            Title = "Destroy UI?",
            Content = "This will remove the whole interface.",
            Buttons = {
                {Name="Cancel"},
                {Name="Destroy",Primary=true,Danger=true,Callback=function() Nihon:Destroy() end}
            }
        })
    end, true)
    actionBtn(4,"refresh","Reset",function() Nihon:MakeNotification({Name="Reset",Type="Info"}) end)

    -- CREATE TAB WINDOW (floating card, like diagram)
    local createCard = mk("Frame",{Name="CreateTab",Visible=false,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-10,1,-10),Size=UDim2.fromOffset(260,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.05,ZIndex=200,Parent=Root})
    bind(createCard,"BackgroundColor3","Surface"); round(createCard,12); outline(createCard,"Stroke",1,0.4)
    local createScale = mk("UIScale",{Scale=0.9,Parent=createCard})
    local ccHead = mk("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,ZIndex=201,Parent=createCard})
    makeIcon(ccHead,"search",12,"Sub",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),ZIndex=202})
    tx("TextLabel",{Text="Create Tab",TextSize=12,Position=UDim2.fromOffset(28,0),Size=UDim2.new(1,-50,1,0),ZIndex=202,Parent=ccHead},3)
    local ccClose = mk("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=202,Parent=ccHead})
    makeIcon(ccClose,"x",12,"Sub",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=203})
    ccClose.Activated:Connect(function() Window:CloseCreateTab() end)
    local ccBody = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=201,Parent=createCard})
    stack(ccBody,6); inset(ccBody,0,10,10,10)
    -- Name row
    local nameRow = mk("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=1,ZIndex=202,Parent=ccBody})
    tx("TextLabel",{Text="Name:",TextSize=12,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(48,28),ZIndex=203,Parent=nameRow},2,"Sub")
    local nameBox = tx("TextBox",{Position=UDim2.fromOffset(52,0),Size=UDim2.new(1,-52,1,0),PlaceholderText="Tab name...",TextSize=12,ZIndex=203,Parent=nameRow},2)
    bind(nameBox,"BackgroundColor3","Elevated"); round(nameBox,6); inset(nameBox,0,8,0,8); outline(nameBox,"Stroke",1,0.5)
    -- Icon row
    local iconRow = mk("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=2,ZIndex=202,Parent=ccBody})
    tx("TextLabel",{Text="Icon:",TextSize=12,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(48,28),ZIndex=203,Parent=iconRow},2,"Sub")
    local iconChip = mk("TextButton",{Position=UDim2.fromOffset(52,0),Size=UDim2.new(1,-52,1,0),BackgroundTransparency=0,ZIndex=203,Parent=iconRow})
    bind(iconChip,"BackgroundColor3","Elevated"); round(iconChip,6); outline(iconChip,"Stroke",1,0.5)
    makeIcon(iconChip,"window",12,"Accent",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,8,0.5,0),ZIndex=204})
    tx("TextLabel",{Text="window",TextSize=11,Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-30,1,0),ZIndex=204,Parent=iconChip},2,"Sub")
    -- Group row
    local groupRow = mk("Frame",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=3,ZIndex=202,Parent=ccBody})
    tx("TextLabel",{Text="Group:",TextSize=12,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(48,28),ZIndex=203,Parent=groupRow},2,"Sub")
    local groupChip = mk("TextButton",{Position=UDim2.fromOffset(52,0),Size=UDim2.new(1,-52,1,0),BackgroundTransparency=0,ZIndex=203,Parent=groupRow})
    bind(groupChip,"BackgroundColor3","Elevated"); round(groupChip,6); outline(groupChip,"Stroke",1,0.5)
    tx("TextLabel",{Text="None",TextSize=11,Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-30,1,0),ZIndex=204,Parent=groupChip},2,"Sub")
    makeIcon(groupChip,"chevron-down",10,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),ZIndex=204})
    -- Create button
    local createBtn = mk("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=0,LayoutOrder=4,ZIndex=203,Parent=ccBody})
    bind(createBtn,"BackgroundColor3","Accent"); round(createBtn,8)
    tx("TextLabel",{Text="Create",TextSize=13,Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Parent=createBtn},3)
    createBtn.Activated:Connect(function()
        local nm = nameBox.Text ~= "" and nameBox.Text or "New Tab"
        Window:MakeTab({Name=nm,Icon="window"})
        Window:SelectTab(Window.Tabs[#Window.Tabs])
        Window:CloseCreateTab()
        Nihon:MakeNotification({Name="Tab Created",Content=nm,Type="Success"})
    end)

    function Window:OpenCreateTab()
        createCard.Visible = true
        play(createCard,0.25,{BackgroundTransparency=0.05})
        play(createScale,0.4,{Scale=1},Enum.EasingStyle.Back)
    end
    function Window:CloseCreateTab()
        local tw = play(createScale,0.2,{Scale=0.9})
        play(createCard,0.2,{BackgroundTransparency=1})
        after(tw,function() createCard.Visible=false end)
    end

    -- USER DROPDOWN
    userChip.Activated:Connect(function()
        local wrap = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=300,Parent=Root})
        local catcher = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=299,Parent=wrap})
        catcher.Activated:Connect(function() wrap:Destroy() end)
        local ap = userChip.AbsolutePosition
        local list = mk("Frame",{Position=UDim2.fromOffset(ap.X, ap.Y + userChip.AbsoluteSize.Y + 4),Size=UDim2.fromOffset(userChip.AbsoluteSize.X, 5*26+12),BackgroundTransparency=0.05,ZIndex=301,Parent=wrap})
        bind(list,"BackgroundColor3","Surface"); round(list,10); outline(list,"Stroke",1,0.4)
        stack(list,2); inset(list,6,6,6,6)
        for i,label in ipairs({"Profile","Inventory","Settings","About","Log out"}) do
            local row = mk("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,LayoutOrder=i,Parent=list})
            round(row,6)
            tx("TextLabel",{Text=label,TextSize=12,Size=UDim2.fromScale(1,1),Parent=row},2,"Sub")
            row.MouseEnter:Connect(function() play(row,0.12,{BackgroundTransparency=0.85}) end)
            row.MouseLeave:Connect(function() play(row,0.15,{BackgroundTransparency=1}) end)
            row.Activated:Connect(function()
                wrap:Destroy()
                if label=="Settings" then
                    for _,t in ipairs(Window.Tabs) do if t.Name=="Settings" then Window:SelectTab(t); return end end
                    if Window.AddSettingsTab then Window:AddSettingsTab() end
                else
                    Nihon:MakeNotification({Name=label,Type="Info"})
                end
            end)
        end
    end)

    -- Window controls actions
    closeBtn.Activated:Connect(function()
        hide()
        Nihon:MakeNotification({Name="Menu hidden",Content="Press "..Window.ToggleKey.Name.." to reopen.",Type="Info",Time=3})
    end)
    minBtn.Activated:Connect(function()
        local tog = not Window.Minimized
        Window.Minimized = tog
        play(minIco.Image,0.25,{Rotation=tog and 180 or 0}); play(minIco.Glyph,0.25,{Rotation=tog and 180 or 0})
        body.Visible = not tog
        play(shell,0.4,{Size=UDim2.fromOffset(shell.Size.X.Offset, tog and (topH+4) or fullH)},Enum.EasingStyle.Quint,Enum.EasingDirection.InOut)
    end)
    maxBtn.Activated:Connect(function()
        Nihon:MakeNotification({Name="Maximize",Type="Info"})
    end)

    -- Drag
    makeDraggable({topBar}, shell, {
        speed = 26,
        clamp = function(p)
            local v = viewport(); local s = shell.AbsoluteSize
            return Vector2.new(math.clamp(p.X, 0, v.X-s.X), math.clamp(p.Y, 0, v.Y-s.Y))
        end,
        canDrag = function() return not Window.Hidden end
    })

    -- Scale
    local function fitScale()
        local v = viewport()
        local fit = math.min((v.X-20)/baseW, (v.Y-20)/baseH, 1)
        return math.max(fit,0.5)
    end
    local activeScale = 1
    local function applyScale(animated)
        activeScale = fitScale(); currentScale = activeScale
        if animated then play(uiScale,0.3,{Scale=activeScale}) else uiScale.Scale = activeScale end
    end
    currentScale = 1

    local cam = workspace.CurrentCamera
    if cam then
        keep(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() if not Window.Hidden then applyScale(true) end end))
    end

    -- Launcher
    local launcher = mk("TextButton",{Name="Launcher",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,34,0.5,0),Size=UDim2.fromOffset(46,46),BackgroundColor3=Color3.new(1,1,1),Visible=false,ZIndex=250,Parent=Root})
    round(launcher,23); bind(launcher,"BackgroundColor3","Accent")
    local launcherIcon = makeIcon(launcher,"window",20,false,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=251})
    launcherIcon.Color(Color3.new(1,1,1))
    local launcherScale = mk("UIScale",{Scale=0,Parent=launcher})

    local function show()
        Window.Hidden = false
        applyScale(false)
        uiScale.Scale = activeScale*0.9
        closeToken = closeToken+1
        body.Visible = not Window.Minimized
        shell.Size = UDim2.fromOffset(shell.Size.X.Offset > 100 and shell.Size.X.Offset or baseW, Window.Minimized and (topH+4) or fullH)
        shell.Visible = true
        play(uiScale,0.5,{Scale=activeScale},Enum.EasingStyle.Back)
        if Nihon.ShowLauncher then
            launcher.Visible = true
            local tw = play(launcherScale,0.2,{Scale=0})
            after(tw,function() launcher.Visible=false end)
        end
    end
    local function hide()
        Window.Hidden = true
        closeToken = closeToken+1
        local mine = closeToken
        local tw = play(uiScale,0.22,{Scale=activeScale*0.9},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
        after(tw,function() if Window.Hidden and mine==closeToken then shell.Visible=false end end)
        if Nihon.ShowLauncher then
            task.delay(0.18,function()
                if mine==closeToken and Window.Hidden then
                    launcher.Visible = true
                    play(launcherScale,0.45,{Scale=1},Enum.EasingStyle.Back)
                end
            end)
        end
    end
    Window.Show, Window.Hide = show, hide
    function Window:Toggle() if Window.Hidden then show() else hide() end end
    launcher.Activated:Connect(function() show() end)

    keep(UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.KeyCode == Window.ToggleKey then Window:Toggle() end
    end))

    Window._parts = {
        shell=shell, clip=clip, body=body, header=topBar, content=content,
        uiScale=uiScale, applyScale=applyScale, topH=topH, mobile=mobile,
        searchIndex=searchIndex, baseW=baseW, baseH=baseH, fullH=function() return fullH end,
        launcher=launcher, launcherScale=launcherScale, createCard=createCard,
    }

    Hooks.attach(Window)
    return Window
end

-- TAB / ELEMENT API
local ElementFactory, TabImpl = nil, {}

function TabImpl.make(Window, tcfg)
    local P = Window._parts
    tcfg = tcfg or {}
    local name = tostring(tcfg.Name or "Tab")
    local Tab = {Name=name,Sections={},Window=Window,IconName=tcfg.Icon or "window"}
    local index = #Window.Tabs+1; Tab.Index = index

    -- top horizontal tab button
    local btn = mk("TextButton",{Name="Tab_"..name,Size=UDim2.fromOffset(0,28),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,LayoutOrder=index,ZIndex=15,Parent=P.TabScroll})
    round(btn,6); inset(btn,0,12,0,12)
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=btn})
    local ico = makeIcon(btn, Tab.IconName, 13, "Sub", {LayoutOrder=1,ZIndex=16})
    Tab.IconObj = ico
    local lbl = tx("TextLabel",{Text=name,TextSize=12,Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,LayoutOrder=2,ZIndex=16,Parent=btn},2,"Sub")
    Tab.Label = lbl
    Tab.Button = btn

    -- page (placed in content, over the empty state)
    local page = mk("CanvasGroup",{Name="Page_"..name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,GroupTransparency=1,Visible=false,ZIndex=14,Parent=P.content})
    local scroll = mk("ScrollingFrame",{Name="Scroll",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageTransparency=0.5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.Never,ZIndex=14,Parent=page})
    bind(scroll,"ScrollBarImageColor3","Stroke")
    inset(scroll,8,10,12,10); stack(scroll,10)
    Tab.Page, Tab.Scroll = page, scroll

    Window.Tabs[index] = Tab

    btn.MouseEnter:Connect(function()
        if Window.Selected ~= Tab then play(btn,0.15,{BackgroundTransparency=0.8}); ico.Color(Pal.Text,true) end
    end)
    btn.MouseLeave:Connect(function()
        play(btn,0.2,{BackgroundTransparency=1})
        if Window.Selected ~= Tab then ico.Color(Pal.Sub,true) end
    end)
    btn.Activated:Connect(function() Window:SelectTab(Tab) end)

    -- right-click context menu (rename / duplicate / delete)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        local wrap = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=300,Parent=Root})
        local catcher = mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=299,Parent=wrap})
        catcher.Activated:Connect(function() wrap:Destroy() end)
        local ap = btn.AbsolutePosition
        local menu = mk("Frame",{Position=UDim2.fromOffset(ap.X, ap.Y + btn.AbsoluteSize.Y + 4),Size=UDim2.fromOffset(160,3*28+12),BackgroundTransparency=0.05,ZIndex=301,Parent=wrap})
        bind(menu,"BackgroundColor3","Surface"); round(menu,10); outline(menu,"Stroke",1,0.4)
        stack(menu,2); inset(menu,6,6,6,6)
        local opts = {
            {"Rename",function() wrap:Destroy(); Nihon:Dialog({Title="Rename Tab",Content="Rename is not implemented inline.",Buttons={{Name="OK",Primary=true}}}) end},
            {"Duplicate",function()
                wrap:Destroy()
                Window:MakeTab({Name=name.." Copy",Icon=Tab.IconName})
                Window:RebuildTabManager()
            end},
            {"Delete",function()
                wrap:Destroy()
                Nihon:Dialog({
                    Title="Delete this Tab?",Content=name,
                    Buttons = {
                        {Name="No"},
                        {Name="Yes",Primary=true,Danger=true,Callback=function()
                            pcall(function() btn:Destroy(); page:Destroy() end)
                            for i,t in ipairs(Window.Tabs) do if t==Tab then table.remove(Window.Tabs,i); break end end
                            if Window.Selected==Tab and #Window.Tabs>0 then Window:SelectTab(Window.Tabs[1]) end
                            Window:RebuildTabManager()
                        end}
                    }
                })
            end}
        }
        for i,o in ipairs(opts) do
            local row = mk("TextButton",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=i,Parent=menu})
            round(row,6)
            tx("TextLabel",{Text=o[1],TextSize=12,Size=UDim2.fromScale(1,1),Parent=row},2,"Sub")
            row.MouseEnter:Connect(function() play(row,0.12,{BackgroundTransparency=0.85}) end)
            row.MouseLeave:Connect(function() play(row,0.15,{BackgroundTransparency=1}) end)
            row.Activated:Connect(o[2])
        end
    end)

    if #Window.Tabs == 1 then task.defer(function() task.wait(); Window:SelectTab(Tab,true) end) end

    local api = ElementFactory(Window, Tab, scroll, nil)

    function api:AddSection(sc)
        sc = type(sc)=="table" and sc or {Name=sc}
        local secName = tostring(sc.Name or "Section")
        local holder = mk("Frame",{Name="Sec_"..secName,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=#Tab.Sections+1,ZIndex=14,Parent=scroll})
        stack(holder,8)
        local head = mk("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,LayoutOrder=0,ZIndex=15,Parent=holder})
        local bar = mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),Size=UDim2.fromOffset(3,12),BackgroundColor3=Color3.new(1,1,1),ZIndex=16,Parent=head})
        round(bar,2); bind(bar,"BackgroundColor3","Accent")
        tx("TextLabel",{Text=string.upper(secName),TextSize=11,Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-60,1,0),ZIndex=16,Parent=head},3,"Sub")
        local body = mk("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,ZIndex=15,Parent=holder})
        stack(body,8)
        local sec = ElementFactory(Window, Tab, body, secName)
        Tab.Sections[#Tab.Sections+1] = sec
        return sec
    end

    return api
end

function TabImpl.select(Window, target, instant)
    if type(target)=="number" then target = Window.Tabs[target] end
    if type(target)=="string" then for _,t in ipairs(Window.Tabs) do if t.Name==target then target=t; break end end end
    if type(target)~="table" or not target.Button then return end
    local prev = Window.Selected
    if prev==target then return end
    Window.Selected = target

    if instant or not prev then
        for _,t in ipairs(Window.Tabs) do
            t.Page.Visible = t==target
            t.Page.GroupTransparency = t==target and 0 or 1
        end
    else
        play(prev.Page,0.16,{GroupTransparency=1})
        task.delay(0.18,function() if Window.Selected~=prev then prev.Page.Visible=false end end)
        target.Page.Visible = true; target.Page.GroupTransparency = 1
        target.Page.Position = UDim2.fromOffset(10,0)
        play(target.Page,0.34,{GroupTransparency=0})
        play(target.Page,0.4,{Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quint)
    end

    Window.Empty.Visible = #Window.Tabs == 0
    if target.Page then Window.Empty.Visible = false end

    for _,t in ipairs(Window.Tabs) do
        local active = t==target
        t.IconObj.Color(active and Pal.Accent or Pal.Sub, not instant)
        play(t.Label,0.2,{TextColor3 = active and Pal.Text or Pal.Sub})
        play(t.Button,0.2,{BackgroundTransparency = active and 0.75 or 1})
    end

    if Window.RebuildTabManager then Window:RebuildTabManager() end
    if Window.PageNum then Window.PageNum.Text = (target.Index or 1).."/"..math.max(#Window.Tabs,1) end
    if Window.ContentTitle then Window.ContentTitle.Text = target.Name end
end

-- elements
local function numFormat(v,step,suffix)
    local s
    if step < 1 then
        local frac = (tostring(step):gsub("^0%.",""))
        local places = math.min(3,math.max(1,#frac))
        s = string.format("%."..places.."f",v); s = (s:gsub("0+$","")); s = (s:gsub("%.$",""))
    else s = tostring(math.floor(v+0.5)) end
    if suffix and suffix~="" then return s.." "..suffix end
    return s
end
local function snapTo(v,step,min) if step<=0 then return v end; return min + math.floor((v-min)/step+0.5)*step end

local function extendElements(E, ctx)
    local Window, Tab, P = ctx.Window, ctx.Tab, ctx.P
    local card, nameLabel, decorate, register = ctx.card, ctx.nameLabel, ctx.decorate, ctx.register
    local mobile, rowH = ctx.mobile, ctx.rowH

    function E:AddToggle(o)
        o = o or {}
        local label = tostring(o.Name or "Toggle")
        local c = card(rowH,true)
        nameLabel(c,label,UDim2.new(1,-70,1,0))
        local track = mk("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(40,22),ZIndex=16,Parent=c})
        bind(track,"BackgroundColor3","Elevated"); round(track,11)
        local fill = mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ZIndex=17,Parent=track})
        round(fill,11); bind(fill,"BackgroundColor3","Accent")
        local knob = mk("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),Size=UDim2.fromOffset(16,16),BackgroundColor3=Color3.new(1,1,1),ZIndex=18,Parent=track})
        round(knob,8)
        local state = {value = o.Default and true or false}
        local function paint(v)
            play(fill,0.2,{BackgroundTransparency = v and 0 or 1})
            play(knob,0.2,{Position = UDim2.new(0, v and 22 or 2, 0.5, 0)},Enum.EasingStyle.Back)
        end
        function E:Set(v,silent)
            v = v and true or false; state.value = v; paint(v)
            if not silent then queueSave() end
            if o.Callback then task.spawn(function() pcall(o.Callback,v) end) end
        end
        c.Activated:Connect(function() E:Set(not state.value) end)
        register(o.Flag, E, o, function() return state.value end, function(v) E:Set(v) end)
        paint(state.value)
        return decorate(E,c,o,"Toggle")
    end

    function E:AddButton(o)
        o = o or {}
        local label = tostring(o.Name or "Button")
        local c = card(rowH,true)
        nameLabel(c,label,UDim2.new(1,-40,1,0))
        makeIcon(c,o.Icon or "chevron-right",14,"Sub",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),ZIndex=16})
        local obj = {}
        function obj:Fire()
            playSound(0.25,1.1)
            play(c,0.08,{BackgroundTransparency=0.35})
            task.delay(0.08,function() play(c,0.25,{BackgroundTransparency=0.15}) end)
            if o.Callback then task.spawn(function() pcall(o.Callback) end) end
        end
        c.Activated:Connect(function() obj:Fire() end)
        return decorate(obj,c,o,"Button")
    end

    function E:AddLabel(o)
        o = type(o)=="table" and o or {Name=o}
        local c = card(rowH-6,false); c.Active=false
        local l = nameLabel(c,o.Name or "",UDim2.new(1,-24,1,0))
        bind(l,"TextColor3","Sub")
        local obj = {}
        function obj:Set(t) l.Text = tostring(t) end
        function obj:Get() return l.Text end
        return decorate(obj,c,o,"Label")
    end

    function E:AddParagraph(o)
        o = o or {}
        local c = card(0,false)
        c.AutomaticSize = Enum.AutomaticSize.Y; c.Size = UDim2.new(1,0,0,0); c.Active=false
        inset(c,12,14,12,14); stack(c,4)
        local h = tx("TextLabel",{Text=tostring(o.Title or o.Name or "Note"),TextSize=13,Size=UDim2.new(1,0,0,18),LayoutOrder=1,Parent=c},3)
        local t = tx("TextLabel",{Text=tostring(o.Content or ""),TextSize=12,TextWrapped=true,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=2,Parent=c},1,"Sub")
        local obj = {}
        function obj:Set(x) t.Text = tostring(x) end
        function obj:SetTitle(x) h.Text = tostring(x) end
        return decorate(obj,c,o,"Paragraph")
    end

    function E:AddTextbox(o)
        o = o or {}
        local label = tostring(o.Name or "Textbox")
        local c = card(rowH,true)
        nameLabel(c,label,UDim2.new(0.4,0,1,0))
        local box = tx("TextBox",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.new(0.55,-4,0,26),Text=tostring(o.Default or ""),PlaceholderText=o.Placeholder or "type here",TextSize=12,ZIndex=16,Parent=c},2)
        bind(box,"BackgroundColor3","Elevated"); round(box,6); inset(box,0,8,0,8); outline(box,"Stroke",1,0.5)
        local obj = {Value=box.Text}
        box.FocusLost:Connect(function()
            obj.Value = box.Text; queueSave()
            if o.Callback then task.spawn(function() pcall(o.Callback, obj.Value) end) end
        end)
        function obj:Set(v) box.Text = tostring(v); obj.Value = box.Text end
        function obj:Get() return obj.Value end
        register(o.Flag,obj,o,function() return obj.Value end,function(v) obj:Set(v) end)
        return decorate(obj,c,o,"Textbox")
    end

    function E:AddSlider(o)
        o = o or {}
        local label = tostring(o.Name or "Slider")
        local min,max = tonumber(o.Min) or 0, tonumber(o.Max) or 100
        if max<=min then max=min+1 end
        local step = tonumber(o.Increment) or 1
        local c = card(56,true)
        local nm = nameLabel(c,label,UDim2.new(0.55,0,0,20)); nm.Position = UDim2.fromOffset(12,6)
        local valBox = tx("TextBox",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,6),Size=UDim2.new(0.4,0,0,20),TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=16,Parent=c},3,"Accent")
        valBox.ClearTextOnFocus = true
        local rail = mk("TextButton",{Position=UDim2.new(0,12,1,-16),Size=UDim2.new(1,-24,0,8),ZIndex=16,Parent=c})
        bind(rail,"BackgroundColor3","Elevated"); round(rail,4)
        local fill = mk("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.new(1,1,1),ZIndex=17,Parent=rail})
        round(fill,4); bind(fill,"BackgroundColor3","Accent")
        local knob = mk("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),Size=UDim2.fromOffset(14,14),BackgroundColor3=Color3.new(1,1,1),ZIndex=18,Parent=rail})
        round(knob,7)
        local value = math.clamp(tonumber(o.Default) or min, min, max)
        local obj = {Value=value}
        local function draw(frac)
            fill.Size = UDim2.new(frac,0,1,0)
            knob.Position = UDim2.new(frac,0,0.5,0)
        end
        local function commit(v)
            v = math.clamp(snapTo(v,step,min),min,max)
            obj.Value = v
            draw(math.clamp((v-min)/(max-min),0,1))
            valBox.Text = numFormat(v,step,o.ValueName or "")
            if o.Callback then task.spawn(function() pcall(o.Callback,v) end) end
            queueSave()
        end
        function obj:Set(v,silent)
            v = math.clamp(snapTo(tonumber(v) or min,step,min),min,max)
            obj.Value = v; draw(math.clamp((v-min)/(max-min),0,1)); valBox.Text = numFormat(v,step,o.ValueName or "")
            if not silent and o.Callback then task.spawn(function() pcall(o.Callback,v) end) end
        end
        function obj:Get() return obj.Value end
        local dragging = false
        trackPointer(rail, function(input)
            dragging = true
            local rel = (input.Position.X - rail.AbsolutePosition.X)/math.max(rail.AbsoluteSize.X,1)
            commit(min + (max-min)*math.clamp(rel,0,1))
        end, function(pos)
            if not dragging then return end
            local rel = (pos.X - rail.AbsolutePosition.X)/math.max(rail.AbsoluteSize.X,1)
            commit(min + (max-min)*math.clamp(rel,0,1))
        end, function() dragging = false end)
        valBox.FocusLost:Connect(function()
            local n = tonumber(valBox.Text:match("-?%d+%.?%d*"))
            if n then obj:Set(n) else valBox.Text = numFormat(obj.Value,step,o.ValueName or "") end
        end)
        register(o.Flag,obj,o,function() return obj.Value end,function(v) obj:Set(v) end)
        decorate(obj,c,o,"Slider")
        draw(math.clamp((value-min)/(max-min),0,1))
        valBox.Text = numFormat(value,step,o.ValueName or "")
        return obj
    end
end

function ElementFactory(Window, Tab, parent, sectionName)
    local P = Window._parts; local mobile = P.mobile
    local E = {_count=0}
    local rowH = mobile and 44 or 40
    local function card(height, hover)
        local c = mk("TextButton",{Size=UDim2.new(1,0,0,height or rowH),BackgroundTransparency=0.1,ZIndex=15,LayoutOrder=E._count+1,Parent=parent})
        bind(c,"BackgroundColor3","Card"); round(c,8)
        local st = outline(c,"Stroke",1,0.5)
        if hover~=false then
            c.MouseEnter:Connect(function() play(c,0.15,{BackgroundTransparency=0}); play(st,0.15,{Transparency=0.15}) end)
            c.MouseLeave:Connect(function() play(c,0.2,{BackgroundTransparency=0.1}); play(st,0.2,{Transparency=0.5}) end)
        end
        return c, st
    end
    local function nameLabel(c,text,width)
        return tx("TextLabel",{Text=tostring(text),TextSize=12,Position=UDim2.fromOffset(12,0),Size=width or UDim2.new(1,-60,1,0),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=16,Parent=c},2)
    end
    local function decorate(obj,c,opts,kind)
        E._count = E._count+1
        function obj:SetVisible(v) c.Visible = v and true or false end
        function obj:Destroy() c:Destroy() end
        obj.Card = c; obj.Kind = kind
        return obj
    end
    local function register(flag,obj,opts,get,set)
        if not flag then return end
        registerFlag(flag,{get=get,set=set,save=opts.Save==true,obj=obj})
        Nihon.Flags[flag] = obj
        if sectionName then
            table.insert(P.searchIndex,{name=(sectionName.." · "..(opts.Name or obj.Kind or "")),tab=Tab.Name,go=function() Window:SelectTab(Tab) end})
        end
    end
    extendElements(E,{Window=Window,Tab=Tab,P=P,card=card,nameLabel=nameLabel,decorate=decorate,register=register,mobile=mobile,rowH=rowH})
    return E
end

-- Default tabs to match diagram
local function buildDefaults(Window)
    local home = Window:MakeTab({Name="Home",Icon="home"})
    local sec1 = home:AddSection({Name="Dashboard"})
    sec1:AddParagraph({Title="Welcome",Content="This is the Home tab. Pick a tab above to switch content."})

    local create = Window:MakeTab({Name="Create",Icon="plus"})
    local cs = create:AddSection({Name="New"})
    cs:AddButton({Name="New Thing",Icon="plus",Callback=function() Nihon:MakeNotification({Name="Created",Type="Success"}) end})

    local edit = Window:MakeTab({Name="Edit",Icon="file"})
    edit:AddSection({Name="Edit Tools"}):AddToggle({Name="Snap to grid",Default=true})

    local view = Window:MakeTab({Name="View",Icon="window"})
    view:AddSection({Name="View Options"}):AddToggle({Name="Show sidebar",Default=true})

    local tools = Window:MakeTab({Name="Tools",Icon="settings"})
    tools:AddSection({Name="Utilities"}):AddButton({Name="Run",Icon="check",Callback=function() Nihon:MakeNotification({Name="Ran",Type="Success"}) end})

    local help = Window:MakeTab({Name="Help",Icon="info"})
    help:AddSection({Name="Help"}):AddParagraph({Title="About",Content="Nihon Lib v"..Nihon.Version})

    -- settings tab (so the settings chip finds it)
    local settingsTab = Window:MakeTab({Name="Settings",Icon="settings"})
    local look = settingsTab:AddSection({Name="Appearance"})
    look:AddSlider({Name="UI scale",Min=60,Max=130,Default=100,Increment=5,ValueName="%",Flag="_scale",Save=true,Callback=function(v) Window:SetScale(v/100) end})
    look:AddSlider({Name="Sound volume",Min=0,Max=100,Default=40,Increment=10,ValueName="%",Flag="_vol",Save=true,Callback=function(v) Nihon.SoundVolume = v/100 end})
    local cfgSec = settingsTab:AddSection({Name="Config"})
    cfgSec:AddButton({Name="Save profile",Icon="save",Callback=function() Nihon:SaveProfile(); Nihon:MakeNotification({Name="Saved",Type="Success"}) end})
    cfgSec:AddButton({Name="Load profile",Icon="folder",Callback=function() Nihon:LoadProfile(); Nihon:MakeNotification({Name="Loaded",Type="Success"}) end})

    Window:RebuildTabManager()
    Window:SelectTab(Window.Tabs[1], true)
end

function Nihon:SetTheme(n) setTheme(n) end
function Nihon:SetFont(n) setFont(n) end
function Nihon:SetSound(v) Nihon.SoundEnabled = v and true or false end
function Nihon:GetThemes() local o={}; for _,n in ipairs(ThemeOrder) do o[#o+1]=n end; return o end

local function attachWindowMethods(Window)
    function Window:MakeTab(cfg) return TabImpl.make(Window,cfg) end
    function Window:SelectTab(t,instant) TabImpl.select(Window,t,instant) end
    function Window:Notify(cfg) return Nihon:MakeNotification(cfg) end
    function Window:SetScale(s) Window.Scale = math.clamp(tonumber(s) or 1, 0.5, 1.4); Window._parts.applyScale(true) end
end

local Hooks = {attach = attachWindowMethods}

function Nihon:Init()
    if Nihon._ready then return end
    local window = Nihon.Windows[1]
    if window then
        buildDefaults(window)
        window.Show()
        Nihon._ready = true
        task.delay(0.4, function()
            Nihon:MakeNotification({Name="✨ Nihon Lib",Content="Horizontal tabs · right side controls",Type="Info",Time=6})
        end)
    end
end

function Nihon:Destroy()

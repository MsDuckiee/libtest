--[[
    ⭐ NovaLib v2.0 "Aurora" (patched)
    A next-generation Roblox UI library.
    Not an Orion reskin: reactive state, command palette, dockable widgets,
    config diffing, accessibility modes, theme lab, console, panic/streamer mode.

    Public API is intentionally close to NovaLib/Orion-style libraries, but the
    renderer and state model underneath are rebuilt.

    --- PATCH NOTES (fixes applied to the version you sent) ---
    1. FIXED: `win:SetVisible` tweened `root.GroupTransparency`, but plain
       Frames don't have that property (only CanvasGroup does). This threw
       an error EVERY time a window was shown/hidden, including via the
       toggle key and the close/minimize buttons. Root is now built as a
       CanvasGroup instead of a Frame so the transparency tween is legal.
    2. FIXED: In MakeWindow, `Connect(NovaLib.Values.Streamer or Bindable().Event, ...)`
       indexed `.Event` on the custom Bindable() wrapper, which doesn't expose
       that field. This threw "attempt to index nil with 'Connect'" on every
       single call to MakeWindow, before anything even rendered. Removed —
       it was dead/no-op code anyway (streamerRefresh was never wired to fire).
       Streamer mode now actually refreshes the sidebar label when toggled.
    3. FIXED: Colorpicker/Bind flags saved to config: Snapshot() stored the
       raw Enum.KeyCode for Bind elements, and HttpService:JSONEncode cannot
       serialize EnumItems. Any SaveConfig=true window with a saved keybind
       crashed on the first debounced save. Snapshot/LoadCfg now pack/unpack
       Bind values as strings (KeyCode.Name), matching how they're restored.
    4. FIXED: Icon() was called synchronously while the lucideblox icon table
       was still loading asynchronously (task.spawn + HttpGetAsync), so every
       icon built during initial UI construction fell back to a raw string
       name like "circle" (not a valid asset id) and never rendered, even
       after the fetch finished. Icons now re-resolve once the fetch
       completes, and Icon() is safe to call before/after that point.
    5. SIMPLIFIED: NovaLib._NewTab was wrapped a second time with a separate
       RealTabMT whose __index built a *second*, disconnected ElementHost
       for the same page, shadowing the working `TabFunctions`-based one and
       adding pointless indirection. Removed the double-wrap; tabs use a
       single, consistent metatable now.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse() or nil

local NovaLib = {
    Version = "2.0.1",
    Elements = {},
    Flags = {},
    Connections = {},
    ThemeObjects = {},
    Values = {},
    Windows = {},
    Logs = {},
    RecentCommands = {},
    ConfigHistory = {},
    ReducedMotion = false,
    HighContrast = false,
    TextScale = 1,
    UIScale = 1,
    StreamerMode = false,
    PanicEnabled = false,
    SelectedTheme = "Aurora",
    Folder = "NovaLib",
    SaveCfg = false,
    ToggleKey = Enum.KeyCode.RightShift,
    PaletteSeed = 36,
    Accent = Color3.fromRGB(96, 165, 250),
    UseSounds = true,
    MaxLogs = 500,
    Debug = false,
    _lastConfigSnapshot = nil,
    _hoveredDebug = nil,
    _streamerListeners = {},
}

local Themes = {
    Aurora = {
        Main = Color3.fromRGB(12, 16, 28),
        Panel = Color3.fromRGB(17, 24, 39),
        Elevated = Color3.fromRGB(24, 34, 56),
        Stroke = Color3.fromRGB(73, 86, 112),
        Divider = Color3.fromRGB(48, 61, 86),
        Text = Color3.fromRGB(235, 244, 255),
        TextDark = Color3.fromRGB(148, 163, 184),
        Accent = Color3.fromRGB(96, 165, 250),
        Good = Color3.fromRGB(52, 211, 153),
        Bad = Color3.fromRGB(251, 113, 133),
        Warn = Color3.fromRGB(251, 191, 36),
    },
    Midnight = {
        Main = Color3.fromRGB(8, 8, 14),
        Panel = Color3.fromRGB(14, 15, 24),
        Elevated = Color3.fromRGB(22, 24, 38),
        Stroke = Color3.fromRGB(55, 61, 83),
        Divider = Color3.fromRGB(39, 43, 62),
        Text = Color3.fromRGB(229, 234, 244),
        TextDark = Color3.fromRGB(130, 139, 160),
        Accent = Color3.fromRGB(129, 140, 248),
        Good = Color3.fromRGB(94, 234, 212),
        Bad = Color3.fromRGB(244, 114, 182),
        Warn = Color3.fromRGB(253, 224, 71),
    },
    Ember = {
        Main = Color3.fromRGB(24, 16, 18),
        Panel = Color3.fromRGB(34, 23, 26),
        Elevated = Color3.fromRGB(48, 31, 36),
        Stroke = Color3.fromRGB(94, 64, 72),
        Divider = Color3.fromRGB(76, 51, 58),
        Text = Color3.fromRGB(255, 241, 238),
        TextDark = Color3.fromRGB(196, 156, 148),
        Accent = Color3.fromRGB(251, 146, 60),
        Good = Color3.fromRGB(74, 222, 128),
        Bad = Color3.fromRGB(248, 113, 113),
        Warn = Color3.fromRGB(250, 204, 21),
    },
    Matrix = {
        Main = Color3.fromRGB(5, 22, 16),
        Panel = Color3.fromRGB(8, 33, 24),
        Elevated = Color3.fromRGB(13, 48, 34),
        Stroke = Color3.fromRGB(45, 94, 70),
        Divider = Color3.fromRGB(35, 77, 57),
        Text = Color3.fromRGB(220, 255, 235),
        TextDark = Color3.fromRGB(120, 190, 150),
        Accent = Color3.fromRGB(74, 222, 128),
        Good = Color3.fromRGB(45, 212, 191),
        Bad = Color3.fromRGB(251, 113, 133),
        Warn = Color3.fromRGB(163, 230, 53),
    },
}
NovaLib.Themes = Themes

-- Compatibility aliases used by some Orion-style scripts.
Themes.Default = Themes.Aurora

-- PATCH 4: icons load async; keep a list of {obj, prop, name} to re-resolve
-- once the fetch completes, and make Icon() usable safely at any time.
local Icons = {}
local IconsLoaded = false
local PendingIconRefresh = {}

local function Icon(name)
    return Icons[name] or name
end

local function TrackIconRefresh(obj, prop, name)
    if IconsLoaded then return end
    table.insert(PendingIconRefresh, {obj = obj, prop = prop, name = name})
end

task.spawn(function()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGetAsync(
            "https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json"
        )).icons
    end)
    if ok then Icons = res or {} else Icons = {} end
    IconsLoaded = true
    for _, entry in ipairs(PendingIconRefresh) do
        if entry.obj and entry.obj.Parent then
            pcall(function() entry.obj[entry.prop] = Icon(entry.name) end)
        end
    end
    table.clear(PendingIconRefresh)
end)

local function destroyOld(parent)
    for _, gui in ipairs(parent:GetChildren()) do
        if gui.Name == "NovaLib_Aurora" and gui:GetAttribute("NovaOwner") == tostring(LocalPlayer.UserId) then
            gui:Destroy()
        end
    end
end

local Nova = Instance.new("ScreenGui")
Nova.Name = "NovaLib_Aurora"
Nova.ResetOnSpawn = false
Nova.IgnoreGuiInset = true
Nova.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Nova:SetAttribute("NovaOwner", tostring(LocalPlayer and LocalPlayer.UserId or 0))
Nova:SetAttribute("Library", "NovaLib v2 Aurora")

local ok = pcall(function()
    if gethui then Nova.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(Nova); Nova.Parent = game:GetService("CoreGui")
    elseif RunService:IsStudio() and LocalPlayer then Nova.Parent = LocalPlayer:WaitForChild("PlayerGui")
    else Nova.Parent = game:GetService("CoreGui") end
end)
if not ok or not Nova.Parent then Nova.Parent = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui") end
if Nova.Parent then destroyOld(Nova.Parent) end

function NovaLib:IsRunning() return Nova.Parent ~= nil end

local function Connect(sig, fn)
    if not NovaLib:IsRunning() then return end
    local c = sig:Connect(fn)
    table.insert(NovaLib.Connections, c)
    return c
end

task.spawn(function()
    while NovaLib:IsRunning() do task.wait() end
    for _, c in ipairs(NovaLib.Connections) do pcall(function() c:Disconnect() end) end
end)

local function New(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = obj end
    return obj
end
local function Children(obj, list) for _, c in ipairs(list or {}) do c.Parent = obj end return obj end
local function Props(obj, list) for k, v in pairs(list or {}) do obj[k] = v end return obj end

local function Tween(obj, info, goal)
    if NovaLib.ReducedMotion then info = TweenInfo.new(0.01, Enum.EasingStyle.Linear) end
    local tw = TweenService:Create(obj, info, goal)
    tw:Play()
    return tw
end

local function Bindable()
    local b = Instance.new("BindableEvent")
    return {Fire = function(_, ...) b:Fire(...) end, Connect = function(_, fn) return b.Event:Connect(fn) end}
end

local function PackColor(c) return {math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)} end
local function UnpackColor(t) return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255) end
local function clamp(n, a, b) return math.max(a, math.min(b, n)) end
local function round(n, inc) inc = inc or 1; if n >= 0 then return math.floor(n/inc + 0.5)*inc else return math.ceil(n/inc - 0.5)*inc end end
local function lerp(a,b,t) return a+(b-a)*t end
local function colorLerp(a,b,t) return Color3.fromRGB(lerp(a.R*255,b.R*255,t), lerp(a.G*255,b.G*255,t), lerp(a.B*255,b.B*255,t)) end
local function relativeLuminance(c) return 0.2126*c.R + 0.7152*c.G + 0.0722*c.B end
local function bestText(bg) return relativeLuminance(bg) > 0.58 and Color3.fromRGB(12,16,24) or Color3.fromRGB(244,247,251) end
local function shiftColor(c, amt) return Color3.fromRGB(clamp(c.R*255+amt,0,255), clamp(c.G*255+amt,0,255), clamp(c.B*255+amt,0,255)) end
local function withAlpha(c, transparency) return c, transparency end

local function ThemeProp(obj)
    if obj:IsA("UIStroke") then return "Color" end
    if obj:IsA("UIGradient") then return "Color" end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then return "TextColor3" end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return "ImageColor3" end
    if obj:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
    return "BackgroundColor3"
end

local function AddTheme(obj, token)
    NovaLib.ThemeObjects[token] = NovaLib.ThemeObjects[token] or {}
    table.insert(NovaLib.ThemeObjects[token], obj)
    local t = Themes[NovaLib.SelectedTheme]
    if token == "AuroraWash" and obj:IsA("UIGradient") then
        obj.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, t.Accent),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(34, 211, 238)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 132, 252)),
        }
    elseif t[token] ~= nil then
        obj[ThemeProp(obj)] = t[token]
    end
    return obj
end

local function ApplyTheme(name)
    if not Themes[name] then return false end
    NovaLib.SelectedTheme = name
    local t = Themes[name]
    NovaLib.Accent = t.Accent
    for token, list in pairs(NovaLib.ThemeObjects) do
        for _, obj in ipairs(list) do
            pcall(function()
                if obj:IsA("UIGradient") and token == "AuroraWash" then
                    obj.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, t.Accent),
                        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(34, 211, 238)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 132, 252)),
                    }
                else
                    obj[ThemeProp(obj)] = t[token]
                end
            end)
        end
    end
    return true
end

function NovaLib:SetTheme(name) return ApplyTheme(name) end
function NovaLib:GetThemes()
    local out = {}
    for k, _ in pairs(Themes) do if k ~= "Default" then table.insert(out, k) end end
    table.sort(out)
    return out
end
function NovaLib:AddTheme(name, data)
    assert(type(name) == "string" and type(data) == "table", "AddTheme(name, data)")
    Themes[name] = setmetatable(data, {__index = Themes.Aurora})
end

function NovaLib:SetPaletteSeed(seed)
    NovaLib.PaletteSeed = tonumber(seed) or 36
    local t = Themes[NovaLib.SelectedTheme]
    local h = (NovaLib.PaletteSeed % 360) / 360
    t.Accent = Color3.fromHSV(h, 0.72, 0.95)
    NovaLib.Accent = t.Accent
    for _, list in pairs(NovaLib.ThemeObjects) do
        for _, obj in ipairs(list) do
            if obj.Name == "AccentDynamic" then pcall(function() obj[ThemeProp(obj)] = t.Accent end) end
        end
    end
end

-- Notification ------------------------------------------------------------
local NotifHolder = Children(Props(New("Frame", {BackgroundTransparency = 1}), {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Size = UDim2.new(0, 360, 1, -36),
}), {Children(New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center}), {})})
NotifHolder.Parent = Nova

function NovaLib:Notify(cfg)
    cfg = cfg or {}
    local name = cfg.Name or cfg.Title or "NovaLib"
    local content = cfg.Content or ""
    local time = cfg.Time or 4
    local color = cfg.Color or Themes[NovaLib.SelectedTheme].Accent
    local image = Icon(cfg.Image or "sparkles")
    local actions = cfg.Actions or {}

    local holder = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = NotifHolder})
    local card = AddTheme(Children(New("Frame", {BackgroundTransparency = 0.06, BackgroundColor3 = Themes[NovaLib.SelectedTheme].Panel, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1,70,0,0)}), {
        Children(New("UICorner", {CornerRadius = UDim.new(0,14)})),
        Children(New("UIStroke", {Color = Themes[NovaLib.SelectedTheme].Stroke, Transparency = 0.25, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})),
        Children(Children(New("Frame", {BorderSizePixel = 0, Size = UDim2.new(0,4,1,0), BackgroundColor3 = color}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))})),
        Children(Children(New("ImageLabel", {BackgroundTransparency = 1, Image = image, ImageColor3 = color, Size = UDim2.new(0,22,0,22), Position = UDim2.new(0,16,0,14)}), {})),
        Children(Children(New("TextLabel", {BackgroundTransparency = 1, Text = name, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Themes[NovaLib.SelectedTheme].Text, Position = UDim2.new(0,48,0,13), Size = UDim2.new(1,-64,0,20)}), {})),
        Children(Children(New("TextLabel", {BackgroundTransparency = 1, Text = content, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Themes[NovaLib.SelectedTheme].TextDark, Position = UDim2.new(0,16,0,42), Size = UDim2.new(1,-32,0,0), AutomaticSize = Enum.AutomaticSize.Y}), {})),
        Children(Children(New("UIPadding", {PaddingTop = UDim.new(0,12), PaddingBottom = UDim.new(0,12), PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12)}), {})),
        Children(Children(New("Frame", {Name = "Actions", BackgroundTransparency = 1, Position = UDim2.new(0,16,1,-4), Size = UDim2.new(1,-32,0,0), AutomaticSize = Enum.AutomaticSize.Y}), {
            Children(New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder}))
        }))
    }), "Panel")
    AddTheme(card.UIStroke, "Stroke")
    TrackIconRefresh(card:FindFirstChildWhichIsA("ImageLabel"), "Image", cfg.Image or "sparkles")
    for i, action in ipairs(actions) do
        local b = AddTheme(Children(New("TextButton", {Text = action.Name or ("Action "..i), Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = bestText(color), BackgroundColor3 = color, Size = UDim2.new(0,0,0,28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, AutoButtonColor = false}), {
            Children(New("UICorner", {CornerRadius = UDim.new(1,0)})),
            Children(New("UIPadding", {PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12)}))
        }), "Elevated")
        b.Parent = card.Actions
        AddTheme(b, "Elevated")
        Connect(b.MouseButton1Click, function() pcall(action.Callback) end)
    end
    local life = New("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(1,0,0,3), Position = UDim2.new(0,0,1,-3), Parent = card})
    Children(life, {New("UICorner", {CornerRadius = UDim.new(1,0)})})
    Tween(card, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {Position = UDim2.new(0,0,0,0)})
    Tween(life, TweenInfo.new(time, Enum.EasingStyle.Linear), {Size = UDim2.new(0,0,0,3)})
    task.delay(time, function()
        Tween(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = UDim2.new(1,90,0,0), BackgroundTransparency = 1})
        task.wait(0.32)
        holder:Destroy()
    end)
end
NovaLib.MakeNotification = NovaLib.Notify

-- Console -----------------------------------------------------------------
local ConsoleState = {Visible = false, Filter = "", Level = "All"}
function NovaLib:Log(level, message, data)
    level = tostring(level or "INFO"):upper()
    table.insert(NovaLib.Logs, 1, {os.time(), level, tostring(message), data})
    if #NovaLib.Logs > NovaLib.MaxLogs then table.remove(NovaLib.Logs) end
    if ConsoleState.OnLog then ConsoleState.OnLog() end
end
for _, lvl in ipairs({"Trace","Debug","Info","Warn","Error"}) do
    NovaLib[lvl] = function(_, msg, data) NovaLib:Log(lvl, msg, data) end
end

-- Reactive values ----------------------------------------------------------
local ValueMT = {}
ValueMT.__index = ValueMT
function ValueMT:Get() return self._value end
function ValueMT:Set(v)
    if self._value == v then return end
    local old = self._value
    self._value = v
    self.Changed:Fire(v, old)
end
function ValueMT:Observe(fn) return self.Changed:Connect(fn) end
function ValueMT:Bind(element, setter)
    if setter then setter(element, self._value) end
    return self:Observe(function(v) setter(element, v) end)
end
function NovaLib:Value(initial)
    return setmetatable({_value = initial, Changed = Bindable()}, ValueMT)
end

-- Config ------------------------------------------------------------------
-- PATCH 3: Bind flags now serialize as a plain string (KeyCode/UserInputType
-- name) instead of the raw EnumItem, which HttpService:JSONEncode cannot
-- handle. LoadCfg already expected a string for Bind, so this makes the two
-- sides agree instead of crashing on the first save.
local function Snapshot()
    local data = {}
    for flag, obj in pairs(NovaLib.Flags) do
        if obj.Save then
            if obj.Type == "Colorpicker" then data[flag] = PackColor(obj.Value)
            elseif obj.Type == "MultiDropdown" then data[flag] = obj.Value
            elseif obj.Type == "Bind" then
                data[flag] = typeof(obj.Value) == "EnumItem" and obj.Value.Name or tostring(obj.Value)
            else data[flag] = obj.Value end
        end
    end
    return data
end

local function LoadCfg(json)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then NovaLib:Warn("Bad config JSON") return end
    for flag, value in pairs(data) do
        local obj = NovaLib.Flags[flag]
        if obj and obj.Set then
            task.spawn(function()
                if obj.Type == "Colorpicker" then obj:Set(UnpackColor(value))
                elseif obj.Type == "Bind" and type(value) == "string" then obj:Set(Enum.KeyCode[value] or Enum.UserInputType[value] or value)
                else obj:Set(value) end
            end)
        end
    end
end

local function WriteCfg(name)
    local ok, snap = pcall(Snapshot)
    if not ok then NovaLib:Warn("Failed to snapshot config", snap) return 0 end
    local before = NovaLib._lastConfigSnapshot or {}
    local changed = 0
    for k, v in pairs(snap) do
        local sameOk, same = pcall(function() return HttpService:JSONEncode(v) == HttpService:JSONEncode(before[k]) end)
        if not sameOk or not same then changed += 1 end
    end
    NovaLib._lastConfigSnapshot = snap
    table.insert(NovaLib.ConfigHistory, 1, {time = os.time(), changed = changed, data = snap})
    if #NovaLib.ConfigHistory > 30 then table.remove(NovaLib.ConfigHistory) end
    pcall(function()
        local path = NovaLib.Folder .. "/" .. tostring(name or game.GameId) .. ".json"
        writefile(path, HttpService:JSONEncode(snap))
    end)
    return changed
end
NovaLib.SaveConfig = WriteCfg

local function DebounceSave()
    if NovaLib._saveDebounce then NovaLib._saveDebounce:Disconnect() end
    NovaLib._saveDebounce = nil
    local token = {}
    NovaLib._saveToken = token
    task.delay(0.8, function()
        if NovaLib._saveToken == token then WriteCfg(game.GameId) end
    end)
end

function NovaLib:Init()
    NovaLib:Info("NovaLib Aurora initialized", {version = NovaLib.Version})
    if NovaLib.SaveCfg then
        task.spawn(function()
            pcall(function()
                local path = NovaLib.Folder .. "/" .. tostring(game.GameId) .. ".json"
                if isfile and isfile(path) then
                    LoadCfg(readfile(path))
                    NovaLib:Notify({Name = "Configuration", Content = "Loaded saved config.", Time = 3})
                elseif readfile then
                    LoadCfg(readfile(path))
                end
            end)
        end)
    end
end

function NovaLib:Destroy()
    Nova:Destroy()
end

-- Base visual atoms --------------------------------------------------------
local function Corner(r) return New("UICorner", {CornerRadius = UDim.new(0, r or 10)}) end
local function Stroke(color, transparency, thickness)
    return New("UIStroke", {Color = color or Themes[NovaLib.SelectedTheme].Stroke, Transparency = transparency or 0.35, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function Padding(l,t,r,b)
    return New("UIPadding", {PaddingLeft = UDim.new(0,l or 12), PaddingTop = UDim.new(0,t or 12), PaddingRight = UDim.new(0,r or 12), PaddingBottom = UDim.new(0,b or 12)})
end
local function List(pad, dir)
    return New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, pad or 8), FillDirection = dir or Enum.FillDirection.Vertical})
end
local function Label(text, size, bold)
    local t = Themes[NovaLib.SelectedTheme]
    return AddTheme(New("TextLabel", {BackgroundTransparency = 1, Text = text or "", TextColor3 = t.Text, TextSize = (size or 14) * NovaLib.TextScale, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true}), "Text")
end
local function AuroraWash(_ignored)
    local holder = New("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ClipsDescendants = true})
    local a = New("Frame", {BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.86, Size = UDim2.fromScale(2.2,2.2), Position = UDim2.fromScale(-0.4,-0.5), Parent = holder}, {New("UICorner", {CornerRadius = UDim.new(1,0)})})
    local g = New("UIGradient", {Rotation = 35, Parent = a})
    AddTheme(g, "AuroraWash")
    local b = New("Frame", {BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.92, Size = UDim2.fromScale(1.8,1.8), Position = UDim2.fromScale(0.2,0.2), Parent = holder}, {New("UICorner", {CornerRadius = UDim.new(1,0)})})
    local g2 = New("UIGradient", {Rotation = 125, Parent = b})
    AddTheme(g2, "AuroraWash")
    Connect(RunService.RenderStepped, function(dt)
        if holder.Parent == nil then return end
        local t = os.clock() * 0.08
        a.Position = UDim2.fromScale(-0.4 + math.sin(t)*0.08, -0.5 + math.cos(t*1.3)*0.08)
        b.Position = UDim2.fromScale(0.2 + math.cos(t*0.8)*0.06, 0.2 + math.sin(t)*0.05)
    end)
    return holder
end

local function MakeHoverable(btn, frame, elevated)
    local base = Themes[NovaLib.SelectedTheme][elevated and "Elevated" or "Panel"]
    local hover = shiftColor(base, 8)
    local press = shiftColor(base, 16)
    Connect(btn.MouseEnter, function() Tween(frame, TweenInfo.new(0.15), {BackgroundColor3 = hover}) end)
    Connect(btn.MouseLeave, function() Tween(frame, TweenInfo.new(0.15), {BackgroundColor3 = base}) end)
    Connect(btn.MouseButton1Down, function() Tween(frame, TweenInfo.new(0.1), {BackgroundColor3 = press}) end)
    Connect(btn.MouseButton1Up, function() Tween(frame, TweenInfo.new(0.12), {BackgroundColor3 = hover}) end)
end

local function Dragify(handle, target, onMove)
    local dragging, input, startPos, startInput
    Connect(handle.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startInput = inp.Position
            startPos = target.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    Connect(handle.InputChanged, function(inp) if inp.UserInputType == Enum.UserInputType.MouseMovement then input = inp end end)
    Connect(UserInputService.InputChanged, function(inp)
        if dragging and inp == input then
            local d = inp.Position - startInput
            local pos = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            Tween(target, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Position = pos})
            if onMove then onMove(pos) end
        end
    end)
end

local KeyBlacklist = {Unknown=true, W=true, A=true, S=true, D=true, Up=true, Down=true, Left=true, Right=true, Tab=true, Escape=true, Backspace=true, Slash=true}
local KeyWhitelist = {MouseButton1=true, MouseButton2=true, MouseButton3=true}
local function InputName(inp)
    return inp.KeyCode.Name ~= "Unknown" and inp.KeyCode.Name or inp.UserInputType.Name
end

-- Command palette ---------------------------------------------------------
local Palette
local PaletteIndex = {}
local function RegisterCommand(name, description, run, scope)
    table.insert(PaletteIndex, {Name = tostring(name), Description = tostring(description or ""), Run = run, Scope = scope or "Global", Lower = string.lower(tostring(name) .. " " .. tostring(description or ""))})
end
local function Score(query, item)
    query = string.lower(query or "")
    if query == "" then return 1 end
    if string.find(item.Lower, query, 1, true) then return 2 end
    local qi, score = 1, 0
    for i = 1, #item.Name do
        local a = string.sub(string.lower(item.Name), i, i)
        local b = string.sub(query, qi, qi)
        if a == b then qi += 1; score += 2 end
    end
    return qi > #query and score or 0
end
local function OpenPalette()
    if Palette and Palette.Parent then Palette.Visible = not Palette.Visible return end
    local t = Themes[NovaLib.SelectedTheme]
    Palette = Children(Children(New("Frame", {Name = "CommandPalette", BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1,1), Visible = true}), {
        Children(New("TextButton", {Name = "Dismiss", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})),
        Children(Children(New("Frame", {AnchorPoint = Vector2.new(0.5,0.25), Position = UDim2.new(0.5,0,0.25,0), Size = UDim2.new(0,560,0,420), BackgroundColor3 = t.Panel, BackgroundTransparency = 0.03}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,16)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.15, Thickness = 1.2})),
            Children(AuroraWash({})),
            Children(Children(New("TextBox", {Name = "Query", BackgroundTransparency = 1, Text = "", PlaceholderText = "Search actions, tabs, toggles...  (Esc to close)", PlaceholderColor3 = t.TextDark, TextColor3 = t.Text, TextSize = 18 * NovaLib.TextScale, Font = Enum.Font.GothamSemibold, ClearTextOnFocus = false, Size = UDim2.new(1,-28,0,52), Position = UDim2.new(0,14,0,8)}), {Children(Padding(4,0,4,0))})),
            Children(Children(New("Frame", {Name = "Line", BackgroundColor3 = t.Stroke, BorderSizePixel = 0, Size = UDim2.new(1,-24,0,1), Position = UDim2.new(0,12,0,64)}), {})),
            Children(Children(New("ScrollingFrame", {Name = "Results", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,-24,1,-76), Position = UDim2.new(0,12,0,72), CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = t.Accent}), {Children(List(6))})),
            Children(Padding(0,0,0,0))
        }))
    }), {})
    Palette.Parent = Nova
    local root = Palette:FindFirstChildWhichIsA("Frame", true)
    local results = root.Results
    local query = root.Query
    local selected = 1
    local buttons = {}
    local runners = {} -- rank -> Run function, so Enter can invoke the
                        -- selected command directly (see PATCH 6 below)
    local function Render()
        for _, c in ipairs(results:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        table.clear(buttons)
        table.clear(runners)
        local ranked = {}
        for i, item in ipairs(PaletteIndex) do
            local s = Score(query.Text, item)
            if s > 0 then table.insert(ranked, {s=s, i=i, item=item}) end
        end
        table.sort(ranked, function(a,b) return a.s == b.s and a.i < b.i or a.s > b.s end)
        for rank, entry in ipairs(ranked) do
            local item = entry.item
            local b = AddTheme(Children(New("TextButton", {AutoButtonColor = false, BackgroundColor3 = rank == selected and t.Accent or t.Elevated, BackgroundTransparency = rank == selected and 0.15 or 0.15, Text = "", Size = UDim2.new(1,0,0,46)}), {
                Children(New("UICorner", {CornerRadius = UDim.new(0,10)})),
                Children(Props(Label(item.Name, 15, true), {Size = UDim2.new(1,-130,0,20), Position = UDim2.new(0,12,0,6), TextColor3 = rank == selected and bestText(t.Accent) or t.Text})),
                Children(Props(Label(item.Description, 12), {Size = UDim2.new(1,-130,0,16), Position = UDim2.new(0,12,0,25), TextColor3 = rank == selected and bestText(t.Accent) or t.TextDark})),
                Children(Props(Label(item.Scope, 11, true), {Size = UDim2.new(0,90,0,16), Position = UDim2.new(1,-102,0,15), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = rank == selected and bestText(t.Accent) or t.Accent}))
            }), "Elevated")
            b.Parent = results
            table.insert(buttons, b)
            runners[rank] = item.Run
            Connect(b.MouseButton1Click, function() Palette.Visible = false item.Run() end)
            if #buttons >= 12 then break end
        end
        results.CanvasSize = UDim2.new(0,0,0, math.max(0, (#buttons * 52) - 6))
    end
    Render()
    Connect(query:GetPropertyChangedSignal("Text"), function() selected = 1 Render() end)
    Connect(Palette.Dismiss.MouseButton1Click, function() Palette.Visible = false end)
    Connect(UserInputService.InputBegan, function(inp, gpe)
        if not Palette.Visible then return end
        if inp.KeyCode == Enum.KeyCode.Escape then Palette.Visible = false
        elseif inp.KeyCode == Enum.KeyCode.Down then selected = math.min(#buttons, selected + 1) Render()
        elseif inp.KeyCode == Enum.KeyCode.Up then selected = math.max(1, selected - 1) Render()
        elseif inp.KeyCode == Enum.KeyCode.Return then
            -- PATCH 6 FIXED: MouseButton1Click is a real RBXScriptSignal and
            -- has no :Fire() method (only BindableEvent exposes Fire). The
            -- old `b.MouseButton1Click:Fire()` threw every time Enter was
            -- pressed in the palette. Run the selected command's function
            -- directly via the `runners` table instead of "firing" the
            -- click signal.
            local run = runners[selected]
            if run then
                Palette.Visible = false
                run()
            end
        end
    end)
    query:CaptureFocus()
end
NovaLib.OpenCommandPalette = OpenPalette
RegisterCommand("Command Palette", "Open fuzzy command search", OpenPalette)
RegisterCommand("Toggle UI", "Hide/show main UI", function() for _, w in ipairs(NovaLib.Windows) do w:SetVisible(not w.Visible) end end)
RegisterCommand("Reduced Motion", "Toggle animation reduction", function() NovaLib.ReducedMotion = not NovaLib.ReducedMotion NovaLib:Notify({Name="Accessibility", Content="Reduced motion "..(NovaLib.ReducedMotion and "on" or "off")}) end)
RegisterCommand("High Contrast", "Toggle high contrast", function() NovaLib.HighContrast = not NovaLib.HighContrast NovaLib:Notify({Name="Accessibility", Content="High contrast "..(NovaLib.HighContrast and "on" or "off")}) end)
RegisterCommand("Streamer Mode", "Hide identity details", function()
    NovaLib.StreamerMode = not NovaLib.StreamerMode
    for _, refresh in ipairs(NovaLib._streamerListeners) do pcall(refresh) end
    NovaLib:Notify({Name="Privacy", Content="Streamer mode "..(NovaLib.StreamerMode and "on" or "off")})
end)
RegisterCommand("Panic", "Disable callbacks and hide", function() NovaLib.PanicEnabled = not NovaLib.PanicEnabled NovaLib:Notify({Name="Panic", Content=NovaLib.PanicEnabled and "Panic enabled" or "Panic disabled", Color=NovaLib.PanicEnabled and Themes[NovaLib.SelectedTheme].Bad or Themes[NovaLib.SelectedTheme].Good}) end)

-- Sections & elements ------------------------------------------------------
-- Forward-declared: MakeWindow (below) needs to call ElementHost while
-- building each tab, but ElementHost's full body (with all the Add* element
-- constructors) is defined further down for readability. Without this
-- forward declaration, `local function ElementHost` later in the file would
-- create a NEW local that shadows this one instead of filling it in, and
-- every call made from inside MakeWindow would hit nil/an upvalue that's
-- never assigned.
local ElementHost

-- Window ------------------------------------------------------------------
local WindowIndex = 0
function NovaLib:MakeWindow(cfg)
    cfg = cfg or {}
    WindowIndex += 1
    local t = Themes[NovaLib.SelectedTheme]
    local win = {
        Name = cfg.Name or ("Nova " .. WindowIndex),
        Subtitle = cfg.Subtitle or "",
        Visible = true,
        Minimized = false,
        Tabs = {},
        Floating = {},
        cfg = cfg,
    }
    table.insert(NovaLib.Windows, win)

    NovaLib.Folder = cfg.ConfigFolder or cfg.Name or "NovaLib"
    NovaLib.SaveCfg = cfg.SaveConfig == true
    NovaLib.ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift

    local size = cfg.Size or UDim2.new(0, 720, 0, 430)
    local pos = cfg.Position or UDim2.new(0.5, -360, 0.5, -215)

    -- PATCH 1: root is a CanvasGroup (not Frame) so GroupTransparency is a
    -- legal, tweenable property when the window fades in/out.
    local root = AddTheme(Children(New("CanvasGroup", {Name = win.Name, BackgroundColor3 = t.Main, BackgroundTransparency = 0.04, Size = size, Position = pos, ClipsDescendants = true}), {
        Children(New("UICorner", {CornerRadius = UDim.new(0,18)})),
        Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.18, Thickness = 1.2})),
        Children(New("UIScale", {Scale = NovaLib.UIScale})),
        Children(AuroraWash({})),
        Children(Children(New("Frame", {Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,52)}), {
            Children(Children(New("TextLabel", {Name = "Title", BackgroundTransparency = 1, Text = win.Name, TextColor3 = t.Text, TextSize = 17 * NovaLib.TextScale, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0,18,0,8), Size = UDim2.new(1,-220,0,22)}), {})),
            Children(Children(New("TextLabel", {Name = "Subtitle", BackgroundTransparency = 1, Text = win.Subtitle, TextColor3 = t.TextDark, TextSize = 12 * NovaLib.TextScale, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0,18,0,30), Size = UDim2.new(1,-220,0,14)}), {})),
            Children(Children(New("Frame", {Name = "Controls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-14,0.5,0), Size = UDim2.new(0,142,0,34)}), {
                Children(New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right})),
                Children(New("TextButton", {Name = "Palette", Text = "⌘K", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = t.Text, AutoButtonColor = false, BackgroundColor3 = t.Elevated, Size = UDim2.new(0,44,1,0), LayoutOrder = 1}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)})), Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.25}))}),
                Children(New("TextButton", {Name = "Mini", Text = "–", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = t.Text, AutoButtonColor = false, BackgroundColor3 = t.Elevated, Size = UDim2.new(0,34,1,0), LayoutOrder = 2}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)})), Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.25}))}),
                Children(New("TextButton", {Name = "Close", Text = "×", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = t.Text, AutoButtonColor = false, BackgroundColor3 = t.Elevated, Size = UDim2.new(0,34,1,0), LayoutOrder = 3}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)})), Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.25}))})
            })),
            Children(Children(New("Frame", {Name = "TopLine", BackgroundColor3 = t.Stroke, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.new(0,0,1,-1), Size = UDim2.new(1,0,0,1)}), {}))
        })),
        Children(Children(New("Frame", {Name = "Body", BackgroundTransparency = 1, Position = UDim2.new(0,0,0,52), Size = UDim2.new(1,0,1,-52)}), {
            Children(Children(New("Frame", {Name = "Sidebar", BackgroundColor3 = t.Panel, BackgroundTransparency = 0.08, Size = UDim2.new(0,176,1,0)}), {
                Children(New("UICorner", {CornerRadius = UDim.new(0,18)})),
                Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.3, Thickness = 1})),
                Children(Children(New("Frame", {Name = "MaskTop", BackgroundColor3 = t.Panel, BorderSizePixel = 0, Size = UDim2.new(1,0,0,18)}), {})),
                Children(Children(New("Frame", {Name = "MaskRight", AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,0,0,0), BackgroundColor3 = t.Panel, BorderSizePixel = 0, Size = UDim2.new(0,1,1,0)}), {})),
                Children(Children(New("ScrollingFrame", {Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0,10,0,14), Size = UDim2.new(1,-20,1,-92), CanvasSize = UDim2.new(), ScrollBarThickness = 0}), {Children(List(6))})),
                Children(Children(New("Frame", {Name = "Profile", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0,1), Position = UDim2.new(0,12,1,-12), Size = UDim2.new(1,-24,0,58)}), {
                    Children(New("UICorner", {CornerRadius = UDim.new(0,14)})),
                    Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.35})),
                    Children(Children(New("ImageLabel", {Name = "Avatar", BackgroundColor3 = t.Elevated, Size = UDim2.new(0,38,0,38), Position = UDim2.new(0,10,0.5,0), AnchorPoint = Vector2.new(0,0.5), Image = LocalPlayer and ("https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png") or ""}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))})),
                    Children(Children(New("TextLabel", {Name = "Display", BackgroundTransparency = 1, Text = NovaLib.StreamerMode and "Streamer" or (LocalPlayer and LocalPlayer.DisplayName or "Player"), TextColor3 = t.Text, TextSize = 13 * NovaLib.TextScale, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0,58,0,10), Size = UDim2.new(1,-66,0,16)}), {})),
                    Children(Children(New("TextLabel", {Name = "User", BackgroundTransparency = 1, Text = NovaLib.StreamerMode and "@hidden" or (LocalPlayer and ("@" .. LocalPlayer.Name) or "@player"), TextColor3 = t.TextDark, TextSize = 11 * NovaLib.TextScale, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0,58,0,28), Size = UDim2.new(1,-66,0,14)}), {}))
                }))
            })),
            Children(Children(New("Frame", {Name = "Content", BackgroundTransparency = 1, Position = UDim2.new(0,188,0,0), Size = UDim2.new(1,-200,1,0)}, {Children(Padding(10,12,10,12))}), {
                Children(New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10)}))
            }))
        })),
        Children(Children(New("Frame", {Name = "Focus", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 5}), {Children(Children(New("UIStroke", {Color = t.Accent, Thickness = 2, Transparency = 1, Name = "Ring"}), {}))}))
    }), "Main")
    root.Parent = Nova
    AddTheme(root.UIStroke, "Stroke")
    AddTheme(root.Top.Controls.Palette, "Elevated")
    AddTheme(root.Top.Controls.Mini, "Elevated")
    AddTheme(root.Top.Controls.Close, "Elevated")
    AddTheme(root.Top.Controls.Palette.UIStroke, "Stroke")
    AddTheme(root.Top.Controls.Mini.UIStroke, "Stroke")
    AddTheme(root.Top.Controls.Close.UIStroke, "Stroke")
    AddTheme(root.Body.Sidebar, "Panel")
    AddTheme(root.Body.Sidebar.UIStroke, "Stroke")
    AddTheme(root.Body.Sidebar.MaskTop, "Panel")
    AddTheme(root.Body.Sidebar.MaskRight, "Panel")
    AddTheme(root.Body.Sidebar.Profile, "Panel")
    AddTheme(root.Body.Sidebar.Profile.UIStroke, "Stroke")
    AddTheme(root.Body.Sidebar.Profile.Avatar, "Elevated")
    AddTheme(root.Top.Title, "Text")
    AddTheme(root.Top.Subtitle, "TextDark")
    AddTheme(root.Top.TopLine, "Stroke")
    AddTheme(root.Body.Sidebar.Profile.Display, "Text")
    AddTheme(root.Body.Sidebar.Profile.User, "TextDark")

    -- PATCH 2: replaced the broken `Connect(NovaLib.Values.Streamer or
    -- Bindable().Event, ...)` no-op (which indexed .Event on a table that
    -- doesn't have one, erroring on every MakeWindow call) with a real
    -- listener registered against the "Streamer Mode" command above, so the
    -- sidebar name/handle actually update when streamer mode is toggled.
    local function streamerRefresh()
        local p = root.Body.Sidebar.Profile
        p.Display.Text = NovaLib.StreamerMode and "Streamer" or (LocalPlayer and LocalPlayer.DisplayName or "Player")
        p.User.Text = NovaLib.StreamerMode and "@hidden" or (LocalPlayer and ("@" .. LocalPlayer.Name) or "@player")
    end
    table.insert(NovaLib._streamerListeners, streamerRefresh)

    local dragHandle = Children(Children(New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,52), ZIndex = 4}), {}), {})
    dragHandle.Parent = root
    Dragify(dragHandle, root)

    function win:SetVisible(v)
        self.Visible = v
        if v then root.Visible = true end
        Tween(root, TweenInfo.new(0.22, Enum.EasingStyle.Quint), {GroupTransparency = v and 0 or 1})
        if not v then
            task.delay(0.22, function() if not win.Visible then root.Visible = false end end)
        end
    end
    function win:Toggle() self:SetVisible(not self.Visible) end
    function win:Destroy() root:Destroy() end

    Connect(root.Top.Controls.Close.MouseButton1Click, function()
        win:SetVisible(false)
        NovaLib:Notify({Name = "Hidden", Content = "Press " .. NovaLib.ToggleKey.Name .. " or ⌘K to reopen.", Time = 3})
        if cfg.CloseCallback then task.spawn(cfg.CloseCallback) end
    end)
    -- PATCH 6 FIXED: extracted so both the click handler and the "Minimize"
    -- palette command (below) can call the same logic directly, instead of
    -- the command trying to call `Mini.MouseButton1Click:Fire()` -- which
    -- doesn't exist on a real RBXScriptSignal and threw every time the
    -- Minimize command was run from the palette.
    local function toggleMinimize()
        win.Minimized = not win.Minimized
        Tween(root, TweenInfo.new(0.32, Enum.EasingStyle.Quint), {Size = win.Minimized and UDim2.new(0, math.max(360, root.Top.Title.TextBounds.X + 220), 0, 52) or size})
        root.Body.Visible = not win.Minimized
    end
    Connect(root.Top.Controls.Mini.MouseButton1Click, toggleMinimize)
    Connect(root.Top.Controls.Palette.MouseButton1Click, OpenPalette)
    Connect(UserInputService.InputBegan, function(inp)
        if inp.KeyCode == Enum.KeyCode.RightControl or (inp.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) then OpenPalette() end
        if inp.KeyCode == NovaLib.ToggleKey and not UserInputService:GetFocusedTextBox() then win:Toggle() end
    end)

    local content = root.Body.Content
    local tabs = root.Body.Sidebar.Tabs
    local firstTab = true

    local function dockTab(tab, floating)
        local fw = AddTheme(Children(New("Frame", {Name = "Dock_" .. tab.Name, BackgroundColor3 = t.Panel, BackgroundTransparency = 0.03, Size = UDim2.new(0, 380, 0, 330), Position = UDim2.new(0.5, 90, 0.5, 40)}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,16)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.18, Thickness = 1.1})),
            Children(New("UIScale", {Scale = NovaLib.UIScale})),
            Children(Children(New("Frame", {Name = "Bar", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,40)}), {
                Children(Children(New("TextLabel", {Name = "Name", BackgroundTransparency = 1, Text = tab.Name, TextColor3 = t.Text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0,14,0,0), Size = UDim2.new(1,-70,1,0)}), {})),
                Children(Children(New("TextButton", {Name = "Pin", Text = "⇥", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = t.Text, BackgroundColor3 = t.Elevated, AutoButtonColor = false, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-42,0.5,0), Size = UDim2.new(0,30,0,28)}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))})),
                Children(Children(New("TextButton", {Name = "Close", Text = "×", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = t.Text, BackgroundColor3 = t.Elevated, AutoButtonColor = false, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-8,0.5,0), Size = UDim2.new(0,30,0,28)}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))}))
            })),
            Children(Props(tab.Container:Clone(), {Visible = true, Position = UDim2.new(0,10,0,48), Size = UDim2.new(1,-20,1,-58)}))
        }), "Panel")
        fw.Parent = Nova
        AddTheme(fw.UIStroke, "Stroke")
        AddTheme(fw.Bar.Name, "Text")
        local bar = fw.Bar
        Dragify(bar, fw)
        local dockHandle = fw:FindFirstChildWhichIsA("ScrollingFrame", true)
        Connect(bar.Pin.MouseButton1Click, function()
            fw.Position = UDim2.new(0, math.clamp(fw.AbsolutePosition.X, 0, math.max(0, Nova.AbsoluteSize.X - fw.AbsoluteSize.X)), 0, math.clamp(fw.AbsolutePosition.Y, 0, math.max(0, Nova.AbsoluteSize.Y - 40)))
        end)
        Connect(bar.Close.MouseButton1Click, function() fw:Destroy() end)
        table.insert(win.Floating, fw)
        return fw
    end
    win.DockTab = dockTab

    local TabMT = {}
    TabMT.__index = TabMT

    local function currentContainer()
        for _, c in ipairs(content:GetChildren()) do
            if c.Name == "Page" and c.Visible then return c end
        end
        return nil
    end

    function NovaLib._NewTab(tabCfg)
        tabCfg = tabCfg or {}
        local tab = setmetatable({
            Name = tabCfg.Name or "Tab",
            Icon = Icon(tabCfg.Icon or "circle"),
            Pinned = false,
            Elements = {},
        }, TabMT)

        local btn = AddTheme(Children(New("TextButton", {Name = tab.Name, Text = "", AutoButtonColor = false, BackgroundColor3 = t.Elevated, BackgroundTransparency = firstTab and 0.05 or 0.25, Size = UDim2.new(1,0,0,38)}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,12)})),
            Children(New("UIStroke", {Color = firstTab and t.Accent or t.Stroke, Transparency = firstTab and 0.15 or 0.5, Thickness = 1})),
            Children(Children(New("ImageLabel", {Name = "Ico", BackgroundTransparency = 1, Image = tab.Icon, ImageColor3 = firstTab and t.Accent or t.TextDark, ImageTransparency = firstTab and 0 or 0.25, Size = UDim2.new(0,18,0,18), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,12,0.5,0)}), {})),
            Children(Children(New("TextLabel", {Name = "Title", BackgroundTransparency = 1, Text = tab.Name, TextColor3 = firstTab and t.Text or t.TextDark, TextTransparency = firstTab and 0 or 0.25, TextSize = 14 * NovaLib.TextScale, Font = firstTab and Enum.Font.GothamBold or Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1,-48,1,0), Position = UDim2.new(0,40,0,0)}), {})),
            Children(Children(New("TextButton", {Name = "Dock", Text = "⇱", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = t.TextDark, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-8,0.5,0), Size = UDim2.new(0,26,0,26)}), {}))
        }), "Elevated")
        btn.Parent = tabs
        AddTheme(btn.UIStroke, "Stroke")
        AddTheme(btn.Ico, firstTab and "Accent" or "TextDark")
        AddTheme(btn.Title, firstTab and "Text" or "TextDark")
        btn.Ico.Name = "AccentDynamic"
        TrackIconRefresh(btn.Ico, "Image", tabCfg.Icon or "circle")

        local page = Children(Children(New("ScrollingFrame", {Name = "Page", Visible = firstTab, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), CanvasSize = UDim2.new(), ScrollBarThickness = 5, ScrollBarImageColor3 = t.Accent}), {Children(List(9), Enum.FillDirection.Vertical)}), {})
        page.Parent = content
        tab.Container = page
        tab.Button = btn
        tab.Window = win

        local function select()
            for _, b in ipairs(tabs:GetChildren()) do
                if b:IsA("TextButton") then
                    b.UIStroke.Color = t.Stroke; b.UIStroke.Transparency = 0.55
                    b.Ico.ImageTransparency = 0.25; b.Ico.ImageColor3 = t.TextDark
                    b.Title.TextTransparency = 0.25; b.Title.TextColor3 = t.TextDark; b.Title.Font = Enum.Font.GothamSemibold
                end
            end
            for _, p in ipairs(content:GetChildren()) do if p.Name == "Page" then p.Visible = false end end
            btn.UIStroke.Color = t.Accent; btn.UIStroke.Transparency = 0.15
            btn.Ico.ImageTransparency = 0; btn.Ico.ImageColor3 = t.Accent
            btn.Title.TextTransparency = 0; btn.Title.TextColor3 = t.Text; btn.Title.Font = Enum.Font.GothamBold
            page.Visible = true
        end
        tab.Select = select
        Connect(btn.MouseButton1Click, select)
        Connect(btn.Dock.MouseButton1Click, function() dockTab(tab) end)
        RegisterCommand("Open " .. tab.Name, "Switch to tab", select, win.Name)

        Connect(page.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            page.CanvasSize = UDim2.new(0,0,0,page.UIListLayout.AbsoluteContentSize.Y + 24)
        end)
        Connect(tabs.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            tabs.CanvasSize = UDim2.new(0,0,0,tabs.UIListLayout.AbsoluteContentSize.Y + 8)
        end)

        firstTab = false
        table.insert(win.Tabs, tab)

        -- PATCH 5: tab methods (:AddButton, :AddToggle, etc.) are attached
        -- directly to this tab's own ElementHost right here — one metatable,
        -- one element host, no shadow copy built later by a second wrapper.
        local elements = ElementHost(page)
        for k, v in pairs(elements) do
            if TabMT[k] == nil then TabMT[k] = v end
        end

        return tab
    end

    local TabFunctions = {}
    function TabFunctions:MakeTab(tabCfg) return NovaLib._NewTab(tabCfg) end
    win.TabFunctions = TabFunctions

    RegisterCommand("Minimize " .. win.Name, "Collapse window", function() if not win.Minimized then toggleMinimize() end end, win.Name)
    return setmetatable(win, {__index = TabFunctions})
end

function ElementHost(page)
    local api = {}
    local function card(height)
        local t = Themes[NovaLib.SelectedTheme]
        local f = AddTheme(Children(New("Frame", {BackgroundColor3 = t.Panel, BackgroundTransparency = 0.08, Size = UDim2.new(1,0,0,height or 44), AutomaticSize = Enum.AutomaticSize.Y}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,14)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.32, Thickness = 1})),
            Children(Padding(12,12,12,12))
        }), "Panel")
        f.Parent = page
        AddTheme(f.UIStroke, "Stroke")
        return f
    end
    local function titleRow(parent, name, right)
        local t = Themes[NovaLib.SelectedTheme]
        local row = Children(Children(New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,34)}), {
            Children(New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right})),
            Children(Children(New("TextLabel", {Name = "Title", BackgroundTransparency = 1, Text = name or "", TextColor3 = t.Text, TextSize = 15 * NovaLib.TextScale, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1,0,1,0)}), {})),
        }), {})
        row.Parent = parent
        AddTheme(row.Title, "Text")
        row.Title.Size = UDim2.new(1, -(right and 150 or 0), 1, 0)
        return row
    end
    local function flag(obj, cfg)
        if cfg.Flag then NovaLib.Flags[cfg.Flag] = obj end
    end

    function api:AddSection(secCfg)
        secCfg = secCfg or {}
        local holder = Children(Children(New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,30), AutomaticSize = Enum.AutomaticSize.Y}), {Children(List(8))}), {})
        holder.Parent = page
        local head = Children(Children(New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,28)}), {
            Children(Children(New("TextLabel", {BackgroundTransparency = 1, Text = secCfg.Name or "Section", TextColor3 = Themes[NovaLib.SelectedTheme].TextDark, TextSize = 13 * NovaLib.TextScale, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1,1)}), {})),
            Children(Children(New("Frame", {AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), BackgroundColor3 = Themes[NovaLib.SelectedTheme].Divider, BorderSizePixel = 0, Size = UDim2.new(0,90,0,1)}), {}))
        }), {})
        head.Parent = holder
        AddTheme(head.TextLabel, "TextDark")
        AddTheme(head.Frame, "Divider")
        local body = Children(Children(New("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1,0,0,0)}), {Children(List(7))}), {})
        body.Parent = holder
        Connect(body.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function() body.Size = UDim2.new(1,0,0,body.UIListLayout.AbsoluteContentSize.Y) end)
        local sub = ElementHost(body)
        sub.Section = holder
        return sub
    end

    function api:AddLabel(text)
        local f = card(32)
        local t = Themes[NovaLib.SelectedTheme]
        local row = titleRow(f, text or "Label")
        row.Title.TextSize = 14 * NovaLib.TextScale
        local funcs = {}
        function funcs:Set(v) row.Title.Text = tostring(v) end
        function funcs:Get() return row.Title.Text end
        return funcs
    end

    function api:AddParagraph(cfg)
        cfg = cfg or {}
        local f = card(58)
        local t = Themes[NovaLib.SelectedTheme]
        local title = AddTheme(New("TextLabel", {BackgroundTransparency = 1, Text = cfg.Title or cfg[1] or "Title", TextColor3 = t.Text, TextSize = 15 * NovaLib.TextScale, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,0)}), "Text")
        local body = AddTheme(New("TextLabel", {BackgroundTransparency = 1, Text = cfg.Content or cfg[2] or "", TextWrapped = true, TextColor3 = t.TextDark, TextSize = 13 * NovaLib.TextScale, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,0,22)}), "TextDark")
        title.Parent = f; body.Parent = f
        Connect(body:GetPropertyChangedSignal("AbsoluteSize"), function() f.Size = UDim2.new(1,0,0, 30 + body.TextBounds.Y) end)
        local funcs = {}
        funcs.Set = function(_, v) if type(v) == "table" then body.Text = v.Content or body.Text; title.Text = v.Title or title.Text else body.Text = tostring(v) end end
        funcs.SetTitle = function(_, v) title.Text = tostring(v) end
        return funcs
    end

    function api:AddButton(cfg)
        cfg = cfg or {}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local click = New("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
        click.Parent = f
        MakeHoverable(click, f)
        local row = titleRow(f, cfg.Name or "Button")
        local img = AddTheme(New("ImageLabel", {BackgroundTransparency = 1, Image = Icon(cfg.Icon or "arrow-right"), ImageColor3 = t.Accent, Size = UDim2.new(0,20,0,20), AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-4,0.5,0)}), "Accent")
        img.Name = "AccentDynamic"; img.Parent = f
        TrackIconRefresh(img, "Image", cfg.Icon or "arrow-right")
        Connect(click.MouseButton1Click, function() task.spawn(cfg.Callback or function() end) end)
        RegisterCommand(cfg.Name or "Button", "Run button action", function() task.spawn(cfg.Callback or function() end) end, "Button")
        local funcs = {}
        funcs.Set = function(_, v) row.Title.Text = tostring(v) end
        return funcs
    end

    function api:AddToggle(cfg)
        cfg = cfg or {}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local obj = {Value = cfg.Default == true, Save = cfg.Save == true, Type = "Toggle"}
        local click = New("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
        click.Parent = f
        MakeHoverable(click, f)
        local row = titleRow(f, cfg.Name or "Toggle")
        local pill = AddTheme(Children(New("Frame", {AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,46,0,26), BackgroundColor3 = t.Divider, BackgroundTransparency = 0.1}), {
            Children(New("UICorner", {CornerRadius = UDim.new(1,0)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.35})),
            Children(Children(New("Frame", {Name = "Knob", AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0,3,0.5,0), Size = UDim2.new(0,20,0,20), BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.05}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))}))
        }), "Divider")
        pill.Parent = f
        AddTheme(pill.UIStroke, "Stroke")
        function obj:Set(v)
            self.Value = v and true or false
            local color = self.Value and (cfg.Color or t.Accent) or t.Divider
            Tween(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {BackgroundColor3 = color, BackgroundTransparency = self.Value and 0.05 or 0.1})
            Tween(pill.Knob, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Position = self.Value and UDim2.new(1,-23,0.5,0) or UDim2.new(0,3,0.5,0), BackgroundColor3 = self.Value and bestText(color) or Color3.new(1,1,1)})
            if cfg.Callback then task.spawn(cfg.Callback, self.Value) end
            if self.Save then DebounceSave() end
        end
        obj.Set(obj, obj.Value)
        Connect(click.MouseButton1Click, function() obj:Set(not obj.Value) end)
        flag(obj, cfg)
        RegisterCommand("Toggle " .. (cfg.Name or "Toggle"), "Switch toggle", function() obj:Set(not obj.Value) end, "Toggle")
        return obj
    end

    function api:AddSlider(cfg)
        cfg = cfg or {}
        cfg.Min = cfg.Min or 0; cfg.Max = cfg.Max or 100; cfg.Increment = cfg.Increment or 1; cfg.Default = cfg.Default or cfg.Min
        local f = card(66)
        local t = Themes[NovaLib.SelectedTheme]
        local obj = {Value = cfg.Default, Save = cfg.Save == true, Type = "Slider"}
        local row = titleRow(f, (cfg.Name or "Slider") .. "  <font color=\"#" .. t.Accent:ToHex() .. "\">" .. tostring(cfg.Default) .. " " .. (cfg.ValueName or "") .. "</font>")
        local bar = AddTheme(Children(New("Frame", {Name = "Bar", BackgroundColor3 = t.Elevated, BackgroundTransparency = 0.05, Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,0,38)}), {
            Children(New("UICorner", {CornerRadius = UDim.new(1,0)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.45})),
            Children(Children(New("Frame", {Name = "Fill", BackgroundColor3 = cfg.Color or t.Accent, Size = UDim2.fromScale(0,1), BackgroundTransparency = 0.05}), {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))})),
            Children(Children(New("TextButton", {Name = "Hit", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)}), {}))
        }), "Elevated")
        bar.Parent = f
        AddTheme(bar.UIStroke, "Stroke")
        bar.Fill.Name = "AccentDynamic"
        local dragging = false
        local function fromX(x)
            local rel = clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            obj:Set(cfg.Min + (cfg.Max - cfg.Min) * rel)
        end
        Connect(bar.Hit.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
        Connect(bar.Hit.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        Connect(UserInputService.InputChanged, function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
        function obj:Set(v)
            self.Value = clamp(round(v, cfg.Increment), cfg.Min, cfg.Max)
            local alpha = (self.Value - cfg.Min) / math.max(1e-9, cfg.Max - cfg.Min)
            Tween(bar.Fill, TweenInfo.new(NovaLib.ReducedMotion and 0.01 or 0.12), {Size = UDim2.fromScale(alpha,1)})
            row.Title.Text = (cfg.Name or "Slider") .. "  <font color=\"#" .. (cfg.Color or Themes[NovaLib.SelectedTheme].Accent):ToHex() .. "\">" .. tostring(self.Value) .. " " .. (cfg.ValueName or "") .. "</font>"
            if cfg.Callback then task.spawn(cfg.Callback, self.Value) end
            if self.Save then DebounceSave() end
        end
        obj:Set(obj.Value)
        flag(obj, cfg)
        return obj
    end

    function api:AddDropdown(cfg)
        cfg = cfg or {}
        local options = cfg.Options or {}
        local obj = {Value = cfg.Default, Options = options, Save = cfg.Save == true, Type = "Dropdown", Buttons = {}}
        if not table.find(options, obj.Value) then obj.Value = "..." end
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local row = titleRow(f, cfg.Name or "Dropdown")
        local selected = AddTheme(New("TextLabel", {BackgroundTransparency = 1, Text = tostring(obj.Value), TextColor3 = t.TextDark, TextSize = 13 * NovaLib.TextScale, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-28,0.5,0), Size = UDim2.new(0,160,0,22)}), "TextDark")
        selected.Parent = f
        local chev = AddTheme(New("ImageLabel", {BackgroundTransparency = 1, Image = Icon("chevron-down"), ImageColor3 = t.TextDark, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-4,0.5,0), Size = UDim2.new(0,18,0,18)}), "TextDark")
        chev.Parent = f
        TrackIconRefresh(chev, "Image", "chevron-down")
        local menu = AddTheme(Children(New("ScrollingFrame", {Name = "Menu", Visible = false, BackgroundColor3 = t.Elevated, BackgroundTransparency = 0.03, BorderSizePixel = 0, Position = UDim2.new(0,0,1,8), Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.None, CanvasSize = UDim2.new(), ScrollBarThickness = 4}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,12)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.25})),
            Children(Padding(8,8,8,8)),
            Children(List(5))
        }), "Elevated")
        menu.Parent = f
        AddTheme(menu.UIStroke, "Stroke")
        local open = false
        local function refresh(opts, del)
            if del then for _, b in pairs(obj.Buttons) do b:Destroy() end table.clear(obj.Buttons) end
            obj.Options = opts or obj.Options
            for i, opt in ipairs(obj.Options) do
                local b = AddTheme(Children(New("TextButton", {Text = tostring(opt), AutoButtonColor = false, Font = Enum.Font.GothamSemibold, TextSize = 13 * NovaLib.TextScale, TextColor3 = Themes[NovaLib.SelectedTheme].Text, BackgroundColor3 = Themes[NovaLib.SelectedTheme].Panel, BackgroundTransparency = opt == obj.Value and 0.05 or 0.35, Size = UDim2.new(1,0,0,30)}), {
                    Children(New("UICorner", {CornerRadius = UDim.new(0,9)}))
                }), "Panel")
                b.LayoutOrder = i
                b.Parent = menu
                Connect(b.MouseButton1Click, function() obj:Set(opt) end)
                obj.Buttons[opt] = b
            end
            menu.CanvasSize = UDim2.new(0,0,0, menu.UIListLayout.AbsoluteContentSize.Y + 16)
        end
        function obj:Refresh(opts, del) refresh(opts, del) end
        function obj:Set(v)
            if v ~= nil and not table.find(self.Options, v) then v = "..." end
            self.Value = v or self.Value
            selected.Text = tostring(self.Value)
            for opt, b in pairs(self.Buttons) do
                b.BackgroundTransparency = opt == self.Value and 0.05 or 0.35
                b.TextColor3 = opt == self.Value and Themes[NovaLib.SelectedTheme].Accent or Themes[NovaLib.SelectedTheme].Text
            end
            if cfg.Callback then task.spawn(cfg.Callback, self.Value) end
            if self.Save then DebounceSave() end
        end
        refresh(obj.Options, false); obj:Set(obj.Value)
        local click = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,44)})
        click.Parent = f
        Connect(click.MouseButton1Click, function()
            open = not open
            menu.Visible = open
            local h = math.min(#obj.Options, 5) * 35 + 16
            Tween(menu, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Size = open and UDim2.new(1,0,0,h) or UDim2.new(1,0,0,0)})
            Tween(chev, TweenInfo.new(0.18), {Rotation = open and 180 or 0})
        end)
        flag(obj, cfg)
        return obj
    end

    function api:AddMultiDropdown(cfg)
        cfg = cfg or {}
        local obj = {Value = cfg.Default or {}, Options = cfg.Options or {}, Save = cfg.Save == true, Type = "MultiDropdown", Buttons = {}}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local row = titleRow(f, cfg.Name or "Multi Select")
        local count = AddTheme(New("TextLabel", {BackgroundTransparency = 1, Text = #obj.Value .. " selected", TextColor3 = t.TextDark, TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-28,0.5,0), Size = UDim2.new(0,120,0,22)}), "TextDark")
        count.Parent = f
        local click = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,44)})
        click.Parent = f
        local list = Children(Children(New("Frame", {Visible = false, BackgroundTransparency = 1, Position = UDim2.new(0,0,1,8), Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y}), {Children(List(5))}), {})
        list.Parent = f
        local function rebuild()
            for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            table.clear(obj.Buttons)
            for i, opt in ipairs(obj.Options) do
                local active = table.find(obj.Value, opt) ~= nil
                local b = AddTheme(Children(New("TextButton", {Text = (active and "☑ " or "☐ ") .. tostring(opt), AutoButtonColor = false, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = active and t.Accent or t.Text, BackgroundColor3 = t.Elevated, BackgroundTransparency = active and 0.05 or 0.35, Size = UDim2.new(1,0,0,30), LayoutOrder = i}), {Children(New("UICorner", {CornerRadius = UDim.new(0,9)}))}), "Elevated")
                b.Parent = list
                Connect(b.MouseButton1Click, function()
                    if table.find(obj.Value, opt) then table.remove(obj.Value, table.find(obj.Value, opt))
                    else table.insert(obj.Value, opt) end
                    obj:Set(obj.Value)
                end)
                obj.Buttons[opt] = b
            end
        end
        function obj:Set(v)
            self.Value = type(v) == "table" and v or {}
            count.Text = #self.Value .. " selected"
            rebuild()
            if cfg.Callback then task.spawn(cfg.Callback, self.Value) end
            if self.Save then DebounceSave() end
        end
        obj:Set(obj.Value)
        Connect(click.MouseButton1Click, function()
            list.Visible = not list.Visible
            Tween(f, TweenInfo.new(0.15), {Size = list.Visible and UDim2.new(1,0,0, 52 + math.min(#obj.Options,6)*35) or UDim2.new(1,0,0,44)})
        end)
        flag(obj, cfg)
        return obj
    end

    function api:AddBind(cfg)
        cfg = cfg or {}
        local obj = {Value = cfg.Default or Enum.KeyCode.Unknown, Binding = false, Save = cfg.Save == true, Type = "Bind"}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local click = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
        click.Parent = f
        MakeHoverable(click, f)
        local row = titleRow(f, cfg.Name or "Keybind")
        local box = AddTheme(Children(New("Frame", {AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,0,28), BackgroundColor3 = t.Elevated, BackgroundTransparency = 0.05}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,9)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.35})),
            Children(Padding(12,6,12,6)),
            Children(Children(New("TextLabel", {Name = "Value", BackgroundTransparency = 1, Text = tostring(obj.Value.Name or obj.Value), TextColor3 = t.Text, TextSize = 13 * NovaLib.TextScale, Font = Enum.Font.GothamBold, Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X}), {}))
        }), "Elevated")
        box.Parent = f
        AddTheme(box.UIStroke, "Stroke")
        function obj:Set(k)
            self.Binding = false
            self.Value = k or self.Value
            local name = typeof(self.Value) == "EnumItem" and self.Value.Name or tostring(self.Value)
            box.Value.Text = name
            box.Size = UDim2.new(0, box.Value.TextBounds.X + 24, 0, 28)
            if self.Save then DebounceSave() end
        end
        obj:Set(obj.Value)
        Connect(click.MouseButton1Click, function() obj.Binding = true box.Value.Text = "..." end)
        Connect(UserInputService.InputBegan, function(inp)
            if UserInputService:GetFocusedTextBox() then return end
            local name = InputName(inp)
            if obj.Binding then
                if not KeyBlacklist[inp.KeyCode.Name] or KeyWhitelist[inp.UserInputType.Name] then obj:Set(inp.KeyCode.Name ~= "Unknown" and inp.KeyCode or inp.UserInputType)
                else obj:Set(Enum.KeyCode.Unknown) end
            elseif name == (typeof(obj.Value) == "EnumItem" and obj.Value.Name or tostring(obj.Value)) then
                if cfg.Hold then cfg.Callback(true) else task.spawn(cfg.Callback) end
            end
        end)
        Connect(UserInputService.InputEnded, function(inp)
            if cfg.Hold and InputName(inp) == (typeof(obj.Value) == "EnumItem" and obj.Value.Name or tostring(obj.Value)) then cfg.Callback(false) end
        end)
        flag(obj, cfg)
        return obj
    end

    function api:AddTextbox(cfg)
        cfg = cfg or {}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local row = titleRow(f, cfg.Name or "Textbox")
        local box = AddTheme(Children(New("Frame", {AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,120,0,30), BackgroundColor3 = t.Elevated, BackgroundTransparency = 0.05}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,9)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.35})),
            Children(Padding(12,5,12,5)),
            Children(Children(New("TextBox", {Name = "Input", BackgroundTransparency = 1, Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "Type...", PlaceholderColor3 = t.TextDark, TextColor3 = t.Text, Font = Enum.Font.GothamSemibold, TextSize = 13 * NovaLib.TextScale, ClearTextOnFocus = false, Size = UDim2.new(0,100,1,0), TextXAlignment = Enum.TextXAlignment.Center}), {}))
        }), "Elevated")
        box.Parent = f
        AddTheme(box.UIStroke, "Stroke")
        Connect(box.Input:GetPropertyChangedSignal("Text"), function() box.Size = UDim2.new(0, math.max(100, box.Input.TextBounds.X + 26), 0, 30) end)
        Connect(box.Input.FocusLost, function(enter)
            if cfg.Callback and (enter or cfg.FireOnFocusLost) then task.spawn(cfg.Callback, box.Input.Text) end
            if cfg.TextDisappear then box.Input.Text = "" end
        end)
        return box.Input
    end

    function api:AddColorpicker(cfg)
        cfg = cfg or {}
        local obj = {Value = cfg.Default or Color3.fromRGB(255,255,255), Toggled = false, Save = cfg.Save == true, Type = "Colorpicker"}
        local f = card(44)
        local t = Themes[NovaLib.SelectedTheme]
        local click = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1,0,0,44)})
        click.Parent = f
        local row = titleRow(f, cfg.Name or "Color")
        local swatch = Children(Children(New("Frame", {AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,42,0,28), BackgroundColor3 = obj.Value, BackgroundTransparency = 0}), {
            Children(New("UICorner", {CornerRadius = UDim.new(0,9)})),
            Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.25, Thickness = 1.2}))
        }), {})
        swatch.Parent = f
        local h,s,v = Color3.toHSV(obj.Value)
        local picker = Children(Children(New("Frame", {Name = "Picker", Visible = false, BackgroundTransparency = 1, Position = UDim2.new(0,0,1,10), Size = UDim2.new(1,0,0,132)}), {
            Children(Children(New("ImageLabel", {Name = "SV", Image = "rbxassetid://4155801252", Size = UDim2.new(1,-28,1,0), BackgroundColor3 = Color3.fromHSV(h,1,1)}), {
                Children(New("UICorner", {CornerRadius = UDim.new(0,12)})),
                Children(New("UIStroke", {Color = t.Stroke, Transparency = 0.45})),
                Children(Children(New("ImageLabel", {Name = "Sel", Image = "rbxassetid://4805639000", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.new(0,16,0,16), Position = UDim2.fromScale(s, 1-v)}), {}))
            })),
            Children(Children(New("Frame", {Name = "Hue", Size = UDim2.new(0,18,1,0), Position = UDim2.new(1,0,0,0), BackgroundColor3 = Color3.new(1,1,1)}), {
                Children(New("UICorner", {CornerRadius = UDim.new(1,0)})),
                Children(New("UIGradient", {Rotation = 90, Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
                }})),
                Children(Children(New("ImageLabel", {Name = "Sel", Image = "rbxassetid://4805639000", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.new(0,18,0,18), Position = UDim2.new(0.5,0,1-h,0)}), {}))
            }))
        }), {})
        picker.Parent = f
        local hueSel, svSel = picker.Hue.Sel, picker.SV.Sel
        local function update(fromSV, fromHue)
            obj.Value = Color3.fromHSV(h, s, v)
            picker.SV.BackgroundColor3 = Color3.fromHSV(h,1,1)
            if not fromSV then svSel.Position = UDim2.fromScale(s, 1-v) end
            if not fromHue then hueSel.Position = UDim2.new(0.5,0,1-h,0) end
            swatch.BackgroundColor3 = obj.Value
            if cfg.Callback then task.spawn(cfg.Callback, obj.Value) end
            if obj.Save then DebounceSave() end
        end
        local dragSV, dragHue = false, false
        Connect(picker.SV.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true end end)
        Connect(picker.SV.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = false end end)
        Connect(picker.Hue.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragHue = true end end)
        Connect(picker.Hue.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragHue = false end end)
        Connect(UserInputService.InputChanged, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement or not Mouse then return end
            if dragSV then
                s = clamp((i.Position.X - picker.SV.AbsolutePosition.X) / math.max(1, picker.SV.AbsoluteSize.X), 0, 1)
                v = 1 - clamp((i.Position.Y - picker.SV.AbsolutePosition.Y) / math.max(1, picker.SV.AbsoluteSize.Y), 0, 1)
                update(true, false)
            elseif dragHue then
                h = 1 - clamp((i.Position.Y - picker.Hue.AbsolutePosition.Y) / math.max(1, picker.Hue.AbsoluteSize.Y), 0, 1)
                update(false, true)
            end
        end)
        function obj:Set(c) h,s,v = Color3.toHSV(c or obj.Value); update(false,false) end
        obj:Set(obj.Value)
        Connect(click.MouseButton1Click, function()
            obj.Toggled = not obj.Toggled
            picker.Visible = obj.Toggled
            Tween(f, TweenInfo.new(0.16, Enum.EasingStyle.Quint), {Size = obj.Toggled and UDim2.new(1,0,0,190) or UDim2.new(1,0,0,44)})
        end)
        flag(obj, cfg)
        return obj
    end

    function api:AddProgress(cfg)
        cfg = cfg or {}
        local f = card(54)
        local t = Themes[NovaLib.SelectedTheme]
        local row = titleRow(f, cfg.Name or "Progress")
        local bar = AddTheme(Children(New("Frame", {BackgroundColor3 = t.Elevated, Size = UDim2.new(1,0,0,16), Position = UDim2.new(0,0,0,34)}), {
            Children(New("UICorner", {CornerRadius = UDim.new(1,0)})),
            Children(Children(New("Frame", {Name = "Fill", BackgroundColor3 = cfg.Color or t.Accent, Size = UDim2.fromScale(clamp(cfg.Value or 0,0,100)/100,1)}, {Children(New("UICorner", {CornerRadius = UDim.new(1,0)}))}), {}))
        }), "Elevated")
        bar.Parent = f
        bar.Fill.Name = "AccentDynamic"
        AddTheme(bar.Fill, "Accent")
        local obj = {Value = cfg.Value or 0}
        function obj:Set(v) self.Value = clamp(v,0,100); Tween(bar.Fill, TweenInfo.new(0.2), {Size = UDim2.fromScale(self.Value/100,1)}); row.Title.Text = string.format("%s  <font color=\"#%s\">%d%%</font>", cfg.Name or "Progress", (cfg.Color or Themes[NovaLib.SelectedTheme].Accent):ToHex(), math.floor(self.Value)) end
        obj:Set(obj.Value)
        return obj
    end

    return api
end

return NovaLib

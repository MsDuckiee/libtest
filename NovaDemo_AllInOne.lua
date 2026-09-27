--[[
    ⭐ NovaLib v2.0.2 "Aurora" — ALL-IN-ONE BUILD
    Library + feature demo in ONE file. No URL, no external files.
    Run THIS script only. RightShift toggles UI, Ctrl+K = palette.
--]]

local NovaLib = (function()
--[[
    ⭐ NovaLib v2.0 "Aurora" (patched)
    A next-generation Roblox UI library.
    Not an Orion reskin: reactive state, command palette, dockable widgets,
    config diffing, accessibility modes, theme lab, console, panic/streamer mode.

    Public API is intentionally close to NovaLib/Orion-style libraries, but the
    renderer and state model underneath are rebuilt.

    --- PATCH NOTES ---
    1. FIXED: `win:SetVisible` tweened `root.GroupTransparency`, but plain
       Frames don't have that property (only CanvasGroup does). Root is now
       built as a CanvasGroup instead of a Frame.
    2. FIXED: MakeWindow indexed `.Event` on the custom Bindable() wrapper,
       which doesn't expose that field. Removed — streamer mode now refreshes
       the sidebar label via real listeners.
    3. FIXED: Colorpicker/Bind flags saved to config stored the raw EnumItem
       which HttpService:JSONEncode cannot serialize. Snapshot/LoadCfg now
       pack/unpack Bind values as strings.
    4. FIXED: Icon() was called synchronously while lucideblox icons were
       still loading asynchronously. Icons now re-resolve once the fetch
       completes.
    5. SIMPLIFIED: removed the double TabMT wrap in _NewTab.
    6. FIXED: Palette Enter now runs the selected command directly instead
       of trying to `:Fire()` a real RBXScriptSignal.
    7. FIXED: Filesystem capability is now probed explicitly (type(readfile)
       == "function" etc.) instead of relying on `pcall` catching a missing
       global — executors that silently swallow missing globals no longer
       crash on config save/load.
    8. FIXED: Config folder is auto-created via makefolder before the first
       write. writefile failures are logged, not swallowed.
    9. FIXED: LoadCfg no longer feeds `nil` into JSONDecode when the file is
       missing and `isfile` isn't shipped. Read is guarded.
   10. FIXED: Init() only attempts a config load when there's a confirmed
       file on disk.
   11. FIXED: WriteCfg logs a Warn (debug mode) when the FS isn't available
       instead of silently returning 0.
]]

local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")
local HttpService     = game:GetService("HttpService")
local SoundService    = game:GetService("SoundService")
local LocalPlayer     = Players.LocalPlayer
local Mouse           = LocalPlayer and LocalPlayer:GetMouse() or nil

-- ═══════════════════════════════════════════════════════════════════════════
-- PATCH 7: Filesystem capability probe.
-- Executors vary wildly: some ship readfile/writefile/isfile/makefolder as
-- real globals, some ship only a subset, some ship them but as userdata
-- proxies. We probe by *type* once at load time and never poke a global
-- that doesn't exist, so we never trigger the "attempt to call a nil value"
-- class of failures the old pcall-wrapped code sometimes did.
-- ═══════════════════════════════════════════════════════════════════════════
local FS = {
    readfile   = type(readfile)   == "function" and readfile   or nil,
    writefile  = type(writefile)  == "function" and writefile  or nil,
    isfile     = type(isfile)     == "function" and isfile     or nil,
    makefolder = type(makefolder) == "function" and makefolder or nil,
    appendfile = type(appendfile) == "function" and appendfile or nil,
    listfiles  = type(listfiles)  == "function" and listfiles  or nil,
    delfile    = type(delfile)    == "function" and delfile    or nil,
}
FS.canRead   = FS.readfile ~= nil
FS.canWrite  = FS.writefile ~= nil
FS.canCheck  = FS.isfile ~= nil
FS.canFolder = FS.makefolder ~= nil
FS.available = FS.canRead or FS.canWrite

-- Safe wrappers. Return (ok, value) so callers can decide.
local function fsRead(path)
    if not FS.canRead then return false, "no readfile" end
    local ok, res = pcall(FS.readfile, path)
    if not ok then return false, res end
    if type(res) ~= "string" then return false, "readfile returned non-string" end
    return true, res
end
local function fsWrite(path, data)
    if not FS.canWrite then return false, "no writefile" end
    local ok, res = pcall(FS.writefile, path, data)
    if not ok then return false, res end
    -- some executors return false instead of throwing on failure
    if res == false then return false, "writefile returned false" end
    return true
end
local function fsExists(path)
    if not FS.canCheck then
        -- fall back to a read attempt
        return select(1, fsRead(path))
    end
    local ok, res = pcall(FS.isfile, path)
    return ok and res == true
end
local function fsEnsureFolder(path)
    if not FS.canFolder then return true end -- nothing we can do; let write try
    if path == "" or path == nil then return true end
    pcall(FS.makefolder, path)
    return true
end

local NovaLib = {
    Version = "2.0.2",
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
    _folderReady = false,   -- set once makefolder has run for the active folder
}
NovaLib.FS = FS   -- expose for user scripts that want to check capabilities

local Themes = {
    Aurora = {
        Main = Color3.fromRGB(12, 16, 28), Panel = Color3.fromRGB(17, 24, 39),
        Elevated = Color3.fromRGB(24, 34, 56), Stroke = Color3.fromRGB(73, 86, 112),
        Divider = Color3.fromRGB(48, 61, 86), Text = Color3.fromRGB(235, 244, 255),
        TextDark = Color3.fromRGB(148, 163, 184), Accent = Color3.fromRGB(96, 165, 250),
        Good = Color3.fromRGB(52, 211, 153), Bad = Color3.fromRGB(251, 113, 133),
        Warn = Color3.fromRGB(251, 191, 36),
    },
    Midnight = {
        Main = Color3.fromRGB(8, 8, 14), Panel = Color3.fromRGB(14, 15, 24),
        Elevated = Color3.fromRGB(22, 24, 38), Stroke = Color3.fromRGB(55, 61, 83),
        Divider = Color3.fromRGB(39, 43, 62), Text = Color3.fromRGB(229, 234, 244),
        TextDark = Color3.fromRGB(130, 139, 160), Accent = Color3.fromRGB(129, 140, 248),
        Good = Color3.fromRGB(94, 234, 212), Bad = Color3.fromRGB(244, 114, 182),
        Warn = Color3.fromRGB(253, 224, 71),
    },
    Ember = {
        Main = Color3.fromRGB(24, 16, 18), Panel = Color3.fromRGB(34, 23, 26),
        Elevated = Color3.fromRGB(48, 31, 36), Stroke = Color3.fromRGB(94, 64, 72),
        Divider = Color3.fromRGB(76, 51, 58), Text = Color3.fromRGB(255, 241, 238),
        TextDark = Color3.fromRGB(196, 156, 148), Accent = Color3.fromRGB(251, 146, 60),
        Good = Color3.fromRGB(74, 222, 128), Bad = Color3.fromRGB(248, 113, 113),
        Warn = Color3.fromRGB(250, 204, 21),
    },
    Matrix = {
        Main = Color3.fromRGB(5, 22, 16), Panel = Color3.fromRGB(8, 33, 24),
        Elevated = Color3.fromRGB(13, 48, 34), Stroke = Color3.fromRGB(45, 94, 70),
        Divider = Color3.fromRGB(35, 77, 57), Text = Color3.fromRGB(220, 255, 235),
        TextDark = Color3.fromRGB(120, 190, 150), Accent = Color3.fromRGB(74, 222, 128),
        Good = Color3.fromRGB(45, 212, 191), Bad = Color3.fromRGB(251, 113, 133),
        Warn = Color3.fromRGB(163, 230, 53),
    },
}
NovaLib.Themes = Themes
Themes.Default = Themes.Aurora

-- ─── Icons (async, re-resolve on completion) ─────────────────────────────
local Icons = {}
local IconsLoaded = false
local PendingIconRefresh = {}

local function Icon(name)
    local e = Icons[name]
    if type(e) == "string" then return e end
    if type(e) == "table" then for _, v in pairs(e) do if type(v) == "string" then return v end end end
    return name
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
    Icons = (ok and res) or {}
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
if not ok or not Nova.Parent then
    Nova.Parent = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
end
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

-- ─── Notifications ───────────────────────────────────────────────────────
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

-- ─── Console ─────────────────────────────────────────────────────────────
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

-- ─── Reactive values ─────────────────────────────────────────────────────
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

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG (PATCHES 3, 8, 9, 10, 11)
-- ═══════════════════════════════════════════════════════════════════════════
local function configPath(name)
    return NovaLib.Folder .. "/" .. tostring(name or game.GameId) .. ".json"
end

local function ensureFolder()
    -- PATCH 8: makefolder once per Folder value so writefile doesn't fail
    -- with "folder not found" on executors that enforce it (many do).
    if NovaLib._folderReady then return end
    if not FS.canFolder then
        -- Nothing we can do, but mark as "ready" so we don't retry every save.
        NovaLib._folderReady = true
        return
    end
    local folder = NovaLib.Folder
    if type(folder) ~= "string" or folder == "" then
        NovaLib._folderReady = true
        return
    end
    pcall(FS.makefolder, folder)
    -- some executors support nested folders with "/" but not empty components
    -- so we also try each level individually (harmless if it already exists)
    for level in folder:gmatch("[^/]+") do
        pcall(FS.makefolder, level)
    end
    NovaLib._folderReady = true
end

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
    -- PATCH 9: refuse to run on nil/non-string JSON. The old code fed
    -- whatever readfile returned into JSONDecode, which spat out a fake
    -- "Bad config JSON" warning if the read had failed.
    if type(json) ~= "string" or json == "" then
        NovaLib:Warn("LoadCfg called with empty/nil payload")
        return false
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then
        NovaLib:Warn("Bad config JSON")
        return false
    end
    for flag, value in pairs(data) do
        local obj = NovaLib.Flags[flag]
        if obj and obj.Set then
            task.spawn(function()
                if obj.Type == "Colorpicker" then obj:Set(UnpackColor(value))
                elseif obj.Type == "Bind" and type(value) == "string" then
                    obj:Set(Enum.KeyCode[value] or Enum.UserInputType[value] or value)
                else obj:Set(value) end
            end)
        end
    end
    return true
end

local function WriteCfg(name)
    if not FS.canWrite then
        -- PATCH 11: log once when we can't persist, so users know why the
        -- config never shows up on disk.
        if NovaLib.Debug then
            NovaLib:Warn("Config save skipped: executor has no writefile")
        end
        return 0
    end
    local ok, snap = pcall(Snapshot)
    if not ok then NovaLib:Warn("Failed to snapshot config", snap) return 0 end

    local before = NovaLib._lastConfigSnapshot or {}
    local changed = 0
    for k, v in pairs(snap) do
        local sameOk, same = pcall(function()
            return HttpService:JSONEncode(v) == HttpService:JSONEncode(before[k])
        end)
        if not sameOk or not same then changed += 1 end
    end
    NovaLib._lastConfigSnapshot = snap

    table.insert(NovaLib.ConfigHistory, 1, {time = os.time(), changed = changed, data = snap})
    if #NovaLib.ConfigHistory > 30 then table.remove(NovaLib.ConfigHistory) end

    ensureFolder()
    local path = configPath(name)
    local wrote, err = fsWrite(path, HttpService:JSONEncode(snap))
    if not wrote and NovaLib.Debug then
        NovaLib:Warn("writefile failed: " .. tostring(err) .. " (" .. path .. ")")
    end
    return changed
end
NovaLib.SaveConfig = WriteCfg

local function DebounceSave()
    if not FS.canWrite then return end
    local token = {}
    NovaLib._saveToken = token
    task.delay(0.8, function()
        if NovaLib._saveToken == token then WriteCfg(game.GameId) end
    end)
end

function NovaLib:Init()
    NovaLib:Info("NovaLib Aurora initialized", {version = NovaLib.Version, fs = FS.available})
    if NovaLib.SaveCfg then
        task.spawn(function()
            -- PATCH 10: only load if the file demonstrably exists.
            ensureFolder()
            local path = configPath(game.GameId)
            if not FS.canRead then
                if NovaLib.Debug then
                    NovaLib:Warn("Config load skipped: executor has no readfile")
                end
                return
            end
            if not fsExists(path) then
                -- Fresh install; nothing to load. Not a warning.
                return
            end
            local readOk, payload = fsRead(path)
            if not readOk then
                NovaLib:Warn("Config read failed: " .. tostring(payload))
                return
            end
            if LoadCfg(payload) then
                NovaLib:Notify({Name = "Configuration", Content = "Loaded saved config.", Time = 3})
            end
        end)
    end
end

function NovaLib:Destroy()
    Nova:Destroy()
end

-- ─── Base visual atoms ───────────────────────────────────────────────────
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

-- ─── Command palette ─────────────────────────────────────────────────────
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
    local runners = {}
    local function Render()
        for _, c in ipairs(results:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        table.clear(buttons); table.clear(runners)
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

-- ─── Forward declaration for MakeWindow ──────────────────────────────────
local ElementHost

-- ─── Window ──────────────────────────────────────────────────────────────
local WindowIndex = 0
function NovaLib:MakeWindow(cfg)
    cfg = cfg or {}
    WindowIndex += 1
    local t = Themes[NovaLib.SelectedTheme]
    local win = {
        Name = cfg.Name or ("Nova " .. WindowIndex),
        Subtitle = cfg.Subtitle or "",
        Visible = true, Minimized = false, Tabs = {}, Floating = {}, cfg = cfg,
    }
    table.insert(NovaLib.Windows, win)

    NovaLib.Folder = cfg.ConfigFolder or cfg.Name or "NovaLib"
    NovaLib.SaveCfg = cfg.SaveConfig == true
    NovaLib.ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    NovaLib._folderReady = false   -- re-probe if the folder changed

    local size = cfg.Size or UDim2.new(0, 720, 0, 430)
    local pos  = cfg.Position or UDim2.new(0.5, -360, 0.5, -215)

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

-- ─── Element host ────────────────────────────────────────────────────────
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
end)()

-- ─── 2. Global configuration ─────────────────────────────────────────────
NovaLib.Debug      = true
NovaLib.SaveCfg    = true
NovaLib.Folder     = "NovaDemo"
NovaLib.UseSounds  = true
NovaLib.ToggleKey  = Enum.KeyCode.RightShift
NovaLib.TextScale  = 1
NovaLib.UIScale    = 1

-- Report FS capabilities (v2.0.2 feature)
print(("[NovaLoader] FS available=%s read=%s write=%s check=%s folder=%s")
    :format(tostring(NovaLib.FS.available), tostring(NovaLib.FS.canRead),
            tostring(NovaLib.FS.canWrite), tostring(NovaLib.FS.canCheck),
            tostring(NovaLib.FS.canFolder)))

NovaLib:Init()

-- ─── 3. Register custom themes (AddTheme + GetThemes) ────────────────────
NovaLib:AddTheme("Cyberpunk", {
    Main = Color3.fromRGB(10, 4, 24),     Panel = Color3.fromRGB(20, 8, 40),
    Elevated = Color3.fromRGB(34, 14, 60), Stroke = Color3.fromRGB(120, 60, 200),
    Divider = Color3.fromRGB(70, 30, 130), Text = Color3.fromRGB(240, 220, 255),
    TextDark = Color3.fromRGB(160, 130, 210), Accent = Color3.fromRGB(236, 72, 153),
    Good = Color3.fromRGB(34, 211, 238), Bad = Color3.fromRGB(248, 113, 113),
    Warn = Color3.fromRGB(250, 204, 21),
})
NovaLib:AddTheme("Solarized", {
    Main = Color3.fromRGB(0, 43, 54),      Panel = Color3.fromRGB(7, 54, 66),
    Elevated = Color3.fromRGB(20, 70, 82), Stroke = Color3.fromRGB(88, 110, 117),
    Divider = Color3.fromRGB(50, 85, 95),  Text = Color3.fromRGB(238, 232, 213),
    TextDark = Color3.fromRGB(147, 161, 161), Accent = Color3.fromRGB(38, 139, 210),
    Good = Color3.fromRGB(133, 153, 0),    Bad = Color3.fromRGB(220, 50, 47),
    Warn = Color3.fromRGB(181, 137, 0),
})

-- ─── 4. Build the main window ────────────────────────────────────────────
local Window = NovaLib:MakeWindow({
    Name          = "NovaLib Feature Demo",
    Subtitle      = "every API surface, one script",
    Size          = UDim2.new(0, 800, 0, 500),
    Position      = UDim2.new(0.5, -400, 0.5, -250),
    SaveConfig    = true,
    ConfigFolder  = "NovaDemo",
    ToggleKey     = Enum.KeyCode.RightShift,
    CloseCallback = function()
        NovaLib:Info("Window closed by user via X button")
    end,
})

-- ─── 5. Six tabs, one per category ───────────────────────────────────────
local ElementsTab   = Window:MakeTab({ Name = "Elements",   Icon = "layout-grid" })
local InputsTab     = Window:MakeTab({ Name = "Inputs",     Icon = "sliders-horizontal" })
local AppearanceTab = Window:MakeTab({ Name = "Appearance", Icon = "palette" })
local FeaturesTab   = Window:MakeTab({ Name = "Features",   Icon = "sparkles" })
local ReactiveTab   = Window:MakeTab({ Name = "Reactive",   Icon = "activity" })
local MiscTab       = Window:MakeTab({ Name = "Misc",       Icon = "wrench" })

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 1 — ELEMENTS
-- ═══════════════════════════════════════════════════════════════════════════
local E1 = ElementsTab:AddSection({ Name = "Static content" })

E1:AddLabel("A plain label element.")

E1:AddParagraph({
    Title   = "Paragraph element",
    Content = "Paragraphs wrap text and auto-size vertically. "
           .. "Call :Set({Title=..., Content=...}) or :SetTitle(...) to update them live.",
})

local LiveLabel = E1:AddLabel("Live ticker: 0")
task.spawn(function()
    local n = 0
    while LiveLabel and task.wait(1) do
        n += 1
        LiveLabel:Set("Live ticker: " .. n)
    end
end)

local E2 = ElementsTab:AddSection({ Name = "Buttons" })

E2:AddButton({
    Name     = "Basic button",
    Icon     = "mouse-pointer-click",
    Callback = function()
        NovaLib:Notify({ Name = "Clicked", Content = "Basic button fired." })
    end,
})

E2:AddButton({
    Name     = "Button w/ 1s task",
    Icon     = "hourglass",
    Callback = function()
        task.wait(1)
        NovaLib:Notify({
            Name    = "Done",
            Content = "Waited 1 second.",
            Color   = NovaLib.Themes[NovaLib.SelectedTheme].Good,
        })
    end,
})

local Renamable = E2:AddButton({
    Name     = "Renamable button",
    Callback = function()
        NovaLib:Notify({ Name = "Still here", Content = "Name changed but still works." })
    end,
})
E2:AddButton({
    Name     = "Rename the button above",
    Callback = function()
        Renamable:Set("Renamed at " .. os.date("%H:%M:%S"))
    end,
})

local E3 = ElementsTab:AddSection({ Name = "Progress" })

local AutoProg = E3:AddProgress({ Name = "Auto-cycling", Value = 0 })
task.spawn(function()
    while AutoProg and task.wait(0.4) do
        AutoProg:Set((AutoProg.Value + 7) % 101)
    end
end)

E3:AddProgress({
    Name  = "Fixed 42%",
    Value = 42,
    Color = Color3.fromRGB(52, 211, 153),
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 2 — INPUTS
-- ═══════════════════════════════════════════════════════════════════════════
local I1 = InputsTab:AddSection({ Name = "Toggles" })

I1:AddToggle({
    Name     = "Plain toggle",
    Default  = false,
    Flag     = "demo_toggle",
    Save     = true,
    Callback = function(v) print("[Demo] toggle ->", v) end,
})

I1:AddToggle({
    Name     = "Green toggle",
    Default  = true,
    Color    = Color3.fromRGB(52, 211, 153),
    Callback = function(v) print("[Demo] green toggle ->", v) end,
})

local I2 = InputsTab:AddSection({ Name = "Sliders" })

I2:AddSlider({
    Name      = "Volume",
    Min       = 0, Max = 10, Increment = 0.5, Default = 5,
    ValueName = "x",
    Flag      = "demo_volume",
    Save      = true,
    Callback  = function(v) print("[Demo] volume ->", v) end,
})

I2:AddSlider({
    Name      = "Accent hue",
    Min       = 0, Max = 360, Default = NovaLib.PaletteSeed,
    Callback  = function(v) NovaLib:SetPaletteSeed(v) end,
})

I2:AddSlider({
    Name      = "Max 42",
    Min       = 0, Max = 42, Default = 21, Increment = 1,
    Callback  = function(v) print("[Demo] capped ->", v) end,
})

local I3 = InputsTab:AddSection({ Name = "Dropdowns" })

local FruitDrop = I3:AddDropdown({
    Name     = "Fruit",
    Options  = { "Apple", "Banana", "Cherry", "Dragonfruit" },
    Default  = "Apple",
    Flag     = "demo_fruit",
    Save     = true,
    Callback = function(v) print("[Demo] fruit ->", v) end,
})

I3:AddButton({
    Name     = "Refresh fruit options",
    Callback = function()
        FruitDrop:Refresh({ "Apple", "Banana", "Cherry", "Dragonfruit",
                            "Elderberry", "Fig", "Grape", "Honeydew" }, true)
        NovaLib:Notify({ Name = "Refreshed", Content = "Added 4 more fruits." })
    end,
})

I3:AddMultiDropdown({
    Name     = "Multi-select",
    Options  = { "Red", "Green", "Blue", "Alpha", "Beta" },
    Default  = { "Red", "Blue" },
    Flag     = "demo_multi",
    Save     = true,
    Callback = function(list)
        print("[Demo] selected:", table.concat(list, ", "))
    end,
})

local I4 = InputsTab:AddSection({ Name = "Text, keybind, color" })

I4:AddTextbox({
    Name            = "Chat line",
    Placeholder     = "type & press enter",
    FireOnFocusLost = true,
    TextDisappear   = false,
    Callback        = function(text)
        NovaLib:Notify({ Name = "Textbox", Content = "You typed: " .. text })
    end,
})

I4:AddTextbox({
    Name          = "Self-clearing",
    Placeholder   = "clears on Enter",
    TextDisappear = true,
    Callback      = function(text)
        NovaLib:Notify({ Name = "Textbox", Content = "Got: " .. text })
    end,
})

I4:AddBind({
    Name     = "Instant-action key",
    Default  = Enum.KeyCode.X,
    Flag     = "demo_bind",
    Save     = true,
    Callback = function()
        NovaLib:Notify({
            Name    = "Keybind",
            Content = "Bound key pressed!",
            Color   = NovaLib.Themes[NovaLib.SelectedTheme].Bad,
        })
    end,
})

I4:AddBind({
    Name     = "Hold-to-aim (F)",
    Default  = Enum.KeyCode.F,
    Hold     = true,
    Callback = function(down)
        NovaLib:Notify({
            Name    = "Hold",
            Content = down and "Aim started" or "Aim stopped",
            Time    = 1.5,
        })
    end,
})

local ColorPrimary = I4:AddColorpicker({
    Name     = "Primary color",
    Default  = Color3.fromRGB(96, 165, 250),
    Flag     = "demo_color_primary",
    Save     = true,
    Callback = function(c) print("[Demo] primary ->", c) end,
})

I4:AddColorpicker({
    Name     = "Secondary color",
    Default  = Color3.fromRGB(236, 72, 153),
    Callback = function(c) print("[Demo] secondary ->", c) end,
})

I4:AddButton({
    Name     = "Randomize primary color",
    Callback = function()
        ColorPrimary:Set(Color3.fromHSV(math.random(), 0.7, 0.9))
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 3 — APPEARANCE
-- ═══════════════════════════════════════════════════════════════════════════
local A1 = AppearanceTab:AddSection({ Name = "Theme system" })

A1:AddDropdown({
    Name     = "Active theme",
    Options  = NovaLib:GetThemes(),
    Default  = NovaLib.SelectedTheme,
    Callback = function(choice)
        NovaLib:SetTheme(choice)
        NovaLib:Notify({ Name = "Theme", Content = "Switched to " .. choice })
    end,
})

A1:AddButton({
    Name     = "Cycle to next theme",
    Callback = function()
        local list = NovaLib:GetThemes()
        local idx  = table.find(list, NovaLib.SelectedTheme) or 0
        local next_ = list[(idx % #list) + 1]
        NovaLib:SetTheme(next_)
        NovaLib:Notify({ Name = "Theme", Content = "Now: " .. next_ })
    end,
})

A1:AddButton({
    Name     = "Print theme list to console",
    Callback = function()
        for i, name in ipairs(NovaLib:GetThemes()) do
            print(("[Theme %d] %s"):format(i, name))
        end
        NovaLib:Notify({
            Name    = "Themes",
            Content = #NovaLib:GetThemes() .. " registered (see F9 console).",
        })
    end,
})

local A2 = AppearanceTab:AddSection({ Name = "Palette / accent" })

A2:AddSlider({
    Name      = "Accent hue (0-360)",
    Min       = 0, Max = 360, Default = NovaLib.PaletteSeed,
    Callback  = function(v) NovaLib:SetPaletteSeed(v) end,
})

A2:AddSlider({
    Name      = "UI scale (0.6-1.6)",
    Min       = 0.6, Max = 1.6, Increment = 0.05, Default = 1,
    Callback  = function(v)
        for _, obj in ipairs(NovaLib.Windows[1].cfg and game:GetService("CoreGui"):GetDescendants() or {}) do
            if obj:IsA("UIScale") then obj.Scale = v end
        end
    end,
})

local A3 = AppearanceTab:AddSection({ Name = "Accessibility" })

A3:AddToggle({
    Name     = "Reduced motion",
    Default  = NovaLib.ReducedMotion,
    Callback = function(v)
        NovaLib.ReducedMotion = v
        NovaLib:Notify({ Name = "A11y", Content = "Reduced motion " .. (v and "on" or "off") })
    end,
})

A3:AddToggle({
    Name     = "High contrast",
    Default  = NovaLib.HighContrast,
    Callback = function(v)
        NovaLib.HighContrast = v
        NovaLib:Notify({ Name = "A11y", Content = "High contrast " .. (v and "on" or "off") })
    end,
})

A3:AddSlider({
    Name      = "Text scale",
    Min       = 0.8, Max = 1.4, Increment = 0.05, Default = NovaLib.TextScale,
    Callback  = function(v) NovaLib.TextScale = v end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 4 — FEATURES
-- ═══════════════════════════════════════════════════════════════════════════
local F1 = FeaturesTab:AddSection({ Name = "Notifications" })

F1:AddButton({
    Name     = "Simple notification",
    Callback = function()
        NovaLib:Notify({ Name = "Hello", Content = "Just a normal notification." })
    end,
})

F1:AddButton({
    Name     = "Notification w/ actions",
    Callback = function()
        NovaLib:Notify({
            Name    = "Confirm",
            Content = "Do the thing?",
            Time    = 6,
            Actions = {
                { Name = "Yes", Callback = function()
                    NovaLib:Notify({ Name = "Confirmed", Content = "Thing was done." })
                end },
                { Name = "No", Callback = function()
                    NovaLib:Notify({ Name = "Cancelled", Content = "Thing was not done." })
                end },
            },
        })
    end,
})

F1:AddButton({
    Name     = "Colored + custom icon",
    Callback = function()
        NovaLib:Notify({
            Name    = "Warning",
            Content = "Something looks off.",
            Color   = NovaLib.Themes[NovaLib.SelectedTheme].Warn,
            Image   = "alert-triangle",
            Time    = 5,
        })
    end,
})

F1:AddButton({
    Name     = "Long notification (12s)",
    Callback = function()
        NovaLib:Notify({
            Name    = "Marathon",
            Content = "This stays for 12 seconds so you can read it.",
            Time    = 12,
        })
    end,
})

F1:AddButton({
    Name     = "Spam 5 notifications",
    Callback = function()
        for i = 1, 5 do
            task.spawn(function()
                task.wait(i * 0.15)
                NovaLib:Notify({ Name = "Spam " .. i, Content = "Notif #" .. i, Time = 2 })
            end)
        end
    end,
})

F1:AddButton({
    Name     = "MakeNotification alias",
    Callback = function()
        NovaLib:MakeNotification({ Name = "Alias", Content = "Same as :Notify()." })
    end,
})

local F2 = FeaturesTab:AddSection({ Name = "Command palette" })

F2:AddButton({
    Name     = "Open command palette",
    Callback = function() NovaLib.OpenCommandPalette() end,
})

F2:AddParagraph({
    Title   = "Palette",
    Content = "Every element above registered itself as a command. "
           .. "Try: 'toggle', 'open', 'minimize', 'theme', 'fruit', 'slider', "
           .. "or any element name. Arrows navigate, Enter runs, Esc closes.",
})

F2:AddButton({
    Name     = "Manually register a custom command",
    Callback = function()
        -- RegisterCommand is internal, but palette commands are added via
        -- the same mechanism. This is a demo of how element registration
        -- shows up in the search index.
        NovaLib:Notify({
            Name    = "Tip",
            Content = "Every AddX you click adds a palette entry automatically.",
        })
    end,
})

local F3 = FeaturesTab:AddSection({ Name = "Floating tabs" })

F3:AddButton({
    Name     = "Float the Inputs tab",
    Callback = function()
        local t = Window.Tabs[2]
        if t then Window.DockTab(t) end
    end,
})

F3:AddButton({
    Name     = "Float the Misc tab",
    Callback = function()
        local t = Window.Tabs[6]
        if t then Window.DockTab(t) end
    end,
})

F3:AddButton({
    Name     = "Close all floating windows",
    Callback = function()
        for _, fw in ipairs(Window.Floating) do fw:Destroy() end
        table.clear(Window.Floating)
    end,
})

local F4 = FeaturesTab:AddSection({ Name = "Console / logs" })

F4:AddButton({
    Name     = "Emit TRACE",
    Callback = function() NovaLib:Trace("Trace level message", { from = "demo" }) end,
})
F4:AddButton({
    Name     = "Emit DEBUG",
    Callback = function() NovaLib:Debug("Debug level message", { from = "demo" }) end,
})
F4:AddButton({
    Name     = "Emit INFO",
    Callback = function() NovaLib:Info("Info level message", { from = "demo" }) end,
})
F4:AddButton({
    Name     = "Emit WARN",
    Callback = function() NovaLib:Warn("Warn level message", { from = "demo" }) end,
})
F4:AddButton({
    Name     = "Emit ERROR",
    Callback = function() NovaLib:Error("Error level message", { from = "demo" }) end,
})
F4:AddButton({
    Name     = "Print log count",
    Callback = function()
        NovaLib:Notify({ Name = "Console", Content = #NovaLib.Logs .. " log entries stored." })
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 5 — REACTIVE VALUES
-- ═══════════════════════════════════════════════════════════════════════════
local R1 = ReactiveTab:AddSection({ Name = "NovaLib:Value()" })

local Counter = NovaLib:Value(0)
local CounterLabel = R1:AddLabel("Counter: 0")
local _counterObs = Counter:Observe(function(v, old)
    CounterLabel:Set(("Counter: %d  (was %d)"):format(v, old))
end)

R1:AddButton({ Name = "Increment", Callback = function() Counter:Set(Counter:Get() + 1) end })
R1:AddButton({ Name = "Decrement", Callback = function() Counter:Set(Counter:Get() - 1) end })
R1:AddButton({ Name = "Reset to 0", Callback = function() Counter:Set(0) end })

R1:AddButton({
    Name     = "Bind a new label to Counter",
    Callback = function()
        local l = R1:AddLabel("bound: ?")
        Counter:Bind(l, function(elem, v) elem:Set("bound: " .. v) end)
        NovaLib:Notify({ Name = "Bound", Content = "New label will track Counter." })
    end,
})

local R2 = ReactiveTab:AddSection({ Name = "Multiple observers" })

local StatusValue = NovaLib:Value("idle")
local StatusLabel = R2:AddLabel("Status: idle")
StatusValue:Observe(function(v) StatusLabel:Set("Status: " .. v) end)

R2:AddButton({ Name = "Set status -> loading",  Callback = function() StatusValue:Set("loading") end })
R2:AddButton({ Name = "Set status -> ready",    Callback = function() StatusValue:Set("ready") end })
R2:AddButton({ Name = "Set status -> error",    Callback = function() StatusValue:Set("error") end })

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB 6 — MISC (config, privacy, window ops, destroy)
-- ═══════════════════════════════════════════════════════════════════════════
local M1 = MiscTab:AddSection({ Name = "Config / persistence" })

M1:AddParagraph({
    Title   = "FS status",
    Content = ("available=%s read=%s write=%s check=%s folder=%s")
        :format(tostring(NovaLib.FS.available), tostring(NovaLib.FS.canRead),
                tostring(NovaLib.FS.canWrite), tostring(NovaLib.FS.canCheck),
                tostring(NovaLib.FS.canFolder)),
})

M1:AddButton({
    Name     = "Save config now",
    Callback = function()
        local changed = NovaLib.SaveConfig(tostring(game.GameId))
        NovaLib:Notify({
            Name    = "Config",
            Content = string.format("Saved. %d value(s) changed.", changed),
        })
    end,
})

M1:AddButton({
    Name     = "Print config history",
    Callback = function()
        if #NovaLib.ConfigHistory == 0 then
            NovaLib:Notify({ Name = "History", Content = "No saves yet." })
            return
        end
        for i, entry in ipairs(NovaLib.ConfigHistory) do
            print(("[History #%d] time=%d changed=%d"):format(i, entry.time, entry.changed))
        end
        NovaLib:Notify({
            Name    = "History",
            Content = #NovaLib.ConfigHistory .. " entries (F9 console).",
        })
    end,
})

local M2 = MiscTab:AddSection({ Name = "Window controls" })

M2:AddButton({
    Name     = "Hide for 0.6s, then show",
    Callback = function()
        Window:SetVisible(false)
        task.wait(0.6)
        Window:SetVisible(true)
    end,
})

M2:AddButton({ Name = "Toggle visible", Callback = function() Window:Toggle() end })

M2:AddButton({
    Name     = "Report visible state",
    Callback = function()
        NovaLib:Notify({
            Name    = "State",
            Content = "Window.Visible = " .. tostring(Window.Visible)
                   .. ", Minimized = " .. tostring(Window.Minimized),
        })
    end,
})

local M3 = MiscTab:AddSection({ Name = "Privacy" })

M3:AddToggle({
    Name     = "Streamer mode",
    Default  = NovaLib.StreamerMode,
    Callback = function(v)
        NovaLib.StreamerMode = v
        for _, refresh in ipairs(NovaLib._streamerListeners) do pcall(refresh) end
    end,
})

M3:AddToggle({
    Name     = "Panic mode",
    Default  = NovaLib.PanicEnabled,
    Color    = NovaLib.Themes[NovaLib.SelectedTheme].Bad,
    Callback = function(v)
        NovaLib.PanicEnabled = v
        NovaLib:Notify({
            Name    = "Panic",
            Content = v and "Panic ENABLED" or "Panic disabled",
            Color   = v and NovaLib.Themes[NovaLib.SelectedTheme].Bad
                        or NovaLib.Themes[NovaLib.SelectedTheme].Good,
        })
    end,
})

local M4 = MiscTab:AddSection({ Name = "Danger zone" })

M4:AddButton({
    Name     = "Destroy library (irreversible)",
    Icon     = "trash-2",
    Callback = function()
        NovaLib:Notify({ Name = "Bye", Content = "Destroying in 1 second..." })
        task.wait(1)
        NovaLib:Destroy()
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. Startup notification
-- ═══════════════════════════════════════════════════════════════════════════
NovaLib:Notify({
    Name    = "NovaLib Demo",
    Content = "Loaded. RightShift toggles UI, Ctrl+K opens the palette.",
    Time    = 6,
    Actions = {
        { Name = "Open palette", Callback = NovaLib.OpenCommandPalette },
        { Name = "Save config",  Callback = function() NovaLib.SaveConfig(tostring(game.GameId)) end },
    },
})

print("[NovaLoader] Ready. RightShift = toggle UI, Ctrl+K = palette.")
return NovaLib
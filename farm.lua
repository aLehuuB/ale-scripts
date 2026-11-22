--[[
    ═══════════════════════════════════════════════════════════
       ALE SCRIPTS · MURDER MYSTERY 2 · COIN FARMER · v5
       RightShift menu · Q farm · E combat
    ═══════════════════════════════════════════════════════════
]]

--=====================================================================
-- [Util]
--=====================================================================
local Util = {}

function Util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function Util.fmt(n, dec)
    return string.format("%." .. (dec or 0) .. "f", n)
end

function Util.try(fn, ...)
    local r = table.pack(pcall(fn, ...))
    if r[1] then return true, table.unpack(r, 2, r.n) end
    return false, r[2]
end

function Util.now()
    return os.clock()
end

--=====================================================================
-- [Theme]
--=====================================================================
local Theme = {
    bg      = Color3.fromRGB(12, 15, 20),
    card    = Color3.fromRGB(18, 22, 29),
    cardTop = Color3.fromRGB(22, 27, 35),
    row     = Color3.fromRGB(23, 28, 36),
    rowOn   = Color3.fromRGB(23, 43, 48),
    track   = Color3.fromRGB(44, 50, 62),
    trackOn = Color3.fromRGB(45, 212, 191),
    line    = Color3.fromRGB(34, 40, 51),
    stroke  = Color3.fromRGB(48, 56, 70),
    text    = Color3.fromRGB(226, 232, 242),
    textOn  = Color3.fromRGB(198, 255, 244),
    muted   = Color3.fromRGB(132, 143, 161),
    soft    = Color3.fromRGB(100, 110, 128),
    accent  = Color3.fromRGB(96, 165, 250),
    accent2 = Color3.fromRGB(139, 122, 255),
    knob    = Color3.fromRGB(146, 154, 168),
    good    = Color3.fromRGB(52, 211, 153),
    warn    = Color3.fromRGB(239, 108, 108),
    gold    = Color3.fromRGB(250, 204, 110),
}

--=====================================================================
-- [Config] every toggle starts disabled
--=====================================================================
local Config = {
    mode        = "teleport",
    delay       = 0.14,
    radius      = 0,
    maxMarkers  = 12,

    showMarkers = false,
    espPlayers  = false,
    roleList    = false,
    humanize    = false,
    autoStart   = false,

    autoShoot   = false,
    autoEquip   = false,
    aimAtMurder = false,
    shootRange  = 220,
    shootDelay  = 0.7,
    aimSmooth   = 14,

    menuKey     = Enum.KeyCode.RightShift,
    farmKey     = Enum.KeyCode.Q,
    combatKey   = Enum.KeyCode.E,
}

function Config.validate()
    Config.delay  = Util.clamp(Config.delay, 0.05, 1.5)
    Config.radius = Util.clamp(Config.radius, 0, 600)
    Config.maxMarkers = Util.clamp(Config.maxMarkers, 0, 40)
    Config.shootRange = Util.clamp(Config.shootRange, 30, 500)
    Config.shootDelay = Util.clamp(Config.shootDelay, 0.25, 3)
    Config.aimSmooth  = Util.clamp(Config.aimSmooth, 2, 30)
    if Config.mode ~= "teleport" and Config.mode ~= "walk" then
        Config.mode = "teleport"
    end
end

--=====================================================================
-- [State]
--=====================================================================
local State = {
    running   = false,
    menuOpen  = true,
    collected = 0,
    nearby    = 0,
    status    = "idle",
    combatMsg = "",
    blacklist = {},
    coinMarks = {},
    playerEsp = {},
    roles     = {},
    inRound   = false,
    cache     = {},
    cacheAt   = 0,
    activeSlider = nil,
    errors    = 0,
    lastShot  = 0,
    hadGun    = false,
}

local CACHE_TTL = 0.3

--=====================================================================
-- [Services]
--=====================================================================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local LP  = Players.LocalPlayer
local PGV = LP:WaitForChild("PlayerGui")
local Mouse = LP:GetMouse()

local ENV = {
    dw = Drawing,
    touch = firetouchinterest,
}

--=====================================================================
-- [Diagnostics]
--=====================================================================
local Diagnostics = {}
local statusLabel, combatLabel

function Diagnostics.log(msg)
    print("[AleScripts] " .. tostring(msg))
    if statusLabel then statusLabel.Text = tostring(msg) end
end

function Diagnostics.note(err)
    State.errors += 1
    if State.errors <= 10 then Diagnostics.log("error: " .. tostring(err)) end
end

function Diagnostics.notify(text)
    Util.try(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Ale Scripts", Text = tostring(text), Duration = 2,
        })
    end)
end

--=====================================================================
-- [Cursor]
--=====================================================================
local Cursor = { saved = nil, savedIcon = nil, open = false, forceClock = 0 }

function Cursor.applyOpen()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
end

function Cursor.set(open)
    if open == Cursor.open then return end
    Cursor.open = open
    if open then
        Cursor.saved = UIS.MouseBehavior
        Cursor.savedIcon = UIS.MouseIconEnabled
        Cursor.applyOpen()
    else
        UIS.MouseBehavior = Cursor.saved or Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = Cursor.savedIcon ~= false
        Cursor.saved, Cursor.savedIcon = nil, nil
    end
end

function Cursor.tick(dt)
    if not Cursor.open then return end
    Cursor.forceClock += dt
    if Cursor.forceClock >= 0.3 then
        Cursor.forceClock = 0
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then Cursor.applyOpen() end
    end
end

function Cursor.release()
    if Cursor.open then Cursor.set(false) end
end

--=====================================================================
-- [Splash]
--=====================================================================
local function splash()
    local Tween = game:GetService("TweenService")
    local sg = Instance.new("ScreenGui")
    sg.Name = "AleSplash"
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 5000
    sg.ResetOnSpawn = false
    sg.Parent = PGV

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(9, 11, 16)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.Parent = sg

    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.fromScale(0.5, 0.5)
    glow.Size = UDim2.fromOffset(20, 20)
    glow.BackgroundColor3 = Color3.fromRGB(70, 90, 170)
    glow.BackgroundTransparency = 0.88
    glow.BorderSizePixel = 0
    glow.Parent = bg
    Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    holder.Size = UDim2.fromScale(1.6, 0.4)
    holder.BackgroundTransparency = 1
    holder.Parent = bg

    local brand = Instance.new("TextLabel")
    brand.Size = UDim2.fromScale(1, 1)
    brand.BackgroundTransparency = 1
    brand.Font = Enum.Font.GothamBlack
    brand.TextScaled = true
    brand.Text = "ALE SCRIPTS"
    brand.TextTransparency = 1
    brand.Parent = holder
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 205, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 140, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(96, 205, 255)),
    })
    g.Parent = brand

    local sub = Instance.new("TextLabel")
    sub.AnchorPoint = Vector2.new(0.5, 0.5)
    sub.Position = UDim2.fromScale(0.5, 0.66)
    sub.Size = UDim2.fromScale(0.3, 0.04)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.TextColor3 = Color3.fromRGB(126, 136, 160)
    sub.Text = "MURDER MYSTERY 2"
    sub.TextTransparency = 1
    sub.Parent = bg

    Tween:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    Tween:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.fromOffset(880, 880), BackgroundTransparency = 1}):Play()
    Tween:Create(holder, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromScale(0.85, 0.21)}):Play()
    Tween:Create(brand, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    task.delay(0.6, function()
        Tween:Create(sub, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    end)

    task.wait(1.6)

    Tween:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.fromScale(1.2, 0.3)}):Play()
    Tween:Create(brand, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    Tween:Create(sub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    Tween:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    task.wait(0.45)
    sg:Destroy()
end

splash()

--=====================================================================
-- [Roles]
--=====================================================================
local Roles = {}

local ROLE_COLOR = {
    Murder   = Color3.fromRGB(255, 118, 118),
    Sheriff  = Color3.fromRGB(112, 178, 255),
    Innocent = Color3.fromRGB(126, 232, 150),
    Unknown  = Color3.fromRGB(186, 194, 208),
}

function Roles.color(role)
    return ROLE_COLOR[role] or ROLE_COLOR.Unknown
end

local function scanTools(container)
    local found
    for _, tool in ipairs(container:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife", 1, true) then
                return "Murder"
            elseif n:find("gun", 1, true) or n:find("revolver", 1, true)
            or n:find("pistol", 1, true) then
                found = "Sheriff"
            end
        end
    end
    return found
end

function Roles.of(plr)
    local attr = plr:GetAttribute("Role")
    if type(attr) == "string" then
        local l = attr:lower()
        if l:find("murder") then return "Murder" end
        if l:find("sheriff") then return "Sheriff" end
        if l:find("innocent") then return "Innocent" end
    end

    local backpack = plr:FindFirstChildOfClass("Backpack")
    local fromBag = backpack and scanTools(backpack)
    if fromBag then return fromBag end

    local char = plr.Character
    if char then
        local fromChar = scanTools(char)
        if fromChar then return fromChar end
    end

    if State.inRound then return "Innocent" end
    return "Unknown"
end

function Roles.refresh()
    local rows = {}
    local anyTool = false

    for _, plr in ipairs(Players:GetPlayers()) do
        local role = Roles.of(plr)
        if role ~= "Innocent" and role ~= "Unknown" then anyTool = true end
        rows[#rows + 1] = { plr = plr, role = role }
    end

    local order = { Murder = 1, Sheriff = 2, Innocent = 3, Unknown = 4 }
    table.sort(rows, function(a, b)
        return (order[a.role] or 9) < (order[b.role] or 9)
    end)

    State.roles = rows
    if anyTool then State.inRound = true end
end

--=====================================================================
-- [CoinScanner]
--=====================================================================
local CoinScanner = {}

local function isCoin(inst)
    return inst:IsA("BasePart") and inst.Name:lower():find("coin", 1, true) ~= nil
end

local function blacklisted(coin)
    local until_ = State.blacklist[coin]
    if not until_ then return false end
    if Util.now() > until_ then
        State.blacklist[coin] = nil
        return false
    end
    return true
end

function CoinScanner.refresh()
    local now = Util.now()
    if now - State.cacheAt < CACHE_TTL then return State.cache end
    State.cacheAt = now

    local seen, raw = {}, {}
    local function add(part)
        if seen[part] or not part.Parent or blacklisted(part) then return end
        seen[part] = true
        raw[#raw + 1] = part
    end

    for _, inst in ipairs(workspace:GetDescendants()) do
        if isCoin(inst) then add(inst) end
    end
    for _, inst in ipairs(CollectionService:GetTagged("Coin")) do
        if inst:IsA("BasePart") then add(inst) end
    end

    local _, root = getRoot()
    local from = root and root.Position or Vector3.zero

    local list = {}
    for _, coin in ipairs(raw) do
        local dist = (coin.Position - from).Magnitude
        if Config.radius == 0 or dist <= Config.radius then
            list[#list + 1] = { coin = coin, dist = dist }
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    State.cache = list
    State.nearby = #list
    if #list > 0 then State.inRound = true end
    return list
end

function CoinScanner.nearest()
    local list = CoinScanner.refresh()
    for _, entry in ipairs(list) do
        if entry.coin.Parent then return entry.coin, entry.dist end
    end
    return nil, nil
end

--=====================================================================
-- [Teleporter]
--=====================================================================
local Teleporter = {}

function getRoot()
    local char = LP.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil, nil end
    return hum, root
end

function Teleporter.hop(root, coin)
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0))
    if ENV.touch then
        Util.try(function()
            ENV.touch(root, coin, 0)
            ENV.touch(root, coin, 1)
        end)
    end
end

--=====================================================================
-- [Combat]
--=====================================================================
local Combat = {}

local GUN_NAMES = { "gun", "revolver", "pistol" }

local function findGun(container)
    if not container then return nil end
    for _, name in ipairs(GUN_NAMES) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and child.Name:lower():find(name, 1, true) then
                return child
            end
        end
    end
    return nil
end

function Combat.equippedGun()
    local char = LP.Character
    return char and findGun(char)
end

function Combat.backpackGun()
    local bag = LP:FindFirstChildOfClass("Backpack")
    return bag and findGun(bag)
end

local function visibleFromCamera(part, char)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, LP.Character}
    params.IgnoreWater = true
    local origin = cam.CFrame.Position
    return workspace:Raycast(origin, part.Position - origin, params) == nil
end

function Combat.pickTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local camPos = cam.CFrame.Position

    local function valid(plr, role)
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then return nil end
        local dist = (head.Position - camPos).Magnitude
        if dist > Config.shootRange then return nil end
        if not visibleFromCamera(head, char) then return nil end
        return head, dist, role
    end

    if Config.aimAtMurder then
        for _, entry in ipairs(State.roles) do
            if entry.role == "Murder" and entry.plr ~= LP then
                local head, dist, role = valid(entry.plr, entry.role)
                if head then return entry.plr, head, dist, role end
            end
        end
    end

    local best, bestHead, bestDist, bestRole
    for _, entry in ipairs(State.roles) do
        if entry.plr ~= LP then
            local head, dist, role = valid(entry.plr, entry.role)
            if head and (not bestDist or dist < bestDist) then
                best, bestHead, bestDist, bestRole = entry.plr, head, dist, role
            end
        end
    end
    return best, bestHead, bestDist, bestRole
end

function Combat.step(dt)
    if not Config.autoShoot then return end

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end

    local gun = Combat.equippedGun()
    if not gun then
        if Config.autoEquip then
            local bagGun = Combat.backpackGun()
            if bagGun then
                Util.try(function() hum:EquipTool(bagGun) end)
                State.combatMsg = "equipping " .. bagGun.Name
            end
        end
        State.hadGun = false
        return
    end

    if not State.hadGun then
        State.hadGun = true
        State.combatMsg = "gun ready"
        Diagnostics.notify("Gun detected: " .. gun.Name)
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local plr, head, dist = Combat.pickTarget()
    if not plr or not head then
        State.combatMsg = "no target"
        return
    end

    State.combatMsg = string.format("%s · %dm", plr.Name, math.floor(dist))

    local desired = head.Position - cam.CFrame.Position
    if desired.Magnitude < 0.5 then return end
    local alpha = Util.clamp(Config.aimSmooth * dt, 0, 1)
    cam.CFrame = CFrame.lookAt(
        cam.CFrame.Position,
        cam.CFrame.Position + cam.CFrame.LookVector:Lerp(desired.Unit, alpha))

    if Util.now() - State.lastShot < Config.shootDelay then return end
    State.lastShot = Util.now()

    local ok = Util.try(function() mouse1click() end)
    if not ok then Util.try(function() gun:Activate() end) end
end

--=====================================================================
-- [Visuals]
--=====================================================================
local Visuals = {}

local function newObj(kind)
    if not ENV.dw then return nil end
    local ok, o = Util.try(function() return ENV.dw.new(kind) end)
    return ok and o or nil
end

local function dropCoin(coin)
    local t = State.coinMarks[coin]
    if not t then return end
    for _, o in pairs(t) do Util.try(function() o:Remove() end) end
    State.coinMarks[coin] = nil
end

local function dropPlayer(plr)
    local t = State.playerEsp[plr]
    if not t then return end
    for _, o in pairs(t) do Util.try(function() o:Remove() end) end
    State.playerEsp[plr] = nil
end

function Visuals.clearAll()
    for coin in pairs(State.coinMarks) do dropCoin(coin) end
    for plr in pairs(State.playerEsp) do dropPlayer(plr) end
end

function Visuals.coins()
    if not Config.showMarkers or not ENV.dw then
        if next(State.coinMarks) then
            for coin in pairs(State.coinMarks) do dropCoin(coin) end
        end
        return
    end

    local cam = workspace.CurrentCamera
    local _, root = getRoot()
    if not cam or not root then return end

    local list = CoinScanner.refresh()
    local limit = math.min(#list, Config.maxMarkers)
    local keep = {}

    for i = 1, limit do
        local entry = list[i]
        local sp, on = cam:WorldToViewportPoint(entry.coin.Position)
        if on and sp.Z > 0 then
            local t = State.coinMarks[entry.coin]
            if not t then
                local sq = newObj("Square")
                if sq then
                    sq.Thickness = 1
                    sq.Filled = false
                    sq.Color = Theme.gold
                    sq.Size = Vector2.new(9, 9)
                    local txt = newObj("Text")
                    if txt then
                        txt.Size = 11
                        txt.Center = true
                        txt.Outline = true
                        txt.Color = Theme.gold
                    end
                    t = { sq, txt }
                    State.coinMarks[entry.coin] = t
                end
            end
            if t then
                t[1].Visible = true
                t[1].Position = Vector2.new(sp.X - 4, sp.Y - 4)
                if t[2] then
                    t[2].Visible = true
                    t[2].Text = math.floor(entry.dist) .. "m"
                    t[2].Position = Vector2.new(sp.X, sp.Y + 10)
                end
                keep[entry.coin] = true
            end
        end
    end

    for coin in pairs(State.coinMarks) do
        if not keep[coin] then dropCoin(coin) end
    end
end

function Visuals.players()
    if not Config.espPlayers or not ENV.dw then
        if next(State.playerEsp) then
            for plr in pairs(State.playerEsp) do dropPlayer(plr) end
        end
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local keep = {}

    for _, entry in ipairs(State.roles) do
        local plr, role = entry.plr, entry.role
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if head and hum and hum.Health > 0 then
            local sp, on = cam:WorldToViewportPoint(head.Position)
            if on and sp.Z > 0 then
                local t = State.playerEsp[plr]
                if not t then
                    local box = newObj("Square")
                    local label = newObj("Text")
                    if box then
                        box.Thickness = 1
                        box.Filled = false
                    end
                    if label then
                        label.Size = 12
                        label.Center = true
                        label.Outline = true
                    end
                    t = { box, label }
                    State.playerEsp[plr] = t
                end

                local color = Roles.color(role)
                local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
                local bot = cam:WorldToViewportPoint(head.Position - Vector3.new(0, 2.7, 0))
                local h = math.max(math.abs(bot.Y - top.Y), 10)
                local w = h * 0.55

                if t[1] then
                    t[1].Visible = true
                    t[1].Color = color
                    t[1].Size = Vector2.new(w, h)
                    t[1].Position = Vector2.new(sp.X - w / 2, sp.Y - h / 2)
                end
                if t[2] then
                    t[2].Visible = true
                    t[2].Color = color
                    t[2].Text = string.format("%s [%s]", plr.Name, role)
                    t[2].Position = Vector2.new(sp.X, sp.Y - h / 2 - 15)
                end
                keep[plr] = true
            end
        end
    end

    for plr in pairs(State.playerEsp) do
        if not keep[plr] then dropPlayer(plr) end
    end
end

--=====================================================================
-- [UI] sidebar + cards
--=====================================================================
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AleScriptsMM2"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 90
    gui.Parent = PGV

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(352, 452)
    root.Position = UDim2.new(0, 26, 0.1, 0)
    root.BackgroundColor3 = Theme.bg
    root.BorderSizePixel = 0
    root.Active = true
    root.Parent = gui
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", root)
    stroke.Color = Theme.stroke

    -- barra de acento superior
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 3)
    top.BackgroundColor3 = Theme.accent
    top.BorderSizePixel = 0
    top.Parent = root
    Instance.new("UICorner", top).CornerRadius = UDim.new(0, 12)
    local tg = Instance.new("UIGradient")
    tg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.accent),
        ColorSequenceKeypoint.new(1, Theme.accent2),
    })
    tg.Parent = top

    -- encabezado
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.Position = UDim2.new(0, 0, 0, 3)
    header.BackgroundTransparency = 1
    header.Active = true
    header.Parent = root

    local mark = Instance.new("Frame")
    mark.Size = UDim2.fromOffset(3, 20)
    mark.Position = UDim2.new(0, 12, 0, 12)
    mark.BackgroundColor3 = Theme.accent
    mark.BorderSizePixel = 0
    mark.Parent = header
    Instance.new("UICorner", mark).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -110, 0, 17)
    title.Position = UDim2.new(0, 21, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "ALE SCRIPTS"
    title.Parent = header
    local grd = Instance.new("UIGradient")
    grd.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.accent),
        ColorSequenceKeypoint.new(1, Theme.accent2),
    })
    grd.Parent = title

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -110, 0, 12)
    sub.Position = UDim2.new(0, 21, 0, 25)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 8.5
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextColor3 = Theme.soft
    sub.Text = "MM2 · farm · roles · combat"
    sub.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(22, 22)
    closeBtn.Position = UDim2.new(1, -30, 0, 11)
    closeBtn.BackgroundColor3 = Theme.row
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Theme.text
    closeBtn.Text = "×"
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    -- barra de estado
    local strip = Instance.new("Frame")
    strip.Size = UDim2.new(1, -20, 0, 22)
    strip.Position = UDim2.new(0, 10, 0, 50)
    strip.BackgroundColor3 = Theme.card
    strip.BorderSizePixel = 0
    strip.Parent = root
    Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 6)

    local collectedLbl = Instance.new("TextLabel")
    collectedLbl.Size = UDim2.fromOffset(78, 22)
    collectedLbl.Position = UDim2.new(0, 8, 0, 0)
    collectedLbl.BackgroundTransparency = 1
    collectedLbl.Font = Enum.Font.GothamBold
    collectedLbl.TextSize = 10
    collectedLbl.TextXAlignment = Enum.TextXAlignment.Left
    collectedLbl.TextColor3 = Theme.gold
    collectedLbl.Text = "0 collected"
    collectedLbl.Parent = strip

    local nearLbl = Instance.new("TextLabel")
    nearLbl.Size = UDim2.fromOffset(70, 22)
    nearLbl.Position = UDim2.new(0, 88, 0, 0)
    nearLbl.BackgroundTransparency = 1
    nearLbl.Font = Enum.Font.Gotham
    nearLbl.TextSize = 10
    nearLbl.TextXAlignment = Enum.TextXAlignment.Left
    nearLbl.TextColor3 = Theme.muted
    nearLbl.Text = "0 on map"
    nearLbl.Parent = strip

    combatLabel = Instance.new("TextLabel")
    combatLabel.Size = UDim2.new(0.4, 0, 0, 22)
    combatLabel.Position = UDim2.new(0.58, 0, 0, 0)
    combatLabel.BackgroundTransparency = 1
    combatLabel.Font = Enum.Font.GothamBold
    combatLabel.TextSize = 9
    combatLabel.TextXAlignment = Enum.TextXAlignment.Right
    combatLabel.TextColor3 = Theme.muted
    combatLabel.Text = "combat off"
    combatLabel.Parent = strip

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 12)
    statusLabel.Position = UDim2.new(0, 10, 0, 76)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Code
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextColor3 = Theme.soft
    statusLabel.Text = "idle"
    statusLabel.Parent = root

    -- navegación lateral
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.fromOffset(76, 320)
    sidebar.Position = UDim2.new(0, 10, 0, 94)
    sidebar.BackgroundColor3 = Theme.card
    sidebar.BorderSizePixel = 0
    sidebar.Parent = root
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)
    local sl = Instance.new("UIListLayout")
    sl.Padding = UDim.new(0, 3)
    sl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sl.Parent = sidebar
    local sp = Instance.new("UIPadding")
    sp.PaddingTop = UDim.new(0, 6)
    sp.Parent = sidebar

    -- contenido
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -96, 320)
    content.Position = UDim2.new(0, 86, 0, 94)
    content.BackgroundTransparency = 1
    content.Parent = root

    local pages, navBtns = {}, {}

    local function selectPage(name)
        for key, frame in pairs(pages) do frame.Visible = (key == name) end
        for key, btn in pairs(navBtns) do
            local active = (key == name)
            btn.bar.Visible = active
            btn.btn.BackgroundColor3 = active and Theme.rowOn or Theme.row
            btn.btn.TextColor3 = active and Theme.accent or Theme.muted
        end
    end

    local function addPage(name, label)
        local wrap = Instance.new("Frame")
        wrap.Size = UDim2.fromOffset(70, 30)
        wrap.BackgroundTransparency = 1
        wrap.Parent = sidebar

        local bar = Instance.new("Frame")
        bar.Size = UDim2.fromOffset(2, 14)
        bar.Position = UDim2.new(0, -4, 0.5, 0)
        bar.AnchorPoint = Vector2.new(0, 0.5)
        bar.BackgroundColor3 = Theme.accent
        bar.BorderSizePixel = 0
        bar.Visible = false
        bar.Parent = wrap
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromScale(1, 1)
        btn.BackgroundColor3 = Theme.row
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextColor3 = Theme.muted
        btn.Text = label
        btn.Parent = wrap
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.stroke
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new()
        page.Active = true
        page.Visible = false
        page.Parent = content
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.Parent = page

        pages[name] = page
        navBtns[name] = { btn = btn, bar = bar }
        btn.MouseButton1Click:Connect(function() selectPage(name) end)
        return page
    end

    -- tarjeta con título
    local function card(page, label)
        local outer = Instance.new("Frame")
        outer.Size = UDim2.new(1, 0, 0, 0)
        outer.AutomaticSize = Enum.AutomaticSize.Y
        outer.BackgroundColor3 = Theme.card
        outer.BorderSizePixel = 0
        outer.Parent = page
        Instance.new("UICorner", outer).CornerRadius = UDim.new(0, 8)

        local cap = Instance.new("Frame")
        cap.Size = UDim2.new(1, 0, 0, 22)
        cap.BackgroundColor3 = Theme.cardTop
        cap.BorderSizePixel = 0
        cap.Parent = outer
        Instance.new("UICorner", cap).CornerRadius = UDim.new(0, 8)

        local capLabel = Instance.new("TextLabel")
        capLabel.Size = UDim2.new(1, -16, 1, 0)
        capLabel.Position = UDim2.new(0, 10, 0, 0)
        capLabel.BackgroundTransparency = 1
        capLabel.Font = Enum.Font.GothamBlack
        capLabel.TextSize = 9
        capLabel.TextXAlignment = Enum.TextXAlignment.Left
        capLabel.TextColor3 = Theme.soft
        capLabel.Text = label:upper()
        capLabel.Parent = cap

        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, -12, 0, 0)
        body.Position = UDim2.new(0, 6, 0, 26)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.Parent = outer
        local bl = Instance.new("UIListLayout")
        bl.Padding = UDim.new(0, 3)
        bl.Parent = body
        local bp = Instance.new("UIPadding")
        bp.PaddingBottom = UDim.new(0, 6)
        bp.Parent = body

        return body
    end

    -- rejilla de dos columnas
    local function grid(body)
        local g = Instance.new("Frame")
        g.Size = UDim2.new(1, 0, 0, 0)
        g.AutomaticSize = Enum.AutomaticSize.Y
        g.BackgroundTransparency = 1
        g.Parent = body
        local gl = Instance.new("UIGridLayout")
        gl.CellSize = UDim2.new(0.5, -3, 0, 32)
        gl.CellPadding = UDim2.new(0, 4, 0, 4)
        gl.SortOrder = Enum.SortOrder.LayoutOrder
        gl.Parent = g
        return g
    end

    local function toggle(parent, label, key, desc)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Theme.row
        row.BorderSizePixel = 0
        row.Text = ""
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -34, 0, 13)
        t.Position = UDim2.new(0, 8, 0, 4)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextTruncate = Enum.TextTruncate.AtEnd
        t.TextColor3 = Theme.text
        t.Text = label
        t.Parent = row

        if desc then
            local d = Instance.new("TextLabel")
            d.Size = UDim2.new(1, -34, 0, 10)
            d.Position = UDim2.new(0, 8, 0, 17)
            d.BackgroundTransparency = 1
            d.Font = Enum.Font.Gotham
            d.TextSize = 8.5
            d.TextXAlignment = Enum.TextXAlignment.Left
            d.TextTruncate = Enum.TextTruncate.AtEnd
            d.TextColor3 = Theme.muted
            d.Text = desc
            d.Parent = row
        end

        local track = Instance.new("Frame")
        track.AnchorPoint = Vector2.new(1, 0.5)
        track.Position = UDim2.new(1, -7, 0.5, 0)
        track.Size = UDim2.fromOffset(20, 11)
        track.BackgroundColor3 = Theme.track
        track.BorderSizePixel = 0
        track.Parent = row
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Position = UDim2.new(0, 2, 0.5, 0)
        knob.Size = UDim2.fromOffset(7, 7)
        knob.BackgroundColor3 = Theme.knob
        knob.BorderSizePixel = 0
        knob.Parent = track
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function paint()
            local v = Config[key]
            track.BackgroundColor3 = v and Theme.trackOn or Theme.track
            knob.Position = v and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
            knob.BackgroundColor3 = v and Color3.fromRGB(255, 255, 255) or Theme.knob
            row.BackgroundColor3 = v and Theme.rowOn or Theme.row
            t.TextColor3 = v and Theme.textOn or Theme.text
        end
        paint()

        row.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            paint()
        end)
    end

    local function slider(parent, label, key, min, max, suffix, dec)
        dec = dec or 0
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Theme.row
        row.BorderSizePixel = 0
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -62, 0, 13)
        t.Position = UDim2.new(0, 8, 0, 3)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextColor3 = Theme.text
        t.Text = label
        t.Parent = row

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0, 48, 0, 13)
        val.Position = UDim2.new(1, -54, 0, 3)
        val.BackgroundTransparency = 1
        val.Font = Enum.Font.GothamBold
        val.TextSize = 9.5
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.TextColor3 = Theme.accent
        val.Text = Util.fmt(Config[key], dec) .. (suffix or "")
        val.Parent = row

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -16, 0, 4)
        track.Position = UDim2.new(0, 8, 0, 22)
        track.BackgroundColor3 = Theme.track
        track.BorderSizePixel = 0
        track.Active = true
        track.Parent = row
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((Config[key] - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Theme.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local function apply(x)
            local rel = Util.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local value = tonumber(Util.fmt(min + (max - min) * rel, dec)) or min
            Config[key] = value
            fill.Size = UDim2.new(rel, 0, 1, 0)
            val.Text = Util.fmt(value, dec) .. (suffix or "")
            Config.validate()
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                State.activeSlider = apply
                apply(input.Position.X)
            end
        end)
    end

    local function actionButton(page, text, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Theme.accent
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(9, 13, 19)
        btn.Text = text
        btn.Parent = page
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    local function segmented(parent, options, current, onPick)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent = parent
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 4)
        layout.Parent = row

        local buttons = {}
        local function paint()
            for key, btn in pairs(buttons) do
                local active = current() == key
                btn.BackgroundColor3 = active and Theme.rowOn or Theme.row
                btn.TextColor3 = active and Theme.accent or Theme.muted
            end
        end
        for _, pair in ipairs(options) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1 / #options, -3, 1, 0)
            btn.BackgroundColor3 = Theme.row
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.TextColor3 = Theme.muted
            btn.Text = pair[2]
            btn.Parent = row
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            buttons[pair[1]] = btn
            btn.MouseButton1Click:Connect(function()
                onPick(pair[1])
                paint()
            end)
        end
        paint()
    end

    -- ═══ Farm ═══
    local farmPage = addPage("farm", "Farm")
    local farmBtn = actionButton(farmPage, "START FARM  ·  Q", function()
        State.requestFarm = true
    end)

    local farmPace = card(farmPage, "pace")
    slider(farmPace, "Delay between coins", "delay", 0.05, 1.5, "s", 2)
    slider(farmPace, "Search radius", "radius", 0, 600, "m")

    local farmMode = card(farmPage, "mode")
    segmented(farmMode, {{"teleport", "Teleport"}, {"walk", "Walk"}},
        function() return Config.mode end,
        function(v) Config.mode = v end)

    local farmOpts = card(farmPage, "options")
    local farmGrid = grid(farmOpts)
    toggle(farmGrid, "Pace variation", "humanize", "random delay")
    toggle(farmGrid, "Coin markers", "showMarkers", "boxes")

    -- ═══ Combat ═══
    local combatPage = addPage("combat", "Combat")
    actionButton(combatPage, "TOGGLE COMBAT  ·  E", function()
        Config.autoShoot = not Config.autoShoot
        Diagnostics.notify(Config.autoShoot and "Combat ON" or "Combat OFF")
    end)

    local combatWeapon = card(combatPage, "weapon")
    local weaponGrid = grid(combatWeapon)
    toggle(weaponGrid, "Auto shot", "autoShoot", "aim + fire")
    toggle(weaponGrid, "Auto equip", "autoEquip", "from backpack")

    local combatTarget = card(combatPage, "targeting")
    toggle(combatTarget, "Prioritize Murder", "aimAtMurder", "else closest")
    slider(combatTarget, "Range", "shootRange", 30, 500, "m")
    slider(combatTarget, "Fire rate", "shootDelay", 0.25, 3, "s", 2)
    slider(combatTarget, "Aim speed", "aimSmooth", 2, 30, "", 1)

    -- ═══ Roles ═══
    local rolePage = addPage("roles", "Roles")
    local roleCard = card(rolePage, "players")
    local roleList = Instance.new("Frame")
    roleList.Size = UDim2.new(1, 0, 0, 16)
    roleList.AutomaticSize = Enum.AutomaticSize.Y
    roleList.BackgroundTransparency = 1
    roleList.Parent = roleCard
    local rl = Instance.new("UIListLayout")
    rl.Padding = UDim.new(0, 2)
    rl.Parent = roleList

    local roleOpts = card(rolePage, "options")
    local roleGrid = grid(roleOpts)
    toggle(roleGrid, "Player ESP", "espPlayers", "role boxes")
    toggle(roleGrid, "Role list", "roleList", "show names")

    -- ═══ Misc ═══
    local miscPage = addPage("misc", "Misc")
    local miscInfo = card(miscPage, "legend")
    local legend = Instance.new("TextLabel")
    legend.Size = UDim2.new(1, 0, 0, 54)
    legend.BackgroundTransparency = 1
    legend.Font = Enum.Font.Gotham
    legend.TextSize = 9.5
    legend.TextWrapped = true
    legend.TextXAlignment = Enum.TextXAlignment.Left
    legend.TextYAlignment = Enum.TextYAlignment.Top
    legend.TextColor3 = Theme.muted
    legend.Text = "Red = Murder · Blue = Sheriff · Green = Innocent.\n\nIf the Sheriff dies and you take the gun, combat equips it by itself."
    legend.Parent = miscInfo

    local miscStart = card(miscPage, "startup")
    toggle(miscStart, "Auto start", "autoStart", "begin on execute")

    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, -20, 0, 12)
    footer.Position = UDim2.new(0, 10, 1, -28)
    footer.BackgroundTransparency = 1
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 8.5
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.TextColor3 = Theme.soft
    footer.Text = "RightShift menu · Q farm · E combat"
    footer.Parent = root

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -20, 0, 12)
    hint.Position = UDim2.new(0, 10, 1, -14)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 8.5
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextColor3 = Theme.soft
    hint.Text = "cursor unlocks only while the menu is open"
    hint.Parent = root

    local drag, dragStart, posStart
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            drag, dragStart, posStart = true, input.Position, root.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                posStart.X.Scale, posStart.X.Offset + delta.X,
                posStart.Y.Scale, posStart.Y.Offset + delta.Y)
        elseif State.activeSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            State.activeSlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
            State.activeSlider = nil
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        State.menuOpen = false
        root.Visible = false
        Cursor.set(false)
    end)

    selectPage("farm")

    local function renderRoles()
        for _, child in ipairs(roleList:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        local shown = 0
        for _, entry in ipairs(State.roles) do
            if shown >= 20 then break end
            shown += 1
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, 0, 0, 15)
            row.BackgroundTransparency = 1
            row.Font = Enum.Font.GothamBold
            row.TextSize = 9.5
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            row.TextColor3 = Roles.color(entry.role)
            row.Text = string.format("%s · %s", entry.plr.Name, entry.role)
            row.Parent = roleList
        end
    end

    return {
        gui = gui,
        root = root,
        farmBtn = farmBtn,
        renderRoles = renderRoles,
        setRunning = function(run)
            farmBtn.Text = run and "STOP FARM  ·  Q" or "START FARM  ·  Q"
            farmBtn.BackgroundColor3 = run and Theme.warn or Theme.accent
            farmBtn.TextColor3 = run and Color3.fromRGB(255, 255, 255)
                or Color3.fromRGB(9, 13, 19)
        end,
        setCollected = function(n)
            collectedLbl.Text = n .. " collected"
        end,
        setNearby = function(n)
            nearLbl.Text = n .. " on map"
        end,
        setMenu = function(open)
            State.menuOpen = open
            root.Visible = open
            Cursor.set(open)
        end,
    }
end

--=====================================================================
-- [Runtime]
--=====================================================================
local Runtime = {}

function Runtime.start()
    local ui = buildUI()

    local function setRunning(run)
        if State.running == run then return end
        State.running = run
        ui.setRunning(run)
        Diagnostics.notify(run and "Farm started" or "Farm stopped")
        Diagnostics.log(run and "farm on" or "farm off")
        if not run then return end

        task.spawn(function()
            while State.running do
                local ok, err = Util.try(function()
                    local hum, root = getRoot()
                    if not root then
                        State.status = "waiting"
                        task.wait(0.3)
                        return
                    end

                    local coin, dist = CoinScanner.nearest()
                    if not coin then
                        State.status = "no coins"
                        task.wait(0.25)
                        return
                    end

                    State.status = string.format("%d m", math.floor(dist))
                    if Config.mode == "teleport" then
                        Teleporter.hop(root, coin)
                    else
                        hum:MoveTo(coin.Position)
                    end

                    local wait = Config.delay
                    if Config.humanize then wait *= 0.8 + math.random() * 0.4 end
                    task.wait(wait)

                    if not coin.Parent then
                        State.collected += 1
                        ui.setCollected(State.collected)
                    else
                        State.blacklist[coin] = Util.now() + 2
                    end
                end)
                if not ok then Diagnostics.note(err) end
            end
        end)
    end

    ui.farmBtn.MouseButton1Click:Connect(function() setRunning(not State.running) end)

    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Config.menuKey then
            ui.setMenu(not State.menuOpen)
        elseif input.KeyCode == Config.farmKey then
            setRunning(not State.running)
        elseif input.KeyCode == Config.combatKey then
            Config.autoShoot = not Config.autoShoot
            Diagnostics.notify(Config.autoShoot and "Combat ON" or "Combat OFF")
        end
    end)

    Cursor.set(true)

    RunService:BindToRenderStep(
        "AleCam",
        Enum.RenderPriority.Camera.Value + 1,
        function(dt)
            local ok, err = Util.try(function()
                Cursor.tick(dt)
                Combat.step(dt)
            end)
            if not ok then Diagnostics.note(err) end
        end
    )

    local visualClock, roleClock, uiClock = 0, 0, 0

    RunService.RenderStepped:Connect(function(dt)
        local ok, err = Util.try(function()
            visualClock += dt
            if visualClock >= 0.06 then
                visualClock = 0
                Visuals.coins()
                Visuals.players()
            end

            roleClock += dt
            if roleClock >= 1 then
                roleClock = 0
                Roles.refresh()
                if Config.roleList and State.menuOpen then ui.renderRoles() end
            end

            uiClock += dt
            if uiClock >= 0.25 then
                uiClock = 0
                ui.setNearby(State.nearby)
                if statusLabel then
                    statusLabel.Text = State.running and (State.status or "searching") or "idle"
                end
                if combatLabel then
                    if Config.autoShoot then
                        combatLabel.Text = State.combatMsg ~= "" and State.combatMsg or "combat on"
                        combatLabel.TextColor3 = Theme.accent
                    else
                        combatLabel.Text = "combat off"
                        combatLabel.TextColor3 = Theme.muted
                    end
                end
            end
        end)
        if not ok then Diagnostics.note(err) end
    end)

    LP.CharacterAdded:Connect(function()
        task.wait(0.4)
        State.cache, State.cacheAt = {}, 0
        State.hadGun = false
    end)

    if Config.autoStart then
        task.delay(1.2, function() setRunning(true) end)
    end

    return {
        stop = function()
            State.running = false
            Visuals.clearAll()
            pcall(function() RunService:UnbindFromRenderStep("AleCam") end)
            Cursor.release()
            ui.gui:Destroy()
        end,
    }
end

Config.validate()
local app = Runtime.start()

game:BindToClose(function()
    if app then Util.try(app.stop) end
end)

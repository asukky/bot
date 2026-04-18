-- ===========================================================
-- DEVIL'S THRONE  —  DxD_Client.lua
-- LocalScript in StarterGui
-- ===========================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local MarketplaceService= game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local pGui      = player.PlayerGui

-- Wait for remotes
local RF        = ReplicatedStorage:WaitForChild("DxDRemotes", 20)
local fnLoad    = RF:WaitForChild("LoadData")
local fnSummon  = RF:WaitForChild("Summon")
local fnBattle  = RF:WaitForChild("BattleEnd")
local evSave    = RF:WaitForChild("SaveData")
local evNotify  = RF:WaitForChild("Notify")

local Data = require(ReplicatedStorage:WaitForChild("DxDData"))

-- ============================================================
-- COLOUR PALETTE
-- ============================================================
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local C = {
    BG         = rgb(6,  3,  12),
    SIDE       = rgb(11, 6,  20),
    PANEL      = rgb(14, 8,  24),
    CARD       = rgb(20, 12, 34),
    CARD2      = rgb(26, 16, 44),
    RED        = rgb(185,22, 48),
    RED_DIM    = rgb(100,14, 28),
    GOLD       = rgb(215,175,40),
    TEXT       = rgb(232,222,248),
    DIM        = rgb(138,122,162),
    BORDER     = rgb(38, 22, 60),
    GREEN      = rgb(55, 205,100),
    ORANGE     = rgb(235,130,35),
    SUCCESS    = rgb(40, 195,90),
    HP_FG      = rgb(55, 210,100),
    HP_BG      = rgb(20, 55, 32),
    SP_FG      = rgb(55, 150,235),
    SP_BG      = rgb(18, 40, 80),
    ENEMY_HP   = rgb(215,50, 60),
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    dp=0, totalDp=0, boostPoints=0, totalBp=0,
    prestigeCount=0, clickMult=1, prestigeMult=1,
    generators={}, upgrades={}, spins=5,
    ownedGears={}, equippedGear=nil, gamepasses={},
    clicks=0,
    dpPerSecond=0, dpPerClick=1,
    activePanel="train",
    notifications={},
    dirty=false,
    -- combat
    combat={
        active=false, enemyData=nil,
        playerHp=0, playerMaxHp=0, playerSp=0,
        enemyHp=0, enemyMaxHp=0,
        moveCooldowns={},
        log={},
        powerUpNext=1, shieldHits=0,
        autoRevive=false, autoReviveUsed=false,
        specialFired=false,
        playerDebuff=0, playerDebuffTurns=0,
        enemyDebuff=0, enemyDebuffTurns=0,
        enemyBurn=0, enemyBurnTurns=0,
    },
}

-- ============================================================
-- HELPERS
-- ============================================================
local SFX = {"","K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc","Ud","Dd"}
local function fmt(n)
    if not n or n~=n then return "0" end
    n = math.max(0, math.floor(n))
    local i, v = 1, n
    while v >= 1000 and i < #SFX do v = v/1000; i = i+1 end
    if i == 1 then return tostring(n) end
    return (tostring(math.floor(v*100)/100)):gsub("%.?0+$","")..SFX[i]
end
local function lerp(a,b,t) return a+(b-a)*t end
local function genCost(g, owned)
    return math.max(1, math.floor(g.baseCost * (g.mult ^ owned)))
end
local function getBpGain()
    local m = State.totalDp / 1e6
    if m < 0.001 then return 0 end
    return math.max(0, math.floor(math.sqrt(m)*0.6))
end
local function getPrestigeMult(bp)
    return 1 + math.sqrt(math.max(0,bp)) * 0.12
end

-- Production recalc
local function genMultiplier(genId)
    local m = 1
    for _, u in ipairs(Data.UPGRADES) do
        if State.upgrades[u.id] then
            if u.type=="gen" and u.gen==genId then m = m*u.mult
            elseif u.type=="global" then m = m*u.mult end
        end
    end
    return m
end
local function recalc()
    -- Sacred gear prod bonuses
    local gearProd = 0
    for _, og in ipairs(State.ownedGears) do
        for _, sg in ipairs(Data.SACRED_GEARS) do
            if sg.id == og.id then gearProd = gearProd + (sg.prodBonus or 0) break end
        end
    end
    -- VIP pass
    local vipMult = State.gamepasses.vip and 2 or 1

    local dps = 0
    for _, g in ipairs(Data.GENERATORS) do
        local cnt = State.generators[g.id] or 0
        if cnt > 0 then
            dps = dps + g.base * cnt * genMultiplier(g.id)
        end
    end
    local clickBase = 1
    for _, u in ipairs(Data.UPGRADES) do
        if u.type=="click" and State.upgrades[u.id] then
            clickBase = clickBase * u.mult
        end
    end
    State.dpPerSecond = dps * State.prestigeMult * vipMult * (1 + gearProd)
    State.dpPerClick  = math.max(1, clickBase * State.prestigeMult * vipMult)
end

-- ============================================================
-- UI BUILDER HELPERS
-- ============================================================
local function New(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() o[k] = v end)
        end
    end
    if parent then o.Parent = parent end
    return o
end
local function corner(r, p)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = p
end
local function stroke(col, thickness, p)
    local s = Instance.new("UIStroke"); s.Color=col; s.Thickness=thickness; s.Parent=p
end
local function gradient(seq, rot, p)
    local g = Instance.new("UIGradient"); g.Color=seq; g.Rotation=rot; g.Parent=p
end
local function padding(v, h, p)
    local pd = Instance.new("UIPadding")
    pd.PaddingTop=UDim.new(0,v); pd.PaddingBottom=UDim.new(0,v)
    pd.PaddingLeft=UDim.new(0,h); pd.PaddingRight=UDim.new(0,h)
    pd.Parent = p
end
local function listLayout(dir, spacing, p)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, spacing or 6)
    l.Parent = p
    return l
end
local function gridLayout(cellSize, spacing, p)
    local g = Instance.new("UIGridLayout")
    g.CellSize = cellSize
    g.CellPaddingStuds = spacing or UDim2.new(0,6,0,6)
    g.SortOrder = Enum.SortOrder.LayoutOrder
    g.Parent = p
    return g
end

local TI = TweenInfo.new
local function tween(inst, info, goal)
    return TweenService:Create(inst, info, goal)
end
local function flash(inst, col, dur)
    local orig = inst.BackgroundColor3
    inst.BackgroundColor3 = col
    task.delay(dur or 0.12, function()
        tween(inst, TI(0.2), {BackgroundColor3=orig}):Play()
    end)
end

local function notify(txt, col)
    table.insert(State.notifications, {text=txt, tc=col or C.GOLD, t=tick()})
end

local rarityColor = function(id)
    local r = Data.GetRarity(id)
    return rgb(r.r, r.g, r.b)
end

-- ============================================================
-- SCREEN SETUP
-- ============================================================
local prev = pGui:FindFirstChild("DxD"); if prev then prev:Destroy() end
local sg = New("ScreenGui", {Name="DxD", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, pGui)

-- ============================================================
-- ══════════════════════════════════════════════════════════
--   LOADING SCREEN
-- ══════════════════════════════════════════════════════════
-- ============================================================
local loadScreen = New("Frame", {
    Name="LoadScreen", Size=UDim2.new(1,0,1,0), BackgroundColor3=rgb(0,0,0),
    ZIndex=100,
}, sg)

-- Vignette gradient overlay
local vigFrame = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=0.3,
    BackgroundColor3=C.RED_DIM, ZIndex=101,
}, loadScreen)
gradient(ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(0.4, Color3.new(0,0,0)),
    ColorSequenceKeypoint.new(1, Color3.new(0,0,0)),
}), 0, vigFrame)

-- Thin horizontal accent line
local accentLine = New("Frame", {
    Size=UDim2.new(0,0,0,1), Position=UDim2.new(0,0,0.5,-0.5),
    BackgroundColor3=C.RED, ZIndex=103,
}, loadScreen)

-- Game title
local titleLbl = New("TextLabel", {
    Size=UDim2.new(0.8,0,0,68), Position=UDim2.new(0.1,0,0.32,0),
    BackgroundTransparency=1, Text="DEVIL'S THRONE",
    Font=Enum.Font.GothamBlack, TextSize=52,
    TextColor3=Color3.new(1,1,1), TextTransparency=1, ZIndex=104,
}, loadScreen)
gradient(ColorSequence.new({
    ColorSequenceKeypoint.new(0, rgb(255,60,60)),
    ColorSequenceKeypoint.new(0.6, rgb(255,220,80)),
    ColorSequenceKeypoint.new(1, rgb(220,60,255)),
}), 0, titleLbl)

local subtitleLbl = New("TextLabel", {
    Size=UDim2.new(0.7,0,0,28), Position=UDim2.new(0.15,0,0.52,0),
    BackgroundTransparency=1, Text="",
    Font=Enum.Font.Gotham, TextSize=18,
    TextColor3=C.DIM, TextTransparency=1, ZIndex=104,
}, loadScreen)

-- Progress bar
local progBg = New("Frame", {
    Size=UDim2.new(0.4,0,0,3), Position=UDim2.new(0.3,0,0.72,0),
    BackgroundColor3=rgb(30,15,50), ZIndex=104,
}, loadScreen)
corner(2, progBg)
local progFill = New("Frame", {
    Size=UDim2.new(0,0,1,0), BackgroundColor3=C.RED, ZIndex=105,
}, progBg)
corner(2, progFill)

local loadStatusLbl = New("TextLabel", {
    Size=UDim2.new(0.4,0,0,20), Position=UDim2.new(0.3,0,0.74,0),
    BackgroundTransparency=1, Text="Initializing...",
    Font=Enum.Font.Gotham, TextSize=11,
    TextColor3=C.DIM, TextTransparency=0, ZIndex=104,
}, loadScreen)

-- Loading animation sequence
local function runLoadingScreen(onComplete)
    local FULL_TEXT = "REINCARNATING AS A DEVIL"

    -- Line sweep
    tween(accentLine, TI(0.6, Enum.EasingStyle.Quad), {Size=UDim2.new(1,0,0,1)}):Play()
    task.wait(0.5)

    -- Title fade in
    tween(titleLbl, TI(0.8, Enum.EasingStyle.Quad), {TextTransparency=0}):Play()
    task.wait(0.7)

    -- Subtitle typewriter
    tween(subtitleLbl, TI(0.3), {TextTransparency=0}):Play()
    for i = 1, #FULL_TEXT do
        subtitleLbl.Text = string.sub(FULL_TEXT, 1, i)
        task.wait(0.045)
    end
    task.wait(0.3)

    -- Progress bar fill with status messages
    local steps = {
        { t="Loading Sacred Gears...",      p=0.20 },
        { t="Summoning Peerage Members...", p=0.45 },
        { t="Opening Devil's Gate...",      p=0.70 },
        { t="Reading your soul...",         p=0.90 },
        { t="Welcome to the Underworld.",   p=1.00 },
    }
    for _, step in ipairs(steps) do
        loadStatusLbl.Text = step.t
        tween(progFill, TI(0.4, Enum.EasingStyle.Quad), {Size=UDim2.new(step.p,0,1,0)}):Play()
        task.wait(0.45)
    end

    task.wait(0.4)

    -- Call the onComplete callback (loads data, builds UI)
    onComplete()

    task.wait(0.3)

    -- Fade out loading screen
    tween(loadScreen, TI(1.0, Enum.EasingStyle.Quad), {BackgroundTransparency=1}):Play()
    for _, d in ipairs(loadScreen:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("Frame") then
            pcall(function()
                tween(d, TI(0.8), {
                    BackgroundTransparency=1,
                    TextTransparency=1,
                }):Play()
            end)
        end
    end
    task.wait(1.1)
    loadScreen:Destroy()
end

-- ============================================================
-- ══════════════════════════════════════════════════════════
--   MAIN UI  (built before loading screen completes)
-- ══════════════════════════════════════════════════════════
-- ============================================================
local mainUI = New("Frame", {
    Name="Main", Size=UDim2.new(1,0,1,0),
    BackgroundColor3=C.BG, BackgroundTransparency=1, ZIndex=1,
}, sg)

-- ── TOP BAR ───────────────────────────────────────────────
local topBar = New("Frame", {
    Size=UDim2.new(1,0,0,50), BackgroundColor3=C.SIDE, ZIndex=3,
}, mainUI)
stroke(C.BORDER, 1, topBar)
New("Frame", {  -- bottom line
    Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2),
    BackgroundColor3=C.RED, ZIndex=4,
}, topBar)

local titleTop = New("TextLabel", {
    Size=UDim2.new(0,180,1,0), Position=UDim2.new(0,14,0,0),
    BackgroundTransparency=1, Text="DEVIL'S THRONE",
    Font=Enum.Font.GothamBlack, TextSize=17,
    TextColor3=C.TEXT, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, topBar)
gradient(ColorSequence.new({
    ColorSequenceKeypoint.new(0, rgb(220,55,55)),
    ColorSequenceKeypoint.new(1, rgb(215,175,40)),
}), 0, titleTop)

-- Stats in top bar
local function topStat(label, xPos, width, nameKey)
    local frame = New("Frame", {
        Size=UDim2.new(0,width,0,36), Position=UDim2.new(0,xPos,0.5,-18),
        BackgroundColor3=C.CARD, ZIndex=4,
    }, topBar)
    corner(6, frame)
    stroke(C.BORDER, 1, frame)
    local nameLbl = New("TextLabel", {
        Size=UDim2.new(1,0,0.45,0), Position=UDim2.new(0,0,0,0),
        BackgroundTransparency=1, Text=label,
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM, ZIndex=5,
    }, frame)
    local valLbl = New("TextLabel", {
        Size=UDim2.new(1,-8,0.55,0), Position=UDim2.new(0,4,0.45,0),
        BackgroundTransparency=1, Text="0",
        Font=Enum.Font.GothamBlack, TextSize=15, TextColor3=C.TEXT, ZIndex=5,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, frame)
    return valLbl
end
local dpValLbl   = topStat("DEMONIC POWER",   210, 148, "dp")
local dpsValLbl  = topStat("DP / SECOND",     368, 130, "dps")
local bpValLbl   = topStat("BOOST POINTS",    508, 120, "bp")
local spinsTopLbl= topStat("SPINS",           638, 80,  "spins")
spinsTopLbl.TextColor3 = C.GOLD

-- Rank label
local rankTopLbl = New("TextLabel", {
    Size=UDim2.new(0,170,1,0), Position=UDim2.new(1,-175,0,0),
    BackgroundTransparency=1, Text="Rank: Stray Devil",
    Font=Enum.Font.GothamBold, TextSize=12, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Right, ZIndex=4,
}, topBar)

-- ── SIDEBAR ────────────────────────────────────────────────
local sidebar = New("Frame", {
    Size=UDim2.new(0,72,1,-50), Position=UDim2.new(0,0,0,50),
    BackgroundColor3=C.SIDE, ZIndex=3,
}, mainUI)
New("Frame", {  -- right border line
    Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0),
    BackgroundColor3=C.BORDER, ZIndex=4,
}, sidebar)

local NAV_ITEMS = {
    { id="train",   label="TRAIN"   },
    { id="summon",  label="SUMMON"  },
    { id="battle",  label="BATTLE"  },
    { id="roster",  label="ROSTER"  },
    { id="shop",    label="SHOP"    },
    { id="stats",   label="STATS"   },
}

local navButtons = {}
local activeAccents = {}
for i, item in ipairs(NAV_ITEMS) do
    local yPos = (i-1) * 72
    local btn = New("TextButton", {
        Size=UDim2.new(1,0,0,72), Position=UDim2.new(0,0,0,yPos),
        BackgroundColor3=C.SIDE, BorderSizePixel=0,
        Text="", AutoButtonColor=false, ZIndex=4,
    }, sidebar)

    -- Active accent (left red bar)
    local accent = New("Frame", {
        Size=UDim2.new(0,3,0.55,0), Position=UDim2.new(0,0,0.225,0),
        BackgroundColor3=C.RED, ZIndex=5, BackgroundTransparency=1,
    }, btn)
    corner(2, accent)
    activeAccents[item.id] = accent

    New("TextLabel", {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text=item.label, Font=Enum.Font.GothamBold, TextSize=11,
        TextColor3=C.DIM, ZIndex=5,
    }, btn)

    navButtons[item.id] = btn
    btn.MouseEnter:Connect(function()
        if State.activePanel ~= item.id then
            tween(btn, TI(0.12), {BackgroundColor3=C.CARD}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.activePanel ~= item.id then
            tween(btn, TI(0.12), {BackgroundColor3=C.SIDE}):Play()
        end
    end)
end

-- ── CONTENT AREA ──────────────────────────────────────────
local contentArea = New("Frame", {
    Size=UDim2.new(1,-72,1,-50), Position=UDim2.new(0,72,0,50),
    BackgroundColor3=C.BG, ZIndex=2,
}, mainUI)

-- Panel container
local panels = {}
local function makePanel(id)
    local p = New("Frame", {
        Name=id, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Visible=false, ZIndex=2,
    }, contentArea)
    panels[id] = p
    return p
end

-- Panel switching
local function switchPanel(id)
    for pid, panel in pairs(panels) do
        panel.Visible = (pid == id)
    end
    for nid, btn in pairs(navButtons) do
        local isActive = (nid == id)
        btn.BackgroundColor3 = isActive and C.CARD2 or C.SIDE
        local lbl = btn:FindFirstChildOfClass("TextLabel")
        if lbl then lbl.TextColor3 = isActive and C.TEXT or C.DIM end
        tween(activeAccents[nid], TI(0.18), {
            BackgroundTransparency = isActive and 0 or 1
        }):Play()
    end
    State.activePanel = id
end

for id, btn in pairs(navButtons) do
    local capturedId = id
    btn.MouseButton1Click:Connect(function() switchPanel(capturedId) end)
end

-- ── NOTIFICATION LAYER ─────────────────────────────────────
local notifContainer = New("Frame", {
    Size=UDim2.new(0,320,0,200), Position=UDim2.new(0.5,-160,0.68,0),
    BackgroundTransparency=1, ZIndex=90,
}, sg)
local notifSlots = {}
for i = 1, 5 do
    local lbl = New("TextLabel", {
        Size=UDim2.new(1,0,0,30), Position=UDim2.new(0,0,0,(i-1)*34),
        BackgroundColor3=C.CARD, BackgroundTransparency=0.15,
        Text="", Font=Enum.Font.GothamBold, TextSize=13,
        TextColor3=C.GOLD, TextWrapped=true, ZIndex=91, Visible=false,
    }, notifContainer)
    corner(6, lbl)
    stroke(C.BORDER, 1, lbl)
    notifSlots[i] = lbl
end

-- ============================================================
-- PANEL: TRAIN
-- ============================================================
local trainPanel = makePanel("train")

-- Left: click area
local clickArea = New("Frame", {
    Size=UDim2.new(0.38,0,1,0), BackgroundTransparency=1, ZIndex=3,
}, trainPanel)

-- Click button
local clickBtnOuter = New("Frame", {
    Size=UDim2.new(0,158,0,158),
    Position=UDim2.new(0.5,-79,0,20),
    BackgroundColor3=C.RED_DIM, ZIndex=3,
}, clickArea)
corner(80, clickBtnOuter)
stroke(C.RED, 3, clickBtnOuter)

local clickBtn = New("TextButton", {
    Size=UDim2.new(1,-10,1,-10), Position=UDim2.new(0,5,0,5),
    BackgroundColor3=rgb(150,18,38), BorderSizePixel=0,
    Text="", AutoButtonColor=false, ZIndex=4,
}, clickBtnOuter)
corner(80, clickBtn)
gradient(ColorSequence.new({
    ColorSequenceKeypoint.new(0, rgb(175,22,45)),
    ColorSequenceKeypoint.new(1, rgb(65,8,18)),
}), 45, clickBtn)

New("TextLabel", {
    Size=UDim2.new(1,0,0.55,0), BackgroundTransparency=1,
    Text="D", Font=Enum.Font.GothamBlack, TextSize=62,
    TextColor3=Color3.new(1,1,1), ZIndex=5,
}, clickBtn)
New("TextLabel", {
    Size=UDim2.new(1,0,0.45,0), Position=UDim2.new(0,0,0.55,0),
    BackgroundTransparency=1, Text="TRAIN",
    Font=Enum.Font.GothamBlack, TextSize=16,
    TextColor3=C.TEXT, ZIndex=5,
}, clickBtn)

local clickDpcLbl = New("TextLabel", {
    Size=UDim2.new(0.9,0,0,18), Position=UDim2.new(0.05,0,0,184),
    BackgroundTransparency=1, Text="+1 DP per click",
    Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.DIM, ZIndex=3,
}, clickArea)
local comboLbl = New("TextLabel", {
    Size=UDim2.new(0.9,0,0,22), Position=UDim2.new(0.05,0,0,204),
    BackgroundTransparency=1, Text="",
    Font=Enum.Font.GothamBlack, TextSize=14, TextColor3=C.GOLD, ZIndex=3,
}, clickArea)

-- Generator list (scrollable, left panel lower section)
local genScrollFrame = New("Frame", {
    Size=UDim2.new(1,-12,1,-238), Position=UDim2.new(0,6,0,232),
    BackgroundTransparency=1, ZIndex=3,
}, clickArea)
New("TextLabel", {
    Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="PEERAGE  MEMBERS", Font=Enum.Font.GothamBlack,
    TextSize=11, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, genScrollFrame)
local genScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,0,1,-22), Position=UDim2.new(0,0,0,22),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=C.RED,
    CanvasSize=UDim2.new(0,0,0,#Data.GENERATORS*80),
    ZIndex=4,
}, genScrollFrame)

-- Right: upgrades
local upgradeArea = New("Frame", {
    Size=UDim2.new(0.62,-6,1,0), Position=UDim2.new(0.38,6,0,0),
    BackgroundTransparency=1, ZIndex=3,
}, trainPanel)
New("Frame", {
    Size=UDim2.new(0,1,1,0), BackgroundColor3=C.BORDER, ZIndex=3,
}, upgradeArea)

local upgHeader = New("TextLabel", {
    Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,10,0,8),
    BackgroundTransparency=1, Text="UPGRADES",
    Font=Enum.Font.GothamBlack, TextSize=13, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, upgradeArea)
local upgScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-16,1,-52), Position=UDim2.new(0,8,0,46),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=C.RED,
    CanvasSize=UDim2.new(0,0,0,math.ceil(#Data.UPGRADES/2)*80),
    ZIndex=4,
}, upgradeArea)

-- Build generator cards
local genUI = {}
for i, gen in ipairs(Data.GENERATORS) do
    local yp = (i-1)*78
    local col = rgb(gen.r, gen.g, gen.b)
    local card = New("Frame", {
        Size=UDim2.new(1,-4,0,72), Position=UDim2.new(0,2,0,yp),
        BackgroundColor3=C.CARD, ZIndex=5,
    }, genScroll)
    corner(7, card)
    stroke(col, 1.5, card)
    -- Color bar on left
    New("Frame", {
        Size=UDim2.new(0,4,1,0), BackgroundColor3=col, ZIndex=6,
    }, card)
    corner(4, card:FindFirstChildOfClass("Frame"))

    New("TextLabel", {
        Size=UDim2.new(0.55,0,0,20), Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1, Text=gen.name,
        Font=Enum.Font.GothamBold, TextSize=12, TextColor3=col,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.55,0,0,14), Position=UDim2.new(0,10,0,26),
        BackgroundTransparency=1, Text=gen.role,
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    local prodLbl = New("TextLabel", {
        Size=UDim2.new(0.55,0,0,13), Position=UDim2.new(0,10,0,40),
        BackgroundTransparency=1, Text="0 DP/s",
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.GREEN,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    local cntLbl = New("TextLabel", {
        Size=UDim2.new(0.3,0,0,28), Position=UDim2.new(0,10,0,42),
        BackgroundTransparency=1, Text="0",
        Font=Enum.Font.GothamBlack, TextSize=26, TextColor3=Color3.new(1,1,1),
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)

    -- Buy section
    local buyBg = New("Frame", {
        Size=UDim2.new(0.38,0,0,56), Position=UDim2.new(0.61,0,0.5,-28),
        BackgroundColor3=C.CARD2, ZIndex=6,
    }, card)
    corner(6, buyBg)
    local costLbl = New("TextLabel", {
        Size=UDim2.new(1,0,0.44,0), BackgroundTransparency=1,
        Text=fmt(gen.baseCost).." DP", Font=Enum.Font.GothamBold,
        TextSize=11, TextColor3=C.GOLD, ZIndex=7,
    }, buyBg)
    local buyBtn = New("TextButton", {
        Size=UDim2.new(0.82,0,0.48,0), Position=UDim2.new(0.09,0,0.48,0),
        BackgroundColor3=col, BorderSizePixel=0,
        Text="BUY", Font=Enum.Font.GothamBlack, TextSize=13,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=7,
    }, buyBg)
    corner(5, buyBtn)

    -- Lock overlay
    local lockOvr = New("Frame", {
        Size=UDim2.new(1,0,1,0), BackgroundColor3=C.BG,
        BackgroundTransparency=0.2, ZIndex=7,
    }, card)
    corner(7, lockOvr)
    lockOvr.Visible = gen.unlock > 0
    New("TextLabel", {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="Unlock at "..fmt(gen.unlock).." total DP",
        Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.DIM, ZIndex=8,
    }, lockOvr)

    genUI[gen.id] = {card=card, costLbl=costLbl, cntLbl=cntLbl, prodLbl=prodLbl, buyBtn=buyBtn, lockOvr=lockOvr, col=col}

    local gd = gen
    buyBtn.MouseButton1Click:Connect(function()
        local owned = State.generators[gd.id] or 0
        local cost  = genCost(gd, owned)
        if State.dp < cost then
            notify("Need "..fmt(cost).." DP for "..gd.name, C.RED); return
        end
        State.dp = State.dp - cost
        State.generators[gd.id] = owned + 1
        recalc(); State.dirty = true
        flash(card, col:Lerp(Color3.new(0,0,0),0.5))
        notify("Recruited "..gd.name, col)
    end)
    buyBtn.MouseEnter:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=col:Lerp(Color3.new(1,1,1),0.2)}):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=col}):Play()
    end)
end

-- Build upgrade cards (2-column grid)
local upgUI = {}
local COL_W = 0.49
for i, upg in ipairs(Data.UPGRADES) do
    local col_idx = ((i-1) % 2)
    local row_idx = math.floor((i-1) / 2)
    local xp = col_idx == 0 and 0 or 0.51
    local yp = row_idx * 78

    local card = New("Frame", {
        Size=UDim2.new(COL_W,-2,0,72),
        Position=UDim2.new(xp,col_idx==0 and 0 or 2,0,yp),
        BackgroundColor3=C.CARD, ZIndex=5,
    }, upgScroll)
    corner(7, card)
    local st = Instance.new("UIStroke"); st.Color=C.BORDER; st.Thickness=1; st.Parent=card

    New("TextLabel", {
        Size=UDim2.new(1,-8,0,18), Position=UDim2.new(0,8,0,6),
        BackgroundTransparency=1, Text=upg.name,
        Font=Enum.Font.GothamBold, TextSize=12, TextColor3=C.TEXT,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,8,0,24),
        BackgroundTransparency=1, Text=upg.desc,
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    local costLbl = New("TextLabel", {
        Size=UDim2.new(0.55,0,0,13), Position=UDim2.new(0,8,0,40),
        BackgroundTransparency=1, Text=fmt(upg.cost).." DP",
        Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.GOLD,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    local buyBtn = New("TextButton", {
        Size=UDim2.new(0.36,0,0,22), Position=UDim2.new(0.62,0,0,42),
        BackgroundColor3=rgb(100,40,180), BorderSizePixel=0,
        Text="BUY", Font=Enum.Font.GothamBlack, TextSize=12,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=6,
    }, card)
    corner(5, buyBtn)

    local boughtOvr = New("Frame", {
        Size=UDim2.new(1,0,1,0), BackgroundColor3=rgb(5,18,5),
        BackgroundTransparency=0.1, ZIndex=7, Visible=false,
    }, card)
    corner(7, boughtOvr)
    New("TextLabel", {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="PURCHASED", Font=Enum.Font.GothamBlack, TextSize=14,
        TextColor3=C.GREEN, ZIndex=8,
    }, boughtOvr)

    upgUI[upg.id] = {card=card, costLbl=costLbl, buyBtn=buyBtn, boughtOvr=boughtOvr, stroke=st}

    local ud = upg
    buyBtn.MouseButton1Click:Connect(function()
        if State.upgrades[ud.id] then return end
        local cost = ud.cost
        if State.dp < cost then notify("Need "..fmt(cost).." DP for "..ud.name, C.RED); return end
        local reqOk = true
        if ud.req then
            if ud.req.type == "gen" then
                reqOk = (State.generators[ud.req.gen] or 0) >= ud.req.val
                if not reqOk then notify("Need "..ud.req.val.." "..ud.req.gen.." first", C.RED) end
            elseif ud.req.type == "dp" then
                reqOk = State.totalDp >= ud.req.val
                if not reqOk then notify("Need "..fmt(ud.req.val).." total DP first", C.RED) end
            end
        end
        if not reqOk then return end
        State.dp = State.dp - cost
        State.upgrades[ud.id] = true
        recalc(); State.dirty = true
        boughtOvr.Visible = true; st.Color = C.GREEN
        flash(card, rgb(20,50,20))
        notify("Unlocked: "..ud.name, C.GREEN)
    end)
    buyBtn.MouseEnter:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=rgb(130,55,210)}):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=rgb(100,40,180)}):Play()
    end)
end

-- Click handler
local comboCount, comboTimer, lastClickTime = 0, 0, 0
local POOL = {}
for _ = 1, 12 do
    local lbl = New("TextLabel", {
        Size=UDim2.new(0,120,0,26), BackgroundTransparency=1,
        Font=Enum.Font.GothamBlack, TextSize=18,
        TextColor3=rgb(220,110,255), TextTransparency=1, ZIndex=20,
    }, sg)
    lbl.Visible = false
    POOL[#POOL+1] = {lbl=lbl, alive=false, ttl=0}
end
local function spawnParticle(amt)
    for _, p in ipairs(POOL) do
        if not p.alive then
            p.alive=true; p.ttl=0.75
            p.lbl.Text="+"..fmt(amt)
            p.lbl.TextTransparency=0
            p.lbl.TextColor3 = State.comboCount and State.comboCount>10 and C.ORANGE or rgb(180,100,255)
            p.lbl.Visible=true
            local rx=math.random(-80,80); local ry=math.random(-15,10)
            p.lbl.Position = UDim2.new(0.24,rx-60,0.33,ry)
            tween(p.lbl, TI(0.72,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                Position=UDim2.new(0.24,rx-60,0.23,ry-42), TextTransparency=1,
            }):Play()
            break
        end
    end
end

clickBtn.MouseButton1Click:Connect(function()
    local now = tick()
    if (now - lastClickTime) < 0.65 then
        comboCount = math.min(comboCount+1, 60)
    else
        comboCount = 1
    end
    comboTimer = 0.65; lastClickTime = now
    State.clicks = State.clicks + 1
    local comboMult = 1 + (comboCount * 0.04)
    local earned = math.max(1, math.floor(State.dpPerClick * comboMult))
    State.dp = State.dp + earned
    State.totalDp = State.totalDp + earned
    State.dirty = true
    spawnParticle(earned)
    tween(clickBtnOuter, TI(0.06), {Size=UDim2.new(0,148,0,148), Position=UDim2.new(0.5,-74,0,25)}):Play()
    task.delay(0.07, function()
        tween(clickBtnOuter, TI(0.12,Enum.EasingStyle.Bounce), {Size=UDim2.new(0,158,0,158), Position=UDim2.new(0.5,-79,0,20)}):Play()
    end)
end)
-- ===========================================================
-- DEVIL'S THRONE  —  DxD_Client_Part2.lua
-- Continuation of DxD_Client.lua  (paste directly after Part1)
-- ===========================================================

-- ============================================================
-- PANEL: SUMMON
-- ============================================================
local summonPanel = makePanel("summon")

-- Header
local sumHeader = New("Frame", {
    Size=UDim2.new(1,0,0,52), BackgroundColor3=C.PANEL, ZIndex=3,
}, summonPanel)
stroke(C.BORDER, 1, sumHeader)
New("TextLabel", {
    Size=UDim2.new(0.6,0,1,0), Position=UDim2.new(0,16,0,0),
    BackgroundTransparency=1, Text="SACRED GEAR SUMMON",
    Font=Enum.Font.GothamBlack, TextSize=22, TextColor3=C.TEXT,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, sumHeader)
local spinCountLbl = New("TextLabel", {
    Size=UDim2.new(0,180,1,0), Position=UDim2.new(1,-185,0,0),
    BackgroundTransparency=1, Text="5 SPINS AVAILABLE",
    Font=Enum.Font.GothamBold, TextSize=14, TextColor3=C.GOLD,
    TextXAlignment=Enum.TextXAlignment.Right, ZIndex=4,
}, sumHeader)

-- Rarity rates panel
local ratesPanel = New("Frame", {
    Size=UDim2.new(0.26,-10,1,-64), Position=UDim2.new(0.74,5,0,62),
    BackgroundColor3=C.PANEL, ZIndex=3,
}, summonPanel)
corner(8, ratesPanel)
stroke(C.BORDER, 1, ratesPanel)
New("TextLabel", {
    Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,4),
    BackgroundTransparency=1, Text="RATES",
    Font=Enum.Font.GothamBlack, TextSize=13, TextColor3=C.DIM, ZIndex=4,
}, ratesPanel)
for i, rar in ipairs(Data.RARITIES) do
    local pct = (rar.weight / Data.TOTAL_WEIGHT) * 100
    local pctStr = pct >= 1 and string.format("%.1f%%", pct) or string.format("%.2f%%", pct)
    local col = rgb(rar.r, rar.g, rar.b)
    local row = New("Frame", {
        Size=UDim2.new(1,-16,0,22), Position=UDim2.new(0,8,0,30+(i-1)*24),
        BackgroundTransparency=1, ZIndex=4,
    }, ratesPanel)
    New("TextLabel", {
        Size=UDim2.new(0.6,0,1,0), BackgroundTransparency=1,
        Text=rar.name, Font=Enum.Font.GothamBold, TextSize=12,
        TextColor3=col, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, row)
    New("TextLabel", {
        Size=UDim2.new(0.4,0,1,0), Position=UDim2.new(0.6,0,0,0),
        BackgroundTransparency=1, Text=pctStr,
        Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Right, ZIndex=5,
    }, row)
end

-- Main summon area
local sumMain = New("Frame", {
    Size=UDim2.new(0.73,-10,1,-64), Position=UDim2.new(0,5,0,62),
    BackgroundTransparency=1, ZIndex=3,
}, summonPanel)

-- Featured gears preview (top 6 rarest)
local featLabel = New("TextLabel", {
    Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,4),
    BackgroundTransparency=1, Text="FEATURED  SACRED  GEARS",
    Font=Enum.Font.GothamBlack, TextSize=11, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
}, sumMain)

local featuredGears = {}
for _, sg in ipairs(Data.SACRED_GEARS) do featuredGears[#featuredGears+1] = sg end
table.sort(featuredGears, function(a,b)
    return Data.GetRarity(a.rarity).weight < Data.GetRarity(b.rarity).weight
end)

for i = 1, math.min(6, #featuredGears) do
    local sg = featuredGears[i]
    local col = rarityColor(sg.rarity)
    local xp = (i-1) % 3
    local yp = math.floor((i-1) / 3)
    local card = New("Frame", {
        Size=UDim2.new(0.325,0,0,72), Position=UDim2.new(xp*0.337,0,0,28+yp*78),
        BackgroundColor3=C.CARD, ZIndex=4,
    }, sumMain)
    corner(7, card)
    stroke(col, 1.5, card)
    New("Frame", {
        Size=UDim2.new(1,0,0,3), BackgroundColor3=col, ZIndex=5,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,-8,0,20), Position=UDim2.new(0,4,0,8),
        BackgroundTransparency=1, Text=sg.name,
        Font=Enum.Font.GothamBold, TextSize=12, TextColor3=col,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, card)
    local rarName = Data.GetRarity(sg.rarity).name
    New("TextLabel", {
        Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,4,0,28),
        BackgroundTransparency=1, Text=rarName,
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=col,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,4,0,44),
        BackgroundTransparency=1,
        Text=string.format("+%.0f%% Prod | %d Moves", sg.prodBonus*100, #sg.moves),
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, card)
end

-- Summon buttons
local function mkSumBtn(txt, xPos, w, cost)
    local btn = New("TextButton", {
        Size=UDim2.new(0,w,0,48), Position=UDim2.new(0,xPos,1,-60),
        BackgroundColor3=C.RED, BorderSizePixel=0,
        Text="", AutoButtonColor=false, ZIndex=4,
    }, sumMain)
    corner(8, btn)
    stroke(C.RED, 2, btn)
    New("TextLabel", {
        Size=UDim2.new(1,0,0.5,0), BackgroundTransparency=1,
        Text=txt, Font=Enum.Font.GothamBlack, TextSize=16,
        TextColor3=Color3.new(1,1,1), ZIndex=5,
    }, btn)
    New("TextLabel", {
        Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0),
        BackgroundTransparency=1,
        Text=cost.." spin"..(cost>1 and "s" or ""),
        Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.DIM, ZIndex=5,
    }, btn)
    btn.MouseEnter:Connect(function()
        tween(btn, TI(0.1), {BackgroundColor3=C.RED:Lerp(Color3.new(1,1,1),0.15)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, TI(0.1), {BackgroundColor3=C.RED}):Play()
    end)
    return btn
end

local totalW = sumMain.AbsoluteSize.X > 0 and sumMain.AbsoluteSize.X or 600
local sumBtn1  = mkSumBtn("SUMMON  x1",  0,   190, 1)
local sumBtn10 = mkSumBtn("SUMMON  x10", 200, 190, 10)

-- Buy spins button
local buySpinsBtn = New("TextButton", {
    Size=UDim2.new(0,148,0,48), Position=UDim2.new(0,400,1,-60),
    BackgroundColor3=rgb(155,125,0), BorderSizePixel=0,
    Text="", AutoButtonColor=false, ZIndex=4,
}, sumMain)
corner(8, buySpinsBtn)
stroke(C.GOLD, 1.5, buySpinsBtn)
New("TextLabel", {
    Size=UDim2.new(1,0,0.5,0), BackgroundTransparency=1,
    Text="BUY SPINS", Font=Enum.Font.GothamBlack, TextSize=14,
    TextColor3=C.GOLD, ZIndex=5,
}, buySpinsBtn)
New("TextLabel", {
    Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0),
    BackgroundTransparency=1, Text="Robux",
    Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.DIM, ZIndex=5,
}, buySpinsBtn)
buySpinsBtn.MouseButton1Click:Connect(function() switchPanel("shop") end)

-- ── SUMMON RESULT OVERLAY ──────────────────────────────────
local sumOvr = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=rgb(0,0,0),
    BackgroundTransparency=0.45, ZIndex=80, Visible=false,
}, sg)

local sumBox = New("Frame", {
    Size=UDim2.new(0,700,0,420), Position=UDim2.new(0.5,-350,0.5,-210),
    BackgroundColor3=C.PANEL, ZIndex=81,
}, sumOvr)
corner(12, sumBox)
stroke(C.BORDER, 2, sumBox)

New("TextLabel", {
    Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,8),
    BackgroundTransparency=1, Text="SUMMON  RESULTS",
    Font=Enum.Font.GothamBlack, TextSize=18, TextColor3=C.TEXT, ZIndex=82,
}, sumBox)

local resultGrid = New("Frame", {
    Size=UDim2.new(1,-20,0,300), Position=UDim2.new(0,10,0,50),
    BackgroundTransparency=1, ZIndex=82,
}, sumBox)

local sumCloseBtn = New("TextButton", {
    Size=UDim2.new(0,180,0,38), Position=UDim2.new(0.5,-90,1,-52),
    BackgroundColor3=C.RED, BorderSizePixel=0,
    Text="CLOSE", Font=Enum.Font.GothamBlack, TextSize=14,
    TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=83,
}, sumBox)
corner(8, sumCloseBtn)
sumCloseBtn.MouseButton1Click:Connect(function()
    tween(sumOvr, TI(0.2), {BackgroundTransparency=1}):Play()
    task.delay(0.22, function() sumOvr.Visible=false end)
end)

local function showSummonResults(results)
    -- Clear old result cards
    for _, c in ipairs(resultGrid:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    local count = #results
    local cols = math.min(count, 5)
    local cardW = math.floor((resultGrid.AbsoluteSize.X > 0 and resultGrid.AbsoluteSize.X or 660) / cols) - 8

    for i, result in ipairs(results) do
        local col_i = (i-1) % 5
        local row_i = math.floor((i-1) / 5)
        local col = rarityColor(result.rarity)

        local card = New("Frame", {
            Size=UDim2.new(0,cardW,0,130),
            Position=UDim2.new(0, col_i*(cardW+8), 0, row_i*138),
            BackgroundColor3=C.CARD, ZIndex=83,
        }, resultGrid)
        corner(8, card)
        stroke(col, 2, card)

        -- Top rarity color bar
        New("Frame", {
            Size=UDim2.new(1,0,0,4), BackgroundColor3=col, ZIndex=84,
        }, card)

        -- Rarity glow tween
        tween(card, TI(0.4, Enum.EasingStyle.Quad), {BackgroundColor3=col:Lerp(C.CARD, 0.85)}):Play()
        task.delay(0.45, function()
            tween(card, TI(0.4), {BackgroundColor3=C.CARD}):Play()
        end)

        local rarName = Data.GetRarity(result.rarity).name
        New("TextLabel", {
            Size=UDim2.new(1,-6,0,16), Position=UDim2.new(0,3,0,10),
            BackgroundTransparency=1, Text=rarName:upper(),
            Font=Enum.Font.GothamBlack, TextSize=11, TextColor3=col, ZIndex=84,
        }, card)
        New("TextLabel", {
            Size=UDim2.new(1,-6,0,36), Position=UDim2.new(0,3,0,28),
            BackgroundTransparency=1, Text=result.name,
            Font=Enum.Font.GothamBold, TextSize=13, TextColor3=C.TEXT,
            TextWrapped=true, ZIndex=84,
        }, card)

        -- Moves count
        local moveCount = 0
        for _, sg in ipairs(Data.SACRED_GEARS) do
            if sg.id == result.id then moveCount = #sg.moves break end
        end
        New("TextLabel", {
            Size=UDim2.new(1,-6,0,14), Position=UDim2.new(0,3,0,72),
            BackgroundTransparency=1, Text=moveCount.." Combat Moves",
            Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM, ZIndex=84,
        }, card)

        -- Stagger animation
        card.BackgroundTransparency = 1
        task.delay(i * 0.08, function()
            tween(card, TI(0.25), {BackgroundTransparency=0}):Play()
        end)
    end

    sumOvr.BackgroundTransparency = 1
    sumOvr.Visible = true
    tween(sumOvr, TI(0.2), {BackgroundTransparency=0.45}):Play()
end

local function doSummon(count)
    if State.spins < count then
        notify("Not enough spins! Buy more in the Shop.", C.RED); return
    end
    local results, newSpins = fnSummon:InvokeServer(count)
    if not results then notify("Summon failed. Try again.", C.RED); return end
    State.spins = newSpins
    -- Add to local owned list
    for _, r in ipairs(results) do
        table.insert(State.ownedGears, {id=r.id, rarity=r.rarity})
    end
    recalc()
    showSummonResults(results)
end

sumBtn1.MouseButton1Click:Connect(function() doSummon(1) end)
sumBtn10.MouseButton1Click:Connect(function() doSummon(10) end)

-- ============================================================
-- PANEL: BATTLE
-- ============================================================
local battlePanel = makePanel("battle")

-- Left: enemy list
local enemyListArea = New("Frame", {
    Size=UDim2.new(0.28,-5,1,0), BackgroundColor3=C.PANEL,
    ZIndex=3,
}, battlePanel)
corner(0, enemyListArea)
stroke(C.BORDER, 1, enemyListArea)
New("TextLabel", {
    Size=UDim2.new(1,0,0,32), Position=UDim2.new(0,0,0,0),
    BackgroundTransparency=1, Text="ENEMIES",
    Font=Enum.Font.GothamBlack, TextSize=12, TextColor3=C.DIM, ZIndex=4,
}, enemyListArea)
local enemyScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-4,1,-34), Position=UDim2.new(0,2,0,34),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=C.RED,
    CanvasSize=UDim2.new(0,0,0,#Data.ENEMIES*90),
    ZIndex=4,
}, enemyListArea)

-- Right: battle arena
local arenaArea = New("Frame", {
    Size=UDim2.new(0.72,-5,1,0), Position=UDim2.new(0.28,5,0,0),
    BackgroundTransparency=1, ZIndex=3,
}, battlePanel)

-- ── Arena layout ──────────────────────────────────────────
local arenaTitle = New("TextLabel", {
    Size=UDim2.new(1,0,0,32), Position=UDim2.new(0,0,0,0),
    BackgroundTransparency=1, Text="Select an enemy to begin",
    Font=Enum.Font.GothamBlack, TextSize=15, TextColor3=C.DIM, ZIndex=4,
}, arenaArea)

-- Player combat card
local playerCard = New("Frame", {
    Size=UDim2.new(0.44,-5,0,130), Position=UDim2.new(0,0,0,40),
    BackgroundColor3=C.CARD, ZIndex=4,
}, arenaArea)
corner(8, playerCard)
stroke(C.BORDER, 1.5, playerCard)
New("TextLabel", {
    Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,8,0,6),
    BackgroundTransparency=1, Text=player.Name,
    Font=Enum.Font.GothamBold, TextSize=13, TextColor3=C.TEXT,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, playerCard)
local playerGearLbl = New("TextLabel", {
    Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,8,0,26),
    BackgroundTransparency=1, Text="No Sacred Gear equipped",
    Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, playerCard)
local playerHpBar = New("Frame", {
    Size=UDim2.new(1,-16,0,12), Position=UDim2.new(0,8,0,46),
    BackgroundColor3=C.HP_BG, ZIndex=5,
}, playerCard)
corner(6, playerHpBar)
local playerHpFill = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=C.HP_FG, ZIndex=6,
}, playerHpBar)
corner(6, playerHpFill)
local playerHpLbl = New("TextLabel", {
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="HP: 1000/1000", Font=Enum.Font.GothamBold, TextSize=9,
    TextColor3=Color3.new(1,1,1), ZIndex=7,
}, playerHpBar)
local playerSpBar = New("Frame", {
    Size=UDim2.new(1,-16,0,10), Position=UDim2.new(0,8,0,64),
    BackgroundColor3=C.SP_BG, ZIndex=5,
}, playerCard)
corner(5, playerSpBar)
local playerSpFill = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=C.SP_FG, ZIndex=6,
}, playerSpBar)
corner(5, playerSpFill)
local playerSpLbl = New("TextLabel", {
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="SP: 100/100", Font=Enum.Font.GothamBold, TextSize=9,
    TextColor3=Color3.new(1,1,1), ZIndex=7,
}, playerSpBar)
local statusLbl = New("TextLabel", {
    Size=UDim2.new(1,-8,0,13), Position=UDim2.new(0,8,0,80),
    BackgroundTransparency=1, Text="",
    Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.ORANGE,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, playerCard)

-- VS divider
New("TextLabel", {
    Size=UDim2.new(0,48,0,48), Position=UDim2.new(0.44,2,0,81),
    BackgroundTransparency=1, Text="VS",
    Font=Enum.Font.GothamBlack, TextSize=22,
    TextColor3=C.RED, ZIndex=4,
}, arenaArea)

-- Enemy combat card
local enemyCard = New("Frame", {
    Size=UDim2.new(0.44,-5,0,130), Position=UDim2.new(0.56,0,0,40),
    BackgroundColor3=C.CARD, ZIndex=4,
}, arenaArea)
corner(8, enemyCard)
stroke(C.RED, 1.5, enemyCard)
local enemyNameLbl = New("TextLabel", {
    Size=UDim2.new(1,-8,0,20), Position=UDim2.new(0,8,0,6),
    BackgroundTransparency=1, Text="???",
    Font=Enum.Font.GothamBold, TextSize=13, TextColor3=C.TEXT,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, enemyCard)
local enemyTitleLbl = New("TextLabel", {
    Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,8,0,26),
    BackgroundTransparency=1, Text="",
    Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, enemyCard)
local enemyHpBar = New("Frame", {
    Size=UDim2.new(1,-16,0,12), Position=UDim2.new(0,8,0,46),
    BackgroundColor3=rgb(55,12,18), ZIndex=5,
}, enemyCard)
corner(6, enemyHpBar)
local enemyHpFill = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=C.ENEMY_HP, ZIndex=6,
}, enemyHpBar)
corner(6, enemyHpFill)
local enemyHpLbl = New("TextLabel", {
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="HP: ???", Font=Enum.Font.GothamBold, TextSize=9,
    TextColor3=Color3.new(1,1,1), ZIndex=7,
}, enemyHpBar)
local enemyStatusLbl = New("TextLabel", {
    Size=UDim2.new(1,-8,0,13), Position=UDim2.new(0,8,0,64),
    BackgroundTransparency=1, Text="",
    Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.ORANGE,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, enemyCard)

-- Move buttons area
local movesArea = New("Frame", {
    Size=UDim2.new(1,0,0,110), Position=UDim2.new(0,0,0,178),
    BackgroundTransparency=1, ZIndex=4,
}, arenaArea)
New("TextLabel", {
    Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="SACRED GEAR MOVES", Font=Enum.Font.GothamBlack,
    TextSize=11, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
}, movesArea)
local moveBtns = {}
for m = 1, 3 do
    local xp = (m-1) * 0.335
    local btn = New("TextButton", {
        Size=UDim2.new(0.325,0,0,82), Position=UDim2.new(xp,0,0,22),
        BackgroundColor3=C.CARD2, BorderSizePixel=0,
        Text="", AutoButtonColor=false, ZIndex=5, Visible=false,
    }, movesArea)
    corner(8, btn)
    stroke(C.BORDER, 1.5, btn)
    local nameLbl = New("TextLabel", {
        Size=UDim2.new(1,-6,0,18), Position=UDim2.new(0,3,0,5),
        BackgroundTransparency=1, Text="",
        Font=Enum.Font.GothamBold, TextSize=13, TextColor3=C.TEXT, ZIndex=6,
    }, btn)
    local descLbl = New("TextLabel", {
        Size=UDim2.new(1,-6,0,26), Position=UDim2.new(0,3,0,23),
        BackgroundTransparency=1, Text="",
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM,
        TextWrapped=true, ZIndex=6,
    }, btn)
    local spLbl = New("TextLabel", {
        Size=UDim2.new(0.5,0,0,13), Position=UDim2.new(0,3,1,-17),
        BackgroundTransparency=1, Text="",
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.SP_FG, ZIndex=6,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, btn)
    local cdLbl = New("TextLabel", {
        Size=UDim2.new(0.5,0,0,13), Position=UDim2.new(0.5,0,1,-17),
        BackgroundTransparency=1, Text="",
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM, ZIndex=6,
        TextXAlignment=Enum.TextXAlignment.Right,
    }, btn)
    moveBtns[m] = {btn=btn, nameLbl=nameLbl, descLbl=descLbl, spLbl=spLbl, cdLbl=cdLbl}
end

-- Battle log
local battleLogFrame = New("Frame", {
    Size=UDim2.new(1,0,0,100), Position=UDim2.new(0,0,0,296),
    BackgroundColor3=C.CARD, ZIndex=4,
}, arenaArea)
corner(8, battleLogFrame)
stroke(C.BORDER, 1, battleLogFrame)
local battleLogScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-8,1,-8), Position=UDim2.new(0,4,0,4),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=3, ScrollBarImageColor3=C.RED,
    CanvasSize=UDim2.new(0,0,0,0), ZIndex=5,
}, battleLogFrame)
local battleLogLayout = listLayout(Enum.FillDirection.Vertical, 2, battleLogScroll)

local function addLog(text, col)
    local lbl = New("TextLabel", {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1,
        Text=text, Font=Enum.Font.Gotham, TextSize=11,
        TextColor3=col or C.DIM, ZIndex=6,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, battleLogScroll)
    task.wait()
    battleLogScroll.CanvasSize = UDim2.new(0,0,0,battleLogLayout.AbsoluteContentSize.Y)
    battleLogScroll.CanvasPosition = Vector2.new(0, battleLogScroll.CanvasSize.Y.Offset)
    table.insert(State.combat.log, text)
    if #battleLogScroll:GetChildren() > 40 then
        battleLogScroll:GetChildren()[2]:Destroy()
    end
end

-- Enemy list cards
local enemyUI = {}
for i, enemy in ipairs(Data.ENEMIES) do
    local yp = (i-1)*88
    local col = rgb(enemy.r, enemy.g, enemy.b)
    local card = New("Frame", {
        Size=UDim2.new(1,-6,0,82), Position=UDim2.new(0,3,0,yp),
        BackgroundColor3=C.CARD, ZIndex=5,
    }, enemyScroll)
    corner(7, card)
    stroke(col, 1.5, card)

    New("Frame", {
        Size=UDim2.new(0,4,1,0), BackgroundColor3=col, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.68,0,0,18), Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1, Text=enemy.name,
        Font=Enum.Font.GothamBold, TextSize=12, TextColor3=col,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.68,0,0,13), Position=UDim2.new(0,10,0,24),
        BackgroundTransparency=1, Text=enemy.title,
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.68,0,0,13), Position=UDim2.new(0,10,0,37),
        BackgroundTransparency=1,
        Text="HP: "..fmt(enemy.hp).."  ATK: "..fmt(enemy.atk),
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.68,0,0,13), Position=UDim2.new(0,10,0,50),
        BackgroundTransparency=1,
        Text="Reward: "..fmt(enemy.bpReward).." BP + "..fmt(enemy.dpReward).." DP",
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.GOLD,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    }, card)

    local fightBtn = New("TextButton", {
        Size=UDim2.new(0.27,0,0,30), Position=UDim2.new(0.72,0,0.5,-15),
        BackgroundColor3=col, BorderSizePixel=0,
        Text="FIGHT", Font=Enum.Font.GothamBlack, TextSize=12,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=6,
    }, card)
    corner(6, fightBtn)
    enemyUI[enemy.id] = {card=card, btn=fightBtn, col=col}

    fightBtn.MouseEnter:Connect(function()
        tween(fightBtn, TI(0.1), {BackgroundColor3=col:Lerp(Color3.new(1,1,1),0.2)}):Play()
    end)
    fightBtn.MouseLeave:Connect(function()
        tween(fightBtn, TI(0.1), {BackgroundColor3=col}):Play()
    end)

    local ed = enemy
    fightBtn.MouseButton1Click:Connect(function()
        if State.combat.active then notify("Already in battle!", C.ORANGE); return end
        if ed.reqGear and not State.equippedGear then
            notify("Equip a Sacred Gear first! (Roster tab)", C.RED); return
        end
        -- Start battle
        State.combat.active = true
        State.combat.enemyData = ed
        State.combat.playerMaxHp = 1000 + State.prestigeCount * 200
        State.combat.playerHp    = State.combat.playerMaxHp
        State.combat.playerSp    = 100
        State.combat.enemyHp     = ed.hp
        State.combat.enemyMaxHp  = ed.hp
        State.combat.moveCooldowns = {}
        State.combat.powerUpNext   = 1
        State.combat.shieldHits    = 0
        State.combat.autoRevive    = false
        State.combat.autoReviveUsed= false
        State.combat.specialFired  = false
        State.combat.playerDebuff  = 0
        State.combat.playerDebuffTurns = 0
        State.combat.enemyDebuff   = 0
        State.combat.enemyDebuffTurns  = 0
        State.combat.enemyBurn     = 0
        State.combat.enemyBurnTurns= 0

        -- Clear log
        for _, c in ipairs(battleLogScroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        battleLogScroll.CanvasSize = UDim2.new(0,0,0,0)

        -- Update arena
        arenaTitle.Text = "BATTLE  —  " .. ed.name
        enemyNameLbl.Text  = ed.name
        enemyTitleLbl.Text = ed.title
        enemyHpLbl.Text  = "HP: "..fmt(ed.hp).."/"..fmt(ed.hp)
        enemyHpFill.Size = UDim2.new(1,0,1,0)

        -- Gear info
        local gearData = nil
        if State.equippedGear then
            for _, sg in ipairs(Data.SACRED_GEARS) do
                if sg.id == State.equippedGear then gearData = sg break end
            end
        end
        playerGearLbl.Text = gearData and gearData.name or "No Gear"

        -- Load move buttons
        for m = 1, 3 do
            local mb = moveBtns[m]
            local move = gearData and gearData.moves[m]
            if move then
                mb.btn.Visible = true
                mb.nameLbl.Text = move.name
                mb.descLbl.Text = move.desc
                mb.spLbl.Text   = "SP: "..move.sp
                mb.cdLbl.Text   = move.cooldown==0 and "No CD" or "CD: "..move.cooldown.."t"
                State.combat.moveCooldowns[m] = 0

                local capturedMove = move
                local capturedIdx  = m
                mb.btn.MouseButton1Click:Connect(function()
                    if not State.combat.active then return end
                    if State.combat.moveCooldowns[capturedIdx] > 0 then
                        notify("Move on cooldown: "..State.combat.moveCooldowns[capturedIdx].." turns", C.DIM); return
                    end
                    if State.combat.playerSp < capturedMove.sp then
                        notify("Not enough SP! Need "..capturedMove.sp, C.SP_FG); return
                    end
                    -- Execute player move
                    task.spawn(function()
                        local CB = State.combat
                        CB.playerSp = CB.playerSp - capturedMove.sp
                        CB.moveCooldowns[capturedIdx] = capturedMove.cooldown
                        local baseAtk = 50 + State.prestigeCount*10

                        -- Apply power_up buff
                        local atk = baseAtk * CB.powerUpNext
                        CB.powerUpNext = 1

                        -- Apply auto_revive setup
                        if capturedMove.effect == "auto_revive" then
                            CB.autoRevive = true
                            addLog("Resurrection: Will revive at 50% HP once!", C.GOLD)
                        end

                        -- Damage
                        if capturedMove.type == "damage" then
                            -- Special: divide
                            local dmg = 0
                            if capturedMove.effect == "divide" then
                                dmg = math.floor(CB.enemyHp * capturedMove.effectVal)
                            else
                                -- Pack Strike (4 hits)
                                if capturedMove.name == "Pack Strike" then
                                    dmg = math.floor(atk * capturedMove.dmgMult * 4)
                                    addLog(capturedMove.name..": 4-hit combo for "..fmt(dmg).." total!", C.TEXT)
                                elseif capturedMove.name == "Storm Surge" then
                                    dmg = math.floor(atk * capturedMove.dmgMult * 3)
                                    addLog(capturedMove.name..": 3-hit barrage for "..fmt(dmg).." total!", C.TEXT)
                                else
                                    dmg = math.floor(atk * capturedMove.dmgMult)
                                end
                            end

                            -- Enemy debuff reduces incoming player dmg? No — enemy debuff reduces enemy's atk
                            -- Enemy shield?
                            dmg = math.max(1, dmg)
                            CB.enemyHp = math.max(0, CB.enemyHp - dmg)
                            if capturedMove.effect ~= "divide" and capturedMove.name ~= "Pack Strike" and capturedMove.name ~= "Storm Surge" then
                                addLog(capturedMove.name..": "..fmt(dmg).." damage!", C.TEXT)
                            end

                            -- Apply additional effect
                            if capturedMove.effect == "burn" then
                                CB.enemyBurn      = math.floor(atk * capturedMove.effectVal)
                                CB.enemyBurnTurns = capturedMove.effectTurns
                                addLog("  + Burning! "..fmt(CB.enemyBurn).." per turn for "..capturedMove.effectTurns.." turns", C.ORANGE)
                            elseif capturedMove.effect == "stun" then
                                -- enemy skip handled in enemy turn section
                                CB.enemyDebuffTurns = capturedMove.effectTurns + 100  -- flag stun
                                CB.enemyDebuff = 0
                                addLog("  + "..ed.name.." is stunned for "..capturedMove.effectTurns.." turns!", C.GOLD)
                            elseif capturedMove.effect == "weaken" then
                                CB.enemyDebuff      = capturedMove.effectVal
                                CB.enemyDebuffTurns = capturedMove.effectTurns
                                addLog(string.format("  + %s weakened %.0f%% for %d turns", ed.name, capturedMove.effectVal*100, capturedMove.effectTurns), C.DIM)
                            end
                        elseif capturedMove.type == "heal" then
                            local healAmt = math.floor(CB.playerMaxHp * capturedMove.healPct)
                            CB.playerHp = math.min(CB.playerMaxHp, CB.playerHp + healAmt)
                            addLog(capturedMove.name..": Healed "..fmt(healAmt).." HP!", C.GREEN)
                            if capturedMove.effect == "weaken" then
                                CB.enemyDebuff = capturedMove.effectVal
                                CB.enemyDebuffTurns = capturedMove.effectTurns
                            end
                        elseif capturedMove.type == "buff" then
                            if capturedMove.effect == "power_up" then
                                CB.powerUpNext = capturedMove.effectVal
                                addLog(capturedMove.name..": Next attack x"..capturedMove.effectVal.."!", C.GOLD)
                            elseif capturedMove.effect == "shield" then
                                CB.shieldHits = capturedMove.effectVal
                                addLog(capturedMove.name..": Shield absorbs next "..math.floor(capturedMove.effectVal).." hits!", C.SP_FG)
                            end
                        elseif capturedMove.type == "debuff" then
                            CB.enemyDebuff = capturedMove.effectVal
                            CB.enemyDebuffTurns = capturedMove.effectTurns
                            addLog(string.format("%s: %s weakened %.0f%% for %d turns", capturedMove.name, ed.name, capturedMove.effectVal*100, capturedMove.effectTurns), C.DIM)
                            if capturedMove.type == "damage" and capturedMove.dmgMult > 0 then
                                local dmg = math.floor(atk * capturedMove.dmgMult)
                                CB.enemyHp = math.max(0, CB.enemyHp - dmg)
                                addLog("  + "..fmt(dmg).." damage!", C.TEXT)
                            end
                        elseif capturedMove.type == "utility" then
                            if capturedMove.effect == "stun" then
                                CB.enemyDebuffTurns = capturedMove.effectTurns + 100
                                CB.enemyDebuff = 0
                                addLog(capturedMove.name..": "..ed.name.." stunned for "..capturedMove.effectTurns.." turns!", C.GOLD)
                            end
                        end

                        -- Decrement cooldowns
                        for idx = 1, 3 do
                            if CB.moveCooldowns[idx] and CB.moveCooldowns[idx] > 0 then
                                CB.moveCooldowns[idx] = CB.moveCooldowns[idx] - 1
                            end
                        end

                        -- Check win
                        if CB.enemyHp <= 0 then
                            CB.active = false
                            addLog("VICTORY! "..ed.name.." defeated!", C.SUCCESS)
                            arenaTitle.Text = "VICTORY!"
                            notify("Defeated "..ed.name.."! +"..fmt(ed.bpReward).." BP, +"..fmt(ed.dpReward).." DP", C.GOLD)
                            -- Send to server for reward
                            local ok, bpG, dpG = fnBattle:InvokeServer(ed.id, true)
                            if ok then
                                State.boostPoints = State.boostPoints + bpG
                                State.totalBp     = State.totalBp + bpG
                                State.dp          = State.dp + dpG
                                State.totalDp     = State.totalDp + dpG
                                State.dirty       = true
                            end
                            return
                        end

                        -- Enemy turn
                        task.wait(0.5)
                        local isStunned = CB.enemyDebuffTurns > 100
                        if isStunned then
                            CB.enemyDebuffTurns = CB.enemyDebuffTurns - 100
                            if CB.enemyDebuffTurns <= 100 then CB.enemyDebuffTurns = 0 end
                            addLog(ed.name.." is stunned — skips turn!", C.DIM)
                        else
                            -- Burn tick
                            if CB.enemyBurnTurns > 0 then
                                CB.enemyHp = math.max(0, CB.enemyHp - CB.enemyBurn)
                                CB.enemyBurnTurns = CB.enemyBurnTurns - 1
                                addLog(ed.name.." takes "..fmt(CB.enemyBurn).." burn damage!", C.ORANGE)
                                if CB.enemyHp <= 0 then
                                    CB.active = false
                                    addLog("VICTORY! "..ed.name.." burned to nothing!", C.SUCCESS)
                                    arenaTitle.Text = "VICTORY!"
                                    notify("Defeated "..ed.name.."! +"..fmt(ed.bpReward).." BP", C.GOLD)
                                    local ok, bpG, dpG = fnBattle:InvokeServer(ed.id, true)
                                    if ok then State.boostPoints=State.boostPoints+bpG; State.dp=State.dp+dpG; State.dirty=true end
                                    return
                                end
                            end

                            -- Enemy debuff decay
                            if CB.enemyDebuffTurns > 0 then
                                CB.enemyDebuffTurns = CB.enemyDebuffTurns - 1
                                if CB.enemyDebuffTurns <= 0 then CB.enemyDebuff = 0 end
                            end

                            -- Enemy special at 50%
                            local useSpecial = not CB.specialFired and CB.enemyHp <= CB.enemyMaxHp * 0.5
                            local eAtk = useSpecial and ed.specialAtk or ed.atk
                            local eName = useSpecial and ed.specialName or "Strike"
                            if useSpecial then CB.specialFired = true end

                            -- Player debuff reduction
                            if CB.playerDebuffTurns > 0 then
                                CB.playerDebuffTurns = CB.playerDebuffTurns - 1
                            else
                                CB.playerDebuff = 0
                            end

                            -- Shield block
                            if CB.shieldHits > 0 then
                                CB.shieldHits = CB.shieldHits - 1
                                addLog(ed.name.." — "..eName..": BLOCKED by shield!", C.SP_FG)
                            else
                                local finalDmg = math.max(1, math.floor(eAtk * (1 - CB.playerDebuff) * (1 - CB.enemyDebuff)))
                                CB.playerHp = math.max(0, CB.playerHp - finalDmg)
                                addLog(ed.name.." — "..eName..": "..fmt(finalDmg).." damage!", C.ENEMY_HP)
                            end
                        end

                        -- SP regen
                        CB.playerSp = math.min(100, CB.playerSp + (State.gamepasses.infinite and 100 or 25))

                        -- Check defeat
                        if CB.playerHp <= 0 then
                            if CB.autoRevive and not CB.autoReviveUsed then
                                CB.autoReviveUsed = true
                                CB.playerHp = math.floor(CB.playerMaxHp * 0.5)
                                addLog("Resurrection activates! Revived at 50% HP!", C.GOLD)
                            else
                                CB.active = false
                                addLog("DEFEATED... Rest and train harder.", C.RED)
                                arenaTitle.Text = "DEFEATED"
                                notify("Defeated by "..ed.name..". Train more!", C.RED)
                            end
                        end
                    end)
                end)
            else
                mb.btn.Visible = false
            end
        end

        addLog("Battle start: "..ed.name.." — HP: "..fmt(ed.hp), C.DIM)
        switchPanel("battle")
    end)
end

-- ============================================================
-- PANEL: ROSTER
-- ============================================================
local rosterPanel = makePanel("roster")

-- Tab bar
local rosterTabBar = New("Frame", {
    Size=UDim2.new(1,0,0,38), BackgroundColor3=C.PANEL, ZIndex=3,
}, rosterPanel)
stroke(C.BORDER, 1, rosterTabBar)

local function mkRosterTab(txt, xp)
    local btn = New("TextButton", {
        Size=UDim2.new(0.5,-2,1,-8), Position=UDim2.new(xp,1,0,4),
        BackgroundColor3=xp==0 and C.CARD2 or C.PANEL, BorderSizePixel=0,
        Text=txt, Font=Enum.Font.GothamBold, TextSize=13,
        TextColor3=xp==0 and C.TEXT or C.DIM,
        AutoButtonColor=false, ZIndex=4,
    }, rosterTabBar)
    corner(6, btn)
    return btn
end
local gearTabBtn = mkRosterTab("SACRED GEARS", 0)
local inventoryScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-8,1,-46), Position=UDim2.new(0,4,0,44),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=C.RED,
    CanvasSize=UDim2.new(0,0,0,0), ZIndex=3,
}, rosterPanel)
listLayout(Enum.FillDirection.Vertical, 4, inventoryScroll)
-- NOTE: Inventory cards are built dynamically when Roster tab opens
-- They update each time panel is shown

local function refreshRoster()
    for _, c in ipairs(inventoryScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    -- Group owned gears
    local gearCounts = {}
    local gearOrder  = {}
    for _, og in ipairs(State.ownedGears) do
        if not gearCounts[og.id] then
            gearCounts[og.id] = 0
            gearOrder[#gearOrder+1] = og.id
        end
        gearCounts[og.id] = gearCounts[og.id] + 1
    end

    if #gearOrder == 0 then
        New("TextLabel", {
            Size=UDim2.new(1,0,0,40), BackgroundTransparency=1,
            Text="No Sacred Gears yet. Visit the Summon tab to obtain gears.",
            Font=Enum.Font.Gotham, TextSize=13, TextColor3=C.DIM, ZIndex=4,
        }, inventoryScroll)
        inventoryScroll.CanvasSize = UDim2.new(0,0,0,50)
        return
    end

    for _, gearId in ipairs(gearOrder) do
        local sgData = nil
        for _, sg in ipairs(Data.SACRED_GEARS) do if sg.id == gearId then sgData = sg break end end
        if not sgData then continue end
        local col = rarityColor(sgData.rarity)
        local isEquipped = (State.equippedGear == gearId)

        local card = New("Frame", {
            Size=UDim2.new(1,-8,0,88), BackgroundColor3=isEquipped and C.CARD2 or C.CARD,
            ZIndex=4,
        }, inventoryScroll)
        corner(8, card)
        stroke(isEquipped and col or C.BORDER, isEquipped and 2 or 1, card)

        -- Left color bar
        New("Frame", {Size=UDim2.new(0,4,1,0), BackgroundColor3=col, ZIndex=5}, card)

        local rarName = Data.GetRarity(sgData.rarity).name
        New("TextLabel", {
            Size=UDim2.new(0.5,0,0,20), Position=UDim2.new(0,12,0,6),
            BackgroundTransparency=1, Text=sgData.name,
            Font=Enum.Font.GothamBold, TextSize=14, TextColor3=col,
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
        }, card)
        New("TextLabel", {
            Size=UDim2.new(0.25,0,0,14), Position=UDim2.new(0,12,0,26),
            BackgroundTransparency=1, Text=rarName,
            Font=Enum.Font.Gotham, TextSize=10, TextColor3=col,
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
        }, card)
        New("TextLabel", {
            Size=UDim2.new(0.2,0,0,14), Position=UDim2.new(0.24,0,0,26),
            BackgroundTransparency=1, Text="x"..gearCounts[gearId],
            Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.DIM,
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
        }, card)

        -- Moves list
        for mi, move in ipairs(sgData.moves) do
            local typeColor = move.type=="damage" and C.RED or move.type=="heal" and C.GREEN or C.SP_FG
            New("TextLabel", {
                Size=UDim2.new(0.55,0,0,13), Position=UDim2.new(0,12,0,40+(mi-1)*14),
                BackgroundTransparency=1,
                Text=move.name.."  ["..move.type.."]",
                Font=Enum.Font.Gotham, TextSize=10, TextColor3=typeColor,
                TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
            }, card)
        end

        -- Equip / unequip button
        local equipBtn = New("TextButton", {
            Size=UDim2.new(0.18,0,0,30), Position=UDim2.new(0.81,0,0.5,-15),
            BackgroundColor3=isEquipped and C.GREEN or col, BorderSizePixel=0,
            Text=isEquipped and "EQUIPPED" or "EQUIP",
            Font=Enum.Font.GothamBlack, TextSize=12,
            TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=5,
        }, card)
        corner(6, equipBtn)

        local capId = gearId
        equipBtn.MouseButton1Click:Connect(function()
            if State.equippedGear == capId then
                State.equippedGear = nil
                notify("Unequipped "..sgData.name, C.DIM)
            else
                State.equippedGear = capId
                notify("Equipped "..sgData.name, col)
            end
            State.dirty = true
            recalc()
            refreshRoster()
        end)
        equipBtn.MouseEnter:Connect(function()
            tween(equipBtn, TI(0.1), {BackgroundColor3=(isEquipped and C.GREEN or col):Lerp(Color3.new(1,1,1),0.2)}):Play()
        end)
        equipBtn.MouseLeave:Connect(function()
            tween(equipBtn, TI(0.1), {BackgroundColor3=isEquipped and C.GREEN or col}):Play()
        end)
    end
    inventoryScroll.CanvasSize = UDim2.new(0,0,0,#gearOrder*94)
end

-- Refresh roster when tab opened
for id, btn in pairs(navButtons) do
    if id == "roster" then
        btn.MouseButton1Click:Connect(function() refreshRoster() end)
    end
end

-- ============================================================
-- PANEL: SHOP
-- ============================================================
local shopPanel = makePanel("shop")
New("TextLabel", {
    Size=UDim2.new(1,0,0,44), Position=UDim2.new(0,16,0,8),
    BackgroundTransparency=1, Text="SHOP",
    Font=Enum.Font.GothamBlack, TextSize=26, TextColor3=C.TEXT,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=3,
}, shopPanel)
New("TextLabel", {
    Size=UDim2.new(0.7,0,0,18), Position=UDim2.new(0,16,0,52),
    BackgroundTransparency=1, Text="Purchase spins and permanent upgrades",
    Font=Enum.Font.Gotham, TextSize=13, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=3,
}, shopPanel)

-- Spin packages
New("TextLabel", {
    Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,16,0,82),
    BackgroundTransparency=1, Text="SPIN PACKAGES",
    Font=Enum.Font.GothamBlack, TextSize=12, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=3,
}, shopPanel)

for i, pkg in ipairs(Data.SPIN_PRODUCTS) do
    local xp = (i-1) * 0.34
    local card = New("Frame", {
        Size=UDim2.new(0.32,0,0,110), Position=UDim2.new(xp,0,0,106),
        BackgroundColor3=C.CARD, ZIndex=3,
    }, shopPanel)
    corner(10, card)
    stroke(C.GOLD, 1.5, card)
    New("Frame", {
        Size=UDim2.new(1,0,0,4), BackgroundColor3=C.GOLD, ZIndex=4,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,10),
        BackgroundTransparency=1, Text=tostring(pkg.spins),
        Font=Enum.Font.GothamBlack, TextSize=28, TextColor3=C.GOLD, ZIndex=4,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,40),
        BackgroundTransparency=1, Text="SPINS",
        Font=Enum.Font.GothamBlack, TextSize=11, TextColor3=C.DIM, ZIndex=4,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,57),
        BackgroundTransparency=1, Text=pkg.desc,
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM, ZIndex=4,
    }, card)
    local buyBtn = New("TextButton", {
        Size=UDim2.new(0.7,0,0,28), Position=UDim2.new(0.15,0,1,-36),
        BackgroundColor3=rgb(150,120,0), BorderSizePixel=0,
        Text=tostring(pkg.robux).." Robux",
        Font=Enum.Font.GothamBlack, TextSize=13, TextColor3=C.GOLD,
        AutoButtonColor=false, ZIndex=4,
    }, card)
    corner(7, buyBtn)
    local pd = pkg
    buyBtn.MouseButton1Click:Connect(function()
        MarketplaceService:PromptProductPurchase(player, pd.productId)
    end)
    buyBtn.MouseEnter:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=rgb(190,155,0)}):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        tween(buyBtn, TI(0.1), {BackgroundColor3=rgb(150,120,0)}):Play()
    end)
end

-- Gamepasses
New("TextLabel", {
    Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,16,0,232),
    BackgroundTransparency=1, Text="GAMEPASSES",
    Font=Enum.Font.GothamBlack, TextSize=12, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=3,
}, shopPanel)

for i, gp in ipairs(Data.GAMEPASSES) do
    local xp = (i-1) * 0.25
    local card = New("Frame", {
        Size=UDim2.new(0.24,-4,0,128), Position=UDim2.new(xp,2,0,258),
        BackgroundColor3=C.CARD, ZIndex=3,
    }, shopPanel)
    corner(10, card)
    stroke(C.RED, 1.5, card)
    New("Frame", {Size=UDim2.new(1,0,0,3), BackgroundColor3=C.RED, ZIndex=4}, card)
    New("TextLabel", {
        Size=UDim2.new(0.9,0,0,32), Position=UDim2.new(0.05,0,0,8),
        BackgroundTransparency=1, Text=gp.name,
        Font=Enum.Font.GothamBlack, TextSize=13, TextColor3=C.TEXT,
        TextWrapped=true, ZIndex=4,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.9,0,0,36), Position=UDim2.new(0.05,0,0,42),
        BackgroundTransparency=1, Text=gp.desc,
        Font=Enum.Font.Gotham, TextSize=9, TextColor3=C.DIM,
        TextWrapped=true, ZIndex=4,
    }, card)
    New("TextLabel", {
        Size=UDim2.new(0.9,0,0,14), Position=UDim2.new(0.05,0,0,80),
        BackgroundTransparency=1, Text=gp.benefit,
        Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.GREEN, ZIndex=4,
    }, card)
    local gpBtn = New("TextButton", {
        Size=UDim2.new(0.82,0,0,28), Position=UDim2.new(0.09,0,1,-34),
        BackgroundColor3=C.RED, BorderSizePixel=0,
        Text=gp.price, Font=Enum.Font.GothamBlack, TextSize=13,
        TextColor3=Color3.new(1,1,1), AutoButtonColor=false, ZIndex=4,
    }, card)
    corner(7, gpBtn)
    local g = gp
    gpBtn.MouseButton1Click:Connect(function()
        MarketplaceService:PromptGamePassPurchase(player, g.gamepassId)
    end)
    gpBtn.MouseEnter:Connect(function()
        tween(gpBtn, TI(0.1), {BackgroundColor3=C.RED:Lerp(Color3.new(1,1,1),0.15)}):Play()
    end)
    gpBtn.MouseLeave:Connect(function()
        tween(gpBtn, TI(0.1), {BackgroundColor3=C.RED}):Play()
    end)
end

-- ============================================================
-- PANEL: STATS
-- ============================================================
local statsPanel = makePanel("stats")
New("TextLabel", {
    Size=UDim2.new(1,-16,0,44), Position=UDim2.new(0,16,0,8),
    BackgroundTransparency=1, Text="STATISTICS",
    Font=Enum.Font.GothamBlack, TextSize=22, TextColor3=C.TEXT,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=3,
}, statsPanel)

local STAT_ROWS = {
    {"Total DP Earned",    "totalDp"  },{"DP per Second",      "dps"     },
    {"DP per Click",       "dpc"      },{"Total Clicks",       "clicks"  },
    {"Boost Points",       "bp"       },{"Total BP Earned",    "totalBp" },
    {"Prestige Count",     "prestige" },{"Prestige Mult",      "pmult"   },
    {"Sacred Gears Owned", "gears"    },{"Spins Remaining",    "spins"   },
    {"Next Prestige BP",   "nextBp"   },{"Combat Power",       "cp"      },
}
local statMap = {}
local SCOLS = 3
for i, row in ipairs(STAT_ROWS) do
    local ci = (i-1) % SCOLS
    local ri = math.floor((i-1) / SCOLS)
    local card = New("Frame", {
        Size=UDim2.new(1/SCOLS,-8,0,64),
        Position=UDim2.new(ci/SCOLS,4+(ci==0 and 12 or 0),0,60+ri*72),
        BackgroundColor3=C.CARD, ZIndex=3,
    }, statsPanel)
    corner(8, card)
    stroke(C.BORDER, 1, card)
    New("TextLabel", {
        Size=UDim2.new(1,-10,0,18), Position=UDim2.new(0,8,0,6),
        BackgroundTransparency=1, Text=row[1],
        Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.DIM,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
    }, card)
    local valLbl = New("TextLabel", {
        Size=UDim2.new(1,-10,0,26), Position=UDim2.new(0,8,0,26),
        BackgroundTransparency=1, Text="0",
        Font=Enum.Font.GothamBlack, TextSize=18, TextColor3=C.TEXT,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4,
    }, card)
    statMap[row[2]] = valLbl
end

-- ============================================================
-- PRESTIGE BOTTOM BAR
-- ============================================================
local presBar = New("Frame", {
    Size=UDim2.new(1,-72,0,44), Position=UDim2.new(0,72,1,-44),
    BackgroundColor3=C.SIDE, ZIndex=5,
}, mainUI)
New("Frame", {
    Size=UDim2.new(1,0,0,1), BackgroundColor3=C.RED, ZIndex=6,
}, presBar)

local presBtn = New("TextButton", {
    Size=UDim2.new(0,260,0,32), Position=UDim2.new(0.5,-130,0.5,-16),
    BackgroundColor3=rgb(130,100,0), BorderSizePixel=0,
    Text="RATING GAME  —  PRESTIGE", Font=Enum.Font.GothamBlack,
    TextSize=14, TextColor3=C.GOLD, AutoButtonColor=false, ZIndex=6,
}, presBar)
corner(7, presBtn)
stroke(C.GOLD, 1.5, presBtn)

local presGainLbl = New("TextLabel", {
    Size=UDim2.new(0,200,1,0), Position=UDim2.new(0.5,138,0,0),
    BackgroundTransparency=1, Text="Gain +0 BP",
    Font=Enum.Font.Gotham, TextSize=13, TextColor3=C.DIM,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
}, presBar)
local presMagnifyLbl = New("TextLabel", {
    Size=UDim2.new(0,170,1,0), Position=UDim2.new(0,0,0,0),
    BackgroundTransparency=1, Text="x1.00",
    Font=Enum.Font.GothamBlack, TextSize=20, TextColor3=C.GOLD,
    TextXAlignment=Enum.TextXAlignment.Right, ZIndex=6,
}, presBar)

presBtn.MouseEnter:Connect(function()
    tween(presBtn, TI(0.1), {BackgroundColor3=rgb(165,130,0)}):Play()
end)
presBtn.MouseLeave:Connect(function()
    tween(presBtn, TI(0.1), {BackgroundColor3=rgb(130,100,0)}):Play()
end)

-- Prestige confirm overlay
local presOvr = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=rgb(0,0,0),
    BackgroundTransparency=0.45, ZIndex=70, Visible=false,
}, sg)
local presBox = New("Frame", {
    Size=UDim2.new(0,400,0,270), Position=UDim2.new(0.5,-200,0.5,-135),
    BackgroundColor3=C.PANEL, ZIndex=71,
}, presOvr)
corner(12, presBox)
stroke(C.GOLD, 2, presBox)
New("TextLabel", {
    Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,10),
    BackgroundTransparency=1, Text="ENTER THE RATING GAME?",
    Font=Enum.Font.GothamBlack, TextSize=18, TextColor3=C.GOLD, ZIndex=72,
}, presBox)
New("TextLabel", {
    Size=UDim2.new(0.9,0,0,36), Position=UDim2.new(0.05,0,0,52),
    BackgroundTransparency=1,
    Text="Reset all progress in exchange for Boost Points that permanently multiply your production.",
    Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.DIM,
    TextWrapped=true, ZIndex=72,
}, presBox)
local confBpLbl = New("TextLabel", {
    Size=UDim2.new(1,0,0,26), Position=UDim2.new(0,0,0,94),
    BackgroundTransparency=1, Text="Reward: +0 Boost Points",
    Font=Enum.Font.GothamBold, TextSize=16, TextColor3=C.GOLD, ZIndex=72,
}, presBox)
local confMultLbl = New("TextLabel", {
    Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,122),
    BackgroundTransparency=1, Text="New multiplier: x1.00",
    Font=Enum.Font.Gotham, TextSize=13, TextColor3=C.GREEN, ZIndex=72,
}, presBox)
New("TextLabel", {
    Size=UDim2.new(0.9,0,0,18), Position=UDim2.new(0.05,0,0,148),
    BackgroundTransparency=1, Text="WARNING: Resets all DP, generators and upgrades.",
    Font=Enum.Font.GothamBold, TextSize=12, TextColor3=C.RED, ZIndex=72,
}, presBox)
local confYes = New("TextButton", {
    Size=UDim2.new(0.44,0,0,34), Position=UDim2.new(0.03,0,1,-48),
    BackgroundColor3=C.GOLD, BorderSizePixel=0,
    Text="FIGHT", Font=Enum.Font.GothamBlack, TextSize=15,
    TextColor3=rgb(12,6,0), AutoButtonColor=false, ZIndex=73,
}, presBox)
corner(7, confYes)
local confNo = New("TextButton", {
    Size=UDim2.new(0.44,0,0,34), Position=UDim2.new(0.53,0,1,-48),
    BackgroundColor3=rgb(60,22,22), BorderSizePixel=0,
    Text="Retreat", Font=Enum.Font.GothamBlack, TextSize=14,
    TextColor3=C.DIM, AutoButtonColor=false, ZIndex=73,
}, presBox)
corner(7, confNo)

presBtn.MouseButton1Click:Connect(function()
    local bp = getBpGain()
    confBpLbl.Text  = "Reward: +"..fmt(bp).." Boost Points"
    local newMult   = getPrestigeMult(State.boostPoints + bp)
    confMultLbl.Text= string.format("New multiplier:  x%.3f  (currently x%.3f)", newMult, State.prestigeMult)
    presOvr.Visible = true
end)
confNo.MouseButton1Click:Connect(function() presOvr.Visible = false end)
confYes.MouseButton1Click:Connect(function()
    presOvr.Visible = false
    local bp = getBpGain()
    if bp <= 0 then notify("Need more DP before prestiging!", C.RED); return end
    -- Reset
    State.boostPoints  = State.boostPoints + bp
    State.totalBp      = State.totalBp + bp
    State.prestigeCount= State.prestigeCount + 1
    State.prestigeMult = getPrestigeMult(State.boostPoints)
    State.dp = 0; State.totalDp = 0
    State.generators = {}
    State.upgrades   = {}
    State.dirty = true
    recalc()
    notify("Rating Game won! +"..fmt(bp).." BP! Multiplier x"..string.format("%.3f",State.prestigeMult), C.GOLD)
end)

-- ============================================================
-- MAIN GAME LOOP
-- ============================================================
local lastTick  = tick()
local saveTimer = 0

RunService.Heartbeat:Connect(function()
    local now = tick()
    local dt  = math.min(now - lastTick, 0.1)
    lastTick  = now

    -- Production
    recalc()
    local prod = State.dpPerSecond * dt
    State.dp     = State.dp     + prod
    State.totalDp= State.totalDp+ prod

    -- Combo decay
    if comboTimer > 0 then
        comboTimer = comboTimer - dt
        if comboTimer <= 0 then comboCount = 0 end
    end

    -- Particle decay
    for _, p in ipairs(POOL) do
        if p.alive then
            p.ttl = p.ttl - dt
            if p.ttl <= 0 then p.alive=false; p.lbl.Visible=false end
        end
    end

    -- Auto-save
    if State.dirty then
        saveTimer = saveTimer + dt
        if saveTimer >= 55 then
            saveTimer = 0
            State.dirty = false
            local upgArr = {}
            for id,_ in pairs(State.upgrades) do upgArr[#upgArr+1]=id end
            evSave:FireServer({
                dp=math.floor(State.dp), totalDp=math.floor(State.totalDp),
                boostPoints=math.floor(State.boostPoints), totalBp=math.floor(State.totalBp),
                prestigeCount=State.prestigeCount, clickMult=State.clickMult,
                generators=State.generators, upgrades=upgArr,
                spins=State.spins, ownedGears=State.ownedGears,
                equippedGear=State.equippedGear, gamepasses=State.gamepasses,
                clicks=State.clicks,
            })
        end
    end

    -- ── HUD updates ────────────────────────────────────────
    dpValLbl.Text  = fmt(State.dp)
    dpsValLbl.Text = fmt(State.dpPerSecond).."/s"
    bpValLbl.Text  = fmt(State.boostPoints)
    spinsTopLbl.Text = tostring(State.spins)
    rankTopLbl.Text  = Data.GetRank(State.boostPoints).name
    presMagnifyLbl.Text = string.format("x%.2f", State.prestigeMult)
    presGainLbl.Text    = "Gain +"..fmt(getBpGain()).." BP"

    -- Combo
    if comboCount > 1 then
        local pct = math.floor(comboCount*4)
        comboLabel.Text = "COMBO x"..comboCount.."  (+"..pct.."%)"
        comboLabel.TextColor3 = comboCount >= 30 and C.RED or (comboCount >= 10 and C.ORANGE or C.GOLD)
    else
        comboLabel.Text = ""
    end
    clickDpcLbl.Text = "+"..fmt(State.dpPerClick).." DP per click"

    -- Generator cards update
    for _, gen in ipairs(Data.GENERATORS) do
        local ui = genUI[gen.id]; if not ui then continue end
        local cnt  = State.generators[gen.id] or 0
        local cost = genCost(gen, cnt)
        local pps  = gen.base * math.max(cnt,1) * genMultiplier(gen.id) * State.prestigeMult
        ui.cntLbl.Text  = tostring(cnt)
        ui.costLbl.Text = fmt(cost).." DP"
        ui.prodLbl.Text = cnt>0 and (fmt(pps).." DP/s") or (fmt(pps).." each")
        local unlocked  = State.totalDp >= gen.unlock
        ui.lockOvr.Visible = not unlocked
        if unlocked then
            ui.buyBtn.BackgroundColor3 = State.dp >= cost and ui.col or rgb(50,38,65)
        end
    end

    -- Upgrade cards update
    for _, upg in ipairs(Data.UPGRADES) do
        local ui = upgUI[upg.id]; if not ui then continue end
        if State.upgrades[upg.id] then
            ui.boughtOvr.Visible = true; ui.stroke.Color = C.GREEN
        else
            ui.boughtOvr.Visible = false
            local reqOk = true
            if upg.req then
                if upg.req.type=="gen"  then reqOk=(State.generators[upg.req.gen] or 0)>=upg.req.val
                elseif upg.req.type=="dp" then reqOk=State.totalDp>=upg.req.val end
            end
            ui.card.BackgroundTransparency = reqOk and 0 or 0.4
            ui.stroke.Color  = reqOk and (State.dp>=upg.cost and rgb(100,40,180) or C.BORDER) or rgb(35,22,52)
            ui.buyBtn.BackgroundColor3 = reqOk and (State.dp>=upg.cost and rgb(100,40,180) or rgb(50,30,80)) or rgb(35,22,52)
        end
    end

    -- Battle HP bars
    if State.combat.enemyData then
        local cb = State.combat
        local phpPct = math.max(0, cb.playerHp / cb.playerMaxHp)
        local ehpPct = math.max(0, cb.enemyHp  / cb.enemyMaxHp)
        local spPct  = cb.playerSp / 100
        playerHpFill.Size = UDim2.new(phpPct, 0, 1, 0)
        playerHpLbl.Text  = "HP: "..fmt(cb.playerHp).."/"..fmt(cb.playerMaxHp)
        enemyHpFill.Size  = UDim2.new(ehpPct, 0, 1, 0)
        enemyHpLbl.Text   = "HP: "..fmt(cb.enemyHp).."/"..fmt(cb.enemyMaxHp)
        playerSpFill.Size = UDim2.new(spPct, 0, 1, 0)
        playerSpLbl.Text  = "SP: "..tostring(cb.playerSp).."/100"
        -- Color HP based on percentage
        playerHpFill.BackgroundColor3 = phpPct > 0.5 and C.HP_FG or (phpPct > 0.25 and C.ORANGE or C.RED)
        -- Status display
        local statParts = {}
        if cb.shieldHits > 0 then statParts[#statParts+1] = "Shield x"..cb.shieldHits end
        if cb.powerUpNext > 1 then statParts[#statParts+1] = "Power Up x"..cb.powerUpNext end
        if cb.autoRevive and not cb.autoReviveUsed then statParts[#statParts+1]="Auto-Revive ready" end
        statusLbl.Text = #statParts>0 and table.concat(statParts,"  |  ") or ""
        local eParts = {}
        if cb.enemyBurnTurns > 0 then eParts[#eParts+1]="Burning "..cb.enemyBurnTurns.."t" end
        if cb.enemyDebuffTurns > 0 then eParts[#eParts+1]=(cb.enemyDebuffTurns>100 and "Stunned" or "Weakened "..cb.enemyDebuffTurns.."t") end
        enemyStatusLbl.Text = table.concat(eParts, "  |  ")

        -- Move cooldowns display
        for m, mb in ipairs(moveBtns) do
            local cd = cb.moveCooldowns[m] or 0
            if mb.btn.Visible then
                if cd > 0 then
                    mb.btn.BackgroundColor3 = rgb(30,22,44)
                    mb.cdLbl.Text = "CD: "..cd.."t"
                else
                    local gearData = nil
                    for _, sg in ipairs(Data.SACRED_GEARS) do
                        if sg.id == State.equippedGear then gearData=sg break end
                    end
                    local move = gearData and gearData.moves[m]
                    if move then
                        local canAfford = cb.playerSp >= move.sp
                        mb.btn.BackgroundColor3 = canAfford and C.CARD2 or rgb(22,16,32)
                        mb.cdLbl.Text = move.cooldown==0 and "No CD" or "CD: "..move.cooldown.."t"
                    end
                end
            end
        end
    end

    -- Summon spins counter
    spinCountLbl.Text = tostring(State.spins).." SPINS AVAILABLE"
    spinCountLbl.TextColor3 = State.spins > 0 and C.GOLD or C.DIM

    -- Stats panel
    if State.activePanel == "stats" then
        local sm = statMap
        if sm.totalDp  then sm.totalDp.Text  = fmt(State.totalDp)       end
        if sm.dps      then sm.dps.Text      = fmt(State.dpPerSecond).."/s" end
        if sm.dpc      then sm.dpc.Text      = fmt(State.dpPerClick)    end
        if sm.clicks   then sm.clicks.Text   = fmt(State.clicks)        end
        if sm.bp       then sm.bp.Text       = fmt(State.boostPoints)   end
        if sm.totalBp  then sm.totalBp.Text  = fmt(State.totalBp)       end
        if sm.prestige then sm.prestige.Text = tostring(State.prestigeCount) end
        if sm.pmult    then sm.pmult.Text    = string.format("x%.4f",State.prestigeMult) end
        if sm.gears    then sm.gears.Text    = tostring(#State.ownedGears) end
        if sm.spins    then sm.spins.Text    = tostring(State.spins)    end
        if sm.nextBp   then sm.nextBp.Text   = "+"..fmt(getBpGain()).." BP" end
        local cp = 50 + State.prestigeCount*10
        if sm.cp       then sm.cp.Text       = fmt(cp).." ATK"          end
    end

    -- Notifications
    local slot = 1; local alive = {}
    for _, n in ipairs(State.notifications) do
        local age = now - n.t
        if age < 3.5 then
            alive[#alive+1] = n
            if slot <= #notifSlots then
                local lbl = notifSlots[slot]
                lbl.Text = n.text; lbl.TextColor3 = n.tc
                lbl.BackgroundTransparency = math.min(0.15, age/3.5*0.15)
                lbl.TextTransparency       = math.max(0, (age-2.5)/1)
                lbl.Visible = true
                slot = slot + 1
            end
        end
    end
    State.notifications = alive
    for j = slot, #notifSlots do notifSlots[j].Visible = false end
end)

-- ============================================================
-- SERVER NOTIFICATION HANDLER
-- ============================================================
evNotify.OnClientEvent:Connect(function(eventType, val)
    if eventType == "spinPurchase" then
        State.spins = State.spins + val
        notify("Purchase successful! +"..tostring(val).." spins added!", C.GOLD)
    elseif eventType == "gamepassPurchase" then
        State.gamepasses[val] = true
        recalc()
        notify("Gamepass activated! Enjoy your benefits.", C.GREEN)
    end
end)

-- Save on leave
player.AncestryChanged:Connect(function()
    local upgArr = {}
    for id,_ in pairs(State.upgrades) do upgArr[#upgArr+1]=id end
    pcall(function() evSave:FireServer({
        dp=math.floor(State.dp), totalDp=math.floor(State.totalDp),
        boostPoints=math.floor(State.boostPoints), totalBp=math.floor(State.totalBp),
        prestigeCount=State.prestigeCount, clickMult=State.clickMult,
        generators=State.generators, upgrades=upgArr,
        spins=State.spins, ownedGears=State.ownedGears,
        equippedGear=State.equippedGear, gamepasses=State.gamepasses,
        clicks=State.clicks,
    }) end)
end)

-- ============================================================
-- LOAD DATA & LAUNCH
-- ============================================================
task.spawn(function()
    runLoadingScreen(function()
        -- Load from server
        local data = fnLoad:InvokeServer()
        if data then
            State.dp           = data.dp or 0
            State.totalDp      = data.totalDp or 0
            State.boostPoints  = data.boostPoints or 0
            State.totalBp      = data.totalBp or 0
            State.prestigeCount= data.prestigeCount or 0
            State.spins        = data.spins ~= nil and data.spins or 5
            State.equippedGear = data.equippedGear
            State.gamepasses   = data.gamepasses or {}
            State.clicks       = data.clicks or 0
            State.ownedGears   = data.ownedGears or {}

            if data.generators then
                for id,v in pairs(data.generators) do State.generators[id]=tonumber(v) or 0 end
            end
            if data.upgrades then
                for _,id in ipairs(data.upgrades) do State.upgrades[id]=true end
            end
        end

        State.prestigeMult = getPrestigeMult(State.boostPoints)
        recalc()

        -- Reveal main UI
        tween(mainUI, TI(0.8), {BackgroundTransparency=0}):Play()
        switchPanel("train")
        notify("Welcome to Devil's Throne, "..player.Name.."!", C.RED)
    end)
end)
-- ===========================================================
-- DEVIL'S THRONE  —  DxD_Server.lua
-- Script in ServerScriptService
-- ===========================================================
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local MarketplaceService= game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("DxDData"))

-- ── Remotes folder ─────────────────────────────────────────
local RF = Instance.new("Folder"); RF.Name = "DxDRemotes"; RF.Parent = ReplicatedStorage

local function mkEvent(name)  local e=Instance.new("RemoteEvent");    e.Name=name; e.Parent=RF; return e end
local function mkFunc(name)   local f=Instance.new("RemoteFunction"); f.Name=name; f.Parent=RF; return f end

local evSave       = mkEvent("SaveData")
local evNotify     = mkEvent("Notify")        -- server→client
local fnLoad       = mkFunc("LoadData")
local fnSummon     = mkFunc("Summon")
local fnBattleEnd  = mkFunc("BattleEnd")      -- client reports result, server grants reward

-- ── DataStore ──────────────────────────────────────────────
local DS_KEY = "DevilsThrone_v1_"
local store, DS_OK = nil, false
DS_OK = pcall(function() store = DataStoreService:GetDataStore("DevilsThrone_v1") end)
if not DS_OK then warn("[DxD Server] DataStore unavailable") end

local cache = {}    -- [userId] = data table
local dirty = {}    -- [userId] = bool

local function safeLoad(uid)
    if not DS_OK then return nil end
    local ok, r = pcall(function() return store:GetAsync(DS_KEY..uid) end)
    return ok and r or nil
end

local function safeSave(uid, data)
    if not DS_OK or type(data) ~= "table" then return end
    pcall(function() store:SetAsync(DS_KEY..uid, data) end)
end

-- Default state for new players
local function defaultState()
    return {
        dp=0, totalDp=0, boostPoints=0, totalBp=0,
        prestigeCount=0, clickMult=1,
        generators={}, upgrades={},
        spins=5,                          -- start with 5 free spins
        ownedGears={},                    -- []{id, rarity}
        equippedGear=nil,
        gamepasses={},                    -- [id]=true
        clicks=0, saveTime=os.time(),
    }
end

local function sanitize(d)
    if type(d) ~= "table" then return nil end
    local s = defaultState()
    s.dp           = math.min(tonumber(d.dp)           or 0, 1e22)
    s.totalDp      = math.min(tonumber(d.totalDp)      or 0, 1e22)
    s.boostPoints  = math.min(tonumber(d.boostPoints)  or 0, 1e13)
    s.totalBp      = math.min(tonumber(d.totalBp)      or 0, 1e13)
    s.prestigeCount= math.min(math.floor(tonumber(d.prestigeCount) or 0), 999999)
    s.clickMult    = math.min(tonumber(d.clickMult)    or 1, 1e9)
    s.spins        = math.min(math.max(math.floor(tonumber(d.spins) or 5), 0), 999999)
    s.clicks       = math.min(math.floor(tonumber(d.clicks) or 0), 1e12)
    s.equippedGear = type(d.equippedGear)=="string" and d.equippedGear or nil
    s.saveTime     = os.time()   -- always overwrite with server time

    if type(d.generators) == "table" then
        for k,v in pairs(d.generators) do
            if type(k)=="string" and #k<40 then s.generators[k]=math.min(math.floor(tonumber(v) or 0),1e6) end
        end
    end
    if type(d.upgrades) == "table" then
        for _,v in ipairs(d.upgrades) do if type(v)=="string" and #v<40 then s.upgrades[v]=true end end
    end
    -- upgrades dict → array for storage
    local upgArr = {}
    for k,_ in pairs(d.upgrades or {}) do upgArr[#upgArr+1]=k end
    s.upgrades = upgArr
    if #s.upgrades > 200 then return nil end

    if type(d.ownedGears) == "table" then
        for _, g in ipairs(d.ownedGears) do
            if type(g)=="table" and type(g.id)=="string" then
                s.ownedGears[#s.ownedGears+1] = {id=g.id, rarity=g.rarity or "common"}
            end
        end
    end
    if #s.ownedGears > 10000 then
        -- cap to most recent 10k
        local trimmed={}
        local start = #s.ownedGears - 9999
        for i=start,#s.ownedGears do trimmed[#trimmed+1]=s.ownedGears[i] end
        s.ownedGears = trimmed
    end

    if type(d.gamepasses) == "table" then
        for k,v in pairs(d.gamepasses) do
            if type(k)=="string" and v==true then s.gamepasses[k]=true end
        end
    end
    return s
end

-- ── Gamepass ownership helper ──────────────────────────────
local function hasPass(player, gpId)
    local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId) end)
    return ok and owns
end

local function refreshGamepasses(player, data)
    for _, gp in ipairs(Data.GAMEPASSES) do
        if hasPass(player, gp.gamepassId) then
            data.gamepasses[gp.id] = true
        end
    end
end

-- ── Summon logic ───────────────────────────────────────────
local function pickGear(luckBoost)
    -- luckBoost: multiply each weight by (1 + luckBoost) except common
    local pool = {}
    local totalW = 0
    for _, sg in ipairs(Data.SACRED_GEARS) do
        local rar = Data.GetRarity(sg.rarity)
        local w = rar.weight
        if sg.rarity ~= "common" and luckBoost then
            w = math.floor(w * (1 + luckBoost))
        end
        pool[#pool+1] = { gear=sg, weight=w }
        totalW = totalW + w
    end
    local roll = math.random(1, totalW)
    local acc  = 0
    for _, entry in ipairs(pool) do
        acc = acc + entry.weight
        if roll <= acc then return entry.gear end
    end
    return pool[1].gear
end

fnSummon.OnServerInvoke = function(player, count)
    count = math.min(math.max(math.floor(tonumber(count) or 1), 1), 10)
    local uid  = player.UserId
    local data = cache[uid]
    if not data then return nil, "No data" end
    if data.spins < count then return nil, "Not enough spins" end

    local luckBoost = data.gamepasses.luck and 0.5 or 0

    local results = {}
    for _ = 1, count do
        local gear = pickGear(luckBoost)
        data.ownedGears[#data.ownedGears+1] = { id=gear.id, rarity=gear.rarity }
        results[#results+1] = { id=gear.id, name=gear.name, rarity=gear.rarity }
    end
    data.spins = data.spins - count
    dirty[uid] = true
    return results, data.spins
end

-- ── Battle reward validation ────────────────────────────────
fnBattleEnd.OnServerInvoke = function(player, enemyId, won)
    if not won then return false end
    local uid  = player.UserId
    local data = cache[uid]
    if not data then return false end
    for _, enemy in ipairs(Data.ENEMIES) do
        if enemy.id == enemyId then
            data.boostPoints = data.boostPoints + enemy.bpReward
            data.totalBp     = data.totalBp     + enemy.bpReward
            data.dp          = data.dp          + enemy.dpReward
            data.totalDp     = data.totalDp     + enemy.dpReward
            dirty[uid]       = true
            return true, enemy.bpReward, enemy.dpReward
        end
    end
    return false
end

-- ── Save / Load ────────────────────────────────────────────
fnLoad.OnServerInvoke = function(player)
    local uid  = player.UserId
    local raw  = safeLoad(uid)
    local data = raw and sanitize(raw) or defaultState()
    refreshGamepasses(player, data)
    cache[uid] = data
    return data
end

evSave.OnServerEvent:Connect(function(player, rawData)
    local uid  = player.UserId
    local data = sanitize(rawData)
    if not data then return end
    -- Re-verify gamepasses server-side
    refreshGamepasses(player, data)
    cache[uid] = data
    dirty[uid] = true
end)

-- ── Developer Product processing ──────────────────────────
MarketplaceService.ProcessReceipt = function(info)
    local player = Players:GetPlayerByUserId(info.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    for _, pkg in ipairs(Data.SPIN_PRODUCTS) do
        if pkg.productId == info.ProductId then
            local uid  = player.UserId
            local data = cache[uid] or defaultState()
            data.spins = data.spins + pkg.spins
            cache[uid] = data
            dirty[uid] = true
            evNotify:FireClient(player, "spinPurchase", pkg.spins)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Gamepass purchase callback
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if not purchased then return end
    local uid  = player.UserId
    local data = cache[uid]
    if not data then return end
    for _, gp in ipairs(Data.GAMEPASSES) do
        if gp.gamepassId == passId then
            data.gamepasses[gp.id] = true
            dirty[uid] = true
            evNotify:FireClient(player, "gamepassPurchase", gp.id)
            break
        end
    end
end)

-- ── Player events ──────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    local uid = player.UserId
    if dirty[uid] and cache[uid] then safeSave(uid, cache[uid]) end
    cache[uid] = nil
    dirty[uid] = nil
end)

-- Periodic save every 2 minutes
task.spawn(function()
    while true do
        task.wait(120)
        local n = 0
        for uid, isDirty in pairs(dirty) do
            if isDirty and cache[uid] then
                safeSave(uid, cache[uid])
                dirty[uid] = false
                n = n + 1
                task.wait(0.1)
            end
        end
        if n > 0 then print("[DxD] Periodic save: "..n.." player(s)") end
    end
end)

game:BindToClose(function()
    for uid, isDirty in pairs(dirty) do
        if isDirty and cache[uid] then safeSave(uid, cache[uid]) task.wait(0.05) end
    end
end)

print("[DxD Server] Ready — "..#Data.SACRED_GEARS.." gears | "..#Data.ENEMIES.." enemies")
-- ===========================================================
-- DEVIL'S THRONE  —  DxD_Data.lua
-- ModuleScript in ReplicatedStorage  |  Name it: DxDData
-- ===========================================================
local Data = {}

-- ── RARITY TIERS ──────────────────────────────────────────
-- 8 tiers. weight = draw weight (higher = more common)
Data.RARITIES = {
    { id="common",       name="Common",       weight=5500, r=145,g=145,b=148 },
    { id="uncommon",     name="Uncommon",     weight=2500, r=65, g=210,b=95  },
    { id="rare",         name="Rare",         weight=1100, r=55, g=135,b=235 },
    { id="epic",         name="Epic",         weight=500,  r=148,g=52, b=235 },
    { id="legendary",    name="Legendary",    weight=200,  r=220,g=175,b=35  },
    { id="mythic",       name="Mythic",       weight=75,   r=235,g=75, b=28  },
    { id="divine",       name="Divine",       weight=20,   r=75, g=225,b=235 },
    { id="transcendent", name="Transcendent", weight=5,    r=235,g=70, b=185 },
}

local totalW = 0
for _, r in ipairs(Data.RARITIES) do totalW = totalW + r.weight end
Data.TOTAL_WEIGHT = totalW

function Data.GetRarity(id)
    for _, r in ipairs(Data.RARITIES) do if r.id == id then return r end end
    return Data.RARITIES[1]
end

function Data.RollRarity()
    local roll, acc = math.random(1, Data.TOTAL_WEIGHT), 0
    for _, r in ipairs(Data.RARITIES) do
        acc = acc + r.weight
        if roll <= acc then return r end
    end
    return Data.RARITIES[1]
end

-- ── SACRED GEARS ──────────────────────────────────────────
-- Each Sacred Gear has up to 3 combat MOVES.
-- Move fields:
--   name, desc
--   type: "damage" | "heal" | "buff" | "debuff" | "utility"
--   dmgMult:     damage = playerAtk * dmgMult (0 = no direct damage)
--   healPct:     heal = playerMaxHp * healPct
--   effect:      "none"|"stun"|"burn"|"weaken"|"shield"|"power_up"|"auto_revive"
--   effectVal:   magnitude of the effect (e.g. 0.3 = 30% weaken)
--   effectTurns: how many turns the effect lasts
--   cooldown:    turns before move can be used again
--   sp:          stamina cost (player has 100 SP, +25/turn)
Data.SACRED_GEARS = {

    -- ════ COMMON ═════════════════════════════════════════════
    {
        id="wind_cutter", name="Wind Cutter", rarity="common",
        desc="Compresses air into razor-sharp blades.",
        prodBonus=0.03,
        moves={
            { name="Air Slash",    desc="Quick compressed-air cut.",                type="damage", dmgMult=1.3,  healPct=0, effect="none",   effectVal=0,   effectTurns=0, cooldown=0, sp=10 },
            { name="Gale Burst",   desc="Burst of wind that staggers the target.",  type="damage", dmgMult=1.6,  healPct=0, effect="weaken", effectVal=0.15,effectTurns=2, cooldown=2, sp=20 },
        },
    },
    {
        id="iron_magnus", name="Iron Magnus", rarity="common",
        desc="Amplifies the bearer's physical strength.",
        prodBonus=0.02,
        moves={
            { name="Heavy Strike", desc="A bone-crushing blow.",                    type="damage", dmgMult=1.5,  healPct=0, effect="none",   effectVal=0,   effectTurns=0, cooldown=1, sp=12 },
            { name="Fortify",      desc="Harden your body. Reduce incoming damage.",type="buff",   dmgMult=0,    healPct=0, effect="shield", effectVal=0.30,effectTurns=2, cooldown=3, sp=18 },
        },
    },
    {
        id="chain_bind", name="Chain of Binding", rarity="common",
        desc="Chains that suppress a target's movement.",
        prodBonus=0.02,
        moves={
            { name="Bind",         desc="Restrain the enemy, skipping their turn.", type="utility",dmgMult=0,    healPct=0, effect="stun",   effectVal=1,   effectTurns=1, cooldown=3, sp=22 },
            { name="Bind Strike",  desc="Strike while the target is bound.",        type="damage", dmgMult=1.4,  healPct=0, effect="none",   effectVal=0,   effectTurns=0, cooldown=1, sp=10 },
        },
    },
    {
        id="hell_eye", name="Hell Eye", rarity="common",
        desc="Grants supernatural perception and a destructive gaze.",
        prodBonus=0.02,
        moves={
            { name="Gaze",         desc="Paralyze the target briefly.",              type="utility",dmgMult=0,    healPct=0, effect="stun",   effectVal=1,   effectTurns=1, cooldown=2, sp=18 },
            { name="Sight Strike", desc="Exploit the target's exposed weakness.",    type="damage", dmgMult=1.7,  healPct=0, effect="none",   effectVal=0,   effectTurns=0, cooldown=2, sp=20 },
        },
    },

    -- ════ UNCOMMON ═══════════════════════════════════════════
    {
        id="twilight_healing", name="Twilight Healing", rarity="uncommon",
        desc="Heals any injury regardless of origin.",
        prodBonus=0.08,
        moves={
            { name="Mend",         desc="Restore 25% of your max HP.",               type="heal",   dmgMult=0,    healPct=0.25,effect="none",   effectVal=0,   effectTurns=0, cooldown=3, sp=25 },
            { name="Holy Light",   desc="Channel healing into a damaging burst.",    type="damage", dmgMult=1.5,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=1, sp=15 },
            { name="Sanctuary",    desc="Heal 15% HP and reduce enemy atk 20%.",    type="heal",   dmgMult=0,    healPct=0.15,effect="weaken", effectVal=0.20,effectTurns=2, cooldown=4, sp=30 },
        },
    },
    {
        id="absorption_line", name="Absorption Line", rarity="uncommon",
        desc="Drains the power of anything it contacts.",
        prodBonus=0.07,
        moves={
            { name="Drain",        desc="Steal 10% HP from the enemy.",              type="damage", dmgMult=0.9,  healPct=0.10,effect="none",   effectVal=0,   effectTurns=0, cooldown=2, sp=18 },
            { name="Power Siphon", desc="Weaken enemy and boost your next attack.",  type="debuff", dmgMult=0,    healPct=0,   effect="weaken", effectVal=0.25,effectTurns=2, cooldown=4, sp=28 },
            { name="Overload",     desc="Release absorbed energy in one blast.",     type="damage", dmgMult=2.2,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=3, sp=30 },
        },
    },
    {
        id="sword_of_betrayer", name="Sword of Betrayer", rarity="uncommon",
        desc="Simultaneously wields both holy and demonic blades.",
        prodBonus=0.09,
        moves={
            { name="Holy Slash",   desc="Strike with the sacred blade.",             type="damage", dmgMult=1.8,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=1, sp=18 },
            { name="Demon Edge",   desc="Strike with the cursed blade. Burns foe.", type="damage", dmgMult=2.0,  healPct=0,   effect="burn",   effectVal=0.08,effectTurns=3, cooldown=2, sp=22 },
            { name="Dual Rend",    desc="Both blades at once. Massive damage.",      type="damage", dmgMult=3.2,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=5, sp=40 },
        },
    },

    -- ════ RARE ═══════════════════════════════════════════════
    {
        id="forbidden_balor", name="Forbidden Balor View", rarity="rare",
        desc="The evil eye that freezes time within a domain.",
        prodBonus=0.12,
        moves={
            { name="Time Stasis",  desc="Freeze the enemy for 2 turns.",             type="utility",dmgMult=0,    healPct=0,   effect="stun",   effectVal=1,   effectTurns=2, cooldown=5, sp=35 },
            { name="Temporal Cut", desc="Strike through frozen time.",               type="damage", dmgMult=2.2,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=2, sp=22 },
            { name="Void Domain",  desc="Freeze time; land three free strikes.",     type="damage", dmgMult=4.0,  healPct=0,   effect="stun",   effectVal=1,   effectTurns=1, cooldown=7, sp=50 },
        },
    },
    {
        id="canis_lykaon", name="Canis Lykaon", rarity="rare",
        desc="The wolf of absolute destruction.",
        prodBonus=0.14,
        moves={
            { name="Wolf Fang",    desc="Tear the enemy — inflicts Bleed.",          type="damage", dmgMult=1.9,  healPct=0,   effect="burn",   effectVal=0.10,effectTurns=3, cooldown=2, sp=20 },
            { name="Howl",         desc="Shatter enemy morale — cut their atk 35%.",type="debuff", dmgMult=0,    healPct=0,   effect="weaken", effectVal=0.35,effectTurns=3, cooldown=3, sp=25 },
            { name="Pack Strike",  desc="A flurry of bites. Four rapid hits.",       type="damage", dmgMult=0.9,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=4, sp=35 },
            -- note: Pack Strike hits 4x at 0.9x each = 3.6x effective
        },
    },
    {
        id="dimension_lost", name="Dimension Lost", rarity="rare",
        desc="Creates a pocket dimension, trapping enemies within.",
        prodBonus=0.13,
        moves={
            { name="Spatial Crush",desc="Compress space around the enemy.",          type="damage", dmgMult=2.1,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=2, sp=22 },
            { name="Void Trap",    desc="Enemy is trapped — reduce all their dmg.",  type="debuff", dmgMult=0,    healPct=0,   effect="weaken", effectVal=0.50,effectTurns=2, cooldown=5, sp=32 },
            { name="Collapse",     desc="Implode the dimension on the enemy.",       type="damage", dmgMult=3.5,  healPct=0,   effect="stun",   effectVal=1,   effectTurns=1, cooldown=6, sp=45 },
        },
    },

    -- ════ EPIC ═══════════════════════════════════════════════
    {
        id="zenith_tempest", name="Zenith Tempest", rarity="epic",
        desc="Commands all atmospheric forces.",
        prodBonus=0.22,
        moves={
            { name="Lightning Burst",desc="Concentrated lightning bolt.",            type="damage", dmgMult=2.5,  healPct=0,   effect="stun",   effectVal=1,   effectTurns=1, cooldown=2, sp=25 },
            { name="Storm Surge",  desc="Rapid lightning barrage. Hits 3 times.",    type="damage", dmgMult=1.2,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=4, sp=35 },
            { name="Tornado God",  desc="Engulf enemy in divine storm.",             type="damage", dmgMult=4.5,  healPct=0,   effect="weaken", effectVal=0.30,effectTurns=3, cooldown=7, sp=55 },
        },
    },
    {
        id="regulus_nemea", name="Regulus Nemea", rarity="epic",
        desc="The armament of the invincible lion king.",
        prodBonus=0.25,
        moves={
            { name="Lions Roar",   desc="Roar that stuns and damages.",              type="damage", dmgMult=2.8,  healPct=0,   effect="stun",   effectVal=1,   effectTurns=1, cooldown=3, sp=28 },
            { name="Royal Coat",   desc="Invincible armor absorbs 2 incoming hits.", type="buff",   dmgMult=0,    healPct=0,   effect="shield", effectVal=2,   effectTurns=3, cooldown=5, sp=35 },
            { name="Leo Drive",    desc="Unleash the true lion king. Massive hit.",  type="damage", dmgMult=5.0,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=8, sp=60 },
        },
    },

    -- ════ LEGENDARY ══════════════════════════════════════════
    {
        id="boosted_gear", name="Boosted Gear", rarity="legendary",
        desc="The Red Dragon Emperor's gauntlet — doubles power every ten seconds.",
        prodBonus=0.45,
        moves={
            { name="Boost",        desc="Double the power of your next attack.",     type="buff",   dmgMult=0,    healPct=0,   effect="power_up",effectVal=2.0, effectTurns=1, cooldown=2, sp=15 },
            { name="Dragon Shot",  desc="Fire a concentrated burst of dragon power.",type="damage", dmgMult=3.2,  healPct=0,   effect="none",   effectVal=0,   effectTurns=0, cooldown=3, sp=30 },
            { name="Explosion",    desc="Release ALL boosted power at once.",        type="damage", dmgMult=6.0,  healPct=0,   effect="stun",   effectVal=1,   effectTurns=2, cooldown=8, sp=65 },
        },
    },
    {
        id="divine_dividing", name="Divine Dividing", rarity="legendary",
        desc="The White Dragon Emperor's wings — halves and steals enemy power.",
        prodBonus=0.45,
        moves={
            { name="Divide",       desc="Cut enemy current HP by 30%.",              type="damage", dmgMult=0,    healPct=0,   effect="divide", effectVal=0.30,effectTurns=0, cooldown=4, sp=30 },
            { name="Half Venom",   desc="Cut enemy ATK in half for 3 turns.",        type="debuff", dmgMult=0,    healPct=0,   effect="weaken", effectVal=0.50,effectTurns=3, cooldown=4, sp=28 },
            { name="White Blaster",desc="The White Dragon's ultimate beam.",         type="damage", dmgMult=5.5,  healPct=0,   effect="weaken", effectVal=0.40,effectTurns=2, cooldown=8, sp=60 },
        },
    },

    -- ════ MYTHIC ═════════════════════════════════════════════
    {
        id="incinerate_anthem", name="Incinerate Anthem", rarity="mythic",
        desc="Undying flames that incinerate even immortal regeneration.",
        prodBonus=0.65,
        moves={
            { name="Phoenix Flame",  desc="Burning strike that leaves a lasting scorch.",type="damage",dmgMult=2.5,healPct=0,   effect="burn",   effectVal=0.15,effectTurns=4, cooldown=3, sp=30 },
            { name="Undying Blaze",  desc="Heal 50% HP. Cannot die this turn.",       type="heal",   dmgMult=0,  healPct=0.50,effect="shield", effectVal=1,   effectTurns=1, cooldown=6, sp=45 },
            { name="Immortal Flame", desc="The eternal flame of destruction.",        type="damage", dmgMult=7.0,healPct=0,   effect="burn",   effectVal=0.20,effectTurns=3, cooldown=9, sp=75 },
        },
    },

    -- ════ DIVINE ═════════════════════════════════════════════
    {
        id="holy_grail", name="Holy Grail", rarity="divine",
        desc="The miracle-granting grail that rewrites reality.",
        prodBonus=0.90,
        moves={
            { name="Miracle",      desc="Fully restore your HP.",                    type="heal",   dmgMult=0,  healPct=1.0, effect="none",   effectVal=0,   effectTurns=0, cooldown=9, sp=60 },
            { name="Divine Smite", desc="Holy judgement from above.",                type="damage", dmgMult=6.5,healPct=0,   effect="stun",   effectVal=1,   effectTurns=2, cooldown=7, sp=65 },
            { name="Resurrection", desc="Auto-revive with 50% HP once. Passive.",    type="utility",dmgMult=0,  healPct=0.50,effect="auto_revive",effectVal=1,effectTurns=1,cooldown=12,sp=80 },
        },
    },

    -- ════ TRANSCENDENT ═══════════════════════════════════════
    {
        id="juggernaut_drive", name="Juggernaut Drive", rarity="transcendent",
        desc="The forbidden form — eternal destruction that consumes the user.",
        prodBonus=1.80,
        moves={
            { name="Dragon Roar",    desc="A primordial howl that annihilates.",      type="damage", dmgMult=5.0, healPct=0,   effect="weaken", effectVal=0.60,effectTurns=3, cooldown=4, sp=45 },
            { name="Limitless Boost",desc="Remove all limits. Next atk x3.",         type="buff",   dmgMult=0,   healPct=0,   effect="power_up",effectVal=3.0,effectTurns=1, cooldown=5, sp=40 },
            { name="Apocalypse",     desc="The apocalypse given form. Unmatchable.", type="damage", dmgMult=12.0,healPct=0,   effect="stun",   effectVal=1,   effectTurns=3, cooldown=12,sp=90 },
        },
    },
    {
        id="qlippoth_dragon", name="Qlippoth Dragon", rarity="transcendent",
        desc="The Apocalypse Beast fused with an evil Sacred Gear.",
        prodBonus=2.00,
        moves={
            { name="Qlippoth Crush", desc="Reality-erasing strike.",                 type="damage", dmgMult=6.0, healPct=0,   effect="burn",   effectVal=0.20,effectTurns=4, cooldown=4, sp=50 },
            { name="Void Devour",    desc="Consume the enemy's power completely.",   type="damage", dmgMult=0,   healPct=0.40,effect="weaken", effectVal=0.70,effectTurns=4, cooldown=6, sp=55 },
            { name="End of All",     desc="The true end of everything.",             type="damage", dmgMult=15.0,healPct=0,   effect="stun",   effectVal=1,   effectTurns=4, cooldown=14,sp=99 },
        },
    },
}

-- ── GENERATORS (auto-producers of DP/s) ────────────────────
Data.GENERATORS = {
    { id="issei",     name="Issei Hyoudou",   role="Pawn",   baseCost=10,       base=0.1,  mult=1.15, unlock=0,         r=190,g=30, b=30  },
    { id="asia",      name="Asia Argento",    role="Bishop", baseCost=100,      base=0.8,  mult=1.15, unlock=50,        r=80, g=200,b=80  },
    { id="koneko",    name="Koneko Toujou",   role="Rook",   baseCost=500,      base=4,    mult=1.15, unlock=300,       r=205,g=205,b=228 },
    { id="kiba",      name="Yuuto Kiba",      role="Knight", baseCost=2000,     base=15,   mult=1.15, unlock=1200,      r=88, g=108,b=222 },
    { id="xenovia",   name="Xenovia Quarta",  role="Knight", baseCost=8000,     base=50,   mult=1.15, unlock=5000,      r=38, g=138,b=212 },
    { id="akeno",     name="Akeno Himejima",  role="Queen",  baseCost=25000,    base=150,  mult=1.15, unlock=18000,     r=108,g=8,  b=192 },
    { id="rias",      name="Rias Gremory",    role="King",   baseCost=2000000,  base=8000, mult=1.15, unlock=1400000,   r=220,g=15, b=72  },
    { id="sirzechs",  name="Sirzechs Lucifer",role="Maou",   baseCost=20000000, base=50000,mult=1.15, unlock=14000000,  r=255,g=52, b=52  },
}

-- ── UPGRADES ───────────────────────────────────────────────
-- type: "click" | "gen" | "global"
Data.UPGRADES = {
    { id="click1",  name="Devil Registration",     desc="x2 click power",          cost=100,      type="click",  mult=2,   req={type="dp",val=0}              },
    { id="click2",  name="Pawn Promotion",          desc="x3 click power",          cost=1000,     type="click",  mult=3,   req={type="dp",val=500}            },
    { id="click3",  name="Sacred Gear Awakening",   desc="x5 click power",          cost=10000,    type="click",  mult=5,   req={type="dp",val=5000}           },
    { id="click4",  name="Balance Breaker",         desc="x10 click power",         cost=200000,   type="click",  mult=10,  req={type="dp",val=100000}         },
    { id="click5",  name="Juggernaut Drive",        desc="x50 click power",         cost=5e7,      type="click",  mult=50,  req={type="dp",val=2e7}            },
    { id="gen_ii1", name="Boost!",                  desc="Issei x3 production",     cost=500,      type="gen",    gen="issei",  mult=3,  req={type="gen",gen="issei",  val=5}  },
    { id="gen_ii2", name="Welsh Dragon Power",      desc="Issei x8 production",     cost=50000,    type="gen",    gen="issei",  mult=8,  req={type="gen",gen="issei",  val=25} },
    { id="gen_as1", name="Twilight Healing",        desc="Asia x3 production",      cost=3000,     type="gen",    gen="asia",   mult=3,  req={type="gen",gen="asia",   val=5}  },
    { id="gen_ko1", name="Senjutsu: Life Force",    desc="Koneko x3 production",    cost=15000,    type="gen",    gen="koneko", mult=3,  req={type="gen",gen="koneko", val=5}  },
    { id="gen_ko2", name="Shirone Mode",            desc="Koneko x6 production",    cost=300000,   type="gen",    gen="koneko", mult=6,  req={type="gen",gen="koneko", val=15} },
    { id="gen_ki1", name="Holy Demon Sword",        desc="Kiba x3 production",      cost=60000,    type="gen",    gen="kiba",   mult=3,  req={type="gen",gen="kiba",   val=5}  },
    { id="gen_xe1", name="Durandal Unleashed",      desc="Xenovia x4 production",   cost=250000,   type="gen",    gen="xenovia",mult=4,  req={type="gen",gen="xenovia",val=5}  },
    { id="gen_ak1", name="Thunder Dragon",          desc="Akeno x3 production",     cost=800000,   type="gen",    gen="akeno",  mult=3,  req={type="gen",gen="akeno",  val=5}  },
    { id="gen_ak2", name="Fallen Angel Awakened",   desc="Akeno x8 production",     cost=2e7,      type="gen",    gen="akeno",  mult=8,  req={type="gen",gen="akeno",  val=20} },
    { id="gen_ri1", name="Power of Destruction",    desc="Rias x5 production",      cost=5e7,      type="gen",    gen="rias",   mult=5,  req={type="gen",gen="rias",   val=5}  },
    { id="gl1",     name="Peerage Bond",            desc="All generators x2",       cost=500000,   type="global", mult=2,   req={type="dp",val=200000}         },
    { id="gl2",     name="Rating Game Champions",   desc="All generators x3",       cost=5e7,      type="global", mult=3,   req={type="dp",val=2.5e7}          },
    { id="gl3",     name="Oppai Dragon Alliance",   desc="All generators x5",       cost=5e9,      type="global", mult=5,   req={type="dp",val=2e9}            },
    { id="gl4",     name="Satans Blessing",         desc="All generators x10",      cost=5e11,     type="global", mult=10,  req={type="dp",val=2e11}           },
    { id="gl5",     name="Dragon Gods Favor",       desc="All generators x25",      cost=1e15,     type="global", mult=25,  req={type="dp",val=5e14}           },
}

-- ── BATTLE ENEMIES ─────────────────────────────────────────
-- atk: base damage per turn
-- special: one-time special attack (triggers at 50% HP)
Data.ENEMIES = {
    { id="stray1",   name="Stray Devil",        title="Lost Soul",         hp=600,    atk=45,   specialAtk=80,  specialName="Desperate Lunge",  bpReward=2,  dpReward=500,    reqGear=false, r=140,g=60, b=60  },
    { id="fallen1",  name="Fallen Angel",        title="Heaven Defector",   hp=1800,   atk=120,  specialAtk=220, specialName="Dark Spear",        bpReward=5,  dpReward=3000,   reqGear=false, r=80, g=80, b=160 },
    { id="exorcist", name="Rogue Exorcist",      title="Church Outcast",    hp=3500,   atk=200,  specialAtk=380, specialName="Sacred Barrier",    bpReward=10, dpReward=10000,  reqGear=true,  r=200,g=200,b=80  },
    { id="vampire",  name="Vampire Noble",       title="House Carmilla",    hp=7000,   atk=320,  specialAtk=580, specialName="Blood Drain",       bpReward=18, dpReward=35000,  reqGear=true,  r=120,g=20, b=80  },
    { id="kokabiel", name="Kokabiel",             title="Fallen Leader",     hp=18000,  atk=600,  specialAtk=1100,specialName="Excalibur Barrage", bpReward=40, dpReward=200000, reqGear=true,  r=28, g=28, b=155 },
    { id="riser",    name="Riser Phenex",         title="Immortal Firebird", hp=40000,  atk=1000, specialAtk=1800,specialName="Phoenix Fire",      bpReward=80, dpReward=800000, reqGear=true,  r=235,g=135,b=18  },
    { id="vali",     name="Vali Lucifer",         title="White Dragon Emperor",hp=100000,atk=2200,specialAtk=4000,specialName="Divine Dividing",  bpReward=200,dpReward=5000000, reqGear=true,  r=200,g=218,b=255 },
    { id="sirzechs", name="Sirzechs Lucifer",     title="Crimson Satan",     hp=300000, atk=5000, specialAtk=9000,specialName="Power of Ruin",     bpReward=500,dpReward=2e7,    reqGear=true,  r=255,g=48, b=48  },
    { id="trihexa",  name="666 — Trihexa",        title="The Apocalypse",    hp=2000000,atk=15000,specialAtk=30000,specialName="End Calamity",    bpReward=2000,dpReward=2e9,   reqGear=true,  r=205,g=18, b=18  },
}

-- ── PRESTIGE RANKS ─────────────────────────────────────────
Data.RANKS = {
    { minBp=0,      name="Stray Devil"        },
    { minBp=1,      name="Low-Class Devil"    },
    { minBp=10,     name="Middle-Class Devil" },
    { minBp=50,     name="High-Class Devil"   },
    { minBp=200,    name="Ultimate-Class"     },
    { minBp=1000,   name="Maou-Class"         },
    { minBp=5000,   name="True Satan"         },
    { minBp=25000,  name="Heavenly Dragon"    },
    { minBp=100000, name="Dragon God"         },
    { minBp=500000, name="Infinite Dragon"    },
}
function Data.GetRank(bp)
    local out = Data.RANKS[1]
    for _, r in ipairs(Data.RANKS) do if bp >= r.minBp then out = r end end
    return out
end

-- ── GAMEPASSES ─────────────────────────────────────────────
-- REPLACE ID VALUES with your actual Roblox gamepass IDs!
Data.GAMEPASSES = {
    { id="vip",      gamepassId=123456001, name="VIP Pass",           price="$4.99",  desc="2x all DP production permanently. Exclusive VIP badge.",         benefit="2x Production" },
    { id="autotrain",gamepassId=123456002, name="Auto-Trainer",       price="$2.99",  desc="Auto-clicks your training button every second.",                 benefit="Auto Click"    },
    { id="luck",     gamepassId=123456003, name="Lucky Devil",         price="$3.99",  desc="Summon rarity weights increased. Better odds every pull.",       benefit="+Luck"         },
    { id="infinite", gamepassId=123456004, name="Infinite Stamina",    price="$4.99",  desc="Stamina recharges instantly between battles. No waiting.",       benefit="Infinite SP"   },
}

-- Developer Products (repeatable — spin purchases)
-- REPLACE IDs with your actual Roblox Developer Product IDs!
Data.SPIN_PRODUCTS = {
    { productId=200000001, spins=50,   robux=49,   name="50 Spins",   desc="50 Sacred Gear summon spins"  },
    { productId=200000002, spins=200,  robux=149,  name="200 Spins",  desc="200 spins — best value"       },
    { productId=200000003, spins=600,  robux=399,  name="600 Spins",  desc="600 spins — mega bundle"      },
}

return Data
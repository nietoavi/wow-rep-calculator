-- Core/Slash.lua — RepCalc
-- /repcalc and /rc. The UI panel doesn't exist yet (added in a later phase),
-- so the calc/show subcommands print to chat for now and we'll swap them out
-- to toggle the panel once it lands.
local _, A = ...

SLASH_REPCALC1 = "/repcalc"
SLASH_REPCALC2 = "/rc"

local PREFIX = "|cffeaeaee[RepCalc]|r"
local SUB    = "|cff9094a0"  -- secondary text color
local RST    = "|r"

local function Trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function Help()
    print(PREFIX .. " commands:")
    print("  /repcalc                 toggle the panel")
    print("  /repcalc show|hide       open or close the panel")
    print("  /repcalc minimap         show/hide the minimap button")
    print("  /repcalc tsmprice [src]  show/set the TSM price source (needs TSM)")
    print("  /repcalc inventory [on|off]  subtract items you already own")
    print("  /repcalc calc            print the current cheapest plan")
    print("  /repcalc reps            list registered reputations")
    print("  /repcalc rep <id>        switch active reputation (e.g. aldor, scryers)")
    print("  /repcalc goal <tier>     set goal (friendly/honored/revered/exalted)")
    print("  /repcalc price <id> <s>  set price for an item by itemID, in silver")
    print("  /repcalc prices          list configured prices for active reputation")
    print("  /repcalc override <tier> [within]   force current standing")
    print("  /repcalc override clear  resume reading live faction data")
    print("  /repcalc bonus <id> <auto|on|off>   diplomacy / spirit / whee")
    print("  /repcalc bonuses         show bonus state and combined multiplier")
    print("  /repcalc state           show DB + faction read-out (debug)")
end

-- Pretty-prints the plan returned by A.Calculator.Compute.
local function PrintPlan(scenario, plan)
    local def = scenario.repDef
    local cur = scenario.current
    local tierName = A.Faction.TIER_NAMES[cur.tier] or cur.tier
    print(PREFIX .. " " .. def.name
        .. " — current: " .. tierName .. " " .. tostring(cur.within)
        .. "/" .. tostring(A.Faction.TierWidth(cur.tier))
        .. ", goal: " .. (A.Faction.TIER_NAMES[scenario.goal] or scenario.goal)
        .. " (bonus x" .. string.format("%.3f", scenario.bonusMult) .. ")")

    if plan.repNeeded == 0 then
        print("  " .. SUB .. "already at or past the goal." .. RST)
        return
    end
    print(string.format("  Reputation needed: %d", plan.repNeeded))
    print("  Items required (turn in this order):")
    for _, g in ipairs(plan.groups) do
        local price = scenario.prices[g.item.itemID] or 0
        local missing = g.missingPrice and "  |cffc8a070(no price set)|r" or ""
        print(string.format("   - %d x %s   (%s)%s",
            g.count,
            g.item.name,
            A.Calculator.FormatSilver(g.silver),
            missing))
        print(string.format("     %srep/turn-in %d (eff %.1f), price %d s ea, covers %s%s",
            SUB,
            g.item.repPer,
            g.item.repPer * scenario.bonusMult,
            price,
            table.concat(g.bandsCovered, ", "),
            RST))
    end
    print(string.format("  TOTAL: %d items, %s",
        plan.totalItems, A.Calculator.FormatSilver(plan.totalSilver)))
    if plan.pricesMissing then
        print("  " .. SUB
            .. "(some bands had no priced item; counts above use the highest-rep fallback)" .. RST)
    end
end

local handlers = {}

handlers.help = Help

-- No-args opens/closes the panel; explicit `help` still prints commands.
handlers[""] = function()
    if A.UI then A.UI.Toggle() else Help() end
end

handlers.show   = function() if A.UI then A.UI.Show()   end end
handlers.hide   = function() if A.UI then A.UI.Hide()   end end
handlers.toggle = function() if A.UI then A.UI.Toggle() end end

handlers.minimap = function()
    if A.Minimap then
        A.Minimap.Toggle()
        local hidden = (A.DB.Shared() or {}).minimapHide
        print(PREFIX .. " minimap button " .. (hidden and "hidden." or "shown."))
    end
end

handlers.inventory = function(args)
    local db = A.DB.Shared()
    if not db then return end
    local a = Trim(args):lower()
    if a == "on" then
        db.useInventory = true
    elseif a == "off" then
        db.useInventory = false
    else
        db.useInventory = not (db.useInventory ~= false)  -- toggle
    end
    print(PREFIX .. " subtract owned items: " .. ((db.useInventory ~= false) and "on" or "off"))
    A.Engine.Refresh("inventory_toggle")
end

handlers.tsmprice = function(args)
    if not A.TSMPrices then
        print(PREFIX .. " TSM price module not loaded.")
        return
    end
    local raw = Trim(args)
    if raw == "" then
        local avail = A.TSMPrices.Available()
        print(string.format("%s TSM price source: |cffffd100%s|r  (TSM %s)",
            PREFIX, A.TSMPrices.GetSource(), avail and "loaded" or "not loaded"))
        print("  usage: /repcalc tsmprice <source>  (e.g. dbminbuyout, dbmarket); 'reset' for default")
        return
    end
    if raw:lower() == "reset" or raw:lower() == "default" then
        A.TSMPrices.SetSource(nil)
        print(PREFIX .. " TSM price source reset to default (dbminbuyout).")
    else
        A.TSMPrices.SetSource(raw)   -- keep case for complex price strings
        print(PREFIX .. " TSM price source: " .. raw)
    end
    if A.UI and A.UI.PullTSMPrices then A.UI.PullTSMPrices() end
    A.Engine.Refresh("tsm_source")
end

handlers.calc = function()
    local scenario = A.Engine.BuildScenario()
    if not scenario then
        print(PREFIX .. " no active reputation registered.")
        return
    end
    local plan = A.Calculator.Compute(scenario)
    PrintPlan(scenario, plan)
end

handlers.reps = function()
    local activeId = RepCalc.GetActiveReputationId()
    print(PREFIX .. " registered reputations:")
    for _, id in ipairs(RepCalc.GetRegisteredReputations()) do
        local def = RepCalc.GetReputation(id)
        local marker = (id == activeId) and "* " or "  "
        print(string.format("  %s%s  (%s, factionID %d)", marker, id, def.name, def.factionID or 0))
    end
end

handlers.rep = function(args)
    local id = Trim(args):lower()
    if id == "" then
        print(PREFIX .. " usage: /repcalc rep <id>")
        return
    end
    if A.DB.SetActiveReputationId(id) then
        print(PREFIX .. " active reputation: " .. id)
        A.Engine.Refresh("rep_changed")
    else
        print(PREFIX .. " unknown reputation: " .. id)
    end
end

handlers.goal = function(args)
    local tier = Trim(args):lower()
    if not A.Faction.TIER_INDEX[tier] then
        print(PREFIX .. " unknown tier: " .. tier)
        return
    end
    A.DB.SetGoal(tier)
    print(PREFIX .. " goal: " .. A.Faction.TIER_NAMES[tier])
    A.Engine.Refresh("goal_changed")
end

handlers.price = function(args)
    local idStr, silverStr = args:match("^(%S+)%s+(%S+)$")
    local id = tonumber(idStr or "")
    local silver = tonumber(silverStr or "")
    if not id or not silver then
        print(PREFIX .. " usage: /repcalc price <itemID> <silver>")
        return
    end
    A.DB.SetPrice(id, silver)
    print(string.format("%s price for itemID %d: %d s", PREFIX, id, silver))
    A.Engine.Refresh("price_changed")
end

handlers.prices = function()
    local def = RepCalc.GetActiveReputation()
    if not def then return end
    print(PREFIX .. " prices for " .. def.name .. ":")
    for _, it in ipairs(def.items or {}) do
        print(string.format("  %d x %s  =  %d s", it.itemID or 0, it.name, A.DB.GetPrice(it.itemID)))
    end
end

handlers.override = function(args)
    args = Trim(args)
    if args == "" then
        print(PREFIX .. " usage: /repcalc override <tier> [within]   |   /repcalc override clear")
        return
    end
    if args:lower() == "clear" then
        A.DB.SetOverride(nil)
        print(PREFIX .. " override cleared (reading live faction data).")
        A.Engine.Refresh("override_cleared")
        return
    end
    local tier, within = args:match("^(%S+)%s*(%d*)$")
    tier = tier and tier:lower()
    if not tier or not A.Faction.TIER_INDEX[tier] then
        print(PREFIX .. " unknown tier: " .. tostring(tier))
        return
    end
    A.DB.SetOverride(tier, tonumber(within) or 0)
    print(string.format("%s override: %s %d", PREFIX, A.Faction.TIER_NAMES[tier], tonumber(within) or 0))
    A.Engine.Refresh("override_set")
end

handlers.bonus = function(args)
    local id, setting = args:match("^(%S+)%s+(%S+)$")
    if not id or not setting then
        print(PREFIX .. " usage: /repcalc bonus <id> <auto|on|off>")
        return
    end
    setting = setting:lower()
    if setting ~= "auto" and setting ~= "on" and setting ~= "off" then
        print(PREFIX .. " invalid setting: " .. setting)
        return
    end
    A.DB.SetBonus(id:lower(), setting)
    print(string.format("%s bonus %s: %s", PREFIX, id, setting))
    A.Engine.Refresh("bonus_changed")
end

handlers.bonuses = function()
    local status = A.Bonuses.Status(A.DB.GetBonuses())
    local mult   = A.Bonuses.Multiplier(A.DB.GetBonuses())
    print(string.format("%s bonus multiplier: x%.3f", PREFIX, mult))
    for _, s in ipairs(status) do
        local on   = s.on and "|cff7fb87fON|r " or "|cff5a5e68off|r"
        local auto = s.autoDetected and "[auto-detected]" or "[not detected]"
        print(string.format("  %s  %s  setting=%s  %s", on, s.label, s.setting, auto))
    end
end

handlers.state = function()
    local def = RepCalc.GetActiveReputation()
    print(PREFIX .. " state:")
    print("  active reputation: " .. tostring(RepCalc.GetActiveReputationId()))
    print("  goal:              " .. tostring(A.DB.GetGoal()))
    if def then
        local live = A.Faction.ReadLive(def.factionID)
        if live then
            print(string.format("  live (%s, factionID %d): %s %d / %d",
                def.name, def.factionID, live.tier, live.within, live.max))
        else
            print(string.format("  live (%s, factionID %d): not tracked yet",
                def.name, def.factionID))
        end
    end
    local ov = A.DB.GetOverride()
    if ov then
        print(string.format("  override: %s %d", ov.tier, ov.within or 0))
    end
end

SlashCmdList["REPCALC"] = function(msg)
    msg = Trim(msg)
    local cmd = msg:match("^(%S+)") or ""
    local args = msg:sub(#cmd + 1):gsub("^%s+", "")
    cmd = cmd:lower()
    local h = handlers[cmd]
    if h then
        h(args)
    else
        print(PREFIX .. " unknown command: " .. cmd)
        Help()
    end
end

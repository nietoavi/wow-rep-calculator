-- Core/DB.lua — RepCalc
-- RepCalcDB schema + accessors.
--
-- Schema:
--   RepCalcDB = {
--       schemaVersion    = 1,
--       activeReputation = "aldor",
--       framePos         = { point, relPoint, x, y },     -- shared UI
--       minimapAngle     = 165,
--       minimapHide      = false,
--       locked           = false,
--       bonuses          = { diplomacy = "auto", spirit = "auto", whee = "auto" },
--       reputations = {
--           aldor = {
--               prices         = { [itemID] = silver, ... },
--               currentOverride = nil,                 -- nil = read live; { tier, within } = manual
--               goal           = "exalted",
--           },
--           scryers = { ... },
--       },
--   }
local _, A = ...
A.DB = {}

local CURRENT_SCHEMA = 1

local function DefaultPerRep(def)
    -- Seed prices to 0 silver; user can fill in or use the AH reader.
    local prices = {}
    if def and def.items then
        for _, it in ipairs(def.items) do
            if it.itemID then prices[it.itemID] = 0 end
        end
    end
    return {
        prices          = prices,
        currentOverride = nil,
        goal            = "exalted",
    }
end

function A.DB.Init()
    RepCalcDB = RepCalcDB or {}
    RepCalcDB.schemaVersion = RepCalcDB.schemaVersion or CURRENT_SCHEMA

    RepCalcDB.bonuses     = RepCalcDB.bonuses or {}
    RepCalcDB.reputations = RepCalcDB.reputations or {}

    -- Shared UI defaults (panel position + minimap button).
    if RepCalcDB.minimapAngle == nil then RepCalcDB.minimapAngle = 165   end
    if RepCalcDB.minimapHide  == nil then RepCalcDB.minimapHide  = false end
    if RepCalcDB.locked       == nil then RepCalcDB.locked       = false end

    -- Defaults for every registered reputation.
    for _, repId in ipairs(RepCalc.GetRegisteredReputations()) do
        local def = RepCalc.GetReputation(repId)
        local entry = RepCalcDB.reputations[repId]
        if not entry then
            RepCalcDB.reputations[repId] = DefaultPerRep(def)
        else
            entry.prices = entry.prices or {}
            entry.goal   = entry.goal or "exalted"
            -- Make sure every known item has a price slot (so the UI can render
            -- the row even before the user fills it in).
            if def and def.items then
                for _, it in ipairs(def.items) do
                    if it.itemID and entry.prices[it.itemID] == nil then
                        entry.prices[it.itemID] = 0
                    end
                end
            end
        end
    end

    -- Honor the saved active reputation if it exists; otherwise leave whatever
    -- Registry already chose (the first registered reputation).
    local saved = RepCalcDB.activeReputation
    if saved and RepCalc.GetReputation(saved) then
        RepCalc.SetActiveReputation(saved)
    else
        RepCalcDB.activeReputation = RepCalc.GetActiveReputationId()
    end
end

-- ============================================================================
-- Accessors
-- ============================================================================

function A.DB.Shared()
    return RepCalcDB
end

function A.DB.Active()
    if not RepCalcDB or not RepCalcDB.reputations then return nil end
    return RepCalcDB.reputations[RepCalcDB.activeReputation]
end

function A.DB.ActiveReputationId()
    return RepCalcDB and RepCalcDB.activeReputation
end

function A.DB.SetActiveReputationId(id)
    if not RepCalc.GetReputation(id) then return false end
    RepCalcDB.activeReputation = id
    RepCalc.SetActiveReputation(id)
    return true
end

-- Prices ---------------------------------------------------------------------

function A.DB.GetPrice(itemID)
    local p = A.DB.Active()
    if not p or not p.prices then return 0 end
    return p.prices[itemID] or 0
end

function A.DB.SetPrice(itemID, silver)
    local p = A.DB.Active()
    if not p then return end
    p.prices = p.prices or {}
    p.prices[itemID] = math.max(0, math.floor(tonumber(silver) or 0))
end

function A.DB.GetPrices()
    local p = A.DB.Active()
    return (p and p.prices) or {}
end

-- Override / goal ------------------------------------------------------------

function A.DB.GetOverride()
    local p = A.DB.Active()
    return p and p.currentOverride
end

function A.DB.SetOverride(tier, within)
    local p = A.DB.Active()
    if not p then return end
    if tier == nil then
        p.currentOverride = nil
    else
        p.currentOverride = { tier = tier, within = within or 0 }
    end
end

function A.DB.GetGoal()
    local p = A.DB.Active()
    return (p and p.goal) or "exalted"
end

function A.DB.SetGoal(tier)
    local p = A.DB.Active()
    if p then p.goal = tier end
end

-- Bonuses --------------------------------------------------------------------

function A.DB.GetBonuses()
    return (RepCalcDB and RepCalcDB.bonuses) or {}
end

function A.DB.SetBonus(id, setting)
    RepCalcDB.bonuses = RepCalcDB.bonuses or {}
    RepCalcDB.bonuses[id] = setting
end

-- Core/Registry.lua — RepCalc
-- Reputation registry. Each Reputations/<X>.lua calls
-- RepCalc.RegisterReputation({...}) and the def gets attached to:
--   _G.RepCalc                          (public API for future addons)
--   A.Reputation                        (active def, so Core stays agnostic)
--
-- Def contract:
--   id          — unique string ("aldor")
--   name        — display string ("The Aldor")
--   factionID   — Blizzard FactionID (used by GetFactionInfoByID)
--   icon        — texture path
--   color       — optional "rrggbb" for header tint
--   items       — array of turn-ins, each:
--     { itemID, name, repPer, tierMin, tierMax, vendor }
--   notes       — optional array of strings shown in the guide
local _, A = ...

_G.RepCalc = _G.RepCalc or {}

local registered = {}
local order = {}      -- registration order (deterministic listing/default)
local activeId

function RepCalc.RegisterReputation(def)
    assert(def and def.id, "RepCalc.RegisterReputation: def.id is required")
    if not registered[def.id] then
        table.insert(order, def.id)
    end
    registered[def.id] = def
    -- The first registered reputation becomes the active default.
    -- DB.Init() may later overwrite this with the player's saved preference.
    if not activeId then
        activeId = def.id
        A.Reputation = def
    end
end

function RepCalc.GetReputation(id)
    return registered[id]
end

function RepCalc.GetActiveReputation()
    return registered[activeId]
end

function RepCalc.GetActiveReputationId()
    return activeId
end

function RepCalc.SetActiveReputation(id)
    local def = registered[id]
    if not def then return false, "reputation not registered: " .. tostring(id) end
    activeId = id
    A.Reputation = def
    return true
end

function RepCalc.GetRegisteredReputations()
    local list = {}
    for _, id in ipairs(order) do table.insert(list, id) end
    return list
end

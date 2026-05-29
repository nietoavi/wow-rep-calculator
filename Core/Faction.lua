-- Core/Faction.lua — RepCalc
-- TBC reputation tier model + live-rep reader.
--
-- Standing values reported by GetFactionInfoByID match the TIERS array order
-- below (1 = Hated ... 8 = Exalted). Tier widths follow the standard WoW
-- model: Neutral 0 -> Friendly 3000 -> Honored 9000 -> Revered 21000 ->
-- Exalted 42000 (absolute), so going Neutral 0 -> Exalted requires 42000 rep.
local _, A = ...
A.Faction = {}

A.Faction.TIERS = {
    { id = "hated",      index = 1, width = 36000 },
    { id = "hostile",    index = 2, width = 3000  },
    { id = "unfriendly", index = 3, width = 3000  },
    { id = "neutral",    index = 4, width = 3000  },
    { id = "friendly",   index = 5, width = 6000  },
    { id = "honored",    index = 6, width = 12000 },
    { id = "revered",    index = 7, width = 21000 },
    { id = "exalted",    index = 8, width = 1000  },  -- functional cap; not summed past entry
}

local TIER_INDEX = {}
for i, t in ipairs(A.Faction.TIERS) do TIER_INDEX[t.id] = i end
A.Faction.TIER_INDEX = TIER_INDEX

A.Faction.TIER_NAMES = {
    hated      = "Hated",
    hostile    = "Hostile",
    unfriendly = "Unfriendly",
    neutral    = "Neutral",
    friendly   = "Friendly",
    honored    = "Honored",
    revered    = "Revered",
    exalted    = "Exalted",
}

-- Tier ids the user can pick as a goal (Exalted being the practical cap).
A.Faction.GOAL_TIERS = {
    "neutral", "friendly", "honored", "revered", "exalted",
}

function A.Faction.TierByIndex(idx)
    return A.Faction.TIERS[idx]
end

function A.Faction.TierWidth(tierId)
    local t = A.Faction.TIERS[TIER_INDEX[tierId or ""] or 0]
    return t and t.width or 0
end

-- Rep needed to reach the START of `goalTierId` from (currentTierId, currentWithin).
-- currentWithin = rep already gained inside the current tier (0 .. width-1).
-- Returns 0 if already at or past the goal tier.
function A.Faction.RepNeeded(currentTierId, currentWithin, goalTierId)
    local cIdx = TIER_INDEX[currentTierId]
    local gIdx = TIER_INDEX[goalTierId]
    if not cIdx or not gIdx then return 0 end
    if cIdx >= gIdx then return 0 end
    local total = math.max(0, (A.Faction.TIERS[cIdx].width or 0) - (currentWithin or 0))
    for i = cIdx + 1, gIdx - 1 do
        total = total + (A.Faction.TIERS[i].width or 0)
    end
    return total
end

-- Reads live faction info via GetFactionInfoByID.
-- Returns nil if the faction isn't tracked yet (e.g. before any contact).
-- Output: { tier = "neutral", within = 0, max = 3000, raw = {standingId, barMin, barMax, barValue} }
function A.Faction.ReadLive(factionID)
    if not factionID or not GetFactionInfoByID then return nil end
    local name, _, standingId, barMin, barMax, barValue = GetFactionInfoByID(factionID)
    if not name then return nil end
    local tier = A.Faction.TIERS[standingId]
    if not tier then return nil end
    return {
        tier   = tier.id,
        within = (barValue or 0) - (barMin or 0),
        max    = (barMax or 0) - (barMin or 0),
        raw    = { standingId = standingId, barMin = barMin, barMax = barMax, barValue = barValue },
    }
end

-- Builds a canonical state {tier, within} from either:
--   - an "override" table { tier = "honored", within = 4000 }
--   - a live read of factionID
--   - nil (returns nil)
function A.Faction.ResolveCurrent(factionID, override)
    if override and override.tier and TIER_INDEX[override.tier] then
        return {
            tier   = override.tier,
            within = math.max(0, math.min(A.Faction.TierWidth(override.tier) - 1, override.within or 0)),
        }
    end
    return A.Faction.ReadLive(factionID)
end

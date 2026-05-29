-- Core/Calculator.lua — RepCalc
-- Cheapest-path solver. Walks tier bands from current standing up to goal,
-- picks the cheapest eligible item per band, and groups consecutive bands
-- that resolved to the same item so the count is ceiled once per group
-- (avoids per-band rounding inflation).
--
-- A "band" is a single tier the player has to fill (e.g. Friendly). For each
-- band the calculator considers only items whose [tierMin..tierMax] covers
-- that tier. Mark of Kil'jaeden, for example, is excluded once the player
-- enters Revered.
local _, A = ...
A.Calculator = {}

local TIER_INDEX = A.Faction.TIER_INDEX

-- An item covers a band if the band's tier index falls within
-- [tierMin..tierMax].
local function ItemEligibleForBand(item, bandIdx)
    local minIdx = TIER_INDEX[item.tierMin or "neutral"] or 1
    local maxIdx = TIER_INDEX[item.tierMax or "exalted"] or 8
    return bandIdx >= minIdx and bandIdx <= maxIdx
end

-- Picks the best item for a band.
--   1. Among items with price > 0, lowest silver-per-effective-rep wins.
--   2. If none priced, fall back to the highest repPer (fewest turn-ins).
-- Returns: pickedItem, silverPerRep (or nil), missingPrice (bool).
local function PickItemForBand(items, bandIdx, prices, bonusMult)
    local bestPriced, bestSPR
    local bestUnpriced, bestRep
    for _, it in ipairs(items) do
        if ItemEligibleForBand(it, bandIdx) then
            local price  = prices[it.itemID] or 0
            local effRep = (it.repPer or 0) * bonusMult
            if effRep > 0 then
                if price > 0 then
                    local spr = price / effRep
                    if not bestSPR or spr < bestSPR then
                        bestPriced, bestSPR = it, spr
                    end
                else
                    if not bestRep or it.repPer > bestRep then
                        bestUnpriced, bestRep = it, it.repPer
                    end
                end
            end
        end
    end
    if bestPriced then
        return bestPriced, bestSPR, false
    end
    return bestUnpriced, nil, bestUnpriced ~= nil
end

-- input  = {
--     repDef    = active reputation def,
--     current   = { tier, within },     -- canonical state from A.Faction.ResolveCurrent
--     goal      = "exalted",
--     prices    = { [itemID] = silver },
--     bonusMult = 1.0,
-- }
-- output = {
--     repNeeded     = N,                -- total rep gained across the path
--     totalItems    = N,
--     totalSilver   = N,
--     pricesMissing = bool,             -- at least one band had no priced option
--     bonusMult     = N,                -- echoed for UI display
--     bands         = { {bandTier, repInBand, item, missingPrice}, ... },
--     groups        = {                 -- "turn in this order" rows
--         { item, repNeeded, count, silver, bandsCovered = {tierId,...}, missingPrice },
--         ...
--     },
-- }
function A.Calculator.Compute(input)
    local repDef    = input.repDef
    local current   = input.current
    local goal      = input.goal or "exalted"
    local prices    = input.prices or {}
    local bonusMult = input.bonusMult or 1.0

    local result = {
        repNeeded     = 0,
        totalItems    = 0,
        totalSilver   = 0,
        pricesMissing = false,
        bonusMult     = bonusMult,
        bands         = {},
        groups        = {},
    }

    if not repDef or not repDef.items or not current or not current.tier then
        return result
    end

    local cIdx = TIER_INDEX[current.tier]
    local gIdx = TIER_INDEX[goal]
    if not cIdx or not gIdx or cIdx >= gIdx then
        return result
    end

    local currentGroup
    for bandIdx = cIdx, gIdx - 1 do
        local bandTier  = A.Faction.TIERS[bandIdx]
        local repInBand = (bandIdx == cIdx)
            and math.max(0, bandTier.width - (current.within or 0))
            or  bandTier.width

        local picked, _, missing = PickItemForBand(repDef.items, bandIdx, prices, bonusMult)
        table.insert(result.bands, {
            bandTier     = bandTier.id,
            repInBand    = repInBand,
            item         = picked,
            missingPrice = missing,
        })

        if picked and repInBand > 0 then
            if currentGroup and currentGroup.item == picked then
                currentGroup.repNeeded = currentGroup.repNeeded + repInBand
                table.insert(currentGroup.bandsCovered, bandTier.id)
                if missing then currentGroup.missingPrice = true end
            else
                currentGroup = {
                    item         = picked,
                    repNeeded    = repInBand,
                    bandsCovered = { bandTier.id },
                    missingPrice = missing,
                }
                table.insert(result.groups, currentGroup)
            end
        end
    end

    -- Resolve counts and silver totals once per group so a single ceil()
    -- doesn't inflate each band's count.
    for _, g in ipairs(result.groups) do
        local effRep = (g.item.repPer or 0) * bonusMult
        g.count  = (effRep > 0) and math.ceil(g.repNeeded / effRep) or 0
        g.silver = g.count * (prices[g.item.itemID] or 0)
        result.repNeeded   = result.repNeeded   + g.repNeeded
        result.totalItems  = result.totalItems  + g.count
        result.totalSilver = result.totalSilver + g.silver
        if g.missingPrice then result.pricesMissing = true end
    end

    return result
end

-- Helper for the slash debug print: human-readable g.s.c from silver.
function A.Calculator.FormatSilver(silver)
    silver = math.floor(silver or 0)
    local g = math.floor(silver / 100)
    local s = silver - g * 100
    if g > 0 then
        return string.format("%dg %02ds", g, s)
    end
    return string.format("%ds", s)
end

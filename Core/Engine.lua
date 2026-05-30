-- Core/Engine.lua — RepCalc
-- Boot + event glue. The UI module (added in a later phase) will subscribe to
-- A.Engine.OnRefresh to redraw when reputation or faction state changes.
local _, A = ...
A.Engine = {}

local PREFIX = "|cffeaeaee[RepCalc]|r"

-- Subscribers fire whenever something the UI may want to know about changes:
--   - PLAYER_LOGIN (after DB init)
--   - UPDATE_FACTION (live rep changed)
--   - PLAYER_AURAS_CHANGED / UNIT_AURA (bonus buffs changed)
local listeners = {}

function A.Engine.OnRefresh(fn)
    table.insert(listeners, fn)
end

function A.Engine.Refresh(reason)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, reason)
        if not ok then
            print(PREFIX .. " refresh listener error: " .. tostring(err))
        end
    end
end

-- Convenience: compute the active scenario from current DB state.
-- Returns the input table for A.Calculator.Compute, or nil if not ready.
function A.Engine.BuildScenario()
    local def = RepCalc.GetActiveReputation()
    if not def then return nil end

    local current = A.Faction.ResolveCurrent(def.factionID, A.DB.GetOverride())
    -- If neither live rep nor an override is available, default to Neutral 0
    -- so the calculator still produces a meaningful preview.
    if not current then
        current = { tier = "neutral", within = 0 }
    end

    return {
        repDef    = def,
        current   = current,
        goal      = A.DB.GetGoal(),
        prices    = A.DB.GetPrices(),
        bonusMult = A.Bonuses.Multiplier(A.DB.GetBonuses()),
    }
end

-- ============================================================================
-- Event frame
-- ============================================================================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_FACTION")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_AURA")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        A.DB.Init()
        print(PREFIX .. " loaded. Type /repcalc help.")
        A.Engine.Refresh("login")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Faction data sometimes isn't ready until after the first PEW.
        A.Timer.After(0.5, function() A.Engine.Refresh("entering_world") end)
    elseif event == "UPDATE_FACTION" then
        A.Engine.Refresh("update_faction")
    elseif event == "UNIT_AURA" and arg1 == "player" then
        A.Engine.Refresh("unit_aura")
    elseif event == "BAG_UPDATE_DELAYED" then
        A.Engine.Refresh("bag_update")
    end
end)

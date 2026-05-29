-- Core/Bonuses.lua — RepCalc
-- Reputation-multiplier sources known in TBC. Each source has:
--   id        — stable key (used in RepCalcDB.bonuses)
--   label     — UI label
--   detect()  — returns true when the bonus is currently active (race or buff)
--   mult      — multiplier (1.10 for +10%)
--
-- The user picks "auto" / "on" / "off" per source. Bonuses.Multiplier()
-- combines them into a single multiplier (multiplicative stacking — three
-- +10% bonuses give 1.10^3 = 1.331).
local _, A = ...
A.Bonuses = {}

-- Is the named buff currently on the player?
function A.Bonuses.HasBuff(name)
    if not UnitBuff or not name then return false end
    for i = 1, 40 do
        local n = UnitBuff("player", i)
        if not n then return false end
        if n == name then return true end
    end
    return false
end

A.Bonuses.SOURCES = {
    {
        id    = "diplomacy",
        label = "Diplomacy (Human racial)",
        mult  = 1.10,
        detect = function()
            if not UnitRace then return false end
            local _, raceFile = UnitRace("player")
            return raceFile == "Human"
        end,
    },
    {
        id    = "spirit",
        label = "Spirit of Sharing (Darkmoon Faire)",
        mult  = 1.10,
        detect = function() return A.Bonuses.HasBuff("Spirit of Sharing") end,
    },
    {
        id    = "whee",
        label = "WHEE!",
        mult  = 1.10,
        detect = function() return A.Bonuses.HasBuff("WHEE!") end,
    },
}

-- Resolves a per-source setting ("auto"|"on"|"off") to a real on/off state.
local function Resolve(setting, autofn)
    if setting == "on"  then return true  end
    if setting == "off" then return false end
    return autofn() == true   -- "auto" or anything else
end

-- Combined multiplier given the user's settings.
-- settings = { diplomacy = "auto", spirit = "off", whee = "auto" } (any missing key defaults to "auto").
function A.Bonuses.Multiplier(settings)
    settings = settings or {}
    local mult = 1.0
    for _, src in ipairs(A.Bonuses.SOURCES) do
        if Resolve(settings[src.id] or "auto", src.detect) then
            mult = mult * src.mult
        end
    end
    return mult
end

-- Per-source status table, useful for the UI:
--   { {id, label, mult, on, autoDetected, setting}, ... }
function A.Bonuses.Status(settings)
    settings = settings or {}
    local out = {}
    for _, src in ipairs(A.Bonuses.SOURCES) do
        local setting       = settings[src.id] or "auto"
        local autoDetected  = src.detect() == true
        local on            = Resolve(setting, src.detect)
        table.insert(out, {
            id           = src.id,
            label        = src.label,
            mult         = src.mult,
            on           = on,
            autoDetected = autoDetected,
            setting      = setting,
        })
    end
    return out
end

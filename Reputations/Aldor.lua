-- Reputations/Aldor.lua — RepCalc
-- Adapter: registers The Aldor with RepCalc.
local _, A = ...

local d = RepCalcAldorData
RepCalc.RegisterReputation({
    id        = d.id,
    name      = d.name,
    factionID = d.factionID,
    icon      = d.icon,
    items     = d.items,
    notes     = d.notes,
})

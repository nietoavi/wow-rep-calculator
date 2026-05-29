-- Reputations/Cenarion.lua — RepCalc
-- Adapter: registers the Cenarion Expedition with RepCalc.
local _, A = ...

local d = RepCalcCenarionData
RepCalc.RegisterReputation({
    id        = d.id,
    name      = d.name,
    factionID = d.factionID,
    icon      = d.icon,
    items     = d.items,
    notes     = d.notes,
})

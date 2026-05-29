-- Reputations/Scryers.lua — RepCalc
-- Adapter: registers The Scryers with RepCalc.
local _, A = ...

local d = RepCalcScryersData
RepCalc.RegisterReputation({
    id        = d.id,
    name      = d.name,
    factionID = d.factionID,
    icon      = d.icon,
    items     = d.items,
    notes     = d.notes,
})

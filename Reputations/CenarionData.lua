-- Reputations/CenarionData.lua — RepCalc
-- The Cenarion Expedition: turn-in items, reputation values, tier coverage.
--
-- itemIDs + factionID verified 2026-05-29 against wago.tools (DB2 ItemSparse /
-- Faction, BCC build 2.5.4.44833):
--   factionID 942               = Cenarion Expedition
--   Unidentified Plant Parts    = 24401  (caps at Honored)
--   Coilfang Armaments          = 24368  (works to Exalted)
-- There is no Hated->Neutral repair item (you never go hostile with them).
--
-- repPer NOT yet confirmed: Coilfang Armaments = 75 is the commonly documented
-- value; Unidentified Plant Parts = 75 is a placeholder. The rep lives on the
-- turn-in quest (server-side), so confirm both on the live site / in-game.
RepCalcCenarionData = {
    id        = "cenarion",
    name      = "Cenarion Expedition",
    factionID = 942,
    icon      = "Interface\\Icons\\INV_Misc_Flower_02",

    items = {
        {
            itemID  = 24401,
            name    = "Unidentified Plant Parts",
            repPer  = 75,    -- UNVERIFIED — confirm turn-in quest rep
            tierMin = "neutral",
            tierMax = "honored",
            vendor  = "Drops from creatures in Zangarmarsh",
        },
        {
            itemID  = 24368,
            name    = "Coilfang Armaments",
            repPer  = 75,    -- UNVERIFIED — confirm turn-in quest rep
            tierMin = "neutral",
            tierMax = "exalted",
            vendor  = "Drops in Coilfang Reservoir dungeons",
        },
    },

    notes = {
        "Unidentified Plant Parts cap at Honored.",
        "Coilfang Armaments work all the way to Exalted.",
        "The calculator picks the cheapest item per tier band automatically.",
    },
}

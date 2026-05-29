-- Reputations/AldorData.lua — RepCalc
-- The Aldor: turn-in items, reputation values, and tier coverage.
--
-- Item data follows the model from the website:
--   itemID   — Blizzard item id (used for icon, link, AH lookup)
--   name     — exact in-game name
--   repPer   — reputation gained per single turn-in (no bonuses)
--   tierMin  — lowest tier where the item still grants reputation
--   tierMax  — highest tier where the item still grants reputation
--
-- itemIDs verified 2026-05-29 against wago.tools (DB2 ItemSparse, BCC build
-- 2.5.4.44833) and cross-checked on tbc.cavernoftime.com. NOTE: ids 25802 and
-- 25744 were recycled in retail (Cataclysm removed the repair items), so they
-- must be checked against a TBC build — they are correct for the 2.5.4 client.
--
-- repPer all confirmed 2026-05-29: Mark of Kil'jaeden and Mark of Sargeras
-- both give 25 (the lesser mark gives the same rep, it just caps at Honored);
-- Fel Armament gives 350; Dreadfang Venom Sac gives 250 (Hated->Neutral
-- repair). Mirrors the confirmed Scryers values in ScryersData.lua.
RepCalcAldorData = {
    id        = "aldor",
    name      = "The Aldor",
    factionID = 932,
    icon      = "Interface\\Icons\\INV_Misc_Token_Aldor",

    items = {
        -- Hated -> Neutral repair (only relevant after switching from Scryers).
        {
            itemID  = 25802,
            name    = "Dreadfang Venom Sac",
            repPer  = 250,   -- Hated->Neutral repair (mirrors Dampscale, confirmed)
            tierMin = "hated",
            tierMax = "neutral",
            vendor  = "Dreadfang widows/lurkers, Terokkar Forest",
        },
        {
            itemID  = 29425,
            name    = "Mark of Kil'jaeden",
            repPer  = 25,
            tierMin = "neutral",
            tierMax = "honored",
            vendor  = "Outland demons (low-tier)",
        },
        {
            itemID  = 30809,
            name    = "Mark of Sargeras",
            repPer  = 25,
            tierMin = "neutral",
            tierMax = "exalted",
            vendor  = "Outland demons",
        },
        {
            itemID  = 29740,
            name    = "Fel Armament",
            repPer  = 350,
            tierMin = "neutral",
            tierMax = "exalted",
            vendor  = "Outland demons (Hellfire / Shadowmoon)",
        },
    },

    notes = {
        "Dreadfang Venom Sac repairs Hated to Neutral.",
        "Mark of Kil'jaeden caps at Honored.",
        "Mark of Sargeras and Fel Armaments work all the way to Exalted.",
        "The calculator picks the cheapest item per tier band automatically.",
    },
}

-- Reputations/ScryersData.lua — RepCalc
--
-- itemIDs verified 2026-05-29 against wago.tools (DB2 ItemSparse, BCC build
-- 2.5.4.44833) and cross-checked on tbc.cavernoftime.com. The Scryers turn-ins
-- are the mirror image of the Aldor set:
--   Dampscale Basilisk Eye <-> Dreadfang Venom Sac (Hated->Neutral repair)
--   Firewing Signet        <-> Mark of Kil'jaeden  (low token, caps at Honored)
--   Sunfury Signet         <-> Mark of Sargeras    (works to Exalted)
--   Arcane Tome            <-> Fel Armament         (350 rep, works to Exalted)
-- The shape mirrors AldorData.lua exactly so the calculator treats both
-- reputations identically.
--
-- repPer all confirmed 2026-05-29: Firewing Signet and Sunfury Signet both
-- give 25 (the lesser signet gives the same rep, it just caps at Honored);
-- Arcane Tome gives 350; Dampscale Basilisk Eye gives 250 (Hated->Neutral
-- repair). NOTE: id 25744 was recycled in retail, so it must be read from a
-- TBC build; it is correct for the 2.5.4 client.
RepCalcScryersData = {
    id        = "scryers",
    name      = "The Scryers",
    factionID = 934,
    icon      = "Interface\\Icons\\INV_Misc_Token_Scryers",

    items = {
        -- Hated -> Neutral repair (only relevant after switching from Aldor).
        {
            itemID  = 25744,
            name    = "Dampscale Basilisk Eye",
            repPer  = 250,   -- Hated->Neutral repair (confirmed)
            tierMin = "hated",
            tierMax = "neutral",
            vendor  = "Dampscale basilisks, Zangarmarsh",
        },
        {
            itemID  = 29426,
            name    = "Firewing Signet",
            repPer  = 25,
            tierMin = "neutral",
            tierMax = "honored",
            vendor  = "Sunfury blood elves in Outland (low-tier)",
        },
        {
            itemID  = 30810,
            name    = "Sunfury Signet",
            repPer  = 25,
            tierMin = "neutral",
            tierMax = "exalted",
            vendor  = "Sunfury blood elves in Outland",
        },
        {
            itemID  = 29739,
            name    = "Arcane Tome",
            repPer  = 350,
            tierMin = "neutral",
            tierMax = "exalted",
            vendor  = "Sunfury casters in Outland",
        },
    },

    notes = {
        "Dampscale Basilisk Eye repairs Hated to Neutral.",
        "Firewing Signet caps at Honored.",
        "Sunfury Signet and Arcane Tomes work all the way to Exalted.",
        "The calculator picks the cheapest item per tier band automatically.",
    },
}

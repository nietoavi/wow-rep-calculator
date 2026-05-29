# RepCalc — Project Context

> Read this file at the start of a new Claude Code session to pick up context.

## What it is

WoW addon for **Burning Crusade Classic Anniversary** (interface `20504`,
English client). In-game clone of <https://aldor-scryers-calculator.com/>:
given a faction (Aldor/Scryers), current reputation, goal, and prices for
turn-in items, it computes the **cheapest path** to the goal — total rep
needed, total turn-ins, total gold, and the order to do them in.

**Multi-reputation by design.** Aldor and Scryers are two registrations
sharing the same architecture. Other TBC reputations (Cenarion Expedition,
Consortium, Ogri'la, Sporeggar, Lower City, Honor Hold/Thrallmar,
Mag'har/Kurenai…) plug in as `Reputations/<X>.lua` adapters that call
`RepCalc.RegisterReputation({...})`. Core stays agnostic.

The patterns are inherited from the user's other addon **Alfred**
(`C:\Users\nieto\Desktop\Alfred\`): private namespace via
`local _, A = ...`, `Core/` agnostic + per-thing modules registered
dynamically, custom dark UI à la Artisan/TSM4, slash with multiple aliases,
SavedVariables with versioned schema. **Do not** copy Alfred's macro /
tradeskill / spellbook subsystems — none of that applies to rep turn-ins.

## Status (updated 2026-05-29)

**Phase 1 done — base.** All math, data, events, and slash commands work.

**Phase 2 in progress — UI.** `Core/MainPanel.lua` is built: a two-column
panel mirroring the website (left = faction dropdown, current-standing override
with a "use live" toggle, goal, bonus checkboxes, per-item price boxes;
right = rep needed, turn-in order, totals, bonus multiplier, missing-price
warning). Opens via `/repcalc`, `/repcalc show|hide|toggle`; closes on
Escape; draggable; position saved in `RepCalcDB.framePos`. It is pure glue
over `A.Engine.BuildScenario` + `A.Calculator.Compute` and repaints through
`A.Engine.OnRefresh`. **Not yet tested in-game** (authored without a live
client) — expect minor layout tweaks.

`Core/Minimap.lua` is built too: a self-contained minimap button (no
LibDBIcon) that toggles the panel, drags around the minimap edge (angle in
`RepCalcDB.minimapAngle`), and hides via `RepCalcDB.minimapHide` /
`/repcalc minimap`. Also untested in a live client.

`Core/AHPrices.lua` is built: a passive scanner (ported from Alfred) that on
`AUCTION_ITEM_LIST_UPDATE` reads the lowest buyout-per-unit for any turn-in
item and writes it (copper→silver) into every reputation's prices, then
`A.Engine.Refresh`. Capture is passive (no button needed) — browse an item
at the AH and its price box auto-fills. Uses the legacy AH API
(`GetAuctionItemInfo("list", i)`; 10th return = buyout, 17th = itemId).
`A.AHPrices.SearchAH(itemName)` (ported from Alfred's `A.Items.SearchAH`)
triggers a search — Blizzard browse box if visible, else `QueryAuctionItems`
direct for TSM/Auctionator. Panel price rows mirror Alfred's click model:
**click** → SearchAH (passive scanner then captures the price); **shift-click**
→ `HandleModifiedItemClick` (drops the item link into whatever edit box is
focused — chat, or a TSM/Auctionator search box). Each turn-in result row on
the right shows the **per-unit price** (`@ Xs ea = total`).

**Phase 2 essentially complete** (panel + minimap + AH prices). Remaining is
polish: in-game layout tuning and any extras the user wants.

## File structure

```
RepCalculator/                   ← addon folder; MUST match the .toc name
├── RepCalculator.toc            ← manifest (interface 20504, version 0.1.0)
├── CONTEXT.md                    ← this file
├── Core/
│   ├── Registry.lua              ← _G.RepCalc + RegisterReputation + Get/SetActive
│   ├── Timer.lua                 ← After() multiplexer (TBC has no C_Timer)
│   ├── Faction.lua               ← TIERS table, RepNeeded(), ReadLive() via GetFactionInfoByID
│   ├── Bonuses.lua               ← Diplomacy/Spirit of Sharing/WHEE! detection + multiplier
│   ├── DB.lua                    ← RepCalcDB schema + Init + accessors
│   ├── Calculator.lua            ← cheapest-path solver, groups by item across bands
│   ├── Engine.lua                ← events (PLAYER_LOGIN, UPDATE_FACTION, UNIT_AURA) + Refresh listeners
│   ├── AHPrices.lua              ← passive AH scanner (port of Alfred); writes lowest buyout into per-rep prices
│   ├── MainPanel.lua             ← two-column UI panel (A.UI.Show/Hide/Toggle), subscribes to OnRefresh
│   ├── Minimap.lua               ← self-contained minimap button (A.Minimap.*), drag to move
│   └── Slash.lua                 ← /repcalc, /rc + subcommands (show/hide/toggle/minimap + power-user cmds)
└── Reputations/
    ├── AldorData.lua             ← Dreadfang Venom Sac, Mark of Kil'jaeden, Mark of Sargeras, Fel Armament
    ├── Aldor.lua                 ← RepCalc.RegisterReputation({...})
    ├── ScryersData.lua           ← Dampscale Basilisk Eye, Firewing Signet, Sunfury Signet, Arcane Tome
    ├── Scryers.lua               ← RepCalc.RegisterReputation({...})
    ├── CenarionData.lua          ← Unidentified Plant Parts, Coilfang Armaments (factionID 942)
    └── Cenarion.lua              ← RepCalc.RegisterReputation({...})
```

Load order (in `.toc`):
```
Registry → Timer → Faction → Bonuses
→ AldorData → Aldor → ScryersData → Scryers → CenarionData → Cenarion
→ DB → Calculator → Engine → AHPrices → MainPanel → Minimap → Slash
```

**Important**: `Registry` must load before any `Reputations/*.lua` (they
call `RepCalc.RegisterReputation`). Each reputation's `Data.lua` must load
before its adapter (the adapter reads the global table defined in the
data file). `DB` loads after all reputations because `DB.Init()` iterates
registered reputations to build per-rep defaults.

## Architecture: Core + Reputation Registry

Each `.lua` receives the addon's private namespace via
`local _, A = ...`. It is the same shared table across every file in the
addon (the second return of the WoW vararg).

**Core never knows "Aldor" directly.** Core modules read from the active
reputation:
- `A.Reputation.items` — turn-in items (the only data Core needs)
- `A.Reputation.factionID` — for `GetFactionInfoByID`
- `A.Reputation.name`, `.icon`, `.notes` — display

`Reputations/Aldor.lua` and `Reputations/Scryers.lua` each call
`RepCalc.RegisterReputation({...})` with the data from their `*Data.lua`
sibling. The first registered reputation becomes active by default; on
`PLAYER_LOGIN` `DB.Init()` overrides this with the saved preference.

## Reputation def contract

```lua
RepCalc.RegisterReputation({
    id        = "aldor",                                   -- unique key
    name      = "The Aldor",                               -- display
    factionID = 932,                                       -- GetFactionInfoByID
    icon      = "Interface\\Icons\\INV_Misc_Token_Aldor",
    items = {
        {
            itemID  = 29425,
            name    = "Mark of Kil'jaeden",
            repPer  = 25,                                  -- base rep per single turn-in
            tierMin = "neutral",                           -- lowest tier eligible
            tierMax = "honored",                           -- highest tier eligible
            vendor  = "Outland demons (low-tier)",         -- informational, shown in guide
        },
        ...
    },
    notes = { "...", "..." },                              -- optional, shown in guide
})
```

## Tier model (Faction.lua)

Standing values returned by `GetFactionInfoByID` (1=Hated … 8=Exalted) map
1:1 to `A.Faction.TIERS`. Tier widths follow the standard WoW model:

| Tier        | Width  | Cumulative (from Neutral 0) |
|-------------|--------|------------------------------|
| Hated       | 36000  | —                            |
| Hostile     | 3000   | —                            |
| Unfriendly  | 3000   | —                            |
| Neutral     | 3000   | 3000                         |
| Friendly    | 6000   | 9000                         |
| Honored     | 12000  | 21000                        |
| Revered     | 21000  | 42000                        |
| Exalted     | 1000   | (cap)                        |

So **Neutral 0 → Exalted = 42000 rep** (matches the website).

`A.Faction.ReadLive(factionID)` returns
`{ tier = "honored", within = 4321, max = 12000, raw = {...} }`
or `nil` if the faction isn't tracked yet.

`A.Faction.ResolveCurrent(factionID, override)` applies a manual override
table `{ tier = "honored", within = 4321 }` on top of the live read; used
when the user wants to plan ahead without their actual character standing.

## Calculator algorithm (Calculator.lua)

For each tier band from `current.tier` up to `goal-1` inclusive:
1. Compute `repInBand` (full tier width, except first band uses
   `width - current.within`).
2. Pick the **cheapest eligible item** for that band:
   - Eligible = `band ∈ [item.tierMin..item.tierMax]`.
   - Among priced items, lowest `silver / (repPer × bonusMult)` wins.
   - If no priced item, fall back to the highest `repPer` (fewest
     turn-ins) and flag `pricesMissing=true`.
3. **Group consecutive bands that picked the same item** so the count is
   `ceil(totalRep / effRep)` once per group, not once per band (avoids
   rounding inflation).

Output:
```lua
{
    repNeeded     = N,
    totalItems    = N,
    totalSilver   = N,         -- in silver units
    pricesMissing = bool,
    bonusMult     = N,         -- echoed for UI display
    bands         = { {bandTier, repInBand, item, missingPrice}, ... },
    groups        = {          -- "turn in this order" rows
        { item, repNeeded, count, silver, bandsCovered = {tierId,...}, missingPrice },
        ...
    },
}
```

## SavedVariables (RepCalcDB)

```lua
RepCalcDB = {
    schemaVersion    = 1,
    activeReputation = "aldor",
    framePos         = { point, relPoint, x, y },     -- for the future UI
    minimapAngle     = 165,
    minimapHide      = false,
    locked           = false,
    bonuses          = { diplomacy = "auto", spirit = "auto", whee = "auto" },
    reputations = {
        aldor = {
            prices          = { [29425] = 99, [32569] = 93, [29183] = 1500 },
            currentOverride = nil,                    -- nil = read live; { tier, within } = manual
            goal            = "exalted",
        },
        scryers = { ... },
    },
}
```

`DB.Init()` is idempotent — runs every login, fills missing keys, doesn't
overwrite existing data. No schema migrations exist yet (the addon is on
`schemaVersion = 1`); add a migration function and bump the version when
the schema changes.

## Bonuses (Bonuses.lua)

Three rep-multiplier sources, each `+10%`, stacking multiplicatively:

| id          | Source                              | Auto-detect                     |
|-------------|-------------------------------------|---------------------------------|
| `diplomacy` | Human racial                        | `UnitRace("player") == "Human"` |
| `spirit`    | Spirit of Sharing (Darkmoon Faire)  | `UnitBuff` named buff           |
| `whee`      | WHEE! (Darkmoon prize)              | `UnitBuff` named buff           |

User setting per source is `"auto" | "on" | "off"`. `"auto"` defers to the
detector. `A.Bonuses.Multiplier(settings)` returns the combined multiplier
(e.g. all three on = `1.10^3 = 1.331`).

## Slash commands (Slash.lua)

`/repcalc` and `/rc`. The UI doesn't exist yet, so these print to chat.
When the panel lands, `show`/`hide`/`toggle` will be added; the rest stay
as power-user shortcuts.

| Command                                  | Action                                            |
|------------------------------------------|---------------------------------------------------|
| `/repcalc` (no args)                     | toggle the panel                                  |
| `/repcalc show` / `hide` / `toggle`      | open / close / toggle the panel                   |
| `/repcalc minimap`                       | show / hide the minimap button                    |
| `/repcalc help`                          | print help                                        |
| `/repcalc calc`                          | print the cheapest plan for the active scenario   |
| `/repcalc reps`                          | list registered reputations                       |
| `/repcalc rep <id>`                      | switch active reputation                          |
| `/repcalc goal <tier>`                   | set goal (friendly/honored/revered/exalted)       |
| `/repcalc price <itemID> <silver>`       | set price for an item                             |
| `/repcalc prices`                        | list configured prices for active rep             |
| `/repcalc override <tier> [within]`      | force current standing                            |
| `/repcalc override clear`                | resume reading live faction data                  |
| `/repcalc bonus <id> <auto\|on\|off>`    | configure a bonus                                 |
| `/repcalc bonuses`                       | show bonus state and combined multiplier          |
| `/repcalc state`                         | DB + faction read-out (debug)                     |

## Public globals

- `RepCalc` — global table (Registry):
  - `RepCalc.RegisterReputation(def)`
  - `RepCalc.GetReputation(id)`, `.GetActiveReputation()`, `.GetActiveReputationId()`
  - `RepCalc.SetActiveReputation(id)`, `.GetRegisteredReputations()`
- `RepCalcDB` — SavedVariable.
- `RepCalcAldorData`, `RepCalcScryersData` — data tables (so adapters can
  reference them by name from `.toc`-separated files).

`A.Engine.OnRefresh(fn)` lets the future UI subscribe to redraw on
`PLAYER_LOGIN`, `UPDATE_FACTION`, and player `UNIT_AURA`.

## Known TODOs

- **itemIDs verified 2026-05-29** against wago.tools (DB2 ItemSparse, BCC
  build 2.5.4.44833) + cross-checked on tbc.cavernoftime.com:
  Aldor — Dreadfang Venom Sac 25802, Mark of Kil'jaeden 29425, Mark of
  Sargeras 30809, Fel Armament 29740. Scryers — Dampscale Basilisk Eye
  25744, Firewing Signet 29426, Sunfury Signet 30810, Arcane Tome 29739.
  WATCH OUT: 25802 and 25744 were recycled in retail (Cataclysm removed the
  repair items), so wago.tools' default (retail) build returns the WRONG
  names for them — always query a TBC build (`?build=2.5.4.44833`). The
  earlier wrong ids (Mark of Sargeras 32569 = Apexis Shard, Fel Armament
  29183) and the scrambled Scryers placeholders are fixed.
- **repPer fully confirmed 2026-05-29** (user-verified the open values on
  tbc.cavernoftime.com): lesser + greater tokens (Mark of Kil'jaeden, Mark
  of Sargeras, Firewing Signet, Sunfury Signet) all = **25** — the lesser
  token gives the same rep, it just caps at Honored. Fel Armament / Arcane
  Tome = **350**. Repair items (Dreadfang Venom Sac / Dampscale Basilisk
  Eye) = **250**. Note: the rep lives on the turn-in quest (server-side), so
  it is NOT in any client DB2 (wago) and not fetchable from the JS-rendered
  cavernoftime pages — it had to come from the live site / in-game.
- **No UI yet.** Phase 2.

## How to test in-game

1. Folder at `World of Warcraft\_classic_\Interface\AddOns\RepCalculator\`
   (folder name MUST match `RepCalculator.toc`) with the contents above.
2. Log in. You should see `[RepCalc] loaded. Type /repcalc help.`
3. Sanity-check the math against the website screenshot:
   ```
   /repcalc rep aldor
   /repcalc bonus diplomacy off
   /repcalc bonus spirit off
   /repcalc bonus whee off
   /repcalc price 29425 99
   /repcalc price 30809 93
   /repcalc price 29740 1500
   /repcalc override neutral 0
   /repcalc goal exalted
   /repcalc calc
   ```
   Expected: 42000 rep needed, 1680 × Mark of Sargeras, total ≈ 1562g 40s.

## Conventions for future modules

- File at `Reputations/<Name>Data.lua` + `Reputations/<Name>.lua`.
- Reputation `id` lowercase (`"aldor"`, `"consortium"`, `"sporeggar"`).
- Slash stays `/repcalc` (single namespace for all reputations).
- SavedVariables always inside `RepCalcDB.reputations[repId]`.
- All chat-visible strings, code, and comments in **English** (the
  in-game audience is English-locale).

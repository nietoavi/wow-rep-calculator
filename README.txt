==============================================================================
 RepCalculator  -  Aldor / Scryers / Cenarion reputation calculator
==============================================================================

An in-game clone of https://aldor-scryers-calculator.com/ for World of
Warcraft: The Burning Crusade Classic (Anniversary, interface 20504).

Pick a faction, set your current standing and goal, enter (or auto-capture)
the turn-in item prices, and RepCalculator computes the CHEAPEST path to your
goal: total reputation needed, how many of each item to hand in and in what
order, the per-unit price, and the total gold cost.


------------------------------------------------------------------------------
 FEATURES
------------------------------------------------------------------------------
 * Cheapest-path solver - walks each reputation tier and picks the cheapest
   eligible turn-in item per band, grouping turn-ins so counts are exact.
 * Live reputation reading - reads your real standing, or override it to plan
   ahead.
 * Reputation bonuses - Diplomacy (Human racial), Spirit of Sharing, and
   WHEE!, auto-detected or forced on/off (+10% each, stacking).
 * Auction House price capture - browse a turn-in item at the AH and its
   price fills in automatically (works with the default AH, TSM, Auctionator).
 * Two-column panel + movable minimap button.
 * Multi-reputation by design - new reputations plug in as data files.


------------------------------------------------------------------------------
 SUPPORTED REPUTATIONS
------------------------------------------------------------------------------
 * The Aldor          - Mark of Kil'jaeden, Mark of Sargeras, Fel Armament
                        (+ Dreadfang Venom Sac for the Hated->Neutral repair)
 * The Scryers        - Firewing Signet, Sunfury Signet, Arcane Tome
                        (+ Dampscale Basilisk Eye repair)
 * Cenarion Expedition - Unidentified Plant Parts, Coilfang Armaments


------------------------------------------------------------------------------
 INSTALLATION
------------------------------------------------------------------------------
 1. Place the addon folder here (the folder name MUST be "RepCalculator",
    matching RepCalculator.toc):

       World of Warcraft\_classic_\Interface\AddOns\RepCalculator\

 2. At the character-select screen, click AddOns and enable RepCalculator
    (tick "Load out of date AddOns" if needed).
 3. Log in. You should see: [RepCalc] loaded. Type /repcalc help.


------------------------------------------------------------------------------
 USAGE
------------------------------------------------------------------------------
 Open the panel with /repcalc (or click the minimap button), choose your
 faction from the dropdown, set current standing / goal, and read the result
 on the right.

 Prices:
   * Type a price (in silver) directly into each item's box, OR
   * Open the Auction House and CLICK an item row in the panel to search it -
     the price is captured automatically from the results.
   * SHIFT-CLICK an item row to drop its link into the focused edit box
     (chat, or a TSM / Auctionator search box).

 Slash commands (/repcalc or /rc):
   /repcalc                  toggle the panel
   /repcalc show | hide      open / close the panel
   /repcalc minimap          show / hide the minimap button
   /repcalc help             list all commands
   /repcalc calc             print the cheapest plan to chat
   /repcalc rep <id>         switch reputation (aldor, scryers, cenarion)
   /repcalc goal <tier>      set goal (friendly/honored/revered/exalted)
   /repcalc price <id> <s>   set an item price (silver) by itemID
   /repcalc override <tier> [within]   force current standing
   /repcalc bonus <id> <auto|on|off>   diplomacy / spirit / whee


------------------------------------------------------------------------------
 NOTES
------------------------------------------------------------------------------
 * Item IDs are verified against the BC Classic data; reputation-per-turn-in
   values for the Aldor and Scryers items are confirmed. Cenarion Expedition
   rep values are provisional pending in-game confirmation.
 * Prices are stored per reputation, per character realm-faction.


------------------------------------------------------------------------------
 CREDITS
------------------------------------------------------------------------------
 Author : Jose G Nieto A
 Source : https://github.com/nietoavi/wow-rep-calculator
 License: see LICENSE
 Inspired by https://aldor-scryers-calculator.com/

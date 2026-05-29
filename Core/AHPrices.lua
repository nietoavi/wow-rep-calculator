-- Core/AHPrices.lua — RepCalc
-- Passive Auction House price capture, ported from Alfred's AHPrices module.
-- Listens to AUCTION_ITEM_LIST_UPDATE and scans the standard "list" result
-- buffer for any of our turn-in items, recording the lowest buyout PER UNIT.
--
-- Why passive: it works no matter what triggered the search — the Blizzard
-- browse box, an Auctionator/TSM shopping scan, or just paging results. Every
-- result page fires AUCTION_ITEM_LIST_UPDATE and we read it via
-- GetAuctionItemInfo("list", i).
--
-- Storage: unlike Alfred (which keeps a separate copper cache), RepCalc already
-- models prices per reputation in silver — RepCalcDB.reputations[rep].prices
-- [itemID]. So a captured buyout is converted copper->silver and written into
-- every registered reputation that uses that itemID, then A.Engine.Refresh()
-- repaints the panel. The result: browse "Mark of Sargeras" at the AH and its
-- price box fills in automatically.
local _, A = ...
A.AHPrices = {}

-- Map every turn-in itemID -> list of repIds that use it. Rebuilt per scan;
-- cheap (a handful of items across all reputations).
local function BuildItemIndex()
    local index = {}
    for _, repId in ipairs(RepCalc.GetRegisteredReputations()) do
        local def = RepCalc.GetReputation(repId)
        if def and def.items then
            for _, it in ipairs(def.items) do
                if it.itemID then
                    index[it.itemID] = index[it.itemID] or {}
                    table.insert(index[it.itemID], repId)
                end
            end
        end
    end
    return index
end

-- Write a silver price into every reputation that has this item. Returns true
-- if anything actually changed.
local function SetPriceAllReps(reps, itemID, silver)
    if not RepCalcDB or not RepCalcDB.reputations then return false end
    local changed = false
    for _, repId in ipairs(reps) do
        local entry = RepCalcDB.reputations[repId]
        if entry then
            entry.prices = entry.prices or {}
            if entry.prices[itemID] ~= silver then
                entry.prices[itemID] = silver
                changed = true
            end
        end
    end
    return changed
end

-- Scan the current AH "list" page and capture the lowest buyout-per-unit for
-- any of our items.
local function ScanAndUpdate()
    if not GetNumAuctionItems or not GetAuctionItemInfo then return end
    if not RepCalcDB or not RepCalcDB.reputations then return end

    local index = BuildItemIndex()
    if not next(index) then return end

    local numBatch = GetNumAuctionItems("list")
    if not numBatch or numBatch == 0 then return end

    local lowest = {}  -- itemID -> lowest copper-per-unit
    for i = 1, numBatch do
        -- BC Classic auction API: 10th return is buyoutPrice, 17th is itemId.
        local _, _, count, _, _, _, _, _, _, buyoutPrice,
              _, _, _, _, _, _, itemId = GetAuctionItemInfo("list", i)
        if itemId and index[itemId]
           and buyoutPrice and buyoutPrice > 0
           and count and count > 0 then
            local per = buyoutPrice / count
            if not lowest[itemId] or per < lowest[itemId] then
                lowest[itemId] = per
            end
        end
    end

    local changed = false
    for itemId, perCopper in pairs(lowest) do
        local silver = math.floor(perCopper / 100 + 0.5)  -- nearest silver
        if silver > 0 and SetPriceAllReps(index[itemId], itemId, silver) then
            changed = true
        end
    end

    if changed then
        A.Engine.Refresh("ah_scan")
    end
end

-- Public: clear AH-captured behaviour is just normal price clearing; kept for
-- symmetry / future use.
function A.AHPrices.Rescan()
    ScanAndUpdate()
end

-- Trigger an Auction House search for itemName (ported from Alfred's
-- A.Items.SearchAH). The passive scanner above then captures the price from
-- the result page. Two paths:
--   * Blizzard browse UI visible → fill BrowseName + click the search button
--     (visual feedback in the standard Browse tab).
--   * TSM / Auctionator active (BrowseName hidden) → QueryAuctionItems directly;
--     silent, but AUCTION_ITEM_LIST_UPDATE still fires so we still capture.
local PREFIX = "|cffeaeaee[RepCalc]|r"
function A.AHPrices.SearchAH(itemName)
    if not itemName or itemName == "" then return end
    if not AuctionFrame or not AuctionFrame:IsShown() then
        print(PREFIX .. " open the Auction House first to search |cffffd100" .. itemName .. "|r.")
        return
    end
    -- Respect the AH rate limit (TSM/Auctionator scans count too).
    if CanSendAuctionQuery and not CanSendAuctionQuery() then
        print(PREFIX .. " AH busy (another addon scanning?). Try again in a moment.")
        return
    end
    -- Path A: Blizzard browse UI is visible → use it for visual feedback.
    if BrowseName and BrowseSearchButton and BrowseName:IsVisible() then
        if AuctionFrameTab_OnClick and AuctionFrameTab1 then
            pcall(AuctionFrameTab_OnClick, AuctionFrameTab1)
        end
        BrowseName:SetText(itemName)
        BrowseSearchButton:Click()
        return
    end
    -- Path B: alternative AH UI (TSM, Auctionator, etc.) → silent direct query.
    if QueryAuctionItems then
        QueryAuctionItems(itemName, nil, nil, 0, false, 0, false, false)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then ScanAndUpdate() end
end)

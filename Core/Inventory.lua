-- Core/Inventory.lua — RepCalc
-- Owned-quantity lookup for turn-in items, ported from Alfred. Two backends:
--   1. TSM4 (preferred) via TSM_API: GetBagQuantity + GetBankQuantity +
--      GetMailQuantity for the current character.
--   2. Fallback: native bag scan via C_Container / GetContainer* .
-- Re-resolve TSM_API every call; pcall everything (TSM throws on bad input).
local _, A = ...
A.Inventory = {}

local function GetTSM()
    local api = _G.TSM_API
    if api and api.GetBagQuantity then return api end
    return nil
end

local function ItemString(api, itemId)
    if api.ToItemString then
        local ok, res = pcall(api.ToItemString, "item:" .. itemId)
        if ok and res then return res end
    end
    return "i:" .. itemId
end

-- Bags + bank + mail are the useful "do I already have this" sources.
local function TSMOwned(api, itemString)
    local total = 0
    local function add(fn)
        if not fn then return end
        local ok, n = pcall(fn, itemString)
        if ok and type(n) == "number" then total = total + n end
    end
    add(api.GetBagQuantity)
    add(api.GetBankQuantity)
    add(api.GetMailQuantity)
    return total
end

-- Fallback: scan the player's bags.
local function BagScan(itemId)
    local total = 0
    local numBags = NUM_BAG_SLOTS or 4
    local GetSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local GetID    = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    local GetInfo  = C_Container and C_Container.GetContainerItemInfo
    if not GetSlots or not GetID then return 0 end
    for bag = 0, numBags do
        local slots = GetSlots(bag) or 0
        for slot = 1, slots do
            if GetID(bag, slot) == itemId then
                if GetInfo then
                    local info = GetInfo(bag, slot)
                    total = total + ((info and (info.stackCount or info.count)) or 1)
                elseif GetContainerItemInfo then
                    local _, count = GetContainerItemInfo(bag, slot)
                    total = total + (count or 1)
                end
            end
        end
    end
    return total
end

-- Public: owned count for an item id (TSM if available, else bag scan).
function A.Inventory.GetCount(itemId)
    if not itemId then return 0 end
    local api = GetTSM()
    if api then
        local owned = TSMOwned(api, ItemString(api, itemId))
        if owned and owned > 0 then return owned end
    end
    return BagScan(itemId)
end

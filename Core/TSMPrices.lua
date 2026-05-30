-- Core/TSMPrices.lua — RepCalc
-- Reads item prices from TradeSkillMaster's price database (TSM_API) when TSM
-- is loaded. Ported from Alfred's Core/TSMPrices.lua. Unlike the passive AH
-- scan (Core/AHPrices.lua), this needs no in-game scanning — TSM already holds
-- account-wide AuctionDB data — so it is the preferred price source when
-- present. When TSM is absent or has no data for an item, Get() returns nil and
-- the caller falls back to the AH-scanned / manual price.
--
-- Price source is configurable via RepCalcDB.tsmPriceSource (default
-- "dbminbuyout" = current lowest buyout), with "dbmarket" as a fallback.
--
-- Safe access pattern: re-resolve TSM_API every call (TSM may still be
-- initializing), build the item string via ToItemString, pcall everything
-- (TSM throws on invalid price strings / unknown items).
local _, A = ...
A.TSMPrices = {}

local DEFAULT_SOURCE  = "dbminbuyout"
local FALLBACK_SOURCE = "dbmarket"

local function GetTSM()
    local api = _G.TSM_API
    if api and api.GetCustomPriceValue then return api end
    return nil
end

local function ItemString(api, itemId)
    if api.ToItemString then
        local ok, res = pcall(api.ToItemString, "item:" .. itemId)
        if ok and res then return res end
    end
    return "i:" .. itemId
end

-- The configured TSM price source string (e.g. "dbminbuyout", "dbmarket",
-- "vendorbuy", or any custom TSM price source the user has defined).
function A.TSMPrices.GetSource()
    local shared = A.DB and A.DB.Shared and A.DB.Shared()
    local src = shared and shared.tsmPriceSource
    if type(src) == "string" and src ~= "" then return src end
    return DEFAULT_SOURCE
end

-- Persist a new price source. Pass nil/"" to reset to the default.
function A.TSMPrices.SetSource(src)
    local shared = A.DB and A.DB.Shared and A.DB.Shared()
    if not shared then return end
    if type(src) == "string" and src ~= "" then
        shared.tsmPriceSource = src
    else
        shared.tsmPriceSource = nil
    end
end

-- Is TSM's price API available right now?
function A.TSMPrices.Available()
    return GetTSM() ~= nil
end

-- Safe single price evaluation. Returns copper (number) or nil.
local function Eval(api, source, itemString)
    if not source or source == "" then return nil end
    local ok, val = pcall(api.GetCustomPriceValue, source, itemString)
    if ok and type(val) == "number" and val > 0 then return val end
    return nil
end

-- Price for an item id: try the configured source first, then dbmarket.
-- Returns copper, sourceUsed (the TSM source string that produced it), or nil.
function A.TSMPrices.Get(itemId)
    if not itemId then return nil end
    local api = GetTSM()
    if not api then return nil end
    local is = ItemString(api, itemId)

    local source = A.TSMPrices.GetSource()
    local val = Eval(api, source, is)
    if val then return val, source end

    if FALLBACK_SOURCE ~= source then
        val = Eval(api, FALLBACK_SOURCE, is)
        if val then return val, FALLBACK_SOURCE end
    end
    return nil
end

-- Core/MainPanel.lua — RepCalc
-- The two-column panel that mirrors aldor-scryers-calculator.com:
--   left  = inputs  (faction, current standing, goal, bonuses, item prices)
--   right = results (rep needed, turn-in order, totals)
--
-- This module is pure UI glue. It never computes anything itself — it reads the
-- scenario via A.Engine.BuildScenario(), runs A.Calculator.Compute(), and writes
-- input changes back through A.DB.* setters, then calls A.Engine.Refresh() so
-- every listener (including this panel) redraws. It subscribes to
-- A.Engine.OnRefresh so live faction / aura changes repaint automatically.
local _, A = ...
A.UI = {}

local PANEL_W, PANEL_H = 560, 460
local LCOL_X, RCOL_X   = 16, 300
local COL_W            = 248

-- ---------------------------------------------------------------------------
-- Small styling helpers (dark look, no external libs).
-- The Anniversary client runs the modern engine where SetBackdrop is NOT a
-- native frame method — a frame must inherit "BackdropTemplate" to get it.
-- BACKDROP_TEMPLATE resolves to that template when available and to nil on
-- older engines (which keep native SetBackdrop), so this works on both.
-- ---------------------------------------------------------------------------
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 14,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function Dark(frame, r, g, b, a)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(r or 0.06, g or 0.06, b or 0.07, a or 0.95)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    return frame
end

local function Label(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    if size then
        local f, _, flags = fs:GetFont()
        fs:SetFont(f, size, flags)
    end
    fs:SetTextColor(r or 0.92, g or 0.92, b or 0.93)
    return fs
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------
local panel          -- the root frame
local widgets = {}   -- references we update in Refresh()
local priceRows = {} -- reusable price-input rows (one per active item)
local groupRows = {} -- reusable result rows

local function SaveFramePos()
    local db = A.DB.Shared()
    if not db then return end
    local point, _, relPoint, x, y = panel:GetPoint()
    db.framePos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestoreFramePos()
    local db = A.DB.Shared()
    panel:ClearAllPoints()
    local p = db and db.framePos
    if p and p.point then
        panel:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        panel:SetPoint("CENTER")
    end
end

-- Tier dropdown ------------------------------------------------------------
-- choices = ordered array of tier ids; onSelect(tierId) writes the change.
local function MakeTierDropdown(parent, name, choices, getValue, onSelect)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 110)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, tierId in ipairs(choices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = A.Faction.TIER_NAMES[tierId] or tierId
            info.value = tierId
            info.func  = function(b)
                UIDropDownMenu_SetSelectedValue(dd, b.value)
                onSelect(b.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd.Sync = function()
        local v = getValue()
        UIDropDownMenu_SetSelectedValue(dd, v)
        UIDropDownMenu_SetText(dd, A.Faction.TIER_NAMES[v] or v)
    end
    return dd
end

-- A labelled numeric edit box ---------------------------------------------
local function MakeNumberBox(parent, width, onCommit)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetSize(width or 60, 20)
    eb:SetMaxLetters(8)
    local function commit()
        eb:ClearFocus()
        onCommit(tonumber(eb:GetText()) or 0)
    end
    eb:SetScript("OnEnterPressed", commit)
    eb:SetScript("OnEditFocusLost", commit)
    eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
    return eb
end

-- A bonus checkbox (on/off; right-click resets to auto) --------------------
local function MakeBonusCheck(parent, src)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetTextColor(0.88, 0.88, 0.9)
    cb:SetScript("OnClick", function(self)
        A.DB.SetBonus(src.id, self:GetChecked() and "on" or "off")
        A.Engine.Refresh("bonus_changed")
    end)
    -- Right-click restores "auto".
    cb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cb:HookScript("OnClick", function(self, button)
        if button == "RightButton" then
            A.DB.SetBonus(src.id, "auto")
            A.Engine.Refresh("bonus_changed")
        end
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(src.label)
        GameTooltip:AddLine("Left-click: toggle on/off.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: back to auto-detect.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cb.srcId = src.id
    return cb
end

local function BuildPanel()
    panel = CreateFrame("Frame", "RepCalcPanel", UIParent, BACKDROP_TEMPLATE)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) if not (A.DB.Shared() or {}).locked then self:StartMoving() end end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveFramePos() end)
    Dark(panel)
    tinsert(UISpecialFrames, "RepCalcPanel")  -- closes on Escape

    -- Header --------------------------------------------------------------
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(30)

    widgets.title = Label(header, "RepCalc", 15)
    widgets.title:SetPoint("LEFT", 12, 0)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() A.UI.Hide() end)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetPoint("TOPLEFT", 8, -30)
    divider:SetPoint("TOPRIGHT", -8, -30)
    divider:SetHeight(1)

    -- Faction selector (dropdown — scales to any number of reputations) ---
    widgets.factionDropdown = CreateFrame("Frame", "RepCalcFactionDropdown", panel, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(widgets.factionDropdown, 200)
    UIDropDownMenu_Initialize(widgets.factionDropdown, function(self, level)
        for _, repId in ipairs(RepCalc.GetRegisteredReputations()) do
            local def  = RepCalc.GetReputation(repId)
            local info = UIDropDownMenu_CreateInfo()
            info.text  = def.name
            info.value = repId
            info.func  = function(b)
                if A.DB.SetActiveReputationId(b.value) then
                    UIDropDownMenu_SetSelectedValue(widgets.factionDropdown, b.value)
                    A.UI.RebuildItemRows()
                    A.UI.PullTSMPrices()
                    A.Engine.Refresh("rep_changed")
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    widgets.factionDropdown:SetPoint("TOPLEFT", LCOL_X - 16, -36)

    -- LEFT COLUMN ---------------------------------------------------------
    local ly = -78

    Label(panel, "Current standing", 12):SetPoint("TOPLEFT", LCOL_X, ly)
    ly = ly - 18

    widgets.liveCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    widgets.liveCheck:SetSize(22, 22)
    widgets.liveCheck:SetPoint("TOPLEFT", LCOL_X - 2, ly)
    local liveText = Label(panel, "Use my live reputation", 11)
    liveText:SetPoint("LEFT", widgets.liveCheck, "RIGHT", 2, 0)
    widgets.liveCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            A.DB.SetOverride(nil)
        else
            -- Seed the override from whatever we're currently showing.
            local cur = A.Faction.ResolveCurrent(RepCalc.GetActiveReputation().factionID, nil)
                        or { tier = "neutral", within = 0 }
            A.DB.SetOverride(cur.tier, cur.within)
        end
        A.Engine.Refresh("override_toggled")
    end)
    ly = ly - 24

    widgets.curDropdown = MakeTierDropdown(panel, "RepCalcCurrentDropdown", A.Faction.GOAL_TIERS,
        function()
            local ov = A.DB.GetOverride()
            return ov and ov.tier or "neutral"
        end,
        function(tierId)
            local ov = A.DB.GetOverride()
            A.DB.SetOverride(tierId, ov and ov.within or 0)
            A.Engine.Refresh("current_changed")
        end)
    widgets.curDropdown:SetPoint("TOPLEFT", LCOL_X - 16, ly)

    widgets.withinBox = MakeNumberBox(panel, 56, function(v)
        local ov = A.DB.GetOverride()
        A.DB.SetOverride(ov and ov.tier or "neutral", v)
        A.Engine.Refresh("current_changed")
    end)
    widgets.withinBox:SetPoint("LEFT", widgets.curDropdown, "RIGHT", 8, 2)
    ly = ly - 30

    widgets.liveReadout = Label(panel, "", 11, 0.62, 0.66, 0.72)
    widgets.liveReadout:SetPoint("TOPLEFT", LCOL_X, ly)
    ly = ly - 22

    Label(panel, "Goal", 12):SetPoint("TOPLEFT", LCOL_X, ly)
    ly = ly - 18
    widgets.goalDropdown = MakeTierDropdown(panel, "RepCalcGoalDropdown", A.Faction.GOAL_TIERS,
        function() return A.DB.GetGoal() end,
        function(tierId) A.DB.SetGoal(tierId); A.Engine.Refresh("goal_changed") end)
    widgets.goalDropdown:SetPoint("TOPLEFT", LCOL_X - 16, ly)
    ly = ly - 34

    Label(panel, "Bonuses (+10% each)", 12):SetPoint("TOPLEFT", LCOL_X, ly)
    ly = ly - 18
    widgets.bonusChecks = {}
    for _, src in ipairs(A.Bonuses.SOURCES) do
        local cb = MakeBonusCheck(panel, src)
        cb:SetPoint("TOPLEFT", LCOL_X - 2, ly)
        cb.text:SetText(src.label)
        widgets.bonusChecks[src.id] = cb
        ly = ly - 22
    end
    ly = ly - 6

    widgets.pricesHeader = Label(panel, "Prices (silver) — click a row to search the AH", 11)
    widgets.pricesHeader:SetPoint("TOPLEFT", LCOL_X, ly)
    widgets.priceTop = ly - 18
    -- price rows are built dynamically in RebuildItemRows()

    -- RIGHT COLUMN --------------------------------------------------------
    local rdiv = panel:CreateTexture(nil, "ARTWORK")
    rdiv:SetColorTexture(1, 1, 1, 0.06)
    rdiv:SetPoint("TOPLEFT", RCOL_X - 12, -72)
    rdiv:SetPoint("BOTTOMLEFT", RCOL_X - 12, 16)
    rdiv:SetWidth(1)

    Label(panel, "Result", 13):SetPoint("TOPLEFT", RCOL_X, -78)

    widgets.repNeeded = Label(panel, "", 12, 0.95, 0.86, 0.55)
    widgets.repNeeded:SetPoint("TOPLEFT", RCOL_X, -100)

    widgets.orderHeader = Label(panel, "Turn in this order:", 11, 0.7, 0.74, 0.8)
    widgets.orderHeader:SetPoint("TOPLEFT", RCOL_X, -122)

    widgets.groupTop = -140

    widgets.totals = Label(panel, "", 12, 0.92, 0.92, 0.94)
    widgets.totals:SetPoint("BOTTOMLEFT", RCOL_X, 56)

    widgets.bonusLine = Label(panel, "", 11, 0.62, 0.66, 0.72)
    widgets.bonusLine:SetPoint("BOTTOMLEFT", RCOL_X, 40)

    widgets.warning = Label(panel, "", 11, 0.85, 0.68, 0.42)
    widgets.warning:SetPoint("BOTTOMLEFT", RCOL_X, 22)
    widgets.warning:SetWidth(COL_W)
    widgets.warning:SetJustifyH("LEFT")

    panel:Hide()
end

-- Rebuild the per-item price rows for the active reputation. Called on first
-- show and whenever the active reputation changes (items differ).
function A.UI.RebuildItemRows()
    if not panel then return end
    for _, row in ipairs(priceRows) do row:Hide() end

    local def = RepCalc.GetActiveReputation()
    if not def or not def.items then return end

    local y = widgets.priceTop
    for i, item in ipairs(def.items) do
        local row = priceRows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row:SetSize(COL_W, 22)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(18, 18)
            row.icon:SetPoint("LEFT", 0, 0)
            row.name = Label(row, "", 11)
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.name:SetWidth(150)
            row.name:SetJustifyH("LEFT")
            row.box = MakeNumberBox(row, 56, function() end)
            row.box:SetPoint("RIGHT", 0, 0)
            priceRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", LCOL_X, y)
        row.itemID = item.itemID
        row.icon:SetTexture(GetItemIcon(item.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(item.name)
        -- rebind commit to this item id
        row.box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            A.DB.SetPrice(row.itemID, tonumber(self:GetText()) or 0)
            A.Engine.Refresh("price_changed")
        end)
        row.box:SetScript("OnEditFocusLost", function(self)
            A.DB.SetPrice(row.itemID, tonumber(self:GetText()) or 0)
            A.Engine.Refresh("price_changed")
        end)
        -- tooltip with item link / vendor + click hints
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if item.itemID then GameTooltip:SetHyperlink("item:" .. item.itemID) end
            if item.vendor then GameTooltip:AddLine(item.vendor, 0.7, 0.7, 0.7) end
            GameTooltip:AddLine("Click: search at the Auction House.", 0.5, 0.7, 1)
            GameTooltip:AddLine("Shift-click: link to chat / TSM / Auctionator.", 0.5, 0.7, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Click  → search this item at the AH (the passive scanner captures it).
        -- Shift  → drop the item link into whatever edit box is focused
        --          (chat, or a TSM / Auctionator search box).
        row:SetScript("OnMouseUp", function()
            if IsShiftKeyDown() then
                local _, link = GetItemInfo(item.itemID)
                link = link or ("item:" .. tostring(item.itemID))
                if HandleModifiedItemClick then
                    HandleModifiedItemClick(link)
                elseif ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                end
            elseif A.AHPrices and A.AHPrices.SearchAH then
                A.AHPrices.SearchAH(item.name)
            end
        end)
        row:Show()
        y = y - 24
    end
end

-- ---------------------------------------------------------------------------
-- Refresh — repaint every widget from current DB / faction state.
-- ---------------------------------------------------------------------------
local function Refresh()
    if not panel or not panel:IsShown() then return end

    local def = RepCalc.GetActiveReputation()
    if not def then return end

    widgets.title:SetText("RepCalc  |cff8a8e98— " .. def.name .. "|r")

    -- faction selector
    UIDropDownMenu_SetSelectedValue(widgets.factionDropdown, RepCalc.GetActiveReputationId())
    UIDropDownMenu_SetText(widgets.factionDropdown, def.name)

    -- current standing
    local override = A.DB.GetOverride()
    local usingLive = (override == nil)
    widgets.liveCheck:SetChecked(usingLive)
    widgets.curDropdown.Sync()
    if usingLive then
        UIDropDownMenu_DisableDropDown(widgets.curDropdown)
        widgets.withinBox:ClearFocus()
        widgets.withinBox:EnableMouse(false)
        widgets.withinBox:EnableKeyboard(false)
        widgets.withinBox:SetTextColor(0.5, 0.5, 0.5)
        widgets.withinBox:SetText("")
    else
        UIDropDownMenu_EnableDropDown(widgets.curDropdown)
        widgets.withinBox:EnableMouse(true)
        widgets.withinBox:EnableKeyboard(true)
        widgets.withinBox:SetTextColor(1, 1, 1)
        if not widgets.withinBox:HasFocus() then
            widgets.withinBox:SetText(tostring(override.within or 0))
        end
    end

    local live = A.Faction.ReadLive(def.factionID)
    if live then
        widgets.liveReadout:SetText(string.format("Live: %s  %d / %d",
            A.Faction.TIER_NAMES[live.tier] or live.tier, live.within, live.max))
    else
        widgets.liveReadout:SetText("Live: not tracked yet")
    end

    widgets.goalDropdown.Sync()

    -- bonuses
    local status = A.Bonuses.Status(A.DB.GetBonuses())
    local statusById = {}
    for _, s in ipairs(status) do statusById[s.id] = s end
    for id, cb in pairs(widgets.bonusChecks) do
        local s = statusById[id]
        if s then
            cb:SetChecked(s.on)
            local tag = (s.setting == "auto") and "  |cff6a8a6a(auto)|r" or ""
            cb.text:SetText(s.label .. tag)
        end
    end

    -- price boxes
    for _, row in ipairs(priceRows) do
        if row:IsShown() and row.itemID and not row.box:HasFocus() then
            row.box:SetText(tostring(A.DB.GetPrice(row.itemID)))
        end
    end

    -- ----- compute + paint results -----
    local scenario = A.Engine.BuildScenario()
    local plan = scenario and A.Calculator.Compute(scenario) or nil

    for _, gr in ipairs(groupRows) do gr:Hide() end

    if not plan or plan.repNeeded == 0 then
        widgets.repNeeded:SetText("Already at or past the goal.")
        widgets.totals:SetText("")
        widgets.bonusLine:SetText("")
        widgets.warning:SetText("")
        return
    end

    widgets.repNeeded:SetText(string.format("Reputation needed: %d", plan.repNeeded))

    local y = widgets.groupTop
    for i, g in ipairs(plan.groups) do
        local gr = groupRows[i]
        if not gr then
            gr = CreateFrame("Frame", nil, panel)
            gr:SetSize(COL_W, 30)
            gr.icon = gr:CreateTexture(nil, "ARTWORK")
            gr.icon:SetSize(16, 16)
            gr.icon:SetPoint("TOPLEFT", 0, 0)
            gr.line1 = Label(gr, "", 11)
            gr.line1:SetPoint("TOPLEFT", gr.icon, "TOPRIGHT", 5, 0)
            gr.line1:SetWidth(COL_W - 22); gr.line1:SetJustifyH("LEFT"); gr.line1:SetWordWrap(false)
            gr.line2 = Label(gr, "", 10, 0.6, 0.64, 0.7)
            gr.line2:SetPoint("TOPLEFT", gr.icon, "BOTTOMRIGHT", 5, -1)
            gr.line2:SetWidth(COL_W - 22); gr.line2:SetJustifyH("LEFT"); gr.line2:SetWordWrap(false)
            groupRows[i] = gr
        end
        gr:ClearAllPoints()
        gr:SetPoint("TOPLEFT", RCOL_X, y)
        gr.icon:SetTexture(GetItemIcon(g.item.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local miss = g.missingPrice and "  |cffd8a060(no price)|r" or ""
        gr.line1:SetText(string.format("%d x %s%s", g.count, g.item.name, miss))
        local unit = (scenario.prices and scenario.prices[g.item.itemID]) or 0
        gr.line2:SetText(string.format("@ %s ea  =  %s",
            A.Calculator.FormatSilver(unit),
            A.Calculator.FormatSilver(g.silver)))
        gr:Show()
        y = y - 32
    end

    widgets.totals:SetText(string.format("Total: %d items   %s",
        plan.totalItems, A.Calculator.FormatSilver(plan.totalSilver)))
    widgets.bonusLine:SetText(string.format("Bonus multiplier: x%.3f", plan.bonusMult))
    if plan.pricesMissing then
        widgets.warning:SetText("Some bands had no priced item; counts use the highest-rep fallback.")
    else
        widgets.warning:SetText("")
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function A.UI.EnsureBuilt()
    if not panel then
        BuildPanel()
        RestoreFramePos()
        A.UI.RebuildItemRows()
    end
end

-- Auto-fill the active reputation's prices from TSM when its API is available.
-- Only overwrites when TSM actually returns a value (>0), so items TSM doesn't
-- know about keep their AH-scanned / manually-entered price. Called on show and
-- on faction switch — not on every Refresh, so a manual edit sticks mid-session.
function A.UI.PullTSMPrices()
    if not A.TSMPrices or not A.TSMPrices.Available() then return end
    local def = RepCalc.GetActiveReputation()
    if not def or not def.items then return end
    for _, it in ipairs(def.items) do
        if it.itemID then
            local copper = A.TSMPrices.Get(it.itemID)
            if copper and copper > 0 then
                A.DB.SetPrice(it.itemID, math.floor(copper / 100 + 0.5))
            end
        end
    end
end

function A.UI.Show()
    A.UI.EnsureBuilt()
    A.UI.PullTSMPrices()
    panel:Show()
    Refresh()
end

function A.UI.Hide()
    if panel then panel:Hide() end
end

function A.UI.Toggle()
    A.UI.EnsureBuilt()
    if panel:IsShown() then panel:Hide() else A.UI.Show() end
end

function A.UI.IsShown()
    return panel and panel:IsShown()
end

-- Repaint whenever the engine signals a change.
A.Engine.OnRefresh(function() Refresh() end)

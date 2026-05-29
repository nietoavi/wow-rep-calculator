-- Core/Minimap.lua — RepCalc
-- Self-contained minimap button (no LibDBIcon dependency, matching the
-- addon's "no external libs" style). Left-click toggles the panel; the button
-- is draggable around the minimap edge and its angle is saved in
-- RepCalcDB.minimapAngle. RepCalcDB.minimapHide controls visibility.
local _, A = ...
A.Minimap = {}

local RADIUS = 80          -- distance from minimap centre
local button               -- the button frame
local built = false

local function SavedAngle()
    local db = A.DB.Shared()
    return (db and db.minimapAngle) or 165
end

local function Reposition()
    if not button then return end
    local a = math.rad(SavedAngle())
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

-- While dragging, track the cursor and convert it to an angle around the
-- minimap centre.
local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale  = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx))
    local db = A.DB.Shared()
    if db then db.minimapAngle = angle end
    Reposition()
end

local function Build()
    if built then return end
    built = true

    button = CreateFrame("Button", "RepCalcMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    -- Icon (uses the active reputation's icon; refreshed in A.Minimap.Refresh).
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    -- Standard tracking-border overlay.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function() A.UI.Toggle() end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RepCalc")
        local def = RepCalc.GetActiveReputation()
        if def then
            GameTooltip:AddLine(def.name, 0.8, 0.8, 0.85)
        end
        GameTooltip:AddLine("Click: open the calculator.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: move around the minimap.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Reposition()
    A.Minimap.Refresh()
end

-- Public: apply hidden state + active-reputation icon. Safe to call anytime.
function A.Minimap.Refresh()
    if not button then return end
    local db  = A.DB.Shared()
    local def = RepCalc.GetActiveReputation()
    if def and def.icon then button.icon:SetTexture(def.icon) end
    if db and db.minimapHide then button:Hide() else button:Show() end
    Reposition()
end

function A.Minimap.SetHidden(hide)
    local db = A.DB.Shared()
    if db then db.minimapHide = hide and true or false end
    A.Minimap.Refresh()
end

function A.Minimap.Toggle()
    local db = A.DB.Shared()
    A.Minimap.SetHidden(not (db and db.minimapHide))
end

-- Build once the DB is ready (login fires the first refresh) and keep the
-- icon / hidden-state in sync with reputation switches.
A.Engine.OnRefresh(function()
    if not built then Build() end
    A.Minimap.Refresh()
end)

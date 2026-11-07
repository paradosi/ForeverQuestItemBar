---- Bar — the frame, its secure buttons, layout and visuals --------------------
--
-- Each button inherits Blizzard's own ActionButtonTemplate (the art, cooldown
-- swipe, count and hotkey text of a real action button) plus
-- SecureActionButtonTemplate (the click). Blizzard documents that pairing as
-- supported in BaseActionButtonMixin:UpdateFlyout. With no self.bar, the
-- template draws the stand-alone slot art the Retail multi-bars use.
--
-- A button's action is the attribute pair type="item", item="item:<id>". Using
-- the item ID rather than bag/slot means the button keeps working if the item
-- moves in combat, when the attribute cannot be updated.

local _, ns = ...

local BUTTON_SIZE = 45      -- ActionButtonTemplate's own size on Retail 12
local RANGE_INTERVAL = 0.2  -- seconds between range checks while there is a target

local bar, mover
local buttons = {}

---- Position ------------------------------------------------------------------
--
-- Saved as the bar's TOPLEFT in UIParent units, so it is independent of the
-- bar's own scale, and the bar grows right and down from a fixed corner as
-- items come and go instead of re-centring.

local function SavePosition()
    local left, top = bar:GetLeft(), bar:GetTop()
    if not left or not top then return end
    local scale = bar:GetScale()
    ns.db.position = { x = left * scale, y = top * scale }
end

local function ApplyPosition()
    local pos, scale = ns.db.position, bar:GetScale()
    bar:ClearAllPoints()
    if type(pos) == "table" and pos.x and pos.y then
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / scale, pos.y / scale)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160 / scale)
    end
end

---- Button scripts ------------------------------------------------------------

local function Button_OnEnter(self)
    if not (self.itemID and ns.db.showTooltips) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:AddLine("Alt-right-click to hide from the bar", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function Button_OnLeave()
    GameTooltip:Hide()
end

-- Runs after the secure click (or instead of it, for the no-op modified
-- clicks set up in CreateButton). Buttons register for both key down and key
-- up, so this runs twice per press; act on the release only.
local function Button_PostClick(self, mouseButton, down)
    self:SetChecked(false) -- CheckButton: don't latch the "pressed" glow
    if down or not self.itemID then return end
    if mouseButton == "RightButton" and IsAltKeyDown() then
        ns:IgnoreItem(self.itemID)
    elseif IsModifiedClick("CHATLINK") then
        local _, link = C_Item.GetItemInfo(self.itemID)
        if link then HandleModifiedItemClick(link) end
    end
end

local function CreateButton(index)
    local b = CreateFrame("CheckButton", ns.BUTTON_NAME .. index, bar,
        "ActionButtonTemplate, SecureActionButtonTemplate")
    -- Mouse clicks fire on release. Keybinds fire on press or release per the
    -- ActionButtonUseKeyDown CVar. Registering both is what lets the secure
    -- handler honour that CVar for this button's CLICK binding.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    -- Shift-left-click links the item instead of using it, and
    -- Alt-right-click hides it: both handled in PostClick.
    b:SetAttribute("shift-type1", ATTRIBUTE_NOOP)
    b:SetAttribute("alt-type2", ATTRIBUTE_NOOP)
    b:HookScript("OnEnter", Button_OnEnter)
    b:HookScript("OnLeave", Button_OnLeave)
    b:SetScript("PostClick", Button_PostClick)
    b:Hide()
    return b
end

---- Per-button visuals (safe in combat) ---------------------------------------

local function UpdateButton(b)
    local itemID = b.itemID
    if not itemID then return end

    b.icon:SetTexture(C_Item.GetItemIconByID(itemID))

    -- includeUses: an item with charges shows its charges, as on an action bar.
    local count = C_Item.GetItemCount(itemID, false, true)
    b.Count:SetText(count > 1 and tostring(count) or "")

    local start, duration, enable = C_Container.GetItemCooldown(itemID)
    CooldownFrame_Set(b.cooldown, start or 0, duration or 0, enable)

    -- Out-of-range is shown on the hotkey (UpdateRange). The icon follows the
    -- action bar convention: dimmed when unusable, blue when out of mana, and
    -- greyed out when the last one was used in combat and the button is
    -- waiting for combat to end to disappear.
    local usable, noMana = C_Item.IsUsableItem(itemID)
    b.icon:SetDesaturated(count == 0)
    if count == 0 then
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    elseif usable then
        b.icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        b.icon:SetVertexColor(0.5, 0.5, 1)
    else
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

function ns:UpdateButtons()
    for _, b in ipairs(buttons) do
        if b:IsShown() then UpdateButton(b) end
    end
end

-- Hotkey text, as Blizzard's ActionButton does it: the bound key, abbreviated,
-- or RANGE_INDICATOR (a dot that appears only while the item checks range).
function ns:UpdateHotkeys()
    for i, b in ipairs(buttons) do
        local key = GetBindingKey(ns.BindingCommand(i))
        local text = key and self.db.showHotkeys and GetBindingText(key, 1) or ""
        if text == "" then
            b.HotKey:SetText(RANGE_INDICATOR)
            b.HotKey:Hide()
        else
            b.HotKey:SetText(text)
            b.HotKey:Show()
        end
    end
    self:UpdateRange()
end

-- Retail made IsItemInRange protected in combat against anything you cannot
-- attack, so in combat it is only asked about hostile targets. Everywhere else
-- the button just shows no range state.
local function CanCheckRange()
    if not UnitExists("target") then return false end
    return not InCombatLockdown() or UnitCanAttack("player", "target")
end

function ns:UpdateRange()
    local check = CanCheckRange()
    for _, b in ipairs(buttons) do
        if b:IsShown() and b.itemID then
            local inRange
            if check then inRange = C_Item.IsItemInRange(b.itemID, "target") end
            ActionButton_UpdateRangeIndicator(b, inRange ~= nil, inRange)
        end
    end
end

---- Layout (out of combat only) -----------------------------------------------

local function Layout(count)
    local db = ns.db
    local perRow = math.max(1, math.min(db.buttonsPerRow, ns.MAX_BUTTONS))
    local step = BUTTON_SIZE + db.spacing
    for i, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", ((i - 1) % perRow) * step, -math.floor((i - 1) / perRow) * step)
    end
    -- An empty, unlocked bar keeps one slot's worth of size so the drag
    -- handle has something to hold.
    local n = math.max(count, 1)
    local cols, rows = math.min(n, perRow), math.ceil(n / perRow)
    bar:SetSize(cols * step - db.spacing, rows * step - db.spacing)
    if bar:GetScale() ~= db.scale then bar:SetScale(db.scale) end
    ApplyPosition()
end

-- Assign items to buttons and rebuild the bar. Called only by ns:Refresh(),
-- which guarantees we are out of combat.
function ns:SetItems(items)
    local db = self.db
    local count = math.min(#items, ns.MAX_BUTTONS)
    for i, b in ipairs(buttons) do
        local itemID = items[i]
        if i <= count then
            if b.itemID ~= itemID then
                b.itemID = itemID
                b:SetAttribute("item", "item:" .. itemID)
            end
            b:Show()
        else
            b.itemID = nil
            b:SetAttribute("item", nil)
            b:Hide()
        end
    end
    Layout(count)
    mover:SetShown(not db.locked)
    bar:SetShown(count > 0 or not db.locked)
    mover.label:SetText(count > 0 and "Quest Item Bar" or "Quest Item Bar\n|cff888888(empty)|r")
    self:UpdateHotkeys()
    self:UpdateButtons()
end

---- Creation ------------------------------------------------------------------

function ns:CreateBar()
    bar = CreateFrame("Frame", "ForeverQuestItemBarFrame", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bar:SetScale(self.db.scale)
    ApplyPosition()
    bar:Hide()

    for i = 1, ns.MAX_BUTTONS do
        buttons[i] = CreateButton(i)
    end

    -- Drag handle, shown while unlocked. It sits above the buttons (whose text
    -- overlay is at frame level 500) so it takes the mouse: an unlocked bar is
    -- for moving, not clicking, as with Blizzard's Edit Mode.
    mover = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    mover:SetPoint("TOPLEFT", -4, 4)
    mover:SetPoint("BOTTOMRIGHT", 4, -4)
    mover:SetFrameLevel(510)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.1, 0.35, 0.8, 0.35)
    mover:SetBackdropBorderColor(0.3, 0.6, 1, 0.9)
    mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.label:SetPoint("CENTER")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        bar:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition()
        -- Re-anchor to TOPLEFT (StartMoving leaves its own anchor), unless
        -- combat began mid-drag: then Refresh re-anchors when it ends.
        if InCombatLockdown() then
            ns.pendingRefresh = true
        else
            ApplyPosition()
        end
    end)
    mover:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "RightButton" then ns:OpenOptions() end
    end)
    mover:SetScript("OnEnter", function(handle)
        GameTooltip:SetOwner(handle, "ANCHOR_TOP")
        GameTooltip:AddLine("Forever Quest Item Bar")
        GameTooltip:AddLine("Drag to move. Right-click for settings.", 1, 1, 1)
        GameTooltip:AddLine("/fqib lock to lock it in place.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    mover:SetScript("OnLeave", Button_OnLeave)
    mover:Hide()

    -- Range only changes as you move, which raises no event. Poll it, but only
    -- while the bar is visible and there is a target to be in range of.
    local elapsed = 0
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < RANGE_INTERVAL then return end
        elapsed = 0
        if UnitExists("target") then ns:UpdateRange() end
    end)
end

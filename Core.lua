--[[ Forever Quest Item Bar
     Author: paradosi-Dreamscythe
     MIT License

     Shows a bar of buttons, one per quest item in your bags, that looks and
     clicks like a standard action bar. Built for WoW Forever, which is Vanilla
     content on Retail 12's engine: the API is Retail's (C_Container, C_Item,
     C_QuestLog), the item and quest data are Vanilla's.

     Files, in TOC load order:
       Core.lua     saved variables, the bag scan, events, slash commands
       Bar.lua      the bar, its secure buttons, layout and per-button visuals
       Options.lua  the Settings panel (Esc > Options > AddOns)

     The one rule that shapes everything: the buttons are secure action buttons,
     so their "item" attribute, and the bar's size, position, scale and
     visibility, can only change OUT of combat. ns:Refresh() is the single entry
     point for those changes and defers itself to PLAYER_REGEN_ENABLED when
     called in combat. Counts, cooldowns, usability and range are plain
     textures and text, and update in combat too.
]]

local addonName, ns = ...

---- Constants -----------------------------------------------------------------

ns.MAX_BUTTONS = 12
ns.BUTTON_NAME = "ForeverQuestItemBarButton"

-- Enum.ItemClass.Questitem. Written as the number because the value has been
-- 12 on every client since Vanilla and the enum adds a lookup for nothing.
local ITEM_CLASS_QUEST = 12

-- Backpack is bag 0; Forever, like Retail, has four bag slots plus a reagent
-- bag (5). Scanning the reagent bag costs nothing and is empty on Vanilla data.
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

ns.defaults = {
    locked = false,        -- false shows the drag handle; a new install starts unlocked
    usableOnly = true,     -- only items you can click: a Use: effect, or starts a quest
    buttonsPerRow = 12,
    scale = 1.0,
    spacing = 4,
    showHotkeys = true,
    showTooltips = true,
    position = false,      -- { x, y }: the bar's TOPLEFT in UIParent units; false = default spot
    ignored = {},          -- [itemID] = true, hidden with Alt-right-click
}

---- Utilities -----------------------------------------------------------------

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Quest Item Bar:|r " .. msg)
end

-- Fill missing keys from defaults, recursing into tables, without overwriting
-- what the player has set.
local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.BindingCommand(index)
    return "CLICK " .. ns.BUTTON_NAME .. index .. ":LeftButton"
end

-- Key Bindings menu labels. The client reads these globals when the menu opens.
BINDING_HEADER_FOREVERQUESTITEMBAR = "Forever Quest Item Bar"
for i = 1, ns.MAX_BUTTONS do
    _G["BINDING_NAME_" .. ns.BindingCommand(i)] = "Quest Item " .. i
end

---- Finding quest items -------------------------------------------------------

-- Items the quest log itself offers as a quest's "special item" (the button
-- that appears next to a quest in the log). On Vanilla data these are rare, but
-- when they exist they are by definition the item the quest wants used.
local function CollectQuestLogItems(out)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local link = GetQuestLogSpecialItemInfo(index)
        if link then
            local itemID = C_Item.GetItemInfoInstant(link)
            if itemID then out[itemID] = true end
        end
    end
end

-- Is the item in bag/slot one the bar should show?
--
-- "Quest item" is any of: item class Quest; the container's isQuestItem flag;
-- an item that starts a quest (questID set); a quest log special item. Classic
-- data is inconsistent about which of these a given item carries, so all four
-- are accepted.
--
-- "Usable" is: the item has a Use: spell, or it starts a quest (clicking it
-- opens the quest). Plain collect-ten-of-these drops have neither, and a button
-- that does nothing when clicked is clutter, so usableOnly hides them.
local function IsBarItem(bag, slot, itemID, questLogItems, usableOnly)
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    local questInfo = C_Container.GetContainerItemQuestInfo(bag, slot)
    local startsQuest = questInfo and questInfo.questID ~= nil
    local isQuest = classID == ITEM_CLASS_QUEST
        or (questInfo and questInfo.isQuestItem)
        or startsQuest
        or questLogItems[itemID]
    if not isQuest then return false end
    if not usableOnly then return true end
    return startsQuest or questLogItems[itemID] or C_Item.GetItemSpell(itemID) ~= nil
end

local questLogItems = {}

-- Returns an ordered list of itemIDs, one per distinct item, in bag order
-- (backpack first, then bags 1-4, each top to bottom). Bag order is stable
-- unless the player rearranges bags, so a keybind keeps pointing at the same
-- item while it is in use.
function ns:ScanItems()
    local db = self.db
    local items, seen = {}, {}
    wipe(questLogItems)
    CollectQuestLogItems(questLogItems)
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                if not db.ignored[itemID]
                    and IsBarItem(bag, slot, itemID, questLogItems, db.usableOnly) then
                    items[#items + 1] = itemID
                end
            end
        end
    end
    return items
end

---- Refresh -------------------------------------------------------------------

-- Bag and quest events arrive in bursts (looting fires BAG_UPDATE per slot,
-- QUEST_LOG_UPDATE fires constantly). Coalesce them into one refresh.
local refreshQueued = false

function ns:RequestRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        ns:Refresh()
    end)
end

-- Rescan the bags and rebuild the bar. In combat, only update what is safe
-- (counts, cooldowns, colours) and finish the job when combat ends.
function ns:Refresh()
    if not self.db then return end
    if InCombatLockdown() then
        self.pendingRefresh = true
        self:UpdateButtons()
        return
    end
    self.pendingRefresh = false
    self:SetItems(self:ScanItems())
end

function ns:IgnoreItem(itemID)
    self.db.ignored[itemID] = true
    local _, link = C_Item.GetItemInfo(itemID)
    ns.Print((link or ("item " .. itemID)) .. " hidden from the bar. |cff888888/fqib unhide|r brings hidden items back.")
    self:RequestRefresh()
end

function ns:SetLocked(locked)
    self.db.locked = locked
    if Settings and Settings.NotifyUpdate then Settings.NotifyUpdate("FQIB_locked") end
    self:RequestRefresh()
end

---- Events --------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    ns[event](ns, ...)
end)
eventFrame:RegisterEvent("ADDON_LOADED")

function ns:ADDON_LOADED(name)
    if name ~= addonName then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")

    ForeverQuestItemBarDB = ForeverQuestItemBarDB or {}
    ApplyDefaults(ForeverQuestItemBarDB, self.defaults)
    self.db = ForeverQuestItemBarDB

    self:CreateBar()
    self:CreateOptions()

    -- What's in the bags changed, or what counts as a quest item did.
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE",
        "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED",
        -- Only the look of existing buttons changed.
        "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "PLAYER_TARGET_CHANGED",
        "UPDATE_BINDINGS",
    }) do
        eventFrame:RegisterEvent(event)
    end
end

function ns:PLAYER_ENTERING_WORLD() self:RequestRefresh() end
function ns:BAG_UPDATE_DELAYED() self:RequestRefresh() end
function ns:QUEST_LOG_UPDATE() self:RequestRefresh() end
function ns:GET_ITEM_INFO_RECEIVED() self:RequestRefresh() end

function ns:PLAYER_REGEN_ENABLED()
    if self.pendingRefresh then self:Refresh() end
end

function ns:BAG_UPDATE_COOLDOWN() self:UpdateButtons() end
function ns:SPELL_UPDATE_USABLE() self:UpdateButtons() end
function ns:PLAYER_TARGET_CHANGED() self:UpdateRange() end
function ns:UPDATE_BINDINGS() self:UpdateHotkeys() end

---- Slash commands ------------------------------------------------------------

local HELP = {
    "|cffffd100/fqib|r opens the settings.",
    "|cffffd100/fqib lock|r / |cffffd100unlock|r locks or unlocks the bar for moving.",
    "|cffffd100/fqib reset|r puts the bar back in its default spot.",
    "|cffffd100/fqib unhide|r brings back items hidden with Alt-right-click.",
}

SLASH_FOREVERQUESTITEMBAR1 = "/fqib"
SLASH_FOREVERQUESTITEMBAR2 = "/questbar"
SlashCmdList.FOREVERQUESTITEMBAR = function(msg)
    local cmd = strtrim(msg or ""):lower()
    local changesBar = cmd == "lock" or cmd == "unlock" or cmd == "reset" or cmd == "unhide"
    if changesBar and InCombatLockdown() then
        ns.Print("In combat: the bar will update when combat ends.")
    end
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns:OpenOptions()
    elseif cmd == "lock" then
        ns:SetLocked(true)
        ns.Print("Bar locked.")
    elseif cmd == "unlock" then
        ns:SetLocked(false)
        ns.Print("Bar unlocked. Drag it to move it; right-click the handle for settings.")
    elseif cmd == "reset" then
        ns.db.position = false
        ns:RequestRefresh()
        ns.Print("Bar position reset.")
    elseif cmd == "unhide" then
        local n = 0
        for _ in pairs(ns.db.ignored) do n = n + 1 end
        wipe(ns.db.ignored)
        ns:RequestRefresh()
        ns.Print(n == 1 and "1 hidden item restored." or (n .. " hidden items restored."))
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end

-- luacheck: ignore
-- (this file stubs the WoW API by assigning its globals; nothing here ships)
--
-- Headless test: loads the addon in TOC order against a stubbed WoW API, then
-- plays through the bag scan, the settings panel (every control), the copy
-- dialog, the slash commands and combat, checking the saved settings and the
-- bar after each step. Catches nil calls, typos and wiring slips that the
-- static gate can't. It does not draw anything: layout still needs the game.
-- The widget stubs are adapted from FarmMode Forever's tests/smoke.lua.
--
--   cd ForeverQuestItemBar && lua5.1 tests/smoke.lua

local failures = 0
local function check(cond, msg)
    if cond then print("ok   " .. msg) else failures = failures + 1; print("FAIL " .. msg) end
end

---- A permissive widget: unknown CamelCase methods are no-ops; the ones the
---- addon reads keep real state

local methods = {}
local Widget = {
    __index = function(_, k)
        if methods[k] then return methods[k] end
        if type(k) == "string" and k:match("^%u") then return function() end end
    end,
}
local function NewWidget(kind, name)
    return setmetatable({ kind = kind, name = name, scripts = {}, shown = true, points = {},
                          w = 100, h = 100, alpha = 1, value = 0, scale = 1, attrs = {},
                          enabled = true, children = {} }, Widget)
end
function methods.SetScript(self, k, fn) self.scripts[k] = fn end
function methods.GetScript(self, k) return self.scripts[k] end
function methods.HookScript(self, k, fn)
    local before = self.scripts[k]
    self.scripts[k] = function(...) if before then before(...) end fn(...) end
end
function methods.Show(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods.Hide(self)
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.GetLeft() return 400 end
function methods.GetRight(self) return 400 + self.w end
function methods.GetTop() return 300 end
function methods.GetFrameLevel() return 1 end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetPoint(self, ...) table.insert(self.points, { ... }) end
function methods.GetPoint(self, i) return unpack(self.points[i or 1] or {}) end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetScale(self, s) self.scale = s end
function methods.GetScale(self) return self.scale end
function methods.IsMouseOver() return false end
function methods.HasFocus(self) return self.focus end
function methods.SetFocus(self) self.focus = true end
function methods.ClearFocus(self) self.focus = false end
function methods.SetText(self, t) self.text = t end
function methods.GetText(self) return self.text end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.GetName(self) return self.name end
function methods.GetID(self) return self.id end
function methods.SetAttribute(self, k, v) self.attrs[k] = v end
function methods.GetAttribute(self, k) return self.attrs[k] end
function methods.CreateTexture(self) return NewWidget("Texture") end
function methods.CreateFontString(self) return NewWidget("FontString") end
function methods.GetThumbTexture(self)
    self.thumb = self.thumb or NewWidget("Texture")
    return self.thumb
end
function methods.SetMinMaxValues(self, a, b) self.min, self.max = a, b end
function methods.SetValue(self, v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function methods.GetValue(self) return self.value end
function methods.RegisterEvent(self, e) self.events = self.events or {}; self.events[e] = true end
function methods.UnregisterEvent(self, e) if self.events then self.events[e] = nil end end
function methods.Click(self, button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end

---- Globals

local frames = {}
function CreateFrame(kind, name, parent, template)
    local f = NewWidget(kind, name)
    if name then _G[name] = f end
    if parent then table.insert(parent.children, f) end
    if template and template:find("ActionButtonTemplate") then
        f.icon, f.Count, f.HotKey, f.cooldown =
            NewWidget("Texture"), NewWidget("FontString"), NewWidget("FontString"), NewWidget("Cooldown")
    end
    table.insert(frames, f)
    return f
end
UIParent = NewWidget("Frame", "UIParent")
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) LAST_PRINT = m end }
SOUNDKIT = { U_CHAT_SCROLL_BUTTON = 1115 }
ATTRIBUTE_NOOP = ""
GameTooltip = NewWidget("GameTooltip")
function PlaySound() end
function CreateColor(r, g, b, a) return { r, g, b, a } end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tinsert(t, v) table.insert(t, v) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetBindingKey() return nil end
function GetBindingText(k) return k end
function CooldownFrame_Set() end
function ActionButton_UpdateRangeIndicator() end
function UnitExists() return false end
function UnitCanAttack() return false end
function IsAltKeyDown() return false end
function IsModifiedClick() return false end
function HandleModifiedItemClick() end
function GetQuestLogSpecialItemInfo() return nil end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5

local state = { combat = false }
function InCombatLockdown() return state.combat end

local timers = {}
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
local function RunAfters()
    while #timers > 0 do table.remove(timers, 1)() end
end

-- Bags: slot contents by bag, and what each item is
local bags = { [0] = {} }
local itemData = {
    [5001] = { class = 12, spell = "Use It" },      -- quest item with a Use: effect
    [5002] = { class = 12 },                        -- collect-only quest item
    [5003] = { class = 0, spell = "Drink" },        -- not a quest item
}
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and 16 or 0 end,
    GetContainerItemID = function(bag, slot) return bags[bag] and bags[bag][slot] end,
    GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
    GetItemCooldown = function() return 0, 0, 1 end,
}
C_Item = {
    GetItemInfoInstant = function(id) local d = itemData[id]; return id, nil, nil, nil, nil, d and d.class end,
    GetItemSpell = function(id) return itemData[id] and itemData[id].spell end,
    GetItemInfo = function(id) return "Item " .. id, "[Item " .. id .. "]" end,
    GetItemIconByID = function() return 134400 end,
    GetItemCount = function() return 1 end,
    IsUsableItem = function() return true end,
    IsItemInRange = function() return true end,
}
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then return "9.9.9" end
        if field == "X-Website" then return "https://github.com/paradosi/ForeverQuestItemBar" end
    end,
}

local opened
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return { panel = panel, name = name, GetID = function() return 42 end }
    end,
    RegisterAddOnCategory = function(cat) Settings.category = cat end,
    OpenToCategory = function(id) opened = id end,
}

---- Load the addon in TOC order

local ns = {}
for line in io.lines("ForeverQuestItemBar.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(line))
        chunk("ForeverQuestItemBar", ns)
    end
end
check(ns.T and ns.W, "Theme and Widgets loaded")

ns.ADDON_LOADED(ns, "ForeverQuestItemBar")
check(ns.db and ForeverQuestItemBarDB == ns.db, "saved variables set up")
check(Settings.category and Settings.category.name == "Forever Quest Item Bar", "settings panel registered")

local function Refresh()
    RunAfters()
end
local function Shown(i) return _G["ForeverQuestItemBarButton" .. i] and _G["ForeverQuestItemBarButton" .. i].shown end

---- Bag scan

bags[0] = { 5001, 5002, 5003 }
ns:RequestRefresh(); Refresh()
check(Shown(1) and not Shown(2), "usable quest item on the bar, collect-only one not")
check(_G.ForeverQuestItemBarButton1.attrs.item == "item:5001", "button 1 casts item 5001")

---- Settings panel: find the controls by walking the panel's tree

local panel = ForeverQuestItemBarOptions
panel:Show()
local function Walk(f, out)
    out = out or {}
    for _, c in ipairs(f.children) do
        table.insert(out, c)
        Walk(c, out)
    end
    return out
end
local all = Walk(panel)
local checks, sliders, buttons = {}, {}, {}
for _, f in ipairs(all) do
    if f.kind == "Button" and f.label and f.label.text then
        local t = f.label.text
        if f.SetChecked and rawget(f, "checked") ~= nil then checks[t] = f else buttons[t] = f end
    elseif f.kind == "Slider" then
        table.insert(sliders, f)
    end
end
local function CheckBox(label) return checks[label] or error("no checkbox " .. label) end

check(CheckBox("Only items you can use").checked == true, "panel shows usableOnly on")
check(CheckBox("Lock the bar").checked == false, "panel shows the bar unlocked")
check(#sliders == 3, "three sliders (per row, scale, spacing)")

CheckBox("Only items you can use"):Click(); Refresh()
check(ns.db.usableOnly == false, "unticking Only usable items saves it")
check(Shown(2), "collect-only quest item now on the bar")

CheckBox("Lock the bar"):Click(); Refresh()
check(ns.db.locked == true, "ticking Lock saves it")

ns.db.position = { x = 400, y = 300 }    -- moved once, before right edges were saved
CheckBox("Grow to the left"):Click(); Refresh()
check(ns.db.growLeft == true, "Grow to the left saves it")
local anchor = ForeverQuestItemBarFrame.points[1]
check(anchor and anchor[1] == "TOPRIGHT", "a moved bar growing left anchors by its top right")
check(ns.db.position.right == 400 + ForeverQuestItemBarFrame.w, "switching saves the right edge where the bar is now")

-- Scale slider: shown in %, saved as a fraction
local scaleSlider = sliders[2]
scaleSlider:SetValue(150); Refresh()
check(math.abs(ns.db.scale - 1.5) < 1e-9, "scale slider at 150% saves 1.5")
sliders[1]:SetValue(3); Refresh()
check(ns.db.buttonsPerRow == 3, "buttons per row slider saves it")

-- Hidden items
ns:IgnoreItem(5001); Refresh()
check(ns.db.ignored[5001] and not (_G.ForeverQuestItemBarButton1.attrs.item == "item:5001"), "Alt-right-click hides the item")
local showHidden = buttons["SHOW HIDDEN ITEMS"]
check(showHidden and showHidden.enabled, "Show hidden items is enabled with one hidden")
showHidden:Click(); Refresh()
check(next(ns.db.ignored) == nil, "Show hidden items brings them back")
check(showHidden.enabled == false, "and greys itself out")

-- Position
ns.db.position = { x = 10, right = 100, y = 500 }
buttons["MOVE IT BACK TO THE MIDDLE"]:Click(); Refresh()
check(ns.db.position == false, "Move it back resets the position")

-- Copy dialog
buttons["HELP AND BUG REPORTS"]:Click()
local dialog = ForeverQuestItemBarCopyDialog
check(dialog and dialog.shown and dialog.box.text == "https://github.com/paradosi/ForeverQuestItemBar",
    "Help button opens the link, selected")
dialog.box.scripts.OnTextChanged(dialog.box, true)
dialog.box.text = "typed over it"
dialog.box.scripts.OnTextChanged(dialog.box, true)
check(dialog.box.text == "https://github.com/paradosi/ForeverQuestItemBar", "typing in the box puts the link back")
dialog.box.scripts.OnEscapePressed(dialog.box)
check(not dialog.shown, "Escape closes it")
check(UISpecialFrames[1] == "ForeverQuestItemBarCopyDialog", "dialog closes with Escape like a panel")

---- Slash commands keep the open panel in step

SlashCmdList.FOREVERQUESTITEMBAR("unlock"); Refresh()
check(ns.db.locked == false and CheckBox("Lock the bar").checked == false, "/fqib unlock updates the panel")
local mover
for _, c in ipairs(ForeverQuestItemBarFrame.children) do if c.label and c.kind == "Frame" then mover = c end end
check(mover and mover.shown, "unlocked: the drag handle shows")
check(mover and mover.label.text and mover.label.text:find("QUEST ITEM BAR"), "handle labelled")
SlashCmdList.FOREVERQUESTITEMBAR("lock"); Refresh()
check(mover and not mover.shown, "locked: the handle hides")
SlashCmdList.FOREVERQUESTITEMBAR("")
check(opened == 42, "/fqib opens the settings")
SlashCmdList.FOREVERQUESTITEMBAR("help")
check(LAST_PRINT and LAST_PRINT:find("hidden with Alt") ~= nil, "/fqib help prints the commands")

---- Combat: a change waits, then applies

state.combat = true
CheckBox("Only items you can use"):Click(); Refresh()
check(ns.pendingRefresh, "in combat the rebuild waits")
state.combat = false
ns.PLAYER_REGEN_ENABLED(ns); Refresh()
check(not ns.pendingRefresh and ns.db.usableOnly == true and not Shown(2), "applied when combat ends")

print(failures == 0 and "\nall passed" or ("\n" .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)

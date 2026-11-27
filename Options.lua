---- Options — the settings panel (Esc > Options > AddOns > Forever Quest Item Bar)
--
-- wowdb.dev's look, shared with Forever Alts, Nightclaw Ears and FarmMode
-- Forever: a navy panel, Oswald capitals for labels, JetBrains Mono for numbers,
-- gold for whatever is active. The controls come from Widgets.lua. Every
-- control writes ns.db and calls ns:RequestRefresh(), which applies it at once
-- out of combat and when combat ends otherwise (the bar holds secure buttons).
-- ns:SyncOptions() puts the controls back in step after a slash command.

local addonName, ns = ...
local T, W = ns.T, ns.W
local C = T.C

-- Both come from the TOC, so `wowdev bump` keeps the version current here.
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
ns.WEBSITE = C_AddOns.GetAddOnMetadata(addonName, "X-Website")

local COL_W = W.COL_W
local category, panel
local Sync = function() end

function ns:OpenOptions()
    if category then Settings.OpenToCategory(category:GetID()) end
end

function ns:ShowSupportLink()
    if ns.WEBSITE then W.CopyDialog("Help and bug reports", ns.WEBSITE) end
end

function ns:SyncOptions()
    if panel and panel:IsShown() then Sync() end
end

local function CountHidden()
    local n = 0
    for _ in pairs(ns.db.ignored) do n = n + 1 end
    return n
end

function ns:CreateOptions()
    local db = self.db
    panel = CreateFrame("Frame", "ForeverQuestItemBarOptions", UIParent)
    panel.name = "Forever Quest Item Bar"
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, C.bg)

    ---- Header: logo, name, version chip, gold line

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 18, -16)
    logo:SetTexture("Interface\\AddOns\\ForeverQuestItemBar\\media\\textures\\logo_64")

    local title = T.Text(panel, T.display, 20, C.primary)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText("FOREVER QUEST ITEM BAR")

    local version = T.Chip(panel)
    version:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -24)
    version:SetText("V" .. ns.VERSION)

    local sub = T.Text(panel, T.mono, 11, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("the usable quest items in your bags, on one bar  ·  changes apply live")

    T.GoldLine(panel, -70)

    local host = CreateFrame("Frame", nil, panel)
    host:SetPoint("TOPLEFT", 0, -72)
    host:SetPoint("BOTTOMRIGHT")

    local function ColumnTop(x)
        local f = CreateFrame("Frame", nil, host)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", host, "TOPLEFT", x, -8)
        return f
    end
    local left, right = ColumnTop(18), ColumnTop(18 + COL_W + 40)

    local function Set(key)
        return function(v)
            db[key] = v
            ns:RequestRefresh()
        end
    end

    ---- Left column: the bar's shape and size

    local barSec = W.Section(host, left, 0, "Bar")
    local locked = W.Check(host, barSec, -10, "Lock the bar")
    locked.onChange = function(v) ns:SetLocked(v) end
    local lockNote = W.Note(host, locked, -4, "unlocked, it shows a handle you can drag")
    local growLeft = W.Check(host, lockNote, -10, "Grow to the left")
    growLeft.onChange = function(v)
        -- Pin the current edges first, so the bar keeps its place when the
        -- corner it grows from switches.
        ns:SavePosition()
        db.growLeft = v
        ns:RequestRefresh()
    end
    local growNote = W.Note(host, growLeft, -4, "the right edge stays put, for a bar on the right")

    local perRow = W.Slider(host, growNote, -14, "Buttons per row", 1, ns.MAX_BUTTONS, 1, 1)
    perRow.onChange = Set("buttonsPerRow")
    local scale = W.Slider(host, perRow, -10, "Scale", 50, 200, 5, 5, "%")
    scale.onChange = function(v)
        db.scale = v / 100
        ns:RequestRefresh()
    end
    local spacing = W.Slider(host, scale, -10, "Button spacing", 0, 20, 1, 1, "px")
    spacing.onChange = Set("spacing")

    ---- Right column: what goes on the bar, how the buttons look

    local itemsSec = W.Section(host, right, 0, "Items")
    local usable = W.Check(host, itemsSec, -10, "Only items you can use")
    usable.onChange = Set("usableOnly")
    local usableNote = W.Note(host, usable, -4, "off also shows pelts, trophies and other quest loot")

    local hidden = W.Button(host, "Show hidden items", COL_W)
    hidden:SetPoint("TOPLEFT", usableNote, "BOTTOMLEFT", 0, -12)
    local hiddenNote = W.Note(host, hidden, -6, "")
    hidden:SetScript("OnClick", function()
        wipe(db.ignored)
        ns:RequestRefresh()
        Sync()
    end)

    local buttonsSec = W.Section(host, hiddenNote, -18, "Buttons")
    local hotkeys = W.Check(host, buttonsSec, -10, "Show keybinds")
    hotkeys.onChange = Set("showHotkeys")
    local tooltips = W.Check(host, hotkeys, -6, "Show tooltips")
    tooltips.onChange = Set("showTooltips")
    local bindNote = W.Note(host, tooltips, -6, "bind keys under Key Bindings > AddOns")

    local posSec = W.Section(host, bindNote, -18, "Position")
    local resetPos = W.Button(host, "Move it back to the middle", COL_W)
    resetPos:SetPoint("TOPLEFT", posSec, "BOTTOMLEFT", 0, -12)
    resetPos:SetScript("OnClick", function()
        db.position = false
        ns:RequestRefresh()
    end)

    ---- Footer: help, and the slash command

    local foot = T.Line(host, C.divider)
    foot:SetPoint("TOPLEFT", resetPos, "BOTTOMLEFT", -(COL_W + 40), -20)
    foot:SetWidth(COL_W * 2 + 40)

    local help = W.Button(host, "Help and bug reports", 180)
    help:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -12)
    help:SetScript("OnClick", function() ns:ShowSupportLink() end)
    help:SetShown(ns.WEBSITE ~= nil)

    local hint = T.Text(host, T.mono, 11, C.muted)
    hint:SetPoint("LEFT", help, "RIGHT", 16, 0)
    hint:SetText("/fqib opens this  ·  Alt-right-click a button to hide its item")

    Sync = function()
        locked:SetChecked(db.locked)
        growLeft:SetChecked(db.growLeft)
        perRow:SetValue(db.buttonsPerRow)
        scale:SetValue(math.floor(db.scale * 100 + 0.5))
        spacing:SetValue(db.spacing)
        usable:SetChecked(db.usableOnly)
        hotkeys:SetChecked(db.showHotkeys)
        tooltips:SetChecked(db.showTooltips)
        local n = CountHidden()
        hidden:SetEnabled(n > 0)
        hidden:SetAlpha(n > 0 and 1 or 0.4)
        hiddenNote:SetText(n == 0 and "no items hidden (Alt-right-click a button to hide one)"
            or n == 1 and "1 item hidden from the bar" or (n .. " items hidden from the bar"))
    end
    panel:SetScript("OnShow", Sync)

    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

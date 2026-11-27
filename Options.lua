---- Options — the Settings panel (Esc > Options > AddOns) ----------------------
--
-- Blizzard's vertical-layout Settings API, with proxy settings: each control
-- reads and writes ns.db directly, and every write goes through
-- ns:RequestRefresh(), which applies it immediately out of combat and after
-- combat otherwise. Setting variables are prefixed FQIB_ because the Settings
-- registry is shared by every addon.

local addonName, ns = ...

local category

-- Both come from the TOC, so `wowdev bump` keeps the version current here.
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
ns.WEBSITE = C_AddOns.GetAddOnMetadata(addonName, "X-Website")

-- Addons can't open a browser, so the support link is shown selected in an
-- edit box for Ctrl+C. Typing in the box puts the link back.
StaticPopupDialogs.FQIB_SUPPORT_LINK = {
    text = "Forever Quest Item Bar on GitHub: report a problem or ask a question.\nPress Ctrl+C to copy the link.",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 340,
    OnShow = function(dialog, url)
        local editBox = dialog:GetEditBox()
        editBox:SetText(url)
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnTextChanged = function(editBox, url)
        if editBox:GetText() ~= url then
            editBox:SetText(url)
            editBox:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns:ShowSupportLink()
    if ns.WEBSITE then StaticPopup_Show("FQIB_SUPPORT_LINK", nil, nil, ns.WEBSITE) end
end

function ns:OpenOptions()
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end

function ns:CreateOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("Forever Quest Item Bar")

    local function Register(key, varType, name)
        return Settings.RegisterProxySetting(category, "FQIB_" .. key, varType, name, ns.defaults[key],
            function() return ns.db[key] end,
            function(value)
                -- Pin the current edges first, so the bar keeps its place
                -- when the corner it grows from switches.
                if key == "growLeft" then ns:SavePosition() end
                ns.db[key] = value
                ns:RequestRefresh()
            end)
    end

    local function Checkbox(key, name, tooltip)
        Settings.CreateCheckbox(category, Register(key, "boolean", name), tooltip)
    end

    local function Slider(key, name, tooltip, minValue, maxValue, step, format)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
        Settings.CreateSlider(category, Register(key, "number", name), options, tooltip)
    end

    Checkbox("locked", "Lock bar",
        "Unlocked, the bar shows a blue handle you can drag, even when it has no items. Lock it to click the buttons.")
    Checkbox("usableOnly", "Only usable items",
        "Show only quest items you can click: items with a Use: effect and items that start a quest. " ..
        "Turn off to also show quest items that are only collected, such as pelts and trophies.")
    Checkbox("showHotkeys", "Show keybinds",
        "Show each button's key binding. Bind them under Key Bindings > AddOns > Forever Quest Item Bar.")
    Checkbox("showTooltips", "Show tooltips", "Show the item tooltip when you mouse over a button.")

    Checkbox("growLeft", "Grow to the left",
        "Keep the bar's right edge in place and add buttons to the left, for a bar placed on the right side of the screen.")

    Slider("buttonsPerRow", "Buttons per row", "Wrap onto a new row after this many buttons.",
        1, ns.MAX_BUTTONS, 1, function(v) return tostring(v) end)
    Slider("scale", "Scale", "Size of the bar.",
        0.5, 2.0, 0.05, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    Slider("spacing", "Button spacing", "Gap between buttons.",
        0, 20, 1, function(v) return tostring(v) end)

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Version " .. ns.VERSION))
    if ns.WEBSITE then
        layout:AddInitializer(CreateSettingsButtonInitializer("Help and bug reports", "GitHub link",
            function() ns:ShowSupportLink() end,
            "Show the link to the addon's GitHub page, where you can report a problem or ask a question.", true))
    end

    Settings.RegisterAddOnCategory(category)
end

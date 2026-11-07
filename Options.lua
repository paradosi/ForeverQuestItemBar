---- Options — the Settings panel (Esc > Options > AddOns) ----------------------
--
-- Blizzard's vertical-layout Settings API, with proxy settings: each control
-- reads and writes ns.db directly, and every write goes through
-- ns:RequestRefresh(), which applies it immediately out of combat and after
-- combat otherwise. Setting variables are prefixed FQIB_ because the Settings
-- registry is shared by every addon.

local _, ns = ...

local category

function ns:OpenOptions()
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end

function ns:CreateOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    category = Settings.RegisterVerticalLayoutCategory("Forever Quest Item Bar")

    local function Register(key, varType, name)
        return Settings.RegisterProxySetting(category, "FQIB_" .. key, varType, name, ns.defaults[key],
            function() return ns.db[key] end,
            function(value)
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

    Slider("buttonsPerRow", "Buttons per row", "Wrap onto a new row after this many buttons.",
        1, ns.MAX_BUTTONS, 1, function(v) return tostring(v) end)
    Slider("scale", "Scale", "Size of the bar.",
        0.5, 2.0, 0.05, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    Slider("spacing", "Button spacing", "Gap between buttons.",
        0, 20, 1, function(v) return tostring(v) end)

    Settings.RegisterAddOnCategory(category)
end

---- MinimapButton — one round button on the minimap's edge
--
-- Shared byte-identical across the Forever addons (ForeverAlts is the source):
-- change it there and copy it to the others. No dependencies, no library: it is
-- drawn like LibDBIcon's (the same textures and geometry, as FloLib does) so it
-- sits with other addons' buttons. Every addon has one, with a setting to hide
-- it (jim, 2026-11-27: "standard on all").
--
--   local button = ns.MinimapButton({
--       name    = "MyAddonMinimapButton",   -- global frame name
--       icon    = "Interface\\AddOns\\MyAddon\\media\\textures\\logo_64",
--       title   = "My Addon",               -- first tooltip line
--       lines   = { "Left-click: ...", "Right-click: ..." },
--       db      = savedTable,               -- holds .minimap (shown) and .minimapAngle
--       onClick = function(mouseButton) end,
--   })
--   button:Update()   -- after db.minimap changes: shows or hides, and places it
--
-- db.minimap == false hides it (nil counts as shown); db.minimapAngle is degrees
-- around the edge, 200 by default, and is saved as the button is dragged.

local _, ns = ...

function ns.MinimapButton(opts)
    local db = opts.db
    local button = CreateFrame("Button", opts.name, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetSize(31, 31)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477)  -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430)  -- Interface\Minimap\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467)  -- Interface\Minimap\UI-Minimap-Background
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(opts.icon)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    local function Place()
        local angle = math.rad(db.minimapAngle or 200)
        local x, y = math.cos(angle), math.sin(angle)
        local w = Minimap:GetWidth() / 2 + 5
        local h = Minimap:GetHeight() / 2 + 5
        -- GetMinimapShape is not Blizzard's: minimap addons (FarmMode Forever's
        -- square shape among them) define it. A square map: ride the box's edge.
        local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
        if shape ~= "ROUND" then
            local d = math.max(math.abs(x), math.abs(y))
            x, y = x / d, y / d
        end
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
    end

    local function OnUpdate()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        db.minimapAngle = math.floor(math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360 + 0.5)
        Place()
    end

    function button:Update()
        if db.minimap == false then
            self:Hide()
        else
            Place()
            self:Show()
        end
    end

    button:SetScript("OnClick", function(_, mouseButton) opts.onClick(mouseButton) end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(opts.title, 0.89, 0.71, 0.39)  -- wowdb.dev gold
        for _, line in ipairs(opts.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1) end
        GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:Update()
    return button
end

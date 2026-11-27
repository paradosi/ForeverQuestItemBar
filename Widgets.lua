---- Widgets — wowdb.dev-styled controls for a settings panel, built on Theme.lua
--
-- Taken from FarmMode Forever's Options.lua and made reusable: every builder
-- takes the frame it draws into (`host`) first, and anchors below `anchor`.
-- Meant to be copied as-is into the next addon that moves to this look, along
-- with Theme.lua and media/fonts.
--
--   W.Section(host, anchor, yOff, label, width)        gold capitals over a hairline
--   W.Slider(host, anchor, yOff, label, min, max, step, wheelStep, suffix, width)
--   W.Check(host, anchor, yOff, label, width)
--   W.Button(host, label, width)                        bordered; :SetSelected(on)
--   W.Segment(host, anchor, yOff, choices, onSelect, width)  one-of-n buttons; :Set(value)
--   W.Note(host, anchor, yOff, text, width)             muted explanation, wraps at width
--   W.CopyDialog(title, text)                           a link shown selected for Ctrl+C
--   W.Panel(opts)                                       a settings page: header + scrolling body
--
-- Sliders and checks call `.onChange(value)` when the player changes them and
-- take `:SetValue(v)` / `:SetChecked(v)` from code without calling it back.
-- Widths are fixed rather than measured: a custom font may not be loaded yet
-- when the panel is built, and then strings measure ~0 wide.

local addonName, ns = ...
local T = ns.T
local C = T.C

local W = {}
ns.W = W

W.COL_W = 260

local function Upper(s) return s:upper() end

function W.Section(host, anchor, yOff, label, width)
    local text = T.Text(host, T.display, 11, C.accent)
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    text:SetText(Upper(label))
    local line = T.Line(host, C.divider)
    line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -5)
    line:SetWidth(width or W.COL_W)
    return line
end

-- LABEL on the left, the value (editable, mono) on the right, and a 3 px gold
-- track below that fills up to the thumb. The mouse wheel steps it.
function W.Slider(host, anchor, yOff, label, minVal, maxVal, step, wheelStep, suffix, width)
    width = width or W.COL_W
    local row = CreateFrame("Frame", nil, host)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    row:SetSize(width, 38)

    local name = T.Text(row, T.display, 11, C.secondary)
    name:SetPoint("TOPLEFT", 0, 0)
    name:SetText(Upper(label))

    local unit = T.Text(row, T.mono, 11, C.muted, "LEFT")
    unit:SetPoint("TOPRIGHT", 0, -1)
    unit:SetWidth(suffix and 18 or 0.01)
    unit:SetText(suffix or "")

    local eb = CreateFrame("EditBox", nil, row)
    eb:SetPoint("RIGHT", unit, "LEFT", -2, 0)
    eb:SetSize(48, 16)
    eb:SetFont(T.mono, 11, "")
    eb:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    eb:SetJustifyH("RIGHT")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(0, 3, 0, 0)
    local ebBg = eb:CreateTexture(nil, "BACKGROUND")
    ebBg:SetAllPoints()
    T.Fill(ebBg, C.raised)
    ebBg:Hide()     -- only while typing

    local s = CreateFrame("Slider", nil, row)
    s:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    s:SetSize(width, 14)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    T.Fill(track, C.track)
    track:SetHeight(3)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = s:GetThumbTexture()
    thumb:SetVertexColor(C.accentHi[1], C.accentHi[2], C.accentHi[3], 1)
    thumb:SetSize(4, 12)

    local fill = s:CreateTexture(nil, "ARTWORK")
    T.Fill(fill, C.accent)
    fill:SetHeight(3)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")     -- follows the thumb by itself

    local function Round(v) return math.floor(v / step + 0.5) * step end
    local function Show(v)
        if not eb:HasFocus() then eb:SetText(Round(v)) end
    end

    local quiet = false -- SetValue from code: show it, don't write it back
    s:SetScript("OnValueChanged", function(_, v)
        v = Round(v)
        Show(v)
        if not quiet and row.onChange then row.onChange(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetValue() + delta * (wheelStep or step)
        self:SetValue(math.max(minVal, math.min(maxVal, v)))
    end)
    s:SetScript("OnEnter", function()
        thumb:SetVertexColor(1, 0.95, 0.82, 1)
        name:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    end)
    s:SetScript("OnLeave", function()
        thumb:SetVertexColor(C.accentHi[1], C.accentHi[2], C.accentHi[3], 1)
        name:SetTextColor(C.secondary[1], C.secondary[2], C.secondary[3])
    end)

    eb:SetScript("OnEditFocusGained", function(self)
        ebBg:Show()
        self:HighlightText()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        ebBg:Hide()
        self:SetText(Round(s:GetValue()))
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then s:SetValue(Round(math.max(minVal, math.min(maxVal, v)))) end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)

    function row:SetEnabledLook(on)
        self:SetAlpha(on and 1 or 0.4)
    end

    function row:SetValue(v)
        quiet = true
        s:SetValue(v)
        eb:SetText(Round(v))
        quiet = false
    end
    return row
end

-- A hairline box that fills gold when on, label beside it. The whole row is
-- clickable.
function W.Check(host, anchor, yOff, label, width)
    local btn = CreateFrame("Button", nil, host)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    btn:SetSize(width or W.COL_W, 18)

    local box = CreateFrame("Frame", nil, btn)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    T.Fill(boxBg, C.raised)
    T.Border(box)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    T.Fill(mark, C.accent)

    local text = T.Text(btn, T.display, 12, C.secondary)
    text:SetPoint("LEFT", box, "RIGHT", 9, 0)
    text:SetText(label)
    btn.label = text

    function btn:SetChecked(v)
        self.checked = v and true or false
        mark:SetShown(self.checked)
    end
    btn:SetChecked(false)
    btn:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.onChange then self.onChange(self.checked) end
    end)
    btn:SetScript("OnEnter", function() text:SetTextColor(C.primary[1], C.primary[2], C.primary[3]) end)
    btn:SetScript("OnLeave", function() text:SetTextColor(C.secondary[1], C.secondary[2], C.secondary[3]) end)
    function btn:SetEnabledLook(on)
        self:SetAlpha(on and 1 or 0.4)
    end
    return btn
end

-- A bordered text button; `selected` paints it gold. Set OnClick yourself.
function W.Button(host, label, width)
    local b = CreateFrame("Button", nil, host)
    b:SetSize(width, 24)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Border(b)
    local text = T.Text(b, T.display, 11, C.muted, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(Upper(label))
    b.label = text

    local function Paint(hover)
        if b.selected then
            T.Fill(bg, C.chip)
            text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        else
            T.Fill(bg, hover and C.raised or { 0, 0, 0, 0 })
            local c = hover and C.primary or C.muted
            text:SetTextColor(c[1], c[2], c[3])
        end
    end
    function b:SetSelected(on)
        self.selected = on
        Paint(self:IsMouseOver())
    end
    function b:SetLabel(s) text:SetText(Upper(s)) end
    b:SetScript("OnEnter", function() Paint(true) end)
    b:SetScript("OnLeave", function() Paint(false) end)
    T.HoverGlow(b)
    Paint(false)
    return b
end

-- A row of buttons, one of them chosen: choices = { {value, label}, ... }
function W.Segment(host, anchor, yOff, choices, onSelect, width)
    width = width or W.COL_W
    local seg = { buttons = {} }
    local w = (width - 8 * (#choices - 1)) / #choices
    for i, c in ipairs(choices) do
        local b = W.Button(host, c[2], w)
        if i == 1 then
            b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        else
            b:SetPoint("LEFT", seg.buttons[i - 1], "RIGHT", 8, 0)
        end
        b:SetScript("OnClick", function()
            seg:Set(c[1])
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            onSelect(c[1])
        end)
        b.value = c[1]
        seg.buttons[i] = b
    end
    function seg:Set(value)
        for _, b in ipairs(self.buttons) do b:SetSelected(b.value == value) end
    end
    seg.first = seg.buttons[1]
    return seg
end

-- Wraps within its column (width, default COL_W) rather than running into the
-- next one: T.Text turns wrapping off, which suits labels but not sentences.
function W.Note(host, anchor, yOff, text, width)
    local fs = T.Text(host, T.mono, 10, C.muted)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    fs:SetWidth(width or W.COL_W)
    fs:SetWordWrap(true)
    fs:SetText(text)
    return fs
end

---- Copy dialog ----------------------------------------------------------------
--
-- Addons can't open a browser, so a link is shown selected in an edit box for
-- Ctrl+C. Typing in the box puts the link back; Enter or Escape closes it.

local dialog

function W.CopyDialog(title, text)
    if not dialog then
        dialog = CreateFrame("Frame", addonName .. "CopyDialog", UIParent)
        dialog:SetSize(420, 112)
        dialog:SetPoint("CENTER", 0, 120)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetToplevel(true)
        dialog:EnableMouse(true)
        local bg = dialog:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        T.Fill(bg, C.bg)
        T.Border(dialog)

        dialog.title = T.Text(dialog, T.display, 13, C.primary)
        dialog.title:SetPoint("TOPLEFT", 16, -14)
        T.GoldLine(dialog, -36)

        local box = CreateFrame("EditBox", nil, dialog)
        box:SetPoint("TOPLEFT", 16, -48)
        box:SetPoint("TOPRIGHT", -16, -48)
        box:SetHeight(24)
        box:SetFont(T.mono, 11, "")
        box:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
        box:SetTextInsets(8, 8, 0, 0)
        box:SetAutoFocus(false)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        T.Fill(boxBg, C.deep)
        T.Border(box)
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput and self:GetText() ~= dialog.text then
                self:SetText(dialog.text)
                self:HighlightText()
            end
        end)
        box:SetScript("OnEnterPressed", function() dialog:Hide() end)
        box:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.box = box

        local hint = T.Text(dialog, T.mono, 10, C.muted)
        hint:SetPoint("BOTTOMLEFT", 16, 14)
        hint:SetText("Ctrl+C to copy  ·  Esc to close")

        local close = W.Button(dialog, "Close", 80)
        close:SetPoint("BOTTOMRIGHT", -16, 10)
        close:SetScript("OnClick", function() dialog:Hide() end)

        -- Escape closes it like any panel, even when the box has no focus
        tinsert(UISpecialFrames, addonName .. "CopyDialog")
    end
    dialog.text = text
    dialog.title:SetText(Upper(title))
    dialog.box:SetText(text)
    dialog:Show()
    dialog.box:SetFocus()
    dialog.box:HighlightText()
end

---- Settings page ---------------------------------------------------------------
--
-- A page for Blizzard's options window (Settings.RegisterCanvasLayoutCategory),
-- as FarmMode Forever's: navy background, a fixed header (logo, title, version
-- chip, a muted line, the gold line) and a body that scrolls with the mouse
-- wheel, with a thin gold bar on the right showing where you are. The window
-- leaves an addon about 650 x 600.
--
--   opts = { name = global frame name, title, sub, logo = texture path,
--            version, bodyWidth = the content's width }
--   returns panel, host (build the controls in host), and fit(bottomWidget),
--   which sizes the scroll area to end at that widget; call it from OnShow,
--   when the fonts are loaded and the widgets can be measured.

function W.Panel(opts)
    local panel = CreateFrame("Frame", opts.name, UIParent)
    panel.name = opts.title
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, C.bg)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 18, -16)
    logo:SetTexture(opts.logo)

    local title = T.Text(panel, T.display, 20, C.primary)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText(Upper(opts.title))

    local version = T.Chip(panel)
    version:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -24)
    version:SetText("V" .. (opts.version or "?"))

    local sub = T.Text(panel, T.mono, 11, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText(opts.sub or "")

    T.GoldLine(panel, -70)

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 0, -72)
    scroll:SetPoint("BOTTOMRIGHT", -12, 4)
    local host = CreateFrame("Frame", nil, scroll)
    local bodyWidth = opts.bodyWidth or (W.COL_W * 2 + 80)
    host:SetSize(bodyWidth, 600)
    scroll:SetScrollChild(host)

    local barTrack = panel:CreateTexture(nil, "ARTWORK")
    T.Fill(barTrack, C.divider)
    barTrack:SetWidth(2)
    barTrack:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -80)
    barTrack:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 10)
    local barThumb = panel:CreateTexture(nil, "OVERLAY")
    T.Fill(barThumb, C.accent)
    barThumb:SetWidth(2)

    local function UpdateBar()
        local range = scroll:GetVerticalScrollRange()
        local shown = range > 1
        barTrack:SetShown(shown)
        barThumb:SetShown(shown)
        if not shown then return end
        local trackH = barTrack:GetHeight()
        local view = scroll:GetHeight()
        local thumbH = math.max(24, trackH * view / (view + range))
        barThumb:SetHeight(thumbH)
        local y = (trackH - thumbH) * scroll:GetVerticalScroll() / range
        barThumb:ClearAllPoints()
        barThumb:SetPoint("TOP", barTrack, "TOP", 0, -y)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
        UpdateBar()
    end)
    scroll:SetScript("OnScrollRangeChanged", UpdateBar)
    scroll:SetScript("OnSizeChanged", function(_, w)
        host:SetWidth(math.max(w, bodyWidth))
        UpdateBar()
    end)

    local function fit(bottom)
        local top, low = host:GetTop(), bottom and bottom:GetBottom()
        if top and low then host:SetHeight(top - low + 20) end
        UpdateBar()
    end
    return panel, host, fit
end

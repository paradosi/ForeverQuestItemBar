---- Theme — wowdb.dev's look, copied unchanged from FarmMode Forever's Theme.lua
---- (itself trimmed from Forever Alts'): navy surfaces, hairline borders, a gold
---- accent, Oswald for labels and JetBrains Mono for numbers (both SIL OFL,
---- media/fonts). The controls built from it are in Widgets.lua.

local addonName, ns = ...

local FONTS = "Interface\\AddOns\\" .. addonName .. "\\media\\fonts\\"

local T = {
    display      = FONTS .. "Oswald-Regular.ttf",
    displayLight = FONTS .. "Oswald-Light.ttf",
    mono         = FONTS .. "JetBrainsMono-Regular.ttf",
    monoMedium   = FONTS .. "JetBrainsMono-Medium.ttf",
}
ns.T = T

-- wowdb's tokens (apps/web/app/globals.css)
local C = {
    bg        = { 0.086, 0.106, 0.161, 0.97 },  -- --bg #161b29
    deep      = { 0.063, 0.075, 0.114, 1 },     -- --bg-deep #10131d
    raised    = { 1, 1, 1, 0.035 },             -- a row under the cursor, a field
    border    = { 1, 1, 1, 0.10 },              -- --border
    divider   = { 1, 1, 1, 0.06 },              -- --divider
    primary   = { 0.961, 0.969, 0.988 },        -- --text-primary #f5f7fc
    secondary = { 0.761, 0.784, 0.855 },        -- --text-secondary #c2c8da
    muted     = { 0.588, 0.616, 0.702 },        -- --text-muted #969db3
    accent    = { 0.890, 0.714, 0.392 },        -- --accent #e3b664
    accentHi  = { 0.953, 0.835, 0.584 },        -- --accent-hi #f3d595
    chip      = { 0.890, 0.714, 0.392, 0.16 },  -- --chip-accent
    track     = { 0.890, 0.714, 0.392, 0.18 },  -- an empty bar: faint gold
}
T.C = C
T.PAD = 14

function T.Fill(tex, c) tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end

function T.Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function T.Line(parent, c, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    T.Fill(t, c)
    t:SetHeight(1)
    return t
end

-- 1px inset border on all four sides (box-shadow: inset 0 0 0 1px var(--border))
function T.Border(frame, c)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        T.Fill(t, c or C.border)
        t:SetPoint(side[1]); t:SetPoint(side[2])
        if side[3] then t:SetWidth(1) else t:SetHeight(1) end
    end
end

-- --gold-line: transparent → gold → transparent, across the frame at y
function T.GoldLine(parent, y)
    local a, b = parent:CreateTexture(nil, "BORDER"), parent:CreateTexture(nil, "BORDER")
    for _, t in ipairs({ a, b }) do t:SetColorTexture(1, 1, 1, 1); t:SetHeight(1) end
    a:SetPoint("TOPLEFT", 0, y); a:SetPoint("TOPRIGHT", parent, "TOP", 0, y)
    b:SetPoint("TOPLEFT", parent, "TOP", 0, y); b:SetPoint("TOPRIGHT", 0, y)
    local r, g, bl = C.accentHi[1], C.accentHi[2], C.accentHi[3]
    a:SetGradient("HORIZONTAL", CreateColor(r, g, bl, 0), CreateColor(r, g, bl, 0.8))
    b:SetGradient("HORIZONTAL", CreateColor(r, g, bl, 0.8), CreateColor(r, g, bl, 0))
end

-- A gold chip: small uppercase label on a faint gold fill
function T.Chip(parent)
    local text = T.Text(parent, T.display, 9, C.accent)
    local bg = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(bg, C.chip)
    bg:SetPoint("TOPLEFT", text, "TOPLEFT", -7, 4)
    bg:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 7, -4)
    return text
end

-- wowdb's .glow: a line of light that runs around a box's border. Two comets of gold
-- (bright head, fading tail) chase each other round the edge, 1.25px thick, fading in and
-- out over 0.3s. Drawn as short segments placed along the perimeter each frame, only
-- while it shows. glow:SetActive(on); glow:SetTarget(frame) moves it onto another frame.
local GLOW_LAP, GLOW_FADE, GLOW_SEGS, GLOW_COMETS, GLOW_LEN = 4.4, 0.3, 10, 2, 0.16

-- style (optional): { thick = px, bright = true }. Bright mixes the head toward white, keeps
-- the tail lit longer and makes the comets longer.
function T.Glow(owner, parent, inset, style)
    local g = CreateFrame("Frame", nil, parent or owner)
    g:SetFrameLevel(owner:GetFrameLevel() + 6)
    g:SetAllPoints(owner)
    if type(inset) == "table" then  -- { x, y }: the ring sits that far inside the frame
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", owner, "TOPLEFT", inset[1], -inset[2])
        g:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset[1], inset[2])
    end
    g:Hide()
    g.tint = g:CreateTexture(nil, "BACKGROUND")
    g.tint:SetColorTexture(1, 1, 1, 0.02)  -- wowdb's #ffffff05 under the cursor
    g.tint:SetAllPoints()
    g.segs = {}
    local bright = style and style.bright
    local headColor = bright and { 1, 0.95, 0.82 } or C.accentHi  -- bright: accent-hi most of the way to white
    for i = 1, GLOW_COMETS * GLOW_SEGS do
        local t = g:CreateTexture(nil, "OVERLAY")
        local k = ((i - 1) % GLOW_SEGS) / GLOW_SEGS     -- 0 at the head, near 1 at the tail
        local r = headColor[1] + (C.accent[1] - headColor[1]) * k
        local gr = headColor[2] + (C.accent[2] - headColor[2]) * k
        local b = headColor[3] + (C.accent[3] - headColor[3]) * k
        t:SetColorTexture(r, gr, b, (1 - k) ^ (bright and 1.0 or 1.6))
        if bright then t:SetBlendMode("ADD") end
        g.segs[i] = t
    end
    g.t, g.alpha, g.on = 0, 0, false
    g.thick = style and style.thick or 1.25
    g.len = bright and 0.22 or GLOW_LEN

    -- One segment [s, s + len] of the perimeter (clockwise from the top left), clipped to its side
    local function Place(tex, s, len, w, h)
        local P = 2 * (w + h)
        s = s % P
        local th = g.thick
        tex:ClearAllPoints()
        if s < w then
            tex:SetPoint("TOPLEFT", g, "TOPLEFT", s, 0)
            tex:SetSize(math.max(0.01, math.min(len, w - s)), th)
        elseif s < w + h then
            local y = s - w
            tex:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, -y)
            tex:SetSize(th, math.max(0.01, math.min(len, h - y)))
        elseif s < 2 * w + h then
            local x = w - (s - w - h)               -- running right to left along the bottom
            local from = math.max(0, x - len)
            tex:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", from, 0)
            tex:SetSize(math.max(0.01, x - from), th)
        else
            local y = h - (s - 2 * w - h)           -- running up the left side
            local from = math.max(0, y - len)
            tex:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -from)
            tex:SetSize(th, math.max(0.01, y - from))
        end
    end

    g:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        local want = self.on and 1 or 0
        if self.alpha ~= want then
            local step = elapsed / GLOW_FADE
            self.alpha = want > self.alpha and math.min(want, self.alpha + step) or math.max(want, self.alpha - step)
            self:SetAlpha(self.alpha)
            if self.alpha == 0 then self:Hide(); return end
        end
        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then return end
        local P = 2 * (w + h)
        local len = P * self.len / GLOW_SEGS
        for c = 0, GLOW_COMETS - 1 do
            local head = ((self.t / GLOW_LAP) % 1) * P + c * P / GLOW_COMETS
            for i = 1, GLOW_SEGS do
                Place(self.segs[c * GLOW_SEGS + i], head - i * len, len, w, h)
            end
        end
    end)

    function g:SetActive(on)
        self.on = on and true or false
        if self.on then self:Show() end
    end
    function g:SetTarget(frame)
        self:ClearAllPoints()
        self:SetAllPoints(frame)
        self:SetFrameLevel(frame:GetFrameLevel() + 6)
    end
    return g
end

-- The glow on hover, made the first time the pointer arrives. Call after the frame's own
-- OnEnter/OnLeave are set: SetScript would replace the hooks. inset as for T.Glow.
function T.HoverGlow(frame, inset, style)
    frame.keepGlow = frame.keepGlow or false
    frame.glowInset = (type(frame.glowInset) == "table" and frame.glowInset) or inset or false
    frame:HookScript("OnEnter", function(self)
        self.hoverGlow = self.hoverGlow or T.Glow(self, nil, self.glowInset or nil, style)
        self.hoverGlow:SetActive(true)
    end)
    frame:HookScript("OnLeave", function(self)
        if self.keepGlow and self:keepGlow() then return end  -- e.g. the open tab keeps its glow
        if self.hoverGlow and not (self.HasFocus and self:HasFocus()) then self.hoverGlow:SetActive(false) end
    end)
end


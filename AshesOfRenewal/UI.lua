local _, AOR = ...
local C = AOR.colors

local UI = {}
AOR.UI = UI
UI.tabs = {}
UI.groupOrder = { "GUILD", "RAID", "OFFICERS" }
UI.navHeads = {}

local FONT      = "Fonts\\ARIALN.TTF"
local HEADFONT  = "Fonts\\FRIZQT__.TTF"
local WHITE     = "Interface\\Buttons\\WHITE8X8"
UI.FONT = FONT

-- Window geometry
local WIN_W, WIN_H = 1120, 720
local SIDEBAR_W, HEADER_H, FOOTER_H = 220, 56, 26
local NAV_TOP, NAV_ITEM_H, NAV_HEAD_H, NAV_GAP = 98, 34, 22, 12
local SIDEBAR_BG = { 0.040, 0.034, 0.034, 1 }

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
function UI:Skin(f, bg, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or C.panel))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

function UI:NewFrame(parent, bg, border, name)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    self:Skin(f, bg, border)
    return f
end

function UI:Text(parent, size, color, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size, "")
    fs:SetTextColor(unpack(color or C.text))
    fs:SetJustifyH("LEFT")
    return fs
end

function UI:Button(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    self:Skin(b, C.panelHi, C.border)
    b.text = self:Text(b, 12, C.text)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.ember)) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function UI:EditBox(parent, w, h, placeholder, maxBytes)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(w, h)
    e:SetAutoFocus(false)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(unpack(C.text))
    e:SetTextInsets(8, 8, 0, 0)
    if maxBytes then e:SetMaxBytes(maxBytes) end
    self:Skin(e, C.bg, C.border)
    if placeholder then
        e.ph = self:Text(e, 12, C.dim)
        e.ph:SetPoint("LEFT", 8, 0)
        e.ph:SetText(placeholder)
    end
    e:SetScript("OnTextChanged", function(s)
        if s.ph then s.ph:SetShown(s:GetText() == "") end
    end)
    e:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.ember)) end)
    e:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

function UI:Check(parent, label, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(110, 20)
    b.box = self:NewFrame(b, C.bg, C.border)
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT")
    b.tick = b.box:CreateTexture(nil, "OVERLAY")
    b.tick:SetColorTexture(unpack(C.ember))
    b.tick:SetPoint("TOPLEFT", 3, -3)
    b.tick:SetPoint("BOTTOMRIGHT", -3, 3)
    b.tick:Hide()
    b.label = self:Text(b, 12, C.text)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
    b.label:SetText(label)
    b.checked = false
    function b:SetChecked(v)
        self.checked = v and true or false
        self.tick:SetShown(self.checked)
    end
    b:SetScript("OnClick", function(s)
        s:SetChecked(not s.checked)
        if onChange then onChange(s.checked) end
    end)
    return b
end

function UI:Card(parent, title, w, h)
    local c = self:NewFrame(parent, C.panel, C.border)
    c:SetSize(w, h)
    local t = self:Text(c, 11, C.ember)
    t:SetPoint("TOPLEFT", 12, -10)
    t:SetText(string.upper(title))
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, -28)
    line:SetPoint("TOPRIGHT", -12, -28)
    return c
end

-- Small outlined label, optionally with a status dot. Used in the header.
function UI:Chip(parent, text, color, withDot)
    color = color or C.gold
    local c = self:NewFrame(parent, { 0, 0, 0, 0.25 }, { color[1], color[2], color[3], 0.55 })
    c:SetHeight(24)
    c.text = self:Text(c, 10, color)
    c.inset = withDot and 22 or 10
    if withDot then
        c.dot = c:CreateTexture(nil, "OVERLAY")
        c.dot:SetSize(6, 6)
        c.dot:SetPoint("LEFT", 10, 0)
        c.dot:SetColorTexture(unpack(color))
    end
    c.text:SetPoint("LEFT", c.inset, 0)
    function c:SetLabel(s, col)
        self.text:SetText(s)
        if col then
            self.text:SetTextColor(unpack(col))
            if self.dot then self.dot:SetColorTexture(unpack(col)) end
            self:SetBackdropBorderColor(col[1], col[2], col[3], 0.55)
        end
        self:SetWidth(self.text:GetStringWidth() + self.inset + 10)
    end
    c:SetLabel(text)
    return c
end

-- A fixed pool of rows with a slim ember scrollbar.
function UI:VirtualList(parent, rowH, rowCount, makeRow, gap)
    gap = gap or 0
    local L = CreateFrame("Frame", nil, parent)
    L.rows, L.offset, L.data = {}, 0, {}

    local sb = CreateFrame("Slider", nil, L)
    sb:SetOrientation("VERTICAL")
    sb:SetWidth(6)
    sb:SetPoint("TOPRIGHT")
    sb:SetPoint("BOTTOMRIGHT")
    local track = sb:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.05)
    sb:SetThumbTexture(WHITE)
    local thumb = sb:GetThumbTexture()
    thumb:SetSize(6, 36)
    thumb:SetVertexColor(unpack(C.ember))
    sb:SetMinMaxValues(0, 1)
    sb:SetValueStep(1)
    sb:SetObeyStepOnDrag(true)
    sb:SetValue(0)
    sb:Hide()
    sb:SetScript("OnValueChanged", function(_, v)
        if L.settingSlider then return end
        L.offset = math.floor(v + 0.5)
        L:Update()
    end)

    function L:Wheel(delta)
        local maxOff = math.max(0, #self.data - rowCount)
        local new = math.min(maxOff, math.max(0, self.offset - delta * 2))
        if new ~= self.offset then
            self.offset = new
            self.settingSlider = true
            sb:SetValue(new)
            self.settingSlider = false
            self:Update()
        end
    end
    L:EnableMouseWheel(true)
    L:SetScript("OnMouseWheel", function(_, d) L:Wheel(d) end)

    for i = 1, rowCount do
        local r = makeRow(L, i)
        local y = -(i - 1) * (rowH + gap)
        r:SetPoint("TOPLEFT", 0, y)
        r:SetPoint("TOPRIGHT", -12, y)
        r:SetHeight(rowH)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) L:Wheel(d) end)
        L.rows[i] = r
    end

    function L:SetData(data)
        self.data = data
        local maxOff = math.max(0, #data - rowCount)
        if self.offset > maxOff then self.offset = maxOff end
        self.settingSlider = true
        sb:SetMinMaxValues(0, math.max(maxOff, 1))
        sb:SetValue(self.offset)
        self.settingSlider = false
        sb:SetShown(maxOff > 0)
        self:Update()
    end

    function L:Update()
        for i, r in ipairs(self.rows) do
            local d = self.data[self.offset + i]
            if d then
                r.data = d
                r:Show()
                if self.onUpdateRow then
                    local ok, err = pcall(self.onUpdateRow, r, d, self.offset + i)
                    if not ok then geterrorhandler()(err) end
                end
            else
                r.data = nil
                r:Hide()
            end
        end
    end

    return L
end

function UI:CopyBox(label, text)
    if not self.copy then
        local f = self:NewFrame(UIParent, C.bg, C.ember)
        f:SetSize(380, 98)
        f:SetPoint("CENTER", 0, 140)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f.title = self:Text(f, 12, C.gold)
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.edit = self:EditBox(f, 356, 26)
        f.edit:SetPoint("TOPLEFT", 12, -34)
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        local hint = self:Text(f, 11, C.dim)
        hint:SetPoint("TOPLEFT", 12, -70)
        hint:SetText("Press Ctrl+C to copy, then Esc to close.")
        self.copy = f
    end
    self.copy.title:SetText(label)
    self.copy.edit:SetText(text)
    self.copy:Show()
    self.copy.edit:SetFocus()
    self.copy.edit:HighlightText()
end

------------------------------------------------------------------------
-- Tabs
--
-- UI:RegisterTab(key, label, init, onShow, opts)
--   opts.group    "GUILD" | "RAID" | "OFFICERS" (sidebar section; default GUILD)
--   opts.hint     small right-aligned label in the sidebar ("Roster", "+1", ...)
--   opts.officer  true = only shown to members who can post (AOR:CanPost)
--   opts.title    breadcrumb text if different from label
------------------------------------------------------------------------
function UI:RegisterTab(key, label, init, onShow, opts)
    opts = opts or {}
    local group = opts.group or "GUILD"
    local known
    for _, g in ipairs(self.groupOrder) do if g == group then known = true end end
    if not known then table.insert(self.groupOrder, group) end
    table.insert(self.tabs, {
        key = key, label = label, init = init, onShow = onShow,
        group = group, hint = opts.hint, officer = opts.officer, title = opts.title or label,
    })
end

function UI:Tab(key)
    for _, t in ipairs(self.tabs) do
        if t.key == key then return t end
    end
end

function UI:TabVisible(t)
    return not t.officer or AOR:CanPost()
end

function UI:StyleNav(t, on)
    local b = t.btn
    if on then
        b:SetBackdropColor(unpack(C.panelHi))
        b:SetBackdropBorderColor(C.ember[1], C.ember[2], C.ember[3], 0.6)
        b.stripe:Show()
        b.text:SetTextColor(unpack(C.gold))
    else
        b:SetBackdropColor(0, 0, 0, 0)
        b:SetBackdropBorderColor(0, 0, 0, 0)
        b.stripe:Hide()
        b.text:SetTextColor(unpack(C.dim))
    end
end

local function MakeNavButton(f, t)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetSize(SIDEBAR_W - 24, NAV_ITEM_H)
    UI:Skin(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    b.stripe = b:CreateTexture(nil, "OVERLAY")
    b.stripe:SetColorTexture(unpack(C.ember))
    b.stripe:SetWidth(2)
    b.stripe:SetPoint("TOPLEFT", 1, -1)
    b.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    b.stripe:Hide()
    b.text = UI:Text(b, 13, C.dim)
    b.text:SetPoint("LEFT", 14, 0)
    b.text:SetText(t.label)
    b.hint = UI:Text(b, 10, C.dim)
    b.hint:SetPoint("RIGHT", -10, 0)
    b.hint:SetJustifyH("RIGHT")
    b.hint:SetText(t.hint or "")
    b:SetScript("OnClick", function() UI:Select(t.key) end)
    b:SetScript("OnEnter", function(s)
        if UI.current ~= t.key then s.text:SetTextColor(unpack(C.text)) end
    end)
    b:SetScript("OnLeave", function(s)
        if UI.current ~= t.key then s.text:SetTextColor(unpack(C.dim)) end
    end)
    return b
end

-- Positions the sidebar: group headings, then the tabs the player may see.
function UI:LayoutNav()
    if not self.frame then return end
    for _, h in pairs(self.navHeads) do h:Hide() end
    for _, t in ipairs(self.tabs) do t.btn:Hide() end
    local y = -NAV_TOP
    for _, group in ipairs(self.groupOrder) do
        local items = {}
        for _, t in ipairs(self.tabs) do
            if t.group == group and self:TabVisible(t) then items[#items + 1] = t end
        end
        if #items > 0 then
            local h = self.navHeads[group]
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, y - 4)
            h:Show()
            y = y - NAV_HEAD_H
            for _, t in ipairs(items) do
                t.btn:ClearAllPoints()
                t.btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 12, y)
                t.btn:Show()
                y = y - NAV_ITEM_H - 2
            end
            y = y - NAV_GAP
        end
    end
end

local function SyncState()
    if not AOR.lastSync then return "WAITING FOR SYNC", C.dim end
    local m = math.floor((time() - AOR.lastSync) / 60)
    if m < 1 then return "SYNCED JUST NOW", C.good end
    if m < 60 then return ("SYNCED %dM AGO"):format(m), C.good end
    return ("SYNCED %dH AGO"):format(math.floor(m / 60)), C.ember
end

-- Breadcrumb, status chips, sidebar presence and footer text.
function UI:UpdateChrome()
    if not self.frame then return end
    local t = self:Tab(self.current)
    if t then
        self.crumb:SetText(("GUILD HALL   /   |cff%s%s|r"):format(AOR:Hex(C.gold), string.upper(t.title)))
    end
    self.syncChip:SetLabel(SyncState())
    local R = AOR.Roster
    local online = R and R.onlineCount or 0
    self.presence:SetText(("%d online"):format(online))
    self.officer:SetText(("OFFICER: %s     INTERFACE %s"):format(AOR:CanPost() and "YES" or "NO", self.interface))
end

function UI:Select(key)
    local sel = self:Tab(key)
    if not sel or not self:TabVisible(sel) then
        sel = self.tabs[1]
        key = sel.key
    end
    self.current = key
    for _, t in ipairs(self.tabs) do
        local on = (t.key == key)
        t.page:SetShown(on)
        self:StyleNav(t, on)
        if on and t.onShow then t.onShow(t.page) end
    end
    self:UpdateChrome()
end

local queued
function UI:Refresh()
    if queued or not (self.frame and self.frame:IsShown()) then return end
    queued = true
    C_Timer.After(0.1, function()
        queued = false
        if self.frame:IsShown() then
            self:LayoutNav()
            local t = self:Tab(self.current)
            if t and not self:TabVisible(t) then
                self:Select(self.tabs[1].key)
            elseif t and t.onShow then
                t.onShow(t.page)
            end
            self:UpdateChrome()
        end
    end)
end

------------------------------------------------------------------------
-- Main window
------------------------------------------------------------------------
function UI:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "AshesOfRenewalFrame", UIParent, "BackdropTemplate")
    self.frame = f
    self.interface = select(4, GetBuildInfo())
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScale(math.min(1, (UIParent:GetHeight() - 40) / WIN_H))
    self:Skin(f, C.bg, C.border)
    tinsert(UISpecialFrames, "AshesOfRenewalFrame")

    -- Sidebar backdrop + divider
    local side = f:CreateTexture(nil, "BACKGROUND")
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDEBAR_W)
    side:SetColorTexture(unpack(SIDEBAR_BG))
    local sideLine = f:CreateTexture(nil, "ARTWORK")
    sideLine:SetColorTexture(unpack(C.border))
    sideLine:SetWidth(1)
    sideLine:SetPoint("TOPLEFT", SIDEBAR_W + 1, -1)
    sideLine:SetPoint("BOTTOMLEFT", SIDEBAR_W + 1, 1)

    -- Rising-ember glow along the bottom of the main area
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetPoint("BOTTOMLEFT", SIDEBAR_W + 2, 1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetHeight(180)
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(1, 0.40, 0.10, 0.09), CreateColor(1, 0.40, 0.10, 0))

    -- Ember -> gold accent bar across the top of the main area
    local bar = f:CreateTexture(nil, "OVERLAY")
    bar:SetHeight(3)
    bar:SetPoint("TOPLEFT", SIDEBAR_W + 2, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetColorTexture(1, 1, 1, 1)
    bar:SetGradient("HORIZONTAL", CreateColor(unpack(C.ember)), CreateColor(unpack(C.gold)))

    -- Brand block
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", 16, -18)
    icon:SetTexture(AOR.config.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = self:Text(f, 15, C.gold, HEADFONT)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    title:SetWidth(140)
    title:SetWordWrap(true)
    title:SetText(string.upper(AOR.config.guildName))

    local sub = self:Text(f, 10, C.dim)
    sub:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -10)
    sub:SetText("GUILD HALL")

    local brandLine = f:CreateTexture(nil, "ARTWORK")
    brandLine:SetColorTexture(unpack(C.border))
    brandLine:SetHeight(1)
    brandLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -84)
    brandLine:SetWidth(SIDEBAR_W)

    -- Sidebar footer: presence + version
    local presenceLine = f:CreateTexture(nil, "ARTWORK")
    presenceLine:SetColorTexture(unpack(C.border))
    presenceLine:SetHeight(1)
    presenceLine:SetPoint("BOTTOMLEFT", 1, FOOTER_H + 1)
    presenceLine:SetWidth(SIDEBAR_W)
    local dot = f:CreateTexture(nil, "OVERLAY")
    dot:SetSize(6, 6)
    dot:SetPoint("BOTTOMLEFT", 18, 10)
    dot:SetColorTexture(unpack(C.good))
    self.presence = self:Text(f, 10, C.dim)
    self.presence:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    local ver = self:Text(f, 10, C.dim)
    ver:SetPoint("BOTTOMLEFT", SIDEBAR_W - 70, 8)
    ver:SetWidth(60)
    ver:SetJustifyH("RIGHT")
    ver:SetText("v" .. AOR.version)

    -- Header (main area): breadcrumb + chips + close
    self.crumb = self:Text(f, 11, C.dim)
    self.crumb:SetPoint("TOPLEFT", SIDEBAR_W + 22, -24)

    local close = self:Button(f, "X", 28, 28, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -16, -14)
    self.syncChip = self:Chip(f, "WAITING FOR SYNC", C.dim, true)
    self.syncChip:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local season = AOR.config.season
    if season and season ~= "" then
        local sc = self:Chip(f, string.upper(season), C.gold)
        sc:SetPoint("RIGHT", self.syncChip, "LEFT", -8, 0)
    end

    local headLine = f:CreateTexture(nil, "ARTWORK")
    headLine:SetColorTexture(unpack(C.border))
    headLine:SetHeight(1)
    headLine:SetPoint("TOPLEFT", SIDEBAR_W + 2, -HEADER_H)
    headLine:SetPoint("TOPRIGHT", -1, -HEADER_H)

    -- Footer (main area)
    local footLine = f:CreateTexture(nil, "ARTWORK")
    footLine:SetColorTexture(unpack(C.border))
    footLine:SetHeight(1)
    footLine:SetPoint("BOTTOMLEFT", SIDEBAR_W + 2, FOOTER_H)
    footLine:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)
    local fdot = f:CreateTexture(nil, "OVERLAY")
    fdot:SetSize(6, 6)
    fdot:SetPoint("BOTTOMLEFT", SIDEBAR_W + 22, 10)
    fdot:SetColorTexture(unpack(C.good))
    local chan = self:Text(f, 10, C.dim)
    chan:SetPoint("LEFT", fdot, "RIGHT", 6, 0)
    chan:SetText("GUILD CHANNEL - AOR V1")
    self.officer = self:Text(f, 10, C.dim)
    self.officer:SetPoint("BOTTOMRIGHT", -20, 8)
    self.officer:SetJustifyH("RIGHT")

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", SIDEBAR_W + 22, -(HEADER_H + 16))
    content:SetPoint("BOTTOMRIGHT", -20, FOOTER_H + 16)
    f.content = content

    -- Sidebar headings, nav buttons and pages
    for _, group in ipairs(self.groupOrder) do
        local h = self:Text(f, 10, C.dim)
        h:SetText(group)
        h:Hide()
        self.navHeads[group] = h
    end
    for _, t in ipairs(self.tabs) do
        t.btn = MakeNavButton(f, t)
        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints()
        page:Hide()
        t.page = page
        t.init(page)
    end

    C_Timer.NewTicker(30, function()
        if f:IsShown() then self:UpdateChrome() end
    end)

    f:SetScript("OnShow", function()
        if IsInGuild() then C_GuildInfo.GuildRoster() end
        self:LayoutNav()
        self:Select(self.current or self.tabs[1].key)
    end)
end

function UI:Open(key)
    self:Build()
    self.current = key or self.current
    if self.frame:IsShown() then self:Select(self.current) else self.frame:Show() end
end

function UI:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

AOR:OnInit(function()
    AOR:Subscribe("ROSTER", function()
        AOR.lastSync = time()
        UI:Refresh()
    end)
    AOR:Subscribe("BOARD", function() UI:Refresh() end)
end)

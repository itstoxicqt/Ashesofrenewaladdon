local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

------------------------------------------------------------------------
-- Cinder: raid preparation
--
-- Lists everyone in your raid or party and the consumable buffs they have
-- active (flask, food, rune ... see `cinder` in Core.lua), with time left.
-- Reads buffs the way the default raid frames do, so it works out of combat
-- on anyone in your group. If the game hides a unit's buffs (restricted in
-- combat on some clients) that row shows "?" instead of guessing.
------------------------------------------------------------------------
local V = { sort = "missing", onlyMissing = false, classMap = {}, rows = {}, visible = {}, heads = {}, boxes = {} }
AOR.Cinder = V

local HEAD = "Fonts\\FRIZQT__.TTF"
local ROW_H, ROWS = 24, 20
local LOW = 600          -- seconds left that counts as "running low"
local MAX_CATS = 4
local NAME_W, GRP_X, CELL_X = 150, 170, 214

------------------------------------------------------------------------
-- Reading buffs
------------------------------------------------------------------------
local function Secret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- calls fn(name, icon, expirationTime) for each buff; returns true if any buff was hidden by the game
local function ForEachBuff(unit, fn)
    local restricted = false
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 80 do
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not a then break end
            if Secret(a.name) then
                restricted = true
            elseif a.name then
                fn(a.name, a.icon, (not Secret(a.expirationTime)) and a.expirationTime or 0)
            end
        end
    elseif UnitBuff then
        for i = 1, 80 do
            local name, icon, _, _, _, expires = UnitBuff(unit, i)
            if not name then break end
            if Secret(name) then restricted = true else fn(name, icon, expires or 0) end
        end
    end
    return restricted
end

local function Units()
    local out = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
    elseif IsInGroup() then
        out[1] = "player"
        for i = 1, GetNumGroupMembers() - 1 do out[#out + 1] = "party" .. i end
    else
        out[1] = "player"
    end
    return out
end

local function Matches(lowerName, patterns)
    for _, p in ipairs(patterns or {}) do
        local ok, hit = pcall(string.find, lowerName, p:lower())
        if ok and hit then return true end
    end
    return false
end

-- Builds V.rows (sorted, filtered), V.visible (categories shown), V.summary
function V:Scan()
    local cats = AOR.config.cinder or {}
    local all, anyHas = {}, {}
    local now = GetTime()

    for _, unit in ipairs(Units()) do
        if UnitExists(unit) then
            local _, classFile = UnitClass(unit)
            local row = {
                unit = unit, name = AOR:UnitKey(unit) or unit, classFile = classFile,
                online = UnitIsConnected(unit) and true or false,
                cats = {}, found = {}, group = 0, restricted = false,
            }
            if IsInRaid() then
                local _, _, sg = GetRaidRosterInfo(tonumber(unit:match("%d+")) or 0)
                row.group = sg or 0
            end
            if row.online then
                row.restricted = ForEachBuff(unit, function(aname, icon, expires)
                    local lower = aname:lower()
                    local remain = (expires and expires > 0) and (expires - now) or nil
                    local matched = false
                    for _, cat in ipairs(cats) do
                        if Matches(lower, cat.patterns) then
                            matched = true
                            local cur = row.cats[cat.key]
                            if not cur or (remain or 1e9) > (cur.remain or 1e9) then
                                row.cats[cat.key] = { name = aname, icon = icon, remain = remain }
                            end
                            anyHas[cat.key] = true
                        end
                    end
                    if matched then row.found[#row.found + 1] = { name = aname, remain = remain } end
                end)
            end
            all[#all + 1] = row
        end
    end

    -- which categories to show (optional ones only once somebody has one)
    local visible = {}
    for _, cat in ipairs(cats) do
        if (not cat.optional or anyHas[cat.key]) and #visible < MAX_CATS then visible[#visible + 1] = cat end
    end

    local summary, checked = {}, 0
    for _, row in ipairs(all) do
        local n = 0
        if row.online and not row.restricted then
            checked = checked + 1
            for _, cat in ipairs(visible) do
                if not cat.optional and not row.cats[cat.key] then n = n + 1 end
            end
        end
        row.missing = n
    end
    for _, cat in ipairs(visible) do
        local have = 0
        for _, row in ipairs(all) do
            if row.online and not row.restricted and row.cats[cat.key] then have = have + 1 end
        end
        summary[cat.key] = { have = have, total = checked }
    end

    local rows = {}
    for _, row in ipairs(all) do
        if not self.onlyMissing or row.missing > 0 then rows[#rows + 1] = row end
    end
    local sort = self.sort
    table.sort(rows, function(a, b)
        if sort == "name" then return a.name:lower() < b.name:lower() end
        if sort == "group" then
            if a.group ~= b.group then return a.group < b.group end
            return a.name:lower() < b.name:lower()
        end
        if a.missing ~= b.missing then return a.missing > b.missing end
        if a.group ~= b.group then return a.group < b.group end
        return a.name:lower() < b.name:lower()
    end)

    self.rows, self.visible, self.summary, self.total = rows, visible, summary, #all
    self.everyone = all
    return rows
end

local function Remain(secs)
    if not secs then return "" end
    if secs >= 3600 then return ("%dh"):format(math.floor(secs / 3600)) end
    if secs >= 60 then return ("%dm"):format(math.floor(secs / 60)) end
    return ("%ds"):format(math.max(0, math.floor(secs)))
end

------------------------------------------------------------------------
-- Announce who is missing what
------------------------------------------------------------------------
function V:Announce()
    if not IsInGroup() then AOR:Print("You aren't in a group."); return end
    self:Scan()
    local channel = IsInRaid() and "RAID" or "PARTY"
    local sent = 0
    for _, cat in ipairs(self.visible) do
        local names = {}
        for _, r in ipairs(cat.optional and {} or self.everyone) do
            if r.online and not r.restricted and not r.cats[cat.key] then names[#names + 1] = r.name end
        end
        table.sort(names)
        if #names > 0 then
            local cur = ("Missing %s (%d): "):format(cat.label, #names)
            for i, n in ipairs(names) do
                local piece = (i > 1 and ", " or "") .. n
                if #cur + #piece > 230 then
                    SendChatMessage(cur, channel); sent = sent + 1
                    cur = ("Missing %s: %s"):format(cat.label, n)
                else
                    cur = cur .. piece
                end
            end
            SendChatMessage(cur, channel); sent = sent + 1
        end
    end
    if sent == 0 then AOR:Print("Everyone has their consumables.") end
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local function MakeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.12)
    r.hl:Hide()
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 14, 0)
    r.name:SetWidth(NAME_W)
    r.name:SetWordWrap(false)
    r.group = UI:Text(r, 12, C.dim)
    r.group:SetPoint("LEFT", GRP_X, 0)
    r.group:SetWidth(34)
    r.cells = {}
    for i = 1, MAX_CATS do
        local c = {}
        c.icon = r:CreateTexture(nil, "OVERLAY")
        c.icon:SetSize(16, 16)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.text = UI:Text(r, 12, C.text)
        c.text:SetWordWrap(false)
        r.cells[i] = c
    end

    r:SetScript("OnEnter", function(s)
        s.hl:Show()
        local d = s.data
        if not d then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AOR:ColorName(d.name, d.classFile), 1, 1, 1)
        if not d.online then
            GameTooltip:AddLine("Offline", 0.6, 0.55, 0.52)
        elseif d.restricted then
            GameTooltip:AddLine("The game is hiding this player's buffs right now.", 0.6, 0.55, 0.52, true)
        else
            if #d.found == 0 then
                GameTooltip:AddLine("No consumables active", 0.9, 0.3, 0.25)
            else
                for _, f in ipairs(d.found) do
                    GameTooltip:AddDoubleLine(f.name, Remain(f.remain), 0.93, 0.89, 0.86, 0.6, 0.55, 0.52)
                end
            end
            local miss = {}
            for _, cat in ipairs(V.visible) do
                if not cat.optional and not d.cats[cat.key] then miss[#miss + 1] = cat.label end
            end
            if #miss > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Missing: " .. table.concat(miss, ", "), 0.9, 0.3, 0.25)
            end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
    return r
end

local function UpdateRow(r, d, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    local cr, cg, cb = AOR:ClassColor(d.classFile)
    r.name:SetText(d.name)
    r.name:SetTextColor(cr, cg, cb, d.online and 1 or 0.5)
    r.group:SetText(d.group > 0 and d.group or "")

    local n = #V.visible
    local cellW = n > 0 and math.min(270, math.floor((846 - CELL_X - 8) / n)) or 200
    for i, c in ipairs(r.cells) do
        local cat = V.visible[i]
        if not cat then
            c.icon:Hide()
            c.text:SetText("")
        else
            local x = CELL_X + (i - 1) * cellW
            c.icon:ClearAllPoints()
            c.icon:SetPoint("LEFT", r, "LEFT", x, 0)
            c.text:ClearAllPoints()
            c.text:SetPoint("LEFT", r, "LEFT", x + 20, 0)
            c.text:SetWidth(cellW - 26)
            local have = d.cats[cat.key]
            if not d.online then
                c.icon:Hide()
                c.text:SetText("offline")
                c.text:SetTextColor(unpack(C.dim))
            elseif d.restricted then
                c.icon:Hide()
                c.text:SetText("?")
                c.text:SetTextColor(unpack(C.dim))
            elseif have then
                c.icon:SetTexture(have.icon)
                c.icon:Show()
                local low = have.remain and have.remain < LOW
                c.text:SetText(have.name .. (have.remain and ("  " .. Remain(have.remain)) or ""))
                c.text:SetTextColor(unpack(low and C.ember or C.good))
            else
                c.icon:Hide()
                if cat.optional then
                    c.text:SetText("-")
                    c.text:SetTextColor(unpack(C.dim))
                else
                    c.text:SetText("None")
                    c.text:SetTextColor(unpack(C.bad))
                end
            end
        end
    end
end

function V:Refresh()
    if not self.list then return end
    self:Scan()

    -- summary boxes
    for i, b in ipairs(self.boxes) do
        local cat = self.visible[i]
        if cat then
            local s = self.summary[cat.key]
            b.label:SetText(string.upper(cat.label))
            b.value:SetText(("%d / %d"):format(s.have, s.total))
            local col = C.bad
            if s.total == 0 then col = C.dim
            elseif s.have == s.total then col = C.good
            elseif s.have / s.total >= 0.8 then col = C.gold end
            b.value:SetTextColor(unpack(col))
            b:Show()
        else
            b:Hide()
        end
    end

    -- column headers follow the visible categories
    local n = #self.visible
    local cellW = n > 0 and math.min(270, math.floor((846 - CELL_X - 8) / n)) or 200
    for i, h in ipairs(self.heads) do
        local cat = self.visible[i]
        if cat then
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.table, "TOPLEFT", CELL_X + (i - 1) * cellW, -4)
            h:SetText(string.upper(cat.label))
            h:Show()
        else
            h:Hide()
        end
    end
    self.headName:SetTextColor(unpack(self.sort == "name" and C.ember or C.dim))
    self.headGroup:SetTextColor(unpack(self.sort == "group" and C.ember or C.dim))

    self.list:SetData(self.rows)
    self.empty:SetShown(#self.rows == 0)
    if self.total == 0 then
        self.empty:SetText("Nobody to check.")
    elseif self.onlyMissing then
        self.empty:SetText("Nobody is missing anything. Nice.")
    end

    local inGroup = IsInGroup()
    self.info:SetText(inGroup and ("%d in %s"):format(self.total, IsInRaid() and "raid" or "party") or "Not in a group - showing you only")
    self.announce:SetShown(AOR:CanPost() and inGroup)
end

local function Init(page)
    V.page = page

    for i = 1, MAX_CATS do
        local b = UI:NewFrame(page, C.panel, C.border)
        b:SetSize(150, 46)
        b:SetPoint("TOPLEFT", (i - 1) * 158, 0)
        b.label = UI:Text(b, 10, C.dim)
        b.label:SetPoint("TOPLEFT", 12, -8)
        b.value = UI:Text(b, 18, C.text, HEAD)
        b.value:SetPoint("TOPLEFT", 12, -22)
        b:Hide()
        V.boxes[i] = b
    end

    V.only = UI:Check(page, "Only show missing", function(v)
        V.onlyMissing = v
        V:Refresh()
    end)
    V.only:SetSize(150, 20)
    V.only:SetPoint("TOPLEFT", 0, -58)
    V.info = UI:Text(page, 11, C.dim)
    V.info:SetPoint("LEFT", V.only, "RIGHT", 16, 0)
    V.announce = UI:Button(page, "Announce Missing", 150, 24, function() V:Announce() end)
    V.announce:SetPoint("TOPRIGHT", 0, -56)

    local tbl = CreateFrame("Frame", nil, page)
    tbl:SetPoint("TOPLEFT", 0, -88)
    tbl:SetPoint("BOTTOMRIGHT", 0, 0)
    V.table = tbl

    local hn = CreateFrame("Button", nil, tbl)
    hn:SetPoint("TOPLEFT", 12, -2)
    hn:SetSize(100, 18)
    V.headName = UI:Text(hn, 10, C.dim)
    V.headName:SetPoint("LEFT", 2, 0)
    V.headName:SetText("PLAYER")
    hn:SetScript("OnClick", function() V.sort = (V.sort == "name") and "missing" or "name"; V:Refresh() end)
    local hg = CreateFrame("Button", nil, tbl)
    hg:SetPoint("TOPLEFT", GRP_X - 2, -2)
    hg:SetSize(40, 18)
    V.headGroup = UI:Text(hg, 10, C.dim)
    V.headGroup:SetPoint("LEFT", 2, 0)
    V.headGroup:SetText("GRP")
    hg:SetScript("OnClick", function() V.sort = (V.sort == "group") and "missing" or "group"; V:Refresh() end)
    for i = 1, MAX_CATS do
        V.heads[i] = UI:Text(tbl, 10, C.dim)
        V.heads[i]:Hide()
    end
    local line = tbl:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -20)
    line:SetPoint("TOPRIGHT", 0, -20)

    V.list = UI:VirtualList(tbl, ROW_H, ROWS, MakeRow, 0)
    V.list:SetPoint("TOPLEFT", 0, -24)
    V.list:SetPoint("BOTTOMRIGHT", 0, 0)
    V.list.onUpdateRow = UpdateRow

    V.empty = UI:Text(page, 13, C.dim)
    V.empty:SetPoint("CENTER", 0, -40)

    C_Timer.NewTicker(10, function()
        if page:IsVisible() then V:Refresh() end
    end)
end

UI:RegisterTab("cinder", "Cinder", Init, function() V:Refresh() end,
    { group = "RAID", hint = "Prep", title = "Cinder" })

-- buff changes in the group refresh the list while it is open
local pending
local function Dirty()
    if pending then return end
    pending = true
    C_Timer.After(0.6, function()
        pending = false
        if V.page and V.page:IsVisible() then V:Refresh() end
    end)
end

AOR:RegisterEvent("UNIT_AURA", function(_, unit)
    if V.page and V.page:IsVisible() and type(unit) == "string"
       and (unit == "player" or unit:find("^raid") or unit:find("^party")) then
        Dirty()
    end
end)
AOR:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    if V.page and V.page:IsVisible() then Dirty() end
end)

local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

local R = { list = {}, view = {}, sortKey = "rank", sortAsc = true, filter = "", onlineOnly = false, total = 0, onlineCount = 0 }
AOR.Roster = R

local ROWS, ROW_H = 24, 22

local columns = {
    { key = "name",  label = "Name",         x = 14,  w = 150 },
    { key = "level", label = "Lvl",          x = 170, w = 36  },
    { key = "class", label = "Class",        x = 210, w = 100 },
    { key = "rank",  label = "Rank",         x = 314, w = 110 },
    { key = "zone",  label = "Zone / Seen",  x = 428, w = 130 },
    { key = "note",  label = "Note",         x = 562, w = 270 },
}

local keyFns = {
    name  = function(e) return e.short:lower() end,
    level = function(e) return e.level end,
    class = function(e) return e.class end,
    rank  = function(e) return e.rankIndex end,
    zone  = function(e) return e.online and 0 or (e.last + 1) end,
}

local function LastSeen(y, m, d, h)
    y, m, d, h = y or 0, m or 0, d or 0, h or 0
    local secs = (((y * 12 + m) * 30 + d) * 24 + h)
    local text
    if y > 0 then text = y .. "y ago"
    elseif m > 0 then text = m .. "mo ago"
    elseif d > 0 then text = d .. "d ago"
    elseif h > 0 then text = h .. "h ago"
    else text = "< 1h ago" end
    return secs, text
end

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
function R:Collect()
    if not IsInGuild() then return end
    local list, rankMap, nameMap, online = {}, {}, {}, 0
    local total = GetNumGuildMembers()
    for i = 1, total do
        local name, rankName, rankIndex, level, classDisp, zone, note, _, isOnline, status, classFile, _, _, isMobile = GetGuildRosterInfo(i)
        if name then
            local short = Ambiguate(name, "short")
            rankMap[short] = rankIndex
            nameMap[short] = rankName
            local e = {
                name = name, short = short, rank = rankName or "", rankIndex = rankIndex or 99,
                level = level or 0, class = classDisp or "", classFile = classFile,
                zone = zone or "", note = note or "", online = isOnline and true or false,
                status = status, last = 0, mobile = isMobile and true or false,
            }
            if e.online then
                online = online + 1
            else
                local y, m, d, h = GetGuildRosterLastOnline(i)
                e.last, e.zone = LastSeen(y, m, d, h)
                if isMobile then e.zone = "Mobile App" end
            end
            list[#list + 1] = e
        end
    end
    self.list, self.total, self.onlineCount = list, #list, online
    AOR.rosterRank = rankMap
    AOR.rosterRankName = nameMap
    AOR:Fire("ROSTER", list)
end

function R:BuildView()
    local f = self.filter:lower()
    local view = {}
    for _, e in ipairs(self.list) do
        if (not self.onlineOnly or e.online) then
            if f == "" or e.short:lower():find(f, 1, true) or e.class:lower():find(f, 1, true)
               or e.rank:lower():find(f, 1, true) or e.zone:lower():find(f, 1, true)
               or e.note:lower():find(f, 1, true) then
                view[#view + 1] = e
            end
        end
    end
    local fn, asc = keyFns[self.sortKey], self.sortAsc
    table.sort(view, function(a, b)
        local ka, kb = fn(a), fn(b)
        if ka ~= kb then
            if asc then return ka < kb else return ka > kb end
        end
        return a.short:lower() < b.short:lower()
    end)
    self.view = view
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local function MakeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.14)
    r.hl:Hide()
    r.dot = r:CreateTexture(nil, "OVERLAY")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 4, 0)
    r.cells = {}
    for _, col in ipairs(columns) do
        local fs = UI:Text(r, 12, C.text)
        fs:SetPoint("LEFT", col.x, 0)
        fs:SetWidth(col.w)
        fs:SetWordWrap(false)
        r.cells[col.key] = fs
    end

    r:SetScript("OnEnter", function(s)
        s.hl:Show()
        local e = s.data
        if not e then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AOR:ColorName(e.short, e.classFile), 1, 1, 1)
        GameTooltip:AddLine(("Level %d %s  -  %s"):format(e.level, e.class, e.rank), 0.9, 0.85, 0.8)
        GameTooltip:AddLine(e.online and e.zone or ("Last seen " .. e.zone), 0.6, 0.55, 0.52)
        if e.note ~= "" then GameTooltip:AddLine("Note: " .. e.note, 0.96, 0.78, 0.36, true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: whisper", 0.6, 0.55, 0.52)
        if e.online then GameTooltip:AddLine("Right-click: invite to group", 0.6, 0.55, 0.52) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s, button)
        local e = s.data
        if not e then return end
        if button == "RightButton" then
            if e.online then C_PartyInfo.InviteUnit(e.name) end
        else
            local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
            open("/w " .. e.name .. " ")
        end
    end)
    return r
end

local function UpdateRow(r, e, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    local cr, cg, cb = AOR:ClassColor(e.classFile)
    local a = e.online and 1 or 0.5
    local tag = ""
    if e.status == 1 then tag = " |cffff9933<AFK>|r" elseif e.status == 2 then tag = " |cffe04a3a<DND>|r" end

    if e.online then r.dot:SetColorTexture(unpack(C.good)) else r.dot:SetColorTexture(0.3, 0.27, 0.26, 1) end
    r.cells.name:SetText(e.short .. tag)
    r.cells.name:SetTextColor(cr, cg, cb, a)
    r.cells.level:SetText(e.level)
    r.cells.level:SetTextColor(C.text[1], C.text[2], C.text[3], a)
    r.cells.class:SetText(e.class)
    r.cells.class:SetTextColor(cr, cg, cb, a)
    r.cells.rank:SetText(e.rank)
    r.cells.rank:SetTextColor(C.gold[1], C.gold[2], C.gold[3], a)
    r.cells.zone:SetText(e.zone)
    r.cells.zone:SetTextColor(C.text[1], C.text[2], C.text[3], a)
    r.cells.note:SetText(e.note)
    r.cells.note:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 1)
end

function R:Refresh()
    if not self.ui then return end
    self:BuildView()
    self.ui.list:SetData(self.view)
    self.ui.counts:SetText(("|cff%s%d|r online  /  %d members"):format(AOR:Hex(C.good), self.onlineCount, self.total))
    for _, h in pairs(self.ui.headers) do
        local active = (h.key == self.sortKey)
        h.text:SetTextColor(unpack(active and C.ember or C.dim))
        h.text:SetText(h.label .. (active and (self.sortAsc and "  ^" or "  v") or ""))
    end
end

local function Init(page)
    local ui = { headers = {} }
    R.ui = ui

    local search = UI:EditBox(page, 240, 26, "Search name, class, rank, zone, note...")
    search:SetPoint("TOPLEFT", 0, 0)
    search:HookScript("OnTextChanged", function(s)
        R.filter = s:GetText() or ""
        R:Refresh()
    end)

    local only = UI:Check(page, "Online only", function(v)
        R.onlineOnly = v
        R:Refresh()
    end)
    only:SetPoint("LEFT", search, "RIGHT", 14, 0)

    ui.counts = UI:Text(page, 12, C.text)
    ui.counts:SetPoint("TOPRIGHT", -14, -7)
    ui.counts:SetJustifyH("RIGHT")

    for _, col in ipairs(columns) do
        local h = CreateFrame("Button", nil, page)
        h:SetPoint("TOPLEFT", col.x - 2, -34)
        h:SetSize(col.w, 20)
        h.key, h.label = col.key, col.label
        h.text = UI:Text(h, 11, C.dim)
        h.text:SetPoint("LEFT", 2, 0)
        h.text:SetText(col.label)
        if keyFns[col.key] then
            h:SetScript("OnClick", function()
                if R.sortKey == col.key then R.sortAsc = not R.sortAsc else R.sortKey, R.sortAsc = col.key, true end
                R:Refresh()
            end)
        end
        ui.headers[col.key] = h
    end

    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -55)
    line:SetPoint("TOPRIGHT", 0, -55)

    ui.list = UI:VirtualList(page, ROW_H, ROWS, MakeRow, 0)
    ui.list:SetPoint("TOPLEFT", 0, -58)
    ui.list:SetPoint("BOTTOMRIGHT", 0, 0)
    ui.list.onUpdateRow = UpdateRow
end

UI:RegisterTab("roster", "Kindred", Init, function() R:Refresh() end,
    { group = "GUILD", hint = "Roster", title = "Kindred" })

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local pending
local function Dirty()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        R:Collect()
    end)
end

AOR:RegisterEvent("GUILD_ROSTER_UPDATE", Dirty)
AOR:RegisterEvent("PLAYER_GUILD_UPDATE", Dirty)

AOR:OnInit(function()
    C_Timer.NewTicker(60, function()
        if IsInGuild() then C_GuildInfo.GuildRoster() end
    end)
end)

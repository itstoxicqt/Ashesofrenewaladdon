local _, AOR = ...
local UI, C = AOR.UI, AOR.colors
local A = AOR.Attend

local V = {
    view = "members", window = "30d", search = "", everyone = false, selected = nil,
    classMap = {}, tabs = {}, frames = {}, winBtns = {},
}
AOR.AttendUI = V

local HEAD = "Fonts\\FRIZQT__.TTF"
local BAR_W = 200
local DETAIL_X, DETAIL_W, LEFT_W = 536, 322, 520

local function PctColor(p)
    if p >= 80 then return C.good end
    if p >= 50 then return C.gold end
    return C.bad
end

local function Colored(name)
    return AOR:ColorName(name, V.classMap[name])
end

------------------------------------------------------------------------
-- Members view
------------------------------------------------------------------------
local function MakeMemberRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 14, 0)
    r.name:SetWidth(180)
    r.name:SetWordWrap(false)
    r.raids = UI:Text(r, 12, C.text)
    r.raids:SetPoint("LEFT", 210, 0)
    r.raids:SetWidth(70)
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetSize(BAR_W, 8)
    r.track:SetPoint("LEFT", 300, 0)
    r.track:SetColorTexture(1, 1, 1, 0.07)
    r.fill = r:CreateTexture(nil, "OVERLAY")
    r.fill:SetHeight(8)
    r.fill:SetPoint("LEFT", r.track, "LEFT", 0, 0)
    r.pct = UI:Text(r, 13, C.text, HEAD)
    r.pct:SetPoint("LEFT", 512, 0)
    r.pct:SetWidth(50)
    r.streak = UI:Text(r, 12, C.dim)
    r.streak:SetPoint("LEFT", 580, 0)
    r.streak:SetWidth(70)
    r.last = UI:Text(r, 12, C.dim)
    r.last:SetPoint("LEFT", 660, 0)
    r.last:SetWidth(130)
    return r
end

local function UpdateMemberRow(r, m, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    local cr, cg, cb = AOR:ClassColor(m.classFile)
    r.name:SetText(m.name)
    r.name:SetTextColor(cr, cg, cb, m.online and 1 or 0.6)
    r.raids:SetText(("%d / %d"):format(m.attended, m.total))
    local col = PctColor(m.pct)
    r.fill:SetColorTexture(col[1], col[2], col[3], 1)
    r.fill:SetWidth(math.max(0.001, BAR_W * math.min(m.pct, 100) / 100))
    r.fill:SetShown(m.pct > 0)
    r.pct:SetText(m.pct .. "%")
    r.pct:SetTextColor(unpack(col))
    r.streak:SetText(m.streak > 0 and (m.streak .. " in a row") or "-")
    r.last:SetText(m.last and date("%a %b %d", m.last) or "never")
end

local function BuildMembers(v)
    local cols = { { "PLAYER", 14 }, { "RAIDS", 210 }, { "ATTENDANCE", 300 }, { "STREAK", 580 }, { "LAST RAID", 660 } }
    for _, c in ipairs(cols) do
        local h = UI:Text(v, 10, C.dim)
        h:SetPoint("TOPLEFT", c[2], -4)
        h:SetText(c[1])
    end
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -20)
    line:SetPoint("TOPRIGHT", 0, -20)

    V.memberList = UI:VirtualList(v, 24, 22, MakeMemberRow, 0)
    V.memberList:SetPoint("TOPLEFT", 0, -24)
    V.memberList:SetPoint("BOTTOMRIGHT", 0, 0)
    V.memberList.onUpdateRow = UpdateMemberRow

    V.memberEmpty = UI:Text(v, 13, C.dim)
    V.memberEmpty:SetPoint("CENTER", 0, -10)
    V.memberEmpty:SetWidth(520)
    V.memberEmpty:SetJustifyH("CENTER")
end

------------------------------------------------------------------------
-- Raids view
------------------------------------------------------------------------
local function MakeRaidRow(parent)
    local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
    UI:Skin(r, C.panel, C.border)
    r.date = UI:Text(r, 12, C.gold)
    r.date:SetPoint("LEFT", 12, 0)
    r.date:SetWidth(150)
    r.title = UI:Text(r, 13, C.text)
    r.title:SetPoint("LEFT", 170, 0)
    r.title:SetWidth(190)
    r.title:SetWordWrap(false)
    r.count = UI:Text(r, 12, C.good)
    r.count:SetPoint("LEFT", 370, 0)
    r.count:SetWidth(80)
    r.del = UI:Button(r, "X", 20, 20, function(s)
        local row = s:GetParent().data
        if row then
            A:Delete(row.id)
            if V.selected == row.id then V.selected = nil end
        end
    end)
    r.del:SetPoint("RIGHT", -18, 0)
    r:SetScript("OnClick", function(s)
        if s.data then V.selected = s.data.id; V:Refresh() end
    end)
    r:SetScript("OnEnter", function(s)
        if V.selected ~= (s.data and s.data.id) then s:SetBackdropBorderColor(unpack(C.ember)) end
    end)
    r:SetScript("OnLeave", function(s)
        local sel = (V.selected == (s.data and s.data.id))
        s:SetBackdropBorderColor(unpack(sel and C.ember or C.border))
    end)
    return r
end

local function UpdateRaidRow(r, s)
    r.date:SetText(date("%a %b %d  %I:%M %p", s.evt))
    r.title:SetText(s.title ~= "" and s.title or "Raid")
    r.count:SetText(("%d present"):format(#A:Attendees(s)))
    r.del:SetShown(AOR:CanPost())
    local sel = (V.selected == s.id)
    r:SetBackdropBorderColor(unpack(sel and C.ember or C.border))
    r:SetBackdropColor(unpack(sel and C.panelHi or C.panel))
end

local function BuildRaids(v)
    V.raidList = UI:VirtualList(v, 30, 18, MakeRaidRow, 2)
    V.raidList:SetPoint("TOPLEFT", 0, 0)
    V.raidList:SetPoint("BOTTOMLEFT", 0, 0)
    V.raidList:SetWidth(LEFT_W)
    V.raidList.onUpdateRow = UpdateRaidRow

    V.raidEmpty = UI:Text(v, 13, C.dim)
    V.raidEmpty:SetPoint("TOPLEFT", 20, -60)
    V.raidEmpty:SetWidth(LEFT_W - 40)
    V.raidEmpty:SetJustifyH("CENTER")

    local card = UI:Card(v, "Raid Details", DETAIL_W, 520)
    card:SetPoint("TOPLEFT", DETAIL_X, 0)
    V.dTitle = UI:Text(card, 15, C.gold, HEAD)
    V.dTitle:SetPoint("TOPLEFT", 12, -40)
    V.dTitle:SetWidth(DETAIL_W - 24)
    V.dTitle:SetWordWrap(false)
    V.dInfo = UI:Text(card, 11, C.dim)
    V.dInfo:SetPoint("TOPLEFT", 12, -62)
    V.dInfo:SetWidth(DETAIL_W - 24)
    V.dCol1 = UI:Text(card, 12, C.text)
    V.dCol1:SetPoint("TOPLEFT", 12, -88)
    V.dCol1:SetSize(146, 360)
    V.dCol1:SetJustifyV("TOP")
    V.dCol1:SetSpacing(3)
    V.dCol2 = UI:Text(card, 12, C.text)
    V.dCol2:SetPoint("TOPLEFT", 166, -88)
    V.dCol2:SetSize(146, 360)
    V.dCol2:SetJustifyV("TOP")
    V.dCol2:SetSpacing(3)

    V.addBox = UI:EditBox(card, 180, 26, "Add a missed player", 24)
    V.addBox:SetPoint("BOTTOMLEFT", 12, 12)
    V.addBtn = UI:Button(card, "Add", 60, 26, function()
        local ok, msg = A:AddAttendee(V.selected, V.addBox:GetText())
        if ok then V.addBox:SetText("") elseif msg then AOR:Print(msg) end
    end)
    V.addBtn:SetPoint("LEFT", V.addBox, "RIGHT", 8, 0)
end

------------------------------------------------------------------------
-- Frame, refresh
------------------------------------------------------------------------
function V:Show(view)
    self.view = view
    for key, f in pairs(self.frames) do f:SetShown(key == view) end
    for key, b in pairs(self.tabs) do
        b:SetBackdropBorderColor(unpack(key == view and C.ember or C.border))
    end
    self:Refresh()
end

function V:Refresh()
    if not self.frames.members then return end
    local officer = AOR:CanPost()

    wipe(self.classMap)
    local roster = AOR.Roster and AOR.Roster.list
    if roster then
        for _, e in ipairs(roster) do self.classMap[e.short] = e.classFile end
    end

    for key, b in pairs(self.winBtns) do
        b:SetBackdropBorderColor(unpack(key == self.window and C.ember or C.border))
    end

    -- tracking status (officers record; everyone else just reads)
    if officer then
        if A.tracking then
            self.status:SetLabel(("TRACKING: %s"):format(string.upper(A.tracking.title)), C.good)
            self.trackBtn.text:SetText("Stop Tracking")
        else
            self.status:SetLabel("NOT TRACKING", C.dim)
            self.trackBtn.text:SetText("Start Tracking")
        end
        self.trackBtn:Show()
    else
        local list = A:Sessions()
        self.status:SetLabel(("%d RAIDS RECORDED"):format(#list), C.dim)
        self.trackBtn:Hide()
    end

    local window = self.window
    if self.view == "members" then
        local rows, total = A:Stats(window, self.search, self.everyone)
        self.memberList:SetData(rows)
        self.memberEmpty:SetShown(#rows == 0)
        if total == 0 then
            self.memberEmpty:SetText("No raids recorded in this range yet.\nAn officer's addon records attendance automatically during Conclave events\n(or press Start Tracking while in a raid group).")
        else
            self.memberEmpty:SetText("No members match.")
        end
        self.info:SetText(("%d raids in range"):format(total))
    else
        local sessions = A:Window(window)
        self.raidList:SetData(sessions)
        self.raidEmpty:SetShown(#sessions == 0)
        self.raidEmpty:SetText("No raids recorded in this range yet.")
        self.info:SetText(("%d raids in range"):format(#sessions))

        local sel
        for _, s in ipairs(sessions) do if s.id == self.selected then sel = s end end
        if not sel and sessions[1] then self.selected, sel = sessions[1].id, sessions[1] end
        if sel then
            local list = A:Attendees(sel)
            self.dTitle:SetText(sel.title ~= "" and sel.title or "Raid")
            self.dInfo:SetText(("%s  -  %d present  -  %d snapshots"):format(date("%a %b %d, %I:%M %p", sel.evt), #list, sel.snaps))
            local c1, c2 = {}, {}
            for i, name in ipairs(list) do
                if i <= 22 then c1[#c1 + 1] = Colored(name)
                elseif i <= 44 then c2[#c2 + 1] = Colored(name)
                elseif i == 45 then c2[#c2 + 1] = ("|cff%s+%d more|r"):format(AOR:Hex(C.dim), #list - 44) end
            end
            self.dCol1:SetText(table.concat(c1, "\n"))
            self.dCol2:SetText(table.concat(c2, "\n"))
        else
            self.dTitle:SetText("")
            self.dInfo:SetText("")
            self.dCol1:SetText("")
            self.dCol2:SetText("")
        end
        self.addBox:SetShown(officer and sel ~= nil)
        self.addBtn:SetShown(officer and sel ~= nil)
    end
end

local function Init(page)
    local x = 0
    for _, t in ipairs({ { "members", "Members", 100 }, { "raids", "Raids", 100 } }) do
        local key = t[1]
        local b = UI:Button(page, t[2], t[3], 26, function() V:Show(key) end)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(V.view == key and C.ember or C.border))
        end)
        x = x + t[3] + 6
        V.tabs[key] = b
    end

    V.status = UI:Chip(page, "NOT TRACKING", C.dim, true)
    V.status:SetPoint("TOPRIGHT", 0, -1)
    V.trackBtn = UI:Button(page, "Start Tracking", 130, 26, function()
        if A.tracking then
            A:Stop()
        else
            local ok, msg = A:Start()
            if not ok and msg then AOR:Print(msg) end
        end
        V:Refresh()
    end)
    V.trackBtn:SetPoint("RIGHT", V.status, "LEFT", -8, 0)

    -- second row: range, search, scope
    local wx = 0
    for _, w in ipairs({ { "30d", "30 days", 84 }, { "10", "Last 10", 84 }, { "all", "All time", 84 } }) do
        local key = w[1]
        local b = UI:Button(page, w[2], w[3], 24, function() V.window = key; V:Refresh() end)
        b:SetPoint("TOPLEFT", wx, -38)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(V.window == key and C.ember or C.border))
        end)
        wx = wx + w[3] + 6
        V.winBtns[key] = b
    end
    local search = UI:EditBox(page, 200, 24, "Search player...")
    search:SetPoint("TOPLEFT", wx + 10, -38)
    search:HookScript("OnTextChanged", function(s)
        V.search = s:GetText() or ""
        V:Refresh()
    end)
    V.allBox = UI:Check(page, "All members", function(v)
        V.everyone = v
        V:Refresh()
    end)
    V.allBox:SetPoint("LEFT", search, "RIGHT", 14, 0)
    V.info = UI:Text(page, 11, C.dim)
    V.info:SetPoint("TOPRIGHT", 0, -44)
    V.info:SetJustifyH("RIGHT")

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 0, -72)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    for _, key in ipairs({ "members", "raids" }) do
        local f = CreateFrame("Frame", nil, body)
        f:SetAllPoints()
        f:Hide()
        V.frames[key] = f
    end
    BuildMembers(V.frames.members)
    BuildRaids(V.frames.raids)

    C_Timer.NewTicker(30, function()
        if page:IsVisible() then V:Refresh() end
    end)
    V:Show("members")
end

UI:RegisterTab("watch", "Ember Watch", Init, function() V:Refresh() end,
    { group = "RAID", hint = "Attend.", title = "Ember Watch" })

AOR:Subscribe("ATTEND", function() UI:Refresh() end)

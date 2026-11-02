local _, AOR = ...
local UI, C = AOR.UI, AOR.colors
local R = AOR.Reserve

local V = { view = "reserves", frames = {}, tabs = {}, classMap = {} }
AOR.ReserveUI = V

local HEAD = "Fonts\\FRIZQT__.TTF"
local ROW_H = 30
local MAX_CANDIDATES = 8

local function Me() return UnitName("player") end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function PlayerName(name)
    if name == "BANK" then return "Guild Bank" end
    return AOR:ColorName(name, V.classMap[name])
end

-- Two-click confirmation for destructive buttons
local function Confirm(btn, label, fn)
    local armed
    btn:SetScript("OnClick", function(s)
        if armed then
            armed = false
            s.text:SetText(label)
            fn()
        else
            armed = true
            s.text:SetText("Click to confirm")
            C_Timer.After(4, function()
                if armed then armed = false; s.text:SetText(label) end
            end)
        end
    end)
end

local function Tooltip(row)
    row:SetScript("OnEnter", function(s)
        if s.hl then s.hl:Show() end
        local e = s.data
        if not e then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. e.id)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(s)
        if s.hl then s.hl:Hide() end
        GameTooltip:Hide()
    end)
end

local function RowBase(parent)
    local r = CreateFrame("Button", nil, parent)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.12)
    r.hl:Hide()
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return r
end

------------------------------------------------------------------------
-- Item link boxes: click in, then shift-click an item link from chat,
-- bags or the loot window. Pasting an item ID and pressing Enter works too.
------------------------------------------------------------------------
local linkBoxes = {}

local function LinkBox(parent, w, placeholder, onItem)
    local e = UI:EditBox(parent, w, 26, placeholder, 200)
    function e:Receive(id)
        self.itemID = id
        self.settingText = true
        self:SetText((R:ItemData(id)))
        self.settingText = false
        if onItem then onItem(id, self) end
    end
    function e:Reset()
        self.itemID = nil
        self.settingText = true
        self:SetText("")
        self.settingText = false
    end
    e:HookScript("OnTextChanged", function(s)
        if s.settingText then return end
        local text = s:GetText() or ""
        if text == "" then s.itemID = nil; return end
        local id = text:match("item:(%d+)")
        if id then s:Receive(tonumber(id)) else s.itemID = nil end
    end)
    e:HookScript("OnEnterPressed", function(s)
        local id = R:ParseItemID(s:GetText())
        if id and not s.itemID then s:Receive(id) end
    end)
    linkBoxes[#linkBoxes + 1] = e
    return e
end

local lastLink, lastAt
local function OnInsertLink(text)
    if type(text) ~= "string" then return end
    local id = text:match("item:(%d+)")
    if not id then return end
    local now = GetTime()
    if lastLink == text and lastAt and now - lastAt < 0.3 then return end
    for _, b in ipairs(linkBoxes) do
        if b:IsVisible() and b:HasFocus() then
            lastLink, lastAt = text, now
            b:Receive(tonumber(id))
            return
        end
    end
end

------------------------------------------------------------------------
-- Award resolver
------------------------------------------------------------------------
local function BuildResolver(page)
    local f = UI:NewFrame(page, C.bg, C.ember)
    f:SetSize(520, 350)
    f:SetPoint("CENTER", 0, 10)
    f:SetFrameLevel(page:GetFrameLevel() + 40)
    f:EnableMouse(true)
    f:Hide()
    V.resolver = f

    f.title = UI:Text(f, 16, C.gold, HEAD)
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.title:SetWidth(488)
    f.title:SetWordWrap(false)
    f.info = UI:Text(f, 12, C.dim)
    f.info:SetPoint("TOPLEFT", 16, -44)
    f.info:SetSize(488, 34)
    f.info:SetJustifyV("TOP")
    f.info:SetWordWrap(true)

    f.rows = {}
    for i = 1, MAX_CANDIDATES do
        local r = UI:NewFrame(f, C.panel, C.border)
        r:SetSize(488, 28)
        r:SetPoint("TOPLEFT", 16, -86 - (i - 1) * 32)
        r.name = UI:Text(r, 13, C.text)
        r.name:SetPoint("LEFT", 10, 0)
        r.name:SetWidth(220)
        r.name:SetWordWrap(false)
        r.plus = UI:Text(r, 13, C.gold)
        r.plus:SetPoint("LEFT", 240, 0)
        r.plus:SetWidth(60)
        r.tag = UI:Text(r, 10, C.ember)
        r.tag:SetPoint("LEFT", 300, 0)
        r.tag:SetWidth(110)
        r.btn = UI:Button(r, "Award", 66, 22, function(s)
            local row = s:GetParent()
            if not row.player then return end
            R:Award(f.itemID, row.player, row.kind)
            AOR:Print(("Awarded %s to %s."):format(R:ColoredName(f.itemID), row.player == "BANK" and "the guild bank" or row.player))
            f:Hide()
        end)
        r.btn:SetPoint("RIGHT", -4, 0)
        r:Hide()
        f.rows[i] = r
    end

    local close = UI:Button(f, "Close", 90, 26, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
end

function V:OpenResolve(id)
    local f = self.resolver
    f.itemID = id
    f.title:SetText(R:ColoredName(id))
    for _, r in ipairs(f.rows) do r:Hide() end
    local res = R:Resolve(id)
    if res.kind == "H" then
        f.info:SetText("Hard reserved. This item skips rolls, soft reserves and +1.")
        local r = f.rows[1]
        r.player, r.kind = res.target, "H"
        r.name:SetText(PlayerName(res.target))
        r.plus:SetText("")
        r.tag:SetText("HARD RESERVE")
        r:Show()
    elseif res.kind == "S" then
        if res.tie then
            f.info:SetText(("Tie at +%d between %s. Have them /roll, then award the winner."):format(res.plus, table.concat(res.tier, ", ")))
        else
            f.info:SetText("Lowest +1 wins. Award the top player, or pick another if the raid agrees.")
        end
        local inTier = {}
        for _, p in ipairs(res.tier) do inTier[p] = true end
        for i, p in ipairs(res.list) do
            if i > MAX_CANDIDATES then break end
            local r = f.rows[i]
            r.player, r.kind = p, "S"
            r.name:SetText(PlayerName(p))
            r.plus:SetText("+" .. R:Plus(p))
            r.tag:SetText(inTier[p] and (res.tie and "TIED" or "LOWEST +1") or "")
            r:Show()
        end
    else
        f.info:SetText("Nobody reserved this item. Open roll for the raid.")
    end
    f:Show()
end

------------------------------------------------------------------------
-- Reserves view
------------------------------------------------------------------------
local function MakeItemRow(parent)
    local r = RowBase(parent)
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 36, 0)
    r.name:SetWidth(300)
    r.name:SetWordWrap(false)
    r.status = UI:Text(r, 12, C.dim)
    r.status:SetPoint("LEFT", 346, 0)
    r.status:SetWidth(300)
    r.status:SetWordWrap(false)
    r.act = UI:Button(r, "Reserve", 84, 22, function(s)
        local e = s:GetParent().data
        if not e then return end
        local ok, msg
        if R:HasMine(e.id) then ok, msg = R:Cancel(e.id) else ok, msg = R:Reserve(e.id) end
        if not ok and msg then AOR:Print(msg) end
    end)
    r.act:SetPoint("RIGHT", -6, 0)
    r.award = UI:Button(r, "Award", 60, 22, function(s)
        local e = s:GetParent().data
        if e then V:OpenResolve(e.id) end
    end)
    r.award:SetPoint("RIGHT", r.act, "LEFT", -4, 0)
    r.rm = UI:Button(r, "X", 22, 22, function(s)
        local e = s:GetParent().data
        if e then R:RemovePool(e.id) end
    end)
    r.rm:SetPoint("RIGHT", r.award, "LEFT", -4, 0)
    Tooltip(r)
    return r
end

local function UpdateItemRow(r, e, index)
    local _, _, _, icon = R:ItemData(e.id)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    r.icon:SetTexture(icon)
    r.name:SetText(R:ColoredName(e.id))
    local officer = AOR:CanPost()
    local locked = R:IsLocked()

    if e.hard then
        r.status:SetText(("|cff%sHARD RESERVED|r  %s"):format(AOR:Hex(C.ember), PlayerName(e.hard.target or "?")))
        r.act:Hide()
    else
        local list = R:Reservers(e.id)
        if #list == 0 then
            r.status:SetText("|cff" .. AOR:Hex(C.dim) .. "No reserves|r")
        else
            local parts = {}
            for i, p in ipairs(list) do
                if i > 4 then parts[#parts + 1] = ("+%d more"):format(#list - 4); break end
                parts[#parts + 1] = ("%s (+%d)"):format(PlayerName(p), R:Plus(p))
            end
            r.status:SetText(("|cff%s%d|r  %s"):format(AOR:Hex(C.gold), #list, table.concat(parts, ", ")))
        end
        r.act:Show()
        r.act.text:SetText(R:HasMine(e.id) and "Remove" or "Reserve")
        r.act:SetAlpha(locked and 0.4 or 1)
        r.act:SetEnabled(not locked)
    end
    r.award:SetShown(officer)
    r.rm:SetShown(officer and e.pooled == true)
end

local function BuildReserves(v)
    V.hint = UI:Text(v, 12, C.dim)
    V.hint:SetPoint("TOPLEFT", 0, -7)
    V.hint:SetText("Pick an item to reserve it. Reserves lock automatically before the next Conclave event.")

    V.poolBox = LinkBox(v, 380, "Officers: shift-click an item link here to add it to the pool", function(id, box)
        local ok, msg = R:AddPool(id)
        if ok then AOR:Print("Added to the reserve pool: " .. R:ColoredName(id))
        elseif msg then AOR:Print(msg) end
        box:Reset()
    end)
    V.poolBox:SetPoint("TOPLEFT", 0, 0)

    V.lockBtn = UI:Button(v, "Lock Now", 90, 26, function()
        R:SetLockMode(R:IsLocked() and "O" or "L")
    end)
    V.lockBtn:SetPoint("LEFT", V.poolBox, "RIGHT", 8, 0)
    V.autoBtn = UI:Button(v, "Auto Lock", 90, 26, function() R:SetLockMode("A") end)
    V.autoBtn:SetPoint("LEFT", V.lockBtn, "RIGHT", 6, 0)
    V.newBtn = UI:Button(v, "New Session", 120, 26, function() end)
    V.newBtn:SetPoint("TOPRIGHT", 0, 0)
    Confirm(V.newBtn, "New Session", function()
        R:NewSession()
        AOR:Print("New session started. Everyone's soft reserves were cleared.")
    end)

    local h1 = UI:Text(v, 10, C.dim)
    h1:SetPoint("TOPLEFT", 38, -40)
    h1:SetText("ITEM")
    local h2 = UI:Text(v, 10, C.dim)
    h2:SetPoint("TOPLEFT", 346, -40)
    h2:SetText("STATUS")
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -56)
    line:SetPoint("TOPRIGHT", 0, -56)

    V.list = UI:VirtualList(v, ROW_H, 16, MakeItemRow, 0)
    V.list:SetPoint("TOPLEFT", 0, -60)
    V.list:SetPoint("BOTTOMRIGHT", 0, 0)
    V.list.onUpdateRow = UpdateItemRow

    V.empty = UI:Text(v, 14, C.dim)
    V.empty:SetPoint("CENTER", 0, -20)
    V.empty:SetWidth(520)
    V.empty:SetJustifyH("CENTER")
end

------------------------------------------------------------------------
-- Hard Reserves view
------------------------------------------------------------------------
local function MakeHardRow(parent)
    local r = RowBase(parent)
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 36, 0)
    r.name:SetWidth(330)
    r.name:SetWordWrap(false)
    r.target = UI:Text(r, 13, C.gold)
    r.target:SetPoint("LEFT", 380, 0)
    r.target:SetWidth(200)
    r.target:SetWordWrap(false)
    r.by = UI:Text(r, 11, C.dim)
    r.by:SetPoint("LEFT", 590, 0)
    r.by:SetWidth(180)
    r.by:SetWordWrap(false)
    r.rm = UI:Button(r, "X", 22, 22, function(s)
        local e = s:GetParent().data
        if e then R:ClearHard(e.id) end
    end)
    r.rm:SetPoint("RIGHT", -6, 0)
    Tooltip(r)
    return r
end

local function UpdateHardRow(r, e, index)
    local _, _, _, icon = R:ItemData(e.id)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    r.icon:SetTexture(icon)
    r.name:SetText(R:ColoredName(e.id))
    r.target:SetText(PlayerName(e.hard.target or "?"))
    r.by:SetText(e.hard.by and ("set by " .. Ambiguate(e.hard.by, "short")) or "")
    r.rm:SetShown(AOR:CanPost())
end

local function BuildHard(v)
    V.hardNote = UI:Text(v, 12, C.dim)
    V.hardNote:SetPoint("TOPLEFT", 0, -7)
    V.hardNote:SetText("Hard reserves are set by officers and visible to everyone. These items skip rolls, soft reserves and +1.")

    V.hardItem = LinkBox(v, 330, "Shift-click an item link here")
    V.hardItem:SetPoint("TOPLEFT", 0, 0)
    V.hardTarget = UI:EditBox(v, 220, 26, "Player name, or BANK", 24)
    V.hardTarget:SetPoint("LEFT", V.hardItem, "RIGHT", 8, 0)
    V.hardBtn = UI:Button(v, "Lock Item", 100, 26, function()
        local id = V.hardItem.itemID or R:ParseItemID(V.hardItem:GetText())
        local ok, msg = R:SetHard(id, V.hardTarget:GetText())
        if ok then
            AOR:Print(("Hard reserved %s for %s."):format(R:ColoredName(id), strtrim(V.hardTarget:GetText())))
            V.hardItem:Reset()
            V.hardTarget:SetText("")
        elseif msg then
            AOR:Print(msg)
        end
    end)
    V.hardBtn:SetPoint("LEFT", V.hardTarget, "RIGHT", 8, 0)

    local h1 = UI:Text(v, 10, C.dim)
    h1:SetPoint("TOPLEFT", 38, -40)
    h1:SetText("ITEM")
    local h2 = UI:Text(v, 10, C.dim)
    h2:SetPoint("TOPLEFT", 380, -40)
    h2:SetText("LOCKED TO")
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -56)
    line:SetPoint("TOPRIGHT", 0, -56)

    V.hardList = UI:VirtualList(v, ROW_H, 16, MakeHardRow, 0)
    V.hardList:SetPoint("TOPLEFT", 0, -60)
    V.hardList:SetPoint("BOTTOMRIGHT", 0, 0)
    V.hardList.onUpdateRow = UpdateHardRow

    V.hardEmpty = UI:Text(v, 14, C.dim)
    V.hardEmpty:SetPoint("CENTER", 0, -20)
    V.hardEmpty:SetText("No hard reserves set.")
end

------------------------------------------------------------------------
-- Standings view
------------------------------------------------------------------------
local LEFT_W = 518

local function MakeStandRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 14, 0)
    r.name:SetWidth(200)
    r.name:SetWordWrap(false)
    r.n = UI:Text(r, 14, C.gold, HEAD)
    r.n:SetPoint("LEFT", 224, 0)
    r.n:SetWidth(50)
    r.items = UI:Text(r, 11, C.dim)
    r.items:SetPoint("LEFT", 284, 0)
    r.items:SetWidth(170)
    r.items:SetWordWrap(false)
    r.plus = UI:Button(r, "+", 20, 20, function(s)
        local e = s:GetParent().data
        if e then R:AdjustPlus(e.name, 1) end
    end)
    r.plus:SetPoint("RIGHT", -4, 0)
    r.minus = UI:Button(r, "-", 20, 20, function(s)
        local e = s:GetParent().data
        if e then R:AdjustPlus(e.name, -1) end
    end)
    r.minus:SetPoint("RIGHT", r.plus, "LEFT", -3, 0)
    return r
end

local function UpdateStandRow(r, e, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    r.name:SetText(PlayerName(e.name))
    r.n:SetText("+" .. e.n)
    local names = {}
    for _, id in ipairs(e.items) do names[#names + 1] = (R:ItemData(id)) end
    r.items:SetText(table.concat(names, ", "))
    local officer = AOR:CanPost()
    r.plus:SetShown(officer)
    r.minus:SetShown(officer)
end

local function BuildStandings(v)
    V.seasonText = UI:Text(v, 15, C.gold, HEAD)
    V.seasonText:SetPoint("TOPLEFT", 0, -4)
    V.seasonText:SetWidth(110)

    V.addPlayer = UI:EditBox(v, 170, 26, "Add player", 24)
    V.addPlayer:SetPoint("TOPLEFT", 120, 0)
    V.addBtn = UI:Button(v, "Add", 50, 26, function()
        local ok, msg = R:AdjustPlus(V.addPlayer:GetText(), 0)
        if ok then V.addPlayer:SetText("") elseif msg then AOR:Print(msg) end
    end)
    V.addBtn:SetPoint("LEFT", V.addPlayer, "RIGHT", 8, 0)
    V.seasonBtn = UI:Button(v, "New Season", 122, 26, function() end)
    V.seasonBtn:SetPoint("TOPLEFT", LEFT_W - 122, 0)
    Confirm(V.seasonBtn, "New Season", function()
        R:NewSeason()
        AOR:Print("Season " .. R:Season() .. " started. Standings begin at +0.")
    end)

    local h1 = UI:Text(v, 10, C.dim)
    h1:SetPoint("TOPLEFT", 14, -40)
    h1:SetText("PLAYER")
    local h2 = UI:Text(v, 10, C.dim)
    h2:SetPoint("TOPLEFT", 224, -40)
    h2:SetText("+1")
    local h3 = UI:Text(v, 10, C.dim)
    h3:SetPoint("TOPLEFT", 284, -40)
    h3:SetText("RESERVED NOW")
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -56)
    line:SetWidth(LEFT_W)

    V.standList = UI:VirtualList(v, 24, 20, MakeStandRow, 0)
    V.standList:SetPoint("TOPLEFT", 0, -60)
    V.standList:SetPoint("BOTTOMLEFT", 0, 0)
    V.standList:SetWidth(LEFT_W)
    V.standList.onUpdateRow = UpdateStandRow

    V.standEmpty = UI:Text(v, 13, C.dim)
    V.standEmpty:SetPoint("TOPLEFT", 14, -80)
    V.standEmpty:SetWidth(LEFT_W - 28)
    V.standEmpty:SetText("No standings yet. Players appear when they reserve or win an item.")

    local card = UI:Card(v, "Recent Awards", 324, 420)
    card:SetPoint("TOPLEFT", LEFT_W + 16, 0)
    V.logText = UI:Text(card, 12, C.text)
    V.logText:SetPoint("TOPLEFT", 12, -38)
    V.logText:SetSize(300, 370)
    V.logText:SetJustifyV("TOP")
    V.logText:SetWordWrap(true)
    V.logText:SetSpacing(4)
end

------------------------------------------------------------------------
-- Frame, tabs, refresh
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
    if not self.frames.reserves then return end
    local officer = AOR:CanPost()

    -- player -> class lookup for colored names
    wipe(self.classMap)
    local roster = AOR.Roster and AOR.Roster.list
    if roster then
        for _, e in ipairs(roster) do self.classMap[e.short] = e.classFile end
    end

    -- status chip + personal counter
    local locked, _, desc = R:LockInfo()
    self.status:SetLabel(string.upper(desc), locked and C.bad or C.good)
    self.mine:SetText(("YOUR RESERVES  %d / %d"):format(#R:SoftItems(Me()), R:Max()))

    if self.view == "reserves" then
        self.hint:SetShown(not officer)
        self.poolBox:SetShown(officer)
        self.lockBtn:SetShown(officer)
        self.lockBtn.text:SetText(locked and "Unlock" or "Lock Now")
        self.autoBtn:SetShown(officer and R:LockMode() ~= "A")
        self.newBtn:SetShown(officer)
        local items = R:Items()
        self.list:SetData(items)
        self.empty:SetShown(#items == 0)
        self.empty:SetText(officer and "The pool is empty. Click the box above and shift-click item links to add them."
            or "Nothing is reservable yet. Officers add items to the pool.")
    elseif self.view == "hard" then
        self.hardNote:SetShown(not officer)
        self.hardItem:SetShown(officer)
        self.hardTarget:SetShown(officer)
        self.hardBtn:SetShown(officer)
        local items = R:HardList()
        self.hardList:SetData(items)
        self.hardEmpty:SetShown(#items == 0)
    else
        self.seasonText:SetText("SEASON " .. R:Season())
        self.addPlayer:SetShown(officer)
        self.addBtn:SetShown(officer)
        self.seasonBtn:SetShown(officer)
        local data = R:Standings()
        self.standList:SetData(data)
        self.standEmpty:SetShown(#data == 0)

        local lines = {}
        for _, a in ipairs(R:RecentAwards(14)) do
            local tag = a.kind == "H" and "  |cff" .. AOR:Hex(C.ember) .. "HR|r" or "  |cff" .. AOR:Hex(C.gold) .. "+1|r"
            lines[#lines + 1] = ("|cff%s%s|r  %s  -  %s%s"):format(
                AOR:Hex(C.dim), date("%b %d", a.stamp), PlayerName(a.player), R:ColoredName(a.item), tag)
        end
        self.logText:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff" .. AOR:Hex(C.dim) .. "No awards this season.|r")
    end
end

local function Init(page)
    local x = 0
    for _, t in ipairs({ { "reserves", "Reserves", 110 }, { "hard", "Hard Reserves", 140 }, { "standings", "Standings", 110 } }) do
        local key = t[1]
        local b = UI:Button(page, t[2], t[3], 26, function() V:Show(key) end)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(V.view == key and C.ember or C.border))
        end)
        x = x + t[3] + 6
        V.tabs[key] = b
    end

    V.status = UI:Chip(page, "LOADING", C.dim, true)
    V.status:SetPoint("TOPRIGHT", 0, -1)
    V.mine = UI:Text(page, 11, C.dim)
    V.mine:SetPoint("RIGHT", V.status, "LEFT", -14, 0)
    V.mine:SetJustifyH("RIGHT")

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 0, -38)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    for _, key in ipairs({ "reserves", "hard", "standings" }) do
        local f = CreateFrame("Frame", nil, body)
        f:SetAllPoints()
        f:Hide()
        V.frames[key] = f
    end
    BuildReserves(V.frames.reserves)
    BuildHard(V.frames.hard)
    BuildStandings(V.frames.standings)
    BuildResolver(page)

    C_Timer.NewTicker(30, function()
        if page:IsVisible() then V:Refresh() end
    end)
    V:Show("reserves")
end

UI:RegisterTab("reserve", "Ember Reserve", Init, function() V:Refresh() end,
    { group = "GUILD", hint = "+1", title = "Ember Reserve" })

AOR:OnInit(function()
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
    end
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
    end
end)

AOR:Subscribe("RESERVE", function() UI:Refresh() end)

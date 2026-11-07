local _, AOR = ...
local UI, C = AOR.UI, AOR.colors
local Vt = AOR.Vault

local V = { boxes = {} }
AOR.VaultUI = V

local HEAD = "Fonts\\FRIZQT__.TTF"
local ROW_H, ROWS = 26, 18
local STATUS_RANK = { OUT = 0, LOW = 1, ["?"] = 2, OK = 3 }

local function Item() return AOR.Reserve end

local function Ago(t)
    local s = math.max(0, time() - t)
    if s < 90 then return "just now" end
    if s < 3600 then return ("%d minutes ago"):format(math.floor(s / 60)) end
    if s < 86400 then return ("%d hours ago"):format(math.floor(s / 3600)) end
    return ("%d days ago"):format(math.floor(s / 86400))
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
local function MakeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.12)
    r.hl:Hide()
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 34, 0)
    r.name:SetWidth(250)
    r.name:SetWordWrap(false)
    r.cat = UI:Text(r, 11, C.dim)
    r.cat:SetPoint("LEFT", 294, 0)
    r.cat:SetWidth(110)
    r.cat:SetWordWrap(false)
    r.count = UI:Text(r, 14, C.text, HEAD)
    r.count:SetPoint("LEFT", 414, 0)
    r.count:SetWidth(70)
    r.delta = UI:Text(r, 12, C.dim)
    r.delta:SetPoint("LEFT", 490, 0)
    r.delta:SetWidth(70)
    r.status = UI:Text(r, 11, C.text)
    r.status:SetPoint("LEFT", 568, 0)
    r.status:SetWidth(110)

    r.minBox = UI:EditBox(r, 54, 20, nil, 6)
    r.minBox:SetPoint("LEFT", 688, 0)
    r.minBox:SetJustifyH("CENTER")
    r.minBox:HookScript("OnEnterPressed", function(s)
        local row = s:GetParent().data
        local n = tonumber(s:GetText())
        if row and n then Vt:SetMin(row.id, n) end
    end)
    r.minBox:HookScript("OnEditFocusLost", function(s)
        local row = s:GetParent().data
        if row then s:SetText(tostring(row.min)) end
    end)

    r.rm = UI:Button(r, "X", 20, 20, function(s)
        local row = s:GetParent().data
        if row then Vt:Untrack(row.id) end
    end)
    r.rm:SetPoint("RIGHT", -6, 0)

    r:SetScript("OnEnter", function(s)
        s.hl:Show()
        local row = s.data
        if not row then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. row.id)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
    return r
end

local function UpdateRow(r, row, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    local R = Item()
    local _, _, _, icon = R:ItemData(row.id)
    r.icon:SetTexture(icon)
    r.name:SetText(R:ColoredName(row.id))
    r.cat:SetText(row.cat)

    local st = row.status
    if row.count == nil then
        r.count:SetText("?")
        r.count:SetTextColor(unpack(C.dim))
    else
        r.count:SetText(row.count)
        r.count:SetTextColor(unpack((st == "OUT" or st == "LOW") and C.bad or C.text))
    end

    if row.delta == nil then
        r.delta:SetText("")
    elseif row.delta == 0 then
        r.delta:SetText("-")
        r.delta:SetTextColor(unpack(C.dim))
    else
        r.delta:SetText((row.delta > 0 and "+" or "") .. row.delta)
        r.delta:SetTextColor(unpack(row.delta > 0 and C.good or C.bad))
    end

    if st == "OUT" then
        r.status:SetText("OUT OF STOCK"); r.status:SetTextColor(unpack(C.bad))
    elseif st == "LOW" then
        r.status:SetText("LOW STOCK"); r.status:SetTextColor(unpack(C.ember))
    elseif st == "OK" then
        r.status:SetText("OK"); r.status:SetTextColor(unpack(C.good))
    else
        r.status:SetText("NO DATA"); r.status:SetTextColor(unpack(C.dim))
    end

    if not r.minBox:HasFocus() then r.minBox:SetText(tostring(row.min)) end
end

------------------------------------------------------------------------
-- Data for the list
------------------------------------------------------------------------
function V:Rows()
    local R = Item()
    local rows = {}
    for _, t in ipairs(Vt:Tracked()) do
        rows[#rows + 1] = {
            id = t.id, min = t.min, cat = Vt:Category(t.id),
            count = Vt:Count(t.id), status = Vt:Status(t.id, t.min), delta = Vt:Delta(t.id),
            name = (R:ItemData(t.id)):lower(),
        }
    end
    table.sort(rows, function(a, b)
        if STATUS_RANK[a.status] ~= STATUS_RANK[b.status] then return STATUS_RANK[a.status] < STATUS_RANK[b.status] end
        if a.cat ~= b.cat then return a.cat < b.cat end
        return a.name < b.name
    end)
    return rows
end

function V:Refresh()
    if not self.list then return end
    local rows = self:Rows()
    local low, out = 0, 0
    for _, r in ipairs(rows) do
        if r.status == "LOW" then low = low + 1 elseif r.status == "OUT" then out = out + 1 end
    end
    self.list:SetData(rows)
    self.empty:SetShown(#rows == 0)

    local vals = {
        { "TRACKED", #rows, C.text },
        { "LOW STOCK", low, low > 0 and C.ember or C.good },
        { "OUT OF STOCK", out, out > 0 and C.bad or C.good },
    }
    for i, b in ipairs(self.boxes) do
        b.label:SetText(vals[i][1])
        b.value:SetText(vals[i][2])
        b.value:SetTextColor(unpack(vals[i][3]))
    end

    local snap = Vt:Snapshot()
    if snap.stamp == 0 then
        self.info:SetText("No snapshot yet. Open the guild bank to scan it.")
    else
        self.info:SetText(("Snapshot %s by %s  -  %d tab%s"):format(
            Ago(snap.stamp), snap.by ~= "" and Ambiguate(snap.by, "short") or "?", snap.tabs, snap.tabs == 1 and "" or "s"))
    end
end

local function Init(page)
    for i = 1, 3 do
        local b = UI:NewFrame(page, C.panel, C.border)
        b:SetSize(150, 46)
        b:SetPoint("TOPLEFT", (i - 1) * 158, 0)
        b.label = UI:Text(b, 10, C.dim)
        b.label:SetPoint("TOPLEFT", 12, -8)
        b.value = UI:Text(b, 18, C.text, HEAD)
        b.value:SetPoint("TOPLEFT", 12, -22)
        V.boxes[i] = b
    end
    V.info = UI:Text(page, 11, C.dim)
    V.info:SetPoint("TOPRIGHT", 0, -8)
    V.info:SetJustifyH("RIGHT")
    V.hint = UI:Text(page, 11, C.dim)
    V.hint:SetPoint("TOPRIGHT", 0, -26)
    V.hint:SetJustifyH("RIGHT")
    V.hint:SetText("Counts cover the guild bank tabs the scanning officer can view.")

    V.minBox = UI:EditBox(page, 90, 26, "Low at", 6)
    V.addBox = UI:LinkBox(page, 400, "Shift-click an item here to track it (flask, potion, stone...)", function(kind, id, name)
        if kind ~= "item" then AOR:Print("That's not an item link."); return end
        local ok, msg = Vt:Track(id, tonumber(V.minBox:GetText()))
        if ok then
            AOR:Print("Ash Vault now tracks " .. Item():ColoredName(id) .. ".")
        elseif msg then
            AOR:Print(msg)
        end
    end)
    V.addBox:SetPoint("TOPLEFT", 0, -58)
    V.minBox:SetPoint("LEFT", V.addBox, "RIGHT", 8, 0)
    V.minBox:SetJustifyH("CENTER")
    local note = UI:Text(page, 11, C.dim)
    note:SetPoint("LEFT", V.minBox, "RIGHT", 10, 0)
    note:SetText("Threshold for new items (blank = default)")

    local cols = { { "ITEM", 34 }, { "TYPE", 294 }, { "IN STOCK", 414 }, { "CHANGE", 490 }, { "STATUS", 568 }, { "LOW AT", 692 } }
    for _, c in ipairs(cols) do
        local h = UI:Text(page, 10, C.dim)
        h:SetPoint("TOPLEFT", c[2], -98)
        h:SetText(c[1])
    end
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -114)
    line:SetPoint("TOPRIGHT", 0, -114)

    V.list = UI:VirtualList(page, ROW_H, ROWS, MakeRow, 0)
    V.list:SetPoint("TOPLEFT", 0, -118)
    V.list:SetPoint("BOTTOMRIGHT", 0, 0)
    V.list.onUpdateRow = UpdateRow

    V.empty = UI:Text(page, 13, C.dim)
    V.empty:SetPoint("CENTER", 0, -50)
    V.empty:SetWidth(520)
    V.empty:SetJustifyH("CENTER")
    V.empty:SetText("Nothing tracked yet.\nClick the box above and shift-click flasks, potions and stones to start watching them.")

    C_Timer.NewTicker(30, function()
        if page:IsVisible() then V:Refresh() end
    end)
end

UI:RegisterTab("vault", "Ash Vault", Init, function() V:Refresh() end,
    { group = "OFFICERS", hint = "Bank", officer = true, title = "Ash Vault" })

AOR:Subscribe("VAULT", function() UI:Refresh() end)

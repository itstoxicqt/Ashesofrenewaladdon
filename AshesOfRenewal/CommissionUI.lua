local _, AOR = ...
local UI, C = AOR.UI, AOR.colors
local Q = AOR.Commission
local F = AOR.Forge

local V = {
    filter = "open", online = {}, classMap = {}, filterBtns = {},
}
AOR.CommissionUI = V

local HEAD = "Fonts\\FRIZQT__.TTF"
local CARD_H, CARD_GAP = 66, 4
local LIST_W, SIDE_X, SIDE_W = 600, 616, 242
local OFFLINE_HEX = "8a7f78"

local function Me() return AOR:Me() end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Whisper(name)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    open("/w " .. name .. " ")
end

local function FeeText(copper)
    if not copper or copper <= 0 then return "|cff" .. AOR:Hex(C.dim) .. "No fee listed|r" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return ("%dg %ds"):format(math.floor(copper / 10000), math.floor((copper % 10000) / 100))
end

local function Ago(t)
    local s = math.max(0, time() - t)
    if s < 90 then return "just now" end
    if s < 3600 then return ("%dm ago"):format(math.floor(s / 60)) end
    if s < 86400 then return ("%dh ago"):format(math.floor(s / 3600)) end
    return ("%dd ago"):format(math.floor(s / 86400))
end

local function Colored(name)
    return AOR:ColorName(name, V.classMap[name])
end

-- Online crafters first
local function SplitCrafters(list)
    local on, off = {}, {}
    for _, n in ipairs(list) do
        if V.online[n] then on[#on + 1] = n else off[#off + 1] = n end
    end
    table.sort(on, function(a, b) return a:lower() < b:lower() end)
    table.sort(off, function(a, b) return a:lower() < b:lower() end)
    return on, off
end

------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------
local function MakeCard(parent)
    local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
    UI:Skin(r, C.panel, C.border)
    r:RegisterForClicks("LeftButtonUp")
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(3)
    r.stripe:SetPoint("TOPLEFT", 1, -1)
    r.stripe:SetPoint("BOTTOMLEFT", 1, 1)

    r.title = UI:Text(r, 14, C.gold)
    r.title:SetPoint("TOPLEFT", 14, -9)
    r.title:SetWidth(330)
    r.title:SetWordWrap(false)
    r.fee = UI:Text(r, 12, C.text)
    r.fee:SetPoint("TOPLEFT", 356, -10)
    r.fee:SetWidth(190)
    r.fee:SetWordWrap(false)
    r.meta = UI:Text(r, 11, C.dim)
    r.meta:SetPoint("TOPLEFT", 14, -30)
    r.meta:SetWidth(556)
    r.meta:SetWordWrap(false)
    r.crafters = UI:Text(r, 12, C.text)
    r.crafters:SetPoint("TOPLEFT", 14, -47)
    r.crafters:SetWidth(400)
    r.crafters:SetWordWrap(false)

    r.del = UI:Button(r, "X", 20, 20, function(s)
        local row = s:GetParent().data
        if not row then return end
        local ok, msg = Q:Cancel(row.req.id)
        if not ok and msg then AOR:Print(msg) end
    end)
    r.del:SetPoint("TOPRIGHT", -8, -8)

    r.act = UI:Button(r, "Claim", 76, 22, function(s)
        local row = s:GetParent().data
        if not row then return end
        local id = row.req.id
        if row.status == "O" then
            local ok, msg = Q:Claim(id)
            if ok then
                AOR:Print(("You claimed %s. Whisper %s to arrange it."):format(row.req.title, row.req.author))
            elseif msg then
                AOR:Print(msg)
            end
        elseif row.status == "C" then
            Q:Unclaim(id)
        end
    end)
    r.act:SetPoint("BOTTOMRIGHT", -8, 8)

    r.done = UI:Button(r, "Done", 62, 22, function(s)
        local row = s:GetParent().data
        if row then Q:Complete(row.req.id) end
    end)
    r.done:SetPoint("RIGHT", r.act, "LEFT", -4, 0)

    r:SetScript("OnEnter", function(s)
        local row = s.data
        if not row then return end
        s:SetBackdropBorderColor(unpack(C.ember))
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(row.req.title, 1, 1, 1)
        if row.tier then GameTooltip:AddLine(row.tier, 0.6, 0.55, 0.52) end
        if row.req.notes ~= "" then GameTooltip:AddLine(row.req.notes, 0.96, 0.78, 0.36, true) end
        GameTooltip:AddLine(" ")
        if #row.on + #row.off == 0 then
            GameTooltip:AddLine("No crafter for this in the Forge ledger yet.", 0.6, 0.55, 0.52, true)
        else
            GameTooltip:AddLine("Crafters", 0.96, 0.78, 0.36)
            for _, n in ipairs(row.on) do GameTooltip:AddLine(n .. "  (online)", 0.4, 0.85, 0.45) end
            for _, n in ipairs(row.off) do GameTooltip:AddLine(n, 0.6, 0.55, 0.52) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(row.req.author == Me() and "Click: whisper an online crafter"
            or ("Click: whisper " .. row.req.author), 0.6, 0.55, 0.52)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(s)
        s:SetBackdropBorderColor(unpack(C.border))
        GameTooltip:Hide()
    end)
    r:SetScript("OnClick", function(s)
        local row = s.data
        if not row then return end
        if row.req.author ~= Me() then
            Whisper(row.req.author)
        elseif row.on[1] then
            Whisper(row.on[1])
        else
            AOR:Print("No crafter for that request is online right now.")
        end
    end)
    return r
end

local function UpdateCard(r, row)
    local req, status = row.req, row.status
    r.title:SetText(req.title)
    r.fee:SetText(FeeText(req.fee))

    local meta = ("by %s  -  %s"):format(Colored(req.author), Ago(req.at))
    local flags = Q:FlagText(req.flags)
    if flags ~= "" then meta = meta .. "  -  |cff" .. AOR:Hex(C.ember) .. flags .. "|r" end
    if status == "C" then
        meta = meta .. ("  -  |cff%sCLAIMED BY|r %s"):format(AOR:Hex(C.gold), Colored(row.state.by))
    elseif status == "D" then
        meta = meta .. "  -  |cff" .. AOR:Hex(C.dim) .. "DONE|r"
    end
    r.meta:SetText(meta)

    -- crafter presence
    local on, off = row.on, row.off
    if status == "D" then
        r.crafters:SetText("")
    elseif #on > 0 then
        local names = {}
        for i, n in ipairs(on) do
            if i > 3 then names[#names + 1] = ("+%d"):format(#on - 3); break end
            names[#names + 1] = Colored(n)
        end
        r.crafters:SetText(("|cff%sCrafters online:|r %s"):format(AOR:Hex(C.good), table.concat(names, ", ")))
    elseif #off > 0 then
        r.crafters:SetText(("|cff%sNo crafters online (%d known)|r"):format(OFFLINE_HEX, #off))
    else
        r.crafters:SetText("|cff" .. OFFLINE_HEX .. "No crafter in the ledger yet|r")
    end

    -- stripe: green = a crafter is online, ember = open, grey = claimed/done
    if status == "D" then
        r.stripe:SetColorTexture(0.3, 0.27, 0.26, 1)
    elseif status == "C" then
        r.stripe:SetColorTexture(unpack(C.gold))
    elseif #on > 0 then
        r.stripe:SetColorTexture(unpack(C.good))
    else
        r.stripe:SetColorTexture(unpack(C.ember))
    end

    local mine = (req.author == Me())
    local claimer = (status == "C" and row.state.by == Me())
    r.del:SetShown(mine or AOR:CanPost())

    if status == "O" and not mine then
        r.act.text:SetText("Claim")
        r.act:Show()
    elseif claimer then
        r.act.text:SetText("Unclaim")
        r.act:Show()
    else
        r.act:Hide()
    end
    r.done:SetShown(status == "C" and (mine or claimer))
    r.done.text:SetText(mine and "Received" or "Done")
    r.done:SetWidth(mine and 74 or 62)
end

------------------------------------------------------------------------
-- Composer
------------------------------------------------------------------------
local linkBoxes = {}

local function OnInsertLink(text)
    if type(text) ~= "string" then return end
    local kind, id = text:match("|H(%a+):(%d+)")
    if kind ~= "enchant" and kind ~= "spell" and kind ~= "item" then return end
    local name = text:match("%[(.-)%]")
    if V.lastLink == text and V.lastAt and GetTime() - V.lastAt < 0.3 then return end
    for _, b in ipairs(linkBoxes) do
        if b:IsVisible() and b:HasFocus() then
            V.lastLink, V.lastAt = text, GetTime()
            b:Receive(kind, tonumber(id), name)
            return
        end
    end
end

local function BuildComposer(page)
    local f = UI:NewFrame(page, C.bg, C.ember)
    f:SetSize(640, 336)
    f:SetPoint("CENTER", 0, 10)
    f:SetFrameLevel(page:GetFrameLevel() + 40)
    f:EnableMouse(true)
    f:Hide()
    V.composer = f

    local head = UI:Text(f, 16, C.gold, HEAD)
    head:SetPoint("TOPLEFT", 14, -12)
    head:SetText("New Craft Request")

    local lbl = UI:Text(f, 10, C.dim)
    lbl:SetPoint("TOPLEFT", 14, -40)
    lbl:SetText("WHAT DO YOU NEED?")

    local box = UI:EditBox(f, 612, 26, "Type a recipe name, or shift-click a recipe or item link", 120)
    box:SetPoint("TOPLEFT", 14, -54)
    box.recipe = nil
    local sugg = {}
    local function Suggest()
        for _, b in ipairs(sugg) do b:Hide() end
        local text = strtrim(box:GetText() or "")
        if box.recipe or #text < 2 or not F then return end
        local rows = F:Query(nil, text, false, {})
        for i = 1, math.min(#sugg, #rows) do
            local row = rows[i]
            local b = sugg[i]
            b.row = row
            local n, on = #row.e.crafters, 0
            for _, c in ipairs(row.e.crafters) do if V.online[c] then on = on + 1 end end
            b.text:SetText(("%s   |cff%s%s  -  %d crafter%s, %d online|r"):format(
                row.name, AOR:Hex(C.dim), row.e.prof, n, n == 1 and "" or "s", on))
            b:Show()
        end
    end
    function box:Receive(kind, id, name)
        self.settingText = true
        if kind == "item" then
            self.recipe = nil
            self:SetText(name or ((AOR.Reserve and AOR.Reserve:ItemData(id)) or ("item " .. id)))
        else
            self.recipe = id
            self:SetText(name or (F and (F:SpellData(id))) or ("recipe " .. id))
        end
        self.settingText = false
        Suggest()
    end
    box:HookScript("OnTextChanged", function(s)
        if s.settingText then return end
        s.recipe = nil
        Suggest()
    end)
    linkBoxes[#linkBoxes + 1] = box

    for i = 1, 4 do
        local b = UI:Button(f, "", 612, 22, function(s)
            if not s.row then return end
            box.settingText = true
            box:SetText(s.row.name)
            box.settingText = false
            box.recipe = s.row.id
            for _, x in ipairs(sugg) do x:Hide() end
        end)
        b:SetPoint("TOPLEFT", 14, -84 - (i - 1) * 24)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 10, 0)
        b.text:SetWidth(592)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:Hide()
        sugg[i] = b
    end

    local feeLbl = UI:Text(f, 10, C.dim)
    feeLbl:SetPoint("TOPLEFT", 14, -186)
    feeLbl:SetText("PROCESSING FEE (GOLD)")
    local fee = UI:EditBox(f, 140, 26, "0", 8)
    fee:SetPoint("TOPLEFT", 14, -200)

    local flagLbl = UI:Text(f, 10, C.dim)
    flagLbl:SetPoint("TOPLEFT", 180, -186)
    flagLbl:SetText("FLAGS")
    local checks = {}
    for i, key in ipairs(Q.FLAG_ORDER) do
        local ck = UI:Check(f, Q.FLAGS[key], nil)
        ck:SetSize(120, 20)
        ck:SetPoint("TOPLEFT", 180 + (i - 1) * 130, -206)
        ck.key = key
        checks[#checks + 1] = ck
    end

    local notes = UI:EditBox(f, 612, 26, "Notes (optional, short)", 80)
    notes:SetPoint("TOPLEFT", 14, -240)

    local err = UI:Text(f, 12, C.bad)
    err:SetPoint("TOPLEFT", 14, -274)
    err:SetWidth(612)

    local function Reset()
        box.recipe = nil
        box.settingText = true
        box:SetText("")
        box.settingText = false
        fee:SetText("")
        notes:SetText("")
        for _, ck in ipairs(checks) do ck:SetChecked(false) end
        for _, b in ipairs(sugg) do b:Hide() end
        err:SetText("")
    end

    local post = UI:Button(f, "Post Request", 120, 26, function()
        err:SetText("")
        local title = strtrim(box:GetText() or "")
        local gold = strtrim(fee:GetText() or "")
        local copper = 0
        if gold ~= "" then
            local g = tonumber(gold)
            if not g or g < 0 then err:SetText("Fee should be a number of gold, like 25."); return end
            copper = math.floor(g * 10000)
        end
        local flags = ""
        for _, ck in ipairs(checks) do if ck.checked then flags = flags .. ck.key end end
        local ok, msg = Q:Post(box.recipe, title, copper, flags, strtrim(notes:GetText() or ""))
        if not ok then err:SetText(msg or "Couldn't post that."); return end
        Reset()
        f:Hide()
    end)
    post:SetPoint("BOTTOMLEFT", 14, 14)
    local cancel = UI:Button(f, "Cancel", 80, 26, function() Reset(); f:Hide() end)
    cancel:SetPoint("LEFT", post, "RIGHT", 8, 0)
end

------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------
local FILTERS = {
    { "open", "Open", 80 }, { "fill", "I can craft", 100 }, { "mine", "Mine", 70 }, { "done", "Done", 70 },
}

function V:SetFilter(key)
    self.filter = key
    self:Refresh()
end

function V:Rows()
    local out = {}
    local me_ = Me()
    local myCrafts = {}
    for _, r in ipairs(Q:All()) do
        local list, tier = Q:Crafters(r.req)
        local on, off = SplitCrafters(list)
        local canFill = false
        for _, n in ipairs(list) do if n == me_ then canFill = true end end
        local keep
        if self.filter == "open" then keep = r.status ~= "D"
        elseif self.filter == "mine" then keep = r.req.author == me_
        elseif self.filter == "fill" then keep = r.status ~= "D" and r.req.author ~= me_ and canFill
        else keep = r.status == "D" end
        r.on, r.off, r.tier, r.canFill = on, off, tier, canFill
        r.list = list
        if keep then out[#out + 1] = r end
        r.keep = keep
    end
    local rank = { O = 0, C = 1, D = 2 }
    table.sort(out, function(a, b)
        if rank[a.status] ~= rank[b.status] then return rank[a.status] < rank[b.status] end
        return a.req.stamp > b.req.stamp
    end)
    return out
end

function V:Refresh()
    if not self.list then return end

    wipe(self.online)
    wipe(self.classMap)
    local roster = AOR.Roster and AOR.Roster.list
    if roster then
        for _, e in ipairs(roster) do
            self.classMap[e.short] = e.classFile
            if e.online then self.online[e.short] = true end
        end
    end

    for key, b in pairs(self.filterBtns) do
        b:SetBackdropBorderColor(unpack(key == self.filter and C.ember or C.border))
    end

    local rows = self:Rows()
    self.list:SetData(rows)
    local msgs = {
        open = "No open requests. Use New Request to pin one.",
        fill = "Nothing open that you can craft right now.",
        mine = "You haven't posted any requests.",
        done = "No completed requests yet.",
    }
    self.empty:SetText(msgs[self.filter])
    self.empty:SetShown(#rows == 0)
    self.newBtn:SetShown(IsInGuild())

    -- crafters online who can fill open requests
    local counts = {}
    local openTotal = 0
    for _, r in ipairs(Q:All()) do
        if r.status ~= "D" then
            openTotal = openTotal + 1
            local list = Q:Crafters(r.req)
            for _, n in ipairs(list) do
                if self.online[n] and n ~= r.req.author then counts[n] = (counts[n] or 0) + 1 end
            end
        end
    end
    local people = {}
    for n, c in pairs(counts) do people[#people + 1] = { n = n, c = c } end
    table.sort(people, function(a, b)
        if a.c ~= b.c then return a.c > b.c end
        return a.n:lower() < b.n:lower()
    end)
    local lines = {}
    for i, p in ipairs(people) do
        if i > 16 then lines[#lines + 1] = ("|cff%s+%d more|r"):format(AOR:Hex(C.dim), #people - 16); break end
        lines[#lines + 1] = ("%s   |cff%s%d open|r"):format(Colored(p.n), AOR:Hex(C.good), p.c)
    end
    if #lines == 0 then
        lines[1] = "|cff" .. AOR:Hex(C.dim) .. (openTotal > 0 and "Nobody online can fill the open requests right now." or "No open requests.") .. "|r"
    end
    self.presence:SetText(table.concat(lines, "\n"))
    self.info:SetText(("%d open  -  %d unclaimed"):format(openTotal, Q:UnclaimedCount()))
end

local function Init(page)
    local x = 0
    for _, t in ipairs(FILTERS) do
        local key = t[1]
        local b = UI:Button(page, t[2], t[3], 26, function() V:SetFilter(key) end)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(V.filter == key and C.ember or C.border))
        end)
        x = x + t[3] + 6
        V.filterBtns[key] = b
    end

    V.newBtn = UI:Button(page, "+ New Request", 130, 26, function()
        V.composer:SetShown(not V.composer:IsShown())
    end)
    V.newBtn:SetPoint("TOPRIGHT", 0, 0)
    V.info = UI:Text(page, 11, C.dim)
    V.info:SetPoint("RIGHT", V.newBtn, "LEFT", -14, 0)
    V.info:SetJustifyH("RIGHT")

    V.list = UI:VirtualList(page, CARD_H, 8, MakeCard, CARD_GAP)
    V.list:SetPoint("TOPLEFT", 0, -38)
    V.list:SetPoint("BOTTOMLEFT", 0, 0)
    V.list:SetWidth(LIST_W)
    V.list.onUpdateRow = UpdateCard

    V.empty = UI:Text(page, 13, C.dim)
    V.empty:SetPoint("TOPLEFT", LIST_W / 2 - 160, -120)
    V.empty:SetWidth(320)
    V.empty:SetJustifyH("CENTER")

    local side = UI:Card(page, "Crafters Online", SIDE_W, 420)
    side:SetPoint("TOPLEFT", SIDE_X, -38)
    V.presence = UI:Text(side, 12, C.text)
    V.presence:SetPoint("TOPLEFT", 12, -40)
    V.presence:SetSize(SIDE_W - 24, 370)
    V.presence:SetJustifyV("TOP")
    V.presence:SetWordWrap(true)
    V.presence:SetSpacing(5)

    BuildComposer(page)

    C_Timer.NewTicker(30, function()
        if page:IsVisible() then V:Refresh() end
    end)
end

UI:RegisterTab("commission", "Commission", Init, function() V:Refresh() end,
    { group = "GUILD", hint = "Requests", title = "Commission" })

AOR:OnInit(function()
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
    end
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
    end
end)

AOR:Subscribe("COMMISSION", function() UI:Refresh() end)
AOR:Subscribe("FORGE", function() UI:Refresh() end)

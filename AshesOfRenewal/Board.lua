local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

local B = {}
AOR.Board = B

local PREFIX = AOR.prefix
local DAY = 86400
local MAX_TITLE, MAX_BODY = 36, 120
local pending = {}

local function store() return AOR.db.board end

local function clean(s)
    return (tostring(s or ""):gsub("|", "/"):gsub("[\r\n]", " "))
end

local function IsOfficer(author)
    local short = Ambiguate(author or "", "short")
    local ri = AOR.rosterRank[short]
    return ri ~= nil and AOR:RankCanPost(AOR.rosterRankName[short], ri)
end

local function Send(msg)
    if IsInGuild() then C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD") end
end

function B.Countdown(t)
    local d = t - time()
    if d <= 0 then return "Happening now" end
    local days, hrs, mins = math.floor(d / DAY), math.floor((d % DAY) / 3600), math.floor((d % 3600) / 60)
    if days > 0 then return ("in %dd %dh"):format(days, hrs) end
    if hrs > 0 then return ("in %dh %dm"):format(hrs, mins) end
    return ("in %dm"):format(math.max(mins, 1))
end

------------------------------------------------------------------------
-- Encoding / sync
------------------------------------------------------------------------
local function Encode(e)
    return table.concat({
        "P", e.id, e.stamp, e.kind, e.evt, e.deleted and 1 or 0,
        clean(e.author), clean(e.title), clean(e.body),
    }, "|")
end

local function Decode(msg)
    local tag, id, stamp, kind, evt, del, author, title, body = strsplit("|", msg)
    if tag ~= "P" or not id or not body then return end
    stamp, evt = tonumber(stamp), tonumber(evt)
    if not stamp or not evt or (kind ~= "E" and kind ~= "A") then return end
    return { id = id, stamp = stamp, kind = kind, evt = evt, deleted = (del == "1"),
             author = author, title = title, body = body }
end

function B:Apply(e, trusted)
    if not trusted and not IsOfficer(e.author) then return false end
    local cur = store()[e.id]
    if cur and cur.stamp >= e.stamp then return false end
    store()[e.id] = e
    return true
end

function B:MaxStamp()
    local m = 0
    for _, e in pairs(store()) do if e.stamp > m then m = e.stamp end end
    return m
end

function B:Respond(since)
    local out = {}
    for _, e in pairs(store()) do
        if e.stamp >= since - 5 then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.stamp > b.stamp end)
    for i = 1, math.min(#out, 12) do
        local e = out[i]
        pending[e.id] = e.stamp
        C_Timer.After(1 + math.random() * 5 + i * 0.5, function()
            -- skip if someone else already sent this exact entry
            if pending[e.id] == e.stamp then
                pending[e.id] = nil
                Send(Encode(e))
            end
        end)
    end
end

function B:Prune()
    local now = time()
    for id, e in pairs(store()) do
        if e.stamp < now - 45 * DAY or (e.kind == "E" and e.evt > 0 and e.evt < now - 7 * DAY) then
            store()[id] = nil
        end
    end
end

------------------------------------------------------------------------
-- Posting
------------------------------------------------------------------------
function B:Post(kind, title, body, evt)
    local now = time()
    local e = {
        id = now .. "-" .. math.random(100, 999), stamp = now, kind = kind, evt = evt or 0,
        author = GetUnitName("player", true), title = clean(title), body = clean(body),
    }
    store()[e.id] = e
    Send(Encode(e))
    AOR:Fire("BOARD")
end

function B:Delete(id)
    local cur = store()[id]
    if not cur then return end
    local e = {
        id = id, stamp = math.max(time(), cur.stamp + 1), kind = cur.kind, evt = cur.evt,
        author = GetUnitName("player", true), title = "", body = "", deleted = true,
    }
    store()[id] = e
    Send(Encode(e))
    AOR:Fire("BOARD")
end

function B:GetList()
    local now = time()
    local events, notes = {}, {}
    for _, e in pairs(store()) do
        if not e.deleted then
            if e.kind == "E" then
                if e.evt >= now - 3600 then events[#events + 1] = e end
            elseif e.stamp >= now - 30 * DAY then
                notes[#notes + 1] = e
            end
        end
    end
    table.sort(events, function(a, b) return a.evt < b.evt end)
    table.sort(notes, function(a, b) return a.stamp > b.stamp end)
    for _, e in ipairs(notes) do events[#events + 1] = e end
    return events
end

function B:GetNext()
    local now, best = time(), nil
    for _, e in pairs(store()) do
        if not e.deleted and e.kind == "E" and e.evt >= now - 3600 then
            if not best or e.evt < best.evt then best = e end
        end
    end
    return best
end

-- Upcoming events and fresh announcements within the last/next 7 days
function B:Counts()
    local now, events, news = time(), 0, 0
    for _, e in pairs(store()) do
        if not e.deleted then
            if e.kind == "E" then
                if e.evt >= now - 3600 and e.evt <= now + 7 * DAY then events = events + 1 end
            elseif e.stamp >= now - 7 * DAY then
                news = news + 1
            end
        end
    end
    return events, news
end

function B:GetLatestNote()
    local now, best = time(), nil
    for _, e in pairs(store()) do
        if not e.deleted and e.kind == "A" and e.stamp >= now - 30 * DAY then
            if not best or e.stamp > best.stamp then best = e end
        end
    end
    return best
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local function MakeCard(parent)
    local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
    UI:Skin(r, C.panel, C.border)
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(3)
    r.stripe:SetPoint("TOPLEFT", 1, -1)
    r.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    r.title = UI:Text(r, 14, C.gold)
    r.title:SetPoint("TOPLEFT", 14, -10)
    r.title:SetWidth(620)
    r.title:SetWordWrap(false)
    r.sub = UI:Text(r, 11, C.dim)
    r.sub:SetPoint("TOPLEFT", 14, -30)
    r.sub:SetWidth(640)
    r.sub:SetWordWrap(false)
    r.body = UI:Text(r, 12, C.text)
    r.body:SetPoint("TOPLEFT", 14, -48)
    r.body:SetSize(640, 28)
    r.body:SetJustifyV("TOP")
    r.body:SetWordWrap(true)
    r.del = UI:Button(r, "X", 22, 22, function(s) B:Delete(s:GetParent().data.id) end)
    r.del:SetPoint("TOPRIGHT", -8, -8)
    return r
end

local function UpdateCard(r, e)
    local isEvent = (e.kind == "E")
    r.stripe:SetColorTexture(unpack(isEvent and C.ember or C.gold))
    r.title:SetText(e.title)
    local who = Ambiguate(e.author or "?", "short")
    if isEvent then
        r.sub:SetText(("EVENT  -  %s  -  |cff%s%s|r  -  posted by %s"):format(
            date("%a %b %d, %I:%M %p", e.evt), AOR:Hex(C.ember), B.Countdown(e.evt), who))
    else
        r.sub:SetText(("ANNOUNCEMENT  -  %s  -  posted by %s"):format(date("%b %d", e.stamp), who))
    end
    r.body:SetText(e.body)
    r.del:SetShown(AOR:CanPost())
end

local function Refresh()
    if not B.list then return end
    local data = B:GetList()
    B.list:SetData(data)
    B.empty:SetShown(#data == 0)
    B.newBtn:SetShown(AOR:CanPost())
    if not AOR:CanPost() then B.composer:Hide() end
end

-- Accepts dates like 2026-11-08 (or 2026/11/08) and times like 20:00, 8:00pm, 8pm
local function ParseWhen(dText, tText)
    local y, m, d = strmatch(strtrim(dText), "^(%d%d%d%d)[%-/%.](%d%d?)[%-/%.](%d%d?)$")
    if not y then return nil, "Date should look like 2026-11-08 (year-month-day)." end
    local t = (strlower(strtrim(tText)):gsub("%s+", ""))
    local hh, mm, ap = strmatch(t, "^(%d%d?):(%d%d)(%a*)$")
    if not hh then
        hh, ap = strmatch(t, "^(%d%d?)(%a+)$")
        mm = "0"
    end
    if not hh or (ap ~= "" and ap ~= "am" and ap ~= "pm") then
        return nil, "Time should look like 20:00 or 8:00pm."
    end
    y, m, d, hh, mm = tonumber(y), tonumber(m), tonumber(d), tonumber(hh), tonumber(mm)
    if ap == "pm" and hh < 12 then hh = hh + 12 elseif ap == "am" and hh == 12 then hh = 0 end
    if m < 1 or m > 12 or d < 1 or d > 31 or hh > 23 or mm > 59 then
        return nil, "That date or time doesn't look right."
    end
    local evt = time({ year = y, month = m, day = d, hour = hh, min = mm, sec = 0 })
    if not evt or tonumber(date("%d", evt)) ~= d then return nil, "That date doesn't exist." end
    if evt < time() then return nil, "That time is in the past." end
    return evt
end

local function BuildComposer(page)
    local f = UI:NewFrame(page, C.panel, C.ember)
    f:SetPoint("TOPLEFT", 0, -36)
    f:SetSize(736, 222)
    f:SetFrameLevel(page:GetFrameLevel() + 30)
    f:Hide()
    B.composer = f

    local kind = "E"
    local kE, kA, dateBox, timeBox
    local function style()
        kE:SetBackdropBorderColor(unpack(kind == "E" and C.ember or C.border))
        kA:SetBackdropBorderColor(unpack(kind == "A" and C.ember or C.border))
        dateBox:SetShown(kind == "E")
        timeBox:SetShown(kind == "E")
    end
    kE = UI:Button(f, "Event", 100, 24, function() kind = "E"; style() end)
    kE:SetPoint("TOPLEFT", 12, -12)
    kA = UI:Button(f, "Announcement", 130, 24, function() kind = "A"; style() end)
    kA:SetPoint("LEFT", kE, "RIGHT", 6, 0)
    for _, b in ipairs({ kE, kA }) do
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(((s == kE and kind == "E") or (s == kA and kind == "A")) and C.ember or C.border))
        end)
    end

    local title = UI:EditBox(f, 712, 26, "Title (e.g. Heroic raid night)", MAX_TITLE)
    title:SetPoint("TOPLEFT", 12, -48)
    dateBox = UI:EditBox(f, 150, 26, "YYYY-MM-DD", 20)
    dateBox:SetPoint("TOPLEFT", 12, -84)
    timeBox = UI:EditBox(f, 150, 26, "8:00pm or 20:00", 16)
    timeBox:SetPoint("LEFT", dateBox, "RIGHT", 8, 0)
    local tz = UI:Text(f, 11, C.dim)
    tz:SetPoint("LEFT", timeBox, "RIGHT", 10, 0)
    tz:SetText("Your local time. Everyone sees it in theirs.")
    local body = UI:EditBox(f, 712, 26, "Details (optional, short)", MAX_BODY)
    body:SetPoint("TOPLEFT", 12, -120)

    local err = UI:Text(f, 12, C.bad)
    err:SetPoint("TOPLEFT", 12, -156)

    local post = UI:Button(f, "Post to Guild", 120, 26, function()
        err:SetText("")
        local t = strtrim(title:GetText())
        if t == "" then err:SetText("Give it a title."); return end
        local evt
        if kind == "E" then
            local when, msg = ParseWhen(dateBox:GetText(), timeBox:GetText())
            if not when then err:SetText(msg); return end
            evt = when
        end
        B:Post(kind, t, strtrim(body:GetText()), evt)
        title:SetText(""); dateBox:SetText(""); timeBox:SetText(""); body:SetText("")
        f:Hide()
    end)
    post:SetPoint("TOPLEFT", 12, -184)
    local cancel = UI:Button(f, "Cancel", 80, 26, function() f:Hide() end)
    cancel:SetPoint("LEFT", post, "RIGHT", 8, 0)
    style()
end

local function Init(page)
    local head = UI:Text(page, 12, C.dim)
    head:SetPoint("TOPLEFT", 2, -8)
    head:SetText("Upcoming events and guild announcements. Synced automatically between members.")

    B.newBtn = UI:Button(page, "+ New Post", 110, 26, function()
        B.composer:SetShown(not B.composer:IsShown())
    end)
    B.newBtn:SetPoint("TOPRIGHT", 0, -2)

    B.list = UI:VirtualList(page, 82, 6, MakeCard, 6)
    B.list:SetPoint("TOPLEFT", 0, -36)
    B.list:SetPoint("BOTTOMRIGHT", 0, 0)
    B.list.onUpdateRow = UpdateCard

    B.empty = UI:Text(page, 14, C.dim)
    B.empty:SetPoint("CENTER", 0, -20)
    B.empty:SetText("Nothing posted yet. Officers can add events and announcements.")

    BuildComposer(page)
end

UI:RegisterTab("board", "Conclave", Init, Refresh, { group = "RAID", hint = "Events", title = "Conclave" })

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    B:Prune()
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not text then return end
    local mine = Ambiguate(sender or "", "short") == AOR:Me()
    local tag = text:sub(1, 1)
    if tag == "P" then
        local e = Decode(text)
        if not e then return end
        if pending[e.id] and pending[e.id] <= e.stamp then pending[e.id] = nil end
        if not mine and B:Apply(e) then
            AOR:Fire("BOARD")
            if not e.deleted then AOR:Fire("BOARD_NEW", e) end
        end
    elseif tag == "R" and not mine then
        B:Respond(tonumber(text:match("^R|(%d+)")) or 0)
    end
end)

-- Ask the guild for anything we missed, once per login, after the roster is known
local synced
AOR:Subscribe("ROSTER", function()
    if synced or not IsInGuild() or not AOR.db then return end
    synced = true
    C_Timer.After(3, function() Send("R|" .. B:MaxStamp()) end)
end)

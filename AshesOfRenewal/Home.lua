local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

local H = {}
AOR.Home = H

local HEAD = "Fonts\\FRIZQT__.TTF"
local DAY = 86400

-- Layout (content area is ~858 x 606)
local LEFT_W, RIGHT_W, GAP = 518, 324, 16
local RIGHT_X = LEFT_W + GAP

local function Dur(s)
    if not s or s <= 0 then return "now" end
    local d, h, m = math.floor(s / DAY), math.floor((s % DAY) / 3600), math.floor((s % 3600) / 60)
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(math.max(m, 1))
end

local function Gold(n) return "|cff" .. AOR:Hex(C.gold) .. n .. "|r" end

local function StatBox(parent, label)
    local b = UI:NewFrame(parent, C.panel, C.border)
    b:SetSize(84, 58)
    b.value = UI:Text(b, 20, C.gold, HEAD)
    b.value:SetPoint("TOP", 0, -10)
    b.value:SetWidth(80)
    b.value:SetJustifyH("CENTER")
    b.label = UI:Text(b, 9, C.dim)
    b.label:SetPoint("BOTTOM", 0, 9)
    b.label:SetWidth(80)
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    return b
end

local function TimeBox(parent, label)
    local b = UI:NewFrame(parent, C.bg, C.border)
    b:SetSize(66, 54)
    b.value = UI:Text(b, 20, C.text, HEAD)
    b.value:SetPoint("TOP", 0, -9)
    b.value:SetWidth(62)
    b.value:SetJustifyH("CENTER")
    b.label = UI:Text(b, 9, C.dim)
    b.label:SetPoint("BOTTOM", 0, 7)
    b.label:SetWidth(62)
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    return b
end

local function Init(page)
    ----------------------------------------------------------------
    -- Headline + stats
    ----------------------------------------------------------------
    H.headline = UI:Text(page, 26, C.text, HEAD)
    H.headline:SetPoint("TOPLEFT", 0, -2)
    H.headline:SetWidth(520)
    H.headline:SetWordWrap(false)

    H.sub = UI:Text(page, 12, C.dim)
    H.sub:SetPoint("TOPLEFT", 0, -42)
    H.sub:SetWidth(560)
    H.sub:SetWordWrap(false)

    H.statOnline = StatBox(page, "ONLINE")
    H.statOnline:SetPoint("TOPRIGHT", 0, 0)
    H.statEvents = StatBox(page, "EVENTS")
    H.statEvents:SetPoint("RIGHT", H.statOnline, "LEFT", -8, 0)
    H.statNews = StatBox(page, "NEWS")
    H.statNews:SetPoint("RIGHT", H.statEvents, "LEFT", -8, 0)

    ----------------------------------------------------------------
    -- Row 1: Next Conclave + Server Timers
    ----------------------------------------------------------------
    local ev = UI:Card(page, "Next Conclave", LEFT_W, 188)
    ev:SetPoint("TOPLEFT", 0, -84)

    H.evChip = UI:Chip(ev, "EVENT", C.ember)
    H.evChip:SetPoint("TOPRIGHT", -12, -3)

    H.evTitle = UI:Text(ev, 18, C.gold, HEAD)
    H.evTitle:SetPoint("TOPLEFT", 12, -40)
    H.evTitle:SetWidth(480)
    H.evTitle:SetWordWrap(false)
    H.evWhen = UI:Text(ev, 12, C.dim)
    H.evWhen:SetPoint("TOPLEFT", 12, -66)
    H.evWhen:SetWidth(480)
    H.evWhen:SetWordWrap(false)

    H.boxDays = TimeBox(ev, "DAYS")
    H.boxDays:SetPoint("TOPLEFT", 12, -90)
    H.boxHours = TimeBox(ev, "HOURS")
    H.boxHours:SetPoint("LEFT", H.boxDays, "RIGHT", 8, 0)
    H.boxMins = TimeBox(ev, "MIN")
    H.boxMins:SetPoint("LEFT", H.boxHours, "RIGHT", 8, 0)

    H.evBody = UI:Text(ev, 12, C.text)
    H.evBody:SetPoint("TOPLEFT", 244, -92)
    H.evBody:SetSize(262, 52)
    H.evBody:SetJustifyV("TOP")
    H.evBody:SetWordWrap(true)

    H.evMeta = UI:Text(ev, 10, C.dim)
    H.evMeta:SetPoint("BOTTOMLEFT", 12, 14)
    H.evMeta:SetWidth(300)

    H.evEmpty = UI:Text(ev, 14, C.dim)
    H.evEmpty:SetPoint("TOPLEFT", 12, -48)
    H.evEmpty:SetWidth(480)
    H.evEmpty:SetText("Nothing scheduled.")
    H.evHint = UI:Text(ev, 11, C.dim)
    H.evHint:SetPoint("TOPLEFT", 12, -72)
    H.evHint:SetWidth(480)

    local openBoard = UI:Button(ev, "OPEN CONCLAVE", 130, 24, function() UI:Open("board") end)
    openBoard:SetPoint("BOTTOMRIGHT", -12, 10)

    local timers = UI:Card(page, "Server Timers", RIGHT_W, 188)
    timers:SetPoint("TOPLEFT", RIGHT_X, -84)
    H.timerRows = {}
    local rows = { "SERVER TIME", "DAILY RESET", "WEEKLY RESET", "YOUR RANK" }
    for i, label in ipairs(rows) do
        local y = -44 - (i - 1) * 32
        local l = UI:Text(timers, 10, C.dim)
        l:SetPoint("TOPLEFT", 12, y - 4)
        l:SetText(label)
        local v = UI:Text(timers, 15, C.gold, HEAD)
        v:SetPoint("TOPRIGHT", -12, y)
        v:SetWidth(180)
        v:SetJustifyH("RIGHT")
        H.timerRows[i] = v
        if i < #rows then
            local line = timers:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 0.05)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", 12, y - 24)
            line:SetPoint("TOPRIGHT", -12, y - 24)
        end
    end

    ----------------------------------------------------------------
    -- Row 2, left: MOTD + Guild Information
    ----------------------------------------------------------------
    local motd = UI:Card(page, "Message of the Day", LEFT_W, 104)
    motd:SetPoint("TOPLEFT", 0, -288)
    H.motd = UI:Text(motd, 13, C.text)
    H.motd:SetPoint("TOPLEFT", 12, -38)
    H.motd:SetSize(LEFT_W - 24, 58)
    H.motd:SetJustifyV("TOP")
    H.motd:SetWordWrap(true)

    local info = UI:Card(page, "Guild Information", LEFT_W, 138)
    info:SetPoint("TOPLEFT", 0, -408)
    H.info = UI:Text(info, 12, C.text)
    H.info:SetPoint("TOPLEFT", 12, -38)
    H.info:SetSize(LEFT_W - 24, 92)
    H.info:SetJustifyV("TOP")
    H.info:SetWordWrap(true)

    ----------------------------------------------------------------
    -- Row 2, right: Latest announcement + Links
    ----------------------------------------------------------------
    local news = UI:Card(page, "Latest Announcement", RIGHT_W, 112)
    news:SetPoint("TOPLEFT", RIGHT_X, -288)
    H.nTitle = UI:Text(news, 14, C.gold)
    H.nTitle:SetPoint("TOPLEFT", 12, -38)
    H.nTitle:SetWidth(RIGHT_W - 24)
    H.nTitle:SetWordWrap(false)
    H.nBody = UI:Text(news, 12, C.text)
    H.nBody:SetPoint("TOPLEFT", 12, -58)
    H.nBody:SetSize(RIGHT_W - 24, 30)
    H.nBody:SetJustifyV("TOP")
    H.nBody:SetWordWrap(true)
    H.nMeta = UI:Text(news, 10, C.dim)
    H.nMeta:SetPoint("BOTTOMLEFT", 12, 9)
    H.nMeta:SetWidth(RIGHT_W - 24)

    local links = UI:Card(page, "Guild Links", RIGHT_W, 130)
    links:SetPoint("TOPLEFT", RIGHT_X, -416)
    local y = -38
    for _, l in ipairs(AOR.config.links) do
        if l.url and l.url ~= "" and y > -118 then
            local b = UI:Button(links, l.label, RIGHT_W - 24, 24, function() UI:CopyBox(l.label, l.url) end)
            b:SetPoint("TOPLEFT", 12, y)
            y = y - 28
        end
    end

    ----------------------------------------------------------------
    -- Officer attention strip
    ----------------------------------------------------------------
    local strip = UI:NewFrame(page, { 0.135, 0.085, 0.055, 1 }, { C.ember[1], C.ember[2], C.ember[3], 0.45 })
    strip:SetHeight(44)
    strip:SetPoint("BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", 0, 0)
    H.strip = strip
    local label = UI:Text(strip, 10, C.ember)
    label:SetPoint("LEFT", 14, 0)
    label:SetText("NEEDS ATTENTION")
    H.attText = UI:Text(strip, 12, C.text)
    H.attText:SetPoint("LEFT", 134, 0)
    H.attText:SetWidth(610)
    H.attText:SetWordWrap(false)
    H.attBtn = UI:Button(strip, "REVIEW", 76, 24, function()
        if H.attTab then UI:Open(H.attTab) end
    end)
    H.attBtn:SetPoint("RIGHT", -10, 0)

    -- keep countdowns and timers fresh while the page is open
    C_Timer.NewTicker(20, function()
        if page:IsVisible() then H:Refresh() end
    end)
end

------------------------------------------------------------------------
-- Officer flags
------------------------------------------------------------------------
local function Flags()
    local f = {}
    local B, R, S = AOR.Board, AOR.Roster, AOR.Sync

    if B and not B:GetNext() then
        f[#f + 1] = { "No upcoming event scheduled", "board" }
    end

    if S then
        local missing, old = S:Coverage()
        if missing > 0 then
            f[#f + 1] = { Gold(missing) .. " online without the addon", "roster" }
        end
        if old > 0 then
            f[#f + 1] = { Gold(old) .. " on an older addon version", "roster" }
        end
    end

    if AOR.Forge and AOR.loginAt and GetTime() - AOR.loginAt > 40 then
        local n = AOR.Forge:UnsyncedOnline()
        if n > 0 then
            f[#f + 1] = { Gold(n) .. " online without synced professions", "forge" }
        end
    end

    if R and R.list then
        local inactive = 0
        for _, e in ipairs(R.list) do
            if not e.online and e.last >= 30 * 24 then inactive = inactive + 1 end
        end
        if inactive > 0 then
            f[#f + 1] = { Gold(inactive) .. " members inactive 30+ days", "roster" }
        end
    end
    return f
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
function H:Refresh()
    if not self.motd then return end
    local R, B = AOR.Roster, AOR.Board
    local online, total = R and R.onlineCount or 0, R and R.total or 0
    local evCount, newsCount = 0, 0
    if B then evCount, newsCount = B:Counts() end

    -- headline + stats
    self.headline:SetText(AOR.config.tagline or "")
    self.sub:SetText(("%s  -  %s members  -  %s online  -  %s event%s this week"):format(
        AOR.config.guildName, Gold(total), Gold(online), Gold(evCount), evCount == 1 and "" or "s"))
    self.statOnline.value:SetText(online)
    self.statEvents.value:SetText(evCount)
    self.statNews.value:SetText(newsCount)

    -- next event
    local e = B and B:GetNext()
    local has = e ~= nil
    for _, w in ipairs({ self.evChip, self.evTitle, self.evWhen, self.boxDays, self.boxHours, self.boxMins, self.evBody, self.evMeta }) do
        w:SetShown(has)
    end
    self.evEmpty:SetShown(not has)
    self.evHint:SetShown(not has)
    if has then
        local d = math.max(0, e.evt - time())
        self.evTitle:SetText(e.title)
        self.evWhen:SetText(date("%A, %B %d  -  %I:%M %p", e.evt) .. "  (your local time)")
        self.boxDays.value:SetText(("%02d"):format(math.floor(d / DAY)))
        self.boxHours.value:SetText(("%02d"):format(math.floor((d % DAY) / 3600)))
        self.boxMins.value:SetText(("%02d"):format(math.floor((d % 3600) / 60)))
        self.evBody:SetText(e.body)
        self.evMeta:SetText(d <= 0 and "HAPPENING NOW" or ("POSTED BY " .. string.upper(Ambiguate(e.author or "?", "short"))))
    else
        self.evHint:SetText(AOR:CanPost() and "Post one from the Conclave tab." or "Officers post events in the Conclave tab.")
    end

    -- timers
    local h, m = GetGameTime()
    self.timerRows[1]:SetText(("%02d:%02d"):format(h or 0, m or 0))
    self.timerRows[2]:SetText(GetQuestResetTime and Dur(GetQuestResetTime()) or "-")
    local weekly = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    self.timerRows[3]:SetText(weekly and Dur(weekly) or "-")
    local _, rankName = GetGuildInfo("player")
    self.timerRows[4]:SetText(rankName or "-")

    -- MOTD / info
    local motd = GetGuildRosterMOTD()
    if motd and motd ~= "" then
        self.motd:SetTextColor(unpack(C.text))
        self.motd:SetText(motd)
    else
        self.motd:SetTextColor(unpack(C.dim))
        self.motd:SetText("No message of the day set.")
    end
    local info = GetGuildInfoText()
    if info and info ~= "" then
        self.info:SetTextColor(unpack(C.text))
        self.info:SetText(info)
    else
        self.info:SetTextColor(unpack(C.dim))
        self.info:SetText("No guild information set.")
    end

    -- latest announcement
    local n = B and B:GetLatestNote()
    if n then
        self.nTitle:SetTextColor(unpack(C.gold))
        self.nTitle:SetText(n.title)
        self.nBody:SetText(n.body)
        self.nMeta:SetText(("%s  -  POSTED BY %s"):format(string.upper(date("%b %d", n.stamp)), string.upper(Ambiguate(n.author or "?", "short"))))
    else
        self.nTitle:SetTextColor(unpack(C.dim))
        self.nTitle:SetText("No announcements yet.")
        self.nBody:SetText("")
        self.nMeta:SetText("")
    end

    -- officer strip
    local officer = AOR:CanPost()
    self.strip:SetShown(officer)
    if officer then
        local flags = Flags()
        if #flags == 0 then
            self.attText:SetText("|cff" .. AOR:Hex(C.good) .. "All clear.|r")
            self.attTab = nil
            self.attBtn:Hide()
        else
            local texts = {}
            for i, fl in ipairs(flags) do texts[i] = fl[1] end
            self.attText:SetText(table.concat(texts, "   |cff" .. AOR:Hex(C.dim) .. "||" .. "|r   "))
            self.attTab = flags[1][2]
            self.attBtn:Show()
        end
    end
end

UI:RegisterTab("home", "The Hearth", Init, function() H:Refresh() end, { group = "GUILD" })

AOR:RegisterEvent("GUILD_MOTD", function() UI:Refresh() end)
AOR:Subscribe("PEERS", function() UI:Refresh() end)

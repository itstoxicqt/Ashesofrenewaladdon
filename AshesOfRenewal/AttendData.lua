local _, AOR = ...

------------------------------------------------------------------------
-- Ember Watch: raid attendance history
--
-- An officer who is in a raid group while a Conclave event is on (from 30
-- minutes before it starts until 6 hours after) has their addon take a roster
-- snapshot every ~5 minutes. Guild members seen in the raid are counted per
-- session. Officers can also start tracking by hand for an unscheduled raid.
-- Sessions are shared with the guild so everyone can see the history.
--
-- A member counts as present for a session once they were seen in at least
-- `attendMinSeen` snapshots (default 2, so zoning in for a moment doesn't count).
--
-- Merging is order independent (per-name maximum), so several officers can
-- record the same raid without overwriting each other.
--
-- Messages (prefix AORAttend), officer-only:
--   H|id|stamp|eventTime|snapshots|part|total|title|name:seen,name:seen
--   X|id|stamp          delete a session
--   Q|since             ask for recent sessions
------------------------------------------------------------------------
local A = { muted = {} }
AOR.Attend = A

local PREFIX = "AORAttend"
local DAY = 86400
local CHUNK = 8
local SNAP_GAP = 270
local pending, incoming = {}, {}

local function d() return AOR.db.attend end
local function short(n) return Ambiguate(n or "", "short") end
local function me() return AOR:Me() end
local function Enc(...) return table.concat({ ... }, "|") end
local function Stamp(prev) return math.max(time(), (prev or 0) + 1) end

local function clean(s, n)
    s = tostring(s or ""):gsub("[|:,\r\n]", " ")
    return strtrim(s):sub(1, n)
end

local function IsOfficerName(name)
    local s = short(name)
    if s == me() then return AOR:CanPost() end
    local ri = AOR.rosterRank[s]
    return ri ~= nil and AOR:RankCanPost(AOR.rosterRankName[s], ri)
end

local function Send(msg)
    if IsInGuild() then C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD") end
end

------------------------------------------------------------------------
-- Sending
------------------------------------------------------------------------
local function Broadcast(s)
    local names = {}
    for name, n in pairs(s.names) do names[#names + 1] = name end
    table.sort(names)
    local total = math.max(1, math.ceil(#names / CHUNK))
    for part = 1, total do
        local slice = {}
        for i = (part - 1) * CHUNK + 1, math.min(part * CHUNK, #names) do
            slice[#slice + 1] = names[i] .. ":" .. s.names[names[i]]
        end
        local msg = Enc("H", s.id, s.stamp, s.evt, s.snaps, part, total, clean(s.title, 36), table.concat(slice, ","))
        C_Timer.After((part - 1) * 0.2, function() Send(msg) end)
    end
end

------------------------------------------------------------------------
-- Recording
------------------------------------------------------------------------
-- The Conclave event this raid belongs to, if any
local function ActiveEvent()
    local now, best, bestDist = time(), nil, nil
    for _, e in pairs(AOR.db.board or {}) do
        if not e.deleted and e.kind == "E" and e.evt and e.evt > 0
           and now >= e.evt - 1800 and now <= e.evt + 6 * 3600 then
            local dist = math.abs(now - e.evt)
            if not best or dist < bestDist then best, bestDist = e, dist end
        end
    end
    return best
end

local function Session(id, title, evt)
    local s = d().sessions[id]
    if not s then
        s = { id = id, evt = evt, title = clean(title, 36), snaps = 0, stamp = 0, names = {}, by = me() }
        d().sessions[id] = s
    end
    return s
end

function A:Snapshot(id, title, evt)
    if not IsInRaid() then return false end
    local s = Session(id, title, evt)
    if s.deleted then return false end
    s.snaps = s.snaps + 1
    local seen = {}
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local who = AOR:UnitKey(unit)
            if who and AOR.rosterRank[who] ~= nil and UnitIsConnected(unit) and not seen[who] then
                seen[who] = true
                s.names[who] = (s.names[who] or 0) + 1
            end
        end
    end
    s.stamp = Stamp(s.stamp)
    Broadcast(s)
    AOR:Fire("ATTEND")
    return true
end

-- Called on roster changes and by a timer. Only officers record.
function A:Check(force)
    if not IsInRaid() or not IsInGuild() then
        self.tracking, self.last = nil, nil
        return
    end
    if not AOR:CanPost() then return end

    local ev = ActiveEvent()
    local id, title, evt
    if ev then
        id, title, evt = "E" .. ev.id, ev.title, ev.evt
    elseif self.manual then
        id, title, evt = self.manual.id, self.manual.title, self.manual.evt
    else
        self.tracking = nil
        return
    end
    if self.muted[id] then return end

    if force or not self.last or time() - self.last >= SNAP_GAP then
        if self:Snapshot(id, title, evt) then
            self.last = time()
            self.tracking = { id = id, title = title }
            AOR:Fire("ATTEND")
        end
    end
end

function A:Start()
    if not AOR:CanPost() then return false, "Only officers can record attendance." end
    if not IsInRaid() then return false, "Join a raid group first." end
    local ev = ActiveEvent()
    if ev then
        self.muted["E" .. ev.id] = nil
    else
        local now = time()
        self.manual = { id = "M" .. now, title = "Raid " .. date("%b %d", now), evt = now }
    end
    self:Check(true)
    return true
end

function A:Stop()
    if self.tracking then self.muted[self.tracking.id] = true end
    self.manual, self.tracking, self.last = nil, nil, nil
    AOR:Fire("ATTEND")
end

function A:Delete(id)
    if not AOR:CanPost() then return false, "Only officers can delete a session." end
    local s = d().sessions[id]
    if not s then return false end
    s.stamp = Stamp(s.stamp)
    s.deleted = true
    Send(Enc("X", id, s.stamp))
    AOR:Fire("ATTEND")
    return true
end

-- Officer fix-up for someone who disconnected or was missed
function A:AddAttendee(id, name)
    if not AOR:CanPost() then return false, "Only officers can do that." end
    local s = d().sessions[id]
    if not s or s.deleted then return false, "Pick a raid first." end
    name = clean(name, 24)
    if name == "" then return false, "Enter a player name." end
    name = AOR:CapitalizeName(name)
    s.names[name] = math.max(s.names[name] or 0, s.snaps, 1)
    s.stamp = Stamp(s.stamp)
    Broadcast(s)
    AOR:Fire("ATTEND")
    return true
end

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------
function A:MinSeen(s)
    return math.min(AOR.config.attendMinSeen or 2, math.max(s.snaps, 1))
end

function A:Attended(s, name)
    local n = s.names[name]
    return n ~= nil and n >= self:MinSeen(s)
end

-- Newest first
function A:Sessions()
    local out = {}
    for _, s in pairs(d().sessions) do
        if not s.deleted and s.snaps > 0 then out[#out + 1] = s end
    end
    table.sort(out, function(a, b)
        if a.evt ~= b.evt then return a.evt > b.evt end
        return a.id > b.id
    end)
    return out
end

function A:Attendees(s)
    local out = {}
    for name in pairs(s.names) do
        if self:Attended(s, name) then out[#out + 1] = name end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- window: "30d", "10" (last ten raids) or "all"
function A:Window(window)
    local all, out = self:Sessions(), {}
    local cutoff = time() - 30 * DAY
    for i, s in ipairs(all) do
        if window == "all" or (window == "10" and i <= 10) or (window == "30d" and s.evt >= cutoff) then
            out[#out + 1] = s
        end
    end
    return out
end

-- One row per member: attended / total, percentage, current streak, last raid
function A:Stats(window, search, everyone)
    local sessions = self:Window(window)
    local total = #sessions
    search = (search or ""):lower()
    local roster = AOR.Roster and AOR.Roster.list or {}
    local out = {}
    for _, e in ipairs(roster) do
        local name = e.short
        if search == "" or name:lower():find(search, 1, true) then
            local attended, streak, last, streaking = 0, 0, nil, true
            for _, s in ipairs(sessions) do
                if self:Attended(s, name) then
                    attended = attended + 1
                    if not last then last = s.evt end
                    if streaking then streak = streak + 1 end
                else
                    streaking = false
                end
            end
            if everyone or attended > 0 then
                out[#out + 1] = {
                    name = name, attended = attended, total = total,
                    pct = total > 0 and math.floor(attended * 100 / total + 0.5) or 0,
                    streak = streak, last = last, classFile = e.classFile, online = e.online,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.pct ~= b.pct then return a.pct > b.pct end
        if a.attended ~= b.attended then return a.attended > b.attended end
        return a.name:lower() < b.name:lower()
    end)
    return out, total
end

------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------
local function Merge(id, stamp, evt, snaps, title, names, sender)
    local s = d().sessions[id]
    if s and s.deleted and stamp <= s.stamp then return false end
    if not s then
        s = { id = id, evt = evt, title = clean(title, 36), snaps = 0, stamp = 0, names = {}, by = short(sender) }
        d().sessions[id] = s
    end
    local changed = false
    if snaps > s.snaps then s.snaps = snaps; changed = true end
    for name, n in pairs(names) do
        if n > (s.names[name] or 0) then s.names[name] = n; changed = true end
    end
    if stamp > s.stamp then s.stamp = stamp end
    return changed
end

local function Handle(text, sender)
    local tag, a, b, c, dd, e, f, g, h = strsplit("|", text)
    local mine = short(sender) == me()

    if tag == "H" then
        local id, stamp, evt, snaps, part, total = a, tonumber(b), tonumber(c), tonumber(dd), tonumber(e), tonumber(f)
        if not (id and id ~= "" and stamp and evt and snaps and part and total) or total < 1 or part < 1 or part > total then return end
        pending[id] = nil
        if mine or not IsOfficerName(sender) then return end
        local key = id .. "|" .. stamp
        local buf = incoming[key]
        if not buf then
            buf = { total = total, parts = {}, got = 0 }
            incoming[key] = buf
        end
        if not buf.parts[part] then
            local names = {}
            for entry in (h or ""):gmatch("[^,]+") do
                local name, n = strsplit(":", entry)
                if name and name ~= "" then names[short(name)] = tonumber(n) or 1 end
            end
            buf.parts[part] = names
            buf.got = buf.got + 1
        end
        if buf.got == buf.total then
            incoming[key] = nil
            local all = {}
            for i = 1, buf.total do
                for name, n in pairs(buf.parts[i]) do all[name] = n end
            end
            if Merge(id, stamp, evt, snaps, g, all, sender) then AOR:Fire("ATTEND") end
        end

    elseif tag == "X" then
        local id, stamp = a, tonumber(b)
        if not (id and stamp) or mine or not IsOfficerName(sender) then return end
        local s = d().sessions[id]
        if s then
            if stamp >= s.stamp then s.deleted = true; s.stamp = stamp; AOR:Fire("ATTEND") end
        else
            d().sessions[id] = { id = id, evt = 0, title = "", snaps = 0, stamp = stamp, names = {}, deleted = true }
        end

    elseif tag == "Q" and not mine then
        local since = tonumber(a) or 0
        local list = {}
        for _, s in pairs(d().sessions) do
            if not s.deleted and s.stamp >= since - 5 then list[#list + 1] = s end
        end
        table.sort(list, function(x, y) return x.stamp > y.stamp end)
        for i = 1, math.min(#list, 3) do
            local s = list[i]
            pending[s.id] = s.stamp
            C_Timer.After(2 + math.random() * 8 + i, function()
                if pending[s.id] == s.stamp then
                    pending[s.id] = nil
                    Broadcast(s)
                end
            end)
        end
    end
end

function A:MaxStamp()
    local m = 0
    for _, s in pairs(d().sessions) do if s.stamp > m then m = s.stamp end end
    return m
end

function A:Prune()
    local now = time()
    for id, s in pairs(d().sessions) do
        if (s.deleted and s.stamp < now - 7 * DAY) or (not s.deleted and s.evt > 0 and s.evt < now - 120 * DAY) then
            d().sessions[id] = nil
        end
    end
end

AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    A:Prune()
    C_Timer.NewTicker(60, function() A:Check() end)
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not text or not AOR.db then return end
    Handle(text, sender)
end)

AOR:RegisterEvent("GROUP_ROSTER_UPDATE", function() if AOR.db then A:Check() end end)

local synced
AOR:Subscribe("ROSTER", function()
    if synced or not IsInGuild() or not AOR.db then return end
    synced = true
    C_Timer.After(6, function() Send("Q|" .. A:MaxStamp()) end)
end)

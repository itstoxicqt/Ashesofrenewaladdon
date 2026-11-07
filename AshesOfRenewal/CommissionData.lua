local _, AOR = ...

------------------------------------------------------------------------
-- Commission: guild craft request board
--
-- A request is two independently synced parts:
--   request  (author only):  recipe, title, fee, flags, notes, cancelled
--   state    (anyone, rules below): O open / C claimed by a crafter / D done
--
-- Rules, enforced on every client when messages arrive:
--   claim     the claimer claims for themselves, never on their own request
--   unclaim   the claimer, the author or an officer
--   complete  the author, the claimer or an officer
--   cancel    the author or an officer
--
-- Crafters are found through the Forge ledger: by recipe id when the request
-- was made from a recipe link or a suggestion, otherwise by matching the
-- title against recipe names.
--
-- Messages (prefix AORCommission):
--   N|id|stamp|created|recipe|fee|flags|cancelled|author|title|notes
--   S|id|stamp|status|by
--   Q|since        ask the guild for anything newer than `since`
------------------------------------------------------------------------
local Q = {}
AOR.Commission = Q

local PREFIX = "AORCommission"
local DAY = 86400
local MAX_OPEN_PER_PLAYER = 5
local pending = {}

local function d() return AOR.db.commission end
local function short(n) return Ambiguate(n or "", "short") end
local function me() return AOR:Me() end
local function Enc(...) return table.concat({ ... }, "|") end
local function Stamp(prev) return math.max(time(), (prev or 0) + 1) end

local function clean(s, n)
    s = tostring(s or ""):gsub("[|\r\n]", " ")
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

Q.FLAGS = {
    M = "Mats provided",
    U = "Urgent",
    R = "For raid",
}
Q.FLAG_ORDER = { "M", "U", "R" }

function Q:FlagText(flags)
    local out = {}
    for _, k in ipairs(self.FLAG_ORDER) do
        if flags and flags:find(k, 1, true) then out[#out + 1] = self.FLAGS[k] end
    end
    return table.concat(out, ", ")
end

------------------------------------------------------------------------
-- Rules
------------------------------------------------------------------------
local function Allowed(who, officer, req, cur, status, by)
    local author = req and req.author
    if status == "C" then
        return by == who and who ~= author and not (cur and cur.status == "D")
    elseif status == "O" or status == "D" then
        return officer or who == author or (cur ~= nil and cur.by == who)
    end
    return false
end

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------
function Q:State(id)
    return d().state[id] or { stamp = 0, status = "O", by = "" }
end

local function Alive(req)
    if req.deleted then return false end
    return req.at >= time() - 14 * DAY
end

-- All live requests with their state attached
function Q:All()
    local out = {}
    for id, req in pairs(d().reqs) do
        if Alive(req) then
            local st = self:State(id)
            out[#out + 1] = { req = req, state = st, status = st.status }
        end
    end
    return out
end

function Q:UnclaimedCount()
    local n = 0
    for _, r in ipairs(self:All()) do
        if r.status == "O" then n = n + 1 end
    end
    return n
end

-- Guildmates who can craft this request, according to the Forge ledger.
-- Returns: list of names, tier name (or nil)
function Q:Crafters(req)
    local F = AOR.Forge
    local list, seen, tier = {}, {}, nil
    if not F then return list, nil end
    local function add(e)
        if not e then return end
        tier = tier or e.tier
        for _, c in ipairs(e.crafters) do
            if not seen[c] then seen[c] = true; list[#list + 1] = c end
        end
    end
    if req.recipe and req.recipe > 0 then
        add(F:Entry(req.recipe))
    else
        for _, e in ipairs(F:EntriesByName(req.title)) do add(e) end
    end
    return list, tier
end

local function OpenCount(me_)
    local n = 0
    for _, r in ipairs(Q:All()) do
        if r.req.author == me_ and r.status ~= "D" then n = n + 1 end
    end
    return n
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
function Q:Post(recipe, title, fee, flags, notes)
    if not IsInGuild() then return false, "You are not in a guild." end
    title = clean(title, 40)
    if title == "" then return false, "Say what you need crafted." end
    if OpenCount(me()) >= MAX_OPEN_PER_PLAYER then
        return false, ("You already have %d open requests. Finish or cancel one first."):format(MAX_OPEN_PER_PLAYER)
    end
    local now = time()
    local req = {
        id = now .. "-" .. math.random(100, 999), stamp = now, at = now,
        recipe = tonumber(recipe) or 0, fee = math.max(0, math.min(tonumber(fee) or 0, 1000000 * 10000)),
        flags = clean(flags, 4), deleted = false, author = me(),
        title = title, notes = clean(notes, 80),
    }
    d().reqs[req.id] = req
    Send(Enc("N", req.id, req.stamp, req.at, req.recipe, req.fee, req.flags, 0, req.author, req.title, req.notes))
    AOR:Fire("COMMISSION")
    return true
end

function Q:Cancel(id)
    local req = d().reqs[id]
    if not req then return false end
    if not (req.author == me() or AOR:CanPost()) then return false, "Only the requester or an officer can cancel." end
    req.stamp = Stamp(req.stamp)
    req.deleted = true
    Send(Enc("N", id, req.stamp, req.at, req.recipe, req.fee, req.flags, 1, req.author, req.title, req.notes))
    AOR:Fire("COMMISSION")
    return true
end

local function SetState(id, status, by)
    local cur = d().state[id]
    local st = { stamp = Stamp(cur and cur.stamp), status = status, by = by or "" }
    d().state[id] = st
    Send(Enc("S", id, st.stamp, st.status, st.by))
    AOR:Fire("COMMISSION")
end

function Q:Claim(id)
    local req, cur = d().reqs[id], d().state[id]
    if not req then return false end
    if not Allowed(me(), AOR:CanPost(), req, cur, "C", me()) then
        return false, req.author == me() and "You can't claim your own request." or "That request is already done."
    end
    SetState(id, "C", me())
    return true
end

function Q:Unclaim(id)
    local req, cur = d().reqs[id], d().state[id]
    if not (req and Allowed(me(), AOR:CanPost(), req, cur, "O", "")) then return false end
    SetState(id, "O", "")
    return true
end

function Q:Complete(id)
    local req, cur = d().reqs[id], d().state[id]
    if not (req and Allowed(me(), AOR:CanPost(), req, cur, "D", "")) then return false end
    SetState(id, "D", (cur and cur.by ~= "" and cur.by) or me())
    return true
end

------------------------------------------------------------------------
-- Sync
------------------------------------------------------------------------
local function Entries(since)
    local out = {}
    for id, r in pairs(d().reqs) do
        if r.stamp >= since - 5 then
            out[#out + 1] = { key = "N" .. id, stamp = r.stamp,
                msg = Enc("N", id, r.stamp, r.at, r.recipe, r.fee, r.flags, r.deleted and 1 or 0, r.author, r.title, r.notes) }
        end
    end
    for id, s in pairs(d().state) do
        if s.stamp >= since - 5 then
            out[#out + 1] = { key = "S" .. id, stamp = s.stamp, msg = Enc("S", id, s.stamp, s.status, s.by) }
        end
    end
    return out
end

function Q:MaxStamp()
    local m = 0
    for _, e in ipairs(Entries(0)) do if e.stamp > m then m = e.stamp end end
    return m
end

function Q:Respond(since)
    local out = Entries(since)
    table.sort(out, function(a, b) return a.stamp > b.stamp end)
    for i = 1, math.min(#out, 30) do
        local e = out[i]
        pending[e.key] = e.stamp
        C_Timer.After(1 + math.random() * 6 + i * 0.4, function()
            if pending[e.key] == e.stamp then
                pending[e.key] = nil
                Send(e.msg)
            end
        end)
    end
end

local function Handle(text, sender)
    local tag, a, b, c, dd, e, f, g, h, i, j = strsplit("|", text)
    local who = short(sender)
    local mine = who == me()
    local data = d()

    if tag == "N" then
        local id, stamp, at = a, tonumber(b), tonumber(c)
        local recipe, fee = tonumber(dd), tonumber(e)
        local flags, del, author, title, notes = f, g, h, i, j
        if not (id and id ~= "" and stamp and at and recipe and fee and author and author ~= "" and title and title ~= "") then return end
        if pending["N" .. id] and pending["N" .. id] <= stamp then pending["N" .. id] = nil end
        local isDel = (del == "1")
        if not (short(author) == who or (isDel and IsOfficerName(sender))) then return end
        local cur = data.reqs[id]
        if cur and cur.stamp >= stamp then return end
        local isNew = (cur == nil)
        data.reqs[id] = {
            id = id, stamp = stamp, at = at, recipe = recipe,
            fee = math.max(0, math.min(fee, 1000000 * 10000)),
            flags = clean(flags, 4), deleted = isDel, author = short(author),
            title = clean(title, 40), notes = clean(notes, 80),
        }
        AOR:Fire("COMMISSION")
        if isNew and not isDel and not mine and stamp > time() - 120 then
            local list = Q:Crafters(data.reqs[id])
            for _, name in ipairs(list) do
                if name == me() then
                    AOR:Toast("You can fill a craft request", data.reqs[id].title .. "  -  " .. short(author))
                    break
                end
            end
        end

    elseif tag == "S" then
        local id, stamp, status, by = a, tonumber(b), c, dd or ""
        if not (id and id ~= "" and stamp and status) then return end
        if pending["S" .. id] and pending["S" .. id] <= stamp then pending["S" .. id] = nil end
        local cur = data.state[id]
        if cur and cur.stamp >= stamp then return end
        if not Allowed(who, IsOfficerName(sender), data.reqs[id], cur, status, short(by)) then return end
        data.state[id] = { stamp = stamp, status = status, by = short(by) }
        AOR:Fire("COMMISSION")
        local req = data.reqs[id]
        if status == "C" and req and req.author == me() and not mine and stamp > time() - 120 then
            AOR:Toast("Craft request claimed", ("%s will craft %s"):format(short(by), req.title))
        end

    elseif tag == "Q" then
        if not mine then Q:Respond(tonumber(a) or 0) end
    end
end

function Q:Prune()
    local now = time()
    for id, r in pairs(d().reqs) do
        local st = d().state[id]
        local doneOld = st and st.status == "D" and st.stamp < now - 3 * DAY
        local cancelledOld = r.deleted and r.stamp < now - 3 * DAY
        if doneOld or cancelledOld or r.at < now - 14 * DAY then
            d().reqs[id] = nil
            d().state[id] = nil
        end
    end
    for id in pairs(d().state) do
        if not d().reqs[id] and d().state[id].stamp < now - 3 * DAY then d().state[id] = nil end
    end
end

AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    Q:Prune()
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not text or not AOR.db then return end
    Handle(text, sender)
end)

local synced
AOR:Subscribe("ROSTER", function()
    if synced or not IsInGuild() or not AOR.db then return end
    synced = true
    C_Timer.After(5, function() Send("Q|" .. Q:MaxStamp()) end)
end)

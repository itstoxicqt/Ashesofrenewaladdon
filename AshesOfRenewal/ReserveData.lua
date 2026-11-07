local _, AOR = ...

------------------------------------------------------------------------
-- Ember Reserve: data, rules and sync
--
--   pool   items officers made reservable (shift-click to add)
--   hard   public hard reserves: item -> player name or BANK (officers)
--   soft   each member's own soft reserves
--   plus   +1 standings per season (officers)
--   log    award history (officers)
--
-- Rules for a drop: hard reserve wins outright (no rolls, no +1), else
-- reservers with the lowest +1, else an open roll.
-- Reserves lock automatically before the next Conclave event starts.
--
-- Sync uses its own addon prefix. Officer-only messages are ignored unless
-- the sender's guild rank can post (same rule as the Board).
------------------------------------------------------------------------
local R = {}
AOR.Reserve = R

local PREFIX = "AORReserve"
local MIN, DAY = 60, 86400
local pending = {}

local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local requested = {}

local function d() return AOR.db.reserve end
local function short(n) return Ambiguate(n or "", "short") end
local function me() return AOR:Me() end
local function Enc(...) return table.concat({ ... }, "|") end
local function Stamp(prev) return math.max(time(), (prev or 0) + 1) end

local function IsOfficerName(name)
    local s = short(name)
    if s == me() then return AOR:CanPost() end
    local ri = AOR.rosterRank[s]
    return ri ~= nil and AOR:RankCanPost(AOR.rosterRankName[s], ri)
end

local function Send(msg)
    if IsInGuild() then C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD") end
end

function R:Max() return AOR.config.maxReserves or 1 end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------
function R:ParseItemID(text)
    text = tostring(text or "")
    local id = text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end

-- The icon is available immediately; name and quality need the item cached.
local function InstantIcon(id)
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(id)
        if icon then return icon end
    end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if fn then
        local _, _, _, _, icon = fn(id)
        if icon then return icon end
    end
    return 134400
end

local function QualityRGB(q)
    q = q or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

-- name, link, quality, icon. Requests the item from the server if unknown.
function R:ItemData(id)
    local ok, name, link, quality, _, _, _, _, _, _, icon = pcall(GetInfo, id)
    if ok and name then return name, link, quality or 1, icon or InstantIcon(id) end
    if Item and Item.CreateFromItemID and not requested[id] then
        requested[id] = true
        Item:CreateFromItemID(id):ContinueOnItemLoad(function()
            requested[id] = nil
            AOR:Fire("RESERVE")
        end)
    end
    return "Item " .. id, nil, 1, InstantIcon(id)
end

function R:ColoredName(id)
    local name, _, q = self:ItemData(id)
    local r, g, b = QualityRGB(q)
    return "|cff" .. AOR:Hex({ r, g, b }) .. name .. "|r"
end

------------------------------------------------------------------------
-- Lock (follows the next Conclave event unless an officer overrides)
-- Returns: locked, lockStartTime (or nil), description
------------------------------------------------------------------------
function R:LockInfo()
    local lock = d().lock
    if lock.mode == "L" then return true, lock.stamp, "Locked by an officer" end
    if lock.mode == "O" then return false, nil, "Held open by an officer" end
    local ev = AOR.Board and AOR.Board:GetNext()
    if ev then
        local at = ev.evt - (AOR.config.lockMinutes or 30) * MIN
        if time() >= at then return true, at, "Locked for " .. ev.title end
        local cd = (AOR.Board.Countdown(at):gsub("^in ", ""))
        return false, at, "Locks in " .. cd
    end
    return false, nil, "No event scheduled - reserves open"
end

function R:IsLocked() return (self:LockInfo()) end

function R:LockMode() return d().lock.mode end

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------
local function SoftItems(player)
    local e = d().soft[player]
    if e and e.stamp >= d().epoch then return e.items end
    return {}
end
function R:SoftItems(player) return SoftItems(player) end

function R:HasMine(id)
    for _, it in ipairs(SoftItems(me())) do if it == id then return true end end
    return false
end

function R:Plus(player, season)
    local s = d().plus[season or d().season]
    local e = s and s[player]
    return e and e.n or 0
end

function R:Season() return d().season end

function R:Reservers(id)
    local out = {}
    for player, e in pairs(d().soft) do
        if e.stamp >= d().epoch then
            for _, it in ipairs(e.items) do
                if it == id then out[#out + 1] = player; break end
            end
        end
    end
    table.sort(out, function(a, b)
        local pa, pb = R:Plus(a), R:Plus(b)
        if pa ~= pb then return pa < pb end
        return a:lower() < b:lower()
    end)
    return out
end

-- Reservable items: pool plus anything hard reserved. Hard reserves first.
function R:Items()
    local data, out, seen, names = d(), {}, {}, {}
    for id, e in pairs(data.hard) do
        if not e.del then
            local p = data.pool[id]
            out[#out + 1] = { id = id, hard = e, pooled = (p ~= nil and not p.del) }
            seen[id] = true
        end
    end
    for id, e in pairs(data.pool) do
        if not e.del and not seen[id] then out[#out + 1] = { id = id, pooled = true } end
    end
    for _, e in ipairs(out) do names[e.id] = (R:ItemData(e.id)):lower() end
    table.sort(out, function(a, b)
        if (a.hard ~= nil) ~= (b.hard ~= nil) then return a.hard ~= nil end
        if names[a.id] ~= names[b.id] then return names[a.id] < names[b.id] end
        return a.id < b.id
    end)
    return out
end

function R:HardList()
    local out, names = {}, {}
    for id, e in pairs(d().hard) do
        if not e.del then out[#out + 1] = { id = id, hard = e }; names[id] = (R:ItemData(id)):lower() end
    end
    table.sort(out, function(a, b)
        if names[a.id] ~= names[b.id] then return names[a.id] < names[b.id] end
        return a.id < b.id
    end)
    return out
end

function R:Standings()
    local map = {}
    for player, e in pairs(d().plus[d().season] or {}) do map[player] = e.n end
    for player, e in pairs(d().soft) do
        if e.stamp >= d().epoch and #e.items > 0 and map[player] == nil then map[player] = 0 end
    end
    local out = {}
    for player, n in pairs(map) do out[#out + 1] = { name = player, n = n, items = SoftItems(player) } end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n < b.n end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function R:RecentAwards(limit)
    local out = {}
    for _, e in pairs(d().log) do
        if e.season == d().season then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.stamp > b.stamp end)
    while #out > (limit or 14) do table.remove(out) end
    return out
end

-- What should happen when this item drops?
--   { kind = "H", target = name|"BANK" }                      hard reserve, bypasses everything
--   { kind = "S", list = {names}, tier = {names}, tie = bool } lowest +1 first
--   { kind = "O" }                                            nobody reserved: open roll
function R:Resolve(id)
    local hard = d().hard[id]
    if hard and not hard.del then return { kind = "H", target = hard.target } end
    local list = self:Reservers(id)
    if #list == 0 then return { kind = "O" } end
    local low = self:Plus(list[1])
    local tier = {}
    for _, p in ipairs(list) do
        if self:Plus(p) == low then tier[#tier + 1] = p end
    end
    return { kind = "S", list = list, tier = tier, tie = #tier > 1, plus = low }
end

------------------------------------------------------------------------
-- Member actions
------------------------------------------------------------------------
local function StoreSoft(player, items)
    local prev = d().soft[player]
    local stamp = math.max(time(), (prev and prev.stamp or 0) + 1, d().epoch + 1)
    d().soft[player] = { stamp = stamp, items = items }
    Send(Enc("S", player, stamp, table.concat(items, ",")))
    AOR:Fire("RESERVE")
end

function R:Reserve(id)
    if not IsInGuild() then return false, "You are not in a guild." end
    if self:IsLocked() then return false, "Reserves are locked." end
    local hard = d().hard[id]
    if hard and not hard.del then return false, "That item is hard reserved." end
    local pool = d().pool[id]
    if not (pool and not pool.del) then return false, "That item is not in the reserve pool." end
    local items = {}
    for _, it in ipairs(SoftItems(me())) do
        if it == id then return false, "You already reserved that item." end
        items[#items + 1] = it
    end
    if #items >= self:Max() then
        return false, ("You can only reserve %d item%s."):format(self:Max(), self:Max() == 1 and "" or "s")
    end
    items[#items + 1] = id
    StoreSoft(me(), items)
    return true
end

function R:Cancel(id)
    if self:IsLocked() then return false, "Reserves are locked." end
    local items = {}
    for _, it in ipairs(SoftItems(me())) do
        if it ~= id then items[#items + 1] = it end
    end
    StoreSoft(me(), items)
    return true
end

------------------------------------------------------------------------
-- Officer actions
------------------------------------------------------------------------
local function CheckOfficer()
    if not AOR:CanPost() then return false, "Only officers can do that." end
    return true
end

function R:AddPool(id)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    if not id then return false, "That isn't an item." end
    local cur = d().pool[id]
    local e = { stamp = Stamp(cur and cur.stamp), del = false }
    d().pool[id] = e
    Send(Enc("I", id, e.stamp, 0))
    AOR:Fire("RESERVE")
    return true
end

function R:RemovePool(id)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local cur = d().pool[id]
    if not cur then return false end
    local e = { stamp = Stamp(cur.stamp), del = true }
    d().pool[id] = e
    Send(Enc("I", id, e.stamp, 1))
    AOR:Fire("RESERVE")
    return true
end

local function CleanName(s)
    s = strtrim((tostring(s or ""):gsub("|", "")))
    if s == "" then return nil end
    local l = s:lower()
    if l == "bank" or l == "guild bank" or l == "gb" then return "BANK" end
    return AOR:CapitalizeName(s)
end

function R:SetHard(id, target)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    if not id then return false, "Add an item first (shift-click a link)." end
    target = CleanName(target)
    if not target then return false, "Enter a player name, or BANK for the guild bank." end
    local cur = d().hard[id]
    local e = { stamp = Stamp(cur and cur.stamp), del = false, target = target, by = me() }
    d().hard[id] = e
    Send(Enc("H", id, e.stamp, 0, target, e.by))
    AOR:Fire("RESERVE")
    return true
end

function R:ClearHard(id)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local cur = d().hard[id]
    if not cur then return false end
    local e = { stamp = Stamp(cur.stamp), del = true, target = cur.target, by = me() }
    d().hard[id] = e
    Send(Enc("H", id, e.stamp, 1, cur.target or "", e.by))
    AOR:Fire("RESERVE")
    return true
end

function R:AdjustPlus(player, delta)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    player = CleanName(player)
    if not player then return false, "Enter a player name." end
    local season = d().season
    d().plus[season] = d().plus[season] or {}
    local cur = d().plus[season][player]
    local e = { n = math.max(0, (cur and cur.n or 0) + delta), stamp = Stamp(cur and cur.stamp) }
    d().plus[season][player] = e
    Send(Enc("N", season, player, e.stamp, e.n))
    AOR:Fire("RESERVE")
    return true
end

-- kind: "H" hard reserve (no +1), "S" soft reserve win (+1 and the reserve is spent)
function R:Award(id, player, kind)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local logId = time() .. "-" .. math.random(100, 999)
    local e = { id = logId, stamp = time(), season = d().season, player = player, item = id, kind = kind }
    d().log[logId] = e
    Send(Enc("W", logId, e.stamp, e.season, player, id, kind))
    if kind == "H" then
        self:ClearHard(id)
    elseif kind == "S" then
        local items = {}
        for _, it in ipairs(SoftItems(player)) do
            if it ~= id then items[#items + 1] = it end
        end
        StoreSoft(player, items)
        self:AdjustPlus(player, 1)
    end
    AOR:Fire("RESERVE")
    return true
end

function R:SetLockMode(mode)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local lock = { stamp = Stamp(d().lock.stamp), mode = mode }
    d().lock = lock
    Send(Enc("K", lock.stamp, mode))
    AOR:Fire("RESERVE")
    return true
end

-- Wipes everyone's soft reserves (pool and hard reserves stay) and returns to auto lock.
function R:NewSession()
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    -- go past every existing reserve stamp so members with fast clocks are cleared too
    local top = d().epoch
    for _, e in pairs(d().soft) do if e.stamp > top then top = e.stamp end end
    d().epoch = Stamp(top)
    Send(Enc("E", d().epoch))
    self:SetLockMode("A")
    AOR:Fire("RESERVE")
    return true
end

function R:NewSeason()
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    d().season = d().season + 1
    d().seasonStamp = Stamp(d().seasonStamp)
    Send(Enc("Z", d().seasonStamp, d().season))
    AOR:Fire("RESERVE")
    return true
end

------------------------------------------------------------------------
-- Sync
------------------------------------------------------------------------
local function Entries(since)
    local out, data = {}, d()
    local function add(key, stamp, msg)
        if stamp and stamp >= since - 5 then out[#out + 1] = { key = key, stamp = stamp, msg = msg } end
    end
    for id, e in pairs(data.pool) do add("I" .. id, e.stamp, Enc("I", id, e.stamp, e.del and 1 or 0)) end
    for id, e in pairs(data.hard) do
        add("H" .. id, e.stamp, Enc("H", id, e.stamp, e.del and 1 or 0, e.target or "", e.by or ""))
    end
    for p, e in pairs(data.soft) do
        if e.stamp >= data.epoch then add("S" .. p, e.stamp, Enc("S", p, e.stamp, table.concat(e.items, ","))) end
    end
    for season, t in pairs(data.plus) do
        for p, e in pairs(t) do add("N" .. season .. p, e.stamp, Enc("N", season, p, e.stamp, e.n)) end
    end
    for id, e in pairs(data.log) do
        add("W" .. id, e.stamp, Enc("W", id, e.stamp, e.season, e.player, e.item, e.kind))
    end
    add("E", data.epoch, Enc("E", data.epoch))
    add("K", data.lock.stamp, Enc("K", data.lock.stamp, data.lock.mode))
    add("Z", data.seasonStamp, Enc("Z", data.seasonStamp, data.season))
    return out
end

function R:MaxStamp()
    local m = 0
    for _, e in ipairs(Entries(0)) do if e.stamp > m then m = e.stamp end end
    return m
end

function R:Respond(since)
    local out = Entries(since)
    table.sort(out, function(a, b) return a.stamp > b.stamp end)
    for i = 1, math.min(#out, 40) do
        local e = out[i]
        pending[e.key] = e.stamp
        C_Timer.After(1 + math.random() * 6 + i * 0.3, function()
            -- skip if someone else already sent this exact entry
            if pending[e.key] == e.stamp then
                pending[e.key] = nil
                Send(e.msg)
            end
        end)
    end
end

local function Handle(text, sender)
    local tag, a, b, c, dd, e, f = strsplit("|", text)
    local data = d()
    local officer = IsOfficerName(sender)
    local mine = short(sender) == me()
    local changed

    if tag == "I" then
        local id, stamp = tonumber(a), tonumber(b)
        if not (id and stamp) then return end
        if pending["I" .. id] and pending["I" .. id] <= stamp then pending["I" .. id] = nil end
        if not officer then return end
        local cur = data.pool[id]
        if cur and cur.stamp >= stamp then return end
        data.pool[id] = { stamp = stamp, del = (c == "1") }
        changed = true

    elseif tag == "H" then
        local id, stamp = tonumber(a), tonumber(b)
        if not (id and stamp) then return end
        if pending["H" .. id] and pending["H" .. id] <= stamp then pending["H" .. id] = nil end
        if not officer then return end
        local cur = data.hard[id]
        if cur and cur.stamp >= stamp then return end
        data.hard[id] = { stamp = stamp, del = (c == "1"), target = dd, by = e }
        changed = true

    elseif tag == "S" then
        local player, stamp = a, tonumber(b)
        if not player or player == "" or not stamp then return end
        if pending["S" .. player] and pending["S" .. player] <= stamp then pending["S" .. player] = nil end
        if not (short(sender) == player or officer) then return end
        if stamp < data.epoch then return end
        if not officer then
            local locked, from = R:LockInfo()
            if locked and from and stamp >= from then return end
        end
        local items = {}
        for n in (c or ""):gmatch("%d+") do items[#items + 1] = tonumber(n) end
        if #items > R:Max() and not officer then return end
        local cur = data.soft[player]
        if cur and cur.stamp >= stamp then return end
        data.soft[player] = { stamp = stamp, items = items }
        changed = true

    elseif tag == "N" then
        local season, player, stamp, n = tonumber(a), b, tonumber(c), tonumber(dd)
        if not (season and player and stamp and n) then return end
        if pending["N" .. season .. player] and pending["N" .. season .. player] <= stamp then
            pending["N" .. season .. player] = nil
        end
        if not officer then return end
        data.plus[season] = data.plus[season] or {}
        local cur = data.plus[season][player]
        if cur and cur.stamp >= stamp then return end
        data.plus[season][player] = { n = n, stamp = stamp }
        changed = true

    elseif tag == "W" then
        local id, stamp, season, item = a, tonumber(b), tonumber(c), tonumber(e)
        if not (id and stamp and season and item) then return end
        if pending["W" .. id] then pending["W" .. id] = nil end
        if not officer or data.log[id] then return end
        data.log[id] = { id = id, stamp = stamp, season = season, player = dd, item = item, kind = f }
        changed = true
        if not mine and stamp > time() - 120 then
            local name = R:ItemData(item)
            AOR:Toast("Loot awarded", ("%s  -  %s"):format(dd == "BANK" and "Guild Bank" or dd, name))
        end

    elseif tag == "E" then
        local stamp = tonumber(a)
        if pending["E"] and stamp and pending["E"] <= stamp then pending["E"] = nil end
        if not (officer and stamp) or stamp <= data.epoch then return end
        data.epoch = stamp
        changed = true

    elseif tag == "K" then
        local stamp = tonumber(a)
        if pending["K"] and stamp and pending["K"] <= stamp then pending["K"] = nil end
        if not (officer and stamp) or stamp <= data.lock.stamp then return end
        if b ~= "A" and b ~= "L" and b ~= "O" then return end
        data.lock = { stamp = stamp, mode = b }
        changed = true

    elseif tag == "Z" then
        local stamp, season = tonumber(a), tonumber(b)
        if pending["Z"] and stamp and pending["Z"] <= stamp then pending["Z"] = nil end
        if not (officer and stamp and season) or stamp <= data.seasonStamp then return end
        data.seasonStamp, data.season = stamp, season
        changed = true

    elseif tag == "Q" then
        if not mine then R:Respond(tonumber(a) or 0) end
        return
    end

    if changed then AOR:Fire("RESERVE") end
end

function R:Prune()
    local data, now = d(), time()
    for player, e in pairs(data.soft) do
        if e.stamp < data.epoch then data.soft[player] = nil end
    end
    for id, e in pairs(data.pool) do
        if e.del and e.stamp < now - 45 * DAY then data.pool[id] = nil end
    end
    for id, e in pairs(data.hard) do
        if e.del and e.stamp < now - 45 * DAY then data.hard[id] = nil end
    end
    local logs = {}
    for _, e in pairs(data.log) do logs[#logs + 1] = e end
    if #logs > 200 then
        table.sort(logs, function(x, y) return x.stamp > y.stamp end)
        for i = 201, #logs do data.log[logs[i].id] = nil end
    end
end

AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    R:Prune()
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not text or not AOR.db then return end
    Handle(text, sender)
end)

-- Ask the guild for anything we missed, once per login, after ranks are known
local synced
AOR:Subscribe("ROSTER", function()
    if synced or not IsInGuild() or not AOR.db then return end
    synced = true
    C_Timer.After(4, function() Send("Q|" .. R:MaxStamp()) end)
end)

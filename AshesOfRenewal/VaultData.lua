local _, AOR = ...

------------------------------------------------------------------------
-- Ash Vault: guild bank stock ledger for officers
--
-- Officers choose which consumables to watch (flasks, potions, stones...)
-- with a low-stock threshold each. Whenever an officer opens the guild bank,
-- every tab they can view is scanned and the counts are saved as a
-- snapshot. Snapshots and the watch list are shared over the OFFICER addon
-- channel, so officers can check stock in a raid without opening the bank.
--
-- Messages (prefix AORVault, officer channel, officer senders only):
--   T|id|stamp|min|removed        watch-list entry
--   C|stamp|by|tabs|part|total|id:count,...    snapshot counts (watched items)
--   Q|since                       ask officers for anything newer
------------------------------------------------------------------------
local Vt = {}
AOR.Vault = Vt

local PREFIX = "AORVault"
local CHUNK = 12
local MAX_SLOTS = MAX_GUILDBANK_SLOTS_PER_TAB or 98
local HISTORY = 10
local pending, incoming = {}, {}
local categoryCache = {}

local function d() return AOR.db.vault end
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
    if IsInGuild() then C_ChatInfo.SendAddonMessage(PREFIX, msg, "OFFICER") end
end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------
-- Category comes from the game's own item type, e.g. "Flasks", "Potions"
function Vt:Category(id)
    if categoryCache[id] then return categoryCache[id] end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local cat
    if fn then
        local _, _, subType = fn(id)
        cat = subType
    end
    if cat and cat ~= "" then categoryCache[id] = cat; return cat end
    return "Other"
end

function Vt:Tracked()
    local out = {}
    for id, e in pairs(d().track) do
        if not e.del then out[#out + 1] = { id = id, min = e.min } end
    end
    return out
end

------------------------------------------------------------------------
-- Stock
------------------------------------------------------------------------
function Vt:Snapshot() return d().snap end

-- count in the latest snapshot, or nil if that snapshot didn't include the item
-- A scan done on this client covers whole tabs, so an absent item really is 0.
function Vt:Count(id)
    local snap = d().snap
    local n = snap.items[id]
    if n == nil and snap.full and snap.stamp > 0 then return 0 end
    return n
end

function Vt:Status(id, min)
    local n = self:Count(id)
    if n == nil then return "?" end
    if n <= 0 then return "OUT" end
    if n <= (min or 0) then return "LOW" end
    return "OK"
end

-- change since the snapshot before the latest one (nil if unknown)
function Vt:Delta(id)
    local prev = d().history[#d().history]
    local now = self:Count(id)
    if not prev or now == nil or prev.items[id] == nil then return nil end
    return now - prev.items[id]
end

function Vt:LowCount()
    local n = 0
    for _, t in ipairs(self:Tracked()) do
        local s = self:Status(t.id, t.min)
        if s == "LOW" or s == "OUT" then n = n + 1 end
    end
    return n
end

------------------------------------------------------------------------
-- Watch list (officers)
------------------------------------------------------------------------
local function CheckOfficer()
    if not AOR:CanPost() then return false, "Only officers can change the vault list." end
    return true
end

local function PutTrack(id, min, del)
    local cur = d().track[id]
    local e = { stamp = Stamp(cur and cur.stamp), min = math.max(0, math.floor(tonumber(min) or 0)), del = del and true or false }
    d().track[id] = e
    Send(Enc("T", id, e.stamp, e.min, e.del and 1 or 0))
    AOR:Fire("VAULT")
end

function Vt:Track(id, min)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    if not id then return false, "That isn't an item." end
    local cur = d().track[id]
    PutTrack(id, min or (cur and not cur.del and cur.min) or AOR.config.vaultDefaultMin or 10, false)
    return true
end

function Vt:SetMin(id, min)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local cur = d().track[id]
    if not cur or cur.del then return false end
    PutTrack(id, min, false)
    return true
end

function Vt:Untrack(id)
    local ok, msg = CheckOfficer()
    if not ok then return false, msg end
    local cur = d().track[id]
    if not cur then return false end
    PutTrack(id, cur.min, true)
    return true
end

------------------------------------------------------------------------
-- Snapshots
------------------------------------------------------------------------
-- tracked-only copy of counts, with an explicit 0 for tracked items not in the bank
local function TrackedCounts(items)
    local out = {}
    for _, t in ipairs(Vt:Tracked()) do out[t.id] = items[t.id] or 0 end
    return out
end

local function Adopt(stamp, by, tabs, items, full)
    local snap = d().snap
    if stamp <= snap.stamp then return false end
    if snap.stamp > 0 then
        table.insert(d().history, { stamp = snap.stamp, items = TrackedCounts(snap.items) })
        while #d().history > HISTORY do table.remove(d().history, 1) end
    end
    d().snap = { stamp = stamp, by = by, tabs = tabs, items = items, full = full and true or false }
    AOR:Fire("VAULT")
    return true
end

local function BroadcastSnapshot(snap)
    local counts = TrackedCounts(snap.items)
    local ids = {}
    for id in pairs(counts) do ids[#ids + 1] = id end
    table.sort(ids)
    local total = math.max(1, math.ceil(#ids / CHUNK))
    for part = 1, total do
        local slice = {}
        for i = (part - 1) * CHUNK + 1, math.min(part * CHUNK, #ids) do
            slice[#slice + 1] = ids[i] .. ":" .. counts[ids[i]]
        end
        local msg = Enc("C", snap.stamp, snap.by, snap.tabs, part, total, table.concat(slice, ","))
        C_Timer.After((part - 1) * 0.25, function() Send(msg) end)
    end
end

------------------------------------------------------------------------
-- Guild bank scan
------------------------------------------------------------------------
local scan

local function Finish()
    local items = scan.items
    local tabs = #scan.tabs
    scan = nil
    if tabs == 0 then return end
    local stamp = Stamp(d().snap.stamp)
    if Adopt(stamp, me(), tabs, items, true) then
        BroadcastSnapshot(d().snap)
        AOR:Print(("Ash Vault: scanned %d guild bank tab%s."):format(tabs, tabs == 1 and "" or "s"))
    end
end

local Next

local function Read(token)
    if not scan or scan.token ~= token or not scan.waiting then return end
    scan.waiting = false
    local tab = scan.tabs[scan.i]
    for slot = 1, MAX_SLOTS do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then
                local _, count = GetGuildBankItemInfo(tab, slot)
                scan.items[id] = (scan.items[id] or 0) + (count or 1)
            end
        end
    end
    C_Timer.After(0.4, Next)
end

Next = function()
    if not scan then return end
    scan.i = scan.i + 1
    local tab = scan.tabs[scan.i]
    if not tab then Finish(); return end
    scan.token = (scan.token or 0) + 1
    scan.waiting = true
    local token = scan.token
    QueryGuildBankTab(tab)
    C_Timer.After(2.5, function() Read(token) end)   -- fall back if the event never comes
end

function Vt:StartScan()
    if scan or not AOR:CanPost() or not GetNumGuildBankTabs then return end
    local tabs = {}
    for t = 1, GetNumGuildBankTabs() do
        local _, _, viewable = GetGuildBankTabInfo(t)
        if viewable then tabs[#tabs + 1] = t end
    end
    if #tabs == 0 then return end
    scan = { tabs = tabs, i = 0, items = {} }
    Next()
end

pcall(AOR.RegisterEvent, AOR, "GUILDBANKFRAME_OPENED", function()
    if AOR.db and AOR:CanPost() then C_Timer.After(1, function() Vt:StartScan() end) end
end)
pcall(AOR.RegisterEvent, AOR, "GUILDBANKFRAME_CLOSED", function() scan = nil end)
pcall(AOR.RegisterEvent, AOR, "GUILDBANKBAGSLOTS_CHANGED", function()
    if scan and scan.waiting then
        local token = scan.token
        C_Timer.After(0.3, function() Read(token) end)
    end
end)

------------------------------------------------------------------------
-- Sync
------------------------------------------------------------------------
local function Entries(since)
    local out = {}
    for id, e in pairs(d().track) do
        if e.stamp >= since - 5 then
            out[#out + 1] = { key = "T" .. id, stamp = e.stamp, msg = Enc("T", id, e.stamp, e.min, e.del and 1 or 0) }
        end
    end
    return out
end

function Vt:MaxStamp()
    local m = d().snap.stamp
    for _, e in pairs(d().track) do if e.stamp > m then m = e.stamp end end
    return m
end

local function Respond(since)
    local out = Entries(since)
    table.sort(out, function(a, b) return a.stamp > b.stamp end)
    for i = 1, math.min(#out, 40) do
        local e = out[i]
        pending[e.key] = e.stamp
        C_Timer.After(1 + math.random() * 5 + i * 0.3, function()
            if pending[e.key] == e.stamp then
                pending[e.key] = nil
                Send(e.msg)
            end
        end)
    end
    local snap = d().snap
    if snap.stamp > since then
        pending["C"] = snap.stamp
        C_Timer.After(3 + math.random() * 5, function()
            if pending["C"] == snap.stamp then
                pending["C"] = nil
                BroadcastSnapshot(snap)
            end
        end)
    end
end

local function Handle(text, sender)
    local tag, a, b, c, dd, e, f = strsplit("|", text)
    if short(sender) == me() then return end
    if tag == "Q" then
        if IsOfficerName(sender) then Respond(tonumber(a) or 0) end
        return
    end
    if not IsOfficerName(sender) then return end

    if tag == "T" then
        local id, stamp, min = tonumber(a), tonumber(b), tonumber(c)
        if not (id and stamp and min) then return end
        if pending["T" .. id] and pending["T" .. id] <= stamp then pending["T" .. id] = nil end
        local cur = d().track[id]
        if cur and cur.stamp >= stamp then return end
        d().track[id] = { stamp = stamp, min = math.max(0, min), del = (dd == "1") }
        AOR:Fire("VAULT")

    elseif tag == "C" then
        local stamp, by, tabs, part, total = tonumber(a), b, tonumber(c), tonumber(dd), tonumber(e)
        if not (stamp and by and tabs and part and total) or total < 1 or part < 1 or part > total then return end
        if pending["C"] and pending["C"] <= stamp then pending["C"] = nil end
        if stamp <= d().snap.stamp then return end
        local key = tostring(stamp)
        local buf = incoming[key]
        if not buf then
            buf = { total = total, parts = {}, got = 0 }
            incoming[key] = buf
        end
        if not buf.parts[part] then
            local items = {}
            for entry in (f or ""):gmatch("[^,]+") do
                local id, n = strsplit(":", entry)
                id, n = tonumber(id), tonumber(n)
                if id and n then items[id] = n end
            end
            buf.parts[part] = items
            buf.got = buf.got + 1
        end
        if buf.got == buf.total then
            incoming[key] = nil
            local all = {}
            for i = 1, buf.total do
                for id, n in pairs(buf.parts[i]) do all[id] = n end
            end
            Adopt(stamp, by, tabs, all, false)
        end
    end
end

AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or not text or not AOR.db then return end
    Handle(text, sender)
end)

local synced
AOR:Subscribe("ROSTER", function()
    if synced or not IsInGuild() or not AOR.db then return end
    synced = true
    C_Timer.After(7, function()
        if AOR:CanPost() then Send("Q|" .. Vt:MaxStamp()) end
    end)
end)

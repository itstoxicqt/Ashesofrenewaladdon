local _, AOR = ...

------------------------------------------------------------------------
-- The Forge: guild crafting ledger
--
-- Every member's addon scans their own professions when a profession
-- window is opened, stores the learned recipes grouped by profession and
-- tier, and shares them with the guild. Others cache what they receive
-- (it persists between sessions). Recipes linked in guild/officer chat
-- are also recorded, marked as "linked" because they are unverified.
--
-- Messages (prefix AORForge). A member can only write their own data.
--   P|stamp|setCount|Prof:skill:max,...   profession summary
--   R|prof|tier|stamp|part|total|ids      recipe set, in chunks
--   D|stamp|since                         "everything up to stamp was sent"
--   G|since                               whisper: send me your sets newer than since
--   Q|                                    broadcast: please whisper me your summary
------------------------------------------------------------------------
local F = {}
AOR.Forge = F

local PREFIX = "AORForge"
local CHUNK = 20
local incoming, asked, cooldown, requested = {}, {}, {}, {}
local spellCache = {}

local function d() return AOR.db.forge end
local function short(n) return Ambiguate(n or "", "short") end
local function me() return UnitName("player") end
local function Enc(...) return table.concat({ ... }, "|") end

local function clean(s, n)
    s = tostring(s or ""):gsub("[|:,]", " ")
    return strtrim(s):sub(1, n or 24)
end

local function Member(name, create)
    local m = d().members[name]
    if not m and create then
        m = { stamp = 0, n = 0, sync = 0, profs = {}, recipes = {}, linked = {} }
        d().members[name] = m
    end
    return m
end

local firePending
local function Touch()
    F.dirty = true
    if firePending then return end
    firePending = true
    C_Timer.After(0.5, function()
        firePending = false
        AOR:Fire("FORGE")
    end)
end

local function SetCount(m)
    local n = 0
    for _, tiers in pairs(m.recipes) do
        for _ in pairs(tiers) do n = n + 1 end
    end
    return n
end

function F:RecipeCount(m)
    local n = 0
    for _, tiers in pairs(m.recipes) do
        for _, rec in pairs(tiers) do n = n + #rec.ids end
    end
    return n
end

------------------------------------------------------------------------
-- Spell names/icons (recipes are spells)
------------------------------------------------------------------------
function F:SpellData(id)
    local c = spellCache[id]
    if c then return c[1], c[2] end
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then name, icon = info.name, info.iconID end
    elseif GetSpellInfo then
        local n, _, ic = GetSpellInfo(id)
        name, icon = n, ic
    end
    if name then
        spellCache[id] = { name, icon or 134400 }
        return name, icon or 134400
    end
    if C_Spell and C_Spell.RequestLoadSpellData and not requested[id] then
        requested[id] = true
        C_Spell.RequestLoadSpellData(id)
    end
    return "Recipe " .. id, 134400
end

------------------------------------------------------------------------
-- Sending (one message at a time so we never trip the addon throttle)
------------------------------------------------------------------------
local queue, pumping = {}, false

local function Pump()
    local item = table.remove(queue, 1)
    if not item then pumping = false; return end
    C_ChatInfo.SendAddonMessage(PREFIX, item.msg, item.channel, item.target)
    C_Timer.After(0.15, Pump)
end

local function Queue(msg, channel, target)
    channel = channel or "GUILD"
    if channel == "GUILD" and not IsInGuild() then return end
    queue[#queue + 1] = { msg = msg, channel = channel, target = target }
    if not pumping then pumping = true; Pump() end
end

local function ProfSummary(m)
    local parts = {}
    for prof, p in pairs(m.profs) do
        parts[#parts + 1] = ("%s:%d:%d"):format(clean(prof, 20), p.skill or 0, p.max or 0)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function F:SendSummary(channel, target)
    local m = Member(me())
    if not m or m.stamp == 0 then return end
    Queue(Enc("P", m.stamp, SetCount(m), ProfSummary(m)), channel, target)
end

-- Sends own recipe sets newer than `since`, then a D marker.
function F:SendRecipes(channel, target, since, onlyProf)
    local m = Member(me())
    if not m then return end
    since = since or 0
    for prof, tiers in pairs(m.recipes) do
        if not onlyProf or prof == onlyProf then
            for tier, rec in pairs(tiers) do
                if rec.stamp > since then
                    local total = math.max(1, math.ceil(#rec.ids / CHUNK))
                    for part = 1, total do
                        local slice = {}
                        for i = (part - 1) * CHUNK + 1, math.min(part * CHUNK, #rec.ids) do
                            slice[#slice + 1] = rec.ids[i]
                        end
                        Queue(Enc("R", clean(prof, 20), clean(tier, 24), rec.stamp, part, total, table.concat(slice, ",")),
                            channel, target)
                    end
                end
            end
        end
    end
    Queue(Enc("D", m.stamp, since), channel, target)
end

------------------------------------------------------------------------
-- Own scan
------------------------------------------------------------------------
local function SameIds(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- tiers: tierName -> list of recipe (spell) ids
function F:Commit(prof, skill, max, tiers)
    prof = clean(prof, 20)
    if prof == "" then return end
    local m = Member(me(), true)
    local old = m.recipes[prof]

    -- a half-loaded profession window must not wipe what we already know
    if next(tiers) == nil and old and next(old) ~= nil then return end

    local stamp = time()
    local changed, recs = false, {}
    for tier, ids in pairs(tiers) do
        table.sort(ids)
        local o = old and old[tier]
        if o and SameIds(o.ids, ids) then
            recs[tier] = o
        else
            recs[tier] = { stamp = stamp, ids = ids }
            changed = true
        end
    end
    if old then
        for tier in pairs(old) do if not tiers[tier] then changed = true end end
    end
    local po = m.profs[prof]
    if not po or po.skill ~= skill or po.max ~= max then changed = true end

    m.profs[prof] = { skill = skill, max = max }
    m.recipes[prof] = recs
    if not changed then return end

    local prev = m.stamp
    m.stamp = math.max(stamp, prev + 1)
    m.sync = m.stamp
    m.n = SetCount(m)
    local count = 0
    for _, ids in pairs(tiers) do count = count + #ids end
    AOR:Print(("The Forge: catalogued %d %s recipes."):format(count, prof))

    self:SendSummary("GUILD")
    self:SendRecipes("GUILD", nil, prev, prof)
    Touch()
end

local function ScanRetail()
    local T = C_TradeSkillUI
    if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return end
    if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return end
    if T.IsNPCCrafting and T.IsNPCCrafting() then return end
    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    local prof = base and base.professionName
    if not prof or prof == "" then return end
    local ids = T.GetAllRecipeIDs and T.GetAllRecipeIDs()
    if not ids or #ids == 0 then return end

    local tierOf = {}
    local function Tier(catID)
        if not catID then return "Recipes" end
        if tierOf[catID] then return tierOf[catID] end
        local info, guard = T.GetCategoryInfo(catID), 0
        while info and info.parentCategoryID and guard < 8 do
            info = T.GetCategoryInfo(info.parentCategoryID)
            guard = guard + 1
        end
        local name = clean(info and info.name or "Recipes", 24)
        tierOf[catID] = name
        return name
    end

    local tiers = {}
    for _, rid in ipairs(ids) do
        local info = T.GetRecipeInfo(rid)
        if info and info.learned then
            local tier = Tier(info.categoryID)
            tiers[tier] = tiers[tier] or {}
            table.insert(tiers[tier], rid)
        end
    end
    F:Commit(prof, base.skillLevel or 0, base.maxSkillLevel or 0, tiers)
end

local function IdFromLink(link)
    if not link then return nil end
    local id = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
    return id and tonumber(id) or nil
end

local function ScanClassic()
    if not (GetTradeSkillLine and GetNumTradeSkills) then return end
    if IsTradeSkillLinked and IsTradeSkillLinked() then return end
    local prof, rank, max = GetTradeSkillLine()
    if not prof or prof == "" or prof == "UNKNOWN" then return end
    local n = GetNumTradeSkills() or 0
    if n == 0 then return end
    local tiers, tier = {}, "Recipes"
    for i = 1, n do
        local name, kind = GetTradeSkillInfo(i)
        if kind == "header" then
            tier = clean(name, 24)
        elseif name then
            local id = IdFromLink(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i))
            if id then
                tiers[tier] = tiers[tier] or {}
                table.insert(tiers[tier], id)
            end
        end
    end
    F:Commit(prof, rank or 0, max or 0, tiers)
end

-- Classic enchanting uses the older "craft" window
local function ScanCraft()
    if not (GetCraftDisplaySkillLine and GetNumCrafts) then return end
    local prof, rank, max = GetCraftDisplaySkillLine()
    if not prof or prof == "" then return end
    local n = GetNumCrafts() or 0
    if n == 0 then return end
    local tiers, tier = {}, "Recipes"
    for i = 1, n do
        local name, _, kind = GetCraftInfo(i)
        if kind == "header" then
            tier = clean(name, 24)
        elseif name then
            local id = IdFromLink(GetCraftRecipeLink and GetCraftRecipeLink(i))
            if id then
                tiers[tier] = tiers[tier] or {}
                table.insert(tiers[tier], id)
            end
        end
    end
    F:Commit(prof, rank or 0, max or 0, tiers)
end

function F:Scan()
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        ScanRetail()
    else
        ScanClassic()
        ScanCraft()
    end
end

local scanPending
local function QueueScan()
    if scanPending or not AOR.db then return end
    scanPending = true
    C_Timer.After(2, function()
        scanPending = false
        local ok, err = pcall(F.Scan, F)
        if not ok then geterrorhandler()(err) end
    end)
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE",
                      "CRAFT_SHOW", "CRAFT_UPDATE", "NEW_RECIPE_LEARNED" }) do
    pcall(AOR.RegisterEvent, AOR, ev, QueueScan)   -- not every client has every event
end

------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------
local function Handle(text, sender)
    local name = short(sender)
    if name == me() then return end
    local tag, a, b, c, dd, e, f = strsplit("|", text)

    if tag == "P" then
        local stamp, n = tonumber(a), tonumber(b)
        if not (stamp and n) then return end
        local m = Member(name, true)
        if stamp >= m.stamp then
            m.stamp, m.n = stamp, n
            local profs = {}
            for entry in (c or ""):gmatch("[^,]+") do
                local p, s, mx = strsplit(":", entry)
                if p and p ~= "" then profs[p] = { skill = tonumber(s) or 0, max = tonumber(mx) or 0 } end
            end
            m.profs = profs
        end
        if stamp > (m.sync or 0) and not asked[name .. stamp] then
            asked[name .. stamp] = true
            Queue("G|" .. (m.sync or 0), "WHISPER", sender)
        end
        Touch()

    elseif tag == "R" then
        local prof, tier, stamp, part, total = a, b, tonumber(c), tonumber(dd), tonumber(e)
        if not (prof and tier and stamp and part and total) or total < 1 or part < 1 or part > total then return end
        local m = Member(name, true)
        local have = m.recipes[prof] and m.recipes[prof][tier]
        if have and have.stamp >= stamp then return end
        local key = name .. "|" .. prof .. "|" .. tier
        local buf = incoming[key]
        if not buf or buf.stamp ~= stamp then
            buf = { stamp = stamp, total = total, parts = {}, got = 0 }
            incoming[key] = buf
        end
        if not buf.parts[part] then
            local ids = {}
            for n in (f or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
            buf.parts[part] = ids
            buf.got = buf.got + 1
        end
        if buf.got == buf.total then
            local all = {}
            for i = 1, buf.total do
                for _, id in ipairs(buf.parts[i]) do all[#all + 1] = id end
            end
            m.recipes[prof] = m.recipes[prof] or {}
            m.recipes[prof][tier] = { stamp = stamp, ids = all }
            incoming[key] = nil
            Touch()
        end

    elseif tag == "D" then
        local stamp, since = tonumber(a), tonumber(b) or 0
        local m = Member(name)
        if m and stamp and (m.sync or 0) >= since and stamp > (m.sync or 0) then
            m.sync = stamp
        end

    elseif tag == "G" then
        local since = tonumber(a) or 0
        if cooldown[name] and GetTime() - cooldown[name] < 120 then return end
        cooldown[name] = GetTime()
        F:SendRecipes("WHISPER", sender, since)

    elseif tag == "Q" then
        C_Timer.After(1 + math.random() * 6, function() F:SendSummary("WHISPER", sender) end)
    end
end

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or not text or not AOR.db then return end
    Handle(text, sender)
end)

------------------------------------------------------------------------
-- Recipes linked in guild / officer chat
------------------------------------------------------------------------
local function OnChat(_, text, sender)
    if not AOR.db or type(text) ~= "string" or type(sender) ~= "string" then return end
    if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
    local name = short(sender)
    if name == me() then return end
    local m
    for id in text:gmatch("|Henchant:(%d+)|h") do
        m = m or Member(name, true)
        m.linked[tonumber(id)] = time()
    end
    if m then
        local n = 0
        for id, stamp in pairs(m.linked) do n = n + 1 end
        if n > 300 then m.linked = {} end
        Touch()
    end
end
pcall(AOR.RegisterEvent, AOR, "CHAT_MSG_GUILD", OnChat)
pcall(AOR.RegisterEvent, AOR, "CHAT_MSG_OFFICER", OnChat)

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------
function F:BuildIndex()
    local idx, list = {}, {}
    local function Add(id, prof, tier, name, linked)
        local e = idx[id]
        if not e then
            e = { id = id, prof = prof, tier = tier, crafters = {}, set = {}, linked = {} }
            idx[id] = e
            list[#list + 1] = e
        end
        if not e.set[name] then
            e.set[name] = true
            e.crafters[#e.crafters + 1] = name
            if linked then e.linked[name] = true end
        end
    end
    for name, m in pairs(d().members) do
        for prof, tiers in pairs(m.recipes) do
            for tier, rec in pairs(tiers) do
                for _, id in ipairs(rec.ids) do Add(id, prof, tier, name, false) end
            end
        end
    end
    -- linked recipes only count if some synced member tells us which profession they are,
    -- or if nobody else has them (then they are listed under "Linked in chat")
    for name, m in pairs(d().members) do
        for id in pairs(m.linked) do
            local e = idx[id]
            if e then
                Add(id, e.prof, e.tier, name, true)
            else
                Add(id, "Linked in chat", "Linked", name, true)
            end
        end
    end
    self.index, self.list, self.dirty = idx, list, false
end

-- online: set of short names currently online
function F:Query(prof, search, onlineOnly, online)
    if self.dirty or not self.list then self:BuildIndex() end
    search = (search or ""):lower()
    local out = {}
    for _, e in ipairs(self.list) do
        if not prof or e.prof == prof then
            local name = self:SpellData(e.id)
            if search == "" or name:lower():find(search, 1, true) or e.prof:lower():find(search, 1, true) then
                local keep = true
                if onlineOnly then
                    keep = false
                    for _, c in ipairs(e.crafters) do
                        if online[c] then keep = true; break end
                    end
                end
                if keep then out[#out + 1] = { id = e.id, e = e, name = name } end
            end
        end
    end
    table.sort(out, function(x, y)
        local a, b = x.name:lower(), y.name:lower()
        if a ~= b then return a < b end
        return x.id < y.id
    end)
    return out
end

-- Profession list with recipe and crafter counts
function F:Professions()
    if self.dirty or not self.list then self:BuildIndex() end
    local map = {}
    local function P(name)
        map[name] = map[name] or { name = name, recipes = 0, crafters = {} }
        return map[name]
    end
    for _, e in ipairs(self.list) do
        local p = P(e.prof)
        p.recipes = p.recipes + 1
    end
    for name, m in pairs(d().members) do
        for prof in pairs(m.profs) do P(prof).crafters[name] = true end
        for prof, tiers in pairs(m.recipes) do
            if next(tiers) then P(prof).crafters[name] = true end
        end
    end
    local out, total = {}, 0
    for _, p in pairs(map) do
        local c = 0
        for _ in pairs(p.crafters) do c = c + 1 end
        p.crafterCount = c
        out[#out + 1] = p
        total = total + p.recipes
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out, total
end

function F:Members(search, onlineOnly, online)
    search = (search or ""):lower()
    local out = {}
    for name, m in pairs(d().members) do
        local profs = {}
        for prof, p in pairs(m.profs) do
            profs[#profs + 1] = ("%s %d/%d"):format(prof, p.skill or 0, p.max or 0)
        end
        table.sort(profs)
        local text = table.concat(profs, "   ")
        if #profs > 0 or self:RecipeCount(m) > 0 then
            if (search == "" or name:lower():find(search, 1, true) or text:lower():find(search, 1, true))
               and (not onlineOnly or online[name]) then
                out[#out + 1] = { name = name, profs = text, recipes = self:RecipeCount(m), online = online[name] and true or false }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function F:CrafterCount()
    local n = 0
    for _, m in pairs(d().members) do
        if next(m.profs) then n = n + 1 end
    end
    return n
end

-- Online members who run the addon but have shared no professions yet
function F:UnsyncedOnline()
    local R, S = AOR.Roster, AOR.Sync
    if not (R and S and R.list) then return 0 end
    local me_, n = me(), 0
    for _, e in ipairs(R.list) do
        if e.online and not e.mobile and e.short ~= me_ and S.peers[e.short] then
            local m = d().members[e.short]
            if not m or next(m.profs) == nil then n = n + 1 end
        end
    end
    return n
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------
AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    pcall(AOR.RegisterEvent, AOR, "SPELL_DATA_LOAD_RESULT", function() Touch() end)
end)

local started
AOR:Subscribe("ROSTER", function(list)
    if started or not IsInGuild() or not AOR.db then return end
    started = true

    -- forget people who have left the guild
    if list and #list > 0 then
        local inGuild = {}
        for _, e in ipairs(list) do inGuild[e.short] = true end
        for name in pairs(d().members) do
            if not inGuild[name] and name ~= me() then d().members[name] = nil end
        end
    end

    C_Timer.After(8, function()
        local m = Member(me())
        if m and m.stamp > 0 then
            F:SendSummary("GUILD")
        else
            AOR:Print("The Forge: open each of your profession windows once so your recipes can be shared with the guild.")
        end
    end)
    C_Timer.After(14, function() Queue("Q|", "GUILD") end)
end)

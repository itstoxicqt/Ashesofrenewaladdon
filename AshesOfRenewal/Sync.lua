local _, AOR = ...

-- Lightweight version handshake over the guild addon channel.
--   "V|<version>"  broadcast once after login (asks everyone to answer)
--   "v|<version>"  whispered reply to a "V" (never answered, so no storms)
-- The Hearth uses this to tell officers who is missing the addon or running
-- an older version.
local S = { peers = {} }
AOR.Sync = S

local PREFIX = AOR.prefix

local function Parse(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

local function Cmp(a, b)
    local x, y = Parse(a), Parse(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p < q and -1 or 1 end
    end
    return 0
end

-- Returns: online members without the addon, online members on an older
-- version than the newest one seen, and that newest version.
-- Quiet (zeros) for the first seconds after login while replies arrive.
function S:Coverage()
    local newest = AOR.version
    for _, v in pairs(self.peers) do
        if Cmp(v, newest) > 0 then newest = v end
    end
    local R = AOR.Roster
    if not R or not AOR.loginAt or GetTime() - AOR.loginAt < 25 then return 0, 0, newest end
    local me, missing, old = AOR:Me(), 0, 0
    for _, e in ipairs(R.list) do
        if e.online and not e.mobile and e.short ~= me then
            local v = self.peers[e.short]
            if not v then
                missing = missing + 1
            elseif Cmp(v, newest) < 0 then
                old = old + 1
            end
        end
    end
    return missing, old, newest
end

local function Hello()
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, "V|" .. AOR.version, "GUILD")
    end
end

AOR:OnInit(function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end)

local greeted
AOR:Subscribe("ROSTER", function()
    if greeted or not IsInGuild() then return end
    greeted = true
    C_Timer.After(6, Hello)
end)

AOR:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, _, sender)
    if prefix ~= PREFIX or not text then return end
    local tag, ver = strsplit("|", text)
    if tag ~= "V" and tag ~= "v" then return end
    local short = Ambiguate(sender or "", "short")
    if short == AOR:Me() then return end
    S.peers[short] = ver
    AOR:Fire("PEERS")
    if tag == "V" then
        C_Timer.After(1 + math.random() * 4, function()
            C_ChatInfo.SendAddonMessage(PREFIX, "v|" .. AOR.version, "WHISPER", sender)
        end)
    end
end)

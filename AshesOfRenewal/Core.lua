local ADDON, AOR = ...
_G.AshesOfRenewal = AOR

------------------------------------------------------------------------
-- GUILD CONFIG: edit this block to customise the addon for your guild
------------------------------------------------------------------------
AOR.config = {
    guildName   = "Ashes of Renewal",
    -- Ember Reserve
    maxReserves = 1,    -- soft reserves each member may hold
    lockMinutes = 30,   -- reserves freeze this many minutes before the next Conclave event
    -- Headline on the Hearth dashboard.
    tagline     = "The fire is still burning.",
    -- Shown as a chip in the window header. Leave "" to hide it.
    season      = "Season I - Ember",
    -- Who can post on the Board and see officer sections. Either rule is enough:
    --   postRankNames: rank names (case-insensitive), e.g. { "Council" }
    --   postRankMax:   highest rank index allowed (0 = Guild Master, 1 = next rank down, ...)
    -- Not sure of your rank index? Type /aor rank in game.
    postRankNames = { "Council" },
    postRankMax = 0,
    -- Buttons shown on the Home tab (click opens a copy box). Leave url = "" to hide one.
    links = {
        { label = "Discord", url = "https://discord.gg/your-invite" },
        { label = "Website", url = "https://example.com" },
    },
    icon = "Interface\\Icons\\Spell_Fire_Fire",
}

AOR.prefix  = "AORBoard"
AOR.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "1.0.0"
AOR.rosterRank = {}
AOR.rosterRankName = {}

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
AOR.colors = {
    bg      = { 0.055, 0.047, 0.047, 0.97 },
    panel   = { 0.100, 0.085, 0.085, 1.00 },
    panelHi = { 0.155, 0.125, 0.115, 1.00 },
    border  = { 0.230, 0.175, 0.150, 1.00 },
    ember   = { 1.000, 0.460, 0.125, 1.00 },
    gold    = { 0.960, 0.780, 0.360, 1.00 },
    text    = { 0.930, 0.890, 0.860, 1.00 },
    dim     = { 0.600, 0.550, 0.520, 1.00 },
    good    = { 0.400, 0.850, 0.450, 1.00 },
    bad     = { 0.900, 0.300, 0.250, 1.00 },
}
local C = AOR.colors

function AOR:Hex(c)
    return string.format("%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function AOR:Print(msg)
    print("|cff" .. self:Hex(C.ember) .. "Ashes of Renewal|r " .. msg)
end

function AOR:ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function AOR:ColorName(name, classFile)
    local c = classFile and RAID_CLASS_COLORS[classFile]
    return c and c:WrapTextInColorCode(name) or name
end

------------------------------------------------------------------------
-- Tiny event + callback system
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function AOR:RegisterEvent(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then
        for i = 1, #list do list[i](AOR, ...) end
    end
end)

local subs = {}
function AOR:Subscribe(name, fn)
    subs[name] = subs[name] or {}
    table.insert(subs[name], fn)
end

function AOR:Fire(name, ...)
    local list = subs[name]
    if list then
        for i = 1, #list do list[i](...) end
    end
end

------------------------------------------------------------------------
-- Saved variables + init
------------------------------------------------------------------------
local defaults = {
    toasts = true, minimapAngle = 215, minimapHide = false, board = {},
    forge = { members = {} },
    reserve = {
        season = 1, seasonStamp = 0, epoch = 0,
        lock = { stamp = 0, mode = "A" },   -- A = auto (follows Conclave), L = locked, O = held open
        pool = {}, hard = {}, soft = {}, plus = {}, log = {},
    },
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                Merge(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
end

local initFns = {}
function AOR:OnInit(fn) table.insert(initFns, fn) end

AOR:RegisterEvent("ADDON_LOADED", function(self, name)
    if name ~= ADDON then return end
    AshesOfRenewalDB = AshesOfRenewalDB or {}
    Merge(AshesOfRenewalDB, defaults)
    self.db = AshesOfRenewalDB
end)

AOR:RegisterEvent("PLAYER_LOGIN", function(self)
    self.loginAt = GetTime()
    for _, fn in ipairs(initFns) do fn(self) end
    if IsInGuild() then C_GuildInfo.GuildRoster() end
end)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function AOR:RankCanPost(rankName, rankIndex)
    if rankName and rankName ~= "" then
        local lower = strlower(rankName)
        for _, n in ipairs(self.config.postRankNames or {}) do
            if strlower(n) == lower then return true end
        end
    end
    return rankIndex ~= nil and rankIndex <= self.config.postRankMax
end

function AOR:CanPost()
    if not IsInGuild() then return false end
    local _, rankName, rankIndex = GetGuildInfo("player")
    return self:RankCanPost(rankName, rankIndex)
end

function AOR:Toggle()
    if not IsInGuild() then
        self:Print("You are not in a guild.")
        return
    end
    self.UI:Toggle()
end

SLASH_ASHESOFRENEWAL1 = "/aor"
SLASH_ASHESOFRENEWAL2 = "/ashes"
SlashCmdList["ASHESOFRENEWAL"] = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        AOR:Toggle()
    elseif cmd == "toasts" then
        AOR.db.toasts = not AOR.db.toasts
        AOR:Print("Alerts " .. (AOR.db.toasts and "enabled." or "disabled."))
    elseif cmd == "rank" then
        local _, rankName, rankIndex = GetGuildInfo("player")
        AOR:Print(("Your guild rank: %s (index %s). Can post: %s."):format(
            tostring(rankName), tostring(rankIndex), AOR:CanPost() and "yes" or "no"))
    elseif cmd == "minimap" then
        AOR.db.minimapHide = not AOR.db.minimapHide
        if AOR.UpdateMinimap then AOR:UpdateMinimap() end
    else
        AOR:Print("Commands: /aor  |  /aor toasts  |  /aor minimap  |  /aor rank")
    end
end

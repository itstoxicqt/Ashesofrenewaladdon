local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

------------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------------
local toast
local queue, showing = {}, false

local function BuildToast()
    toast = UI:NewFrame(UIParent, C.bg, C.ember)
    toast:SetSize(330, 48)
    toast:SetPoint("TOP", 0, -140)
    toast:SetFrameStrata("FULLSCREEN_DIALOG")
    toast:Hide()
    local stripe = toast:CreateTexture(nil, "ARTWORK")
    stripe:SetColorTexture(unpack(C.ember))
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", 1, 1)
    local icon = toast:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture(AOR.config.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    toast.line1 = UI:Text(toast, 13, C.gold)
    toast.line1:SetPoint("TOPLEFT", 48, -9)
    toast.line1:SetWidth(270)
    toast.line1:SetWordWrap(false)
    toast.line2 = UI:Text(toast, 11, C.dim)
    toast.line2:SetPoint("TOPLEFT", 48, -27)
    toast.line2:SetWidth(270)
    toast.line2:SetWordWrap(false)
end

local function NextToast()
    if showing or #queue == 0 then return end
    showing = true
    if not toast then BuildToast() end
    local t = table.remove(queue, 1)
    toast.line1:SetText(t.head)
    toast.line2:SetText(t.sub or "")
    UIFrameFadeIn(toast, 0.3, 0, 1)
    C_Timer.After(4, function()
        UIFrameFadeOut(toast, 0.5, 1, 0)
        C_Timer.After(0.6, function()
            toast:Hide()
            showing = false
            NextToast()
        end)
    end)
end

-- kind "online" toasts can be switched off separately (/aor online or the settings panel)
function AOR:Toast(head, sub, kind)
    if not self.db.toasts then return end
    if kind == "online" and self.db.onlineToasts == false then return end
    queue[#queue + 1] = { head = head, sub = sub }
    if #queue > 5 then table.remove(queue, 1) end
    NextToast()
end

------------------------------------------------------------------------
-- Alerts: guild members coming online, new board posts, login greeting
------------------------------------------------------------------------
local prev
AOR:Subscribe("ROSTER", function(list)
    local now = {}
    for _, e in ipairs(list) do
        if e.online then now[e.name] = true end
    end
    local quiet = (not prev) or (AOR.loginAt and GetTime() - AOR.loginAt < 10)
    if not quiet then
        for _, e in ipairs(list) do
            if e.online and not prev[e.name] and e.short ~= AOR:Me() then
                AOR:Toast(AOR:ColorName(e.short, e.classFile) .. " is online",
                    ("Level %d %s  -  %s"):format(e.level, e.class, e.zone), "online")
            end
        end
    end
    prev = now
end)

AOR:OnInit(function()
    AOR:Subscribe("BOARD_NEW", function(e)
        if e.kind == "E" then
            AOR:Toast("New event: " .. e.title, date("%a %b %d, %I:%M %p", e.evt))
            AOR:Print("New event posted: " .. e.title .. " (" .. date("%a %b %d, %I:%M %p", e.evt) .. ")")
        else
            AOR:Toast("New announcement", e.title)
            AOR:Print("New announcement: " .. e.title)
        end
    end)

    local greeted
    AOR:Subscribe("ROSTER", function()
        if greeted or not IsInGuild() then return end
        greeted = true
        C_Timer.After(5, function()
            local motd = GetGuildRosterMOTD()
            AOR:Print("Welcome back. " .. AOR.Roster.onlineCount .. " guildmates online. Type |cff" .. AOR:Hex(C.gold) .. "/aor|r to open the hub.")
            if motd and motd ~= "" then AOR:Print("MOTD: " .. motd) end
            local ev = AOR.Board:GetNext()
            if ev then
                AOR:Print("Next event: |cff" .. AOR:Hex(C.gold) .. ev.title .. "|r " .. AOR.Board.Countdown(ev.evt))
            end
        end)
    end)
end)

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local button

local function Place()
    local angle = math.rad(AOR.db.minimapAngle)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function AOR:UpdateMinimap()
    if not button then return end
    button:SetShown(not self.db.minimapHide)
    if self.db.minimapHide then self:Print("Minimap button hidden. /aor minimap to show it again.") end
end

AOR:OnInit(function()
    button = CreateFrame("Button", "AshesOfRenewalMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430)
    overlay:SetPoint("TOPLEFT")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture(136467)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(AOR.config.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -6)

    button:SetScript("OnClick", function() AOR:Toggle() end)
    button:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(AOR.config.guildName, unpack(C.gold))
        GameTooltip:AddLine(AOR.Roster.onlineCount .. " online", unpack(C.good))
        GameTooltip:AddLine("Click to open the guild hub. Drag to move.", 0.6, 0.55, 0.52)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:SetScript("OnDragStart", function(s)
        s:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            AOR.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)

    Place()
    button:SetShown(not AOR.db.minimapHide)
end)

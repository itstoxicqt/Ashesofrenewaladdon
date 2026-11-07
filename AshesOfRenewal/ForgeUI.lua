local _, AOR = ...
local UI, C = AOR.UI, AOR.colors
local F = AOR.Forge

local V = {
    view = "recipes", prof = nil, search = "", onlineOnly = false,
    online = {}, classMap = {}, tabs = {}, frames = {}, profButtons = {},
}
AOR.ForgeUI = V

local PROF_W, MAX_PROF_BUTTONS = 160, 16
local OFFLINE_HEX = "8a7f78"

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Whisper(name)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    open("/w " .. name .. " ")
end

local function CrafterText(e)
    -- online crafters first, then the rest; online in class colour, offline greyed
    local names = {}
    for _, c in ipairs(e.crafters) do names[#names + 1] = c end
    table.sort(names, function(a, b)
        local oa, ob = V.online[a] and true or false, V.online[b] and true or false
        if oa ~= ob then return oa end
        return a:lower() < b:lower()
    end)
    local parts = {}
    for i, n in ipairs(names) do
        if i > 3 then parts[#parts + 1] = ("+%d"):format(#names - 3); break end
        if V.online[n] then
            parts[#parts + 1] = AOR:ColorName(n, V.classMap[n])
        else
            parts[#parts + 1] = ("|cff%s%s|r"):format(OFFLINE_HEX, n)
        end
    end
    return table.concat(parts, ", "), names
end

local function FirstOnline(e)
    local best
    for _, c in ipairs(e.crafters) do
        if V.online[c] and (not best or c:lower() < best:lower()) then best = c end
    end
    return best
end

------------------------------------------------------------------------
-- Recipe rows
------------------------------------------------------------------------
local function MakeRecipeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.12)
    r.hl:Hide()
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 36, 0)
    r.name:SetWidth(240)
    r.name:SetWordWrap(false)
    r.tier = UI:Text(r, 11, C.dim)
    r.tier:SetPoint("LEFT", 284, 0)
    r.tier:SetWidth(130)
    r.tier:SetWordWrap(false)
    r.crafters = UI:Text(r, 12, C.text)
    r.crafters:SetPoint("LEFT", 420, 0)
    r.crafters:SetWidth(240)
    r.crafters:SetWordWrap(false)

    r:SetScript("OnEnter", function(s)
        s.hl:Show()
        local row = s.data
        if not row then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(row.name, 1, 1, 1)
        GameTooltip:AddLine(("%s  -  %s"):format(row.e.prof, row.e.tier), 0.6, 0.55, 0.52)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Crafters", 0.96, 0.78, 0.36)
        local _, names = CrafterText(row.e)
        for _, n in ipairs(names) do
            local line = n .. (V.online[n] and "  (online)" or "")
            if row.e.linked[n] then line = line .. "  (linked in chat)" end
            if V.online[n] then
                GameTooltip:AddLine(line, 0.4, 0.85, 0.45)
            else
                GameTooltip:AddLine(line, 0.6, 0.55, 0.52)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: whisper an online crafter", 0.6, 0.55, 0.52)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s)
        local row = s.data
        if not row then return end
        local who = FirstOnline(row.e)
        if who then Whisper(who) else AOR:Print("No crafters for that recipe are online right now.") end
    end)
    return r
end

local function UpdateRecipeRow(r, row, index)
    local _, icon = F:SpellData(row.id)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    r.icon:SetTexture(icon)
    r.name:SetText(row.name)
    r.tier:SetText(row.e.tier)
    r.crafters:SetText((CrafterText(row.e)))
end

------------------------------------------------------------------------
-- Crafter rows
------------------------------------------------------------------------
local function MakeMemberRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "ARTWORK")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.46, 0.125, 0.12)
    r.hl:Hide()
    r.dot = r:CreateTexture(nil, "OVERLAY")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 6, 0)
    r.name = UI:Text(r, 13, C.text)
    r.name:SetPoint("LEFT", 20, 0)
    r.name:SetWidth(170)
    r.name:SetWordWrap(false)
    -- one clickable chip per profession: opens that member's profession window
    r.chips = {}
    for i = 1, 4 do
        local b = UI:Button(r, "", 120, 20, function(s)
            local row = s:GetParent()
            if not (row.data and s.prof) then return end
            local ok, msg = F:ViewProfession(row.data.name, s.prof)
            if not ok and msg then AOR:Print(msg) end
        end)
        b:SetPoint("LEFT", 196 + (i - 1) * 124, 0)
        b.text:SetWidth(112)
        b.text:SetWordWrap(false)
        b.text:SetTextColor(unpack(C.gold))
        b:SetScript("OnEnter", function(s)
            s:SetBackdropBorderColor(unpack(C.ember))
            local row = s:GetParent()
            if row.hl then row.hl:Show() end
            if row.data and s.prof then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine(("%s - %s"):format(row.data.name, s.prof), 1, 1, 1)
                GameTooltip:AddLine("Click to open their profession window", 0.6, 0.55, 0.52)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(C.border))
            local row = s:GetParent()
            if row.hl then row.hl:Hide() end
            GameTooltip:Hide()
        end)
        b:Hide()
        r.chips[i] = b
    end
    r.count = UI:Text(r, 11, C.dim)
    r.count:SetPoint("RIGHT", -18, 0)
    r.count:SetWidth(110)
    r.count:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(s) s.hl:Show() end)
    r:SetScript("OnLeave", function(s) s.hl:Hide() end)
    r:SetScript("OnClick", function(s)
        if s.data then Whisper(s.data.name) end
    end)
    return r
end

local function UpdateMemberRow(r, m, index)
    r.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.035 or 0)
    if m.online then r.dot:SetColorTexture(unpack(C.good)) else r.dot:SetColorTexture(0.3, 0.27, 0.26, 1) end
    r.name:SetText(m.name)
    local cr, cg, cb = AOR:ClassColor(V.classMap[m.name])
    r.name:SetTextColor(cr, cg, cb, m.online and 1 or 0.5)
    for i, b in ipairs(r.chips) do
        local p = m.plist[i]
        if p then
            b.prof = p.name
            b.text:SetText(p.skill > 0 and ("%s %d"):format(p.name, p.skill) or p.name)
            b:SetAlpha(m.online and 1 or 0.7)
            b:Show()
        else
            b.prof = nil
            b:Hide()
        end
    end
    r.count:SetText(m.recipes > 0 and (m.recipes .. " recipes") or "")
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function BuildRecipes(v)
    local head = UI:Text(v, 10, C.dim)
    head:SetPoint("TOPLEFT", 4, -4)
    head:SetText("PROFESSION")

    for i = 1, MAX_PROF_BUTTONS do
        local b = UI:Button(v, "", PROF_W, 26, function(s)
            V.prof = s.prof
            V:Refresh()
        end)
        b:SetPoint("TOPLEFT", 0, -22 - (i - 1) * 29)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 10, 0)
        b.text:SetWidth(PROF_W - 54)
        b.text:SetWordWrap(false)
        b.count = UI:Text(b, 10, C.dim)
        b.count:SetPoint("RIGHT", -8, 0)
        b.count:SetJustifyH("RIGHT")
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(s.selected and C.ember or C.border))
        end)
        b:Hide()
        V.profButtons[i] = b
    end

    local h1 = UI:Text(v, 10, C.dim)
    h1:SetPoint("TOPLEFT", PROF_W + 16 + 36, -4)
    h1:SetText("RECIPE")
    local h2 = UI:Text(v, 10, C.dim)
    h2:SetPoint("TOPLEFT", PROF_W + 16 + 284, -4)
    h2:SetText("TIER")
    local h3 = UI:Text(v, 10, C.dim)
    h3:SetPoint("TOPLEFT", PROF_W + 16 + 420, -4)
    h3:SetText("CRAFTERS")
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", PROF_W + 16, -20)
    line:SetPoint("TOPRIGHT", 0, -20)

    V.recipeList = UI:VirtualList(v, 28, 19, MakeRecipeRow, 0)
    V.recipeList:SetPoint("TOPLEFT", PROF_W + 16, -24)
    V.recipeList:SetPoint("BOTTOMRIGHT", 0, 0)
    V.recipeList.onUpdateRow = UpdateRecipeRow

    V.empty = UI:Text(v, 13, C.dim)
    V.empty:SetPoint("CENTER", PROF_W / 2 + 8, -10)
    V.empty:SetWidth(460)
    V.empty:SetJustifyH("CENTER")
end

local function BuildMembers(v)
    local h1 = UI:Text(v, 10, C.dim)
    h1:SetPoint("TOPLEFT", 20, -4)
    h1:SetText("MEMBER")
    local h2 = UI:Text(v, 10, C.dim)
    h2:SetPoint("TOPLEFT", 196, -4)
    h2:SetText("PROFESSIONS  (click one to open their window)")
    local line = v:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -20)
    line:SetPoint("TOPRIGHT", 0, -20)

    V.memberList = UI:VirtualList(v, 26, 20, MakeMemberRow, 0)
    V.memberList:SetPoint("TOPLEFT", 0, -24)
    V.memberList:SetPoint("BOTTOMRIGHT", 0, 0)
    V.memberList.onUpdateRow = UpdateMemberRow

    V.memberEmpty = UI:Text(v, 13, C.dim)
    V.memberEmpty:SetPoint("CENTER", 0, -10)
    V.memberEmpty:SetText("No crafters catalogued yet.")
end

function V:Show(view)
    self.view = view
    for key, f in pairs(self.frames) do f:SetShown(key == view) end
    for key, b in pairs(self.tabs) do
        b:SetBackdropBorderColor(unpack(key == view and C.ember or C.border))
    end
    self:Refresh()
end

function V:Refresh()
    if not self.frames.recipes then return end

    -- who is online / class colours
    wipe(self.online)
    wipe(self.classMap)
    local roster = AOR.Roster and AOR.Roster.list
    if roster then
        for _, e in ipairs(roster) do
            self.classMap[e.short] = e.classFile
            if e.online then self.online[e.short] = true end
        end
    end

    local profs, total = F:Professions()
    self.info:SetText(("%d crafters  -  %d recipes catalogued"):format(F:CrafterCount(), total))

    if self.view == "recipes" then
        -- "All" + professions
        local entries = { { name = nil, label = "All professions", n = total } }
        for _, p in ipairs(profs) do
            entries[#entries + 1] = { name = p.name, label = p.name, n = p.recipes }
        end
        if self.prof then
            local found
            for _, en in ipairs(entries) do if en.name == self.prof then found = true end end
            if not found then self.prof = nil end
        end
        for i, b in ipairs(self.profButtons) do
            local en = entries[i]
            if en then
                b.prof = en.name
                b.text:SetText(en.label)
                b.count:SetText(en.n)
                b.selected = (en.name == self.prof)
                b:SetBackdropBorderColor(unpack(b.selected and C.ember or C.border))
                b.text:SetTextColor(unpack(b.selected and C.gold or C.text))
                b:Show()
            else
                b:Hide()
            end
        end

        local rows = F:Query(self.prof, self.search, self.onlineOnly, self.online)
        self.recipeList:SetData(rows)
        self.empty:SetShown(#rows == 0)
        if total == 0 then
            self.empty:SetText("Nothing catalogued yet.\nOpen a profession window to scan yours.\nGuildmates running the addon share theirs automatically.")
        else
            self.empty:SetText("No recipes match.")
        end
    else
        local rows = F:Members(self.search, self.onlineOnly, self.online)
        self.memberList:SetData(rows)
        self.memberEmpty:SetShown(#rows == 0)
    end
end

local function Init(page)
    local x = 0
    for _, t in ipairs({ { "recipes", "Recipes", 100 }, { "crafters", "Crafters", 100 } }) do
        local key = t[1]
        local b = UI:Button(page, t[2], t[3], 26, function() V:Show(key) end)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropBorderColor(unpack(V.view == key and C.ember or C.border))
        end)
        x = x + t[3] + 6
        V.tabs[key] = b
    end

    local search = UI:EditBox(page, 240, 26, "Search recipes, professions or crafters...")
    search:SetPoint("TOPLEFT", 222, 0)
    search:HookScript("OnTextChanged", function(s)
        V.search = s:GetText() or ""
        V:Refresh()
    end)
    local only = UI:Check(page, "Online only", function(v)
        V.onlineOnly = v
        V:Refresh()
    end)
    only:SetPoint("LEFT", search, "RIGHT", 14, 0)

    V.info = UI:Text(page, 11, C.dim)
    V.info:SetPoint("TOPRIGHT", 0, -7)
    V.info:SetJustifyH("RIGHT")

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 0, -38)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    for _, key in ipairs({ "recipes", "crafters" }) do
        local f = CreateFrame("Frame", nil, body)
        f:SetAllPoints()
        f:Hide()
        V.frames[key] = f
    end
    BuildRecipes(V.frames.recipes)
    BuildMembers(V.frames.crafters)

    C_Timer.NewTicker(30, function()
        if page:IsVisible() then V:Refresh() end
    end)
    V:Show("recipes")
end

UI:RegisterTab("forge", "The Forge", Init, function() V:Refresh() end,
    { group = "GUILD", hint = "Craft", title = "The Forge" })

AOR:Subscribe("FORGE", function() UI:Refresh() end)

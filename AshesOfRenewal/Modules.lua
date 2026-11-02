local _, AOR = ...
local UI, C = AOR.UI, AOR.colors

------------------------------------------------------------------------
-- Planned modules. Each one gets a sidebar entry and a placeholder page
-- until it is built. To build one: remove it from this list and register
-- a real tab with UI:RegisterTab in its own file (and add the file to the .toc).
------------------------------------------------------------------------
local planned = {
    { key = "commission", label = "Commission",    group = "GUILD",    hint = "Requests",
      blurb = "Craft request board with fees, plus a live view of which crafters are online and able to fill each request." },
    { key = "watch",      label = "Ember Watch",   group = "RAID",     hint = "Attend.",
      blurb = "Raid attendance history for every member." },
    { key = "cinder",     label = "Cinder",        group = "RAID",     hint = "Prep",
      blurb = "Pre-raid preparation checks for consumables and readiness." },
    { key = "vault",      label = "Ash Vault",     group = "OFFICERS", hint = "Bank",     officer = true,
      blurb = "Bank ledger for flasks, potions and stones, with low-stock warnings and officer snapshots you can check mid-raid." },
    { key = "herald",     label = "Herald",        group = "OFFICERS", hint = "News",     officer = true,
      blurb = "Officer directives and system notices that feed the dashboard's needs-attention strip." },
    { key = "kindling",   label = "Kindling",      group = "OFFICERS", hint = "Recruit",  officer = true,
      blurb = "Recruitment hub that collects applications and whispers from unguilded prospects." },
    { key = "embers",     label = "Embers",        group = "OFFICERS", hint = "Kudos",    officer = true,
      blurb = "Peer commendations and contribution highlights." },
}

local function MakePlaceholder(m)
    return function(page)
        local card = UI:NewFrame(page, C.panel, C.border)
        card:SetSize(460, 150)
        card:SetPoint("CENTER", 0, 30)

        local tag = UI:Text(card, 10, C.ember)
        tag:SetPoint("TOPLEFT", 20, -18)
        tag:SetText("PLANNED MODULE")

        local name = UI:Text(card, 20, C.gold, "Fonts\\FRIZQT__.TTF")
        name:SetPoint("TOPLEFT", 20, -38)
        name:SetText(m.label)

        local body = UI:Text(card, 12, C.dim)
        body:SetPoint("TOPLEFT", 20, -72)
        body:SetSize(420, 60)
        body:SetJustifyV("TOP")
        body:SetWordWrap(true)
        body:SetText(m.blurb)
    end
end

for _, m in ipairs(planned) do
    UI:RegisterTab(m.key, m.label, MakePlaceholder(m), nil,
        { group = m.group, hint = m.hint, officer = m.officer })
end

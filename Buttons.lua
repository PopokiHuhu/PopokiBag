local ADDON, ns = ...

-- Sloty na przyciskach Blizzarda (ContainerFrameItemButtonTemplate): używanie, przeciąganie,
-- dzielenie stosów, linkowanie i tooltipy innych addonów działają same.
-- Ramka-rodzic niesie ID torby, przycisk ID slotu (tak robi Blizzard i Ellesmere).
-- Przycisków nie tworzymy w walce (byłyby "skażone" i nie dałoby się ich używać).

ns.SLOT_SIZE = 37
ns.SLOT_GAP = 4

local POOL_START = 160   -- więcej niż maksymalna liczba slotów plecaka
local pool = {}

local function NewSlot(container)
    local parent = CreateFrame("Frame", nil, container)
    parent:SetSize(ns.SLOT_SIZE, ns.SLOT_SIZE)
    local btn = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
    btn:SetAllPoints(parent)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    parent.btn = btn
    parent:Hide()
    return parent
end

local function CreateSlot()
    if InCombatLockdown() then return nil end
    local parent = NewSlot(ns.content)
    pool[#pool + 1] = parent
    return parent
end

-- Osobne sloty dla sekcji "Use me!" w lewym pasku (poza główną pulą)
local useMeSlots = {}
function ns.CreateUseMeSlots(container, n)
    if InCombatLockdown() then return end
    for i = #useMeSlots + 1, n do useMeSlots[i] = NewSlot(container) end
end

function ns.GetUseMeSlot(i)
    return useMeSlots[i]
end

function ns.CreateSlotPool()
    for _ = #pool + 1, POOL_START do CreateSlot() end
end

-- i-ty slot; nil w walce, jeśli pula się skończyła
function ns.GetSlot(i)
    return pool[i] or CreateSlot()
end

function ns.HideSlotsFrom(i)
    for j = i, #pool do pool[j]:Hide() end
end

-- jak w Ellesmere (Grid.lua:333): pusty slot = ukryta ramka jakości
local function SetQuality(btn, quality, link)
    if not link then
        if btn.IconBorder then btn.IconBorder:Hide() end
        return
    end
    btn:SetItemButtonQuality(quality, link, false, false)
end

local function SetCooldown(btn, bag, slot)
    local cd = btn.Cooldown
    if not cd then return end
    local start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
    if enable and enable ~= 0 and start and start > 0 and duration and duration > 0 then
        cd:SetDrawEdge(true)
        cd:SetCooldown(start, duration)
    else
        cd:Clear()
    end
end

local function SetQuestBorder(btn, isQuest, isStarter)
    local tex = btn.IconQuestTexture
    if not tex then return end
    if isStarter then
        tex:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        tex:Show()
    elseif isQuest then
        tex:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        tex:Show()
    else
        tex:Hide()
    end
end

-- Kolor pancerza: czerwony = za ciężki dla Ciebie, żółtawy = lżejszy niż nosisz.
-- Wypełnienie + ramka w tym samym kolorze zamiast ramki jakości.
local TINTS = {
    high = { fill = { 1, 0.1, 0.1, 0.35 }, edge = { 1, 0.15, 0.15 } },
    low  = { fill = { 1, 0.85, 0.2, 0.25 }, edge = { 1, 0.82, 0.2 } },
}
local EDGE = 2
local function SetTint(parent, fit)
    local c = fit and TINTS[fit]
    local f = parent.tint
    if not c then
        if f then f:Hide() end
        return
    end
    if not f then
        f = CreateFrame("Frame", nil, parent)
        f:SetAllPoints(parent)
        f:EnableMouse(false)
        f.tex = f:CreateTexture(nil, "OVERLAY")
        f.tex:SetPoint("TOPLEFT", EDGE, -EDGE)
        f.tex:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
        f.edges = {}
        for i, pts in ipairs({
            { "TOPLEFT", "TOPRIGHT", nil, EDGE }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, EDGE },
            { "TOPLEFT", "BOTTOMLEFT", EDGE }, { "TOPRIGHT", "BOTTOMRIGHT", EDGE },
        }) do
            local e = f:CreateTexture(nil, "OVERLAY", nil, 1)
            e:SetPoint(pts[1])
            e:SetPoint(pts[2])
            if pts[3] then e:SetWidth(pts[3]) else e:SetHeight(pts[4]) end
            f.edges[i] = e
        end
        parent.tint = f
    end
    f.tex:SetColorTexture(unpack(c.fill))
    for _, e in ipairs(f.edges) do e:SetColorTexture(c.edge[1], c.edge[2], c.edge[3], 1) end
    -- ramka jakości Blizzarda pod spodem gryzłaby się z naszą
    if parent.btn.IconBorder then parent.btn.IconBorder:Hide() end
    f:SetFrameLevel(parent.btn:GetFrameLevel() + 1)
    f:Show()
end

-- Przedmiot questowy, którego nie ma w celach żadnego questa z dziennika: przygaszony,
-- z małą czerwoną kropką w rogu (pewnie zbędny, decyzja należy do Ciebie)
local function SetStale(parent, on)
    local f = parent.stale
    if not on then
        if f then f:Hide() end
        return
    end
    if not f then
        f = CreateFrame("Frame", nil, parent)
        f:SetAllPoints(parent)
        f:EnableMouse(false)
        f.dim = f:CreateTexture(nil, "OVERLAY")
        f.dim:SetPoint("TOPLEFT", 1, -1)
        f.dim:SetPoint("BOTTOMRIGHT", -1, 1)
        f.dim:SetColorTexture(0, 0, 0, 0.55)
        f.dot = f:CreateTexture(nil, "OVERLAY", nil, 1)
        f.dot:SetSize(7, 7)
        f.dot:SetPoint("TOPRIGHT", -3, -3)
        f.dot:SetColorTexture(0.9, 0.2, 0.2, 1)
        parent.stale = f
    end
    f:SetFrameLevel(parent.btn:GetFrameLevel() + 2)
    f:Show()
end

-- Poświata nowego przedmiotu (pulsująca ramka nad ikoną)
local function SetGlow(parent, on)
    local g = parent.glow
    if not on then
        if g then g:Hide() end
        return
    end
    if not g then
        g = CreateFrame("Frame", nil, parent)
        g:SetAllPoints(parent)
        g:EnableMouse(false)
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        t:SetBlendMode("ADD")
        t:SetVertexColor(1, 0.85, 0.3)
        t:SetPoint("CENTER")
        t:SetSize(ns.SLOT_SIZE * 1.8, ns.SLOT_SIZE * 1.8)
        local anim = g:CreateAnimationGroup()
        anim:SetLooping("BOUNCE")
        local a = anim:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.35)
        a:SetDuration(0.8)
        g.anim = anim
        parent.glow = g
    end
    g:SetFrameLevel(parent.btn:GetFrameLevel() + 3)
    g:Show()
    g.anim:Play()
end

-- item = { bag, slot, info, link, isQuest, isStarter } albo pusty slot (info == nil)
function ns.SetSlot(parent, item, dimmed)
    parent.item = item
    local btn = parent.btn
    parent:SetID(item.bag)
    btn:SetID(item.slot)
    local info = item.info

    if not info then
        btn:SetItemButtonTexture(nil)
        btn:SetItemButtonCount(0)
        SetItemButtonDesaturated(btn, false)
        SetQuality(btn, nil)
        SetQuestBorder(btn, false)
        if btn.Cooldown then btn.Cooldown:Clear() end
        btn:SetAlpha(1)
    else
        btn:SetItemButtonTexture(info.iconFileID)
        btn:SetItemButtonCount(info.stackCount)
        SetItemButtonDesaturated(btn, info.isLocked)
        SetQuality(btn, info.quality, item.link)
        SetQuestBorder(btn, item.isQuest, item.isStarter)
        SetCooldown(btn, item.bag, item.slot)
        btn:SetAlpha(dimmed and 0.25 or 1)
    end
    if btn.JunkIcon then btn.JunkIcon:Hide() end
    if btn.UpgradeIcon then btn.UpgradeIcon:Hide() end
    SetGlow(parent, ns.Setting("newGlow") and info and ns.recent[info.itemID] or false)
    SetTint(parent, ns.Setting("armorColors") and info and item.armorFit)
    SetStale(parent, info and item.questNeed == false)
    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end

    parent:Show()
    btn:Show()

    -- tooltip pod myszką ma pokazać nowy przedmiot po przetasowaniu slotów
    if GameTooltip:IsOwned(btn) then
        if info and btn.UpdateTooltip then btn:UpdateTooltip() else GameTooltip:Hide() end
    end
end

---------------------------------------------------------------------------
-- Przeciąganie między sekcjami: dopóki kursor trzyma przedmiot z plecaka, nad slotami
-- INNYCH kategorii leżą przezroczyste nakładki. Upuszczenie na nie przenosi rodzaj
-- przedmiotu do tej kategorii zamiast fizycznie zamieniać sloty.
-- Przycisków Blizzarda nie ruszamy (tak robi Ellesmere, EUI_Bags_Select.lua:153).
---------------------------------------------------------------------------
local function DropOverlay(parent)
    if parent.drop then return parent.drop end
    local ov = CreateFrame("Button", nil, parent)
    ov:SetAllPoints(parent)
    ov:SetHighlightTexture("Interface/Buttons/WHITE8x8")
    ov:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
    local function drop(self)
        local item = self:GetParent().item
        if item and item.cat then ns.DropOnItem(item) end
    end
    ov:SetScript("OnReceiveDrag", drop)
    ov:SetScript("OnClick", drop)
    ov:Hide()
    parent.drop = ov
    return ov
end

function ns.UpdateDropOverlays()
    local kind, itemID = GetCursorInfo()
    local source = kind == "item" and ns.itemsByID[itemID]
    local active = source and PopokiBagDB.view ~= "bags" and PopokiBagDB.view ~= "everything"
    for _, parent in ipairs(pool) do
        local target = parent:IsShown() and parent.item
        local show = active and target and target.info and ns.CATEGORY_BY_KEY[target.cat]
            and target.info.itemID ~= source.info.itemID
        if show then
            local ov = DropOverlay(parent)
            ov:SetFrameLevel(parent.btn:GetFrameLevel() + 5)
            ov:Show()
        elseif parent.drop then
            parent.drop:Hide()
        end
    end
end

ns.On("CURSOR_CHANGED", function() ns.UpdateDropOverlays() end)

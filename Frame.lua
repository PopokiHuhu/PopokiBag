local ADDON, ns = ...

-- Okno plecaka: lewy pasek z widokami, nagłówek z wyszukiwarką, sekcje ze slotami, stopka.

local COLS = 10
local SIDEBAR_W = 140
local PAD = 10
local HEADER_H = 40
local FOOTER_H = 28
local SECTION_H = 22
local CONTENT_H = 520   -- stała wysokość; więcej przedmiotów = przewijanie

local ACCENT = { 0.25, 0.8, 0.7 }
local BG = { 0.06, 0.06, 0.07, 0.95 }
local EDGE = { 0.2, 0.2, 0.22, 1 }
local DIM_TEXT = { 0.6, 0.6, 0.6 }

local GRID_W = COLS * (ns.SLOT_SIZE + ns.SLOT_GAP) - ns.SLOT_GAP

-- Widoki w lewym pasku: wszystko, każda kategoria osobno, fizyczne torby
local function BuildViews()
    local views = { { key = "all", label = "Categories" } }
    for _, c in ipairs(ns.OrderedCategories()) do
        views[#views + 1] = { key = c.key, label = c.label, color = c.color, isCategory = true }
    end
    views[#views + 1] = { key = "bags", label = "Bags", gapBefore = true }
    views[#views + 1] = { key = "everything", label = "All Items" }
    return views
end

local function SetFlatBackdrop(f, bg, edge)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(edge))
end

local function Hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

---------------------------------------------------------------------------
-- Okno
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "PopokiBagFrame", UIParent, "BackdropTemplate")
frame:SetWidth(SIDEBAR_W + PAD * 2 + GRID_W + PAD)
frame:SetHeight(HEADER_H + 4 + CONTENT_H + 4 + FOOTER_H)
-- nad paskami akcji, buffami i quest trackerem (jak Ellesmere: HIGH, poziom 100)
frame:SetFrameStrata("HIGH")
frame:SetFrameLevel(100)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()
SetFlatBackdrop(frame, BG, EDGE)
table.insert(UISpecialFrames, "PopokiBagFrame")   -- ESC zamyka
ns.frame = frame

frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    PopokiBagDB.pos = { point, x, y }
end)

function ns.RestorePosition()
    frame:ClearAllPoints()
    local p = PopokiBagDB and PopokiBagDB.pos
    if p then
        frame:SetPoint(p[1], UIParent, p[1], p[2], p[3])
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110)
    end
end

frame:SetScript("OnShow", function()
    ns.ResetRestedXPCache()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    PopokiBagDB.view = "all"   -- plecak zawsze otwiera się na głównym widoku (Categories)
    ns.Refresh()
end)
frame:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
end)

-- tytuł
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD + 2, -12)
title:SetText("Inventory")
title:SetTextColor(1, 1, 1)

local slotsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
slotsText:SetPoint("LEFT", title, "RIGHT", 10, 0)
slotsText:SetTextColor(unpack(DIM_TEXT))

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-- wyszukiwarka
local search = CreateFrame("EditBox", "PopokiBagSearch", frame, "SearchBoxTemplate")
search:SetSize(170, 20)
search:SetPoint("TOPRIGHT", -34, -10)
search:HookScript("OnTextChanged", function() ns.Refresh() end)
ns.search = search

local function SearchQuery()
    local t = search:GetText()
    if not t or t == "" or t == SEARCH then return nil end
    return t:lower()
end

---------------------------------------------------------------------------
-- Przeciąganie do kategorii: przedmiot z kursora trafia na stałe do tej kategorii
---------------------------------------------------------------------------
ns.itemsByID = {}

-- Własna kolejność w sekcjach: numer per rodzaj przedmiotu (mniejszy = bardziej z lewej).
-- Nowy loot trafia na początek sekcji, ręcznie przeniesiony przedmiot na koniec.
-- Przy pierwszym uruchomieniu numerujemy rosnąco, żeby zachować dotychczasowy układ.
local function NextOrder()
    local max = 0
    for _, n in pairs(PopokiBagCharDB.order) do if n > max then max = n end end
    return max + 1
end

local function FirstOrder()
    local min = 1
    for _, n in pairs(PopokiBagCharDB.order) do if n < min then min = n end end
    return min - 1
end

function ns.OrderOf(itemID)
    local order = PopokiBagCharDB.order
    if not order[itemID] then
        order[itemID] = PopokiBagCharDB.orderReady and FirstOrder() or NextOrder()
    end
    return order[itemID]
end

function ns.MoveToFront(itemID)
    PopokiBagCharDB.order[itemID] = FirstOrder()
end

function ns.MoveToEnd(itemID)
    PopokiBagCharDB.order[itemID] = NextOrder()
end

-- Upuszczenie przedmiotu z kursora na inny przedmiot w widoku kategorii:
-- ta sama sekcja = zamiana miejscami w kolejności, inna sekcja = przeniesienie na koniec tamtej.
function ns.DropOnItem(target)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID or not target or not target.info then return end
    local source = ns.itemsByID[itemID]
    if source and source.cat == target.cat then
        local order = PopokiBagCharDB.order
        local a, b = ns.OrderOf(itemID), ns.OrderOf(target.info.itemID)
        order[itemID], order[target.info.itemID] = b, a
        ClearCursor()
        ns.Refresh()
    else
        ns.DropOnCategory(target.cat)
    end
end

function ns.DropOnCategory(catKey)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID or not ns.CATEGORY_BY_KEY[catKey] then return false end
    local item = ns.itemsByID[itemID]
    ns.AssignItem(itemID, catKey, item and item.autoCat)
    ns.MoveToEnd(itemID)
    local label = ns.CATEGORY_BY_KEY[catKey].label
    local name = (item and item.link) or ("item " .. itemID)
    if PopokiBagCharDB.assign[itemID] then
        ns.Print(name .. " -> " .. label)
    else
        ns.Print(name .. " -> " .. label .. " (back to automatic)")
    end
    ClearCursor()
    ns.Refresh()
    return true
end

---------------------------------------------------------------------------
-- Lewy pasek
---------------------------------------------------------------------------
local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 1, -HEADER_H)
sidebar:SetPoint("BOTTOMLEFT", 1, FOOTER_H)
sidebar:SetWidth(SIDEBAR_W)
SetFlatBackdrop(sidebar, { 0.04, 0.04, 0.05, 0.9 }, { 0, 0, 0, 0 })

local sideHeader = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sideHeader:SetPoint("TOPLEFT", 10, -8)
sideHeader:SetText("Views")
sideHeader:SetTextColor(unpack(DIM_TEXT))

-- Edit: przesuwanie kategorii strzałkami w lewym pasku
local editMode = false
local editBtn = CreateFrame("Button", nil, sidebar)
editBtn:SetSize(40, 16)
editBtn:SetPoint("TOPRIGHT", -8, -6)
editBtn.text = editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
editBtn.text:SetPoint("RIGHT")
editBtn.text:SetText("Edit")
editBtn.text:SetTextColor(unpack(DIM_TEXT))
editBtn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
editBtn:SetScript("OnLeave", function(self)
    if editMode then self.text:SetTextColor(unpack(ACCENT)) else self.text:SetTextColor(unpack(DIM_TEXT)) end
end)
editBtn:SetScript("OnClick", function(self)
    editMode = not editMode
    self.text:SetText(editMode and "Done" or "Edit")
    self.text:SetTextColor(unpack(editMode and ACCENT or DIM_TEXT))
    ns.Refresh()
end)

local sideButtons = {}

local function SideButtonClick(self)
    if self.isCategory and CursorHasItem() then
        ns.DropOnCategory(self.key)
        return
    end
    PopokiBagDB.view = self.key
    ns.Refresh()
end

local function CreateSideButton()
    local b = CreateFrame("Button", nil, sidebar)
    b:SetSize(SIDEBAR_W, 24)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(2)
    b.bar:SetColorTexture(unpack(ACCENT))
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(6, 6)
    b.dot:SetPoint("LEFT", 10, 0)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("RIGHT", -10, 0)
    b.count:SetTextColor(unpack(DIM_TEXT))
    -- strzałki ▲▼ widoczne tylko w trybie Edit
    local function Arrow(rot, delta, x)
        local a = CreateFrame("Button", nil, b)
        a:SetSize(16, 16)
        a:SetPoint("RIGHT", x, 0)
        local t = a:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture("Interface/Buttons/Arrow-Down-Up")
        t:SetRotation(rot)
        a:SetHighlightTexture("Interface/Buttons/WHITE8x8")
        a:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
        a:SetScript("OnClick", function()
            ns.MoveCategory(b.key, delta)
            ns.Refresh()
        end)
        a:Hide()
        return a
    end
    b.up = Arrow(math.pi, -1, -24)
    b.down = Arrow(0, 1, -6)
    b:SetScript("OnClick", SideButtonClick)
    b:SetScript("OnReceiveDrag", function(self)
        if self.isCategory then ns.DropOnCategory(self.key) end
    end)
    return b
end

local function UpdateSidebar(views, counts)
    local y = -26
    for i, v in ipairs(views) do
        local b = sideButtons[i] or CreateSideButton()
        sideButtons[i] = b
        if v.gapBefore then y = y - 10 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, y)
        y = y - 26
        b.key, b.isCategory = v.key, v.isCategory
        b.label:ClearAllPoints()
        if v.color then
            b.dot:SetColorTexture(v.color[1], v.color[2], v.color[3], 1)
            b.dot:Show()
            b.label:SetPoint("LEFT", b.dot, "RIGHT", 7, 0)
        else
            b.dot:Hide()
            b.label:SetPoint("LEFT", 12, 0)
        end
        b.label:SetText(v.label)
        local editing = editMode and v.isCategory
        b.count:SetText(editing and "" or (counts[v.key] or ""))
        b.up:SetShown(editing and true or false)
        b.down:SetShown(editing and true or false)
        local selected = PopokiBagDB.view == v.key
        b.sel:SetShown(selected)
        b.bar:SetShown(selected)
        b:Show()
    end
    for i = #views + 1, #sideButtons do sideButtons[i]:Hide() end
end

---------------------------------------------------------------------------
-- "Use me!" na dole lewego paska: przedmioty do użycia od razu (start questa,
-- receptura do nauczenia, coś do otwarcia). Chowa się, gdy nic takiego nie ma.
---------------------------------------------------------------------------
local USEME_COLS, USEME_MAX = 3, 9
local useMe = CreateFrame("Frame", nil, sidebar)
useMe:SetPoint("BOTTOMLEFT", 0, 8)
useMe:SetPoint("BOTTOMRIGHT", 0, 8)
useMe:SetHeight(20)
useMe:Hide()
useMe.line = useMe:CreateTexture(nil, "ARTWORK")
useMe.line:SetHeight(1)
useMe.line:SetPoint("TOPLEFT", 8, 0)
useMe.line:SetPoint("TOPRIGHT", -8, 0)
useMe.line:SetColorTexture(1, 1, 1, 0.08)
useMe.title = useMe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
useMe.title:SetPoint("TOPLEFT", 10, -8)
useMe.title:SetTextColor(unpack(DIM_TEXT))
useMe.more = useMe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
useMe.more:SetPoint("TOPRIGHT", -10, -9)
useMe.more:SetTextColor(unpack(DIM_TEXT))

local function UpdateUseMe(list)
    local STEP = ns.SLOT_SIZE + ns.SLOT_GAP
    local shownN = math.min(#list, USEME_MAX)
    for i = 1, USEME_MAX do
        local slot = ns.GetUseMeSlot(i)
        if slot then
            local item = list[i]
            if item then
                local col = (i - 1) % USEME_COLS
                local row = math.floor((i - 1) / USEME_COLS)
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", useMe, "TOPLEFT", 10 + col * STEP, -28 - row * STEP)
                slot.btn:SetFrameLevel(useMe:GetFrameLevel() + 2)
                ns.SetSlot(slot, item, false)
            else
                slot:Hide()
            end
        end
    end
    if shownN == 0 then
        useMe:Hide()
        return
    end
    useMe.title:SetText(ns.USE_ME.label)
    useMe.more:SetText(#list > USEME_MAX and ("+" .. (#list - USEME_MAX) .. " more") or "")
    useMe:SetHeight(28 + math.ceil(shownN / USEME_COLS) * STEP)
    useMe:Show()
end

---------------------------------------------------------------------------
-- Zawartość (przewijana)
---------------------------------------------------------------------------
local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", SIDEBAR_W + PAD + 1, -HEADER_H - 4)
scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H + 4)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = self:GetVerticalScrollRange()
    local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40))
    self:SetVerticalScroll(v)
end)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(GRID_W, 10)
scroll:SetScrollChild(content)
ns.content = content

-- nagłówki sekcji; upuszczenie przedmiotu na nagłówek kategorii też go przypisuje
local headers = {}
local function GetHeader(i)
    local h = headers[i]
    if not h then
        h = CreateFrame("Button", nil, content)
        h:SetSize(GRID_W, SECTION_H)
        -- strzałka: w dół = rozwinięta, w prawo = zwinięta
        h.arrow = h:CreateTexture(nil, "OVERLAY")
        h.arrow:SetTexture("Interface/Buttons/Arrow-Down-Up")
        h.arrow:SetSize(14, 14)
        h.arrow:SetPoint("LEFT", -2, -3)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.text:SetTextColor(0.85, 0.85, 0.85)
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetHeight(1)
        h.line:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
        h.line:SetPoint("RIGHT")
        h.line:SetColorTexture(1, 1, 1, 0.08)
        -- "Sell" przy For Vendor (widoczny tylko przy otwartym vendorze)
        h.sell = CreateFrame("Button", nil, h, "BackdropTemplate")
        h.sell:SetSize(46, 18)
        h.sell:SetPoint("RIGHT", 0, 0)
        SetFlatBackdrop(h.sell, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.25 })
        h.sell.text = h.sell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h.sell.text:SetPoint("CENTER")
        h.sell.text:SetText("Sell")
        h.sell:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.6) end)
        h.sell:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.25) end)
        h.sell:SetScript("OnClick", function() ns.SellVendorSection() end)
        h.sell:Hide()
        local function drop(self) if self.catKey then ns.DropOnCategory(self.catKey) end end
        h:SetScript("OnReceiveDrag", drop)
        h:SetScript("OnClick", function(self)
            if CursorHasItem() then
                drop(self)
            elseif self.collapsible then
                local c = PopokiBagDB.collapsed
                c[self.catKey] = not c[self.catKey] or nil
                ns.Refresh()
            end
        end)
        headers[i] = h
    end
    return h
end

-- nagłówek ze strzałką (zwijalny) albo bez
local function SetHeaderArrow(h, collapsible, collapsed)
    h.collapsible = collapsible
    h.text:ClearAllPoints()
    if collapsible then
        h.arrow:SetRotation(collapsed and (math.pi / 2) or 0)
        h.arrow:Show()
        h.text:SetPoint("LEFT", 14, 0)
    else
        h.arrow:Hide()
        h.text:SetPoint("LEFT", 0, 0)
    end
end

-- slot "+" na końcu sekcji kategorii: tu upuszczasz przedmiot, żeby go przenieść
local plusSlots = {}
local function GetPlusSlot(i)
    local p = plusSlots[i]
    if not p then
        p = CreateFrame("Button", nil, content, "BackdropTemplate")
        p:SetSize(ns.SLOT_SIZE, ns.SLOT_SIZE)
        SetFlatBackdrop(p, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.12 })
        p.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        p.text:SetTextColor(0.5, 0.5, 0.5)
        p.text:SetPoint("CENTER", 0, 1)
        p.text:SetText("+")
        local function drop(self) ns.DropOnCategory(self.catKey) end
        p:SetScript("OnReceiveDrag", drop)
        p:SetScript("OnClick", function(self) if CursorHasItem() then drop(self) end end)
        p:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 1, 1, 0.4)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drop an item here")
            GameTooltip:AddLine("All items of this kind will go to " .. ns.CATEGORY_BY_KEY[self.catKey].label .. ".", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(1, 1, 1, 0.12)
            GameTooltip:Hide()
        end)
        plusSlots[i] = p
    end
    return p
end

---------------------------------------------------------------------------
-- Stopka
---------------------------------------------------------------------------
local money = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
money:SetPoint("BOTTOMRIGHT", -PAD, 9)

-- Cash-in: ile dałaby sprzedaż For Vendor (vendor), For Auction (AH po 5% prowizji)
-- i kategorie profesji (AH albo vendor, co wychodzi lepiej wg progu); na środku stopki
local earnings = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
earnings:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
earnings:SetTextColor(unpack(DIM_TEXT))
local AH_CUT = 0.95

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("BOTTOMLEFT", PAD, 9)
hint:SetTextColor(unpack(DIM_TEXT))

---------------------------------------------------------------------------
-- Skan toreb
---------------------------------------------------------------------------
function ns.Scan()
    local items, slots = {}, {}
    local total, free = 0, 0
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            total = total + 1
            local item = { bag = bag, slot = slot }
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                item.info = info
                item.link = C_Container.GetContainerItemLink(bag, slot)
                local q = C_Container.GetContainerItemQuestInfo(bag, slot)
                if q and (q.isQuestItem or q.questID) then
                    item.isQuest = true
                    item.isStarter = q.questID and not q.isActive or false
                end
                items[#items + 1] = item
            else
                free = free + 1
            end
            slots[#slots + 1] = item
        end
    end
    return items, slots, total, free
end

local function BagName(bag)
    if bag == 0 then return "Backpack" end
    local name = (C_Container.GetBagName and C_Container.GetBagName(bag)) or (GetBagName and GetBagName(bag))
    return name or ("Bag " .. bag)
end

local function SortItems(list)
    -- Twoja kolejność (ns.OrderOf); kilka stacków tego samego przedmiotu obok siebie
    table.sort(list, function(a, b)
        local oa, ob = ns.OrderOf(a.info.itemID), ns.OrderOf(b.info.itemID)
        if oa ~= ob then return oa < ob end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list
end

-- Sekcja kategorii z sumą wartości (dla vendora i aukcji)
local function CategorySection(cat, items)
    local list, value = {}, 0
    for _, it in ipairs(items) do
        if it.cat == cat.key then
            list[#list + 1] = it
            if cat.key == "vendor" then value = value + (it.vendorValue or 0) end
            if cat.key == "auction" then value = value + (it.auctionValue or 0) end
        end
    end
    local s = { title = Hex(cat.color) .. cat.label .. "|r", items = SortItems(list), catKey = cat.key }
    if value > 0 then s.extra = ns.MoneyText(value) end
    return s
end

-- All Items: podział według rodzaju przedmiotu (klasa przedmiotu w grze)
local TYPE_GROUPS = {
    { title = "Weapons",       classes = { [2] = true } },
    { title = "Armor",         classes = { [4] = true } },
    { title = "Consumables",   classes = { [0] = true } },
    { title = "Trade Goods",   classes = { [7] = true, [3] = true } },
    { title = "Reagents",      classes = { [5] = true } },
    { title = "Recipes",       classes = { [9] = true } },
    { title = "Quest Items",   classes = { [12] = true } },
    { title = "Ammo",          classes = { [6] = true } },
    { title = "Containers",    classes = { [1] = true, [11] = true } },
    { title = "Keys",          classes = { [13] = true } },
    { title = "Miscellaneous" },   -- reszta
}

local function TypeSections(items)
    local sections, byTitle = {}, {}
    for _, g in ipairs(TYPE_GROUPS) do
        local s = { title = g.title, items = {} }
        sections[#sections + 1] = s
        byTitle[g.title] = s
    end
    for _, item in ipairs(items) do
        local target = byTitle["Miscellaneous"]
        for _, g in ipairs(TYPE_GROUPS) do
            if g.classes and g.classes[item.classID] then target = byTitle[g.title] break end
        end
        target.items[#target.items + 1] = item
    end
    return sections
end

local ALWAYS_SHOWN = { vendor = true, auction = true }

-- Zwraca listę sekcji { title, items, catKey?, extra?, countText? } dla widoku
local function BuildSections(view, items, slots)
    -- wszystko, pogrupowane według rodzaju przedmiotu (także amunicja i "Use me!")
    if view == "everything" then
        return TypeSections(items)
    end
    if view == "bags" then
        local sections, byBag = {}, {}
        for _, item in ipairs(slots) do
            local s = byBag[item.bag]
            if not s then
                s = { title = BagName(item.bag), items = {} }
                byBag[item.bag] = s
                sections[#sections + 1] = s
            end
            s.items[#s.items + 1] = item
        end
        for _, s in ipairs(sections) do
            local used = 0
            for _, it in ipairs(s.items) do if it.info then used = used + 1 end end
            s.countText = used .. "/" .. #s.items
        end
        return sections
    end
    if view == "all" then
        local sections = {}
        for _, cat in ipairs(ns.OrderedCategories()) do
            local s = CategorySection(cat, items)
            -- For Vendor i For Auction zawsze widoczne (z "+"), żeby było gdzie przeciągnąć przedmiot
            if ALWAYS_SHOWN[cat.key] then s.showEmpty = true end
            if #s.items > 0 or s.showEmpty then sections[#sections + 1] = s end
        end
        return sections
    end
    local cat = ns.CATEGORY_BY_KEY[view]
    if cat then
        local s = CategorySection(cat, items)
        s.showEmpty = true
        return { s }
    end
    return {}
end

---------------------------------------------------------------------------
-- Tooltip: linijka z kategorią i powodem pod tooltipem przedmiotu
---------------------------------------------------------------------------
local itemAt = {}

hooksecurefunc(GameTooltip, "SetBagItem", function(tt, bag, slot)
    if not frame:IsShown() then return end
    local item = itemAt[bag * 1000 + slot]
    local cat = item and (ns.CATEGORY_BY_KEY[item.cat] or (item.cat == "useme" and ns.USE_ME))
    if not cat then return end   -- np. amunicja
    tt:AddLine(" ")
    tt:AddLine("Popoki Bag: " .. Hex(cat.color) .. cat.label .. "|r", 1, 1, 1)
    tt:AddLine(item.reason, 0.75, 0.75, 0.75, true)
    if ns.recent[item.info.itemID] then tt:AddLine("New item", 1, 0.85, 0.3) end
    if item.questNeed then
        tt:AddLine("Needed for: " .. item.questNeed.quest .. " (" .. item.questNeed.raw .. ")", 0.6, 0.9, 0.6, true)
    elseif item.questNeed == false then
        tt:AddLine("Not in any active quest objective. Probably not needed anymore.", 1, 0.45, 0.45, true)
    end
    tt:Show()
end)

---------------------------------------------------------------------------
-- Odświeżanie
---------------------------------------------------------------------------
local function RefreshInner()
    if not frame:IsShown() then return end
    local items, slots, total, free = ns.Scan()

    wipe(itemAt)
    wipe(ns.itemsByID)
    local counts, shown, ammo, useMeList = {}, 0, 0, {}
    for _, item in ipairs(items) do
        ns.Classify(item)
        ns.OrderOf(item.info.itemID)   -- nowe rodzaje dostają numer przed sortowaniem (= koniec sekcji)
        itemAt[item.bag * 1000 + item.slot] = item
        ns.itemsByID[item.info.itemID] = item
        if item.cat == "useme" then
            useMeList[#useMeList + 1] = item
        elseif item.cat == "ammo" then
            ammo = ammo + (item.info.stackCount or 0)
        else
            counts[item.cat] = (counts[item.cat] or 0) + 1
            shown = shown + 1
        end
    end
    counts.all = shown
    counts.bags = (total - free) .. "/" .. total
    counts.everything = #items

    slotsText:SetText((total - free) .. " / " .. total)
    money:SetText(ns.MoneyText(GetMoney()))
    local est = 0
    for _, item in ipairs(items) do
        if item.cat == "vendor" then
            est = est + (item.vendorValue or 0)
        elseif item.profSell == "auction" then   -- kategorie profesji: AH albo vendor wg progu
            est = est + math.floor((ns.AuctionValue(item) or 0) * AH_CUT)
        elseif item.profSell == "vendor" then
            est = est + (item.vendorValue or 0)
        elseif item.cat == "auction" then
            if item.randomSuffix then
                est = est + (item.vendorValue or 0)   -- prawdziwej ceny wariantu nie znamy; vendor jako minimum
            else
                est = est + math.floor((item.auctionValue or ns.AuctionValue(item) or 0) * AH_CUT)
            end
        end
    end
    earnings:SetText(est > 0 and ("Cash-in: |cffffffff" .. ns.MoneyText(est) .. "|r") or "")
    if not ns.takeover then
        hint:SetText("EllesmereUIBags is enabled: B opens the old bags")
    elseif ammo > 0 then
        hint:SetText("Ammo: |cffffffff" .. ammo .. "|r")
    else
        hint:SetText("")
    end

    PopokiBagCharDB.orderReady = true
    local views = BuildViews()
    local view = PopokiBagDB.view
    local known = false
    for _, v in ipairs(views) do if v.key == view then known = true end end
    if not known then view = "all"; PopokiBagDB.view = view end
    UpdateSidebar(views, counts)
    UpdateUseMe(useMeList)

    local query = SearchQuery()
    local sections = BuildSections(view, items, slots)
    local STEP = ns.SLOT_SIZE + ns.SLOT_GAP

    local y, slotIdx, hdrIdx, plusIdx = 0, 1, 1, 1
    for _, s in ipairs(sections) do
        if #s.items > 0 or s.showEmpty then
            local h = GetHeader(hdrIdx)
            hdrIdx = hdrIdx + 1
            h.catKey = s.catKey
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            local text = s.title .. "  |cff999999" .. (s.countText or #s.items) .. "|r"
            if s.extra then text = text .. "  |cff999999·|r  " .. s.extra end
            h.text:SetText(text)
            -- zwijanie tylko w widoku All Items; stan zapamiętany w PopokiBagDB.collapsed
            local collapsible = s.catKey ~= nil and view == "all"
            local collapsed = collapsible and PopokiBagDB.collapsed[s.catKey]
            SetHeaderArrow(h, collapsible, collapsed)
            local canSell = s.catKey == "vendor" and ns.merchantOpen
            h.sell:SetShown(canSell and true or false)
            h.line:SetPoint("RIGHT", canSell and -54 or 0, 0)
            h:Show()
            y = y + SECTION_H + 2

            if collapsed then
                y = y + 4
            else
                local n = #s.items
                for i, item in ipairs(s.items) do
                    local slot = ns.GetSlot(slotIdx)
                    if not slot then break end   -- walka i brak przycisków w puli; dorobimy po walce
                    slotIdx = slotIdx + 1
                    local col = (i - 1) % COLS
                    local row = math.floor((i - 1) / COLS)
                    slot:ClearAllPoints()
                    slot:SetPoint("TOPLEFT", col * STEP, -(y + row * STEP))
                    slot.btn:SetFrameLevel(content:GetFrameLevel() + 2)
                    local dimmed = false
                    if query and item.info then
                        local name = (item.info.itemName or ""):lower()
                        dimmed = not name:find(query, 1, true)
                    end
                    ns.SetSlot(slot, item, dimmed)
                end

                -- "+" za ostatnim przedmiotem sekcji kategorii
                if s.catKey then
                    local p = GetPlusSlot(plusIdx)
                    plusIdx = plusIdx + 1
                    p.catKey = s.catKey
                    p:ClearAllPoints()
                    p:SetPoint("TOPLEFT", (n % COLS) * STEP, -(y + math.floor(n / COLS) * STEP))
                    p:Show()
                    n = n + 1
                end

                y = y + math.ceil(n / COLS) * STEP + 8
            end
        end
    end
    ns.HideSlotsFrom(slotIdx)
    ns.UpdateDropOverlays()
    for i = hdrIdx, #headers do headers[i]:Hide() end
    for i = plusIdx, #plusSlots do plusSlots[i]:Hide() end

    content:SetHeight(math.max(y, 10))
    if scroll:GetVerticalScroll() > scroll:GetVerticalScrollRange() then scroll:SetVerticalScroll(0) end
end

function ns.Refresh()
    ns.SafeCall("refresh", RefreshInner)
end

-- Zbiorcze odświeżenie (kilka zdarzeń w jednej klatce = jedno przeliczenie)
local pending = false
function ns.RequestRefresh()
    if pending or not frame:IsShown() then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        ns.Refresh()
    end)
end

for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
    "QUEST_LOG_UPDATE", "GET_ITEM_INFO_RECEIVED", "INVENTORY_SEARCH_UPDATE", "PLAYER_LEVEL_UP" }) do
    ns.On(e, ns.RequestRefresh)
end

ns.On("PLAYER_LOGIN", function()
    ns.RestorePosition()
    ns.CreateSlotPool()
    ns.CreateUseMeSlots(useMe, USEME_MAX)
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    ns.CreateSlotPool()
    ns.CreateUseMeSlots(useMe, USEME_MAX)
    ns.RequestRefresh()
end)

function ns.Open() if not frame:IsShown() then frame:Show() end end
function ns.Close() frame:Hide() end
function ns.Toggle() if frame:IsShown() then frame:Hide() else frame:Show() end end

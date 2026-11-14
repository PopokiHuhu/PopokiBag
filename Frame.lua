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
-- COLS i GRID_W zmienia przeciąganie rogu okna (PopokiBagDB.cols, zmiana rozmiaru na końcu pliku)
local MIN_COLS, MAX_COLS = 6, 16
local function SetCols(n)
    COLS = math.max(MIN_COLS, math.min(MAX_COLS, n))
    GRID_W = COLS * (ns.SLOT_SIZE + ns.SLOT_GAP) - ns.SLOT_GAP
end
-- Compact mode: lewy pasek to wąska kolumna ikon
local COMPACT_W = 40
-- Compact mode w motywie Blizzard: bez lewego paska, ikony widoków w nagłówku
local function NoSidebar()
    return ns.Compact and ns.Compact() and ns.ThemeKey() == "blizzard"
end
local function SideW()
    if NoSidebar() then return 0 end
    return (ns.Compact and ns.Compact()) and COMPACT_W or SIDEBAR_W
end
-- szerokość okna dla bieżącej liczby kolumn
local function FrameWidth(cols)
    local grid = (cols or COLS) * (ns.SLOT_SIZE + ns.SLOT_GAP) - ns.SLOT_GAP
    return SideW() + PAD * 2 + grid + PAD
end
-- Widoki w lewym pasku: wszystko, każda kategoria osobno, fizyczne torby
-- showCats = kategorie jako podpunkty w lewym pasku (ustawienie; w trybie Edit zawsze, bo tam się je przestawia)
local function BuildViews(showCats)
    local views = { { key = "all", label = "Categories" } }
    if showCats then
        local colors = ns.CategoryColors()
        for _, c in ipairs(ns.OrderedCategories()) do
            views[#views + 1] = { key = c.key, label = c.label, color = colors and c.color or nil, isCategory = true }
        end
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
ns.slotsText = slotsText
slotsText:SetPoint("LEFT", title, "RIGHT", 10, 0)
slotsText:SetTextColor(unpack(DIM_TEXT))

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
ns.closeButton = close
close:SetPoint("TOPRIGHT", 2, 2)

-- wyszukiwarka
local search = CreateFrame("EditBox", "PopokiBagSearch", frame, "SearchBoxTemplate")
search:SetSize(170, 20)
search:SetPoint("TOPRIGHT", -34, -10)
search:HookScript("OnTextChanged", function() ns.Refresh() end)
ns.search = search

-- Compact mode: widoki jako ikony w wąskim lewym pasku (ustawiane w motywie, na końcu pliku)
local VIEW_ICONS = {
    { key = "all", icon = "Interface/Icons/INV_Misc_Note_01", tip = "Categories", text = "Items sorted into categories" },
    { key = "bags", icon = "Interface/Icons/INV_Misc_Bag_08", tip = "Bags", text = "Your bags as they are" },
    { key = "everything", icon = "Interface/Icons/INV_Misc_Book_09", tip = "All Items", text = "Everything, grouped by item type" },
}
local viewIcons = {}
for i, def in ipairs(VIEW_ICONS) do
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(24, 24)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(def.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.check = b:CreateTexture(nil, "OVERLAY")   -- wybrany widok: poświata Blizzarda
    b.check:SetPoint("TOPLEFT", -3, 3)
    b.check:SetPoint("BOTTOMRIGHT", 3, -3)
    b.check:SetTexture("Interface/Buttons/CheckButtonHilight")
    b.check:SetBlendMode("ADD")
    b.check:Hide()
    b:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    b.key = def.key
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.tip)
        GameTooltip:AddLine(def.text, 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        PopokiBagDB.view = self.key
        ns.Refresh()
    end)
    b:Hide()
    viewIcons[i] = b
end

local function UpdateViewIcons(view)
    for _, b in ipairs(viewIcons) do
        local on = b.key == view
        b.check:SetShown(on)
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.75)
    end
end
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
        -- kategorie = podpunkty "Categories": mniejsza czcionka i wcięcie
        b.label:SetFontObject(v.isCategory and "GameFontHighlightSmall" or "GameFontHighlight")
        b.dot:ClearAllPoints()
        b.dot:SetPoint("LEFT", v.isCategory and 20 or 10, 0)
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
        h.arrow:SetSize(12, 12)
        h.arrow:SetPoint("LEFT", 0, 0)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.text:SetTextColor(unpack(ns.Theme().header))
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetHeight(1)
        h.line:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
        h.line:SetPoint("RIGHT")
        h.line:SetColorTexture(unpack(ns.Theme().line))
        -- wyróżniona sekcja ("Use me!" w Compact mode): złote tło nagłówka z paskiem z lewej
        h.band = h:CreateTexture(nil, "BACKGROUND")
        h.band:SetPoint("TOPLEFT", -4, 0)
        h.band:SetPoint("BOTTOMRIGHT", 0, 0)
        h.band:SetColorTexture(1, 0.82, 0, 0.14)
        h.band:Hide()
        h.bandBar = h:CreateTexture(nil, "ARTWORK")
        h.bandBar:SetPoint("TOPLEFT", h.band, "TOPLEFT")
        h.bandBar:SetPoint("BOTTOMLEFT", h.band, "BOTTOMLEFT")
        h.bandBar:SetWidth(2)
        h.bandBar:SetColorTexture(1, 0.82, 0, 1)
        h.bandBar:Hide()
        -- "Sell" przy For Vendor (widoczny tylko przy otwartym vendorze)
        h.sell = CreateFrame("Button", nil, h, "BackdropTemplate")
        h.sell:SetSize(46, 18)
        h.sell:SetPoint("RIGHT", 0, 0)
        h.sell.text = h.sell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h.sell.text:SetPoint("CENTER")
        h.sell.text:SetText("Sell")
        ns.SkinButton(h.sell)
        -- ten sam przycisk: "Sell" przy For Vendor u vendora, "Pack" w widoku Bags
        h.sell:SetScript("OnEnter", function(self)
            ns.SkinButton(self, true)
            if self.action == "sort" then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Pack bags")
                GameTooltip:AddLine("Moves items into the first bags so the last ones end up empty (to swap a bag). Categories don't change.", 0.75, 0.75, 0.75, true)
                GameTooltip:Show()
            end
        end)
        h.sell:SetScript("OnLeave", function(self) ns.SkinButton(self, false) GameTooltip:Hide() end)
        h.sell:SetScript("OnClick", function(self)
            if self.action == "sort" then ns.CompactBags() else ns.SellVendorSection() end
        end)
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

-- Ikona zwijania: szewrony z interfejsu gry (v = rozwinięta, > = zwinięta), a gdy klient
-- ich nie ma - klasyczne plus/minus Blizzarda. Szewrony są białe, barwimy je kolorem nagłówka.
local CHEVRONS = { "uitools-icon-chevron-down", "uitools-icon-chevron-right" }
local hasChevrons = C_Texture and C_Texture.GetAtlasInfo
    and C_Texture.GetAtlasInfo(CHEVRONS[1]) and C_Texture.GetAtlasInfo(CHEVRONS[2]) and true or false
local function SetArrow(tex, collapsed)
    if hasChevrons then
        tex:SetAtlas(collapsed and CHEVRONS[2] or CHEVRONS[1])
        tex:SetVertexColor(unpack(ns.Theme().header))
    else
        tex:SetTexture(collapsed and "Interface/Buttons/UI-PlusButton-Up" or "Interface/Buttons/UI-MinusButton-Up")
        tex:SetVertexColor(1, 1, 1)
    end
end

-- nagłówek ze strzałką (zwijalny) albo bez
local function SetHeaderArrow(h, collapsible, collapsed)
    h.collapsible = collapsible
    h.text:ClearAllPoints()
    if collapsible then
        SetArrow(h.arrow, collapsed)
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
        p.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        p.text:SetPoint("CENTER", 0, 1)
        p.text:SetText("+")
        ns.SkinPlus(p)
        local function drop(self) ns.DropOnCategory(self.catKey) end
        p:SetScript("OnReceiveDrag", drop)
        p:SetScript("OnClick", function(self) if CursorHasItem() then drop(self) end end)
        p:SetScript("OnEnter", function(self)
            ns.SkinPlus(self, true)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drop an item here")
            GameTooltip:AddLine("All items of this kind will go to " .. ns.CATEGORY_BY_KEY[self.catKey].label .. ".", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function(self)
            ns.SkinPlus(self, false)
            GameTooltip:Hide()
        end)
        plusSlots[i] = p
    end
    return p
end

---------------------------------------------------------------------------
-- Stopka
---------------------------------------------------------------------------
-- osobny pasek stopki: ciemniejsze tło + kreska u góry (położenie i kolory ustawia motyw)
local footerBg = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
local footerLine = frame:CreateTexture(nil, "ARTWORK")
footerLine:SetHeight(1)
footerLine:SetPoint("BOTTOMLEFT", footerBg, "TOPLEFT")
footerLine:SetPoint("BOTTOMRIGHT", footerBg, "TOPRIGHT")

local money = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
money:SetPoint("BOTTOMRIGHT", -PAD, 9)

-- Cash-in: ile dałaby sprzedaż For Vendor (vendor), For Auction (AH po 5% prowizji)
-- i kategorie profesji (AH albo vendor, co wychodzi lepiej wg progu); na środku stopki
local earnings = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
earnings:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
earnings:SetTextColor(unpack(DIM_TEXT))
local AH_CUT = 0.95

-- Cash-in da się kliknąć: podświetla się na hover, klik pokazuje/chowa tooltip z wyjaśnieniem
-- i podziałem na For Vendor / For Auction / materiały profesji
local earningsBtn = CreateFrame("Button", nil, frame)
earningsBtn:SetPoint("TOPLEFT", earnings, "TOPLEFT", -6, 4)
earningsBtn:SetPoint("BOTTOMRIGHT", earnings, "BOTTOMRIGHT", 6, -4)
earningsBtn:SetHighlightTexture("Interface/Buttons/WHITE8x8")
earningsBtn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
earningsBtn:Hide()

local function CashLine(label, n, value, note)
    local left = label .. "  |cff999999(" .. n .. (n == 1 and " item" or " items") .. ")|r"
    GameTooltip:AddDoubleLine(left, ns.MoneyText(value), 1, 1, 1, 1, 1, 1)
    if note then GameTooltip:AddLine(note, 0.6, 0.6, 0.6, true) end
end

local function ShowCashTooltip(self)
    local c = ns.cashIn
    if not c then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Cash-in")
    GameTooltip:AddLine("Roughly what you'd get by selling everything that is meant to be sold.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    CashLine("For Vendor", c.vendorN, c.vendor, "Vendor price.")
    CashLine("For Auction", c.auctionN, c.auction,
        "AH price minus the 5% AH cut" .. (c.guessed > 0 and ("; " .. c.guessed .. " \"of the ...\" item(s) counted at vendor price, so it's likely more.") or "."))
    CashLine("Profession materials", c.profN, c.prof, "AH or vendor, whichever pays better by your AH threshold.")
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total", ns.MoneyText(c.vendor + c.auction + c.prof), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

earningsBtn:SetScript("OnEnter", function() earnings:SetTextColor(1, 1, 1) end)
earningsBtn:SetScript("OnLeave", function(self)
    earnings:SetTextColor(unpack(DIM_TEXT))
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)
earningsBtn:SetScript("OnClick", function(self)
    if GameTooltip:IsOwned(self) and GameTooltip:IsShown() then GameTooltip:Hide() else ShowCashTooltip(self) end
end)

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
    local title = ns.CategoryColors() and (Hex(cat.color) .. cat.label .. "|r") or cat.label
    local s = { title = title, items = SortItems(list), catKey = cat.key }
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
    tt:AddLine("Popoki Bag: " .. (ns.CategoryColors() and (Hex(cat.color) .. cat.label .. "|r") or cat.label), 1, 1, 1)
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
    -- podział na trzy części (tooltip po kliknięciu w Cash-in)
    local cash = { vendor = 0, auction = 0, prof = 0, vendorN = 0, auctionN = 0, profN = 0, guessed = 0 }
    for _, item in ipairs(items) do
        if item.cat == "vendor" then
            cash.vendor = cash.vendor + (item.vendorValue or 0)
            cash.vendorN = cash.vendorN + 1
        elseif item.profSell == "auction" then   -- kategorie profesji: AH albo vendor wg progu
            cash.prof = cash.prof + math.floor((ns.AuctionValue(item) or 0) * AH_CUT)
            cash.profN = cash.profN + 1
        elseif item.profSell == "vendor" then
            cash.prof = cash.prof + (item.vendorValue or 0)
            cash.profN = cash.profN + 1
        elseif item.cat == "auction" then
            if item.randomSuffix then
                cash.auction = cash.auction + (item.vendorValue or 0)   -- prawdziwej ceny wariantu nie znamy; vendor jako minimum
                cash.guessed = cash.guessed + 1
            else
                cash.auction = cash.auction + math.floor((item.auctionValue or ns.AuctionValue(item) or 0) * AH_CUT)
            end
            cash.auctionN = cash.auctionN + 1
        end
    end
    local est = cash.vendor + cash.auction + cash.prof
    ns.cashIn = cash
    earnings:SetText(est > 0 and ("Cash-in: |cffffffff" .. ns.MoneyText(est) .. "|r") or "")
    earningsBtn:SetShown(est > 0)
    if not ns.takeover then
        hint:SetText("EllesmereUIBags is enabled: B opens the old bags")
    elseif ammo > 0 then
        hint:SetText("Ammo: |cffffffff" .. ammo .. "|r")
    else
        hint:SetText("")
    end

    PopokiBagCharDB.orderReady = true
    local compact = ns.Compact()
    local views = BuildViews((ns.Setting("sidebarCategories") or editMode) and not compact)
    local view = PopokiBagDB.view
    local known = false
    for _, v in ipairs(views) do if v.key == view then known = true end end
    if not known then view = "all"; PopokiBagDB.view = view end
    UpdateSidebar(views, counts)
    if compact then
        for _, b in ipairs(sideButtons) do b:Hide() end
        useMe:Hide()
        UpdateViewIcons(view)
    else
        UpdateUseMe(useMeList)
    end

    local query = SearchQuery()
    local sections = BuildSections(view, items, slots)
    -- Compact mode: wąski pasek nie mieści "Use me!", więc to pierwsza sekcja widoku Categories
    if compact and view == "all" and #useMeList > 0 then
        table.insert(sections, 1, { title = ns.USE_ME.label, items = useMeList, highlight = true,
            extra = "|cffffd100things to use right away|r" })
    end
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
            -- wyróżnienie: złote tło i jaśniejszy napis; zwykłe sekcje w kolorze nagłówków motywu
            h.band:SetShown(s.highlight and true or false)
            h.bandBar:SetShown(s.highlight and true or false)
            if s.highlight then
                h.text:SetFontObject("GameFontNormalLarge")
                h.text:SetTextColor(1, 0.85, 0.25)
            else
                h.text:SetFontObject("GameFontNormal")
                h.text:SetTextColor(unpack(ns.Theme().header))
            end
            -- zwijanie tylko w widoku All Items; stan zapamiętany w PopokiBagDB.collapsed
            local collapsible = s.catKey ~= nil and view == "all"
            local collapsed = collapsible and PopokiBagDB.collapsed[s.catKey]
            SetHeaderArrow(h, collapsible, collapsed)
            local action
            if s.catKey == "vendor" and ns.merchantOpen then
                action = "sell"
            elseif view == "bags" and hdrIdx == 2 then   -- pierwszy nagłówek w widoku Bags
                action = "sort"
            end
            h.sell.action = action
            if action then
                h.sell.text:SetText(action == "sort" and (ns.compacting and "Packing..." or "Pack") or "Sell")
                h.sell:SetWidth(math.max(46, h.sell.text:GetStringWidth() + 18))
            end
            h.sell:SetShown(action and true or false)
            h.line:SetPoint("RIGHT", action and -(h.sell:GetWidth() + 8) or 0, 0)
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

---------------------------------------------------------------------------
-- Motyw okna (Theme.lua): Dark = płaskie tło, Blizzard = ramka okien gry na "rock"
---------------------------------------------------------------------------
local chrome   -- nil = jeszcze nie próbowano, false = klient nie ma ramki Blizzarda
local GOLD_DIALOG = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}

local function BlizzardChrome()
    if chrome ~= nil then return chrome end
    chrome = false
    local util = NineSliceUtil
    local layout = "ButtonFrameTemplateNoPortrait"
    if not (util and util.GetLayout and util.ApplyLayoutByName and util.GetLayout(layout)) then return chrome end
    local ok, nine = pcall(CreateFrame, "Frame", nil, frame, "NineSlicePanelTemplate")
    if not (ok and nine and pcall(util.ApplyLayoutByName, nine, layout)) then return chrome end
    nine:SetAllPoints()
    nine:SetFrameLevel(frame:GetFrameLevel())
    -- pełne, nieprzezroczyste podłoże pod kamieniem (sama tekstura kamienia prześwituje)
    local base = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    base:SetPoint("TOPLEFT", 6, -21)
    base:SetPoint("BOTTOMRIGHT", -2, 3)
    base:SetColorTexture(0.07, 0.065, 0.06, 1)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 6, -21)
    bg:SetPoint("BOTTOMRIGHT", -2, 3)
    if bg:SetTexture("Interface/FrameGeneral/UI-Background-Rock", "REPEAT", "REPEAT") == false then
        bg:SetColorTexture(0.1, 0.09, 0.08, 1)
    end
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetAllPoints(bg)
    shade:SetColorTexture(0, 0, 0, 0.45)   -- przyciemniony kamień, żeby drobny tekst był czytelny
    chrome = { nine = nine, bg = bg, shade = shade, base = base }
    return chrome
end

local function ShowChrome(on)
    if not chrome then return end
    chrome.nine:SetShown(on)
    chrome.bg:SetShown(on)
    chrome.shade:SetShown(on)
    chrome.base:SetShown(on)
end

ns.OnThemeChange(function()
    local t = ns.Theme()
    local blizz = ns.ThemeKey() == "blizzard"
    local compact = ns.Compact()
    for i = 1, 3 do
        ACCENT[i] = t.accent[i]
        DIM_TEXT[i] = t.dim[i]
    end

    -- tło i ramka
    local nine = blizz and BlizzardChrome()
    if blizz then
        if nine then
            frame:SetBackdrop(nil)
            ShowChrome(true)
        else
            frame:SetBackdrop(GOLD_DIALOG)   -- zapas, gdyby klient nie miał nine-slice
            frame:SetBackdropBorderColor(1, 1, 1, 1)
        end
    else
        ShowChrome(false)
        SetFlatBackdrop(frame, BG, EDGE)
    end
    -- Compact mode: węższy lewy pasek, więc i okno
    frame:SetWidth(FrameWidth())

    -- nagłówek: przy ramce Blizzarda tytuł w pasku tytułu, reszta rząd niżej
    title:ClearAllPoints()
    slotsText:ClearAllPoints()
    search:ClearAllPoints()
    close:ClearAllPoints()
    -- top = gdzie kończy się nagłówek (lewy pasek i zawartość zaczynają się niżej)
    local top
    if blizz and nine then
        top = 56   -- rząd pod paskiem tytułu z lekkim odstępem od góry
        title:SetFontObject("GameFontNormal")
        title:SetPoint("TOP", 0, -4)
        if NoSidebar() then
            -- ikony widoków na początku rzędu z wyszukiwarką, licznik slotów za nimi
            slotsText:SetPoint("LEFT", viewIcons[#viewIcons], "RIGHT", 10, 0)
        else
            slotsText:SetPoint("LEFT", frame, "TOPLEFT", PAD + 8, -40)   -- środek rzędu z wyszukiwarką
        end
        search:SetPoint("TOPRIGHT", -14, -30)
        close:SetPoint("TOPRIGHT", 1, 0)
    else
        top = HEADER_H
        title:SetFontObject("GameFontNormalLarge")
        -- jeden rząd: tytuł, licznik, przyciski, wyszukiwarka, zębatka i X na wspólnym środku (-20)
        title:SetPoint("LEFT", frame, "TOPLEFT", PAD + 4, -20)
        slotsText:SetPoint("LEFT", title, "RIGHT", 10, 0)
        search:SetPoint("RIGHT", frame, "TOPRIGHT", -60, -20)   -- miejsce na zębatkę i X
        close:SetPoint("CENTER", frame, "TOPRIGHT", -18, -20)
    end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", SideW() + PAD + (blizz and 6 or 1), -top - 4)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H + 4)
    title:SetTextColor(unpack(t.title))
    slotsText:SetTextColor(unpack(DIM_TEXT))
    search:SetWidth(compact and 140 or 170)

    -- lewy pasek: pełny (widoki z napisami, kategorie, "Use me!") albo w Compact mode kolumna ikon
    sidebar:ClearAllPoints()
    sidebar:SetWidth(SideW())
    if blizz then
        sidebar:SetPoint("TOPLEFT", 6, -top)
        sidebar:SetPoint("BOTTOMLEFT", 6, FOOTER_H)
        SetFlatBackdrop(sidebar, { 0.03, 0.03, 0.03, 0.75 }, { 0.55, 0.45, 0.25, 0.6 })
    else
        sidebar:SetPoint("TOPLEFT", 1, -HEADER_H)
        sidebar:SetPoint("BOTTOMLEFT", 1, FOOTER_H)
        SetFlatBackdrop(sidebar, { 0.04, 0.04, 0.05, 0.9 }, { 0, 0, 0, 0 })
    end
    sideHeader:SetShown(not compact)
    editBtn:SetShown(not compact)
    if compact then
        if editMode then editMode = false editBtn.text:SetText("Edit") end
        for _, b in ipairs(sideButtons) do b:Hide() end
        useMe:Hide()
    end
    local noSide = NoSidebar()
    sidebar:SetShown(not noSide)
    for i, b in ipairs(viewIcons) do
        b:ClearAllPoints()
        if noSide then
            -- w nagłówku, w rzędzie z wyszukiwarką
            b:SetSize(20, 20)
            if i == 1 then b:SetPoint("LEFT", frame, "TOPLEFT", PAD + 6, -40)
            else b:SetPoint("LEFT", viewIcons[i - 1], "RIGHT", 6, 0) end
        else
            b:SetSize(24, 24)
            b:SetPoint("TOP", sidebar, "TOP", 0, -10 - (i - 1) * 32)
        end
        b:SetShown(compact)
    end
    sideHeader:SetTextColor(unpack(DIM_TEXT))
    editBtn.text:SetTextColor(unpack(editMode and ACCENT or DIM_TEXT))
    for _, b in ipairs(sideButtons) do
        b.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
        b.bar:SetColorTexture(unpack(ACCENT))
        b.count:SetTextColor(unpack(DIM_TEXT))
    end
    useMe.line:SetColorTexture(unpack(t.line))
    useMe.title:SetTextColor(unpack(DIM_TEXT))
    useMe.more:SetTextColor(unpack(DIM_TEXT))

    -- sekcje
    for _, h in ipairs(headers) do
        h.text:SetTextColor(unpack(t.header))
        h.line:SetColorTexture(unpack(t.line))
        ns.SkinButton(h.sell)
    end
    for _, p in ipairs(plusSlots) do ns.SkinPlus(p) end

    -- stopka: pasek oddzielony od zawartości jak nagłówek
    footerBg:ClearAllPoints()
    hint:ClearAllPoints()
    money:ClearAllPoints()
    if blizz and nine then
        footerBg:SetPoint("BOTTOMLEFT", 6, 3)
        footerBg:SetPoint("BOTTOMRIGHT", -3, 3)
        footerBg:SetHeight(FOOTER_H - 3)
        footerBg:SetColorTexture(0, 0, 0, 0.5)
        footerLine:SetColorTexture(1, 0.82, 0, 0.3)
        hint:SetPoint("BOTTOMLEFT", PAD + 8, 10)
        money:SetPoint("BOTTOMRIGHT", -PAD - 16, 10)
    else
        footerBg:SetPoint("BOTTOMLEFT", 1, 1)
        footerBg:SetPoint("BOTTOMRIGHT", -1, 1)
        footerBg:SetHeight(FOOTER_H - 1)
        footerBg:SetColorTexture(0, 0, 0, 0.3)
        footerLine:SetColorTexture(1, 1, 1, 0.08)
        hint:SetPoint("BOTTOMLEFT", PAD + 4, 9)
        money:SetPoint("BOTTOMRIGHT", -PAD - 14, 9)
    end
    earnings:SetTextColor(unpack(DIM_TEXT))
    hint:SetTextColor(unpack(DIM_TEXT))
end)

ns.On("PLAYER_LOGIN", ns.ApplyTheme)

---------------------------------------------------------------------------
-- Zmiana rozmiaru: uchwyt w prawym dolnym rogu, swobodnie w obu kierunkach. Siatka mieści tyle
-- pełnych kolumn (6-16), ile się zmieści; resztę szerokości zostawia jako margines z prawej.
-- Zapamiętane w PopokiBagDB.width / PopokiBagDB.height; /popoki reset przywraca domyślne.
---------------------------------------------------------------------------
local DEFAULT_H = HEADER_H + 4 + CONTENT_H + 4 + FOOTER_H
local MIN_H, MAX_H = 320, 1100
local EXTRA_W = 120   -- ile szerzej niż 16 kolumn można rozciągnąć okno
frame:SetResizable(true)
local function UpdateBounds()
    local minW, maxW = FrameWidth(MIN_COLS), FrameWidth(MAX_COLS) + EXTRA_W
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, MIN_H, maxW, MAX_H)
    else
        frame:SetMinResize(minW, MIN_H)
        frame:SetMaxResize(maxW, MAX_H)
    end
end

local function ApplyCols(n)
    local before = COLS
    SetCols(n)
    if COLS == before then return end
    content:SetWidth(GRID_W)
    for _, h in ipairs(headers) do h:SetWidth(GRID_W) end
    ns.RequestRefresh()
end

-- ile pełnych kolumn mieści się w danej szerokości okna
local function ColsFor(width)
    return math.floor((width - FrameWidth(0)) / (ns.SLOT_SIZE + ns.SLOT_GAP))
end

-- szerokość: zapisana przez Ciebie (w granicach) albo dopasowana do 10 kolumn
local function ApplyWidth()
    local w = PopokiBagDB.width or (PopokiBagDB.cols and FrameWidth(PopokiBagDB.cols))   -- zapis z 1.0.8 (kolumny)
    if w then
        w = math.max(FrameWidth(MIN_COLS), math.min(FrameWidth(MAX_COLS) + EXTRA_W, w))
        frame:SetWidth(w)
        ApplyCols(ColsFor(w))
    else
        ApplyCols(10)
        frame:SetWidth(FrameWidth())
    end
end

local grip = CreateFrame("Button", nil, frame)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:SetFrameLevel(frame:GetFrameLevel() + 20)
grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Drag to resize")
    GameTooltip:Show()
end)
grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
grip:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then return end
    GameTooltip:Hide()
    UpdateBounds()
    frame.sizing = true
    frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
    frame.sizing = false
    frame:StopMovingOrSizing()
    PopokiBagDB.width = math.floor(frame:GetWidth() + 0.5)
    PopokiBagDB.height = math.floor(frame:GetHeight() + 0.5)
    PopokiBagDB.cols = nil   -- stary zapis (sprzed swobodnej szerokości)
    local point, _, _, x, y = frame:GetPoint()
    PopokiBagDB.pos = { point, x, y }
end)

frame:HookScript("OnSizeChanged", function(self, width)
    if not frame.sizing then return end
    ApplyCols(ColsFor(width))
end)

local function ApplySavedSize()
    ApplyWidth()
    frame:SetHeight(PopokiBagDB.height or DEFAULT_H)
end
ns.On("PLAYER_LOGIN", ApplySavedSize)
-- motyw / Compact mode zmieniają szerokość lewego paska: przelicz kolumny dla zapisanej szerokości
ns.OnThemeChange(function() if PopokiBagDB then ApplyWidth() end end)

-- /popoki reset: także domyślny rozmiar
local oldReset = ns.commands.reset
ns.commands.reset = function(...)
    PopokiBagDB.cols, PopokiBagDB.width, PopokiBagDB.height = nil, nil, nil
    ApplySavedSize()
    if oldReset then oldReset(...) end
end

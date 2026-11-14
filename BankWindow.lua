local ADDON, ns = ...

-- Okno banku w stylu plecaka.
-- Przy bankierze (bank otwarty): prawdziwe sloty (ContainerFrameItemButtonTemplate) - prawy klik
-- przenosi do plecaka, przeciąganie działa w obie strony, jak w zwykłym banku.
-- Gdzie indziej (przycisk "Bank" w plecaku): podgląd z ostatniej wizyty w banku, tylko do oglądania.
-- Na Forever bank jest jak w Classicu: główne pole (kontener -1) + torby bankowe (kontenery 6-12),
-- sprawdzone /popoki bankdebug. Domyślne okno banku chowamy (ustawienie "bankWindow").

local BANK = BANK_CONTAINER or -1
local FIRST_BANK_BAG = (ns.LAST_BAG or 5) + 1
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 7
local COLS = 12
local SLOT = ns.SLOT_SIZE
local STEP = ns.SLOT_SIZE + ns.SLOT_GAP
local PAD = 14
local CONTENT_H = 420
local FOOTER_H = 30
local SECTION_H = 22

local bankOpen = false
local view = "all"   -- all = kategorie, bags = kontenery, everything = rodzaj przedmiotu

local function Hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

-- Forever (screen domyślnego banku): główne pole = 48 slotów w kontenerze CharacterBankTab_1 (6),
-- 8 miejsc na torby = CharacterBankTab_2..9 (7-14), kupowane po kolei (C_Bank).
-- Kontener -1 (32 sloty, klucze) domyślny bank w ogóle nie pokazuje - pomijamy go.
-- Klasyczny klient (bez CharacterBankTab): -1 + torby 6-12.
local TAB1 = Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
local function MainBankID() return TAB1 or BANK end

local function BankBagIDs()
    local ids = {}
    if TAB1 then
        for i = 2, 20 do
            local id = Enum.BagIndex["CharacterBankTab_" .. i]
            if not id then break end
            ids[#ids + 1] = id
        end
    else
        for i = 0, NUM_BANK_BAGS - 1 do ids[#ids + 1] = FIRST_BANK_BAG + i end
    end
    return ids
end

local function IsBankContainer(bag)
    if bag == MainBankID() then return true end
    for _, id in ipairs(BankBagIDs()) do if id == bag then return true end end
    return false
end

local function ContainerName(bag)
    if bag == MainBankID() then return "Bank" end
    local name = C_Container.GetBagName and C_Container.GetBagName(bag)
    if name and name ~= "" then return name end
    for i, id in ipairs(BankBagIDs()) do if id == bag then return "Bank bag " .. i end end
    return "Bank bag"
end

---------------------------------------------------------------------------
-- Okno
---------------------------------------------------------------------------
local win = CreateFrame("Frame", "PopokiBagBankWindow", UIParent, "BackdropTemplate")
win:SetSize(PAD * 2 + COLS * STEP - ns.SLOT_GAP, 74 + CONTENT_H + FOOTER_H)
win:SetFrameStrata("HIGH")
win:SetClampedToScreen(true)
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win:Hide()
ns.bankWin = win

local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("Bank")
local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetScript("OnClick", function() win:Hide() end)

-- napis obok tytułu: "snapshot, 2 h ago" w trybie podglądu
local subtitle = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetTextColor(0.6, 0.6, 0.6)

local search = CreateFrame("EditBox", nil, win, "SearchBoxTemplate")
search:SetSize(130, 20)
search:SetPoint("TOPRIGHT", -PAD, -44)
search:HookScript("OnTextChanged", function() ns.RequestBankRefresh() end)

-- przełączniki widoków (w Compact mode ikony, jak w plecaku)
local VIEWS = {
    { key = "all", label = "Categories", icon = "Interface/Icons/INV_Misc_Note_01" },
    { key = "bags", label = "Bags", icon = "Interface/Icons/INV_Misc_Bag_08" },
    { key = "everything", label = "All Items", icon = "Interface/Icons/INV_Misc_Book_09" },
}
local viewButtons = {}
local prevBtn
for _, v in ipairs(VIEWS) do
    local b = ns.HeaderButton(win, v.label, v.label, nil, function()
        view = v.key
        ns.RequestBankRefresh()
    end, { icon = v.icon })
    if prevBtn then b:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", PAD, -44) end
    b.viewKey = v.key
    viewButtons[#viewButtons + 1] = b
    prevBtn = b
end

local function UpdateViewButtons()
    for _, b in ipairs(viewButtons) do
        local on = b.viewKey == view
        b.icon:SetAlpha(on and 1 or 0.45)
        if on then b.text:SetTextColor(unpack(ns.Theme().accent)) else b.text:SetTextColor(0.6, 0.6, 0.6) end
    end
end

-- "Deposit": okno "Put in bank" (To Bank + zakładki profesji) - tylko przy bankierze
local depositBtn = ns.HeaderButton(win, "Deposit", "Put in bank",
    "Items from To Bank and your profession categories, to move here",
    function() if ns.OpenBankList then ns.OpenBankList(true) end end,
    { icon = "Interface/Icons/INV_Misc_Coin_02" })
depositBtn:SetPoint("RIGHT", search, "LEFT", -10, 0)

local scroll = CreateFrame("ScrollFrame", nil, win)
scroll:SetPoint("TOPLEFT", PAD, -74)
scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H + 4)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * STEP * 2)))
end)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(COLS * STEP, 10)
scroll:SetScrollChild(content)

-- stopka: zajęte sloty + kupno miejsca na torbę bankową
local footerLine = win:CreateTexture(nil, "ARTWORK")
footerLine:SetHeight(1)
footerLine:SetPoint("BOTTOMLEFT", PAD, FOOTER_H)
footerLine:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H)
local slotsText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
slotsText:SetPoint("BOTTOMLEFT", PAD, 10)

-- Kupno miejsca na torbę bankową. Klasyczne API (PurchaseSlot) na Forever nie istnieje
-- (sprawdzone /run print), więc próbujemy nowszego C_Bank (zakładki banku postaci = kontenery 6-12).
local CHAR_BANK = Enum and Enum.BankType and Enum.BankType.Character

-- { bought = n, canBuy = bool, cost = miedziaki?, buy = fn } albo nil, gdy klient nie ma żadnego API
local function BankSlotInfo()
    if PurchaseSlot and GetNumBankSlots and GetBankSlotCost then
        local n, full = GetNumBankSlots()
        return { bought = n or 0, canBuy = not full, cost = GetBankSlotCost(n), buy = PurchaseSlot }
    end
    if C_Bank and CHAR_BANK and C_Bank.FetchNumPurchasedBankTabs then
        local ok, n = pcall(C_Bank.FetchNumPurchasedBankTabs, CHAR_BANK)
        if not ok then return nil end
        local can = C_Bank.CanPurchaseBankTab and select(2, pcall(C_Bank.CanPurchaseBankTab, CHAR_BANK))
        local cost
        if C_Bank.FetchNextPurchasableBankTabData then
            local ok2, data = pcall(C_Bank.FetchNextPurchasableBankTabData, CHAR_BANK)
            cost = ok2 and type(data) == "table" and data.tabCost or nil
        end
        -- pierwsza "zakładka" to główne pole banku, kolejne to miejsca na torby
        return { bought = math.max(0, (n or 0) - (TAB1 and 1 or 0)), canBuy = can == true, cost = cost, tabs = true,
            buy = function() C_Bank.PurchaseBankTab(CHAR_BANK) end }
    end
end

-- Kupno jest zablokowane dla addonów ("blocked from an action only available to the Blizzard UI"),
-- więc przycisk przełącza na zwykłe okno banku - tam kupujesz przyciskiem Purchase.
local buyBtn = ns.HeaderButton(win, "Buy bag slot", "Buy a bank bag slot",
    "Opens the game's bank window - buy the slot there with Purchase (only the game's own window can do it)", function()
        ns.UseBlizzardBank()
    end)
buyBtn:SetPoint("BOTTOMRIGHT", -PAD, 6)

-- awaryjnie: zwykłe okno banku Blizzarda (do końca tej wizyty u bankiera)
local blizzardThisVisit = false
function ns.UseBlizzardBank()
    blizzardThisVisit = true
    ns.ShowBlizzardBank()
    win:Hide()
end
local defaultBtn = ns.HeaderButton(win, "Default bank", "Default bank window",
    "Shows the game's own bank window until you close the bank", function()
        ns.UseBlizzardBank()
    end)
defaultBtn:SetPoint("RIGHT", buyBtn, "LEFT", -8, 0)

ns.SkinWindow(win, { title = title, close = close, side = true, onApply = function(blizz, framed)
    footerLine:SetColorTexture(unpack(ns.Theme().line))
    subtitle:ClearAllPoints()
    if framed then
        subtitle:SetPoint("LEFT", title, "RIGHT", 8, 0)
    else
        subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    end
    if win:IsShown() then ns.RequestBankRefresh() end
end })
table.insert(UISpecialFrames, "PopokiBagBankWindow")   -- ESC zamyka

---------------------------------------------------------------------------
-- Elementy listy: nagłówki sekcji, prawdziwe sloty, sloty podglądu, sloty na torby bankowe
---------------------------------------------------------------------------
local headers = {}
local function GetHeader(i)
    local h = headers[i]
    if h then return h end
    h = CreateFrame("Frame", nil, content)
    h:SetSize(COLS * STEP - ns.SLOT_GAP, SECTION_H)
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.text:SetPoint("LEFT", 0, 0)
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
    h.line:SetPoint("RIGHT", 0, 0)
    headers[i] = h
    return h
end

-- kategoria i powód w tooltipie (prawdziwe sloty banku)
local itemAt = {}
local function AddCategoryLines(tt, item)
    local cat = item and (ns.CATEGORY_BY_KEY[item.cat] or (item.cat == "useme" and ns.USE_ME))
    if not cat then return end
    tt:AddLine(" ")
    tt:AddLine("Popoki Bag: " .. (ns.CategoryColors() and cat.color and (Hex(cat.color) .. cat.label .. "|r") or cat.label), 1, 1, 1)
    if item.reason then tt:AddLine(item.reason, 0.75, 0.75, 0.75, true) end
    tt:Show()
end
hooksecurefunc(GameTooltip, "SetBagItem", function(tt, bag, slot)
    if not (win:IsShown() and bankOpen) then return end
    if not IsBankContainer(bag) then return end
    AddCategoryLines(tt, itemAt[bag * 1000 + slot])
end)

local live = {}
local function GetLiveSlot(i)
    if live[i] then return live[i] end
    if InCombatLockdown() then return nil end
    local p = ns.NewSlot(content)
    -- główne pole banku: jeśli SetBagItem nie zna kontenera -1, tooltip z "ekwipunku" banku
    p.btn:HookScript("OnEnter", function(btn)
        local bag = btn:GetParent():GetID()
        if bag ~= BANK or not BankButtonIDToInvSlotID then return end
        if GameTooltip:IsOwned(btn) and GameTooltip:NumLines() > 0 then return end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(btn:GetID()))
        AddCategoryLines(GameTooltip, itemAt[bag * 1000 + btn:GetID()])
        GameTooltip:Show()
    end)
    live[i] = p
    return p
end

local ghosts = {}
local function GetGhost(i)
    if ghosts[i] then return ghosts[i] end
    local b = CreateFrame("Button", nil, content, "BackdropTemplate")
    b:SetSize(SLOT, SLOT)
    b:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetScript("OnEnter", function(self)
        if not self.entry or not self.entry.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.entry.link)
        AddCategoryLines(GameTooltip, self.entry)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if self.entry and self.entry.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.entry.link) end
    end)
    ghosts[i] = b
    return b
end

local function SetGhost(b, e, dimmed)
    b.entry = e
    if e.link then
        b.icon:SetTexture(e.icon or C_Item.GetItemIconByID(e.id) or 134400)
        b.icon:Show()
        b.count:SetText((e.count or 1) > 1 and e.count or "")
        b:SetBackdropColor(0, 0, 0, 0.4)
        if (e.quality or 1) > 1 then
            local r, g, bl = C_Item.GetItemQualityColor(e.quality)
            b:SetBackdropBorderColor(r, g, bl, 1)
        else
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    else
        b.icon:Hide()
        b.count:SetText("")
        b:SetBackdropColor(1, 1, 1, 0.03)
        b:SetBackdropBorderColor(1, 1, 1, 0.1)
    end
    b:SetAlpha(dimmed and 0.25 or 1)
    b:Show()
end

-- sloty na torby bankowe (widok Bags, przy bankierze): przeciągnij torbę, żeby ją włożyć
local bagSlots = {}
local function BagInvSlot(bag)
    if C_Container.ContainerIDToInventoryID then
        local ok, inv = pcall(C_Container.ContainerIDToInventoryID, bag)
        if ok and inv then return inv end
    end
    if BankButtonIDToInvSlotID and not TAB1 then return BankButtonIDToInvSlotID(bag - FIRST_BANK_BAG + 1, 1) end
end

local function GetBagSlot(i)
    if bagSlots[i] then return bagSlots[i] end
    local b = CreateFrame("Button", nil, content, "BackdropTemplate")
    b:SetSize(SLOT, SLOT)
    b:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.lock = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.lock:SetPoint("CENTER")
    local function put(self)
        if not self.owned or not self.inv or not bankOpen then return end
        if CursorHasItem() then PutItemInBag(self.inv) else PickupBagFromSlot(self.inv) end
    end
    b:SetScript("OnClick", put)
    b:SetScript("OnReceiveDrag", put)
    b:SetScript("OnDragStart", function(self)
        if self.owned and self.inv and bankOpen then PickupBagFromSlot(self.inv) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.owned and self.inv and GetInventoryItemTexture("player", self.inv) then
            GameTooltip:SetInventoryItem("player", self.inv)
        elseif self.owned then
            GameTooltip:SetText("Empty bank bag slot")
            GameTooltip:AddLine("Drag a bag here to put it in the bank.", 0.75, 0.75, 0.75, true)
        else
            GameTooltip:SetText("Bank bag slot not bought yet")
            GameTooltip:AddLine("Use \"Buy bag slot\" at the bottom of this window.", 0.75, 0.75, 0.75, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagSlots[i] = b
    return b
end

---------------------------------------------------------------------------
-- Dane: skan przy bankierze (i zapis podglądu) albo zapisany podgląd
---------------------------------------------------------------------------
local function ScanLive()
    local items, slots, total, free = {}, {}, 0, 0
    local containers = { MainBankID() }
    for _, id in ipairs(BankBagIDs()) do containers[#containers + 1] = id end
    for _, bag in ipairs(containers) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            total = total + 1
            local item = { bag = bag, slot = slot }
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                item.info = info
                item.link = C_Container.GetContainerItemLink(bag, slot)
                item.id = info.itemID
                item.name = info.itemName
                local q = C_Container.GetContainerItemQuestInfo(bag, slot)
                if q and (q.isQuestItem or q.questID) then
                    item.isQuest = true
                    item.isStarter = q.questID and not q.isActive or false
                end
                ns.Classify(item)
                items[#items + 1] = item
            else
                free = free + 1
            end
            slots[#slots + 1] = item
        end
    end
    return items, slots, total, free
end

-- zapis podglądu (per postać): przedmioty z kategorią, rozmiary kontenerów
local function SaveSnapshot(items, total, free)
    local snap = { time = time(), total = total, free = free, sizes = {}, names = {}, items = {} }
    local containers = { MainBankID() }
    for _, id in ipairs(BankBagIDs()) do containers[#containers + 1] = id end
    for _, bag in ipairs(containers) do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        if n > 0 then
            snap.sizes[#snap.sizes + 1] = { bag = bag, size = n }
            snap.names[bag] = ContainerName(bag)
        end
    end
    for _, it in ipairs(items) do
        snap.items[#snap.items + 1] = {
            bag = it.bag, slot = it.slot, link = it.link, id = it.id, name = it.name,
            count = it.info.stackCount, icon = it.info.iconFileID, quality = it.info.quality,
            cat = it.cat, reason = it.reason, classID = it.classID,
        }
    end
    PopokiBagCharDB.bankSnap = snap
end

local function SnapshotData()
    local snap = PopokiBagCharDB and PopokiBagCharDB.bankSnap
    if not snap then return nil end
    local byKey = {}
    for _, e in ipairs(snap.items) do byKey[e.bag * 1000 + e.slot] = e end
    local slots = {}
    for _, c in ipairs(snap.sizes) do
        for slot = 1, c.size do
            slots[#slots + 1] = byKey[c.bag * 1000 + slot] or { bag = c.bag, slot = slot }
        end
    end
    return snap.items, slots, snap.total, snap.free, snap
end

---------------------------------------------------------------------------
-- Sekcje (jak w plecaku)
---------------------------------------------------------------------------
local function ItemID(e) return e.id or (e.info and e.info.itemID) end

local function SortList(list)
    table.sort(list, function(a, b)
        local oa, ob = ns.OrderOf(ItemID(a)), ns.OrderOf(ItemID(b))
        if oa ~= ob then return oa < ob end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list
end

local function BuildSections(items, slots, names)
    if view == "everything" then return ns.TypeSections(items) end
    if view == "bags" then
        local sections, byBag = {}, {}
        for _, e in ipairs(slots) do
            local s = byBag[e.bag]
            if not s then
                s = { title = (names and names[e.bag]) or ContainerName(e.bag), items = {} }
                byBag[e.bag] = s
                sections[#sections + 1] = s
            end
            s.items[#s.items + 1] = e
        end
        for _, s in ipairs(sections) do
            local used = 0
            for _, e in ipairs(s.items) do if e.link then used = used + 1 end end
            s.countText = used .. "/" .. #s.items
        end
        return sections
    end
    -- Categories: kategorie w Twojej kolejności, potem "Use me!" i amunicja
    local byCat = {}
    for _, e in ipairs(items) do
        local k = e.cat or "misfits"
        byCat[k] = byCat[k] or {}
        table.insert(byCat[k], e)
    end
    local sections = {}
    for _, cat in ipairs(ns.OrderedCategories()) do
        local list = byCat[cat.key]
        if list then
            local t = ns.CategoryColors() and cat.color and (Hex(cat.color) .. cat.label .. "|r") or cat.label
            sections[#sections + 1] = { title = t, items = SortList(list) }
            byCat[cat.key] = nil
        end
    end
    if byCat.useme then
        sections[#sections + 1] = { title = ns.USE_ME and ns.USE_ME.label or "Use me!", items = SortList(byCat.useme) }
        byCat.useme = nil
    end
    local rest = {}
    for _, list in pairs(byCat) do for _, e in ipairs(list) do rest[#rest + 1] = e end end
    if #rest > 0 then sections[#sections + 1] = { title = "Other", items = SortList(rest) } end
    return sections
end

---------------------------------------------------------------------------
-- Rysowanie
---------------------------------------------------------------------------
local function Ago(t)
    local s = time() - (t or 0)
    if s < 120 then return "just now" end
    if s < 7200 then return math.floor(s / 60) .. " min ago" end
    if s < 172800 then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / 86400) .. " days ago"
end

local function RefreshInner()
    if not win:IsShown() then return end
    local items, slots, total, free, snap, names
    wipe(itemAt)
    if bankOpen then
        items, slots, total, free = ScanLive()
        for _, it in ipairs(items) do itemAt[it.bag * 1000 + it.slot] = it end
        SaveSnapshot(items, total, free)
        subtitle:SetText("")
    else
        items, slots, total, free, snap = SnapshotData()
        if not items then
            subtitle:SetText("")
            slotsText:SetText("Visit a banker once so Popoki Bag can remember your bank.")
            for _, p in ipairs(live) do p:Hide() end
            for _, g in ipairs(ghosts) do g:Hide() end
            for _, h in ipairs(headers) do h:Hide() end
            for _, b in ipairs(bagSlots) do b:Hide() end
            depositBtn:Hide()
            buyBtn:Hide()
            defaultBtn:Hide()
            return
        end
        names = snap.names
        subtitle:SetText("snapshot, " .. Ago(snap.time) .. " - view only")
    end

    UpdateViewButtons()
    depositBtn:SetShown(bankOpen)
    slotsText:SetText((total - free) .. " / " .. total .. " slots")

    local slotInfo = bankOpen and BankSlotInfo()
    local nBought = slotInfo and slotInfo.bought or 0
    buyBtn:SetShown(slotInfo and slotInfo.canBuy or false)
    defaultBtn:SetShown(bankOpen)

    local query = search:GetText()
    query = (query and query ~= "") and query:lower() or nil
    local theme = ns.Theme()

    local y, li, gi, hi, bi = 0, 1, 1, 1, 1
    -- widok Bags przy bankierze: rząd slotów na torby bankowe
    -- (tylko klasyczny bank z torbami; przy zakładkach banku nie ma slotów na torby)
    if view == "bags" and bankOpen then
        local h = GetHeader(hi); hi = hi + 1
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h.text:SetText("Bank bags  |cff999999" .. (nBought or 0) .. "/" .. #BankBagIDs() .. "|r")
        h.text:SetTextColor(unpack(theme.header))
        h.line:SetColorTexture(unpack(theme.line))
        h:Show()
        y = y + SECTION_H + 2
        for i, bag in ipairs(BankBagIDs()) do
            local b = GetBagSlot(bi); bi = bi + 1
            b.inv = BagInvSlot(bag)
            b.owned = i <= (nBought or 0)
            local tex = b.owned and b.inv and GetInventoryItemTexture("player", b.inv)
            b.icon:SetTexture(tex or nil)
            b.icon:SetShown(tex and true or false)
            b.lock:SetText(b.owned and "" or "-")
            b:SetBackdropColor(b.owned and 0 or 0.4, 0, 0, b.owned and 0.4 or 0.25)
            b:SetBackdropBorderColor(1, 1, 1, b.owned and 0.25 or 0.1)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", (i - 1) * STEP, -y)
            b:Show()
        end
        y = y + STEP + 8
    end

    for _, s in ipairs(BuildSections(items, slots, names)) do
        if #s.items > 0 then
            local h = GetHeader(hi); hi = hi + 1
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h.text:SetText(s.title .. "  |cff999999" .. (s.countText or #s.items) .. "|r")
            h.text:SetTextColor(unpack(theme.header))
            h.line:SetColorTexture(unpack(theme.line))
            h:Show()
            y = y + SECTION_H + 2
            for i, e in ipairs(s.items) do
                local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
                local dimmed = false
                local name = e.name or (e.info and e.info.itemName)
                if query and e.link then dimmed = not (name or ""):lower():find(query, 1, true) end
                local f
                if bankOpen then
                    f = GetLiveSlot(li)
                    if f then
                        li = li + 1
                        f.btn:SetFrameLevel(content:GetFrameLevel() + 2)
                        ns.SetSlot(f, e, dimmed)
                    end
                else
                    f = GetGhost(gi); gi = gi + 1
                    SetGhost(f, e, dimmed)
                end
                if f then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", col * STEP, -(y + row * STEP))
                end
            end
            y = y + math.ceil(#s.items / COLS) * STEP + 8
        end
    end
    for i = li, #live do live[i]:Hide() end
    for i = gi, #ghosts do ghosts[i]:Hide() end
    for i = hi, #headers do headers[i]:Hide() end
    for i = bi, #bagSlots do bagSlots[i]:Hide() end
    content:SetHeight(math.max(y, 10))
    if scroll:GetVerticalScroll() > scroll:GetVerticalScrollRange() then scroll:SetVerticalScroll(0) end
end

local pending = false
function ns.RequestBankRefresh()
    if pending or not win:IsShown() then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        ns.SafeCall("bank window", RefreshInner)
    end)
end

win:SetScript("OnShow", function()
    ns.PlaceBeside(win)
    ns.SafeCall("bank window", RefreshInner)
end)
-- zamknięcie naszego okna przy bankierze zamyka bank (jak zamknięcie zwykłego okna banku)
win:SetScript("OnHide", function()
    GameTooltip:Hide()
    if bankOpen and not blizzardThisVisit then
        if C_Bank and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame() elseif CloseBankFrame then CloseBankFrame() end
    end
end)

for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BAG_CONTAINER_UPDATE",
    "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED" }) do
    ns.On(e, function() ns.RequestBankRefresh() end)
end

---------------------------------------------------------------------------
-- Przejęcie banku: domyślne okno zostaje "otwarte" (gra tego wymaga), ale niewidoczne
---------------------------------------------------------------------------
local hidden = CreateFrame("Frame")
hidden:Hide()
local bankParent

local function HideBlizzardBank()
    if not BankFrame or BankFrame:GetParent() == hidden then return end
    bankParent = BankFrame:GetParent()
    BankFrame:SetParent(hidden)
end

local function RestoreBlizzardBank()
    if BankFrame and BankFrame:GetParent() == hidden then BankFrame:SetParent(bankParent or UIParent) end
end
ns.ShowBlizzardBank = RestoreBlizzardBank

ns.On("BANKFRAME_OPENED", function()
    bankOpen = true
    if not ns.Setting("bankWindow") then
        RestoreBlizzardBank()
        return
    end
    local ok = ns.SafeCall("bank window", function()
        if win:IsShown() then RefreshInner() else win:Show() end
        return true
    end)
    if ok then HideBlizzardBank() else RestoreBlizzardBank() end
    if ns.Open then ns.Open() end   -- plecak obok
end)

ns.On("BANKFRAME_CLOSED", function()
    bankOpen = false
    blizzardThisVisit = false
    if win:IsShown() then win:Hide() end
end)

---------------------------------------------------------------------------
-- Przycisk "Bank" w nagłówku plecaka (podgląd z dowolnego miejsca)
---------------------------------------------------------------------------
local bankBtn = ns.HeaderButton(ns.frame, "Bank",
    function() return win:IsShown() and "Hide bank" or "Show bank" end,
    "Away from a banker you see what was in your bank on your last visit",
    function() win:SetShown(not win:IsShown()) end,
    { icon = "Interface/Icons/INV_Box_02" })
if ns.roomButton then bankBtn:SetPoint("RIGHT", ns.roomButton, "LEFT", -8, 0) end
ns.bankButton = bankBtn

---------------------------------------------------------------------------
-- Tooltip każdego przedmiotu: ile masz go w banku (z podglądu)
---------------------------------------------------------------------------
local function BankCount(itemID)
    local snap = PopokiBagCharDB and PopokiBagCharDB.bankSnap
    if not snap or not itemID then return 0 end
    local n = 0
    for _, e in ipairs(snap.items) do if e.id == itemID then n = n + (e.count or 1) end end
    return n
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
        local id = data and data.id
        local n = BankCount(id)
        if n > 0 then tt:AddLine("In bank: |cffffffff" .. n .. "|r", 0.6, 0.75, 1) end
    end)
end

-- sprzątanie po tymczasowej diagnostyce banku (/popoki bankdebug)
ns.On("PLAYER_LOGIN", function() PopokiBagDB.bankDebug = nil end)

---------------------------------------------------------------------------
-- Prawy klik w tło okna banku: krótkie menu (jak w plecaku). Ponowny prawy klik zamyka.
---------------------------------------------------------------------------
local bankMenu, menuClosedAt = nil, 0
win:HookScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" or not self:IsMouseOver() then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    if bankMenu and bankMenu:IsShown() then bankMenu:Hide() return end
    if GetTime() - menuClosedAt < 0.3 then return end
    bankMenu = MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateButton("Sort", function() ns.CleanupOrder() end)   -- kolejność w kategoriach wg rodzaju
        if bankOpen then
            root:CreateButton("Deposit", function() if ns.OpenBankList then ns.OpenBankList(true) end end)
        end
        root:CreateDivider()
        root:CreateButton("Settings", function() if ns.ToggleSettings then ns.ToggleSettings() end end)
    end)
    if bankMenu and not bankMenu.popokiHooked then
        bankMenu.popokiHooked = true
        bankMenu:HookScript("OnHide", function() menuClosedAt = GetTime() end)
    end
end)
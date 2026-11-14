local ADDON, ns = ...

-- Pełne torby.
-- 1) Niepełne stosy tego samego przedmiotu łączą się same (po każdej zmianie w torbach,
--    po jednym ruchu naraz). Nie ruszamy ich w walce, przy vendorze, banku, poczcie, handlu
--    i AH, ani przez 5 minut po ręcznym podziale (ns.splitHold z Buttons.lua).
-- 2) Okno "Make room": otwiera się, gdy gra powie "Inventory is full". Pokazuje najtańsze
--    rzeczy w plecaku (wartość tego, co faktycznie masz w slocie: 1/20 skóry to grosze),
--    a przy otwartym lootcie porównuje je z tym, czego nie dało się zabrać, i mówi,
--    czy w ogóle warto coś wyrzucać. Niszczenie: klik zaznacza, drugi klik niszczy.
--    Nigdy nie proponujemy: questowych, Essentials, Consumables, Misfits, "Use me!",
--    zielonych "of the ..." (cena z AH niepewna) i rzeczy bez ceny.

---------------------------------------------------------------------------
-- 1) Łączenie stosów
---------------------------------------------------------------------------
local HOLD_AFTER_SPLIT = 300
local mergeQueued = false
local misses = {}   -- [itemID] = ile razy się nie udało (np. związany + niezwiązany)

local function MergeStep()
    mergeQueued = false
    if not ns.Setting("autoStack") then return end
    if ns.compacting or InCombatLockdown() or CursorHasItem() or ns.merchantOpen or ns.ElsewhereOpen() then return end
    local stacks = {}
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not info.isLocked and (misses[id] or 0) < 2 then
                local hold = ns.splitHold[id]
                local max = select(8, ns.GetItemInfo(id)) or 1
                if not (hold and GetTime() - hold < HOLD_AFTER_SPLIT) and max > 1 and info.stackCount < max then
                    stacks[id] = stacks[id] or {}
                    table.insert(stacks[id], { bag = bag, slot = slot, count = info.stackCount })
                end
            end
        end
    end
    for id, list in pairs(stacks) do
        if #list >= 2 then
            -- najmniejszy stos dosypujemy do największego niepełnego
            table.sort(list, function(a, b) return a.count > b.count end)
            local dst, src = list[1], list[#list]
            C_Container.PickupContainerItem(src.bag, src.slot)
            C_Container.PickupContainerItem(dst.bag, dst.slot)
            C_Timer.After(0.3, function()
                local kind, cursorID = GetCursorInfo()
                if kind == "item" and cursorID == id then
                    ClearCursor()   -- wraca na swoje miejsce
                    misses[id] = (misses[id] or 0) + 1
                end
            end)
            return   -- jeden ruch; kolejny po BAG_UPDATE_DELAYED
        end
    end
end

local function QueueMerge()
    if mergeQueued then return end
    mergeQueued = true
    C_Timer.After(0.3, MergeStep)
end

for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "MERCHANT_CLOSED", "BANKFRAME_CLOSED",
                     "MAIL_CLOSED", "TRADE_CLOSED", "PLAYER_ENTERING_WORLD" }) do
    ns.On(e, QueueMerge)
end

---------------------------------------------------------------------------
-- 2) Okno "Make room"
---------------------------------------------------------------------------
local SAFE = { quest = true, essentials = true, consumables = true, misfits = true, useme = true }
local MAX_CANDIDATES = 8

-- realistyczna wartość: AH (minus 5% prowizji), jeśli się opłaca, inaczej vendor
local function RealValue(vendor, ah)
    if ah and ns.AuctionWorthIt(vendor, ah) then return math.floor(ah * 0.95) end
    return vendor
end

-- Czy wyrzucenie przedmiotu zwolni zwykły slot: amunicja i wszystko z kołczanu, torby na
-- reagenty itp. nie pomoże, bo w takie torby nie włożysz zwykłych przedmiotów.
local BAG_REAGENT = 5   -- torba na reagenty
local function FreesNormalSlot(item)
    if item.classID == 6 then return false end   -- amunicja (strzały, kule)
    if item.bag == BAG_REAGENT then return false end
    local _, family = C_Container.GetContainerNumFreeSlots(item.bag)
    return not family or family == 0
end

local function Candidates()
    local list = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        if not SAFE[item.cat] and not item.isQuest and not item.randomSuffix and not item.info.isLocked
            and FreesNormalSlot(item) then
            local e = ns.ListEntry(item)
            e.real = RealValue(e.value, e.ah)
            if e.real > 0 then list[#list + 1] = e end
        end
    end
    table.sort(list, function(a, b) return a.real < b.real end)
    for i = #list, MAX_CANDIDATES + 1, -1 do list[i] = nil end
    -- na górze rzeczy z "Use me!": użycie (receptura, start questa, założenie torby, otwarcie)
    -- też zwalnia slot, a niczego nie niszczy. Klik ich nie niszczy - używasz ich w plecaku.
    local useme = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        if item.cat == "useme" then
            local e = ns.ListEntry(item)
            e.useme, e.reason = true, item.reason
            useme[#useme + 1] = e
        end
    end
    for i = #useme, 1, -1 do table.insert(list, 1, useme[i]) end
    return list
end

local lootOpen = false
ns.On("LOOT_OPENED", function() lootOpen = true end)
ns.On("LOOT_CLOSED", function() lootOpen = false end)

local pendingLootInfo = false   -- jakiś przedmiot z lootu czeka na dane z serwera

-- Najcenniejsza rzecz, która została w okienku lootu (przedmioty questowe zawsze wygrywają)
local function LootTarget()
    pendingLootInfo = false
    if not lootOpen then return nil end
    local best
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        local icon, name, qty, currencyID, quality, _, isQuestItem = GetLootSlotInfo(i)
        local isItem = not (GetLootSlotType and Enum and Enum.LootSlotType) or GetLootSlotType(i) == Enum.LootSlotType.Item
        if link and isItem and not currencyID then
            qty = (qty and qty > 0) and qty or 1
            -- przedmiot jeszcze nieznany klientowi: link ma pustą nazwę "[]", brak ikony i ceny.
            -- Ikona z GetItemInfoInstant (działa od razu), nazwa z okienka lootu, a gdy dane
            -- dojdą (GET_ITEM_INFO_RECEIVED), ramka się odświeży.
            icon = icon or select(5, C_Item.GetItemInfoInstant(link))
            if name and name ~= "" and link:find("%[%]") then
                link = link:gsub("%[%]", "[" .. name .. "]")
            end
            local info = { ns.GetItemInfo(link) }
            if not info[1] then pendingLootInfo = true end
            local sell = info[11] or 0
            local vendor = sell * qty
            local ah = ns.AuctionValue({ link = link, info = { stackCount = qty } })
            local e = { index = i, link = link, qty = qty, value = RealValue(vendor, ah), quest = isQuestItem,
                vendor = vendor, ah = ah,
                icon = icon, quality = quality }
            if not best or (e.quest and not best.quest) or (e.quest == best.quest and e.value > best.value) then
                best = e
            end
        end
    end
    return best
end

local target   -- wynik LootTarget() z chwili otwarcia okna
local win

local function Verdict(list)
    local cheapest   -- najtańsza rzecz do zniszczenia (bez pozycji z "Use me!")
    for _, e in ipairs(list) do if not e.useme then cheapest = e break end end
    if not target then
        if not cheapest then return "Bags are full and nothing here is safe to suggest." end
        return "Bags are full. Cheapest things you carry:"
    end
    if target.quest then
        return "|cffffd100Quest item|r - make room for it."
    end
    if target.value <= 0 then
        return "|cff999999No price known - your call.|r"
    end
    if not cheapest or target.value <= cheapest.real then
        return "|cffe08060Not worth it|r - it's worth less than anything here."
    end
    return "|cff66cc99Worth it|r - destroy something marked green."
end

local function Reload(w)
    w.list = Candidates()
    -- przy lootcie: zielone = tańsze niż to, co podnosisz (warto zamienić), reszta przygaszona
    for _, e in ipairs(w.list) do
        e.good, e.dim = nil, nil
        if e.useme then
            -- "Use me!" ma własne oznaczenie (niebieski pasek), bez porównania z lootem
        elseif target and target.quest then
            e.good = true
        elseif target and target.value > 0 then
            e.good = e.real < target.value
            e.dim = not e.good
        end
    end
    w.hintText:SetText(Verdict(w.list))
    if w.UpdatePick then w.UpdatePick() end
    w:Render()
end

-- loot się zmienił albo zamknął: odśwież werdykt i podświetlenie, jeśli okno jest otwarte
local function LootChanged()
    if not win or not win:IsShown() then return end
    target = LootTarget()
    Reload(win)
end
ns.On("LOOT_OPENED", function() C_Timer.After(0, LootChanged) end)
ns.On("LOOT_SLOT_CLEARED", function() C_Timer.After(0, LootChanged) end)
ns.On("LOOT_CLOSED", function() C_Timer.After(0, LootChanged) end)
-- dane przedmiotu z lootu doszły z serwera: teraz znamy nazwę, ikonę i cenę
ns.On("GET_ITEM_INFO_RECEIVED", function()
    if pendingLootInfo and lootOpen then C_Timer.After(0.1, LootChanged) end
end)

local function Destroy(w, e)
    local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
    if not info or info.itemID ~= e.id or info.isLocked then
        return Reload(w)
    end
    if CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(e.bag, e.slot)
    DeleteCursorItem()
    ns.Print("Destroyed " .. (e.link or e.name or "item") .. (e.count > 1 and (" x" .. e.count) or "") .. ".")
    -- miejsce jest: zabieramy to, czego wcześniej nie dało się podnieść
    if target and lootOpen then
        local index = target.index
        C_Timer.After(0.4, function() if lootOpen then LootSlot(index) end end)
        target = nil
        w:Hide()
        return
    end
    C_Timer.After(0.4, function() if w:IsShown() then Reload(w) end end)
end

win = ns.CreateItemListWindow({
    name = "PopokiBagRoomFrame",
    title = "Make room",
    hint = "",
    extraTop = 46,   -- ramka z podnoszonym przedmiotem
    tooltip = { "Click: select, click again: destroy", "Right-click: hide from this list" },
    onLeft = function(w, index)
        local e = w.list[index]
        if not e then return end
        if e.useme then
            ns.Print((e.link or e.name or "Item") .. ": use it from your bags (right-click) to free a slot.")
            return
        end
        if e.selected then return Destroy(w, e) end
        for _, x in ipairs(w.list) do x.selected = nil end
        e.selected = true
        w:Render()
    end,
    onRight = function(w, index)
        table.remove(w.list, index)
        w:Render()
    end,
    summary = function(w)
        for _, e in ipairs(w.list) do
            if e.selected then
                return "|cffe08060Click again to destroy|r " .. (e.link or e.name or "")
            end
        end
        return #w.list > 0 and "Click an item to select it" or ""
    end,
    buttons = {
        { label = "Close", onClick = function(w) w:Hide() end },
    },
})
win.hintText:SetPoint("RIGHT", win, "RIGHT", -14, 0)
win.hintText:SetJustifyH("LEFT")
win.hintText:SetWordWrap(false)
win.hintText:SetFontObject("GameFontHighlight")   -- werdykt ma być dobrze widoczny
ns.RegisterSideWindow(win)

-- Ramka nad listą: CO podnosisz (ikona, nazwa w kolorze jakości, ilość, wartość).
-- Najedź, żeby zobaczyć pełny tooltip przedmiotu.
local pick = CreateFrame("Frame", nil, win, "BackdropTemplate")
pick:SetPoint("TOPLEFT", 12, -56)
pick:SetPoint("TOPRIGHT", -12, -56)
pick:SetHeight(40)
pick:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
pick:SetBackdropColor(0, 0, 0, 0.35)
pick:SetBackdropBorderColor(1, 1, 1, 0.15)
pick:EnableMouse(true)
pick.icon = pick:CreateTexture(nil, "ARTWORK")
pick.icon:SetSize(32, 32)
pick.icon:SetPoint("LEFT", 4, 0)
pick.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
pick.label = pick:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pick.label:SetPoint("TOPLEFT", pick.icon, "TOPRIGHT", 8, -1)
pick.label:SetTextColor(0.6, 0.6, 0.6)
pick.name = pick:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pick.name:SetPoint("BOTTOMLEFT", pick.icon, "BOTTOMRIGHT", 8, 1)
pick.name:SetPoint("RIGHT", pick, "RIGHT", -120, 0)
pick.name:SetJustifyH("LEFT")
pick.name:SetWordWrap(false)
-- wartość w dwóch linijkach, jak kolumny listy: "Vendor ..." i "AH ..."
pick.value = pick:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pick.value:SetPoint("TOPRIGHT", -8, -5)
pick.value:SetJustifyH("RIGHT")
pick.ah = pick:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pick.ah:SetPoint("BOTTOMRIGHT", -8, 5)
pick.ah:SetJustifyH("RIGHT")
pick:SetScript("OnEnter", function(self)
    if not target then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(target.link)
    GameTooltip:Show()
end)
pick:SetScript("OnLeave", function() GameTooltip:Hide() end)

function win.UpdatePick()
    if target then
        pick.icon:SetTexture(target.icon or 134400)
        pick.icon:SetDesaturated(false)
        pick.label:SetText(target.quest and "Picking up (quest item)" or "Picking up")
        pick.name:SetText(target.link .. (target.qty > 1 and (" |cffffffffx" .. target.qty .. "|r") or ""))
        local none = "|cff666666-|r"
        pick.value:SetText("|cff999999Vendor|r  " .. ((target.vendor or 0) > 0 and ns.MoneyText(target.vendor) or none))
        pick.ah:SetText("|cff999999AH|r  " .. (target.ah and ns.MoneyText(target.ah) or none))   -- jak kolumna AH w liście
    else
        pick.icon:SetTexture(134400)   -- znak zapytania
        pick.icon:SetDesaturated(true)
        pick.label:SetText("Picking up")
        pick.name:SetText("|cff999999nothing from loot - just the cheapest things you carry|r")
        pick.value:SetText("")
        pick.ah:SetText("")
    end
end

local function OpenRoom()
    target = LootTarget()
    Reload(win)
    if not win:IsShown() then
        win:ClearAllPoints()
        if LootFrame and LootFrame:IsShown() then
            win:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 12, 0)
        else
            ns.PlaceBeside(win)   -- na lewo od plecaka i innych otwartych okien
        end
        win:Show()
    end
end
ns.OpenRoom = OpenRoom
ns.commands.room = OpenRoom

local FULL = {}
for _, k in ipairs({ "ERR_INV_FULL", "ERR_BAG_FULL" }) do
    if _G[k] then FULL[_G[k]] = true end
end

local lastOpen = 0
ns.On("UI_ERROR_MESSAGE", function(_, _, message)
    if not FULL[message] or not ns.Setting("roomPopup") then return end
    if GetTime() - lastOpen < 1 then return end
    lastOpen = GetTime()
    ns.SafeCall("Make room", OpenRoom)
end)

-- przycisk w nagłówku plecaka: drugi klik zamyka
function ns.ToggleRoom()
    if win:IsShown() then win:Hide() else OpenRoom() end
end
ns.commands.room = ns.ToggleRoom

---------------------------------------------------------------------------
-- 3) Sortowanie w widoku Bags ("Sort bags"): przedmioty po kolei zapełniają pierwsze torby,
--    a puste sloty zostają w ostatnich - tak da się opróżnić torbę do wymiany.
--    Ruszamy tylko zwykłe torby (bez torby na reagenty, kołczanów itp.). Kategorie, kolejność
--    w sekcjach i przypisania są po rodzaju przedmiotu, więc przenosiny niczego tam nie zmieniają.
---------------------------------------------------------------------------
local REAGENT_BAG = 5
local MAX_MOVES = 300

local function GeneralSlots()
    local list = {}
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        if bag ~= REAGENT_BAG and (not family or family == 0) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                list[#list + 1] = { bag = bag, slot = slot }
            end
        end
    end
    return list
end

function ns.CompactBags()
    if ns.compacting then return end
    if InCombatLockdown() then return ns.Print("Can't sort bags in combat.") end
    ns.compacting = true
    ns.RequestRefresh()
    local moves, waits = 0, 0
    local function finish(reason)
        ns.compacting = false
        if reason then ns.Print(reason) end
        ns.RequestRefresh()
    end
    local function step()
        if InCombatLockdown() then return finish("Sorting stopped: combat started.") end
        if CursorHasItem() then return finish("Sorting stopped: you're holding an item.") end
        local slots = GeneralSlots()
        -- pierwszy pusty slot i ostatni zajęty za nim
        local empty, last
        for i, s in ipairs(slots) do
            if not C_Container.GetContainerItemID(s.bag, s.slot) then empty = i break end
        end
        if empty then
            for i = #slots, empty + 1, -1 do
                local s = slots[i]
                if C_Container.GetContainerItemID(s.bag, s.slot) then last = i break end
            end
        end
        if not (empty and last) or moves >= MAX_MOVES then return finish() end
        local from, to = slots[last], slots[empty]
        local info = C_Container.GetContainerItemInfo(from.bag, from.slot)
        if info and info.isLocked then
            -- poprzedni ruch jeszcze się nie zakończył po stronie serwera
            waits = waits + 1
            if waits > 30 then return finish("Sorting stopped: an item stayed locked.") end
            return C_Timer.After(0.2, step)
        end
        waits = 0
        C_Container.PickupContainerItem(from.bag, from.slot)
        C_Container.PickupContainerItem(to.bag, to.slot)
        if CursorHasItem() then ClearCursor() return finish("Sorting stopped: couldn't move an item.") end
        moves = moves + 1
        C_Timer.After(0.12, step)
    end
    step()
end

---------------------------------------------------------------------------
-- 4) Cleanup: porządkuje kolejność WEWNĄTRZ każdej kategorii według rodzaju przedmiotu
--    (np. Consumables: jedzenie, picie, mikstury, eliksiry, flaszki, scrolle, bandaże...).
--    Niczego nie przenosi w torbach - zmienia tylko Twoją kolejność (PopokiBagCharDB.order),
--    tę samą, którą ustawiasz przeciąganiem. Nowe przedmioty dalej wskakują na początek sekcji.
---------------------------------------------------------------------------
local CONSUMABLE_CLASS = 0
-- podklasy Consumables w kolejności wyświetlania (jedzenie i picie rozdzielamy niżej)
local CONSUMABLE_ORDER = { [5] = 1, [1] = 3, [2] = 4, [3] = 5, [4] = 6, [7] = 7, [6] = 8, [0] = 9, [8] = 10 }

-- jedzenie przed piciem: zaklęcie użycia to "Food" / "Drink" / "Refreshment"
local function FoodOrDrink(id)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    local spell = getSpell and getSpell(id)
    if spell == "Drink" then return 2 end
    return 1
end

local function CleanupKey(id)
    local name, _, quality, itemLevel, _, _, _, _, _, _, _, classID, subClassID = ns.GetItemInfo(id)
    local group
    if classID == CONSUMABLE_CLASS then
        group = CONSUMABLE_ORDER[subClassID] or 11
        if subClassID == 5 then group = FoodOrDrink(id) end
    else
        group = (subClassID or 0) + 1
    end
    return { class = classID or 99, group = group, level = itemLevel or 0, quality = quality or 0, name = name or "" }
end

function ns.CleanupOrder()
    local ids, seen = {}, {}
    for _, item in ipairs(ns.Scan()) do
        local id = item.info.itemID
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = { id = id, key = CleanupKey(id) }
        end
    end
    table.sort(ids, function(a, b)
        local x, y = a.key, b.key
        if x.class ~= y.class then return x.class < y.class end
        if x.group ~= y.group then return x.group < y.group end
        if x.level ~= y.level then return x.level > y.level end      -- lepsze (wyższy poziom) wyżej
        if x.quality ~= y.quality then return x.quality > y.quality end
        return x.name < y.name
    end)
    for i, e in ipairs(ids) do PopokiBagCharDB.order[e.id] = i end
    ns.Print("Cleanup: items in each category are now ordered by type.")
    ns.RequestRefresh()
end

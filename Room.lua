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
    if InCombatLockdown() or CursorHasItem() or ns.merchantOpen or ns.ElsewhereOpen() then return end
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

local function Candidates()
    local list = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        if not SAFE[item.cat] and not item.isQuest and not item.randomSuffix and not item.info.isLocked then
            local e = ns.ListEntry(item)
            e.real = RealValue(e.value, e.ah)
            if e.real > 0 then list[#list + 1] = e end
        end
    end
    table.sort(list, function(a, b) return a.real < b.real end)
    for i = #list, MAX_CANDIDATES + 1, -1 do list[i] = nil end
    return list
end

local lootOpen = false
ns.On("LOOT_OPENED", function() lootOpen = true end)
ns.On("LOOT_CLOSED", function() lootOpen = false end)

-- Najcenniejsza rzecz, która została w okienku lootu (przedmioty questowe zawsze wygrywają)
local function LootTarget()
    if not lootOpen then return nil end
    local best
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        local _, name, qty, currencyID, _, _, isQuestItem = GetLootSlotInfo(i)
        if link and not currencyID then
            qty = (qty and qty > 0) and qty or 1
            local sell = select(11, ns.GetItemInfo(link)) or 0
            local vendor = sell * qty
            local ah = ns.AuctionValue({ link = link, info = { stackCount = qty } })
            local e = { index = i, link = link, qty = qty, value = RealValue(vendor, ah), quest = isQuestItem }
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
    local cheapest = list[1]
    if not target then
        if not cheapest then return "Bags are full and nothing here is safe to suggest." end
        return "Bags are full. Cheapest things you carry:"
    end
    local what = target.link .. (target.qty > 1 and (" x" .. target.qty) or "")
    if target.quest then
        return "|cffffd100Quest item:|r " .. what .. " - make room for it."
    end
    if target.value <= 0 then
        return "|cff999999No price known for|r " .. what .. "|cff999999 - your call.|r"
    end
    if not cheapest or target.value <= cheapest.real then
        return "|cffe08060Not worth it:|r " .. what .. " (" .. ns.MoneyText(target.value) .. ") is worth less than anything here."
    end
    return "|cff66cc99Worth it:|r " .. what .. " (" .. ns.MoneyText(target.value) .. ") - destroy something cheaper."
end

local function Reload(w)
    w.list = Candidates()
    w.hintText:SetText(Verdict(w.list))
    w:Render()
end

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
    tooltip = { "Click: select, click again: destroy", "Right-click: hide from this list" },
    onLeft = function(w, index)
        local e = w.list[index]
        if not e then return end
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

local function OpenRoom()
    target = LootTarget()
    Reload(win)
    if not win:IsShown() then
        win:ClearAllPoints()
        if LootFrame and LootFrame:IsShown() then
            win:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 12, 0)
        else
            win:SetPoint("CENTER", 0, 80)
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

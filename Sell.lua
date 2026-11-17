local ADDON, ns = ...

-- Sprzedaż sekcji For Vendor: okno otwiera się samo u vendora (jeśli jest co sprzedać).
-- Lewy klik = sprzedaj ten jeden, prawy = zaznacz/odznacz "keep", Sell all = sprzedaj
-- niezaznaczone, a zaznaczone na stałe do Misfits. Cancel niczego nie zmienia.
-- Po jednym przedmiocie co 0,08 s; przerywamy, gdy vendor się zamknie, zacznie się walka
-- albo gra poprosi o potwierdzenie sprzedaży (przedmiot na kursorze).
-- Pomijamy przedmioty bez ceny i te, które da się jeszcze zwrócić (refund).
-- Wzór sprzedaży: EllesmereUIBags SellJunk (EUI_Bags_Select.lua:640).

ns.merchantOpen = false

-- tab "main" = For Vendor, inaczej klucz kategorii profesji: to z niej, co lepiej sprzedać u vendora
local function GatherSellable(tab)
    local list = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        local wanted
        if tab ~= "main" then
            wanted = item.cat == tab and item.profSell == "vendor"
        else
            wanted = item.cat == "vendor"
        end
        if wanted and not item.info.hasNoValue and (item.sellPrice or 0) > 0 then
            local p = C_Container.GetContainerItemPurchaseInfo(item.bag, item.slot, false)
            if not (p and p.refundSeconds and p.refundSeconds > 0) then
                list[#list + 1] = ns.ListEntry(item)
            end
        end
    end
    return list
end

local selling = false

local function SellList(list)
    if selling then return end
    selling = true
    local i, sold, earned = 0, 0, 0
    local function finish(reason)
        selling = false
        if sold > 0 then ns.Print("Sold " .. sold .. " item(s) for " .. ns.MoneyText(earned)) end
        if reason then ns.Print(reason) end
        ns.RequestRefresh()
    end
    local function step()
        if not ns.merchantOpen then return finish(i < #list and "Stopped: merchant closed." or nil) end
        if InCombatLockdown() then return finish("Stopped: combat started.") end
        if CursorHasItem() then return finish("Stopped: the game is asking you to confirm a sale.") end
        while i < #list do
            i = i + 1
            local e = list[i]
            local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
            -- nadal ten sam przedmiot i nie zablokowany
            if info and info.itemID == e.id and not info.isLocked then
                C_Container.UseContainerItem(e.bag, e.slot)
                sold, earned = sold + 1, earned + e.value
                C_Timer.After(0.08, step)
                return
            end
        end
        finish()
    end
    step()
end

-- Zaznaczone "keep" na stałe do Misfits, żeby nie wracały na listę
function ns.KeepToMisfits(list)
    local done = {}
    for _, e in ipairs(list) do
        if e.keep and not done[e.id] then
            done[e.id] = true
            ns.AssignItem(e.id, "misfits", e.autoCat)
            ns.Print((e.link or e.name or "item") .. " -> Misfits")
        end
    end
    if next(done) then ns.RequestRefresh() end
end

local win
win = ns.CreateItemListWindow({
    name = "PopokiBagSellFrame",
    title = "Sell to vendor",
    hint = "Click: sell   Right-click: keep",
    onTab = function(w, key)
        w.list = GatherSellable(key)
        w.scroll:SetVerticalScroll(0)
        w:Render()
    end,
    tooltip = { "Click: sell this item now", "Right-click: keep it (not sold by Sell all)" },
    onLeft = function(w, index)
        local e = w.list[index]
        if not e or not ns.merchantOpen or selling then return end
        table.remove(w.list, index)
        SellList({ e })
        if #w.list == 0 then
            -- zakładka pusta: po chwili otwórz pierwszą niepustą (np. Skinning)
            w:Hide()
            C_Timer.After(0.8, function() ns.SellVendorSection(true) end)
        else
            w:Render()
        end
    end,
    onRight = function(w, index)
        local e = w.list[index]
        if not e then return end
        e.keep = not e.keep
        w:Render()
    end,
    summary = function(w)
        local n, total, kept = 0, 0, 0
        for _, e in ipairs(w.list) do
            if e.keep then kept = kept + 1 else n, total = n + 1, total + e.value end
        end
        local text = n .. " to sell   " .. ns.MoneyText(total)
        if kept > 0 then text = text .. "   |cff999999(" .. kept .. " kept)|r" end
        return text
    end,
    buttons = {
        { label = "Sell all", onClick = function(w)
            local toSell = {}
            for _, e in ipairs(w.list) do
                if not e.keep then toSell[#toSell + 1] = e end
            end
            w:Hide()
            if w.tab == "main" then ns.KeepToMisfits(w.list) end
            if #toSell > 0 then SellList(toSell) end
        end },
        { label = "Cancel", onClick = function(w) w:Hide() end },
    },
})

function ns.SellVendorSection(silent, startTab)
    if not ns.merchantOpen or selling then return end
    if InCombatLockdown() then
        ns.Print("Can't sell during combat.")
        return
    end
    -- zakładki: For Vendor + kategorie profesji postaci; okno zawsze otwiera się na For Vendor
    local tabs, counts, any = { { key = "main", label = "For Vendor" } }, {}, false
    counts.main = #GatherSellable("main")
    for _, c in ipairs(ns.CATEGORIES) do
        if c.isProfession then
            tabs[#tabs + 1] = { key = c.key, label = c.label }
            counts[c.key] = #GatherSellable(c.key)
        end
    end
    for _, n in pairs(counts) do if n > 0 then any = true end end
    if not any then
        if not silent then ns.Print("Nothing to sell.") end
        return
    end
    -- podana zakładka (przycisk w nagłówku sekcji), inaczej pierwsza niepusta
    local start = (startTab and (counts[startTab] or 0) > 0) and startTab
    if not start then
        for _, t in ipairs(tabs) do
            if counts[t.key] > 0 then start = t.key break end
        end
    end
    win:SetTabs(tabs)
    for key, n in pairs(counts) do win:SetTabCount(key, n) end
    win:SetTab(start)
    win:Show()
end

ns.On("MERCHANT_SHOW", function()
    ns.merchantOpen = true
    ns.RequestRefresh()
    -- okno sprzedaży otwiera się samo, jeśli w For Vendor coś jest (chwila na wczytanie danych)
    C_Timer.After(0.2, function()
        if ns.merchantOpen and not win:IsShown() and ns.Setting("autoSell") then ns.SellVendorSection(true) end
    end)
end)
ns.On("MERCHANT_CLOSED", function()
    ns.merchantOpen = false
    win:Hide()
    ns.RequestRefresh()
end)

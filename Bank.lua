local ADDON, ns = ...

-- Odkładanie do banku: przy otwarciu banku okno z To Bank (i zakładkami kategorii profesji).
-- Lewy klik = odłóż ten jeden, prawy = zaznacz/odznacz "keep" (zostaje w plecaku),
-- Deposit all = odłóż niezaznaczone, po jednym co 0,08 s (jak sprzedaż w Sell.lua).
-- Przy otwartym banku UseContainerItem przenosi przedmiot z plecaka do banku.

local bankOpen = false

-- tab "main" = To Bank, inaczej klucz kategorii profesji (cała jej zawartość)
local function GatherBankable(tab)
    local list = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        local wanted = (tab == "main" and item.cat == "bank") or (tab ~= "main" and item.cat == tab)
        if wanted then list[#list + 1] = ns.ListEntry(item) end
    end
    return list
end

local moving = false

local function DepositList(list)
    if moving then return end
    moving = true
    local i = 0
    local function finish(reason)
        moving = false
        -- liczymy, co faktycznie zniknęło z plecaka (pełny bank = przedmiot zostaje)
        C_Timer.After(0.5, function()
            local moved = 0
            for _, e in ipairs(list) do
                if C_Container.GetContainerItemID(e.bag, e.slot) ~= e.id then moved = moved + 1 end
            end
            if moved > 0 then ns.Print("Moved " .. moved .. " item(s) to the bank.") end
            if moved < #list and not reason then reason = (#list - moved) .. " item(s) didn't fit (bank full?)." end
            if reason then ns.Print(reason) end
            ns.RequestRefresh()
        end)
    end
    local function step()
        if not bankOpen then return finish(i < #list and "Stopped: bank closed." or nil) end
        if InCombatLockdown() then return finish("Stopped: combat started.") end
        while i < #list do
            i = i + 1
            local e = list[i]
            local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
            if info and info.itemID == e.id and not info.isLocked then
                C_Container.UseContainerItem(e.bag, e.slot)
                C_Timer.After(0.08, step)
                return
            end
        end
        finish()
    end
    step()
end

local win
win = ns.CreateItemListWindow({
    name = "PopokiBagBankFrame",
    title = "Put in bank",
    hint = "Click: put in bank   Right-click: keep in bags",
    tooltip = { "Click: put this item in the bank now", "Right-click: keep it in your bags" },
    onTab = function(w, key)
        w.list = GatherBankable(key)
        w.scroll:SetVerticalScroll(0)
        w:Render()
    end,
    onLeft = function(w, index)
        local e = w.list[index]
        if not e or not bankOpen or moving then return end
        table.remove(w.list, index)
        DepositList({ e })
        w:Render()
    end,
    onRight = function(w, index)
        local e = w.list[index]
        if not e then return end
        e.keep = not e.keep
        w:Render()
    end,
    summary = function(w)
        local n, kept = 0, 0
        for _, e in ipairs(w.list) do
            if e.keep then kept = kept + 1 else n = n + 1 end
        end
        local text = n .. " to put in bank"
        if kept > 0 then text = text .. "   |cff999999(" .. kept .. " kept)|r" end
        return text
    end,
    buttons = {
        { label = "Deposit all", onClick = function(w)
            local toMove = {}
            for _, e in ipairs(w.list) do
                if not e.keep then toMove[#toMove + 1] = e end
            end
            w:Hide()
            if #toMove > 0 then DepositList(toMove) end
        end },
        { label = "Close", onClick = function(w) w:Hide() end },
    },
})

-- force = przycisk Deposit w oknie banku: otwiera też przy pustym To Bank, drugi klik zamyka
local function OpenBankList(force)
    if force and win:IsShown() then win:Hide() return end
    if not bankOpen or win:IsShown() or InCombatLockdown() then return end
    -- zakładki: To Bank + kategorie profesji; okno otwiera się zawsze na To Bank, a tylko gdy tam coś jest
    local tabs, counts = { { key = "main", label = "To Bank" } }, {}
    counts.main = #GatherBankable("main")
    if counts.main == 0 and not force then return end
    for _, c in ipairs(ns.CATEGORIES) do
        if c.isProfession then
            tabs[#tabs + 1] = { key = c.key, label = c.label }
            counts[c.key] = #GatherBankable(c.key)
        end
    end
    win:SetTabs(tabs)
    for key, n in pairs(counts) do win:SetTabCount(key, n) end
    win:ClearAllPoints()
    if ns.bankWin and ns.bankWin:IsShown() then
        ns.PlaceBeside(win)   -- na lewo od naszego okna banku
    elseif BankFrame and BankFrame:IsShown() and BankFrame:IsVisible() then
        win:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 12, 0)
    else
        win:SetPoint("CENTER", 0, 80)
    end
    win:SetTab("main")
    win:Show()
end
ns.OpenBankList = OpenBankList

ns.On("BANKFRAME_OPENED", function()
    bankOpen = true
    if ns.Setting("autoBank") then C_Timer.After(0.2, OpenBankList) end
end)
ns.On("BANKFRAME_CLOSED", function()
    bankOpen = false
    win:Hide()
end)

local ADDON, ns = ...

-- Wystawianie For Auction przez Auctionatora: przy otwarciu AH obok okna aukcji pokazuje się
-- lista. Lewy klik wrzuca przedmiot do zakładki Selling Auctionatora (on dobiera cenę),
-- Ty klikasz jego Post albo spację. Po wystawieniu sam wskakuje następny przedmiot.
-- Prawy klik = zaznacz/odznacz "keep"; po zamknięciu okna zaznaczone idą do Misfits.
-- Samego wystawiania nie robimy: gra wymaga Twojego kliknięcia/klawisza przy każdej aukcji.
--
-- Auctionator nie ma publicznego API do Selling, więc wołamy to samo, co jego Alt+klik
-- w torbach (Source_ModernAH/Selling/Hooks.lua): zdarzenie BagItemClicked na jego EventBus.
-- Każdą nazwę sprawdzamy przed użyciem; jeśli Auctionator się zmieni, okno po prostu nic nie zrobi.

local ahOpen = false
local SOURCE = {}   -- nadawca zdarzeń dla EventBus Auctionatora

local function AuctionatorReady()
    return Auctionator and Auctionator.EventBus and Auctionator.Selling and Auctionator.Selling.Events
        and Auctionator.Groups and Auctionator.Groups.Utilities and Auctionator.Groups.Utilities.ToPostingItem
        and AuctionatorTabs_Selling and AuctionatorBagCacheFrame and AuctionHouseFrame and AuctionHouseFrame:IsShown()
end

-- Wrzuca przedmiot z bag/slot do zakładki Selling Auctionatora
local function SelectInAuctionator(e)
    if not AuctionatorReady() then return false end
    local loc = ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
    if not loc:IsValid() or not C_AuctionHouse.IsSellItemValid(loc, false) then return false end
    AuctionatorTabs_Selling:Click()
    local link = C_Container.GetContainerItemLink(e.bag, e.slot)
    if not link then return false end
    AuctionatorBagCacheFrame:CacheLinkInfo(link, function()
        local raw = AuctionatorBagCacheFrame:GetByLinkInstant(link, true)
        if not raw or not (AuctionatorSellingFrame and AuctionatorSellingFrame:IsVisible()) then return end
        local info = Auctionator.Groups.Utilities.ToPostingItem(raw)
        info.itemLink = link
        info.location = loc
        info.count = C_AuctionHouse.GetAvailablePostCount(loc)
        pcall(function()
            Auctionator.EventBus:RegisterSource(SOURCE, "Popoki Bag")
            Auctionator.EventBus:Fire(SOURCE, Auctionator.Selling.Events.BagItemClicked, info)
            Auctionator.EventBus:UnregisterSource(SOURCE)
        end)
    end)
    return true
end

-- tab "main" = For Auction, inaczej klucz kategorii profesji: to z niej, co lepiej wystawić na AH
local function GatherAuctionable(tab)
    local list = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        local wanted
        if tab ~= "main" then
            wanted = item.cat == tab and item.profSell == "auction"
        else
            wanted = item.cat == "auction"
        end
        if wanted then list[#list + 1] = ns.ListEntry(item) end
    end
    return list
end

local win

local function Select(index)
    local e = win.list[index]
    if not e or e.keep then return end
    for _, x in ipairs(win.list) do x.selected = nil end
    local ok, loaded = pcall(SelectInAuctionator, e)
    if ok and loaded then
        e.selected = true
    else
        ns.Print("Couldn't load " .. (e.link or e.name or "item") .. " into Auctionator.")
    end
    win:Render()
end

-- następny niezaznaczony przedmiot za wybranym (albo pierwszy)
local function SelectNext(after)
    local list = win.list
    for k = 1, #list do
        local i = ((after or 0) + k - 1) % #list + 1
        if not list[i].keep then return Select(i) end
    end
end

win = ns.CreateItemListWindow({
    name = "PopokiBagAuctionFrame",
    title = "Post to auction",
    hint = "Click: load   Right-click: keep   Post or Space: post",
    onTab = function(w, key)
        w.list = GatherAuctionable(key)
        w.scroll:SetVerticalScroll(0)
        w:Render()
        SelectNext(0)
    end,
    tooltip = { "Click: load into Auctionator, then press Post (or Space)", "Right-click: keep it (moves to Misfits when you close this)" },
    onLeft = function(w, index) Select(index) end,
    onRight = function(w, index)
        local e = w.list[index]
        if not e then return end
        e.keep = not e.keep
        if e.keep then e.selected = nil end
        w:Render()
    end,
    summary = function(w)
        -- ile do wystawienia, szacunek AH tylko dla znanych cen, reszta "price in Auctionator"
        local n, total, kept, unknown = 0, 0, 0, 0
        for _, e in ipairs(w.list) do
            if e.keep then
                kept = kept + 1
            else
                n = n + 1
                local v = e.live or e.ah
                if v then total = total + v else unknown = unknown + 1 end
            end
        end
        local text = n .. " to post"
        if total > 0 then text = text .. "   ~" .. ns.MoneyText(total) end
        if unknown > 0 then text = text .. "   |cff999999(" .. unknown .. " priced in Auctionator)|r" end
        if kept > 0 then text = text .. "   |cff999999(" .. kept .. " kept)|r" end
        return text
    end,
    buttons = {
        -- Post: Twoje kliknięcie przekazane do przycisku Post Auctionatora (gra wymaga kliknięcia
        -- przy każdej aukcji, więc nigdy nie wołamy tego z timera)
        { label = "Post", onClick = function(w)
            local post = AuctionatorPostButton
            if not post then
                ns.Print("Auctionator's Selling tab isn't open.")
            elseif not post:IsEnabled() then
                ns.Print("Auctionator isn't ready to post yet (still checking prices?). Try again in a moment.")
            else
                post:Click()
            end
        end },
        { label = "Next", onClick = function(w)
            local cur
            for i, e in ipairs(w.list) do if e.selected then cur = i end end
            SelectNext(cur)
        end },
        { label = "Close", onClick = function(w) w:Hide() end },
    },
})

-- "keep" z For Auction idzie do Misfits; w zakładkach profesji tylko pomija (materiały zostają w swojej kategorii)
win:HookScript("OnHide", function(self) if self.tab == "main" then ns.KeepToMisfits(self.list) end end)

-- Cena z zakładki Selling Auctionatora dla podświetlonego przedmiotu: pole Buyout Price
-- (za sztukę) × Quantity. Odczyt co 0,25 s, więc ręczna zmiana ceny w Auctionatorze też widać.
local function LivePrice(e)
    local sf = AuctionatorSellingFrame and AuctionatorSellingFrame.SaleItemFrame
    if not (sf and sf:IsVisible() and sf.Price and sf.Quantity and sf.itemInfo) then return nil end
    local link = C_Container.GetContainerItemLink(e.bag, e.slot)
    if not link or sf.itemInfo.itemLink ~= link then return nil end
    local ok, unit = pcall(sf.Price.GetAmount, sf.Price)
    if not ok or not unit or unit <= 0 then return nil end
    local okq, qty = pcall(sf.Quantity.GetNumber, sf.Quantity)
    return unit * ((okq and qty and qty > 0) and qty or 1)
end

local elapsed = 0
win:HookScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    local sel
    for _, e in ipairs(self.list) do if e.selected then sel = e end end
    local live = sel and LivePrice(sel)
    if sel and sel.live ~= live then
        sel.live = live
        self:Render()
    end
    local label = live and ("Post " .. ns.MoneyText(live)) or "Post"
    local b = self.buttons.Post
    if b and b.text:GetText() ~= label then b:SetLabel(label) end
end)

-- Po zmianie w torbach (wystawiony przedmiot znika) odświeżamy listę i ładujemy następny
local function Rebuild()
    if not win:IsShown() then return end
    local old, selectedGone, selectedPos = {}, false, nil
    for i, e in ipairs(win.list) do
        old[e.bag * 1000 + e.slot] = e
        if e.selected then selectedPos = i end
    end
    local list = GatherAuctionable(win.tab)
    for _, e in ipairs(list) do
        local prev = old[e.bag * 1000 + e.slot]
        if prev and prev.id == e.id then e.keep, e.selected = prev.keep, prev.selected end
    end
    if selectedPos then
        selectedGone = true
        for _, e in ipairs(list) do if e.selected then selectedGone = false end end
    end
    win.list = list
    if #list == 0 then
        win:Hide()
        return
    end
    win:Render()
    if selectedGone then SelectNext((selectedPos or 1) - 1) end
end

local pending = false
ns.On("BAG_UPDATE_DELAYED", function()
    if pending or not win:IsShown() then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        Rebuild()
    end)
end)

local function OpenAuctionList()
    if not ahOpen or win:IsShown() then return end
    if not AuctionatorReady() then return end
    -- zakładki: For Auction + kategorie profesji postaci; okno zawsze otwiera się na For Auction
    local tabs, counts, any = { { key = "main", label = "For Auction" } }, {}, false
    counts.main = #GatherAuctionable("main")
    for _, c in ipairs(ns.CATEGORIES) do
        if c.isProfession then
            tabs[#tabs + 1] = { key = c.key, label = c.label }
            counts[c.key] = #GatherAuctionable(c.key)
        end
    end
    for _, n in pairs(counts) do if n > 0 then any = true end end
    if not any then return end
    win:SetTabs(tabs)
    for key, n in pairs(counts) do win:SetTabCount(key, n) end
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 12, 0)
    win:Show()
    win:SetTab("main")   -- zawsze zakładka główna; ładuje listę i pierwszy przedmiot
end
ns.OpenAuctionList = OpenAuctionList

local AUCTIONEER = Enum.PlayerInteractionType and Enum.PlayerInteractionType.Auctioneer
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, paneType)
    if paneType ~= AUCTIONEER then return end
    ahOpen = true
    -- Auctionator przy pierwszym otwarciu sam przełącza zakładkę klatkę później; czekamy chwilę
    if ns.Setting("autoAuction") then C_Timer.After(0.6, OpenAuctionList) end
end)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, paneType)
    if paneType ~= AUCTIONEER then return end
    ahOpen = false
    win:Hide()
end)

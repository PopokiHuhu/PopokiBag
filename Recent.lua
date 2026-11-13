local ADDON, ns = ...

-- Nowe przedmioty: porównujemy liczbę sztuk każdego przedmiotu (torby + założony ekwipunek)
-- przed i po zmianie w torbach. Wzrost = nowy przedmiot, świeci do zamknięcia plecaka.
-- Przy otwartym banku i poczcie nie wykrywamy (przekładanie wyglądałoby jak loot).
-- Wzór: EUI_Bags_Start.lua (Recent Items).

ns.recent = {}   -- [itemID] = true

local known = {}
local ready, frozen = false, false

local function Tally()
    local counts = {}
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 0)
            end
        end
    end
    -- założony ekwipunek: zakładanie/zdejmowanie nie zmienia sumy, więc nie świeci
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then counts[id] = (counts[id] or 0) + (GetInventoryItemCount("player", slot) or 1) end
    end
    return counts
end

local function Resync()
    known = Tally()
    ready = true
end

ns.On("PLAYER_ENTERING_WORLD", Resync)

ns.On("BAG_UPDATE_DELAYED", function()
    if not ready or frozen then return end
    local counts = Tally()
    for id, n in pairs(counts) do
        if n > (known[id] or 0) then
            ns.recent[id] = true
            -- nie było go w ogóle (nowy albo znów zdobyty) = na początek sekcji
            if not known[id] then ns.MoveToFront(id) end
        end
    end
    known = counts
end)

local function Freeze() frozen = true end
local function Unfreeze()
    frozen = false
    Resync()
end
ns.On("BANKFRAME_OPENED", Freeze)
ns.On("MAIL_SHOW", Freeze)
ns.On("BANKFRAME_CLOSED", Unfreeze)
ns.On("MAIL_CLOSED", Unfreeze)

-- zamknięcie plecaka = przejrzane
ns.frame:HookScript("OnHide", function() wipe(ns.recent) end)

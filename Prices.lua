local ADDON, ns = ...

-- Ceny za cały stack (w miedziakach). Vendor z GetItemInfo, aukcja z Auctionatora (jeśli jest).

function ns.VendorValue(item)
    local sell = item.sellPrice or 0
    return sell * (item.info.stackCount or 1)
end

local function AuctionatorAPI()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    return api and api.GetAuctionPriceByItemLink and api
end

-- nil = brak danych z AH
function ns.AuctionValue(item)
    local api = AuctionatorAPI()
    if not api or not item.link then return nil end
    local ok, unit = pcall(api.GetAuctionPriceByItemLink, ADDON, item.link)
    if not ok or not unit or unit <= 0 then return nil end
    return unit * (item.info.stackCount or 1)
end

-- Czy AH się opłaca: cena AH >= vendor * próg% ORAZ zysk >= minimum (depozyt przepada przy braku sprzedaży)
function ns.AuctionWorthIt(vendor, ah)
    if not ah then return false end
    local ratio = PopokiBagDB.ahMinRatio or 1.5
    local minProfit = PopokiBagDB.ahMinProfit or 200
    return ah >= vendor * ratio and (ah - vendor) >= minProfit
end

-- Po skanie Auctionatora (pełnym albo przyrostowym) przeliczamy kategorie na świeżych cenach
ns.On("PLAYER_LOGIN", function()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.RegisterForDBUpdate then
        pcall(api.RegisterForDBUpdate, ADDON, function() ns.RequestRefresh() end)
    end
end)

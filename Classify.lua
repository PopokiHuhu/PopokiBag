local ADDON, ns = ...

-- Kategorie w kolejności wyświetlania. Pierwsze = rzeczy, które nosisz;
-- dalej decyzje, co zrobić z resztą. Przedmiot można przeciągnąć do innej (ns.AssignItem).
-- Kategorie profesji (np. Skinning, Mining) wstawiamy za Consumables według profesji postaci
-- (ns.EnsureCategories niżej), więc każda postać ma swoje.
local BASE_BEFORE = {
    { key = "essentials",  label = "Essentials",  color = { 0.40, 0.80, 0.40 } },
    { key = "consumables", label = "Consumables", color = { 0.30, 0.80, 0.80 } },
}
local BASE_AFTER = {
    { key = "vendor",      label = "For Vendor",  color = { 0.90, 0.40, 0.35 } },
    { key = "auction",     label = "For Auction", color = { 0.75, 0.50, 1.00 } },
    { key = "bank",        label = "To Bank",     color = { 0.35, 0.65, 1.00 } },
    { key = "misfits",     label = "Misfits",     color = { 0.62, 0.62, 0.62 } },
    { key = "quest",       label = "Quest Items", color = { 1.00, 0.82, 0.00 } },
}
ns.CATEGORIES = {}
ns.CATEGORY_BY_KEY = {}
-- Kategorie, z których nic nie sprzedajemy hurtem (profesje dopisuje ns.EnsureCategories)
ns.PROTECTED = { essentials = true, consumables = true, quest = true, misfits = true }

-- "Use me!": przedmioty do użycia od razu, pokazywane w lewym pasku zamiast w kategoriach
ns.USE_ME = { key = "useme", label = "Use me!", color = { 0.85, 0.85, 0.85 } }

-- Kolejność kategorii ustawiona przez Ciebie (PopokiBagDB.catOrder, przycisk Edit w lewym pasku).
-- Kategorie, których nie ma na zapisanej liście (np. nowe), dopisujemy na końcu.
function ns.OrderedCategories()
    local list, seen = {}, {}
    for _, key in ipairs(PopokiBagDB.catOrder or {}) do
        local c = ns.CATEGORY_BY_KEY[key]
        if c and not seen[key] then
            list[#list + 1] = c
            seen[key] = true
        end
    end
    -- kategorie spoza zapisanej listy (np. nowe) wstawiamy zaraz za ich domyślnym poprzednikiem
    for i, c in ipairs(ns.CATEGORIES) do
        if not seen[c.key] then
            local pos = 1
            local prev = ns.CATEGORIES[i - 1]
            if prev then
                for j, x in ipairs(list) do
                    if x.key == prev.key then pos = j + 1 break end
                end
            end
            table.insert(list, pos, c)
            seen[c.key] = true
        end
    end
    return list
end

-- delta = -1 (w górę) albo +1 (w dół)
function ns.MoveCategory(key, delta)
    local keys = {}
    for i, c in ipairs(ns.OrderedCategories()) do keys[i] = c.key end
    for i, k in ipairs(keys) do
        if k == key then
            local j = i + delta
            if j < 1 or j > #keys then return end
            keys[i], keys[j] = keys[j], keys[i]
            PopokiBagDB.catOrder = keys
            return
        end
    end
end

-- Enum.ItemClass
local CONSUMABLE, CONTAINER, WEAPON, GEM, ARMOR, REAGENT, PROJECTILE, TRADEGOODS, RECIPE, QUIVER, QUESTITEM, KEY, MISC =
    0, 1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 15
local WEAPON_FISHING_POLE = 20

---------------------------------------------------------------------------
-- Kategorie profesji: każda profesja główna postaci dostaje swoją kategorię z materiałami.
-- Pary zbieracz + rzemieślnik z tymi samymi materiałami łączymy w jedną kategorię nazwaną
-- od zbieracza (Skinning + Leatherworking = "Skinning" ze skórami i materiałami do LW).
-- Podklasy Trade Goods jak w grze (Light Leather = 7/6, Copper Ore = 7/7, sprawdzone).
---------------------------------------------------------------------------
local function Set(...)
    local t = {}
    for _, list in ipairs({ ... }) do for _, id in ipairs(list) do t[id] = true end end
    return t
end
local THREADS = { 2320, 2321, 4291, 8343, 14341 }                          -- Coarse ... Rune Thread
local DYES = { 2324, 2604, 2605, 2325, 4340, 4341, 4342, 10290 }          -- Bleach i barwniki
local SALTS = { 4289, 8150, 15409 }                                        -- Salt, Deeprock Salt
local ELEMENTALS = { 7070, 7067, 7068, 7069 }                              -- Elemental Water/Earth/Fire/Air
local VIALS = { 3371, 3372, 8925, 18256 }                                  -- Empty ... Imbued Vial

-- podklasy Trade Goods: 1 Parts, 2 Explosives, 3 Devices, 5 Cloth, 6 Leather, 7 Metal & Stone,
-- 9 Herb, 12 Enchanting
local PROF_MATS = {
    Skinning       = { color = { 0.80, 0.55, 0.35 }, subclasses = { [6] = true } },
    Leatherworking = { color = { 0.75, 0.55, 0.30 }, subclasses = { [6] = true }, ids = Set(THREADS, DYES, SALTS, ELEMENTALS) },
    Mining         = { color = { 0.70, 0.70, 0.78 }, subclasses = { [7] = true } },
    Blacksmithing  = { color = { 0.65, 0.65, 0.72 }, subclasses = { [7] = true } },
    Engineering    = { color = { 0.95, 0.75, 0.35 }, subclasses = { [1] = true, [2] = true, [3] = true, [7] = true } },
    Herbalism      = { color = { 0.45, 0.80, 0.35 }, subclasses = { [9] = true } },
    Alchemy        = { color = { 0.55, 0.85, 0.75 }, subclasses = { [9] = true }, ids = Set(VIALS) },
    Tailoring      = { color = { 0.85, 0.70, 0.90 }, subclasses = { [5] = true }, ids = Set(THREADS, DYES) },
    Enchanting     = { color = { 0.70, 0.55, 1.00 }, subclasses = { [12] = true } },
}
-- zbieracz -> rzemieślnicy, z którymi się łączy
local PAIRS = {
    Skinning = { "Leatherworking" },
    Mining = { "Blacksmithing", "Engineering" },
    Herbalism = { "Alchemy" },
}
local GATHERER_OF = {}
for g, crafts in pairs(PAIRS) do for _, c in ipairs(crafts) do GATHERER_OF[c] = g end end

local function Merge(into, def)
    for k in pairs(def.subclasses or {}) do into.subclasses[k] = true end
    for k in pairs(def.ids or {}) do into.ids[k] = true end
end

local categoriesSig
-- Przebudowuje listę kategorii, gdy zmienią się profesje główne postaci
function ns.EnsureCategories()
    local primaries = ns.MyPrimaryProfessions and ns.MyPrimaryProfessions() or {}
    local sig = table.concat(primaries, ",")
    if sig == categoriesSig then return end
    categoriesSig = sig

    local has = {}
    for _, p in ipairs(primaries) do has[p] = true end
    local profCats = {}
    for _, p in ipairs(primaries) do
        local def = PROF_MATS[p]
        -- rzemieślnik, którego zbieracz też jest wśród profesji, siedzi w kategorii zbieracza
        if def and not (GATHERER_OF[p] and has[GATHERER_OF[p]]) then
            local cat = { key = p:lower(), label = p, color = def.color, isProfession = true,
                subclasses = {}, ids = {} }
            Merge(cat, def)
            for _, craft in ipairs(PAIRS[p] or {}) do
                if has[craft] then Merge(cat, PROF_MATS[craft]) end
            end
            profCats[#profCats + 1] = cat
        end
    end

    wipe(ns.CATEGORIES)
    for _, c in ipairs(BASE_BEFORE) do table.insert(ns.CATEGORIES, c) end
    for _, c in ipairs(profCats) do table.insert(ns.CATEGORIES, c) end
    for _, c in ipairs(BASE_AFTER) do table.insert(ns.CATEGORIES, c) end
    wipe(ns.CATEGORY_BY_KEY)
    for _, c in ipairs(ns.CATEGORIES) do ns.CATEGORY_BY_KEY[c.key] = c end
    for _, c in ipairs(profCats) do ns.PROTECTED[c.key] = true end
end
ns.EnsureCategories()

-- Kategoria profesji, do której pasuje przedmiot (albo nil)
local function ProfessionCategory(id, classID, subClassID)
    for _, c in ipairs(ns.CATEGORIES) do
        if c.isProfession and (c.ids[id] or (classID == TRADEGOODS and c.subclasses[subClassID])) then
            return c
        end
    end
end

-- narzędzia profesji, które są "bronią"
local TOOLS = {
    [2901] = true,  -- Mining Pick
    [7005] = true,  -- Skinning Knife
    [5956] = true,  -- Blacksmith Hammer
    [6219] = true,  -- Arclight Spanner
    [6256] = true,  -- Fishing Pole
}

-- Rzeczy do obozowania: zawsze Essentials. Lista z Forever wzięta z Ellesmere
-- (EllesmereUIBags_Categories.lua:53), do tego drewno i krzesiwo na ognisko.
local CAMP = {
    [4470] = true,   -- Simple Wood
    [4471] = true,   -- Flint and Tinder
    [279956] = true, [279970] = true, [279990] = true, [279944] = true, [279988] = true,
    [279955] = true, [279976] = true, [279985] = true, [279987] = true, [279950] = true,
    [279949] = true, [279989] = true, [279962] = true, [279964] = true, [279947] = true,
    [279978] = true, -- Camp Tent
    [279941] = true, [279945] = true, [279960] = true, [279948] = true, [279952] = true,
    [279979] = true, -- Camp Chair
    [279969] = true, [279938] = true, [279973] = true, [279943] = true, [279959] = true,
    [279981] = true, -- Basic Campfire Kit
    [279961] = true, -- Journeyman Campfire Kit
    [279957] = true,
    [279974] = true, -- Expert Campfire Kit
    [279982] = true, [279968] = true, [279940] = true, [279951] = true, [279967] = true,
    [279965] = true, [279966] = true,
}

---------------------------------------------------------------------------
-- RestedXP: dopisek "Item used in guide" w tooltipie (sprawdzone w grze).
-- Czytamy go ukrytym tooltipem; wynik zapamiętujemy per przedmiot.
---------------------------------------------------------------------------
local rxpCache = {}

-- czyścimy przy każdym otwarciu okna: RestedXP może dopisać linijkę później niż nasz pierwszy skan
function ns.ResetRestedXPCache() wipe(rxpCache) end
local scanTip

local function RestedXPNote(item)
    local id = item.info.itemID
    if rxpCache[id] ~= nil then return rxpCache[id] or nil end
    scanTip = scanTip or CreateFrame("GameTooltip", "PopokiBagClassifyTip", UIParent, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:SetBagItem(item.bag, item.slot)
    local note = false
    for i = 2, scanTip:NumLines() do
        local fs = _G["PopokiBagClassifyTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t:find("Item used in guide", 1, true) then
            -- "Item used in guide:\n|T...|t24-27 Duskwood/Redridge" -> "24-27 Duskwood/Redridge"
            note = t:gsub("^Item used in guide:%s*", ""):gsub("|T.-|t", ""):gsub("\n", ", ")
            break
        end
    end
    scanTip:Hide()
    -- RestedXP zna quest, do którego jest przedmiot (questItemList). Jeśli ten quest już
    -- oddałaś, przedmiot nie jest questowy (np. Lean Wolf Flank po "Seasoned Wolf Kabobs").
    -- Quest jeszcze niewzięty = przedmiot zebrany na zapas, zostaje w Quest Items.
    if note then
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        local rxp = ace and ace:GetAddon("RXPGuides", true)
        local questID = rxp and rxp.questItemList and rxp.questItemList[id]
        if questID and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then
            note = false
        end
    end
    rxpCache[id] = note
    return note or nil
end

-- Przedmiot z losowym przyrostkiem ("Durable Hat of the Sorcerer"): nazwa z linku różni się od
-- nazwy bazowej. Auctionator na Forever trzyma jedną cenę dla wszystkich wariantów
-- (Source/Utilities/DBKeyFromLink.lua), więc jego cena bywa mocno zaniżona.
local function IsRandomSuffix(item)
    local full = item.link and item.link:match("%[(.-)%]")
    local base = ns.GetItemInfo(item.info.itemID)
    return full and base and full ~= base
end

---------------------------------------------------------------------------
-- Sprzedaż czy aukcja. Bez ceny nigdzie = Misfits.
---------------------------------------------------------------------------
local function PriceDecision(item)
    local vendor = ns.VendorValue(item)
    local ah = ns.AuctionValue(item)
    item.vendorValue, item.auctionValue = vendor, ah
    if ns.AuctionWorthIt(vendor, ah) then
        return "auction", "AH " .. ns.MoneyText(ah) .. " vs vendor " .. ns.MoneyText(vendor)
    end
    if vendor > 0 then
        if ah then
            return "vendor", "AH not worth it (" .. ns.MoneyText(ah) .. " vs " .. ns.MoneyText(vendor) .. ")"
        end
        return "vendor", "No AH price data, vendor " .. ns.MoneyText(vendor)
    end
    if ah then
        return "auction", "No vendor price, AH " .. ns.MoneyText(ah)
    end
    return "misfits", "No vendor or AH price"
end

---------------------------------------------------------------------------
-- Receptury: tooltip ma "Requires First Aid (140)" (sprawdzone w grze) i ewentualnie
-- "Already known". Twoja profesja + za mały poziom = bank, wystarczający = Essentials.
---------------------------------------------------------------------------
local KNOWN = ITEM_SPELL_KNOWN or "Already known"
local recipeTip

local function RecipeDecision(item)
    recipeTip = recipeTip or CreateFrame("GameTooltip", "PopokiBagRecipeTip", UIParent, "GameTooltipTemplate")
    recipeTip:SetOwner(UIParent, "ANCHOR_NONE")
    recipeTip:SetBagItem(item.bag, item.slot)
    local prof, req, known
    for i = 1, recipeTip:NumLines() do
        local fs = _G["PopokiBagRecipeTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then
            if t == KNOWN then known = true end
            local p, n = t:match("^Requires (.+) %((%d+)%)$")
            if p then prof, req = p, tonumber(n) end
        end
    end
    recipeTip:Hide()

    if known then
        local cat, why = PriceDecision(item)
        return cat, "Already known; " .. why
    end
    if not prof then return PriceDecision(item) end
    local rank = ns.SkillRank(prof)
    if not rank then
        local cat, why = PriceDecision(item)
        return cat, "Not your profession (" .. prof .. "); " .. why
    end
    if rank >= req then
        return "useme", "Learn it now: " .. prof .. " " .. rank .. "/" .. req
    end
    return "bank", "Learn later: " .. prof .. " " .. rank .. "/" .. req
end

---------------------------------------------------------------------------
-- Consumable wzmacniający którąś z Twoich profesji (np. Nightcrawlers: "Use: ... increasing
-- Fishing by ..."). Szukamy nazwy profesji w linijkach "Use:" / "Equip:" tooltipa.
---------------------------------------------------------------------------
local boostTip

local function BoostedProfession(item)
    boostTip = boostTip or CreateFrame("GameTooltip", "PopokiBagBoostTip", UIParent, "GameTooltipTemplate")
    boostTip:SetOwner(UIParent, "ANCHOR_NONE")
    boostTip:SetBagItem(item.bag, item.slot)
    local found
    for i = 2, boostTip:NumLines() do
        local fs = _G["PopokiBagBoostTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and (t:find("^Use:") or t:find("^Equip:")) then
            for prof in pairs(ns.MyProfessions()) do
                if t:find(prof, 1, true) then found = prof break end
            end
        end
        if found then break end
    end
    boostTip:Hide()
    return found
end

-- Przedmiot, który się otwiera, choć gra nie oznacza go jako "do otwarcia"
-- (Sealed Expert's Writ: "Use: Tear open the envelope to reveal the writ.", sprawdzone w grze)
local OPEN_WORDS = { "tear open", "use: open", "unwrap", "break the seal", "break open", "crack open" }

local function OpensSomething(item)
    boostTip = boostTip or CreateFrame("GameTooltip", "PopokiBagBoostTip", UIParent, "GameTooltipTemplate")
    boostTip:SetOwner(UIParent, "ANCHOR_NONE")
    boostTip:SetBagItem(item.bag, item.slot)
    local found = false
    for i = 2, boostTip:NumLines() do
        local fs = _G["PopokiBagBoostTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t:find("^Use:") then
            local low = t:lower()
            for _, w in ipairs(OPEN_WORDS) do
                if low:find(w, 1, true) then found = true break end
            end
        end
        if found then break end
    end
    boostTip:Hide()
    return found
end

-- Zamknięty lockbox: tooltip ma linijkę "Locked" (jak w Ellesmere QuickActions.lua:89).
-- Otworzy go tylko rogue, więc nie trafia do "Use me!", tylko na sprzedaż.
local function IsLockedBox(item)
    boostTip = boostTip or CreateFrame("GameTooltip", "PopokiBagBoostTip", UIParent, "GameTooltipTemplate")
    boostTip:SetOwner(UIParent, "ANCHOR_NONE")
    boostTip:SetBagItem(item.bag, item.slot)
    local locked = false
    local word = LOCKED or "Locked"
    for i = 2, boostTip:NumLines() do
        local fs = _G["PopokiBagBoostTipTextLeft" .. i]
        if fs and fs:GetText() == word then locked = true break end
    end
    boostTip:Hide()
    return locked
end

-- Przedmiot tylko dla innych klas: tooltip ma linijkę "Classes: Mage" (ITEM_CLASSES_ALLOWED),
-- a Twojej klasy na niej nie ma. Zwraca listę klas z tooltipa albo nil.
local function OtherClassOnly(item)
    local fmt = ITEM_CLASSES_ALLOWED or "Classes: %s"
    local pattern = "^" .. fmt:gsub("%%s", "(.+)")
    local myClass = UnitClass("player")
    if not myClass then return nil end
    boostTip = boostTip or CreateFrame("GameTooltip", "PopokiBagBoostTip", UIParent, "GameTooltipTemplate")
    boostTip:SetOwner(UIParent, "ANCHOR_NONE")
    boostTip:SetBagItem(item.bag, item.slot)
    local classes
    for i = 2, boostTip:NumLines() do
        local fs = _G["PopokiBagBoostTipTextLeft" .. i]
        local text = fs and fs:GetText()
        classes = text and text:match(pattern)
        if classes then break end
    end
    boostTip:Hide()
    if classes and not classes:find(myClass, 1, true) then return classes end
    return nil
end

-- Torby nigdy nie idą na sprzedaż (łatwo przegapić ważną rzecz):
--   zwykła torba większa od najmniejszej założonej albo wolne miejsce na torbę -> "Use me!" (załóż ją),
--   reszta toreb, kołczany, ładownice i torby profesji -> Essentials.
local function BagSlots(item)
    boostTip = boostTip or CreateFrame("GameTooltip", "PopokiBagBoostTip", UIParent, "GameTooltipTemplate")
    boostTip:SetOwner(UIParent, "ANCHOR_NONE")
    boostTip:SetBagItem(item.bag, item.slot)
    local slots
    for i = 2, boostTip:NumLines() do
        local fs = _G["PopokiBagBoostTipTextLeft" .. i]
        local text = fs and fs:GetText()
        slots = text and tonumber(text:match("^(%d+) Slot"))
        if slots then break end
    end
    boostTip:Hide()
    return slots
end

local function BagDecision(item, classID, subClassID)
    if classID == QUIVER then return "essentials", "Quiver / ammo pouch" end
    if subClassID ~= 0 then return "essentials", "Profession bag" end
    local slots = BagSlots(item)
    local smallest
    for bag = 1, 4 do   -- zwykłe miejsca na torby (0 = plecak, 5 = torba na reagenty)
        local n = C_Container.GetContainerNumSlots(bag) or 0
        if not smallest or n < smallest then smallest = n end
    end
    if slots and smallest and slots > smallest then
        return "useme", smallest == 0 and ("Bag (" .. slots .. " slots) - you have a free bag slot, equip it")
            or ("Bigger bag (" .. slots .. " vs " .. smallest .. " slots) - equip it")
    end
    return "essentials", slots and ("Spare bag (" .. slots .. " slots)") or "Bag"
end

---------------------------------------------------------------------------
-- Reguły; pierwsza pasująca wygrywa. Zwraca kategoria, powód.
---------------------------------------------------------------------------
-- Czy używasz tej amunicji: tylko rodzaj pasujący do założonej broni - łuk/kusza = strzały,
-- strzelba = kule (każda klasa, także hunter: kule przy łuku idą na sprzedaż).
-- Hunter bez żadnej broni na amunicję (np. w trakcie zmiany broni) zatrzymuje każdą.
-- Broń dystansowa może być w slocie ranged (18) albo w ręce (16).
local AMMO_FOR_WEAPON = { [2] = 2, [18] = 2, [3] = 3 }   -- podklasa broni -> podklasa amunicji
local function UsesAmmo(ammoSubClass)
    local hasAmmoWeapon = false
    for _, slot in ipairs({ 18, 16 }) do
        local id = GetInventoryItemID("player", slot)
        if id then
            local _, _, _, _, _, wClass, wSub = C_Item.GetItemInfoInstant(id)
            local needs = wClass == WEAPON and AMMO_FOR_WEAPON[wSub]
            if needs then
                hasAmmoWeapon = true
                if needs == ammoSubClass then return true end
            end
        end
    end
    local _, class = UnitClass("player")
    return class == "HUNTER" and not hasAmmoWeapon
end

local function Decide(item)
    local info = item.info
    local id = info.itemID

    if item.isStarter then return "useme", "Starts a quest" end
    if item.isQuest then return "quest", "Quest item" end
    -- Skrzynki z Forever na bundle ("Crate: ...", "Waylaid Crate: ...") domyślnie na sprzedaż
    -- (vendor albo AH wg ceny), także gdy dają się otworzyć
    if (info.itemName or ""):find("Crate:", 1, true) then
        local cat, why = PriceDecision(item)
        return cat, "Crate; " .. why
    end
    if info.hasLoot then
        if IsLockedBox(item) then
            local cat, why = PriceDecision(item)
            return cat, "Locked box (needs Lockpicking); " .. why
        end
        return "useme", "Open me"
    end
    if CAMP[id] then return "essentials", "Camp item" end

    local name, _, _, _, _, _, _, _, _, _, _, classID, subClassID = ns.GetItemInfo(id)
    if not name then return "misfits", "Loading item info..." end

    -- amunicja, której używasz (hunter albo pasująca broń dystansowa): nie pokazujemy jej
    -- w kategoriach, jej suma jest w stopce okna. Cudza amunicja (inna klasa, brak łuku/strzelby)
    -- idzie na sprzedaż jak każdy inny przedmiot.
    if classID == PROJECTILE then
        if UsesAmmo(subClassID) then return "ammo", "Ammo" end
        local cat, why = PriceDecision(item)
        return cat, "Ammo you don't use; " .. why
    end

    local rxp = RestedXPNote(item)
    if rxp then return "quest", "RestedXP guide: " .. rxp end

    if info.quality == 0 then
        -- szary bez ceny (np. Field Marshal's Log do czytania): vendor go nie kupi
        local sell = select(11, ns.GetItemInfo(id))
        if info.hasNoValue or not sell or sell == 0 then
            return "misfits", "Grey item, no sell price"
        end
        return "vendor", "Grey item"
    end

    -- tylko dla innej klasy (np. scrolle maga, gdy nie grasz magiem): na sprzedaż
    local forClass = OtherClassOnly(item)
    if forClass then
        local cat, why = PriceDecision(item)
        return cat, "For " .. forClass .. " only; " .. why
    end

    if classID == QUESTITEM then return "quest", "Quest item" end
    if classID == KEY then return "essentials", "Key" end
    if classID == REAGENT then return "essentials", "Class reagent" end
    if (classID == CONSUMABLE or classID == MISC) and OpensSomething(item) then return "useme", "Open me" end
    if classID == MISC and info.isBound then return "essentials", "Bound utility item" end
    if TOOLS[id] or (classID == WEAPON and subClassID == WEAPON_FISHING_POLE) then
        return "essentials", "Profession tool"
    end
    if classID == CONSUMABLE then
        local prof = BoostedProfession(item)
        if prof then return "bank", "Boosts " .. prof end
        return "consumables", "Consumable"
    end

    local prof = ProfessionCategory(id, classID, subClassID)
    if prof then return prof.key, prof.label .. " material" end
    -- Trade Goods z efektem "Use:" (oleje na broń, np. Lesser Mana Oil) to w praktyce consumables
    if classID == TRADEGOODS then
        local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        if getSpell and getSpell(id) then return "consumables", "Consumable (weapon oil / usable trade good)" end
    end
    if classID == TRADEGOODS or classID == GEM then return PriceDecision(item) end
    if classID == RECIPE then return RecipeDecision(item) end
    if classID == CONTAINER or classID == QUIVER then return BagDecision(item, classID, subClassID) end

    if classID == WEAPON or classID == ARMOR then
        if info.isBound then
            if item.sellPrice > 0 then return "vendor", "Soulbound" end
            return "misfits", "Soulbound, no vendor value"
        end
        if (info.quality or 1) >= 2 and IsRandomSuffix(item) then
            item.vendorValue = ns.VendorValue(item)
            -- cena tego wariantu zapamiętana z zakładki Selling Auctionatora (Auction.lua)
            local unit = ns.SuffixPrice and ns.SuffixPrice(item.link)
            if unit then
                local vendor, ah = item.vendorValue, unit * (info.stackCount or 1)
                item.auctionValue, item.suffixPriced = ah, true
                if ns.AuctionWorthIt(vendor, ah) then
                    return "auction", "Auctionator price for this variant: " .. ns.MoneyText(ah) .. " vs vendor " .. ns.MoneyText(vendor)
                end
                if vendor > 0 then
                    return "vendor", "AH not worth it for this variant (" .. ns.MoneyText(ah) .. " vs " .. ns.MoneyText(vendor) .. ")"
                end
            end
            item.randomSuffix = true
            return "auction", "Random-suffix item: real price only in Auctionator's Selling tab"
        end
        return PriceDecision(item)
    end

    if info.isBound then
        if item.sellPrice > 0 then return "vendor", "Soulbound" end
        return "misfits", "Soulbound, no vendor value"
    end
    return PriceDecision(item)
end

function ns.Classify(item)
    ns.EnsureCategories()
    local _, _, _, _, _, _, _, _, equipLoc, _, sellPrice, classID, subClassID = ns.GetItemInfo(item.info.itemID)
    item.sellPrice = sellPrice or 0
    item.classID = classID
    item.randomSuffix = nil
    item.suffixPriced, item.auctionValue = nil, nil
    item.armorFit = ns.ArmorFit(classID, subClassID, equipLoc)
    item.armorType = item.armorFit and ns.ARMOR_NAMES[subClassID]
    local ok, cat, reason = pcall(Decide, item)
    if not ok then
        cat, reason = "misfits", "Popoki Bag error: " .. tostring(cat)
    end
    item.autoCat, item.autoReason = cat, reason

    -- ręczne przypisanie (przeciągnięcie) wygrywa z regułami
    local manual = PopokiBagCharDB.assign[item.info.itemID]
    local auto = ns.CATEGORY_BY_KEY[item.autoCat]
    if manual and auto and ns.CATEGORY_BY_KEY[manual] then
        cat, reason = manual, "Moved here by you (auto: " .. auto.label .. ")"
    end
    item.cat, item.reason = cat, reason
    if not item.vendorValue then item.vendorValue = ns.VendorValue(item) end

    -- Kategorie profesji: osobna decyzja AH czy vendor dla zakładek profesji w oknach sprzedaży
    -- (ten sam próg co reszta: wartość całego stacka, 150% + minimalny zysk)
    item.questNeed = ns.QuestNeed(item)
    item.profSell = nil
    local catDef = ns.CATEGORY_BY_KEY[cat]
    if catDef and catDef.isProfession then
        local vendor = item.vendorValue or 0
        local ah = ns.AuctionValue(item)
        if ns.AuctionWorthIt(vendor, ah) or (vendor == 0 and ah) then
            item.profSell = "auction"
        elseif vendor > 0 then
            item.profSell = "vendor"
        end
    end
end

-- Przypisanie rodzaju przedmiotu do kategorii; powrót do kategorii z reguł kasuje przypisanie
function ns.AssignItem(itemID, catKey, autoCat)
    if catKey == autoCat then
        PopokiBagCharDB.assign[itemID] = nil
    else
        PopokiBagCharDB.assign[itemID] = catKey
    end
end

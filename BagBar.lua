local ADDON, ns = ...

-- Przycisk w nagłówku otwiera pasek z założonymi torbami (jak "Show Bags" w Ellesmere).
-- Przeciągnięcie nowej torby na slot zakłada ją / zamienia; przeciągnięcie założonej zdejmuje.
-- Wzór: EUI_Bags_Slots.lua:299 i EUI_Bags_Refresh.lua:1127.

local SIZE = ns.SLOT_SIZE
local GAP = ns.SLOT_GAP
local NUM = ns.LAST_BAG - ns.FIRST_BAG + 1

local frame = ns.frame

local win = CreateFrame("Frame", nil, frame, "BackdropTemplate")
win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
win:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
win:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
win:SetSize(NUM * (SIZE + GAP) - GAP + 20, SIZE + 20)
ns.SkinWindow(win, { small = true })   -- motyw (Theme.lua)
win:Hide()

local slots = {}

local function InvID(bag)
    return C_Container.ContainerIDToInventoryID(bag)
end

local function TrySwapBag(self)
    if InCombatLockdown() or not CursorHasItem() then return end
    local bag = self:GetID()
    if bag == 0 then return end   -- plecaka nie da się wymienić
    PutItemInBag(InvID(bag))
end

local function CreateBagSlot(i)
    local b = CreateFrame("Button", nil, win, "BackdropTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    b:SetScript("OnReceiveDrag", TrySwapBag)
    b:SetScript("OnClick", TrySwapBag)
    b:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        local bag = self:GetID()
        if bag == 0 then return end
        PickupBagFromSlot(InvID(bag))
    end)
    b:SetScript("OnEnter", function(self)
        local bag = self:GetID()
        local name
        if bag == 0 then
            name = "Backpack"
        else
            local link = GetInventoryItemLink("player", InvID(bag))
            name = link and ns.GetItemInfo(link) or "Empty bag slot"
        end
        local total = C_Container.GetContainerNumSlots(bag) or 0
        local free = C_Container.GetContainerNumFreeSlots(bag) or 0
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(name)
        if total > 0 then
            GameTooltip:AddLine((total - free) .. " / " .. total .. " slots used", 0.8, 0.8, 0.8)
        end
        if bag ~= 0 then
            GameTooltip:AddLine("Drop a bag here to equip or swap it", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[i] = b
    return b
end

local function UpdateBagSlot(bag)
    local i = bag - ns.FIRST_BAG + 1
    local b = slots[i] or CreateBagSlot(i)
    b:SetID(bag)
    -- kolejność jak pasek Blizzarda: plecak po prawej
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 10 + (NUM - i) * (SIZE + GAP), -10)
    b:Show()

    local total = C_Container.GetContainerNumSlots(bag) or 0
    local free = C_Container.GetContainerNumFreeSlots(bag) or 0
    local inv = bag ~= 0 and InvID(bag) or nil
    if bag == 0 then
        b.icon:SetTexture(133633)
    else
        local tex = inv and GetInventoryItemTexture("player", inv)
        b.icon:SetTexture(tex or "Interface/PaperDoll/UI-PaperDoll-Slot-Bag")
    end
    if total > 0 then b.count:SetText(free) else b.count:SetText("") end
    local quality = inv and GetInventoryItemQuality("player", inv) or 0
    if quality > 1 then
        local r, g, bl = C_Item.GetItemQualityColor(quality)
        b:SetBackdropBorderColor(r, g, bl, 1)
    else
        b:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    end
end

-- każda torba osobno: błąd przy jednej nie chowa pozostałych
function ns.RefreshBagBar()
    if not win:IsShown() then return end
    for bag = ns.FIRST_BAG, ns.LAST_BAG do
        ns.SafeCall("bag bar (bag " .. bag .. ")", UpdateBagSlot, bag)
    end
end

-- przycisk w nagłówku, na lewo od wyszukiwarki
local btn = ns.HeaderButton(frame, "Bags",
    function() return win:IsShown() and "Hide equipped bags" or "Show equipped bags" end,
    "Bags you have equipped; drag a new bag onto a slot there to equip it",
    function()
        win:SetShown(not win:IsShown())
        ns.RefreshBagBar()
    end)
btn:SetPoint("RIGHT", ns.search, "LEFT", -10, -1)   -- ramka wyszukiwarki Blizzarda jest wizualnie niżej niż jej środek
ns.bagBarButton = btn

win:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, 6)

for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "PLAYER_EQUIPMENT_CHANGED" }) do
    ns.On(e, function()
        ns.RefreshBagBar()
        ns.RequestRefresh()
    end)
end

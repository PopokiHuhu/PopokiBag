local ADDON, ns = ...

-- Przejęcie plecaka: klawisz B, kliknięcia w torby i auto-otwieranie (vendor, poczta, bank)
-- pokazują Popoki Bag zamiast toreb Blizzarda. Wzorowane na EllesmereUIBags (EUI_Bags_Start.lua).
-- Gdy EllesmereUIBags jest włączony, nic nie przejmujemy: PopokiBag otwiera tylko /popoki.

local function EllesmereBagsLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return isLoaded and isLoaded("EllesmereUIBags")
end

-- Torby Blizzarda z plecakiem (0-4) chowamy, przenosząc je pod ukrytą ramkę
-- (nie nadpisujemy Show/Hide na ramkach Blizzarda, bo to psuje bezpieczeństwo UI).
-- Bank, torby bankowe i keyring zostają zwykłe.
local hidden = CreateFrame("Frame")
hidden:Hide()
hidden:SetAllPoints(UIParent)

local function IsBackpackBag(id)
    return id and id >= ns.FIRST_BAG and id <= ns.LAST_BAG
end

local function ContainerBagID(f)
    if f.GetBagID then
        local ok, id = pcall(f.GetBagID, f)
        if ok and id then return id end
    end
    return f:GetID()
end

local originalParent = {}
local function FixContainer(f)
    if not originalParent[f] then originalParent[f] = f:GetParent() end
    if IsBackpackBag(ContainerBagID(f)) then
        f:SetParent(hidden)
    elseif f:GetParent() == hidden then
        f:SetParent(originalParent[f] or UIParent)
    end
end

local function HookContainers()
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then
            f:HookScript("OnShow", FixContainer)
            if f:IsShown() then FixContainer(f) end
        end
    end
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hidden) end
end

local lastToggle, visibleBefore = 0, false
local function SmartToggle()
    -- klawisz potrafi wywołać dwie funkcje w tej samej klatce; liczymy to jako jedno kliknięcie
    if GetTime() == lastToggle then return end
    lastToggle = GetTime()
    visibleBefore = ns.frame:IsShown()
    ns.Toggle()
end

local function Takeover()
    ns.takeover = true
    ToggleAllBags = SmartToggle
    hooksecurefunc("ToggleBackpack", SmartToggle)
    hooksecurefunc("ToggleBag", function(id)
        if IsBackpackBag(id) then SmartToggle() end
    end)

    -- okno, które samo otworzyło plecak (vendor, poczta, bank...), zamyka go razem ze sobą
    local opener
    hooksecurefunc("OpenAllBags", function(f)
        local wasVisible = ns.frame:IsShown()
        if lastToggle == GetTime() then wasVisible = visibleBefore end
        if not wasVisible then
            ns.Open()
            opener = f
        end
    end)
    hooksecurefunc("CloseAllBags", function(f)
        if f and f == opener then
            opener = nil
            ns.Close()
        end
    end)
    ns.frame:HookScript("OnHide", function() opener = nil end)

    HookContainers()
end

ns.On("PLAYER_LOGIN", function()
    if EllesmereBagsLoaded() then
        ns.Print("EllesmereUIBags is enabled, so B opens the old bags. Use /popoki to open Popoki Bag.")
        return
    end
    Takeover()
end)

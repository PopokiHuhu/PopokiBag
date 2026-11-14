local ADDON, ns = ...

-- Okno ustawień: próg AH vs vendor, automatyczne okna przy NPC, wygląd.
-- Otwiera je zębatka w nagłówku plecaka albo /popoki settings. Zmiany działają od razu.
-- Przełączniki: nil = włączone (domyślnie), false = wyłączone.

local DIM_TEXT = { 0.6, 0.6, 0.6 }
local ACCENT = { 0.25, 0.8, 0.7 }
local WIDTH = 480

local function Flat(f, bg, edge)
    f:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(edge))
end

function ns.Setting(key)
    return PopokiBagDB[key] ~= false
end

local win = CreateFrame("Frame", "PopokiBagSettingsFrame", UIParent, "BackdropTemplate")
win:SetWidth(WIDTH)
win:SetFrameStrata("DIALOG")
win:SetClampedToScreen(true)
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
Flat(win, { 0.06, 0.06, 0.07, 0.97 }, { 0.2, 0.2, 0.22, 1 })
win:Hide()
table.insert(UISpecialFrames, "PopokiBagSettingsFrame")   -- ESC zamyka

local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetTextColor(1, 1, 1)
title:SetText("Popoki Bag settings")

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local y = -44
local controls = {}   -- odświeżane przy otwarciu okna
local headerParts, checks = {}, {}   -- do przekolorowania przy zmianie motywu

local function Header(text)
    local fs = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetTextColor(unpack(DIM_TEXT))
    fs:SetText(text)
    local line = win:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    line:SetColorTexture(1, 1, 1, 0.08)
    headerParts[#headerParts + 1] = { fs = fs, line = line }
    y = y - 22
end

-- płaski przełącznik z opisem
-- optIn = przełącznik domyślnie wyłączony (PopokiBagDB[key] == true); onChange po kliknięciu
local function Toggle(key, text, optIn, onChange)
    local function isOn()
        if optIn then return PopokiBagDB[key] == true end
        return ns.Setting(key)
    end
    local b = CreateFrame("Button", nil, win, "BackdropTemplate")
    b:SetSize(16, 16)
    b:SetPoint("TOPLEFT", 16, y)
    Flat(b, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0.3 })
    b.check = b:CreateTexture(nil, "ARTWORK")
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetColorTexture(unpack(ACCENT))
    checks[#checks + 1] = b.check
    local label = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", b, "RIGHT", 8, 0)
    label:SetText(text)
    b:SetScript("OnClick", function(self)
        if optIn then
            PopokiBagDB[key] = (not isOn()) or nil
        elseif ns.Setting(key) then
            PopokiBagDB[key] = false
        else
            PopokiBagDB[key] = nil
        end
        self.check:SetShown(isOn())
        if onChange then onChange() end
        ns.RequestRefresh()
    end)
    controls[#controls + 1] = function() b.check:SetShown(isOn()) end
    y = y - 24
end

-- liczba w płaskim polu: tekst przed, pole, tekst po
local function Number(before, after, get, set)
    local pre = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pre:SetPoint("TOPLEFT", 16, y - 3)
    pre:SetText(before)
    local box = CreateFrame("EditBox", nil, win, "BackdropTemplate")
    box:SetSize(46, 20)
    box:SetPoint("LEFT", pre, "RIGHT", 8, 0)
    Flat(box, { 0, 0, 0, 0.4 }, { 1, 1, 1, 0.3 })
    box:SetFontObject("GameFontHighlight")
    box:SetJustifyH("CENTER")
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    local post = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    post:SetPoint("LEFT", box, "RIGHT", 8, 0)
    post:SetText(after)
    local function save(self)
        local n = tonumber(self:GetText())
        if n then set(n) end
        self:SetText(tostring(get()))
        self:ClearFocus()
        ns.RequestRefresh()
    end
    box:SetScript("OnEnterPressed", save)
    box:SetScript("OnEditFocusLost", save)
    box:SetScript("OnEscapePressed", function(self) self:SetText(tostring(get())) self:ClearFocus() end)
    controls[#controls + 1] = function() box:SetText(tostring(get())) end
    y = y - 28
end

Header("Auction vs vendor")
Number("Auction when AH price is at least", "% of vendor price",
    function() return math.floor((PopokiBagDB.ahMinRatio or 1.5) * 100 + 0.5) end,
    function(n) PopokiBagDB.ahMinRatio = math.max(100, n) / 100 end)
Number("and AH pays at least", "silver more",
    function() return math.floor((PopokiBagDB.ahMinProfit or 200) / 100) end,
    function(n) PopokiBagDB.ahMinProfit = n * 100 end)
y = y - 6

Header("Open automatically")
Toggle("autoSell", "Sell window at merchants")
Toggle("autoAuction", "Post window at the auction house")
Toggle("autoBank", "Bank window at the bank")
y = y - 6

Header("Full bags")
Toggle("autoStack", "Merge partial stacks automatically")
Toggle("roomPopup", "\"Make room\" window when bags are full")
y = y - 6

Header("Look")

-- motyw okna plecaka: przyciski-wybór obok siebie, zaznaczony ma kolor akcentu
do
    local label = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 16, y - 3)
    label:SetText("Theme")
    local prev
    local choices = {}
    for _, key in ipairs(ns.THEME_ORDER) do
        local b = CreateFrame("Button", nil, win, "BackdropTemplate")
        b:SetHeight(20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT", label, "RIGHT", 10, 0) end
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(ns.THEMES[key].label)
        b:SetWidth(b.text:GetStringWidth() + 20)
        b.key = key
        b:SetScript("OnClick", function(self)
            ns.SetTheme(self.key)
            for _, refresh in ipairs(controls) do refresh() end
        end)
        choices[#choices + 1] = b
        prev = b
    end
    controls[#controls + 1] = function()
        for _, b in ipairs(choices) do
            local on = b.key == ns.ThemeKey()
            if on then
                Flat(b, { ACCENT[1], ACCENT[2], ACCENT[3], 0.2 }, { ACCENT[1], ACCENT[2], ACCENT[3], 1 })
                b.text:SetTextColor(1, 1, 1)
            else
                Flat(b, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0.25 })
                b.text:SetTextColor(unpack(DIM_TEXT))
            end
        end
    end
    y = y - 28
end

Toggle("compact", "Compact mode (icons instead of the left panel and buttons)", true, function() ns.ApplyTheme() end)
Toggle("sidebarCategories", "Categories in the left panel")
Toggle("categoryColors", "Colored category names")
Toggle("newGlow", "Glow on new items")
Toggle("armorColors", "Color armor that isn't your type")

win:SetHeight(-y + 14)

-- motyw (Theme.lua): tło, tytuł, akcent przełączników i nagłówków
ns.SkinWindow(win, {
    title = title, titleX = 16, close = close, side = true,
    onApply = function()
        local th = ns.Theme()
        for i = 1, 3 do
            ACCENT[i] = th.accent[i]
            DIM_TEXT[i] = th.dim[i]
        end
        for _, h in ipairs(headerParts) do
            h.fs:SetTextColor(unpack(DIM_TEXT))
            h.line:SetColorTexture(unpack(th.line))
        end
        for _, c in ipairs(checks) do c:SetColorTexture(unpack(ACCENT)) end
        for _, refresh in ipairs(controls) do refresh() end
    end,
})

function ns.ToggleSettings()
    if win:IsShown() then
        win:Hide()
        return
    end
    for _, refresh in ipairs(controls) do refresh() end
    ns.PlaceBeside(win)   -- na lewo od plecaka i innych otwartych okien
    win:Show()
end

ns.commands.settings = ns.ToggleSettings

-- zębatka ustawień obok X w prawym górnym rogu (ikona Blizzarda; pierwsza, którą klient ma)
local gear = CreateFrame("Button", nil, ns.frame)
gear:SetSize(16, 16)
gear:SetPoint("RIGHT", ns.closeButton, "LEFT", -6, 0)
gear:SetFrameLevel(ns.closeButton:GetFrameLevel())
gear.icon = gear:CreateTexture(nil, "ARTWORK")
gear.icon:SetAllPoints()
local GEAR_ATLASES = { "QuestLog-icon-setting", "GM-icon-settings", "mechagon-projects" }
local gearAtlas
for _, atlas in ipairs(GEAR_ATLASES) do
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        gearAtlas = atlas
        break
    end
end
if gearAtlas then gear.icon:SetAtlas(gearAtlas) else gear.icon:SetTexture("Interface/Buttons/UI-OptionsButton") end
gear.icon:SetVertexColor(0.85, 0.85, 0.85)
gear:SetScript("OnEnter", function(self)
    self.icon:SetVertexColor(1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Settings")
    GameTooltip:AddLine("Tip: right-click the bag background for Sort, Clean and Pack.", 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
end)
gear:SetScript("OnLeave", function(self)
    self.icon:SetVertexColor(0.85, 0.85, 0.85)
    GameTooltip:Hide()
end)
gear:SetScript("OnClick", function() GameTooltip:Hide() ns.ToggleSettings() end)

-- przyciski z napisem w rzędzie wyszukiwarki, od prawej: [Bags] [Make room]
local room = ns.HeaderButton(ns.frame, "Make room", "Make room",
    "Cheapest things in your bags, to destroy when they're full",
    function() ns.ToggleRoom() end,
    { icon = "Interface/Icons/Spell_Fire_Fire" })   -- ogień: niszczenie przedmiotów
room:SetPoint("RIGHT", ns.bagBarButton, "LEFT", -8, 0)

-- Prawy klik w tło plecaka: krótkie menu bez nagłówka (Sort, Clean, Pack, kreska, Settings).
-- Ponowny prawy klik, gdy menu jest otwarte, tylko je zamyka.
local bagMenu, menuClosedAt = nil, 0
local function OpenBagMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    bagMenu = MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton("Sort", function() ns.CleanupOrder() end)     -- kolejność w kategoriach wg rodzaju
        root:CreateButton("Clean", function() ns.ToggleRoom() end)      -- Make room
        root:CreateButton("Pack", function() ns.CompactBags() end)      -- opróżnij ostatnią torbę
        root:CreateDivider()
        root:CreateButton("Settings", function() ns.ToggleSettings() end)
    end)
    if bagMenu and not bagMenu.popokiHooked then
        bagMenu.popokiHooked = true
        bagMenu:HookScript("OnHide", function() menuClosedAt = GetTime() end)
    end
end
ns.frame:HookScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" or not self:IsMouseOver() then return end
    if bagMenu and bagMenu:IsShown() then
        bagMenu:Hide()
        return
    end
    -- ten sam klik mógł już zamknąć menu (gra zamyka je przy kliknięciu obok) - nie otwieraj od nowa
    if GetTime() - menuClosedAt < 0.3 then return end
    OpenBagMenu(self)
end)ns.roomButton = room

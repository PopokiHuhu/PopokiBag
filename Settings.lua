local ADDON, ns = ...

-- Okno ustawień: próg AH vs vendor, automatyczne okna przy NPC, wygląd.
-- Otwiera je zębatka w nagłówku plecaka albo /popoki settings. Zmiany działają od razu.
-- Przełączniki: nil = włączone (domyślnie), false = wyłączone.

local DIM_TEXT = { 0.6, 0.6, 0.6 }
local ACCENT = { 0.25, 0.8, 0.7 }
local WIDTH = 420

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

local function Header(text)
    local fs = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 14, y)
    fs:SetTextColor(unpack(DIM_TEXT))
    fs:SetText(text)
    local line = win:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", win, "RIGHT", -14, 0)
    line:SetColorTexture(1, 1, 1, 0.08)
    y = y - 22
end

-- płaski przełącznik z opisem
local function Toggle(key, text)
    local b = CreateFrame("Button", nil, win, "BackdropTemplate")
    b:SetSize(16, 16)
    b:SetPoint("TOPLEFT", 16, y)
    Flat(b, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0.3 })
    b.check = b:CreateTexture(nil, "ARTWORK")
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetColorTexture(unpack(ACCENT))
    local label = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", b, "RIGHT", 8, 0)
    label:SetText(text)
    b:SetScript("OnClick", function(self)
        if ns.Setting(key) then PopokiBagDB[key] = false else PopokiBagDB[key] = nil end
        self.check:SetShown(ns.Setting(key))
        ns.RequestRefresh()
    end)
    controls[#controls + 1] = function() b.check:SetShown(ns.Setting(key)) end
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

Header("Look")
Toggle("newGlow", "Glow on new items")
Toggle("armorColors", "Color armor that isn't your type")

win:SetHeight(-y + 14)

function ns.ToggleSettings()
    if win:IsShown() then
        win:Hide()
        return
    end
    for _, refresh in ipairs(controls) do refresh() end
    win:ClearAllPoints()
    if ns.frame and ns.frame:IsShown() then
        win:SetPoint("TOPRIGHT", ns.frame, "TOPLEFT", -12, 0)
    else
        win:SetPoint("CENTER")
    end
    win:Show()
end

ns.commands.settings = ns.ToggleSettings

-- zębatka w nagłówku plecaka, na lewo od ikony toreb
local gear = CreateFrame("Button", nil, ns.frame)
gear:SetSize(18, 18)
gear:SetPoint("RIGHT", ns.bagBarButton, "LEFT", -8, 0)
gear.icon = gear:CreateTexture(nil, "ARTWORK")
gear.icon:SetAllPoints()
gear.icon:SetTexture("Interface/Icons/INV_Misc_Gear_01")
gear.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
gear.icon:SetAlpha(0.85)
gear:SetScript("OnEnter", function(self)
    self.icon:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Settings")
    GameTooltip:Show()
end)
gear:SetScript("OnLeave", function(self)
    self.icon:SetAlpha(0.85)
    GameTooltip:Hide()
end)
gear:SetScript("OnClick", function() GameTooltip:Hide() ns.ToggleSettings() end)

local ADDON, ns = ...

-- Motywy wszystkich okien addonu (plecak, okna przy NPC, ustawienia, pasek toreb).
--   dark     - nasz płaski, ciemny styl jak w EllesmereUI
--   blizzard - ramka okien Blizzarda (nine-slice "ButtonFrameTemplateNoPortrait", na Forever
--              brązowa) na ciemnym "rock", złote nagłówki, czerwono-złote przyciski.
--              Wzór: OpenMap (Look:Window) i EllesmereUIBags (UI-Background-Rock).
-- PopokiBagDB.theme: nil = dark. Zmiana działa od razu (ns.SetTheme).

ns.THEMES = {
    dark = {
        label = "Dark",
        accent = { 0.25, 0.8, 0.7 },
        dim = { 0.6, 0.6, 0.6 },
        title = { 1, 1, 1 },
        header = { 0.85, 0.85, 0.85 },
        line = { 1, 1, 1, 0.08 },
        plusText = { 0.5, 0.5, 0.5 },
    },
    blizzard = {
        label = "Blizzard",
        accent = { 1, 0.82, 0 },
        dim = { 0.72, 0.66, 0.54 },
        title = { 1, 0.82, 0 },
        header = { 1, 0.82, 0 },
        line = { 1, 0.82, 0, 0.22 },
        plusText = { 0.85, 0.72, 0.4 },
    },
}
ns.THEME_ORDER = { "dark", "blizzard" }

-- Compact mode (ustawienie, działa z każdym motywem): lewy pasek to wąska kolumna ikon,
-- przyciski w nagłówku to ikony. PopokiBagDB.compact == true.
function ns.Compact()
    return PopokiBagDB and PopokiBagDB.compact == true or false
end

-- kolorowe nazwy kategorii (ustawienie)
function ns.CategoryColors()
    return ns.Setting("categoryColors")
end

function ns.ThemeKey()
    local k = PopokiBagDB and PopokiBagDB.theme
    return ns.THEMES[k] and k or "dark"
end

function ns.Theme()
    return ns.THEMES[ns.ThemeKey()]
end

local hooks = {}
function ns.OnThemeChange(fn)
    hooks[#hooks + 1] = fn
end

function ns.ApplyTheme()
    for _, fn in ipairs(hooks) do ns.SafeCall("Theme", fn) end
end

function ns.SetTheme(key)
    PopokiBagDB.theme = (key ~= "dark") and key or nil
    ns.ApplyTheme()
    ns.RequestRefresh()
end

---------------------------------------------------------------------------
-- Przyciski z napisem (Sell w nagłówku sekcji, Make room) i sloty "+"
-- Tło ustawiamy tylko przy zmianie motywu; najechanie zmienia jedynie kolor ramki.
---------------------------------------------------------------------------
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local BLIZZ_BUTTON = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local EMPTY_SLOT = { bgFile = "Interface\\PaperDoll\\UI-Backpack-EmptySlot" }

function ns.SkinButton(b, hover)
    local key = ns.ThemeKey()
    if b.skin ~= key then
        b.skin = key
        if key == "blizzard" then
            b:SetBackdrop(BLIZZ_BUTTON)
            b:SetBackdropColor(0.32, 0.04, 0.02, 0.95)
        else
            b:SetBackdrop(FLAT)
            b:SetBackdropColor(1, 1, 1, 0.06)
        end
        if b.text then
            if key == "blizzard" then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(0.85, 0.85, 0.85) end
        end
    end
    if key == "blizzard" then
        b:SetBackdropBorderColor(hover and 1 or 0.8, hover and 0.85 or 0.65, hover and 0.45 or 0.3, 1)
    else
        b:SetBackdropBorderColor(1, 1, 1, hover and 0.6 or 0.25)
    end
end

function ns.SkinPlus(p, hover)
    local key = ns.ThemeKey()
    if p.skin ~= key then
        p.skin = key
        p:SetBackdrop(key == "blizzard" and EMPTY_SLOT or FLAT)
        if p.text then p.text:SetTextColor(unpack(ns.Theme().plusText)) end
    end
    if key == "blizzard" then
        p:SetBackdropColor(1, 1, 1, hover and 1 or 0.75)
    else
        p:SetBackdropColor(1, 1, 1, 0.03)
        p:SetBackdropBorderColor(1, 1, 1, hover and 0.4 or 0.12)
    end
end

-- Przycisk w nagłówku plecaka (Make room, Bags, Cleanup): z napisem, a w Compact mode jako ikona.
-- Wysokość jak wyszukiwarka, więc rząd stoi równo; wygląd z motywu.
-- iconSpec = { atlas = "...", icon = "Interface/Icons/..." } (atlas, jeśli klient go ma, inaczej icon)
local function SetIconTexture(tex, spec)
    if spec.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(spec.atlas) then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(spec.atlas)
    else
        tex:SetTexture(spec.icon)
        if spec.flat then tex:SetTexCoord(0, 1, 0, 1) return end   -- tekstura przycisku, nie ikona przedmiotu
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end
ns.SetIconTexture = SetIconTexture

function ns.HeaderButton(parent, label, tipTitle, tipText, onClick, iconSpec)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(20)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:Hide()
    if iconSpec then SetIconTexture(b.icon, iconSpec) end
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetTexture("Interface/Buttons/ButtonHilight-Square")
    b.hl:SetBlendMode("ADD")
    b.hl:Hide()
    local function Apply()
        if ns.Compact() and iconSpec then
            b.compact = true
            b.skin = nil   -- po wyjściu z Compact mode tło ustawi się od nowa
            b:SetBackdrop(nil)
            b:SetSize(22, 22)
            b.text:Hide()
            b.icon:Show()
        else
            b.compact = false
            b.icon:Hide()
            b.text:Show()
            b:SetSize(math.floor(b.text:GetStringWidth() + 18), 20)
            ns.SkinButton(b)
        end
    end
    Apply()
    ns.OnThemeChange(Apply)
    b:SetScript("OnEnter", function(self)
        if self.compact then self.hl:Show() else ns.SkinButton(self, true) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(type(tipTitle) == "function" and tipTitle() or tipTitle)
        if tipText then GameTooltip:AddLine(tipText, 0.75, 0.75, 0.75, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if not self.compact then ns.SkinButton(self, false) end
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        onClick(self)
    end)
    return b
end
---------------------------------------------------------------------------
-- Pozostałe okna (Sell, Post, Bank, Make room, ustawienia, pasek toreb).
-- ns.SkinWindow(win, { title = fs, titleDark = { punkt }, close = przycisk X,
--                      small = true (małe okienko bez paska tytułu), onApply = fn(blizz) })
-- Blizzard: ramka okien gry na ciemnym kamieniu (jak plecak), tytuł w pasku tytułu.
-- Małe okienka (pasek toreb) dostają cienką złotą ramkę zamiast pełnej ramki z tytułem.
---------------------------------------------------------------------------
local FLAT_WINDOW = { bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 }
local GOLD_DIALOG = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}
local SMALL_GOLD = {
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- ramka Blizzarda (nine-slice) + kamień; false, gdy klient jej nie ma
local function MakeChrome(win)
    local util = NineSliceUtil
    local layout = "ButtonFrameTemplateNoPortrait"
    if not (util and util.GetLayout and util.ApplyLayoutByName and util.GetLayout(layout)) then return false end
    local ok, nine = pcall(CreateFrame, "Frame", nil, win, "NineSlicePanelTemplate")
    if not (ok and nine and pcall(util.ApplyLayoutByName, nine, layout)) then return false end
    nine:SetAllPoints()
    nine:SetFrameLevel(win:GetFrameLevel())
    local c = { nine = nine }
    c.base = win:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.base:SetColorTexture(0.07, 0.065, 0.06, 1)
    c.bg = win:CreateTexture(nil, "BACKGROUND")
    if c.bg:SetTexture("Interface/FrameGeneral/UI-Background-Rock", "REPEAT", "REPEAT") == false then
        c.bg:SetColorTexture(0.1, 0.09, 0.08, 1)
    end
    c.bg:SetHorizTile(true)
    c.bg:SetVertTile(true)
    c.shade = win:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.shade:SetColorTexture(0, 0, 0, 0.45)
    for _, t in ipairs({ c.base, c.bg, c.shade }) do
        t:SetPoint("TOPLEFT", 6, -21)
        t:SetPoint("BOTTOMRIGHT", -2, 3)
    end
    function c:SetShown(on)
        for _, x in ipairs({ self.nine, self.base, self.bg, self.shade }) do x:SetShown(on) end
    end
    return c
end

function ns.SkinWindow(win, p)
    p = p or {}
    local chrome   -- nil = jeszcze nie tworzona
    if not p.small then
        win:SetToplevel(true)   -- kliknięte okno wychodzi na wierzch
        win:HookScript("OnShow", function(self) ns.RaiseWindow(self) end)
    end
    if p.side then ns.RegisterSideWindow(win) end
    ns.OnThemeChange(function()
        local t = ns.Theme()
        local blizz = ns.ThemeKey() == "blizzard"
        local framed = false
        if blizz and not p.small then
            if chrome == nil then chrome = MakeChrome(win) end
            framed = chrome and true or false
        end
        if chrome then chrome:SetShown(framed) end
        if framed then
            win:SetBackdrop(nil)
        elseif blizz and p.small then
            win:SetBackdrop(SMALL_GOLD)
            win:SetBackdropColor(0.07, 0.065, 0.06, 0.97)
            win:SetBackdropBorderColor(0.85, 0.7, 0.35, 1)
        elseif blizz then
            win:SetBackdrop(GOLD_DIALOG)
        else
            win:SetBackdrop(FLAT_WINDOW)
            win:SetBackdropColor(0.06, 0.06, 0.07, 1)
            win:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
        end
        if p.title then
            p.title:ClearAllPoints()
            if framed then
                p.title:SetFontObject("GameFontNormal")
                p.title:SetPoint("TOP", 0, -4)
            else
                p.title:SetFontObject("GameFontNormalLarge")
                p.title:SetPoint("LEFT", win, "TOPLEFT", p.titleX or 16, -20)
            end
            p.title:SetTextColor(unpack(t.title))
        end
        if p.close then
            p.close:ClearAllPoints()
            if framed then p.close:SetPoint("TOPRIGHT", 1, 0) else p.close:SetPoint("CENTER", win, "TOPRIGHT", -18, -20) end
        end
        if p.onApply then p.onApply(blizz, framed) end
    end)
end

---------------------------------------------------------------------------
-- Kilka okien naraz: każde okno jest "toplevel" (kliknięte wychodzi na wierzch, a przy
-- otwarciu dostaje własny, wyższy poziom), żeby elementy dwóch okien się nie przeplatały.
-- Okna boczne (ustawienia, Make room) ustawiamy w rzędzie na lewo od plecaka,
-- każde kolejne na lewo od już otwartych - nie wchodzą na siebie.
---------------------------------------------------------------------------
function ns.RaiseWindow(win)
    win:Raise()   -- razem z dziećmi ponad inne okna tej samej warstwy
end

local sideWindows = {}
function ns.RegisterSideWindow(win)
    sideWindows[#sideWindows + 1] = win
end

function ns.PlaceBeside(win)
    win:ClearAllPoints()
    local bag = ns.frame
    if not (bag and bag:IsShown()) then
        win:SetPoint("CENTER", 0, 80)
        return
    end
    -- najbardziej wysunięte w lewo otwarte okno boczne (albo sam plecak)
    local anchor = bag
    for _, w in ipairs(sideWindows) do
        if w ~= win and w:IsShown() and w:GetLeft() and anchor:GetLeft() and w:GetLeft() < anchor:GetLeft() then
            anchor = w
        end
    end
    win:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -10, 0)
end

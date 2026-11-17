local ADDON, ns = ...

-- Wspólne okno z listą przedmiotów (sprzedaż u vendora, wystawianie na AH):
-- ikona + nazwa, kolumny Vendor i AH, tooltip po najechaniu, lewy/prawy klik na wierszu,
-- podsumowanie i przyciski na dole. Wiersz "keep" = przygaszony, cienka jasna kreska z lewej;
-- wiersz "selected" = kreska w kolorze akcentu.
--
-- opts: name, title, hint, onLeft(win, index), onRight(win, index), summary(win) -> tekst,
--       tooltip = { linijki pod tooltipem przedmiotu }, buttons = { { label, onClick(win) }, ... }

local ROW_H = 22
local MAX_ROWS = 12
local WIDTH = 500
local DIM_TEXT = { 0.6, 0.6, 0.6 }
local ACCENT = { 0.25, 0.8, 0.7 }
local COL_VENDOR_R = WIDTH - 125   -- prawa krawędź kolumny Vendor (miejsce na "5g 75s 95c")
local COL_AH_R = WIDTH - 22        -- prawa krawędź kolumny AH

local function Flat(f, bg, edge)
    f:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(edge))
end

local function FlatHover(b)
    Flat(b, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.25 })
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.6) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.25) end)
end

function ns.CreateItemListWindow(opts)
    local win = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    win:SetWidth(WIDTH)
    win:SetFrameStrata("DIALOG")
    win:SetPoint("CENTER", 0, 80)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    Flat(win, { 0.06, 0.06, 0.07, 0.97 }, { 0.2, 0.2, 0.22, 1 })
    win:Hide()
    table.insert(UISpecialFrames, opts.name)   -- ESC zamyka
    win.list = {}

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetTextColor(1, 1, 1)
    title:SetText(opts.title)

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 14, -36)
    hint:SetTextColor(unpack(DIM_TEXT))
    hint:SetText(opts.hint)
    win.hintText = hint

    -- zakładki w prawym górnym rogu, ustawiane przez win:SetTabs({ { key, label }, ... })
    -- (np. "For Vendor" + kategorie profesji postaci); opts.onTab(win, key) przeładowuje listę
    win.tabButtons = {}
    local tabPool = {}
    function win:SetTabs(tabs)
        for _, b in ipairs(tabPool) do b:Hide() end
        wipe(self.tabButtons)
        local prevTab
        for n = #tabs, 1, -1 do
            local i = #tabs - n + 1
            local t = tabs[n]
            local b = tabPool[i]
            if not b then
                b = CreateFrame("Button", nil, self)
                b:SetHeight(18)
                b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                b.text:SetPoint("CENTER")
                b.line = b:CreateTexture(nil, "ARTWORK")
                b.line:SetHeight(1)
                b.line:SetPoint("BOTTOMLEFT")
                b.line:SetPoint("BOTTOMRIGHT")
                b.line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
                b:SetScript("OnClick", function(btn) self:SetTab(btn.key) end)
                tabPool[i] = b
            end
            b:ClearAllPoints()
            if prevTab then
                b:SetPoint("RIGHT", prevTab, "LEFT", -12, 0)
            else
                b:SetPoint("TOPRIGHT", -14, self.framed and -26 or -14)   -- pod paskiem tytułu ramki Blizzarda
            end
            b.key, b.label = t.key, t.label
            b.text:SetText(t.label)
            b:SetWidth(b.text:GetStringWidth() + 4)
            b:Show()
            self.tabButtons[t.key] = b
            prevTab = b
        end
        self:FitHint()
    end

    -- podpowiedź pod tytułem chowa się, gdy zakładki by na nią nachodziły
    -- (te same informacje są w tooltipie wiersza)
    function win:FitHint()
        local tabsW, n = 0, 0
        for _, b in ipairs(tabPool) do
            if b:IsShown() then tabsW, n = tabsW + b:GetWidth(), n + 1 end
        end
        if n > 0 then tabsW = tabsW + 12 * (n - 1) end
        local hintRight = 14 + hint:GetStringWidth()
        local tabsLeft = WIDTH - 14 - tabsW
        -- zakładki są w linii podpowiedzi tylko w motywie Blizzard (framed); w Dark są wyżej, przy tytule
        hint:SetShown(n == 0 or not self.framed or hintRight + 16 <= tabsLeft)
    end

    -- napis zakładki z licznikiem, np. "Skinning (3)"
    function win:SetTabCount(key, n)
        local b = self.tabButtons[key]
        if not b then return end
        b.text:SetText(b.label .. ((n and n > 0) and (" (" .. n .. ")") or ""))
        b:SetWidth(b.text:GetStringWidth() + 4)
        self:FitHint()
    end

    function win:SetTab(key)
        self.tab = key
        for k, b in pairs(self.tabButtons) do
            local on = k == key
            b.text:SetTextColor(on and 1 or DIM_TEXT[1], on and 1 or DIM_TEXT[2], on and 1 or DIM_TEXT[3])
            b.line:SetShown(on)
        end
        if opts.onTab then opts.onTab(self, key) end
    end

    local colLabels = {}
    local function ColumnLabel(text, point, x)
        local fs = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint(point, win, "TOPLEFT", x, -58 - (opts.extraTop or 0))
        fs:SetTextColor(unpack(DIM_TEXT))
        fs:SetText(text)
        colLabels[#colLabels + 1] = fs
    end
    ColumnLabel("Item", "TOPLEFT", 14)
    ColumnLabel("Vendor", "TOPRIGHT", COL_VENDOR_R)
    ColumnLabel("AH", "TOPRIGHT", COL_AH_R)

    local scroll = CreateFrame("ScrollFrame", nil, win)
    -- opts.extraTop: dodatkowe miejsce nad listą (np. podnoszony przedmiot w Make room)
    scroll:SetPoint("TOPLEFT", 8, -74 - (opts.extraTop or 0))
    scroll:SetPoint("TOPRIGHT", -8, -74 - (opts.extraTop or 0))
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ROW_H * 2)))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(WIDTH - 16)
    scroll:SetScrollChild(content)
    win.scroll = scroll

    local rows = {}
    local function GetRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, content)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
        r:SetHighlightTexture("Interface/Buttons/WHITE8x8")
        r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bar = r:CreateTexture(nil, "ARTWORK")
        r.bar:SetPoint("TOPLEFT")
        r.bar:SetPoint("BOTTOMLEFT")
        r.bar:SetWidth(2)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 6, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.vendor = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.vendor:SetPoint("RIGHT", r, "LEFT", COL_VENDOR_R - 8, 0)
        -- nazwa kończy się tam, gdzie zaczyna się cena vendora (długie kwoty nie nachodzą na nazwę)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetPoint("RIGHT", r.vendor, "LEFT", -10, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.ah = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.ah:SetPoint("RIGHT", r, "LEFT", COL_AH_R - 8, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" then opts.onRight(win, self.index) else opts.onLeft(win, self.index) end
        end)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.e.bag, self.e.slot)
            GameTooltip:AddLine(" ")
            for _, line in ipairs(opts.tooltip) do GameTooltip:AddLine(line, 0.75, 0.75, 0.75) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
        return r
    end

    local summary = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("BOTTOMLEFT", 14, 44)

    -- przyciski od prawej; każdy przy kolejnym po lewej, szerokość dopasowana do napisu
    win.buttons = {}
    local prev
    for i = #opts.buttons, 1, -1 do
        local spec = opts.buttons[i]
        local b = CreateFrame("Button", nil, win, "BackdropTemplate")
        b:SetHeight(22)
        if prev then
            b:SetPoint("RIGHT", prev, "LEFT", -8, 0)
        else
            b:SetPoint("BOTTOMRIGHT", -12, 12)
        end
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER")
        ns.SkinButton(b)
        b:SetScript("OnEnter", function(self) ns.SkinButton(self, true) end)
        b:SetScript("OnLeave", function(self) ns.SkinButton(self, false) end)
        function b:SetLabel(text)
            self.text:SetText(text)
            self:SetWidth(math.max(80, self.text:GetStringWidth() + 24))
        end
        b:SetLabel(spec.label)
        b:SetScript("OnClick", function() spec.onClick(win) end)
        win.buttons[spec.label] = b
        prev = b
    end

    function win:Render()
        local list = self.list
        for i, e in ipairs(list) do
            local r = GetRow(i)
            r.e, r.index = e, i
            r.icon:SetTexture(e.icon)
            local name = e.link or e.name or ("item " .. e.id)
            if e.count > 1 then name = name .. " |cff999999x" .. e.count .. "|r" end
            if e.useme then name = name .. " |cff66bbff(use it)|r" end   -- Make room: użyj zamiast niszczyć
            r.name:SetText(name)
            r.vendor:SetText(ns.MoneyText(e.value))
            if e.live then
                -- cena z zakładki Selling Auctionatora; na czerwono, gdy AH da mniej niż vendor
                -- (po 5% prowizji AH)
                local low = e.value > 0 and e.live * 0.95 < e.value
                r.ah:SetText((low and "|cffff5555" or "") .. ns.MoneyText(e.live) .. (low and "|r" or ""))
            else
                r.ah:SetText(e.ahCheck and "|cff999999check|r" or (e.ah and ns.MoneyText(e.ah)) or "|cff666666-|r")
            end
            -- e.good = warto (zielony pasek, np. tańsze niż loot w Make room), e.dim = przygaszony
            local alpha = (e.keep or e.dim) and 0.4 or 1
            r.name:SetAlpha(alpha)
            r.icon:SetAlpha(alpha)
            r.vendor:SetAlpha(alpha)
            r.ah:SetAlpha(alpha)
            if e.keep then
                r.bg:SetColorTexture(1, 1, 1, 0.04)
                r.bar:SetColorTexture(1, 1, 1, 0.6)
            elseif e.selected then
                r.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
                r.bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
            elseif e.useme then
                r.bg:SetColorTexture(0.4, 0.7, 1, 0.10)
                r.bar:SetColorTexture(0.4, 0.7, 1, 1)
            elseif e.good then
                r.bg:SetColorTexture(0.4, 0.8, 0.6, 0.10)
                r.bar:SetColorTexture(0.4, 0.8, 0.6, 1)
            end
            local marked = (e.keep or e.selected or e.good or e.useme) and true or false
            r.bg:SetShown(marked)
            r.bar:SetShown(marked)
            r:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        content:SetHeight(#list * ROW_H)
        local visible = math.max(1, math.min(#list, MAX_ROWS))
        scroll:SetHeight(visible * ROW_H)
        if scroll:GetVerticalScroll() > scroll:GetVerticalScrollRange() then scroll:SetVerticalScroll(0) end
        self:SetHeight(74 + (opts.extraTop or 0) + visible * ROW_H + 76)
        summary:SetText(opts.summary(self))
    end

    -- motyw (Theme.lua): tło, tytuł, kolory akcentu, przyciski
    ns.SkinWindow(win, {
        title = title, titleX = 14,
        onApply = function(_, framed)
            win.framed = framed
            if win.tabButtons then
                local first
                for _, b in ipairs(tabPool) do if b:IsShown() and not first then first = b end end
                if first then first:ClearAllPoints() first:SetPoint("TOPRIGHT", -14, framed and -26 or -14) end
            end
            local t = ns.Theme()
            for i = 1, 3 do
                ACCENT[i] = t.accent[i]
                DIM_TEXT[i] = t.dim[i]
            end
            hint:SetTextColor(unpack(DIM_TEXT))
            win:FitHint()
            for _, fs in ipairs(colLabels) do fs:SetTextColor(unpack(DIM_TEXT)) end
            for _, b in ipairs(tabPool) do
                b.line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
                local on = b.key == win.tab
                b.text:SetTextColor(on and 1 or DIM_TEXT[1], on and 1 or DIM_TEXT[2], on and 1 or DIM_TEXT[3])
            end
            for _, b in pairs(win.buttons) do ns.SkinButton(b) end
            if win:IsShown() then win:Render() end
        end,
    })

    return win
end

-- Wpis listy dla przedmiotu z plecaka (po ns.Classify)
function ns.ListEntry(item)
    return {
        bag = item.bag, slot = item.slot, id = item.info.itemID,
        value = (item.sellPrice or 0) * (item.info.stackCount or 1),
        -- przyrostek z zapamiętaną ceną wariantu: ta cena; bez niej "check"
        ah = item.suffixPriced and item.auctionValue or (not item.randomSuffix and ns.AuctionValue(item)) or nil,
        ahCheck = item.randomSuffix,
        link = item.link, icon = item.info.iconFileID,
        count = item.info.stackCount or 1, name = item.info.itemName, autoCat = item.autoCat,
    }
end

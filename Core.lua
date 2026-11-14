local ADDON, ns = ...

ns.name = ADDON

function ns.Print(...)
    print("|cff4fc3f7Popoki Bag:|r", ...)
end

-- Na Forever nie ma globalnego GetItemInfo
ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Kwota z ikonkami monet (na Forever nie ma GetCoinTextureString)
local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
function ns.MoneyText(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. GOLD end
    if s > 0 then parts[#parts + 1] = s .. SILVER end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COPPER end
    return table.concat(parts, " ")
end

-- Wywołanie z zapisem błędu do PopokiBagDB.lastError (trafia do pliku po /reload)
local reported = {}
function ns.SafeCall(name, fn, ...)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debugstack(2) end, ...)
    if not ok then
        PopokiBagDB.lastError = { time = date("%Y-%m-%d %H:%M:%S"), where = name, error = err }
        if not reported[name] then
            reported[name] = true
            ns.Print("|cffff5555" .. name .. " error:|r " .. (err:match("^[^\n]*") or err))
        end
    end
    return ok
end

-- Torby plecaka: 0 = plecak, 1..4 = założone torby, 5 = szósty slot (reagent bag na Forever,
-- tak liczy Ellesmere: EUI_Bags_Refresh.lua:1131). Pusty slot ma 0 miejsc, więc nic nie psuje.
ns.FIRST_BAG = 0
ns.LAST_BAG = 5

local defaults = {
    pos = nil,          -- {point, x, y}
    view = "all",
    ahMinRatio = 1.5,   -- AH >= vendor * 150%
    ahMinProfit = 200,  -- i co najmniej 2s więcej (miedziaki, cały stack)
    collapsed = {},     -- [klucz kategorii] = true, zwinięte sekcje w widoku All Items
}
local charDefaults = {
    assign = {},        -- [itemID] = klucz kategorii, ręczne przypisania tej postaci
    order = {},         -- [itemID] = numer kolejności w sekcji (większy = dalej)
}

-- Komendy /popoki; kolejne pliki dopisują tu swoje podkomendy
ns.commands = {}

SLASH_POPOKIBAG1 = "/popoki"
SLASH_POPOKIBAG2 = "/plecak"
SlashCmdList.POPOKIBAG = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local fn = ns.commands[cmd]
    if fn then
        fn(rest)
    elseif cmd == "" then
        ns.Toggle()
    else
        ns.Print("commands: /popoki (toggle), /popoki settings, /popoki room (make room), /popoki quests, /popoki armor, /popoki reset (window position)")
    end
end

ns.commands.reset = function()
    PopokiBagDB.pos = nil
    ns.RestorePosition()
end

-- Proste zdarzenia: ns.On("EVENT", fn)
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)

function ns.On(event, fn)
    if not handlers[event] then
        -- zdarzenie, którego klient nie zna (Forever nie ma wszystkich z Classica/retaila): pomijamy
        if not pcall(events.RegisterEvent, events, event) then return end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    PopokiBagDB = PopokiBagDB or {}
    PopokiBagCharDB = PopokiBagCharDB or {}
    for k, v in pairs(defaults) do
        if PopokiBagDB[k] == nil then PopokiBagDB[k] = v end
    end
    -- dane z testów (komendy diagnostyczne usunięte w 1.0.0)
    PopokiBagDB.debug, PopokiBagDB.debugSkills, PopokiBagDB.debugTip = nil, nil, nil
    -- jednorazowo: próg zysku 20s -> 2s (decyzja z 2026-11-13)
    if not PopokiBagDB.migratedProfit2s then
        PopokiBagDB.ahMinProfit = 200
        PopokiBagDB.migratedProfit2s = true
    end
    for k, v in pairs(charDefaults) do
        if PopokiBagCharDB[k] == nil then PopokiBagCharDB[k] = v end
    end
end)

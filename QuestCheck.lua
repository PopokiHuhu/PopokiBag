local ADDON, ns = ...

-- Czy przedmiot oznaczony przez grę jako "Quest Item" jest jeszcze potrzebny:
-- szukamy jego nazwy w celach WSZYSTKICH questów z dziennika (nie tylko śledzonych),
-- np. "Twilight Pendant: 9/10". Brak w celach = podejrzany (pewnie zbędny), ale nie
-- usuwamy niczego sami: część przedmiotów (do oddania, do użycia) nie występuje w celach.
-- API dziennika jak w EllesmereUIQuestTracker (C_QuestLog.GetInfo / GetQuestObjectives).

local objectives = {}   -- { { text = "twilight pendant: 9/10", quest = "The Twilight Pendants", raw = "..." } }
local dirty = true

local function Rebuild()
    wipe(objectives)
    dirty = false
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives) then
        return
    end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            for _, obj in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if obj.text and obj.text ~= "" then
                    objectives[#objectives + 1] = { text = obj.text:lower(), raw = obj.text, quest = info.title }
                end
            end
        end
    end
end

ns.On("QUEST_LOG_UPDATE", function() dirty = true end)

-- nil = nie dotyczy (to nie "Quest Item" od gry albo starter questa),
-- false = brak w celach dziennika, tabela = { quest, raw } gdzie jest potrzebny
function ns.QuestNeed(item)
    if not (item.isQuest or item.classID == 12) or item.isStarter then return nil end
    if dirty then
        local ok = pcall(Rebuild)
        if not ok then return nil end
    end
    local name = item.info.itemName and item.info.itemName:lower()
    if not name then return nil end
    for _, o in ipairs(objectives) do
        if o.text:find(name, 1, true) then return o end
    end
    return false
end

-- /popoki quests: lista przedmiotów z Quest Items z wynikiem sprawdzenia
ns.commands.quests = function()
    local seen = {}
    for _, item in ipairs(ns.Scan()) do
        ns.Classify(item)
        local id = item.info.itemID
        if item.cat == "quest" and not seen[id] then
            seen[id] = true
            local name = item.link or item.info.itemName or ("item " .. id)
            local need = item.questNeed
            if need then
                ns.Print("|cff66dd66needed|r " .. name .. " - " .. need.quest .. " (" .. need.raw .. ")")
            elseif need == false then
                ns.Print("|cffff6666not in quest log|r " .. name)
            else
                ns.Print("|cff999999not checked|r " .. name .. " - " .. (item.reason or ""))
            end
        end
    end
end

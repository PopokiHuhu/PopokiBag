local ADDON, ns = ...

-- Typ pancerza względem tego, co postać może nosić:
-- cięższy niż umiesz nosić = "high" (czerwony), lżejszy = "low" (żółtawy).
-- Dotyczy tylko części z typem pancerza (cloth/leather/mail/plate); peleryny pomijamy,
-- bo każdy je nosi.

local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4
local ARMOR_CLASS = 4
local SKILL_TO_TYPE = { ["Cloth"] = CLOTH, ["Leather"] = LEATHER, ["Mail"] = MAIL, ["Plate Mail"] = PLATE }
ns.ARMOR_NAMES = { [CLOTH] = "Cloth", [LEATHER] = "Leather", [MAIL] = "Mail", [PLATE] = "Plate" }

-- Z umiejętności postaci (Forever: C_SkillInfo, inne klienty: stare API)
local function FromSkills()
    local best
    local function check(name)
        local t = name and SKILL_TO_TYPE[name]
        if t and (not best or t > best) then best = t end
    end
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        for i = 1, C_SkillInfo.GetNumSkillLines() do
            local d = C_SkillInfo.GetSkillLineInfo(i)
            check(d and d.name)
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            check((GetSkillLineInfo(i)))
        end
    end
    return best
end

-- Zapasowo: zasady klasycznego WoW
local function FromClass()
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    if class == "WARRIOR" or class == "PALADIN" then return level >= 40 and PLATE or MAIL end
    if class == "HUNTER" or class == "SHAMAN" then return level >= 40 and MAIL or LEATHER end
    if class == "ROGUE" or class == "DRUID" then return LEATHER end
    return CLOTH
end

local maxArmor
function ns.UpdateArmorType()
    local ok, fromSkills = pcall(FromSkills)
    maxArmor = (ok and fromSkills) or FromClass()
    ns.armorSource = (ok and fromSkills) and "skills" or "class"
end

function ns.MaxArmorType()
    if not maxArmor then ns.UpdateArmorType() end
    return maxArmor
end

-- "high" / "low" / nil
function ns.ArmorFit(classID, subClassID, equipLoc)
    if classID ~= ARMOR_CLASS or not ns.ARMOR_NAMES[subClassID] or equipLoc == "INVTYPE_CLOAK" then return nil end
    local max = ns.MaxArmorType()
    if subClassID > max then return "high" end
    if subClassID < max then return "low" end
end

ns.On("PLAYER_LOGIN", ns.UpdateArmorType)
ns.On("PLAYER_LEVEL_UP", function() C_Timer.After(1, ns.UpdateArmorType) end)
ns.On("SKILL_LINES_CHANGED", ns.UpdateArmorType)

ns.commands.armor = function()
    ns.UpdateArmorType()
    ns.Print("your armor type: " .. ns.ARMOR_NAMES[ns.MaxArmorType()] .. " (from " .. ns.armorSource .. ")")
end

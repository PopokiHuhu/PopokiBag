local ADDON, ns = ...

-- Umiejętności postaci (profesje i poziomy). Forever: C_SkillInfo albo stare API.
-- Zwraca listę { name, rank, max, header }.
function ns.ReadSkills()
    local list = {}
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        for i = 1, C_SkillInfo.GetNumSkillLines() do
            local d = C_SkillInfo.GetSkillLineInfo(i)
            if d then
                list[#list + 1] = { name = d.name, rank = d.skillRank or d.rank, max = d.maxRank, header = d.isHeader, src = "C_SkillInfo" }
            end
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            list[#list + 1] = { name = name, rank = rank, max = maxRank, header = isHeader, src = "legacy" }
        end
    end
    return list
end

-- Poziomy umiejętności po nazwie ("First Aid" -> 42), odświeżane przy zmianie umiejętności
local ranks = {}
function ns.UpdateSkillRanks()
    wipe(ranks)
    local ok, skills = pcall(ns.ReadSkills)
    if not ok then return end
    for _, s in ipairs(skills) do
        if not s.header and s.name and s.rank then ranks[s.name] = s.rank end
    end
end

function ns.SkillRank(name)
    if not next(ranks) then ns.UpdateSkillRanks() end
    return ranks[name]
end

ns.On("PLAYER_LOGIN", ns.UpdateSkillRanks)
ns.On("SKILL_LINES_CHANGED", ns.UpdateSkillRanks)

-- Twoje profesje (główne + drugorzędne) z nagłówków "Professions" i "Secondary Skills"
local myProfs = {}
function ns.MyProfessions()
    if next(myProfs) then return myProfs end
    local ok, skills = pcall(ns.ReadSkills)
    if not ok then return myProfs end
    local section
    for _, s in ipairs(skills) do
        if s.header then
            section = s.name
        elseif s.name and (section == "Professions" or section == "Secondary Skills") then
            myProfs[s.name] = true
        end
    end
    return myProfs
end
ns.On("SKILL_LINES_CHANGED", function() wipe(myProfs) end)

-- Profesje główne (tylko nagłówek "Professions"), w kolejności z okna umiejętności
local primaries
function ns.MyPrimaryProfessions()
    if primaries and #primaries > 0 then return primaries end
    primaries = {}
    local ok, skills = pcall(ns.ReadSkills)
    if not ok then return primaries end
    local section, seen = nil, {}
    for _, s in ipairs(skills) do
        if s.header then
            section = s.name
        elseif s.name and section == "Professions" and not seen[s.name] then
            seen[s.name] = true
            primaries[#primaries + 1] = s.name
        end
    end
    return primaries
end
ns.On("SKILL_LINES_CHANGED", function() primaries = nil end)

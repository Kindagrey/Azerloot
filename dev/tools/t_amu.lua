dofile("/home/claude/work/mock/load.lua")
AzerlootDB = { lang = "de" }
local info = AZL.ClassInfo("shaman")
for i = 1, table.getn(info.spells) do
  local s = info.spells[i]
  if s.amulet then
    print(AzG(s.amulet) .. " [" .. tostring(Azerloot_AmuletIcons[s.amulet]) .. "]")
    for e = 1, table.getn(s.effects) do print("   " .. AzG(s.effects[e])) end
  end
end

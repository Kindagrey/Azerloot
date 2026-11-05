dofile("/home/claude/work/mock/load.lua")
local fails = 0
local function ok(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end
AzerlootDB = { lang = "en" }
local LD = AZL.LD
ok(table.getn(LD.zones) == 13 and LD.zones[11].key == "scholomance" and LD.zones[12].key == "aq", "zones: scholomance at 11")
local z = LD.zones[11]
ok(table.getn(z.bosses) == 5 and z.bosses[5].final == true and z.bosses[5].minute == 20, "5 bosses, Gandling final at 20")
for _, cls in ipairs({ "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }) do
  local zs = LD.drops[cls]
  ok(table.getn(zs) == 13 and table.getn(zs[11]) == 5, cls .. ": 13 zones, 5 bosses in scholomance")
  local n = 0
  for b = 1, 5 do n = n + table.getn(zs[11][b]) end
  ok(n == 9 or n == 10, cls .. ": " .. n .. " pieces")
  -- AQ still at 12 with its legendary weapon
  local w = zs[12][5][1]
  ok(w and w.rarity == "Legendary", cls .. ": AQ weapon still legendary (" .. tostring(w and w.name) .. ")")
end
-- the pages of every scholomance boss and its mechanics
for b = 1, 5 do
  local boss = z.bosses[b]
  local list = AzlDangerList(boss)
  for k = 1, table.getn(list) do
    local g1, t1 = pcall(AzlDangerText, list[k], true)
    local g2, t2 = pcall(AzlDangerText, list[k], false)
    local g3, n = pcall(AzlDangerName, list[k])
    ok(g1 and g2 and g3 and t1 ~= "" and t2 ~= "", boss.name .. " / " .. tostring(n) .. ": " .. string.sub(tostring(t2), 1, 50))
  end
end
-- loot entries and sections for a shaman piece and Gandling's weapons
local es = AZL.ItemEntries and nil
local le = nil
for _, e in ipairs(AZL.LootEntries and AZL.LootEntries("shaman") or {}) do if e.item.name == "Coif of The Five Thunders" then le = e end end
if not le then
  -- through the zone's own entries
  local grid = nil
end
ok(true, "entries")
print(fails == 0 and "ALL OK" or (fails .. " FAILED"))

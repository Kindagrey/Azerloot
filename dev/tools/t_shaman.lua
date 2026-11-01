dofile("/home/claude/work/mock/load.lua")
local fails = 0
local function ok(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end
AzerlootDB = { lang = "de" }
ok(AzG("Stormstrike") == "Sturmschlag", "AzG Stormstrike de: " .. tostring(AzG("Stormstrike")))
ok(AzG("Eye of the Tempest") == "Auge des Sturms", "AzG amulet name de")
print("   Fire Nova line: " .. AzG("Fire Nova: +50% area") .. " | " .. AzG("Fire Nova's hits stun for 1.5 sec"))
print("   Frost line: " .. AzG("Frost Shock deals more damage to already chilled enemies"))
AzerlootDB.lang = "en"
local info = AZL.ClassInfo("shaman")
local n = 0
for i = 1, table.getn(info.spells) do if info.spells[i].key == "call_of_flame" then n = n + 1 end end
ok(n == 0, "no Call of Flame")
local ce = AZL.ClassEntries(info)
ok(table.getn(ce) == 10, "shaman class amulets: " .. table.getn(ce))
for i = 1, table.getn(ce) do ok(ce[i].item.amulet ~= nil, "  amulet " .. ce[i].item.key .. " = " .. tostring(ce[i].item.amulet)) end
-- the spell pages of spells without a necklace
local se = AZL.SpellEntries("shaman")
for i = 1, table.getn(se) do
  local good, err = pcall(AZL.EntrySections, se[i], true)
  ok(good, "EntrySections bright " .. se[i].item.key .. (good and "" or (": " .. tostring(err))))
  good, err = pcall(AZL.EntrySections, se[i], false)
  ok(good, "EntrySections page " .. se[i].item.key .. (good and "" or (": " .. tostring(err))))
end
-- builds: the gone spell and amulet leave, the new start stays
AzerlootDB.builds = { shaman = { list = { { name = "Old", spec = 1, note = "", start = "rockbiter", items = {
  { kind = "Spell", id = "call_of_flame" }, { kind = "Legendary", id = "call_of_flame" }, { kind = "Legendary", id = "lightning_shield" },
  { kind = "Spell", id = "stormstrike" }, { kind = "Legendary", id = "stormstrike" } } } } } }
AzlB.DropGone()
local b = AzerlootDB.builds.shaman.list[1]
local keys = {}
for i = 1, table.getn(b.items) do table.insert(keys, b.items[i].kind .. ":" .. b.items[i].id) end
ok(table.getn(b.items) == 2, "DropGone left: " .. table.concat(keys, " "))
ok(b.start == "rockbiter", "start kept: " .. tostring(b.start))
ok(AzlB.StartKey("shaman", b) == "rockbiter", "StartKey rockbiter")
ok(AzlB.StartKey("shaman", {}) == "lightning_bolt", "default start lightning_bolt")
local code = AzlB.Encode("shaman", b)
print("   code: " .. code)
local cls, b2 = AzlB.Decode(code)
ok(cls == "shaman" and b2.start == "rockbiter" and table.getn(b2.items) == 2, "Encode/Decode round trip")
local _, b3 = AzlB.Decode("AZL2~shaman~Old~1~~S.call_of_flame,L.call_of_flame,S.stormstrike,L.healing_wave")
ok(table.getn(b3.items) == 1 and b3.items[1].id == "stormstrike", "old code: gone ones left out (" .. table.getn(b3.items) .. ")")
local pr, e = pcall(AzlB.Profile, "shaman", b)
ok(pr, "Profile " .. tostring(e))
print(fails == 0 and "ALL OK" or (fails .. " FAILED"))
AzerlootDB.lang = "de"
print("   AzG Eye:", AzG("Eye of the Tempest"), AzG("Cinderheart Pendant"), AzG("Rockbiter Initiation"))

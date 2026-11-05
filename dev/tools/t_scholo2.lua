dofile("/home/claude/work/mock/load.lua")
local fails = 0
local function ok(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end
AzerlootDB = { lang = "en" }
local LD = AZL.LD
local z = LD.zones[11]
local function Entry(cls, bi, k)
  local it = LD.drops[cls][11][bi][k]
  return { kind = "LootItem", item = it, class = cls, zone = z, zoneIndex = 11, boss = z.bosses[bi], bossIndex = bi, rarity = it.rarity or z.rarity, sources = {} }
end
for _, lg in ipairs({ "en", "de", "fr", "es", "pt" }) do
 AzInLang(lg, function()
  for _, e in ipairs({ Entry("shaman", 1, 1), Entry("shaman", 5, 2), Entry("rogue", 5, 2), Entry("hunter", 5, 1) }) do
    local g, secs = pcall(AZL.EntrySections, e, true)
    ok(g, lg .. " sections " .. e.item.name .. (g and "" or (": " .. tostring(secs))))
    if g then
      local t = {}
      for s = 1, table.getn(secs) do t[s] = secs[s][1] .. " | " .. secs[s][2][1][1] end
      if lg == "de" or lg == "en" then print("   " .. table.concat(t, "\n   ")) end
    end
    local g2, title, col, sub = pcall(AZL.EntryTitle, e)
    ok(g2 and title and col and sub, lg .. " title " .. tostring(title) .. " / " .. tostring(sub))
  end
  -- the mechanics in this language
  local b = z.bosses[5]
  local list = AzlDangerList(b)
  print("   " .. lg .. ": " .. AzlDangerName(list[1]) .. " - " .. string.sub(AzlDangerText(list[1]), 1, 70))
  print("   " .. lg .. ": " .. string.sub(AzlDangerText(list[4]), 1, 90))
  print("   " .. lg .. ": " .. AzG("Tier 0.5") .. " / " .. AzG(LD.sets.shaman.name) .. " / " .. AzG("Kirtonos the Herald") .. " / " .. AzG(z.subtitle))
  print("   " .. lg .. ": " .. AzT("Remove run") .. " / " .. AzName("Frozen Checkmate") .. " / " .. AzName("Changes form") .. " / " .. AzG("Helm of Heroism") .. " / " .. AzG("+181% pickup range"))
 end)
end
-- the chronicle: a run taken out, the best and the records found again
AzerlootDB.lang = "en"
AzerlootDB.chronicle = { shaman = { runs = {
  { id = "a", at = 1, t = 900, kills = 100, won = true, level = 30, bosses = 3, dealt = 90000, gold = 10, result = "won" },
  { id = "b", at = 2, t = 1200, kills = 300, won = true, level = 40, bosses = 5, dealt = 200000, gold = 20, result = "won" },
  { id = "c", at = 3, t = 300, kills = 50, won = false, level = 10, bosses = 1, dealt = 5000, gold = 5, result = "died" } }, rec = {}, n = 3 } }
local C = AzlC
local bk = C.Book("shaman")
for k = 3, 1, -1 do C.Note(bk, bk.runs[k]) end
ok(bk.best.id == "b" and bk.rec.kills.id == "b", "best is b before")
C.Remove("shaman", bk.runs[2])
ok(table.getn(bk.runs) == 2 and bk.best.id == "a" and bk.rec.kills.id == "a" and bk.rec.t.v == 900, "after removing b: best a, records from a (" .. tostring(bk.best.id) .. ")")
C.Remove("shaman", { id = "zz" })
ok(table.getn(bk.runs) == 2, "removing an unknown run changes nothing")
print(fails == 0 and "ALL OK" or (fails .. " FAILED"))

-- Azerloot: the chronicle. Every run the game reports as ended is written down per class:
-- how it went (from the game's AZS_GetRunSummary), and what the hero had (the build, the
-- spells and their ranks, the jewelry worn, the run's numbers and the boss loot). The last
-- fifty runs are kept; the best run and the records of each class are kept for good.
-- The book's own parts come from Azerloot.lua through the table AZL.

AzlC = {}
local C = AzlC
local Mod = math.mod or math.fmod
local KEEP = 50        -- runs kept per class
local ROWS = 10        -- runs per page on the left, under the best run
local PAGE_MID = 188   -- the middle of a page, where its ornament lines sit
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local STAR = "Interface\\AddOns\\Azerloot\\media\\textures\\star.tga"   -- the best run's own gold star
local JEWEL_SLOTS = { 2, 11, 12, 13, 14 }

-- ---------- what is kept ----------
function C.Book(cls)
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.chronicle) ~= "table" then AzerlootDB.chronicle = {} end
  local t = AzerlootDB.chronicle[cls]
  if type(t) ~= "table" then t = {}; AzerlootDB.chronicle[cls] = t end
  if type(t.runs) ~= "table" then t.runs = {} end
  if type(t.rec) ~= "table" then t.rec = {} end
  t.n = tonumber(t.n) or 0
  return t
end

-- the run being played, noted every two seconds (and kept over a /reload)
function C.Live()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.chronicleLive) ~= "table" then AzerlootDB.chronicleLive = {} end
  return AzerlootDB.chronicleLive
end

-- ---------- reading the game ----------
local function Plain(v)
  local t = type(v)
  return t == "string" or t == "number" or t == "boolean"
end

-- a field of the game's summary, whatever its exact spelling ("damageDealt", "damage_dealt")
local function Squash(k) return string.lower(string.gsub(tostring(k), "[^%w]", "")) end
local FIELDS = {
  result = { "result", "outcome", "res", "status", "ending", "won", "victory" },
  t = { "timesurvived", "survived", "time", "duration", "runtime", "t", "secs", "seconds" },
  level = { "level", "lvl", "herolevel" },
  kills = { "kills", "kill", "killed" },
  elites = { "elites", "elite", "elitekills" },
  guardians = { "guardians", "guardian", "guardiankills" },
  bosses = { "bosses", "boss", "bosskills" },
  dealt = { "damagedealt", "dealt", "dmgdealt", "damage", "dmg", "dd" },
  taken = { "damagetaken", "taken", "dmgtaken", "dt" },
  gold = { "gold", "money" },
  caches = { "caches", "cache", "chests", "chest" },
  hero = { "hero", "heroname", "name", "player" },
  class = { "class", "heroclass" },
  race = { "race", "herorace" },
  zone = { "zone", "zonename", "map" },
}
function C.Normalize(sum)
  local out, flat = {}, {}
  if type(sum) ~= "table" then return out end
  for k, v in pairs(sum) do
    if Plain(v) then flat[Squash(k)] = v end
  end
  for field, names in pairs(FIELDS) do
    for i = 1, table.getn(names) do
      if out[field] == nil and flat[names[i]] ~= nil then out[field] = flat[names[i]] end
    end
  end
  return out
end

-- a run ended by the hero's own choice ("left"), not by death or victory
function C.Left(result)
  if type(result) ~= "string" then return false end
  local r = string.lower(result)
  return r == "left" or string.find(r, "abandon", 1, true) ~= nil or string.find(r, "quit", 1, true) ~= nil
    or string.find(r, "leave", 1, true) ~= nil
end

-- did the hero survive? the summary's own word first, else the game's last phase
function C.Won(result, phase)
  if type(result) == "boolean" then return result end
  if type(result) == "number" then return result > 0 end
  if type(result) == "string" then
    local r = string.lower(result)
    if string.find(r, "vict") or string.find(r, "win") or string.find(r, "won") or string.find(r, "surviv")
      or string.find(r, "success") or string.find(r, "clear") then return true end
    if string.find(r, "dead") or string.find(r, "death") or string.find(r, "died") or string.find(r, "fail")
      or string.find(r, "lost") or string.find(r, "defeat") or string.find(r, "fall") then return false end
  end
  return phase == "victory"
end

local function English(n) return (Azerloot_Names and Azerloot_Names[n]) or n end
-- a worn piece's name as the game writes it may carry more: a class amulet its spell and
-- rank ("Auge des gespaltenen Himmels: Sternenfeuer X"), a piece its rarity's numeral.
-- What is left is the piece's own name, in English when the book knows it.
function C.CleanJewel(n)
  if type(n) ~= "string" then return n end
  local base = string.gsub(n, "%s*:.*$", "")
  base = string.gsub(base, "%s+[IVX]+$", "")
  return English(base)
end

-- what the hero has now: spells and ranks, jewelry, numbers, build
function C.Snap()
  local Z = AZL
  local L = C.Live()
  local cls = Z.PlayerClass()
  L.cls = cls
  -- the class's own spells (a racial trait is not one), with their rank
  local AZS_SPELLS = (AzlSpells and AzlSpells()) or AZS_SPELLS
  if type(AZS_SPELLS) == "table" and table.getn(AZS_SPELLS) > 0 then
    local own, info, sp = {}, Z.ClassInfo(cls), {}
    for i = 1, table.getn(info.spells) do own[info.spells[i].key] = true end
    for i = 1, table.getn(AZS_SPELLS) do
      local s = AZS_SPELLS[i]
      if own[s.key] then table.insert(sp, { k = s.key, r = tonumber(s.rank) or 0 }) end
    end
    if table.getn(sp) > 0 then L.spells = sp end
  end
  local jw = {}
  for i = 1, table.getn(JEWEL_SLOTS) do
    local link = GetInventoryItemLink and GetInventoryItemLink("player", JEWEL_SLOTS[i])
    local _, _, n = string.find(link or "", "%[(.-)%]")
    if n then
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", JEWEL_SLOTS[i])
      table.insert(jw, { s = JEWEL_SLOTS[i], n = C.CleanJewel(n), raw = n, ic = tex })
    end
  end
  if table.getn(jw) > 0 then L.jewels = jw end
  if type(AZS_STATS) == "table" and next(AZS_STATS) then
    local st = {}
    for k, v in pairs(AZS_STATS) do if type(v) == "number" then st[k] = v end end
    L.stats = st
  end
  -- the build loaded into the wishlist, and how much of it the hero has
  if AzlB then
    local all = AzlB.All(cls)
    local b = all.active and all.list[all.active]
    if b then
      local got, n = AzlB.Progress(cls, b)
      local miss = {}
      local items = AzlB.Items(cls, b)
      local worn = Z.WornNames()
      for k = 1, table.getn(items) do
        local rec = items[k]
        local e = AzlB.Entry(cls, rec)
        if e then
          local have
          if rec.kind == "Spell" then have = Z.KnowsSpell(rec.id) else have = Z.IsFound(e, worn) end
          if not have then table.insert(miss, { kind = rec.kind, id = rec.id }) end
        end
      end
      L.build = { i = all.active, uid = AzlB.Uid and AzlB.Uid(b), name = b.name, got = got, all = n, miss = miss }
    end
  end
  local R = type(AZS_RUN) == "table" and AZS_RUN or {}
  local ok, rt = pcall(function() return AZS_GetRunTime and AZS_GetRunTime() end)
  L.t = (ok and tonumber(rt)) or tonumber(R.t) or L.t
  L.kills = tonumber(R.kills) or L.kills
  L.gold = tonumber(R.gold) or L.gold
  L.caches = tonumber(R.chest) or L.caches
  L.level = (UnitLevel and UnitLevel("player")) or L.level
  if type(AZS_ZONE) == "table" and AZS_ZONE.zone and AZS_ZONE.zone ~= "" then L.zone = AZS_ZONE.zone end
end

-- a piece of boss loot that dropped in this run
function C.Loot(cls, name, new)
  local L = C.Live()
  if not L.active or L.done then return end
  if type(L.loot) ~= "table" then L.loot = {} end
  -- the pieces this run brought into the collection for the first time
  if new then
    if type(L.lootNew) ~= "table" then L.lootNew = {} end
    L.lootNew[name] = true
  end
  for i = 1, table.getn(L.loot) do if L.loot[i] == name then return end end
  table.insert(L.loot, name)
end

local function Summary()
  if not AZS_GetRunSummary then return nil end
  local ok, s = pcall(AZS_GetRunSummary)
  if ok and type(s) == "table" and next(s) then return s end
  return nil
end

-- the run is over: written into the chronicle, once
function C.Record(phase)
  local L = C.Live()
  if not L.active or L.done then return end
  L.done = true
  local sum = Summary()
  local S = C.Normalize(sum)
  -- a run the hero left by the game's own button is not written down (nor does leaving
  -- the endless fight change the run already written)
  if C.Left(S.result) then return end
  local cls = L.cls or AZL.PlayerClass()
  if type(S.class) == "string" and S.class ~= "" then cls = string.lower(S.class) end
  local bk = C.Book(cls)
  -- the endless fight after a run's end: the same run goes on, its numbers grow
  if L.cont then
    local old = nil
    for k = 1, table.getn(bk.runs) do if bk.runs[k].id == L.cont then old = bk.runs[k] end end
    if old then
      C.Continue(old, S, L, sum)
      C.Note(bk, old)
      L.last = old.id
      C.sel = old
      if AZL.state.module == "Chronicle" and C.pane and C.pane:IsVisible() then C.Draw() end
      return
    end
  end
  bk.n = bk.n + 1
  local run = {
    id = bk.n, at = time and time() or 0,
    won = C.Won(S.result, phase), result = Plain(S.result) and S.result or phase,
    t = tonumber(S.t) or L.t or 0, level = tonumber(S.level) or L.level,
    kills = tonumber(S.kills) or L.kills, elites = tonumber(S.elites), guardians = tonumber(S.guardians),
    bosses = tonumber(S.bosses), dealt = tonumber(S.dealt), taken = tonumber(S.taken),
    gold = tonumber(S.gold) or L.gold, caches = tonumber(S.caches) or L.caches,
    hero = S.hero or (UnitName and UnitName("player")), race = S.race, zone = S.zone or L.zone,
    build = L.build, spells = L.spells, jewels = L.jewels, stats = L.stats, loot = L.loot,
    lootNew = L.lootNew,
  }
  -- the summary as the game gave it, for anything it tells that is not shown yet
  if type(sum) == "table" then
    run.raw = {}
    for k, v in pairs(sum) do if Plain(v) then run.raw[tostring(k)] = v end end
  end
  table.insert(bk.runs, 1, run)
  while table.getn(bk.runs) > KEEP do table.remove(bk.runs) end
  C.Note(bk, run)
  L.last = run.id
  C.sel = run
  C.page = 1
  if AZL.state.module == "Chronicle" and C.pane and C.pane:IsVisible() then C.Draw() end
end

-- A run carried on in endless mode: what it reached at its official end is kept (time and
-- result), and its numbers become those of the whole fight. Survived or fallen stays as the
-- official end had it.
function C.Continue(run, S, L, sum)
  if not run.official then run.official = { t = run.t, won = run.won, kills = run.kills, level = run.level } end
  run.endless = true
  run.t = tonumber(S.t) or L.t or run.t
  run.level = tonumber(S.level) or L.level or run.level
  run.kills = tonumber(S.kills) or L.kills or run.kills
  for _, f in ipairs({ "elites", "guardians", "bosses", "dealt", "taken" }) do
    if tonumber(S[f]) then run[f] = tonumber(S[f]) end
  end
  run.gold = tonumber(S.gold) or L.gold or run.gold
  run.caches = tonumber(S.caches) or L.caches or run.caches
  run.spells = L.spells or run.spells
  run.jewels = L.jewels or run.jewels
  run.stats = L.stats or run.stats
  run.loot = L.loot or run.loot
  run.lootNew = L.lootNew or run.lootNew
  if type(sum) == "table" then
    run.raw = {}
    for k, v in pairs(sum) do if Plain(v) then run.raw[tostring(k)] = v end end
  end
end

-- the best run (survived beats fallen, then longer, then more kills) and the records stay
local function Score(r)
  return (r.won and 1e12 or 0) + (tonumber(r.t) or 0) * 1e6 + (tonumber(r.kills) or 0)
end
C.Score = Score
C.RECORDS = { "t", "kills", "dealt", "level", "bosses", "gold" }
function C.Note(bk, run)
  if not bk.best or Score(run) > Score(bk.best) then bk.best = run end
  for i = 1, table.getn(C.RECORDS) do
    local f = C.RECORDS[i]
    local v = tonumber(run[f])
    if v and v > 0 and (not bk.rec[f] or v > (tonumber(bk.rec[f].v) or 0)) then
      bk.rec[f] = { v = v, id = run.id, at = run.at }
    end
  end
end

-- every two seconds from the book's watcher; and once the game's AZSEND message comes
function C.Tick()
  local ph = AZS_GetPhase and AZS_GetPhase() or nil
  local L = C.Live()
  -- the run's clock went back: a new run began without the old one being reported over
  local ok, rt = pcall(function() return AZS_GetRunTime and AZS_GetRunTime() end)
  rt = ok and tonumber(rt) or nil
  local fighting = (ph == "playing" or ph == "endless")
  local restarted = fighting and rt and L.t and rt + 5 < L.t
  if fighting and L.done and not restarted and L.last and rt and rt > 5 then
    -- the run ended, and the hero fights on (endless): the same run goes on
    L.done, L.active, L.cont, L.endAt, L.phase = nil, true, L.last, nil, nil
  elseif ph == "ready" or (fighting and L.done) or restarted then
    -- a new run: a fresh page
    AzerlootDB.chronicleLive = { active = fighting or nil, started = ph }
    L = C.Live()
  end
  if fighting then
    L.active = true
    C.Snap()
  elseif (ph == "dead" or ph == "victory") and L.active and not L.done then
    -- the game may need a moment for its summary: wait up to twenty seconds for it
    L.endAt = L.endAt or (GetTime and GetTime() or 0)
    L.phase = ph
    local waited = (GetTime and GetTime() or 0) - L.endAt
    if Summary() or waited > 20 then C.Record(ph) end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function()
  if arg1 ~= "AZSEND" then return end
  local L = C.Live()
  if L.active and not L.done then C.Record(L.phase or (AZS_GetPhase and AZS_GetPhase()) or "dead") end
end)

-- ---------- for the builds pages: how a build has done ----------
function C.BuildRecord(cls, i)
  local bk = C.Book(cls)
  local n, won, best = 0, 0, nil
  local key = C.KeyOfBuild(cls, i)
  for k = 1, table.getn(bk.runs) do
    local r = bk.runs[k]
    if key and C.RunKey(r) == key then
      n = n + 1
      if r.won then won = won + 1 end
      if not best or (tonumber(r.t) or 0) > best then best = tonumber(r.t) or 0 end
    end
  end
  return n, won, best
end

-- ---------- writing it out ----------
function C.Time(s)
  s = math.floor(tonumber(s) or 0)
  local h, m, x = math.floor(s / 3600), math.floor(Mod(s, 3600) / 60), Mod(s, 60)
  if h > 0 then return string.format("%d:%02d:%02d", h, m, x) end
  return string.format("%d:%02d", m, x)
end
function C.Big(v)
  v = tonumber(v)
  if not v then return "-" end
  if v >= 1e6 then return string.format("%.1fM", v / 1e6) end
  if v >= 1e4 then return string.format("%.1fk", v / 1e3) end
  return string.format("%d", math.floor(v + 0.5))
end
-- A run's day and hour, as the hero's own computer tells the time (an American player sees
-- American time), written the way the book's language writes dates: in English with the
-- month's name, so it reads the same in America and in Britain.
C.DATE_FMT = {
  en = { "%b %d", "%b %d, %Y  " },               -- the hour follows in 12-hour time, see C.Date
  de = { "%d.%m.", "%d.%m.%Y  %H:%M" },
  fr = { "%d/%m", "%d/%m/%Y  %H:%M" },
  es = { "%d/%m", "%d/%m/%Y  %H:%M" },
  pt = { "%d/%m", "%d/%m/%Y  %H:%M" },
}
function C.Date(at, long)
  if not at or at == 0 or not date then return "" end
  local lang = (AzLang and AzLang()) or "en"
  local f = C.DATE_FMT[lang] or C.DATE_FMT.en
  local out = date(long and f[2] or f[1], at)
  if long and f == C.DATE_FMT.en then
    -- Britain and America both read the hour as 8:01 PM; date's own %I would say 08
    local h, m = tonumber(date("%H", at)) or 0, date("%M", at) or "00"
    local h12 = Mod(h, 12)
    if h12 == 0 then h12 = 12 end
    out = out .. h12 .. ":" .. m .. ((h < 12) and " AM" or " PM")
  end
  return out
end

-- a spell's icon and name, a jewel's icon (a class amulet by its own icon)
function C.SpellInfo(cls, key)
  local info = AZL.ClassInfo(cls)
  for i = 1, table.getn(info.spells) do
    if info.spells[i].key == key then return info.spells[i] end
  end
  return nil
end
-- a zone as the game names it ("aq") or as the book does ("Gates of Ahn'Qiraj"), in the book's language
function C.ZoneName(z)
  if not z or z == "" then return "?" end
  local zones = Azerloot_Loot and Azerloot_Loot.zones or {}
  for i = 1, table.getn(zones) do
    if zones[i].key == z or string.lower(zones[i].name) == string.lower(z) then return AzG(zones[i].name) end
  end
  return AzG(z)
end
function C.JewelIcon(name)
  if Azerloot_AmuletIcons and Azerloot_AmuletIcons[name] then return Azerloot_AmuletIcons[name] end
  local kinds = { "Rings", "Trinkets", "Amulets" }
  for k = 1, 3 do
    local all = AZL.ItemEntries(kinds[k])
    for i = 1, table.getn(all) do
      if all[i].item.name == name then return all[i].item.icon end
    end
  end
  return "INV_Misc_QuestionMark"
end
function C.PartName(cls, rec)
  if rec.kind == "Spell" then
    local sp = C.SpellInfo(cls, rec.id)
    return AzG(sp and sp.name or rec.id)
  elseif rec.kind == "Legendary" then
    local sp = C.SpellInfo(cls, rec.id)
    return sp and AzG(sp.amulet) or rec.id
  end
  return AzG(rec.id)
end

-- A run's build, as the filter knows it: the build's own mark, or for runs from before the
-- marks its place and name. A build deleted (or replaced) keeps its runs under its name.
function C.RunKey(r)
  if not r.build then return nil end
  if r.build.uid then return r.build.uid end
  return "old:" .. tostring(r.build.i) .. ":" .. tostring(r.build.name)
end
-- the mark of the build now in place i (the runs from before the marks: by place and name)
function C.KeyOfBuild(cls, i)
  local b = AzlB and AzlB.Get(cls, i)
  if not b then return nil end
  local uid = AzlB.Uid(b)
  -- runs from before the marks, played in this place: this build's own
  local bk = C.Book(cls)
  for k = 1, table.getn(bk.runs) do
    local r = bk.runs[k]
    if r.build and not r.build.uid and r.build.i == i then r.build.uid = uid end
  end
  return uid
end
-- the builds the chronicle knows, newest run first, each once: { key, name }
function C.Builds(cls)
  local bk = C.Book(cls)
  local out, seen = {}, {}
  for i = 1, 5 do C.KeyOfBuild(cls, i) end   -- (gives older runs their build's mark)
  for k = 1, table.getn(bk.runs) do
    local key = C.RunKey(bk.runs[k])
    if key and not seen[key] then
      seen[key] = true
      table.insert(out, { key = key, name = bk.runs[k].build.name })
    end
  end
  return out
end
-- The filter's list: "All builds", the builds you have now (in their places), and, apart
-- and in grey, deleted builds that still have runs here.
function C.FilterChoices(cls)
  local out, have = { { key = false, name = AzT("All builds") } }, {}
  local first = true
  for i = 1, 5 do
    local b = AzlB and AzlB.Get(cls, i)
    if b then
      if first then table.insert(out, { head = AzT("Active Builds"), gap = true }); first = false end
      local key = C.KeyOfBuild(cls, i)
      have[key] = true
      table.insert(out, { key = key, name = b.name, place = i })
    end
  end
  -- deleted builds that still have runs among the last fifty
  local list = C.Builds(cls)
  local gone = 0
  first = true
  for k = 1, table.getn(list) do
    if not have[list[k].key] then
      if first then table.insert(out, { head = AzT("Deleted Builds"), gap = true }); first = false end
      gone = gone + 1
      table.insert(out, { key = list[k].key, name = list[k].name, gone = true, n = 5 + gone })
    end
  end
  return out
end
-- the filter opens a small window like the builds page's own list: a heading, the gold line,
-- and its rows with an icon each; the build on show has the gold bar
C.FM_W, C.FM_ROW = 210, 20
function C.ToggleFilterMenu(owner)
  local Z = AZL
  local m = C.fmenu
  if m and m:IsShown() then m:Hide(); return end
  if not m then
    m = CreateFrame("Frame", "AzerlootChronicleFilter", C.pane)
    -- above the page and its rows, none of which may show through
    m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetToplevel(true); m:SetWidth(C.FM_W)
    if C.pane.GetFrameLevel then m:SetFrameLevel(math.min(100, (C.pane:GetFrameLevel() or 1) + 40)) end
    m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    m:SetBackdropColor(0.06, 0.04, 0.02, 1)
    local solid = m:CreateTexture(nil, "BACKGROUND"); solid:SetTexture(Z.WHITE)
    solid:SetVertexColor(0.08, 0.055, 0.03); solid:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4); solid:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -4, 4)
    m:SetBackdropBorderColor(0.8, 0.62, 0.3, 1)
    m:EnableMouse(true); m:SetClampedToScreen(true)
    m:EnableMouseWheel(true); m:SetScript("OnMouseWheel", function() end)   -- the runs under it stay put
    local hd = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hd:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -9); hd:SetJustifyH("LEFT")
    m.head = hd
    local dv = m:CreateTexture(nil, "ARTWORK"); dv:SetTexture(Z.MEDIA .. "divider_gold.tga")
    dv:SetWidth(C.FM_W - 16); dv:SetHeight(12); dv:SetPoint("TOP", m, "TOP", 0, -25)
    m.rows = {}
    table.insert(UISpecialFrames, "AzerlootChronicleFilter")
    C.fmenu = m
  end
  m.head:SetText(AzT("Show runs of"))
  local cls = Z.PlayerClass()
  local ch = C.FilterChoices(cls)
  local y = -38
  for k = 1, math.max(table.getn(ch), table.getn(m.rows)) do
    local r = m.rows[k]
    if not r then
      r = CreateFrame("Button", nil, m)
      r:SetHeight(C.FM_ROW); r:SetWidth(C.FM_W - 16)
      local cur = r:CreateTexture(nil, "BACKGROUND"); cur:SetTexture(Z.WHITE)
      cur:SetVertexColor(0.85, 0.62, 0.15); cur:SetAlpha(0.28); cur:SetAllPoints(r); cur:Hide()
      r.cur = cur
      local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture(Z.WHITE); hl:SetAllPoints(r)
      hl:SetVertexColor(1, 0.8, 0.4); hl:SetAlpha(0.22)
      local num = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      num:SetPoint("LEFT", r, "LEFT", 4, 0); num:SetWidth(14); num:SetJustifyH("CENTER")
      r.num = num
      local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      t:SetPoint("LEFT", r, "LEFT", 22, 0); t:SetWidth(C.FM_W - 46); t:SetHeight(14); t:SetJustifyH("LEFT")
      r.text = t
      r:SetScript("OnClick", function()
        C.filter = this.key or nil
        C.page = 1; C.sel = nil
        C.fmenu:Hide()
        C.Draw()
      end)
      m.rows[k] = r
    end
    local c = ch[k]
    if c then
      if c.gap then y = y - 3 end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", m, "TOPLEFT", 8, y)
      r.num:SetText("")
      if c.head then
        -- a category, as on the builds page: a muted gold heading, not a choice
        r.key = nil
        r.cur:Hide()
        r.text:SetText("|cffbfae8c" .. c.head .. "|r")
        r:EnableMouse(false)
      else
        r.key = c.key
        r:EnableMouse(true)
        r.text:SetText(c.name or "")
        -- numbered: a build by its place, a deleted one after them, all builds without
        if c.place then r.num:SetText("|cffffd100" .. c.place .. "|r")
        elseif c.gone then r.num:SetText("|cff8c8070" .. c.n .. "|r") end
        if c.gone then r.text:SetTextColor(0.6, 0.57, 0.52) else r.text:SetTextColor(1, 1, 1) end
        -- the runs on show now
        if (c.key or nil) == C.filter then r.cur:Show() else r.cur:Hide() end
      end
      r:Show()
      y = y - C.FM_ROW
    else
      r.key = nil
      r:Hide()
    end
  end
  m:SetHeight(-y + 8)
  m:ClearAllPoints(); m:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
  m:Show()
end

-- the runs on show: all, or one build's
function C.Runs(cls)
  local bk = C.Book(cls)
  if not C.filter then return bk.runs end
  local out = {}
  for k = 1, table.getn(bk.runs) do
    local r = bk.runs[k]
    if C.RunKey(r) == C.filter then table.insert(out, r) end
  end
  return out
end

-- ---------- the pages ----------
local function Line(parent, x1, x2, y, a)
  local Z = AZL
  local l = parent:CreateTexture(nil, "ARTWORK"); l:SetTexture(Z.WHITE)
  l:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); l:SetAlpha(a or 0.35); l:SetHeight(1)
  l:SetPoint("LEFT", parent, "TOPLEFT", x1, y); l:SetPoint("RIGHT", parent, "TOPLEFT", x2, y)
  return l
end
-- a heading in the middle of a page, with a fine line to each side
function C.Head(P, page, y)
  local Z = AZL
  local h = Z.Engraved(Z.Heading(Z.Font(P, "GameFontNormal", Z.INK), 15))
  h:SetPoint("TOP", page, "TOPLEFT", PAGE_MID, y)
  local l1, l2 = P:CreateTexture(nil, "ARTWORK"), P:CreateTexture(nil, "ARTWORK")
  for _, l in ipairs({ l1, l2 }) do
    l:SetTexture(Z.WHITE); l:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); l:SetAlpha(0.35); l:SetHeight(1)
  end
  l1:SetPoint("LEFT", page, "TOPLEFT", PAGE_MID - 150, y - 8); l1:SetPoint("RIGHT", h, "LEFT", -8, 0)
  l2:SetPoint("LEFT", h, "RIGHT", 8, 0); l2:SetPoint("RIGHT", page, "TOPLEFT", PAGE_MID + 150, y - 8)
  return h
end

-- a small square icon with a dark rim, and a number under it
function C.Icon(P, size)
  local Z = AZL
  local f = CreateFrame("Frame", nil, P)
  f:SetWidth(size); f:SetHeight(size)
  local rim = f:CreateTexture(nil, "BORDER"); rim:SetTexture(Z.WHITE); rim:SetVertexColor(0.16, 0.09, 0.03)
  rim:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2); rim:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
  local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetAllPoints(f); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.icon = ic
  local n = Z.Engraved(Z.Font(f, "GameFontNormalSmall", Z.INK_SOFT, 10))
  n:SetPoint("TOP", f, "BOTTOM", 0, -3)
  f.num = n
  f:EnableMouse(true)
  f:SetScript("OnEnter", function()
    if not this.tipTitle then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(this.tipTitle, 1, 0.82, 0)
    if this.tipText then GameTooltip:AddLine(this.tipText, 0.85, 0.85, 0.85, 1) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

-- one run in the list: its mark, date, zone, time and level
function C.Row(P)
  local Z = AZL
  local r = CreateFrame("Button", nil, P)
  r:SetWidth(300); r:SetHeight(21)
  local sel = r:CreateTexture(nil, "BACKGROUND"); sel:SetTexture(Z.WHITE)
  sel:SetVertexColor(0.55, 0.32, 0.08); sel:SetAlpha(0.16); sel:SetAllPoints(r); sel:Hide()
  r.sel = sel
  local hv = r:CreateTexture(nil, "BACKGROUND"); hv:SetTexture(Z.WHITE)
  hv:SetVertexColor(0.55, 0.32, 0.08); hv:SetAlpha(0.09); hv:SetAllPoints(r); hv:Hide()
  r.hv = hv
  local mk = r:CreateTexture(nil, "OVERLAY"); mk:SetWidth(16); mk:SetHeight(16)
  mk:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.mark = mk
  local d = Z.Engraved(Z.Font(r, "GameFontNormalSmall", Z.INK_SOFT, 11))
  d:SetPoint("LEFT", r, "LEFT", 26, 0)
  r.date = d
  local z = Z.Engraved(Z.Font(r, "GameFontNormal", Z.INK, 12))
  z:SetPoint("LEFT", r, "LEFT", 70, 0); z:SetWidth(130); z:SetJustifyH("LEFT")
  r.zone = z
  local t = Z.Engraved(Z.Font(r, "GameFontNormal", Z.INK, 12))
  t:SetPoint("RIGHT", r, "RIGHT", -52, 0)
  r.time = t
  local lv = Z.Engraved(Z.Font(r, "GameFontNormalSmall", Z.INK_SOFT, 11))
  lv:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  r.lv = lv
  r:SetScript("OnEnter", function()
    this.hv:Show()
    if this.tag then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.tag, 1, 0.82, 0)
      GameTooltip:AddLine(AzT("Kept for good, until a better run takes its place."), 0.85, 0.85, 0.85, 1)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function() this.hv:Hide(); GameTooltip:Hide() end)
  r:SetScript("OnClick", function() if this.run then C.sel = this.run; C.Draw() end end)
  return r
end
function C.FillRow(r, run)
  r.run = run
  r.date:SetText(C.Date(run.at))
  r.zone:SetText(C.ZoneName(run.zone))
  r.time:SetText(C.Time(run.t))
  r.lv:SetText(run.level and AzT("Lv %d", run.level) or "")
  if run == C.sel then r.sel:Show() else r.sel:Hide() end
end

function C.MakeLeft(P)
  local Z = AZL
  local ui = Z.ui
  local Lf = {}
  C.L = Lf
  Lf.bestHead = C.Head(P, ui.left, -6)
  Lf.bestHead:SetText(AzT("Personal Bests"))
  -- the records: three side by side, three under them
  Lf.recs = {}
  for k = 1, 6 do
    local f = CreateFrame("Frame", nil, P)
    f:SetWidth(110); f:SetHeight(30)
    f:SetPoint("TOP", ui.left, "TOPLEFT", PAGE_MID + (Mod(k - 1, 3) - 1) * 116, -30 - math.floor((k - 1) / 3) * 34)
    local v = Z.Engraved(Z.Heading(Z.Font(f, "GameFontNormal", Z.INK), 16))
    v:SetPoint("TOP", f, "TOP", 0, 0)
    local l = Z.Engraved(Z.Font(f, "GameFontNormalSmall", Z.INK_SOFT, 10))
    l:SetPoint("TOP", v, "BOTTOM", 0, -1)
    f.v, f.l = v, l
    f:EnableMouse(true)
    f:SetScript("OnEnter", function()
      if not this.tip then return end
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine(this.tip[1], 1, 0.82, 0)
      GameTooltip:AddLine(this.tip[2], 0.85, 0.85, 0.85, 1)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Lf.recs[k] = f
  end
  Lf.runsHead = C.Head(P, ui.left, -104)
  Lf.runsHead:SetText(AzT("Runs"))
  -- which runs: all, or one build's (a click goes on to the next build)
  local fb = AzlB.WoodButton(P, AzT("All builds"), function()
    -- a short list to choose from: all builds, yours, then the deleted ones with runs
    C.ToggleFilterMenu(this)
  end, { AzT("Show runs of"), AzT("Click to choose a build: only its runs are shown.") })
  fb:SetPoint("TOPRIGHT", ui.left, "TOPLEFT", PAGE_MID + 150, -122)
  -- a small red arrow at its right: it opens a list
  local ar = fb:CreateTexture(nil, "OVERLAY"); ar:SetTexture(Z.MEDIA .. "arrow_down.tga")
  ar:SetWidth(12); ar:SetHeight(12); ar:SetPoint("RIGHT", fb, "RIGHT", -8, -1)
  fb.arrow = ar
  local setLabel = fb.SetLabel
  fb.SetLabel = function(self, txt, c)
    setLabel(self, txt, c)
    self:SetWidth(self:GetWidth() + 14)
    self.text:ClearAllPoints(); self.text:SetPoint("CENTER", self, "CENTER", -7, 0)
  end
  fb:SetLabel(AzT("All builds"))
  Lf.filter = fb
  local cnt = Z.Engraved(Z.Font(P, "GameFontNormalSmall", Z.INK_SOFT, 11))
  cnt:SetPoint("LEFT", ui.left, "TOPLEFT", PAGE_MID - 150, -134)
  Lf.count = cnt

  -- the best run, always on top: a star, a soft golden shimmer, and a little room below it
  local br = C.Row(P)
  br:SetPoint("TOPLEFT", ui.left, "TOPLEFT", PAGE_MID - 150, -152)
  br:SetHeight(24)
  local sh = br:CreateTexture(nil, "BORDER"); sh:SetTexture(Z.GLOW); sh:SetBlendMode("ADD")
  sh:SetVertexColor(1, 0.72, 0.25); sh:SetPoint("TOPLEFT", br, "TOPLEFT", -6, 5); sh:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", 6, -5)
  br.shine = sh
  local sw = br:CreateTexture(nil, "ARTWORK"); sw:SetTexture(Z.GLOW); sw:SetBlendMode("ADD")
  sw:SetVertexColor(1, 0.9, 0.6); sw:SetWidth(60); sw:SetHeight(24)
  br.sweep = sw
  for side = 1, 2 do
    local e = br:CreateTexture(nil, "ARTWORK"); e:SetTexture(Z.WHITE); e:SetVertexColor(0.78, 0.55, 0.16); e:SetAlpha(0.55); e:SetHeight(1)
    if side == 1 then e:SetPoint("TOPLEFT", br, "TOPLEFT", 0, 0); e:SetPoint("TOPRIGHT", br, "TOPRIGHT", 0, 0)
    else e:SetPoint("BOTTOMLEFT", br, "BOTTOMLEFT", 0, 0); e:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", 0, 0) end
  end
  br.mark:SetTexture(STAR); br.mark:SetWidth(18); br.mark:SetHeight(18)
  br.zone:SetTextColor(0.5, 0.26, 0.02); br.time:SetTextColor(0.5, 0.26, 0.02)
  br.tag = AzT("Best run")
  br:SetScript("OnUpdate", function()
    this.ph = (this.ph or 0) + (arg1 or 0)
    local a = 0.5 + 0.5 * math.sin(this.ph * 2.2)
    this.shine:SetAlpha(0.18 + 0.17 * a)
    -- a light passing over it every few seconds
    local k = Mod(this.ph, 4.5) / 1.4
    if k <= 1 then
      this.sweep:Show(); this.sweep:SetAlpha(0.45 * math.sin(k * math.pi))
      this.sweep:ClearAllPoints(); this.sweep:SetPoint("CENTER", this, "LEFT", k * 300, 0)
    else
      this.sweep:Hide()
    end
  end)
  Lf.bestRow = br

  Lf.rows = {}
  for k = 1, ROWS do
    local r = C.Row(P)
    r:SetPoint("TOPLEFT", ui.left, "TOPLEFT", PAGE_MID - 150, -186 - (k - 1) * 22)
    Lf.rows[k] = r
  end
  -- turning the pages of the list
  local prev = AzlB.WoodButton(P, "<", function() C.page = math.max(1, (C.page or 1) - 1); C.Draw() end)
  prev:SetWidth(30); prev:SetPoint("BOTTOMLEFT", ui.left, "BOTTOMLEFT", PAGE_MID - 80, 2)
  local nxt = AzlB.WoodButton(P, ">", function() C.page = (C.page or 1) + 1; C.Draw() end)
  nxt:SetWidth(30); nxt:SetPoint("BOTTOMRIGHT", ui.left, "BOTTOMLEFT", PAGE_MID + 80, 2)
  local pn = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK, 12))
  pn:SetPoint("BOTTOM", ui.left, "BOTTOMLEFT", PAGE_MID, 8)
  Lf.prev, Lf.next, Lf.pageNum = prev, nxt, pn
  local empty = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_SOFT, 13))
  empty:SetPoint("TOP", ui.left, "TOPLEFT", PAGE_MID, -200); empty:SetWidth(280)
  empty:SetText(AzT("No runs yet. Finish a run, and it is written here."))
  Lf.empty = empty
end

-- where a worn piece sits on the right page, by its slot (neck 2, fingers 11 and 12, trinkets 13 and 14)
C.LOOT_MAX, C.LOOT_ROW = 14, 7   -- boss loot icons: two rows of seven at most
C.JEWEL_POS = { [11] = 1, [12] = 2, [13] = 3, [14] = 4, [2] = 5 }
C.JEWEL_PLACES = {
  { "Ring", false, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
  { "Ring", true, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
  { "Trinket", false, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
  { "Trinket", true, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
  { "Amulet", false, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
}

-- the right page's numbers: label and value, two columns
local SUMMARY = {
  { "Time", function(r)
    -- carried on in endless mode: the official end, then the time fought on
    if r.endless and r.official and tonumber(r.official.t) then
      return C.Time(r.official.t) .. " +" .. C.Time((tonumber(r.t) or 0) - r.official.t)
    end
    return C.Time(r.t)
  end },
  { "Level", function(r) return r.level and tostring(r.level) or "-" end },
  { "Kills", function(r) return C.Big(r.kills) end },
  { "Elites", function(r) return C.Big(r.elites) end },
  { "Guardians", function(r) return C.Big(r.guardians) end },
  { "Bosses", function(r) return C.Big(r.bosses) end },
  { "Damage dealt", function(r) return C.Big(r.dealt) end },
  { "Damage taken", function(r) return C.Big(r.taken) end },
  { "Gold", function(r) return C.Big(r.gold) end },
  { "Caches", function(r) return C.Big(r.caches) end },
}
C.SUMMARY = SUMMARY

-- ---------- the heading's animation ----------
local FX = "Interface\\AddOns\\Azerloot\\media\\textures\\"
-- the drips that run from the band's lower edge: where along the word, how long, how slow, how late
C.DRIPS = {
  { 0.10, 8, 3.6, 0.15 }, { 0.37, 12, 4.4, 0.9 }, { 0.63, 6, 3.2, 1.7 }, { 0.90, 10, 4.0, 0.45 },
}
-- the band is three parts of one texture: its two ends keep their shape, its middle stretches with the word
C.BLOOD_H, C.BLOOD_CAP = 44, 36
-- where fresh drops land: along the band (0 its left, 1 its right end), pixels beside it, above it, size
C.SPATS = {
  { 1, 38, 5, 15 }, { 0, 22, 19, 11 }, { 0, -42, 0, 16 }, { 1, -24, 20, 10 }, { 0.5, 10, 21, 11 }, { 1, 20, 16, 9 },
}
C.SPAT_EVERY = 1.3
local SPARK_X = { 0.08, 0.26, 0.44, 0.6, 0.78, 0.94, 0.35 }
function C.MakeFx(P, word)
  local Z = AZL
  local F = { word = word }
  C.fx = F
  F.band = {}
  local cuts = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
  for k = 1, 3 do
    local b = P:CreateTexture(nil, "BORDER"); b:SetTexture(FX .. "fx_blood.tga")
    b:SetTexCoord(cuts[k][1], cuts[k][2], 0, 1); b:Hide()
    F.band[k] = b
  end
  F.drops = {}
  for k = 1, table.getn(C.DRIPS) do
    local d = P:CreateTexture(nil, "BORDER"); d:SetTexture(FX .. "fx_drop.tga"); d:Hide()
    F.drops[k] = d
  end
  local g = P:CreateTexture(nil, "BORDER"); g:SetTexture(Z.GLOW); g:SetBlendMode("ADD")
  g:SetVertexColor(0.45, 1, 0.45); g:Hide()
  F.glow = g
  F.spats = {}
  for k = 1, 3 do
    local t = P:CreateTexture(nil, "BORDER"); t:SetTexture(FX .. "fx_splat.tga"); t:Hide()
    F.spats[k] = t
  end
  F.sparks = {}
  for k = 1, table.getn(SPARK_X) do
    local t = P:CreateTexture(nil, "ARTWORK"); t:SetTexture(FX .. "fx_spark.tga"); t:SetBlendMode("ADD"); t:Hide()
    F.sparks[k] = t
  end
  local f = CreateFrame("Frame", nil, P)
  f:SetScript("OnUpdate", function() C.FxStep(arg1 or 0) end)
  F.frame = f
  F.t = 0
end
function C.FxSet(mode)
  local F = C.fx
  if not F then return end
  F.mode = mode
  F.t = 0                                        -- each run chosen paints its stroke anew
  -- on the blood the word is set a little smaller, so the band holds it with room around it
  if not F.font then
    local fp, fs, ff = F.word:GetFont()
    F.font = { fp, fs, ff }
  end
  local fp, fs, ff = F.font[1], F.font[2], F.font[3]
  if fp and fs then F.word:SetFont(fp, (mode == "blood") and math.floor(fs * 0.86 + 0.5) or fs, ff) end
  local w = math.max(60, (F.word:GetStringWidth() or 90))
  F.w = w
  F.mw = w + 18                                  -- the middle is as long as the word, in any language
  -- on the blood the word sits 2 px higher; the band and the line under it stay where they were
  local dy = (mode == "blood") and 2 or 0
  local function Lift(f, key, by)
    if not f or not f.GetPoint then return end
    if not F[key] then
      local p, rel, rp, x, y = f:GetPoint(1)
      if type(p) ~= "string" then return end
      F[key] = { p, rel, rp, x or 0, y or 0 }
    end
    local a = F[key]
    f:ClearAllPoints(); f:SetPoint(a[1], a[2], a[3], a[4], a[5] + by)
  end
  Lift(F.word, "wordAt", dy)
  Lift(C.R and C.R.sub, "subAt", -dy)
  local L, M, R = F.band[1], F.band[2], F.band[3]
  M:ClearAllPoints(); M:SetPoint("CENTER", F.word, "CENTER", 0, 1 - dy)
  L:ClearAllPoints(); L:SetPoint("RIGHT", M, "LEFT", 0, 0)
  R:ClearAllPoints(); R:SetPoint("LEFT", M, "RIGHT", 0, 0)
  L:SetWidth(C.BLOOD_CAP); R:SetWidth(C.BLOOD_CAP)
  F.glow:ClearAllPoints(); F.glow:SetPoint("CENTER", F.word, "CENTER", 0, 0)
  F.glow:SetWidth(w + 80); F.glow:SetHeight(50)
  for k = 1, 3 do F.band[k]:Hide() end
  for k = 1, 3 do F.spats[k]:Hide() end
  if mode == "heal" then F.glow:Show() else F.glow:Hide() end
  for k = 1, table.getn(F.drops) do F.drops[k]:Hide() end
  for k = 1, table.getn(F.sparks) do F.sparks[k]:Hide() end
  -- on the blood the word is pale as bone, cut in with a dark edge; elsewhere engraved in ink
  if mode == "blood" then
    F.word:SetTextColor(0.98, 0.92, 0.80); F.word:SetShadowColor(0.15, 0, 0, 1)
  else
    F.word:SetShadowColor(1, 0.95, 0.8, 0.55)
  end
  F.word:SetShadowOffset(1, -1)
end
-- every frame: a stroke of blood is drawn, beats and drips; or small lights rise through the word
function C.FxStep(dt)
  local F = C.fx
  if not F or not F.mode then return end
  F.t = F.t + dt
  local t, w = F.t, F.w or 90
  if F.mode == "blood" then
    local mw = F.mw or (w + 18)
    local r = math.min(1, t / 0.3)               -- the band spreads out from the middle of the word
    r = 1 - (1 - r) * (1 - r)
    local M = F.band[2]
    M:SetWidth(math.max(1, mw * r))
    for k = 1, 3 do
      local b = F.band[k]
      b:SetHeight(C.BLOOD_H); b:SetVertexColor(0.92, 0.9, 0.9); b:SetAlpha(math.min(1, t / 0.12)); b:Show()
    end
    -- fresh drops keep landing around the band: each strikes, spreads a little, and dries away
    local n = math.floor((t - 0.8) / C.SPAT_EVERY)
    for k = 1, 3 do F.spats[k]:Hide() end
    for back = 0, 2 do
      local j = n - back
      if j >= 0 then
        local age = t - 0.8 - j * C.SPAT_EVERY
        local at = C.SPATS[Mod(j, table.getn(C.SPATS)) + 1]
        local tx = F.spats[Mod(j, 3) + 1]
        local grow = (age < 0.08) and (age / 0.08 * 1.2) or ((age < 0.2) and (1.2 - (age - 0.08) / 0.12 * 0.2) or 1)
        local sz = math.max(1, at[4] * grow)
        local a = (age < 1.2) and 1 or math.max(0, 1 - (age - 1.2) / 2.2)
        if a > 0 then
          tx:ClearAllPoints()
          tx:SetPoint("CENTER", M, "LEFT", mw * at[1] + at[2], at[3])
          tx:SetWidth(sz); tx:SetHeight(sz)
          if Mod(j, 2) == 1 then tx:SetTexCoord(1, 0, 0, 1) else tx:SetTexCoord(0, 1, 0, 1) end
          tx:SetAlpha(a); tx:Show()
        end
      end
    end
    for k = 1, table.getn(F.drops) do
      local d, D = F.drops[k], C.DRIPS[k]
      local p = (t - 0.3) / D[3] - D[4] / D[3]
      if p < 0 then
        d:Hide()
      else
        p = Mod(p, 1)
        local q = math.min(1, p / 0.75)          -- thick and slow, as blood runs
        q = 1 - (1 - q) * (1 - q) * (1 - q)
        local len = 2 + (D[2] - 2) * q
        d:ClearAllPoints()
        d:SetPoint("TOP", M, "LEFT", mw * D[1], -11)
        d:SetWidth(4); d:SetHeight(len)
        d:SetTexCoord(0, 1, 1 - math.min(1, len / 16), 1)  -- the bead stays, the trail behind it grows
        d:SetAlpha((p < 0.82) and 0.95 or 0.95 * (1 - (p - 0.82) / 0.18))
        d:Show()
      end
    end
  else
    F.glow:SetAlpha(0.42 + 0.2 * math.sin(t * 2))
    for k = 1, table.getn(F.sparks) do
      local sp = F.sparks[k]
      local p = Mod(t / 2.2 + k * 0.37, 1)
      local sz = 8 + 10 * math.sin(p * math.pi)
      sp:ClearAllPoints()
      sp:SetPoint("CENTER", F.word, "BOTTOMLEFT", w * SPARK_X[k], 2 + p * 30)
      sp:SetWidth(sz); sp:SetHeight(sz)
      sp:SetAlpha(0.9 * math.sin(p * math.pi))
      sp:Show()
    end
  end
end

function C.MakeRight(P)
  local Z = AZL
  local ui = Z.ui
  local R = {}
  C.R = R
  local res = Z.Engraved(Z.Heading(Z.Font(P, "GameFontNormalLarge", Z.INK), 22))
  res:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, -2)
  R.result = res
  local sub = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_SOFT, 12))
  sub:SetPoint("TOP", res, "BOTTOM", 0, -9)   -- room for the effects behind the heading
  R.sub = sub
  -- behind the heading: blood for a run lost, a healing light for one survived
  C.MakeFx(P, res)
  -- the best run's star, beside its heading
  local seal = P:CreateTexture(nil, "OVERLAY"); seal:SetWidth(20); seal:SetHeight(20)
  seal:SetTexture(STAR); seal:SetPoint("LEFT", res, "RIGHT", 6, 1); seal:Hide()
  R.seal = seal

  R.sumHead = C.Head(P, ui.right, -52)
  R.sumHead:SetText(AzT("Summary"))
  -- the run's own numbers, at its end, in the heading's tooltip
  local sh = CreateFrame("Frame", nil, P)
  sh:SetWidth(120); sh:SetHeight(18); sh:SetPoint("CENTER", R.sumHead, "CENTER", 0, 0)
  sh:EnableMouse(true)
  sh:SetScript("OnEnter", function()
    local r = C.sel
    if not (r and r.stats and AzlB.STATS) then return end
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(AzT("Run Stats"), 1, 0.82, 0)
    for k = 1, table.getn(AzlB.STATS) do
      local s = AzlB.STATS[k]
      GameTooltip:AddDoubleLine(AzT(s[1]), s[2](r.stats), 0.85, 0.85, 0.85, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  sh:SetScript("OnLeave", function() GameTooltip:Hide() end)
  R.rows = {}
  for k = 1, table.getn(SUMMARY) do
    local col, row = Mod(k - 1, 2), math.floor((k - 1) / 2)
    local x = PAGE_MID - 150 + col * 160
    local l = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK, 12))
    l:SetPoint("TOPLEFT", ui.right, "TOPLEFT", x, -74 - row * 17)
    local v = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_GOOD, 12))
    v:SetPoint("TOPRIGHT", ui.right, "TOPLEFT", x + 140, -74 - row * 17)
    R.rows[k] = { l = l, v = v }
  end

  R.buildHead = C.Head(P, ui.right, -166)
  local bl = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK, 12))
  bl:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, -188)
  R.buildLine = bl
  R.spells = {}
  for k = 1, 6 do
    local f = C.Icon(P, 28)
    f:SetPoint("TOPLEFT", ui.right, "TOPLEFT", PAGE_MID - 145 + (k - 1) * 50 + 6, -208)
    R.spells[k] = f
  end
  R.jewels = {}
  for k = 1, 5 do
    local f = C.Icon(P, 28)
    f:SetPoint("TOPLEFT", ui.right, "TOPLEFT", PAGE_MID - 119 + (k - 1) * 50 + 6, -258)
    R.jewels[k] = f
  end
  local miss = Z.Font(P, "GameFontNormalSmall", { 0.62, 0.1, 0.06 }, 11)
  miss:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, -304); miss:SetWidth(310)
  R.miss = miss

  R.lootHead = C.Head(P, ui.right, -340)
  R.lootHead:SetText(AzT("Boss Loot"))
  -- the boss loot as icons, side by side and centred, two rows at most
  local lt = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_SOFT, 12))
  lt:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, -368); lt:SetWidth(310)
  R.loot = lt
  R.lootIcons = {}
  for k = 1, C.LOOT_MAX do
    local f = C.Icon(P, 28)
    f:SetScript("OnEnter", function()
      if not this.piece then return end
      local it, c = this.piece, this.rc or { 1, 1, 1 }
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzG(it.name), c[1], c[2], c[3])
      if it.slot then GameTooltip:AddLine(AzG(it.slot), 1, 1, 1) end
      if type(it.bonus) == "table" then
        for i = 1, table.getn(it.bonus) do GameTooltip:AddLine(AzG(it.bonus[i]), 0.12, 1, 0) end
      end
      if this.zoneName then GameTooltip:AddLine(AzG(this.zoneName), 0.6, 0.6, 0.6) end
      if this.isNew then GameTooltip:AddLine(AzT("New in your collection in this run."), 1, 0.82, 0, 1) end
      GameTooltip:Show()
    end)
    -- "New!" at the icon's upper left corner, for a piece this run collected first
    local bd = CreateFrame("Frame", nil, f)
    bd:SetFrameLevel(f:GetFrameLevel() + 3)
    bd:SetWidth(1); bd:SetHeight(1); bd:SetPoint("CENTER", f, "TOPLEFT", 2, -2)
    -- a gold sparkle: drawn plainly, as light added onto the pale page would hardly show
    local burst = bd:CreateTexture(nil, "BACKGROUND"); burst:SetTexture(FX .. "fx_spark.tga")
    burst:SetVertexColor(1, 0.72, 0.1); burst:SetPoint("CENTER", bd, "CENTER", 0, 0)
    local nt = bd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local face = nt:GetFont()
    if face then nt:SetFont(face, 10, "OUTLINE") end
    nt:SetTextColor(0.45, 1, 0.3)
    nt:SetText(AzT("New!"))
    nt:SetPoint("CENTER", bd, "CENTER", 0, 0)
    bd.burst, bd.text = burst, nt
    bd:Hide()
    f.badge = bd
    R.lootIcons[k] = f
  end
  -- the badges breathe: a gold burst pulses behind the word, and the word bobs a little
  local tick = CreateFrame("Frame", nil, P)
  tick:SetScript("OnUpdate", function()
    C.newT = (C.newT or 0) + (arg1 or 0)
    local t = C.newT
    for k = 1, C.LOOT_MAX do
      local b = R.lootIcons[k].badge
      if b:IsShown() then
        local s = math.sin(t * 3 + k * 0.7)
        local sz = 34 + 8 * s
        b.burst:SetWidth(sz); b.burst:SetHeight(sz); b.burst:SetAlpha(0.75 + 0.25 * s)
        b.text:ClearAllPoints(); b.text:SetPoint("CENTER", b, "CENTER", 0, 1 + 1.5 * math.sin(t * 4 + k))
      end
    end
  end)
  local none = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_SOFT, 13))
  none:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, -180); none:SetWidth(280)
  none:SetText(AzT("Choose a run on the left to read it here."))
  R.none = none
end

function C.MakePane()
  if C.pane then return end
  local Z = AZL
  local frame = Z.Frame()
  local P = CreateFrame("Frame", nil, frame)
  Z.OnPage(P)
  P:SetAllPoints(frame)
  P:Hide()
  C.pane = P
  if Z.ui.panes then table.insert(Z.ui.panes, P) end
  C.MakeLeft(P)
  C.MakeRight(P)
end
function C.ShowPane()
  if not C.pane then C.MakePane() end
  C.pane:Show()
  C.Draw()
end
function C.HidePane()
  if C.fmenu then C.fmenu:Hide() end
  if C.pane then C.pane:Hide() end
end
-- opened from a build: its runs only
function C.OpenBuild(i)
  C.filter = C.KeyOfBuild(AZL.PlayerClass(), i)
  C.page = 1
  C.sel = nil
  AZL.state.module = "Chronicle"
  AZL.Refresh()
end

-- ---------- drawing ----------
local REC_LABEL = { t = "Longest run", kills = "Most kills", dealt = "Most damage", level = "Highest level",
  bosses = "Most bosses", gold = "Most gold" }
function C.DrawLeft(cls)
  local Lf = C.L
  local bk = C.Book(cls)
  for k = 1, 6 do
    local f, fld = Lf.recs[k], C.RECORDS[k]
    local rc = bk.rec[fld]
    local v = rc and ((fld == "t") and C.Time(rc.v) or C.Big(rc.v)) or "-"
    f.v:SetText(v); f.l:SetText(AzT(REC_LABEL[fld]))
    f.tip = rc and { AzT(REC_LABEL[fld]), AzT("Set on %s. Kept for good, until you beat it.", C.Date(rc.at, true)) } or nil
  end
  -- the filter's label: all builds or the build shown
  local fname = nil
  if C.filter then
    local list = C.Builds(cls)
    for k = 1, table.getn(list) do if list[k].key == C.filter then fname = list[k].name end end
    -- (a build of yours without runs yet: shown by its name, with an empty list)
    for i = 1, 5 do
      local b = AzlB.Get(cls, i)
      if not fname and b and b.uid == C.filter then fname = b.name end
    end
    if not fname then C.filter = nil end
  end
  Lf.filter:SetLabel(fname and AzlB.Short(fname, 13) or AzT("All builds"))
  local runs = C.Runs(cls)
  local n = table.getn(runs)
  local won = C.CountWon(runs)
  Lf.count:SetText(AzT("%d runs, %d survived, %d fallen", n, won, n - won))
  -- the best run on top (of the build shown, when one is), the others below it
  local best = C.BestOf(cls, runs)
  if best then
    C.FillRow(Lf.bestRow, best)
    Lf.bestRow:Show()
  else
    Lf.bestRow.run = nil
    Lf.bestRow:Hide()
  end
  local rest = {}
  for k = 1, n do
    if not (best and runs[k].id == best.id) then table.insert(rest, runs[k]) end
  end
  local pages = math.max(1, math.ceil(table.getn(rest) / ROWS))
  C.page = math.max(1, math.min(C.page or 1, pages))
  local first = (C.page - 1) * ROWS
  for k = 1, ROWS do
    local r, run = Lf.rows[k], rest[first + k]
    if run then
      C.FillRow(r, run)
      r.mark:SetTexture(run.won and CHECK or SKULL)
      if run.won then r.mark:SetVertexColor(0.1, 0.6, 0.1) else r.mark:SetVertexColor(1, 1, 1) end
      r:Show()
    else
      r.run = nil
      r:Hide()
    end
  end
  Lf.pageNum:SetText(C.page .. " / " .. pages)
  if pages > 1 then Lf.prev:Show(); Lf.next:Show(); Lf.pageNum:Show() else Lf.prev:Hide(); Lf.next:Hide(); Lf.pageNum:Hide() end
  if n == 0 and not best then Lf.empty:Show() else Lf.empty:Hide() end
end
-- the best run: the chronicle's own, kept for good; with a build shown, that build's best
function C.BestOf(cls, runs)
  local bk = C.Book(cls)
  if not C.filter then return bk.best end
  local best = nil
  for k = 1, table.getn(runs) do
    if not best or C.Score(runs[k]) > C.Score(best) then best = runs[k] end
  end
  return best
end
function C.CountWon(runs)
  local w = 0
  for k = 1, table.getn(runs) do if runs[k].won then w = w + 1 end end
  return w
end

function C.DrawRight(cls)
  local Z = AZL
  local R = C.R
  local run = C.sel
  local bk = C.Book(cls)
  local parts = { R.result, R.sub, R.sumHead, R.buildHead, R.buildLine, R.miss, R.lootHead, R.loot }
  if not run then
    for k = 1, table.getn(parts) do parts[k]:Hide() end
    for k = 1, table.getn(R.rows) do R.rows[k].l:Hide(); R.rows[k].v:Hide() end
    for k = 1, 6 do R.spells[k]:Hide() end
    for k = 1, 5 do R.jewels[k]:Hide() end
    for k = 1, C.LOOT_MAX do R.lootIcons[k]:Hide() end
    R.seal:Hide(); R.none:Show()
    C.FxSet(nil)
    return
  end
  R.none:Hide()
  for k = 1, table.getn(parts) do parts[k]:Show() end
  if run.won then
    R.result:SetText(AzT("Survived")); R.result:SetTextColor(0.1, 0.45, 0.04)
  else
    R.result:SetText(AzT("Fallen")); R.result:SetTextColor(0.6, 0.1, 0.05)
  end
  C.FxSet(run.won and "heal" or "blood")
  local best = C.BestOf(cls, C.Runs(cls))
  if best and best.id == run.id then R.seal:Show() else R.seal:Hide() end
  R.sub:SetText(C.ZoneName(run.zone) .. "  ·  " .. C.Date(run.at, true))
  for k = 1, table.getn(SUMMARY) do
    local row = R.rows[k]
    row.l:SetText(AzT(SUMMARY[k][1])); row.v:SetText(SUMMARY[k][2](run))
    -- the numbers in the heading's own ink: green for a run survived, red for one lost
    if run.won then row.v:SetTextColor(0.1, 0.45, 0.04) else row.v:SetTextColor(0.6, 0.1, 0.05) end
    row.l:Show(); row.v:Show()
  end
  -- the build it was played with, and what the hero really had
  if run.build then
    R.buildHead:SetText(AzT("Build"))
    R.buildLine:SetText(AzlB.Short(run.build.name or "", 22) .. "  ·  " .. AzT("%d/%d collected", run.build.got or 0, run.build.all or 0))
  else
    R.buildHead:SetText(AzT("Spells and Jewelry"))
    R.buildLine:SetText(AzT("No build loaded"))
  end
  local sp = run.spells or {}
  for k = 1, 6 do
    local f, s = R.spells[k], sp[k]
    if s then
      local info = C.SpellInfo(cls, s.k)
      f.icon:SetTexture("Interface\\Icons\\" .. (info and info.icon or "INV_Misc_QuestionMark"))
      f.num:SetText((s.r and s.r > 0) and AzT("Rank %s", s.r) or "")
      f.tipTitle = AzG(info and info.name or s.k)
      f.tipText = (s.r and s.r > 0) and AzT("Rank %s at the end of the run.", s.r) or nil
      f:Show()
    else
      f:Hide()
    end
  end
  -- the jewelry in the builds' order: Ring, Ring 2, Trinket, Trinket 2, Amulet
  local jw, at = run.jewels or {}, {}
  for k = 1, table.getn(jw) do
    local pos = C.JEWEL_POS[jw[k].s]
    if pos and not at[pos] then at[pos] = jw[k] end
  end
  for k = 1, 5 do
    local f, j, place = R.jewels[k], at[k], C.JEWEL_PLACES[k]
    f.num:SetText(AzlSlotWord(place[1]) .. (place[2] and " 2" or ""))
    if j then
      -- the picture the game showed for it, else the book's own
      local nm = C.CleanJewel(j.n)
      f.icon:SetTexture(j.ic or ("Interface\\Icons\\" .. C.JewelIcon(nm)))
      f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); f.icon:SetAlpha(1)
      f.tipTitle = j.raw or AzG(nm)
      f.tipText = AzT("Worn at the end of the run.")
    else
      -- an empty place: the game's own empty slot, faint
      f.icon:SetTexture(place[3]); f.icon:SetTexCoord(0, 1, 0, 1); f.icon:SetAlpha(0.45)
      f.tipTitle = AzlSlotWord(place[1]) .. (place[2] and " 2" or "")
      f.tipText = AzT("Empty at the end of the run.")
    end
    f:Show()
  end
  local miss = run.build and run.build.miss or {}
  if table.getn(miss) > 0 then
    local names = {}
    for k = 1, table.getn(miss) do table.insert(names, C.PartName(cls, miss[k])) end
    R.miss:SetText(AzT("Missing from the build:") .. " " .. table.concat(names, ", "))
  elseif run.build then
    R.miss:SetText("|cff1a7310" .. AzT("Every part of the build collected.") .. "|r")
  else
    R.miss:SetText("")
  end
  local loot = run.loot or {}
  local n = math.min(table.getn(loot), C.LOOT_MAX)
  if n > 0 then R.loot:SetText("") else R.loot:SetText(AzT("No boss loot in this run.")) end
  -- each row centred, with the same room to either side
  local per, size, gap = C.LOOT_ROW, 28, 10
  for k = 1, C.LOOT_MAX do
    local f = R.lootIcons[k]
    if k <= n then
      local row = math.floor((k - 1) / per)
      local inRow = math.min(per, n - row * per)
      local col = k - 1 - row * per
      local w = inRow * size + (inRow - 1) * gap
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", Z.ui.right, "TOPLEFT", PAGE_MID - w / 2 + col * (size + gap), -368 - row * (size + 12))
      local piece, zone = C.FindPiece(cls, loot[k])
      f.piece = piece or { name = loot[k] }
      f.zoneName = zone and zone.name
      -- the piece's own quality (a legendary zone's armour is epic), else its zone's
      f.rc = Z.RARITY_COLOR[(piece and piece.rarity) or (zone and zone.rarity) or "Common"] or { 1, 1, 1 }
      f.icon:SetTexture("Interface\\Icons\\" .. ((piece and piece.icon) or "INV_Misc_QuestionMark"))
      f.num:SetText("")
      f.isNew = type(run.lootNew) == "table" and run.lootNew[loot[k]] and true or false
      if f.isNew then f.badge:Show() else f.badge:Hide() end
      f:Show()
    else
      f.piece = nil
      f.isNew = false; f.badge:Hide()
      f:Hide()
    end
  end
end

-- a boss piece by its English name: its entry (icon, slot, bonuses) and the zone it drops in
function C.FindPiece(cls, name)
  local L = Azerloot_Loot
  if not (L and L.drops) then return nil end
  local order = { cls }
  for c in pairs(L.drops) do if c ~= cls then table.insert(order, c) end end
  for o = 1, table.getn(order) do
    local zs = L.drops[order[o]] or {}
    for zi = 1, table.getn(zs) do
      local list = zs[zi]
      for i = 1, table.getn(list) do
        local alts = list[i]
        for a = 1, table.getn(alts) do
          if alts[a].name == name then return alts[a], L.zones and L.zones[zi] end
        end
      end
    end
  end
  return nil
end

function C.Draw()
  if not C.pane then return end
  local cls = AZL.PlayerClass()
  local bk = C.Book(cls)
  -- a run from another class's chronicle, or none yet: the newest
  if C.sel and C.selCls ~= cls then C.sel = nil end
  if not C.sel then
    local runs = C.Runs(cls)
    C.sel = runs[1]
  end
  C.selCls = cls
  C.DrawLeft(cls)
  C.DrawRight(cls)
end

-- ---------- sample runs from a test build: taken out once, the real best run and records kept ----------
function C.ClearDemo(cls)
  local bk = C.Book(cls)
  local keep = {}
  for k = 1, table.getn(bk.runs) do
    if not bk.runs[k].demo then table.insert(keep, bk.runs[k]) end
  end
  bk.runs = keep
  if bk.saved then
    bk.best, bk.rec, bk.n = bk.saved.best, bk.saved.rec or {}, bk.saved.n or 0
    bk.saved = nil
  end
  -- a real run noted while the samples were in: its marks count again
  for k = table.getn(bk.runs), 1, -1 do C.Note(bk, bk.runs[k]) end
  C.sel, C.filter, C.page = nil, nil, 1
end

-- runs left by the game's own button, written down by an earlier version: they go, and the
-- best run and the records they had set are found again among the rest
function C.DropLeft(bk)
  local keep, gone = {}, {}
  for k = 1, table.getn(bk.runs) do
    local r = bk.runs[k]
    if C.Left(r.result) and not r.endless then gone[r.id] = true else table.insert(keep, r) end
  end
  if not next(gone) then return end
  bk.runs = keep
  if bk.best and gone[bk.best.id] then bk.best = nil end
  if type(bk.rec) == "table" then
    for f, rc in pairs(bk.rec) do if type(rc) == "table" and gone[rc.id] then bk.rec[f] = nil end end
  end
  for k = table.getn(keep), 1, -1 do C.Note(bk, keep[k]) end
end

-- at login: any sample runs still in a chronicle go
function C.Tidy()
  if type(AzerlootDB) ~= "table" or type(AzerlootDB.chronicle) ~= "table" then return end
  for cls, bk in pairs(AzerlootDB.chronicle) do
    if type(bk) == "table" and type(bk.runs) == "table" then C.DropLeft(bk) end
  end
  for cls, bk in pairs(AzerlootDB.chronicle) do
    local has = type(bk) == "table" and bk.saved ~= nil
    if type(bk) == "table" and type(bk.runs) == "table" then
      for k = 1, table.getn(bk.runs) do if bk.runs[k].demo then has = true end end
    end
    if has then C.ClearDemo(cls) end
  end
end
local tidy = CreateFrame("Frame")
tidy:RegisterEvent("VARIABLES_LOADED")
tidy:SetScript("OnEvent", function() C.Tidy() end)

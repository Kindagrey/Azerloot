-- Azerloot: builds. Up to five per class: the spells and jewelry planned for a run, with a
-- profile of what the build is strong and weak at. One build is loaded into the wishlist,
-- from the book or with a click when a run begins; builds travel as short text codes.
-- The book's own parts come from Azerloot.lua through the table AZL.

AzlB = {}
local B = AzlB
local MAX = { Spell = 6, Rings = 2, Trinkets = 2, Neck = 1 }
local NBUILDS = 5   -- builds per class
local PAGE_MID = 188 -- the middle of the right page, where its ornament lines sit
local SLOT_NAME = { Spell = "Spells", Rings = "Rings", Trinkets = "Trinkets", Neck = "Amulet" }
-- a jewelry place's short word under its icon: German says "Schmuck" for a trinket there,
-- as "Schmuckstück" and "Schmuckstück 2" run into each other
function AzlSlotWord(w)
  if w == "Trinket" and AzLang and AzLang() == "de" then return "Schmuck" end
  return AzT(w)
end
local SLOT_KINDS = { "Rings", "Rings", "Trinkets", "Trinkets", "Neck" }
local DROP = "Interface\\AddOns\\Azerloot\\media\\textures\\drop.tga"
local PLUS = "Interface\\AddOns\\Azerloot\\media\\textures\\plus.tga"
local BAR_FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local GOOD = { 0.1, 0.5, 0.04 }      -- a strength, in green ink
local BAD = { 0.62, 0.1, 0.06 }      -- a weakness, in red ink

local function Slot(kind)
  if kind == "Amulets" or kind == "Legendary" then return "Neck" end
  return kind
end

-- ---------- the builds, saved per class ----------
function B.All(cls)
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.builds) ~= "table" then AzerlootDB.builds = {} end
  local t = AzerlootDB.builds[cls]
  if type(t) ~= "table" then t = {}; AzerlootDB.builds[cls] = t end
  if type(t.list) ~= "table" then t.list = {} end
  return t
end
function B.Get(cls, i) return B.All(cls).list[i] end
function B.Count(cls)
  local n = 0
  for i = 1, NBUILDS do if B.Get(cls, i) then n = n + 1 end end
  return n
end

-- a build's part: { kind = "Spell" / "Legendary" / "Rings" / "Trinkets" / "Amulets", id }
-- (a spell's key, a class amulet's spell, a piece's English name); keyed as the wishlist is
local function RecKey(rec)
  if rec.kind == "Spell" then return "spell:" .. rec.id end
  if rec.kind == "Legendary" then return "class:" .. rec.id end
  return rec.id
end
B.RecKey = RecKey
local function FromEntry(e)
  if e.kind == "Spell" or e.kind == "Legendary" then return { kind = e.kind, id = e.item.key } end
  return { kind = e.kind, id = e.item.name }
end

-- the book's own entry for a part, or nil when it is not (or no longer) in the book
function B.Entry(cls, rec)
  local Z = AZL
  local all
  if rec.kind == "Spell" then all = Z.SpellEntries(cls)
  elseif rec.kind == "Legendary" then all = Z.ClassEntries(Z.ClassInfo(cls))
  elseif rec.kind == "Rings" or rec.kind == "Trinkets" or rec.kind == "Amulets" then all = Z.ItemEntries(rec.kind)
  else return nil end
  local byKey = (rec.kind == "Spell" or rec.kind == "Legendary")
  for i = 1, table.getn(all) do
    local it = all[i].item
    if (byKey and it.key == rec.id) or ((not byKey) and it.name == rec.id) then return all[i] end
  end
  return nil
end

function B.Has(b, key)
  if not b then return nil end
  for i = 1, table.getn(b.items) do if RecKey(b.items[i]) == key then return i end end
  return nil
end
function B.InSlot(b, slot)
  local out = {}
  for i = 1, table.getn(b.items) do if Slot(b.items[i].kind) == slot then table.insert(out, b.items[i]) end end
  return out
end

-- Every run begins with the class's starting spell (the first of its spells), before any
-- level-up: it is part of every build, in the first spell place, and is not stored with it.
function B.StartKey(cls)
  local info = AZL.ClassInfo(cls)
  local first = info and info.spells and info.spells[1]
  return first and first.key or nil
end
local function IsStart(cls, rec) return rec.kind == "Spell" and rec.id == B.StartKey(cls) end
-- a build's parts with the starting spell first
function B.Items(cls, b)
  local out = {}
  local st = B.StartKey(cls)
  if st then table.insert(out, { kind = "Spell", id = st }) end
  for i = 1, table.getn(b.items) do
    if not IsStart(cls, b.items[i]) then table.insert(out, b.items[i]) end
  end
  return out
end
-- how many spells a build holds, the starting spell counted
function B.SpellCount(cls, b)
  local n = B.StartKey(cls) and 1 or 0
  for i = 1, table.getn(b.items) do
    if b.items[i].kind == "Spell" and not IsStart(cls, b.items[i]) then n = n + 1 end
  end
  return n
end
-- builds from before: their starting spell is taken out, it has its own place now
function B.StripStart()
  if type(AzerlootDB) ~= "table" or type(AzerlootDB.builds) ~= "table" then return end
  for cls, t in pairs(AzerlootDB.builds) do
    if type(t) == "table" and type(t.list) == "table" then
      for i = 1, NBUILDS do
        local b = t.list[i]
        if type(b) == "table" and type(b.items) == "table" then
          for n = table.getn(b.items), 1, -1 do
            if IsStart(cls, b.items[n]) then table.remove(b.items, n) end
          end
        end
      end
    end
  end
end

-- a new build in the first free place; its number
function B.NewAt(cls, i)
  local t = B.All(cls)
  if t.list[i] then return nil end
  t.list[i] = { name = AzT("Build %d", i), spec = math.min(i, 3), note = "", items = {} }
  B.Uid(t.list[i])
  return i
end
-- every build's own mark, kept for its life: the chronicle tells its runs by it, so a new
-- build in the same place (or one imported there) does not take over the old one's runs
function B.Uid(b)
  if type(b) ~= "table" then return nil end
  if type(b.uid) ~= "string" then
    AzerlootDB.buildSeq = (tonumber(AzerlootDB.buildSeq) or 0) + 1
    b.uid = tostring((type(time) == "function" and time()) or 0) .. "-" .. AzerlootDB.buildSeq
  end
  return b.uid
end
function B.New(cls)
  local t = B.All(cls)
  for i = 1, NBUILDS do
    if not t.list[i] then return B.NewAt(cls, i) end
  end
  return nil
end

-- puts a part into build i (in place of `oldKey` if given). Returns true, or nil and the
-- slot when that slot is full.
function B.Add(cls, i, entry, oldKey, pos)
  local b = B.Get(cls, i)
  if not b then return nil end
  local rec = FromEntry(entry)
  if IsStart(cls, rec) then return true end
  if B.Has(b, RecKey(rec)) then return true end
  local at
  if oldKey then
    at = B.Has(b, oldKey)
    if at then
      rec.pos = rec.pos or b.items[at].pos   -- the new part takes the old one's place
      table.remove(b.items, at)
    end
  end
  if pos then rec.pos = pos end
  local slot = Slot(rec.kind)
  local have = (slot == "Spell") and B.SpellCount(cls, b) or table.getn(B.InSlot(b, slot))
  if have >= MAX[slot] then return nil, slot end
  -- a replaced part keeps its place, so the new one shows where the old one was
  if at then table.insert(b.items, at, rec) else table.insert(b.items, rec) end
  B.Changed(cls, i)
  return true
end

function B.Remove(cls, i, key)
  local b = B.Get(cls, i)
  local k = B.Has(b, key)
  if k then table.remove(b.items, k); B.Changed(cls, i) end
end

function B.Delete(cls, i)
  local t = B.All(cls)
  t.list[i] = nil
  if t.active == i then t.active = nil end
  B.Changed(cls, i)
end

-- after any change: the loaded build follows into the wishlist, the pages are drawn again
function B.Changed(cls, i)
  local t = B.All(cls)
  if t.active == i and t.list[i] and cls == AZL.PlayerClass() then B.Apply(cls, i, true) end
  AZL.RefreshTracker()
  if B.pane and B.pane:IsVisible() then B.Draw() end
end

-- Loads build i into the wishlist: its spells and jewelry take the place of the ones there;
-- the wished boss loot stays, and so do the spells learned in this run.
function B.Apply(cls, i, quiet)
  local Z = AZL
  local b = B.Get(cls, i)
  if not b then return end
  local w, auto = Z.Wish(cls), Z.AutoSpells()
  for k in pairs(w) do
    local pre = string.sub(k, 1, 6)
    if pre == "class:" then
      w[k] = nil
    elseif pre == "spell:" then
      local sp = string.sub(k, 7)
      if Z.KnowsSpell(sp) then auto[sp] = "auto" else w[k] = nil; auto[sp] = nil end
    elseif not string.find(k, ":", 1, true) then
      w[k] = nil
    end
  end
  -- (the starting spell needs no wish: every run hands it over, and the window lists it then)
  for n = 1, table.getn(b.items) do
    local rec = b.items[n]
    w[RecKey(rec)] = true
    if rec.kind == "Spell" and auto[rec.id] == "auto" then auto[rec.id] = "hand" end
  end
  B.All(cls).active = i
  AzerlootDB.buildPick = nil
  if not quiet then Z.Print(AzT("build \"%s\" loaded into your wishlist", b.name)) end
  Z.RefreshTracker()
  if Z.Frame() and Z.Frame():IsVisible() then Z.Refresh() end
end

-- parts of the loaded build taken off the wishlist by hand: the wishlist is no longer that
-- build, so it is no longer loaded (the window's head, the chronicle and the "Loaded" button
-- go by it); loading it again brings every part back
function B.Unwished(cls, keys)
  local t = B.All(cls)
  local b = t.active and t.list[t.active]
  if not b then return end
  local mine = {}
  for n = 1, table.getn(b.items or {}) do mine[RecKey(b.items[n])] = true end
  for i = 1, table.getn(keys) do
    if mine[keys[i]] then
      t.active = nil
      return
    end
  end
end

-- how much of a build the run has brought: spells known, jewelry worn or marked found
function B.Progress(cls, b)
  local Z = AZL
  local got, all = 0, 0
  local worn = Z.WornNames()
  local items = B.Items(cls, b)
  for n = 1, table.getn(items) do
    local rec = items[n]
    local e = B.Entry(cls, rec)
    if e then
      all = all + 1
      if rec.kind == "Spell" then
        if Z.KnowsSpell(rec.id) then got = got + 1 end
      elseif Z.IsFound(e, worn) then
        got = got + 1
      end
    end
  end
  return got, all
end

-- the parts of a build this run has not brought yet, as the book's entries
function B.Missing(cls, b)
  local Z = AZL
  local out = {}
  local worn = Z.WornNames()
  local items = B.Items(cls, b)
  for n = 1, table.getn(items) do
    local rec = items[n]
    local e = B.Entry(cls, rec)
    if e then
      local have
      if rec.kind == "Spell" then have = Z.KnowsSpell(rec.id) else have = Z.IsFound(e, worn) end
      if not have then table.insert(out, e) end
    end
  end
  return out
end

-- ---------- the builds a wishlist already held (Azerloot before 2.0) ----------
local function JewelKind(name)
  local D = AZL.D
  local lists = { { "Rings", D.rings }, { "Trinkets", D.trinkets }, { "Amulets", D.amulets } }
  for l = 1, 3 do
    for i = 1, table.getn(lists[l][2]) do if lists[l][2][i].name == name then return lists[l][1] end end
  end
  return nil
end
function B.Migrate()
  if type(AzerlootDB) ~= "table" or AzerlootDB.buildsMade then return end
  AzerlootDB.buildsMade = true
  if type(AzerlootDB.wish) ~= "table" then return end
  for cls, w in pairs(AzerlootDB.wish) do
    if type(w) == "table" then
      local auto = (type(AzerlootDB.autoSpells) == "table" and type(AzerlootDB.autoSpells[cls]) == "table") and AzerlootDB.autoSpells[cls] or {}
      local b = { name = AzT("My wishlist"), spec = 1, note = "", items = {} }
      local count = { Spell = 0, Rings = 0, Trinkets = 0, Neck = 0 }
      local function Put(rec)
        local sl = Slot(rec.kind)
        if B.Entry(cls, rec) and count[sl] < MAX[sl] then count[sl] = count[sl] + 1; table.insert(b.items, rec) end
      end
      local keys = {}
      for k in pairs(w) do table.insert(keys, k) end
      table.sort(keys)
      for n = 1, table.getn(keys) do
        local k = keys[n]
        if string.sub(k, 1, 6) == "class:" then Put({ kind = "Legendary", id = string.sub(k, 7) })
        elseif string.sub(k, 1, 6) == "spell:" then
          local id = string.sub(k, 7)
          if auto[id] ~= "auto" then Put({ kind = "Spell", id = id }) end
        elseif not string.find(k, ":", 1, true) then
          local kind = JewelKind(k)
          if kind then Put({ kind = kind, id = k }) end
        end
      end
      if table.getn(b.items) > 0 then
        local t = B.All(cls)
        if not t.list[1] then t.list[1] = b; t.active = 1 end
      end
    end
  end
end

-- Builds made by 2.0's first days all said "Spec 1": an untouched spec follows the place
function B.MigrateSpecs()
  if type(AzerlootDB) ~= "table" or AzerlootDB.buildSpecs then return end
  AzerlootDB.buildSpecs = true
  if type(AzerlootDB.builds) ~= "table" then return end
  for cls, t in pairs(AzerlootDB.builds) do
    if type(t) == "table" and type(t.list) == "table" then
      for i = 2, 3 do
        local b = t.list[i]
        if type(b) == "table" and (tonumber(b.spec) or 1) == 1 and not b.specSet then b.spec = i end
      end
    end
  end
end

-- the tooltip of a part: its name, kind and everything it gives, then a hint
function B.EntryTip(owner, entry, hint)
  local Z = AZL
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local title, col, sub = Z.EntryTitle(entry)
  GameTooltip:AddLine(title, col[1], col[2], col[3])
  GameTooltip:AddLine(sub, 0.8, 0.8, 0.8)
  local secs = Z.EntrySections(entry, true)
  for n = 1, table.getn(secs) do
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(secs[n][1], 1, 0.82, 0)
    for k = 1, table.getn(secs[n][2]) do
      local l = secs[n][2][k]
      GameTooltip:AddLine(l[1], l[2][1], l[2][2], l[2][3], 1)
    end
  end
  if hint then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, 1)
  end
  GameTooltip:Show()
end

-- ---------- a build's profile: what it is strong and weak at ----------
-- Each spell counts by the kind of spell it is, told by its class amulet (the game gives
-- every kind of spell its own); a few spells that do more or less than their kind are
-- set apart. h: crowds, b: bosses, s: survival, c: control, r: reach in yards.
local KIND = {
  ["Eye of the Splitting Sky"] = { h = 1, b = 3, s = 0, c = 0, r = 30 },
  ["Medallion of the Bladestorm"] = { h = 2, b = 2, s = 0, c = 0, r = 5 },
  ["Heart of the Earthshaker"] = { h = 3, b = 1, s = 0, c = 2, r = 8 },
  ["The Reaper's Amulet"] = { h = 1, b = 3, s = 0, c = 0, r = 5 },
  ["Pendant of the Plague"] = { h = 2, b = 2, s = 0, c = 0, r = 30, dot = true },
  ["Amulet of the Inferno"] = { h = 3, b = 1, s = 0, c = 1, r = 30, area = true },
  ["Breath of the Black Dragon"] = { h = 2, b = 1, s = 0, c = 1, r = 10 },
  ["Charm of the Fated Hour"] = { h = 2, b = 1, s = 0, c = 0, r = 30 },
  ["Stormcaller's Amulet"] = { h = 2, b = 2, s = 0, c = 0, r = 30 },
  ["Talisman of the Tempest"] = { h = 3, b = 1, s = 0, c = 0, r = 30 },
  ["The Eternal Talisman"] = { h = 0, b = 1, s = 2, c = 0, buff = true },
  ["Amulet of the Ancients"] = { h = 2, b = 1, s = 1, c = 0, r = 8 },
}
local OWN = {
  rend = { r = 5 }, rupture = { r = 5 }, consecration = { r = 8 }, immolation_trap = { r = 8 },
  frost_trap = { r = 8, c = 3 }, explosive_trap = { r = 8 }, magma_totem = { r = 8 }, swipe = { r = 5 },
  shred = { r = 5 }, holy_shield = { r = 5, h = 1 }, hunters_mark = { b = 2, h = 1 }, faerie_fire = { b = 2 },
  holy_light = { s = 3, b = 0 }, healing_wave = { s = 3, b = 0 }, regrowth = { s = 3, b = 0 },
  rejuvenation = { s = 3, b = 0 }, renew = { s = 3, b = 0 }, pw_shield = { s = 3, b = 0 },
  ice_barrier = { s = 3, b = 0 }, divine_shield = { s = 3, b = 0 }, lightwell = { s = 2, h = 2 },
  lightning_shield = { s = 1, c = 1, h = 1, b = 0, r = 5 }, thorns = { s = 1, c = 1, h = 1, b = 0, r = 5 },
  battle_shout = { b = 2, h = 1, s = 0 }, adrenaline_rush = { b = 2, h = 1, s = 0 }, slice_and_dice = { b = 2, h = 1, s = 0 },
  entangling_roots = { c = 3 }, frost_nova = { c = 3 }, psychic_scream = { c = 3 }, fear = { c = 3 },
  polymorph = { c = 2 }, hammer_of_justice = { c = 2 }, kidney_shot = { c = 2 }, gouge = { c = 2 },
  shield_slam = { c = 1 }, concussive_shot = { c = 2 }, frost_shock = { c = 1 }, frostbolt = { c = 1 },
  cone_of_cold = { c = 2 }, blizzard = { c = 2 }, hurricane = { c = 1 }, blast_wave = { c = 2 },
  demo_shout = { c = 1 }, death_coil = { c = 1, s = 1 }, drain_life = { s = 1 }, chain_lightning = { h = 3, b = 2 },
  multi_shot = { h = 2, b = 2, r = 35 }, auto_shot = { r = 35 }, aimed_shot = { r = 35 }, volley = { r = 35 },
  pyroblast = { b = 3 }, mind_flay = { r = 20, b = 2 }, searing_totem = { r = 30, h = 1, b = 2 },
  execute = { b = 3 }, eviscerate = { b = 3 }, backstab = { b = 3 },
}
-- the jewelry, by what it gives
local CAT = {
  ["Damage"] = { h = 1, b = 1 }, ["Cooldowns"] = { h = 1, b = 1 }, ["Health"] = { s = 2 },
  ["Critical strike"] = { b = 1, crit = true }, ["Critical damage"] = { b = 2, crit = true },
  ["Damage reduction and health"] = { s = 3 }, ["Regeneration"] = { s = 2 }, ["Leech"] = { s = 2 },
  ["Area of effect"] = { h = 2, area = true }, ["Damage over time speed"] = { h = 1, b = 1, dot = true },
  ["Echo"] = { h = 1, b = 1 }, ["Movement speed"] = { s = 1 }, ["Health per kill"] = { s = 1, h = 1 },
  ["Buff power"] = { b = 1, buff = true }, ["Lives"] = { s = 3 },
}
-- what an effect line adds (basic and class amulets)
local function FromText(t, v)
  local l = string.lower(t)
  if string.find(l, "critical") then v.b = v.b + 1; v.crit = true end
  if string.find(l, "damage reduction") or string.find(l, "max health") or string.find(l, "health per second")
    or string.find(l, "heal") or string.find(l, "shield") or string.find(l, "killing blow leaves") then v.s = v.s + 1 end
  if string.find(l, "explode") or string.find(l, "leap") or string.find(l, "target") or string.find(l, "area")
    or string.find(l, "splash") or string.find(l, "chains") then v.h = v.h + 1 end
  if string.find(l, "stun") then v.c = v.c + 1 end
  if (string.find(l, "%% damage") and not string.find(l, "critical")) or string.find(l, "cooldown")
    or string.find(l, "cast twice") or string.find(l, "strike again") then v.b = v.b + 1 end
end

-- the reach of a spell, read from what it does when the game has shown it ("within 30 yd")
local function Reach(key, base)
  local ok, desc = pcall(AZL.SpellDesc, key)
  if ok and type(desc) == "string" then
    local _, _, yd = string.find(desc, "within (%d+) yd")
    if tonumber(yd) then return tonumber(yd) end
  end
  return base
end

-- how many bosses strike everything close around them
local function CloseBosses()
  if B.close then return B.close end
  local n = 0
  local zones = AZL.LD.zones
  for z = 1, table.getn(zones) do
    for b = 1, table.getn(zones[z].bosses) do
      local ab = zones[z].bosses[b].abilities or {}
      local close = false
      -- (an attack made of steps counts by its steps)
      local function Look(x)
        local k = x.kind
        if k == "nova" or k == "ring" or k == "spin" or k == "knock" or k == "waves" then close = true end
        for s = 1, table.getn(x.steps or {}) do Look(x.steps[s]) end
      end
      for a = 1, table.getn(ab) do Look(ab[a]) end
      if close then n = n + 1 end
    end
  end
  B.close = n
  return n
end

-- The profile: five values from 0 to 1 and a few lines of strengths (+) and weaknesses (-).
function B.Profile(cls, b)
  local Z = AZL
  local v = { h = 0, b = 0, s = 0, c = 0 }
  local reach, nreach, crowd, dots, crits = 0, 0, 0, 0, 0
  local area, dotgear, nspell = false, false, 0
  local info = Z.ClassInfo(cls)
  local items = B.Items(cls, b)
  for n = 1, table.getn(items) do
    local rec = items[n]
    local e = B.Entry(cls, rec)
    if e then
      if rec.kind == "Spell" then
        nspell = nspell + 1
        local k = KIND[e.item.amulet or ""] or { h = 1, b = 1, s = 0, c = 0, r = 20 }
        local o = OWN[rec.id] or {}
        local function P(f) if o[f] ~= nil then return o[f] end return k[f] end
        v.h = v.h + (P("h") or 0); v.b = v.b + (P("b") or 0); v.s = v.s + (P("s") or 0); v.c = v.c + (P("c") or 0)
        if (P("h") or 0) >= 2 then crowd = crowd + 1 end
        if k.dot then dots = dots + 1 end
        local r = P("r")
        if r then reach = reach + Reach(rec.id, r); nreach = nreach + 1 end
      elseif rec.kind == "Rings" or rec.kind == "Trinkets" then
        local c = CAT[e.item.cat or ""] or {}
        v.h = v.h + (c.h or 0); v.b = v.b + (c.b or 0); v.s = v.s + (c.s or 0); v.c = v.c + (c.c or 0)
        if c.crit then crits = crits + 1 end
        if c.area then area = true end
        if c.dot then dotgear = true end
      else
        local t = { h = 0, b = 0, s = 0, c = 0 }
        for x = 1, table.getn(e.item.effects or {}) do FromText(e.item.effects[x], t) end
        v.h = v.h + t.h; v.b = v.b + t.b; v.s = v.s + t.s; v.c = v.c + t.c
        if t.crit then crits = crits + 1 end
      end
    end
  end
  local function Cap(x, top) return math.max(0, math.min(1, x / top)) end
  local avg = nreach > 0 and (reach / nreach) or nil
  local p = {
    crowds = Cap(v.h, 20), bosses = Cap(v.b, 20), survival = Cap(v.s, 14), control = Cap(v.c, 10),
    reach = avg and Cap(avg - 4, 28) or 0,
  }
  -- the lines: strengths first, at most three of each and five in all
  local plus, minus = {}, {}
  local njewel = table.getn(b.items) - nspell
  if table.getn(b.items) == 0 then
    table.insert(minus, AzT("Still empty: click a place above to choose a spell or a piece of jewelry."))
  else
    if p.crowds >= 0.6 then table.insert(plus, AzT("Strong against crowds: %d spells hit many enemies", crowd)) end
    if p.bosses >= 0.6 then table.insert(plus, AzT("Strong against bosses and elites")) end
    if crits >= 2 then table.insert(plus, AzT("Critical synergy: your critical pieces work together")) end
    if dotgear and dots >= 1 then table.insert(plus, AzT("Damage over time synergy: faster ticks for your lasting spells")) end
    if area and crowd >= 2 then table.insert(plus, AzT("Area synergy: wider spells for a crowd build")) end
    if p.survival >= 0.55 then table.insert(plus, AzT("Hard to kill: plenty of health, healing or protection")) end
    if p.control >= 0.45 then table.insert(plus, AzT("Keeps enemies in check: slows, stuns and roots")) end
    if avg and avg >= 25 then table.insert(plus, AzT("Fights from afar")) end
    if nspell > 0 and p.bosses < 0.35 then table.insert(minus, AzT("Little damage against single bosses")) end
    if nspell > 0 and p.crowds < 0.35 then table.insert(minus, AzT("Few spells for the big crowds")) end
    if p.survival < 0.2 then table.insert(minus, AzT("No protection: no health, healing or damage reduction")) end
    if avg and avg <= 10 then table.insert(minus, AzT("Short reach: %d bosses hit everything close to them", CloseBosses())) end
    local open = {}
    local ns = MAX.Spell - B.SpellCount(cls, b)
    if ns > 0 then table.insert(open, ns == 1 and AzT("1 spell") or AzT("%d spells", ns)) end
    local nr = MAX.Rings - table.getn(B.InSlot(b, "Rings"))
    if nr > 0 then table.insert(open, nr == 1 and AzT("1 ring") or AzT("%d rings", nr)) end
    local nt = MAX.Trinkets - table.getn(B.InSlot(b, "Trinkets"))
    if nt > 0 then table.insert(open, nt == 1 and AzT("1 trinket") or AzT("%d trinkets", nt)) end
    if table.getn(B.InSlot(b, "Neck")) == 0 then table.insert(open, AzT("the amulet")) end
    if table.getn(open) > 0 then table.insert(minus, AzT("Still open: %s", table.concat(open, ", "))) end
  end
  local lines = {}
  for i = 1, math.min(3, table.getn(plus)) do table.insert(lines, { "+ " .. plus[i], GOOD }) end
  for i = 1, table.getn(minus) do
    if table.getn(lines) < 5 then table.insert(lines, { "- " .. minus[i], BAD }) end
  end
  return p, lines
end

-- ---------- builds as text: share and import ----------
local function Idx(list, name)
  for i = 1, table.getn(list) do if list[i].name == name then return i end end
  return nil
end
local function Clean(s) return (string.gsub(s or "", "[~|%c]", "")) end
function B.Encode(cls, b)
  local D = AZL.D
  local parts = {}
  for n = 1, table.getn(b.items) do
    local rec = b.items[n]
    local code
    if rec.kind == "Spell" then code = "S." .. rec.id
    elseif rec.kind == "Legendary" then code = "L." .. rec.id
    elseif rec.kind == "Rings" then code = Idx(D.rings, rec.id) and ("R." .. Idx(D.rings, rec.id))
    elseif rec.kind == "Trinkets" then code = Idx(D.trinkets, rec.id) and ("T." .. Idx(D.trinkets, rec.id))
    elseif rec.kind == "Amulets" then code = Idx(D.amulets, rec.id) and ("A." .. Idx(D.amulets, rec.id)) end
    if code then table.insert(parts, code) end
  end
  return "AZL2~" .. cls .. "~" .. Clean(b.name) .. "~" .. (tonumber(b.spec) or 1) .. "~" .. Clean(b.note) .. "~" .. table.concat(parts, ",")
end
-- the class and the build of a code; nil if it is none
function B.Decode(code)
  local D = AZL.D
  code = string.gsub(code or "", "^%s+", "")
  code = string.gsub(code, "%s+$", "")
  local _, _, cls, name, spec, note, list = string.find(code, "^AZL2~(%a+)~([^~]*)~(%d)~([^~]*)~(.*)$")
  if not cls then return nil end
  local b = { name = (name ~= "" and name) or AzT("Shared build"), spec = math.max(1, math.min(3, tonumber(spec) or 1)), note = note, items = {} }
  local count = { Spell = 1, Rings = 0, Trinkets = 0, Neck = 0 }   -- the starting spell is in every build
  for part in (string.gfind or string.gmatch)(list .. ",", "([^,]*),") do
    local _, _, t, id = string.find(part, "^(%a)%.(.+)$")
    local rec
    if t == "S" then rec = { kind = "Spell", id = id }
    elseif t == "L" then rec = { kind = "Legendary", id = id }
    elseif t == "R" and D.rings[tonumber(id) or 0] then rec = { kind = "Rings", id = D.rings[tonumber(id)].name }
    elseif t == "T" and D.trinkets[tonumber(id) or 0] then rec = { kind = "Trinkets", id = D.trinkets[tonumber(id)].name }
    elseif t == "A" and D.amulets[tonumber(id) or 0] then rec = { kind = "Amulets", id = D.amulets[tonumber(id)].name } end
    if rec and B.Entry(cls, rec) and not B.Has(b, RecKey(rec)) and not IsStart(cls, rec) then
      local sl = Slot(rec.kind)
      if count[sl] < MAX[sl] then count[sl] = count[sl] + 1; table.insert(b.items, rec) end
    end
  end
  return cls, b
end

-- ---------- a new run: the builds may be chosen ----------
function B.NewRun()
  if type(AzerlootDB) ~= "table" then return end
  if B.Count(AZL.PlayerClass()) > 0 then AzerlootDB.buildPick = true end
end
-- the choice of a build shows in the wishlist window at a run's start, for two minutes
function B.Picking()
  if type(AzerlootDB) ~= "table" or not AzerlootDB.buildPick then return false end
  if B.Count(AZL.PlayerClass()) == 0 then return false end
  -- opened by a click on the window's head: open until a build is chosen or it is closed
  if AzerlootDB.buildPick == "manual" then return true end
  -- (a level-up's choice of a card or a pause is still the run: the choice stays, rather than
  -- closing and opening again around it)
  local ph = (AzlPhase and AzlPhase()) or (AZS_GetPhase and AZS_GetPhase()) or nil
  if ph ~= "ready" and ph ~= "playing" and ph ~= "choosing" and ph ~= "paused" then return false end
  -- (after a reload the game's clock comes again only later: the warner's kept one meanwhile)
  local ok, t = pcall(function() return (AZS_GetRunTime and AZS_GetRunTime()) or (AzlW and AzlW.RunTime and AzlW.RunTime()) or 0 end)
  if ok and tonumber(t) and tonumber(t) > 120 then AzerlootDB.buildPick = nil; return false end
  return true
end
function B.TrackerWanted() return B.Picking() end
-- the choice a new run opens by itself (not one opened by a click on the window's head):
-- while it waits, the wishlist window shows the choice alone
function B.RunPick() return B.Picking() and AzerlootDB.buildPick == true end
-- the choice of a build, opened by hand (a click on the wishlist window's head); a second
-- click closes it again
function B.OpenPick()
  if type(AzerlootDB) ~= "table" then return end
  if B.Picking() then AzerlootDB.buildPick = nil else AzerlootDB.buildPick = "manual" end
  AZL.RefreshTracker()
end

-- ---------- small parts of the pages ----------
-- a small wooden button with a carved label, like the book's other buttons
local function WoodButton(parent, label, onClick, tip)
  local Z = AZL
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(24)
  Z.DropShadow(b, b, 2, -3, 3, 0.6)
  local bg = Z.Tex(b, "button.tga", "BORDER"); bg:SetAllPoints(b)
  local t = Z.Carved(Z.Font(b, "GameFontNormal", { 0.95, 0.9, 0.78 }, 11))
  t:SetShadowColor(0, 0, 0, 1)
  t:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text = t
  b.SetLabel = function(self, s, c)
    self.text:SetText(s)
    if c then self.text:SetTextColor(c[1], c[2], c[3]) else self.text:SetTextColor(0.95, 0.9, 0.78) end
    self:SetWidth(math.max(54, (self.text:GetStringWidth() or 40) + 26))
  end
  b:SetLabel(label)
  Z.Highlight(b, 0.2, 3)
  b:SetScript("OnClick", onClick)
  if tip then
    b.tip = tip
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine(this.tip[1], 1, 0.82, 0)
      if this.tip[2] then GameTooltip:AddLine(this.tip[2], 0.85, 0.85, 0.85, 1) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end

B.WoodButton = WoodButton

-- A bar in the style of the game's experience bar: a dark trough in a bronze frame, filled
-- with the game's own status bar texture and cut into ten parts by fine dark lines.
local function XPBar(parent, w, h, c)
  local Z = AZL
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(w); f:SetHeight(h)
  local frameT = f:CreateTexture(nil, "BACKGROUND"); frameT:SetTexture(Z.WHITE)
  frameT:SetVertexColor(0.42, 0.3, 0.12)
  frameT:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2); frameT:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
  local inner = f:CreateTexture(nil, "BORDER"); inner:SetTexture(Z.WHITE)
  inner:SetVertexColor(0.1, 0.06, 0.02)
  inner:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1); inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
  local trough = f:CreateTexture(nil, "BORDER"); trough:SetTexture(Z.WHITE)
  trough:SetVertexColor(0.05, 0.04, 0.05); trough:SetAllPoints(f)
  local fill = f:CreateTexture(nil, "ARTWORK"); fill:SetTexture(BAR_FILL)
  fill:SetVertexColor(c[1], c[2], c[3])
  fill:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); fill:SetHeight(h)
  f.fill = fill
  local shine = f:CreateTexture(nil, "OVERLAY"); shine:SetTexture(Z.WHITE)
  shine:SetVertexColor(1, 1, 1); shine:SetAlpha(0.1)
  shine:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); shine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  shine:SetHeight(math.floor(h / 2))
  for k = 1, 9 do
    local tick = f:CreateTexture(nil, "OVERLAY"); tick:SetTexture(Z.WHITE)
    tick:SetVertexColor(0, 0, 0); tick:SetAlpha(0.65)
    tick:SetWidth(1); tick:SetHeight(h)
    tick:SetPoint("TOPLEFT", f, "TOPLEFT", math.floor(w * k / 10), 0)
  end
  -- a soft light that runs along the filled part now and then, as on the game's bars
  local run = f:CreateTexture(nil, "OVERLAY"); run:SetTexture(Z.GLOW); run:SetBlendMode("ADD")
  run:SetVertexColor(1, 0.95, 0.8); run:SetWidth(28); run:SetHeight(h + 6); run:Hide()
  f.run = run
  f.cur, f.target, f.phase = 0, 0, 0
  local function Show(self, v)
    if v <= 0.002 then self.fill:Hide() else self.fill:Show(); self.fill:SetWidth(math.max(1, w * v)) end
  end
  -- the bar eases to its new value instead of jumping there
  f.SetValue = function(self, v)
    self.target = math.max(0, math.min(1, v or 0))
  end
  f.Snap = function(self) self.cur = 0; Show(self, 0) end
  f:SetScript("OnUpdate", function()
    local dt = arg1 or 0
    if math.abs(this.target - this.cur) > 0.001 then
      this.cur = this.cur + (this.target - this.cur) * math.min(1, dt * 5)
      if math.abs(this.target - this.cur) <= 0.001 then this.cur = this.target end
      Show(this, this.cur)
    end
    -- the light: a pass of 1.2 seconds every 4.5, each bar a little after the one above
    this.phase = this.phase + dt
    local t = math.mod(this.phase, 4.5)
    local fw = w * this.cur
    if this.phase > 0 and t < 1.2 and fw > 12 then
      local x = (t / 1.2) * (fw + 28) - 28
      local a = math.sin(t / 1.2 * math.pi) * 0.55
      this.run:ClearAllPoints()
      this.run:SetPoint("LEFT", this, "LEFT", math.max(0, x), 0)
      this.run:SetWidth(math.max(1, math.min(28, fw - math.max(0, x), 28 + x)))
      this.run:SetAlpha(a); this.run:Show()
    else
      this.run:Hide()
    end
  end)
  return f
end

B.XPBar = XPBar   -- (the boss warner's health bar is one of these, in red)

-- a part of a build as an icon set into the page: left-click opens its page, right-click
-- takes it out of the build; an empty one leads to the pages to fill it from
local SLOT_ICON = {
  Spell = "Interface\\PaperDoll\\UI-Backpack-EmptySlot", Rings = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
  Trinkets = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket", Neck = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
}
local function PartSlot(parent, size, clickable)
  local Z = AZL
  local b = CreateFrame(clickable and "Button" or "Frame", nil, parent)
  b:SetWidth(size); b:SetHeight(size)
  local box = Z.SetIcon(b, size)
  box:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon = box.icon
  if clickable then
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- under the mouse a filled place lights up: a warm halo behind it, a gold frame around
    -- it and its picture a touch brighter (drawn by hand: the client's highlight layer does
    -- not wait for the mouse)
    local halo = b:CreateTexture(nil, "BACKGROUND")
    halo:SetTexture(Z.GLOW); halo:SetBlendMode("ADD"); halo:SetVertexColor(1, 0.72, 0.25); halo:SetAlpha(0.7)
    halo:SetPoint("TOPLEFT", b, "TOPLEFT", -12, 12); halo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 12, -12)
    local lit = { halo }
    local function Edge(a1, a2, wd, ht)
      local e = box:CreateTexture(nil, "OVERLAY"); e:SetTexture(Z.WHITE); e:SetVertexColor(1, 0.8, 0.3)
      e:SetPoint(a1, box, a1, 0, 0); e:SetPoint(a2, box, a2, 0, 0)
      if wd then e:SetWidth(wd) else e:SetHeight(ht) end
      table.insert(lit, e)
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, 2); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    Edge("TOPLEFT", "BOTTOMLEFT", 2, nil); Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    local shine = box:CreateTexture(nil, "OVERLAY"); shine:SetTexture(Z.WHITE); shine:SetBlendMode("ADD")
    shine:SetAlpha(0.14); shine:SetAllPoints(box.icon)
    table.insert(lit, shine)
    for k = 1, table.getn(lit) do lit[k]:Hide() end
    b.litParts = lit
    b.Lit = function(self, on)
      on = on and self.entry and true or false
      for k = 1, table.getn(lit) do if on then lit[k]:Show() else lit[k]:Hide() end end
    end
    -- an empty place is filled with its gold +, a filled one is changed by clicking it
    local pl = CreateFrame("Button", nil, b)
    pl:SetWidth(20); pl:SetHeight(20)
    pl:SetPoint("CENTER", b, "CENTER", 0, 0)
    pl:SetFrameLevel(b:GetFrameLevel() + 3)
    local pt = pl:CreateTexture(nil, "OVERLAY"); pt:SetAllPoints(pl); pt:SetTexture(PLUS)
    pl.tex = pt
    pl.slotButton = b
    pl:SetScript("OnEnter", function()
      this.tex:SetVertexColor(1, 1, 0.75); this:SetWidth(22); this:SetHeight(22)
      local sb = this.slotButton
      local what = { Spell = "Empty spell slot", Rings = "Empty ring slot", Trinkets = "Empty trinket slot", Neck = "Empty amulet slot" }
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzT(what[sb.slot] or "Empty spell slot"), 1, 0.82, 0)
      GameTooltip:AddLine(AzT("Click the + to choose one from a short list."), 0.8, 0.8, 0.8, 1)
      GameTooltip:Show()
    end)
    pl:SetScript("OnLeave", function() this.tex:SetVertexColor(0.92, 0.85, 0.7); this:SetWidth(20); this:SetHeight(20); GameTooltip:Hide() end)
    pl:SetScript("OnClick", function() GameTooltip:Hide(); B.OpenPicker(this.slotButton) end)
    pt:SetVertexColor(0.92, 0.85, 0.7)
    pl:Hide()
    b.plus = pl
  end
  b.Fill = function(self, entry, slot)
    self.entry, self.slot = entry or false, slot
    if self.Lit and not entry then self:Lit(false) end
    if entry then
      self.icon:SetTexture("Interface\\Icons\\" .. (entry.item.icon or "INV_Misc_QuestionMark"))
      self.icon:SetVertexColor(1, 1, 1); self.icon:SetAlpha(1)
      if self.plus then self.plus:Hide() end
    else
      self.icon:SetTexture(SLOT_ICON[slot] or SLOT_ICON.Spell)
      self.icon:SetVertexColor(0.55, 0.5, 0.45); self.icon:SetAlpha(self.plus and 0.35 or 0.7)
      if self.plus then self.plus:Show() end
    end
  end
  return b
end

-- ---------- the left page: the hero as the game's character window shows it ----------
-- Gear on both sides of the hero's own model (turned by dragging), the weapons below, and
-- under them the run's numbers that the game sends for its character pane (AZS_STATS).
local DOLL = {
  { 1, "Head", "HEADSLOT" }, { 2, "Neck", "NECKSLOT" }, { 3, "Shoulder", "SHOULDERSLOT" },
  { 5, "Chest", "CHESTSLOT" }, { 9, "Wrists", "WRISTSLOT" }, { 10, "Hands", "HANDSSLOT" },
  { 6, "Waist", "WAISTSLOT" },
  { 7, "Legs", "LEGSSLOT" }, { 8, "Feet", "FEETSLOT" }, { 11, "Finger", "FINGER0SLOT" },
  { 12, "Finger", "FINGER1SLOT" }, { 13, "Trinket", "TRINKET0SLOT" }, { 14, "Trinket", "TRINKET1SLOT" },
  { 16, "MainHand", "MAINHANDSLOT" }, { 17, "SecondaryHand", "SECONDARYHANDSLOT" }, { 18, "Ranged", "RANGEDSLOT" },
}
local SLOT_WORD = {
  HEADSLOT = "Head", NECKSLOT = "Neck", SHOULDERSLOT = "Shoulder", CHESTSLOT = "Chest", WRISTSLOT = "Wrist",
  HANDSSLOT = "Hands", WAISTSLOT = "Waist", LEGSSLOT = "Legs", FEETSLOT = "Feet", FINGER0SLOT = "Finger",
  FINGER1SLOT = "Finger", TRINKET0SLOT = "Trinket", TRINKET1SLOT = "Trinket", MAINHANDSLOT = "Main Hand",
  SECONDARYHANDSLOT = "Off Hand", RANGEDSLOT = "Ranged",
}
local function Pct(v) return string.format("%+.0f%%", (tonumber(v) or 0) * 100) end
local function Num(v) return tonumber(v) or 0 end
-- the twelve numbers of the character pane: label, value, what it means, what the gear adds
local STATS = {
  { "Max Health", function(s) return string.format("%.0f", Num(s.hp)) end, "The most health you can have.",
    function(s) return Num(s.ghp) ~= 0 and string.format("+%.0f", Num(s.ghp)) end },
  { "Damage", function(s) return Pct(Num(s.dmg) - 1) end, "Every spell you cast deals this much more damage. It grows with your level, gear, talents, jewelry and buffs.",
    function(s) return Num(s.gdmg) ~= 0 and Pct(s.gdmg) end },
  { "Haste", function(s) return Pct(1 - Num(s.cd)) end, "Your spells come back this much sooner.",
    function(s) return Num(s.gcd) ~= 0 and Pct(s.gcd) end },
  { "Crit", function(s) return string.format("%.1f%%", Num(s.crit) * 100) end, "The chance a spell strikes critically. Past 100%, the rest adds to your critical damage.",
    function(s) return Num(s.gcrit) ~= 0 and Pct(s.gcrit) end },
  { "Crit Dmg", function(s) return string.format("%.0f%%", Num(s.cm) * 100) end, "A critical strike deals this much of a spell's damage.",
    function(s) return Num(s.gcm) ~= 0 and Pct(s.gcm) end },
  { "Armor", function(s) return string.format("%.0f%%", Num(s.arm) * 100) end, "Damage you take is reduced by this much (60% at most).",
    function(s) return Num(s.garm) ~= 0 and Pct(s.garm) end },
  { "Area", function(s) return Pct(Num(s.area) - 1) end, "Your spells' areas and ranges are this much larger.",
    function(s) return Num(s.garea) ~= 0 and Pct(s.garea) end },
  { "Targets", function(s) return string.format("+%d", Num(s.cnt)) end, "Every spell that picks its targets picks this many more.",
    function(s) return Num(s.gcnt) ~= 0 and string.format("+%d", Num(s.gcnt)) end },
  { "Echo", function(s) return string.format("%.0f%%", Num(s.echo) * 100) end, "The chance a spell strikes twice. Past 100%, every spell strikes twice and the rest is the chance of a third.",
    function(s) return Num(s.gecho) ~= 0 and Pct(s.gecho) end },
  { "Speed", function(s) return Pct(Num(s.spd) - 1) end, "You run this much faster.",
    function(s) return Num(s.gspd) ~= 0 and Pct(s.gspd) end },
  { "Regen", function(s) return string.format("%.1f", Num(s.reg)) end, "Health you regain every second.",
    function(s) return Num(s.greg) ~= 0 and string.format("+%.1f", Num(s.greg)) end },
  { "Pickup", function(s) return AzT("%d yd", math.floor(Num(s.pick) + 0.5)) end, "Experience and gold fly to you from this far.",
    function(s) return Num(s.gpick) ~= 0 and Pct(s.gpick) end },
}
B.STATS = STATS
-- the rest of the run's numbers, for the heading's tooltip (the last ones only once raised)
local MORE = {
  { "Lifesteal", function(s) return string.format("%.1f%%", Num(s.lch) * 100) end, true },
  { "Kill Heal", function(s) return string.format("%.0f", Num(s.heal)) end, true },
  { "Thorns", function(s) return string.format("%.0f%%", Num(s.thn) * 100) end, true },
  { "Lives", function(s) return string.format("%d", Num(s.liv)) end, true },
  { "Experience", function(s) return Pct(Num(s.xp) - 1) end, true },
  { "Gold", function(s) return Pct(Num(s.gold) - 1) end, true },
  { "Luck", function(s) return Pct(s.luck) end, true },
  { "Buff Power", function(s) return Pct(s.bp) end, true },
  { "DoT Stacks", function(s) return string.format("%d", Num(s.dots)) end, true },
  { "DoT Haste", function(s) return Pct(s.doth) end, true },
  { "Vs Elites", function(s) return Pct(s.big) end, "big" },
  { "Execute", function(s) return Pct(s.exe) end, "exe" },
  { "Vs Controlled", function(s) return Pct(s.cc) end, "cc" },
  { "Vs Afflicted", function(s) return Pct(s.dotd) end, "dotd" },
  { "Shielded", function(s) return Pct(s.shd) end, "shd" },
  { "Melee", function(s) return Pct(s.auto) end, "auto" },
  { "Pet Damage", function(s) return Pct(s.pet) end, "pet" },
}
-- The game sends its numbers only now and then (with its character window open, during a
-- run), and a reload forgets them: the last ones it sent are kept per class until new come.
-- the classes with a painted emblem of their own (media\\textures\\emblem_<class>.tga)
local EMBLEM = { warrior = true, paladin = true, hunter = true, rogue = true, priest = true,
  shaman = true, mage = true, warlock = true, druid = true }

local function RunStats()
  local cls = AZL.PlayerClass()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.runStats) ~= "table" then AzerlootDB.runStats = {} end
  if type(AZS_STATS) == "table" and next(AZS_STATS) then
    local copy = {}
    for k, v in pairs(AZS_STATS) do copy[k] = v end
    AzerlootDB.runStats[cls] = copy
    return AZS_STATS, false
  end
  local kept = AzerlootDB.runStats[cls]
  if type(kept) == "table" and next(kept) then return kept, true end
  return nil
end

-- a hover tint of our own: the game's highlight layer does not always wait for the mouse
local function Hover(f, r, g, b, a)
  local t = f:CreateTexture(nil, "BACKGROUND"); t:SetTexture(AZL.WHITE)
  t:SetVertexColor(r, g, b); t:SetAlpha(a); t:SetAllPoints(f); t:Hide()
  f.hover = t
  return t
end
B.Hover = Hover

local function GearSlot(P, d)
  local Z = AZL
  local b = CreateFrame("Button", nil, P)
  b:SetWidth(32); b:SetHeight(32)
  local box = Z.SetIcon(b, 32)
  box:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon = box.icon
  -- a frame in the rarity's colour around a piece (epic purple, rare blue...), drawn on the
  -- icon's own box so nothing covers it, with a soft glow of the same colour behind
  local glow = box:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture(Z.GLOW); glow:SetBlendMode("ADD"); glow:SetAlpha(0.55)
  glow:SetPoint("TOPLEFT", box, "TOPLEFT", -9, 9); glow:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 9, -9)
  local edges = { glow }
  local function Edge(a1, a2, w, h)
    local t = box:CreateTexture(nil, "OVERLAY"); t:SetTexture(Z.WHITE)
    t:SetPoint(a1, box, a1, 0, 0); t:SetPoint(a2, box, a2, 0, 0)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    table.insert(edges, t)
  end
  Edge("TOPLEFT", "TOPRIGHT", nil, 2); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
  Edge("TOPLEFT", "BOTTOMLEFT", 2, nil); Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
  b.rim = {
    SetVertexColor = function(self, r, g, bl) for i = 1, table.getn(edges) do edges[i]:SetVertexColor(r, g, bl) end end,
    Show = function(self) self.shown = true; for i = 1, table.getn(edges) do edges[i]:Show() end end,
    Hide = function(self) self.shown = false; for i = 1, table.getn(edges) do edges[i]:Hide() end end,
  }
  b.rim:Hide()
  Z.Highlight(b, 0.3, -2)
  b.id, b.empty, b.word = d[1], "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. d[2], d[3]
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local has = GetInventoryItemTexture and GetInventoryItemTexture("player", this.id)
    if not (has and GameTooltip.SetInventoryItem and GameTooltip:SetInventoryItem("player", this.id)) then
      local w = getglobal(this.word)
      GameTooltip:SetText(type(w) == "string" and w or AzT(SLOT_WORD[this.word] or "Head"), 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function B.MakeDoll(P)
  local Z = AZL
  local ui = Z.ui
  local D = {}
  B.doll = D
  -- the hero's name, warm like the book's own title: a soft light breathing behind the
  -- word and a glowing contour around every letter
  local nm = Z.Engraved(Z.Heading(Z.Font(P, "GameFontNormalLarge", Z.INK), 24))
  nm:SetPoint("TOP", ui.left, "TOPLEFT", 180, 0)
  D.name = nm
  local ng = P:CreateTexture(nil, "BORDER")
  ng:SetTexture(Z.GLOW); ng:SetBlendMode("ADD"); ng:SetVertexColor(1, 0.62, 0.18)
  ng:SetPoint("TOPLEFT", nm, "TOPLEFT", -30, 12); ng:SetPoint("BOTTOMRIGHT", nm, "BOTTOMRIGHT", 30, -12)
  D.nameGlow = ng
  D.nameRim = {}
  for i = 1, 16 do
    local ang, r = (i - 1) * math.pi / 8, (math.floor(i / 2) * 2 == i) and 2.2 or 1.4
    local f = P:CreateFontString(nil, "BORDER")
    f:SetPoint("CENTER", nm, "CENTER", math.cos(ang) * r, math.sin(ang) * r)
    f:SetTextColor(1, 0.66, 0.2)
    D.nameRim[i] = f
  end
  local lv = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK_SOFT, 12))
  lv:SetPoint("TOP", nm, "BOTTOM", 0, -3)   -- a little room under the name's tall letters
  D.level = lv
  -- the hero, on dark wood like the game's window behind its model
  -- the class's own painted emblem, large on the parchment between the gear, lying on its
  -- soft shadow
  local spot = CreateFrame("Frame", nil, P)
  spot:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 54, -44); spot:SetWidth(252); spot:SetHeight(198)
  D.back = spot
  -- pressed into the page like a seal: a hollow in the parchment lit on its lower right, a
  -- dark line where the rim meets the page, and a soft shadow thrown down and to the right
  local EM = 178
  local sh = P:CreateTexture(nil, "BORDER")
  sh:SetTexture(Z.MEDIA .. "emblem_shadow.tga")
  sh:SetWidth(EM * 256 / 176); sh:SetHeight(EM * 256 / 176); sh:SetPoint("CENTER", spot, "CENTER", 0, 0)
  local lip = P:CreateTexture(nil, "BORDER")
  lip:SetTexture(Z.MEDIA .. "emblem_lip.tga"); lip:SetBlendMode("ADD"); lip:SetAlpha(0.6)
  lip:SetAllPoints(sh)
  local em = P:CreateTexture(nil, "ARTWORK")
  em:SetWidth(EM); em:SetHeight(EM); em:SetPoint("CENTER", spot, "CENTER", 0, 0)
  D.emblem = em
  D.slots = {}
  for k = 1, table.getn(DOLL) do
    local s = GearSlot(P, DOLL[k])
    if k <= 7 then s:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 14, -44 - (k - 1) * 34)
    elseif k <= 13 then s:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 314, -44 - (k - 8) * 34)
    else s:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 128 + (k - 14) * 38, -252) end
    D.slots[k] = s
  end
  -- the run's numbers, two columns
  local sh = Z.Engraved(Z.Heading(Z.Font(P, "GameFontNormal", Z.INK), 15))
  sh:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 22, -300)
  sh:SetText(AzT("Run Stats"))
  local shb = CreateFrame("Frame", nil, P)
  shb:SetPoint("TOPLEFT", sh, "TOPLEFT", -2, 2); shb:SetWidth(120); shb:SetHeight(20)
  shb:EnableMouse(true)
  shb:SetScript("OnEnter", function()
    local s, old = RunStats()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Run Stats"), 1, 0.82, 0)
    if old then GameTooltip:AddLine(AzT("The last numbers the game sent; they change as soon as it sends new ones."), 0.6, 0.6, 0.6, 1) end
    if not s then
      GameTooltip:AddLine(AzT("The game sends these numbers in a run; open your character window once if they stay empty."), 0.85, 0.85, 0.85, 1)
    else
      for i = 1, table.getn(MORE) do
        local r = MORE[i]
        if r[3] == true or Num(s[r[3]]) ~= 0 then GameTooltip:AddDoubleLine(AzT(r[1]), r[2](s), 1, 0.82, 0, 1, 1, 1) end
      end
    end
    GameTooltip:Show()
  end)
  shb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local sd = Z.Tex(P, "divider.tga", "ARTWORK")
  sd:SetWidth(330); sd:SetHeight(16)
  sd:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 15, -314)
  D.rows = {}
  for k = 1, table.getn(STATS) do
    local col = math.floor((k - 1) / 6)
    local row = k - 1 - col * 6
    local r = CreateFrame("Frame", nil, P)
    r:SetWidth(158); r:SetHeight(16)
    r:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 22 + col * 172, -333 - row * 17)
    -- under the mouse: a warm ink wash over the row, a fine gold edge on its left and a line
    -- beneath it, so it reads clearly on the light parchment
    local wash = r:CreateTexture(nil, "BACKGROUND"); wash:SetTexture(Z.WHITE)
    wash:SetVertexColor(0.5, 0.3, 0.08); wash:SetAlpha(0.2); wash:SetAllPoints(r)
    local edge = r:CreateTexture(nil, "BORDER"); edge:SetTexture(Z.WHITE)
    edge:SetVertexColor(0.85, 0.6, 0.15); edge:SetWidth(2)
    edge:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0); edge:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    local under = r:CreateTexture(nil, "BORDER"); under:SetTexture(Z.WHITE)
    under:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); under:SetAlpha(0.45); under:SetHeight(1)
    under:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 0); under:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    r.lit = { wash, edge, under }
    for i = 1, 3 do r.lit[i]:Hide() end
    r.Lit = function(self, on) for i = 1, 3 do if on then self.lit[i]:Show() else self.lit[i]:Hide() end end end
    local lb = Z.Font(r, "GameFontNormal", Z.INK, 12)
    lb:SetPoint("LEFT", r, "LEFT", 4, 0); lb:SetText(AzT(STATS[k][1]))
    lb:SetShadowColor(0, 0, 0, 0); lb:SetShadowOffset(1, -1)
    local v = Z.Font(r, "GameFontNormal", Z.INK, 13)
    v:SetShadowColor(0, 0, 0, 0); v:SetShadowOffset(1, -1)
    v:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.value = v
    r.stat = STATS[k]
    r:EnableMouse(true)
    r:SetScript("OnEnter", function()
      this:Lit(true)
      local s = RunStats()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzT(this.stat[1]) .. (s and (" " .. this.stat[2](s)) or ""), 1, 1, 1)
      GameTooltip:AddLine(AzT(this.stat[3]), 1, 0.82, 0, 1)
      local g = s and this.stat[4](s)
      if g then GameTooltip:AddLine(AzT("Worn gear: %s", g), 0.3, 1, 0.45) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() this:Lit(false); GameTooltip:Hide() end)
    D.rows[k] = r
  end
  -- gear, level and the numbers change while the book is open
  local ev = CreateFrame("Frame", nil, P)
  ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
  ev:RegisterEvent("PLAYER_LEVEL_UP")
  ev:RegisterEvent("UNIT_MODEL_CHANGED")
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" and arg1 ~= "AZS" then return end
    if (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MODEL_CHANGED") and arg1 ~= "player" then return end
    B.dollDirty = true
  end)
end

-- the name's light breathes slowly, as the title's does; the contour follows the name's face
function B.GlowName()
  local D = B.doll
  if not D then return end
  local a = 0.5 + 0.5 * math.sin(GetTime() * 2.2)
  D.nameGlow:SetAlpha(0.28 + 0.3 * a)
  local face, size, flags = D.name:GetFont()
  local text = D.name:GetText() or ""
  for i = 1, 16 do
    local f = D.nameRim[i]
    if face and (f.face ~= face or f.size ~= size or D.rimText ~= text) then
      f:SetFont(face, size, flags); f.face, f.size = face, size; f:SetText(text)
    end
    f:SetAlpha((math.floor(i / 2) * 2 == i and 0.22 or 0.5) * (0.25 + 0.75 * a))
  end
  D.rimText = text
end

function B.DrawDoll()
  local D = B.doll
  if not D then return end
  local Z = AZL
  local cls = Z.PlayerClass()
  D.name:SetText(UnitName and UnitName("player") or "")
  D.rimText = nil   -- the contour takes the name up anew
  local lvl = UnitLevel and UnitLevel("player") or 1
  D.level:SetText(AzT("Level %d %s", tonumber(lvl) or 1, AzG(Z.ClassInfo(cls).name)))
  D.emblem:SetTexture(Z.MEDIA .. "emblem_" .. (EMBLEM[cls] and cls or "warrior") .. ".tga")
  for k = 1, table.getn(D.slots) do
    local b = D.slots[k]
    local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", b.id)
    if type(tex) == "string" then
      b.icon:SetTexture(tex); b.icon:SetVertexColor(1, 1, 1); b.icon:SetAlpha(1)
      local link = GetInventoryItemLink and GetInventoryItemLink("player", b.id)
      local _, _, hex = string.find(type(link) == "string" and link or "", "|c%x%x(%x%x%x%x%x%x)")
      if hex and hex ~= "ffffff" and hex ~= "9d9d9d" then
        b.rim:SetVertexColor(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255)
        b.rim:Show()
      else
        b.rim:Hide()
      end
    else
      b.icon:SetTexture(b.empty); b.icon:SetVertexColor(1, 1, 1); b.icon:SetAlpha(0.85)
      b.rim:Hide()
    end
  end
  local s = RunStats()
  for k = 1, table.getn(D.rows) do
    local r = D.rows[k]
    if s then
      r.value:SetText(r.stat[2](s))
      if r.stat[4](s) then r.value:SetTextColor(0.02, 0.3, 0.01) else r.value:SetTextColor(Z.INK[1], Z.INK[2], Z.INK[3]) end
    else
      r.value:SetText("-"); r.value:SetTextColor(Z.INK_SOFT[1], Z.INK_SOFT[2], Z.INK_SOFT[3])
    end
  end
end

-- ---------- the builds page: the hero on the left, the chosen build on the right ----------
local SEL_EDGE = { 1, 0.75, 0.15 }

function B.MakePane()
  if B.pane then return end
  local Z = AZL
  local ui, frame = Z.ui, Z.Frame()
  local P = CreateFrame("Frame", nil, frame)
  Z.OnPage(P)
  P:SetAllPoints(frame)
  P:Hide()
  B.pane = P
  if ui.panes then table.insert(ui.panes, P) end

  -- LEFT: the hero as in the game's character window: gear, model and the run's numbers
  B.MakeDoll(P)
  P:SetScript("OnUpdate", function()
    if B.dollDirty then B.dollDirty = nil; B.DrawDoll() end
    B.GlowName()
  end)

  -- RIGHT: the chosen build
  local R = {}
  B.R = R
  local area = CreateFrame("Frame", nil, P)
  area:SetAllPoints(frame)
  R.area = area
  local nm = CreateFrame("EditBox", nil, area)
  nm:SetWidth(300); nm:SetHeight(28)
  nm:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -2)
  nm:SetAutoFocus(false); nm:SetMaxLetters(30)
  nm:SetFontObject(GameFontNormalLarge)
  nm:SetFont(Z.HEAD_FONT, 21)
  nm:SetTextColor(Z.INK[1], Z.INK[2], Z.INK[3])
  nm:SetShadowColor(0, 0, 0, 0); nm:SetShadowOffset(1, -1)
  local function SaveName(box)
    local b = B.Get(AZL.PlayerClass(), B.sel or 0)
    local s = string.gsub(box:GetText() or "", "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "[~|]", "")
    if b and s ~= "" and s ~= b.name then b.name = s; B.Changed(AZL.PlayerClass(), B.sel) end
    if b then box:SetText(b.name) end
  end
  nm:SetScript("OnEnterPressed", function() SaveName(this); this:ClearFocus() end)
  nm:SetScript("OnEscapePressed", function()
    local b = B.Get(AZL.PlayerClass(), B.sel or 0)
    if b then this:SetText(b.name) end
    this:ClearFocus()
  end)
  nm:SetScript("OnEditFocusGained", function() this.focus = true end)
  nm:SetScript("OnEditFocusLost", function() this.focus = nil; SaveName(this) end)
  nm:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(AzT("The build's name"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click to rename it, Enter to keep the new name."), 0.85, 0.85, 0.85, 1)
    GameTooltip:Show()
  end)
  nm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  nm.focus = false
  R.name = nm
  -- a field to write in: a faint ink wash behind the name, a firmer line under it and a quill
  local wash = area:CreateTexture(nil, "BORDER"); wash:SetTexture(Z.WHITE)
  wash:SetVertexColor(0.35, 0.22, 0.08); wash:SetAlpha(0.1)
  wash:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -1); wash:SetPoint("BOTTOMRIGHT", ui.right, "TOPRIGHT", -24, -29)
  local ul = area:CreateTexture(nil, "ARTWORK"); ul:SetTexture(Z.WHITE)
  ul:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); ul:SetAlpha(0.45); ul:SetHeight(1)
  ul:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -29); ul:SetPoint("TOPRIGHT", ui.right, "TOPRIGHT", -24, -29)
  local quill = CreateFrame("Button", nil, area)
  quill:SetWidth(22); quill:SetHeight(22)
  quill:SetPoint("BOTTOMRIGHT", ul, "TOPRIGHT", -2, 2)
  local qt = quill:CreateTexture(nil, "ARTWORK"); qt:SetAllPoints(quill)
  qt:SetTexture(Z.MEDIA .. "quill.tga")
  Z.Highlight(quill, 0.4, -2)
  quill:SetScript("OnClick", function() R.name:SetFocus(); R.name:HighlightText() end)
  quill:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(AzT("The build's name"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click to rename it, Enter to keep the new name."), 0.85, 0.85, 0.85, 1)
    GameTooltip:Show()
  end)
  quill:SetScript("OnLeave", function() GameTooltip:Hide() end)
  nm:SetWidth(296)

  -- the five builds, one button each (an empty place starts a new one), then the talents
  local sl = Z.Engraved(Z.Font(P, "GameFontNormal", Z.INK, 13))
  sl:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -44)
  sl:SetText(AzT("Build"))
  R.buildLabel = sl
  R.builds = {}
  for k = 1, NBUILDS do
    local b = WoodButton(P, tostring(k), function()
      local cls = AZL.PlayerClass()
      if arg1 == "RightButton" then
        if AzlC and B.Get(cls, this.place) then AzlC.OpenBuild(this.place) end
        return
      end
      if not B.Get(cls, this.place) then
        B.NewAt(cls, this.place)
        if not B.All(cls).active then B.Apply(cls, this.place, true) end
      end
      B.ClosePicker()
      B.sel = this.place
      B.Draw()
    end)
    b.place = k
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetWidth(26); b:SetHeight(20)
    b:SetPoint("LEFT", sl, "RIGHT", 8 + (k - 1) * 30, 0)
    b:SetScript("OnEnter", function()
      local cls = AZL.PlayerClass()
      local bd = B.Get(cls, this.place)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      if bd then
        GameTooltip:AddLine(bd.name, 1, 0.82, 0)
        if (bd.note or "") ~= "" then GameTooltip:AddLine(bd.note, 0.85, 0.85, 0.85) end
        if B.All(cls).active == this.place then GameTooltip:AddLine(AzT("Loaded into your wishlist"), 0.3, 1, 0.45) end
        -- how it has done in the chronicle
        if AzlC then
          local n, won, best = AzlC.BuildRecord(cls, this.place)
          if n > 0 then
            GameTooltip:AddLine(AzT("%d runs, %d survived, best %s", n, won, AzlC.Time(best)), 0.95, 0.8, 0.5)
            GameTooltip:AddLine(AzT("Right-click: its runs in the chronicle"), 0.6, 0.6, 0.6)
          end
        end
      else
        GameTooltip:AddLine(AzT("Build %d", this.place), 1, 0.82, 0)
        GameTooltip:AddLine(AzT("Empty: click to start a new build here."), 0.85, 0.85, 0.85, 1)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- the wax seal of the build loaded into the wishlist
    local seal = b:CreateTexture(nil, "OVERLAY")
    seal:SetWidth(16); seal:SetHeight(16)
    seal:SetPoint("CENTER", b, "TOPRIGHT", -2, -1)
    seal:SetTexture(Z.RIBBON); seal:Hide()
    b.seal = seal
    R.builds[k] = b
  end
  local nt = CreateFrame("EditBox", nil, area)
  nt:SetWidth(108); nt:SetHeight(20)
  nt:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 238, -40)
  nt:SetAutoFocus(false); nt:SetMaxLetters(40)
  nt:SetFontObject(GameFontNormal)
  nt:SetFont(Z.FONT, 12)
  nt:SetTextColor(Z.INK_SOFT[1], Z.INK_SOFT[2], Z.INK_SOFT[3])
  nt:SetShadowColor(0, 0, 0, 0)
  local nul = area:CreateTexture(nil, "ARTWORK"); nul:SetTexture(Z.WHITE)
  nul:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); nul:SetAlpha(0.18); nul:SetHeight(1)
  nul:SetPoint("TOPLEFT", nt, "BOTTOMLEFT", 0, 1); nul:SetPoint("TOPRIGHT", nt, "BOTTOMRIGHT", 0, 1)
  local ph = Z.Font(area, "GameFontNormal", { 0.5, 0.42, 0.32 }, 12)
  ph:SetPoint("LEFT", nt, "LEFT", 0, 0)
  ph:SetText(AzT("Talents, e.g. 31/0/20"))
  R.notePH = ph
  local function SaveNote(box)
    local b = B.Get(AZL.PlayerClass(), B.sel or 0)
    local s = string.gsub(box:GetText() or "", "[~|]", "")
    if b and s ~= (b.note or "") then b.note = s; B.Changed(AZL.PlayerClass(), B.sel) end
  end
  nt:SetScript("OnEnterPressed", function() SaveNote(this); this:ClearFocus() end)
  nt:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  nt:SetScript("OnEditFocusGained", function() this.focus = true; R.notePH:Hide() end)
  nt:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(AzT("Talents"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("The talent points this build is meant for, e.g. 31/0/20. Azerloot cannot read your talents: it is your own note."), 0.85, 0.85, 0.85, 1)
    GameTooltip:Show()
  end)
  nt:SetScript("OnLeave", function() GameTooltip:Hide() end)
  nt:SetScript("OnEditFocusLost", function()
    this.focus = nil
    SaveNote(this)
    if (this:GetText() or "") == "" then R.notePH:Show() end
  end)
  nt.focus = false
  R.note = nt
  local d1 = Z.Tex(area, "divider.tga", "ARTWORK")
  d1:SetWidth(330); d1:SetHeight(16)
  d1:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -62)

  -- the parts: six spells, then the jewelry (two rings, two trinkets, one amulet)
  local function CenteredHead(y)
    local h = Z.Engraved(Z.Heading(Z.Font(area, "GameFontNormal", Z.INK), 15))
    h:SetPoint("TOP", ui.right, "TOPLEFT", PAGE_MID, y)
    for side = 1, 2 do
      local l = area:CreateTexture(nil, "ARTWORK"); l:SetTexture(Z.WHITE)
      l:SetVertexColor(Z.INK[1], Z.INK[2], Z.INK[3]); l:SetAlpha(0.35); l:SetHeight(1)
      if side == 1 then
        l:SetPoint("LEFT", ui.right, "TOPLEFT", PAGE_MID - 150, y - 8); l:SetPoint("RIGHT", h, "LEFT", -8, 0)
      else
        l:SetPoint("LEFT", h, "RIGHT", 8, 0); l:SetPoint("RIGHT", ui.right, "TOPLEFT", PAGE_MID + 150, y - 8)
      end
    end
    return h
  end
  R.spellHead = CenteredHead(-76)
  R.jewelHead = CenteredHead(-136)
  R.parts = {}
  for k = 1, 11 do
    local s = PartSlot(area, 30, true)
    s.place = (k <= 6) and k or (k - 6)
    -- centred on the page; each jewel stands between two spells, as in a triangle
    if k <= 6 then
      s:SetPoint("TOPLEFT", ui.right, "TOPLEFT", PAGE_MID - 145 + (k - 1) * 52, -98)
    else
      s:SetPoint("TOPLEFT", ui.right, "TOPLEFT", PAGE_MID - 119 + (k - 7) * 52, -158)
    end
    s:SetScript("OnClick", function()
      local cls = AZL.PlayerClass()
      if this.locked then return end   -- the starting spell stays
      if arg1 == "RightButton" then
        B.ClosePicker()
        if this.entry then B.Remove(cls, B.sel, AZL.WishKey(this.entry)) end
        GameTooltip:Hide()
        return
      end
      if not this.entry then return end   -- an empty place opens with its +
      if IsShiftKeyDown and IsShiftKeyDown() then B.ClosePicker(); B.OpenPage(this.entry, this.slot); return end
      GameTooltip:Hide()
      B.OpenPicker(this)
    end)
    s:SetScript("OnEnter", function()
      this:Lit(true)
      if B.picker and B.picker:IsVisible() and B.picker.owner == this then return end
      if this.locked and this.entry then
        B.EntryTip(this, this.entry, AzT("Your starting spell: every run begins with it, so it is part of every build. A spell your talents give you at the start as well (Moonfire with 31 points in Balance, say) goes in one of the other places."))
      elseif this.entry then
        B.EntryTip(this, this.entry, AzT("Click to choose another, or None to empty the place. Right-click takes it out too. Shift-click opens its page in the book."))
      else
        local what = { Spell = "Empty spell slot", Rings = "Empty ring slot", Trinkets = "Empty trinket slot", Neck = "Empty amulet slot" }
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AzT(what[this.slot] or "Empty spell slot"), 1, 0.82, 0)
        GameTooltip:AddLine(AzT("Click the + to choose one from a short list."), 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
      end
    end)
    s:SetScript("OnLeave", function() this:Lit(false); GameTooltip:Hide() end)
    if k > 6 then
      local cap = Z.Font(area, "GameFontNormalSmall", Z.INK_SOFT, 10)
      cap:SetPoint("TOP", s, "BOTTOM", 0, -4); cap:SetWidth(62)
      -- the second ring and trinket carry a 2, so the pairs tell apart
      local caps = { "Ring", "Ring", "Trinket", "Trinket", "Amulet" }
      local two = { false, " 2", false, " 2", false }
      cap:SetText(AzlSlotWord(caps[k - 6]) .. (two[k - 6] or ""))
    end
    s.locked = false
    if k == 1 then
      -- the starting spell's place: a small gold word under it, and no + or list
      local tag = CreateFrame("Frame", nil, s)
      tag:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 0, 0); tag:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 0, 0)
      tag:SetHeight(11); tag:SetFrameLevel(s:GetFrameLevel() + 4)
      local tb = tag:CreateTexture(nil, "BACKGROUND"); tb:SetTexture(Z.WHITE); tb:SetAllPoints(tag)
      tb:SetVertexColor(0, 0, 0); tb:SetAlpha(0.7)
      local st = tag:CreateFontString(nil, "OVERLAY")
      st:SetFont(Z.FONT, 9, "OUTLINE"); st:SetTextColor(1, 0.82, 0)
      st:SetPoint("CENTER", tag, "CENTER", 0, 0)
      st:SetText(AzT("Start"))
      s.startTag = tag
    end
    R.parts[k] = s
  end
  local d2 = Z.Tex(area, "divider.tga", "ARTWORK")
  d2:SetWidth(330); d2:SetHeight(16)
  d2:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -202)

  -- the profile: five bars in the style of the experience bar
  -- centred between two ink lines, as Spells and Jewelry; the bars begin 3 px below it
  local ph2 = CenteredHead(-217)
  ph2:SetText(AzT("Battle Traits"))
  local AXES = {
    { "crowds", "Crowds", { 0.92, 0.45, 0.1 }, "How well it clears the big crowds: spells that hit many enemies, areas, explosions." },
    { "bosses", "Bosses", { 0.62, 0.18, 0.82 }, "How well it brings down a single boss or elite: strong single hits, critical strikes." },
    { "survival", "Survival", { 0.2, 0.68, 0.16 }, "How long it keeps you alive: health, healing, shields and damage reduction." },
    { "control", "Control", { 0.22, 0.5, 0.95 }, "How well it keeps enemies off you: slows, stuns, roots and fear." },
    { "reach", "Reach", { 0.85, 0.68, 0.12 }, "How far away its spells hit: long reach lets you fight from a safe distance." },
  }
  R.bars = {}
  for k = 1, 5 do
    local y = -239 - (k - 1) * 15
    local lb = Z.Engraved(Z.Font(area, "GameFontNormal", Z.INK, 12))
    lb:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 30, y)
    lb:SetText(AzT(AXES[k][2]))
    local bar = XPBar(area, 214, 10, AXES[k][3])
    bar:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 128, y - 2)
    local hit = CreateFrame("Frame", nil, area)
    hit:SetPoint("TOPLEFT", lb, "TOPLEFT", -2, 2); hit:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -3)
    hit:EnableMouse(true)
    hit.tip = AXES[k]
    hit:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzT(this.tip[2]), 1, 0.82, 0)
      GameTooltip:AddLine(AzT(this.tip[4]), 0.85, 0.85, 0.85, 1)
      GameTooltip:AddLine(AzT("An estimate from the build's parts, not an exact count of damage."), 0.6, 0.6, 0.6, 1)
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.key = AXES[k][1]
    bar.phase = -0.35 * (k - 1)   -- the light runs down the bars one after another
    R.bars[k] = bar
  end
  -- the same for the strengths and weaknesses; their lines begin 3 px below it
  local sh = CenteredHead(-320)
  sh:SetText(AzT("Strengths and weaknesses"))
  R.lines = {}
  for k = 1, 5 do
    local l = Z.Font(area, "GameFontNormal", Z.INK, 11)
    if k == 1 then l:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 30, -339)
    else l:SetPoint("TOPLEFT", R.lines[k - 1], "BOTTOMLEFT", 0, -2) end
    l:SetWidth(318); l:SetJustifyH("LEFT")
    l:SetShadowColor(0, 0, 0, 0); l:SetShadowOffset(1, -1)
    R.lines[k] = l
  end

  -- the buttons at the foot of the page
  R.load = WoodButton(area, AzT("Load into wishlist"), function()
    local cls = AZL.PlayerClass()
    if B.Get(cls, B.sel or 0) then B.Apply(cls, B.sel) end
  end, { AzT("Load into wishlist"), AzT("Its spells and jewelry take the place of those on your wishlist; your wished boss loot stays.") })
  R.load:SetPoint("BOTTOMLEFT", ui.right, "BOTTOMLEFT", 24, 1)
  R.share = WoodButton(area, AzT("Share"), function() B.Popup("share") end,
    { AzT("Share"), AzT("A short code for this build, to post anywhere. Others import it with the Import button.") })
  R.share:SetPoint("LEFT", R.load, "RIGHT", 6, 0)
  R.import = WoodButton(area, AzT("Import"), function() B.Popup("import") end,
    { AzT("Import"), AzT("Paste a build code from another player into this place.") })
  R.import:SetPoint("LEFT", R.share, "RIGHT", 6, 0)
  R.del = WoodButton(area, AzT("Delete"), function()
    if not this.armed then
      this.armed = 3
      this:SetLabel(AzT("Click again"), { 1, 0.45, 0.35 })
      B.FitButtons()
      return
    end
    this.armed = false
    this:SetLabel(AzT("Delete"))
    local cls = AZL.PlayerClass()
    if B.Get(cls, B.sel or 0) then B.Delete(cls, B.sel) end
  end, { AzT("Delete"), AzT("Deletes this build. Click twice within 3 seconds to confirm.") })
  R.del:SetPoint("LEFT", R.import, "RIGHT", 6, 0)
  R.del.armed = false
  R.del:SetScript("OnUpdate", function()
    if not this.armed then return end
    this.armed = this.armed - (arg1 or 0)
    if this.armed <= 0 then this.armed = false; this:SetLabel(AzT("Delete")); B.FitButtons() end
  end)
  -- with no build chosen: a few words instead
  local em = Z.Font(P, "GameFontNormal", Z.INK_SOFT, 14)
  em:SetPoint("CENTER", ui.right, "CENTER", 0, 30)
  em:SetWidth(300)
  R.empty = em
  local ib = WoodButton(P, AzT("Import"), function() B.Popup("import") end,
    { AzT("Import"), AzT("Paste a build code from another player into this place.") })
  ib:SetPoint("TOP", em, "BOTTOM", 0, -14)
  R.emptyImport = ib
end

function B.ShowPane()
  if not B.pane then B.MakePane() end
  if not B.pane then return end
  local opening = not B.pane:IsShown()
  B.pane:Show()
  -- opened anew: the profile's bars grow from empty
  if opening and B.R and B.R.bars then for k = 1, table.getn(B.R.bars) do B.R.bars[k]:Snap() end end
  B.Draw()
end
function B.HidePane()
  if B.picker and B.picker:IsVisible() then B.CloseMenu() end
  if B.pane then B.pane:Hide() end
end

-- opens the page of a part, or the pages to choose a part for an empty place from
function B.OpenPage(entry, slot)
  local Z = AZL
  local st = Z.state
  st.search = ""
  if Z.ui.search then Z.ui.search:SetText(""); Z.ui.search:ClearFocus() end
  st.offset = 0
  st.selected = nil
  if (entry and entry.kind == "Spell") or ((not entry) and slot == "Spell") then
    st.module = "Spells"; st.view = "Spells"; st.class = Z.PlayerClass()
    if entry then
      local all = Z.SpellEntries(st.class)
      for k = 1, table.getn(all) do
        if all[k].item.key == entry.item.key then st.selected = all[k]; st.offset = math.floor((k - 1) / Z.ROWS) * Z.ROWS end
      end
    end
  else
    local view = entry and entry.kind or ((slot == "Neck") and "Amulets" or slot)
    st.module = "Jewelry"; st.view = view
    if view == "Legendary" then st.class = Z.PlayerClass() end
    if entry then
      local all = (view == "Legendary") and Z.ClassEntries(Z.ClassInfo(Z.PlayerClass())) or Z.ItemEntries(view)
      for k = 1, table.getn(all) do
        if Z.WishKey(all[k]) == Z.WishKey(entry) then st.selected = all[k]; st.offset = math.floor((k - 1) / Z.ROWS) * Z.ROWS end
      end
    end
  end
  Z.Refresh()
end

local function Short(s, n)
  if string.len(s or "") <= n then return s or "" end
  return string.sub(s, 1, n - 3) .. "..."
end
B.Short = Short

-- the parts of a build in their places: spells, then rings, trinkets and amulet
-- The parts of a build in their places: the starting spell, five spells, then two rings, two
-- trinkets and the amulet. Every part keeps the place it was put in (rec.pos), so taking one
-- out leaves that very place empty and nothing moves up; a part without a place yet gets the
-- first free one of its kind, and keeps it from then on.
local JEWEL_PLACES = { Rings = { 1, 2 }, Trinkets = { 3, 4 }, Neck = { 5 } }
local function Places(cls, b)
  local spells, jewel = {}, {}
  for k = 1, 6 do spells[k] = false end
  for k = 1, 5 do jewel[k] = false end
  if not b then return spells, jewel end
  local st = B.StartKey(cls)
  if st then spells[1] = B.Entry(cls, { kind = "Spell", id = st }) or false end
  local waiting = {}
  -- first the parts that have a place of their own
  for n = 1, table.getn(b.items) do
    local rec = b.items[n]
    if not IsStart(cls, rec) then
      local e = B.Entry(cls, rec)
      if e then
        local p = tonumber(rec.pos)
        if rec.kind == "Spell" then
          if p and p >= 2 and p <= 6 and not spells[p] then spells[p] = e else table.insert(waiting, { rec, e }) end
        else
          local ok = false
          local places = JEWEL_PLACES[Slot(rec.kind)] or {}
          for k = 1, table.getn(places) do if places[k] == p then ok = true end end
          if ok and not jewel[p] then jewel[p] = e else table.insert(waiting, { rec, e }) end
        end
      end
    end
  end
  -- then the others, each into the first free place of its kind, which it keeps
  for n = 1, table.getn(waiting) do
    local rec, e = waiting[n][1], waiting[n][2]
    if rec.kind == "Spell" then
      for k = 2, 6 do
        if not spells[k] then spells[k] = e; rec.pos = k; break end
      end
    else
      local places = JEWEL_PLACES[Slot(rec.kind)] or {}
      for k = 1, table.getn(places) do
        local p = places[k]
        if not jewel[p] then jewel[p] = e; rec.pos = p; break end
      end
    end
  end
  return spells, jewel
end

function B.Draw()
  if not B.pane then return end
  local Z = AZL
  local cls = Z.PlayerClass()
  local t = B.All(cls)
  if B.sel and not t.list[B.sel] then B.sel = nil end
  if not B.sel then
    B.sel = t.active
    if not (B.sel and t.list[B.sel]) then
      B.sel = nil
      for i = 1, NBUILDS do if not B.sel and t.list[i] then B.sel = i end end
    end
  end
  B.DrawDoll()
  local R = B.R
  local ui = Z.ui
  for k = 1, NBUILDS do
    local btn, bd = R.builds[k], t.list[k]
    if B.sel == k then btn:SetLabel(tostring(k), { 1, 0.82, 0 }); btn:SetAlpha(1)
    elseif bd then btn:SetLabel(tostring(k)); btn:SetAlpha(0.8)
    else btn:SetLabel(tostring(k), { 0.6, 0.55, 0.48 }); btn:SetAlpha(0.45) end
    btn:SetWidth(26)
    if bd and t.active == k then btn.seal:Show() else btn.seal:Hide() end
  end
  local b = B.sel and t.list[B.sel]
  if not b then
    R.area:Hide()
    R.empty:SetText(AzT("A build plans a run: up to six spells, two rings, two trinkets and an amulet.\n\nClick a number above to start one, up to five. Then click its places to choose spells and jewelry from a short list.\n\nWhen a run begins, the wishlist window lets you load one with a single click."))
    R.empty:Show(); R.emptyImport:Show()
    return
  end
  R.empty:Hide(); R.emptyImport:Hide()
  R.area:Show()
  if not R.name.focus then R.name:SetText(b.name) end
  if not R.note.focus then
    R.note:SetText(b.note or "")
    if (b.note or "") == "" then R.notePH:Show() else R.notePH:Hide() end
  end
  local spells, jewel = Places(cls, b)
  local ns = 0
  for k = 1, 6 do if spells[k] then ns = ns + 1 end end
  R.spellHead:SetText(AzT("Spells") .. "  " .. ns .. "/" .. MAX.Spell)
  local nj = 0
  for k = 1, 5 do if jewel[k] then nj = nj + 1 end end
  R.jewelHead:SetText(AzT("Jewelry") .. "  " .. nj .. "/5")
  for k = 1, 6 do R.parts[k]:Fill(spells[k], "Spell") end
  -- the first place holds the starting spell for good
  local st = B.StartKey(cls)
  local p1 = R.parts[1]
  p1.locked = (st ~= nil and spells[1] and spells[1].item.key == st) and true or false
  if p1.locked then p1.startTag:Show(); if p1.plus then p1.plus:Hide() end else p1.startTag:Hide() end
  for k = 1, 5 do R.parts[6 + k]:Fill(jewel[k] or nil, SLOT_KINDS[k]) end
  local p, lines = B.Profile(cls, b)
  for k = 1, 5 do R.bars[k]:SetValue(p[R.bars[k].key]) end
  local room = 79 -- from the first line down to the buttons
  for k = 1, 5 do
    local l = lines[k]
    if l and room > 0 then
      R.lines[k]:SetText(l[1]); R.lines[k]:SetTextColor(l[2][1], l[2][2], l[2][3]); R.lines[k]:Show()
      -- a wrapped line takes two rows; what no longer fits above the buttons stays hidden
      local h = R.lines[k].GetHeight and R.lines[k]:GetHeight()
      if type(h) ~= "number" or h < 1 then h = 13 end
      room = room - h - 2
      if room < 0 then R.lines[k]:Hide() end
    else R.lines[k]:Hide() end
  end
  if t.active == B.sel then R.load:SetLabel(AzT("Loaded"), { 0.55, 1, 0.45 })
  else R.load:SetLabel(AzT("Load into wishlist")) end
  B.FitButtons()
end

-- the four buttons as one row in the middle of the page; where the words run long
-- (German, Portuguese) they get a smaller type and less wood round it, so the row
-- stays on the page
function B.FitButtons()
  local R = B.R
  if not (R and R.load) then return end
  local ui = AZL.ui
  local row = { R.load, R.share, R.import, R.del }
  local MAXW = 336
  local function Total(pad)
    local total = 18
    for k = 1, 4 do
      local tw = row[k].text and row[k].text:GetStringWidth()
      if type(tw) ~= "number" then tw = 40 end
      total = total + math.max(54, tw + pad)
    end
    return total
  end
  local size, pad = 11, 26
  for k = 1, 4 do AzlFitText(row[k].text, 9999, 11, 11) end
  if Total(pad) > MAXW then
    size = 10
    for k = 1, 4 do AzlFitText(row[k].text, 9999, 10, 10) end
    pad = 26
    while pad > 14 and Total(pad) > MAXW do pad = pad - 2 end
  end
  local total = 18
  for k = 1, 4 do
    local tw = row[k].text:GetStringWidth()
    if type(tw) ~= "number" then tw = 40 end
    local w = math.max(54, tw + pad)
    row[k]:SetWidth(w)
    total = total + w
  end
  R.load:ClearAllPoints()
  R.load:SetPoint("BOTTOMLEFT", ui.right, "BOTTOMLEFT", math.floor(PAGE_MID - total / 2), 1)
end

-- ---------- share and import: a small sheet over the book ----------
function B.Popup(mode)
  local Z = AZL
  local frame = Z.Frame()
  if not frame then return end
  local pop = B.pop
  if not pop then
    pop = CreateFrame("Frame", "AzerlootBuildCodeFrame", frame)
    pop:SetWidth(380); pop:SetHeight(196)
    pop:SetPoint("CENTER", frame, "CENTER", 0, 0)
    pop:SetFrameLevel(frame:GetFrameLevel() + 40)
    pop:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    pop:EnableMouse(true)
    local tt = Z.Font(pop, "GameFontNormalLarge", nil, 16)
    tt:SetTextColor(1, 0.82, 0)
    tt:SetPoint("TOP", pop, "TOP", 0, -20)
    pop.title = tt
    local eb = CreateFrame("EditBox", "AzerlootBuildCode", pop, "InputBoxTemplate")
    eb:SetWidth(320); eb:SetHeight(24)
    eb:SetPoint("TOP", pop, "TOP", 0, -50)
    eb:SetAutoFocus(false); eb:SetMaxLetters(400)
    eb:SetScript("OnEscapePressed", function() B.pop:Hide() end)
    eb:SetScript("OnEnterPressed", function() if B.pop.mode == "import" then B.pop.action:Click() else B.pop:Hide() end end)
    eb:SetScript("OnTextChanged", function()
      -- shared: the code stays as it was, so a stray key cannot spoil it
      if B.pop.mode == "share" and this:GetText() ~= B.pop.code then this:SetText(B.pop.code); this:HighlightText() end
      -- import: as soon as a code is pasted, it is read and the five places are offered
      if B.pop.mode == "import" then B.CheckImport() end
    end)
    pop.edit = eb
    local hint = Z.Font(pop, "GameFontHighlightSmall", { 0.85, 0.85, 0.85 }, 11)
    hint:SetPoint("TOP", eb, "BOTTOM", 0, -6)
    hint:SetWidth(330)
    pop.hint = hint
    local act = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    act:SetWidth(100); act:SetHeight(22)
    act:SetScript("OnClick", function() B.ImportNow() end)
    pop.action = act
    -- Copy and Paste: the game keeps the clipboard to itself, so they ready the box for
    -- Ctrl+C or Ctrl+V and say so
    local cp = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    cp:SetWidth(100); cp:SetHeight(22)
    cp:SetScript("OnClick", function()
      local pp = B.pop
      pp.edit:SetFocus()
      if pp.mode == "share" then
        pp.edit:HighlightText()
        pp.hint:SetText(AzT("Selected: now press Ctrl+C to copy it.")); pp.hint:SetTextColor(0.55, 1, 0.45)
      else
        pp.edit:SetText("")
        pp.hint:SetText(AzT("Ready: now press Ctrl+V to paste the code.")); pp.hint:SetTextColor(0.55, 1, 0.45)
      end
    end)
    pop.copy = cp
    local cl = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    cl:SetWidth(100); cl:SetHeight(22)
    cl:SetText(AzT("Close"))
    cl:SetScript("OnClick", function() B.pop:Hide() end)
    pop.close = cl
    -- the five places to import into: a free one fills, a taken one is replaced
    local pl = Z.Font(pop, "GameFontNormal", nil, 12)
    pl:SetTextColor(1, 0.82, 0)
    pl:SetPoint("TOP", pop, "TOP", 0, -112)
    pl:SetText(AzT("Import into which build?"))
    pop.placeLabel = pl
    pop.places = {}
    for k = 1, NBUILDS do
      local pb = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
      pb:SetWidth(44); pb:SetHeight(22)
      pb:SetPoint("TOP", pop, "TOP", (k - 3) * 52, -130)
      pb:SetText(tostring(k))
      pb.place = k
      pb:SetScript("OnClick", function() B.ImportInto(this.place) end)
      pb:SetScript("OnEnter", function()
        local bd = B.Get(AZL.PlayerClass(), this.place)
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(AzT("Build %d", this.place), 1, 0.82, 0)
        if bd then
          GameTooltip:AddLine(AzT("Replaces \"%s\".", bd.name), 1, 0.45, 0.35, 1)
        else
          GameTooltip:AddLine(AzT("Empty: the build goes here."), 0.85, 0.85, 0.85, 1)
        end
        GameTooltip:Show()
      end)
      pb:SetScript("OnLeave", function() GameTooltip:Hide() end)
      pop.places[k] = pb
    end
    pop:SetScript("OnHide", function() this.armed = false end)
    pop.armed = false
    B.pop = pop
  end
  pop.mode = mode
  pop.armed = false
  local cls = Z.PlayerClass()
  if mode == "share" then
    local b = B.Get(cls, B.sel or 0)
    if not b then return end
    pop.code = B.Encode(cls, b)
    pop.title:SetText(AzT("Share \"%s\"", b.name))
    pop.hint:SetText(AzT("Copy the code with Ctrl+C and post it anywhere. Other players import it in their builds."))
    pop.hint:SetTextColor(0.85, 0.85, 0.85)
    pop.action:Hide()
    B.ShowPlaces(false)
    pop.copy:SetText(AzT("Copy"))
    pop.copy:ClearAllPoints(); pop.copy:SetPoint("BOTTOM", pop, "BOTTOM", -56, 18)
    pop.close:ClearAllPoints(); pop.close:SetPoint("BOTTOM", pop, "BOTTOM", 56, 18)
    pop:Show()
    pop.edit:SetText(pop.code)
    pop.edit:SetFocus(); pop.edit:HighlightText()
  else
    pop.code = nil
    pop.title:SetText(AzT("Import a build"))
    pop.hint:SetText(AzT("Paste a build code with Ctrl+V."))
    pop.hint:SetTextColor(0.85, 0.85, 0.85)
    pop.action:Hide()
    B.ShowPlaces(false)
    pop.copy:SetText(AzT("Paste"))
    pop.copy:ClearAllPoints(); pop.copy:SetPoint("BOTTOM", pop, "BOTTOM", -56, 18)
    pop.close:ClearAllPoints(); pop.close:SetPoint("BOTTOM", pop, "BOTTOM", 56, 18)
    pop:Show()
    pop.edit:SetText("")
    pop.edit:SetFocus()
  end
end

-- the five places, shown once a fitting code is in the box; a taken one in a warmer red
function B.ShowPlaces(on)
  local pop = B.pop
  if not pop then return end
  local cls = AZL.PlayerClass()
  if on then pop.placeLabel:Show() else pop.placeLabel:Hide() end
  for k = 1, NBUILDS do
    local pb = pop.places[k]
    if on then
      local bd = B.Get(cls, k)
      local fs = pb:GetFontString()
      if fs then if bd then fs:SetTextColor(1, 0.55, 0.4) else fs:SetTextColor(1, 0.82, 0) end end
      pb:Show()
    else
      pb:Hide()
    end
  end
end

-- reads what is in the box: not a code, another class's build, or one to import
function B.CheckImport()
  local Z = AZL
  local pop = B.pop
  local text = pop.edit:GetText() or ""
  local function Say(s, c)
    pop.hint:SetText(s); pop.hint:SetTextColor(c[1], c[2], c[3])
  end
  if string.gsub(text, "%s", "") == "" then
    Say(AzT("Paste a build code with Ctrl+V."), { 0.85, 0.85, 0.85 }); B.ShowPlaces(false); return
  end
  local cls = Z.PlayerClass()
  local ccls, b = B.Decode(text)
  if not ccls then Say(AzT("That is not a build code."), { 1, 0.4, 0.35 }); B.ShowPlaces(false); return end
  if ccls ~= cls then
    -- a druid's build never goes into a mage's builds
    Say(AzT("This build is for a %s; you play a %s.", AzG(Z.ClassInfo(ccls).name), AzG(Z.ClassInfo(cls).name)), { 1, 0.4, 0.35 })
    B.ShowPlaces(false); return
  end
  pop.ready = b
  Say(AzT("\"%s\" is ready. Choose its place: a taken one is replaced.", b.name), { 0.55, 1, 0.45 })
  B.ShowPlaces(true)
end

-- the read build into a place, replacing what was there
function B.ImportInto(place)
  local Z = AZL
  local pop = B.pop
  local cls = Z.PlayerClass()
  local ccls, b = B.Decode(pop.edit:GetText())
  if not ccls or ccls ~= cls then B.CheckImport(); return end
  local t = B.All(cls)
  B.Uid(b)   -- an imported build is a new one, with runs of its own
  t.list[place] = b
  B.sel = place
  pop:Hide()
  Z.Print(AzT("build \"%s\" imported", b.name))
  B.Changed(cls, place)
end

-- the pasted code into the chosen place (a free one if none is chosen); replacing a build
-- takes a second click
function B.ImportNow()
  local Z = AZL
  local pop = B.pop
  local cls = Z.PlayerClass()
  local ccls, b = B.Decode(pop.edit:GetText())
  local function Say(s, bad)
    pop.hint:SetText(s)
    if bad then pop.hint:SetTextColor(1, 0.4, 0.35) else pop.hint:SetTextColor(0.85, 0.85, 0.85) end
  end
  if not ccls then Say(AzT("That is not a build code."), true); return end
  if ccls ~= cls then Say(AzT("This build is for a %s; you play a %s.", AzG(Z.ClassInfo(ccls).name), AzG(Z.ClassInfo(cls).name)), true); return end
  local t = B.All(cls)
  local place = B.sel
  if not place or t.list[place] then
    for i = NBUILDS, 1, -1 do if not t.list[i] then place = i end end
  end
  if not place then place = B.sel or 1 end
  if t.list[place] and pop.armed ~= place then
    pop.armed = place
    Say(AzT("Click Import again to replace \"%s\".", t.list[place].name), true)
    return
  end
  t.list[place] = b
  B.sel = place
  pop:Hide()
  Z.Print(AzT("build \"%s\" imported", b.name))
  B.Changed(cls, place)
end

-- ---------- "Add to build": the button on a spell's or jewel's page, and its list ----------
function B.SetupButton(btn, entry)
  local Z = AZL
  local cls = Z.PlayerClass()
  local key = Z.WishKey(entry)
  -- another class's spell or class amulet cannot go into this hero's builds
  if type(entry.class) == "table" and entry.class.key and entry.class.key ~= cls then
    btn.isStart = true   -- (no list opens)
    btn.text:SetText(AzT("Only for %s builds", AzG(entry.class.name))); btn.text:SetTextColor(0.6, 0.55, 0.48)
    btn.mark:SetTexture(nil)
    return
  end
  btn.isStart = (entry.kind == "Spell" and entry.item.key == B.StartKey(cls)) and true or false
  if btn.isStart then
    btn.text:SetText(AzT("Starting spell: in every build")); btn.text:SetTextColor(1, 0.82, 0)
    btn.mark:SetTexture(nil)
    return
  end
  local names = {}
  for i = 1, NBUILDS do
    local b = B.Get(cls, i)
    if b and B.Has(b, key) then table.insert(names, b.name) end
  end
  if type(btn.flashUntil) == "number" and GetTime() < btn.flashUntil and type(btn.flash) == "string" then
    btn.text:SetText(btn.flash); btn.text:SetTextColor(0.55, 1, 0.45)
  elseif table.getn(names) == 0 then
    btn.text:SetText(AzT("Add to build")); btn.text:SetTextColor(0.95, 0.9, 0.78)
  elseif table.getn(names) == 1 then
    btn.text:SetText(AzT("In build: %s", Short(names[1], 18))); btn.text:SetTextColor(1, 0.82, 0)
  else
    btn.text:SetText(AzT("In %d builds", table.getn(names))); btn.text:SetTextColor(1, 0.82, 0)
  end
  btn.mark:SetTexture(DROP); btn.mark:SetVertexColor(1, 1, 1)
  btn.mark:SetWidth(14); btn.mark:SetHeight(14)
  btn.mark:ClearAllPoints(); btn.mark:SetPoint("LEFT", btn.text, "RIGHT", 4, -1)
end

function B.CloseMenu()
  if B.menu then B.menu:Hide() end
  if B.picker then B.picker:Hide() end
  if B.catcher then B.catcher:Hide() end
end

-- a click anywhere outside an open list closes it
local function Catcher()
  if B.catcher then return B.catcher end
  local c = CreateFrame("Button", nil, UIParent)
  c:SetAllPoints(UIParent); c:SetFrameStrata("FULLSCREEN")
  c:EnableMouse(true); c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  c:SetScript("OnClick", function() B.CloseMenu() end)
  c:Hide()
  B.catcher = c
  return c
end

-- ---------- the short list to fill a place on the builds page ----------
local PICK_ROWS, PICK_H = 10, 20
local CROSS = "Interface\\AddOns\\Azerloot\\media\\textures\\cross.tga"
function B.ClosePicker()
  if B.picker then B.picker:Hide() end
end

-- what can go into a place: the class's spells, the rings, the trinkets, or the amulets
-- (the basic ones, then the class amulets)
local function Choices(cls, slot, filled)
  local Z = AZL
  local out = {}
  local function Put(list) for i = 1, table.getn(list) do table.insert(out, list[i]) end end
  if filled then table.insert(out, { none = true }) end
  if slot == "Spell" then Put(Z.SpellEntries(cls))
  elseif slot == "Rings" or slot == "Trinkets" then Put(Z.ItemEntries(slot))
  else
    table.insert(out, { head = AzT("Basic Amulets") })
    Put(Z.ItemEntries("Amulets"))
    table.insert(out, { head = AzT("Class Amulets") })
    Put(Z.ClassEntries(Z.ClassInfo(cls)))
  end
  return out
end

local function PickerRow(p, i)
  local Z = AZL
  local r = CreateFrame("Button", nil, p)
  r:SetWidth(232); r:SetHeight(PICK_H)
  r:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -38 - (i - 1) * PICK_H)
  local cur = r:CreateTexture(nil, "BACKGROUND"); cur:SetTexture(Z.WHITE)
  cur:SetVertexColor(0.85, 0.62, 0.15); cur:SetAlpha(0.28); cur:SetAllPoints(r); cur:Hide()
  r.cur = cur
  Hover(r, 1, 0.8, 0.4, 0.22)
  local ic = r:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(18); ic:SetHeight(18); ic:SetPoint("LEFT", r, "LEFT", 2, 0)
  ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.icon = ic
  local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("LEFT", r, "LEFT", 25, 0); t:SetWidth(186); t:SetHeight(14); t:SetJustifyH("LEFT")
  r.text = t
  local tick = r:CreateTexture(nil, "OVERLAY")
  tick:SetWidth(14); tick:SetHeight(14); tick:SetPoint("RIGHT", r, "RIGHT", -2, 0)
  tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); tick:SetVertexColor(0.3, 1, 0.25); tick:Hide()
  r.tick = tick
  r:SetScript("OnClick", function()
    if this.none then B.PickNone() elseif this.entry then B.Pick(this.entry) end
  end)
  r:SetScript("OnEnter", function()
    if this.none then
      this.hover:Show()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzT("None"), 1, 0.82, 0)
      GameTooltip:AddLine(AzT("Empties this place."), 0.85, 0.85, 0.85, 1)
      GameTooltip:Show()
      return
    end
    if not this.entry then return end
    this.hover:Show()
    local hint
    if this.inBuild then hint = AzT("Already in this build") end
    B.EntryTip(this, this.entry, hint)
  end)
  r:SetScript("OnLeave", function() this.hover:Hide(); GameTooltip:Hide() end)
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function() B.ScrollPicker(arg1) end)
  return r
end

function B.DrawPicker()
  local p = B.picker
  local Z = AZL
  local cls = Z.PlayerClass()
  local b = B.Get(cls, B.sel or 0)
  local list = p.list
  local n = table.getn(list)
  p:SetHeight(46 + math.min(math.max(n, 1), PICK_ROWS) * PICK_H)
  local top = math.max(0, math.min(p.offset, n - PICK_ROWS))
  p.offset = top
  local curKey = p.owner and p.owner.entry and Z.WishKey(p.owner.entry)
  for i = 1, PICK_ROWS do
    local r, e = p.rows[i], list[top + i]
    r.none = false
    if not e then
      r:Hide()
    elseif e.none then
      -- empties the place again
      r.entry = false; r.inBuild = false; r.none = true
      r.icon:SetTexture(CROSS); r.icon:SetTexCoord(0, 1, 0, 1); r.icon:SetAlpha(0.85); r.icon:Show()
      r.tick:Hide(); r.cur:Hide()
      r.text:SetText(AzT("None")); r.text:SetTextColor(0.75, 0.72, 0.68)
      r:Show()
    elseif e.head then
      r.entry = false; r.inBuild = false
      r.icon:Hide(); r.tick:Hide(); r.cur:Hide()
      r.text:SetText("|cffbfae8c" .. e.head .. "|r")
      r:Show()
    else
      local title, col = Z.EntryTitle(e)
      local key = Z.WishKey(e)
      local inBuild = b and (B.Has(b, key) or key == "spell:" .. tostring(B.StartKey(cls))) and key ~= curKey
      r.entry = e; r.inBuild = inBuild and true or false
      r.icon:SetTexture("Interface\\Icons\\" .. (e.item.icon or "INV_Misc_QuestionMark")); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icon:Show()
      r.text:SetText(title)
      if inBuild then r.text:SetTextColor(0.55, 0.55, 0.55); r.icon:SetAlpha(0.5)
      else r.text:SetTextColor(col[1], col[2], col[3]); r.icon:SetAlpha(1) end
      if inBuild then r.tick:Show() else r.tick:Hide() end
      if key == curKey then r.cur:Show() else r.cur:Hide() end
      r:Show()
    end
  end
  -- the thumb on the right shows where in the list one is
  if n > PICK_ROWS then
    local h = PICK_ROWS * PICK_H
    local th = math.max(14, h * PICK_ROWS / n)
    p.thumb:SetHeight(th)
    p.thumb:ClearAllPoints()
    p.thumb:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -38 - (h - th) * top / (n - PICK_ROWS))
    p.thumb:Show(); p.track:Show()
  else
    p.thumb:Hide(); p.track:Hide()
  end
end

function B.ScrollPicker(delta)
  local p = B.picker
  if not p then return end
  p.offset = p.offset - (tonumber(delta) or 0) * 3
  B.DrawPicker()
end

-- "None": the place clicked is emptied again
function B.PickNone()
  local Z = AZL
  local p = B.picker
  local cls = Z.PlayerClass()
  local old = p and p.owner and p.owner.entry
  B.CloseMenu()
  GameTooltip:Hide()
  if old and B.Get(cls, B.sel or 0) then B.Remove(cls, B.sel, Z.WishKey(old)) end
end

-- the chosen part goes into the place clicked (in place of what was there)
function B.Pick(entry)
  local Z = AZL
  local p = B.picker
  local cls = Z.PlayerClass()
  local b = B.Get(cls, B.sel or 0)
  if not (p and b) then return end
  local old = p.owner and p.owner.entry
  local key = Z.WishKey(entry)
  if old and Z.WishKey(old) == key then B.CloseMenu(); return end
  if B.Has(b, key) then return end
  B.CloseMenu()
  GameTooltip:Hide()
  B.Add(cls, B.sel, entry, old and Z.WishKey(old) or nil, p.owner and p.owner.place)
end

function B.OpenPicker(btn)
  local Z = AZL
  local cls = Z.PlayerClass()
  if not B.Get(cls, B.sel or 0) then return end
  local p = B.picker
  if p and p:IsVisible() and p.owner == btn then B.CloseMenu(); return end
  if B.menu then B.menu:Hide() end
  if not p then
    p = CreateFrame("Frame", "AzerlootBuildPicker", UIParent)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetWidth(252); p:SetHeight(46 + PICK_ROWS * PICK_H)
    p:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    p:SetBackdropColor(0.06, 0.04, 0.02, 1)
    -- a solid ground under the border: the tooltip backdrop alone lets the page show through
    local solid = p:CreateTexture(nil, "BACKGROUND"); solid:SetTexture(Z.WHITE)
    solid:SetVertexColor(0.08, 0.055, 0.03); solid:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4); solid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 4)
    p:SetBackdropBorderColor(0.8, 0.62, 0.3, 1)
    p:EnableMouse(true); p:SetClampedToScreen(true)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function() B.ScrollPicker(arg1) end)
    local hd = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hd:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -9); hd:SetJustifyH("LEFT")
    p.head = hd
    -- the book's ornament line under the heading, in gold on the dark ground
    local dv = p:CreateTexture(nil, "ARTWORK"); dv:SetTexture(Z.MEDIA .. "divider_gold.tga")
    dv:SetWidth(236); dv:SetHeight(12); dv:SetPoint("TOP", p, "TOP", 0, -25)
    p.divider = dv
    local track = p:CreateTexture(nil, "BORDER"); track:SetTexture(Z.WHITE)
    track:SetVertexColor(0, 0, 0); track:SetAlpha(0.45); track:SetWidth(4)
    track:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -38); track:SetHeight(PICK_ROWS * PICK_H)
    p.track = track
    local thumb = p:CreateTexture(nil, "ARTWORK"); thumb:SetTexture(Z.WHITE)
    thumb:SetVertexColor(0.85, 0.65, 0.3); thumb:SetWidth(4)
    p.thumb = thumb
    p.rows = {}
    for i = 1, PICK_ROWS do p.rows[i] = PickerRow(p, i) end
    table.insert(UISpecialFrames, "AzerlootBuildPicker")
    p:SetScript("OnHide", function() if B.catcher then B.catcher:Hide() end end)
    p.offset = 0
    B.picker = p
  end
  p.owner = btn
  p.list = Choices(cls, btn.slot, btn.entry and true or false)
  local heads = { Spell = "Choose a spell", Rings = "Choose a ring", Trinkets = "Choose a trinket", Neck = "Choose an amulet" }
  p.head:SetText(AzT(heads[btn.slot] or "Choose a spell"))
  -- open with the part already there in sight
  p.offset = 0
  if btn.entry then
    local key = Z.WishKey(btn.entry)
    for i = 1, table.getn(p.list) do
      if p.list[i].item and Z.WishKey(p.list[i]) == key then p.offset = i - 3 end
    end
  end
  B.DrawPicker()
  local f = Z.Frame()
  local fs, us = f and f:GetEffectiveScale(), UIParent:GetEffectiveScale()
  if type(fs) == "number" and type(us) == "number" and us > 0 then p:SetScale(fs / us) end
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", -4, -4)
  Catcher():Show()
  p:Show()
end

local function MenuRow(menu, i)
  if menu.rows[i] then return menu.rows[i] end
  local Z = AZL
  local r = CreateFrame("Button", nil, menu)
  r:SetWidth(250); r:SetHeight(20)
  Hover(r, 1, 0.8, 0.4, 0.22)
  r:SetScript("OnEnter", function() this.hover:Show() end)
  r:SetScript("OnLeave", function() this.hover:Hide() end)
  local ic = r:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(16); ic:SetHeight(16); ic:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.icon = ic
  local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("LEFT", r, "LEFT", 26, 0); t:SetJustifyH("LEFT"); t:SetWidth(160)
  r.text = t
  local v = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  v:SetPoint("RIGHT", r, "RIGHT", -6, 0); v:SetJustifyH("RIGHT")
  r.value = v
  r:SetScript("OnClick", function() if this.act then this.act() end end)
  menu.rows[i] = r
  return r
end

-- the list of builds: tick = in it; a click puts the part in or takes it out; a full
-- place asks which part to replace
function B.OpenMenu(btn, entry, mode, place)
  local Z = AZL
  if entry and entry.kind == "Spell" and entry.item.key == B.StartKey(Z.PlayerClass()) then return end
  if not mode and B.menu and B.menu:IsVisible() and B.menuOwner == btn then B.CloseMenu(); return end
  local menu = B.menu
  if B.picker then B.picker:Hide() end
  if not menu then
    Catcher()
    menu = CreateFrame("Frame", "AzerlootBuildMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetWidth(266)
    menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    menu:SetBackdropColor(0.06, 0.04, 0.02, 1)
    local solid = menu:CreateTexture(nil, "BACKGROUND"); solid:SetTexture(Z.WHITE)
    solid:SetVertexColor(0.08, 0.055, 0.03); solid:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4); solid:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
    menu:SetBackdropBorderColor(0.8, 0.62, 0.3, 1)
    menu:EnableMouse(true)
    local hd = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hd:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -10); hd:SetJustifyH("LEFT"); hd:SetWidth(240)
    menu.head = hd
    menu.rows = {}
    table.insert(UISpecialFrames, "AzerlootBuildMenu")
    menu:SetScript("OnHide", function() if B.catcher then B.catcher:Hide() end end)
    B.menu = menu
  end
  B.menuOwner = btn
  local cls = Z.PlayerClass()
  if type(entry.class) == "table" and entry.class.key and entry.class.key ~= cls then return end
  local key = Z.WishKey(entry)
  local slot = Slot(entry.kind)
  local rows = {}
  local function Flash(s)
    btn.flash, btn.flashUntil = s, GetTime() + 2.5
    Z.Refresh()
  end
  -- a full build's parts to replace; if that build is gone meanwhile (deleted, or the hero's
  -- class read differently since), back to the list of builds instead of an error
  if mode == "replace" and not B.Get(cls, place or 0) then mode = "main" end
  if mode == "replace" then
    local b = B.Get(cls, place)
    local what = { Spell = "spell", Rings = "ring", Trinkets = "trinket", Neck = "amulet" }
    menu.head:SetText(AzT("\"%s\" is full. Replace which %s?", Short(b.name, 18), AzT(what[slot])))
    local inSlot = B.InSlot(b, slot)
    for n = 1, table.getn(inSlot) do
      local rec = inSlot[n]
      local e = B.Entry(cls, rec)
      if e then
        local tt = Z.EntryTitle(e)
        table.insert(rows, { icon = "Interface\\Icons\\" .. (e.item.icon or "INV_Misc_QuestionMark"), text = tt, act = function()
          B.Add(cls, place, entry, RecKey(rec))
          B.CloseMenu()
          Flash(AzT("Added to %s", Short(b.name, 16)))
        end })
      end
    end
    table.insert(rows, { text = "|cffaaaaaa" .. AzT("Back") .. "|r", act = function() B.OpenMenu(btn, entry, "main") end })
  else
    menu.head:SetText(AzT("Add to build"))
    local free
    for i = 1, NBUILDS do
      -- the place in a local of its own: under the game's Lua 5.0 every click handler made
      -- in this loop would otherwise see the loop's last number, not its own
      local place = i
      local b = B.Get(cls, place)
      if b then
        local has = B.Has(b, key) ~= nil
        local n = (slot == "Spell") and B.SpellCount(cls, b) or table.getn(B.InSlot(b, slot))
        local full = n >= MAX[slot]
        local val = AzT(SLOT_NAME[slot]) .. " " .. n .. "/" .. MAX[slot]
        if full and not has then val = "|cffff8866" .. val .. "|r" end
        table.insert(rows, { icon = has and "Interface\\Buttons\\UI-CheckBox-Check" or nil, text = Short(b.name, 24), value = val, act = function()
          if B.Has(B.Get(cls, place), key) then
            B.Remove(cls, place, key)
            B.OpenMenu(btn, entry, "main")
            Z.Refresh()
            return
          end
          local ok = B.Add(cls, place, entry)
          if ok then
            B.CloseMenu()
            Flash(AzT("Added to %s", Short(b.name, 16)))
          else
            B.OpenMenu(btn, entry, "replace", place)
          end
        end })
      elseif not free then
        free = i
      end
    end
    if free then
      table.insert(rows, { text = "|cff88dd66+ " .. AzT("New build") .. "|r", act = function()
        local n = B.New(cls)
        if n then
          -- the first build goes straight into the wishlist
          if not B.All(cls).active then B.All(cls).active = n end
          B.Add(cls, n, entry)
          B.sel = n
          B.CloseMenu()
          Flash(AzT("Added to %s", Short(B.Get(cls, n).name, 16)))
        end
      end })
    end
  end
  for i = 1, table.getn(menu.rows) do menu.rows[i]:Hide() end
  for i = 1, table.getn(rows) do
    local r = MenuRow(menu, i)
    local d = rows[i]
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -30 - (i - 1) * 21)
    if d.icon then
      r.icon:SetTexture(d.icon); r.icon:Show()
      if d.icon == "Interface\\Buttons\\UI-CheckBox-Check" then r.icon:SetVertexColor(0.3, 1, 0.25); r.icon:SetTexCoord(0, 1, 0, 1)
      else r.icon:SetVertexColor(1, 1, 1); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    else r.icon:Hide() end
    r.text:SetText(d.text or "")
    r.value:SetText(d.value or "")
    r.act = d.act
    r:Show()
  end
  local hh = menu.head:GetHeight()
  menu:SetHeight(38 + table.getn(rows) * 21 + ((type(hh) == "number" and hh > 16) and 12 or 0))
  local f = Z.Frame()
  local fs, us = f and f:GetEffectiveScale(), UIParent:GetEffectiveScale()
  if type(fs) == "number" and type(us) == "number" and us > 0 then menu:SetScale(fs / us) end
  menu:ClearAllPoints()
  menu:SetPoint("BOTTOM", btn, "TOP", 0, 6)
  B.catcher:Show()
  menu:Show()
end

-- ---------- the wishlist window: the loaded build, and the choice when a run begins ----------
local function TrackerParts(tr)
  if B.tparts == tr then return end
  B.tparts = tr
  local Z = AZL
  local bl = CreateFrame("Button", nil, tr)
  bl:SetHeight(14)
  local bt = bl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bt:SetPoint("LEFT", bl, "LEFT", 0, 0); bt:SetJustifyH("LEFT")
  bl.text = bt
  bl:SetScript("OnClick", function()
    local st = AZL.state
    if not AZL.Frame() then Azerloot_Toggle() end
    st.module = "Builds"; st.search = ""
    AZL.Frame():Show()
    AZL.Refresh()
  end)
  bl:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Your loaded build"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("How much of it this run has brought. Click to open your builds in the book."), 0.85, 0.85, 0.85, 1)
    GameTooltip:Show()
  end)
  bl:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- how far the build has come: a slim bar in a dark trough with a fine gold edge
  local bar = CreateFrame("Frame", nil, bl)
  bar:SetHeight(11)
  local tb = bar:CreateTexture(nil, "BACKGROUND"); tb:SetTexture(Z.WHITE); tb:SetAllPoints(bar)
  tb:SetVertexColor(0.08, 0.05, 0.02); tb:SetAlpha(0.9)
  local fill = bar:CreateTexture(nil, "BORDER"); fill:SetTexture(BAR_FILL)
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1); fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
  bar.fill = fill
  for side = 1, 4 do
    local e = bar:CreateTexture(nil, "ARTWORK"); e:SetTexture(Z.WHITE); e:SetVertexColor(0.75, 0.56, 0.22); e:SetAlpha(0.8)
    if side == 1 then e:SetPoint("TOPLEFT", bar, "TOPLEFT"); e:SetPoint("TOPRIGHT", bar, "TOPRIGHT"); e:SetHeight(1)
    elseif side == 2 then e:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT"); e:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT"); e:SetHeight(1)
    elseif side == 3 then e:SetPoint("TOPLEFT", bar, "TOPLEFT"); e:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT"); e:SetWidth(1)
    else e:SetPoint("TOPRIGHT", bar, "TOPRIGHT"); e:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT"); e:SetWidth(1) end
  end
  local bn = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bn:SetPoint("CENTER", bar, "CENTER", 0, 0)
  local face = bn:GetFont()
  if face then bn:SetFont(face, 9, "OUTLINE") end
  bar.text = bn
  bl.bar = bar
  bar:Hide()
  -- how far the build has come, one small gem for each of its parts: lit once it is had
  bl.pips = {}
  for k = 1, 11 do
    local pp = bl:CreateTexture(nil, "ARTWORK")
    pp:SetWidth(11); pp:SetHeight(11)
    pp:SetPoint("LEFT", bl, "LEFT", (k - 1) * 12, 0)
    bl.pips[k] = pp
  end
  local pc = bl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pc:SetTextColor(0.85, 0.78, 0.62)
  bl.pipText = pc
  bl.xp, bl.xpW = false, false
  tr.bline = bl
  local pk = CreateFrame("Frame", nil, tr)
  local pl = pk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pl:SetPoint("TOPLEFT", pk, "TOPLEFT", 0, 0)
  pl:SetText(AzT("Choose a build for this run:"))
  pk.label = pl
  local x = CreateFrame("Button", nil, pk)
  x:SetWidth(14); x:SetHeight(14)
  x:SetPoint("TOPRIGHT", pk, "TOPRIGHT", 0, 1)
  local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetAllPoints(x)
  xt:SetTexture("Interface\\AddOns\\Azerloot\\media\\textures\\cross.tga"); xt:SetAlpha(0.8)
  x:SetScript("OnClick", function() AzerlootDB.buildPick = nil; AZL.RefreshTracker() end)
  x:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Keep the wishlist as it is"), 1, 0.82, 0)
    GameTooltip:Show()
  end)
  x:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pk.btns = {}
  -- each build as a small dark plate with a fine gold edge and a lighter top, like a bevel;
  -- under the mouse the edge lights up and a warm glow fills it
  for i = 1, NBUILDS do
    local b = CreateFrame("Button", nil, pk)
    b:SetHeight(19)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(Z.WHITE)
    bg:SetVertexColor(0.13, 0.08, 0.03); bg:SetAlpha(0.88); bg:SetAllPoints(b)
    local top = b:CreateTexture(nil, "BORDER"); top:SetTexture(Z.WHITE)
    top:SetVertexColor(0.55, 0.4, 0.18); top:SetAlpha(0.22)
    top:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1); top:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1); top:SetHeight(8)
    local glow = b:CreateTexture(nil, "BORDER"); glow:SetTexture(Z.GLOW); glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.75, 0.3); glow:SetAlpha(0.35); glow:SetAllPoints(b); glow:Hide()
    b.glow = glow
    b.edges = {}
    local function Edge(a1, a2, wd, ht)
      local e = b:CreateTexture(nil, "ARTWORK"); e:SetTexture(Z.WHITE); e:SetVertexColor(0.9, 0.7, 0.3)
      e:SetPoint(a1, b, a1, 0, 0); e:SetPoint(a2, b, a2, 0, 0)
      if wd then e:SetWidth(wd) else e:SetHeight(ht) end
      table.insert(b.edges, e)
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, 1); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT", "BOTTOMLEFT", 1, nil); Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    b.SetEdge = function(self, a) for k = 1, 4 do self.edges[k]:SetAlpha(a) end end
    b:SetEdge(0.45)
    -- the build's number, small and gold, before its name
    local num = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    num:SetPoint("LEFT", b, "LEFT", 6, 0); num:SetTextColor(1, 0.78, 0.25)
    b.num = num
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", b, "LEFT", 20, 0); t:SetJustifyH("LEFT")
    b.text = t
    local s = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s:SetPoint("RIGHT", b, "RIGHT", -6, 0); s:SetTextColor(0.75, 0.68, 0.55)
    b.sub = s
    b:SetScript("OnEnter", function()
      this.hover = true; this:SetEdge(1); this.glow:Show(); this.text:SetTextColor(1, 0.95, 0.75)
      local bd = B.Get(AZL.PlayerClass(), this.index or 0)
      if bd then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(bd.name, 1, 0.82, 0)
        if (bd.note or "") ~= "" then GameTooltip:AddLine(bd.note, 0.85, 0.85, 0.85) end
        GameTooltip:AddLine(AzT("Click to load it into your wishlist for this run."), 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      this.hover = false; this:SetEdge(0.45); this.glow:Hide(); this.text:SetTextColor(this.r or 1, this.g or 1, this.b or 1)
      GameTooltip:Hide()
    end)
    b.hover = false
    b:SetScript("OnClick", function() B.Apply(AZL.PlayerClass(), this.index) end)
    pk.btns[i] = b
  end
  -- when the choice appears, the plates' edges breathe a few times to catch the eye
  pk:SetScript("OnShow", function() this.since = GetTime() end)
  pk:SetScript("OnUpdate", function()
    local t = GetTime() - (this.since or 0)
    if t > 3.2 then
      if not this.calm then
        this.calm = true
        for k = 1, NBUILDS do if not this.btns[k].hover then this.btns[k]:SetEdge(0.45) end end
      end
      return
    end
    this.calm = false
    local a = 0.45 + 0.5 * math.abs(math.sin(t * math.pi / 1.05))
    for k = 1, NBUILDS do if not this.btns[k].hover then this.btns[k]:SetEdge(a) end end
  end)
  pk.since = 0
  pk.calm = true
  tr.pick = pk
end

-- draws the build line (and the choice) under the window's title; returns the new top
function B.TrackerHead(tr, W, y)
  TrackerParts(tr)
  local cls = AZL.PlayerClass()
  local t = B.All(cls)
  local b = t.active and t.list[t.active]
  local bl, pk = tr.bline, tr.pick
  if B.Picking() then
    bl:Hide()
    pk:ClearAllPoints(); pk:SetPoint("TOPLEFT", tr, "TOPLEFT", 8, y)
    pk:SetWidth(W - 16)
    local n = 0
    for i = 1, NBUILDS do
      local bd, btn = t.list[i], pk.btns[i]
      if bd then
        n = n + 1
        btn.index = i
        btn.num:SetText(tostring(i))
        btn.text:SetText(Short(bd.name, 20))
        -- an empty build is offered too, but quieter
        local empty = table.getn(bd.items) == 0
        if empty then btn.r, btn.g, btn.b = 0.6, 0.57, 0.52 else btn.r, btn.g, btn.b = 1, 0.92, 0.78 end
        if not btn.hover then btn.text:SetTextColor(btn.r, btn.g, btn.b) end
        btn.sub:SetText(empty and AzT("empty") or Short(bd.note or "", 12))
        btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", pk, "TOPLEFT", 0, -16 - (n - 1) * 22)
        btn:SetWidth(W - 16)
        btn:Show()
      else
        btn:Hide()
      end
    end
    local h = 16 + n * 22
    pk:SetHeight(h)
    pk:Show()
    return y - h - 6
  end
  pk:Hide()
  if b then
    local got, all = B.Progress(cls, b)
    local done = all > 0 and got >= all
    -- the window's head card names the build (Azerloot.lua); here, on its second line: a
    -- bar like the battle traits' of how much of the build came, from yellow to green
    bl.text:SetText(""); bl.text:Hide()
    for k = 1, 11 do bl.pips[k]:Hide() end
    bl.pipText:SetText("")
    -- the same length always, with room kept at its right for the waiting level-ups, so
    -- the bar does not shrink the moment they come
    local bw = math.floor(math.max(60, W - 24 - 104))
    if bl.xpW ~= bw then
      if type(bl.xp) == "table" then bl.xp:Hide() end
      bl.xp = XPBar(bl, bw, 10, { 1, 0.82, 0.1 })
      bl.xp:SetPoint("TOPLEFT", bl, "TOPLEFT", 0, 0)
      local tx = bl.xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      tx:SetPoint("CENTER", bl.xp, "CENTER", 0, 1)   -- the letters sit low in their line: lifted to the middle
      local face = tx:GetFont()
      if face then tx:SetFont(face, 9, "OUTLINE") end
      bl.xp.text = tx
      bl.xpW = bw
    end
    bl:ClearAllPoints(); bl:SetPoint("TOPLEFT", tr, "TOPLEFT", 12, -48)
    bl:SetWidth(bw); bl:SetHeight(10)
    local f = (all > 0) and got / all or 0
    -- yellow while little has come, turning green the closer the build is
    bl.xp.fill:SetVertexColor(1 - 0.75 * f, 0.82 + 0.03 * f, 0.1 + 0.1 * f)
    bl.xp:SetValue(f)
    -- the count alone, in the bar's middle (a word after it ran out of a narrow bar)
    bl.xp.text:SetText(got .. "/" .. all)
    bl.bar.text:SetText(got .. "/" .. all)
    bl:Show()
    return y, b
  end
  bl:Hide()
  return y
end

-- The player opens the window whose model the book holds: it gets its model back first,
-- then opens as always.
-- ---------- once the saved settings are there ----------
local starter = CreateFrame("Frame")
starter:RegisterEvent("VARIABLES_LOADED")
starter:SetScript("OnEvent", function()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  B.Migrate()
  B.MigrateSpecs()
  B.StripStart()
end)

-- Copyright (c) 2026 Kindagrey. All rights reserved. See LICENSE.txt.
-- Azerloot 2.5.1 - Azeroth Survivors (benilla client, Lua 5.0) by Kindagrey
-- A book-style compendium: every ring, trinket and amulet a run can offer with its value
-- at every rarity, each class's spells and their legendary amulets, a search, and a
-- wishlist that also lives in a small see-through window on your screen. The Loot chapter
-- has every boss of every zone: how it fights, what it drops for each class, and which of
-- those pieces are already in your collection.

local D = Azerloot_Data
local LD = Azerloot_Loot
local BOOK_SCALE = 1.15   -- the whole book, text and art alike, a size larger than the game's panels
local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"
local RIBBON = "Interface\\AddOns\\Azerloot\\media\\textures\\wax.tga"  -- wishlist mark: a wax seal
local GLOW = "Interface\\AddOns\\Azerloot\\media\\textures\\glow.tga"  -- soft oval, no hard edges
local RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
-- bright rarity colours for dark wood and tooltips, deep "ink" ones for the parchment
local RARITY_COLOR = {
  Common = { 1, 1, 1 }, Uncommon = { 0.12, 1, 0 }, Rare = { 0, 0.44, 0.87 },
  Epic = { 0.64, 0.21, 0.93 }, Legendary = { 1, 0.5, 0 }, PvP = { 0.93, 0.2, 0.16 },
}
local INK_RARITY = {
  Common = { 0.12, 0.1, 0.08 }, Uncommon = { 0.03, 0.34, 0 }, Rare = { 0, 0.2, 0.56 },
  Epic = { 0.36, 0.04, 0.56 }, Legendary = { 0.6, 0.24, 0 }, PvP = { 0.55, 0.05, 0.03 },
}
-- rarity colours for bright text on the parchment, each set off by a dark edge
local PAGE_RARITY = {
  Common = { 0.9, 0.88, 0.84 }, Uncommon = { 0.2, 0.82, 0.05 }, Rare = { 0.12, 0.52, 1 },
  Epic = { 0.68, 0.25, 0.98 }, Legendary = { 1, 0.5, 0.02 }, PvP = { 0.95, 0.22, 0.16 },
}
-- lighter rarity colours that stand out on the dark wood banners
local WOOD_RARITY = {
  Common = { 1, 1, 1 }, Uncommon = { 0.4, 1, 0.3 }, Rare = { 0.45, 0.72, 1 },
  Epic = { 0.82, 0.55, 1 }, Legendary = { 1, 0.66, 0.2 }, PvP = { 1, 0.48, 0.42 },
}
local INK = { 0.2, 0.1, 0.02 }         -- headings and values on parchment
local INK_GOOD = { 0.18, 0.74, 0.05 }  -- effect lines: the uncommon green, set off by a dark edge
local INK_SOFT = { 0.28, 0.18, 0.08 }  -- notes on parchment
local FONT = "Fonts\\FRIZQT__.TTF"
local HEAD_FONT = "Fonts\\MORPHEUS.TTF"  -- the game's own storybook face, for headings
local ITALIC_FONT = "Interface\\AddOns\\Azerloot\\media\\fonts\\AzerlootItalic.ttf"  -- Lora Italic, SIL OFL
local QUEST_YES = "Interface\\GossipFrame\\AvailableQuestIcon"  -- the game's yellow "!"
local QUEST_NO = "Interface\\GossipFrame\\ActiveQuestIcon"      -- the game's yellow "?"
-- the game's own check mark (the one in its check boxes), tinted green by SetCheck
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local function SetCheck(t) t:SetTexture(CHECK); t:SetVertexColor(0.3, 1, 0.25) end
local WHITE = MEDIA .. "white.tga"
local PAGE_BTN = "Interface\\Buttons\\UI-SpellbookIcon-"

-- one telling, colourful icon per class for the class picker
local CLASS_ICON = {
  warrior = "INV_Sword_48", paladin = "Spell_Holy_SealOfMight", hunter = "Ability_Marksmanship",
  rogue = "Ability_BackStab", priest = "Spell_Holy_PowerWordShield", shaman = "Spell_Nature_LightningShield",
  mage = "Spell_Frost_FrostBolt02", warlock = "Spell_Shadow_CurseOfSargeras", druid = "Spell_Nature_Rejuvenation",
}

-- the book's chapters, as tabs on its right edge
local MODULES = {
  { key = "Jewelry", label = "Jewelry", icon = MEDIA .. "tab_jewelry.tga",
    tip = "Rings, trinkets and amulets at every rarity." },
  { key = "Loot", label = "Loot", icon = MEDIA .. "tab_loot.tga", tip = "What every boss drops, zone by zone." },
  { key = "Spells", label = "Spells", icon = MEDIA .. "tab_spells.tga",
    tip = "Every spell of your class and its bonuses." },
  { key = "Builds", label = "Builds", icon = MEDIA .. "tab_builds.tga",
    tip = "Up to five builds for your class, ready for any run." },
  { key = "Chronicle", label = "Chronicle", icon = MEDIA .. "tab_chronicle.tga",
    tip = "Every run you finish, your best run and your records." },
}

local CATS = {
  { key = "Rings", label = "Rings", tile = "tile_rings", blurb = "Every ring with its value at every rarity." },
  { key = "Trinkets", label = "Trinkets", tile = "tile_trinkets", blurb = "Every trinket with its value at every rarity." },
  { key = "Amulets", label = "Basic Amulets", tile = "tile_basic", blurb = "The amulets every class can find." },
  { key = "Legendary", label = "Class Amulets", tile = "tile_class", blurb = "One legendary amulet for every spell." },
}
local ROWS, ROW_H = 7, 48

local state = { module = "Title", view = "Home", offset = 0, selected = nil, class = nil, search = "", closed = {} }
local frame, ui = nil, {}
local Refresh          -- draws the book; defined with it below
local RefreshTracker   -- draws the wishlist window; defined with it below

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffc873ffAzerloot:|r |cffe6ccff" .. msg .. "|r")
end

local function Hex(c)
  local function B(v) return math.floor(v * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x", B(c[1]), B(c[2]), B(c[3]))
end

local function CatLabel(key)
  for i = 1, table.getn(CATS) do if CATS[i].key == key then return AzT(CATS[i].label) end end
  return AzT(key)
end

-- The hero's class: from the game's run data. Between runs that line is empty, so the
-- class of the last run is kept; before any run, the character's own class.
local function PlayerClass()
  if type(AZS_ZONE) == "table" and AZS_ZONE.class and AZS_ZONE.class ~= "" then
    local c = string.lower(AZS_ZONE.class)
    if type(AzerlootDB) == "table" then AzerlootDB.lastClass = c end
    return c
  end
  if type(AzerlootDB) == "table" and AzerlootDB.lastClass then return AzerlootDB.lastClass end
  local _, c = UnitClass("player")
  if c then return string.lower(c) end
  return "warrior"
end

local function ClassInfo(key)
  for i = 1, table.getn(D.classes) do
    if D.classes[i].key == key then return D.classes[i] end
  end
  return D.classes[1]
end

-- ---------- wishlist (saved per class) ----------
local function Wish(cls)
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.wish) ~= "table" then AzerlootDB.wish = {} end
  local c = cls or PlayerClass()
  if type(AzerlootDB.wish[c]) ~= "table" then AzerlootDB.wish[c] = {} end
  return AzerlootDB.wish[c]
end

-- Rings, trinkets and amulets are keyed by name, class amulets by their spell.
local function WishKey(entry)
  if entry.kind == "Legendary" then return "class:" .. entry.item.key end
  if entry.kind == "LootItem" then return "loot:" .. entry.item.name end
  if entry.kind == "Spell" then return "spell:" .. entry.item.key end
  return entry.item.name
end

-- ---------- found in this run ----------
-- Automatic: what the hero wears in the neck, finger and trinket slots, by name.
-- By hand: right-click a wishlist entry; those marks are cleared when a new run begins.
-- Works in every language: a worn piece is recognised by its icon (the same in all
-- languages) and by its name, which Names.lua turns back into the English one.
local SLOTS = { { 2, "neck" }, { 11, "finger" }, { 12, "finger" }, { 13, "trinket" }, { 14, "trinket" } }

local function IconKey(path)
  if not path then return nil end
  local _, _, base = string.find(path, "([^\\/]+)$")
  return string.lower(base or path)
end

local function EnglishName(n)
  return (Azerloot_Names and Azerloot_Names[n]) or n
end

local function WornNames()
  local t = { names = {}, icons = { neck = {}, finger = {}, trinket = {} } }
  for i = 1, table.getn(SLOTS) do
    local slot, kind = SLOTS[i][1], SLOTS[i][2]
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if link then
      local _, _, n = string.find(link, "%[(.-)%]")
      if n then t.names[EnglishName(n)] = true end
    end
    local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
    if tex then t.icons[kind][IconKey(tex)] = true end
  end
  return t
end

local KIND_SLOT = { Rings = "finger", Trinkets = "trinket", Amulets = "neck" }

local function Marks()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.found) ~= "table" then AzerlootDB.found = {} end
  return AzerlootDB.found
end

-- Boss loot that reached the collection, per class and for good (unlike the run's marks).
-- A drop chance in a colour from green (likely) to red (rare), each with its dark edge.
local CHANCE_COLOR = {
  [60] = { { 0.18, 0.74, 0.05 }, { 0.02, 0.14, 0 } },  -- the green of the Jewelry effects
  [50] = { { 0.62, 0.78, 0.05 }, { 0.1, 0.14, 0 } },
  [40] = { { 1, 0.78, 0.08 }, { 0.25, 0.12, 0 } },
  [30] = { { 1, 0.5, 0.02 }, { 0.22, 0.07, 0 } },
  [20] = { { 0.86, 0.1, 0.06 }, { 0.2, 0, 0 } },
}
local function ChanceColor(c)
  return CHANCE_COLOR[c] or CHANCE_COLOR[40]
end

-- A boss's arrival in run minutes: "3 minutes", "1 minute".
local function Minutes(m) return (m == 1) and AzT("%d minute", m) or AzT("%d minutes", m) end

local function Collected(cls)
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.collected) ~= "table" then AzerlootDB.collected = {} end
  if type(AzerlootDB.collected[cls]) ~= "table" then AzerlootDB.collected[cls] = {} end
  return AzerlootDB.collected[cls]
end

-- at a new run: boss loot wished for that is now in the collection leaves the wishlist
-- (it was ticked in the run that brought it; the next run has no use for it)
function AzlDropCollectedLoot()
  local cls = PlayerClass()
  local w, got = Wish(cls), Collected(cls)
  local gone = {}
  for k in pairs(w) do
    local _, _, nm = string.find(k, "^loot:(.+)$")
    if nm and got[nm] then table.insert(gone, k) end
  end
  for i = 1, table.getn(gone) do w[gone[i]] = nil end
  return table.getn(gone)
end

-- After a /reload (changing the book's language is one) the game lists the run's spells
-- again only once they are cast: until then the list is empty. The spells and the phase are
-- kept when the interface goes down, and stand in for the game's until it speaks again.
function AzlSpellSnapFresh()
  local DBv = AzerlootDB
  local sn = type(DBv) == "table" and DBv.spellSnap
  if type(sn) ~= "table" or type(sn.list) ~= "table" then return nil end
  if AzlSnapDone then return nil end
  local live = type(AZS_SPELLS) == "table" and table.getn(AZS_SPELLS) > 0
  local ph = AZS_GetPhase and AZS_GetPhase() or nil
  -- the kept list is done once the game lists the spells again, once the run is over (or a
  -- new one stands ready while the kept one was already under way), or after ten minutes.
  -- The game may name its phase again before it lists the spells: that alone ends nothing.
  local over = ph == "dead" or ph == "victory" or (ph == "ready" and sn.phase ~= "ready")
  if live or over or not time or time() - (sn.at or 0) > 600 then
    AzlSnapDone = true; DBv.spellSnap = nil
    return nil
  end
  return sn
end
function AzlSpells()
  if type(AZS_SPELLS) == "table" and table.getn(AZS_SPELLS) > 0 then return AZS_SPELLS end
  local sn = AzlSpellSnapFresh()
  if sn then return sn.list end
  return (type(AZS_SPELLS) == "table") and AZS_SPELLS or {}
end
function AzlPhase()
  local ph = AZS_GetPhase and AZS_GetPhase() or nil
  local sn = AzlSpellSnapFresh()
  if sn and sn.phase and (ph == nil or ph == sn.phase or ph == "playing" or ph == "ready") then return sn.phase end
  return ph
end
AzlSnapSaver = CreateFrame("Frame")
AzlSnapSaver:RegisterEvent("PLAYER_LOGOUT")
AzlSnapSaver:SetScript("OnEvent", function()
  if type(AzerlootDB) ~= "table" then return end
  -- the phase and spells as the book knows them: after a reload with no step since, that
  -- is the kept list again, so two reloads in a row keep it too
  local ph = AzlPhase()
  local sp = AzlSpells()
  if (ph == "playing" or ph == "endless" or ph == "ready") and table.getn(sp) > 0 and time then
    local list = {}
    for i = 1, table.getn(sp) do
      table.insert(list, { key = sp[i].key, rank = sp[i].rank, spell = sp[i].spell })
    end
    AzerlootDB.spellSnap = { at = time(), phase = ph, list = list }
  else
    AzerlootDB.spellSnap = nil
  end
end)

local function KnowsSpell(key)
  local sp = AzlSpells()
  for i = 1, table.getn(sp) do
    if sp[i].key == key then return true end
  end
  return false
end

local WornAmuletKey   -- the spell the worn class amulet belongs to; set with the worn jewelry, below

-- true when worn now or marked by hand; the second value says it was by hand
local function IsFound(entry, worn)
  if entry.kind == "Spell" then return false end
  if entry.kind == "LootItem" then
    if Collected(entry.class)[entry.item.name] then return true, false end
    return false
  end
  local key = WishKey(entry)
  worn = worn or WornNames()
  if entry.kind == "Legendary" then
    -- several spells share an amulet's name: it counts for the spell the hero knows
    local amuIcon = Azerloot_AmuletIcons and Azerloot_AmuletIcons[entry.item.amulet]
    local wearing = worn.names[entry.item.amulet] or (amuIcon and worn.icons.neck[IconKey(amuIcon)])
    if wearing and entry.class and entry.class.key == PlayerClass() then
      -- the amulet's own lines name its spell; only when they cannot be read, the known spell
      local wk = WornAmuletKey and WornAmuletKey()
      if wk then
        if wk == entry.item.key then return true, false end
      elseif KnowsSpell(entry.item.key) then
        return true, false
      end
    end
  elseif worn.names[entry.item.name] or worn.icons[KIND_SLOT[entry.kind]][IconKey(entry.item.icon)] then
    return true, false
  end
  if Marks()[key] then return true, true end
  return false
end

-- Class amulets a hero of the class has worn, remembered for good: "discovered".
local function Discovered(cls)
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.amulets) ~= "table" then AzerlootDB.amulets = {} end
  if type(AzerlootDB.amulets[cls]) ~= "table" then AzerlootDB.amulets[cls] = {} end
  return AzerlootDB.amulets[cls]
end

-- How many of a class's amulets (one for every spell it has) are discovered.
local function AmuletProgress(cls)
  local info, got, have = ClassInfo(cls), Discovered(cls), 0
  for i = 1, table.getn(info.spells) do
    if got[info.spells[i].key] then have = have + 1 end
  end
  return have, table.getn(info.spells)
end

-- Every class amulet the hero wears now (or that was marked found) becomes discovered.
local function NoteAmulets()
  local info = ClassInfo(PlayerClass())
  local got, worn, changed = Discovered(info.key), WornNames(), false
  for i = 1, table.getn(info.spells) do
    local sp = info.spells[i]
    if not got[sp.key] and IsFound({ kind = "Legendary", item = sp, class = info }, worn) then
      got[sp.key] = true
      changed = true
    end
  end
  return changed
end

local function ToggleMark(entry)
  if entry.kind == "Spell" then return end
  if entry.kind == "LootItem" then
    local c = Collected(entry.class)
    if c[entry.item.name] then c[entry.item.name] = nil else c[entry.item.name] = true end
    return
  end
  local m, key = Marks(), WishKey(entry)
  if m[key] then m[key] = nil else m[key] = true end
end

local function ItemEntries(kind)
  local src = (kind == "Rings" and D.rings) or (kind == "Trinkets" and D.trinkets) or D.amulets
  local list = {}
  for i = 1, table.getn(src) do table.insert(list, { kind = kind, item = src[i] }) end
  return list
end

local function ClassEntries(info)
  local list = {}
  for i = 1, table.getn(info.spells) do
    table.insert(list, { kind = "Legendary", item = info.spells[i], class = info })
  end
  return list
end

-- One piece of boss loot as an entry, with where it drops.
local function LootEntry(cls, zi, bi, it)
  local zone = LD.zones[zi]
  -- every boss that drops it: a weapon is shared by the two zones of its rank
  LD.src = LD.src or {}
  local key = cls .. "|" .. it.name
  local src = LD.src[key]
  if not src then
    src = {}
    local zones = LD.drops[cls] or {}
    for z = 1, table.getn(zones) do
      for b = 1, table.getn(zones[z]) do
        for k = 1, table.getn(zones[z][b]) do
          if zones[z][b][k].name == it.name then
            table.insert(src, { zone = LD.zones[z], boss = LD.zones[z].bosses[b] })
          end
        end
      end
    end
    LD.src[key] = src
  end
  return { kind = "LootItem", item = it, class = cls, zone = zone, zoneIndex = zi,
    boss = zone.bosses[bi], bossIndex = bi, rarity = it.rarity or zone.rarity, sources = src }
end

-- Every piece a class can loot, in zone and boss order; a weapon two zones share counts once.
local lootCache = {}
local function LootEntries(cls)
  if lootCache[cls] then return lootCache[cls] end
  local list, seen = {}, {}
  local zones = LD.drops[cls] or {}
  for z = 1, table.getn(zones) do
    for b = 1, table.getn(zones[z]) do
      local items = zones[z][b]
      for k = 1, table.getn(items) do
        if not seen[items[k].name] then
          seen[items[k].name] = true
          table.insert(list, LootEntry(cls, z, b, items[k]))
        end
      end
    end
  end
  lootCache[cls] = list
  return list
end

-- ---------- collection progress ----------
-- How many of a zone's pieces are in the class's collection; a piece two of its bosses
-- share counts once.
local function ZoneProgress(cls, zi)
  local got, seen, have, n = Collected(cls), {}, 0, 0
  local zone = LD.drops[cls] and LD.drops[cls][zi] or {}
  for b = 1, table.getn(zone) do
    for k = 1, table.getn(zone[b]) do
      local nm = zone[b][k].name
      if not seen[nm] then
        seen[nm] = true
        n = n + 1
        if got[nm] then have = have + 1 end
      end
    end
  end
  return have, n
end

-- ... and of everything the class can loot (the weapon two zones share counts once).
local function ClassProgress(cls)
  local got, all, have = Collected(cls), LootEntries(cls), 0
  for i = 1, table.getn(all) do
    if got[all[i].item.name] then have = have + 1 end
  end
  return have, table.getn(all)
end

-- Every entry on the wishlist, in a fixed order: rings, trinkets, amulets, class amulets,
-- then boss loot.
-- ---------- spells and their bonuses in this run ----------
-- A spell's tooltip on the action bar ends with what this run did to it: its improvements
-- ("Improvements: +65% damage") and, in green, its bonuses ("Your bonuses: +122% damage,
-- -25% cooldown, +1 target"), in the player's language. The book reads those lines from a
-- hidden tooltip, so the player need not hover the bar. Talents and the rest are left out.
local function SpellEntries(cls)
  local list, info = {}, ClassInfo(cls)
  for i = 1, table.getn(info.spells) do
    table.insert(list, { kind = "Spell", item = info.spells[i], class = info })
  end
  return list
end

-- every class spell's id in the game (from its spell table)
local SPELL_ID = { cleave = 845, whirlwind = 1680, thunder_clap = 6343, mortal_strike = 12294, execute = 5308, demo_shout = 1160, battle_shout = 6673, bloodthirst = 23881, rend = 772, shield_slam = 23922, bloodrage = 2687, consecration = 26573, exorcism = 879, hammer_of_wrath = 24275, holy_shock = 25912, holy_wrath = 2812, judgement = 20271, hammer_of_justice = 853, holy_light = 635, divine_shield = 642, holy_shield = 20925, redemption = 7328, auto_shot = 75, arcane_shot = 3044, multi_shot = 2643, serpent_sting = 1978, volley = 1510, explosive_trap = 13812, concussive_shot = 5116, aimed_shot = 19434, immolation_trap = 13797, frost_trap = 13810, hunters_mark = 1130, sinister_strike = 1752, eviscerate = 2098, blade_flurry = 13877, rupture = 1943, kidney_shot = 408, gouge = 1776, ghostly_strike = 14278, adrenaline_rush = 13750, backstab = 53, slice_and_dice = 5171, seal_fate = 14186, smite = 585, sw_pain = 589, mind_blast = 8092, holy_nova = 15237, pw_shield = 17, renew = 139, holy_fire = 14914, mind_flay = 15407, psychic_scream = 8122, devouring_plague = 2944, lightwell = 724, lightning_bolt = 403, chain_lightning = 421, earth_shock = 8042, flame_shock = 8050, frost_shock = 8056, lightning_shield = 324, magma_totem = 8190, searing_totem = 3599, fire_nova = 1535, healing_wave = 331, call_of_flame = 16038, fireball = 133, frostbolt = 116, arcane_missiles = 7269, frost_nova = 122, arcane_explosion = 1449, blizzard = 10, flamestrike = 2120, fire_blast = 2136, cone_of_cold = 120, blast_wave = 11113, pyroblast = 11366, ice_barrier = 11426, polymorph = 118, shadow_bolt = 686, corruption = 172, immolate = 348, curse_of_agony = 980, rain_of_fire = 5740, hellfire = 1949, death_coil = 6789, searing_pain = 5676, drain_life = 689, fear = 5782, soul_fire = 6353, demonic_empowerment = 18708, wrath = 5176, moonfire = 8921, starfire = 2912, hurricane = 16914, insect_swarm = 5570, entangling_roots = 339, rejuvenation = 774, regrowth = 8936, thorns = 467, swipe = 779, shred = 5221, faerie_fire = 770, perception = 20600, blood_fury = 23234, stoneform = 20594, shadowmeld = 20580, will_of_the_forsaken = 7744, war_stomp = 20549, escape_artist = 20589, berserking = 26635, penance = 25912, arcane_power = 12042 }
local spellScan = { bonus = {}, at = -10 }   -- the action bar's spells, read at most once a second
local function ScanTip()
  if not AzerlootScanTip then CreateFrame("GameTooltip", "AzerlootScanTip", UIParent, "GameTooltipTemplate") end
  return AzerlootScanTip
end

-- ---------- the game's words in English ----------
-- The game writes its tooltips in the language it runs in. Its own translation tables
-- (locales\Tooltips.lua) turn them back into English: whole texts directly, texts with values
-- by matching their pattern and putting the values, themselves turned back, into the
-- English text. Whatever cannot be matched stays as the game wrote it.
local TT = Azerloot_TT or {}
local LOCALE_TT = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", ptBR = "pt", ptPT = "pt",
  plPL = "pl", ruRU = "ru", koKR = "ko", zhCN = "zh", zhTW = "zh", trTR = "enx", csCZ = "cs" }
local ttState = { lang = nil, cache = {} }   -- the tooltips' language once found, and texts done
local sfind_all = string.gfind or string.gmatch

-- the language a tooltip is written in, found by its labels; else the client's
local function TTLang(text)
  if ttState.lang then return ttState.lang end
  -- languages share some labels (German and Romanian both say "Talente: "): the one with
  -- the most labels in the text wins, a tie goes to the language listed first
  local best, bestN, tie = nil, 0, false
  local order = { "de", "fr", "es", "pt", "pl", "ru", "uk", "ro", "ko", "zh", "ja", "enx", "cs" }
  for i = 1, table.getn(order) do
    local d = TT[order[i]]
    local n = 0
    for _, lab in pairs(d and d.labels or {}) do
      if lab ~= "" and string.find(text, lab, 1, true) then n = n + 1 end
    end
    if n > bestN then best, bestN, tie = order[i], n, false
    elseif n > 0 and n == bestN then tie = true end
  end
  -- kept for the session only when no other language says the same (Polish and Czech
  -- both write "Talenty: "): a tie is used for this text, and asked again with the next
  if best and not tie then ttState.lang = best; AzNoteGameLang(best); return best end
  if best then return best end
  return GetLocale and LOCALE_TT[GetLocale()] or nil
end

-- Returns the English text and whether all of it could be put into English. A pattern that
-- matches is taken only if each of its values comes out in English too; otherwise the next
-- one is tried, and a whole text is also tried sentence by sentence.
local function Tr(s, d, depth)
  local _, _, lead, core, trail = string.find(s, "^(%s*)(.-)(%s*)$")
  if not core or core == "" then return s, true end
  if string.find(core, "^[%d%.,%%%+%-]+$") then return lead .. (string.gsub(core, "(%d),(%d)", "%1.%2")) .. trail, true end
  local hit = d.exact[core]
  if hit then return lead .. hit .. trail, true end
  d.memo = d.memo or {}
  local m = d.memo[core]
  if m then return lead .. m[1] .. trail, m[2] end
  local best
  if depth < 5 then
    for i = 1, table.getn(d.tpl) do
      local t = d.tpl[i]
      local caps = { string.find(core, t[1]) }
      if caps[1] then
        local vals, used, allok = {}, {}, true
        for j = 1, table.getn(t[2]) do
          local nm = t[2][j]
          local v, ok = Tr(caps[j + 2] or "", d, depth + 1)
          if not ok then allok = false end
          vals[nm] = vals[nm] or {}
          table.insert(vals[nm], v)
        end
        local out = string.gsub(t[3], "{([%w_]+)}", function(nm)
          used[nm] = (used[nm] or 0) + 1
          return (vals[nm] and (vals[nm][used[nm]] or vals[nm][1])) or ""
        end)
        if allok then d.memo[core] = { out, true }; return lead .. out .. trail, true end
        best = best or out
      end
    end
  end
  if depth < 4 then
    -- the game's sentences end in a full stop and start with a capital, its parts do not:
    -- "Die Treffer von Zorn springen ... ueber." is "die Treffer von {spell}" in a sentence
    local plain, dot = core, ""
    if string.find(plain, "%.$") then plain, dot = string.sub(plain, 1, -2), "." end
    local first = string.sub(plain, 1, 1)
    local low = string.lower(first) .. string.sub(plain, 2)
    if dot ~= "" or low ~= plain then
      local v, ok = Tr(plain, d, depth + 1)
      if not ok and low ~= plain then v, ok = Tr(low, d, depth + 1) end
      if ok then
        v = string.upper(string.sub(v, 1, 1)) .. string.sub(v, 2) .. dot
        d.memo[core] = { v, true }
        return lead .. v .. trail, true
      end
    end
  end
  if depth == 0 then
    -- sentence by sentence: a full stop, then a capital letter
    local parts, rest, allok = {}, core, true
    while true do
      local a, b = string.find(rest, "%.%s+%u")
      if not a then break end
      table.insert(parts, string.sub(rest, 1, a)); rest = string.sub(rest, b)
    end
    table.insert(parts, rest)
    if table.getn(parts) > 1 then
      for i = 1, table.getn(parts) do
        local v, ok = Tr(parts[i], d, 1)
        if not ok then allok = false end
        parts[i] = v
      end
      local out = table.concat(parts, " ")
      if allok then d.memo[core] = { out, true }; return lead .. out .. trail, true end
      best = best or out
    end
  end
  d.memo[core] = { best or core, false }
  return lead .. (best or core) .. trail, false
end

-- a text of the game in English (as it came, if the game runs in English)
-- Only a text that comes out wholly in English is used; a half-translated one would mix
-- the languages, so the game's own words are kept instead. A label before a colon ("Equip:",
-- which the game may already write in English) is put into English by itself.
local function English(text, lang)
  if not text or text == "" then return text end
  -- the book in the game's own language: the game's words as they are
  local book = AzLang()
  if book ~= "en" and (lang == book or (not lang and GetLocale and string.sub(GetLocale(), 1, 2) == book)) then return text end
  local d = lang and TT[lang]
  if not d then return AzG(text) end
  if not ttState.cache[text] then
    local out, ok = Tr(text, d, 0)
    if not ok then
      local _, _, pre, rest = string.find(text, "^([^:]+):%s+(.+)$")
      if pre then
        local p = (pre == "Equip" and "Equip") or d.exact[pre]
        local r, rok = Tr(rest, d, 0)
        if p and rok then out, ok = p .. ": " .. r, true end
      end
    end
    ttState.cache[text] = ok and out or text
  end
  return AzG(ttState.cache[text])
end

-- A spell's tooltip, read from a hidden copy: what it does (the first paragraph of its text)
-- and the bonuses this run gave it (the line after "Your bonuses: "). Improvements, talents
-- and set bonuses are left out.
local function ReadSpellTip(tip)
  local texts = {}
  for l = 2, (tip:NumLines() or 0) do
    local fs = getglobal("AzerlootScanTipTextLeft" .. l)
    local t = fs and fs:GetText()
    if type(t) == "string" then table.insert(texts, t) end
  end
  local all = string.gsub(table.concat(texts, "\n"), "|c%x%x%x%x%x%x%x%x", "")
  all = string.gsub(all, "|r", "")
  local lang = TTLang(all)
  local labels = (lang and TT[lang] and TT[lang].labels) or {}
  local bonusLabel = labels.bonuses or "Your bonuses: "
  local upLabel = labels.upgrades or "Upgrades: "
  local desc, bonus, upgrades = nil, nil, nil
  -- the description: the first longer text, up to its first empty line
  for i = 1, table.getn(texts) do
    local t = string.gsub(string.gsub(texts[i], "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    local _, _, first = string.find(t .. "\n", "^(.-)\n")
    if first and (string.len(first) >= 30 or string.find(first, "%.$")) then desc = first; break end
  end
  for seg in sfind_all(all .. "\n", "(.-)\n") do
    local a, b = string.find(seg, bonusLabel, 1, true)
    if not a then a, b = string.find(seg, "Your bonuses: ", 1, true) end
    if a == 1 then bonus = string.sub(seg, b + 1) end
    -- the upgrades the level-ups gave it
    local c, e = string.find(seg, upLabel, 1, true)
    if not c then c, e = string.find(seg, "Upgrades: ", 1, true) end
    if c == 1 then upgrades = string.sub(seg, e + 1) end
  end
  -- the description in English, to tell the game's own words from the old client's: the game
  -- writes a spell's text only for the hero's class; another class's spell comes back with
  -- the client's original (English) text, which the game never translated
  local descEn = desc
  if desc and lang and lang ~= "en" and TT[lang] then
    local o, ok = Tr(desc, TT[lang], 0)
    descEn = ok and o or nil
  end
  local game = descEn and AzlGameTextEn(descEn) or false
  if desc then desc = English(desc, lang) end
  -- each value by itself: "+83% Schaden, -25% Abklingzeit" -> "+83% damage, -25% cooldown"
  local function Values(list)
    if not list then return nil end
    local parts = {}
    -- split at ", " only: a decimal comma ("1,5%") stays inside its value
    for v in sfind_all(list .. ", ", "(.-), ") do
      v = string.gsub(v, "^%s+", "")
      if v ~= "" then table.insert(parts, English(v, lang)) end
    end
    return table.concat(parts, ", ")
  end
  return { desc = desc, bonus = Values(bonus), upgrades = Values(upgrades), en = descEn, game = game }
end

-- the spells on the action bar, by key, read again at most once a second
local function SpellBonuses()
  if GetTime and GetTime() - spellScan.at < 1 then return spellScan.bonus end
  spellScan.at = GetTime and GetTime() or 0
  spellScan.bonus = {}
  if not (HasAction and GetActionTexture) then return spellScan.bonus end
  local byIcon = {}
  local spells = ClassInfo(PlayerClass()).spells
  for i = 1, table.getn(spells) do byIcon[string.lower(spells[i].icon)] = spells[i].key end
  local tip = ScanTip()
  for slot = 1, 120 do
    if HasAction(slot) then
      local tex = GetActionTexture(slot)
      local key = type(tex) == "string" and byIcon[string.lower((string.gsub(tex, "^.*\\", "")))]
      if key and not spellScan.bonus[key] then
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearLines()
        tip:SetAction(slot)
        spellScan.bonus[key] = ReadSpellTip(tip)
        tip:Hide()
      end
    end
  end
  return spellScan.bonus
end

-- What a spell does, for every spell of every class, learned or not: the game shows a spell's
-- tooltip for an "enchant:<id>" link. Read once a second at most, then kept.
-- Another class's spell never changes and is kept once read; the hero's own are read again
-- (at most once a second), as a run raises their numbers.
local spellCache = { desc = {}, at = {}, info = {} }
-- a name set a size smaller, step by step, until it fits on one line (not below `min`)
function AzlFitText(fs, w, size, min)
  local face, _, flags = fs:GetFont()
  if not face then return end
  local sz = size
  fs:SetFont(face, sz, flags)
  while sz > min and (fs:GetStringWidth() or 0) > w do
    sz = sz - 1
    fs:SetFont(face, sz, flags)
  end
end
-- true for a text that is one of the game's own (its German table has them all)
function AzlGameTextEn(t)
  local g = Azerloot_GT and Azerloot_GT.de
  if type(g) ~= "table" or type(t) ~= "string" then return false end
  if type(AzlGameMemo) ~= "table" then AzlGameMemo = {} end
  if AzlGameMemo[t] ~= nil then return AzlGameMemo[t] end
  -- the game's words go wholly into its German table; the old client's do not
  local hit = true
  local parts = {}
  for seg in sfind_all(t .. "\n", "(.-)\n") do table.insert(parts, seg) end
  for i = 1, table.getn(parts) do
    local _, ok = Tr(parts[i], g, 0)
    if not ok then hit = false end
  end
  AzlGameMemo[t] = hit
  return hit
end
-- a spell newer than the game's own spell table: its words from the game's text, with its
-- numbers from the game's spell list (cooldown 16 sec)
AZL_SPELL_TEXT = {
  demonic_empowerment = "Your demons deal 40% more damage for 8 sec. Cast once enemies are within 30 yd and a demon fights for you.",
}
local function SpellDesc(key, force)
  local id = SPELL_ID[key]
  if not id then return nil end
  local now = GetTime and GetTime() or 0
  if not force and spellCache.desc[key] then
    local mine = false
    local own = ClassInfo(PlayerClass()).spells
    for i = 1, table.getn(own) do if own[i].key == key then mine = true end end
    if not mine or now - (spellCache.at[key] or -10) < 1 then return spellCache.desc[key] end
  elseif not force and spellCache.desc[key] == false and now - (spellCache.at[key] or -10) < 0.5 then
    return nil
  end
  spellCache.at[key] = now
  local tip = ScanTip()
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  local ok = pcall(function() tip:SetHyperlink("enchant:" .. id) end)
  local info = ok and (tip:NumLines() or 0) > 1 and ReadSpellTip(tip) or nil
  local d = info and info.desc
  if info then
    if info.game and info.en then
      -- the game's own text: kept, so the book can show it when this class is not played
      if type(AzerlootDB) == "table" then
        if type(AzerlootDB.spellDesc) ~= "table" then AzerlootDB.spellDesc = {} end
        AzerlootDB.spellDesc[key] = info.en
      end
    else
      local saved = type(AzerlootDB) == "table" and type(AzerlootDB.spellDesc) == "table" and AzerlootDB.spellDesc[key]
      if saved then d = AzG(saved)
      elseif AZL_SPELL_TEXT[key] then d = AzT(AZL_SPELL_TEXT[key])
      elseif AzLang() ~= "en" then d = AzT("The game describes a spell only to its own class. Play that class once, and its text is kept here.") end
    end
  end
  tip:Hide()
  if not d and AZL_SPELL_TEXT[key] then d = AzT(AZL_SPELL_TEXT[key]) end
  spellCache.desc[key] = d or false
  if d then spellCache.info[key] = info end
  return d
end

-- a few words under each spell's name, as if overheard on the battlefield
local SPELL_QUOTE = {
  cleave = "One swing, many regrets.", whirlwind = "Stand still and let them come.",
  thunder_clap = "The ground answers the shield.", mortal_strike = "Some wounds never close.",
  execute = "The weak are finished last.", demo_shout = "Fear weakens every arm.",
  battle_shout = "One voice, a hundred blades.", bloodthirst = "Each hit feeds the next.",
  rend = "Let them bleed the slow way.", shield_slam = "A shield is a weapon too.",
  bloodrage = "Pain is just more fuel.",
  consecration = "Holy ground burns the unworthy.", exorcism = "Begone, and stay gone.",
  hammer_of_wrath = "Judgement falls from above.", holy_shock = "Light that heals and harms.",
  holy_wrath = "The Light does not forgive.", judgement = "The verdict is final.",
  hammer_of_justice = "Kneel before the hammer.", holy_light = "Rise, and fight again.",
  divine_shield = "Untouchable, for a moment.", holy_shield = "Faith turns the blade.",
  redemption = "No soul left behind.",
  auto_shot = "Every breath, another arrow.", arcane_shot = "Magic on the tip of a shaft.",
  multi_shot = "Why aim for just one?", serpent_sting = "The venom does the waiting.",
  volley = "Let it rain arrows.", explosive_trap = "Mind your step.",
  concussive_shot = "Slow them, then end them.", aimed_shot = "Patience hits harder.",
  immolation_trap = "A warm welcome.", frost_trap = "Cold ground, slow feet.",
  hunters_mark = "Nowhere left to hide.",
  sinister_strike = "Quick, dirty, effective.", eviscerate = "Save it all for the finish.",
  blade_flurry = "Two blades, twice the trouble.", rupture = "A cut that keeps on cutting.",
  kidney_shot = "Right where it hurts.", gouge = "Look away. Too late.",
  ghostly_strike = "Here, then gone.", adrenaline_rush = "Faster than fear.",
  backstab = "Never from the front.", slice_and_dice = "Speed is the sharpest edge.",
  seal_fate = "Fortune favours the precise.",
  smite = "The Light strikes plainly.", sw_pain = "Suffering, slowly spoken.",
  mind_blast = "A thought that shatters.", holy_nova = "Light in every direction.",
  pw_shield = "A word between you and harm.", renew = "Healing takes its time.",
  holy_fire = "Faith that burns.", mind_flay = "The mind breaks before the body.",
  psychic_scream = "Run, and do not look back.", devouring_plague = "A hunger that spreads.",
  lightwell = "Drink deep of the Light.",
  lightning_bolt = "The sky takes a side.", chain_lightning = "It never strikes just once.",
  earth_shock = "The earth has a temper.", flame_shock = "Fire that lingers.",
  frost_shock = "Cold enough to stop a charge.", lightning_shield = "Touch me and find out.",
  magma_totem = "The ground itself rises.", searing_totem = "A small flame with a long reach.",
  fire_nova = "The totem's last word.", healing_wave = "The tide returns what it took.",
  call_of_flame = "The fire answers its kin.",
  fireball = "The classic never fades.", frostbolt = "Cold, slow and certain.",
  arcane_missiles = "Pure magic, poured out.", frost_nova = "Hold still. Forever, if you like.",
  arcane_explosion = "Too close is too late.", blizzard = "Winter on demand.",
  flamestrike = "A circle of ruin.", fire_blast = "No time to aim.",
  cone_of_cold = "A breath of deep winter.", blast_wave = "Step back. Further.",
  pyroblast = "Worth the wait.", ice_barrier = "A wall of winter around you.",
  polymorph = "Everyone deserves a second form.",
  shadow_bolt = "The darkness has good aim.", corruption = "Rot from within.",
  immolate = "Burn now, burn later.", curse_of_agony = "The pain only grows.",
  rain_of_fire = "The sky falls in flames.", hellfire = "Burn with them, burn brighter.",
  death_coil = "A dark coil of terror.", searing_pain = "Simple. Searing.",
  drain_life = "Their life, your gain.", fear = "Run, little ones.",
  soul_fire = "A soul burns hottest.", demonic_empowerment = "Your servants, unleashed.",
  wrath = "Nature's anger, made small.", moonfire = "The moon remembers.",
  starfire = "A star, brought low.", hurricane = "The wind takes sides.",
  insect_swarm = "A thousand tiny bites.", entangling_roots = "The forest holds them fast.",
  rejuvenation = "Spring, in a breath.", regrowth = "Life grows back stronger.",
  thorns = "Every rose has them.", swipe = "Claws for everyone.",
  faerie_fire = "Glowing marks make easy targets.", shred = "Teeth and claws, nothing more.",
}
local function SpellSub(entry)
  local q = SPELL_QUOTE[entry.item.key]
  if q then return "\"" .. AzT(q) .. "\"" end
  return AzT("%s spell", AzG(entry.class.name))
end

-- The game may need a moment to know a spell it has not shown yet. So all spells are asked
-- for once, a few each frame, when the book first opens, and asked again while one is
-- missing; the open page is redrawn as soon as its spell has an answer.
local descWarm = CreateFrame("Frame")
descWarm.queue, descWarm.dirty, descWarm.since = false, false, 0
descWarm:Hide()
local function WarmSpellDescs()
  if descWarm.queue then return end
  local q = {}
  local classes = D.classes
  for c = 1, table.getn(classes) do
    for i = 1, table.getn(classes[c].spells) do table.insert(q, classes[c].spells[i].key) end
  end
  descWarm.queue, descWarm.pos, descWarm.round, descWarm.wait = q, 1, 1, 0
  descWarm:Show()
end
descWarm:SetScript("OnUpdate", function()
  -- new answers redraw the open Spells pages, at most four times a second
  this.since = (this.since or 0) + (arg1 or 0)
  if this.dirty and this.since > 0.25 then
    this.dirty, this.since = false, 0
    if frame and frame:IsVisible() and state.module == "Spells" and not ui.flipping then Refresh() end
  end
  if this.wait > 0 then this.wait = this.wait - (arg1 or 0); return end
  local q, missing = this.queue, false
  for n = 1, 4 do
    local key = q[this.pos]
    if not key then break end
    if not spellCache.desc[key] then
      SpellDesc(key, true)
      if spellCache.desc[key] then this.dirty = true end
    end
    this.pos = this.pos + 1
  end
  if this.pos > table.getn(q) then
    for i = 1, table.getn(q) do if not spellCache.desc[q[i]] then missing = true end end
    this.round = this.round + 1
    if not missing then
      if this.dirty and frame and frame:IsVisible() and state.module == "Spells" then Refresh() end
      this.dirty = false
      this:Hide(); return
    end
    if this.round > 20 then this.queue = false; this:Hide(); return end  -- may be asked again later
    this.pos, this.wait = 1, 0.5
  end
end)

-- its upgrades from level-ups, in white as in the game's tooltip (its green bonuses are left out)
local function SpellLine(key)
  local b = SpellBonuses()[key]
  if not b or not b.upgrades or b.upgrades == "" then return nil end
  -- one value per line, each under the one before, in the green of the jewelry's lines
  return "|cff4dff4d" .. string.gsub(b.upgrades, ", ", "|r\n|cff4dff4d") .. "|r"
end

-- ---------- worn jewelry, read live ----------
-- A worn ring, trinket or amulet shows in the wishlist window with the green lines of its
-- own tooltip (what it gives at the rarity it was found in), in English, kept up to date.
local function GreenCode(hex)
  local r, g, b = tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16), tonumber(string.sub(hex, 7, 8), 16)
  return r and g and b and g > 180 and r < 150 and b < 150
end

local function WornSlot(entry)
  local k = entry.kind
  if not (k == "Rings" or k == "Trinkets" or k == "Amulets" or k == "Legendary") then return nil end
  local want = (k == "Legendary") and entry.item.amulet or entry.item.name
  local wantIcon = (k == "Legendary") and Azerloot_AmuletIcons and Azerloot_AmuletIcons[want] or entry.item.icon
  local slotKind = KIND_SLOT[k] or "neck"
  for i = 1, table.getn(SLOTS) do
    local slot = SLOTS[i][1]
    if SLOTS[i][2] == slotKind then
      local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
      local _, _, n = string.find(link or "", "%[(.-)%]")
      if n and EnglishName(n) == want then return slot end
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
      if tex and wantIcon and IconKey(tex) == IconKey(wantIcon) then return slot end
    end
  end
  return nil
end

local wornCache = { read = {}, at = {}, link = {} }   -- per slot: its lines, when, for which piece
local function WornLine(entry)
  local slot = WornSlot(entry)
  if not slot then return nil end
  local now = GetTime and GetTime() or 0
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or ""
  if wornCache.read[slot] ~= nil and wornCache.link[slot] == link and now - (wornCache.at[slot] or -10) < 1 then return wornCache.read[slot] or nil end
  wornCache.at[slot], wornCache.link[slot] = now, link
  local tip = ScanTip()
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  local ok = pcall(function() tip:SetInventoryItem("player", slot) end)
  local found = {}
  if ok then
    for l = 2, (tip:NumLines() or 0) do
      local fs = getglobal("AzerlootScanTipTextLeft" .. l)
      local raw = fs and fs:GetText()
      if type(raw) == "string" then
        local whole = false
        if fs.GetTextColor then
          local r, g, b = fs:GetTextColor()
          whole = type(g) == "number" and g > 0.7 and r < 0.6 and b < 0.6
        end
        for seg in sfind_all(raw .. "\n", "(.-)\n") do
          local _, _, hex = string.find(seg, "|c(%x%x%x%x%x%x%x%x)")
          local plain = string.gsub(string.gsub(seg, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
          if plain ~= "" and ((hex and GreenCode(hex)) or (whole and not hex)) then
            table.insert(found, English(plain, TTLang(plain)))
          end
        end
      end
    end
  end
  tip:Hide()
  local text = table.getn(found) > 0 and table.concat(found, "\n") or nil
  wornCache.read[slot] = text or false
  return text
end

-- A worn piece's lines, short: the game's whole sentences ("Increases all damage you deal by
-- 146%.") become the book's own words with the numbers the game shows now ("+146% damage").
-- Rings and trinkets take the form of their value, amulets that of each effect, line by line.
-- Where the numbers do not fit the form, the game's sentence stays.
function AzlShortWorn(entry, text)
  if type(text) ~= "string" or text == "" then return text end
  local it = entry.item
  if it.noShort then return text end   -- (its forms name no numbers to fill)
  local forms
  if entry.kind == "Rings" or entry.kind == "Trinkets" then forms = it.values and { it.values[1] }
  elseif entry.kind == "Amulets" or entry.kind == "Legendary" then forms = it.effects end
  if type(forms) ~= "table" or table.getn(forms) == 0 then return text end
  local NUM = "%d+%.?%d*"
  local function Nums(t)
    local out = {}
    for n in sfind_all(t, NUM) do table.insert(out, n) end
    return out
  end
  -- the book's own words for a form, in the book's language, with the game's numbers in
  -- place of the book's: each number found again by its value, wherever the language
  -- puts it ("for 80% more over 4 sec" / "lassen über 4 Sek. für 80% mehr")
  local function Say(form, have)
    local orig = Nums(form)
    local said = AzG(form)
    if said == form and AzLang() ~= "en" then return nil end   -- not in the book's language
    local used = {}
    local out = string.gsub(said, "%d+[%.,]?%d*", function(n)
      local key = string.gsub(n, ",", ".")
      for i = 1, table.getn(orig) do
        if orig[i] == key and not used[i] then
          used[i] = true
          local v = have[i]
          if string.find(n, ",") then v = string.gsub(v, "%.", ",") end
          return v
        end
      end
      return n
    end)
    return out
  end
  local lines = {}
  for seg in sfind_all(text .. "\n", "(.-)\n") do if seg ~= "" then table.insert(lines, seg) end end
  local out = {}
  if table.getn(forms) == 1 or table.getn(lines) ~= table.getn(forms) then
    -- one form for all the numbers of the text, in their order
    if table.getn(forms) ~= 1 then return text end
    local need, have = table.getn(Nums(forms[1])), Nums(text)
    -- one number: the first the game names; several: only when the game names as many
    if need == 0 or table.getn(have) < need or (need > 1 and table.getn(have) ~= need) then return text end
    local said = Say(forms[1], have)
    if not said then return text end
    table.insert(out, said)
  else
    for i = 1, table.getn(forms) do
      local need, have = table.getn(Nums(forms[i])), Nums(lines[i])
      if table.getn(have) < need or (need > 1 and table.getn(have) ~= need) then return text end
      local said = Say(forms[i], have)
      if not said then return text end
      table.insert(out, said)
    end
  end
  return table.concat(out, "\n")
end

-- Several spells share a class amulet's name (Eye of the Splitting Sky for Wrath and for
-- Starfire, Pendant of the Plague for Moonfire and Insect Swarm): the worn one's own lines
-- name its spell. Every line of its tooltip is read, whatever its colour, as the game gives
-- it and in English. nil when it cannot be told.
-- (kept on wornCache: the file has no room for more locals of its own)
wornCache.neck = { link = false, at = -10, text = "" }
function wornCache.NeckText()
  local now = GetTime and GetTime() or 0
  local link = GetInventoryItemLink and GetInventoryItemLink("player", 2) or ""
  if wornCache.neck.link == link and now - wornCache.neck.at < 1 then return wornCache.neck.text end
  local tip = ScanTip()
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  local out = {}
  local ok = pcall(function() tip:SetInventoryItem("player", 2) end)
  if ok then
    for l = 2, (tip:NumLines() or 0) do
      local fs = getglobal("AzerlootScanTipTextLeft" .. l)
      local raw = fs and fs:GetText()
      if type(raw) == "string" then
        local plain = string.gsub(string.gsub(raw, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
        table.insert(out, plain)
        local en = English(plain, TTLang(plain))
        if type(en) == "string" and en ~= plain then table.insert(out, en) end
      end
    end
  end
  tip:Hide()
  wornCache.neck.link, wornCache.neck.at, wornCache.neck.text = link, now, table.concat(out, "\n")
  return wornCache.neck.text
end

WornAmuletKey = function()
  local info, name, icon = ClassInfo(PlayerClass()), nil, nil
  local link = GetInventoryItemLink and GetInventoryItemLink("player", 2)
  local _, _, n = string.find(link or "", "%[(.-)%]")
  if n then name = EnglishName(n) end
  local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", 2)
  if tex then icon = IconKey(tex) end
  if not (name or icon) then return nil end
  -- the class spells whose amulet it is: by its name, else by its icon
  local cand = {}
  for i = 1, table.getn(info.spells) do
    if name and info.spells[i].amulet == name then table.insert(cand, info.spells[i]) end
  end
  if table.getn(cand) == 0 and icon then
    for i = 1, table.getn(info.spells) do
      local ai = Azerloot_AmuletIcons and Azerloot_AmuletIcons[info.spells[i].amulet or ""]
      if ai and IconKey(ai) == icon then table.insert(cand, info.spells[i]) end
    end
  end
  if table.getn(cand) == 0 then return nil end
  if table.getn(cand) == 1 then return cand[1].key end
  -- its lines name the spell; the longest name wins (Hammer of Wrath over Wrath)
  local text = wornCache.NeckText()
  local best, bl = nil, 0
  for i = 1, table.getn(cand) do
    local names = { cand[i].name, AzG(cand[i].name) }
    for k = 1, 2 do
      local nm = names[k]
      if type(nm) == "string" and nm ~= "" and string.find(text, nm, 1, true) and string.len(nm) > bl then
        best, bl = cand[i].key, string.len(nm)
      end
    end
  end
  if best then return best end
  -- the lines cannot tell: the one spell of them the hero knows in this run
  local known = nil
  for i = 1, table.getn(cand) do
    if KnowsSpell(cand[i].key) then
      if known then return nil end
      known = cand[i].key
    end
  end
  return known
end

-- A spell the hero picks up in a run (at the start or with a level-up) goes on the wishlist
-- by itself, so the window shows it with its improvements. It comes off again when the next
-- run begins, unless it was put there by hand.
local function AutoSpells()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if type(AzerlootDB.autoSpells) ~= "table" then AzerlootDB.autoSpells = {} end
  local c = PlayerClass()
  if type(AzerlootDB.autoSpells[c]) ~= "table" then AzerlootDB.autoSpells[c] = {} end
  return AzerlootDB.autoSpells[c]
end

-- true if anything was added
local function WishLearnedSpells()
  if type(AzerlootDB) == "table" and AzerlootDB.spellTracker == false then return false end
  -- from the moment a run starts ("ready", before the first step) until it ends
  local ph = AzlPhase()
  if ph ~= "ready" and ph ~= "playing" then return false end
  local mine, byIcon = {}, {}
  local spells = ClassInfo(PlayerClass()).spells
  for i = 1, table.getn(spells) do
    mine[spells[i].key] = true
    if spells[i].icon then byIcon[string.lower(spells[i].icon)] = spells[i].key end
  end
  local keys = {}
  -- what the hero has on the action bar's first six buttons, known before a single cast
  if HasAction and GetActionTexture then
    for slot = 1, 6 do
      if HasAction(slot) then
        local tex = GetActionTexture(slot)
        local k = type(tex) == "string" and byIcon[string.lower((string.gsub(tex, "^.*\\", "")))]
        if k then table.insert(keys, k) end
      end
    end
  end
  -- and, once the run is under way, every spell the game lists for it
  if ph == "playing" then
    local sp = AzlSpells()
    for i = 1, table.getn(sp) do table.insert(keys, sp[i].key) end
  end
  local auto, w, added = AutoSpells(), Wish(), false
  for i = 1, table.getn(keys) do
    local k = keys[i]
    if k and mine[k] and not auto[k] then
      local key = "spell:" .. k
      if w[key] then auto[k] = "hand" else auto[k] = "auto"; w[key] = true; added = true end
    end
  end
  return added
end

-- a new run: the spells added by themselves come off the wishlist
local function ForgetLearnedSpells()
  if type(AzerlootDB) ~= "table" or type(AzerlootDB.autoSpells) ~= "table" then return end
  for cls, t in pairs(AzerlootDB.autoSpells) do
    local w = Wish(cls)
    for k, how in pairs(t) do if how == "auto" then w["spell:" .. k] = nil end end
  end
  AzerlootDB.autoSpells = {}
end

-- entries off the wishlist; a spell taken off by hand is not added again by itself
-- in this run
function AzlUnwish(entries)
  local w, auto, keys = Wish(), AutoSpells(), {}
  for i = 1, table.getn(entries) do
    local e = entries[i]
    local k = WishKey(e)
    w[k] = nil
    table.insert(keys, k)
    if e.kind == "Spell" and e.item and e.item.key then auto[e.item.key] = "off" end
  end
  if AzlB and AzlB.Unwished then AzlB.Unwished(PlayerClass(), keys) end
end

local function WishEntries()
  local list, w = {}, Wish()
  local function Put(all)
    for i = 1, table.getn(all) do
      if w[WishKey(all[i])] then table.insert(list, all[i]) end
    end
  end
  -- the amulet first (a basic one or the class amulet: they share the neck), then the rings,
  -- then the trinkets
  Put(ItemEntries("Amulets"))
  -- class amulets: only the hero's own; another class's that slipped in is taken off
  local own, mine = ClassInfo(PlayerClass()), {}
  local all = ClassEntries(own)
  for i = 1, table.getn(all) do mine[WishKey(all[i])] = true end
  Put(all)
  for k in pairs(w) do
    if string.sub(k, 1, 6) == "class:" and not mine[k] then w[k] = nil end
  end
  Put(ItemEntries("Rings"))
  Put(ItemEntries("Trinkets"))
  local loot = LootEntries(PlayerClass())
  for i = 1, table.getn(loot) do
    if w[WishKey(loot[i])] then table.insert(list, loot[i]) end
  end
  if not (type(AzerlootDB) == "table" and AzerlootDB.spellTracker == false) then
    local spells = SpellEntries(PlayerClass())
    for i = 1, table.getn(spells) do
      if w[WishKey(spells[i])] then table.insert(list, spells[i]) end
    end
  end
  return list
end

local function EntryTitle(entry)
  local it = entry.item
  if entry.kind == "Rings" or entry.kind == "Trinkets" then
    return AzG(it.name), { 1, 0.82, 0 }, AzName(entry.kind == "Rings" and "Ring" or "Trinket") .. " - " .. AzName(it.cat)
  elseif entry.kind == "Amulets" then
    return AzG(it.name), RARITY_COLOR[it.rarity], AzT("%s amulet", AzG(it.rarity))
  elseif entry.kind == "LootItem" then
    return AzG(it.name), RARITY_COLOR[entry.rarity], AzG(entry.rarity) .. " " .. AzName(it.slot) .. " - " .. AzG(entry.boss.name)
  elseif entry.kind == "Spell" then
    return AzG(it.name), { 1, 0.82, 0 }, AzT("%s spell", AzG(entry.class.name))
  end
  return AzG(it.amulet), { 1, 0.5, 0 }, AzT("Legendary amulet - remakes %s", AzG(it.name))
end

-- a small white gem after a section's title; hovering it tells
-- what the section means. `tip` nil hides them.
function AzlSectionGems(h, tip)
  if type(h.gems) ~= "table" then
    -- one small white gem
    local f = CreateFrame("Frame", nil, h)
    f:SetWidth(12); f:SetHeight(12)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(MEDIA .. "gem_white.tga")
    t:SetWidth(11); t:SetHeight(11)
    t:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.t = t
    f:EnableMouse(true)
    f:SetScript("OnEnter", function()
      if not this.tip then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.tip[1], 1, 0.82, 0)
      GameTooltip:AddLine(this.tip[2], 0.85, 0.85, 0.85, 1)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    h.gems = f
  end
  local f = h.gems
  f.tip = tip
  if not tip then f:Hide(); return end
  f:ClearAllPoints()
  f:SetPoint("LEFT", h, "LEFT", 38 + (h.title:GetStringWidth() or 80) + 7, 0)
  f:Show()
end
-- the "?" after a jewel's section titles: what the section means
AZL_SECTION_HELP = {
  ["A new one, by rarity"] = "What it gives when you take it new, by the rarity the game offers it in: the rarer, the stronger.",
  ["Picked again"] = "Offered again while you wear it: taking it makes the one you wear grow, as written here. The wishlist window counts these picks as its rank.",
  ["Offered again"] = "Offered again while you wear it: taking it empowers the one you wear.",
}
-- An entry's text in sections: { title, { {text, colour}, ... } }.
-- `bright` picks colours for dark backgrounds (tooltips) instead of parchment.
local function EntrySections(entry, bright)
  local it = entry.item
  local good = bright and { 0.3, 1, 0.45 } or INK_GOOD
  local soft = bright and { 0.75, 0.75, 0.75 } or INK_SOFT
  local rcol = bright and RARITY_COLOR or PAGE_RARITY
  local secs = {}
  if entry.kind == "Rings" or entry.kind == "Trinkets" then
    local lines = {}
    for r = 1, 5 do
      if bright then
        table.insert(lines, { Hex(rcol[RARITY[r]]) .. AzG(RARITY[r]) .. "|r   " .. AzG(it.values[r]), good })
      else
        -- on the page the rarity is its own label, bright with a dark edge; the value stays in ink
        table.insert(lines, { AzG(it.values[r]), INK, AzG(RARITY[r]), rcol[RARITY[r]] })
      end
    end
    table.insert(secs, { AzT("A new one, by rarity"), lines })
    table.insert(secs, { AzT("Picked again"), { { AzG(it.again), soft } } })
  elseif entry.kind == "Amulets" then
    local lines = {}
    for e = 1, table.getn(it.effects) do table.insert(lines, { AzG(it.effects[e]), good }) end
    table.insert(secs, { AzT("Effects"), lines })
    table.insert(secs, { AzT("Offered again"), { { AzG(D.amuletAgain), soft } } })
  elseif entry.kind == "Spell" then
    local b = entry.class.key == PlayerClass() and SpellBonuses()[it.key]
    local desc = SpellDesc(it.key) or (b and b.desc)
    if desc then table.insert(secs, { AzT("What it does"), { { desc, bright and { 1, 0.82, 0 } or INK } } }) end
    if bright and b and b.bonus then table.insert(secs, { AzT("Your bonuses"), { { b.bonus, good } } }) end
    if bright then
      local lines = { { AzG(it.amulet), rcol.Legendary } }
      for e = 1, table.getn(it.effects) do table.insert(lines, { AzG(it.effects[e]), soft }) end
      table.insert(secs, { AzT("Its class amulet"), lines })
    end
  elseif entry.kind == "LootItem" then
    local lines = {}
    for e = 1, table.getn(it.bonus) do table.insert(lines, { AzG(it.bonus[e]), good }) end
    table.insert(secs, { AzT("Bonuses"), lines })
    local src = entry.sources or {}
    if table.getn(src) > 1 then
      -- each boss that drops it on a line of its own, then the chance once
      local where = {}
      for i = 1, table.getn(src) do
        table.insert(where, { AzT("%s in %s, arriving after %s.", AzG(src[i].boss.name), AzG(src[i].zone.name), Minutes(src[i].boss.minute)), soft })
      end
      table.insert(where, { AzT("Each kill gives it a %s%% chance; once it drops it stays in your collection.", entry.zone.chance), soft })
      table.insert(secs, { AzT("Where it drops"), where })
    else
      table.insert(secs, { AzT("Where it drops"), { { AzT("%s in %s, arriving after %s. Each kill gives it a %s%% chance; once it drops it stays in your collection.",
        AzG(entry.boss.name), AzG(entry.zone.name), Minutes(entry.boss.minute), entry.zone.chance), soft } } })
    end
    local got = Collected(entry.class)[it.name]
    table.insert(secs, { AzT("Collection"), { { got and AzT("In your collection, kept for good.") or AzT("Not collected yet."), got and good or soft } } })
  else
    local lines = {}
    for e = 1, table.getn(it.effects) do table.insert(lines, { AzG(it.effects[e]), good }) end
    table.insert(secs, { AzT("Effects"), lines })
    table.insert(secs, { AzT("When it is offered"), { { AzT("Offered only once your hero knows %s. Offered again while worn, it is empowered.", AzG(it.name)), soft } } })
  end
  return secs
end


-- ---------- what the left page lists ----------
-- ---------- loot: the zones and what their bosses drop ----------
local ZONE_ICON = "INV_Misc_Map_01"
-- one picture of what each zone's story is about
local ZONE_ICONS = {
  elwynn = "INV_Misc_Bandana_01",            -- a Defias bandana
  duskwood = "INV_Misc_Head_Undead_01",      -- the restless dead of Raven Hill
  wsg = "Spell_Shadow_Metamorphosis",        -- the Burning Legion
  ungoro = "Ability_Mount_Raptor",           -- the ravasaur packs of the crater
  ab = "INV_Misc_Map_01",                    -- the Highlands march to take back the Basin
  feralas = "INV_Misc_Head_Centaur_01",      -- the wild folk of Feralas
  arena = "INV_Misc_Head_Troll_01",          -- the Gurubashi trolls of the Blood God
  sm = "Spell_Holy_SealOfMight",             -- the Scarlet Crusade
  av = "INV_Jewelry_FrostwolfTrinket_01",    -- the frozen wilds of the Frostwolves
  brm = "Spell_Fire_Volcano",                -- the burning mountain
  aq = "INV_Misc_AhnQirajTrinket_01",        -- the scarab of Ahn'Qiraj
  naxx = "INV_Trinket_Naxxramas01",          -- the Scourge's floating citadel
}

local function ZoneEntries()
  local list = {}
  for i = 1, table.getn(LD.zones) do
    local z = LD.zones[i]
    table.insert(list, { kind = "Zone", index = i, zone = z, item = { name = z.name, icon = ZONE_ICONS[z.key] or ZONE_ICON, key = z.key } })
  end
  return list
end

-- The search also finds the book's pages, its zones and its bosses. Each page answers to a few
-- words, so "amulet" finds both amulet pages and "drops" finds the boss loot.
local SEARCH_PAGES = {
  { target = "Rings", label = "Rings", icon = "INV_Jewelry_Ring_03", blurb = "Jewelry page", words = { "rings", "jewelry" } },
  { target = "Trinkets", label = "Trinkets", icon = "INV_Jewelry_Talisman_07", blurb = "Jewelry page", words = { "trinkets", "jewelry" } },
  { target = "Amulets", label = "Basic Amulets", icon = "INV_Jewelry_Necklace_07", blurb = "Jewelry page", words = { "basic amulets", "necklaces", "jewelry" } },
  { target = "Legendary", label = "Class Amulets", icon = "INV_Jewelry_Necklace_13", blurb = "Jewelry page", words = { "class amulets", "legendary amulets", "spells" } },
  { target = "Builds", label = "Builds", icon = "INV_Scroll_03", blurb = "Your builds", words = { "builds", "build", "wishlist" } },
  { target = "Chronicle", label = "Chronicle", icon = "INV_Misc_PocketWatch_01", blurb = "Your runs and records", words = { "chronicle", "runs", "history", "records", "best run" } },
  { target = "Loot", label = "Loot", icon = "INV_Misc_Bag_10", blurb = "Chapter: every zone and its bosses", words = { "loot", "boss loot", "drops", "zones", "bosses" } },
  { target = "Book", label = "Collection Book", icon = "INV_Misc_Book_09", blurb = "Your class's boss loot at a glance", words = { "collection book", "collected" } },
}

-- a boss is found by its English name and by its name in every language the game ships
local bossHay = {}
local function BossHay(name)
  if not bossHay[name] then
    local h = name
    for loc, en in pairs(LD.bossNames or {}) do if en == name then h = h .. " " .. loc end end
    bossHay[name] = string.lower(h)
  end
  return bossHay[name]
end

-- a boss piece is found by its English name and by its name in every language the game ships
local lootHay = {}
local function LootHay(cls, name)
  local k = cls .. "|" .. name
  if not lootHay[k] then
    local h = name
    for loc, en in pairs((LD.names or {})[cls] or {}) do if en == name and loc ~= name then h = h .. " " .. loc end end
    lootHay[k] = string.lower(h)
  end
  return lootHay[k]
end

local function ListEntries()
  if state.module == "Loot" then return ZoneEntries() end
  if state.module == "Spells" then return SpellEntries(state.class or PlayerClass()) end
  local s = string.lower(state.search or "")
  if s ~= "" then
    local out = {}
    -- first the book's own pages, then zones and bosses, then the jewelry by name
    for i = 1, table.getn(SEARCH_PAGES) do
      local pg = SEARCH_PAGES[i]
      local hit = false
      for w = 1, table.getn(pg.words) do if string.find(pg.words[w], s, 1, true) then hit = true end end
      if string.find(string.lower(AzT(pg.label)), s, 1, true) then hit = true end
      if hit then table.insert(out, { kind = "Page", target = pg.target, item = { name = pg.label, icon = pg.icon, blurb = pg.blurb } }) end
    end
    for zi = 1, table.getn(LD.zones) do
      local z = LD.zones[zi]
      if string.find(string.lower(z.name .. " " .. z.subtitle .. " " .. AzG(z.name) .. " " .. AzG(z.subtitle)), s, 1, true) then
        table.insert(out, { kind = "ZoneHit", zoneIndex = zi, zone = z, item = { name = z.name, icon = ZONE_ICONS[z.key] or ZONE_ICON } })
      end
    end
    for zi = 1, table.getn(LD.zones) do
      local z = LD.zones[zi]
      for bi = 1, table.getn(z.bosses) do
        local b = z.bosses[bi]
        if string.find(BossHay(b.name), s, 1, true) then
          table.insert(out, { kind = "BossHit", zoneIndex = zi, bossIndex = bi, zone = z, boss = b, item = { name = b.name, icon = b.icon or "INV_Misc_QuestionMark" } })
        end
      end
    end
    -- the boss loot of your own class, then the jewelry, then every other class's boss loot
    local function Loot(cls, mine)
      if (cls == PlayerClass()) ~= mine then return end
      local all = LootEntries(cls)
      for i = 1, table.getn(all) do
        if string.find(LootHay(cls, all[i].item.name), s, 1, true) then table.insert(out, all[i]) end
      end
    end
    Loot(PlayerClass(), true)
    local pools = { ItemEntries("Rings"), ItemEntries("Trinkets"), ItemEntries("Amulets") }
    for c = 1, table.getn(D.classes) do table.insert(pools, ClassEntries(D.classes[c])) end
    for p = 1, table.getn(pools) do
      for i = 1, table.getn(pools[p]) do
        local e = pools[p][i]
        local hay = string.lower(e.item.name .. " " .. (e.item.amulet or "") .. " " .. AzG(e.item.name) .. " " .. AzG(e.item.amulet or ""))
        if string.find(hay, s, 1, true) then table.insert(out, e) end
      end
    end
    for c = 1, table.getn(D.classes) do Loot(D.classes[c].key, false) end
    return out
  end
  if state.view == "Legendary" then return ClassEntries(ClassInfo(state.class or PlayerClass())) end
  if state.view == "Wishlist" then
    -- in sections: Jewelry, Spells, Loot, each under its own heading
    local all, groups = WishEntries(), { {}, {}, {} }
    for i = 1, table.getn(all) do
      local k = all[i].kind
      local g = (k == "Spell" and 2) or (k == "LootItem" and 3) or 1
      table.insert(groups[g], all[i])
    end
    local out, titles = {}, { "Jewelry", "Spells", "Loot" }
    local signs = { MEDIA .. "diamond.tga", "Interface\\PvPRankBadges\\PvPRank06", "Interface\\GossipFrame\\VendorGossipIcon" }
    for g = 1, 3 do
      if table.getn(groups[g]) > 0 then
        table.insert(out, { kind = "Header", item = { name = titles[g], sign = signs[g] } })
        for i = 1, table.getn(groups[g]) do table.insert(out, groups[g][i]) end
      end
    end
    return out
  end
  return ItemEntries(state.view)
end

local function Go(view)
  state.view = view
  state.offset = 0
  state.selected = nil
  state.search = ""
  if ui.search then ui.search:SetText(""); ui.search:ClearFocus() end
  if view == "Legendary" then state.class = state.class or PlayerClass() end
  Refresh()
end

local PageTurn -- the page-turn animation, defined with the book below

-- a page, zone or boss found by the search: the book opens it, as if reached by hand
local function OpenSearchHit(e)
  state.search = ""
  if ui.search then ui.search:SetText(""); ui.search:ClearFocus() end
  state.selected = nil; state.offset = 0; state.lootBoss = nil; state.lootBook = nil
  if e.kind == "Page" and (e.target == "Builds" or e.target == "Chronicle") then
    state.module = e.target
    Refresh()
    return
  end
  if e.kind == "Page" and e.target ~= "Loot" and e.target ~= "Book" then
    state.module = "Jewelry"
    Go(e.target)
    return
  end
  state.module = "Loot"
  state.class = state.class or PlayerClass()
  if e.kind == "LootItem" then state.class = e.class end
  if e.kind == "Page" then
    if e.target == "Book" then state.lootBook = true end
  else
    local rows = ROWS - 1
    state.lootZone = e.zoneIndex
    state.selected = ZoneEntries()[e.zoneIndex]
    state.offset = math.floor((e.zoneIndex - 1) / rows) * rows
    if e.kind == "BossHit" or e.kind == "LootItem" then state.lootBoss = e.bossIndex end
  end
  Refresh()
  PageTurn(true)
end

-- ---------- right page: header plus collapsible sections ----------
local function DrawDetail()
  local d = ui.detail
  for i = 1, table.getn(d.heads) do d.heads[i]:Hide() end
  for i = 1, table.getn(d.lines) do d.lines[i]:Hide() end
  for i = 1, table.getn(d.labels) do d.labels[i]:Hide() end
  local entry = state.selected
  d.amulet:Hide()
  if not entry then
    d.iconBox:Hide(); d.name:SetText(""); d.sub:SetText(""); d.wish:Hide()
    d.empty:Show()
    if state.view == "Wishlist" and table.getn(WishEntries()) == 0 then
      d.empty:SetText(AzT("Your wishlist is empty.\n\nOpen any ring, trinket or amulet and click the star to add it. The wishlist is kept for each class and also shows in a small window you can move anywhere on your screen."))
    else
      d.empty:SetText(AzT("Choose an entry on the left page to read it."))
    end
    return
  end
  d.empty:Hide()
  local title, _, sub = EntryTitle(entry)
  d.icon:SetTexture("Interface\\Icons\\" .. (entry.item.icon or "INV_Misc_QuestionMark")); d.iconBox:Show()
  local ink = INK
  if entry.kind == "Amulets" then ink = INK_RARITY[entry.item.rarity]
  elseif entry.kind == "Legendary" then ink = INK_RARITY.Legendary
  elseif entry.kind == "LootItem" then ink = INK_RARITY[entry.rarity] end
  d.name:SetText(title); d.name:SetTextColor(ink[1], ink[2], ink[3])
  -- legendary and epic names glow in their own colour, set off by a dark edge;
  -- the others stay pressed into the paper
  local rarity = (entry.kind == "Legendary" and "Legendary") or (entry.kind == "Amulets" and entry.item.rarity)
    or (entry.kind == "LootItem" and entry.rarity)
  if rarity == "Legendary" then
    d.name:SetTextColor(1, 0.5, 0.02)
    d.name:SetShadowColor(0.22, 0.07, 0, 1); d.name:SetShadowOffset(1, -1)
  elseif rarity == "Epic" then
    d.name:SetTextColor(0.68, 0.25, 0.98)
    d.name:SetShadowColor(0.12, 0.02, 0.2, 1); d.name:SetShadowOffset(1, -1)
  elseif rarity == "Rare" then
    d.name:SetTextColor(0.12, 0.52, 1)
    d.name:SetShadowColor(0, 0.05, 0.2, 1); d.name:SetShadowOffset(1, -1)
  elseif rarity == "Uncommon" then
    d.name:SetTextColor(0.2, 0.82, 0.05)
    d.name:SetShadowColor(0.02, 0.14, 0, 1); d.name:SetShadowOffset(1, -1)
  else
    d.name:SetShadowColor(0, 0, 0, 0); d.name:SetShadowOffset(1, -1)
  end
  d.sub:SetText(sub)
  -- icon, name and line below centred together on the page
  local tw = math.min(250, math.max(d.name:GetStringWidth() or 0, d.sub:GetStringWidth() or 0))
  d.iconBox:ClearAllPoints()
  d.iconBox:SetPoint("TOPLEFT", ui.right, "TOPLEFT", math.floor((374 - (42 + 10 + tw)) / 2) + 3, -26)
  d.wish.key = WishKey(entry); d.wish.entry = entry; d.wish:Show()
  local other = (entry.kind == "Legendary" or entry.kind == "Spell") and entry.class and entry.class.key ~= PlayerClass() and entry.class
  if other then
    -- another class's spell or amulet: never offered to this hero, so no build of its
    d.wish.key = false
    d.wish.text:SetText(AzT("Only for a %s", AzG(other.name))); d.wish.text:SetTextColor(0.7, 0.66, 0.58)
    -- the game's own red cross, where the arrow would be
    d.wish.mark:SetTexture("Interface\\Glues\\Login\\Glues-CheckBox-Check"); d.wish.mark:SetVertexColor(1, 0.3, 0.25)
    -- the cross is drawn high in its square: a little smaller and lower, it sits on the line
    d.wish.mark:SetWidth(14); d.wish.mark:SetHeight(14)
    d.wish.mark:ClearAllPoints(); d.wish.mark:SetPoint("LEFT", d.wish.text, "RIGHT", 4, -2)
  elseif entry.kind == "LootItem" then
    d.wish:Hide()
  else
    -- spells and jewelry are planned in builds: the button opens the list of them
    AzlB.SetupButton(d.wish, entry)
  end
  -- 28 left (behind the seal's inner half) and 28 right, so label and mark sit centred
  d.wish:SetWidth(d.wish.text:GetStringWidth() + 3 + 16 + 56)

  -- everything below the header is laid out top to bottom with a running offset; if a
  -- long text (in a long language) would run under the button at the foot, the page is
  -- laid out once more, a little tighter
  local secs = EntrySections(entry, false)
  local limit = -((ui.right:GetHeight() or 420) - 56)
  local y, ln
  for pass = 1, 2 do
    local headGap, lineGap, secGap = 30, 5, 6
    if pass == 2 then headGap, lineGap, secGap = 25, 2, 2 end
    y, ln = -116, 0
    for s = 1, table.getn(secs) do
      local h = d.heads[s]
      h.secKey = secs[s][1]
      h.title:SetText(secs[s][1])
      -- a section that wants a word of explanation gets the small "?" after its title
      local helpText = AZL_SECTION_HELP[secs[s][1]]
      if secs[s][1] == AzT("What it does") then helpText = "Read from the game's own tooltip, in the book's language. The numbers are those the game shows now: in a run they grow with your hero."
      else
        for en, tx in pairs(AZL_SECTION_HELP) do if AzT(en) == secs[s][1] then helpText = tx end end
      end
      -- "A new one, by rarity": a small white gem instead of the "?"
      local gems = (secs[s][1] == AzT("A new one, by rarity")) and helpText
      AzlSectionGems(h, gems and { secs[s][1], AzT(helpText) } or nil)
      if gems then helpText = nil end
      if helpText then
        h.help.tip = { secs[s][1], AzT(helpText) }
        h.help:ClearAllPoints()
        h.help:SetPoint("LEFT", h, "LEFT", 38 + (h.title:GetStringWidth() or 80) + 5, 0)
        h.help:Show()
      else
        h.help:Hide()
      end
      local closed = state.closed[h.secKey]
      h.sign:SetText(closed and "+" or "-")
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, y)
      h:Show()
      y = y - headGap
      if not closed then
        local lines = secs[s][2]
        -- the rarity labels' column is as wide as its longest word ("Ungewöhnlich"), the
        -- values start right after it
        local colX = 128
        for i = 1, table.getn(lines) do
          if lines[i][3] then
            local lb = d.labels[ln + i]
            lb:SetText(lines[i][3]); lb:Show()   -- (a hidden string measures nothing)
            colX = math.max(colX, 36 + math.ceil(lb:GetStringWidth() or 0) + 8)
          end
        end
        for i = 1, table.getn(lines) do
          ln = ln + 1
          local l = d.lines[ln]
          l:SetText(lines[i][1]); l:SetTextColor(lines[i][2][1], lines[i][2][2], lines[i][2][3])
          if lines[i][2] == INK_GOOD then
            l:SetShadowColor(0.02, 0.14, 0, 1)        -- bright green with a dark edge
          else
            l:SetShadowColor(0, 0, 0, 0)      -- dark ink, no light rim
          end
          l:ClearAllPoints()
          if lines[i][3] then
            -- a rarity label in its own colour, the values lined up in a column after it
            local lb = d.labels[ln]
            lb:SetText(lines[i][3]); lb:SetTextColor(lines[i][4][1], lines[i][4][2], lines[i][4][3])
            -- the two faces stand at different heights: line their first rows up at the
            -- bottom, so both words sit on one baseline
            local drop = math.max(0, (d.probe:GetHeight() or 0) - (lb:GetHeight() or 0))
            lb:ClearAllPoints(); lb:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 36, y - drop); lb:Show()
            l:SetWidth(344 - colX)
            l:SetPoint("TOPLEFT", ui.right, "TOPLEFT", colX, y - 2)  -- fine-tuned in the game
          else
            l:SetWidth(306)
            l:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 36, y)
          end
          l:Show()
          y = y - (l:GetHeight() or 14) - lineGap
        end
        y = y - secGap
      end
    end
    if entry.kind == "Spell" and entry.item.amulet then
      local h = d.heads[table.getn(secs) + 1]
      h.secKey = AzT("Its class amulet")
      h.title:SetText(AzT("Its class amulet"))
      h.help:Hide()
      local closed = state.closed[h.secKey]
      h.sign:SetText(closed and "+" or "-")
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, y); h:Show()
      y = y - headGap
      if not closed then
        local a = d.amulet
        a.spell = entry.item
        a.icon:SetTexture("Interface\\Icons\\" .. ((Azerloot_AmuletIcons and Azerloot_AmuletIcons[entry.item.amulet]) or "INV_Jewelry_Necklace_07"))
        a.name:SetText(AzG(entry.item.amulet))
        a:ClearAllPoints(); a:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 32, y + 2); a:Show()
        y = y - 28
      end
    end
    if y >= limit or not d.wish:IsShown() then break end
  end
end

-- ---------- left page: banners ----------
local function DrawList()
  local list = ListEntries()
  local total = table.getn(list)
  local loot = (state.module == "Loot")
  local legendary = (not loot) and (state.view == "Legendary") and (state.search == "")
  local picker = legendary or loot or (state.module == "Spells")   -- the class icons above the banners
  local rows = picker and ROWS - 1 or ROWS
  local pages = math.max(1, math.ceil(total / rows))
  local page = math.floor(state.offset / rows) + 1
  if page > pages then page = pages end
  if page < 1 then page = 1 end
  state.offset = (page - 1) * rows
  local w = Wish()
  for i = 1, ROWS do
    local row = ui.rows[i]
    local e = (i <= rows) and list[state.offset + i] or nil
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 16, (picker and -90 or -58) - (i - 1) * ROW_H)
    local head = e and e.kind == "Header"
    if head then
      row.bg:Hide(); row.shadow:Hide(); row.ibox:Hide()
      row.headText:SetText(AzT(e.item.name)); row.headText:Show(); row.headLine:Show(); row.headShadow:Show()
      row.headIcon:SetTexture(e.item.sign); row.headIcon:Show()
    else
      row.bg:Show(); row.shadow:Show(); row.ibox:Show()
      row.headText:Hide(); row.headLine:Hide(); row.headIcon:Hide(); row.headShadow:Hide()
    end
    if head then
      row.entry = e
      row.name:SetText(""); row.sub:SetText(""); row.star:Hide(); row.count:Hide(); row.bar:Hide(); row.check:Hide(); row.glow:Hide()
      row:Show()
    elseif e then
      row.entry = e
      row.icon:SetTexture("Interface\\Icons\\" .. (e.item.icon or "INV_Misc_QuestionMark"))
      local col
      if e.kind == "Zone" or e.kind == "ZoneHit" then col = WOOD_RARITY[e.zone.rarity]
      elseif e.kind == "BossHit" then col = e.boss.final and WOOD_RARITY.Legendary or { 1, 0.88, 0.45 }
      elseif e.kind == "LootItem" then col = WOOD_RARITY[e.rarity]
      elseif e.kind == "Amulets" then col = WOOD_RARITY[e.item.rarity]
      elseif e.kind == "Legendary" then col = WOOD_RARITY.Legendary
      else col = { 1, 0.88, 0.45 } end
      row.name:SetText(e.kind == "Page" and AzT(e.item.name) or AzG(e.item.name)); row.name:SetTextColor(col[1], col[2], col[3])
      -- a long name (a long language) is set a little smaller, so it keeps to one line
      row:Show(); AzlFitText(row.name, 250, 14, 10)
      if e.kind == "Page" then row.sub:SetText(AzT(e.item.blurb))
      elseif e.kind == "Spell" then row.sub:SetText(SpellSub(e))
      elseif e.kind == "ZoneHit" then row.sub:SetText(AzT("Zone") .. " - " .. AzG(e.zone.subtitle))
      elseif e.kind == "BossHit" then
        row.sub:SetText(AzT(e.boss.final and "Final boss" or "Boss") .. " - " .. AzG(e.zone.name) .. ", " .. Minutes(e.boss.minute))
      elseif e.kind == "Zone" then
        row.sub:SetText((e.zone.rarity == "Legendary" and (AzG("Epic") .. " + " .. AzG("Legendary")) or AzG(e.zone.rarity)) .. " - " .. AzG(e.zone.subtitle))
        -- too long for the banner (a long language): the name's colour tells the rarity
        -- already, so the line keeps the zone's own words only
        if (row.sub:GetStringWidth() or 0) > 236 then row.sub:SetText(AzG(e.zone.subtitle)) end
      elseif e.kind == "LootItem" then
        -- another class's piece names its class instead of its rarity (the name's colour shows
        -- that), and leaves out the boss if the line would grow past the banner
        if e.class ~= PlayerClass() then
          local cn = AzG(ClassInfo(e.class).name)
          row.sub:SetText(AzName(e.item.slot) .. " - " .. AzG(e.boss.name) .. " - " .. cn)
          if (row.sub:GetStringWidth() or 0) > 262 then row.sub:SetText(AzName(e.item.slot) .. " - " .. cn) end
        else
          row.sub:SetText(AzG(e.rarity) .. " " .. AzName(e.item.slot) .. " - " .. AzG(e.boss.name))
          if (row.sub:GetStringWidth() or 0) > 262 then row.sub:SetText(AzName(e.item.slot) .. " - " .. AzG(e.boss.name)) end
        end
      elseif e.kind == "Amulets" then row.sub:SetText(AzT("%s amulet", AzG(e.item.rarity)))
      elseif e.kind == "Legendary" then row.sub:SetText(AzG(e.item.amulet))
      else row.sub:SetText(AzName(e.kind == "Rings" and "Ring" or "Trinket") .. " - " .. AzName(e.item.cat)) end
      -- and the line under it the same way, so it stays on the banner
      AzlFitText(row.sub, 244, 11, 9)
      if not (e.kind == "Zone" or e.kind == "Page" or e.kind == "ZoneHit" or e.kind == "BossHit") and w[WishKey(e)] then row.star:Show() else row.star:Hide() end
      if e.kind == "Zone" then
        local have, n = ZoneProgress(state.class or PlayerClass(), e.index)
        row.count:SetText(have .. "/" .. n)
        row.bar:SetProgress(have, n)
        row.count:Show(); row.bar:Show()
      else
        row.count:Hide(); row.bar:Hide()
      end
      -- a class amulet the class has worn before: discovered, with the green check
      if e.kind == "Legendary" and e.class and Discovered(e.class.key)[e.item.key] then row.check:Show() else row.check:Hide() end
      if state.selected and state.selected.item == e.item and not (loot and state.lootBook) then row.glow:Show() else row.glow:Hide() end
      row:Show()
    else
      row.entry = nil
      row:Hide()
    end
  end
  state.page, state.pages = page, pages
  if total == 0 and state.search ~= "" then
    ui.count:SetText(AzT("Nothing found."))
  elseif pages > 1 then
    ui.count:SetText(AzT("Page %d of %d", page, pages))
  else
    ui.count:SetText("")
  end
  local multi = pages > 1
  if multi then ui.prev:Show(); ui.next:Show() else ui.prev:Hide(); ui.next:Hide() end
  if page > 1 then ui.prev:Enable() else ui.prev:Disable() end
  if page < pages then ui.next:Enable() else ui.next:Disable() end
  ui.nextHint.on = multi and page < pages
  if ui.nextHint.on then ui.nextHint:Show(); ui.moreText:Show() else ui.nextHint:Hide(); ui.moreText:Hide() end
  local current = state.class or PlayerClass()
  for i = 1, table.getn(ui.classes) do
    local b = ui.classes[i]
    if picker then b:Show() else b:Hide() end
    local on = (b.key == current)
    b.glow:SetAlpha(0)
    b.on = on
    if on then b.icon:SetVertexColor(1, 1, 1); b.sel:Show(); b.sparks:Show()
    else b.icon:SetVertexColor(0.6, 0.6, 0.6); b.sel:Hide(); b.sparks:Hide() end
    b.frame:SetAlpha(on and 1 or 0.5)
  end
  local heading
  if loot then heading = AzT("Loot") .. " - " .. AzG(ClassInfo(current).name)
  elseif state.search ~= "" then heading = AzT("Search: %s", state.search)
  elseif legendary then
    local ci = ClassInfo(state.class or PlayerClass())
    heading = AzT("Class Amulets") .. " - " .. AzG(ci.name)
  elseif state.module == "Spells" then heading = AzT("Spells") .. " - " .. AzG(ClassInfo(state.class or PlayerClass()).name)
  elseif state.view == "Wishlist" then heading = AzT("Wishlist") .. " - " .. AzG(ClassInfo(PlayerClass()).name)
  else heading = CatLabel(state.view) end
  ui.leftTitle:SetText(heading)
  if loot then ui.bookLink:Show() else ui.bookLink:Hide() end
  if (not loot) and state.view == "Wishlist" and state.search == "" and total > 0 then ui.clearWish:Show()
  else ui.clearWish:Hide(); ui.clearWish:Reset() end
end

-- Class colours made into ink: dark enough to read on the parchment (the bright
-- WoW colours of mage, priest or rogue vanish on it).
local CLASS_INK = {
  warrior = { 0.45, 0.28, 0.12 }, paladin = { 0.62, 0.18, 0.4 }, hunter = { 0.25, 0.42, 0.1 },
  rogue = { 0.55, 0.45, 0.0 }, priest = { 0.25, 0.25, 0.3 }, shaman = { 0.0, 0.3, 0.62 },
  mage = { 0.05, 0.38, 0.6 }, warlock = { 0.36, 0.22, 0.6 }, druid = { 0.68, 0.3, 0.0 },
}
local function ClassInk(key) return CLASS_INK[key] or INK end
-- a class's NAME on the parchment: the colour of its icon's frame, only deeper, with a firm
-- dark-brown shadow so even the light ones (priest, mage, rogue) read on the paper.
-- (kept in the table: the main chunk has no locals left)
CLASS_INK.names = {
  warrior = { 0.58, 0.32, 0.08 }, paladin = { 0.80, 0.28, 0.55 }, hunter = { 0.52, 0.62, 0.10 },
  rogue = { 0.78, 0.66, 0.0 }, priest = { 0.97, 0.96, 0.92 }, shaman = { 0.0, 0.42, 0.86 },
  mage = { 0.22, 0.66, 0.88 }, warlock = { 0.52, 0.40, 0.80 }, druid = { 0.92, 0.44, 0.02 },
}
-- the icon's frame on the parchment: the class colour, but the warrior's pale tan is a deeper brown
CLASS_INK.frames = { warrior = { 0.62, 0.36, 0.12 } }
function CLASS_INK.Name(fs, key)
  local c = CLASS_INK.names[key] or INK
  fs:SetTextColor(c[1], c[2], c[3]); fs:SetShadowColor(0.16, 0.08, 0.02, 1); fs:SetShadowOffset(1, -1)
end
function CLASS_INK.Frame(tex, key, hex)
  local c = CLASS_INK.frames[key]
  if c then tex:SetVertexColor(c[1], c[2], c[3])
  else tex:SetVertexColor(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255) end
end

-- A boss's health as the game gives it with the standard run options: the base value of
-- the boss table x 5.75 x the zone's strength (Elwynn 0.82 ... Ahn'Qiraj 4.4). Checked in the
-- game: Hogger 3,600 -> 16,974, Mother Fang 9,000 -> 42,435, Korrak 4,000 -> 67,850.
local HEALTH_BASE = 5.75

local function Thousands(n)
  local str, out = tostring(math.floor(n + 0.5)), ""
  -- the separator of the book's language: 1,234 / 1.234 / 1 234
  local sep = (AzLang() == "en" and ",") or (AzLang() == "fr" and " ") or "."
  while string.len(str) > 3 do
    out = sep .. string.sub(str, -3) .. out
    str = string.sub(str, 1, -4)
  end
  return str .. out
end

-- the zone: its bosses as banners, each with what it drops and how much of it you own
local function DrawZone(z, cls, drops, zi)
  local Z = ui.zv
  local ci = ClassInfo(cls)
  Z.name:SetText(AzG(z.name))
  Z.sub:SetText(AzG(z.subtitle) .. ".")
  local what
  if z.rarity == "Legendary" then
    what = AzT("%s pieces and the %s weapon", Hex(INK_RARITY.Epic) .. AzG("Epic") .. "|r", Hex(INK_RARITY.Legendary) .. AzG("Legendary") .. "|r")
  else
    what = AzT("%s pieces", Hex(INK_RARITY[z.rarity]) .. AzG(z.rarity) .. "|r")
  end
  Z.info:SetText(AzT("Drops %s for a %s. Each piece rolls on its own: %s%% of a kill.", what, Hex(ClassInk(cls)) .. AzG(ci.name) .. "|r", z.chance))
  -- two lines at most above "Collected:": a third would run into its bar
  do
    local face, _, fl = Z.info:GetFont()
    if face then
      Z.info:SetFont(face, 12, fl)
      if (Z.info:GetHeight() or 0) > 30 then Z.info:SetFont(face, 11, fl) end
    end
  end
  local zh, zn = ZoneProgress(cls, zi)
  Z.bar:SetProgress(zh, zn)
  Z.count:SetText(AzT("%d of %d", zh, zn))
  if zh >= zn and zn > 0 then
    Z.count:SetTextColor(1, 0.75, 0.15); Z.count:SetShadowColor(0.25, 0.12, 0, 0.5)
  else
    Z.count:SetTextColor(INK_GOOD[1], INK_GOOD[2], INK_GOOD[3]); Z.count:SetShadowColor(0.02, 0.14, 0, 0.5)
  end
  local got, wish = Collected(cls), Wish(cls)
  for b = 1, table.getn(Z.bosses) do
    local row, boss = Z.bosses[b], z.bosses[b]
    if boss then
      local list = drops[b] or {}
      local n, have, wished = table.getn(list), 0, false
      for k = 1, n do
        if got[list[k].name] then have = have + 1 end
        if wish["loot:" .. list[k].name] then wished = true end
      end
      row.index = b
      row.icon:SetTexture("Interface\\Icons\\" .. (boss.icon or "INV_Misc_QuestionMark"))
      row.name:SetText(AzG(boss.name))
      row:Show(); AzlFitText(row.name, 230, 14, 10)
      local col = boss.final and WOOD_RARITY.Legendary or { 1, 0.88, 0.45 }
      row.name:SetTextColor(col[1], col[2], col[3])
      local rest = (boss.final and (" - " .. AzT("final boss")) or "") .. " - "
      -- a lone piece taken needs no "1 of 1": the check says it, and the line stays clear of it
      if have > 0 and have == n and n == 1 then rest = rest .. AzT("collected")
      elseif have > 0 then rest = rest .. AzT("%d of %d collected", have, n)
      else rest = rest .. ((n == 1) and AzT("%d piece", n) or AzT("%d pieces", n)) end
      row.sub:SetText("|cff66ff4d" .. Minutes(boss.minute) .. "|r" .. rest)
      -- still running into the check (a client with a wider font, a longer language): "min"
      local wsub = row.sub:GetStringWidth() or 0
      if (n > 0 and have == n and wsub > 198) or wsub > 250 then
        row.sub:SetText("|cff66ff4d" .. AzT("%d min", boss.minute) .. "|r" .. rest)
      end
      if wished then row.star:Show() else row.star:Hide() end
      if n > 0 and have == n then row.check:Show() else row.check:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
end

-- A short introduction to every boss, for the line under its name.
local BOSS_BIO = {
  ["Hogger"] = "A gnoll chieftain grown huge and bold, terror of the Elwynn farms.",
  ["Mother Fang"] = "A bloated spider queen nesting deep in the Jasperlode Mine.",
  ["Rhahk'Zor"] = "The Defias' ogre foreman, swinging the hammer that keeps the mines working.",
  ["Mr. Smite"] = "VanCleef's first mate, a brutal tauren who wields whatever is at hand.",
  ["Edwin VanCleef"] = "The Defias kingpin, a stonemason betrayed by Stormwind and sworn to burn it down.",
  ["Naraxis"] = "A giant spider that hunts the dark woods from the branches above.",
  ["Mor'Ladim"] = "A cursed revenant who stalks the graves of Raven Hill, still seeking his lost family.",
  ["Stitches"] = "An abomination sewn together in the Darkshire night, ever hungry.",
  ["Lupos"] = "A spectral worgen hound, swift and silent among the dead trees.",
  ["Morbent Fel"] = "The necromancer behind the Nightbane, raising Raven Hill's dead by the score.",
  ["Doomguard Commander"] = "A towering demon at the head of the Legion's vanguard in the gulch.",
  ["Mannoroth's Herald"] = "A satyr who carries the Pit Lord's will into battle.",
  ["Varimathras"] = "A dreadlord schemer who rains fire on any who stand in his way.",
  ["Lord Hel'nurath"] = "A dreadlord summoned from beyond, hungry for mortal souls.",
  ["Lord Kazzak"] = "The Supreme Highlord of the Burning Legion, master of the gulch's invasion.",
  ["Patchwerk"] = "Kel'Thuzad's prized abomination, a mountain of stitched flesh that never tires.",
  ["Anub'Rekhan"] = "A crypt lord of fallen Azjol-Nerub, spinning in a storm of claws.",
  ["Kel'Thuzad"] = "The archlich himself, the Lich King's will on Azeroth.",
  ["Zevrim Thornhoof"] = "A satyr butcher who carves shadow magic into the ruins of Dire Maul.",
  ["Alzzin the Wildshaper"] = "A satyr who twists the forest itself into storms and snaring roots.",
  ["Tendris Warpwood"] = "A corrupted ancient guarding the warped groves of Dire Maul.",
  ["Immol'thar"] = "A demon the Highborne bound under Dire Maul, now loose and furious.",
  ["King Gordok"] = "The ogre king of Dire Maul, who rules for as long as nobody beats him.",
  ["High Priestess Jeklik"] = "The bat priestess of the Gurubashi, hurling fire from on high.",
  ["High Priest Venoxis"] = "The snake priest of Hethiss, calling down lightning on the arena.",
  ["Bloodlord Mandokir"] = "Hakkar's champion, a raptor rider who never lets a coward go.",
  ["Jin'do the Hexxer"] = "A witch doctor who curses, hexes and bends the minds of his foes.",
  ["Hakkar the Soulflayer"] = "The Blood God of the trolls, summoned back to drink the world dry.",
  ["Korrak the Bloodrager"] = "An ogre warlord of the valley, mad with rage and hard to stop.",
  ["Ivus the Forest Lord"] = "The Stormpike's ancient champion, a tree of war that shakes the ground.",
  ["Lokholar the Ice Lord"] = "The Frostwolves' ice elemental, a winter storm with a will.",
  ["Glacius the Frozen Titan"] = "A frost giant of Alterac, whose fists stun all around him.",
  ["Azuregos"] = "A blue dragon guarding Azshara's lost magic, quick to freeze intruders.",
  ["General Angerforge"] = "The Dark Iron general who drills the armies of Blackrock Depths.",
  ["Warchief Rend Blackhand"] = "The Dark Horde's warchief, charging down from Blackrock Spire.",
  ["Emperor Dagran Thaurissan"] = "The Dark Iron emperor, enthralled by Ragnaros and burning with his fire.",
  ["Majordomo Executus"] = "Ragnaros' steward in the Molten Core, the Firelord's voice in the flames.",
  ["Nefarian"] = "Son of Deathwing and lord of Blackrock Spire, master of the black dragonflight.",
  ["Kurinnaxx"] = "A sand reaver that bursts from the dunes at the gates of Ahn'Qiraj.",
  ["General Rajaxx"] = "The qiraji general leading the swarm against the Scarab Wall.",
  ["Princess Huhuran"] = "A silithid princess with a venomous sting and a temper to match.",
  ["Ossirian the Unscarred"] = "The qiraji champion who has never been wounded, until now.",
  ["C'Thun"] = "The Old God beneath Ahn'Qiraj, whose eye sees every thought.",
  ["Ravasaur Matriarch"] = "The mother of the crater's ravasaur packs, never far from her brood.",
  ["Uhk'loc"] = "A silverback ape king of Un'Goro, beating his chest before the charge.",
  ["Lar'korwi"] = "A great raptor of the crater, hunting whoever came too close to her nest.",
  ["Tyrant Devilsaur"] = "A devilsaur grown huge on the crater's beasts, its footfalls heard from afar.",
  ["King Mosh"] = "The oldest devilsaur in Un'Goro, king of the crater's hunters.",
  ["Kovork"] = "A Boulderfist ogre chieftain come down from the Highlands to take the Basin.",
  ["Nimar the Slayer"] = "A Witherbark headhunter who hangs his trophies in his village.",
  ["Marez Cowl"] = "A Syndicate mage who freezes the Basin's defenders where they stand.",
  ["Lord Falconcrest"] = "A Syndicate lord of fallen Alterac, fighting for a crown long lost.",
  ["Lord Aliden Perenolde"] = "The last lord of Alterac, sending the Highlands to win back his kingdom.",
  ["Houndmaster Loksey"] = "The Scarlet Crusade's houndmaster, setting his dogs loose in the garden.",
  ["Arcanist Doan"] = "The Crusade's keeper of forbidden lore, guarding its library with arcane fire.",
  ["Herod"] = "The Scarlet Champion of the armory, whirling his axe at any real challenge.",
  ["Scarlet Commander Mograine"] = "The commander of the Scarlet Crusade, holding the cathedral with his shield.",
  ["High Inquisitor Whitemane"] = "The Crusade's high inquisitor, who raises the fallen at her altar.",
  ["Noth the Plaguebringer"] = "A necromancer of the Cult of the Damned, spreading plague for his master.",
  ["Sapphiron"] = "Kel'Thuzad's frost wyrm, risen from the bones of a blue dragon.",
}

-- ---------- a boss's attacks, as the game's code has them (data\BossLoot.lua) ----------
-- a number as the book's language writes it: 1.5 / 1,5
function AzlNum(v)
  v = tonumber(v) or 0
  local s
  if math.abs(v - math.floor(v + 0.5)) < 0.001 then s = tostring(math.floor(v + 0.5))
  else s = string.format("%.2f", v); s = string.gsub(s, "0+$", "") end
  if AzLang() ~= "en" then s = string.gsub(s, "%.", ",") end
  return s
end

-- the boss's attacks in the game's order, then what it does once wounded
function AzlDangerList(boss)
  local out = {}
  for k = 1, table.getn(boss.abilities or {}) do table.insert(out, boss.abilities[k]) end
  if type(boss.phases) == "table" and table.getn(boss.phases) > 0 then
    table.insert(out, { phases = boss.phases, icon = "Spell_Shadow_UnholyFrenzy" })
  end
  return out
end

-- the one told at first: the attack that hits hardest
function AzlDangerDefault(list)
  local best, bv = 1, -1
  for k = 1, table.getn(list) do
    local d = list[k].dm or 0
    if d > bv then best, bv = k, d end
  end
  return best
end

function AzlDangerName(a)
  if a.phases then return AzT("When it is wounded") end
  if a.kind == "adds" then return AzT("Calls for help") end
  -- (the things a boss puts around itself have no spell's name of their own)
  if a.kind == "eggs" or a.kind == "heal_wards" or a.kind == "shield_totems" then return AzT(a.name) end
  return AzName(a.name)
end

-- what an attack does, from its shape in the game: sizes in yards, times in seconds
-- (short: the wounded boss's turns one line each, its new attacks by name only; the
-- tooltip tells them in full)
function AzlDangerText(a, short)
  if a.phases then
    local lines = {}
    for k = 1, table.getn(a.phases) do
      local ph, what = a.phases[k], nil
      if ph.adds then what = AzT("Calls in %s helpers.", ph.adds)
      elseif ph.a and ph.a.kind == "stance" then what = AzlStanceText(ph.a, short)
      elseif ph.a and short then what = AzT("New attack, %s.", AzlDangerName(ph.a))
      elseif ph.a then what = AzT("New attack, %s: %s", AzlDangerName(ph.a), AzlDangerText(ph.a)) end
      table.insert(lines, AzT("%d%% health: %s", ph.pct, what or "?"))
    end
    return table.concat(lines, "\n")
  end
  local p, N = a.p or {}, AzlNum
  local k = a.kind
  if k == "adds" then return AzT("Calls in %s helpers.", p[1])
  elseif k == "circle" then return AzT("A %s yd circle where you stand strikes %s sec later.", N(p[1]), N(p[2]))
  elseif k == "bolts" then return AzT("%s bolts land on and around you, each marked by a small circle first.", p[1])
  elseif k == "nova" then return AzT("Stops, then strikes everything within %s yd 1.3 sec later.", N(p[1]))
  elseif k == "charge" then return AzT("Charges along a marked line, 6 yd past your spot. 1 sec to step aside.")
  elseif k == "cone" then return AzT("Stops, then strikes a %s yd cone of %s degrees toward you %s sec later.", N(p[1]), N(p[2]), N(p[3]))
  elseif k == "line" then return AzT("Stops, then strikes a line of %s by %s yd toward you %s sec later.", N(p[1]), N(p[2]), N(p[3]))
  elseif k == "circles" then return AzT("%s circles of %s yd, on and around you, strike %s sec later.", p[1], N(p[2]), N(p[3]))
  elseif k == "follow" then
    local s
    if (p[2] or 0) > 0 then s = AzT("A %s yd circle follows you for %s sec and strikes %s sec after it appeared.", N(p[1]), N(p[2]), N(p[3]))
    else s = AzT("A %s yd circle where you stand strikes %s sec later.", N(p[1]), N(p[3])) end
    if (p[4] or 0) > 0 then s = s .. " " .. AzT("The ground stays harmful for %s sec.", N(p[4])) end
    return s
  elseif k == "towers" then
    if p[1] == 1 and (p[3] or 0) == 0 then return AzT("A %s yd circle around you: stay inside until it fills, %s sec later.", N(p[2]), N(p[4])) end
    return AzT("%s safe circles of %s yd appear near you: be inside one when they fill, %s sec later.", p[1], N(p[2]), N(p[4]))
  elseif k == "ring" then
    if (p[1] or 0) > 0 then return AzT("Strikes %s to %s yd around it %s sec later: stay right by it or far away.", N(p[1]), N(p[2]), N(p[3])) end
    return AzT("Strikes everything within %s yd %s sec later.", N(p[2]), N(p[3]))
  elseif k == "spin" then return AzT("Spins %s sec after 1 sec, striking everything within %s yd as it moves.", N(p[2]), N(p[1]))
  elseif k == "beam" then return AzT("A %s yd beam aimed at you; after %s sec it sweeps half a circle in %s sec.", N(p[1]), N(p[2]), N(p[3]))
  elseif k == "cross" then return AzT("Four %s yd lines in a cross, one at you, strike %s sec later.", N(p[1]), N(p[2]))
  elseif k == "rows" then return AzT("%s rows of %s yd circles roll near you, one every %s sec, from %s sec on.", p[1], N(p[2]), N(p[3]), N(p[4]))
  elseif k == "combo_out" then return AzT("Strikes within %s yd, %s sec later %s to %s yd around it: move away, then back in.", N(p[1]), N(p[2]), N(p[3]), N(p[4]))
  elseif k == "combo_in" then return AzT("Strikes %s to %s yd around it, %s sec later within %s yd: stay close, then move away.", N(p[1]), N(p[2]), N(p[3]), N(p[4]))
  elseif k == "seq" then return AzlSeqText(a)
  elseif k == "stance" then return AzlStanceText(a, short)
  end
  return AzlDangerText2(a)
end

-- the mechanics the game added later (knockbacks, eggs, wards, tethers, ...)
function AzlDangerText2(a)
  local p, N, k = a.p or {}, AzlNum, a.kind
  if k == "knock" then return AzT("Stomps within %s yd %s sec later and throws you %s yd out: walk back in.", N(p[1]), N(p[2]), N(p[3]))
  elseif k == "eggs" then return AzT("Lays %s eggs %s yd around itself: destroy them, or they hatch into enemies after %s sec.", p[1], N(p[2]), N(p[3]))
  elseif k == "heal_wards" then
    if p[1] == 1 then return AzT("Puts a healing ward %s yd from itself; it slowly mends it until you destroy it.", N(p[2])) end
    return AzT("Puts %s healing wards %s yd around itself; they slowly mend it until you destroy them.", p[1], N(p[2]))
  elseif k == "shield_totems" then return AzT("Raises %s protectors %s yd around itself; while they stand, it takes only a quarter of the damage.", p[1], N(p[2]))
  elseif k == "shield" then return AzT("Shields itself for %s sec.", N(p[1]))
  elseif k == "orbs" then
    if p[1] == 1 then return AzT("An orb of %s yd rolls after you for %s sec, slower than you run: keep moving.", N(p[2]), N(p[3])) end
    return AzT("%s orbs of %s yd roll after you for %s sec, slower than you run: keep moving.", p[1], N(p[2]), N(p[3]))
  elseif k == "tether" then return AzT("A tether drains you every half second for up to %s sec: get %s yd away once to break it.", N(p[2]), N(p[1]))
  elseif k == "gaze" then return AzT("A %s yd blue ring settles under you: do not move until it fades, %s sec later.", N(p[1]), N(p[2]))
  elseif k == "waves" then return AzT("%s shockwaves roll out from it, one every %s sec from %s sec on: step across each just after it goes off.", p[1], N(p[3]), N(p[2]))
  elseif k == "burn" then return AzT("%s sec later everything beyond %s yd around you burns for %s sec: stay inside.", N(p[2]), N(p[1]), N(p[3]))
  elseif k == "lanes" then return AzT("%s lanes of %s yd go off in turns, %s times, every %s sec from %s sec on: stand in the safe ones.", p[1], N(p[2]), p[5], N(p[4]), N(p[3]))
  elseif k == "bomb" then return AzT("A %s yd bomb rides on you and goes off %s sec later: carry it into the horde, it blasts every enemy around it.", N(p[1]), N(p[2]))
  elseif k == "meteors" then return AzT("%s meteors of %s yd land near you %s sec later; each brings a new enemy.", p[1], N(p[2]), N(p[3]))
  elseif k == "crystals" then return AzT("%s crystals of %s yd appear %s yd away: stand in one for %s sec as it fills to break the shield; then it takes 50%% more damage for %s sec.", p[1], N(p[2]), N(p[3]), N(p[4]), N(p[5]))
  elseif k == "root" then return AzT("Roots you for %s sec.", N(p[1]))
  elseif k == "vanish" then return AzT("Vanishes and strikes from behind you.")
  elseif k == "blink" then return AzT("Blinks behind you.")
  end
  return ""
end

-- an attack in steps: a strike close by, then a ring (or the other way round), as before;
-- one move a few times over; else each step in turn
function AzlSeqText(a)
  local st, gap = a.steps or {}, (a.p or {})[1] or 0
  local n = table.getn(st)
  if n == 2 and st[1].kind == "nova" and st[2].kind == "ring" then
    return AzlDangerText({ kind = "combo_out", p = { st[1].p[1], gap, st[2].p[1], st[2].p[2] } })
  end
  if n == 2 and st[1].kind == "ring" and st[2].kind == "nova" then
    return AzlDangerText({ kind = "combo_in", p = { st[1].p[1], st[1].p[2], gap, st[2].p[1] } })
  end
  local same = n > 1
  for i = 2, n do if st[i].kind ~= st[1].kind or AzlDangerText(st[i]) ~= AzlDangerText(st[1]) then same = false end end
  if same then return AzT("%s times in a row, %s sec apart: %s", n, AzlNum(gap), AzlDangerText(st[1])) end
  local out = {}
  for i = 1, n do
    local t = AzlDangerText(st[i])
    if t ~= "" then
      if table.getn(out) > 0 then t = AzT("Then:") .. " " .. t end
      table.insert(out, t)
    end
  end
  return table.concat(out, " ")
end

-- a new stance: its attacks by name (short), or each with what it does
function AzlStanceText(a, short)
  local names, full = {}, {}
  for i = 1, table.getn(a.steps or {}) do
    local x = a.steps[i]
    if x.kind == "adds" then table.insert(names, AzT("helpers"))
    else
      table.insert(names, AzlDangerName(x))
      table.insert(full, AzlDangerName(x) .. ": " .. AzlDangerText(x))
    end
  end
  if short then return AzT("New stance: %s.", table.concat(names, ", ")) end
  return AzT("New stance: %s.", table.concat(names, ", ")) .. " " .. table.concat(full, " ")
end

-- a danger's words cut to the room left: whole sentences from the end first
function AzlFitDanger(fs, text, room)
  fs:SetText(text)
  if (fs:GetHeight() or 0) <= room then return text end
  -- lines go whole, from the last (a wounded boss's turns); else sentences, and a
  -- sentence ends at a mark before a capital ("Sek. später" goes on)
  local parts, from, sep = {}, 1, " "
  if string.find(text, "\n") then
    sep = "\n"
    for s in string.gfind(text .. "\n", "(.-)\n") do table.insert(parts, s) end
  else
    while true do
      local s, e = string.find(text, "[%.:;!?]%s+%u", from)
      if not s then break end
      table.insert(parts, string.sub(text, from, s))
      from = e
    end
    table.insert(parts, string.sub(text, from))
  end
  for n = table.getn(parts) - 1, 1, -1 do
    local t = table.concat(parts, sep, 1, n)
    if string.find(t, "[:;]$") then t = string.sub(t, 1, -2) .. "." end
    fs:SetText(t)
    if (fs:GetHeight() or 0) <= room or n == 1 then return t end
  end
  return text
end

local FitHeading -- set once Heading exists, below

-- one boss: portrait, what it says, its numbers, what it does, and what it drops
local function DrawBoss(z, zi, bi, cls, list)
  local B = ui.bv
  local boss = z.bosses[bi]
  local face = "Interface\\Icons\\" .. (boss.icon or "INV_Misc_QuestionMark")
  -- the game's own round mask for portraits; a plain square if the client lacks it
  if SetPortraitToTexture then SetPortraitToTexture("AzerlootBossFace", face) else B.avatar:SetTexture(face) end
  FitHeading(B.name, AzG(boss.name), 22, 228)
  -- a short introduction; the zone's name only for a boss without one
  B.sub:SetText(BOSS_BIO[boss.name] and AzT(BOSS_BIO[boss.name]) or AzT(boss.final and "Final boss of %s." or "Boss of %s.", AzG(z.name)))
  B.spawns:SetText(boss.minute .. ":00")
  B.back.tip = AzT("Back to %s", AzG(z.name))
  -- everything below the header follows it, however many lines name and line above took
  local top = 14 + (B.name:GetHeight() or 22) + 3 + (B.sub:GetHeight() or 14)
  local y = -math.max(88, top + 10)
  B.yell:ClearAllPoints(); B.yell:SetPoint("TOP", ui.right, "TOP", 0, y)
  B.yell:SetText("\"" .. AzG(boss.yell or "") .. "\"")
  y = y - (B.yell:GetHeight() or 14) - 4
  B.div:ClearAllPoints(); B.div:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, y)
  y = y - 20
  B.statStrip:ClearAllPoints(); B.statStrip:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, y)
  y = y - 31
  B.health:SetText(Thousands(boss.health * HEALTH_BASE * (z.might or 1)))
  B.hit:SetText(tostring(boss.hit))
  B.speed:SetText((string.gsub(string.format("%.1f", boss.speed), "%.", AzLang() == "en" and "." or ",")))
  B.stats:ClearAllPoints(); B.stats:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 34, y)
  y = y - 42
  B.dangers:ClearAllPoints(); B.dangers:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, y)
  y = y - 31
  -- every attack as an icon in one row; the one picked (at first the hardest-hitting) is
  -- told in full below it, any other on a mouse-over or a click
  local abl = AzlDangerList(boss)
  local pick = B.pickFor == boss.name and B.pick or nil
  if not (pick and abl[pick]) then pick = AzlDangerDefault(abl) end
  B.pickFor, B.pick, B.redraw = boss.name, pick, function() DrawBoss(z, zi, bi, cls, list) end
  for a = 1, table.getn(B.dicons) do
    local r, ab = B.dicons[a], abl[a]
    if ab then
      r.ab = ab
      r.icon:SetTexture("Interface\\Icons\\" .. ab.icon)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 34 + (a - 1) * 36, y - 2)
      r:Pick(a == pick)
      r.index = a
      r:Show()
    else
      r:Hide()
    end
  end
  y = y - 34
  local ab = abl[pick]
  if ab then
    y = y - 3
    local top = y + 3
    B.dname:SetText(AzlDangerName(ab))
    B.dname:ClearAllPoints(); B.dname:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 43, y)
    B.dline:ClearAllPoints(); B.dline:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 43, y - 18)
    if ab.cd then B.dcd:SetText(AzT("Every %s sec.", AzlNum(ab.cd))) else B.dcd:SetText("") end
    B.dcd:ClearAllPoints(); B.dcd:SetPoint("BOTTOMRIGHT", ui.right, "TOPLEFT", 345, y - 15)
    -- (a long name keeps the line: the time is in the icon's tooltip as well)
    if (B.dname:GetStringWidth() or 0) + (B.dcd:GetStringWidth() or 0) > 290 then B.dcd:SetText("") end
    -- what the page still has room for once the loot below is counted: a text too long
    -- for it keeps its first sentences (the tooltip tells it all)
    local lootH = 31
    for k = 1, table.getn(list or {}) do
      lootH = lootH + ((string.len(AzG(list[k].name or "")) > 26) and 54 or 40)
    end
    local room = y - 22 - 5 - 2 - lootH + 458
    B.dtext:SetText(AzlFitDanger(B.dtext, AzlDangerText(ab, true), room))
    B.dtext:ClearAllPoints(); B.dtext:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 43, y - 22)
    y = y - 22 - (B.dtext:GetHeight() or 14) - 4
    -- the band and its edge, from above the name to under the words
    B.dbg:ClearAllPoints(); B.dbg:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 31, top)
    B.dbg:SetHeight(top - y)
    B.dbar:ClearAllPoints(); B.dbar:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 31, top)
    B.dbar:SetHeight(top - y)
    B.dname:Show(); B.dline:Show(); B.dtext:Show(); B.dcd:Show(); B.dbg:Show(); B.dbar:Show()
    y = y - 2
  else
    B.dname:Hide(); B.dline:Hide(); B.dtext:Hide(); B.dcd:Hide(); B.dbg:Hide(); B.dbar:Hide()
  end
  y = y - 1
  B.loot:ClearAllPoints(); B.loot:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, y)
  y = y - 31
  local got, wish = Collected(cls), Wish(cls)
  for k = 1, table.getn(B.items) do
    local r, it = B.items[k], list[k]
    if it then
      local e = LootEntry(cls, zi, bi, it)
      r.entry = e
      r.dot.entry = e
      r.icon:SetTexture("Interface\\Icons\\" .. (it.icon or "INV_Misc_QuestionMark"))
      local c = PAGE_RARITY[e.rarity]
      r.name:SetText(AzG(it.name)); r.name:SetTextColor(c[1], c[2], c[3])
      r.info:SetText(AzG(e.rarity) .. " " .. AzName(it.slot) .. "  -")
      local cc = ChanceColor(z.chance)
      r.chance:SetText(z.chance .. "%")
      r.chance:SetTextColor(cc[1][1], cc[1][2], cc[1][3]); r.chance:SetShadowColor(cc[2][1], cc[2][2], cc[2][3], 1)
      -- already in the collection: the check takes the button's place, nothing left to wish for
      -- the round button only for the hero's own class and only while it is missing
      if got[it.name] then r.check:Show(); r.dot:Hide()
      elseif cls ~= PlayerClass() then r.check:Hide(); r.dot:Hide()
      else r.check:Hide(); r.dot:Show() end
      if wish[WishKey(e)] then r.dot.tex:SetTexture(MEDIA .. "dot_on.tga") else r.dot.tex:SetTexture(MEDIA .. "dot_off.tga") end
      -- a long name (Atiesh, Thunderfury ...) takes two lines: the row grows with it
      local h = math.max(36, (r.name:GetHeight() or 14) + (r.info:GetHeight() or 13) + 7)
      r:SetHeight(h)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 28, y); r:Show()
      y = y - h - 4
    else
      r:Hide()
    end
  end
end

-- The collection book's grid for a class: rows by the rank of the zones (common to the
-- legendary zones), columns by slot as the game orders them; the off hand gets a tenth.
local BOOK_COL = { Head = 1, Shoulder = 2, Chest = 3, Waist = 4, Legs = 5, Feet = 6, Wrist = 7, Hands = 8,
  ["Main Hand"] = 9, Ranged = 9, ["Off Hand"] = 10 }
local function BookGrid(cls)
  local grid, cols = {}, 9
  for r = 1, table.getn(LD.ranks) do grid[r] = {} end
  local zones = LD.drops[cls] or {}
  for zi = 1, table.getn(zones) do
    local rank = 1
    for r = 1, table.getn(LD.ranks) do if LD.ranks[r] == LD.zones[zi].rarity then rank = r end end
    for bi = 1, table.getn(zones[zi]) do
      for k = 1, table.getn(zones[zi][bi]) do
        local it = zones[zi][bi][k]
        local col = BOOK_COL[it.slot]
        if col then
          if col == 10 then cols = 10 end
          if not grid[rank][col] then grid[rank][col] = LootEntry(cls, zi, bi, it) end
        end
      end
    end
  end
  return grid, cols
end

local function DrawBook(cls)
  local K = ui.kv
  local grid, cols = BookGrid(cls)
  local got, all, have = Collected(cls), 0, 0
  local wish = (cls == PlayerClass()) and Wish(cls) or {}
  for r = 1, table.getn(LD.ranks) do
    local row, rh, rn = K.rows[r], 0, 0
    for c = 1, 10 do
      local b, e = row.cells[c], grid[r][c]
      if e and c <= cols then
        b.entry = e
        b.icon:SetTexture("Interface\\Icons\\" .. (e.item.icon or "INV_Misc_QuestionMark"))
        rn = rn + 1
        if got[e.item.name] then
          rh = rh + 1
          -- the frame in the piece's own quality: the legendary zones' armour is epic
          local rc = RARITY_COLOR[e.rarity]
          b.icon:SetVertexColor(1, 1, 1); b.icon:SetAlpha(1); b.q:Hide()
          b.edge:SetVertexColor(rc[1], rc[2], rc[3]); b.edge:SetAlpha(0.9)
        else
          -- missing: a dark, faded picture with a question mark, as in the game
          b.icon:SetVertexColor(0.35, 0.3, 0.25); b.icon:SetAlpha(0.6); b.q:Show()
          b.edge:SetVertexColor(0.16, 0.09, 0.03); b.edge:SetAlpha(1)
        end
        if wish[WishKey(e)] then b.seal:Show() else b.seal:Hide() end
        b:Show()
      else
        b:Hide()
      end
    end
    row.count:SetText(rh .. "/" .. rn)
    row.card:Complete(rn > 0 and rh >= rn)
    all, have = all + rn, have + rh
  end
  local ft = K.foot
  ft.l1:SetWidth((ft.a1:GetStringWidth() or 60) + 1 + (ft.b1:GetStringWidth() or 200))
  ft.l2:SetWidth((ft.a2:GetStringWidth() or 40) + (ft.b2:GetStringWidth() or 70))
  K.count:SetText(AzT("%d of %d", have, all))
  -- the line spans the cards: its name under their left edge, its count ending with their right
  local right = K.left + 2 * K.cw + 12 - 1
  local bw = right - 30 - (K.label:GetStringWidth() or 70) - 8 - 8 - (K.count:GetStringWidth() or 50)
  K.bar:SetBarWidth(math.max(120, bw))
  K.bar:SetProgress(have, all)
  if have >= all and all > 0 then K.count:SetTextColor(1, 0.75, 0.15) else K.count:SetTextColor(INK_GOOD[1], INK_GOOD[2], INK_GOOD[3]) end
end

local function DrawLoot()
  if state.lootBook then
    ui.zoneView:Hide(); ui.bossView:Hide(); ui.bookView:Show()
    DrawBook(state.class or PlayerClass())
    return
  end
  ui.bookView:Hide()
  local e = state.selected
  if not e then return end
  local z = e.zone
  local cls = state.class or PlayerClass()
  local drops = LD.drops[cls] and LD.drops[cls][e.index] or {}
  if state.lootBoss and z.bosses[state.lootBoss] then
    ui.zoneView:Hide(); ui.bossView:Show()
    DrawBoss(z, e.index, state.lootBoss, cls, drops[state.lootBoss] or {})
  else
    state.lootBoss = nil
    ui.bossView:Hide(); ui.zoneView:Show()
    DrawZone(z, cls, drops, e.index)
  end
end

-- Shows the path's crumbs; when they would run into the search field, the longest
-- label loses letters (ending in "...") until the whole path fits.
local function ShowCrumbs(labels)
  local c = ui.crumbs
  local n = table.getn(labels)
  local avail = (820 - 89 - 190 - 10) - (50 + (ui.title:GetStringWidth() or 100) + 6) - 12
  local cut, shown = {}, {}
  for i = 1, n do shown[i] = labels[i] end
  for guard = 1, 300 do
    local w = 0
    for i = 1, n do c[i]:SetLabel(shown[i]); w = w + (c[i].text:GetStringWidth() or 0) + 20 end
    if w <= avail then break end
    local k, kl = nil, 0
    for i = 2, n do
      local l = cut[i] or string.len(labels[i])
      if l > kl then k, kl = i, l end
    end
    if not k or kl <= 3 then break end
    cut[k] = kl - 1
    shown[k] = string.gsub(string.sub(labels[k], 1, cut[k]), "[%s%p]+$", "") .. "..."
  end
  for i = 1, table.getn(c) do if i <= n then c[i]:Show() else c[i]:Hide() end end
end

-- the home page's collection: every class's count and bar
local function DrawHome()
  if not ui.homeCells then return end
  for i = 1, table.getn(ui.homeCells) do
    local cell = ui.homeCells[i]
    local have, n = ClassProgress(cell.key)
    cell.count:SetText(have .. "/" .. n)
    cell.bar:SetProgress(have, n)
    local ah, an = AmuletProgress(cell.key)
    cell.amulets:SetText(AzT("%d/%d amulets discovered", ah, an))
  end
end

local function DrawCrumbs()
  local c = ui.crumbs
  local labels
  if state.module == "Title" then
    labels = {}
  elseif state.module == "Loot" then
    labels = { AzT("Loot"), AzG(ClassInfo(state.class or PlayerClass()).name) }
    if state.lootBook then
      table.insert(labels, AzT("Collection Book"))
    elseif state.selected and state.selected.kind == "Zone" then
      table.insert(labels, AzG(state.selected.zone.name))
      local boss = state.lootBoss and state.selected.zone.bosses[state.lootBoss]
      if boss then table.insert(labels, AzG(boss.name)) end
    end
  elseif state.module == "Spells" then
    labels = { AzT("Spells"), AzG(ClassInfo(state.class or PlayerClass()).name) }
  elseif state.module == "Builds" then
    labels = { AzT("Builds"), AzG(ClassInfo(PlayerClass()).name) }
  elseif state.module == "Chronicle" then
    labels = { AzT("Chronicle"), AzG(ClassInfo(PlayerClass()).name) }
  else
    labels = { AzT("Jewelry") }
    if not (state.view == "Home" and state.search == "") then
      table.insert(labels, state.search ~= "" and AzT("Search") or CatLabel(state.view))
      if state.view == "Legendary" and state.search == "" then
        table.insert(labels, AzG(ClassInfo(state.class or PlayerClass()).name))
      end
    end
  end
  ShowCrumbs(labels)
end

-- the title page's hero and saying
local function DrawTitle()
  local T = ui.tp
  local cls = PlayerClass()
  local ci = ClassInfo(cls)
  T.icon:SetTexture("Interface\\Icons\\" .. (CLASS_ICON[cls] or "INV_Misc_QuestionMark"))
  CLASS_INK.Frame(T.frame, cls, ci.color)
  T.hero:SetText(AzG(ci.name)); CLASS_INK.Name(T.hero, cls)
  local have, n = ClassProgress(cls)
  T.bar:SetProgress(have, n)
  T.count:SetText(have .. "/" .. n)
  local ah, an = AmuletProgress(cls)
  local wished = 0
  local all = WishEntries()
  for i = 1, table.getn(all) do wished = wished + 1 end
  local zones, done = table.getn(LD.zones), 0
  for z = 1, zones do
    local zh, zn = ZoneProgress(cls, z)
    if zn > 0 and zh == zn then done = done + 1 end
  end
  T.lines[1]:SetText(AzT("%d of %d zones fully collected.", done, zones))
  T.lines[2]:SetText(AzT("%d of %d class amulets discovered.", ah, an))
  T.lines[3]:SetText(wished == 0 and AzT("Nothing on your wishlist yet.") or ((wished == 1) and AzT("%d entry on your wishlist.", wished) or AzT("%d entries on your wishlist.", wished)))
  -- a saying: a spell's few words or a boss's cry, chosen when the book opens
  if not state.quote then
    local pool = {}
    for c = 1, table.getn(D.classes) do
      local sp = D.classes[c].spells
      for i = 1, table.getn(sp) do
        if SPELL_QUOTE[sp[i].key] then table.insert(pool, { SPELL_QUOTE[sp[i].key], sp[i].name }) end
      end
    end
    for z = 1, table.getn(LD.zones) do
      local bs = LD.zones[z].bosses
      for b = 1, table.getn(bs) do
        if bs[b].yell then table.insert(pool, { bs[b].yell, bs[b].name }) end
      end
    end
    -- the game starts its dice the same way every time: the clock's milliseconds stir them,
    -- and the saying of last time is not shown twice in a row
    local n = table.getn(pool)
    local stir = math.floor((GetTime and GetTime() or 0) * 1000) + (time and time() or 0) + math.random(n)
    local k = stir - math.floor(stir / n) * n + 1
    local last = type(AzerlootDB) == "table" and AzerlootDB.lastQuote
    if n > 1 and pool[k][1] == last then k = k - math.floor(k / n) * n + 1 end
    state.quote = pool[k]
    if type(AzerlootDB) == "table" then AzerlootDB.lastQuote = pool[k][1] end
  end
  -- the dotted lines: as long as the room between name and page, their dots kept round
  for i = 1, table.getn(T.chapters) do
    local b = T.chapters[i]
    local w = 330 - 10 - (b.page:GetStringWidth() or 12) - 6 - 78 - (b.name:GetStringWidth() or 80) - 8
    b.dots:SetTexCoord(0, math.max(0.02, math.min(1, w / 512)), 0, 1)
  end
  T.quote:SetText("\"" .. AzT(AzG(state.quote[1])) .. "\"")
  T.who:SetText("- " .. AzName(state.quote[2]))
end

Refresh = function()
  if not frame then return end
  for i = 1, table.getn(ui.tabs) do
    local t = ui.tabs[i]
    local on = (t.key == state.module)
    t.glow:SetAlpha(on and 1 or 0)
    if on then t.icon:SetVertexColor(1, 1, 1); t.bg:SetVertexColor(1, 1, 1)
    else t.icon:SetVertexColor(0.7, 0.7, 0.7); t.bg:SetVertexColor(0.75, 0.75, 0.75) end
  end
  if (state.module == "Builds" or state.module == "Chronicle") and state.search ~= "" then state.module = "Jewelry"; state.view = "Home" end
  if state.module == "Builds" and not AzlB then state.module = "Title" end
  if state.module == "Chronicle" and not AzlC then state.module = "Title" end
  if AzlC and state.module ~= "Chronicle" then AzlC.HidePane() end
  local home = (state.view == "Home") and (state.search == "")
  -- the builds pages stay up while the book redraws them (their hero is borrowed only once)
  if AzlB and AzlB.HidePane and state.module ~= "Builds" then AzlB.HidePane() end
  if state.module == "Spells" then WarmSpellDescs() end
  if state.module == "Title" then
    if state.search ~= "" then state.module = "Jewelry"
    else
      ui.homePane:Hide(); ui.listPane:Hide(); ui.detailPane:Hide(); ui.lootPane:Hide()
      ui.titlePane:Show()
      DrawTitle()
      DrawCrumbs()
      return
    end
  end
  ui.titlePane:Hide()
  if state.module == "Loot" then
    ui.homePane:Hide(); ui.detailPane:Hide(); ui.listPane:Show(); ui.lootPane:Show()
    if state.search ~= "" then state.search = ""; if ui.search then ui.search:SetText("") end end
    -- open on a zone straight away: the one picked before, else the first
    if not (state.selected and state.selected.kind == "Zone") then
      state.selected = ZoneEntries()[state.lootZone or 1]
    end
    state.lootZone = state.selected.index
    DrawList(); DrawLoot()
    DrawCrumbs()
    return
  end
  ui.lootPane:Hide()
  if state.module == "Builds" then
    ui.homePane:Hide(); ui.listPane:Hide(); ui.detailPane:Hide()
    AzlB.ShowPane()
    DrawCrumbs()
    return
  end
  if state.module == "Chronicle" then
    ui.homePane:Hide(); ui.listPane:Hide(); ui.detailPane:Hide()
    AzlC.ShowPane()
    DrawCrumbs()
    return
  end
  if home then
    ui.homePane:Show(); ui.listPane:Hide(); ui.detailPane:Hide()
    DrawHome()
  else
    ui.homePane:Hide(); ui.listPane:Show(); ui.detailPane:Show()
    DrawList(); DrawDetail()
  end
  DrawCrumbs()
end

-- ---------- building the book ----------
local function Tex(parent, file, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(MEDIA .. file)
  return t
end

-- The book's own text face: the italic, if the client can load it; else the game's.
local BODY = FONT
local function PickBodyFont(parent)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont(ITALIC_FONT, 14)
  local got = f:GetFont()
  if got and string.find(string.upper(got), "AZERLOOTITALIC", 1, true) then BODY = ITALIC_FONT end
  f:Hide()
end

-- ---------- the reading face ----------
-- Besides the book's own faces, a player can pick a typeface that is easier to read, for
-- example with dyslexia. Every text the book draws is noted here with its classic face and
-- size, so a new pick can redraw all of them at once. A picked face is set at the size that
-- gives the classic width (measured in the game), so no text grows out of its place.
local FONT_DIR = "Interface\\AddOns\\Azerloot\\media\\fonts\\"
local FACES = {
  { key = "classic", label = "Original",
    tip = "The book's own faces: storybook headings and an italic hand." },
  { key = "hyperlegible", label = "Atkinson Hyperlegible",
    body = FONT_DIR .. "AtkinsonHyperlegible-Regular.ttf", head = FONT_DIR .. "AtkinsonHyperlegible-Bold.ttf",
    tip = "Made by the Braille Institute so that similar letters never look alike. Plain and very clear." },
  { key = "andika", label = "Andika",
    body = FONT_DIR .. "Andika-Regular.ttf", head = FONT_DIR .. "Andika-Bold.ttf",
    tip = "Made by SIL for beginning readers: simple, open letters that are hard to mix up." },
  { key = "comic", label = "Comic Neue",
    body = FONT_DIR .. "ComicNeue-Regular.ttf", head = FONT_DIR .. "ComicNeue-Bold.ttf",
    tip = "Rounded, handwritten letters in the style many readers with dyslexia find easiest." },
}
local fontReg = {}     -- every text of the book: its role ("body" or "head") and classic face and size
local faceScale = {}   -- per picked face and classic face: the size factor that keeps the classic width
local faceBroken = {}  -- faces the client could not load
local measure          -- a hidden string to measure faces with
local MEASURE_TEXT = "The quick brown fox jumps over the lazy dog, 1234567890."

local function FaceInfo(key)
  for i = 1, table.getn(FACES) do if FACES[i].key == key then return FACES[i] end end
  return FACES[1]
end

-- (group "warn": the warner's own pick, Settings - Azerwarn - Font, when it is not "book")
local function FaceKey(group)
  local k = type(AzerlootDB) == "table" and AzerlootDB.font or "classic"
  if group == "warn" and type(AzerlootDB) == "table" and AzerlootDB.warnFont and AzerlootDB.warnFont ~= "book" then
    k = AzerlootDB.warnFont
  end
  local f = FaceInfo(k)
  if faceBroken[f.key] then return "classic" end
  return f.key
end

-- true if the string really draws in this face (the client keeps the old face otherwise)
local function Loaded(fs, face)
  local got = fs:GetFont()
  if type(got) ~= "string" then return false end
  local base = string.gsub(string.upper(face), "^.*\\", "")
  return string.find(string.upper(got), base, 1, true) ~= nil
end

local function MeasureWidth(face, size)
  if not measure then
    local m = CreateFrame("Frame", nil, UIParent)
    m:SetAlpha(0)   -- never anchored and never seen: it only measures
    measure = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  end
  measure:SetFont(face, size)
  if not Loaded(measure, face) then return nil end
  measure:SetText(MEASURE_TEXT)
  local w = measure:GetStringWidth()
  if type(w) ~= "number" or w <= 0 then return nil end
  return w
end

-- the factor for drawing `face` as wide as the classic face `classic`
local function FaceScale(face, classic)
  local k = face .. "|" .. classic
  if not faceScale[k] then
    local a, b = MeasureWidth(classic, 20), MeasureWidth(face, 20)
    if a and b then faceScale[k] = math.max(0.6, math.min(1.25, a / b)) else faceScale[k] = 1 end
  end
  return faceScale[k]
end

local function ApplyFace(fs, e)
  local pick = FaceInfo(FaceKey(e.group))
  local face = pick.body and ((e.role == "head") and pick.head or pick.body)
  local bump = e.bump or 0
  if face then
    fs:SetFont(face, math.floor((e.size + bump) * FaceScale(face, e.face) + 0.5), e.flags)
    if Loaded(fs, face) then return end
    faceBroken[pick.key] = true   -- the client cannot draw it: back to the classic faces
  end
  fs:SetFont(e.face, e.size + bump, e.flags)
end

-- notes a string with its role and classic face and size, and draws it in the picked face
local function SetFace(fs, role, face, size, flags, group)
  local e = { role = role, face = face, size = size, flags = flags or "", group = group }
  fontReg[fs] = e
  ApplyFace(fs, e)
  return fs
end

-- redraws every text of the book after a new pick
local function ApplyAllFaces()
  for fs, e in pairs(fontReg) do ApplyFace(fs, e) end
end

local function Font(parent, template, c, size)
  local f = parent:CreateFontString(nil, "OVERLAY", template)
  if size then
    SetFace(f, "body", BODY, size)
  else
    -- the template's own face and size are its classic look
    local face, s, fl = f:GetFont()
    if type(face) == "string" and type(s) == "number" then
      fontReg[f] = { role = "body", face = face, size = s, flags = type(fl) == "string" and fl or "" }
      ApplyFace(f, fontReg[f])
    end
  end
  if c then f:SetTextColor(c[1], c[2], c[3]); f:SetShadowColor(0, 0, 0, 0) end
  return f
end

-- Headings in the storybook face; if the client lacks it, they stay in the body face.
local function Heading(f, size)
  f:SetFont(HEAD_FONT, size)
  local got = f:GetFont()
  if not got or not string.find(string.upper(got), "MORPHEUS", 1, true) then
    SetFace(f, "head", FONT, size - 2)
  else
    SetFace(f, "head", HEAD_FONT, size)
  end
  return f
end

-- A heading as large as it can be up to `size`, made smaller until it fits `width` on one line.
FitHeading = function(fs, text, size, width)
  Heading(fs, size)
  fs:SetText(text)
  local w = fs:GetStringWidth() or 0
  if w > width then
    Heading(fs, math.max(15, math.floor(size * width / w)))
    fs:SetText(text)
  end
end

-- dark ink on the paper: no shadow, a light edge showed as a white rim on the darker parchment
local function Engraved(f)
  f:SetShadowColor(0, 0, 0, 0); f:SetShadowOffset(1, -1)
  return f
end

-- light text on dark wood: a firm black shadow keeps it readable
local function Carved(f)
  f:SetShadowColor(0, 0, 0, 1); f:SetShadowOffset(1, -1)
  return f
end

local function Highlight(parent, alpha, inset)
  local hl = parent:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(GLOW)
  hl:SetBlendMode("ADD"); hl:SetAlpha(alpha)
  hl:SetPoint("TOPLEFT", parent, "TOPLEFT", inset or 0, -(inset or 0))
  hl:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(inset or 0), inset or 0)
  return hl
end

local OnPage

-- A soft shadow under a texture or frame, so it seems to lie on the page.
local function DropShadow(parent, target, dx, dy, grow, alpha, file)
  local sh = parent:CreateTexture(nil, "BACKGROUND")
  sh:SetTexture(MEDIA .. (file or "dropshadow.tga"))
  sh:SetVertexColor(0.12, 0.06, 0.01)
  sh:SetAlpha(alpha or 0.8)
  sh:SetPoint("TOPLEFT", target, "TOPLEFT", dx - grow, dy + grow)
  sh:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", dx + grow, dy - grow)
  return sh
end

-- An icon set into the page: dark rim, soft shadow, the picture on top.
local function SetIcon(parent, size, layer)
  local box = CreateFrame("Frame", nil, parent)
  box:SetWidth(size); box:SetHeight(size)
  -- the shadow art fills only the middle half of its square, so it is drawn at twice
  -- the icon's size to reach out from under it, a little to the lower right
  DropShadow(box, box, 3, -4, math.floor(size / 2), 0.8, "shadow.tga")
  local rim = box:CreateTexture(nil, "BORDER")
  rim:SetTexture(WHITE); rim:SetVertexColor(0.16, 0.09, 0.03)
  rim:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2); rim:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
  local icon = box:CreateTexture(nil, layer or "ARTWORK")
  icon:SetAllPoints(box)
  icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
  box.icon = icon
  return box
end

-- ---------- page turning ----------
-- A tab change turns a leaf: it lifts off one page, stands up, and lays down on the other,
-- the new pages showing through as it settles.
local FLIP_TIME, FLIP_SETTLE, LEAF_W = 0.36, 0.14, 385

local function ContentAlpha(a)
  for i = 1, table.getn(ui.panes) do ui.panes[i]:SetAlpha(a) end
end

-- The leaf hangs from the spine; `rightSide` says which page it lies over now.
local function PlaceLeaf(rightSide, w)
  local f = ui.flip
  f:ClearAllPoints()
  f.cast:ClearAllPoints()
  if rightSide then
    f:SetPoint("TOPLEFT", ui.pageR, "TOPLEFT", 0, 0)
    f.sheet:SetTexture(MEDIA .. "page_r.tga"); f.sheet:SetTexCoord(0, 1, 0, 1)
    f.cast:SetPoint("CENTER", f, "RIGHT", 0, 0)
  else
    f:SetPoint("TOPRIGHT", ui.pageL, "TOPRIGHT", 0, 0)
    f.sheet:SetTexture(MEDIA .. "page.tga"); f.sheet:SetTexCoord(0, 1, 0, 1)
    f.cast:SetPoint("CENTER", f, "LEFT", 0, 0)
  end
  f:SetWidth(math.max(1, w))
end

local function FlipStep()
  local f = ui.flip
  local t, half = f.t, FLIP_TIME / 2
  if t < half then
    -- rising: the leaf narrows towards the spine and darkens
    local th = (t / half) * math.pi / 2
    PlaceLeaf(f.forward, LEAF_W * math.cos(th))
    f.shade:SetAlpha(0.45 * math.sin(th)); f.cast:SetAlpha(0.5 * math.cos(th))
    f:SetAlpha(1)
    ContentAlpha(0)
  elseif t < FLIP_TIME then
    -- falling: it opens out over the other page while the new pages appear
    local u = (t - half) / half
    local th = u * math.pi / 2
    PlaceLeaf(not f.forward, LEAF_W * math.sin(th))
    f.shade:SetAlpha(0.45 * math.cos(th)); f.cast:SetAlpha(0.5 * math.sin(th))
    f:SetAlpha(1)
    ContentAlpha(u)
  else
    -- settled: the leaf melts into the page it landed on
    local v = math.min(1, (t - FLIP_TIME) / FLIP_SETTLE)
    PlaceLeaf(not f.forward, LEAF_W)
    f.shade:SetAlpha(0); f.cast:SetAlpha(0)
    f:SetAlpha(1 - v)
    ContentAlpha(1)
    if v >= 1 then f:Hide(); f:SetAlpha(1); ui.flipping = false end
  end
end

-- forward: the right page turns over to the left (to a later chapter); back: the other way
PageTurn = function(forward)
  if not (frame and frame:IsVisible() and ui.flip) then return end
  ui.fader:Hide()
  ui.flip.t, ui.flip.forward = 0, forward
  ui.flipping = true
  ui.flip:Show()
  FlipStep()
end

-- a boss's page fades in where the zone's was
local function FadeIn(f)
  if ui.flipping or not ui.fader then return end
  ui.fader.t, ui.fader.target = 0, f
  f:SetAlpha(0)
  ui.fader:Show()
end

local function StopAnimations()
  if not ui.flip then return end
  ui.flip:Hide(); ui.flip:SetAlpha(1); ui.flipping = false
  ui.fader:Hide()
  ContentAlpha(1)
  ui.bossView:SetAlpha(1)
end

-- A small progress bar: a sunken trough in a brass rim, filled green; gold once complete.
local BAR_GREEN, BAR_GOLD = { 0.25, 0.8, 0.1 }, { 1, 0.75, 0.15 }
local function ProgressBar(parent, w, h)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(w); b:SetHeight(h)
  -- set into the page: a soft shadow the bar sits in, a little to the lower right
  local sh = b:CreateTexture(nil, "BACKGROUND")
  sh:SetTexture(MEDIA .. "bar_shadow.tga"); sh:SetVertexColor(0.16, 0.08, 0.01); sh:SetAlpha(0.55)
  sh:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4); sh:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -6)
  -- a deep trough in a brass rim; the fill is glass-bright, green while it grows and gold
  -- once complete, round at both ends like the trough, with a soft light that sweeps
  -- along it and a glow at its leading edge
  -- the trough under the fill, the brass rim over it: the fill's ends tuck under the rim
  local trough = Tex(b, "bar_trough.tga", "BORDER"); trough:SetAllPoints(b)
  local rim = Tex(b, "bar_rim.tga", "OVERLAY"); rim:SetAllPoints(b)
  local ins = math.max(1, math.floor(h * 0.17 + 0.5))
  local hx = math.max(0, ins - 1)
  local fh = h - 2 * ins
  local cap = math.max(1, math.floor(fh / 2 + 0.5))
  local capL = Tex(b, "bar_cap_green_l.tga", "ARTWORK")
  capL:SetPoint("TOPLEFT", b, "TOPLEFT", hx, -ins); capL:SetWidth(cap); capL:SetHeight(fh)
  local fill = Tex(b, "bar_fill_green.tga", "ARTWORK")
  fill:SetPoint("TOPLEFT", capL, "TOPRIGHT", 0, 0)
  fill:SetHeight(fh)
  local capR = Tex(b, "bar_cap_green_r.tga", "ARTWORK")
  capR:SetHeight(fh)
  local shine = Tex(b, "bar_shine.tga", "OVERLAY")
  shine:SetBlendMode("ADD"); shine:SetHeight(fh); shine:Hide()
  local tip = b:CreateTexture(nil, "OVERLAY")
  tip:SetTexture(GLOW); tip:SetBlendMode("ADD")
  tip:SetWidth(h * 2.2); tip:SetHeight(h * 2.4); tip:Hide()
  b.fill, b.inner, b.ins, b.shine, b.tip, b.capL, b.capR, b.cap = fill, w - 2 * hx, hx, shine, tip, capL, capR, cap
  b.have, b.total, b.fw, b.done = false, 0, 0, false
  b.SetBarWidth = function(self, nw)
    self:SetWidth(nw); self.inner = nw - 2 * self.ins
    if self.have then self:SetProgress(self.have, self.total) end
  end
  b.SetProgress = function(self, have, total)
    self.have, self.total = have, total
    local f = (total > 0) and (have / total) or 0
    if f <= 0 then
      self.fill:Hide(); self.capL:Hide(); self.capR:Hide(); self.tip:Hide(); self.shine:Hide(); self.fw = 0
      return
    end
    if f > 1 then f = 1 end
    local done = have >= total
    local fw = math.max(2, self.inner * f)
    self.fw = fw
    local c = math.min(self.cap, math.floor(fw / 2))
    local col = done and "gold" or "green"
    self.capL:SetTexture(MEDIA .. "bar_cap_" .. col .. "_l.tga"); self.capL:SetWidth(math.max(1, c))
    self.capR:SetTexture(MEDIA .. "bar_cap_" .. col .. "_r.tga"); self.capR:SetWidth(math.max(1, c))
    local body = fw - 2 * c
    self.capR:ClearAllPoints()
    if body >= 1 then
      self.fill:SetTexture(MEDIA .. "bar_fill_" .. col .. ".tga")
      self.fill:SetWidth(body)
      -- the bands keep their size, however full the bar
      self.fill:SetTexCoord(0, math.max(0.002, body / self.inner), 0, 1)
      self.fill:SetVertexColor(1, 1, 1)
      self.fill:Show()
      self.capR:SetPoint("TOPLEFT", self.fill, "TOPRIGHT", 0, 0)
    else
      self.fill:Hide()
      self.capR:SetPoint("TOPLEFT", self.capL, "TOPRIGHT", 0, 0)
    end
    self.capL:Show(); self.capR:Show()
    self.tip:ClearAllPoints(); self.tip:SetPoint("CENTER", self.capR, "RIGHT", -1, 0)
    if done then self.tip:SetVertexColor(1, 0.8, 0.3) else self.tip:SetVertexColor(0.6, 1, 0.4) end
    self.tip:SetAlpha(0.55)
    if f < 1 then self.tip:Show() else self.tip:Hide() end
    self.done = done
  end
  b:SetScript("OnUpdate", function()
    local fw = this.fw or 0
    if fw < 4 then this.shine:Hide(); return end
    local t = GetTime and GetTime() or 0
    -- the light crosses the fill every few seconds, kept off the round ends
    local sw = (this:GetHeight() or 10) * 3
    local c = this.cap
    local span = fw - 2 * c
    local x = (t - math.floor(t / 3.6) * 3.6) / 3.6 * (span + sw * 2) - sw
    local l, r = math.max(0, x), math.min(span, x + sw)
    if r - l < 1 then this.shine:Hide()
    else
      this.shine:ClearAllPoints(); this.shine:SetPoint("LEFT", this.capL, "RIGHT", l, 0)
      this.shine:SetWidth(r - l); this.shine:SetTexCoord((l - x) / sw, (r - x) / sw, 0, 1)
      this.shine:SetAlpha(this.done and 0.75 or 0.5)
      this.shine:Show()
    end
    if this.tip:IsShown() then this.tip:SetAlpha(0.4 + 0.25 * math.sin(t * 3)) end
  end)
  return b
end

-- The boss warner's (Azerwarn) two parts, each switched on its own in the settings window: the
-- big words in the middle of the screen, and the boss's line in the wishlist window.
AZL_WARN_PARTS = {
  { key = "bossAlerts", label = "Warnings",
    tip = "Big words when a boss comes, when it turns and when the game calls a stampede, a pack or a guardian. The game's own banners make room for them." },
  { key = "bossBar", label = "Boss in the wishlist",
    tip = "A line in the wishlist window: the next boss and its time, or the boss alive with its health and the marks where it turns." },
}

-- The settings, built apart from the book so neither function grows too big for the game's
-- Lua (it allows a function only so many outside names).
local function BuildSettings(search)
  -- the settings: a brass gear before the close button. It opens the settings window
  -- (modules\Settings.lua), in front of the book, which steps back into the dark meanwhile.
  local gear = CreateFrame("Button", nil, frame)
  OnPage(gear)
  gear:SetWidth(19); gear:SetHeight(19)
  gear:SetPoint("LEFT", search, "RIGHT", 11, 0)   -- (beside the cross; their medallions do not touch)
  local gt = Tex(gear, "gear.tga", "ARTWORK"); gt:SetAllPoints(gear)
  -- under the mouse it sits on a small dark medallion with a gold rim (inside the bar's band)
  local gd = Tex(gear, "btn_disc.tga", "BORDER"); gd:SetWidth(24); gd:SetHeight(24); gd:SetPoint("CENTER", gear, "CENTER", 0, 0); gd:Hide()
  -- lit like the path and the title while the mouse is on it
  local gg = gear:CreateTexture(nil, "BACKGROUND")
  gg:SetTexture(GLOW); gg:SetBlendMode("ADD"); gg:SetVertexColor(1, 0.72, 0.15)
  gg:SetPoint("TOPLEFT", gear, "TOPLEFT", -14, 12); gg:SetPoint("BOTTOMRIGHT", gear, "BOTTOMRIGHT", 14, -12)
  gg:Hide()
  gear.Lit = function(self, on)
    if on then gg:Show(); gd:Show(); gt:SetVertexColor(1, 1, 0.8) else gg:Hide(); gd:Hide(); gt:SetVertexColor(1, 1, 1) end
  end
  gear.glow = gg
  gear:SetScript("OnClick", function()
    GameTooltip:Hide()
    if AzlSettings then AzlSettings.Toggle(nil, "book") end   -- (fixed over the book)
  end)
  gear:SetScript("OnEnter", function()
    this:Lit(true)
    -- short lines that never wrap: the client lays out wrapped lines badly in this corner
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(AzT("Settings"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Opens the settings window."), 0.85, 0.85, 0.85)
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function() GameTooltip:Hide(); this:Lit(false) end)
  ui.gear = gear
end

-- the home pages' headings and the right page's collection of every class
local function BuildHomeCollection(Strip)
  -- HOME: the left page's heading, level with the Collection on the right
  local tr = Strip(ui.homePane, "Treasury")
  tr:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 21, -12)
  local coin = tr:CreateTexture(nil, "OVERLAY")
  coin:SetTexture("Interface\\MoneyFrame\\UI-MoneyIcons")
  coin:SetTexCoord(0, 0.25, 0, 1)   -- the gold coin of the game's money icons
  coin:SetWidth(16); coin:SetHeight(16)
  coin:SetPoint("RIGHT", tr, "RIGHT", -22, 0)

  -- HOME: the right page holds the boss loot every class has collected
  local hc = Strip(ui.homePane, "Collection")
  hc:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, -12)
  local tab = hc:CreateTexture(nil, "OVERLAY")
  tab:SetTexture("Interface\\GossipFrame\\TabardGossipIcon")
  tab:SetWidth(18); tab:SetHeight(18)
  tab:SetPoint("RIGHT", hc, "RIGHT", -22, 0)
  ui.homeCells = {}
  for i = 1, table.getn(D.classes) do
    local c = D.classes[i]
    local cell = CreateFrame("Button", nil, ui.homePane)
    -- centred under the heading
    cell:SetWidth(296); cell:SetHeight(38)
    cell:SetPoint("TOP", ui.right, "TOP", 0, -48 - (i - 1) * 39)
    -- the class icon in its colour, as in the class picker
    local ib = CreateFrame("Frame", nil, cell)
    ib:SetWidth(28); ib:SetHeight(28)
    ib:SetPoint("LEFT", cell, "LEFT", 4, 0)
    local sh = ib:CreateTexture(nil, "BACKGROUND")
    sh:SetTexture(MEDIA .. "shadow.tga"); sh:SetVertexColor(0.15, 0.08, 0.02); sh:SetAlpha(0.75)
    sh:SetPoint("TOPLEFT", ib, "TOPLEFT", -12, 9); sh:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", 16, -17)
    local fr = ib:CreateTexture(nil, "BORDER"); fr:SetAllPoints(ib); fr:SetTexture(WHITE)
    CLASS_INK.Frame(fr, c.key, c.color)
    local ic = ib:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("TOPLEFT", ib, "TOPLEFT", 2, -2); ic:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", -2, 2)
    ic:SetTexture("Interface\\Icons\\" .. (CLASS_ICON[c.key] or c.spells[1].icon))
    ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- the name above a long bar, the count at the right end of the bar
    local nm = Heading(Font(cell, "GameFontNormal", ClassInk(c.key)), 15); CLASS_INK.Name(nm, c.key)
    nm:SetPoint("TOPLEFT", ib, "TOPRIGHT", 10, 2)
    nm:SetText(AzG(c.name))
    local bar = ProgressBar(cell, 196, 10)
    bar:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -4)
    local cnt = Engraved(Font(cell, "GameFontNormal", INK_SOFT, 13))
    cnt:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    -- the class amulets it has worn, small at the right end of the name line
    local am = Engraved(Font(cell, "GameFontNormalSmall", INK_SOFT, 11))
    am:SetPoint("BOTTOMRIGHT", cnt, "TOPRIGHT", 0, 5)
    am:SetJustifyH("RIGHT")
    cell.key, cell.bar, cell.count, cell.amulets = c.key, bar, cnt, am
    Highlight(cell, 0.25, -2)
    -- a class's line opens its loot, a page further on
    cell:SetScript("OnClick", function()
      state.module = "Loot"; state.class = this.key
      state.selected = nil; state.lootBoss = nil; state.offset = 0
      state.lootBook = true   -- straight to the class's collection book
      Refresh()
      PageTurn(true)
    end)
    cell:SetScript("OnEnter", function()
      local ci = ClassInfo(this.key)
      local have, n = ClassProgress(this.key)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine("|cff" .. ci.color .. AzG(ci.name) .. "|r")
      GameTooltip:AddLine(AzT("%d of %d boss pieces collected", have, n), 0.8, 0.8, 0.8)
      local ah, an = AmuletProgress(this.key)
      GameTooltip:AddLine(AzT("%d of %d class amulets discovered (worn in a run)", ah, an), 0.8, 0.8, 0.8)
      GameTooltip:AddLine(AzT("Click to open this class's loot."), 0.6, 0.6, 0.6, 1)
      GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.homeCells[i] = cell
  end
  local foot = Font(ui.homePane, "GameFontNormalSmall", INK_SOFT, 12)
  foot:SetPoint("TOP", ui.right, "TOP", 0, -408)
  foot:SetWidth(320)
  foot:SetText(AzT("Counted: drops, worn pieces and your own marks."))

end

-- a boss's page in the Loot chapter
local function BuildBossView(Strip)
  -- the boss: a portrait in a brass ring, its words, its numbers, its dangers, its loot
  ui.bossView = CreateFrame("Frame", nil, ui.lootPane)
  ui.bossView:SetAllPoints(frame)
  local B = { abilities = {}, items = {} }
  local av = CreateFrame("Frame", nil, ui.bossView)
  av:SetWidth(76); av:SetHeight(76)
  av:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 20, -4)
  DropShadow(av, av, 3, -4, 30, 0.85, "shadow.tga")
  local face = av:CreateTexture("AzerlootBossFace", "BORDER")
  face:SetWidth(54); face:SetHeight(54); face:SetPoint("CENTER", av, "CENTER", 0, 0)
  B.avatar = face
  local ring = Tex(av, "ring.tga", "OVERLAY"); ring:SetAllPoints(av)
  B.name = Engraved(Heading(Font(ui.bossView, "GameFontNormalLarge", INK), 22))
  B.name:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 104, -14)
  B.name:SetWidth(232); B.name:SetJustifyH("LEFT")
  B.sub = Engraved(Font(ui.bossView, "GameFontNormalSmall", INK_SOFT, 12))
  B.sub:SetPoint("TOPLEFT", B.name, "BOTTOMLEFT", 0, -3)
  B.sub:SetWidth(240); B.sub:SetJustifyH("LEFT")
  B.yell = Engraved(Font(ui.bossView, "GameFontNormal", INK, 13))
  B.yell:SetWidth(310); B.yell:SetJustifyH("CENTER")
  B.div = Tex(ui.bossView, "divider.tga", "ARTWORK")
  B.div:SetWidth(330); B.div:SetHeight(16)
  -- back to the zone: the book's own page arrow, in the page's top corner
  local back = CreateFrame("Button", nil, ui.bossView)
  back:SetWidth(28); back:SetHeight(28)
  back:SetPoint("TOPRIGHT", ui.right, "TOPRIGHT", -10, -4)
  back:SetNormalTexture(PAGE_BTN .. "PrevPage-Up")
  back:SetPushedTexture(PAGE_BTN .. "PrevPage-Down")
  back:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  back:SetScript("OnClick", function() state.lootBoss = nil; Refresh() end)
  back:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine(this.tip or AzT("Back"), 1, 0.82, 0)
    GameTooltip:Show()
  end)
  back:SetScript("OnLeave", function() GameTooltip:Hide() end)
  B.back = back

  -- STATS: health and hit in red, speed in gold, each after its name
  B.statStrip = Strip(ui.bossView, "Stats")
  -- marked with the sword of the game's PvP rank badges
  local sword = B.statStrip:CreateTexture(nil, "OVERLAY")
  sword:SetTexture("Interface\\PvPRankBadges\\PvPRank06")
  sword:SetWidth(18); sword:SetHeight(18)
  sword:SetPoint("RIGHT", B.statStrip, "RIGHT", -22, 0)
  local st = CreateFrame("Frame", nil, ui.bossView)
  st:SetWidth(310); st:SetHeight(36)
  B.stats = st
  -- two columns of two: name and number in the same face and size, on one line
  local function Stat(label, x, y, col, edge)
    local l = Engraved(Font(st, "GameFontNormal", INK_SOFT, 13))
    l:SetPoint("TOPLEFT", st, "TOPLEFT", x, y)
    l:SetText(AzT(label) .. ":")
    local v = Font(st, "GameFontNormal", col, 13)
    v:SetShadowColor(edge[1], edge[2], edge[3], 1); v:SetShadowOffset(1, -1)
    v:SetPoint("LEFT", l, "RIGHT", 3, 0)
    return v
  end
  B.health = Stat("Health", 0, 0, INK_GOOD, { 0.02, 0.14, 0 })   -- the green of the Jewelry effects
  B.hit = Stat("Hit", 160, 0, { 0.86, 0.1, 0.06 }, { 0.2, 0, 0 })
  B.speed = Stat("Speed", 0, -18, { 1, 0.78, 0.08 }, { 0.25, 0.12, 0 })
  B.spawns = Stat("Spawns", 160, -18, PAGE_RARITY.Legendary, { 0.22, 0.07, 0 })   -- the legendary orange

  -- DANGERS: marked with the skull the game shows for a foe far above you
  B.dangers = Strip(ui.bossView, "Dangers")
  local skull = B.dangers:CreateTexture(nil, "OVERLAY")
  skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  skull:SetWidth(18); skull:SetHeight(18)
  skull:SetPoint("RIGHT", B.dangers, "RIGHT", -22, 0)
  -- one icon for each attack (and one for what it does once wounded)
  B.dicons = {}
  for i = 1, 8 do
    local r = CreateFrame("Button", nil, ui.bossView)
    r:SetWidth(26); r:SetHeight(26)
    local ib = SetIcon(r, 26)
    ib:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.icon = ib.icon
    -- above the icon, as for the chosen class on the loot page but always in the book's
    -- gold: the picked one gets a gold frame, a breathing glow and a few sparks; the one
    -- under the mouse a soft light (the icon's own frame would cover anything on the button)
    local ov = CreateFrame("Frame", nil, r)
    ov:SetAllPoints(r); ov:SetFrameLevel(ib:GetFrameLevel() + 2)
    local GR, GG, GB = 1, 0.78, 0.25
    local edges = {}
    for k = 1, 4 do
      local e = ov:CreateTexture(nil, "ARTWORK"); e:SetTexture(WHITE); e:SetVertexColor(GR, GG, GB)
      if k <= 2 then e:SetHeight(2) else e:SetWidth(2) end
      e:Hide(); edges[k] = e
    end
    edges[1]:SetPoint("TOPLEFT", r, "TOPLEFT", -2, 2); edges[1]:SetPoint("TOPRIGHT", r, "TOPRIGHT", 2, 2)
    edges[2]:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", -2, -2); edges[2]:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 2, -2)
    edges[3]:SetPoint("TOPLEFT", r, "TOPLEFT", -2, 2); edges[3]:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", -2, -2)
    edges[4]:SetPoint("TOPRIGHT", r, "TOPRIGHT", 2, 2); edges[4]:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 2, -2)
    r.edges = edges
    local sel = ov:CreateTexture(nil, "OVERLAY")
    sel:SetTexture(MEDIA .. "selglow.tga"); sel:SetVertexColor(GR, GG, GB)
    sel:SetWidth(56); sel:SetHeight(56); sel:SetPoint("CENTER", r, "CENTER", 0, 0)
    sel:Hide()
    r.sel = sel
    local sp = ov:CreateTexture(nil, "OVERLAY")
    sp:SetTexture(MEDIA .. "selsparks.tga"); sp:SetVertexColor(GR, GG, GB)
    sp:SetWidth(56); sp:SetHeight(56); sp:SetPoint("CENTER", r, "CENTER", 0, 0)
    sp:Hide()
    r.sparks = sp
    local lit = ov:CreateTexture(nil, "OVERLAY")
    lit:SetTexture(GLOW); lit:SetBlendMode("ADD"); lit:SetAlpha(0.5)
    lit:SetPoint("TOPLEFT", r, "TOPLEFT", -6, 6); lit:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 6, -6)
    lit:Hide()
    r.lit = lit
    r.Pick = function(self, on)
      self.on = on
      for k = 1, 4 do if on then self.edges[k]:Show() else self.edges[k]:Hide() end end
      if on then self.sel:Show(); self.sparks:Show() else self.sel:Hide(); self.sparks:Hide() end
    end
    r:SetScript("OnEnter", function()
      local a = this.ab
      if not a then return end
      this.lit:Show()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzlDangerName(a), 1, 0.82, 0)
      GameTooltip:AddLine(AzlDangerText(a), 1, 1, 1, 1)
      if a.cd then GameTooltip:AddLine(AzT("Every %s sec.", AzlNum(a.cd)), 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() this.lit:Hide(); GameTooltip:Hide() end)
    r:SetScript("OnClick", function()
      B.pick = this.index
      if B.redraw then B.redraw() end
    end)
    r:Hide()
    B.dicons[i] = r
  end
  -- the picked attack's glow breathes and its sparks twinkle, as the chosen class's do
  local pulseF, pulse = CreateFrame("Frame", nil, ui.bossView), 0
  pulseF:SetScript("OnUpdate", function()
    pulse = pulse + (arg1 or 0)
    for k = 1, table.getn(B.dicons) do
      local d = B.dicons[k]
      if d.on and d:IsShown() then
        d.sel:SetAlpha(0.72 + 0.28 * math.sin(pulse * 2.6))
        local grow = 56 + 3 * math.sin(pulse * 2.6)
        d.sel:SetWidth(grow); d.sel:SetHeight(grow)
        d.sparks:SetAlpha(0.35 + 0.45 * (0.5 + 0.5 * math.sin(pulse * 1.7 + 1.3)))
      end
    end
  end)
  -- the picked attack, set off as a note in the margin: a faint darker band of paper with a
  -- blood-red edge on its left, the name in red ink over a red line that fades out, how often
  -- it comes on the right, and what it does below
  local VIOLET = { 0.72, 0.1, 0.05 }   -- (the name stayed: it was violet once)
  B.dbg = ui.bossView:CreateTexture(nil, "BACKGROUND"); B.dbg:SetTexture(WHITE)
  B.dbg:SetVertexColor(0.42, 0.22, 0.05); B.dbg:SetAlpha(0.13); B.dbg:SetWidth(318)
  B.dbar = ui.bossView:CreateTexture(nil, "ARTWORK"); B.dbar:SetTexture(WHITE)
  B.dbar:SetVertexColor(VIOLET[1], VIOLET[2], VIOLET[3]); B.dbar:SetAlpha(0.85); B.dbar:SetWidth(3)
  B.dname = Engraved(Heading(Font(ui.bossView, "GameFontNormal", { 0.62, 0.06, 0.03 }), 16))
  B.dline = ui.bossView:CreateTexture(nil, "ARTWORK"); B.dline:SetTexture(WHITE)
  B.dline:SetHeight(1); B.dline:SetWidth(300)
  B.dline:SetGradientAlpha("HORIZONTAL", VIOLET[1], VIOLET[2], VIOLET[3], 0.8, VIOLET[1], VIOLET[2], VIOLET[3], 0)
  B.dcd = Engraved(Font(ui.bossView, "GameFontNormalSmall", INK_SOFT, 11))
  B.dcd:SetJustifyH("RIGHT")
  B.dtext = Engraved(Font(ui.bossView, "GameFontNormalSmall", INK, 12))
  B.dtext:SetWidth(300); B.dtext:SetJustifyH("LEFT")
  B.dname:Hide(); B.dline:Hide(); B.dtext:Hide(); B.dcd:Hide(); B.dbg:Hide(); B.dbar:Hide()

  -- LOOT: each piece with a round brass button for the wishlist
  B.loot = Strip(ui.bossView, "Loot")
  -- marked with the game's own loot bag, as a vendor shows it in a conversation
  local bag = B.loot:CreateTexture(nil, "OVERLAY")
  bag:SetTexture("Interface\\GossipFrame\\VendorGossipIcon")
  bag:SetWidth(18); bag:SetHeight(18)
  bag:SetPoint("RIGHT", B.loot, "RIGHT", -22, 0)
  local function WishTip(dot)
    local on = Wish(dot.entry.class)[WishKey(dot.entry)]
    GameTooltip:SetOwner(dot, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT(on and "On your wishlist" or "Add to wishlist"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT(on and "Click to take it off again." or "It then shows in your wishlist window and is ticked once collected."), 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end
  for i = 1, 4 do
    local r = CreateFrame("Button", nil, ui.bossView)
    r:SetWidth(320); r:SetHeight(36)
    r:RegisterForClicks("RightButtonUp")
    local ib = SetIcon(r, 30)
    ib:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -3)
    r.icon = ib.icon
    local nm = Font(r, "GameFontNormal", nil, 14)
    nm:SetShadowColor(0.08, 0.03, 0, 1); nm:SetShadowOffset(1, -1)
    nm:SetPoint("TOPLEFT", ib, "TOPRIGHT", 10, 1)
    nm:SetWidth(216); nm:SetJustifyH("LEFT")
    local inf = Engraved(Font(r, "GameFontNormalSmall", INK_SOFT, 12))
    inf:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -2)
    -- the chance in its colour, then the rest in ink: three pieces on one line
    local ch = Font(r, "GameFontNormalSmall", nil, 12)
    ch:SetShadowOffset(1, -1)
    ch:SetPoint("LEFT", inf, "RIGHT", 4, 0)
    local tail = Engraved(Font(r, "GameFontNormalSmall", INK_SOFT, 12))
    tail:SetPoint("LEFT", ch, "RIGHT", 3, 0)
    tail:SetText(AzT("of a kill"))
    r.name, r.info, r.chance = nm, inf, ch
    local ck = r:CreateTexture(nil, "OVERLAY")
    ck:SetWidth(26); ck:SetHeight(26); ck:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    SetCheck(ck); ck:Hide()
    r.check = ck
    local dot = CreateFrame("Button", nil, r)
    dot:SetWidth(22); dot:SetHeight(22)
    dot:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    local dt = dot:CreateTexture(nil, "ARTWORK"); dt:SetAllPoints(dot); dt:SetTexture(MEDIA .. "dot_off.tga")
    dot.tex = dt
    local dg = dot:CreateTexture(nil, "HIGHLIGHT")
    dg:SetTexture(GLOW); dg:SetBlendMode("ADD"); dg:SetVertexColor(1, 0.8, 0.35)
    dg:SetPoint("TOPLEFT", dot, "TOPLEFT", -8, 8); dg:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", 8, -8)
    dot:SetScript("OnClick", function()
      local w, k = Wish(this.entry.class), WishKey(this.entry)
      if w[k] then w[k] = nil else w[k] = true end
      Refresh()
      RefreshTracker()
      WishTip(this)
    end)
    dot:SetScript("OnEnter", function() WishTip(this) end)
    dot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.dot = dot
    Highlight(r, 0.3, -2)
    -- right-click: collected by hand, for a drop the game did not report
    r:SetScript("OnClick", function()
      if arg1 == "RightButton" then
        ToggleMark(this.entry)
        Refresh()
        RefreshTracker()
        if GameTooltip.IsOwned and GameTooltip:IsOwned(this) then this:GetScript("OnEnter")() end
      end
    end)
    r:SetScript("OnEnter", function()
      local e = this.entry
      local it = e.item
      local c = RARITY_COLOR[e.rarity]
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzG(it.name), c[1], c[2], c[3])
      GameTooltip:AddLine(AzG(e.rarity) .. " " .. AzT(it.slot), 0.8, 0.8, 0.8)
      local src = (e.sources and table.getn(e.sources) > 0) and e.sources or { { boss = e.boss, zone = e.zone } }
      for i = 1, table.getn(src) do
        GameTooltip:AddLine(AzT("Drops from %s (after %s), %s%% of a kill", AzG(src[i].boss.name), Minutes(src[i].boss.minute), src[i].zone.chance), 1, 0.82, 0, 1)
      end
      if table.getn(it.bonus) > 0 then GameTooltip:AddLine(" ") end
      for k = 1, table.getn(it.bonus) do GameTooltip:AddLine(AzG(it.bonus[k]), 0.3, 1, 0.45) end
      GameTooltip:AddLine(" ")
      if Collected(e.class)[it.name] then
        GameTooltip:AddLine(AzT("In your collection"), 0.3, 1, 0.45)
      else
        GameTooltip:AddLine(AzT("Not collected yet"), 0.6, 0.6, 0.6)
      end
      if e.class ~= PlayerClass() then
        GameTooltip:AddLine(AzT("Only a %s can wish for it.", AzG(ClassInfo(e.class).name)), 0.6, 0.6, 0.6, 1)
      else
        if Wish(e.class)[WishKey(e)] then GameTooltip:AddLine(AzT("On your wishlist"), 1, 0.82, 0) end
        GameTooltip:AddLine(AzT("The round button adds it to your wishlist. Right-click marks it collected by hand."), 0.6, 0.6, 0.6, 1)
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    B.items[i] = r
  end
  ui.bv = B
end

-- the chapter tabs on the book's right edge
local function BuildTabs()
  -- chapter tabs on the book's right edge
  ui.tabs = {}
  for i = 1, table.getn(MODULES) do
    local m = MODULES[i]
    -- a leather band whose flat end tucks under the book's cover, like a bookmark
    local t = CreateFrame("Button", nil, frame)
    t:SetFrameLevel(frame:GetFrameLevel())  -- below the book, so the cover overlaps it
    t:SetWidth(64); t:SetHeight(58)
    t:SetPoint("TOPLEFT", ui.book, "TOPRIGHT", -30, -70 - (i - 1) * 66)
    local glow = t:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "tabglow.tga"); glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 12); glow:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 14, -12)
    t.glow = glow
    local bg = t:CreateTexture(nil, "BORDER"); bg:SetAllPoints(t); bg:SetTexture(MEDIA .. "tab_band.tga")
    t.bg = bg
    -- the cover hides the first 11 px; the band ends at 61 px: the icon sits between
    local ic = t:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(38); ic:SetHeight(38)
    ic:SetPoint("CENTER", t, "LEFT", 32, 0)
    ic:SetTexture(m.icon)
    if string.find(m.icon, "Interface\\Icons\\", 1, true) then ic:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    t.icon = ic
    Highlight(t, 0.4, 4)
    t.key, t.label, t.tip = m.key, m.label, m.tip
    t.order = i
    t:SetScript("OnClick", function()
      local from = state.module
      local forward = true
      for k = 1, table.getn(ui.tabs) do
        if ui.tabs[k].key == from then forward = this.order > ui.tabs[k].order end
      end
      state.module = this.key
      state.lootBoss = nil
      if this.key == "Jewelry" then Go("Home") elseif this.key == "Spells" then WarmSpellDescs(); Go("Spells") else Refresh() end
      if from ~= this.key then PageTurn(forward) end
    end)
    t:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(AzT(this.label), 1, 0.82, 0)
      GameTooltip:AddLine(AzT(this.tip), 0.9, 0.9, 0.9)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.tabs[i] = t
  end
end

-- ---------- the title page: the book's first two pages ----------
-- Left, the title page: the emblem, the book's name, a few words about the hero and a saying
-- that changes every time the book is opened. Right, the contents: the three chapters, each
-- with its picture, a dotted line and its page, as in an old book.
local function BuildTitle(Strip)
  local CHAPTERS = {
    { key = "Jewelry", num = "Chapter I", name = "Jewelry", page = "3", icon = "tab_jewelry.tga",
      blurb = "Every ring, trinket and amulet, and the class amulets that remake a spell." },
    { key = "Loot", num = "Chapter II", name = "Loot", page = "17", icon = "tab_loot.tga",
      blurb = "Every zone and boss: how they fight, and what each class can take from them." },
    { key = "Spells", num = "Chapter III", name = "Spells", page = "31", icon = "tab_spells.tga",
      blurb = "Every class's spells, what they do, and the amulet that remakes each one." },
    { key = "Builds", num = "Chapter IV", name = "Builds", page = "45", icon = "tab_builds.tga",
      blurb = "Up to five builds for your class, ready for any run." },
    { key = "Chronicle", num = "Chapter V", name = "Chronicle", page = "59", icon = "tab_chronicle.tga",
      blurb = "Every run you finish, with your best run and records kept for good." },
  }
  
  local function OpenChapter(key)
    state.lootBoss = nil
    state.module = key
    if key == "Jewelry" then Go("Home")
    elseif key == "Spells" then WarmSpellDescs(); Go("Spells")
    else Refresh() end
    PageTurn(true)
  end
  local T = {}
  ui.titlePane = CreateFrame("Frame", nil, frame)
  OnPage(ui.titlePane)
  ui.titlePane:SetAllPoints(frame)
  local P = ui.titlePane
  -- LEFT: the title page
  local em = P:CreateTexture(nil, "ARTWORK")
  em:SetTexture(MEDIA .. "emblem_book.tga")
  em:SetWidth(104); em:SetHeight(104)
  em:SetPoint("TOP", ui.left, "TOP", 0, -4)
  DropShadow(P, em, 3, -5, 10, 0.6, "shadow.tga")
  local name = Engraved(Heading(Font(P, "GameFontNormalLarge", INK), 32))
  name:SetPoint("TOP", em, "BOTTOM", 0, -6)
  name:SetText("Azerloot")
  -- a warm light breathes behind the whole word, and a glowing contour traces every letter
  local nglow = P:CreateTexture(nil, "BORDER")
  nglow:SetTexture(GLOW); nglow:SetBlendMode("ADD"); nglow:SetVertexColor(1, 0.62, 0.18)
  nglow:SetPoint("TOPLEFT", name, "TOPLEFT", -34, 16)
  nglow:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 34, -16)
  local rim = {}
  for i = 1, 16 do
    local ang, r = (i - 1) * math.pi / 8, (math.floor(i / 2) * 2 == i) and 2.5 or 1.5
    local f = P:CreateFontString(nil, "BORDER")
    f:SetPoint("CENTER", name, "CENTER", math.cos(ang) * r, math.sin(ang) * r)
    f:SetTextColor(1, 0.66, 0.2)
    rim[i] = f
  end
  local pulse = CreateFrame("Frame", nil, P)
  pulse:SetScript("OnUpdate", function()
    local a = 0.5 + 0.5 * math.sin(GetTime() * 2.2)
    nglow:SetAlpha(0.35 + 0.35 * a)
    local face, size, flags = name:GetFont()
    for i = 1, 16 do
      local f = rim[i]
      if face and (f.face ~= face or f.size ~= size) then f:SetFont(face, size, flags); f.face, f.size = face, size; f:SetText("Azerloot") end
      f:SetAlpha((math.floor(i / 2) * 2 == i and 0.25 or 0.55) * (0.25 + 0.75 * a))
    end
  end)
  local sub = Engraved(Font(P, "GameFontNormal", INK_SOFT, 13))
  sub:SetPoint("TOP", name, "BOTTOM", 0, -4)
  sub:SetText(AzT("A Chronicle of Treasure, Bosses and Spells"))
  local div = Tex(P, "divider.tga", "ARTWORK")
  div:SetWidth(330); div:SetHeight(16)
  div:SetPoint("TOP", ui.left, "TOP", 0, -178)
  -- the hero: class icon and name, the collection, the amulets, the wishlist
  local ib = CreateFrame("Frame", nil, P)
  ib:SetWidth(40); ib:SetHeight(40)
  ib:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 40, -204)
  local sh = ib:CreateTexture(nil, "BACKGROUND")
  sh:SetTexture(MEDIA .. "shadow.tga"); sh:SetVertexColor(0.15, 0.08, 0.02); sh:SetAlpha(0.75)
  sh:SetPoint("TOPLEFT", ib, "TOPLEFT", -14, 10); sh:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", 18, -20)
  T.frame = ib:CreateTexture(nil, "BORDER"); T.frame:SetAllPoints(ib); T.frame:SetTexture(WHITE)
  T.icon = ib:CreateTexture(nil, "ARTWORK")
  T.icon:SetPoint("TOPLEFT", ib, "TOPLEFT", 2, -2); T.icon:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", -2, 2)
  T.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  T.hero = Engraved(Heading(Font(P, "GameFontNormal", INK), 20))
  T.hero:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, 1)
  T.heroSub = Engraved(Font(P, "GameFontNormalSmall", INK_SOFT, 12))
  T.heroSub:SetPoint("TOPLEFT", T.hero, "BOTTOMLEFT", 0, -3)
  T.heroSub:SetText(AzT("Boss loot in your collection."))
  -- the hero's line leads to the class's collection book
  local hb = CreateFrame("Button", nil, P)
  hb:SetPoint("TOPLEFT", ib, "TOPLEFT", -4, 4)
  hb:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", 230, -4)
  -- hovering lights the line with the warm glow of the chapters on the right
  local hg = hb:CreateTexture(nil, "BACKGROUND")
  hg:SetTexture(GLOW); hg:SetBlendMode("ADD"); hg:SetVertexColor(1, 0.75, 0.3)
  hg:SetAllPoints(hb); hg:SetAlpha(0.45); hg:Hide()
  hb:SetScript("OnClick", function()
    hg:Hide()
    state.module = "Loot"; state.class = PlayerClass()
    state.selected = nil; state.lootBoss = nil; state.offset = 0
    state.lootBook = true
    Refresh()
    PageTurn(true)
  end)
  hb:SetScript("OnEnter", function() hg:Show() end)
  hb:SetScript("OnLeave", function() hg:Hide() end)
  T.bar = ProgressBar(P, 210, 10)
  T.bar:SetPoint("TOPLEFT", ib, "BOTTOMLEFT", 2, -14)
  T.count = Engraved(Font(P, "GameFontNormal", INK_SOFT, 13))
  T.count:SetPoint("LEFT", T.bar, "RIGHT", 8, 0)
  T.lines = {}
  for i = 1, 3 do
    local l = Engraved(Font(P, "GameFontNormal", INK, 13))
    l:SetPoint("TOPLEFT", ib, "BOTTOMLEFT", 2, -34 - (i - 1) * 20)
    T.lines[i] = l
  end
  -- a saying, new each time the book is opened
  T.quote = Engraved(Font(P, "GameFontNormal", INK, 15))
  T.quote:SetPoint("BOTTOM", ui.left, "BOTTOM", 0, 52)
  T.quote:SetWidth(300); T.quote:SetJustifyH("CENTER")
  T.who = Engraved(Font(P, "GameFontNormalSmall", INK_SOFT, 12))
  -- as wide as the saying and centred in the same way, so the name stands right under its middle
  T.who:SetPoint("TOP", T.quote, "BOTTOM", 0, -5)
  T.who:SetWidth(300); T.who:SetJustifyH("CENTER")

  -- RIGHT: the contents
  local hc = Strip(P, "Contents")
  hc:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, -12)
  local bk = hc:CreateTexture(nil, "OVERLAY")
  bk:SetTexture("Interface\\GossipFrame\\PetitionGossipIcon"); bk:SetWidth(16); bk:SetHeight(16)
  bk:SetPoint("RIGHT", hc, "RIGHT", -20, 0)
  T.chapters = {}
  for i = 1, table.getn(CHAPTERS) do
    local c = CHAPTERS[i]
    local b = CreateFrame("Button", nil, P)
    b:SetWidth(330); b:SetHeight(70)
    b:SetPoint("TOP", ui.right, "TOP", 0, -46 - (i - 1) * 72)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(GLOW); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.75, 0.3)
    glow:SetAllPoints(b); glow:SetAlpha(0.45); glow:Hide()
    b.glow = glow
    local ic = b:CreateTexture(nil, "ARTWORK")
    local own = not string.find(c.icon, "\\", 1, true)
    ic:SetTexture(own and (MEDIA .. c.icon) or c.icon)
    if own then ic:SetWidth(50); ic:SetHeight(50)
    else ic:SetWidth(38); ic:SetHeight(38); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    ic:SetPoint("CENTER", b, "LEFT", 37, 2)
    DropShadow(b, ic, 3, -4, 6, 0.5, "shadow.tga")
    local num = Engraved(Font(b, "GameFontNormalSmall", INK_SOFT, 11))
    num:SetPoint("TOPLEFT", b, "TOPLEFT", 78, -5)
    num:SetText(string.upper(AzT(c.num)))
    local nm = Engraved(Heading(Font(b, "GameFontNormal", INK), 19))
    nm:SetPoint("TOPLEFT", num, "BOTTOMLEFT", 0, -2)
    nm:SetText(AzT(c.name))
    local pg = Engraved(Heading(Font(b, "GameFontNormal", INK), 16))
    pg:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -22)   -- level with the chapter's name
    pg:SetText(c.page)
    b.page = pg
    -- the dotted line from the name to its page
    local dots = b:CreateTexture(nil, "ARTWORK")
    dots:SetTexture(MEDIA .. "dots.tga"); dots:SetHeight(4)
    dots:SetPoint("BOTTOMLEFT", nm, "BOTTOMRIGHT", 8, 4)
    dots:SetPoint("BOTTOMRIGHT", pg, "BOTTOMLEFT", -6, 4)
    b.dots = dots
    -- five chapters share the page: the words keep to two lines
    local bl = Engraved(Font(b, "GameFontNormalSmall", INK_SOFT, 11))
    bl:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3)
    bl:SetWidth(246); bl:SetHeight(28); bl:SetJustifyH("LEFT"); bl:SetJustifyV("TOP")
    bl:SetText(AzT(c.blurb))
    b.key, b.name = c.key, nm
    b:SetScript("OnEnter", function() this.glow:Show(); this.name:SetTextColor(0.55, 0.2, 0.02) end)
    b:SetScript("OnLeave", function() this.glow:Hide(); this.name:SetTextColor(INK[1], INK[2], INK[3]) end)
    b:SetScript("OnClick", function() this.glow:Hide(); OpenChapter(this.key) end)
    T.chapters[i] = b
  end
  local foot = Engraved(Font(P, "GameFontNormalSmall", INK_SOFT, 12))
  foot:SetPoint("BOTTOM", ui.right, "BOTTOM", 0, 12)
  foot:SetWidth(320)
  foot:SetText(AzT("Choose a chapter, or use the tabs at the book's edge."))
  ui.tp = T
  P:Hide()
end

-- The book's size from the settings: 85% to 125% of its own. The book keeps its middle
-- where it was on the screen.
function Azerloot_SetBookSize(v)
  v = tonumber(v) or 1
  if v < 0.85 then v = 0.85 elseif v > 1.25 then v = 1.25 end
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  AzerlootDB.bookSize = v
  if not frame then return end
  local old, new = frame:GetScale() or BOOK_SCALE, BOOK_SCALE * v
  if math.abs(old - new) < 0.001 then return end
  local x, y = frame:GetCenter()
  frame:SetScale(new)
  if x and y then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * old / new, y * old / new)
  end
end

-- Lua 5.0 lets a function reach at most 32 locals of the file around it: the book's builder
-- takes its helpers and constants from this one table and keeps them as its own locals.
local BX = {
  D = D, LD = LD, BOOK_SCALE = BOOK_SCALE, MEDIA = MEDIA, RIBBON = RIBBON, GLOW = GLOW,
  RARITY_COLOR = RARITY_COLOR, WOOD_RARITY = WOOD_RARITY, INK = INK, INK_GOOD = INK_GOOD, INK_SOFT = INK_SOFT, FONT = FONT,
  QUEST_NO = QUEST_NO, SetCheck = SetCheck, WHITE = WHITE, PAGE_BTN = PAGE_BTN, CLASS_ICON = CLASS_ICON, CATS = CATS,
  ROWS = ROWS, ROW_H = ROW_H, state = state, ui = ui, Print = Print, Hex = Hex,
  PlayerClass = PlayerClass, ClassInfo = ClassInfo, Wish = Wish, WishKey = WishKey, ChanceColor = ChanceColor, Collected = Collected,
  Go = Go, OpenSearchHit = OpenSearchHit, Tex = Tex, PickBodyFont = PickBodyFont, SetFace = SetFace, Font = Font,
  Heading = Heading, Engraved = Engraved, Carved = Carved, Highlight = Highlight, DropShadow = DropShadow, SetIcon = SetIcon,
  FlipStep = FlipStep, FadeIn = FadeIn, StopAnimations = StopAnimations, ProgressBar = ProgressBar, BuildSettings = BuildSettings, BuildHomeCollection = BuildHomeCollection,
  BuildBossView = BuildBossView, BuildTabs = BuildTabs, BuildTitle = BuildTitle,
}
local function Build()
  local D, LD, BOOK_SCALE, MEDIA, RIBBON, GLOW, RARITY_COLOR, WOOD_RARITY = BX.D, BX.LD, BX.BOOK_SCALE, BX.MEDIA, BX.RIBBON, BX.GLOW, BX.RARITY_COLOR, BX.WOOD_RARITY
  local INK, INK_GOOD, INK_SOFT, FONT, QUEST_NO, SetCheck, WHITE, PAGE_BTN = BX.INK, BX.INK_GOOD, BX.INK_SOFT, BX.FONT, BX.QUEST_NO, BX.SetCheck, BX.WHITE, BX.PAGE_BTN
  local CLASS_ICON, CATS, ROWS, ROW_H, state, ui, Print, Hex = BX.CLASS_ICON, BX.CATS, BX.ROWS, BX.ROW_H, BX.state, BX.ui, BX.Print, BX.Hex
  local PlayerClass, ClassInfo, Wish, WishKey, ChanceColor, Collected, Go, OpenSearchHit = BX.PlayerClass, BX.ClassInfo, BX.Wish, BX.WishKey, BX.ChanceColor, BX.Collected, BX.Go, BX.OpenSearchHit
  local Tex, PickBodyFont, SetFace, Font, Heading, Engraved, Carved, Highlight = BX.Tex, BX.PickBodyFont, BX.SetFace, BX.Font, BX.Heading, BX.Engraved, BX.Carved, BX.Highlight
  local DropShadow, SetIcon, FlipStep, FadeIn, StopAnimations, ProgressBar, BuildSettings, BuildHomeCollection = BX.DropShadow, BX.SetIcon, BX.FlipStep, BX.FadeIn, BX.StopAnimations, BX.ProgressBar, BX.BuildSettings, BX.BuildHomeCollection
  local BuildBossView, BuildTabs, BuildTitle = BX.BuildBossView, BX.BuildTabs, BX.BuildTitle
  frame = CreateFrame("Frame", "AzerlootFrame", UIParent)
  frame:SetWidth(880); frame:SetHeight(586)
  local size = (type(AzerlootDB) == "table" and tonumber(AzerlootDB.bookSize)) or 1
  if size < 0.85 or size > 1.25 then size = 1 end
  frame:SetScale(BOOK_SCALE * size)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30 / (BOOK_SCALE * size))
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame:Hide()
  table.insert(UISpecialFrames, "AzerlootFrame") -- Escape closes it
  PickBodyFont(frame)

  ui.book = CreateFrame("Frame", nil, frame)
  ui.book:SetWidth(880); ui.book:SetHeight(560)
  ui.book:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -26)
  local book = Tex(ui.book, "book.tga", "BACKGROUND")
  book:SetAllPoints(ui.book)

  -- the two parchment pages run from seam to seam; ui.left / ui.right are the
  -- writing areas on them, below a header line
  -- each page reaches out to the stitching; the writing area keeps its old place
  local function Page(point, x, mirror, ax)
    local pg = CreateFrame("Frame", nil, ui.book)
    pg:SetWidth(385); pg:SetHeight(504)
    pg:SetPoint(point, ui.book, point, x, -28)
    -- two different sheets, so the open book does not show the same page twice
    local t = Tex(pg, mirror and "page_r.tga" or "page.tga", "BORDER"); t:SetAllPoints(pg)
    local area = CreateFrame("Frame", nil, pg)
    area:SetWidth(374); area:SetHeight(444)
    area:SetPoint("TOPLEFT", pg, "TOPLEFT", ax, -33)
    return pg, area
  end
  local pageL, pageR
  -- Everything written on the pages must sit above them: frames that share a level
  -- draw in no fixed order, which hid text and banners behind the parchment.
  OnPage = function(f) f:SetFrameLevel(ui.book:GetFrameLevel() + 6) end
  pageL, ui.left = Page("TOPLEFT", 28, false, 12)
  pageR, ui.right = Page("TOPRIGHT", -28, true, -1)
  ui.pageL, ui.pageR = pageL, pageR
  -- the brass corners of the cover, drawn again above the pages so they grip them
  local grip = CreateFrame("Frame", nil, ui.book)
  grip:SetAllPoints(ui.book)
  grip:SetFrameLevel(ui.book:GetFrameLevel() + 3)
  local corners = Tex(grip, "corners.tga", "ARTWORK"); corners:SetAllPoints(grip)

  -- navigation bar above the book: emblem, path, search, close
  -- drawn in three parts so the end caps keep their shape at any width
  local bar = CreateFrame("Frame", nil, frame) -- holds no art, only marks the bar's place
  -- its lower edge tucks under the book's cover, so the bar is fixed to the book
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -6)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -6)
  bar:SetHeight(40)
  local CAP = 28
  local bl = Tex(frame, "navbar.tga", "BACKGROUND")
  bl:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); bl:SetWidth(CAP); bl:SetHeight(40)
  bl:SetTexCoord(0, 0.085, 0, 1)
  local br = Tex(frame, "navbar.tga", "BACKGROUND")
  br:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0); br:SetWidth(CAP); br:SetHeight(40)
  br:SetTexCoord(0.915, 1, 0, 1)
  local bm = Tex(frame, "navbar.tga", "BACKGROUND")
  bm:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0); bm:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
  bm:SetTexCoord(0.085, 0.915, 0, 1)
  -- the emblem sits above the book's own frame so its lower edge is not covered
  local ef = CreateFrame("Frame", nil, frame)
  ef:SetFrameLevel(frame:GetFrameLevel() + 12)
  ef:SetWidth(74); ef:SetHeight(74)
  ef:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 12)
  local emblem = Tex(ef, "emblem_book.tga", "OVERLAY")
  emblem:SetAllPoints(ef)
  local title = Heading(Carved(Font(frame, "GameFontNormalLarge", { 1, 0.82, 0 })), 20)
  title:SetPoint("LEFT", bar, "LEFT", 50, 2)
  title:SetText("Azerloot")
  ui.title = title
  -- the title glows softly and slowly breathes; a click leads home to the jewelry start page
  local tglow = frame:CreateTexture(nil, "BORDER")
  tglow:SetTexture(GLOW); tglow:SetBlendMode("ADD"); tglow:SetVertexColor(1, 0.72, 0.15)
  tglow:SetPoint("TOPLEFT", title, "TOPLEFT", -18, 11)
  tglow:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 18, -11)
  local home = CreateFrame("Button", nil, frame)
  home:SetPoint("TOPLEFT", title, "TOPLEFT", -4, 4)
  home:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 4, -4)
  home:SetScript("OnUpdate", function()
    local a = 0.45 + 0.15 * math.sin(GetTime() * 2)
    if this.over then a = math.min(1, a + 0.3) end
    tglow:SetAlpha(a)
  end)
  home:SetScript("OnClick", function()
    local from = state.module
    state.module = "Title"
    state.lootBoss = nil
    state.search = ""
    if ui.search then ui.search:SetText(""); ui.search:ClearFocus() end
    Refresh()
    if from ~= "Title" then PageTurn(false) end
  end)
  home:SetScript("OnEnter", function()
    this.over = true
    title:SetTextColor(1, 0.9, 0.45)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("Azerloot", 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Back to the title page."), 0.9, 0.9, 0.9)
    GameTooltip:Show()
  end)
  home:SetScript("OnLeave", function()
    this.over = false
    title:SetTextColor(1, 0.82, 0)
    GameTooltip:Hide()
  end)
  home.over = false
  ui.home = home
  ui.crumbs = {}
  local prev = title
  for i = 1, 4 do
    local b = CreateFrame("Button", nil, frame)
    OnPage(b)
    b:SetHeight(24)
    local arrow = Engraved(Font(b, "GameFontNormal", { 0.85, 0.65, 0.2 }))
    SetFace(arrow, "body", FONT, 14)
    arrow:SetShadowColor(0, 0, 0, 0.8)
    arrow:SetPoint("LEFT", b, "LEFT", 0, -2)
    arrow:SetText(">")
    -- dark letters on the red leather, with a soft light edge so they read as stamped
    local t = Carved(Font(b, "GameFontHighlight", { 0.95, 0.92, 0.85 }))
    SetFace(t, "body", FONT, 14)
    t:SetPoint("LEFT", b, "LEFT", 14, 0)
    b.text = t
    -- on hover: a warm golden glow behind the word, in the colour of the title
    local g = b:CreateTexture(nil, "BACKGROUND")
    g:SetTexture(GLOW); g:SetBlendMode("ADD"); g:SetVertexColor(1, 0.72, 0.15)
    g:SetPoint("TOPLEFT", t, "TOPLEFT", -14, 9); g:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 14, -9)
    g:Hide()
    b.glow = g
    b.SetLabel = function(self, s) self.text:SetText(s); self:SetWidth(self.text:GetStringWidth() + 14) end
    b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    b.index = i
    b:SetScript("OnClick", function()
      if this.index == 1 then
        if state.module == "Jewelry" then Go("Home") else state.offset = 0; state.lootBoss = nil; Refresh() end
      elseif state.module == "Loot" then
        -- the class opens its collection book; the zone goes back to its bosses
        if this.index == 2 then state.lootBook = true; state.lootBoss = nil; Refresh()
        elseif this.index == 3 and not state.lootBook then state.lootBoss = nil; Refresh() end
      elseif this.index == 2 and state.search == "" then Go(state.view) end
    end)
    b:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.86, 0.35); this.glow:Show() end)
    b:SetScript("OnLeave", function() this.text:SetTextColor(0.95, 0.92, 0.85); this.glow:Hide() end)
    ui.crumbs[i] = b
    prev = b
  end

  local search = CreateFrame("EditBox", "AzerlootSearch", frame, "InputBoxTemplate")
  OnPage(search)
  search:SetWidth(190); search:SetHeight(22)
  search:SetPoint("RIGHT", bar, "RIGHT", -89, 0)   -- (room for the two medallions, clear of the gold end)
  search:SetAutoFocus(false)
  -- its own look: a slot sunk into the band with a fine gold rim, a gold magnifier at its
  -- start, and the word "Search" inside it while it is empty (the template's box hidden)
  for _, part in ipairs({ "Left", "Middle", "Right" }) do
    local t = getglobal("AzerlootSearch" .. part)
    if t and t.Hide then t:Hide() end
  end
  do
    local CAP = 15   -- (the ends keep the picture's round shape)
    local l = Tex(search, "search_box.tga", "BACKGROUND"); l:SetWidth(CAP); l:SetHeight(22)
    l:SetPoint("LEFT", search, "LEFT", 0, 0); l:SetTexCoord(0, 22 / 256, 0, 1)
    local r = Tex(search, "search_box.tga", "BACKGROUND"); r:SetWidth(CAP); r:SetHeight(22)
    r:SetPoint("RIGHT", search, "RIGHT", 0, 0); r:SetTexCoord(1 - 22 / 256, 1, 0, 1)
    local m = Tex(search, "search_box.tga", "BACKGROUND"); m:SetHeight(22)
    m:SetPoint("LEFT", l, "RIGHT", 0, 0); m:SetPoint("RIGHT", r, "LEFT", 0, 0); m:SetTexCoord(22 / 256, 1 - 22 / 256, 0, 1)
    local g = Tex(search, "search_glass.tga", "ARTWORK"); g:SetWidth(14); g:SetHeight(14)
    g:SetPoint("LEFT", search, "LEFT", 7, 0)
    search.glass = g
  end
  if search.SetTextInsets then search:SetTextInsets(25, 10, 0, 0) end
  search:SetScript("OnTextChanged", function()
    local s = this:GetText() or ""
    if this.HintLook then this.HintLook() end
    if s == state.search then return end -- SetText from the addon itself
    state.search = s
    if s ~= "" then
      if state.module == "Spells" then state.view = "Home" end
      state.module = "Jewelry"
    end
    state.offset = 0
    state.selected = nil
    Refresh()
  end)
  search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  ui.search = search
  local hint = Font(search, "GameFontNormalSmall", { 0.62, 0.55, 0.45 })
  SetFace(hint, "body", FONT, 12)
  hint:SetPoint("LEFT", search, "LEFT", 26, 0)
  hint:SetText(AzT("Search"))
  ui.searchHint = hint
  -- the word inside only while the box is empty and not being typed in
  local function HintLook()
    local empty = (search:GetText() or "") == ""
    if empty and not search.typing then hint:Show() else hint:Hide() end
    if search.glass then
      if search.typing then search.glass:SetVertexColor(1, 1, 0.8) else search.glass:SetVertexColor(1, 1, 1) end
    end
  end
  search.typing = false
  search:SetScript("OnEditFocusGained", function() this.typing = true; HintLook() end)
  search:SetScript("OnEditFocusLost", function() this.typing = false; HintLook() end)
  -- a click anywhere else lets go of the box: the cursor goes, and an empty box says "Search"
  -- again. (The game has no way to ask for the mouse buttons, so the places that can be
  -- clicked tell it: the book itself, its bar and pages, and the world around it.)
  local function LetGo() if search.typing then search:ClearFocus() end end
  frame:SetScript("OnMouseDown", LetGo)
  if WorldFrame and WorldFrame.GetScript and WorldFrame.SetScript then
    local before = WorldFrame:GetScript("OnMouseDown")
    WorldFrame:SetScript("OnMouseDown", function()
      LetGo()
      if before then before() end
    end)
  end
  AzlSearchLetGo = LetGo   -- (for other parts of the book that catch clicks)
  search.HintLook = HintLook
  -- closing: a gold cross in the gear's own style beside it, lit the same way under the mouse
  local close = CreateFrame("Button", nil, frame)
  OnPage(close)
  close:SetWidth(19); close:SetHeight(19)
  close:SetPoint("LEFT", search, "RIGHT", 36, 0)
  do
    local ct = Tex(close, "close.tga", "ARTWORK"); ct:SetAllPoints(close)
    local cd = Tex(close, "btn_disc.tga", "BORDER"); cd:SetWidth(24); cd:SetHeight(24); cd:SetPoint("CENTER", close, "CENTER", 0, 0); cd:Hide()
    local cg = close:CreateTexture(nil, "BACKGROUND")
    cg:SetTexture(GLOW); cg:SetBlendMode("ADD"); cg:SetVertexColor(1, 0.72, 0.15)
    cg:SetPoint("TOPLEFT", close, "TOPLEFT", -14, 12); cg:SetPoint("BOTTOMRIGHT", close, "BOTTOMRIGHT", 14, -12)
    cg:Hide()
    close:SetScript("OnEnter", function() cg:Show(); cd:Show(); ct:SetVertexColor(1, 1, 0.8) end)
    close:SetScript("OnLeave", function() cg:Hide(); cd:Hide(); ct:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnMouseDown", function() ct:SetPoint("TOPLEFT", close, "TOPLEFT", 1, -1); ct:SetPoint("BOTTOMRIGHT", close, "BOTTOMRIGHT", 1, -1) end)
    close:SetScript("OnMouseUp", function() ct:ClearAllPoints(); ct:SetAllPoints(close) end)
    close:SetScript("OnClick", function() cg:Hide(); cd:Hide(); frame:Hide() end)
  end
  ui.close = close

  BuildSettings(search)

  -- HOME: the four kinds of jewelry as illustrated strips down the left page
  ui.homePane = CreateFrame("Frame", nil, frame)
  OnPage(ui.homePane)
  ui.homePane:SetAllPoints(frame)
  for i = 1, table.getn(CATS) do
    local c = CATS[i]
    local b = CreateFrame("Button", nil, ui.homePane)
    b:SetWidth(340); b:SetHeight(74)
    b:SetPoint("TOP", ui.left, "TOP", 0, -48 - (i - 1) * 92)
    -- the middle band of each picture, with soft edges of its own
    local art = Tex(b, c.tile .. "_c.tga", "BORDER"); art:SetAllPoints(b)
    -- a dark veil behind the words, only on the picture and never on the page around it
    local veil = Tex(b, "veil_c.tga", "ARTWORK"); veil:SetAllPoints(b)
    local name = Heading(Carved(Font(b, "GameFontNormalLarge")), 18)
    name:SetPoint("TOPLEFT", b, "TOPLEFT", 22, -9)
    name:SetText(AzT(c.label))
    local blurb = Carved(Font(b, "GameFontHighlightSmall", { 1, 0.97, 0.9 }, 12))
    blurb:SetShadowColor(0, 0, 0, 1); blurb:SetShadowOffset(1, -1)
    blurb:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    blurb:SetText(AzT(c.blurb))
    -- hovering lights the picture with the warm glow of the banners on the other pages
    local glow = b:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(GLOW); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0.35)
    glow:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 4); glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -4)
    glow:SetAlpha(0.55); glow:Hide()
    b.glow = glow
    b:SetScript("OnEnter", function() this.glow:Show() end)
    b:SetScript("OnLeave", function() this.glow:Hide() end)
    b.key = c.key
    b:SetScript("OnClick", function() this.glow:Hide(); Go(this.key) end)
  end

  -- LIST: banners on the left page
  ui.listPane = CreateFrame("Frame", nil, frame)
  OnPage(ui.listPane)
  ui.listPane:SetAllPoints(frame)
  ui.leftTitle = Engraved(Heading(Font(ui.listPane, "GameFontNormalLarge", INK), 21))
  ui.leftTitle:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 28, -8)
  -- in Loot: the class's collection book, at the right end of the heading's line
  -- a small wooden button, like the one that clears the wishlist
  local bl = CreateFrame("Button", nil, ui.listPane)
  bl:SetHeight(24)
  bl:SetPoint("TOPRIGHT", ui.left, "TOPRIGHT", -29, -6)
  DropShadow(bl, bl, 2, -3, 3, 0.6)
  local blb = Tex(bl, "button.tga", "BORDER"); blb:SetAllPoints(bl)
  local blt = Carved(Font(bl, "GameFontNormal", { 0.95, 0.9, 0.78 }, 11))
  blt:SetShadowColor(0, 0, 0, 1)
  blt:SetPoint("CENTER", bl, "CENTER", 9, 0); blt:SetText(AzT("Collection Book"))
  local bli = bl:CreateTexture(nil, "ARTWORK")
  bli:SetTexture("Interface\\GossipFrame\\TabardGossipIcon"); bli:SetWidth(14); bli:SetHeight(14)
  bli:SetPoint("RIGHT", blt, "LEFT", -4, 0)
  bl:SetWidth((blt:GetStringWidth() or 90) + 14 + 4 + 28)
  Highlight(bl, 0.2, 3)
  bl:SetScript("OnClick", function()
    state.lootBook = true; state.lootBoss = nil
    Refresh()
    FadeIn(ui.bookView)
  end)
  bl:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(AzT("Collection Book"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Every piece of this class at a glance. Mark what you already own."), 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  bl:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bl:Hide()
  ui.bookLink = bl
  -- in the Wishlist: one button to clear it all; a second click within a few seconds confirms
  local cw = CreateFrame("Button", nil, ui.listPane)
  -- at the right end of the heading's line, where the Loot pages keep their Collection Book
  cw:SetHeight(24); cw:SetWidth(110)
  cw:SetPoint("TOPRIGHT", ui.left, "TOPRIGHT", -29, -6)
  DropShadow(cw, cw, 2, -3, 3, 0.6)
  local cwb = Tex(cw, "button.tga", "BORDER"); cwb:SetAllPoints(cw)
  local cwt = Carved(Font(cw, "GameFontNormal", { 0.95, 0.9, 0.78 }, 11))
  cwt:SetShadowColor(0, 0, 0, 1)
  cwt:SetPoint("CENTER", cw, "CENTER", 0, 0)
  cw.text = cwt
  Highlight(cw, 0.2, 3)
  cw.Reset = function(self)
    self.armed = false
    self.text:SetText(AzT("Clear wishlist")); self.text:SetTextColor(0.95, 0.9, 0.78)
    self:SetWidth(self.text:GetStringWidth() + 28)
  end
  cw:SetScript("OnClick", function()
    if not this.armed then
      this.armed = 3
      this.text:SetText(AzT("Click again")); this.text:SetTextColor(1, 0.45, 0.35)
      this:SetWidth(this.text:GetStringWidth() + 28)
      return
    end
    local w = Wish()
    for k in pairs(w) do w[k] = nil end
    -- an empty wishlist is no build any more
    if AzlB and AzlB.All then AzlB.All(PlayerClass()).active = nil end
    this:Reset()
    state.selected = nil
    Refresh()
    RefreshTracker()
    Print(AzT("wishlist of your %s cleared", AzG(ClassInfo(PlayerClass()).name)))
  end)
  cw:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(AzT("Clear wishlist"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Removes every piece from your wishlist. Click twice within 3 seconds to confirm."), 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  cw:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cw:SetScript("OnUpdate", function()
    if not this.armed then return end
    this.armed = this.armed - arg1
    if this.armed <= 0 then this:Reset() end
  end)
  cw:Reset()
  cw:Hide()
  ui.clearWish = cw
  local ldiv = Tex(ui.listPane, "divider.tga", "ARTWORK")
  ldiv:SetWidth(330); ldiv:SetHeight(16)
  ldiv:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 22, -30)
  ui.classes = {}
  for i = 1, table.getn(D.classes) do
    local c = D.classes[i]
    local b = CreateFrame("Button", nil, ui.listPane)
    b:SetWidth(26); b:SetHeight(26)
    b:SetPoint("TOPLEFT", ui.left, "TOPLEFT", 28 + (i - 1) * 35, -50)
    local shadow = b:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(MEDIA .. "shadow.tga"); shadow:SetVertexColor(0.15, 0.08, 0.02)
    shadow:SetPoint("TOPLEFT", b, "TOPLEFT", -12, 9); shadow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 16, -17)
    shadow:SetAlpha(0.75)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "tabglow.tga"); glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", b, "TOPLEFT", -10, 10); glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 10, -10)
    b.glow = glow
    local fr = b:CreateTexture(nil, "BORDER"); fr:SetAllPoints(b)
    fr:SetTexture(WHITE)
    local r, g, bl = tonumber(string.sub(c.color, 1, 2), 16), tonumber(string.sub(c.color, 3, 4), 16), tonumber(string.sub(c.color, 5, 6), 16)
    fr:SetVertexColor(r / 255, g / 255, bl / 255)
    b.frame = fr
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2); t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    t:SetTexture("Interface\\Icons\\" .. (CLASS_ICON[c.key] or c.spells[1].icon))
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon = t
    -- the chosen class: a glowing frame in the class's own colour, with a few sparks
    local cr, cg, cb = r / 255, g / 255, bl / 255
    if cr + cg + cb > 2.7 then cr, cg, cb = 0.85, 0.85, 0.9 end   -- the priest's white, a touch of grey to show on paper
    local sel = b:CreateTexture(nil, "OVERLAY")
    sel:SetTexture(MEDIA .. "selglow.tga"); sel:SetVertexColor(cr, cg, cb)
    sel:SetWidth(56); sel:SetHeight(56); sel:SetPoint("CENTER", b, "CENTER", 0, 0)
    sel:Hide()
    b.sel = sel
    local sp = b:CreateTexture(nil, "OVERLAY")
    sp:SetTexture(MEDIA .. "selsparks.tga"); sp:SetVertexColor(cr, cg, cb)
    sp:SetWidth(56); sp:SetHeight(56); sp:SetPoint("CENTER", b, "CENTER", 0, 0)
    sp:Hide()
    b.sparks = sp
    Highlight(b, 0.5, -6)
    b.key = c.key
    b:SetScript("OnClick", function()
      state.class = this.key
      if state.module ~= "Loot" then state.offset = 0; state.selected = nil end
      Refresh()
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      local ci = ClassInfo(this.key)
      GameTooltip:AddLine("|cff" .. ci.color .. AzG(ci.name) .. "|r")
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.classes[i] = b
  end
  ui.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, ui.listPane)
    row:SetWidth(332); row:SetHeight(ROW_H - 4)
    row.shadow = DropShadow(row, row, 3, -5, 4, 0.75)
    local bg = Tex(row, "banner.tga", "BORDER"); bg:SetAllPoints(row)
    row.bg = bg
    local glow = row:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(GLOW); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0.35)
    glow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 4); glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -4)
    glow:Hide(); row.glow = glow
    -- a section heading on the wishlist page: the dark strip of the book's other headings,
    -- its title in the middle and its sign at the right end
    local hs = Tex(row, "strip.tga", "BORDER")
    hs:SetWidth(332); hs:SetHeight(26); hs:SetPoint("CENTER", row, "CENTER", 0, -2)
    hs:Hide(); row.headLine = hs
    local hsh = DropShadow(row, hs, 3, -4, 3, 0.7)   -- the strip's own shadow, as under Treasury
    hsh:Hide(); row.headShadow = hsh
    local ht = Heading(Carved(Font(row, "GameFontNormal")), 16)
    ht:SetPoint("CENTER", hs, "CENTER", 0, 0)
    ht:Hide(); row.headText = ht
    local hi = row:CreateTexture(nil, "OVERLAY")
    hi:SetWidth(18); hi:SetHeight(18); hi:SetPoint("RIGHT", hs, "RIGHT", -22, 0)
    hi:Hide(); row.headIcon = hi
    -- hovering lights the banner with the same warm glow as the selection, softer
    row:SetScript("OnEnter", function()
      if this.entry and this.entry.kind == "Header" then return end
      this.glow:Show(); this.glow:SetAlpha(0.55)
    end)
    row:SetScript("OnLeave", function()
      this.glow:SetAlpha(1)
      if not (state.selected and this.entry and state.selected.item == this.entry.item) then this.glow:Hide() end
    end)
    local ibox = SetIcon(row, 28, "OVERLAY")
    ibox:SetPoint("LEFT", row, "LEFT", 18, 0)
    row.ibox = ibox
    local icon = ibox.icon
    row.icon = icon
    local name = Carved(Font(row, "GameFontNormal", nil, 14))
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, 0)
    name:SetWidth(250); name:SetJustifyH("LEFT")
    row.name = name
    local sub = Carved(Font(row, "GameFontHighlightSmall", nil, 11))
    sub:SetTextColor(0.96, 0.9, 0.76)
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    sub:SetWidth(266); sub:SetJustifyH("LEFT")
    row.sub = sub
    -- wishlist seal pressed onto the banner's right end
    local star = row:CreateTexture(nil, "OVERLAY")
    star:SetWidth(24); star:SetHeight(24)
    star:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, 9)  -- hangs over the banner's top edge
    star:SetTexture(RIBBON)
    row.star = star
    -- a zone's collection: its count and a small bar at the right end of the name line
    local pb = ProgressBar(row, 52, 7)
    pb:SetPoint("TOPRIGHT", row, "TOPRIGHT", -24, -12)
    pb:Hide()
    row.bar = pb
    local pc = Carved(Font(row, "GameFontHighlightSmall", { 0.96, 0.9, 0.76 }, 11))
    pc:SetPoint("RIGHT", pb, "LEFT", -6, 0)
    pc:Hide()
    row.count = pc
    -- a discovered class amulet
    local rck = row:CreateTexture(nil, "OVERLAY")
    rck:SetWidth(24); rck:SetHeight(24); rck:SetPoint("RIGHT", row, "RIGHT", -52, 0)
    SetCheck(rck); rck:Hide()
    row.check = rck
    row:SetScript("OnClick", function()
      if this.entry.kind == "Header" then return end
      if this.entry.kind == "Page" or this.entry.kind == "ZoneHit" or this.entry.kind == "BossHit"
        or (this.entry.kind == "LootItem" and state.search ~= "") then
        OpenSearchHit(this.entry)
        return
      end
      state.selected = this.entry
      if this.entry.kind == "Zone" then state.lootZone = this.entry.index; state.lootBoss = nil; state.lootBook = nil end
      Refresh()
    end)
    ui.rows[i] = row
  end
  ui.listPane:EnableMouseWheel(true)
  local function Flip(dir)
    local rows = (state.module == "Loot" or state.module == "Spells" or ((state.view == "Legendary") and (state.search == ""))) and ROWS - 1 or ROWS
    local page = (state.page or 1) + dir
    if page < 1 or page > (state.pages or 1) then return end
    state.offset = (page - 1) * rows
    Refresh()
  end
  ui.listPane:SetScript("OnMouseWheel", function() Flip(arg1 > 0 and -1 or 1) end)
  ui.count = Font(ui.listPane, "GameFontNormal", INK, 14)
  ui.count:SetPoint("BOTTOM", ui.left, "BOTTOM", 0, 22)
  local function PageButton(kind, dir)
    local b = CreateFrame("Button", nil, ui.listPane)
    b:SetWidth(30); b:SetHeight(30)
    b:SetNormalTexture(PAGE_BTN .. kind .. "Page-Up")
    b:SetPushedTexture(PAGE_BTN .. kind .. "Page-Down")
    b:SetDisabledTexture(PAGE_BTN .. kind .. "Page-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b.dir = dir
    b:SetScript("OnClick", function() Flip(this.dir) end)
    return b
  end
  ui.prev = PageButton("Prev", -1)
  ui.prev:SetPoint("RIGHT", ui.count, "LEFT", -12, 0)
  ui.next = PageButton("Next", 1)
  ui.next:SetPoint("LEFT", ui.count, "RIGHT", 12, 0)
  -- a gentle pulse on the next-page arrow while more entries wait
  local hint = ui.listPane:CreateTexture(nil, "ARTWORK")
  hint:SetTexture(MEDIA .. "tabglow.tga"); hint:SetBlendMode("ADD")
  hint:SetWidth(54); hint:SetHeight(54)
  hint:SetPoint("CENTER", ui.next, "CENTER", 0, 0)
  ui.nextHint = hint
  ui.moreText = Font(ui.listPane, "GameFontNormalSmall", INK_SOFT, 11)
  ui.moreText:SetPoint("LEFT", ui.next, "RIGHT", 6, 0)
  ui.moreText:SetText(AzT("more"))
  local pulse = 0
  ui.listPane:SetScript("OnUpdate", function()
    pulse = pulse + arg1
    if ui.nextHint.on then ui.nextHint:SetAlpha(0.35 + 0.35 * math.sin(pulse * 3.5)) end
    -- the chosen class's frame breathes, its sparks twinkle a beat behind
    for i = 1, table.getn(ui.classes) do
      local b = ui.classes[i]
      if b.on then
        b.sel:SetAlpha(0.72 + 0.28 * math.sin(pulse * 2.6))
        local grow = 56 + 3 * math.sin(pulse * 2.6)
        b.sel:SetWidth(grow); b.sel:SetHeight(grow)
        b.sparks:SetAlpha(0.35 + 0.45 * (0.5 + 0.5 * math.sin(pulse * 1.7 + 1.3)))
      end
    end
  end)

  -- DETAIL: the right page
  ui.detailPane = CreateFrame("Frame", nil, frame)
  OnPage(ui.detailPane)
  ui.detailPane:SetAllPoints(frame)
  local d = { heads = {}, lines = {} }
  d.iconBox = SetIcon(ui.detailPane, 42)
  d.iconBox:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -26)
  d.icon = d.iconBox.icon
  local rdiv = Tex(d.iconBox, "divider.tga", "ARTWORK")
  rdiv:SetWidth(330); rdiv:SetHeight(16)
  rdiv:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -96)
  d.name = Engraved(Heading(Font(ui.detailPane, "GameFontNormalLarge", INK), 21))
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
  d.name:SetWidth(250); d.name:SetJustifyH("LEFT")
  d.sub = Engraved(Font(ui.detailPane, "GameFontNormalSmall", INK_SOFT, 12))
  d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
  d.sub:SetWidth(250); d.sub:SetJustifyH("LEFT")
  for i = 1, 4 do
    local h = CreateFrame("Button", nil, ui.detailPane)
    h:SetWidth(332); h:SetHeight(26)
    DropShadow(h, h, 3, -4, 3, 0.7)
    local bg = Tex(h, "strip.tga", "BORDER"); bg:SetAllPoints(h)
    local sign = Carved(Font(h, "GameFontNormal", nil, 14)); sign:SetPoint("LEFT", h, "LEFT", 22, 0)
    local t = Heading(Carved(Font(h, "GameFontNormal")), 16); t:SetPoint("LEFT", h, "LEFT", 38, 0)
    t:SetWidth(300); t:SetJustifyH("LEFT")
    h.sign, h.title = sign, t
    -- the game's "?" after a heading that explains itself on hovering
    local q = CreateFrame("Button", nil, h)
    q:SetWidth(16); q:SetHeight(16)
    local qt = q:CreateTexture(nil, "OVERLAY"); qt:SetAllPoints(q); qt:SetTexture(QUEST_NO)
    q:SetScript("OnEnter", function()
      if not this.tip then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.tip[1], 1, 0.82, 0)
      GameTooltip:AddLine(this.tip[2], 0.85, 0.85, 0.85, 1)
      GameTooltip:Show()
    end)
    q:SetScript("OnLeave", function() GameTooltip:Hide() end)
    q:Hide()
    h.help = q
    Highlight(h, 0.35)
    h:SetScript("OnClick", function()
      state.closed[this.secKey] = not state.closed[this.secKey]
      Refresh()
    end)
    h:Hide()
    d.heads[i] = h
  end
  for i = 1, 14 do
    local l = Engraved(Font(ui.detailPane, "GameFontNormal", INK_GOOD, 14))
    l:SetWidth(306); l:SetJustifyH("LEFT")
    l:Hide()
    d.lines[i] = l
  end
  -- one line of body text, to measure the height a single value line takes
  d.probe = Font(ui.detailPane, "GameFontNormal", nil, 14)
  d.probe:SetText("Ag"); d.probe:SetAlpha(0)  -- shown but invisible, so it is measured
  d.probe:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, 0)
  d.labels = {}
  for i = 1, 14 do
    local lb = Heading(Font(ui.detailPane, "GameFontNormal"), 14)  -- rarity names in the storybook face
    lb:SetShadowColor(0.08, 0.03, 0, 1); lb:SetShadowOffset(1, -1)
    lb:SetJustifyH("LEFT")
    lb:Hide()
    d.labels[i] = lb
  end
  d.empty = Font(ui.detailPane, "GameFontNormal", INK_SOFT, 14)
  d.empty:SetPoint("CENTER", ui.right, "CENTER", 0, 20)
  d.empty:SetWidth(300)
  local wish = CreateFrame("Button", nil, ui.detailPane)
  -- a small wooden button, centred at the foot of the right page
  wish:SetHeight(34); wish:SetWidth(180)
  wish:SetPoint("BOTTOM", ui.right, "BOTTOM", 0, 12)
  DropShadow(wish, wish, 2, -4, 4, 0.7)
  local wbg = Tex(wish, "button.tga", "BORDER"); wbg:SetAllPoints(wish)
  -- the wax seal is pressed onto the button's left end, half of it beyond the edge
  local wt = wish:CreateTexture(nil, "OVERLAY")
  wt:SetWidth(38); wt:SetHeight(38); wt:SetPoint("CENTER", wish, "LEFT", 2, 0)
  wt:SetTexture(RIBBON)
  DropShadow(wish, wt, 2, -3, 12, 0.7, "shadow.tga")
  wish.tex = wt
  -- label in the book's italic, ending in the game's own quest mark:
  -- "?" while not on the list, "!" once it is; label and mark centred together
  local wl = Carved(Font(wish, "GameFontNormal", nil, 14))
  wl:SetPoint("LEFT", wish, "LEFT", 28, 0)
  local mk = wish:CreateTexture(nil, "OVERLAY")
  mk:SetWidth(16); mk:SetHeight(16)
  mk:SetPoint("LEFT", wl, "RIGHT", 3, 0)
  wish.mark = mk
  wish.text = wl
  Highlight(wish, 0.2, 4)
  -- pressed: the label sinks a pixel
  wish:SetScript("OnMouseDown", function() this.text:SetPoint("LEFT", this, "LEFT", 29, -1) end)
  wish:SetScript("OnMouseUp", function() this.text:SetPoint("LEFT", this, "LEFT", 28, 0) end)
  wish:SetScript("OnClick", function()
    if not this.key or not this.entry then return end
    AzlB.OpenMenu(this, this.entry)
  end)
  wish:Hide()
  d.wish = wish
  -- a spell's class amulet: its icon and name; its effects on hovering
  local amu = CreateFrame("Button", nil, ui.detailPane)
  amu:SetWidth(300); amu:SetHeight(34)
  local abox = SetIcon(amu, 28)
  abox:SetPoint("LEFT", amu, "LEFT", 4, 0)
  amu.icon = abox.icon
  local an = Font(amu, "GameFontNormal", nil, 15)
  an:SetTextColor(1, 0.5, 0.02); an:SetShadowColor(0.22, 0.07, 0, 1); an:SetShadowOffset(1, -1)
  an:SetPoint("LEFT", abox, "RIGHT", 10, 0)
  amu.name = an
  Highlight(amu, 0.25, -2)
  amu:SetScript("OnEnter", function()
    local it = this.spell
    if not it then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzG(it.amulet), 1, 0.5, 0)
    GameTooltip:AddLine(AzT("Legendary amulet - remakes %s", AzG(it.name)), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    for e = 1, table.getn(it.effects) do GameTooltip:AddLine(AzG(it.effects[e]), 0.3, 1, 0.45, 1) end
    GameTooltip:Show()
  end)
  amu:SetScript("OnLeave", function() GameTooltip:Hide() end)
  amu:Hide()
  d.amulet = amu
  ui.detail = d

  -- LOOT: on the right page, the chosen zone's bosses; a boss opens its own page
  ui.lootPane = CreateFrame("Frame", nil, frame)
  OnPage(ui.lootPane)
  ui.lootPane:SetAllPoints(frame)

  -- a strip heading, as on the Jewelry pages, with a small note at its right end
  local function Strip(parent, title)
    local h = CreateFrame("Frame", nil, parent)
    h:SetWidth(332); h:SetHeight(26)
    DropShadow(h, h, 3, -4, 3, 0.7)
    local bg = Tex(h, "strip.tga", "BORDER"); bg:SetAllPoints(h)
    local t = Heading(Carved(Font(h, "GameFontNormal")), 16); t:SetPoint("CENTER", h, "CENTER", 0, 0)
    t:SetText(AzT(title))
    local note = Carved(Font(h, "GameFontHighlightSmall", { 0.9, 0.85, 0.75 }, 11)); note:SetPoint("RIGHT", h, "RIGHT", -22, 0)
    note:SetShadowColor(0, 0, 0, 1)
    h.title, h.note = t, note
    return h
  end

  -- the zone: header, then one wooden banner per boss, like the banners on the left
  ui.zoneView = CreateFrame("Frame", nil, ui.lootPane)
  ui.zoneView:SetAllPoints(frame)
  local Z = { bosses = {} }
  Z.name = Engraved(Heading(Font(ui.zoneView, "GameFontNormalLarge", INK), 21))
  Z.name:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -10)
  Z.sub = Engraved(Font(ui.zoneView, "GameFontNormalSmall", INK_SOFT, 12))
  Z.sub:SetPoint("TOPLEFT", Z.name, "BOTTOMLEFT", 0, -2)
  Z.info = Engraved(Font(ui.zoneView, "GameFontNormalSmall", INK, 12))
  Z.info:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -52)
  Z.info:SetWidth(322); Z.info:SetJustifyH("LEFT")
  local zdiv = Tex(ui.zoneView, "divider.tga", "ARTWORK")
  zdiv:SetWidth(330); zdiv:SetHeight(16)
  zdiv:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 22, -108)
  -- the zone's collection: "Collected:", a bar, the count; the class's whole count at the right
  local pl = Engraved(Font(ui.zoneView, "GameFontNormal", INK_SOFT, 13))
  pl:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 26, -88)
  pl:SetText(AzT("Collected:"))
  -- the bar after the name, the count after the bar: all three hang from the name's
  -- middle, so they share one line; the count a size smaller, its dark edge kept faint
  Z.bar = ProgressBar(ui.zoneView, 150, 10)
  Z.bar:SetPoint("LEFT", pl, "RIGHT", 8, 0)
  Z.count = Font(ui.zoneView, "GameFontNormal", INK_GOOD, 12)
  Z.count:SetShadowOffset(1, -1)
  Z.count:SetPoint("LEFT", pl, "RIGHT", 8 + 150 + 8, 1)
  for i = 1, 5 do
    local row = CreateFrame("Button", nil, ui.zoneView)
    row:SetWidth(332); row:SetHeight(ROW_H - 4)
    row:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, -128 - (i - 1) * ROW_H)
    DropShadow(row, row, 3, -5, 4, 0.75)
    local bg = Tex(row, "banner.tga", "BORDER"); bg:SetAllPoints(row)
    local glow = row:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(GLOW); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0.35)
    glow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 4); glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -4)
    glow:SetAlpha(0.55); glow:Hide()
    row:SetScript("OnEnter", function() this.glow:Show() end)
    row:SetScript("OnLeave", function() this.glow:Hide() end)
    row.glow = glow
    local ibox = SetIcon(row, 28, "OVERLAY")
    ibox:SetPoint("LEFT", row, "LEFT", 18, 0)
    row.icon = ibox.icon
    local name = Carved(Font(row, "GameFontNormal", nil, 14))
    name:SetPoint("TOPLEFT", ibox, "TOPRIGHT", 9, 0)
    name:SetWidth(230); name:SetJustifyH("LEFT")
    row.name = name
    local sub = Carved(Font(row, "GameFontHighlightSmall", nil, 11))
    sub:SetTextColor(0.96, 0.9, 0.76)
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    sub:SetWidth(236); sub:SetJustifyH("LEFT")
    row.sub = sub
    -- every piece of this boss collected: the green check
    local ck = row:CreateTexture(nil, "OVERLAY")
    ck:SetWidth(24); ck:SetHeight(24); ck:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    SetCheck(ck); ck:Hide()
    row.check = ck
    -- something of this boss on the wishlist: the wax seal, as on the left banners
    local star = row:CreateTexture(nil, "OVERLAY")
    star:SetWidth(24); star:SetHeight(24)
    star:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, 9)
    star:SetTexture(RIBBON); star:Hide()
    row.star = star
    row:SetScript("OnClick", function()
      state.lootBoss = this.index
      Refresh()
      FadeIn(ui.bossView)
    end)
    Z.bosses[i] = row
  end
  Z.note = Font(ui.zoneView, "GameFontNormal", INK_SOFT, 13)
  Z.note:SetPoint("BOTTOM", ui.right, "BOTTOM", 0, 34)
  Z.note:SetWidth(320)
  Z.note:SetText(AzT("Choose a boss to read how it fights and what it drops."))
  -- back to the class's collection book: the page arrow, as on a boss's page
  local zb = CreateFrame("Button", nil, ui.zoneView)
  zb:SetWidth(28); zb:SetHeight(28)
  zb:SetPoint("TOPRIGHT", ui.right, "TOPRIGHT", -10, -4)
  zb:SetNormalTexture(PAGE_BTN .. "PrevPage-Up")
  zb:SetPushedTexture(PAGE_BTN .. "PrevPage-Down")
  zb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  zb:SetScript("OnClick", function()
    state.lootBook = true; state.lootBoss = nil
    Refresh()
    FadeIn(ui.bookView)
  end)
  zb:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine(AzT("Back to the Collection Book"), 1, 0.82, 0)
    GameTooltip:Show()
  end)
  zb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Z.back = zb
  ui.zv = Z

  BuildHomeCollection(Strip)

  BuildBossView(Strip)
  ui.bossView:Hide()
  -- COLLECTION BOOK: every piece of a class in one grid, as the game's own collection
  -- shows it: a row for each rank of zones, a column for each slot. A click marks a piece.
  ui.bookView = CreateFrame("Frame", nil, ui.lootPane)
  ui.bookView:SetAllPoints(frame)
  local K = { rows = {} }
  local bs = Strip(ui.bookView, "Collection Book")
  bs:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 21, -12)
  local btab = bs:CreateTexture(nil, "OVERLAY")
  btab:SetTexture("Interface\\GossipFrame\\TabardGossipIcon")
  btab:SetWidth(18); btab:SetHeight(18)
  btab:SetPoint("RIGHT", bs, "RIGHT", -22, 0)
  K.hint = Font(ui.bookView, "GameFontNormalSmall", INK_SOFT, 12)
  K.hint:SetPoint("TOP", ui.right, "TOP", 0, -42)
  K.hint:SetWidth(330)
  K.hint:SetText(AzT("Click every piece the game's Collection shows you own."))
  K.hint:Show(); AzlFitText(K.hint, 326, 12, 10)   -- one line in every language, clear of the boxes
  -- six ranks as six cards in two columns, read like a book: common to uncommon, rare to
  -- epic, the PvP set to legendary. Each card: the rank's name in its colour over a fine
  -- line of that colour, its count at the right, and its pieces in two lines of five
  -- (head to legs, then feet, wrists, hands and the weapons).
  local CW, CH, GX, GY, TOP = 160, 91, 12, 6, -59
  K.cw, K.left = CW, 26
  for r = 1, table.getn(LD.ranks) do
    local cx = 26 + ((r - 1) - math.floor((r - 1) / 2) * 2) * (CW + GX)
    local cy = TOP - math.floor((r - 1) / 2) * (CH + GY)
    local card = CreateFrame("Frame", nil, ui.bookView)
    card:SetWidth(CW); card:SetHeight(CH)
    card:SetPoint("TOPLEFT", ui.right, "TOPLEFT", cx, cy)
    DropShadow(card, card, 2, -3, 3, 0.45)
    -- a board of the same dark wood as the book's banners
    local bg = Tex(card, "card.tga", "BORDER"); bg:SetAllPoints(card)
    local edges = {}
    for k = 1, 4 do
      local t = card:CreateTexture(nil, "ARTWORK"); t:SetTexture(WHITE)
      t:SetVertexColor(1, 0.75, 0.15); t:Hide()
      edges[k] = t
    end
    edges[1]:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0); edges[1]:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0); edges[2]:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0); edges[3]:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0); edges[4]:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0); edges[4]:SetWidth(1)
    local pc = WOOD_RARITY[LD.ranks[r]]
    local lab = Heading(Font(card, "GameFontNormal"), 13)
    lab:SetTextColor(pc[1], pc[2], pc[3]); lab:SetShadowColor(0, 0, 0, 1); lab:SetShadowOffset(1, -1)
    lab:SetPoint("TOPLEFT", card, "TOPLEFT", 7, -5)
    lab:SetText(AzG(LD.ranks[r]))
    local ul = card:CreateTexture(nil, "ARTWORK"); ul:SetTexture(WHITE); ul:SetHeight(1)
    ul:SetVertexColor(pc[1], pc[2], pc[3]); ul:SetAlpha(0.7)
    ul:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -21); ul:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -21)
    local cnt = Font(card, "GameFontNormalSmall", { 0.88, 0.8, 0.66 }, 11)
    cnt:SetShadowColor(0, 0, 0, 1); cnt:SetShadowOffset(1, -1)
    cnt:SetJustifyH("RIGHT")
    cnt:SetPoint("TOPRIGHT", card, "TOPRIGHT", -7, -7)
    -- a complete rank: its board framed in gold
    card.Complete = function(self, on)
      for k = 1, 4 do if on then edges[k]:Show() else edges[k]:Hide() end end
    end
    local row = { label = lab, count = cnt, cells = {}, y = cy, card = card }
    -- frames 25 wide, 29 apart: their rims never touch, and the outer ones (2 px of rim
    -- each) stay clear of the board's soft edge, 7 px in on either side
    local gx = math.floor((CW - (4 * 29 + 25)) / 2)
    for c = 1, 10 do
      local b = CreateFrame("Button", nil, card)
      b:SetWidth(25); b:SetHeight(25)
      b:SetPoint("TOPLEFT", card, "TOPLEFT", gx + ((c - 1) - math.floor((c - 1) / 5) * 5) * 29, -27 - math.floor((c - 1) / 5) * 31)
      local edge = b:CreateTexture(nil, "BORDER"); edge:SetTexture(WHITE)
      edge:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2); edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
      b.edge = edge
      local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetAllPoints(b); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      b.icon = ic
      local q = Font(b, "GameFontNormal", { 0.75, 0.68, 0.55 }, 14)
      q:SetPoint("CENTER", b, "CENTER", 1, 0); q:SetText("?")
      b.q = q
      -- on the wishlist: a small wax seal pressed onto the frame's upper right corner
      local seal = b:CreateTexture(nil, "OVERLAY")
      seal:SetWidth(15); seal:SetHeight(15)
      seal:SetPoint("CENTER", b, "TOPRIGHT", -1, -1)
      seal:SetTexture(RIBBON); seal:Hide()
      b.seal = seal
      Highlight(b, 0.4, -3)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b:SetScript("OnClick", function()
        local e = this.entry
        if arg1 == "RightButton" then
          -- right-click: on or off the wishlist, for the hero's own class
          local w, k = Wish(e.class), WishKey(e)
          if e.class ~= PlayerClass() then return end
          if w[k] then w[k] = nil
          elseif not Collected(e.class)[e.item.name] then w[k] = true
          else return end
          Refresh()
          RefreshTracker()
          this:GetScript("OnEnter")()
          return
        end
        local got = Collected(e.class)
        local n = e.item.name
        if got[n] then got[n] = nil else got[n] = true end
        Refresh()
        RefreshTracker()
        this:GetScript("OnEnter")()
      end)
      b:SetScript("OnEnter", function()
        local e = this.entry
        local cc = RARITY_COLOR[e.rarity]
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AzG(e.item.name), cc[1], cc[2], cc[3])
        GameTooltip:AddLine(AzG(e.rarity) .. " " .. AzT(e.item.slot), 0.8, 0.8, 0.8)
        local src = (e.sources and table.getn(e.sources) > 0) and e.sources or { { boss = e.boss, zone = e.zone } }
        for i = 1, table.getn(src) do
          -- the chance in brackets, in its colour from green (likely) to red (rare)
          GameTooltip:AddLine(AzT("Drops from %s in %s", AzG(src[i].boss.name), AzG(src[i].zone.name))
            .. " (" .. Hex(ChanceColor(src[i].zone.chance)[1]) .. src[i].zone.chance .. "%|r)", 1, 0.82, 0, 1)
        end
        GameTooltip:AddLine(" ")
        local have, on = Collected(e.class)[e.item.name], Wish(e.class)[WishKey(e)]
        if have then
          GameTooltip:AddLine(AzT("In your collection"), 0.3, 1, 0.45)
        else
          GameTooltip:AddLine(AzT("Not collected yet"), 0.6, 0.6, 0.6)
        end
        if on and e.class == PlayerClass() then GameTooltip:AddLine(AzT("On your wishlist"), 1, 0.82, 0) end
        GameTooltip:AddLine(AzT(have and "Click if you do not have it after all." or "Click to mark it as collected."), 0.6, 0.6, 0.6, 1)
        if e.class ~= PlayerClass() then
          GameTooltip:AddLine(AzT("Only a %s can wish for it.", AzG(ClassInfo(e.class).name)), 0.6, 0.6, 0.6, 1)
        elseif on then
          GameTooltip:AddLine(AzT("Right-click to take it off your wishlist."), 0.6, 0.6, 0.6, 1)
        elseif not have then
          GameTooltip:AddLine(AzT("Right-click to add it to your wishlist."), 0.6, 0.6, 0.6, 1)
        end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      b:Hide()
      row.cells[c] = b
    end
    K.rows[r] = row
  end
  local tl = Engraved(Font(ui.bookView, "GameFontNormal", INK_SOFT, 13))
  tl:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 30, -354)
  tl:SetText(AzT("Collected:"))
  K.bar = ProgressBar(ui.bookView, 170, 10)
  K.bar:SetPoint("LEFT", tl, "RIGHT", 8, 0)
  K.count = Font(ui.bookView, "GameFontNormal", INK_GOOD, 12)
  K.count:SetShadowOffset(1, -1); K.count:SetShadowColor(0.02, 0.14, 0, 0.5)
  K.count:SetPoint("LEFT", K.bar, "RIGHT", 8, 1)
  K.label = tl
  -- the note in two centred lines, in the face of the line at the top; "New drops" and
  -- "before" underlined with a fine line of ink
  local function Part(parent, text)
    local f = Font(parent, "GameFontNormalSmall", INK_SOFT, 12)   -- as the line at the top of the page
    f:SetText(text)
    return f
  end
  local l1 = CreateFrame("Frame", nil, ui.bookView); l1:SetHeight(14)
  l1:SetPoint("TOP", ui.right, "TOP", 0, -376)
  local a1 = Part(l1, AzT("New drops")); a1:SetPoint("LEFT", l1, "LEFT", 0, 0)
  local ul1 = l1:CreateTexture(nil, "ARTWORK"); ul1:SetTexture(WHITE); ul1:SetHeight(1)
  ul1:SetVertexColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
  ul1:SetPoint("TOPLEFT", a1, "BOTTOMLEFT", 0, 1); ul1:SetPoint("TOPRIGHT", a1, "BOTTOMRIGHT", 0, 1)
  local b1 = Part(l1, AzT(" tick themselves; this is for what you had")); b1:SetPoint("LEFT", a1, "RIGHT", 1, 0)
  local l2 = CreateFrame("Frame", nil, ui.bookView); l2:SetHeight(14)
  l2:SetPoint("TOP", ui.right, "TOP", 0, -392)
  local a2 = Part(l2, AzT("before")); a2:SetPoint("LEFT", l2, "LEFT", 0, 0)
  local ul = l2:CreateTexture(nil, "ARTWORK"); ul:SetTexture(WHITE); ul:SetHeight(1)
  ul:SetVertexColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
  ul:SetPoint("TOPLEFT", a2, "BOTTOMLEFT", 0, 1); ul:SetPoint("TOPRIGHT", a2, "BOTTOMRIGHT", 0, 1)
  local b2 = Part(l2, AzT(" Azerloot.")); b2:SetPoint("LEFT", a2, "RIGHT", 0, 0)
  K.foot = { l1 = l1, a1 = a1, b1 = b1, l2 = l2, a2 = a2, b2 = b2 }
  ui.kv = K
  ui.bookView:Hide()

  ui.lootPane:Hide()

  -- PAGE TURN: a sheet of parchment that lifts off one page and settles on the other
  ui.panes = { ui.homePane, ui.listPane, ui.detailPane, ui.lootPane }
  if AzlB then AzlB.MakePane() end
  local flip = CreateFrame("Frame", nil, frame)
  flip:SetFrameLevel(ui.book:GetFrameLevel() + 12)
  flip:SetWidth(385); flip:SetHeight(504)
  local cast = flip:CreateTexture(nil, "BACKGROUND")   -- its shadow on the page below
  cast:SetTexture(GLOW); cast:SetVertexColor(0.08, 0.04, 0)
  cast:SetWidth(90); cast:SetHeight(560)
  flip.cast = cast
  local sheet = Tex(flip, "page.tga", "ARTWORK"); sheet:SetAllPoints(flip)
  flip.sheet = sheet
  local shade = flip:CreateTexture(nil, "OVERLAY")     -- darker as it stands up
  shade:SetTexture(WHITE); shade:SetVertexColor(0.12, 0.06, 0.01); shade:SetAllPoints(flip)
  flip.shade = shade
  flip:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    FlipStep()
  end)
  flip:Hide()
  ui.flip = flip
  local fader = CreateFrame("Frame", nil, frame)
  fader:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    local a = math.min(1, this.t / 0.22)
    this.target:SetAlpha(a)
    if a >= 1 then this:Hide() end
  end)
  fader:Hide()
  ui.fader = fader
  -- closing the book in the middle of a turn leaves nothing half-drawn
  frame:SetScript("OnHide", function() StopAnimations(); state.quote = nil; if AzlB then AzlB.CloseMenu() end end)

  BuildTabs()
  BuildTitle(Strip)
end

-- ---------- tracker: a small see-through wishlist window ----------
local tracker, trackerRows = nil, {}
local TRACK_W, TRACK_ROW, TRACK_HEAD = 230, 18, 17
-- the signs of the window's sections, as on the book's own strips
AZL_TRACK_SIGNS = { Spells = "Interface\\PvPRankBadges\\PvPRank06", Jewelry = MEDIA .. "gem.tga",
  Loot = "Interface\\GossipFrame\\VendorGossipIcon" }

local function TrackerDB()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if AzerlootDB.tracker == nil then AzerlootDB.tracker = true end
  return AzerlootDB
end

-- true while the window is locked and a run is on: it lets the clicks through
function AzlTrackerThrough()
  if not (type(AzerlootDB) == "table" and AzerlootDB.trackerLocked) then return false end
  local ph = AzlPhase and AzlPhase()
  return ph == "playing" or ph == "ready"
end

-- closed: the lock lights up gold and the corner grip goes; open: a dim lock and the grip
local function TrackerLockLook()
  if not tracker or not tracker.lock then return end
  if TrackerDB().trackerLocked then
    tracker.lock.tex:SetVertexColor(1, 0.82, 0); tracker.lock.tex:SetAlpha(1)
    tracker.grip:Hide()
  else
    tracker.lock.tex:SetVertexColor(0.8, 0.8, 0.8); tracker.lock.tex:SetAlpha(0.45)
    tracker.grip:Show()
  end
end

-- each class's symbol on the game's sheet of them (Interface\Glues\CharacterCreate)
Azerloot_ClassCoords = {
  warrior = { 0, 0.25, 0, 0.25 }, mage = { 0.25, 0.49609375, 0, 0.25 }, rogue = { 0.49609375, 0.7421875, 0, 0.25 },
  druid = { 0.7421875, 0.98828125, 0, 0.25 }, hunter = { 0, 0.25, 0.25, 0.5 }, shaman = { 0.25, 0.49609375, 0.25, 0.5 },
  priest = { 0.49609375, 0.7421875, 0.25, 0.5 }, warlock = { 0.7421875, 0.98828125, 0.25, 0.5 }, paladin = { 0, 0.25, 0.5, 0.75 },
}

-- the window at its place: offsets are given in the window's own units, so a window scaled
-- down is placed with them divided by its scale
function AzlAnchorTracker()
  if not tracker then return end
  local sc = tracker:GetScale()
  if type(sc) ~= "number" or sc <= 0 then sc = 1 end
  local p = TrackerDB().trackerPos
  tracker:ClearAllPoints()
  if type(p) == "table" and type(p[3]) == "number" then
    tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p[1] / sc, p[3] / sc)
  elseif type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
    tracker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1] / sc, p[2] / sc)
  else
    tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20 / sc, -220 / sc)
  end
end
-- The window at the size the player set in the settings (60% to 140%); one longer than
-- the room below its top (a smaller screen, a long run) is scaled down until it fits,
-- never below 45%; with room again it grows back.
AzlFitState = {}   -- (the lines and the room when it was last made smaller)
-- How tall a text is in the wishlist window, worked out from its words rather than asked of
-- the client: right after a change the client tells the height of the text before it, and a
-- window refreshed every second then took one height, then the other, for ever. Each line of
-- the text is measured on its own, unwrapped, and counted as the lines it wraps into.
-- How many lines a text takes at a width. First a careful guess, word by word with the same
-- face; then, a frame later, the line count the game really drew is read off the text itself
-- and kept (per text and width), and the window is laid out once more if the guess was off.
-- (A guess alone left a gap under a name that just fits on one line.)
AzlLines = {}
function AzlTextHeight(fs, width)
  local m = AzlFitState.m
  if not m then m = UIParent:CreateFontString(nil, "OVERLAY"); m:Hide(); AzlFitState.m = m end
  local face, size, flags = fs:GetFont()
  size = tonumber(size) or 10
  if face then m:SetFont(face, size, flags) end
  local room = math.max(40, width)
  local key = (fs:GetText() or "") .. "|" .. math.floor(room + 0.5) .. "|" .. size
  local known = AzlLines[key]
  if known then return known * (size + 3) end
  local n, text, at = 0, (fs:GetText() or "") .. "\n", 1
  while true do
    local nl = string.find(text, "\n", at, true)
    if not nl then break end
    local line = string.sub(text, at, nl - 1)
    m:SetText((line ~= "") and line or " ")
    if (m:GetStringWidth() or 0) <= room then
      n = n + 1
    else
      local lines, cur, i = 1, "", 1
      while i <= string.len(line) do
        local sp = string.find(line, " ", i, true)
        local word = sp and string.sub(line, i, sp - 1) or string.sub(line, i)
        local try = (cur == "") and word or (cur .. " " .. word)
        m:SetText(try)
        if cur ~= "" and (m:GetStringWidth() or 0) > room then lines = lines + 1; cur = word
        else cur = try end
        if not sp then break end
        i = sp + 1
      end
      n = n + lines
    end
    at = nl + 1
  end
  n = math.max(1, n)
  -- to be checked against what the game draws, once it has drawn it
  local q = AzlFitState.check or {}
  AzlFitState.check = q
  table.insert(q, { fs = fs, key = key, size = size, guess = n })
  if not AzlFitState.checker then
    local c = CreateFrame("Frame")
    c:SetScript("OnUpdate", function()
      local list = AzlFitState.check
      if not list or table.getn(list) == 0 then return end
      -- (the first frame after: drawn by now)
      AzlFitState.waited = (AzlFitState.waited or 0) + 1
      if AzlFitState.waited < 2 then return end
      AzlFitState.check, AzlFitState.waited = {}, 0
      local off = false
      for i = 1, table.getn(list) do
        local it = list[i]
        local h = it.fs.GetHeight and it.fs:GetHeight()
        if not AzlLines[it.key] and type(h) == "number" and h > 0 and it.fs:IsVisible() then
          local real = math.max(1, math.floor(h / it.size + 0.25))
          AzlLines[it.key] = real
          if real ~= it.guess then off = true end
        end
      end
      if off and RefreshTracker then RefreshTracker() end
    end)
    AzlFitState.checker = c
  end
  return n * (size + 3)
end
function AzlFitTracker()
  if not tracker or (tracker.grip and tracker.grip.sizing) then return end
  local sh, h = UIParent:GetHeight(), tracker:GetHeight()
  if type(sh) ~= "number" or type(h) ~= "number" then return end
  if sh <= 0 or h <= 0 then return end
  local p = TrackerDB().trackerPos
  local fromTop = (type(p) == "table" and type(p[3]) == "number") and p[3] or -220
  if type(p) == "table" and type(p[3]) ~= "number" and type(p[2]) == "number" then fromTop = p[2] - sh end
  local room = sh + fromTop - 8          -- from the window's top to the screen's bottom
  local base = tonumber(TrackerDB().trackerScale) or 1
  local cur = tracker:GetScale()
  if type(cur) ~= "number" or cur <= 0 then cur = 1 end
  -- (a step either way changes how the letters fall, and with them the window's length a
  -- little: so it shrinks only when it does not fit, a bit more than needed, and grows back
  -- only with clearly more room; else it swung between two sizes for ever)
  -- (once made smaller, it grows back only when its lines or the screen changed: its own
  -- longer or shorter wrapping alone never brings it back up)
  local fit, want = room / h, nil
  local F = AzlFitState
  local same = F.at and F.at[1] == F.lines and math.abs(F.at[2] - room) < 1
  if cur > base + 0.005 then want = math.min(base, fit * 0.97)
  elseif fit < cur - 0.005 then want = fit * 0.97; F.at = { F.lines, room }
  elseif cur < base - 0.005 and fit > cur + 0.08 and not same then want = math.min(base, fit * 0.97)
  end
  if not want then return end
  want = math.max(0.45, math.min(base, want))
  if math.abs(want - cur) > 0.005 then
    tracker:SetScale(want)
    AzlAnchorTracker()
  end
end
-- the window kept by its upper left corner: dragged or sized, it is pinned there again, so
-- it grows and shrinks downwards and opens at the same place in every run
function AzlPinTracker()
  if not tracker then return end
  local l, t = tracker:GetLeft(), tracker:GetTop()
  if not (l and t) then return end
  local sc = tracker:GetScale()
  if type(sc) ~= "number" or sc <= 0 then sc = 1 end
  l, t = l * sc, t * sc   -- (the window's own units, when it is scaled down, into the screen's)
  -- kept from the screen's top, not its bottom: the game may change the screen's height in
  -- the interface's units at a run's start, and a window measured from the bottom then
  -- slides down from the top
  local top = UIParent:GetTop() or UIParent:GetHeight() or t
  TrackerDB().trackerPos = { l, t, t - top }
  if tracker.SetUserPlaced then tracker:SetUserPlaced(false) end
  AzlAnchorTracker()
end
local function BuildTracker()
  tracker = CreateFrame("Frame", "AzerlootTracker", UIParent)
  tracker:SetWidth(TRACK_W); tracker:SetHeight(40)
  -- as high as the interface goes, so it stays in view over level-up and treasure screens
  tracker:SetFrameStrata("FULLSCREEN_DIALOG")
  tracker:SetToplevel(true)
  tracker:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  tracker:SetBackdropColor(0, 0, 0, 0.35)
  tracker:SetBackdropBorderColor(0.8, 0.62, 0.28, 0.7)
  tracker:EnableMouse(true)
  tracker:SetMovable(true)
  tracker:SetClampedToScreen(true)
  tracker:RegisterForDrag("LeftButton")
  tracker:SetScript("OnDragStart", function()
    if TrackerDB().trackerLocked then return end
    tracker.moving = true
    tracker:StartMoving()
  end)
  tracker:SetScript("OnDragStop", function()
    if not tracker.moving then return end
    tracker.moving = nil
    tracker:StopMovingOrSizing()
    AzlPinTracker()
  end)
  -- the size set in the settings (Wishlist size), kept over a /reload and a new run
  -- (an older version threw it away here each time the window was built)
  -- a place saved under another resolution or UI scale may lie off the screen now: then
  -- the window starts again at its first place (so does a size taller than the screen)
  -- (checked a few seconds later: right at login the screen's size is not settled yet, and a
  -- place near its edge looked "off the screen", so the window jumped back to its first place)
  local pos = TrackerDB().trackerPos
  if pos and (type(pos[1]) ~= "number" or type(pos[2]) ~= "number") then
    TrackerDB().trackerPos = nil; pos = nil
  end
  -- the game itself keeps no place of its own for it: only the book's counts
  if tracker.SetUserPlaced then tracker:SetUserPlaced(false) end
  tracker:ClearAllPoints()
  if pos and type(pos[3]) == "number" then
    tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos[1], pos[3])
  elseif pos then
    tracker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])   -- (kept so by 2.1.0)
  else
    tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
  end
  local chk = CreateFrame("Frame")
  chk:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + (arg1 or 0)
    if this.t < 3 then return end
    this:SetScript("OnUpdate", nil)
    local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    local p = TrackerDB().trackerPos
    if type(p) == "table" and type(p[3]) ~= "number" then
      -- a place kept from the bottom (2.1.0): kept from the top from now on, where it is
      AzlPinTracker(); p = TrackerDB().trackerPos
    end
    if sw > 0 and type(p) == "table" and type(p[3]) == "number" and (p[1] < -40 or p[1] > sw - 40 or p[3] > 40 or p[3] < -(sh - 40)) then
      TrackerDB().trackerPos = nil
      tracker:ClearAllPoints(); tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
    end
    if sh > 0 and (TrackerDB().trackerH or 0) > sh - 40 then TrackerDB().trackerH = nil; RefreshTracker() end
  end)
  -- the head's words and emblem on a layer of their own, above the panels behind them
  local hf = CreateFrame("Frame", nil, tracker)
  hf:SetAllPoints(tracker); hf:SetFrameLevel(tracker:GetFrameLevel() + 2)
  tracker.headLayer = hf
  -- the window's title in the same face as its entries, clearly larger than its section headings
  local title = Font(hf, "GameFontNormal")
  if fontReg[title] then fontReg[title].bump = 3; ApplyFace(title, fontReg[title]) end
  title:SetShadowColor(0, 0, 0, 1); title:SetShadowOffset(1, -1)
  title:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, -6)
  title:SetText(AzT("Wishlist"))
  tracker.title = title
  -- the class's emblem right after its name, as on the builds page
  local emb = hf:CreateTexture(nil, "ARTWORK")
  -- the size of the title's capitals, sitting on the same line as the class name
  emb:SetWidth(15); emb:SetHeight(15)
  emb:SetPoint("LEFT", title, "RIGHT", 4, -1)
  tracker.emblem = emb
  -- a click on the head card: the builds to choose from, under it
  local pb = CreateFrame("Button", nil, hf)
  pb:SetFrameLevel(hf:GetFrameLevel() + 1)
  pb:SetScript("OnClick", function()
    if AzlB and AzlB.OpenPick then AzlB.OpenPick() end
  end)
  pb:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Pick a build"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click to choose one of your builds for the wishlist."), 0.85, 0.85, 0.85, 1)
    GameTooltip:Show()
  end)
  pb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pb:Hide()
  tracker.pickBtn = pb
  -- with a build loaded, the head card: the build's name large, the window's name under it
  local sub = Font(hf, "GameFontHighlightSmall")
  sub:SetTextColor(0.8, 0.76, 0.68); sub:Hide()
  tracker.sub = sub
  -- the level-ups the game keeps waiting (Store Level-Ups), in the head card: a click opens
  -- them as the game's own Level Up! button does
  local lb = CreateFrame("Button", nil, tracker)
  lb:SetHeight(14); lb:SetWidth(60); lb:SetFrameLevel(tracker:GetFrameLevel() + 3)
  local lg = lb:CreateTexture(nil, "BACKGROUND")
  lg:SetTexture(GLOW); lg:SetBlendMode("ADD"); lg:SetVertexColor(1, 0.62, 0.18)
  lg:SetPoint("TOPLEFT", lb, "TOPLEFT", -6, 4); lg:SetPoint("BOTTOMRIGHT", lb, "BOTTOMRIGHT", 6, -4)
  lb.glow = lg
  -- (small, as the build's count beside it)
  local ltx = Font(lb, "GameFontNormalSmall")
  ltx:SetPoint("RIGHT", lb, "RIGHT", 0, 0); ltx:SetTextColor(1, 0.82, 0)
  lb.text = ltx
  local lhl = lb:CreateTexture(nil, "HIGHLIGHT")
  lhl:SetTexture(GLOW); lhl:SetBlendMode("ADD"); lhl:SetVertexColor(1, 0.85, 0.4); lhl:SetAlpha(0.35)
  lhl:SetAllPoints(lg)
  lb:SetScript("OnClick", function() if AZS_OpenStoredLevels then AZS_OpenStoredLevels() end end)
  lb:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Stored level-ups"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click to choose them, one after another."), 0.85, 0.85, 0.85, 1)
    GameTooltip:AddLine(AzT("Or press Y, the game's own key for it."), 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
  end)
  lb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lb:SetScript("OnUpdate", function()
    this.glow:SetAlpha(0.15 + 0.25 * (0.5 + 0.5 * math.sin(GetTime() * 2.2)))
  end)
  lb:Hide()
  tracker.levels = lb

  -- the lock: once closed the window can no longer be moved or resized by accident
  local lock = CreateFrame("Button", nil, tracker)
  lock:SetWidth(14); lock:SetHeight(14)
  lock:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -10, -9)   -- off the corner, inside the frame
  local lt = lock:CreateTexture(nil, "ARTWORK"); lt:SetAllPoints(lock)
  lt:SetTexture("Interface\\ChatFrame\\UI-ChatFrame-LockIcon")
  lock.tex = lt
  local lh = lock:CreateTexture(nil, "HIGHLIGHT"); lh:SetAllPoints(lock)
  lh:SetTexture("Interface\\ChatFrame\\UI-ChatFrame-LockIcon"); lh:SetBlendMode("ADD")
  lock:SetScript("OnClick", function()
    local db = TrackerDB()
    db.trackerLocked = not db.trackerLocked
    TrackerLockLook()
    RefreshTracker()
    this:GetScript("OnEnter")()
  end)
  lock:SetScript("OnEnter", function()
    local locked = TrackerDB().trackerLocked
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT(locked and "Locked" or "Unlocked"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT(locked and "Click to move and resize the window again."
      or "Drag the window to move it, the corner to resize it. Click to lock it in place."), 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tracker.lock = lock

  -- the corner grip: drag it right for a wider window, down for a longer one
  local grip = CreateFrame("Button", nil, tracker)
  grip:SetWidth(14); grip:SetHeight(14)
  grip:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", -3, 3)
  local gt = grip:CreateTexture(nil, "ARTWORK"); gt:SetAllPoints(grip)
  gt:SetTexture(MEDIA .. "grip.tga"); gt:SetAlpha(0.6)
  grip.tex = gt
  grip:SetScript("OnEnter", function() this.tex:SetAlpha(1) end)
  grip:SetScript("OnLeave", function() this.tex:SetAlpha(0.6) end)
  grip:SetScript("OnMouseDown", function()
    if TrackerDB().trackerLocked then return end
    local x, y = GetCursorPosition()
    local es = tracker.GetEffectiveScale and tracker:GetEffectiveScale()
    local s = (type(es) == "number" and es > 0) and es or UIParent:GetEffectiveScale()
    this.startX, this.startY = x / s, y / s
    this.startW, this.startH = tracker:GetWidth(), tracker:GetHeight()
    this.sizing = true
  end)
  grip:SetScript("OnMouseUp", function()
    if not this.sizing then return end
    this.sizing = nil
    AzlPinTracker()
  end)
  grip:SetScript("OnUpdate", function()
    if not this.sizing then return end
    local x, y = GetCursorPosition()
    local es = tracker.GetEffectiveScale and tracker:GetEffectiveScale()
    local s = (type(es) == "number" and es > 0) and es or UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    local w = this.startW + (x - this.startX)
    local h = this.startH - (y - this.startY)   -- the screen counts upwards
    if w < 170 then w = 170 elseif w > 700 then w = 700 end
    if h < 40 then h = 40 elseif h > 900 then h = 900 end
    local db = TrackerDB()
    db.trackerW, db.trackerH = math.floor(w + 0.5), math.floor(h + 0.5)
    RefreshTracker()
  end)
  tracker.grip = grip
  TrackerLockLook()
  tracker:Hide()
end

-- Brings the wishlist window back to its first place and size, unlocked and shown: for a
-- window that went off the screen. From the settings (gear) or with /azl reset.
function Azerloot_ResetTracker()
  local db = TrackerDB()
  db.trackerPos, db.trackerW, db.trackerH, db.trackerLocked = nil, nil, nil, nil
  db.tracker = true
  if tracker then
    tracker:SetScale(1)
    AzlAnchorTracker()
    TrackerLockLook()
  end
  RefreshTracker()
  Print((table.getn(WishEntries()) == 0) and AzT("wishlist window back at its first place (it shows once your wishlist has an entry).") or AzT("wishlist window back at its first place."))
end

local function TrackerRow(i)
  if trackerRows[i] then return trackerRows[i] end
  local r = CreateFrame("Button", nil, tracker)
  r:SetWidth(TRACK_W - 12); r:SetHeight(TRACK_ROW)
  -- a section heading in the middle of its line: a fine line, its sign, its name, the sign
  -- again and the line on
  local hd = Font(r, "GameFontNormal")   -- a heading: a size above the entries
  hd:SetPoint("BOTTOM", r, "BOTTOM", 0, 3)
  hd:SetTextColor(1, 0.82, 0)
  r.head = hd
  -- the section's sign right after its name: the sword, the tabard, the loot bag
  local sg = r:CreateTexture(nil, "ARTWORK")
  sg:SetWidth(11); sg:SetHeight(11)
  sg:SetPoint("LEFT", hd, "RIGHT", 4, 0)
  sg:Hide()
  r.sign = sg
  local sl = r:CreateTexture(nil, "ARTWORK")
  sl:SetWidth(11); sl:SetHeight(11)
  sl:SetPoint("RIGHT", hd, "LEFT", -4, 0)
  sl:Hide()
  r.signL = sl
  r.sideLines = {}
  for k = 1, 2 do
    local l = r:CreateTexture(nil, "ARTWORK")
    l:SetTexture(WHITE); l:SetVertexColor(1, 0.82, 0); l:SetAlpha(0.35); l:SetHeight(1); l:Hide()
    r.sideLines[k] = l
  end
  -- the heading's own band, a little warmer than its panel, and its count at the right
  local band = r:CreateTexture(nil, "BACKGROUND")
  band:SetTexture(WHITE); band:SetVertexColor(0.42, 0.28, 0.08); band:SetAlpha(0.35)
  band:SetPoint("TOPLEFT", r, "TOPLEFT", -4, 1); band:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 4, 0)
  band:Hide()
  r.band = band
  local cnt = Font(r, "GameFontHighlightSmall")
  cnt:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -2, 4); cnt:SetTextColor(0.85, 0.78, 0.62); cnt:Hide()
  r.count = cnt
  -- a part the loaded build still waits for, in its place at the right
  local stt = Font(r, "GameFontNormalSmall")
  stt:SetTextColor(1, 0.82, 0); stt:Hide()
  r.status = stt
  -- shown as the game's yellow "?", the same as beside the book's headings
  local ask = r:CreateTexture(nil, "OVERLAY")
  ask:SetWidth(14); ask:SetHeight(14); ask:SetTexture(QUEST_NO); ask:Hide()
  r.ask = ask
  local ln = r:CreateTexture(nil, "ARTWORK")
  ln:SetTexture(WHITE); ln:SetVertexColor(1, 0.82, 0); ln:SetAlpha(0.3)
  ln:SetHeight(1)
  ln:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 1); ln:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
  r.line = ln
  local ic = r:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(16); ic:SetHeight(16); ic:SetPoint("LEFT", r, "LEFT", 3, 0)   -- 3 pixels in from the panel's edge
  r.icon = ic
  local nm = Font(r, "GameFontHighlightSmall")
  nm:SetPoint("LEFT", ic, "RIGHT", 5, 0)
  nm:SetWidth(TRACK_W - 55); nm:SetJustifyH("LEFT")
  r.name = nm
  -- the rank right after the name, coloured from grey (rank 1) to green (rank 20); from
  -- rank 15 on a warm golden light breathes behind it and a faint golden contour traces
  -- its letters, as behind the book's title, full at rank 20
  local rg = r:CreateTexture(nil, "BACKGROUND")
  rg:SetTexture(GLOW); rg:SetBlendMode("ADD"); rg:SetVertexColor(1, 0.62, 0.18); rg:Hide()
  r.rankGlow = rg
  local rk = Font(r, "GameFontHighlightSmall")
  rk:SetJustifyH("LEFT"); rk:Hide()
  r.rank = rk
  r.rankRim = {}
  for i = 1, 8 do
    local ang = (i - 1) * math.pi / 4
    local f = r:CreateFontString(nil, "BORDER")
    f:SetPoint("CENTER", rk, "CENTER", math.cos(ang), math.sin(ang))
    f:SetTextColor(1, 0.7, 0.25); f:Hide()
    r.rankRim[i] = f
  end
  r.rankLevel = 0
  -- on the window's first heading: the level-ups the game keeps waiting (Store Level-Ups),
  -- a click opens them as the game's own Level Up! button does
  local lb = CreateFrame("Button", nil, r)
  lb:SetHeight(TRACK_HEAD); lb:SetWidth(60)
  lb:SetPoint("RIGHT", cnt, "LEFT", -8, 0)
  local lg = lb:CreateTexture(nil, "BACKGROUND")
  lg:SetTexture(GLOW); lg:SetBlendMode("ADD"); lg:SetVertexColor(1, 0.62, 0.18)
  lg:SetPoint("TOPLEFT", lb, "TOPLEFT", -8, 5); lg:SetPoint("BOTTOMRIGHT", lb, "BOTTOMRIGHT", 8, -5)
  lb.glow = lg
  local lt = Font(lb, "GameFontNormalSmall")
  lt:SetPoint("RIGHT", lb, "RIGHT", 0, 0); lt:SetTextColor(1, 0.82, 0)
  lb.text = lt
  local lh = lb:CreateTexture(nil, "HIGHLIGHT")
  lh:SetTexture(GLOW); lh:SetBlendMode("ADD"); lh:SetVertexColor(1, 0.85, 0.4); lh:SetAlpha(0.35)
  lh:SetAllPoints(lg)
  lb:SetScript("OnClick", function() if AZS_OpenStoredLevels then AZS_OpenStoredLevels() end end)
  lb:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AzT("Stored level-ups"), 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click to choose them, one after another."), 0.85, 0.85, 0.85, 1)
    GameTooltip:AddLine(AzT("Or press Y, the game's own key for it."), 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
  end)
  lb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lb:SetScript("OnUpdate", function()
    this.glow:SetAlpha(0.15 + 0.25 * (0.5 + 0.5 * math.sin(GetTime() * 2.2)))
  end)
  lb:Hide()
  r.levels = lb
  local pf = CreateFrame("Frame", nil, r)
  pf:SetScript("OnUpdate", function()
    local row = this:GetParent()
    local lv = row.rankLevel or 0
    if lv <= 0 or not row.rank:IsVisible() then return end
    local a = 0.5 + 0.5 * math.sin(GetTime() * 2.2)
    row.rankGlow:SetAlpha(lv * (0.1 + 0.2 * a))
    local face, size, flags = row.rank:GetFont()
    for i = 1, 8 do
      local f = row.rankRim[i]
      if face and (f.face ~= face or f.size ~= size) then f:SetFont(face, size, flags); f.face, f.size = face, size end
      f:SetAlpha(lv * 0.3 * (0.25 + 0.75 * a))
    end
  end)
  local ck = r:CreateTexture(nil, "OVERLAY")
  ck:SetWidth(18); ck:SetHeight(18); ck:SetPoint("RIGHT", r, "RIGHT", -1, 0)
  SetCheck(ck); ck:Hide()
  r.check = ck
  -- a red cross in the check's place: a class amulet wished for, while another one is worn
  local cx = r:CreateTexture(nil, "OVERLAY")
  cx:SetWidth(14); cx:SetHeight(14); cx:SetTexture(MEDIA .. "cross.tga"); cx:Hide()
  r.cross = cx
  r.missed = false
  -- a spell's bonuses of this run, in the tooltip's green, under its name
  local bo = Font(r, "GameFontHighlightSmall")
  bo:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -1)
  bo:SetWidth(TRACK_W - 55); bo:SetJustifyH("LEFT")
  bo:Hide()
  r.bonus = bo
  -- a line through the name once the entry is collected or found
  local st = r:CreateTexture(nil, "OVERLAY")
  st:SetTexture(WHITE); st:SetHeight(1)
  st:SetPoint("LEFT", nm, "LEFT", -1, 0)
  st:Hide()
  r.strike = st
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", function() tracker:GetScript("OnDragStart")() end)
  r:SetScript("OnDragStop", function() tracker:GetScript("OnDragStop")() end)
  r:SetScript("OnEnter", function()
    if not this.entry then
      if this.foldKey then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(this.head:GetText() or "", 1, 0.82, 0)
        GameTooltip:AddLine(AzT(this.folded and "Folded away: click to show it again." or "Click to fold it away."), 0.85, 0.85, 0.85, 1)
        GameTooltip:AddLine(AzT("Right-click twice to take the whole section off your wishlist."), 0.6, 0.6, 0.6, 1)
        GameTooltip:Show()
      end
      return
    end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local title, col, sub = EntryTitle(this.entry)
    GameTooltip:AddLine(title, col[1], col[2], col[3])
    GameTooltip:AddLine(sub, 0.8, 0.8, 0.8)
    local f, byHand = IsFound(this.entry)
    local loot = (this.entry.kind == "LootItem")
    if f then GameTooltip:AddLine(AzT((loot and "In your collection") or (byHand and "Found in this run") or "Worn in this run"), 0.3, 1, 0.45) end
    -- the game's own words for a worn piece, shown short in the window
    if this.longText then GameTooltip:AddLine(this.longText, 0.3, 1, 0.3, 1) end
    if this.missed then GameTooltip:AddLine(AzT(this.missed), 1, 0.3, 0.25, 1) end
    if this.needed then GameTooltip:AddLine(AzT("Still needed in this run."), 1, 0.82, 0, 1) end
    local secs = EntrySections(this.entry, true)
    for s = 1, table.getn(secs) do
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(secs[s][1], 1, 0.82, 0)
      for i = 1, table.getn(secs[s][2]) do
        local l = secs[s][2][i]
        GameTooltip:AddLine(l[1], l[2][1], l[2][2], l[2][3], 1)
      end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(AzT(loot and "Click to open its boss in the book. Right-click to mark it collected."
      or "Click to open it in the book. Right-click to mark it found."), 0.6, 0.6, 0.6, 1)
    GameTooltip:AddLine(AzT("Shift-right-click takes it off your wishlist."), 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:SetScript("OnClick", function()
    if not this.entry then
      -- a heading's right-click: the whole section off the wishlist, after a second click
      if this.foldKey and arg1 == "RightButton" then
        local armed = AzlTrackClear and AzlTrackClear.key == this.foldKey and GetTime() < AzlTrackClear.till
        if armed then
          AzlTrackClear = nil
          AzlUnwish(this.sectionEntries or {})
          RefreshTracker(); Refresh()
        else
          AzlTrackClear = { key = this.foldKey, till = GetTime() + 3 }
          -- the heading's own words again once the 3 seconds are over
          if not AzlTrackClearF then
            AzlTrackClearF = CreateFrame("Frame")
            AzlTrackClearF:SetScript("OnUpdate", function()
              if AzlTrackClear and GetTime() >= AzlTrackClear.till then AzlTrackClear = nil; RefreshTracker() end
            end)
          end
          RefreshTracker()
        end
        return
      end
      -- a heading: its section folds away, or opens again
      if this.foldKey then
        local db = TrackerDB()
        if type(db.fold) ~= "table" then db.fold = {} end
        db.fold[this.foldKey] = not db.fold[this.foldKey] or nil
        RefreshTracker()
      end
      return
    end
    if arg1 == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
      -- shift and right-click: off the wishlist
      AzlUnwish({ this.entry }); RefreshTracker(); Refresh()
      return
    end
    if arg1 == "RightButton" then
      ToggleMark(this.entry); RefreshTracker(); Refresh()
      return
    end
    if not frame then Build() end
    local e = this.entry
    if e.kind == "LootItem" then
      -- straight to the boss that drops it
      state.module = "Loot"; state.search = ""
      if ui.search then ui.search:SetText(""); ui.search:ClearFocus() end
      state.class = e.class
      state.lootZone, state.lootBoss = e.zoneIndex, e.bossIndex
      state.selected = ZoneEntries()[e.zoneIndex]
      state.offset = 0
      frame:Show(); Refresh()
      return
    end
    state.search = ""; state.offset = 0; state.selected = this.entry
    if e.kind == "Spell" then
      state.module = "Spells"; state.view = "Spells"
    else
      state.module = "Jewelry"; state.view = e.kind
      if e.kind == "Legendary" then state.class = PlayerClass() end
      -- the page that shows it
      local all = (e.kind == "Legendary") and ClassEntries(ClassInfo(PlayerClass())) or ItemEntries(e.kind)
      for k = 1, table.getn(all) do
        if WishKey(all[k]) == WishKey(e) then state.selected = all[k]; state.offset = math.floor((k - 1) / ROWS) * ROWS end
      end
    end
    if ui.search then ui.search:SetText(""); ui.search:ClearFocus() end
    frame:Show(); Refresh()
  end)
  trackerRows[i] = r
  return r
end

-- A wished ring, trinket or amulet out of reach for this run: every slot of its kind holds
-- another piece. Rings and trinkets stay for the whole run; the one amulet can be swapped,
-- so an amulet is open again once the other one comes off. Gives the tooltip's reason.
AZL_SLOT_FULL = { neck = "You wear another amulet in this run.",
  finger = "Both ring slots are taken in this run.", trinket = "Both trinket slots are taken in this run." }
function AzlOutOfReach(e, worn, wk)
  local kind = (e.kind == "Legendary") and "neck" or KIND_SLOT[e.kind]
  if not kind or IsFound(e, worn) then return nil end
  if e.kind == "Legendary" and WornSlot(e) then
    -- an amulet of the same name: only out of reach when its lines tell another spell
    if wk and wk ~= e.item.key then return AZL_SLOT_FULL.neck end
    return nil
  end
  for i = 1, table.getn(SLOTS) do
    if SLOTS[i][2] == kind then
      local link = GetInventoryItemLink and GetInventoryItemLink("player", SLOTS[i][1])
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", SLOTS[i][1])
      if not (link or tex) then return nil end   -- a free slot: it can still come
    end
  end
  return AZL_SLOT_FULL[kind]
end

-- the window shows only the effects: the game's "Equip:" before each line goes, in every
-- language the book has
AZL_EQUIP = { "Equip: ", "Anlegen: ", "\195\137quip\195\169 : ", "Equipar: ", "Equipado: " }
function AzlNoEquip(text)
  local out = {}
  for line in (string.gfind or string.gmatch)(text .. "\n", "(.-)\n") do
    for i = 1, table.getn(AZL_EQUIP) do
      local p = AZL_EQUIP[i]
      if string.sub(line, 1, string.len(p)) == p then line = string.sub(line, string.len(p) + 1); break end
    end
    table.insert(out, line)
  end
  return table.concat(out, "\n")
end

-- The game's own Level Up! button is never touched. A test build could hide it: if it did,
-- it is shown again once.
function AzlLevelHud()
  if type(AzerlootDB) ~= "table" then return end
  AzerlootDB.hideLevelHud = nil
  if AzerlootDB.levelHudHidden and AZS_SetHudShown and pcall(AZS_SetHudShown, "levels", true) then
    AzerlootDB.levelHudHidden = nil
  end
end

-- The worn rings, trinkets and amulets not yet in the list, each once: known by its name
-- (in English), else by its icon. A worn class amulet (wk) is already in the list.
function AzlAddWorn(list, wk)
  local KIND = { finger = "Rings", trinket = "Trinkets", neck = "Amulets" }
  local have = {}
  for i = 1, table.getn(list) do have[list[i].item.name or ""] = true end
  for i = 1, table.getn(SLOTS) do
    local slot, sk = SLOTS[i][1], SLOTS[i][2]
    if not (sk == "neck" and wk) then
      local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
      if link or tex then
        local _, _, n = string.find(link or "", "%[(.-)%]")
        local name = n and EnglishName(n)
        local all, pick = ItemEntries(KIND[sk]), nil
        for k = 1, table.getn(all) do
          if name and all[k].item.name == name then pick = all[k] end
        end
        if not pick and tex then
          for k = 1, table.getn(all) do
            if not pick and IconKey(tex) == IconKey(all[k].item.icon) then pick = all[k] end
          end
        end
        if pick and not have[pick.item.name] then
          have[pick.item.name] = true
          pick.extra = true   -- worn, but not wished for: no check
          table.insert(list, pick)
        end
      end
    end
  end
end

-- the level-ups the game keeps waiting (Store Level-Ups); 0 with the setting off, and on a
-- game too old to know them
function AzlStoredLevels()
  if not AZS_GetStoredLevels then return 0 end
  local ok, n = pcall(AZS_GetStoredLevels)
  return ok and tonumber(n) or 0
end

-- A run holds six spells (the starting one and five more), and a spell once taken stays:
-- with all six places filled, a wished spell the hero does not know can no longer come.
AZL_SLOT_FULL.spell = "All six spell places are taken in this run."
-- Only the class's own spells count: a racial trait (Escape Artist, Stoneform...) the game
-- lists among the run's spells takes no place.
function AzlSpellsFull()
  local AZS_SPELLS = AzlSpells()
  local own, info = {}, ClassInfo(PlayerClass())
  for i = 1, table.getn(info.spells) do own[info.spells[i].key] = true end
  local n = 0
  for i = 1, table.getn(AZS_SPELLS) do
    local rk = tonumber(AZS_SPELLS[i].rank)
    if own[AZS_SPELLS[i].key] and not (rk and rk <= 0) then n = n + 1 end
  end
  return n >= 6
end

-- the rank the game gives a spell of this run (AZS_SPELLS: key, spell, rank, cd, cdmax)
function AzlSpellRank(key)
  local AZS_SPELLS = AzlSpells()
  for i = 1, table.getn(AZS_SPELLS) do
    local sp = AZS_SPELLS[i]
    if sp.key == key and tonumber(sp.rank) and tonumber(sp.rank) > 0 then return tonumber(sp.rank) end
  end
  return nil
end

-- A worn ring, trinket or amulet counts its upgrades in this run: it starts at rank 1 when
-- found; each time its numbers change (one upgrade, however many of its values grow) it
-- goes one up. Another piece in the slot (a swapped amulet) starts again at 1. Kept over a
-- /reload, cleared when a new run begins.
function AzlJewelRank(e)
  local slot = WornSlot(e)
  if not slot then return nil end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or ""
  local _, _, name = string.find(link, "%[(.-)%]")
  name = name or ""
  local text = WornLine(e)
  local sig
  if text then
    local nums = {}
    for n in (string.gfind or string.gmatch)(text, "%d+[%.,]?%d*") do table.insert(nums, n) end
    sig = table.concat(nums, "|")
  end
  if type(AzerlootDB.jrank) ~= "table" then AzerlootDB.jrank = {} end
  local rec = AzerlootDB.jrank[slot]
  if not rec or rec.name ~= name then
    rec = { name = name, sig = sig, rank = 1 }
    AzerlootDB.jrank[slot] = rec
  elseif sig and sig ~= "" and sig ~= rec.sig then
    if rec.sig then rec.rank = rec.rank + 1 end
    rec.sig = sig
  end
  return rec.rank
end

-- A rank's colour: a smooth way through a colour table from grey at rank 1 to the
-- legendary orange at rank 20, every rank a little further along.
local RANK_STOPS = {
  { 0.00, 0.62, 0.62, 0.62 },   -- grey
  { 0.35, 0.80, 0.72, 0.58 },   -- a light, warm grey
  { 0.70, 0.96, 0.62, 0.26 },   -- amber
  { 1.00, 1.00, 0.50, 0.00 },   -- legendary orange
}
function AzlRankColor(rank)
  local t = math.max(0, math.min(1, (rank - 1) / 19))
  for i = 2, table.getn(RANK_STOPS) do
    local a, b = RANK_STOPS[i - 1], RANK_STOPS[i]
    if t <= b[1] then
      local k = (t - a[1]) / (b[1] - a[1])
      k = k * k * (3 - 2 * k)   -- eased, so no stop shows as a step
      return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k, t
    end
  end
  return 1, 0.5, 0, 1
end
function AzlShowRank(r, rank, W)
  if not rank then
    r.rank:Hide(); r.rankGlow:Hide(); r.rankLevel = 0
    for i = 1, 8 do r.rankRim[i]:Hide() end
    return
  end
  local cr, cg, cb, t = AzlRankColor(rank)
  r.rank:SetText("(" .. AzT("Rank %s", rank) .. ")")
  r.rank:SetTextColor(cr, cg, cb)
  local avail = W - 55
  local rw = (r.rank:GetStringWidth() or 40) + 2
  local nw = r.name:GetStringWidth() or 0
  local x
  if nw + 4 + rw <= avail then
    x = nw + 4
  else
    -- a long name: it wraps before the rank, which keeps the end of its first line
    r.name:SetWidth(avail - rw - 4)
    x = avail - rw
  end
  r.rank:ClearAllPoints(); r.rank:SetPoint("TOPLEFT", r.name, "TOPLEFT", x, 0)
  r.rank:Show()
  -- the golden light: from rank 15 on, growing softly, full at 20 and kept from there
  local lv = math.max(0, math.min(1, (rank - 15) / 5))
  lv = lv * lv * (3 - 2 * lv)
  if rank >= 15 then lv = math.max(lv, 0.15) end
  r.rankLevel = lv
  if lv > 0 then
    local face, size, flags = r.rank:GetFont()
    for i = 1, 8 do
      local f = r.rankRim[i]
      if face then f:SetFont(face, size, flags); f.face, f.size = face, size end
      f:SetText(r.rank:GetText()); f:Show()
    end
    r.rankGlow:ClearAllPoints()
    r.rankGlow:SetPoint("TOPLEFT", r.rank, "TOPLEFT", -10, 6)
    r.rankGlow:SetPoint("BOTTOMRIGHT", r.rank, "BOTTOMRIGHT", 10, -6)
    r.rankGlow:Show()
  else
    for i = 1, 8 do r.rankRim[i]:Hide() end
    r.rankGlow:Hide()
  end
end

-- the count at a section's heading: spells had of six, jewelry worn of five, loot collected
function AzlSectionCount(title, entries)
  if title == "Spells" then
    local AZS_SPELLS = AzlSpells()
    if table.getn(AZS_SPELLS) == 0 then return nil end
    local own, info, n = {}, ClassInfo(PlayerClass()), 0
    for i = 1, table.getn(info.spells) do own[info.spells[i].key] = true end
    for i = 1, table.getn(AZS_SPELLS) do if own[AZS_SPELLS[i].key] then n = n + 1 end end
    return n .. " / 6"
  elseif title == "Jewelry" then
    local n = 0
    for _, slot in ipairs({ 2, 11, 12, 13, 14 }) do
      if GetInventoryItemLink and GetInventoryItemLink("player", slot) then n = n + 1 end
    end
    return n .. " / 5"
  elseif title == "Loot" then
    local got = 0
    for i = 1, table.getn(entries) do if IsFound(entries[i]) then got = got + 1 end end
    return got .. " / " .. table.getn(entries)
  end
  return nil
end
-- The window's head: with a build loaded, a card with the class's emblem, the build's name in
-- gold and the window's name under it (the bar of the build's progress at its right, from
-- Builds.lua); without one, the window's name with the emblem after it, as before.
function AzlTrackerCard(b, ci, waiting)
  local t, e, sub, lv = tracker.title, tracker.emblem, tracker.sub, tracker.levels
  t:ClearAllPoints(); e:ClearAllPoints(); lv:ClearAllPoints()
  local face, size, flags = t:GetFont()
  if b then
    -- the card: emblem, the build's name large in gold, the window's name under it, and on
    -- a second line the build's gems (Builds.lua) and the waiting level-ups
    e:SetWidth(32); e:SetHeight(32)
    e:SetPoint("TOPLEFT", tracker, "TOPLEFT", 10, -11)
    if face and not t.big then t.small = size; t:SetFont(face, size + 3, flags); t.big = true end
    t:SetPoint("TOPLEFT", e, "TOPRIGHT", 8, 1)
    t:SetText("|cffffd100" .. ((AzlB and AzlB.Short) and AzlB.Short(b.name, 18) or b.name) .. "|r")
    sub:ClearAllPoints(); sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -1)
    sub:SetText(AzT("Wishlist") .. " - |cff" .. ci.color .. AzG(ci.name) .. "|r")
    sub:Show()
    lv:SetPoint("RIGHT", tracker, "TOPRIGHT", -12, -53)
    return -66, -72   -- the card reaches 4 pixels further down: room under the bar's frame
  end
  e:SetWidth(15); e:SetHeight(15)
  if face and t.big then t:SetFont(face, t.small or size, flags); t.big = nil end
  -- without a build the card holds the title alone: 3 pixels more room above it and below
  t:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, -9)
  e:SetPoint("LEFT", t, "RIGHT", 4, -1)
  sub:Hide()
  -- builds made but none loaded (none chosen, or one taken apart): a line under the title
  -- says a click on it brings the choice back
  local hint = AzlB and AzlB.Count and AzlB.Count(PlayerClass()) > 0 and not (AzlB.Picking and AzlB.Picking())
  if hint then
    sub:ClearAllPoints(); sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2)
    sub:SetText("|cffffd100" .. AzT("Click here to pick a build") .. "|r")
    sub:Show()
  end
  if lv:IsShown() then
    lv:SetPoint("LEFT", tracker, "TOPLEFT", 10, hint and -50 or -36)
    if hint then return -62, -68, true end
    return -48, -54
  end
  if hint then return -44, -49, true end
  return -30, -35
end
-- a heading's fine lines, one to each side of its signs, as long as each other; the right
-- one stops short of the count (and the waiting level-ups)
function AzlHeadLines(r, w)
  local hw = (r.head:GetStringWidth() or 40) / 2 + 4 + 11 + 6
  local c = w / 2
  local right = w - ((r.count:IsShown() and (r.count:GetStringWidth() or 0) + 8) or 2)
  if r.levels:IsShown() then right = right - (r.levels:GetWidth() or 60) - 8 end
  local len = math.max(0, math.min(c - hw - 2, right - (c + hw)))
  local l1, l2 = r.sideLines[1], r.sideLines[2]
  l1:ClearAllPoints(); l2:ClearAllPoints()
  if len >= 8 then
    l1:SetPoint("LEFT", r, "BOTTOMLEFT", c - hw - len, 9); l1:SetWidth(len); l1:Show()
    l2:SetPoint("LEFT", r, "BOTTOMLEFT", c + hw, 9); l2:SetWidth(len); l2:Show()
  else
    l1:Hide(); l2:Hide()
  end
end
-- a wished part not here yet, during a run: a little softer, "needed" at the right
function AzlNeeded(r)
  -- only while a run is on: the game then lists the run's spells
  local ph = AzlPhase()
  local on = (ph == "playing" or ph == "endless" or ph == "ready") and table.getn(AzlSpells()) > 0
  if not on then return end
  r.name:SetAlpha(0.6)
  r.ask:Show(); r.needed = true
end
-- each section on a dark panel with a rounded gold edge, behind its heading and its entries;
-- the head card warmer, in a brighter gold
function AzlTrackerPanels(pan, W)
  if type(tracker.panels) ~= "table" then tracker.panels = {} end
  local a = math.min(0.6, (TrackerDB().trackerAlpha or 0.35) + 0.15)
  for k = 1, math.max(table.getn(pan), table.getn(tracker.panels)) do
    local p = tracker.panels[k]
    if not p then
      p = CreateFrame("Frame", nil, tracker)
      p:SetFrameLevel(tracker:GetFrameLevel())   -- under the entries
      p:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
      })
      tracker.panels[k] = p
    end
    local s = pan[k]
    if s and s.b then
      p:ClearAllPoints()
      p:SetPoint("TOPLEFT", tracker, "TOPLEFT", 3, s.t + 1)
      p:SetPoint("BOTTOMRIGHT", tracker, "TOPLEFT", W - 3, s.b - 1)
      if s.card then
        p:SetBackdropColor(0.2, 0.12, 0.04, math.min(0.8, a + 0.2))
        p:SetBackdropBorderColor(1, 0.78, 0.32, 1)
      else
        p:SetBackdropColor(0.05, 0.035, 0.02, a)
        p:SetBackdropBorderColor(0.8, 0.6, 0.24, 0.75)
      end
      p:Show()
    else
      p:Hide()
    end
  end
end

RefreshTracker = function()
  if not tracker then BuildTracker() end
  -- locked during a run: clicks go through the window to the game (the lock itself, the
  -- level-ups, the choice of a build and a left-click on a section's heading still count)
  local through = AzlTrackerThrough()
  tracker:EnableMouse(not through)
  local list = WishEntries()
  local n = table.getn(list)
  local worn = WornNames()
  local ci = ClassInfo(PlayerClass())
  tracker.title:SetText(AzT("Wishlist") .. " - |cff" .. ci.color .. AzG(ci.name) .. "|r")
  -- the game's own class symbol, as its character creation shows it
  local tc = Azerloot_ClassCoords[PlayerClass()] or Azerloot_ClassCoords.warrior
  tracker.emblem:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
  tracker.emblem:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
  -- two sections: the run's jewelry, then the boss loot for the collection
  local jewelry, loot, spells = {}, {}, {}
  for i = 1, n do
    if list[i].kind == "LootItem" then table.insert(loot, list[i])
    elseif list[i].kind == "Spell" then table.insert(spells, list[i])
    else table.insert(jewelry, list[i]) end
  end
  -- the class amulet the hero wears shows too, even when it is not on the wishlist
  local wk = WornAmuletKey()
  if wk then
    local have = false
    for i = 1, table.getn(jewelry) do
      if jewelry[i].kind == "Legendary" and jewelry[i].item.key == wk then have = true end
    end
    for i = 1, table.getn(ci.spells) do
      if not have and ci.spells[i].key == wk then
        table.insert(jewelry, { kind = "Legendary", item = ci.spells[i], class = ci, extra = true })
        n = n + 1
      end
    end
  end
  -- and every other ring, trinket and amulet the hero wears, wished for or not: checked,
  -- with what it gives now and its rank
  AzlAddWorn(jewelry, wk)
  -- the amulet on top, then the rings, then the trinkets (each kept in its own order)
  local RANK = { Amulets = 1, Legendary = 1, Rings = 2, Trinkets = 3 }
  for i = 1, table.getn(jewelry) do jewelry[i].trackOrder = i end
  table.sort(jewelry, function(a, b)
    local ra, rb = RANK[a.kind] or 4, RANK[b.kind] or 4
    if ra ~= rb then return ra < rb end
    return a.trackOrder < b.trackOrder
  end)
  n = table.getn(jewelry) + table.getn(spells) + table.getn(loot)
  local lines = {}
  local function Section(title, entries, label)
    if table.getn(entries) == 0 then return end
    -- a section folded by a click on its heading keeps its heading and count only
    local folded = type(TrackerDB().fold) == "table" and TrackerDB().fold[title]
    table.insert(lines, { header = AzT(label or title), sign = AZL_TRACK_SIGNS[title], count = AzlSectionCount(title, entries), key = title, folded = folded, entries = entries })
    if folded then return end
    for i = 1, table.getn(entries) do table.insert(lines, { entry = entries[i] }) end
  end
  -- the run's spells first, then its jewelry, last the boss loot for the collection
  Section("Spells", spells)
  Section("Jewelry", jewelry)
  Section("Loot", loot, "Boss Loot")
  tracker.spells = table.getn(spells) > 0
  local pan = {}
  local y = -35   -- under the title, with room to breathe
  local W = TrackerDB().trackerW or TRACK_W
  local cardBuild = nil
  local waiting = AzlStoredLevels() or 0
  if waiting > 0 then y = -54 end   -- the level-ups' own line in the head card
  -- the level-ups first: the build's bar makes room for them
  local lvb = tracker.levels
  if waiting > 0 then
    lvb.text:SetText(AzT("Level Up! (%d)", waiting))
    lvb:SetWidth((lvb.text:GetStringWidth() or 60) + 4)
    lvb:Show()
  else
    lvb:Hide()
  end
  if AzlB then y, cardBuild = AzlB.TrackerHead(tracker, W, y) end
  -- a new run's choice of a build stands alone: the lists come once a build is chosen (or
  -- the choice is closed, or two minutes have passed)
  local runPick = AzlB and AzlB.RunPick and AzlB.RunPick() and true or false
  if runPick then lines = {} end
  local cardBottom, below, hinted = AzlTrackerCard(cardBuild, ci, waiting)
  if cardBuild or hinted then y = below end
  -- the head card itself takes a click: the choice of a build opens under it
  local pb = tracker.pickBtn
  if pb then
    pb:ClearAllPoints()
    pb:SetPoint("TOPLEFT", tracker, "TOPLEFT", 4, -4)
    -- (the title and the line under it only: the build's gems and the level-ups below keep
    -- their own clicks)
    pb:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT", -30, (cardBuild and -46) or (hinted and -40) or -26)
    if AzlB and AzlB.Count and AzlB.Count(PlayerClass()) > 0 then pb:Show() else pb:Hide() end
  end
  -- the head card on its own panel, like the sections below it
  table.insert(pan, { t = -4, b = cardBottom, card = true })
  -- the boss warner's strip (modules\BossWarn.lua) under the head: the next boss, or the one
  -- alive with its health; on its own panel, like a section (under a run's choice of a build
  -- too: a run started without one still has its boss timer)
  if AzlW and AzlW.StripPlace then
    local sh = AzlW.StripPlace(tracker, W, y - 4, false)
    if sh > 0 then
      table.insert(pan, { t = y, b = y - 4 - sh - 4 })
      y = y - 4 - sh - 4 - 6
    end
  end
  tracker:SetWidth(W)
  local alpha = TrackerDB().trackerAlpha or 0.35
  tracker:SetBackdropColor(0, 0, 0, alpha)
  tracker:SetBackdropBorderColor(0.8, 0.62, 0.28, math.min(1, alpha + 0.4))   -- a warm gold frame, as the book's
  for i = 1, math.max(table.getn(lines), table.getn(trackerRows)) do
    local r = TrackerRow(i)
    -- (headings stay for a left-click that folds them; their right-click waits for the lock)
    local isHead = (lines[i] and lines[i].header) and true or false
    r:EnableMouse((not through) or isHead)
    if through and isHead then r:RegisterForClicks("LeftButtonUp")
    else r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r:SetWidth(W - 12); r.name:SetWidth(W - 55); r.bonus:SetWidth(W - 55)
    local l = lines[i]
    r:ClearAllPoints()
    r.bonus:Hide()
    r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", r, "LEFT", 3, 0)
    r.name:ClearAllPoints(); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    if l and l.header then
      r.entry = nil
      r.icon:Hide(); r.check:Hide(); r.cross:Hide(); r.name:Hide(); r.strike:Hide()
      r.rank:Hide(); r.rankGlow:Hide(); r.rankLevel = 0
      for k = 1, 8 do r.rankRim[k]:Hide() end
      r.head:SetText(l.header); r.head:Show(); r.line:Hide(); r.band:Show(); r.status:Hide(); r.ask:Hide(); r.needed = false
      r.foldKey, r.folded, r.sectionEntries = l.key, l.folded, l.entries
      r.head:SetAlpha(l.folded and 0.6 or 1)
      -- a right-click on the heading asks first: a second one within 3 seconds clears it
      if AzlTrackClear and AzlTrackClear.key == l.key and GetTime() < AzlTrackClear.till then
        r.head:SetText(AzT("Right-click again to clear"))
      end
      r.count:SetText(l.count or ""); r.count:Show()
      r.sign:SetTexture(l.sign); r.sign:Show(); r.signL:SetTexture(l.sign); r.signL:Show()
      -- the waiting level-ups on the first heading only; none (or the setting off): nothing
      local sl = 0   -- (the waiting level-ups have their place in the head card now)
      if sl and sl > 0 then
        r.levels.text:SetText(AzT("Level Up! (%d)", sl))
        r.levels:SetWidth((r.levels.text:GetStringWidth() or 60) + 4)
        r.levels:Show()
      else
        r.levels:Hide()
      end
      AzlHeadLines(r, W - 12)
      -- the section before ends 6 pixels under its last entry, then a little gap
      if pan.cur then pan.cur.b = y - 6 end
      if i > 1 then y = y - 11 end
      -- each section on its own dark panel
      pan.cur = { t = y + 3 }
      table.insert(pan, pan.cur)
      r:SetHeight(TRACK_HEAD)
      r:SetPoint("TOPLEFT", tracker, "TOPLEFT", 6, y)
      y = y - TRACK_HEAD - 1 - 3   -- 3 pixels free under the line
      r:Show()
    elseif l then
      r.levels:Hide()
      local e = l.entry
      r.entry = e
      r.foldKey, r.longText = nil, nil
      r.cross:Hide(); r.missed = false
      local away = AzlOutOfReach(e, worn, wk)
      r.head:Hide(); r.line:Hide(); r.sign:Hide(); r.signL:Hide(); r.icon:Show(); r.name:Show()
      r.sideLines[1]:Hide(); r.sideLines[2]:Hide()
      r.band:Hide(); r.count:Hide(); r.status:Hide(); r.ask:Hide(); r.needed = false
      r.icon:SetTexture("Interface\\Icons\\" .. (e.item.icon or "INV_Misc_QuestionMark"))
      local title, col = EntryTitle(e)
      if e.kind == "Legendary" then title = title .. " (" .. AzG(e.item.name) .. ")" end
      local rank
      if e.kind == "Spell" then
        -- the spell's rank in this run, as the game counts it: one up with every upgrade
        rank = AzlSpellRank(e.item.key)
      end
      -- (jewelry shows no rank: the game does not raise one when a piece is upgraded)
      if e.kind == "LootItem" then
        -- where it drops and how likely, in grey brackets: every zone of a shared weapon
        local zs, seen = {}, {}
        local src = (e.sources and table.getn(e.sources) > 0) and e.sources or { { zone = e.zone } }
        for k = 1, table.getn(src) do
          local zn = AzG(src[k].zone.name)
          if not seen[zn] then
            seen[zn] = true
            -- and its chance per kill, in its colour from green (likely) to red (rare)
            table.insert(zs, zn .. " " .. Hex(ChanceColor(src[k].zone.chance)[1]) .. src[k].zone.chance .. "%|cff9d9d9d")
          end
        end
        title = title .. " |cff9d9d9d(" .. table.concat(zs, ", ") .. ")|r"
      end
      r.name:SetText(title); r.name:SetTextColor(col[1], col[2], col[3])
      AzlShowRank(r, rank, W)
      -- a name over two lines (a long name, a long language) gets the room of both
      local wrapped = (r.name:GetStringWidth() or 0) > W - 55
      local h = TRACK_ROW
      if wrapped then
        -- as many lines as the name takes (the client may tell its height a moment late), its
        -- first line beside the icon, the others below: never up into the line above
        h = math.max(TRACK_ROW, AzlTextHeight(r.name, r.name:GetWidth() or (W - 55)) + 6)
        r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 24, -3)
      end
      r.strike:ClearAllPoints(); r.strike:SetPoint("LEFT", r.name, "LEFT", -1, 0)
      if e.kind == "Spell" then
        -- a spell the hero has in this run gets the green check; its bonuses, read from the
        -- action bar, go under it
        local text = SpellLine(e.item.key)
        r.check:Hide(); r.name:SetAlpha(1); r.strike:Hide()
        if KnowsSpell(e.item.key) then
          r.check:Show()
        elseif not AzlSpellsFull() then
          AzlNeeded(r)
        else
          -- wished, but every spell place holds another spell: out of reach, crossed and struck
          r.missed = AZL_SLOT_FULL.spell
          r.cross:Show(); r.name:SetAlpha(0.45)
          r.strike:SetVertexColor(col[1], col[2], col[3]); r.strike:SetAlpha(0.7)
          r.strike:SetWidth(math.min((r.name:GetStringWidth() or 0) + 2, W - 55))
          r.strike:Show()
        end
        if text then
          r.bonus:SetText(text)
          r.bonus:SetTextColor(0.3, 1, 0.3)   -- the same green as the jewelry's lines
          r.bonus:Show()
          r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -1)
          h = 4 + AzlTextHeight(r.name, r.name:GetWidth() or (W - 55)) + AzlTextHeight(r.bonus, W - 55)
        end
      elseif away then
        -- every slot of its kind holds another piece: out of reach, crossed and struck
        r.missed = away
        r.check:Hide(); r.cross:Show(); r.name:SetAlpha(0.45)
        r.strike:SetVertexColor(col[1], col[2], col[3]); r.strike:SetAlpha(0.7)
        r.strike:SetWidth(math.min((r.name:GetStringWidth() or 0) + 2, W - 55))
        r.strike:Show()
      elseif IsFound(e, worn) and WornSlot(e) then
        -- worn: never struck, and what it gives now in green under its name; checked only
        -- when it was on the wishlist (a piece worn instead shows, but earns no check)
        tracker.spells = true
        if e.extra then r.check:Hide() else r.check:Show() end
        r.name:SetAlpha(1); r.strike:Hide()
        local text = WornLine(e)
        if text then
          local long = AzlNoEquip(text)
          text = AzlShortWorn(e, long)
          if text ~= long then r.longText = long end
          r.bonus:SetText("|cff4dff4d" .. string.gsub(text, "\n", "|r\n|cff4dff4d") .. "|r")
          r.bonus:Show()
          r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -1)
          h = 4 + AzlTextHeight(r.name, r.name:GetWidth() or (W - 55)) + AzlTextHeight(r.bonus, W - 55)
        end
      elseif IsFound(e, worn) then
        r.check:Show(); r.name:SetAlpha(0.45)
        r.strike:SetVertexColor(col[1], col[2], col[3]); r.strike:SetAlpha(0.7)
        r.strike:SetWidth(math.min((r.name:GetStringWidth() or 0) + 2, W - 55))
        r.strike:Show()
      else
        r.check:Hide(); r.name:SetAlpha(1); r.strike:Hide()
        if e.kind ~= "LootItem" then AzlNeeded(r) end
      end
      -- a name over two lines: the icon at the top; a loot name with its zone needs no line,
      -- any other is struck through its first line, not between the two
      if wrapped then
        r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -1)
        if e.kind == "LootItem" then r.strike:Hide()
        else
          r.strike:ClearAllPoints(); r.strike:SetPoint("LEFT", r.name, "TOPLEFT", -1, -7)
        end
      end
      -- the check sits beside the name, however many lines follow under it
      r.check:ClearAllPoints()
      r.check:SetPoint("RIGHT", r, "TOPRIGHT", -1, (h > TRACK_ROW) and -9 or -h / 2)
      r.cross:ClearAllPoints()
      r.cross:SetPoint("CENTER", r.check, "CENTER", 0, 0)
      r.status:ClearAllPoints()
      r.status:SetPoint("RIGHT", r, "TOPRIGHT", -2, (h > TRACK_ROW) and -9 or -h / 2)
      r.ask:ClearAllPoints()
      r.ask:SetPoint("CENTER", r.check, "CENTER", 0, 0)
      r:SetHeight(h)
      r:SetPoint("TOPLEFT", tracker, "TOPLEFT", 6, y)
      y = y - h
      r:Show()
    else
      r.entry = nil
      r:Hide()
    end
  end
  if pan.cur then y = y - 6; pan.cur.b = y end   -- room under the last entry too
  AzlTrackerPanels(pan, W)
  -- as long as you pulled it, but never shorter than its entries
  -- room for the corner grip; the size the player drew it to once the lists show (the choice
  -- of a build at a run's start stands alone, as tall as it needs)
  if runPick then tracker:SetHeight(-y + 14)
  else tracker:SetHeight(math.max(-y + 14, TrackerDB().trackerH or 0)) end
  AzlFitState.lines = table.getn(lines)
  AzlFitTracker()
  if (n > 0 or (AzlB and AzlB.TrackerWanted())) and TrackerDB().tracker then tracker:Show() else tracker:Hide() end
end

-- the spells' lines change during a run: the window and the open spell page follow once a second
local spellTicker = CreateFrame("Frame")
spellTicker:SetScript("OnUpdate", function()
  this.t = (this.t or 0) + (arg1 or 0)
  if this.t < 1 then return end
  this.t = 0
  local sl = AzlStoredLevels()
  if tracker and tracker:IsVisible() and (tracker.spells or sl ~= this.sl) then RefreshTracker() end
  this.sl = sl
  AzlLevelHud()
  if frame and frame:IsVisible() and not ui.flipping and state.module == "Spells" then Refresh() end
end)

-- ---------- the collection: boss loot the game reports ----------
-- When a boss drops a piece, the game writes "You receive loot: [piece] (New in your
-- collection!)" (or "already collected") in the player's language. The piece's name is
-- looked up in every language and ticked for good.
local gfind = string.gfind or string.gmatch
local function FindPiece(n)
  n = string.gsub(n, "^%s+", ""); n = string.gsub(n, "%s+$", "")
  local cls = PlayerClass()
  if LD.names[cls] and LD.names[cls][n] then return cls, LD.names[cls][n] end
  for c, t in pairs(LD.names) do
    if t[n] then return c, t[n] end
  end
end

local function NoteCollected(cls, en)
  local col = Collected(cls)
  if col[en] then return false end
  col[en] = true
  if Wish(cls)["loot:" .. en] then
    Print(AzT("%s is in your collection: ticked on your wishlist.", "|cff40ff40" .. AzG(en) .. "|r"))
  end
  return true
end

-- The gear the hero wears comes from the collection: every worn piece is collected.
-- Names are read in any language; head to ranged, the jewelry slots left out.
local GEAR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local function GearName(slot)
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
  if not link then return nil end
  local _, _, n = string.find(link, "%[(.-)%]")
  return n
end

function Azerloot_CheckGear()
  local changed = NoteAmulets()
  for i = 1, table.getn(GEAR_SLOTS) do
    local n = GearName(GEAR_SLOTS[i])
    if n then
      local cls, en = FindPiece(n)
      if cls and NoteCollected(cls, en) then changed = true end
    end
  end
  return changed
end

-- the game's own words for a piece new to the collection ("New in your collection!")
AZL_NEW_WORDS = { "new in your collection", "neu in deiner sammlung", "nouveau dans votre collection",
  "nuevo en tu colecci", "novo na sua cole" }
function AzlSaysNew(plain)
  local low = string.lower(plain or "")
  for i = 1, table.getn(AZL_NEW_WORDS) do
    if string.find(low, AZL_NEW_WORDS[i], 1, true) then return true end
  end
  return false
end
function Azerloot_NoteLoot(msg)
  if type(msg) ~= "string" or msg == "" then return end
  local plain = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
  plain = string.gsub(plain, "|r", "")
  plain = string.gsub(plain, "|H.-|h", "")
  plain = string.gsub(plain, "|h", "")
  local hit, changed = false, false
  for n in gfind(plain, "%[(.-)%]") do
    local cls, en = FindPiece(n)
    if cls then
      hit = true
      -- new to the collection: the game says so, or it was not in it yet
      local new = NoteCollected(cls, en)
      if new then changed = true end
      if AzlC then AzlC.Loot(cls, en, new or AzlSaysNew(plain)) end
    end
  end
  if not hit then
    -- no brackets: look for a whole piece name of the hero's class in the line
    local t = LD.names[PlayerClass()] or {}
    for n, en in pairs(t) do
      if string.len(n) >= 8 and string.find(plain, n, 1, true) then
        local new = NoteCollected(PlayerClass(), en)
        if new then changed = true end
        if AzlC then AzlC.Loot(PlayerClass(), en, new or AzlSaysNew(plain)) end
      end
    end
  end
  if changed then
    RefreshTracker()
    if frame and frame:IsVisible() then Refresh() end
  end
end

function Azerloot_Toggle()
  if not frame then Build() end
  if frame:IsVisible() then
    frame:Hide()
  else
    state.class = PlayerClass()
    Azerloot_CheckGear()
    frame:Show()
    Refresh()
  end
end

-- ---------- minimap button ----------
-- A round book on the minimap's edge: left-click opens the book, right-click a small menu,
-- drag it to move it round the edge. Square minimaps (SurvivorsDragonUi) get a square path.
local mmButton

local function SquareMinimap()
  local ok, loaded = pcall(IsAddOnLoaded, "SurvivorsDragonUi")
  return ok and loaded
end

-- until the player moves it: on the left, just above the game's own damage meter button
-- (that one sits a little under the middle of the left side, at about 197 degrees); on the
-- square map straight left, on the smaller round one a bit higher, so the two never touch
local function MinimapDB()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  if AzerlootDB.minimapAngle == nil or not AzerlootDB.minimapMoved then
    AzerlootDB.minimapAngle = SquareMinimap() and 180 or 170
  end
  return AzerlootDB
end

local function PlaceMinimapButton()
  local a = math.rad(MinimapDB().minimapAngle)
  local c, s = math.cos(a), math.sin(a)
  local half = (Minimap:GetWidth() or 140) / 2
  local x, y
  if SquareMinimap() then
    -- along the square border, a little outside it
    local r = half + 6
    local m = math.max(math.abs(c), math.abs(s))
    x, y = c * r / m, s * r / m
  else
    local r = half + 10
    x, y = c * r, s * r
  end
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function BuildMinimapButton()
  if not Minimap then return end
  mmButton = CreateFrame("Button", "AzerlootMinimapButton", Minimap)
  mmButton:SetWidth(31); mmButton:SetHeight(31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmButton:RegisterForDrag("LeftButton")
  -- the Azerloot book, already cut round
  local icon = mmButton:CreateTexture("AzerlootMinimapIcon", "ARTWORK")
  icon:SetWidth(21); icon:SetHeight(21)
  icon:SetPoint("CENTER", mmButton, "CENTER", 0, 1)
  icon:SetTexture(MEDIA .. "minimap_book.tga")
  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53); border:SetHeight(53)
  border:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 0, 0)
  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmButton:SetScript("OnClick", function()
    GameTooltip:Hide()
    if IsShiftKeyDown and IsShiftKeyDown() then Azerloot_LayoutMode(); return end
    if arg1 == "RightButton" and AzlSettings then AzlSettings.Toggle(); return end
    Azerloot_Toggle()
  end)
  mmButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("Azerloot", 1, 0.82, 0)
    GameTooltip:AddLine(AzT("Click: open or close the book"), 0.9, 0.9, 0.9)
    GameTooltip:AddLine(AzT("Right-click: settings"), 0.9, 0.9, 0.9)
    GameTooltip:AddLine(AzT("Shift-click: move the wishlist and the warnings"), 0.9, 0.9, 0.9)
    GameTooltip:AddLine(AzT("Drag: move round the minimap"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- dragging: the button follows the cursor round the minimap's edge
  mmButton:SetScript("OnDragStart", function()
    GameTooltip:Hide()
    this.dragging = true
  end)
  mmButton:SetScript("OnDragStop", function() this.dragging = nil end)
  mmButton:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local x, y = GetCursorPosition()
    local sc = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    local dx, dy = x / sc - cx, y / sc - cy
    local deg = math.deg((math.atan2 or math.atan)(dy, dx))
    if deg < 0 then deg = deg + 360 end
    local db = MinimapDB()
    db.minimapAngle, db.minimapMoved = deg, true
    PlaceMinimapButton()
  end)
  PlaceMinimapButton()
  -- always there: it is the way into the book and into moving the windows
  MinimapDB().minimapHidden = nil
  mmButton:Show()
end

-- Shift-click on the minimap button: the wishlist window opens unlocked and the three warning
-- places show an example; dragging moves them. Another Shift-click (or a click on an
-- example) ends it, and the wishlist gets its lock (and shown or not) back as it was.
AzlLayout = { on = false }   -- (a global: the file's main chunk has no locals left)
function Azerloot_LayoutMode(on)
  local L = AzlLayout
  if on == nil then on = not L.on end
  local db = TrackerDB()
  if on then
    if L.on then return end
    L.on, L.lock, L.shown = true, db.trackerLocked, db.tracker
    db.tracker = true
    db.trackerLocked = false
    TrackerLockLook(); RefreshTracker()
    if AzlW and AzlW.MoveMode then AzlW.MoveMode(true) end
    Print(AzT("Move the wishlist and the warnings, then Shift-click the minimap button again."))
  else
    if not L.on then return end
    L.on = false
    db.trackerLocked, db.tracker = L.lock, L.shown
    L.lock, L.shown = nil, nil
    TrackerLockLook(); RefreshTracker()
    if AzlW and AzlW.MoveMode and AzlW.moving then AzlW.MoveMode(false) end
  end
end

BINDING_HEADER_AZERLOOT = "Azerloot"
BINDING_NAME_AZERLOOT_TOGGLE = "Open or close Azerloot"

SLASH_AZERLOOT1 = "/azerloot"
SLASH_AZERLOOT2 = "/azl"
SlashCmdList["AZERLOOT"] = function(msg)
  msg = string.lower(msg or "")
  if AzlW and AzlW.Slash and AzlW.Slash(msg) then return end
  if msg == "worn" then
    -- what the game reports in the jewelry slots, to see why a piece does or does not tick
    for i = 1, table.getn(SLOTS) do
      local slot = SLOTS[i][1]
      local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
      local n
      if link then local _, _, x = string.find(link, "%[(.-)%]"); n = x end
      Print(SLOTS[i][2] .. " (" .. slot .. "): " .. (n and (n .. " -> " .. EnglishName(n)) or "empty") .. (tex and ("  [" .. IconKey(tex) .. "]") or ""))
    end
    local list, worn, found = WishEntries(), WornNames(), 0
    for i = 1, table.getn(list) do if IsFound(list[i], worn) then found = found + 1 end end
    Print(AzT("%d of %d wishlist entries ticked", found, table.getn(list)))
    -- the gear slots: each worn piece counts as collected
    for i = 1, table.getn(GEAR_SLOTS) do
      local n = GearName(GEAR_SLOTS[i])
      if n then
        local cls, en = FindPiece(n)
        Print("gear (" .. GEAR_SLOTS[i] .. "): " .. n .. " -> " .. (en and (en .. ", " .. cls) or "not a boss piece"))
      end
    end
    return
  end
  if msg == "probe" then
    -- what the game tells an addon about your spells: its own tables and the action bar tooltips
    local function Dump(v, depth)
      if type(v) ~= "table" then return tostring(v) end
      if depth > 2 then return "{...}" end
      local parts = {}
      for k, x in pairs(v) do table.insert(parts, tostring(k) .. "=" .. Dump(x, depth + 1)) end
      return "{" .. table.concat(parts, ", ") .. "}"
    end
    local names = {}
    for k in pairs(getfenv and getfenv(0) or _G) do
      if type(k) == "string" and string.find(k, "^AZS") then table.insert(names, k) end
    end
    table.sort(names)
    Print("game globals: " .. table.concat(names, ", "))
    local sn = type(AzerlootDB) == "table" and AzerlootDB.spellSnap
    Print("phase: " .. tostring(AZS_GetPhase and AZS_GetPhase()) .. ", book's phase: " .. tostring(AzlPhase())
      .. ", kept spells: " .. ((type(sn) == "table" and type(sn.list) == "table") and (table.getn(sn.list) .. " (" .. tostring(sn.phase) .. ")") or "none"))
    if type(AZS_SPELLS) == "table" then
      for i = 1, table.getn(AZS_SPELLS) do Print("AZS_SPELLS[" .. i .. "] " .. Dump(AZS_SPELLS[i], 0)) end
    else
      Print("AZS_SPELLS: " .. tostring(AZS_SPELLS))
    end
    local tip = AzerlootScanTip or CreateFrame("GameTooltip", "AzerlootScanTip", UIParent, "GameTooltipTemplate")
    local found = 0
    for slot = 1, 120 do
      if HasAction and HasAction(slot) then
        found = found + 1
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearLines()
        tip:SetAction(slot)
        local lines = {}
        for l = 1, tip:NumLines() or 0 do
          local L = getglobal("AzerlootScanTipTextLeft" .. l)
          local R = getglobal("AzerlootScanTipTextRight" .. l)
          local t = (L and L:GetText()) or ""
          if R and R:GetText() and R:IsShown() then t = t .. " || " .. R:GetText() end
          table.insert(lines, t)
        end
        local tex = GetActionTexture and GetActionTexture(slot) or "?"
        Print("slot " .. slot .. " [" .. tostring(tex) .. "]: " .. table.concat(lines, " / "))
        tip:Hide()
      end
    end
    Print(found .. " action slots in use")
    return
  end
  if msg == "lootlog" then
    -- every line the loot watcher sees, codes shown, to check what the game sends
    if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
    AzerlootDB.lootlog = not AzerlootDB.lootlog
    Print("loot log " .. (AzerlootDB.lootlog and "on: loot and system lines are shown here" or "off"))
    return
  end
  if msg == "collection" then
    local cls = PlayerClass()
    local all, have = LootEntries(cls), 0
    for i = 1, table.getn(all) do if Collected(cls)[all[i].item.name] then have = have + 1 end end
    Print(AzT("%s: %d of %d pieces in your collection", AzG(ClassInfo(cls).name), have, table.getn(all)))
    return
  end
  if msg == "layout" then Azerloot_LayoutMode(); return end
  if msg == "settings" or msg == "options" or msg == "config" then if AzlSettings then AzlSettings.Toggle() end; return end
  if msg == "reset" then
    Azerloot_ResetTracker()
    return
  end
  if msg == "tracker" then
    local db = TrackerDB()
    db.tracker = not db.tracker
    RefreshTracker()
    Print(AzT(db.tracker and "wishlist window shown" or "wishlist window hidden")
      .. ((db.tracker and table.getn(WishEntries()) == 0) and AzT(" (your wishlist is empty, so it waits for its first entry)") or "")
      .. AzT(". Lost it? /azl reset brings it back to its first place."))
  else
    Azerloot_Toggle()
  end
end

local watcher = CreateFrame("Frame", "AzerlootWatcher", UIParent)
local lastClass, lastPhase, seenPhase, tick = nil, nil, false, 0
watcher:RegisterEvent("VARIABLES_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
-- the lines a boss drop may arrive in; a client without one of them simply skips it
local LOOT_EVENTS = { "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_BOSS_EMOTE", "UI_INFO_MESSAGE" }
local isLoot = {}
for i = 1, table.getn(LOOT_EVENTS) do
  if pcall(watcher.RegisterEvent, watcher, LOOT_EVENTS[i]) then isLoot[LOOT_EVENTS[i]] = true end
end
watcher:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
    if not mmButton then BuildMinimapButton() end
    -- the PvP set in the hero's own faction's names and looks
    if LD.UseFaction and UnitFactionGroup and LD.UseFaction(UnitFactionGroup("player")) then
      for k in pairs(lootCache) do lootCache[k] = nil end
    end
  end
  if isLoot[event] then
    if type(AzerlootDB) == "table" and AzerlootDB.lootlog and type(arg1) == "string" then
      Print(event .. ": " .. string.gsub(arg1, "|", "||"))
    end
    Azerloot_NoteLoot(arg1)
    return
  end
  lastClass = PlayerClass()
  Azerloot_CheckGear()
  RefreshTracker()
  if frame and frame:IsVisible() then Refresh() end
end)

-- A new run begins when the game is "ready" again, or plays again after a run ended.
-- A /reload in the middle of a run keeps the marks.
local runOver = false
local function WatchRun()
  local ph = AzlPhase()
  if ph == lastPhase and seenPhase then return end
  lastPhase, seenPhase = ph, true
  if ph == "dead" or ph == "victory" then runOver = true; return end
  -- after a run's end the hero may fight on (endless): that is no new run, its clock goes on
  local fresh = true
  if runOver and ph ~= "ready" then
    local ok, t = pcall(function() return AZS_GetRunTime and AZS_GetRunTime() end)
    if ok and tonumber(t) and tonumber(t) > 5 then fresh = false end
  end
  if ph == "endless" or (runOver and not fresh) then runOver = false; return end
  if ph == "ready" or (runOver and ph == "playing") then
    runOver = false
    if type(AzerlootDB) == "table" then AzerlootDB.found = {}; AzerlootDB.jrank = {} end
    ForgetLearnedSpells()
    AzlDropCollectedLoot()
    if AzlB then AzlB.NewRun() end
    RefreshTracker()
    if frame and frame:IsVisible() then Refresh() end
  end
end
-- the hero's class can change between runs: show that class's wishlist
watcher:SetScript("OnUpdate", function()
  tick = tick + arg1
  if tick < 2 then return end
  tick = 0
  WatchRun()
  if AzlC then AzlC.Tick() end
  -- the screen's height in the interface's units changed (another resolution or scale,
  -- or the game's own change at a run's start): the wishlist window fits itself again
  local sh = UIParent:GetHeight()
  if type(sh) == "number" and sh ~= AzlLastScreenH then
    AzlLastScreenH = sh
    if AzlFitTracker then AzlFitTracker() end
  end
  if WishLearnedSpells() then
    RefreshTracker()
    if frame and frame:IsVisible() then Refresh() end
  end
  local c = PlayerClass()
  if c ~= lastClass then
    lastClass = c
    -- a different hero: the book follows with that class's wishlist and amulets
    state.class = c
    if frame and frame:IsVisible() then Refresh() end
    RefreshTracker()
  end
end)

-- ---------- for Builds.lua: the book's parts, read when they are used ----------
AZL = {
  state = state, ui = ui, D = D, LD = LD,
  Refresh = function() Refresh() end, RefreshTracker = function() RefreshTracker() end,
  Frame = function() return frame end, OnPage = function(f) OnPage(f) end,
  Font = Font, Tex = Tex, Heading = Heading, Engraved = Engraved, Carved = Carved, Highlight = Highlight,
  DropShadow = DropShadow, SetIcon = SetIcon, SetFace = SetFace, FadeIn = FadeIn, Go = Go, Print = Print, Hex = Hex,
  OpenSearchHit = OpenSearchHit, Faces = FACES, ApplyFaces = function() ApplyAllFaces() end,
  FaceKey = function(g) return FaceKey(g) end, HEAD_FONT = HEAD_FONT, FONT = FONT, Body = function() return BODY end,
  ForgetLearnedSpells = function() ForgetLearnedSpells() end,
  -- the wishlist window locked or open, as its own lock button does it
  SetTrackerLock = function(on)
    TrackerDB().trackerLocked = on and true or false
    TrackerLockLook(); RefreshTracker()
  end,
  Wish = Wish, WishKey = WishKey, ClassInfo = ClassInfo, PlayerClass = PlayerClass, ItemEntries = ItemEntries,
  ClassEntries = ClassEntries, SpellEntries = SpellEntries, IsFound = IsFound, KnowsSpell = KnowsSpell,
  SpellDesc = SpellDesc, EntryTitle = EntryTitle, EntrySections = EntrySections, AutoSpells = AutoSpells,
  WishLearnedSpells = WishLearnedSpells, WornNames = WornNames, SetCheck = SetCheck,
  INK = INK, INK_SOFT = INK_SOFT, INK_GOOD = INK_GOOD, MEDIA = MEDIA, GLOW = GLOW, RIBBON = RIBBON, WHITE = WHITE,
  FONT = FONT, HEAD_FONT = HEAD_FONT, ROWS = ROWS, RARITY_COLOR = RARITY_COLOR,
}

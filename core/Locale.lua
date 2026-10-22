-- Copyright (c) 2026 Kindagrey. All rights reserved. See LICENSE.txt.
-- Azerloot: the book's language. English, German, French, Spanish or Portuguese: the
-- languages whose every letter the book's fonts can show. "Auto" follows the game's
-- language when it is one of them, else English. The choice is read once per session;
-- choosing another language in the settings reloads the interface.
--   AzT(text, ...)  the book's own words (locales\Strings.lua), with %s filled in
--   AzG(text)       the game's words (locales\GameText.lua): names, values, effects

AZL_LANGS = {
  { code = "auto", label = "Auto (game language)" },
  { code = "en", label = "English" },
  { code = "de", label = "Deutsch" },
  { code = "fr", label = "Fran\195\167ais" },
  { code = "es", label = "Espa\195\177ol" },
  { code = "pt", label = "Portugu\195\170s" },
}
local OK = { en = true, de = true, fr = true, es = true, pt = true }
local CLIENT = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", ptBR = "pt", ptPT = "pt" }
local cur

-- The game's language, asked of the game itself: the name it gives a spell in its own
-- tooltip (Fireball, Feuerball, Boule de feu ...). The client's locale cannot be trusted
-- for this: it may say English while the game runs in German.
local function Probe()
  if not (CreateFrame and UIParent and Azerloot_GT) then return nil end
  if not AzerlootLangTip then CreateFrame("GameTooltip", "AzerlootLangTip", UIParent, "GameTooltipTemplate") end
  local tip = AzerlootLangTip
  local found
  local probes = { { 133, "Fireball" }, { 116, "Frostbolt" }, { 686, "Shadow Bolt" } }
  for i = 1, table.getn(probes) do
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    local ok = pcall(function() tip:SetHyperlink("enchant:" .. probes[i][1]) end)
    local fs = getglobal("AzerlootLangTipTextLeft1")
    local name = ok and fs and fs:GetText()
    tip:Hide()
    if type(name) == "string" and name ~= "" then
      if name == probes[i][2] then found = "en" end
      for lg, d in pairs(Azerloot_GT) do
        if d.exact and d.exact[probes[i][2]] == name then found = lg end
      end
      if found then return found end
      return "other"   -- a language the book does not have: English
    end
  end
  return nil
end

-- the language the book is shown in this session
function AzLang()
  if cur then return cur end
  if type(AzerlootDB) ~= "table" then return "en" end   -- not loaded yet: decide later
  local c = AzerlootDB.lang or "auto"
  if c ~= "auto" and OK[c] then cur = c; return cur end
  -- Auto: the game's language, asked of the game; else as found before; else the client's
  local p = Probe()
  if p then
    AzerlootDB.autoLang = OK[p] and p or "en"
    cur = AzerlootDB.autoLang
    return cur
  end
  local a = AzerlootDB.autoLang
  if a and OK[a] then cur = a; return cur end
  return (GetLocale and CLIENT[GetLocale()]) or "en"   -- not settled yet: asked again next time
end

-- decided as soon as the saved settings are there, before the book is first opened
local starter = CreateFrame and CreateFrame("Frame")
if starter then
  starter:RegisterEvent("VARIABLES_LOADED")
  starter:RegisterEvent("PLAYER_ENTERING_WORLD")
  starter:SetScript("OnEvent", function() if type(AzerlootDB) ~= "table" then AzerlootDB = {} end; AzLang() end)
end

-- the game's own language, whatever the book is set to (the warner's words on the screen
-- speak it, beside the game's own banners)
local gameCur
function AzGameLang()
  -- read off the names the game gives its bosses (modules\BossWarn.lua): the surest sign,
  -- as the game's spell tooltips may stay English while its own words are another language
  if type(AzerlootDB) == "table" and AzerlootDB.gameLang and OK[AzerlootDB.gameLang] then return AzerlootDB.gameLang end
  if gameCur then return gameCur end
  local p = Probe()
  if p then gameCur = OK[p] and p or "en"; return gameCur end
  if type(AzerlootDB) == "table" and AzerlootDB.autoLang and OK[AzerlootDB.autoLang] then return AzerlootDB.autoLang end
  return (GetLocale and CLIENT[GetLocale()]) or "en"
end
-- fn's words in another language than the book's (AzT, AzG and AzName follow it meanwhile)
function AzInLang(lg, fn)
  local keep = cur
  cur = lg
  local ok, a, b = pcall(fn)
  cur = keep
  if ok then return a, b end
  return nil
end

-- the game's language as the tooltips show it: remembered for "Auto" from the next session on
function AzNoteGameLang(lg)
  if type(AzerlootDB) ~= "table" or not lg then return end
  if OK[lg] then AzerlootDB.autoLang = lg else AzerlootDB.autoLang = "en" end
end

function AzT(s, a, b, c, d, e, f)
  local lg = AzLang()
  local t = s
  if lg ~= "en" then
    if Azerloot_UI and Azerloot_UI[lg] and Azerloot_UI[lg][s] then t = Azerloot_UI[lg][s]
    elseif a == nil then t = AzG(s) end   -- a word the game itself has (a slot, a category)
  end
  if a ~= nil then return string.format(t, a, b, c, d, e, f) end
  return t
end

-- the game's words: a whole text, or a text with values (its values put across too)
local memo = {}
local function G(s, d, depth)
  local _, _, lead, core, trail = string.find(s, "^(%s*)(.-)(%s*)$")
  if not core or core == "" then return s end
  if string.find(core, "^[%d%.,%%%+%-x]+$") then return s end
  local hit = d.exact[core]
  if hit then return lead .. hit .. trail end
  if depth < 4 then
    for i = 1, table.getn(d.tpl) do
      local t = d.tpl[i]
      local caps = { string.find(core, t[1]) }
      if caps[1] then
        local vals = {}
        for j = 1, table.getn(t[2]) do vals[t[2][j]] = G(caps[j + 2] or "", d, depth + 1) end
        local out = string.gsub(t[3], "{([%w_]+)}", function(nm) return vals[nm] or "" end)
        return lead .. out .. trail
      end
    end
  end
  return s
end

function AzG(s)
  if type(s) ~= "string" or s == "" then return s end
  local lg = AzLang()
  if lg == "en" then return s end
  local d = Azerloot_GT and Azerloot_GT[lg]
  if not d then return s end
  memo[lg] = memo[lg] or {}
  local m = memo[lg][s]
  if m then return m end
  -- a text of several lines or parts: each by itself
  local out
  if string.find(s, "\n") then
    local parts = {}
    for seg in (string.gfind or string.gmatch)(s .. "\n", "(.-)\n") do table.insert(parts, G(seg, d, 0)) end
    out = table.concat(parts, "\n")
  else
    out = G(s, d, 0)
    if out == s and string.find(s, ", ") then
      local parts = {}
      for seg in (string.gfind or string.gmatch)(s .. ", ", "(.-), ") do table.insert(parts, G(seg, d, 0)) end
      out = table.concat(parts, ", ")
    end
  end
  -- a line that begins with "the hits of ...": the game's words for the middle of a
  -- sentence, so its first letter is raised at the start of one
  if string.find(out, "^die Treffer ") or string.find(out, "^die kritischen ") or string.find(out, "^les coups ")
    or string.find(out, "^los golpes ") or string.find(out, "^os acertos ") then
    out = string.upper(string.sub(out, 1, 1)) .. string.sub(out, 2)
  end
  memo[lg][s] = out
  return out
end

-- a name the game may know (a spell, a class) or the book itself
function AzName(s)
  local t = AzG(s)
  if t == s then t = AzT(s) end
  return t
end

-- what a boss does, as the book writes it (data\BossLoot.lua): its few kinds of sentences
function AzAbility(s)
  if AzLang() == "en" or type(s) ~= "string" then return s end
  local _, _, a, b
  _, _, a = string.find(s, "^Casts (.-) at you from range, even while you keep your distance%.$")
  if a then return AzT("Casts %s at you from range, even while you keep your distance.", AzName(a)) end
  _, _, a = string.find(s, "^Strikes and stuns everything within (%d+) yd of it%. Keep your distance and let your spells do the work%.$")
  if a then return AzT("Strikes and stuns everything within %s yd of it. Keep your distance and let your spells do the work.", a) end
  _, _, a = string.find(s, "^Spins and cuts down everything within (%d+) yd of it%. Keep your distance%.$")
  if a then return AzT("Spins and cuts down everything within %s yd of it. Keep your distance.", a) end
  _, _, a = string.find(s, "^Roots everything within (%d+) yd of it in place%. Stay out of its reach%.$")
  if a then return AzT("Roots everything within %s yd of it in place. Stay out of its reach.", a) end
  _, _, a, b = string.find(s, "^Also casts (.-): (.-)%.$")
  if a then return AzT("Also casts %s: %s.", AzName(a), AzT(b)) end
  return AzT(s)
end

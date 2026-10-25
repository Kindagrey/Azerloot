-- Copyright (c) 2026 Kindagrey. All rights reserved. See LICENSE.txt.
-- Azerloot: the boss warner. During a run a small bar shows the boss alive now (its health
-- live from the game, with a gold mark at each health where it changes its tactics), or, with
-- none alive, how long until the next one comes. Big words in the middle of the screen say
-- when a boss is about to come and when it turns at one of its marks.
-- The bosses' attacks and turns come from data\BossLoot.lua (read from the game's code); the
-- living bosses and the schedule from the game's own addon lines (AZS_GetBosses,
-- AZS_GetUpcomingBosses).
-- The game's own banners (a boss entering, a pack hunting you, a guardian taking its lair
-- back, a stampede) come to an addon as CHAT_MSG_RAID_BOSS_EMOTE: while the warner is on, the
-- game's banners are switched off (its own setting "Show Banners", given back when the warner
-- is switched off or the game is left) and their words come in the warner's alert instead.

AzlW = {}
local W = AzlW
local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local bar   -- the boss bar (built on first use)

local function DB()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  return AzerlootDB
end
-- two parts, each switched on its own in the settings (Azerwarn): the big words, and the bar
function W.AlertsOn() local d = DB(); return d.bossWarn ~= false and d.bossAlerts ~= false end
function W.BarOn() local d = DB(); return d.bossWarn ~= false and d.bossBar ~= false end
function W.On() return W.AlertsOn() or W.BarOn() end

-- ---------- the bosses of the book, found by the name the game gives them ----------
local byName
local nameLangs = {}   -- a boss's name, as one language writes it -> the languages that do
local function Lookup(name)
  if not byName then
    byName = {}
    local zones = Azerloot_Loot and Azerloot_Loot.zones or {}
    for zi = 1, table.getn(zones) do
      local bosses = zones[zi].bosses or {}
      for bi = 1, table.getn(bosses) do
        local b = bosses[bi]
        b.zi, b.bi = zi, bi   -- (where its page is, for a click on the strip)
        byName[string.lower(b.name)] = b
        local ke = string.lower(b.name)
        nameLangs[ke] = nameLangs[ke] or {}; nameLangs[ke].en = true
        -- the same boss in each of the game's languages
        if type(Azerloot_GT) == "table" then
          for code, lg in pairs(Azerloot_GT) do
            local ex = type(lg) == "table" and lg.exact
            if type(ex) == "table" and type(ex[b.name]) == "string" and ex[b.name] ~= b.name then
              local kl = string.lower(ex[b.name])
              byName[kl] = b
              nameLangs[kl] = nameLangs[kl] or {}; nameLangs[kl][code] = true
            end
          end
        end
      end
    end
  end
  if type(name) ~= "string" then return nil end
  return byName[string.lower(name)]
end
W.Lookup = Lookup
-- the game's language, read off the names it gives its bosses (the schedule, a boss's
-- emote, a banner): a name only one language writes so tells which one the game speaks
function W.NoteLang(name)
  if type(name) ~= "string" or name == "" then return end
  Lookup(nil)
  local set = nameLangs[string.lower(name)]
  if not set then return end
  local only, n = nil, 0
  for lg in pairs(set) do only = lg; n = n + 1 end
  -- (an English name tells English only when every other language writes it otherwise)
  if n == 1 and only == "en" then
    local b = Lookup(name)
    for _, lg in ipairs({ "de", "fr", "es", "pt" }) do
      local ex = type(Azerloot_GT) == "table" and type(Azerloot_GT[lg]) == "table" and Azerloot_GT[lg].exact
      if not (b and type(ex) == "table" and type(ex[b.name]) == "string" and ex[b.name] ~= b.name) then return end
    end
  end
  if n == 1 and DB().gameLang ~= only then DB().gameLang = only end
end

-- a text of the warner follows the book's reading face (Settings - Font), like the book's own
-- (group "warn": the warnings' own face, Settings - Azerwarn - Font)
local function Face(fs, role, group)
  local f, size, fl = fs:GetFont()
  if AZL and AZL.SetFace and type(f) == "string" and type(size) == "number" then
    AZL.SetFace(fs, role or "body", f, size, type(fl) == "string" and fl or "", group)
  end
  return fs
end

-- After a reload the game sends the run's phase and clock again only when they change: the
-- phase then comes from the book's own snapshot (AzlPhase), the clock from the last one kept,
-- run on by the real time since
local function Phase()
  local ok, ph = pcall(function() return (AzlPhase and AzlPhase()) or (AZS_GetPhase and AZS_GetPhase()) end)
  return ok and ph or nil
end
local function RunTime()
  local ok, t = pcall(function() return AZS_GetRunTime and AZS_GetRunTime() end)
  t = ok and tonumber(t) or nil
  local d = DB()
  local now = time and time() or 0
  if t then
    d.runClock = { t = t, at = now }
    return t
  end
  local c = d.runClock
  if type(c) == "table" and tonumber(c.t) and tonumber(c.at) and now - c.at >= 0 and now - c.at < 900 then
    -- the clock runs only while the run is played: before the first step (ready), in a pause
    -- or a choice it stands, as the game's own does
    if Phase() ~= "playing" then c.at = now; return c.t end
    return c.t + (now - c.at)
  end
  return nil
end
W.RunTime = RunTime

local function Clock(s)
  s = math.max(0, math.floor((tonumber(s) or 0) + 0.5))
  return string.format("%d:%02d", math.floor(s / 60), s - 60 * math.floor(s / 60))
end

-- 2102344 -> "2.102.344" (or "2,102,344" in English)
local function Big(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local sep = (AzLang and AzLang() == "en") and "," or "."
  local out = ""
  while string.len(s) > 3 do out = sep .. string.sub(s, -3) .. out; s = string.sub(s, 1, -4) end
  return s .. out
end
-- a text's first sentence ("Sek. später" goes on: a sentence ends at a mark before a capital)
local function First(t)
  if type(t) ~= "string" then return "" end
  local s = string.find(t, "[%.!?]%s+%u")
  if s then return string.sub(t, 1, s) end
  return t
end

-- the warner's own words on the screen in the game's language, as the game's banners beside
-- them (the book itself may be set to another)
local function G(fn)
  if AzInLang and AzGameLang then return AzInLang(AzGameLang(), fn) end
  return fn()
end
W.G = G

-- a wounded boss's turn, as one short line
local function TurnText(ph)
  if ph.adds then return AzT("Calls in %s helpers.", ph.adds) end
  if ph.a and ph.a.kind == "stance" and AzlStanceText then return AzlStanceText(ph.a, true) end
  if ph.a then return AzT("New attack, %s.", AzlDangerName(ph.a)) end
  return ""
end

-- ---------- the words on the screen: three places ----------
-- The big words (bosses, guardians, waves, mechanics, the warner's own) high in the middle;
-- the small things (runes, magnets, caches, achievements) in a smaller place of their own,
-- low in the middle, and the guardians and the waves in orange under the boss's words. Each
-- player can move and size all three (Shift-click on the minimap button).
local alert   -- the big words' place (built on first use)
local boxes = {}
local BOX = {
  main = { name = "AzerlootBossAlert", w = 700, h = 92, big = 28, small = 15, icon = 42, wrap = 520, dur = 4, pos = "alertPos", size = "alertScale",
    point = { "TOP", "TOP", 0, -150 } },
  mid = { name = "AzerlootMidAlert", w = 600, h = 70, big = 22, small = 13, icon = 34, wrap = 480, dur = 3, pos = "midPos", size = "midScale",
    point = { "TOP", "TOP", 0, -262 } },
  small = { name = "AzerlootSmallAlert", w = 460, h = 58, big = 18, small = 12, icon = 26, wrap = 400, dur = 2.5, pos = "smallPos", size = "smallScale",
    point = { "BOTTOM", "BOTTOM", 0, 190 } },
}
local Show
-- the colours a player can give each of the three places (Settings - Azerwarn); first the
-- ones they had from the start: red for bosses, orange for guardians and waves, green for the rest
W.COLORS = {
  { key = "red", label = "Red", c = { 1, 0.18, 0.12 } },
  { key = "orange", label = "Orange", c = { 1, 0.55, 0.12 } },
  { key = "yellow", label = "Yellow", c = { 1, 0.88, 0.2 } },
  { key = "green", label = "Green", c = { 0.35, 1, 0.35 } },
  { key = "teal", label = "Turquoise", c = { 0.25, 0.95, 0.85 } },
  { key = "blue", label = "Blue", c = { 0.4, 0.68, 1 } },
  { key = "purple", label = "Purple", c = { 0.78, 0.5, 1 } },
  { key = "pink", label = "Pink", c = { 1, 0.5, 0.78 } },
  { key = "white", label = "White", c = { 1, 1, 1 } },
}
W.COLOR_KEY = { main = "warnColorMain", mid = "warnColorMid", small = "warnColorSmall" }
W.COLOR_FIRST = { main = "red", mid = "orange", small = "green" }
-- a place's colour: the key the player chose (or its first one), and its r, g, b
function W.ColourKey(kind)
  local k = DB()[W.COLOR_KEY[kind] or ""]
  for i = 1, table.getn(W.COLORS) do if W.COLORS[i].key == k then return k end end
  return W.COLOR_FIRST[kind] or "red"
end
function W.ColourOf(key)
  for i = 1, table.getn(W.COLORS) do if W.COLORS[i].key == key then return W.COLORS[i].c end end
  return W.COLORS[1].c
end
function W.Colour(kind) return W.ColourOf(W.ColourKey(kind)) end
-- the sounds a player can pick for a boss in 10 seconds, a boss's turn and a hero down
-- (Settings - Azerwarn); every one played from its file (the game's SoundEntries name each):
-- as named interface sounds the game cut them short, or lost them, in a busy fight. The
-- first is none at all.
W.SOUNDS = {
  { key = "off", label = "Off" },
  -- soft
  { key = "whisper", dur = 0.4, label = "Whisper", file = "Sound\\Interface\\iTellMessage.wav" },
  { key = "friend", dur = 1.5, label = "Friend online", file = "Sound\\Interface\\FriendJoin.wav" },
  { key = "quest", dur = 1.6, label = "Quest update", file = "Sound\\Interface\\iQuestUpdate.wav" },
  { key = "ping", dur = 1.6, label = "Map ping", file = "Sound\\Interface\\MapPing.wav", name = "MapPing" },
  -- clear
  { key = "raid", dur = 1.3, label = "Raid warning", file = "Sound\\Interface\\RaidWarning.wav", name = "RaidWarning" },
  { key = "ready", dur = 2.9, label = "Ready check", file = "Sound\\Interface\\ReadyCheck.wav", name = "ReadyCheck" },
  { key = "gong", dur = 2.2, label = "Auction house", file = "Sound\\Interface\\AuctionWindowOpen.wav", name = "AUCTIONWINDOWOPEN" },
  { key = "invite", dur = 2.8, label = "Invitation", file = "Sound\\Interface\\iPlayerInviteA.wav", name = "igPlayerInvite" },
  -- loud (only files the game's own archives hold play: these are in its patch.MPQ)
  { key = "flag", dur = 2.0, label = "Flag taken", file = "Sound\\Interface\\PVPFlagTakenMono.wav" },
  { key = "alarm", dur = 4.9, label = "Battle alarm", file = "Sound\\Interface\\PVPWarningAllianceMono.wav" },
  { key = "drums", dur = 4.9, label = "War drums", file = "Sound\\Interface\\OrcExploration.wav" },
}
-- which sound each call has: "soon" (a boss in 10 seconds), "turn" (a boss's phase) and
-- "down" (in co-op, a hero of the party down)
local SOUND_KEY = { soon = "soundSoon", turn = "soundTurn", down = "soundDown" }
W.SOUND_KEY = SOUND_KEY
function W.SoundPick(what)
  local k = DB()[SOUND_KEY[what] or ""] or "raid"
  for i = 1, table.getn(W.SOUNDS) do if W.SOUNDS[i].key == k then return W.SOUNDS[i], i end end
  -- a sound the list no longer has (or none yet): the raid warning
  for i = 1, table.getn(W.SOUNDS) do if W.SOUNDS[i].key == "raid" then return W.SOUNDS[i], i end end
  return W.SOUNDS[2], 2
end
-- (a sound with a file plays from it; one with only a name, by the game's name for it)
function W.PlaySoundOf(sd)
  if not sd or not (sd.file or sd.name) then return end
  local ok = sd.file and PlaySoundFile and pcall(PlaySoundFile, sd.file)
  if not ok and sd.name and PlaySound then pcall(PlaySound, sd.name) end
end
-- (true: the boss in 10 seconds, as before)
function W.Sound(what)
  if what == true then what = "soon" end
  W.PlaySoundOf((W.SoundPick(what)))
end
-- the next sound for a call, played at once to be heard
function W.NextSound(what)
  local _, i = W.SoundPick(what)
  local n = i + 1
  if n > table.getn(W.SOUNDS) then n = 1 end
  DB()[SOUND_KEY[what]] = W.SOUNDS[n].key
  W.PlaySoundOf(W.SOUNDS[n])
  return W.SOUNDS[n]
end
-- each place's size, as the player made it with the mouse wheel: from half to twice its own
local function Size(kind)
  local v = tonumber(DB()[BOX[kind].size]) or 1
  if v < 0.5 then v = 0.5 elseif v > 2 then v = 2 end
  return v
end
W.Size = Size
-- (a place is kept in the screen's own measure, its top in the middle: it grows and shrinks
-- from there; the frame's offsets are in its own, scaled measure)
local function Place(f)
  local c = BOX[f.kind]
  local p = DB()[c.pos]
  local sc = Size(f.kind)
  f:SetScale(sc)
  f:ClearAllPoints()
  if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then
    f:SetPoint("TOP", UIParent, "BOTTOMLEFT", p[1] / sc, p[2] / sc)
  else
    f:SetPoint(c.point[1], UIParent, c.point[2], c.point[3] / sc, c.point[4] / sc)
  end
end
-- a colour chosen in the settings: the places that exist take it at once
function W.ApplyColours()
  for kind in pairs(BOX) do
    local f = boxes[kind]
    if f and f.text then local c = W.Colour(kind); f.text:SetTextColor(c[1], c[2], c[3]) end
  end
end
-- while being moved: the example names the place's size
local function MoveText(f)
  local title = (f.kind == "main" and "Boss warnings") or (f.kind == "mid" and "Guardians and waves") or "Small notices"
  f.text:SetText(AzT(title) .. "  " .. math.floor(Size(f.kind) * 100 + 0.5) .. "%")
end
local function Box(kind)
  if boxes[kind] then return boxes[kind] end
  local c = BOX[kind]
  local f = CreateFrame("Button", c.name, UIParent)
  f.kind = kind
  f:SetFrameStrata("HIGH")
  f:SetWidth(c.w); f:SetHeight(c.h)
  local ic = f:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(c.icon); ic:SetHeight(c.icon)
  f.icon = ic
  local t = f:CreateFontString(nil, "OVERLAY")
  t:SetFont("Fonts\\MORPHEUS.TTF", c.big, "THICKOUTLINE")
  -- in the colour the player gave the place (danger red, guardians orange, the good things
  -- green, unless they chose others)
  local col = W.Colour(kind)
  t:SetTextColor(col[1], col[2], col[3])
  Face(t, "head", "warn")
  t:SetPoint("TOP", f, "TOP", math.floor(c.icon / 2) + 3, 0)
  f.text = t
  local s = f:CreateFontString(nil, "OVERLAY")
  s:SetFont("Fonts\\FRIZQT__.TTF", c.small, "OUTLINE")
  s:SetTextColor(1, 0.9, 0.65)
  Face(s, nil, "warn")
  s:SetPoint("TOP", t, "BOTTOM", 0, -4)
  s:SetWidth(c.wrap)   -- a long line wraps under the big words
  f.sub = s
  f.queue = {}
  f.left = 0
  -- while it is being moved: a dark box shows where it sits
  -- (and under its words, a quieter line on how to place it, only while being moved)
  local hint = f:CreateFontString(nil, "OVERLAY")
  hint:SetFont("Fonts\\FRIZQT__.TTF", c.small, "OUTLINE")
  hint:SetTextColor(0.7, 0.65, 0.55)
  Face(hint, nil, "warn")
  hint:SetPoint("TOP", s, "BOTTOM", 0, -6)
  hint:SetWidth(c.wrap)
  hint:Hide()
  f.hint = hint
  -- the dark box: room above the big words, and under the hint as much
  local box = f:CreateTexture(nil, "BACKGROUND")
  box:SetTexture(WHITE); box:SetVertexColor(0, 0, 0); box:SetAlpha(0.5)
  box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 10); box:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 10)
  box:SetPoint("BOTTOM", hint, "BOTTOM", 0, -10)
  box:Hide()
  f.box = box
  f:SetMovable(true); f:EnableMouse(false)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnDragStart", function() if W.moving then W.dragged = true; this:StartMoving() end end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local l, r, tp = this:GetLeft(), this:GetRight(), this:GetTop()
    local sc = Size(this.kind)
    if l and r and tp then DB()[BOX[this.kind].pos] = { (l + r) / 2 * sc, tp * sc } end
    Place(this)
  end)
  -- the mouse wheel while moving: larger or smaller, a tenth at a time
  f:SetScript("OnMouseWheel", function()
    if not W.moving then return end
    local v = Size(this.kind) + ((arg1 or 0) > 0 and 0.1 or -0.1)
    v = math.floor(v * 10 + 0.5) / 10
    if v < 0.5 then v = 0.5 elseif v > 2 then v = 2 end
    DB()[BOX[this.kind].size] = (v ~= 1) and v or nil
    Place(this)
    MoveText(this)
  end)
  f:SetScript("OnClick", function()
    if W.dragged then W.dragged = false; return end
    if arg1 == "RightButton" then
      DB()[BOX[this.kind].pos] = nil; DB()[BOX[this.kind].size] = nil
      Place(this); MoveText(this)
      return
    end
    W.MoveMode(false)
  end)
  f:SetScript("OnUpdate", function()
    if W.moving then return end
    this.left = (this.left or 0) - (arg1 or 0)
    -- words waiting behind these: they follow once these were read for 1.5 sec
    if table.getn(this.queue) > 0 and this.left <= BOX[this.kind].dur - 1.5 then
      local q = table.remove(this.queue, 1)
      Show(this, q[1], q[2], q[3], q[4])
      return
    end
    if this.left <= 0 then this:Hide(); return end
    -- in softly over 0.3 sec, out softly over its last 0.8 sec
    local shown = BOX[this.kind].dur - this.left
    this:SetAlpha(math.max(0, math.min(1, shown / 0.3, this.left / 0.8)))
  end)
  f:Hide()
  boxes[kind] = f
  if kind == "main" then alert = f end
  return f
end
W.Box = Box

Show = function(f, text, sub, icon, sound)
  f.live = nil
  f.text:SetText(text or "")
  f.sub:SetText(sub or "")
  Place(f)
  f.icon:ClearAllPoints()
  f.icon:SetPoint("RIGHT", f.text, "LEFT", -8, 0)
  if icon then f.icon:SetTexture("Interface\\Icons\\" .. icon); f.icon:Show() else f.icon:Hide() end
  f.left = BOX[f.kind].dur
  f:SetAlpha(0)   -- (it fades in: its OnUpdate brings it up)
  f:Show()
  if sound then W.Sound(sound) end
end

-- words for the screen: the big place, or the small one (low: a rune, a magnet, a cache, an
-- achievement); something said a moment ago is not covered at once, the new words wait their
-- turn (a sound only with a boss coming or turning: the other words come quietly)
-- (low: true for the small place, "mid" for the guardians' and the waves')
local function Alert(text, sub, icon, sound, low)
  local kind = (low == "mid" and "mid") or (low and "small") or "main"
  local f = Box(kind)
  if W.moving then return end   -- (being moved: the examples stay)
  local how = "shown"
  if f:IsShown() and (f.left or 0) > BOX[f.kind].dur - 1.5 then
    if table.getn(f.queue) < ((kind == "small") and 2 or 3) then table.insert(f.queue, { text, sub, icon, sound }); how = "queued"
    else how = "DROPPED" end
  end
  -- no room for the words: their sound is heard all the same
  if how == "DROPPED" and sound then W.Sound(sound) end
  if how ~= "shown" then return end
  Show(f, text, sub, icon, sound)
end
function W.ShowAlert(text, sub, icon, sound) Show(Box("main"), text, sub, icon, sound) end

function W.Place()
  for _, f in pairs(boxes) do Place(f) end
end
-- each player puts the words where he likes (Shift-click on the minimap button, or
-- /azl warnmove): both places show an example in a dark box to drag and to size with the
-- mouse wheel; a click ends it, a right-click puts that one back in its first place and size
function W.MoveMode(on)
  if on == nil then on = not W.moving end
  W.dragged = false
  if on then
    W.moving = true
    for _, kind in ipairs({ "main", "mid", "small" }) do
      local f = Box(kind)
      f.queue = {}
      MoveText(f)
      -- what shows here, then (quieter) how to place it
      f.sub:SetText(AzT((kind == "main" and "A boss coming and turning, its attacks and its defeat.")
        or (kind == "mid" and "Guardians coming, waking or slain, lairs filling, swarms, stampedes and walls of foes.")
        or "Runes picked up, magnets, caches and achievements."))
      -- (on one line where it fits: the example uses the box's whole width)
      f.sub:SetWidth(BOX[kind].w - 40); f.hint:SetWidth(BOX[kind].w - 40)
      f.hint:SetText(AzT("Drag: move · Mouse wheel: size · Click: done · Right-click: reset"))
      f.hint:Show()
      f.icon:Hide()
      f.box:Show()
      f:EnableMouse(true)
      f:EnableMouseWheel(true)
      f:SetAlpha(1); f:Show()
      Place(f)
    end
  else
    W.moving = false
    for _, f in pairs(boxes) do
      f.box:Hide()
      f.hint:Hide()
      f.sub:SetWidth(BOX[f.kind].wrap)
      f:EnableMouse(false)
      f:EnableMouseWheel(false)
      f:Hide()
    end
    -- ended by a click on an example: the wishlist's moving (Shift-click on the minimap
    -- button) ends with it
    if Azerloot_LayoutMode then Azerloot_LayoutMode(false) end
  end
end
W.Alert = Alert

-- ---------- the game's banners, in the warner's words ----------
local arrived = {}   -- boss name (lower case) -> when its coming was called out
local function Hud(shown)
  if not AZS_SetHudShown then return end
  pcall(AZS_SetHudShown, "banners", shown)
end
local function HudShown()
  if not AZS_IsHudShown then return true end
  local ok, v = pcall(AZS_IsHudShown, "banners")
  return not ok or v ~= false
end
-- the warner on: the game's banners off (only when they were on: a player who switched them
-- off in the game keeps them off); the warner off: given back
function W.Banners()
  if not AZS_SetHudShown then return end   -- (a game without the setting keeps its banners)
  local d = DB()
  if W.AlertsOn() then
    W.MuteEmoteFrame()
    if not d.bannersTaken and HudShown() then d.bannersTaken = true; Hud(false)
    elseif d.bannersTaken and not W.hid then Hud(false) end   -- (given back on leaving)
    W.hid = true
  elseif d.bannersTaken then
    d.bannersTaken = nil; Hud(true)
  end
end
-- the game's interface writes each of these words a second time, in the middle of the screen
-- (RaidBossEmoteFrame): quiet while the warner says them
local function MuteEmoteFrame()
  local f = RaidBossEmoteFrame
  if type(f) ~= "table" or f.azlMuted or type(f.AddMessage) ~= "function" then return end
  f.azlMuted = true
  local orig = f.AddMessage
  f.AddMessage = function(self, a, b, c, d, e)
    if W.AlertsOn() and DB().bannersTaken then return end
    return orig(self, a, b, c, d, e)
  end
end
W.MuteEmoteFrame = MuteEmoteFrame
-- the game's words for a guardian slain, in each of its languages: too long for the middle of
-- the screen, said shorter by the warner
local GUARD_SLAIN = {
  ["%s a fost ucis! Bârlogul lui dă comori și puterea lui, iar ceilalți gardieni devin mai puternici."] = true,
  ["%s est tué ! Son antre livre un trésor et sa force, et les autres gardiens deviennent plus forts."] = true,
  ["%s foi morto! O covil entrega tesouro e força, e os outros guardiões ficam mais fortes."] = true,
  ["%s ginie! Jego legowisko oddaje skarb i siłę, a pozostali strażnicy rosną w siłę."] = true,
  ["%s is slain! Its lair yields treasure and its strength, and the other guardians grow stronger."] = true,
  ["%s padl! Jeho doupě vydává poklad a jeho sílu a ostatní strážci sílí."] = true,
  ["%s wurde getötet! Sein Hort gibt Schätze und seine Stärke frei, und die anderen Wächter werden stärker."] = true,
  ["%s öldürüldü! İni hazinesini ve gücünü bırakıyor, diğer muhafızlar güçleniyor."] = true,
  ["%s загинув! Його лігво дає скарби і його силу, а інші вартові стають сильнішими."] = true,
  ["%s повержен! Его логово отдаёт сокровище и его силу, а остальные стражи становятся сильнее."] = true,
  ["%s 처치되었습니다! 소굴이 보물과 힘을 내주고, 다른 수호자들이 강해집니다."] = true,
  ["%sが倒れた！その巣穴から宝と力が得られ、他の守護者たちは強くなる。"] = true,
  ["%s被击杀了！它的巢穴交出了财宝和力量，其他守护者变得更强。"] = true,
  ["¡%s ha caído! Su guarida entrega su tesoro y su fuerza, y los demás guardianes se hacen más fuertes."] = true,
}
-- what was told of whom, a moment ago, and by which way: the game's banner and its emote of
-- the same thing are told once; two emotes of one sender (a guardian's shards and its wards
-- in the same moment) are both told
local said, saidBy = {}, {}
local function Said(who, by)
  if type(who) ~= "string" or who == "" then return false end
  local k = string.lower(who)
  if said[k] and GetTime() - said[k] < 3 and saidBy[k] ~= by then return true end
  said[k], saidBy[k] = GetTime(), by
  return false
end

local REVIVE_ICON = "Spell_Holy_Resurrection"
-- The game's banners, as it sends them to addons (since its update of 21 October): every one,
-- bosses, guardians, achievements, zones, magnets, caches and runes, with its text in the
-- player's language, even while its own banners are hidden
function W.OnBanner(b)
  if type(b) ~= "table" or type(b.text) ~= "string" or b.text == "" then return end
  W.NoteLang(b.name)
  if not W.AlertsOn() or not DB().bannersTaken then return end
  if b.name and b.name ~= "" and Said(b.name, "banner") then return end
  local text, rest = b.text, nil
  -- a rune: "Restoration Rune picked up!" (the game says only its name)
  if b.kind == "rune" and b.name and b.name ~= "" then
    text = G(function() return AzT("%s picked up!", b.name) end) or text
  end
  if string.len(text) > 70 then
    local first = First(text)
    if first ~= text then
      rest = string.gsub(string.sub(text, string.len(first) + 1), "^%s+", "")
      text = first
    end
  end
  -- co-op: a friend down (by name, in the game's words), the hero down, the hero back up
  if b.kind == "frienddown" or b.kind == "downed" then
    -- "Anna is down!" big, what to do about it under it
    if not rest then
      local first = First(text)
      if first ~= text then
        rest = string.gsub(string.sub(text, string.len(first) + 1), "^%s+", "")
        text = first
      end
    end
    Alert(text, rest, REVIVE_ICON, "down")
    return
  elseif b.kind == "revived" then
    Alert(text, rest, REVIVE_ICON, nil, true)
    return
  end
  local boss = b.boss and Lookup(b.name) or nil
  if boss then arrived[string.lower(b.name)] = GetTime() end
  local low = b.kind == "rune" or b.kind == "magnet" or b.kind == "cache" or b.kind == "achievement"
  if b.kind == "guardian" then low = "mid" end
  Alert(text, rest, boss and boss.icon or nil, nil, low)
end
W.banners = false
if AZS_RegisterBannerHandler then
  W.banners = pcall(AZS_RegisterBannerHandler, function(b) W.OnBanner(b) end) and true or false
end

-- (and a guardian taking its lair again)
local MID_TEXTS = {
  ["%s claims its lair once more."] = true,
  ["%s beansprucht seinen Hort erneut."] = true,
  ["%s reprend son antre."] = true,
  ["%s reclama su guarida una vez más."] = true,
  ["%s toma o covil de volta."] = true,
  ["%s approaches!"] = true,
  ["%s approche !"] = true,
  ["%s naht!"] = true,
  ["%s se aproxima!"] = true,
  ["A stampede charges through!"] = true,
  ["A wall of foes closes in!"] = true,
  ["Der Ansturm endet nie..."] = true,
  ["Ein Schwarm umzingelt dich!"] = true,
  ["Eine Stampede prescht heran!"] = true,
  ["Eine Wand aus Feinden rückt näher!"] = true,
  ["L'assaut ne finit jamais..."] = true,
  ["La embestida no termina nunca..."] = true,
  ["La nuée vous encercle !"] = true,
  ["O ataque nunca termina..."] = true,
  ["O enxame cerca você!"] = true,
  ["Swarm surrounds you!"] = true,
  ["The onslaught never ends..."] = true,
  ["Uma debandada atravessa o campo!"] = true,
  ["Uma muralha de inimigos se aproxima!"] = true,
  ["Un mur d'ennemis se referme !"] = true,
  ["Une ruée traverse le champ !"] = true,
  ["¡%s se acerca!"] = true,
  ["¡Un enjambre te rodea!"] = true,
  ["¡Un muro de enemigos se acerca!"] = true,
  ["¡Una estampida arrasa el campo!"] = true,
}
local function Emote(text, who)
  W.NoteLang(who)
  if not W.AlertsOn() or not DB().bannersTaken or type(text) ~= "string" then return end
  -- (the same thing told by a banner a moment before, or after: once)
  if W.banners and Said(who, "emote") then return end
  if GUARD_SLAIN[text] then
    local t1, t2 = G(function() return AzT("%s is defeated!", tostring(who)), AzT("Lair looted, the other guardians grow stronger.") end)
    Alert(t1, t2, nil, nil, "mid")
    return
  end
  -- a guardian coming and the waves (a swarm, a stampede, a wall of foes): the orange place;
  -- so too any other words of the game's that name no one (a wave it may add later)
  local mid = MID_TEXTS[text] or not string.find(text, "%s", 1, true)
  if type(who) == "string" and who ~= "" then
    text = string.gsub(text, "%%s", (string.gsub(who, "%%", "%%%%")))
  end
  -- other long words (a text the game may add later): the first sentence large, the rest
  -- of it whole in the small line under it
  local rest
  if string.len(text) > 70 then
    local first = First(text)
    if first ~= text then
      rest = string.gsub(string.sub(text, string.len(first) + 1), "^%s+", "")
      text = first
    end
  end
  local b = Lookup(who)
  if b then
    -- a boss coming: its own call (from the bar, a moment before) is not said twice
    local k = string.lower(who)
    if arrived[k] and GetTime() - arrived[k] < 4 then return end
    arrived[k] = GetTime()
    Alert(text, rest, b.icon)
  else
    -- who sent it (a guardian, a pack), under the words when they do not name it
    local sub = rest
    if not sub and type(who) == "string" and who ~= "" and not string.find(text, who, 1, true) then sub = who end
    Alert(text, sub, nil, nil, mid and "mid" or nil)
  end
end
W.Emote = Emote
local emoteF = CreateFrame("Frame")
W.eventF = emoteF
emoteF:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
emoteF:RegisterEvent("PLAYER_LOGOUT")
emoteF:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
emoteF:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then
    -- the banners' setting is the game's own and outlives the addon: given back on leaving
    -- (taken again on the next start), so the game never stays without them
    if DB().bannersTaken then Hud(true) end
    return
  end
  if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    -- a boss down: the game's banner for it is off with the others, so the warner says it
    if W.banners or not W.AlertsOn() or not DB().bannersTaken or type(arg1) ~= "string" then return end
    local who = string.gsub(arg1, " dies%.$", "")
    local b = Lookup(who)
    if b then Alert(G(function() return AzT("%s is defeated!", AzG(b.name)) end), nil, b.icon) end
    return
  end
  Emote(arg1, arg2)
end)

-- ---------- the strip in the wishlist window ----------
-- One line under the window's head: the next boss and its time, or, with one alive, its name,
-- its health in percent and a thin bar of the book's own kind (red), with a gold mark at each
-- health where it turns. The full tale is in its tooltip; a click opens its page in the book.
-- It keeps to the wishlist window, so it never stands in the way of another addon's frames.
local hpb, stripBoss   -- the health bar, the boss the strip tells of
function W.Health() return hpb end
local function StripFrame()
  if bar then return bar end
  if not AzerlootTracker then return nil end
  bar = CreateFrame("Button", "AzerlootBossBar", AzerlootTracker)
  bar:SetHeight(24)
  local ic = bar:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(20); ic:SetHeight(20)
  ic:SetPoint("LEFT", bar, "TOPLEFT", 2, -12)
  ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  bar.icon = ic
  local nm = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nm:SetPoint("LEFT", ic, "RIGHT", 6, 0); nm:SetJustifyH("LEFT")
  nm:SetTextColor(1, 0.82, 0)
  Face(nm)
  bar.name = nm
  local info = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("RIGHT", bar, "TOPRIGHT", -3, -12)
  info:SetTextColor(1, 0.9, 0.75)
  Face(info)
  bar.info = info
  bar.marks = {}
  bar:RegisterForClicks("LeftButtonUp")
  bar:SetScript("OnClick", function() W.OpenPage(stripBoss) end)
  bar:SetScript("OnEnter", function() W.Tip(this) end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar:SetScript("OnUpdate", function() if W.Pulse then W.Pulse() end end)
  bar:Hide()
  return bar
end
W.Build = StripFrame

-- the thin health bar, made anew when the window's width changes (its marks are drawn
-- for one width)
local function HealthBar(w)
  if hpb and hpb.w == w then return hpb end
  if hpb then hpb:Hide() end
  local tr
  if AzlB and AzlB.XPBar then
    tr = AzlB.XPBar(bar, w, 6, { 0.82, 0.13, 0.08 })
  else
    tr = CreateFrame("Frame", nil, bar)
    tr:SetWidth(w); tr:SetHeight(6)
    local bg = tr:CreateTexture(nil, "BORDER"); bg:SetTexture(WHITE); bg:SetVertexColor(0.12, 0.08, 0.05); bg:SetAllPoints(tr)
    local fl = tr:CreateTexture(nil, "ARTWORK"); fl:SetTexture(WHITE); fl:SetVertexColor(0.72, 0.2, 0.14)
    fl:SetPoint("TOPLEFT", tr, "TOPLEFT", 0, 0); fl:SetHeight(6)
    tr.SetValue = function(self, v) fl:SetWidth(math.max(1, w * v)) end
  end
  tr.w = w
  tr:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 3, 5)
  -- (a child of the health bar: hidden with it, when the next boss is told instead)
  local mk = CreateFrame("Frame", nil, tr)
  mk:SetAllPoints(bar)
  mk:SetFrameLevel(tr:GetFrameLevel() + 3)
  tr.mk = mk
  for k = 1, table.getn(bar.marks) do bar.marks[k]:Hide() end
  bar.marks = {}
  for k = 1, 4 do
    local m = mk:CreateTexture(nil, "OVERLAY")
    m:SetTexture(WHITE); m:SetVertexColor(1, 0.84, 0.35); m:SetWidth(2); m:SetHeight(10)
    m:Hide(); bar.marks[k] = m
  end
  hpb = tr
  return tr
end

-- what the strip shows now: "boss", "next" or nothing (out of a run, or switched off)
W.mode = nil
function W.StripMode() return W.mode end
-- placed by the wishlist window under its head (core\Azerloot.lua): its height, 0 for none
function W.StripPlace(tracker, w, y, hidden)
  local s = StripFrame()
  if not s then return 0 end
  W.placed = W.mode
  if hidden or not W.mode then s:Hide(); return 0 end
  s:ClearAllPoints()
  s:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, y)
  s:SetWidth(w - 16)
  if W.mode == "boss" then HealthBar(w - 22); hpb:Show() elseif hpb then hpb:Hide() end
  s:SetHeight(W.mode == "boss" and 38 or 24)
  s:Show()
  W.Fill()
  return W.mode == "boss" and 38 or 24
end

-- the strip's words and bar from what the last look found
function W.Fill()
  if not bar or not bar:IsShown() then return end
  local c = W.cur or {}
  if c.mode == "boss" then
    local u, b = c.u, c.b
    local hp, hpm = tonumber(u.hp) or 0, tonumber(u.hpm) or 0
    local pct = hpm > 0 and hp / hpm or 0
    stripBoss = b
    bar.icon:SetTexture("Interface\\Icons\\" .. ((b and b.icon) or "INV_Misc_QuestionMark"))
    local info = string.format("%d%%", math.floor(pct * 100 + 0.5))
    if u.enraged then info = "|cffff4020" .. AzT("Enraged") .. "|r  " .. info end
    bar.info:SetText(info)
    bar.info:SetTextColor(1, 0.9, 0.75); bar.info:SetAlpha(1)
    W.FitName(b and AzG(b.name) or tostring(u.name), W.ShortName(b))
    local tr = hpb
    if tr then
      tr:SetValue(math.min(1, pct))
      local phases = (b and b.phases) or {}
      for k = 1, 4 do
        local ph = phases[k]
        if ph and bar.marks[k] then
          bar.marks[k]:ClearAllPoints()
          bar.marks[k]:SetPoint("CENTER", tr, "LEFT", math.floor(tr.w * ph.pct / 100), 0)
          bar.marks[k]:Show()
        elseif bar.marks[k] then bar.marks[k]:Hide() end
      end
    end
  elseif c.mode == "next" then
    local nb = c.nb
    local b = Lookup(nb.name)
    stripBoss = b
    bar.icon:SetTexture("Interface\\Icons\\" .. ((b and b.icon) or "INV_Misc_QuestionMark"))
    bar.info:SetText(Clock(nb.left))
    W.leftAt, W.left = GetTime(), nb.left
    local sn = W.ShortName(b)
    if not nb.name then
      -- (endless: the next boss's name is not told)
      bar.icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
      W.FitName(AzT("Next boss"), nil)
    else
      W.FitName(AzT("Next boss: %s", b and AzG(b.name) or tostring(nb.name)), sn and AzT("Next boss: %s", sn))
    end
  end
end

-- the short form of a long name: its own name without the title, in every language (the word
-- the boss is known by: first or last in the game's name), else nothing
local SHORT = {
  ["Morbent Fel"] = "first", ["Nimar the Slayer"] = "first", ["Alzzin the Wildshaper"] = "first",
  ["Jin'do the Hexxer"] = "first", ["Hakkar the Soulflayer"] = "first", ["Korrak the Bloodrager"] = "first",
  ["Ivus the Forest Lord"] = "first", ["Lokholar the Ice Lord"] = "first", ["Glacius the Frozen Titan"] = "first",
  ["Ossirian the Unscarred"] = "first", ["Noth the Plaguebringer"] = "first", ["Zevrim Thornhoof"] = "first",
  ["Tendris Warpwood"] = "first",
  ["Lord Hel'nurath"] = "last", ["Lord Falconcrest"] = "last", ["Lord Aliden Perenolde"] = "last",
  ["High Priestess Jeklik"] = "last", ["High Priest Venoxis"] = "last", ["Bloodlord Mandokir"] = "last",
  ["Houndmaster Loksey"] = "last", ["Scarlet Commander Mograine"] = "last", ["High Inquisitor Whitemane"] = "last",
  ["General Angerforge"] = "last", ["Emperor Dagran Thaurissan"] = "last", ["Majordomo Executus"] = "last",
  ["Princess Huhuran"] = "last", ["Warchief Rend Blackhand"] = "Rend",
}
function W.ShortName(b)
  if not b then return nil end
  local how, t = SHORT[b.name], AzG(b.name)
  if not how then return nil end
  if how == "first" then return (string.gsub(t, "[%s,].*$", "")) end
  if how == "last" then return (string.gsub(t, "^.*%s", "")) end
  return how
end

-- the name in the room left of the number: whole, else with the boss's short name ("Next boss:
-- Mograine"), else a little smaller, else shortened with "..." (it never runs into the time)
local nameSize
function W.FitName(text, short)
  local fs = bar.name
  local face, size, flags = fs:GetFont()
  if not nameSize then nameSize = size end
  if face and nameSize then fs:SetFont(face, nameSize, flags) end
  local room = (bar:GetWidth() or 200) - 34 - (bar.info:GetStringWidth() or 30)
  fs:SetText(text)
  if (fs:GetStringWidth() or 0) <= room then return end
  if short then fs:SetText(short); text = short end
  if (fs:GetStringWidth() or 0) <= room then return end
  if face and nameSize and AzlFitText then AzlFitText(fs, room, nameSize, nameSize - 1) end
  local n = string.len(text)
  while n > 4 and (fs:GetStringWidth() or 0) > room do
    n = n - 1
    -- (never in the middle of a letter of several bytes)
    while n > 4 and string.byte(text, n + 1) and string.byte(text, n + 1) >= 128 and string.byte(text, n + 1) < 192 do n = n - 1 end
    fs:SetText((string.gsub(string.sub(text, 1, n), "[%s,]+$", "")) .. "...")
  end
end

-- the time to the next boss turns from yellow (3 minutes and more) through orange (1:30) to
-- red (0:15), smoothly; from 1:30 on it pulses, and faster from 0:15 on
local function Lerp(a, b, f) return a + (b - a) * f end
function W.TimeColour(left)
  local Y, O, R = { 1, 0.82, 0 }, { 1, 0.5, 0.05 }, { 1, 0.16, 0.1 }
  local c
  if left >= 180 then c = Y
  elseif left >= 90 then local f = (180 - left) / 90; c = { Lerp(Y[1], O[1], f), Lerp(Y[2], O[2], f), Lerp(Y[3], O[3], f) }
  elseif left >= 15 then local f = (90 - left) / 75; c = { Lerp(O[1], R[1], f), Lerp(O[2], R[2], f), Lerp(O[3], R[3], f) }
  else c = R end
  -- the pulse: none before 1:30, growing in over the next 10 seconds; quicker and deeper at
  -- the end
  local amp, speed = 0, 4
  if left < 90 then amp = 0.3 * math.min(1, (90 - left) / 10) end
  if left < 15 then amp, speed = 0.45, 7 end
  return c, amp, speed
end
local function Pulse()
  if not bar or not bar:IsShown() or W.mode ~= "next" or not W.leftAt then return end
  local left = math.max(0, (W.left or 0) - (GetTime() - W.leftAt))
  local c, amp, speed = W.TimeColour(left)
  bar.info:SetTextColor(c[1], c[2], c[3])
  bar.info:SetAlpha(1 - amp * (0.5 + 0.5 * math.sin(GetTime() * speed)))
end
W.Pulse = Pulse

-- its tooltip: the boss, its health and next turn, every danger it has
function W.Tip(s)
  local c, b = W.cur or {}, stripBoss
  GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
  GameTooltip:AddLine(b and AzG(b.name) or (s.name:GetText() or ""), 1, 0.82, 0)
  if c.mode == "boss" then
    local u = c.u
    if (tonumber(u.hpm) or 0) > 0 then GameTooltip:AddLine(Big(u.hp) .. " / " .. Big(u.hpm), 1, 1, 1) end
    local pct = (tonumber(u.hpm) or 0) > 0 and (u.hp / u.hpm * 100) or 100
    local phases = (b and b.phases) or {}
    for k = 1, table.getn(phases) do
      if pct > phases[k].pct then
        GameTooltip:AddLine(AzT("At %d%%: %s", phases[k].pct, TurnText(phases[k])), 1, 0.78, 0.47, 1)
        break
      end
    end
  elseif c.mode == "next" then
    GameTooltip:AddLine(AzT("comes in %s", Clock(c.nb.left)), 1, 1, 1)
  end
  if b then
    local list = AzlDangerList and AzlDangerList(b) or {}
    for i = 1, table.getn(list) do
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(AzlDangerName(list[i]), 1, 0.82, 0)
      GameTooltip:AddLine(AzlDangerText(list[i]), 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(AzT("Click to open its page in the book."), 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- the boss's page in the book
function W.OpenPage(b)
  if not b or not b.zi or not AZL or not AZL.OpenSearchHit then return end
  if AzerlootFrame and not AzerlootFrame:IsShown() and Azerloot_Toggle then Azerloot_Toggle() end
  AZL.OpenSearchHit({ kind = "BossHit", zoneIndex = b.zi, bossIndex = b.bi })
end

-- ---------- every 0.2 sec ----------
-- each part only while it is switched on
local function Say(text, sub, icon, sound) if W.AlertsOn() then Alert(text, sub, icon, sound) end end
-- the strip shows "boss", "next" or nothing; a change of kind redraws the wishlist window,
-- which gives it its room
local function SetMode(mode, data)
  if not W.BarOn() then mode = nil end
  data.mode = mode
  W.cur = data
  W.mode = mode
  if W.placed ~= mode then
    if AZL and AZL.RefreshTracker then AZL.RefreshTracker() end
  else
    W.Fill()
  end
end
local seen = {}       -- per boss id: the turns already announced
local warned = {}     -- per schedule index: the 10-second warning given
local alive = {}      -- the boss ids seen alive, to announce one once
-- ---------- the guardians' lairs (the game's AZS_LAIRS) ----------
-- In the orange place: a guardian waking up, and an empty lair about to fill (10 sec.). What
-- is already so when first seen (a run joined late, a /reload) is not told.
W.lairSeen, W.lairWarn = {}, {}
local function LairSay(t) if W.AlertsOn() then Alert(t, nil, nil, nil, "mid") end end
function W.Lairs()
  local ok, lairs = pcall(function() return (AZS_GetLairs and AZS_GetLairs()) or AZS_LAIRS end)
  if not ok or type(lairs) ~= "table" then return end
  for i = 1, table.getn(lairs) do
    local l = lairs[i]
    local key = l.index or i
    local st, left, name = l.state, tonumber(l.left), l.name
    local prev = W.lairSeen[key]
    W.lairSeen[key] = st
    if type(name) == "string" and name ~= "" then
      if prev and prev ~= "awake" and st == "awake" then
        LairSay(G(function() return AzT("%s awakens!", name) end))
      end
      if st == "empty" and left and left > 0 and left <= 10 then
        if not W.lairWarn[key] then
          W.lairWarn[key] = true
          if prev then LairSay(G(function() return AzT("%s takes its lair in 10 sec.", name) end)) end
        end
      elseif st ~= "empty" or (left and left > 10) then
        W.lairWarn[key] = nil
      end
    end
  end
end

-- co-op: while the hero brings a friend back, or is being brought back, how far it is, in the
-- small place, kept up for as long as it goes on (the game's AZS_GetRevive)
function W.Revive()
  if not W.AlertsOn() or not AZS_GetRevive or W.moving then return end
  local ok, r = pcall(AZS_GetRevive)
  if not ok or type(r) ~= "table" then return end
  local rs, sh = tonumber(r.rshare), tonumber(r.share)
  local text
  if type(r.reviving) == "string" and r.reviving ~= "" and rs and rs > 0 and rs < 1 then
    text = G(function() return AzT("Bringing %s back: %d%%", r.reviving, math.floor(rs * 100)) end)
  elseif tonumber(r.down) == 1 and sh and sh > 0 and sh < 1 and type(r.by) == "string" and r.by ~= "" then
    text = G(function() return AzT("%s is bringing you back: %d%%", r.by, math.floor(sh * 100)) end)
  end
  if not text then return end
  local f = Box("small")
  -- a notice just shown there is read first
  if f:IsShown() and not f.live and (f.left or 0) > BOX.small.dur - 1.5 then return end
  if not (f:IsShown() and f.live) then Show(f, text, nil, REVIVE_ICON) end
  f.live = true
  f.text:SetText(text)
  if (f.left or 0) < 1.2 then f.left = 1.2 end
end

function W.Update()
  W.Revive()
  local ph = Phase()
  local running = ph == "playing" or ph == "ready" or ph == "paused" or ph == "choosing"
  if not running then
    SetMode(nil, {})
    seen, warned, alive = {}, {}, {}
    W.lairSeen, W.lairWarn = {}, {}
    return
  end
  if not W.On() then SetMode(nil, {}); return end
  W.Lairs()
  local okB, bosses = pcall(function() return AZS_GetBosses and AZS_GetBosses() end)
  bosses = okB and type(bosses) == "table" and bosses or {}
  if table.getn(bosses) > 0 then
    -- the most wounded first: the one being fought
    local u = bosses[1]
    for i = 2, table.getn(bosses) do
      local a = bosses[i]
      if (tonumber(a.hpm) or 0) > 0 and (tonumber(u.hpm) or 0) > 0 and a.hp / a.hpm < u.hp / u.hpm then u = a end
    end
    local b = Lookup(u.name)
    if not alive[u.id] then
      alive[u.id] = true
      -- marks it is already past when first seen (after a /reload) are not called out again
      local p0 = (tonumber(u.hpm) or 0) > 0 and (u.hp / u.hpm * 100) or 100
      local s0 = {}
      local ph0 = (b and b.phases) or {}
      for k = 1, table.getn(ph0) do if p0 <= ph0[k].pct - 1 then s0[k] = true end end
      seen[u.id] = s0
      local k = string.lower(tostring(u.name))
      -- (with the game's banners it tells a boss's coming itself)
      if not W.banners and not (arrived[k] and GetTime() - arrived[k] < 4) then
        arrived[k] = GetTime()
        Say(G(function() return AzT("%s is here!", b and AzG(b.name) or tostring(u.name)) end), nil, b and b.icon)
      end
    end
    -- its turns: a word as it comes close (5% before), the big words when it happens
    local pct = (tonumber(u.hpm) or 0) > 0 and (u.hp / u.hpm * 100) or 100
    local s = seen[u.id] or {}
    seen[u.id] = s
    local phases = (b and b.phases) or {}
    for k = 1, table.getn(phases) do
      local p = phases[k]
      if pct <= p.pct and not s[k] then
        s[k] = true
        local icon = p.a and p.a.icon or (p.adds and "Ability_Warrior_BattleShout") or nil
        -- a short hint with a sound (what it does is in the line's tooltip and the book)
        local t1, t2 = G(function() return AzT("%d%% health!", p.pct), TurnText(p) end)
        Say(t1, t2, icon, "turn")
      end
    end
    SetMode("boss", { u = u, b = b })
    return
  end
  local okU, up = pcall(function() return AZS_GetUpcomingBosses and AZS_GetUpcomingBosses() end)
  up = okU and type(up) == "table" and up or {}
  -- the game sends its schedule at a run's start and when it changes, not again after a
  -- /reload: the last one sent is kept, and used until the game sends a new one
  local now = RunTime() or 0
  local d = DB()
  -- (an empty schedule sent while the kept one still has bosses to come does not wipe it: the
  -- game may send its lines anew, before the schedule, after a reload)
  local kept = type(d.bossSched) == "table" and type(d.bossSched.list) == "table" and d.bossSched.list or {}
  local future = false
  for i = 1, table.getn(kept) do if tonumber(kept[i].at) and kept[i].at > now and now + 1 >= (tonumber(d.bossSched.t) or 0) then future = true end end
  if AZS_SCHEDULE_UPDATED and (table.getn(up) > 0 or not future) then
    local keep = {}
    for i = 1, table.getn(up) do
      local x = up[i]
      if tonumber(x.at) then table.insert(keep, { index = x.index, name = x.name, at = tonumber(x.at), final = x.final }) end
    end
    d.bossSched = { t = now, list = keep }
  elseif type(d.bossSched) == "table" and type(d.bossSched.list) == "table" and now + 1 >= (tonumber(d.bossSched.t) or 0) then
    up = {}
    for i = 1, table.getn(d.bossSched.list) do
      local x = d.bossSched.list[i]
      if tonumber(x.at) and x.at > now then
        table.insert(up, { index = x.index, name = x.name, at = x.at, left = x.at - now, final = x.final })
      end
    end
  end
  local nb
  for i = 1, table.getn(up) do
    local x = up[i]
    W.NoteLang(x.name)
    if tonumber(x.left) and (not nb or x.left < nb.left) then nb = x end
  end
  -- endless mode: no schedule, the bosses come back on a timer (the game's AZSRUN: nb seconds,
  -- nbn its name, empty there); told as a boss to come, by how many have come so far
  if not nb and type(AZS_RUN) == "table" and tonumber(AZS_RUN.endl) == 1 and tonumber(AZS_RUN.nb) and AZS_RUN.nb >= 0 then
    local nm = AZS_RUN.nbn
    if nm == "" then nm = nil end
    nb = { index = "endless" .. tostring(AZS_RUN.bs or ""), name = nm, left = AZS_RUN.nb, endless = true }
  end
  if nb then
    if nb.left <= 10 and nb.left > 0 and not warned[nb.index or nb.name] then
      warned[nb.index or nb.name] = true
      local b = Lookup(nb.name)
      if nb.name then
        Say(G(function() return AzT("%s in 10 sec.", b and AzG(b.name) or tostring(nb.name)) end), nil, b and b.icon, "soon")
      else
        Say(G(function() return AzT("A boss in 10 sec.") end), nil, nil, "soon")
      end
    end
    SetMode("next", { nb = nb })
  else
    SetMode(nil, {})
  end
end

function W.Slash(msg)
  if msg == "warnmove" then W.MoveMode(); return true end
  if msg == "bosstest" then
    Alert(AzT("%d%% health!", 70), AzT("New attack, %s.", AzName("Shadow Fissure")), "Spell_Shadow_CreepingPlague")
    return true
  end
  return false
end

local ticker = CreateFrame("Frame")
-- (the debugging logs of earlier versions, and their lines, are gone from the saved settings)
ticker:RegisterEvent("VARIABLES_LOADED")
ticker:SetScript("OnEvent", function()
  local d = DB()
  d.bossLog, d.bossLogOn, d.soundLogOn = nil, nil, nil
end)
local acc = 0
ticker:SetScript("OnUpdate", function()
  acc = acc + (arg1 or 0)
  if acc < 0.2 then return end
  acc = 0
  W.Banners()
  W.Update()
end)

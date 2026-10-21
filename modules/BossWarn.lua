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
-- "/azl bosslog" writes down for one run what else the game tells an addon in a fight (to
-- find out whether a boss's casts can be seen); the lines go to AzerlootDB.bossLog.

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
local function Face(fs, role)
  local f, size, fl = fs:GetFont()
  if AZL and AZL.SetFace and type(f) == "string" and type(size) == "number" then
    AZL.SetFace(fs, role or "body", f, size, type(fl) == "string" and fl or "")
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

-- ---------- the big words in the middle of the screen ----------
local alert
local function Alert(text, sub, icon, sound, low)
  if not alert then
    alert = CreateFrame("Button", "AzerlootBossAlert", UIParent)
    alert:SetFrameStrata("HIGH")
    alert:SetWidth(700); alert:SetHeight(80)
    local ic = alert:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(42); ic:SetHeight(42)
    alert.icon = ic
    local t = alert:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\MORPHEUS.TTF", 28, "THICKOUTLINE")
    t:SetTextColor(1, 0.55, 0.12)
    Face(t, "head")
    t:SetPoint("TOP", alert, "TOP", 24, 0)
    alert.text = t
    local s = alert:CreateFontString(nil, "OVERLAY")
    s:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    s:SetTextColor(1, 0.9, 0.65)
    Face(s)
    s:SetPoint("TOP", t, "BOTTOM", 0, -6)
    s:SetWidth(520)   -- a long line wraps under the big words
    alert.sub = s
    alert.queue = {}
    -- while it is being moved: a dark box shows where it sits
    local box = alert:CreateTexture(nil, "BACKGROUND")
    box:SetTexture(WHITE); box:SetVertexColor(0, 0, 0); box:SetAlpha(0.5); box:SetAllPoints(alert); box:Hide()
    alert.box = box
    alert:SetMovable(true); alert:EnableMouse(false)
    alert:RegisterForDrag("LeftButton")
    alert:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    alert:SetScript("OnDragStart", function() if W.moving then W.dragged = true; this:StartMoving() end end)
    alert:SetScript("OnDragStop", function()
      this:StopMovingOrSizing()
      local l, r, t = this:GetLeft(), this:GetRight(), this:GetTop()
      if l and r and t then DB().alertPos = { (l + r) / 2, t } end
      W.Place()
    end)
    alert:SetScript("OnClick", function()
      if W.dragged then W.dragged = false; return end
      if arg1 == "RightButton" then DB().alertPos = nil; W.Place(); return end
      W.MoveMode(false)
    end)
    alert:SetScript("OnUpdate", function()
      if W.moving then return end
      this.left = (this.left or 0) - (arg1 or 0)
      -- words waiting behind these: they follow once these were read for 1.5 sec
      if table.getn(this.queue) > 0 and this.left <= 2.5 then
        local q = table.remove(this.queue, 1)
        W.ShowAlert(q[1], q[2], q[3], q[4], q[5])
        return
      end
      if this.left <= 0 then this:Hide(); return end
      this:SetAlpha(math.min(1, this.left / 0.6))
    end)
  end
  if W.moving then return end   -- (being moved: the example stays)
  -- the small things (a rune, a magnet, a cache, an achievement) never keep the important
  -- ones (a boss, a guardian, a wave) waiting: they give way, and are left out when busy
  if alert:IsShown() and (alert.left or 0) > 2.5 then
    if low then return end
    if W.lowShown then W.ShowAlert(text, sub, icon, sound, low); return end
    for i = table.getn(alert.queue), 1, -1 do
      if alert.queue[i][5] then table.remove(alert.queue, i) end
    end
    if table.getn(alert.queue) < 3 then table.insert(alert.queue, { text, sub, icon, sound, low }) end
    return
  end
  W.ShowAlert(text, sub, icon, sound, low)
end
-- where the words stand: where the player put them, else high in the middle of the screen
function W.Place()
  if not alert then return end
  local p = DB().alertPos
  alert:ClearAllPoints()
  if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then
    alert:SetPoint("TOP", UIParent, "BOTTOMLEFT", p[1], p[2])
  else
    alert:SetPoint("TOP", UIParent, "TOP", 0, -150)
  end
end
-- each player puts the words where he likes (Settings - Azerwarn - Move warnings, or
-- /azl warnmove): they show as an example in a dark box to drag; a click ends it, a
-- right-click puts them back in their first place
function W.MoveMode(on)
  if on == nil then on = not W.moving end
  if on then
    Alert(" ")
    W.moving = true
    alert.queue = {}
    alert.text:SetText("Azerwarn")
    alert.sub:SetText(AzT("Drag to move. Click when done; right-click puts it back in its first place."))
    alert.icon:Hide()
    alert.box:Show()
    alert:EnableMouse(true)
    alert:SetAlpha(1); alert:Show()
    W.Place()
  elseif alert then
    W.moving = false
    alert.box:Hide()
    alert:EnableMouse(false)
    alert:Hide()
  end
end
-- (a sound only with a boss coming: the other words come quietly)
function W.ShowAlert(text, sub, icon, sound, low)
  alert.text:SetText(text or "")
  alert.sub:SetText(sub or "")
  W.Place()
  alert.icon:ClearAllPoints()
  alert.icon:SetPoint("RIGHT", alert.text, "LEFT", -10, 0)
  if icon then alert.icon:SetTexture("Interface\\Icons\\" .. icon); alert.icon:Show() else alert.icon:Hide() end
  alert.left = low and 2.5 or 4
  W.lowShown = low and true or false
  alert:SetAlpha(1)
  alert:Show()
  -- the raid warning's sound, played from its file: as a named interface sound the game cut
  -- it short in a busy fight
  if sound then
    local ok = PlaySoundFile and pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav")
    if not ok and PlaySound then pcall(PlaySound, "RaidWarning") end
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
-- what was told of whom, a moment ago: the game's banner and its emote of the same thing are
-- told once
local said = {}
local function Said(who)
  if type(who) ~= "string" or who == "" then return false end
  local k = string.lower(who)
  if said[k] and GetTime() - said[k] < 3 then return true end
  said[k] = GetTime()
  return false
end

-- The game's banners, as it sends them to addons (since its update of 21 October): every one,
-- bosses, guardians, achievements, zones, magnets, caches and runes, with its text in the
-- player's language, even while its own banners are hidden
function W.OnBanner(b)
  if type(b) ~= "table" or type(b.text) ~= "string" or b.text == "" then return end
  W.NoteLang(b.name)
  if not W.AlertsOn() or not DB().bannersTaken then return end
  if b.name and b.name ~= "" and Said(b.name) then return end
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
  local boss = b.boss and Lookup(b.name) or nil
  if boss then arrived[string.lower(b.name)] = GetTime() end
  local low = b.kind == "rune" or b.kind == "magnet" or b.kind == "cache" or b.kind == "achievement"
  Alert(text, rest, boss and boss.icon or nil, nil, low)
end
W.banners = false
if AZS_RegisterBannerHandler then
  W.banners = pcall(AZS_RegisterBannerHandler, function(b) W.OnBanner(b) end) and true or false
end

local function Emote(text, who)
  W.NoteLang(who)
  if not W.AlertsOn() or not DB().bannersTaken or type(text) ~= "string" then return end
  -- (the same thing told by a banner a moment before, or after: once)
  if W.banners and Said(who) then return end
  if GUARD_SLAIN[text] then
    Alert(G(function() return AzT("%s is defeated!", tostring(who)), AzT("Lair looted, the other guardians grow stronger.") end))
    return
  end
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
    Alert(text, sub)
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
    W.FitName(AzT("Next boss: %s", b and AzG(b.name) or tostring(nb.name)), sn and AzT("Next boss: %s", sn))
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
function W.Update()
  local ph = Phase()
  local running = ph == "playing" or ph == "ready" or ph == "paused" or ph == "choosing"
  if not running then
    SetMode(nil, {})
    seen, warned, alive = {}, {}, {}
    return
  end
  if not W.On() then SetMode(nil, {}); return end
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
        Say(t1, t2, icon, true)
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
  if nb then
    if nb.left <= 10 and nb.left > 0 and not warned[nb.index or nb.name] then
      warned[nb.index or nb.name] = true
      local b = Lookup(nb.name)
      Say(G(function() return AzT("%s in 10 sec.", b and AzG(b.name) or tostring(nb.name)) end), nil, b and b.icon, true)
    end
    SetMode("next", { nb = nb })
  else
    SetMode(nil, {})
  end
end

-- ---------- /azl bosslog: what the game tells an addon in a fight ----------
local LOG_EVENTS = {
  "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
  "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF", "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
  "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
  "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_RAID_BOSS_EMOTE",
  "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
  "SPELLCAST_START", "SPELLCAST_STOP", "UNIT_SPELLCAST_START", "PLAYER_TARGET_CHANGED", "CHAT_MSG_ADDON",
}
local logF
local function Log(line)
  local d = DB()
  if type(d.bossLog) ~= "table" then d.bossLog = {} end
  local t = AZS_GetRunTime and AZS_GetRunTime() or 0
  table.insert(d.bossLog, string.format("%7.1f  %s", tonumber(t) or 0, line))
  while table.getn(d.bossLog) > 1500 do table.remove(d.bossLog, 1) end
end
local lastUnits = ""
function W.StartLog()
  if not logF and AZS_RegisterBannerHandler then
    -- (the game's banners too, with their kind)
    pcall(AZS_RegisterBannerHandler, function(b)
      if DB().bossLogOn and type(b) == "table" then
        Log("banner " .. tostring(b.kind) .. " [" .. tostring(b.name) .. "]: " .. tostring(b.text))
      end
    end)
  end
  if not logF then
    logF = CreateFrame("Frame")
    for i = 1, table.getn(LOG_EVENTS) do pcall(logF.RegisterEvent, logF, LOG_EVENTS[i]) end
    -- and every other event that carries a sentence (the game's banners might come so)
    local listed = {}
    for i = 1, table.getn(LOG_EVENTS) do listed[LOG_EVENTS[i]] = true end
    if logF.RegisterAllEvents then pcall(logF.RegisterAllEvents, logF) end
    logF:SetScript("OnEvent", function()
      if not DB().bossLogOn then return end
      if not listed[event] then
        if type(arg1) ~= "string" or not string.find(arg1, "%a %a") or string.len(arg1) > 200 then return end
      end
      -- the hero's own hits, the pets' and the small foes' deaths fill the log too fast
      if type(arg1) == "string" and (string.find(arg1, "[Yy]our ") or string.find(event, "PET")
        or (string.find(event, "DEATH") and not Lookup((string.gsub(arg1, " dies%.$", ""))))) then return end
      if event == "CHAT_MSG_ADDON" then
        -- the game's own lines: only the bosses' (the rest come every moment)
        if arg1 == "AZSUNITS" and type(arg2) == "string" then
          local b = {}
          for e in string.gfind(arg2, "[^;]+") do
            if string.find(e, "^boss,") or string.find(e, "^final,") then table.insert(b, e) end
          end
          local s = table.concat(b, " | ")
          if s ~= lastUnits then lastUnits = s; if s ~= "" then Log("units: " .. s) end end
        elseif arg1 == "AZSBOSSES" then
          -- (the schedule, when it changes)
          local s = arg1 .. ": " .. tostring(arg2)
          if s ~= W.lastLine then W.lastLine = s; Log(s) end
        elseif arg1 and string.sub(arg1, 1, 3) ~= "AZS" then
          Log("addon " .. tostring(arg1) .. ": " .. tostring(arg2))
        end
        return
      end
      Log(event .. ": " .. tostring(arg1) .. (arg2 and ("  [" .. tostring(arg2) .. "]") or ""))
    end)
  end
end
function W.Slash(msg)
  if msg == "bosslog" then
    local d = DB()
    d.bossLogOn = not d.bossLogOn
    if d.bossLogOn then
      d.bossLog = {}
      W.StartLog()
      AZL.Print(AzT("Boss log on: fight a boss, then type /azl bosslog again and /reload. The lines are kept in your saved variables (AzerlootDB.bossLog)."))
    else
      AZL.Print(AzT("Boss log off: %d lines kept. /reload writes them to your saved variables.", table.getn(d.bossLog or {})))
    end
    return true
  end
  if msg == "warnmove" then W.MoveMode(); return true end
  if msg == "bosstest" then
    Alert(AzT("%d%% health!", 70), AzT("New attack, %s.", AzName("Shadow Fissure")), "Spell_Shadow_CreepingPlague")
    return true
  end
  return false
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function()
  acc = acc + (arg1 or 0)
  if acc < 0.2 then return end
  acc = 0
  if DB().bossLogOn then W.StartLog() end
  W.Banners()
  W.Update()
end)

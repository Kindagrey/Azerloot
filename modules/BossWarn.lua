-- Azerloot: the boss warner. During a run a small bar shows the boss alive now (its health
-- live from the game, with a gold mark at each health where it changes its tactics), or, with
-- none alive, how long until the next one comes. Big words in the middle of the screen say
-- when a boss is about to come and when it turns at one of its marks.
-- The bosses' attacks and turns come from data\BossLoot.lua (read from the game's code); the
-- living bosses and the schedule from the game's own addon lines (AZS_GetBosses,
-- AZS_GetUpcomingBosses).
-- "/azl bosslog" writes down for one run what else the game tells an addon in a fight (to
-- find out whether a boss's casts can be seen); the lines go to AzerlootDB.bossLog.

AzlW = {}
local W = AzlW
local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BAR_W = 300
local bar   -- the boss bar (built on first use)

local function DB()
  if type(AzerlootDB) ~= "table" then AzerlootDB = {} end
  return AzerlootDB
end
function W.On() return DB().bossWarn ~= false end

-- ---------- the bosses of the book, found by the name the game gives them ----------
local byName
local function Lookup(name)
  if type(name) ~= "string" then return nil end
  if not byName then
    byName = {}
    local zones = Azerloot_Loot and Azerloot_Loot.zones or {}
    for zi = 1, table.getn(zones) do
      local bosses = zones[zi].bosses or {}
      for bi = 1, table.getn(bosses) do
        local b = bosses[bi]
        byName[string.lower(b.name)] = b
        -- the same boss in each of the game's languages
        if type(Azerloot_GT) == "table" then
          for _, lg in pairs(Azerloot_GT) do
            local ex = type(lg) == "table" and lg.exact
            if type(ex) == "table" and type(ex[b.name]) == "string" then byName[string.lower(ex[b.name])] = b end
          end
        end
      end
    end
  end
  return byName[string.lower(name)]
end
W.Lookup = Lookup

local function Phase()
  local ok, ph = pcall(function() return AZS_GetPhase and AZS_GetPhase() end)
  return ok and ph or nil
end

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

-- a wounded boss's turn, as one short line
local function TurnText(ph)
  if ph.adds then return AzT("Calls in %s helpers.", ph.adds) end
  if ph.a then return AzT("New attack, %s.", AzName(ph.a.name)) end
  return ""
end

-- ---------- the big words in the middle of the screen ----------
local alert
local function Alert(text, sub, icon)
  if not alert then
    alert = CreateFrame("Frame", "AzerlootBossAlert", UIParent)
    alert:SetFrameStrata("HIGH")
    alert:SetWidth(700); alert:SetHeight(80)
    local ic = alert:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(42); ic:SetHeight(42)
    alert.icon = ic
    local t = alert:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\MORPHEUS.TTF", 28, "THICKOUTLINE")
    t:SetTextColor(1, 0.55, 0.12)
    t:SetPoint("TOP", alert, "TOP", 24, 0)
    alert.text = t
    local s = alert:CreateFontString(nil, "OVERLAY")
    s:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    s:SetTextColor(1, 0.9, 0.65)
    s:SetPoint("TOP", t, "BOTTOM", 0, -6)
    alert.sub = s
    alert:SetScript("OnUpdate", function()
      this.left = (this.left or 0) - (arg1 or 0)
      if this.left <= 0 then this:Hide(); return end
      this:SetAlpha(math.min(1, this.left / 0.6))
    end)
  end
  alert.text:SetText(text or "")
  alert.sub:SetText(sub or "")
  -- right under the boss bar, wherever it has been put: the game's own banners (a boss or
  -- a guardian coming, a stampede, a lair taken back) keep the middle of the screen
  if not bar and W.Build then W.Build() end
  alert:ClearAllPoints()
  if bar then alert:SetPoint("TOP", bar, "BOTTOM", 0, -10)
  else alert:SetPoint("TOP", UIParent, "TOP", 0, -200) end
  alert.icon:ClearAllPoints()
  alert.icon:SetPoint("RIGHT", alert.text, "LEFT", -10, 0)
  if icon then alert.icon:SetTexture("Interface\\Icons\\" .. icon); alert.icon:Show() else alert.icon:Hide() end
  alert.left = 4
  alert:SetAlpha(1)
  alert:Show()
  if PlaySound then pcall(PlaySound, "RaidWarning") end
end
W.Alert = Alert

-- ---------- the bar ----------
function W.Build()
  bar = CreateFrame("Frame", "AzerlootBossBar", UIParent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetWidth(BAR_W + 24); bar:SetHeight(64)
  bar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  bar:SetBackdropColor(0, 0, 0, 0.6)
  bar:SetBackdropBorderColor(0.8, 0.62, 0.28, 1)
  bar:SetClampedToScreen(true)
  bar:SetMovable(true); bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() if not DB().bossLocked then this:StartMoving() end end)
  bar:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local l, t = this:GetLeft(), this:GetTop()
    if l and t then DB().bossPos = { l, t - (UIParent:GetTop() or t) } end
    W.Anchor()
  end)
  local ic = bar:CreateTexture(nil, "ARTWORK")
  ic:SetWidth(30); ic:SetHeight(30)
  ic:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, -9)
  ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  bar.icon = ic
  local nm = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nm:SetPoint("TOPLEFT", ic, "TOPRIGHT", 8, 1)
  nm:SetTextColor(1, 0.82, 0)
  bar.name = nm
  local info = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -2)
  info:SetTextColor(0.85, 0.8, 0.7)
  bar.info = info
  -- the health bar: a dark trough, the fill, the marks
  local tr = bar:CreateTexture(nil, "BORDER")
  tr:SetTexture(WHITE); tr:SetVertexColor(0.12, 0.08, 0.05); tr:SetAlpha(0.95)
  tr:SetWidth(BAR_W); tr:SetHeight(14)
  tr:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -46)
  bar.trough = tr
  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(WHITE); fill:SetVertexColor(0.72, 0.2, 0.14)
  fill:SetHeight(12)
  fill:SetPoint("LEFT", tr, "LEFT", 1, 0)
  bar.fill = fill
  bar.marks, bar.markText = {}, {}
  for k = 1, 4 do
    local m = bar:CreateTexture(nil, "OVERLAY")
    m:SetTexture(WHITE); m:SetVertexColor(1, 0.84, 0.35); m:SetWidth(2); m:SetHeight(20)
    m:Hide(); bar.marks[k] = m
    local mt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mt:SetTextColor(1, 0.84, 0.35); mt:Hide(); bar.markText[k] = mt
  end
  local nx = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nx:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, -14)
  nx:SetWidth(BAR_W); nx:SetJustifyH("LEFT")
  nx:SetTextColor(1, 0.78, 0.47)
  bar.next = nx
  bar:SetScript("OnEnter", function()
    if not this.boss then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine(AzG(this.boss.name), 1, 0.82, 0)
    local list = AzlDangerList and AzlDangerList(this.boss) or {}
    for i = 1, table.getn(list) do
      local a = list[i]
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(AzlDangerName(a), 1, 0.82, 0)
      GameTooltip:AddLine(AzlDangerText(a), 1, 1, 1, 1)
    end
    if not DB().bossLocked then GameTooltip:AddLine(" "); GameTooltip:AddLine(AzT("Drag to move it."), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  W.Anchor()
  bar:Hide()
end

function W.Anchor()
  if not bar then return end
  local p = DB().bossPos
  bar:ClearAllPoints()
  if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p[1], p[2])
  else
    bar:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
end

-- the bar with a boss alive: name, health, the marks where it turns, the next turn
local function ShowBoss(u, b)
  local hp, hpm = tonumber(u.hp) or 0, tonumber(u.hpm) or 0
  local pct = hpm > 0 and hp / hpm or 0
  bar.boss = b
  bar.icon:SetTexture("Interface\\Icons\\" .. ((b and b.icon) or "INV_Misc_QuestionMark"))
  bar.name:SetText(b and AzG(b.name) or tostring(u.name))
  local info = string.format("%d%%", math.floor(pct * 100 + 0.5))
  if hpm > 0 then info = info .. "  -  " .. Big(hp) .. " / " .. Big(hpm) end
  if u.enraged then info = info .. "  |cffff4020" .. AzT("Enraged") .. "|r" end
  bar.info:SetText(info)
  bar.fill:SetWidth(math.max(1, (BAR_W - 2) * math.min(1, pct)))
  bar.fill:Show()
  local phases = (b and b.phases) or {}
  local nextTurn
  for k = 1, 4 do
    local ph = phases[k]
    if ph then
      local x = math.floor(BAR_W * ph.pct / 100)
      bar.marks[k]:ClearAllPoints(); bar.marks[k]:SetPoint("CENTER", bar.trough, "LEFT", x, 0); bar.marks[k]:Show()
      bar.markText[k]:ClearAllPoints(); bar.markText[k]:SetPoint("TOP", bar.trough, "BOTTOMLEFT", x, -1)
      bar.markText[k]:SetText(ph.pct .. "%"); bar.markText[k]:Show()
      if pct * 100 > ph.pct and not nextTurn then nextTurn = ph end
    else
      bar.marks[k]:Hide(); bar.markText[k]:Hide()
    end
  end
  if nextTurn then
    bar.next:SetText(AzT("At %d%%: %s", nextTurn.pct, TurnText(nextTurn)))
    bar.next:Show()
    bar:SetHeight(table.getn(phases) > 0 and 92 or 70)
  else
    bar.next:Hide()
    bar:SetHeight(table.getn(phases) > 0 and 76 or 64)
  end
  bar.trough:Show()
end

-- the bar with none alive: the next boss and its time
local function ShowNext(nb)
  local b = Lookup(nb.name)
  bar.boss = b
  bar.icon:SetTexture("Interface\\Icons\\" .. ((b and b.icon) or "INV_Misc_QuestionMark"))
  bar.name:SetText(AzT("Next boss: %s", b and AzG(b.name) or tostring(nb.name)))
  bar.info:SetText(AzT("comes in %s", Clock(nb.left)))
  bar.trough:Hide(); bar.fill:Hide(); bar.next:Hide()
  for k = 1, 4 do bar.marks[k]:Hide(); bar.markText[k]:Hide() end
  bar:SetHeight(48)
end

-- ---------- every 0.2 sec ----------
local seen = {}       -- per boss id: the turns already announced
local warned = {}     -- per schedule index: the 10-second warning given
local alive = {}      -- the boss ids seen alive, to announce one once
function W.Update()
  if not bar then W.Build() end
  local ph = Phase()
  local running = ph == "playing" or ph == "ready" or ph == "paused" or ph == "choosing"
  if not running then
    bar:Hide()
    seen, warned, alive = {}, {}, {}
    return
  end
  if not W.On() then bar:Hide(); return end
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
      Alert(AzT("%s is here!", b and AzG(b.name) or tostring(u.name)), b and b.yell and ("\"" .. AzG(b.yell) .. "\"") or nil, b and b.icon)
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
        Alert(AzT("%d%% health!", p.pct), TurnText(p) .. (p.a and ("  " .. First(AzlDangerText(p.a))) or ""), icon)
      end
    end
    ShowBoss(u, b)
    bar:Show()
    return
  end
  local okU, up = pcall(function() return AZS_GetUpcomingBosses and AZS_GetUpcomingBosses() end)
  up = okU and type(up) == "table" and up or {}
  local nb
  for i = 1, table.getn(up) do
    local x = up[i]
    if tonumber(x.left) and (not nb or x.left < nb.left) then nb = x end
  end
  if nb then
    if nb.left <= 10 and nb.left > 0 and not warned[nb.index or nb.name] then
      warned[nb.index or nb.name] = true
      local b = Lookup(nb.name)
      Alert(AzT("%s in 10 sec.", b and AzG(b.name) or tostring(nb.name)), nil, b and b.icon)
    end
    ShowNext(nb)
    bar:Show()
  else
    bar:Hide()
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
  while table.getn(d.bossLog) > 600 do table.remove(d.bossLog, 1) end
end
local lastUnits = ""
function W.StartLog()
  if not logF then
    logF = CreateFrame("Frame")
    for i = 1, table.getn(LOG_EVENTS) do pcall(logF.RegisterEvent, logF, LOG_EVENTS[i]) end
    logF:SetScript("OnEvent", function()
      if not DB().bossLogOn then return end
      if event == "CHAT_MSG_ADDON" then
        -- the game's own lines: only the bosses' (the rest come every moment)
        if arg1 == "AZSUNITS" and type(arg2) == "string" then
          local b = {}
          for e in string.gfind(arg2, "[^;]+") do
            if string.find(e, "^boss,") or string.find(e, "^final,") then table.insert(b, e) end
          end
          local s = table.concat(b, " | ")
          if s ~= lastUnits then lastUnits = s; if s ~= "" then Log("units: " .. s) end end
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
  W.Update()
end)

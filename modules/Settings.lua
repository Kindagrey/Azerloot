-- Azerloot: the settings window. Opened by the gear in the book's top bar (the book steps
-- back into the dark meanwhile), by a right-click on the minimap button, or by /azl settings.
-- Three tabs - the book, the wishlist window and Azerwarn - each a list of settings on a
-- page of parchment: a name, and its value between two arrows with marks under it for its
-- choices. The setting under the mouse is told on the right: what it does, and a live
-- preview of it (the words in their font, the wishlist at its size, the sound at a click).
-- A setting that needs a reload (the language; the book's original faces back) waits until
-- the player applies it.

AzlSettings = {}
local ST = AzlSettings

local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"
local WHITE = MEDIA .. "white.tga"
local FRIZ = "Fonts\\FRIZQT__.TTF"
local MORPH = "Fonts\\MORPHEUS.TTF"
local W, H = 740, 470          -- the window, in its own units
local LIST_W, ROW_H = 384, 30  -- the parchment's rows
local BRASS = { 0.77, 0.59, 0.24 }
local INK = { 0.2, 0.1, 0.02 }
local LIGHT = { 1, 0.92, 0.75 }
local GOLD = { 1, 0.82, 0 }

local function DB() if type(AzerlootDB) ~= "table" then AzerlootDB = {} end return AzerlootDB end
local function Pct(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) .. "%" end

-- texts in the book's faces (they follow the reading face picked for the book)
local function Text(parent, role, size, c, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(role == "head" and MORPH or FRIZ, size)
  if c then fs:SetTextColor(c[1], c[2], c[3]) end
  if AZL and AZL.SetFace then AZL.SetFace(fs, role, role == "head" and MORPH or FRIZ, size, "") end
  return fs
end
local function Tex(parent, file, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(file)
  return t
end
-- a frame's edge in fine lines: gold outside, a darker brass a few units in
local function Edge(f, inset, c, a, thick)
  local sides = {}
  for k = 1, 4 do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetTexture(WHITE); t:SetVertexColor(c[1], c[2], c[3]); t:SetAlpha(a or 1)
    sides[k] = t
  end
  local th = thick or 1
  sides[1]:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset); sides[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset); sides[1]:SetHeight(th)
  sides[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset); sides[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset); sides[2]:SetHeight(th)
  sides[3]:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset); sides[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset); sides[3]:SetWidth(th)
  sides[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset); sides[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset); sides[4]:SetWidth(th)
  return sides
end

-- ---------- the faces, for the previews ----------
local function FaceFiles(key)
  local faces = (AZL and AZL.Faces) or {}
  for i = 1, table.getn(faces) do
    local f = faces[i]
    if f.key == key and f.body then return f.head, f.body end
  end
  return MORPH, (AZL and AZL.Body and AZL.Body()) or FRIZ   -- the book's own faces
end
local function FaceLabel(key)
  local faces = (AZL and AZL.Faces) or {}
  for i = 1, table.getn(faces) do if faces[i].key == key then return faces[i].label, faces[i].tip end end
  return "Original", nil
end

-- ---------- the settings ----------
-- Each: key, kind ("choice", "toggle", "range", "action"), its name and what it does, and
-- get/set; a choice lists its values, a range its least, most and step. preview: what the
-- right side shows. reload: set only once the player applies it (it reloads the interface).
local function Choices(list) return function() return list end end
local function FaceChoices()
  local out = {}
  local faces = (AZL and AZL.Faces) or {}
  for i = 1, table.getn(faces) do table.insert(out, { value = faces[i].key, label = faces[i].label }) end
  return out
end
local function OnOff() return { { value = false, label = "Off" }, { value = true, label = "On" } } end

local function WarnSet(key, on)
  local d = DB()
  -- (the old single switch, off: both parts start off)
  if d.bossWarn == false then d.bossWarn = nil; d.bossAlerts = false; d.bossBar = false end
  d[key] = on and true or false
  if AzlW and AzlW.Banners then AzlW.Banners() end
  if AzlW and AzlW.Update then AzlW.Update() end
end
local function WarnGet(key)
  local d = DB()
  return d.bossWarn ~= false and d[key] ~= false
end
local function Refreshes()
  if AZL and AZL.RefreshTracker then AZL.RefreshTracker() end
end
local function PartTip(key)
  local parts = AZL_WARN_PARTS or {}
  for i = 1, table.getn(parts) do if parts[i].key == key then return parts[i].tip end end
  return ""
end
local function SoundChoices()
  local out = {}
  local s = (AzlW and AzlW.SOUNDS) or {}
  for i = 1, table.getn(s) do table.insert(out, { value = s[i].key, label = s[i].label }) end
  return out
end
local function SoundGet(what)
  local sd = AzlW and AzlW.SoundPick and AzlW.SoundPick(what)
  return sd and sd.key or "raid"
end
local function SoundSet(what, key)
  DB()[what == "soon" and "soundSoon" or "soundTurn"] = key
  local s = (AzlW and AzlW.SOUNDS) or {}
  for i = 1, table.getn(s) do if s[i].key == key and AzlW.PlaySoundOf then AzlW.PlaySoundOf(s[i]) end end
end

ST.TABS = {
  { key = "book", label = "Book", sections = {
    { label = "Reading", rows = {
      { key = "font", kind = "choice", label = "Font", preview = "bookfont", reload = "classic",
        desc = "The font of the book and of the wishlist window. Fonts made for easy reading help, for example, with dyslexia.",
        options = FaceChoices,
        get = function() return (AZL and AZL.FaceKey and AZL.FaceKey()) or "classic" end,
        set = function(v)
          DB().font = v
          if AZL and AZL.ApplyFaces then AZL.ApplyFaces() end
          if AZL and AZL.FaceKey and AZL.FaceKey() ~= v then
            DB().font = "classic"
            if AZL.Print then AZL.Print(AzT("%s could not be loaded by your game, so the book keeps its original faces.", AzT(FaceLabel(v)))) end
          end
          if AZL and AZL.Refresh then AZL.Refresh() end
          Refreshes()
        end },
      { key = "lang", kind = "choice", label = "Language", preview = "language", reload = true,
        desc = "The book's language. Changing it reloads the interface.",
        options = function()
          local out = {}
          for i = 1, table.getn(AZL_LANGS or {}) do
            local lg = AZL_LANGS[i]
            table.insert(out, { value = lg.code, label = lg.label, plain = lg.code ~= "auto" })
          end
          return out
        end,
        get = function() return DB().lang or "auto" end,
        set = function(v) DB().lang = v end },
    } },
    { label = "Book", rows = {
      { key = "bookSize", kind = "range", label = "Book size", preview = "booksize", min = 0.85, max = 1.25, step = 0.05,
        desc = "Makes the whole book smaller or larger, text and pictures alike: from 85% to 125%.",
        get = function() return tonumber(DB().bookSize) or 1 end,
        set = function(v) if Azerloot_SetBookSize then Azerloot_SetBookSize(v) end end },
    } },
  } },
  { key = "wish", label = "Wishlist", sections = {
    { label = "Window", rows = {
      { key = "tracker", kind = "toggle", label = "Wishlist window", preview = "tracker",
        desc = "The small window with your wishlist.",
        get = function() return DB().tracker ~= false end,
        set = function(v) DB().tracker = v; Refreshes() end },
      { key = "locked", kind = "toggle", label = "Locked", preview = "tracker",
        desc = "Locked, the window cannot be moved or sized, and clicks go through it to the game. Its headings still fold.",
        get = function() return DB().trackerLocked and true or false end,
        set = function(v) if AZL and AZL.SetTrackerLock then AZL.SetTrackerLock(v) else DB().trackerLocked = v end end },
      { key = "trackerScale", kind = "range", label = "Wishlist size", preview = "tracker", min = 0.6, max = 1.4, step = 0.05,
        desc = "Makes the wishlist window smaller or larger: from 60% to 140%.",
        get = function() return tonumber(DB().trackerScale) or 1 end,
        set = function(v) DB().trackerScale = v; if AzlFitTracker then AzlFitTracker() end end },
      { key = "trackerAlpha", kind = "range", label = "Wishlist opacity", preview = "tracker", min = 0, max = 1, step = 0.05,
        desc = "How dark the wishlist window's background is, from clear to solid.",
        get = function() return tonumber(DB().trackerAlpha) or 0.35 end,
        set = function(v) DB().trackerAlpha = v; Refreshes() end },
    } },
    { label = "Contents", rows = {
      { key = "spellTracker", kind = "toggle", label = "Spell tracker", preview = "tracker",
        desc = "Spells you pick up in a run join the wishlist window, with their bonuses.",
        get = function() return DB().spellTracker ~= false end,
        set = function(v)
          DB().spellTracker = v
          if not v and AZL and AZL.ForgetLearnedSpells then AZL.ForgetLearnedSpells() end
          Refreshes()
          if AZL and AZL.Refresh then AZL.Refresh() end
        end },
    } },
    { label = "Place", rows = {
      { key = "resetTracker", kind = "action", label = "Reset Wishlist position", button = "Reset", preview = "reset",
        desc = "Brings the wishlist window back to its first place and size, unlocked and shown.",
        run = function() if Azerloot_ResetTracker then Azerloot_ResetTracker() end end },
      { key = "arrange", kind = "action", label = "Arrange windows", button = "Arrange", preview = "arrange", closes = true,
        desc = "Move the wishlist window and the three warning places where you like them; the mouse wheel sizes the warnings. Shift-click on the minimap button does the same.",
        run = function() if Azerloot_LayoutMode then Azerloot_LayoutMode(true) end end },
    } },
  } },
  { key = "warn", label = "Azerwarn", plain = true, sections = {
    { label = "Display", rows = {
      { key = "bossAlerts", kind = "toggle", label = "Warnings", preview = "warnings",
        desc = PartTip("bossAlerts"),
        get = function() return WarnGet("bossAlerts") end,
        set = function(v) WarnSet("bossAlerts", v) end },
      { key = "bossBar", kind = "toggle", label = "Boss in the wishlist", preview = "bossline",
        desc = PartTip("bossBar"),
        get = function() return WarnGet("bossBar") end,
        set = function(v) WarnSet("bossBar", v) end },
      { key = "warnFont", kind = "choice", label = "Font", preview = "warnings",
        desc = "The warnings' own font. Like the book follows the book's font; any other changes the warnings only.",
        options = function()
          local out = { { value = "book", label = "Like the book" } }
          local f = FaceChoices()
          for i = 1, table.getn(f) do table.insert(out, f[i]) end
          return out
        end,
        get = function() return DB().warnFont or "book" end,
        set = function(v)
          DB().warnFont = v
          if AZL and AZL.ApplyFaces then AZL.ApplyFaces() end
          if v ~= "book" and v ~= "classic" and AZL and AZL.FaceKey and AZL.FaceKey("warn") ~= v then DB().warnFont = "book" end
        end },
    } },
    { label = "Sounds", rows = {
      { key = "soundSoon", kind = "choice", label = "Boss in 10 sec.", preview = "sound", sound = "soon",
        desc = "Played with the warning that a boss comes in 10 seconds.",
        options = SoundChoices, get = function() return SoundGet("soon") end, set = function(v) SoundSet("soon", v) end },
      { key = "soundTurn", kind = "choice", label = "Boss phase", preview = "sound", sound = "turn",
        desc = "Played when a boss turns: a new phase or a new attack once wounded.",
        options = SoundChoices, get = function() return SoundGet("turn") end, set = function(v) SoundSet("turn", v) end },
    } },
    { label = "Windows", rows = {
      { key = "arrangeWarn", kind = "action", label = "Arrange windows", button = "Arrange", preview = "arrange", closes = true,
        desc = "Move the wishlist window and the three warning places where you like them; the mouse wheel sizes the warnings. Shift-click on the minimap button does the same.",
        run = function() if Azerloot_LayoutMode then Azerloot_LayoutMode(true) end end },
    } },
  } },
}

-- ---------- values: the one shown, the next one, the words for it ----------
ST.pending = {}
local function Current(def)
  if ST.pending[def.key] ~= nil then return ST.pending[def.key] end
  return def.get()
end
local function OptIndex(def, v)
  local o = def.options()
  for i = 1, table.getn(o) do if o[i].value == v then return i, o end end
  return 1, o
end
function ST.ValueText(def)
  local v = Current(def)
  if def.kind == "toggle" then return AzT(v and "On" or "Off") end
  if def.kind == "range" then return Pct(v) end
  if def.kind == "choice" then
    local i, o = OptIndex(def, v)
    local opt = o[i]
    if not opt then return "" end
    return opt.plain and opt.label or AzT(opt.label)
  end
  return ""
end
-- one step forward (+1) or back (-1); ranges stop at their ends, lists go round
function ST.Step(def, dir)
  if def.kind == "action" then return end
  local v = Current(def)
  local nv
  if def.kind == "toggle" then nv = not v
  elseif def.kind == "range" then
    nv = math.floor(((tonumber(v) or 0) + dir * def.step) / def.step + 0.5) * def.step
    if nv < def.min then nv = def.min elseif nv > def.max then nv = def.max end
    if math.abs(nv - (tonumber(v) or 0)) < 0.001 then return end
  else
    local i, o = OptIndex(def, v)
    local n = table.getn(o)
    if n == 0 then return end
    i = i + dir
    if i > n then i = 1 elseif i < 1 then i = n end
    nv = o[i].value
  end
  ST.Set(def, nv)
end
local function Click(sound) if PlaySound then pcall(PlaySound, sound) end end
-- a value set: at once, or kept until applied when it needs a reload
function ST.Set(def, nv)
  if ST.flashRow and ST.flashRow ~= ST.selRow then ST.flashRow.flash:SetAlpha(0) end
  ST.flashRow, ST.flashT = ST.selRow, 0
  if not def.sound then Click("igMainMenuOptionCheckBoxOn") end
  local needs = def.reload == true or (def.reload ~= nil and def.reload == nv and def.get() ~= nv)
  if needs then
    if nv == def.get() then ST.pending[def.key] = nil else ST.pending[def.key] = nv end
  else
    ST.pending[def.key] = nil
    def.set(nv)
  end
  ST.Update()
end
function ST.Pending()
  for k in pairs(ST.pending) do return true end
  return false
end
-- the waiting values set, and the interface reloaded with them
function ST.Apply()
  for _, tab in ipairs(ST.TABS) do
    for _, sec in ipairs(tab.sections) do
      for _, def in ipairs(sec.rows) do
        local v = ST.pending[def.key]
        if v ~= nil then
          if def.key == "font" then DB().font = v else def.set(v) end
        end
      end
    end
  end
  ST.pending = {}
  if AZL and AZL.ApplyFaces then AZL.ApplyFaces() end
  ReloadUI()
end

-- ---------- the window ----------
-- a range's mark: a fine trough under its value, filled in red-brown as far as it goes
local function RangeBar(row, f)
  if not row.trough then
    local t = row:CreateTexture(nil, "ARTWORK"); t:SetTexture(WHITE); t:SetVertexColor(0.55, 0.42, 0.25); t:SetAlpha(0.55)
    t:SetWidth(120); t:SetHeight(2); t:SetPoint("TOP", row.value, "BOTTOM", 0, -2)
    local b = row:CreateTexture(nil, "OVERLAY"); b:SetTexture(WHITE); b:SetVertexColor(0.62, 0.12, 0.05)
    b:SetHeight(3); b:SetPoint("LEFT", t, "LEFT", 0, 0)
    local k = row:CreateTexture(nil, "OVERLAY"); k:SetTexture(WHITE); k:SetVertexColor(0.62, 0.12, 0.05)
    k:SetWidth(2); k:SetHeight(7)
    row.trough, row.fill, row.knob = t, b, k
  end
  f = math.max(0, math.min(1, f))
  row.fill:SetWidth(math.max(1, 120 * f))
  row.knob:ClearAllPoints(); row.knob:SetPoint("CENTER", row.trough, "LEFT", 120 * f, 0)
  row.trough:Show(); row.fill:Show(); row.knob:Show()
end
local function HideRangeBar(row)
  if row.trough then row.trough:Hide(); row.fill:Hide(); row.knob:Hide() end
end

local function SegMarks(row, n, i)
  -- the marks under a value: one per choice (at most 9), the chosen one red and thicker
  local shown = math.min(n, 9)
  local w, gap = (shown > 6) and 11 or 16, 3
  local total = shown * w + (shown - 1) * gap
  for k = 1, 9 do
    local m = row.marks[k]
    if not m then
      m = row:CreateTexture(nil, "ARTWORK"); m:SetTexture(WHITE)
      row.marks[k] = m
    end
    if k <= shown then
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT", row.value, "BOTTOM", -total / 2 + (k - 1) * (w + gap), -2)
      m:SetWidth(w)
      local on
      if shown < n then on = (k == math.floor((i - 1) * (shown - 1) / math.max(1, n - 1) + 1.5)) else on = (k == i) end
      if on then m:SetHeight(3); m:SetVertexColor(0.62, 0.12, 0.05); m:SetAlpha(1)
      else m:SetHeight(2); m:SetVertexColor(0.55, 0.42, 0.25); m:SetAlpha(0.55) end
      m:Show()
    else
      m:Hide()
    end
  end
end

local function MakeRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetWidth(LIST_W); r:SetHeight(ROW_H)
  r.def, r.marks, r.trough = false, {}, false
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:EnableMouseWheel(true)
  -- under the mouse: a soft warm light; chosen: a dark band with a gold line round it
  local hv = r:CreateTexture(nil, "BACKGROUND"); hv:SetTexture(WHITE); hv:SetVertexColor(1, 0.85, 0.5); hv:SetAlpha(0.16)
  hv:SetAllPoints(r); hv:Hide()
  r.hover = hv
  local band = r:CreateTexture(nil, "BACKGROUND"); band:SetTexture(WHITE); band:SetVertexColor(0.24, 0.12, 0.04); band:SetAlpha(0.93)
  band:SetPoint("TOPLEFT", r, "TOPLEFT", -6, 1); band:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 6, -1); band:Hide()
  r.band = band
  local bf = CreateFrame("Frame", nil, r); bf:SetPoint("TOPLEFT", r, "TOPLEFT", -6, 1); bf:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 6, -1)
  r.bandEdge = Edge(bf, 0, { 1, 0.82, 0.35 }, 0.95)
  r.bandFrame = bf; bf:Hide()
  local ln = r:CreateTexture(nil, "BORDER"); ln:SetTexture(WHITE); ln:SetVertexColor(0.55, 0.42, 0.25); ln:SetAlpha(0.35)
  ln:SetHeight(1); ln:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0); ln:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
  r.line = ln
  r.label = Text(r, "body", 13, INK)
  r.label:SetPoint("LEFT", r, "LEFT", 10, 0)
  r.label:SetJustifyH("LEFT")
  r.value = Text(r, "body", 12, INK)
  r.value:SetPoint("CENTER", r, "RIGHT", -90, 2)
  r.value:SetWidth(150); r.value:SetJustifyH("CENTER")
  -- a value just changed lights up for a moment
  local fl = r:CreateTexture(nil, "ARTWORK"); fl:SetTexture(MEDIA .. "glow.tga"); fl:SetBlendMode("ADD")
  fl:SetVertexColor(1, 0.75, 0.3); fl:SetWidth(176); fl:SetHeight(30); fl:SetPoint("CENTER", r.value, "CENTER", 0, -1); fl:SetAlpha(0)
  r.flash = fl
  -- the two arrows: buttons of their own, so a click on one steps that way
  local function Arrow(dir, x)
    local b = CreateFrame("Button", nil, r)
    b:SetWidth(22); b:SetHeight(ROW_H)
    b:SetPoint("CENTER", r, "RIGHT", x, 0)
    -- the game's own small arrow (its menus' "more" mark), turned for the left one
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    t:SetWidth(13); t:SetHeight(13); t:SetPoint("CENTER", b, "CENTER", 0, 1)
    if dir < 0 then t:SetTexCoord(1, 0, 0, 1) end
    b.tex = t
    b.dir, b.lit, b.row = dir, false, r
    b:SetScript("OnClick", function() if this.row.def then ST.selRow = this.row; ST.Step(this.row.def, this.dir) end end)
    b:SetScript("OnEnter", function() ST.Hover(this.row); this.lit = true; ST.Update() end)
    b:SetScript("OnLeave", function()
      this.lit = false
      if not (MouseIsOver and MouseIsOver(this.row)) then this.row.hover:Hide() end
      ST.Update()
    end)
    return b
  end
  r.prev = Arrow(-1, -172)
  r.next = Arrow(1, -8)
  -- an action: a small wooden button at the right
  local ab = CreateFrame("Button", nil, r)
  ab:SetWidth(132); ab:SetHeight(24)
  ab:SetPoint("RIGHT", r, "RIGHT", -6, 0)
  local abg = Tex(ab, MEDIA .. "button.tga", "BACKGROUND"); abg:SetAllPoints(ab)
  local abh = ab:CreateTexture(nil, "HIGHLIGHT"); abh:SetTexture(MEDIA .. "glow.tga"); abh:SetBlendMode("ADD"); abh:SetAlpha(0.25); abh:SetAllPoints(ab)
  ab.text = Text(ab, "head", 14, GOLD)
  ab.text:SetPoint("CENTER", ab, "CENTER", 0, 0)
  ab.row = r
  ab:SetScript("OnClick", function() local d = this.row.def; if d then ST.Run(d) end end)
  ab:SetScript("OnEnter", function() ST.Hover(this.row) end)
  r.action = ab
  r:SetScript("OnClick", function()
    if not this.def then return end
    ST.selRow = this
    if this.def.kind == "action" then ST.Run(this.def); return end
    ST.Step(this.def, (arg1 == "RightButton") and -1 or 1)
  end)
  r:SetScript("OnMouseWheel", function() if this.def then ST.selRow = this; ST.Step(this.def, ((arg1 or 0) > 0) and 1 or -1) end end)
  r:SetScript("OnEnter", function() ST.Hover(this) end)
  r:SetScript("OnLeave", function() this.hover:Hide() end)
  return r
end

local function MakeHead(parent)
  -- a section's heading: a dark wooden tab, fading out to the right, a line along the page
  local h = CreateFrame("Frame", nil, parent)
  h:SetWidth(LIST_W); h:SetHeight(ROW_H)
  local tab = h:CreateTexture(nil, "BACKGROUND"); tab:SetTexture(WHITE)
  tab:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", -6, 4); tab:SetWidth(220); tab:SetHeight(21)
  tab:SetGradientAlpha("HORIZONTAL", 0.29, 0.16, 0.06, 1, 0.29, 0.16, 0.06, 0)
  local ln = h:CreateTexture(nil, "BORDER"); ln:SetTexture(WHITE); ln:SetVertexColor(0.29, 0.16, 0.06)
  ln:SetHeight(1); ln:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", -6, 3); ln:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 6, 3)
  h.text = Text(h, "head", 15, GOLD)
  h.text:SetShadowColor(0, 0, 0, 1); h.text:SetShadowOffset(1, -1)
  h.text:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 4, 7)
  return h
end

-- ---------- the previews on the right ----------
local PV = {}
local function PvFrame(name)
  if PV[name] then return PV[name] end
  local f = CreateFrame("Frame", nil, ST.preview)
  f:SetAllPoints(ST.preview)
  f:Hide()
  f.built = false
  PV[name] = f
  return f
end
local function Field(f, alpha)
  local t = Tex(f, MEDIA .. "preview_field.tga", "BACKGROUND"); t:SetAllPoints(f)
  local v = f:CreateTexture(nil, "BORDER"); v:SetTexture(WHITE); v:SetVertexColor(0, 0, 0); v:SetAlpha(alpha or 0.2); v:SetAllPoints(f)
  return t
end
local function Parchment(f)
  local t = Tex(f, MEDIA .. "page_wide.tga", "BACKGROUND"); t:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6); t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
  return t
end
local function OffMark(f)
  local o = CreateFrame("Frame", nil, f); o:SetAllPoints(f); o:SetFrameLevel(f:GetFrameLevel() + 5)
  local v = o:CreateTexture(nil, "BACKGROUND"); v:SetTexture(WHITE); v:SetVertexColor(0, 0, 0); v:SetAlpha(0.55); v:SetAllPoints(o)
  local t = Text(o, "head", 22, { 1, 0.3, 0.25 }); t:SetPoint("CENTER", o, "CENTER", 0, 0); t:SetText(AzT("Off"))
  t:SetShadowColor(0, 0, 0, 1); t:SetShadowOffset(1, -1)
  o:Hide()
  return o
end

-- a small wishlist window, as the real one draws: its size and darkness from the settings
local function MiniTracker(f)
  local m = CreateFrame("Frame", nil, f)
  m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  m:SetWidth(156); m:SetHeight(92)
  m.title = Text(m, "head", 12, GOLD); m.title:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -7); m.title:SetText(AzT("Wishlist"))
  m.rows = {}
  local lines = {
    { "Interface\\Icons\\INV_Jewelry_Ring_03", "Heavy Dark Iron Ring", { 0.12, 1, 0 } },
    { "Interface\\Icons\\INV_Jewelry_Necklace_07", "Choker of the Fire Lord", { 0.64, 0.21, 0.93 } },
    { "Interface\\Icons\\Spell_Nature_StarFall", "Moonfire", { 1, 1, 1 }, "+90% damage" },
  }
  for i = 1, table.getn(lines) do
    local L = lines[i]
    local ic = m:CreateTexture(nil, "ARTWORK"); ic:SetTexture(L[1]); ic:SetWidth(11); ic:SetHeight(11)
    local tx = m:CreateFontString(nil, "OVERLAY"); tx:SetFont(FRIZ, 8); tx:SetTextColor(L[3][1], L[3][2], L[3][3])
    tx:SetText(AzG and AzG(L[2]) or L[2]); tx:SetJustifyH("LEFT")
    local bn
    if L[4] then bn = m:CreateFontString(nil, "OVERLAY"); bn:SetFont(FRIZ, 7); bn:SetTextColor(0.3, 1, 0.3); bn:SetText(L[4]) end
    m.rows[i] = { icon = ic, text = tx, bonus = bn, spell = L[4] ~= nil }
  end
  m.lock = Tex(m, "Interface\\ChatFrame\\UI-ChatFrame-LockIcon", "OVERLAY"); m.lock:SetWidth(11); m.lock:SetHeight(11)
  m.lock:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -6)
  m.Draw = function(self, spells, alpha, scale, locked)
    local y = -22
    for i = 1, table.getn(self.rows) do
      local R = self.rows[i]
      if R.spell and not spells then
        R.icon:Hide(); R.text:Hide(); if R.bonus then R.bonus:Hide() end
      else
        R.icon:ClearAllPoints(); R.icon:SetPoint("TOPLEFT", self, "TOPLEFT", 8, y); R.icon:Show()
        R.text:ClearAllPoints(); R.text:SetPoint("LEFT", R.icon, "RIGHT", 4, 0); R.text:Show()
        y = y - 15
        if R.bonus then R.bonus:ClearAllPoints(); R.bonus:SetPoint("TOPLEFT", R.text, "BOTTOMLEFT", 0, -1); R.bonus:Show(); y = y - 9 end
      end
    end
    self:SetHeight(-y + 6)
    self:SetBackdropColor(0, 0, 0, alpha)
    self:SetBackdropBorderColor(0.8, 0.62, 0.28, math.min(1, alpha + 0.4))
    self:SetScale(scale)
    if locked then self.lock:SetVertexColor(1, 0.82, 0); self.lock:SetAlpha(1) else self.lock:SetVertexColor(0.8, 0.8, 0.8); self.lock:SetAlpha(0.45) end
  end
  return m
end

-- a face the game can draw: one it cannot (its file gone) falls back to the classic faces
local function SafeFont(fs, file, size, flags, fallback)
  fs:SetFont(file, size, flags)
  local got = fs:GetFont()
  if type(got) ~= "string" or not string.find(string.upper(got), string.upper(string.gsub(file, "^.*\\", "")), 1, true) then
    fs:SetFont(fallback, size, flags)
  end
end
local function WarnFaces(key)
  if key == "book" then key = (AZL and AZL.FaceKey and AZL.FaceKey()) or "classic" end
  local head, body = FaceFiles(key)
  if key == "classic" then body = FRIZ end
  return head, body
end

local BUILD = {}
BUILD.bookfont = function(f)
  Parchment(f)
  f.head = f:CreateFontString(nil, "OVERLAY"); f.head:SetFont(MORPH, 20); f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -18); f.head:SetTextColor(0.2, 0.1, 0.02)
  f.body = f:CreateFontString(nil, "OVERLAY"); f.body:SetFont(FRIZ, 12); f.body:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -6); f.body:SetWidth(232)
  f.body:SetJustifyH("LEFT"); f.body:SetTextColor(0.28, 0.18, 0.08)
  f.foot = f:CreateFontString(nil, "OVERLAY"); f.foot:SetFont(FRIZ, 11); f.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14); f.foot:SetTextColor(0.18, 0.74, 0.05)
end
BUILD.language = function(f)
  Parchment(f)
  f.head = Text(f, "head", 20, { 0.2, 0.1, 0.02 }); f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -18)
  f.body = Text(f, "body", 12, { 0.28, 0.18, 0.08 }); f.body:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -6); f.body:SetWidth(232); f.body:SetJustifyH("LEFT")
  f.foot = Text(f, "body", 11, { 0.45, 0.3, 0.12 }); f.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
end
BUILD.booksize = function(f)
  local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(WHITE); bg:SetVertexColor(0.07, 0.05, 0.03); bg:SetAllPoints(f)
  -- the book at 100% as a faint outline, the chosen size drawn over it
  f.ghost = Tex(f, MEDIA .. "book.tga", "BORDER"); f.ghost:SetAlpha(0.25)
  f.ghost:SetPoint("CENTER", f, "CENTER", 0, 6); f.ghost:SetWidth(180); f.ghost:SetHeight(90)
  f.book = Tex(f, MEDIA .. "book.tga", "ARTWORK")
  f.book:SetPoint("CENTER", f, "CENTER", 0, 6)
  f.pct = Text(f, "head", 16, GOLD); f.pct:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
end
BUILD.tracker = function(f)
  Field(f, 0.1)
  f.mini = MiniTracker(f)
  f.off = OffMark(f)
end
BUILD.reset = function(f)
  Field(f, 0.25)
  -- (a frame's offsets count in its own scale: these are drawn at 0.6)
  f.ghost = MiniTracker(f); f.ghost:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16 / 0.6, 12 / 0.6); f.ghost:SetAlpha(0.35)
  f.ghost:Draw(true, 0.35, 0.6, false)
  f.mini = MiniTracker(f); f.mini:SetPoint("TOPLEFT", f, "TOPLEFT", 14 / 0.6, -14 / 0.6)
  f.mini:Draw(true, 0.35, 0.6, false)
  f.arrow = Text(f, "head", 26, GOLD); f.arrow:SetPoint("CENTER", f, "CENTER", 10, -4); f.arrow:SetText("<<")
  f.arrow:SetShadowColor(0, 0, 0, 1); f.arrow:SetShadowOffset(1, -1)
end
BUILD.arrange = function(f)
  Field(f, 0.25)
  local function Box(y, w, c)
    local b = CreateFrame("Frame", nil, f); b:SetWidth(w); b:SetHeight(18); b:SetPoint("TOP", f, "TOP", 50, y)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(WHITE); bg:SetVertexColor(0, 0, 0); bg:SetAlpha(0.5); bg:SetAllPoints(b)
    Edge(b, 0, c, 1)
    return b
  end
  f.boxes = { Box(-14, 130, { 1, 0.18, 0.12 }), Box(-40, 100, { 1, 0.55, 0.12 }), Box(-96, 80, { 0.35, 1, 0.35 }) }
  f.mini = MiniTracker(f); f.mini:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8 / 0.55, 24 / 0.55); f.mini:Draw(false, 0.35, 0.55, false)
  f.hint = Text(f, "body", 10, LIGHT); f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -118); f.hint:SetWidth(240); f.hint:SetJustifyH("RIGHT")
  f.hint:SetShadowColor(0, 0, 0, 1); f.hint:SetShadowOffset(1, -1)
end
BUILD.warnings = function(f)
  Field(f, 0.15)
  f.main = f:CreateFontString(nil, "OVERLAY"); f.main:SetFont(MORPH, 20, "THICKOUTLINE"); f.main:SetPoint("TOP", f, "TOP", 0, -24); f.main:SetTextColor(1, 0.18, 0.12)
  f.mid = f:CreateFontString(nil, "OVERLAY"); f.mid:SetFont(MORPH, 15, "THICKOUTLINE"); f.mid:SetPoint("TOP", f.main, "BOTTOM", 0, -14); f.mid:SetTextColor(1, 0.55, 0.12)
  f.small = f:CreateFontString(nil, "OVERLAY"); f.small:SetFont(MORPH, 12, "THICKOUTLINE"); f.small:SetPoint("BOTTOM", f, "BOTTOM", 0, 18); f.small:SetTextColor(0.35, 1, 0.35)
  f.off = OffMark(f)
end
BUILD.bossline = function(f)
  Field(f, 0.35)
  local s = CreateFrame("Frame", nil, f)
  s:SetWidth(232); s:SetHeight(34); s:SetPoint("CENTER", f, "CENTER", 0, 0)
  s:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  s:SetBackdropColor(0, 0, 0, 0.75); s:SetBackdropBorderColor(0.8, 0.62, 0.28, 1)
  s.icon = s:CreateTexture(nil, "ARTWORK"); s.icon:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Hyena")
  s.icon:SetWidth(22); s.icon:SetHeight(22); s.icon:SetPoint("LEFT", s, "LEFT", 6, 0)
  s.name = Text(s, "body", 11, { 1, 0.86, 0.6 }); s.name:SetPoint("LEFT", s.icon, "RIGHT", 6, 0)
  s.time = Text(s, "body", 12, GOLD); s.time:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  f.strip = s
  f.off = OffMark(f)
end
BUILD.sound = function(f)
  local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(WHITE); bg:SetVertexColor(0.07, 0.05, 0.03); bg:SetAllPoints(f)
  local b = CreateFrame("Button", nil, f)
  b:SetWidth(64); b:SetHeight(64); b:SetPoint("CENTER", f, "CENTER", 0, 12)
  b.ring = Tex(b, MEDIA .. "ring.tga", "ARTWORK"); b.ring:SetAllPoints(b)
  b.glow = Tex(b, MEDIA .. "glow.tga", "BACKGROUND"); b.glow:SetBlendMode("ADD"); b.glow:SetVertexColor(1, 0.75, 0.3)
  b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -26, 26); b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 26, -26); b.glow:SetAlpha(0)
  b.play = Text(b, "head", 30, GOLD); b.play:SetPoint("CENTER", b, "CENTER", 3, 1); b.play:SetText(">")
  b:SetScript("OnClick", function() ST.PlayPreview() end)
  b:SetScript("OnEnter", function() this.play:SetTextColor(1, 1, 0.7) end)
  b:SetScript("OnLeave", function() this.play:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
  f.button = b
  f.name = Text(f, "body", 13, LIGHT); f.name:SetPoint("BOTTOM", f, "BOTTOM", 0, 26)
  f.hint = Text(f, "body", 10, { 0.7, 0.62, 0.48 }); f.hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 10); f.hint:SetText(AzT("Click to hear it."))
end

-- draws a preview for the setting (and the value it would have)
local DRAW = {}
DRAW.bookfont = function(f, def)
  local key = Current(def)
  local head, body = FaceFiles(key)
  SafeFont(f.head, head, 20, "", MORPH); f.head:SetText(AzT("Rings"))
  SafeFont(f.body, body, 12, "", FRIZ); f.body:SetText(AzT("Every ring with its value at every rarity."))
  SafeFont(f.foot, body, 11, "", FRIZ); f.foot:SetText(AzG and AzG("Heavy Dark Iron Ring") or "Heavy Dark Iron Ring")
end
DRAW.language = function(f, def)
  local code = Current(def)
  if code == "auto" then code = DB().autoLang or (AzGameLang and AzGameLang()) or "en" end
  local h, b, w = AzT("Rings"), AzT("Every ring with its value at every rarity."), AzT("Wishlist")
  if AzInLang then
    -- (it hands back two words at a time)
    local a1, a2 = AzInLang(code, function() return AzT("Rings"), AzT("Every ring with its value at every rarity.") end)
    local a3 = AzInLang(code, function() return AzT("Wishlist") end)
    if a1 then h, b = a1, a2 end
    if a3 then w = a3 end
  end
  f.head:SetText(h); f.body:SetText(b); f.foot:SetText(w)
end
DRAW.booksize = function(f, def)
  local v = Current(def)
  f.book:SetWidth(180 * v); f.book:SetHeight(90 * v)
  f.pct:SetText(Pct(v))
end
DRAW.tracker = function(f, def)
  local function V(key) for _, t in ipairs(ST.TABS) do for _, s in ipairs(t.sections) do for _, d in ipairs(s.rows) do if d.key == key then return Current(d) end end end end end
  local sc = 0.75 * V("trackerScale")
  f.mini:Draw(V("spellTracker"), V("trackerAlpha"), sc, V("locked"))
  f.mini:ClearAllPoints(); f.mini:SetPoint("TOPLEFT", f, "TOPLEFT", 14 / sc, -14 / sc)
  if V("tracker") then f.off:Hide() else f.off:Show() end
end
DRAW.reset = function(f, def) end
DRAW.arrange = function(f, def) f.hint:SetText(AzT("Shift-click: move the wishlist and the warnings")) end
DRAW.warnings = function(f, def)
  local key = DB().warnFont or "book"
  if def.key == "warnFont" then key = Current(def) end
  local head, body = WarnFaces(key)
  SafeFont(f.main, head, 20, "THICKOUTLINE", MORPH); f.main:SetText(AzT("%s in 10 sec.", AzG and AzG("Hogger") or "Hogger"))
  SafeFont(f.mid, head, 15, "THICKOUTLINE", MORPH); f.mid:SetText(AzG and AzG("A wall of foes closes in!") or "A wall of foes closes in!")
  SafeFont(f.small, head, 12, "THICKOUTLINE", MORPH); f.small:SetText(AzT("%s picked up!", AzG and AzG("Restoration Rune") or "Restoration Rune"))
  local on = WarnGet("bossAlerts")
  if def.key == "bossAlerts" then on = Current(def) end
  if on then f.off:Hide() else f.off:Show() end
end
DRAW.bossline = function(f, def)
  if Current(def) then f.off:Hide() else f.off:Show() end
end
DRAW.sound = function(f, def)
  local i, o = OptIndex(def, Current(def))
  f.name:SetText(o[i] and AzT(o[i].label) or "")
end

function ST.PlayPreview()
  local def = ST.selected
  if not (def and def.sound and AzlW and AzlW.SOUNDS) then return end
  local key = Current(def)
  for i = 1, table.getn(AzlW.SOUNDS) do
    if AzlW.SOUNDS[i].key == key and AzlW.PlaySoundOf then AzlW.PlaySoundOf(AzlW.SOUNDS[i]) end
  end
  ST.ping = 0
end

function ST.ShowPreview(def)
  for _, f in pairs(PV) do f:Hide() end
  if not def or not def.preview or not BUILD[def.preview] then return end
  local f = PvFrame(def.preview)
  if not f.built then BUILD[def.preview](f); f.built = true end
  DRAW[def.preview](f, def)
  f:Show()
  ST.shownPv = f
end

-- ---------- the right side: name, words, preview, notes ----------
local function Extras(def)
  local out = {}
  if def.preview == "warnings" or def.key == "arrangeWarn" then
    if AzlW and AzlW.Size then
      table.insert(out, { AzT("Boss warnings"), Pct(AzlW.Size("main")) })
      table.insert(out, { AzT("Guardians and waves"), Pct(AzlW.Size("mid")) })
      table.insert(out, { AzT("Small notices"), Pct(AzlW.Size("small")) })
    end
  elseif def.key == "font" then
    local _, tip = FaceLabel(Current(def))
    if tip then table.insert(out, { AzT(tip), "" }) end
  elseif def.key == "lang" and Current(def) == "auto" then
    table.insert(out, { AzT("Auto follows the game's language when the book has it, else English."), "" })
  end
  return out
end

function ST.Describe(def)
  local F = ST.frame
  ST.selected = def
  if not def then return end
  F.dName:SetText(AzT(def.label))
  F.dText:SetText(AzT(def.desc or ""))
  if AZL and AZL.SetFace then AZL.SetFace(F.dText, "body", FRIZ, 12, "") end
  if (F.dText:GetHeight() or 0) > 78 and AZL and AZL.SetFace then AZL.SetFace(F.dText, "body", FRIZ, 11, "") end
  if (F.dText:GetHeight() or 0) > 78 and AZL and AZL.SetFace then AZL.SetFace(F.dText, "body", FRIZ, 10, "") end
  ST.ShowPreview(def)
  local ex = Extras(def)
  for k = 1, 3 do
    local L = F.extra[k]
    local e = ex[k]
    if e then
      L.left:SetText(e[1]); L.right:SetText(e[2])
      -- a long note alone across the line
      if e[2] == "" then L.left:SetWidth(262) else L.left:SetWidth(190) end
      L:Show()
    else
      L:Hide()
    end
  end
end

-- the row under the mouse becomes the chosen one: told on the right
function ST.Hover(row)
  if not row or not row.def then return end
  ST.selRow = row
  row.hover:Show()
  ST.Update()
end

-- ---------- the tabs and their rows ----------
function ST.ShowTab(key)
  local F = ST.frame
  ST.tab = key
  DB().settingsTab = key
  local tab
  for _, t in ipairs(ST.TABS) do if t.key == key then tab = t end end
  if not tab then tab = ST.TABS[1]; ST.tab = tab.key end
  -- the tabs: the chosen one in gold with a glowing line under it
  for _, b in ipairs(F.tabs) do
    if b.key == ST.tab then
      b.text:SetTextColor(1, 0.82, 0); b.under:Show(); b.glow:Show()
    else
      b.text:SetTextColor(0.84, 0.75, 0.58); b.under:Hide(); b.glow:Hide()
    end
  end
  for _, h in ipairs(F.heads) do h:Hide() end
  for _, r in ipairs(F.rows) do r:Hide(); r.def = false end
  local y, hi, ri = -10, 0, 0
  local first
  for _, sec in ipairs(tab.sections) do
    hi = hi + 1
    local h = F.heads[hi]
    if not h then h = MakeHead(F.list); F.heads[hi] = h end
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", F.list, "TOPLEFT", 14, y)
    h.text:SetText(AzT(sec.label))
    h:Show()
    y = y - ROW_H
    for _, def in ipairs(sec.rows) do
      ri = ri + 1
      local r = F.rows[ri]
      if not r then r = MakeRow(F.list); F.rows[ri] = r end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", F.list, "TOPLEFT", 14, y)
      r.def = def
      r:Show()
      first = first or r
      y = y - ROW_H
    end
    y = y - 4
  end
  ST.selRow = first
  ST.Update()
end

-- every row drawn anew: its value, its marks, chosen or not; the right side told
function ST.Update()
  local F = ST.frame
  if not F then return end
  for _, r in ipairs(F.rows) do
    local def = r.def
    if def and r:IsShown() then
      local sel = (r == ST.selRow)
      local lc = sel and LIGHT or INK
      r.label:SetText(AzT(def.label))
      r.label:SetTextColor(lc[1], lc[2], lc[3])
      local room = (def.kind == "action") and 228 or 186
      if AZL and AZL.SetFace then AZL.SetFace(r.label, "body", FRIZ, 13, "") end
      if (r.label:GetStringWidth() or 0) > room and AZL and AZL.SetFace then AZL.SetFace(r.label, "body", FRIZ, 11, "") end
      r.label:SetWidth(room)
      if sel then r.band:Show(); r.bandFrame:Show() else r.band:Hide(); r.bandFrame:Hide() end
      if def.kind == "action" then
        r.value:Hide(); r.prev:Hide(); r.next:Hide()
        for _, m in pairs(r.marks) do m:Hide() end
        HideRangeBar(r)
        r.action.text:SetText(AzT(def.button or "OK")); r.action:Show()
      else
        r.action:Hide()
        r.value:Show(); r.prev:Show(); r.next:Show()
        local vc = sel and GOLD or { 0.43, 0.22, 0.04 }
        local txt = ST.ValueText(def)
        if ST.pending[def.key] ~= nil then txt = txt .. " *" end
        r.value:SetText(txt)
        -- a long value a little smaller, so it stays between its arrows
        r.value:SetFont(FRIZ, 12)
        if AZL and AZL.SetFace then AZL.SetFace(r.value, "body", FRIZ, 12, "") end
        if (r.value:GetStringWidth() or 0) > 146 then
          if AZL and AZL.SetFace then AZL.SetFace(r.value, "body", FRIZ, 10, "") else r.value:SetFont(FRIZ, 10) end
        end
        r.value:SetTextColor(vc[1], vc[2], vc[3])
        -- the arrows: dark ink on the page, gold on the chosen row, bright under the mouse
        for _, a in ipairs({ r.prev, r.next }) do
          if a.lit then a.tex:SetVertexColor(1, 1, 0.75); a.tex:SetAlpha(1)
          elseif sel then a.tex:SetVertexColor(1, 0.82, 0.2); a.tex:SetAlpha(1)
          else a.tex:SetVertexColor(0.45, 0.25, 0.06); a.tex:SetAlpha(0.9) end
        end
        -- the marks: a toggle's two, a list's choices; a range a bar filled as far as it goes
        if def.kind == "range" then
          for _, m in pairs(r.marks) do m:Hide() end
          RangeBar(r, (Current(def) - def.min) / (def.max - def.min))
        else
          HideRangeBar(r)
          local n, i
          if def.kind == "toggle" then n, i = 2, Current(def) and 2 or 1
          else local k, o = OptIndex(def, Current(def)); n, i = table.getn(o), k end
          SegMarks(r, n, i)
        end
      end
    end
  end
  if ST.selRow and ST.selRow.def then ST.Describe(ST.selRow.def) end
  -- waiting values: the button that applies them, in the notes' place
  if ST.Pending() then
    F.apply:Show(); F.applyNote:Show()
    for k = 1, 3 do F.extra[k]:Hide() end
  else
    F.apply:Hide(); F.applyNote:Hide()
  end
end

function ST.Run(def)
  Click("igMainMenuOptionCheckBoxOn")
  if def.closes then ST.Close() end
  if def.run then def.run() end
  ST.Update()
end

-- ---------- building the window ----------
function ST.Build()
  if ST.frame then return ST.frame end
  local F = CreateFrame("Frame", "AzerlootSettings", UIParent)
  ST.frame = F
  F:SetWidth(W); F:SetHeight(H)
  F:SetScale(1.1)
  F:SetFrameStrata("FULLSCREEN_DIALOG")
  -- its level set before any of its parts are made: they are made a step above it, and a
  -- level set later would leave them under the window's own wood
  F:SetFrameLevel(40)
  F:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  F:EnableMouse(true); F:SetMovable(true)
  if F.SetToplevel then F:SetToplevel(true) end
  if F.SetClampedToScreen then F:SetClampedToScreen(true) end
  F:RegisterForDrag("LeftButton")
  F:SetScript("OnDragStart", function() this:StartMoving() end)
  F:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  table.insert(UISpecialFrames, "AzerlootSettings")
  -- a soft shadow under it, the dark wood, a gold frame with the book's brass corners below
  local sh = Tex(F, MEDIA .. "shadow.tga", "BACKGROUND"); sh:SetVertexColor(0, 0, 0); sh:SetAlpha(0.75)
  sh:SetPoint("TOPLEFT", F, "TOPLEFT", -26, 20); sh:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", 26, -32)
  local wood = Tex(F, MEDIA .. "leather.tga", "BACKGROUND"); wood:SetAllPoints(F)
  local dim = F:CreateTexture(nil, "BACKGROUND"); dim:SetTexture(WHITE); dim:SetVertexColor(0, 0, 0); dim:SetAlpha(0.16); dim:SetAllPoints(F)
  Edge(F, 0, BRASS, 1, 2)
  Edge(F, 5, { 0.47, 0.33, 0.12 }, 1, 1)
  local cl, cr, ct, cb = 19 / 1024, 99 / 1024, 11 / 512, 91 / 512
  -- (at the foot only: the banner's own gold ends crown the top)
  local corners = {
    { "BOTTOMLEFT", 1, 1, cl, cr, cb, ct }, { "BOTTOMRIGHT", -1, 1, cr, cl, cb, ct },
  }
  for _, c in ipairs(corners) do
    local t = F:CreateTexture(nil, "OVERLAY"); t:SetTexture(MEDIA .. "corners.tga")
    t:SetWidth(34); t:SetHeight(34); t:SetPoint(c[1], F, c[1], c[2], c[3])
    t:SetTexCoord(c[4], c[5], c[6], c[7])
  end
  -- the title on the red banner, the book's emblem at its start
  local bar = Tex(F, MEDIA .. "navbar.tga", "ARTWORK")
  bar:SetPoint("TOPLEFT", F, "TOPLEFT", 14, -10); bar:SetPoint("TOPRIGHT", F, "TOPRIGHT", -14, -10); bar:SetHeight(44)
  local em = CreateFrame("Frame", nil, F); em:SetWidth(58); em:SetHeight(58); em:SetPoint("TOPLEFT", F, "TOPLEFT", 6, -3)
  em:SetFrameLevel(F:GetFrameLevel() + 3)
  local emt = Tex(em, MEDIA .. "emblem_book.tga", "ARTWORK"); emt:SetAllPoints(em)
  local title = Text(F, "head", 21, GOLD)
  title:SetShadowColor(0, 0, 0, 1); title:SetShadowOffset(1, -1)
  title:SetPoint("LEFT", bar, "LEFT", 58, 1)
  title:SetText(AzT("Settings"))
  F.title = title
  local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
  close:SetWidth(30); close:SetHeight(30)
  close:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
  close:SetFrameLevel(F:GetFrameLevel() + 4)
  close:SetScript("OnClick", function() ST.Close() end)
  -- the tabs: words in a row, a fine line under all of them
  F.tabs = {}
  local tx = 34
  for i, t in ipairs(ST.TABS) do
    local b = CreateFrame("Button", nil, F)
    b.key = t.key
    b.text = Text(b, "head", 19, { 0.84, 0.75, 0.58 })
    b.text:SetShadowColor(0, 0, 0, 1); b.text:SetShadowOffset(1, -1)
    b.text:SetText(t.plain and t.label or AzT(t.label))
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    local tw = (b.text:GetStringWidth() or 80) + 24
    b:SetWidth(tw); b:SetHeight(28)
    b:SetPoint("TOPLEFT", F, "TOPLEFT", tx, -64)
    b.glow = Tex(b, MEDIA .. "glow.tga", "BACKGROUND"); b.glow:SetBlendMode("ADD"); b.glow:SetVertexColor(1, 0.7, 0.2); b.glow:SetAlpha(0.45)
    b.glow:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -6, 12); b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -10)
    b.under = b:CreateTexture(nil, "ARTWORK"); b.under:SetTexture(WHITE); b.under:SetVertexColor(1, 0.82, 0.25)
    b.under:SetHeight(2); b.under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 0); b.under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture(MEDIA .. "glow.tga"); hl:SetBlendMode("ADD"); hl:SetAlpha(0.18); hl:SetAllPoints(b)
    b:SetScript("OnClick", function() if ST.tab ~= this.key then Click("igCharacterInfoTab") end; ST.ShowTab(this.key) end)
    F.tabs[i] = b
    tx = tx + tw + 14
    if i < table.getn(ST.TABS) then
      local sep = F:CreateTexture(nil, "ARTWORK"); sep:SetTexture(WHITE); sep:SetVertexColor(0.47, 0.33, 0.12)
      sep:SetWidth(1); sep:SetHeight(16); sep:SetPoint("TOPLEFT", F, "TOPLEFT", tx - 7, -70)
    end
  end
  local rule = Tex(F, MEDIA .. "divider_gold.tga", "ARTWORK")
  rule:SetHeight(14); rule:SetPoint("TOPLEFT", F, "TOPLEFT", 24, -92); rule:SetPoint("TOPRIGHT", F, "TOPRIGHT", -24, -92)
  -- the list on its parchment, at the left
  local list = CreateFrame("Frame", nil, F)
  list:SetWidth(LIST_W + 28); list:SetHeight(H - 132)
  list:SetPoint("TOPLEFT", F, "TOPLEFT", 22, -110)
  local page = Tex(list, MEDIA .. "page_wide.tga", "BACKGROUND")
  page:SetPoint("TOPLEFT", list, "TOPLEFT", -8, 8); page:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 8, -8)
  F.list = list
  F.heads, F.rows = {}, {}
  -- the right side: what the chosen setting does, its preview, notes
  local rx = LIST_W + 28 + 22 + 22
  local rw = W - rx - 26
  local vline = F:CreateTexture(nil, "ARTWORK"); vline:SetTexture(WHITE); vline:SetVertexColor(0.6, 0.45, 0.18); vline:SetAlpha(0.5)
  vline:SetWidth(1); vline:SetPoint("TOPLEFT", F, "TOPLEFT", rx - 12, -112); vline:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", rx - 12, 26)
  F.dName = Text(F, "head", 17, GOLD)
  F.dName:SetShadowColor(0, 0, 0, 1); F.dName:SetShadowOffset(1, -1)
  F.dName:SetPoint("TOPLEFT", F, "TOPLEFT", rx, -112); F.dName:SetWidth(rw); F.dName:SetJustifyH("LEFT")
  F.dText = Text(F, "body", 12, { 0.93, 0.87, 0.74 })
  F.dText:SetPoint("TOPLEFT", F.dName, "BOTTOMLEFT", 0, -6); F.dText:SetWidth(rw); F.dText:SetJustifyH("LEFT")
  local pv = CreateFrame("Frame", nil, F)
  pv:SetWidth(rw); pv:SetHeight(136)
  pv:SetPoint("TOPLEFT", F, "TOPLEFT", rx, -220)
  Edge(pv, -1, BRASS, 1, 1)
  ST.preview = pv
  F.extra = {}
  for k = 1, 3 do
    local L = CreateFrame("Frame", nil, F)
    L:SetWidth(rw); L:SetHeight(16)
    L:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", 0, -10 - (k - 1) * 18)
    L.left = Text(L, "body", 11, { 0.93, 0.87, 0.74 }); L.left:SetPoint("TOPLEFT", L, "TOPLEFT", 0, 0); L.left:SetJustifyH("LEFT")
    L.right = Text(L, "body", 11, GOLD); L.right:SetPoint("TOPRIGHT", L, "TOPRIGHT", 0, 0)
    L:Hide()
    F.extra[k] = L
  end
  -- waiting values (a language, the original faces): applied with a reload
  local ap = CreateFrame("Button", nil, F)
  ap:SetWidth(rw); ap:SetHeight(28)
  ap:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", 0, -30)
  local apb = Tex(ap, MEDIA .. "button.tga", "BACKGROUND"); apb:SetAllPoints(ap)
  local aph = ap:CreateTexture(nil, "HIGHLIGHT"); aph:SetTexture(MEDIA .. "glow.tga"); aph:SetBlendMode("ADD"); aph:SetAlpha(0.3); aph:SetAllPoints(ap)
  ap.text = Text(ap, "head", 15, GOLD); ap.text:SetPoint("CENTER", ap, "CENTER", 0, 0); ap.text:SetText(AzT("Apply and reload"))
  ap:SetScript("OnClick", function() ST.Apply() end)
  ap:Hide()
  F.apply = ap
  F.applyNote = Text(F, "body", 10, { 0.85, 0.75, 0.55 })
  F.applyNote:SetPoint("BOTTOMLEFT", ap, "TOPLEFT", 2, 6); F.applyNote:SetText(AzT("Takes effect after a reload.")); F.applyNote:Hide()
  -- how to change a value, at the foot of the right side
  F.foot = Text(F, "body", 10, { 0.66, 0.58, 0.44 })
  F.foot:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", rx, 22); F.foot:SetWidth(rw); F.foot:SetJustifyH("LEFT")
  F.foot:SetText(AzT("Click or mouse wheel: change - Right-click: back"))
  -- the book behind steps back: a dark veil over it, a click on which closes the settings
  F:SetScript("OnUpdate", function() ST.Tick(arg1 or 0) end)
  F:SetScript("OnHide", function() ST.OnHide() end)
  F:Hide()
  return F
end

-- ---------- opening and closing ----------
local function Veil()
  local book = AZL and AZL.Frame and AZL.Frame()
  if not book then return nil end
  if not ST.veil then
    local v = CreateFrame("Button", nil, book)
    v:SetAllPoints(book)
    v:SetFrameLevel((book:GetFrameLevel() or 1) + 80)
    v:EnableMouse(true)
    local t = v:CreateTexture(nil, "OVERLAY"); t:SetTexture(WHITE); t:SetVertexColor(0, 0, 0); t:SetAllPoints(v)
    v.tex = t
    v:SetScript("OnClick", function() ST.Close() end)
    v:Hide()
    ST.veil = v
  end
  return ST.veil
end

function ST.Open(tab)
  local F = ST.Build()
  ST.pending = {}
  ST.open = true
  ST.fade = 0
  local book = AZL and AZL.Frame and AZL.Frame()
  F:ClearAllPoints()
  if book and book:IsVisible() then
    -- in front of the book, which steps back into the dark
    local x, y = book:GetCenter()
    local s = (book:GetEffectiveScale() or 1) / (F:GetEffectiveScale() or 1)
    if x and y then F:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s, y * s) else F:SetPoint("CENTER", UIParent, "CENTER", 0, 20) end
    local v = Veil()
    if v then v.tex:SetAlpha(0); v:Show() end
    ST.withBook = true
    -- (Escape closes the settings alone meanwhile: the book leaves the list of windows it
    -- closes until they are gone)
    for i = table.getn(UISpecialFrames), 1, -1 do
      if UISpecialFrames[i] == "AzerlootFrame" then table.remove(UISpecialFrames, i) end
    end
  else
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    ST.withBook = false
  end
  F:SetAlpha(0)
  F:Show()
  -- above the wishlist window (the same layer): raised by the game, its parts with it
  if F.Raise then F:Raise() end
  Click("igMainMenuOpen")
  ST.ShowTab(tab or DB().settingsTab or "book")
end

function ST.Close()
  if not ST.frame then return end
  ST.frame:Hide()
  ST.OnHide()   -- (also run by the window's own OnHide, as after Escape: once is enough)
end
function ST.OnHide()
  if not ST.open then return end
  -- (the whole interface hidden, Alt-Z: the settings stay open behind it)
  if ST.frame and ST.frame:IsShown() then return end
  ST.open = false
  -- values waiting for a reload are let go; the book comes forward again
  ST.pending = {}
  if ST.veil then ST.veil:Hide() end
  local back = false
  for i = 1, table.getn(UISpecialFrames) do if UISpecialFrames[i] == "AzerlootFrame" then back = true end end
  if not back then table.insert(UISpecialFrames, "AzerlootFrame") end
  if PlaySound then pcall(PlaySound, "igMainMenuClose") end
end
function ST.Toggle(tab)
  if ST.frame and ST.frame:IsShown() then ST.Close() else ST.Open(tab) end
end
function ST.IsOpen() return (ST.frame and ST.open and ST.frame:IsShown()) and true or false end

-- the window and the veil fading in; the previews' small movements
function ST.Tick(e)
  ST.t = (ST.t or 0) + e
  if ST.fade and ST.fade < 1 then
    ST.fade = math.min(1, ST.fade + e / 0.18)
    ST.frame:SetAlpha(ST.fade)
    if ST.veil and ST.veil:IsShown() then ST.veil.tex:SetAlpha(0.62 * ST.fade) end
  end
  -- the value just changed: its light fading
  if ST.flashRow and ST.flashT then
    ST.flashT = ST.flashT + e
    ST.flashRow.flash:SetAlpha(math.max(0, 0.55 * (1 - ST.flashT / 0.45)))
    if ST.flashT > 0.45 then ST.flashRow.flash:SetAlpha(0); ST.flashRow, ST.flashT = nil, nil end
  end
  local f = ST.shownPv
  if not (f and f:IsShown()) then return end
  local def = ST.selected
  if not def then return end
  if def.preview == "warnings" then
    -- the three come in one after another, stay, and fade, as in a run
    local c = math.mod and math.mod(ST.t, 3.2) or (ST.t - math.floor(ST.t / 3.2) * 3.2)
    local function A(start) local x = c - start; if x < 0 then return 0 end; return math.max(0, math.min(1, x / 0.3, (2.4 - x) / 0.5)) end
    f.main:SetAlpha(A(0)); f.mid:SetAlpha(A(0.35)); f.small:SetAlpha(A(0.7))
  elseif def.preview == "bossline" then
    -- the next boss's time running down, its colour from yellow through orange to red
    local left = math.max(0, 95 - (ST.t - math.floor(ST.t / 12) * 12) * 95 / 12)
    local s = f.strip
    s.name:SetText(AzT("Next boss: %s", AzG and AzG("Hogger") or "Hogger"))
    s.time:SetText(math.floor(left / 60) .. ":" .. string.format("%02d", math.floor(left - math.floor(left / 60) * 60)))
    if AzlW and AzlW.TimeColour then
      local c, amp, speed = AzlW.TimeColour(left)
      s.time:SetTextColor(c[1], c[2], c[3])
      s.time:SetAlpha(1 - amp * (0.5 + 0.5 * math.sin(ST.t * speed)))
    end
  elseif def.preview == "sound" and ST.ping then
    ST.ping = ST.ping + e
    local g = f.button.glow
    g:SetAlpha(math.max(0, 0.8 - ST.ping))
    if ST.ping > 1 then ST.ping = nil end
  end
end

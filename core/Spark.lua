-- Azerloot: a small spark that runs along the glowing "A" on the book's emblem, now and then.
-- AzlSpark(texture, its frame) puts it over any texture that shows emblem_book.tga at full size (the title
-- page, the bar at the top of the book, the settings window). It draws only while shown.

local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"

-- the strokes of the A, in the emblem's own pixels (128 x 128), traced from the picture:
-- the left leg from its foot up to the head, the head's curl and the bar across the top, back
-- to the stem and down it to its curled foot; then, as a second stroke, the swash across
local STROKES = {
  { { 44, 63 }, { 50, 63 }, { 53, 59 }, { 56, 56 }, { 59, 52 }, { 62, 47 }, { 63, 43 }, { 61, 39 }, { 64, 37 },
    { 68, 40 }, { 73, 40 }, { 79, 39 }, { 75, 41 }, { 71, 44 }, { 71, 49 }, { 71, 55 }, { 71, 60 }, { 70, 65 },
    { 73, 68 }, { 77, 68 }, { 80, 66 } },
  { { 49, 50 }, { 54, 51 }, { 60, 51 }, { 64, 52 }, { 66, 55 }, { 68, 59 } },
}
local SPEED = 52      -- emblem pixels a second
local REST = 2.4      -- seconds of quiet between two runs
local TRAIL = 5       -- glows following the head

-- each stroke with its length so far at every point
local RUN, TOTAL = {}, 0
for s = 1, table.getn(STROKES) do
  local pts, acc = STROKES[s], 0
  local lens = { 0 }
  for i = 2, table.getn(pts) do
    local dx, dy = pts[i][1] - pts[i - 1][1], pts[i][2] - pts[i - 1][2]
    acc = acc + math.sqrt(dx * dx + dy * dy)
    lens[i] = acc
  end
  RUN[s] = { pts = pts, lens = lens, len = acc, from = TOTAL / SPEED }
  TOTAL = TOTAL + acc + 6   -- (a short gap between the strokes)
end
local CYCLE = TOTAL / SPEED + REST

-- the point a distance d along a stroke
local function At(st, d)
  local pts, lens = st.pts, st.lens
  if d <= 0 then return pts[1][1], pts[1][2] end
  for i = 2, table.getn(pts) do
    if d <= lens[i] then
      local k = (d - lens[i - 1]) / math.max(0.001, lens[i] - lens[i - 1])
      return pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * k, pts[i - 1][2] + (pts[i][2] - pts[i - 1][2]) * k
    end
  end
  local n = table.getn(pts)
  return pts[n][1], pts[n][2]
end

local function Glow(f, layer, r, g, b, file)
  local t = f:CreateTexture(nil, layer)
  t:SetTexture(MEDIA .. (file or "glow.tga")); t:SetBlendMode("ADD"); t:SetVertexColor(r, g, b); t:SetAlpha(0)
  return t
end

function AzlSpark(tex, owner, delay)
  if not (tex and owner and owner.GetFrameLevel) then return end
  local f = CreateFrame("Frame", nil, owner)
  f:SetFrameLevel(owner:GetFrameLevel() + 2)
  f:SetAllPoints(tex)
  f.halo = Glow(f, "ARTWORK", 1, 0.8, 0.45, "spark.tga")       -- a soft warm light around it, to stand out on the violet
  f.head = Glow(f, "OVERLAY", 1, 1, 0.92, "spark.tga")   -- its bright white heart, a little star
  f.trail = {}
  for i = 1, TRAIL do f.trail[i] = Glow(f, "ARTWORK", 1, 0.85, 0.6, "spark.tga") end
  f.t = -(delay or 1.5)
  local function Place(t, x, y, size, a)
    local S = f:GetWidth() or 0
    if type(S) ~= "number" or S <= 0 then t:SetAlpha(0); return end
    t:ClearAllPoints()
    t:SetPoint("CENTER", f, "TOPLEFT", x / 128 * S, -y / 128 * S)
    t:SetWidth(size * S); t:SetHeight(size * S)
    t:SetAlpha(a)
  end
  local function Hide()
    f.halo:SetAlpha(0); f.head:SetAlpha(0)
    for i = 1, TRAIL do f.trail[i]:SetAlpha(0) end
  end
  f:SetScript("OnUpdate", function()
    local e = arg1 or 0
    f.t = f.t + e
    if f.t < 0 then Hide(); return end
    local c = f.t - math.floor(f.t / CYCLE) * CYCLE
    local d = c * SPEED
    -- which stroke the head is on
    local st
    for s = 1, table.getn(RUN) do
      local r = RUN[s]
      local from = r.from * SPEED
      if d >= from and d <= from + r.len then st = r; d = d - from; break end
    end
    if not st then Hide(); return end
    -- it lights up as it starts a stroke and dims as it ends it
    local edge = math.min(1, d / 6, (st.len - d) / 6)
    if edge < 0 then edge = 0 end
    local flick = 0.85 + 0.15 * math.sin(f.t * 23)
    local x, y = At(st, d)
    Place(f.halo, x, y, 0.34, 0.6 * edge * flick)
    Place(f.head, x, y, 0.16, 1 * edge)
    for i = 1, TRAIL do
      local back = d - i * 2.6
      if back > 0 then
        local tx, ty = At(st, back)
        Place(f.trail[i], tx, ty, 0.11 - i * 0.012, (0.7 - i * 0.11) * edge)
      else
        f.trail[i]:SetAlpha(0)
      end
    end
  end)
  return f
end

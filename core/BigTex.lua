-- Copyright (c) 2026 Kindagrey. All rights reserved. See LICENSE.txt.
-- Azerloot: the book's large pictures in 512-pixel pieces.
-- The game's update of 25 October loads no addon picture longer than 512 pixels on a side.
-- The cover (1024 x 1024), the pages (512 x 1024), the leather, the wide page, the corners
-- and the bar (1024 wide) are kept as two or four pieces each, and drawn side by side as one:
-- AzlBigTex gives a stand-in that takes the calls a texture takes (points, size, colour,
-- alpha, the part of the picture to show) and hands them on to its pieces.

-- how each picture is cut: columns, rows (the pieces are name_1 .. name_n, row by row)
AZL_BIG_TEX = {
  book = { 2, 2 }, page = { 1, 2 }, page_r = { 1, 2 }, page_wide = { 2, 1 },
  leather = { 2, 1 }, corners = { 2, 1 }, navbar = { 2, 1 },
}

-- the picture's own name, from a path or a file name ("...\\book.tga" -> "book")
local function BaseName(file)
  if type(file) ~= "string" then return nil end
  local _, _, n = string.find(file, "([^\\/]+)%.tga$")
  if not n then _, _, n = string.find(file, "([^\\/]+)$") end
  return n and string.lower(n) or nil
end
function AzlBigTexName(file)
  local n = BaseName(file)
  if n and AZL_BIG_TEX[n] then return n end
  return nil
end

local MEDIA = "Interface\\AddOns\\Azerloot\\media\\textures\\"
-- the points a piece is anchored to, by where its edges fall on the whole: 0, a half, or 1
local H = { [0] = "LEFT", [1] = "", [2] = "RIGHT" }     -- (x: left edge, middle, right edge)
local V = { [0] = "TOP", [1] = "", [2] = "BOTTOM" }     -- (y: top edge, middle, bottom edge)
local function Point(xi, yi)
  local p = V[yi] .. H[xi]
  if p == "" then return "CENTER" end
  return p
end

local Proto = {}
-- (anything else a texture is asked, its place is asked: GetLeft, GetTop and the like)
local Meta = { __index = function(o, k)
  if Proto[k] then return Proto[k] end
  if type(k) ~= "string" or not string.find(k, "^%u") then return nil end   -- (its own fields)
  return function(self, a, b, c, d, e)
    local f = self.area[k]
    if f then return f(self.area, a, b, c, d, e) end
  end
end }

-- the region to anchor to: a stand-in's place, else the region itself (another region set
-- against a stand-in is set against its place)
function AzlRegion(r)
  if type(r) == "table" and r.area and r.pieces then return r.area end
  return r
end

-- a stand-in for one big picture on `parent` in `layer`
function AzlBigTex(parent, file, layer)
  local name = AzlBigTexName(file)
  if not name then
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(file)
    return t
  end
  local o = setmetatable({}, Meta)
  -- (the place the whole takes: an empty frame, the pieces drawn on the parent itself, so
  -- they keep the layer and the order they had as one picture)
  o.area = CreateFrame("Frame", nil, parent)
  o.area:SetWidth(1); o.area:SetHeight(1)
  o.parent, o.layer = parent, layer or "ARTWORK"
  o.pieces = {}
  o.coord = { 0, 1, 0, 1 }
  o:SetTexture(file)
  return o
end

function Proto:SetTexture(file)
  local name = AzlBigTexName(file)
  if not name then return end
  self.name = name
  local cut = AZL_BIG_TEX[name]
  self.cols, self.rows = cut[1], cut[2]
  local n = self.cols * self.rows
  for i = 1, n do
    local p = self.pieces[i]
    if not p then
      p = self.parent:CreateTexture(nil, self.layer)
      self.pieces[i] = p
      if self.vc then p:SetVertexColor(self.vc[1], self.vc[2], self.vc[3], self.vc[4]) end
      if self.alpha then p:SetAlpha(self.alpha) end
      if self.blend then p:SetBlendMode(self.blend) end
    end
    p:SetTexture(MEDIA .. name .. "_" .. i .. ".tga")
  end
  for i = n + 1, table.getn(self.pieces) do self.pieces[i]:Hide() end
  self:Layout()
end

-- the part of the whole to show, as a texture's SetTexCoord (left, right, top, bottom); each
-- piece shows its share of it. A cut must fall on an edge or the middle of what is shown
-- (as it does for every part the book uses).
function Proto:SetTexCoord(l, r, t, b)
  self.coord = { l or 0, r or 1, t or 0, b or 1 }
  self:Layout()
end

-- one axis: the whole's [a, b] (a > b: mirrored) against the pieces of `count`; for each piece
-- the part of it shown and where it lies on the shown whole (0 / 1 / 2: start, middle, end),
-- or nil when it is not shown at all
local function Axis(a, b, count, k)
  local lo, hi = math.min(a, b), math.max(a, b)
  local p0, p1 = (k - 1) / count, k / count
  local s0, s1 = math.max(lo, p0), math.min(hi, p1)
  if s1 - s0 <= 0.0001 then return nil end
  -- the piece's own coordinates of the part shown
  local c0, c1 = (s0 - p0) * count, (s1 - p0) * count
  -- where its ends lie on the shown whole
  local w = hi - lo
  local function At(v)
    local f = (v - lo) / w
    if f < 0.25 then return 0 elseif f > 0.75 then return 2 end
    return 1
  end
  local e0, e1 = At(s0), At(s1)
  if a > b then
    -- mirrored: the piece's part runs the other way, and lies mirrored on the whole
    c0, c1 = c1, c0
    e0, e1 = 2 - e1, 2 - e0
  end
  return c0, c1, e0, e1
end

function Proto:Layout()
  if not self.cols then return end
  local c = self.coord
  for row = 1, self.rows do
    for col = 1, self.cols do
      local p = self.pieces[(row - 1) * self.cols + col]
      local x0, x1, ex0, ex1 = Axis(c[1], c[2], self.cols, col)
      local y0, y1, ey0, ey1 = Axis(c[3], c[4], self.rows, row)
      if x0 and y0 then
        p:SetTexCoord(x0, x1, y0, y1)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self.area, Point(ex0, ey0), 0, 0)
        p:SetPoint("BOTTOMRIGHT", self.area, Point(ex1, ey1), 0, 0)
        p.cut = true
        if not self.hidden then p:Show() end
      else
        p.cut = false
        p:Hide()
      end
    end
  end
end

-- what a texture takes, handed on: the place to the frame, the looks to the pieces
function Proto:SetPoint(a, b, c, d, e)
  if type(b) == "number" or b == nil then self.area:SetPoint(a, b, c, d, e); return end
  self.area:SetPoint(a, AzlRegion(b), c, d, e)
end
function Proto:SetAllPoints(f) self.area:SetAllPoints(AzlRegion(f)) end
function Proto:ClearAllPoints() self.area:ClearAllPoints() end
function Proto:SetWidth(w) self.area:SetWidth(w) end
function Proto:SetHeight(h) self.area:SetHeight(h) end
function Proto:GetWidth() return self.area:GetWidth() end
function Proto:GetHeight() return self.area:GetHeight() end
function Proto:SetVertexColor(r, g, b, a)
  self.vc = { r, g, b, a }
  for i = 1, table.getn(self.pieces) do self.pieces[i]:SetVertexColor(r, g, b, a) end
end
function Proto:SetAlpha(a)
  self.alpha = a
  for i = 1, table.getn(self.pieces) do self.pieces[i]:SetAlpha(a) end
end
function Proto:GetAlpha() return self.alpha or 1 end
function Proto:SetBlendMode(m)
  self.blend = m
  for i = 1, table.getn(self.pieces) do self.pieces[i]:SetBlendMode(m) end
end
function Proto:Show()
  self.hidden = nil
  for i = 1, table.getn(self.pieces) do if self.pieces[i].cut then self.pieces[i]:Show() end end
end
function Proto:Hide()
  self.hidden = true
  for i = 1, table.getn(self.pieces) do self.pieces[i]:Hide() end
end
function Proto:IsShown() return not self.hidden end

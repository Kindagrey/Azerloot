-- a loose WoW 1.12 stand-in: every unknown global is a stub that takes any call
local Stub
local smt = {}
smt.__index = function(t, k)
  if k == "GetWidth" or k == "GetHeight" or k == "GetLeft" or k == "GetRight" or k == "GetTop" or k == "GetBottom"
    or k == "GetStringWidth" or k == "GetScale" or k == "GetEffectiveScale" or k == "GetFrameLevel" or k == "NumLines" then
    return function() return (k == "GetScale" or k == "GetEffectiveScale") and 1 or 100 end
  end
  if k == "GetText" or k == "GetName" then return function() return "" end end
  if k == "IsShown" or k == "IsVisible" then return function() return false end end
  if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
  if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
  if k == "GetCenter" then return function() return 100, 100 end end
  return function() return Stub() end
end
smt.__call = function() return Stub() end
Stub = function() return setmetatable({}, smt) end
function CreateFrame(t, name) local f = Stub(); if name then getfenv(0)[name] = f end; return f end
UIParent = Stub(); Minimap = Stub(); GameTooltip = Stub(); DEFAULT_CHAT_FRAME = Stub(); WorldFrame = Stub()
function GetTime() return 1000 end
function GetLocale() return "deDE" end
function UnitClass() return "Shaman", "SHAMAN" end
function UnitName() return "Tester" end
function UnitLevel() return 10 end
function UnitRace() return "Orc", "Orc" end
function GetCVar() return "1" end
function SetCVar() end
function GetCursorPosition() return 0, 0 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetInventoryItemLink() return nil end
function GetInventoryItemTexture() return nil end
function GetNumSpellTabs() return 0 end
function GetSpellName() return nil end
function hooksecurefunc() end
function time() return 1700000000 end
function date() return "01.11.2026" end
function PlaySoundFile() end
function PlaySound() end
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
setmetatable(getfenv(0), { __index = function(t, k)
  if k == "arg" or k == "this" or k == "event" or string.find(k, "^arg%d") or string.find(k, "^AZS_") or string.find(k, "^Azerloot") or string.find(k, "^AZL") or string.find(k, "^Azl") or string.find(k, "^Az%u") then return nil end
  return Stub()
end })

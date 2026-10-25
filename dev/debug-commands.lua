-- Copyright (c) 2026 Kindagrey. All rights reserved. See LICENSE.txt.
-- Azerloot's debugging commands, kept for us only: not loaded by the addon, not in the release.
-- To use one, paste it back into SlashCmdList["AZERLOOT"] in core/Azerloot.lua (worn, probe,
-- lootlog) or into W.Slash in modules/BossWarn.lua (bosstest) for a test build. The boss and
-- sound logs (bosslog, soundlog) are in the git history (before "the debugging logs are gone").
-- lootlog also needs, in the watcher's OnEvent before Azerloot_NoteLoot(arg1):
--   if type(AzerlootDB) == "table" and AzerlootDB.lootlog and type(arg1) == "string" then
--     Print(event .. ": " .. string.gsub(arg1, "|", "||"))
--   end

-- core/Azerloot.lua, SlashCmdList["AZERLOOT"]:
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

-- modules/BossWarn.lua, W.Slash:
  if msg == "bosstest" then
    Alert(AzT("%d%% health!", 70), AzT("New attack, %s.", AzName("Shadow Fissure")), "Spell_Shadow_CreepingPlague")
    return true
  end

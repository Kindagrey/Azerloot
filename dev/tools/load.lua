dofile("/home/claude/work/mock/env.lua")
local root = "/home/claude/azerloot/"
local files = { "core/Locale.lua", "core/BigTex.lua", "locales/Strings.lua", "locales/GameText.lua", "locales/JewelryNames.lua",
  "locales/Tooltips.lua", "data/Jewelry.lua", "data/BossLoot.lua", "core/Azerloot.lua", "modules/Builds.lua", "modules/Chronicle.lua",
  "modules/BossWarn.lua", "modules/Settings.lua" }
for i = 1, table.getn(files) do
  local f, err = loadfile(root .. files[i])
  if not f then print("LOADFAIL " .. files[i] .. " " .. tostring(err)) else
    local ok, e = pcall(f)
    if not ok then print("RUNFAIL " .. files[i] .. " " .. tostring(e)) end
  end
end
print("loaded")

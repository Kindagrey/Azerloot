for i = 1, table.getn(arg) do
  local f, err = loadfile(arg[i])
  if f then print("ok   " .. arg[i]) else print("FAIL " .. arg[i] .. ": " .. tostring(err)) end
end

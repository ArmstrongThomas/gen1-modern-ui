-- Parses repository Lua files with the same Lua runtime embedded by LÖVE.
-- Pass a semicolon-delimited absolute path list in GEN1_LUA_CHECK.

local function fail(message)
  io.stderr:write("Lua syntax test: ", tostring(message), "\n")
  os.exit(1)
end

function love.load()
  io.stdout:setvbuf("no")
  local paths = os.getenv("GEN1_LUA_CHECK")
  if not paths or paths == "" then fail("GEN1_LUA_CHECK is required") end
  local count = 0
  for path in paths:gmatch("[^;]+") do
    local chunk, parseError = loadfile(path)
    if not chunk then fail(parseError) end
    count = count + 1
  end
  if count == 0 then fail("no paths were supplied") end
  print(("Lua syntax test: PASS (%d files)"):format(count))
  love.event.quit(0)
end

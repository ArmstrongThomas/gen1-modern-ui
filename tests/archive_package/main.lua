-- Exercises the same stage-and-mount path used by LauncherMods.installZip.

local function fail(message)
  error("archive package test: " .. tostring(message), 0)
end

local function check(value, message)
  if not value then fail(message) end
end

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

function love.load()
  local source = os.getenv("GEN1_UI_ZIP")
  check(source and source ~= "", "GEN1_UI_ZIP is required")
  local input, openError = io.open(source, "rb")
  check(input, openError)
  local bytes = input:read("*a")
  input:close()
  check(bytes and #bytes > 0, "archive is empty")

  local staged = "gen1_modern_ui_archive_test.zip"
  local mount = "gen1_modern_ui_archive_test"
  love.filesystem.remove(staged)
  local wrote, writeError = love.filesystem.write(staged, bytes)
  check(wrote, writeError)
  check(love.filesystem.mount(staged, mount), "PhysFS could not mount archive")

  local manifestPath = mount .. "/manifest.json"
  check(love.filesystem.getInfo(manifestPath, "file"),
    "manifest.json is not a readable root file")
  local manifest = love.filesystem.read(manifestPath)
  check(manifest and manifest:find('"id"%s*:%s*"gen1_modern_ui"'),
    "manifest id is missing or unreadable")
  check(manifest and manifest:find('"version"%s*:%s*"0%.9%.2"'),
    "maintenance release version is missing or unreadable")
  check(manifest and manifest:find('"games"%s*:%s*%[%s*"gen1"%s*%]'),
    "retirement package is not explicitly Gen1-only")
  check(manifest and manifest:find('"conflicts"%s*:%s*%[%s*"gen1_clean_ui"%s*%]'),
    "retirement package does not conflict with Gen1 Clean UI")
  check(manifest and manifest:find('"permissions"%s*:%s*%[%s*"engine_internals"%s*,%s*"network"%s*%]'),
    "sandbox compatibility permissions are missing")
  check(love.filesystem.getInfo(mount .. "/main.lua", "file"),
    "main.lua is not a readable root file")
  for _, name in ipairs({ "pixel_frame1.png", "pixel_frame2.png",
      "pixel_frame3.png" }) do
    check(love.filesystem.getInfo(mount .. "/assets/" .. name, "file"),
      name .. " is missing from the archive")
  end

  love.filesystem.unmount(staged)
  love.filesystem.remove(staged)
  print("archive package test: PASS")
  love.event.quit(0)
end

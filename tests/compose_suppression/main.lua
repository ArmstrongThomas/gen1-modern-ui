-- LÖVE smoke coverage for Gen1 Modern UI's render.compose suppression seam.
-- Run from the repository root with GEN1_UI_MAIN pointing at the mod entry:
--   $env:GEN1_UI_MAIN = (Resolve-Path 'mods/gen1_modern_ui/main.lua')
--   & 'C:\Program Files\LOVE\lovec.exe' tests/compose_suppression

local function fail(message)
  error("compose suppression test: " .. tostring(message), 0)
end

local function check(value, message)
  if not value then fail(message) end
end

function love.load()
  local entryPath = os.getenv("GEN1_UI_MAIN")
  check(entryPath and entryPath ~= "", "GEN1_UI_MAIN is required")

  local hooks = {}
  local values = {}
  local schemas = {}
  local mod = {
    hooks = {
      wrap = function(_, name, callback)
        hooks[name] = callback
      end,
    },
    options = {
      define = function(_, schema)
        schemas[#schemas + 1] = schema
        for _, row in ipairs(schema) do values[row.key] = row.default end
      end,
      get = function(_, key) return values[key] end,
    },
    ui = {
      Menu = {}, ListMenu = {}, ChoiceBox = {}, QuantityBox = {},
      Strings = function(value) return value end,
    },
  }

  local installer, loadError = loadfile(entryPath)
  check(installer, loadError)
  installer = installer()
  check(type(installer) == "function", "entry must return an installer")
  installer(mod)

  local themeRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "theme" then themeRow = row break end
    end
  end
  check(themeRow and type(themeRow.choices) == "table", "theme choices registered")
  local expectedThemes = {
    "default",
    "gen1_modern_ui:modern_glass",
    "gen1_modern_ui:classic_mono",
    "gen1_modern_ui:pocket_green",
    "gen1_modern_ui:midnight",
    "gen1_modern_ui:midnight_glass",
    "gen1_modern_ui:frost",
  }
  check(#themeRow.choices == #expectedThemes, "all built-in themes registered once")
  for index, id in ipairs(expectedThemes) do
    check(themeRow.choices[index][2] == id, "built-in theme order: " .. id)
  end
  check(mod.exports.themes["gen1_modern_ui:modern_glass"].colors.backdrop[4] == 0.38,
    "glass theme retains authored backdrop alpha")

  mod.exports.registerTheme({
    id = "test_theme:custom", name = "Custom", colors = { accent = { 1, 0, 0, 1 } },
  })
  check(#themeRow.choices == #expectedThemes + 1,
    "third-party theme appends to the live option choices")
  mod.exports.registerTheme({
    id = "test_theme:custom", name = "Custom Reloaded",
    colors = { accent = { 0, 1, 0, 1 } },
  })
  check(#themeRow.choices == #expectedThemes + 1,
    "theme re-registration does not duplicate its choice")
  check(themeRow.choices[#themeRow.choices][1] == "Custom Reloaded",
    "theme re-registration refreshes its display name")
  check(mod.exports.themes["test_theme:custom"].colors.accent[2] == 1,
    "theme re-registration refreshes its tokens")

  check(type(hooks["render.zones"]) == "function", "render.zones hook registered")
  check(type(hooks["render.compose"]) == "function", "render.compose hook registered")

  local state = { screenId = "OptionsMenu", rows = {}, index = 1 }
  local overworld = {}
  local game = { overworld = overworld, stack = {
    states = { overworld, state },
    top = function(self) return self.states[#self.states] end,
    visibleBase = function() return 1 end,
  } }
  local zones = {}
  local returnedZones = hooks["render.zones"](
    function(_, value) return value end, game, zones)
  check(returnedZones == zones, "render.zones remains an identity wrapper")

  local canvas = love.graphics.newCanvas(16, 16)
  local function fill()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
  end
  local function alpha()
    local data = canvas:newImageData()
    local _, _, _, a = data:getPixel(0, 0)
    return a
  end
  local function compose(nextResult)
    return hooks["render.compose"](
      function() return nextResult end, {}, { uiCanvas = canvas })
  end

  fill()
  check(compose(false) == false, "normal compositor result is preserved")
  check(alpha() == 0, "supported normal UI canvas is cleared")

  fill()
  check(compose(true) == true, "downstream takeover result is preserved")
  check(alpha() == 1, "downstream takeover keeps the original UI canvas")

  values.hideOriginalUi = false
  fill()
  compose(false)
  check(alpha() == 1, "HIDE ORIGINAL UI off keeps the canvas")

  values.hideOriginalUi = true
  values.menuUi = false
  fill()
  compose(false)
  check(alpha() == 1, "disabled presenter keeps the canvas")

  values.menuUi = true
  local underlying = { screenId = "ListMenu" }
  game.stack.states = { underlying, state }
  fill()
  compose(false)
  check(alpha() == 1, "nested presenter keeps its visible classic context")

  game.stack.states = { overworld, state }
  state.capture = { action = "binding" }
  fill()
  compose(false)
  check(alpha() == 1, "custom capture mode keeps its classic prompt")
  state.capture = nil

  state.draw = function() end
  fill()
  compose(false)
  check(alpha() == 1, "unknown custom draw override keeps its classic UI")
  state.draw = nil

  state = setmetatable({
    screenId = "BagMenu", items = {}, index = 1, modernBag = {},
    draw = function() end,
  }, { __index = mod.ui.ListMenu })
  game.stack.states = { overworld, state }
  fill()
  compose(false)
  check(alpha() == 0, "recognized Modern Bag draw wrapper remains suppressible")

  state = { phase = "command", queue = {}, kind = "wild" }
  game.stack.states = { state }
  game.stack.visibleBase = function() return 1 end
  fill()
  compose(false)
  check(alpha() == 1, "battle UI stays native while WIP presenter is off")

  print("compose suppression test: PASS")
  love.event.quit(0)
end

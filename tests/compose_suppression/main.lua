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

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

function love.load()
  local entryPath = os.getenv("GEN1_UI_MAIN")
  check(entryPath and entryPath ~= "", "GEN1_UI_MAIN is required")

  local hooks = {}
  local eventListeners = {}
  local values = {}
  local schemas = {}
  local menuDraws = 0
  local menuClass = {
    draw = function() menuDraws = menuDraws + 1 end,
    new = function(_, items, opts)
      return setmetatable({ items = items, onCancel = opts and opts.onCancel },
        { __index = menuClass })
    end,
  }
  local listClass = { draw = function() end, isOpaque = true }
  local choiceClass = { draw = function() end }
  local quantityClass = { draw = function() end }
  local textBoxClass = { draw = function() end }
  local trainerCardClass = { draw = function() end }
  local optionsClass = { draw = function() end }
  local partyClass = { draw = function() end }
  local summaryClass = { draw = function() end }
  local dexEntryClass = { draw = function() end }
  local managerClass = { draw = function() end }
  local overworldClass = { draw = function() end, drawUI = function() end }
  local titleClass = { draw = function() end, isOpaque = true }
  local statsLibrary = {
    calc = function(speciesDef, level)
      local base = speciesDef.baseStats or {}
      return {
        hp = (base.hp or 10) + level + 10,
        attack = (base.attack or 10) + level,
        defense = (base.defense or 10) + level,
        speed = (base.speed or 10) + level,
        special = (base.special or 10) + level,
      }
    end,
  }
  package.loaded["src.ui.TrainerCard"] = trainerCardClass
  package.loaded["src.ui.OptionsMenu"] = optionsClass
  package.loaded["src.ui.PartyMenu"] = partyClass
  package.loaded["src.ui.SummaryMenu"] = summaryClass
  package.loaded["src.ui.DexEntryMenu"] = dexEntryClass
  package.loaded["src.mods.ManagerState"] = managerClass
  package.loaded["src.world.OverworldController"] = overworldClass
  package.loaded["src.ui.TitleState"] = titleClass
  package.loaded["src.pokemon.Stats"] = statsLibrary
  local mod = {
    hooks = {
      wrap = function(_, name, callback)
        hooks[name] = callback
      end,
    },
    events = {
      on = function(_, name, callback)
        eventListeners[name] = callback
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
      Menu = menuClass, ListMenu = listClass,
      ChoiceBox = choiceClass, QuantityBox = quantityClass,
      TextBox = textBoxClass,
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
  local minimalRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "minimalUi" then minimalRow = row break end
    end
  end
  check(minimalRow and minimalRow.default == false,
    "minimal UI defaults to the richer presentation")
  local modMenusRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "startMenuModMenus" then modMenusRow = row break end
    end
  end
  check(modMenusRow and modMenusRow.default == true,
    "Start menu mod grouping defaults to enabled")
  check(type(themeRow.description) == "string" and themeRow.description ~= "",
    "mod settings expose option descriptions")
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
  check(type(hooks["render.hud"]) == "function", "render.hud hook registered")
  check(type(hooks["ui.state.decorate"]) == "function",
    "ui.state.decorate hook registered")
  check(type(eventListeners["screen.pushed"]) == "function",
    "screen lifecycle visibility listener registered")

  local state = setmetatable({ screenId = "OptionsMenu", rows = {}, index = 1 },
    { __index = optionsClass })
  local overworld = overworldClass
  local game = { overworld = overworld, stack = {
    states = { overworld, state },
    top = function(self) return self.states[#self.states] end,
    visibleBase = function(self)
      for index = #self.states, 1, -1 do
        if self.states[index].isOpaque then return index end
      end
      return 1
    end,
  } }
  check(type(hooks["ui.start_menu.items"]) == "function",
    "start-menu hook registered")
  local shortcutItems = hooks["ui.start_menu.items"](
    function(_, items) return items end, game,
    { { label = "SAVE" }, { label = "OPTION" } })
  local shortcutFound = false
  for _, item in ipairs(shortcutItems) do
    if item.id == "gen1_modern_ui.options" then shortcutFound = true break end
  end
  check(#shortcutItems == 3 and shortcutFound,
    "Start menu exposes the direct UI settings shortcut")
  local modMenuRow = { id = "example.dexnav", label = "DEXNAV",
    onSelect = function() end }
  local groupedItems = hooks["ui.start_menu.items"](
    function(_, list) list[#list + 1] = modMenuRow return list end, game,
    { { label = "OPTION" }, { label = "MODS" } })
  local groupedFound, leaked = false, false
  for _, item in ipairs(groupedItems) do
    if item.id == "gen1_modern_ui.mod_menus" then groupedFound = true end
    if item.id == "example.dexnav" then leaked = true end
  end
  check(groupedFound and not leaked,
    "Start menu groups rows appended by other mods")
  values.startMenuModMenus = false
  local flatItems = hooks["ui.start_menu.items"](
    function(_, list) list[#list + 1] = modMenuRow return list end, game,
    { { label = "OPTION" }, { label = "MODS" } })
  local flatFound = false
  for _, item in ipairs(flatItems) do
    if item.id == "example.dexnav" then flatFound = true break end
  end
  check(flatFound, "Start menu grouping can be disabled")
  values.startMenuModMenus = true
  check(type(hooks["input.step"]) == "function", "Start fast-jump hook registered")
  local jumpMenu = setmetatable({ screenId = "StartMenu", startCloses = true, index = 1,
    items = { {}, {}, {}, {}, {}, {}, {}, {} },
    clampScroll = function(self) self.clamped = true end }, { __index = menuClass })
  local jumpGame = { input = { pressQueue = { "right" }, }, save = {}, stack = {
    top = function(self) return jumpMenu end,
  } }
  hooks["input.step"](function() end, jumpGame, 0)
  check(jumpMenu.index == 6 and jumpMenu.clamped
      and jumpGame.save.startMenuIndex == 6,
    "Start fast-jump advances five rows")
  jumpGame.input.pressQueue = { "left" }
  hooks["input.step"](function() end, jumpGame, 0)
  check(jumpMenu.index == 1, "Start fast-jump wraps back by five rows")
  local optionState = {
    screenId = "ManagerState", screen = "options", cursor = 1,
    optionRows = { { id = "theme", label = "UI THEME" } },
  }
  local optionGame = { input = { pressQueue = { "select" } }, stack = {
    top = function(self) return optionState end,
  } }
  hooks["input.step"](function() end, optionGame, 0)
  check(optionState._gen1OptionDescription
      and optionState._gen1OptionDescription.title == "UI THEME"
      and #optionGame.input.pressQueue == 0,
    "SELECT opens the focused option description")
  optionGame.input.pressQueue = { "b" }
  hooks["input.step"](function() end, optionGame, 0)
  check(optionState._gen1OptionDescription == nil
      and #optionGame.input.pressQueue == 0,
    "A/B/SELECT closes the option description")
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
  local function alphaAt(x, y)
    local data = canvas:newImageData()
    local _, _, _, a = data:getPixel(x, y)
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
  local underlying = { screenId = "ListMenu", draw = function() end }
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

  local customOptionsClass = setmetatable({ draw = function() end },
    { __index = optionsClass })
  state = setmetatable({ screenId = "OptionsMenu", rows = {}, index = 1 },
    { __index = customOptionsClass })
  game.stack.states = { overworld, state }
  fill()
  compose(false)
  check(alpha() == 1, "class-level custom draw override keeps its classic UI")

  state = setmetatable({ screenId = "OptionsMenu", rows = {}, index = 1 },
    { __index = optionsClass })
  overworld.emote = { pikaPic = "portrait.png" }
  game.stack.states = { overworld, state }
  fill()
  compose(false)
  check(alpha() == 1, "overworld Pikachu portrait keeps its classic UI")
  overworld.emote = nil
  overworld.poisonFlash = 4
  fill()
  compose(false)
  check(alpha() == 1, "overworld poison flash keeps its classic UI")
  overworld.poisonFlash = nil

  local releasedDrawUI = overworld.drawUI
  overworld.drawUI = function() end
  fill()
  compose(false)
  check(alpha() == 0,
    "additive overworld UI wrapper does not disable the Start/menu stack")
  overworld.drawUI = releasedDrawUI
  local releasedDraw = overworld.draw
  overworld.draw = function() end
  fill()
  compose(false)
  check(alpha() == 1, "replaced overworld world renderer keeps its classic UI")
  overworld.draw = releasedDraw
  local foreignOverworld = { draw = overworld.draw, drawUI = overworld.drawUI }
  game.overworld = foreignOverworld
  game.stack.states = { foreignOverworld, state }
  fill()
  compose(false)
  check(alpha() == 1, "foreign overworld replacement keeps its classic UI")
  game.overworld = overworld

  local startState = setmetatable({ screenId = "StartMenu", items = {
    { label = "POKéMON" }, { label = "ITEM" }, { label = "OPTION" },
  }, index = 1, update = function() end }, { __index = menuClass })
  game.stack.states = { overworld, startState }
  fill()
  compose(false)
  check(alpha() == 0,
    "released overworld plus ordinary StartMenu is suppressible")
  startState.draw = function() end
  fill()
  compose(false)
  check(alpha() == 1, "custom StartMenu draw remains classic")
  startState.draw = nil

  -- Title art shares the UI canvas with its private main Menu. The decorator
  -- suppresses only that ordinary Menu draw while compose vacates its small
  -- canvas rectangle and preserves the title pixels around it.
  local title = setmetatable({ screenId = "TitleState" }, { __index = titleClass })
  game.stack.states = { title }
  local titleMenu = setmetatable({ items = { { label = "NEW GAME" } }, index = 1,
    titleUiBox = { 0, 0, 0, 0 } }, { __index = menuClass })
  titleMenu = hooks["ui.state.decorate"](
    function(_, value) return value end, game, titleMenu, nil)
  game.stack.states = { title, titleMenu }
  menuDraws = 0
  titleMenu:draw()
  check(menuDraws == 0, "modern title Menu suppresses only its classic draw")
  fill()
  compose(false)
  check(alphaAt(0, 0) == 0 and alphaAt(15, 15) == 1,
    "title menu rectangle is cleared while surrounding artwork is preserved")
  game.stack.states = { title, titleMenu, { draw = function() end } }
  menuDraws = 0
  titleMenu:draw()
  check(menuDraws == 1,
    "title Menu restores its classic draw when an unknown overlay blocks presentation")

  local bag = setmetatable({ screenId = "BagMenu", items = {}, index = 1 },
    { __index = listClass })
  local choice = setmetatable({ index = 1 }, { __index = choiceClass })
  game.stack.states = { bag, choice }
  fill()
  compose(false)
  check(alpha() == 0, "fully modeled Bag and choice stack is cleared")

  local textBox = setmetatable({ pages = { { "HELLO" } }, pageIndex = 1,
    lineIndex = 1, charIndex = 5, shown = { {} }, done = true },
    { __index = textBoxClass })
  game.stack.states = { overworld, textBox, choice }
  fill()
  compose(false)
  check(alpha() == 0, "fully modeled dialogue and choice stack is cleared")

  local unknown = { draw = function() end }
  game.stack.states = { bag, unknown, choice }
  fill()
  compose(false)
  check(alpha() == 1, "unknown state in a modeled stack keeps the classic UI")

  state = setmetatable({
    screenId = "BagMenu", items = {}, index = 1, modernBag = {},
    draw = function() end,
  }, { __index = mod.ui.ListMenu })
  game.stack.states = { overworld, state }
  fill()
  compose(false)
  check(alpha() == 0, "recognized Modern Bag draw wrapper remains suppressible")

  state = { screenId = "Gen3Box", mode = "box", row = 0, col = 0,
    draw = function() end }
  game.stack.states = { state }
  fill()
  compose(false)
  check(alpha() == 0, "recognized Gen3 Box instance draw remains suppressible")

  state = { phase = "command", queue = {}, kind = "wild" }
  game.stack.states = { state }
  fill()
  compose(false)
  check(alpha() == 1, "battle UI stays native while WIP presenter is off")

  game.save = {
    player = { name = "RED", id = 1 }, money = 1234, playTime = 3600,
    inventory = { POTION = 2 }, pokedex = { seen = { TESTMON = true },
      owned = { TESTMON = true } },
    currentBox = 1, boxes = { {} },
  }
  game.data = {
    items = {
      POTION = { id = "POTION", name = "POTION", price = 300 },
      TM_TEST = { id = "TM_TEST", name = "TM01", price = 3000,
        machine = { kind = "TM", move = "TEST_MOVE" } },
      KEY_TEST = { id = "KEY_TEST", name = "CARD KEY", price = 0,
        keyItem = true, description = "Opens a locked door." },
    },
    moves = { TEST_MOVE = { id = "TEST_MOVE", name = "TEST MOVE",
      type = "NORMAL", pp = 20 } },
    pokemon = { TESTMON = { id = "TESTMON", name = "TESTMON", dex = 1,
      types = { "NORMAL" }, baseStats = { hp = 30, attack = 25,
        defense = 20, speed = 22, special = 18 } } },
    constants = {},
  }
  local testMon = { species = "TESTMON", nickname = "BUDDY", level = 12,
    hp = 31, status = nil, exp = 1234,
    stats = { hp = 40, attack = 24, defense = 22, speed = 25, special = 20 },
    moves = { { id = "TEST_MOVE", pp = 17 } } }
  local boxedMon = { species = "TESTMON", nickname = "BOXED", level = 12,
    hp = 31, status = nil, dvs = {}, statExp = {},
    moves = { { id = "TEST_MOVE", pp = 17 } } }
  game.save.party = { testMon }
  game.save.boxes[1] = { boxedMon }
  local viewport = { width = 640, height = 360,
    safe = { x = 0, y = 0, width = 640, height = 360 } }
  local portraitViewport = { width = 360, height = 640,
    safe = { x = 0, y = 0, width = 360, height = 640 },
    _gen1TouchVisible = true }
  local mobileLandscapeViewport = { width = 640, height = 360,
    safe = { x = 0, y = 0, width = 640, height = 360 },
    _gen1TouchVisible = true }
  local hudCanvases = {}
  local captureHud = os.getenv("GEN1_UI_SHOTS") == "1"
  local function renderHud(states, name, activeViewport)
    activeViewport = activeViewport or viewport
    local key = activeViewport.width .. "x" .. activeViewport.height
    local hudCanvas = hudCanvases[key]
    if not hudCanvas then
      hudCanvas = love.graphics.newCanvas(activeViewport.width, activeViewport.height)
      hudCanvases[key] = hudCanvas
    end
    game.stack.states = states
    love.graphics.setCanvas(hudCanvas)
    love.graphics.clear(0, 0, 0, 0)
    hooks["render.hud"](function() end, game, activeViewport)
    love.graphics.setCanvas()
    if captureHud and name then
      hudCanvas:newImageData():encode("png", "gen1_ui_" .. name .. ".png")
    end
    return hudCanvas
  end
  local function pixelAlpha(canvas, x, y)
    local _, _, _, a = canvas:newImageData():getPixel(x, y)
    return a
  end
  bag.items = { { label = "POTION", right = "x2", value = "POTION" } }
  bag.footer = "¥1234"
  local opaqueBag = setmetatable({ screenId = "BagMenu", items = {}, index = 1,
    isOpaque = true }, { __index = listClass })
  game.stack.states = { overworld, opaqueBag }
  values.layoutStyle = "floating"
  hooks["input.step"](function() end, game, 0)
  check(opaqueBag.isOpaque == false,
    "FLOATING makes an eligible opaque screen world-visible before draw")
  fill()
  compose(false)
  check(alpha() == 0,
    "world-visible opaque screen can be suppressed with its overworld layer")
  values.layoutStyle = "full"
  hooks["input.step"](function() end, game, 0)
  check(opaqueBag.isOpaque == true,
    "FULL SCREEN restores an eligible screen's original opacity")
  values.layoutStyle = "auto"
  game.stack.states = { overworld, bag }
  local desktopBag = renderHud({ bag }, "bag")
  check(pixelAlpha(desktopBag, 0, 0) == 0,
    "desktop floating presenter leaves the world area transparent")

  -- Rich/static screens share one backdrop policy. Explicit FLOATING and the
  -- default ADAPTIVE mode leave the world pass visible; FULL SCREEN is the
  -- opt-in themed blackout presentation. The new setting also wins over the
  -- retained legacy boolean.
  values.layoutStyle = "floating"
  values.desktopFloating = false
  local explicitFloatingBag = renderHud({ bag }, nil)
  check(pixelAlpha(explicitFloatingBag, 0, 0) == 0,
    "explicit FLOATING keeps the world visible")
  values.layoutStyle = "full"
  local explicitFullBag = renderHud({ bag }, nil)
  check(pixelAlpha(explicitFullBag, 0, 0) > 0,
    "explicit FULL SCREEN paints the themed backdrop")
  values.layoutStyle = "auto"
  values.desktopFloating = true
  local adaptiveBag = renderHud({ bag }, nil)
  check(pixelAlpha(adaptiveBag, 0, 0) == 0,
    "ADAPTIVE defaults to a world-visible presenter")

  values.desktopFloating = false
  local backedDesktopBag = renderHud({ bag }, nil)
  check(pixelAlpha(backedDesktopBag, 0, 0) > 0,
    "desktop floating option off restores the themed backdrop")
  values.desktopFloating = true
  local mobileBag = renderHud({ bag }, "bag_portrait", portraitViewport)
  check(pixelAlpha(mobileBag, 0, 0) == 0,
    "adaptive mobile presenter leaves the world area transparent")
  bag.items = { { label = "TM01", right = "x1", value = "TM_TEST" } }
  renderHud({ bag }, "bag_tm_value")
  bag.items = { { label = "CARD KEY", right = "x1", value = "KEY_TEST" } }
  renderHud({ bag }, "bag_key_value")
  bag.items = { { label = "POTION", right = "x2", value = "POTION" } }
  values.minimalUi = true
  renderHud({ bag }, "bag_minimal")
  values.minimalUi = false

  local startMenu = setmetatable({ screenId = "StartMenu", index = 4,
    items = {
      { label = "POKéDEX" }, { label = "POKéMON" }, { label = "ITEM" },
      { label = "RED" }, { label = "SAVE" }, { label = "OPTION" },
      { label = "LINK" }, { label = "MODS" }, { label = "RET" },
      { label = "SPRITE STYLE" }, { label = "SPAWN AMOUNT" },
    } }, { __index = menuClass })
  local desktopMenu = renderHud({ startMenu }, "start_menu_floating")
  check(pixelAlpha(desktopMenu, 10, 180) == 0
      and pixelAlpha(desktopMenu, 610, 180) > 0,
    "desktop start menu floats at the right with outside breathing room")
  local mobileMenu = renderHud({ startMenu }, "start_menu_mobile_landscape",
    mobileLandscapeViewport)
  check(pixelAlpha(mobileMenu, 0, 0) == 0,
    "adaptive mobile landscape start menu leaves the world area transparent")

  -- Third-party settings mods use plain registered screens built from the
  -- released OptionRows helper rather than an OptionsMenu subclass. The
  -- shared adapter must recognize their public shape, suppress the native
  -- 160x144 draw, and still render live labels/values.
  for _, screenId in ipairs({ "RunModeOptions", "ShinyPokemonOptions",
      "QualityOfLife" }) do
    local optionScreen = {
      screenId = screenId,
      rows = { { label = "EXAMPLE SETTING", value = function() return "ON" end } },
      index = 1, scroll = 0, isOpaque = true,
      update = function() end, draw = function() end,
    }
    game.stack.states = { overworld, optionScreen }
    hooks["input.step"](function() end, game, 0)
    check(optionScreen.isOpaque == false,
      "OptionRows adapter makes " .. screenId .. " world-visible")
    fill()
    compose(false)
    check(alpha() == 0,
      "OptionRows adapter suppresses the native " .. screenId .. " canvas")
    local optionCanvas = renderHud({ optionScreen }, "options_" .. screenId)
    check(pixelAlpha(optionCanvas, 320, 180) > 0,
      "OptionRows adapter renders " .. screenId .. " through modern HUD")
  end
  renderHud({ title, titleMenu }, "title_main_menu")

  local dex = setmetatable({ screenId = "PokedexMenu", title = "POKéDEX",
    items = { { label = "001 TESTMON", value = "TESTMON", ball = true } },
    index = 1, scroll = 0, pageJump = true, footer = "SEEN 1  OWN 1" },
    { __index = listClass })
  renderHud({ dex }, "pokedex")
  renderHud({ dex }, "pokedex_portrait", portraitViewport)
  values.minimalUi = true
  renderHud({ dex }, "pokedex_minimal")
  values.minimalUi = false

  local party = setmetatable({ screenId = "PartyMenu", game = game,
    index = 1, party = game.save.party }, { __index = partyClass })
  renderHud({ party }, "party_rich")
  renderHud({ party }, "party_rich_portrait", portraitViewport)
  values.layoutStyle = "floating"
  local floatingParty = renderHud({ party }, nil)
  check(pixelAlpha(floatingParty, 0, 0) == 0,
    "FLOATING keeps the world visible behind the Party screen")
  values.layoutStyle = "full"
  local fullParty = renderHud({ party }, nil)
  check(pixelAlpha(fullParty, 0, 0) > 0,
    "FULL SCREEN backs the Party screen with the themed backdrop")
  values.layoutStyle = "auto"
  values.minimalUi = true
  renderHud({ party }, "party_minimal")
  values.minimalUi = false
  party.submenu = true
  party.subIndex = 9
  party.subItems = {
    { label = "STATS", onSelect = function() end },
    { label = "CUT", onSelect = function() end },
    { label = "FLY", onSelect = function() end },
    { label = "SURF", onSelect = function() end },
    { label = "STRENGTH", onSelect = function() end },
    { label = "FLASH", onSelect = function() end },
    { label = "TELEPORT", onSelect = function() end },
    { label = "MOD ACTION", onSelect = function() end },
    { label = "CANCEL", onSelect = function() end },
  }
  renderHud({ party }, "party_injected_actions")
  party.submenu, party.subItems = nil, nil

  -- Floating rich-screen regression coverage: a Summary/DexEntry stack must
  -- remain visible after its opaque states are made world-visible.  The
  -- classic canvas is cleared by compose, so a missing modern layer would
  -- otherwise leave a blank screen.
  values.layoutStyle = "floating"
  values.hideOriginalUi = true
  local summary = setmetatable({ screenId = "SummaryMenu", game = game,
    mon = testMon, page = 1 }, { __index = summaryClass })
  game.stack.states = { overworld, party, summary }
  hooks["input.step"](function() end, game, 0)
  local floatingSummary = renderHud({ party, summary }, "summary_floating")
  fill()
  compose(false)
  check(pixelAlpha(floatingSummary, 320, 180) > 0,
    "floating Summary presenter survives classic UI suppression")
  check(pixelAlpha(floatingSummary, 20, 20) > 0,
    "nested Summary uses its rich presenter instead of a generic modal")

  local dexEntry = setmetatable({ screenId = "DexEntryMenu", vanilla = {},
    def = game.data.pokemon.TESTMON, view = "data", forceOwned = true },
    { __index = dexEntryClass })
  local dexOverlay = setmetatable({ screenId = "PokedexMenu", title = "POKéDEX",
    items = { { label = "001 TESTMON", value = "TESTMON", ball = true } },
    index = 1, scroll = 0, pageJump = true, footer = "SEEN 1  OWN 1" },
    { __index = listClass })
  game.stack.states = { overworld, dexOverlay, dexEntry }
  hooks["input.step"](function() end, game, 0)
  local floatingDexEntry = renderHud({ dexOverlay, dexEntry }, "dex_entry_floating")
  fill()
  compose(false)
  check(pixelAlpha(floatingDexEntry, 320, 180) > 0,
    "floating Dex Entry presenter survives classic UI suppression")
  check(pixelAlpha(floatingDexEntry, 20, 20) > 0,
    "nested Dex Entry uses its rich presenter instead of a generic modal")

  -- A malformed/partially initialized rich state must never leave a blank
  -- world-visible frame.  The classic canvas remains available until the
  -- presenter can resolve its live record.
  local missingSummary = setmetatable({ screenId = "SummaryMenu", game = game,
    page = 1 }, { __index = summaryClass })
  game.stack.states = { overworld, missingSummary }
  eventListeners["screen.pushed"]({ state = missingSummary })
  fill()
  compose(false)
  check(alpha() == 1,
    "floating Summary fallback keeps classic UI when live data is missing")
  local missingDexEntry = setmetatable({ screenId = "DexEntryMenu",
    vanilla = {}, view = "data" }, { __index = dexEntryClass })
  game.stack.states = { overworld, missingDexEntry }
  eventListeners["screen.pushed"]({ state = missingDexEntry })
  fill()
  compose(false)
  check(alpha() == 1,
    "floating Dex Entry fallback keeps classic UI when live data is missing")

  local boxRootItems = {}
  for index = 1, 4 do
    boxRootItems[index] = { label = "BOX ACTION " .. index, keepOpen = true,
      onSelect = function() end }
  end
  boxRootItems[5] = { label = "SEE YA!" }
  local boxRoot = setmetatable({ screenId = "BoxMenu", game = game,
    index = 1, noSound = true, items = boxRootItems }, { __index = menuClass })
  local boxList = setmetatable({ game = game, title = "BOX 1 (WITHDRAW)",
    index = 1, scroll = 0, items = { { label = "BOXED :L12", value = 1 } } },
    { __index = listClass })
  renderHud({ boxRoot, boxList }, "box_withdraw_rich")
  check(boxedMon.stats == nil,
    "Bill PC derives display stats without mutating the boxed save record")
  boxRoot.index = 2
  boxList.title = "PARTY (DEPOSIT)"
  renderHud({ boxRoot, boxList }, "box_deposit_rich")
  local secondMon = { species = "TESTMON", nickname = "SECOND", level = 9,
    hp = 20, stats = { hp = 20, attack = 15, defense = 15, speed = 15,
      special = 15 }, moves = {} }
  game.save.boxes[1] = { boxedMon, secondMon }
  boxRoot.index = 3
  boxList.title = "BOX 1 (RELEASE)"
  boxList.items = {
    { label = "BOXED :L12", value = 1 },
    -- ListMenu:removeCurrent intentionally leaves this released payload stale.
    { label = "SECOND :L9", value = 3 },
  }
  renderHud({ boxRoot, boxList }, "box_release_stale_payload")
  fill()
  compose(false)
  check(alpha() == 0,
    "Bill release list remains modeled when retained row payloads are stale")

  local trainer = setmetatable({ screenId = "TrainerCard", game = game },
    { __index = trainerCardClass })
  renderHud({ trainer }, "trainer")
  renderHud({ trainer }, "trainer_portrait", portraitViewport)

  local shop = setmetatable({ title = "BUY", dialogue = true,
    money = function() return 1234 end, footer = "What would you like?",
    items = { { label = "POTION", right = "¥300", value = "POTION" } },
    index = 1, scroll = 0 }, { __index = listClass })
  renderHud({ shop }, "shop")
  shop.items = { { label = "TM01", right = "¥3000", value = "TM_TEST" } }
  renderHud({ shop }, "shop_portrait", portraitViewport)
  shop.items = { { label = "POTION", right = "¥300", value = "POTION" } }
  values.minimalUi = true
  renderHud({ shop }, "shop_minimal")
  values.minimalUi = false

  local pc = setmetatable({ title = "WITHDRAW", messageBox = true,
    footer = "Withdraw how many?",
    items = { { label = "POTION", right = "x2", value = "POTION" } },
    index = 1, scroll = 0 }, { __index = listClass })
  renderHud({ pc }, "pc")
  renderHud({ pc }, "pc_portrait", portraitViewport)

  textBox.choice = true
  choice.anchor = "bottom"
  renderHud({ overworld, textBox, choice }, "dialogue_choice")
  renderHud({ overworld, textBox, choice }, "dialogue_choice_portrait",
    portraitViewport)

  if captureHud then
    print("compose suppression shots: " .. love.filesystem.getSaveDirectory())
  end

  print("compose suppression test: PASS")
  love.event.quit(0)
end

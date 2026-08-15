-- LÖVE smoke coverage for Gen1 Modern UI's render.compose suppression seam.
-- Run from the repository root with GEN1_UI_MAIN pointing at the mod entry:
--   $env:GEN1_UI_MAIN = (Resolve-Path 'mods/gen1_modern_ui/main.lua')
--   & 'C:\Program Files\LOVE\lovec.exe' tests/compose_suppression

local function fail(message)
  error("compose suppression test: " .. tostring(message), 0)
end

local function check(value, message)
  if not value and os.getenv("GEN1_UI_DEX_RADAR_ONLY") == "1"
      and not tostring(message):find("Dex Radar", 1, true) then
    return
  end
  if not value then fail(message) end
end

local function verifyRichPixelHeaders(values, renderHud, latestLayoutRect,
    verticallySeparated, getLayoutDiagnostics, state, label, shotName, viewport)
  local savedUiScale, savedFontScale = values.uiScale, values.fontScale
  values.uiScale = "100"
  for pixelStep = 2, 4 do
    values.fontScale = tostring(pixelStep * 100)
    renderHud({ state }, pixelStep == 4 and shotName or nil, viewport)
    check(verticallySeparated(latestLayoutRect("header"),
        latestLayoutRect("rows")),
      pixelStep .. "X Plain Pixel " .. label
        .. " rows remain below its header")
    local diagnostics = getLayoutDiagnostics()
    local layer = diagnostics.layers and diagnostics.layers[#diagnostics.layers]
    check(layer and #(layer.overflows or {}) == 0,
      pixelStep .. "X Plain Pixel " .. label
        .. " remains inside its stable envelope")
  end
  values.uiScale, values.fontScale = savedUiScale, savedFontScale
end

local function optionDefault(schemas, key)
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == key then return row.default end
    end
  end
end

local PLAIN_PIXEL_VIRTUAL =
  "assets/fonts/plainpixel/PlainPixel-Regular.ttf"

local function stagePlainPixelHostAsset()
  love.filesystem.remove(PLAIN_PIXEL_VIRTUAL)
  local source = os.getenv("GEN1_UI_PLAIN_PIXEL_FONT")
  if not source or source == "" then return end
  local input, openError = io.open(source, "rb")
  check(input, openError)
  local bytes = input:read("*a")
  input:close()
  check(bytes and #bytes > 0, "Plain Pixel host asset is not empty")
  check(love.filesystem.createDirectory("assets/fonts/plainpixel"),
    "Plain Pixel staging directory is writable")
  local wrote, writeError = love.filesystem.write(PLAIN_PIXEL_VIRTUAL, bytes)
  check(wrote, writeError)
  check(love.filesystem.getInfo(PLAIN_PIXEL_VIRTUAL, "file"),
    "Plain Pixel host asset is readable at the production path")
end

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

local function namingGridHasNumberRows(hook)
  local base = { { "A", "B", "C" }, { "ED" }, { "lower case" } }
  local result = hook(function(grid) return grid end, base, { lower = false })
  return #result == 5 and result[3][1] == "1"
    and result[4][5] == "0" and result[5][1] == "lower case"
end

local function namingGridKeepsLowercase(hook)
  local base = { { "a", "b", "c" }, { "ED" }, { "UPPER CASE" } }
  local digitPage = { { "1", "2", "3" }, { "ABC" } }
  local result = hook(function() return digitPage end, base, { lower = true })
  return result[1][1] == "a" and result[3][1] == "1"
    and result[#result][1] == "UPPER CASE"
end

local function namingGridNormalizesRbyMmoSwitch(hook)
  local upper = { { "A", "B" }, { "1", "2" }, { "123" } }
  local lower = { { "a", "b" }, { "1", "2" }, { "ABC" } }
  local upperResult = hook(function() return upper end, upper,
    { lower = false })
  local lowerResult = hook(function() return lower end, lower,
    { lower = true })
  return upperResult[#upperResult][1] == "lower case"
    and lowerResult[#lowerResult][1] == "UPPER CASE"
end

local function namingGridKeepsNativeNewGame(hook, game, state)
  local base = { { "A", "B", "C" }, { "ED" }, { "lower case" } }
  local result = hook(function(grid) return grid end, base,
    { lower = false, game = game, state = state })
  return #result == #base and result[#result][1] == "lower case"
end

local function verifyFixedBattleSourceTransform(context)
  local sourceCanvas = love.graphics.newCanvas(304, 144)
  love.graphics.setCanvas(sourceCanvas)
  love.graphics.clear(0.1, 0.8, 0.2, 1)
  love.graphics.setCanvas()
  local renderer = {
    uiFill = false, battleDim = 0, scale = 5,
    uiScale = function(self) return self.scale end,
    blitCanvas = function(_, canvas, sx, sy, _, _, _, bx, by,
        boxX, boxY, boxW, boxH)
      love.graphics.setScissor(boxX, boxY, boxW, boxH)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(canvas, bx, by, 0, sx, sy)
      love.graphics.setScissor()
    end,
  }
  context.hooks["render.zones"](
    function(_, value) return value end, context.game, {})
  context.hooks["render.compose"](function() return false end, renderer, {
    uiCanvas = sourceCanvas, uiw = 304, uih = 144,
    zones = nil, ww = 1600, wh = 1000, pw = 1600, ph = 1000,
    dpiX = 1, dpiY = 1, scale = 5,
  })
  check(context.alphaBounds(sourceCanvas) == nil,
    "captured WIDE source removes the host-sized duplicate canvas")
  local transformed = context.renderHud({ context.battle },
    "battle_2d_fixed_source_transform", context.viewport)
  local image = transformed:newImageData()
  local sourceR, sourceG, sourceB, sourceA = image:getPixel(800, 450)
  local _, _, _, oldLetterboxA = image:getPixel(100, 500)
  check(sourceA > 0.95 and sourceG > sourceR and sourceG > sourceB,
    "cleaned 304x144 source is rescaled into the modern arena")
  check(oldLetterboxA == 0,
    "fixed WIDE transform leaves no source pixels outside its envelope")

  love.graphics.setCanvas(sourceCanvas)
  love.graphics.clear(0.1, 0.8, 0.2, 1)
  love.graphics.setCanvas()
  renderer.scale = 1
  context.hooks["render.zones"](
    function(_, value) return value end, context.game, {})
  context.hooks["render.compose"](function() return false end, renderer, {
    uiCanvas = sourceCanvas, uiw = 304, uih = 144,
    zones = nil, ww = 420, wh = 760, pw = 420, ph = 760,
    dpiX = 1, dpiY = 1, scale = 1,
  })
  local portrait = context.renderHud({ context.battle },
    "battle_2d_fixed_source_transform_portrait", context.portraitViewport)
  local portraitImage = portrait:newImageData()
  local portraitR, portraitG, portraitB, portraitA =
    portraitImage:getPixel(210, 250)
  check(portraitA > 0.95 and portraitG > portraitR
      and portraitG > portraitB,
    "portrait WIDE shell moves the live source into its framed arena")
end

local function verifyUiGallery(context)
  local catalog = context.mod.exports.uiGalleryCatalog()
  check(type(catalog) == "table" and #catalog >= 50,
    "UI Gallery publishes the complete stable presenter catalog")
  local seen, coveredKinds = {}, {}
  for _, spec in ipairs(catalog) do
    check(type(spec.id) == "string" and spec.id ~= ""
        and not seen[spec.id] and type(spec.kind) == "string"
        and type(spec.screenId) == "string"
        and spec.qualifiedId == "gen1_modern_ui.gallery." .. spec.id,
      "UI Gallery entries expose unique id, type, and screen metadata")
    seen[spec.id] = true
    coveredKinds[spec.kind] = true
  end
  for _, kind in ipairs({
      "text", "choice", "quantity", "menu", "list", "options",
      "mod_options", "mod_manager", "link", "external", "party",
      "summary", "trainer_card", "pokedex", "dex_entry", "box_root",
      "box_mon_list", "gen3_box", "move_learn", "bag", "shop_list",
      "pc_list", "pic_box", "naming", "town_map", "quarantine_report",
      "dex_radar", "rby_mmo_profile", "rby_mmo_rank",
      "rby_mmo_char_pick", "battle",
    }) do
    check(coveredKinds[kind] == true,
      "UI Gallery covers presenter kind " .. kind)
  end
  check(seen["battle.catch.nickname_prompt"]
      and seen["battle.catch.nickname_entry"],
    "UI Gallery names both post-catch nickname screens explicitly")
  local startSpec
  for _, spec in ipairs(catalog) do
    if spec.id == "core.start_menu" then startSpec = spec break end
  end
  check(startSpec and startSpec.preset == "NAV",
    "UI Gallery exercises Start through the production NAV envelope")

  local savedScale = context.mod.exports.getScaleTokens(context.viewport)
  local gallery = context.mod.exports.openUiGallery(context.game)
  check(gallery and gallery.screenId == "Gen1ModernUiGallery"
      and context.game.stack:top() == gallery,
    "UI Gallery opens as an in-game Modern UI-owned state")
  for index, spec in ipairs(catalog) do
    for _, contentIndex in ipairs({ 1, 3, 5 }) do
      gallery.entryIndex, gallery.contentIndex = index, contentIndex
      gallery.preview, gallery.previewKey = nil, nil
      local shot = contentIndex == 3 and (
        spec.id == "pokemon.party" and "ui_gallery_party"
        or spec.id == "battle.wide.moves" and "ui_gallery_battle_moves"
        or spec.id == "battle.catch.nickname_prompt"
          and "ui_gallery_catch_nickname_prompt"
        or spec.id == "battle.catch.nickname_entry"
          and "ui_gallery_catch_nickname_entry"
        or spec.id == "integration.external_details"
          and "ui_gallery_external_details") or nil
      check(context.alphaBounds(context.renderHud({ gallery }, shot,
        context.viewport)) ~= nil,
        "UI Gallery renders " .. spec.id .. " at content profile "
          .. contentIndex)
      if spec.id == "integration.external_details" and contentIndex == 3 then
        local byRole = {}
        for _, rect in ipairs(gallery.previewDiagnostics
            and gallery.previewDiagnostics.rects or {}) do
          byRole[rect.role] = rect
        end
        check(gallery.previewDiagnostics
            and #(gallery.previewDiagnostics.overflows or {}) == 0,
          "structured adapter details remain inside the Gallery preview")
        check(byRole["external-detail-scalars"]
            and byRole["external-detail-custom-fields"]
            and byRole["external-detail-footer-lists"]
            and byRole["external-detail-scalars"].y
              + byRole["external-detail-scalars"].h
              <= byRole["external-detail-custom-fields"].y + 0.01
            and byRole["external-detail-custom-fields"].y
              + byRole["external-detail-custom-fields"].h
              <= byRole["external-detail-footer-lists"].y + 0.01,
          "structured adapter fields and bottom footer lists never overlap")
      end
    end
  end
  gallery.contentIndex = 3

  context.game.stack.states = { gallery }
  context.game.input = { pressQueue = { "right" } }
  local entryBefore = gallery.entryIndex
  context.hooks["input.step"](function() end, context.game, 0)
  check(gallery.entryIndex ~= entryBefore
      and #context.game.input.pressQueue == 0,
    "UI Gallery cycles presenter entries with LEFT/RIGHT")
  context.game.input.pressQueue = { "down" }
  local contentBefore = gallery.contentIndex
  context.hooks["input.step"](function() end, context.game, 0)
  check(gallery.contentIndex ~= contentBefore,
    "UI Gallery cycles sparse, normal, and stress content")
  context.game.input.pressQueue = { "a" }
  local uiBefore = gallery.optionOverrides.uiScale
  context.hooks["input.step"](function() end, context.game, 0)
  check(gallery.optionOverrides.uiScale ~= uiBefore,
    "UI Gallery cycles temporary UI scale")
  local liveScale = context.mod.exports.getScaleTokens(context.viewport)
  check(math.abs(liveScale.uiScale - savedScale.uiScale) < 0.0001,
    "UI Gallery scale overrides remain scoped to the nested preview")
  context.game.input.pressQueue = { "select" }
  local fontBefore = gallery.optionOverrides.fontScale
  context.hooks["input.step"](function() end, context.game, 0)
  check(gallery.optionOverrides.fontScale ~= fontBefore,
    "UI Gallery cycles temporary font scale")
  context.game.input.pressQueue = { "start" }
  local pixelBefore = gallery.optionOverrides.pixelFont
  context.hooks["input.step"](function() end, context.game, 0)
  check(gallery.optionOverrides.pixelFont ~= pixelBefore,
    "UI Gallery toggles system and whole-step pixel font modes")

  if not gallery.optionOverrides.pixelFont then
    context.game.input.pressQueue = { "start" }
    context.hooks["input.step"](function() end, context.game, 0)
  end
  context.renderHud({ gallery }, nil, context.viewport)
  local pixelStep = gallery.previewTheme and gallery.previewTheme.scale
    and gallery.previewTheme.scale.pixelFontStep
  check(type(pixelStep) == "number" and pixelStep >= 1
      and pixelStep == math.floor(pixelStep),
    "UI Gallery preserves whole-number Plain Pixel raster steps")

  local menuIndex
  for index, spec in ipairs(catalog) do
    if spec.id == "core.start_menu" then menuIndex = index break end
  end
  local function previewPanelAt(contentIndex)
    gallery.entryIndex, gallery.contentIndex = menuIndex, contentIndex
    gallery.preview, gallery.previewKey = nil, nil
    context.renderHud({ gallery }, nil, context.viewport)
    for _, rect in ipairs(gallery.previewDiagnostics
        and gallery.previewDiagnostics.rects or {}) do
      if rect.role == "panel" then return rect end
    end
  end
  local emptyPanel = previewPanelAt(1)
  local overflowPanel = previewPanelAt(5)
  check(emptyPanel and overflowPanel
      and math.abs(emptyPanel.w - overflowPanel.w) < 0.01
      and math.abs(emptyPanel.h - overflowPanel.h) < 0.01,
    "Gallery content profiles retain one stable presenter envelope")
  check(gallery.previewDiagnostics
      and #(gallery.previewDiagnostics.overflows or {}) == 0,
    "Gallery reports no out-of-bounds rectangles for the menu stress preview")

  context.game.input.pressQueue = { "b" }
  context.hooks["input.step"](function() end, context.game, 0)
  check(context.game.stack:top() ~= gallery,
    "UI Gallery closes without retaining its temporary preview state")
end

local function verifyCatchNicknameScreens(context)
  -- AskName is two different screens: a TextBox with a ChoiceBox riding it,
  -- followed by the opaque NamingScreen when YES is selected. Keep both in
  -- the visual regression so battle child handling cannot make either one
  -- disappear again.
  local function newCatchPrompt()
    return setmetatable({
      pages = { { "Do you want to", "give a nickname", "to TESTMON?" } },
      pageIndex = 1, lineIndex = 3, charIndex = 11,
      shown = { {} }, done = true, choice = true,
    }, { __index = context.textBoxClass })
  end
  local function newCatchChoice()
    return setmetatable({ index = 1, anchor = "bottom" },
      { __index = context.choiceClass })
  end
  local function promptPanels()
    local dialoguePanel, choicePanel
    for _, layer in ipairs(
        context.mod.exports.getLayoutDiagnostics().layers or {}) do
      for _, rect in ipairs(layer.rects or {}) do
        if rect.role == "panel" and layer.kind == "text" then
          dialoguePanel = rect
        elseif rect.role == "panel" and layer.kind == "choice" then
          choicePanel = rect
        end
      end
    end
    return dialoguePanel, choicePanel
  end
  local oldBlank, oldPhase = context.battle.blankForAskName,
    context.battle.phase
  context.battle.blankForAskName, context.battle.phase = true, "messages"
  context.renderHud({ context.battle, newCatchPrompt(), newCatchChoice() },
    "battle_catch_nickname_prompt", context.battleViewport)
  local desktopDialogue, desktopChoice = promptPanels()
  check(desktopDialogue and desktopChoice,
    "post-catch nickname dialogue and YES/NO prompt render together")
  context.renderHud({ context.battle, newCatchPrompt(), newCatchChoice() },
    "battle_catch_nickname_prompt_compact", context.compactViewport)
  local dialoguePanel, choicePanel = promptPanels()
  check(dialoguePanel and choicePanel
      and choicePanel.y + choicePanel.h <= dialoguePanel.y + 0.51,
    "compact post-catch prompt stays visible with its choice clear of dialogue")
  local catchNaming = setmetatable({
    screenId = "NamingScreen", title = "NICKNAME?", maxLen = 10,
    glyphs = {}, row = 1, col = 1, lower = false,
    grid = function()
      return {
        { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
        { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
        { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
        { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
        { "-", "?", "!", "(", ")", "/", ".", ",", "ED" },
        { "lower case" },
      }
    end,
  }, { __index = context.namingClass })
  check(context.alphaBounds(context.renderHud({ catchNaming },
      "battle_catch_nickname_entry", context.portraitViewport)) ~= nil,
    "post-catch NamingScreen renders its complete modern keyboard")
  context.battle.blankForAskName, context.battle.phase = oldBlank, oldPhase
end

function love.load()
  local entryPath = os.getenv("GEN1_UI_MAIN")
  check(entryPath and entryPath ~= "", "GEN1_UI_MAIN is required")
  local assetRoot = entryPath:gsub("[\\/]main%.lua$", "assets")
  local mountedAssets = false
  if love.filesystem.mount then
    local mountOk, mountResult = pcall(love.filesystem.mount, assetRoot, "assets")
    mountedAssets = mountOk and mountResult == true
  end
  if mountedAssets then
    for _, name in ipairs({ "pixel_frame1.png", "pixel_frame2.png",
        "pixel_frame3.png" }) do
      check(love.filesystem.getInfo("assets/" .. name, "file"),
        "mounted " .. name .. " is readable")
    end
  end
  -- gen1recomp owns Plain Pixel rather than the mod archive. CI and local
  -- probes can mount the host asset at its production virtual path so the
  -- real font rasterization and multilingual glyph coverage are exercised.
  stagePlainPixelHostAsset()
  local hooks = {}
  local eventListeners = {}
  local values = {}
  local savedPins = {}
  local pointerTaps = {}
  local schemas = {}
  local modAssetLoads = 0
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
  local optionsDraws = 0
  local optionsClass = { draw = function() optionsDraws = optionsDraws + 1 end }
  local partyClass = { draw = function() end }
  local summaryClass = { draw = function() end }
  local dexEntryClass = { draw = function() end }
  local managerClass = { draw = function() end }
  local linkClass = { draw = function() end, isOpaque = true }
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
  package.loaded["src.ui.MoveLearnMenu"] = { draw = function() end }
  package.loaded["src.ui.PicBox"] = { draw = function() end }
  package.loaded["src.ui.NamingScreen"] = { draw = function() end }
  package.loaded["src.ui.OakSpeech"] = {
    draw = function() end,
    isOpaque = true,
  }
  package.loaded["src.ui.TownMap"] = { draw = function() end }
  package.loaded["src.ui.QuarantineReport"] = { draw = function() end }
  package.loaded["src.mods.ManagerState"] = managerClass
  package.loaded["src.link.LinkState"] = linkClass
  package.loaded["src.world.OverworldController"] = overworldClass
  package.loaded["src.ui.TitleState"] = titleClass
  package.loaded["src.pokemon.Stats"] = statsLibrary
  local mod = {
    find = function(id)
      if values.externalHandles and values.externalHandles[id] then
        return values.externalHandles[id]
      end
      if id == "rby_mmo" and values.rbyPartyExports then
        return { id = id, version = "0.8.0", exports = values.rbyPartyExports }
      end
      return nil
    end,
    assets = {
      image = function(_, relative)
        modAssetLoads = modAssetLoads + 1
        return love.graphics.newImage(relative)
      end,
    },
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
    input = {
      tap = function(_, targetGame, button)
        pointerTaps[#pointerTaps + 1] = { game = targetGame, button = button }
        local input = targetGame and targetGame.input
        if input and type(input.sourcePress) == "function"
            and type(input.sourceRelease) == "function" then
          local source = "test:mod.tap:" .. tostring(#pointerTaps)
          input:sourcePress(button, source)
          input:sourceRelease(button, source)
        end
        return true
      end,
    },
    ui = {
      Menu = menuClass, ListMenu = listClass,
      ChoiceBox = choiceClass, QuantityBox = quantityClass,
      TextBox = textBoxClass,
      push = function(targetGame, screen)
        if screen ~= "ManagerState" then return nil end
        local manager = setmetatable({
          game = targetGame,
          screenId = "ManagerState", screen = "list", cursor = 1, optionRows = {},
          isOpaque = true,
          byId = { ["gen1_modern_ui"] = { id = "gen1_modern_ui" } },
          openOptions = function(self)
            self.screen = "options"
            self.optionRows = { { id = "theme", label = "UI THEME" } }
          end,
        }, { __index = managerClass })
        targetGame.stack:push(manager)
        return manager
      end,
    },
    save = {
      get = function(_, key, default) return savedPins[key] or default end,
      set = function(_, key, value) savedPins[key] = value end,
    },
  }

  local installer, loadError = loadfile(entryPath)
  check(installer, loadError)
  installer = installer()
  check(type(installer) == "function", "entry must return an installer")
  installer(mod)

  local themeRow, frameStyleRow, frameAssetRow, frameScaleRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "theme" then themeRow = row end
      if row.key == "frameStyle" then frameStyleRow = row end
      if row.key == "frameAsset" then frameAssetRow = row end
      if row.key == "frameScale" then frameScaleRow = row end
    end
  end
  check(themeRow and type(themeRow.choices) == "table", "theme choices registered")
  check(themeRow.default == "gen1_modern_ui:classic_mono",
    "Classic Mono is the first-run theme")
  check(frameStyleRow and #frameStyleRow.choices == 4
      and frameStyleRow.choices[1][2] == "theme"
      and frameStyleRow.choices[4][2] == "plain"
      and frameStyleRow.default == "pixel",
    "frame style exposes theme, pixel, soft, and plain treatments")
  check(frameAssetRow and #frameAssetRow.choices == 3
      and frameAssetRow.default == "2",
    "pixel frame 2 is the first-run authored frame")
  check(frameScaleRow and #frameScaleRow.choices == 4
      and frameScaleRow.choices[1][2] == "1"
      and frameScaleRow.choices[4][2] == "4"
      and frameScaleRow.default == "2",
    "pixel frame scale exposes whole-number 1X through 4X choices")
  check(optionDefault(schemas, "pixelFont") == false,
    "the experimental pixel-art font defaults off")
  check(mod.exports.pixelFontTokens
      and mod.exports.pixelFontTokens.cellHeight == 11
      and mod.exports.pixelFontTokens.rasterStep == 15
      and mod.exports.pixelFontTokens.coordinateStep == 1,
    "pixel font exposes its 11-row cell and 15-point raster contract")
  check(mod.exports.scaleTokens.uiMax == 4
      and mod.exports.scaleTokens.fontMax == 4
      and mod.exports.scaleTokens.fontAutoMax == 5,
    "public scale tokens distinguish manual 400% from system-font AUTO 500%")
  check(optionDefault(schemas, "pointerUi") == false
      and optionDefault(schemas, "dragPanels") == false,
    "experimental pointer interaction and panel dragging default off")
  local battleWipRow, battleModeRow, battle3dBypassRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "battleUiWip" then battleWipRow = row end
      if row.key == "battleUiMode" then battleModeRow = row end
      if row.key == "battle3dBypass" then battle3dBypassRow = row end
    end
  end
  check(battleWipRow and battleWipRow.default == false,
    "battle UI remains opt-in while WIP")
  check(battleModeRow and #battleModeRow.choices == 3
      and battleModeRow.choices[1][2] == "auto"
      and battleModeRow.choices[2][2] == "full"
      and battleModeRow.choices[3][2] == "hud"
      and battleModeRow.default == "auto",
    "battle UI retains AUTO, 2D FRAMED, and the legacy SCENE HUD alias")
  check(battle3dBypassRow and battle3dBypassRow.default == true,
    "3D battle native ownership bypass defaults on")
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
  check(mod.exports.layoutPresets
      and mod.exports.layoutPresets.NAV
      and mod.exports.layoutPresets.NAV.width == 440
      and mod.exports.layoutPresets.NAV.height == 560,
    "NAV envelope remains the tall 440x560 Start-menu contract")
  local uiScaleRow, fontScaleRow, dialogueScaleRow
  for _, schema in ipairs(schemas) do
    for _, row in ipairs(schema) do
      if row.key == "uiScale" then uiScaleRow = row end
      if row.key == "fontScale" then fontScaleRow = row end
      if row.key == "dialogueTextScale" then dialogueScaleRow = row end
    end
  end
  check(uiScaleRow and #uiScaleRow.choices == 27 and uiScaleRow.choices[1][2] == "auto"
      and uiScaleRow.default == "100",
    "UI scale preserves 75%-150% steps and adds high-resolution presets through 400%")
  check(fontScaleRow and #fontScaleRow.choices == 34 and fontScaleRow.choices[1][2] == "auto"
      and fontScaleRow.default == "100",
    "font scale preserves 80%-200% steps and adds high-resolution presets through 400%")
  check(dialogueScaleRow and #dialogueScaleRow.choices == 6
      and dialogueScaleRow.default == "inherit",
    "dialogue scale exposes inherit and readability presets")
  check(mod.exports.getScaleTokens().uiScale == 1
      and mod.exports.getScaleTokens().fontScale == 1
      and mod.exports.getScaleTokens().dialogueTextScale == 1,
    "scale token API reports default effective sizes")
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
    "gen1_modern_ui:light",
    "gen1_modern_ui:dark",
  }
  check(#themeRow.choices == #expectedThemes, "all built-in themes registered once")
  for index, id in ipairs(expectedThemes) do
    check(themeRow.choices[index][2] == id, "built-in theme order: " .. id)
  end
  check(mod.exports.themes["gen1_modern_ui:modern_glass"].colors.backdrop[4] == 0.72,
    "glass theme retains authored backdrop alpha")
  local function channelLuminance(color)
    local function linear(channel)
      return channel <= 0.03928 and channel / 12.92
        or ((channel + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * linear(color[1]) + 0.7152 * linear(color[2])
      + 0.0722 * linear(color[3])
  end
  local function contrastRatio(first, second)
    local a = channelLuminance(first)
    local b = channelLuminance(second)
    local light = math.max(a, b)
    local dark = math.min(a, b)
    return (light + 0.05) / (dark + 0.05)
  end
  for _, id in ipairs(expectedThemes) do
    local colors = mod.exports.themes[id].colors
    check(contrastRatio(colors.text, colors.surface) >= 4.5,
      "theme text has readable surface contrast: " .. id)
    check(contrastRatio(colors.text, colors.selected) >= 3.0,
      "theme selected rows retain text contrast: " .. id)
    check(contrastRatio(colors.textMuted, colors.surface) >= 3.0,
      "theme muted text remains readable: " .. id)
  end

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
  check(type(hooks["screen.render_visible"]) == "function",
    "screen.render_visible hook registered")
  check(type(hooks["ui.naming.grid"]) == "function",
    "naming grid hook registered")
  check(type(hooks["ui.state.decorate"]) == "function",
    "ui.state.decorate hook registered")
  check(type(eventListeners["screen.pushed"]) == "function",
    "screen lifecycle visibility listener registered")
  check(type(eventListeners["screen.popped"]) == "function",
    "screen lifecycle palette restore listener registered")
  check(type(eventListeners["map.entered"]) == "function",
    "QOL location banner replacement listener registered")

  local adapterActions = {}
  values.externalHandles = {
    test_source = { id = "test_source", version = "1.2.3", exports = {} },
  }
  local adapterContract = {
    apiVersion = 1,
    screens = {
      TestScreen = {
        match = function(state) return state.screenId == "TestScreen" end,
        model = function()
          return { title = "TEST", rows = { { label = "ROW",
              image = "badge" } }, index = 1, scroll = 0,
            footer = { "A choose" },
            assets = { badge = "assets/pixel_frame1.png" } }
        end,
        actions = {
          select = function(_, _, index) adapterActions.select = index end,
          hover = function(_, _, index) adapterActions.hover = index end,
        },
        layer = "screen", canSuppressNative = true,
      },
      Battle = {
        match = function(state)
          return state.screenId == "TestBattle"
        end,
        model = function(_, state)
          return {
            title = "BATTLE", rows = { "FIGHT", "ITEM" }, index = 1,
            phase = state.phase, player = state.player, enemy = state.enemy,
            moves = state.moves, message = state.message,
            overlays = state.overlays,
          }
        end,
        actions = {
          select = function(_, state) state.selected = true end,
        },
        layer = "battle", canSuppressNative = true,
      },
    },
    themes = {
      test = {
        name = "Test Source Theme",
        frame = { style = "pixel", asset = "test_source:frame" },
      },
      alternate = {
        name = "Alternate Source Theme",
        frame = { style = "pixel", asset = "test_source:frame-two" },
      },
    },
    frames = {
      frame = { asset = "assets/pixel_frame1.png" },
      ["frame-two"] = { asset = "assets/pixel_frame2.png" },
    },
  }
  check(mod.exports.compatibilityApiVersion == 1,
    "compatibility API version is exported")
  check(mod.exports.registerAdapter({ owner = "test_source",
    contract = adapterContract }), "valid source adapter registers")
  check(mod.exports.frames["test_source:frame"] == "assets/pixel_frame1.png",
    "adapter contract registers a namespaced source frame")
  check(mod.exports.frames["test_source:frame-two"] == "assets/pixel_frame2.png",
    "adapter contract registers multiple source frames")
  do
    local hasFrameOne, hasFrameTwo = false, false
    for _, choice in ipairs(mod.exports.frameChoices) do
      hasFrameOne = hasFrameOne or choice[2] == "test_source:frame"
      hasFrameTwo = hasFrameTwo or choice[2] == "test_source:frame-two"
    end
    check(#mod.exports.frameChoices == 5 and hasFrameOne and hasFrameTwo,
      "multiple source frames appear in the pixel-frame selector")
  end
  check(mod.exports.themes["test_source:test"]
      and mod.exports.themes["test_source:test"].frame.asset
        == "test_source:frame",
    "adapter contract registers a source theme using its frame")
  check(mod.exports.themes["test_source:alternate"]
      and mod.exports.themes["test_source:alternate"].frame.asset
        == "test_source:frame-two",
    "adapter contract registers multiple source themes")
  check(mod.exports.registerFrame({ owner = "test_source", id = "direct-frame",
    asset = "assets/pixel_frame2.png" }) == "test_source:direct-frame",
    "theme-only source mods can register namespaced frame assets")
  mod.exports.registerTheme({ owner = "test_source", id = "test_source:direct",
    name = "Direct Source Theme",
    frame = { style = "pixel", asset = "test_source:direct-frame" },
  })
  check(mod.exports.themes["test_source:direct"] ~= nil,
    "theme-only source mods can register a frame-backed theme")
  check(not mod.exports.registerAdapter({ owner = "test_source",
    contract = { apiVersion = 99, screens = {} } }),
    "unsupported adapter versions are rejected")
  check(not mod.exports.registerAdapter({ owner = "test_source",
    contract = { apiVersion = 1, screens = { Bad = { match = function() return true end,
      model = function() return {} end, draw = function() end } } } }),
    "third-party draw callbacks are rejected")
  do
    local adapterGame = { overworld = {}, stack = {} }
    local adapterState = { screenId = "TestScreen", isOpaque = true,
      draw = function() end }
    adapterGame.stack.states = { adapterGame.overworld, adapterState }
    adapterGame.stack.top = function(self) return self.states[#self.states] end
    hooks["render.zones"](function(_, zones) return zones end, adapterGame, {})
    check(hooks["screen.render_visible"](function(visible) return visible end,
      true, adapterState) == false,
      "valid adapter suppresses only its native draw")
    local normalizedModel = mod._gen1ModernCompatibility:modelFor(
      adapterGame, adapterState)
    check(normalizedModel and normalizedModel.assets
        and normalizedModel.assets.badge == "assets/pixel_frame1.png",
      "source model preserves a public image asset catalog")
    check(mod._gen1ModernCompatibility:action(adapterGame, adapterState,
      "select", 3) and adapterActions.select == 3,
      "adapter actions remain source-owned semantic callbacks")
    check(mod._gen1ModernCompatibility:action(adapterGame, adapterState,
      "hover", 2) and adapterActions.hover == 2,
      "adapter hover actions receive row context")
    local battleAdapterState = { screenId = "TestBattle", phase = "menu",
      player = { mon = { species = "TESTMON", hp = 10 } },
      enemy = { mon = { species = "TESTMON", hp = 8 } },
      overlays = { caughtIndicator = { caught = true } } }
    local battleModel = mod._gen1ModernCompatibility:modelFor(
      adapterGame, battleAdapterState)
    check(battleModel and battleModel.player and battleModel.overlays,
      "battle adapter preserves public battlers and data-only overlays")
    check(mod._gen1ModernCompatibility:action(adapterGame,
      battleAdapterState, "select") and battleAdapterState.selected == true,
      "battle adapter actions remain source-owned")
    local usefulBagState = {
      screenId = "BagMenu", items = {}, title = "MEDICINE", index = 1,
      scroll = 0, __pocketIndex = 2, __pocketIds = {},
      __project = function() end,
    }
    check(mod._gen1ModernCompatibility:isUsefulBagState(usefulBagState),
      "Useful Bag's public pocket projection is recognized")
    usefulBagState.__pocketIds = nil
    check(not mod._gen1ModernCompatibility:isUsefulBagState(usefulBagState),
      "malformed Useful Bag state stays on the native fallback")

    local extensionContract = {
      apiVersion = 1,
      extensions = {
        partyRows = {
          match = function(_, kind) return kind == "party" end,
          model = function() return {
            rows = { [1] = { background = "surfaceRaised" } },
          } end,
        },
        trainerPage = {
          match = function(_, kind) return kind == "trainer_card" end,
          model = function() return {
            pages = { { id = "notes", rows = { { label = "NOTES" } } } },
          } end,
        },
        battleLayout = {
          match = function(_, kind) return kind == "battle" end,
          model = function() return { battle = { cardWidth = 180 } } end,
        },
      },
    }
    check(mod.exports.registerAdapter({ owner = "test_source",
      contract = extensionContract }),
      "additive-only extension contract registers")
    local extensionRows = { { label = "ONE" }, { label = "TWO" } }
    mod._gen1ModernCompatibility:augmentRows(adapterGame,
      { party = {} }, "party", extensionRows)
    check(extensionRows[1].background == "surfaceRaised",
      "additive extension decorates an existing row")
    local trainerPages = mod._gen1ModernCompatibility:pagesFor(
      adapterGame, {}, "trainer_card")
    check(#trainerPages == 1 and trainerPages[1].page.id == "notes",
      "additive extension contributes a Trainer Card page")
    local battleOptions = mod._gen1ModernCompatibility:battleOptions(
      adapterGame, {})
    check(battleOptions.cardWidth == 180,
      "battle extension contributes data-only layout options")
    local nativeContract = {
      apiVersion = 1,
      battle = {
        native3d = function() return true end,
      },
      extensions = extensionContract.extensions,
    }
    check(mod.exports.registerAdapter({ owner = "test_source",
      contract = nativeContract }),
      "native 3D ownership contract registers")
    check(mod._gen1ModernCompatibility:isNative3dBattle(
        adapterGame, battleAdapterState),
      "native 3D ownership contract is detected")
    check(mod.exports.unregisterAdapter("test_source"),
      "native 3D ownership contract unregisters cleanly")
    values.externalHandles.dramatic_shape = {
      id = "dramatic_shape", version = "1.7.8", exports = {
        lib = {
          require = function(name)
            if name == "OverworldBattle" then
              return { enabled = function() return true end }
            end
          end,
        },
      },
    }
    check(mod._gen1ModernCompatibility:isNative3dBattle(
        adapterGame, battleAdapterState),
      "DramaticShape public OverworldBattle setting is detected")
    values.externalHandles.dramatic_shape = nil
  end
  check(mod.exports.registerFrame({ owner = "test_source", id = "frame",
    asset = "assets/pixel_frame1.png" }) == "test_source:frame",
    "source mods can register namespaced frame assets")
  check(mod.exports.unregisterAdapter("test_source"),
    "source adapter unregisters cleanly")
  check(mod.exports.frames["test_source:frame"] == nil
      and mod.exports.themes["test_source:test"] == nil
      and mod.exports.themes["test_source:alternate"] == nil
      and mod.exports.frames["test_source:direct-frame"] == nil
      and mod.exports.themes["test_source:direct"] == nil,
    "unregister removes source-owned theme and frame assets")
  check(#mod.exports.frameChoices == 3,
    "source frame choices are removed when the owner unregisters")
  do
    local bannerGame = {
      data = {
        field = { townMap = { locations = {
          PALLET_TOWN = { name = "Pallet Town" },
        } } },
      },
      save = { options = { modOptions = {
        quality_of_life = { qol_location_banners = 2 },
      } } },
    }
    check(mod._gen1ModernSpecialPresenters.qolLocationDuration(bannerGame) == 2,
      "QOL banner duration follows the saved feature option")
    check(mod._gen1ModernSpecialPresenters.qolLocationName(
        bannerGame, "PALLET_TOWN") == "PALLET TOWN",
      "QOL banner uses the resolved Town Map location name")
  end

  check(namingGridHasNumberRows(hooks["ui.naming.grid"]),
    "naming grid adds numeric entry before the case page")
  check(namingGridKeepsLowercase(hooks["ui.naming.grid"]),
    "naming grid keeps lowercase when a mod uses lower for digits")
  check(namingGridNormalizesRbyMmoSwitch(hooks["ui.naming.grid"]),
    "naming grid normalizes RBY MMO case-switch labels")
  values.menuUi = false
  check(not namingGridHasNumberRows(hooks["ui.naming.grid"]),
    "disabled menu UI leaves the native naming grid unchanged")
  values.menuUi = true

  do
    local titleGame = { stack = { states = {} } }
    local titleState = setmetatable({}, { __index = titleClass })
    local titleMenu = setmetatable({ game = titleGame,
      titleUiBox = { 0, 0, 12, 3 } }, { __index = menuClass })
    titleGame.stack.states = { titleState, titleMenu }
    eventListeners["screen.pushed"]({ state = titleMenu })
    check(titleMenu.titleUiBox[3] == 20 and titleMenu.titleUiBox[4] == 18,
      "title menu expands its palette zone while modern menu is active")
    eventListeners["screen.popped"]({ state = titleMenu })
    check(titleMenu.titleUiBox[3] == 12 and titleMenu.titleUiBox[4] == 3,
      "title menu restores its original palette zone on close")
  end

  local state = setmetatable({ screenId = "OptionsMenu", rows = {}, index = 1 },
    { __index = optionsClass })
  local overworld = overworldClass
  local game = { overworld = overworld, stack = {
    states = { overworld, state },
    top = function(self) return self.states[#self.states] end,
    push = function(self, value) self.states[#self.states + 1] = value end,
    pop = function(self) return table.remove(self.states) end,
    visibleBase = function(self)
      for index = #self.states, 1, -1 do
        if self.states[index].isOpaque then return index end
      end
      return 1
    end,
  } }
  do
    -- The lifecycle event must tolerate hosts that emit screen.pushed before
    -- the new state is visible in the stack. It must not make a transient
    -- native state transparent before the first complete modern frame exists.
    local transientMenu = setmetatable({ game = game, items = {
      { label = "POKEMON" },
    }, index = 1, isOpaque = true }, { __index = menuClass })
    local transientText = setmetatable({ game = game, pages = {
      { "HELLO" },
    }, pageIndex = 1, lineIndex = 1, charIndex = 0, isOpaque = true },
      { __index = textBoxClass })
    game.stack.states = { overworld }
    eventListeners["screen.pushed"]({ state = transientMenu })
    eventListeners["screen.pushed"]({ state = transientText })
    check(transientMenu.isOpaque == true and transientText.isOpaque == true,
      "early screen lifecycle events keep transient menu and dialogue native")
    game.stack.states = { overworld, transientMenu }
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, transientMenu) == false,
      "settled first-frame menu can be suppressed without opacity mutation")
    game.stack.states = { overworld, state }
  end
  do
    local oakSpeech = setmetatable({ screenId = "OakSpeech" },
      { __index = package.loaded["src.ui.OakSpeech"] })
    local namingState = setmetatable({ screenId = "NamingScreen" },
      { __index = package.loaded["src.ui.NamingScreen"] })
    local priorStates = game.stack.states
    game.stack.states = { overworld, oakSpeech, namingState }
    check(namingGridKeepsNativeNewGame(hooks["ui.naming.grid"], game),
      "New Game naming keeps the host-native keyboard")
    game.stack.states = priorStates
  end
  check(type(hooks["ui.start_menu.items"]) == "function",
    "start-menu hook registered")
  do
    local shortcutItems = hooks["ui.start_menu.items"](
      function(_, items) return items end, game,
      { { label = "SAVE" }, { label = "OPTION" }, { label = "MODS" } })
    local shortcutFound, modMenusRow
    for _, item in ipairs(shortcutItems) do
      if item.id == "gen1_modern_ui.options" then shortcutFound = true end
      if item.id == "gen1_modern_ui.mod_menus" then modMenusRow = item end
    end
    check(not shortcutFound and modMenusRow,
      "UI settings default under the MOD MENUS start entry")
    -- Match the host Menu lifecycle: selecting a start-menu entry closes the
    -- current menu before its callback pushes the destination screen.
    game.stack:pop()
    modMenusRow.onSelect()
    local groupedMenu = game.stack:top()
    check(groupedMenu._gen1ModMenus and #groupedMenu.items == 1
        and groupedMenu.items[1].id == "gen1_modern_ui.options",
      "MOD MENUS contains UI SETTINGS by default")
    values.menuUi, values.dialogueUi, values.managerUi = false, false, true
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, groupedMenu) == false,
      "real MOD MENUS remains owned when generic menu and dialogue UI are off")
    groupedMenu.items[1].onSelect()
    local shortcutManager = game.stack:top()
    check(shortcutManager.currentMod
        and shortcutManager.currentMod.id == "gen1_modern_ui",
      "UI SETTINGS shortcut opens the categorized modern options context")
    hooks["input.step"](function() end,
      { input = { pressQueue = {} }, stack = game.stack }, 0)
    check(shortcutManager.optionRows[1]
        and shortcutManager.optionRows[1].id == "__category:appearance",
      "direct UI SETTINGS opens with categorized option rows")
    values.galleryAction = shortcutManager._gen1OptionGroups
      and shortcutManager._gen1OptionGroups.advanced
      and shortcutManager._gen1OptionGroups.advanced.rows[1]
    check(values.galleryAction
        and values.galleryAction.id == "gen1_modern_ui.gallery.open"
        and type(values.galleryAction.activate) == "function",
      "Advanced UI settings exposes the stable UI Gallery action")
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, shortcutManager) == false,
      "mod manager remains modern when generic menu and dialogue UI are off")
    game.stack:pop()
    game.stack:pop()
    values.menuUi, values.dialogueUi = true, true
    -- Restore the supported screen used by the compose-fallback checks below.
    game.stack:push(state)
  end
  local modMenuRow = { id = "example.dexnav", label = "DEXNAV",
    onSelect = function() end }
  do
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
  do
    local clonedVanilla = {
      { id = "pokemon", label = "POKEMON" },
      { id = "items", label = "ITEM" },
      { id = "options", label = "OPTION" },
    }
    local clonedItems = hooks["ui.start_menu.items"](
      function(_, list)
        local copied = {}
        for index, item in ipairs(list) do
          copied[index] = { id = item.id, label = item.label,
            onSelect = item.onSelect }
        end
        copied[#copied + 1] = {
          id = "example.cloned_mod", label = "CLONED MOD",
          onSelect = function() end,
        }
        return copied
      end, game, clonedVanilla)
    local vanillaCount, clonedModLeaked, clonedGroup = 0, false, false
    for _, item in ipairs(clonedItems) do
      if item.id == "pokemon" or item.id == "items" or item.id == "options" then
        vanillaCount = vanillaCount + 1
      elseif item.id == "example.cloned_mod" then
        clonedModLeaked = true
      elseif item.id == "gen1_modern_ui.mod_menus" then
        clonedGroup = true
      end
    end
    check(vanillaCount == 3 and clonedGroup and not clonedModLeaked,
      "Start menu keeps vanilla rows when another hook clones descriptors")
  end
  local pinMenuRow
  for _, item in ipairs(groupedItems) do
    if item.id == "gen1_modern_ui.mod_menus" then pinMenuRow = item end
  end
  check(pinMenuRow and type(pinMenuRow.onSelect) == "function",
    "MOD MENUS exposes a navigable grouped submenu")
  pinMenuRow.onSelect()
  local pinMenu = game.stack:top()
  local dexIndex
  local settingsIndex
  for index, item in ipairs(pinMenu.items) do
    if item.id == "example.dexnav" then dexIndex = index end
    if item.id == "gen1_modern_ui.options" then settingsIndex = index end
  end
  check(dexIndex and settingsIndex,
    "grouped submenu retains every third-party row and UI SETTINGS")
  pinMenu.index = dexIndex
  local pinInput = { pressQueue = { "select" } }
  values.pinSaveWrites = 0
  local pinGame = { input = pinInput, stack = game.stack, save = {},
    writeSave = function() values.pinSaveWrites = values.pinSaveWrites + 1 end }
  hooks["input.step"](function() end, pinGame, 0)
  check(savedPins.startMenuPins and savedPins.startMenuPins["example.dexnav"] == true
      and #pinInput.pressQueue == 0,
    "SELECT pins the highlighted mod menu")
  check(values.pinSaveWrites == 1,
    "SELECT flushes the pinned mod menu to the active save")
  game.stack:pop()
  local pinnedItems = hooks["ui.start_menu.items"](
    function(_, list) list[#list + 1] = modMenuRow return list end, game,
    { { label = "OPTION" }, { label = "MODS" } })
  local pinnedDirect, pinnedGroup = false, false
  for _, item in ipairs(pinnedItems) do
    if item.id == "example.dexnav" then pinnedDirect = true end
    if item.id == "gen1_modern_ui.mod_menus" then pinnedGroup = true end
  end
  check(pinnedDirect and pinnedGroup,
    "pinned mod menus remain direct while other rows stay grouped")
  local pinnedDirectRow
  for _, item in ipairs(pinnedItems) do
    if item.id == "example.dexnav" then pinnedDirectRow = item end
  end
  check(pinnedDirectRow and pinnedDirectRow._gen1Pinned == true,
    "pinned direct rows carry a visible presentation marker")

  -- A pinned row remains in MOD MENUS so SELECT can toggle it back off.
  local pinnedGroupRow
  for _, item in ipairs(pinnedItems) do
    if item.id == "gen1_modern_ui.mod_menus" then pinnedGroupRow = item end
  end
  pinnedGroupRow.onSelect()
  local pinnedGroupMenu = game.stack:top()
  local pinnedDexIndex
  for index, item in ipairs(pinnedGroupMenu.items) do
    if item.id == "example.dexnav" then pinnedDexIndex = index end
  end
  check(pinnedDexIndex, "pinned row remains available in MOD MENUS")
  pinnedGroupMenu.index = pinnedDexIndex
  local unpinInput = { pressQueue = { "select" } }
  hooks["input.step"](function() end, { input = unpinInput, stack = game.stack }, 0)
  check(savedPins.startMenuPins and savedPins.startMenuPins["example.dexnav"] == false
      and #unpinInput.pressQueue == 0,
    "SELECT unpins the highlighted mod menu")
  game.stack:pop()
  local unpinnedItems = hooks["ui.start_menu.items"](
    function(_, list) list[#list + 1] = modMenuRow return list end, game,
    { { label = "OPTION" }, { label = "MODS" } })
  local directAfterUnpin = false
  for _, item in ipairs(unpinnedItems) do
    if item.id == "example.dexnav" then directAfterUnpin = true end
  end
  check(not directAfterUnpin,
    "unpinning removes the row from the root Start menu")
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
  end
  check(type(hooks["input.step"]) == "function", "Start fast-jump hook registered")
  do
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
      top = function() return optionState end,
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

    values.battleUiWip, values.battleUiMode = true, "full"
    local moveState = {
      phase = "moveSelect", moveIndex = 1,
      player = { curMoves = { {}, {}, {}, {} } },
    }
    local moveGame = { input = { pressQueue = {} }, stack = {
      top = function() return moveState end,
    } }
    for _, layoutCase in ipairs({
        { name = "callback false", value = function() return false end },
        { name = "boolean false", value = false },
        { name = "missing metadata", missing = true },
      }) do
      moveState.moveIndex = 1
      moveState.wideLayout = layoutCase.missing and nil or layoutCase.value
      moveGame.input.pressQueue = { "right" }
      hooks["input.step"](function() end, moveGame, 0)
      check(moveState.moveIndex == 1 and moveGame.input.pressQueue[1] == "right",
        layoutCase.name .. " battle keeps native move navigation untouched")
    end
    for _, layoutCase in ipairs({
        { name = "callback true", value = function() return true end },
      }) do
      moveState.moveIndex = 1
      moveState.wideLayout = layoutCase.value
      moveGame.input.pressQueue = { "right" }
      hooks["input.step"](function() end, moveGame, 0)
      check(moveState.moveIndex == 1 and moveGame.input.pressQueue[1] == "right",
        layoutCase.name .. " WIDE battle keeps directional input source-owned")
    end
    moveState.wideLayout = false
    moveState.dramaticShapeShot = { canvas = true }
    values.battleUiMode = "auto"
    values.battle3dBypass = true
    moveGame.input.pressQueue = { "right" }
    hooks["input.step"](function() end, moveGame, 0)
    check(moveState.moveIndex == 1 and moveGame.input.pressQueue[1] == "right",
      "AUTO 3D scene battle keeps directional input source-owned")
    values.battleUiWip, values.battleUiMode, values.battle3dBypass = false, "auto", true
  end
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

  values.managerUi = true
  values.dialogueUi = false
  local modMenusState = setmetatable({
    _gen1ModMenus = true,
    items = { { label = "UI SETTINGS" } },
    index = 1,
  }, { __index = menuClass })
  game.stack.states = { overworld, modMenusState }
  hooks["render.zones"](function(_, zones) return zones end, game, {})
  fill()
  compose(false)
  check(alpha() == 0,
    "MOD MENUS remains modern when menu and dialogue UI are disabled")
  check(hooks["screen.render_visible"](
      function(visible) return visible end, true, modMenusState) == false,
    "MOD MENUS native rows stay suppressed under its manager presenter")

  values.menuUi = true
  values.dialogueUi = true
  do
    local oakSpeech = setmetatable({
      screenId = "OakSpeech",
      isOpaque = true,
    }, { __index = package.loaded["src.ui.OakSpeech"] })
    local nativeChoice = setmetatable({
      items = { { label = "NEW NAME" } },
      index = 1,
      isOpaque = true,
    }, { __index = menuClass })
    game.stack.states = { overworld, oakSpeech, nativeChoice }
    oakSpeech.game = game
    eventListeners["screen.pushed"]({ state = oakSpeech })
    eventListeners["screen.pushed"]({ state = nativeChoice })
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    fill()
    compose(false)
    check(alpha() == 1,
      "New Game Oak flow keeps the complete native UI canvas")
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, nativeChoice) == true,
      "New Game nested menus remain visible through precise suppression")

    local staleGame = { stack = { states = { overworld, state } } }
    hooks["render.zones"](function(_, zones) return zones end, staleGame, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, nativeChoice) == true,
      "New Game child keeps cached ownership over a stale render cache")
    check(namingGridKeepsNativeNewGame(hooks["ui.naming.grid"], nil,
        nativeChoice),
      "New Game keyboard stays native without an explicit game context")
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    game.stack:pop()
    eventListeners["screen.popped"]({ state = nativeChoice })
    game.stack:pop()
    eventListeners["screen.popped"]({ state = oakSpeech })
    check(namingGridHasNumberRows(hooks["ui.naming.grid"]),
      "New Game native ownership clears after returning to overworld")
  end

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
  -- suppresses only that ordinary Menu draw; compose must preserve the whole
  -- canvas so the title background and artwork cannot become a black block.
  -- Some v0.1.68 title instances omit screenId; class identity is the
  -- stable fallback used by the mod's title suppression path.
  local title = setmetatable({}, { __index = titleClass })
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
  check(alphaAt(0, 0) == 1 and alphaAt(15, 15) == 1,
    "title artwork remains intact while the native menu is suppressed")
  game.stack.states = { title, titleMenu, { draw = function() end } }
  menuDraws = 0
  titleMenu:draw()
  check(menuDraws == 1,
    "title Menu restores its classic draw when an unknown overlay blocks presentation")

  -- Options opened from the title share the title UI canvas. The modern
  -- options presenter must suppress only the native options rows, then let
  -- them return if an unknown overlay makes the replacement unsafe.
  local titleOptions = setmetatable({ screenId = "OptionsMenu", game = game,
    rows = {}, index = 1 }, { __index = optionsClass })
  titleOptions = hooks["ui.state.decorate"](
    function(_, value) return value end, game, titleOptions, nil)
  game.stack.states = { title, titleOptions }
  optionsDraws = 0
  titleOptions:draw()
  check(optionsDraws == 0,
    "title-launched OptionsMenu suppresses its native shared-canvas draw")
  game.stack.states = { title, titleOptions, { draw = function() end } }
  optionsDraws = 0
  titleOptions:draw()
  check(optionsDraws == 1,
    "title-launched OptionsMenu restores native draw behind an unknown overlay")

  local link = setmetatable({ stage = "menu", index = 1 },
    { __index = linkClass })
  game.stack.states = { overworld, link }
  fill()
  compose(false)
  check(alpha() == 0, "released LinkState is modernized by the menu presenter")

  local bag = setmetatable({ screenId = "BagMenu", items = {}, index = 1 },
    { __index = listClass })
  local choice = setmetatable({ index = 1 }, { __index = choiceClass })
  local choiceNavigationState = setmetatable({ index = 1 },
    { __index = choiceClass })
  local choiceNavigationInput = {
    pressQueue = { "left" }, state = { left = false, right = false,
      up = false, down = false }, sources = {},
  }
  function choiceNavigationInput:sourcePress(button, source)
    self.sources[button] = self.sources[button] or {}
    self.sources[button][source] = true
    self.state[button] = true
    self.pressQueue[#self.pressQueue + 1] = button
  end
  function choiceNavigationInput:sourceRelease(button, source)
    self.sources[button][source] = nil
    self.state[button] = false
  end
  function choiceNavigationInput:step()
    for _, button in ipairs(self.pressQueue) do
      local sources = self.sources[button]
      if sources == nil then
        self.state[button] = true
      elseif next(sources) ~= nil then
        self.state[button] = true
      end
    end
    for button, sources in pairs(self.sources) do
      if next(sources) == nil then self.sources[button] = nil end
    end
    self.pressQueue = {}
  end
  local choiceNavigationGame = { input = choiceNavigationInput, stack = {
    top = function() return choiceNavigationState end,
  } }
  local choiceTapStart = #pointerTaps
  hooks["input.step"](function() choiceNavigationInput:step() end,
    choiceNavigationGame, 0)
  check(#choiceNavigationInput.pressQueue == 0
      and #pointerTaps == choiceTapStart + 1
      and pointerTaps[#pointerTaps].button == "up"
      and choiceNavigationInput.state.up == false,
    "horizontal LEFT becomes a source-safe YES/NO up tap")
  choiceNavigationInput.pressQueue = { "right" }
  hooks["input.step"](function() choiceNavigationInput:step() end,
    choiceNavigationGame, 0)
  check(#choiceNavigationInput.pressQueue == 0
      and #pointerTaps == choiceTapStart + 2
      and pointerTaps[#pointerTaps].button == "down"
      and choiceNavigationInput.state.down == false,
    "horizontal RIGHT does not leave DOWN held after YES/NO navigation")
  while #pointerTaps > choiceTapStart do table.remove(pointerTaps) end
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

  local pendingTextBox = setmetatable({ pages = {}, pageIndex = 1,
    lineIndex = 1, charIndex = 0, shown = {}, done = false, isOpaque = true },
    { __index = textBoxClass })
  game.stack.states = { overworld, pendingTextBox }
  fill()
  compose(false)
  check(alpha() == 1,
    "pending New Game dialogue keeps the native UI until text is ready")
  hooks["render.zones"](function(_, zones) return zones end, game, {})
  check(hooks["screen.render_visible"](
      function(visible) return visible end, true, pendingTextBox) == true,
    "pending New Game dialogue is never hidden by precise suppression")

  local pendingMenu = setmetatable({ screenId = "Menu", items = {},
    index = 1, isOpaque = true }, { __index = menuClass })
  game.stack.states = { overworld, pendingMenu }
  fill()
  compose(false)
  check(alpha() == 1,
    "pending New Game name choice remains native until choices exist")
  hooks["render.zones"](function(_, zones) return zones end, game, {})
  check(hooks["screen.render_visible"](
      function(visible) return visible end, true, pendingMenu) == true,
    "pending New Game name choice is never hidden by precise suppression")

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
  game.stack.states = { state }
  fill()
  compose(false)
  check(alpha() == 0, "recognized Gen3 Box instance draw remains suppressible")

  state = { phase = "command", queue = {}, kind = "wild" }
  game.stack.states = { state }
  fill()
  compose(false)
  check(alpha() == 1, "battle UI stays native while WIP presenter is off")

  do
    local originalDraw = function(self) self.drawCalls = (self.drawCalls or 0) + 1 end
    local originalHud = function(self) self.hudCalls = (self.hudCalls or 0) + 1 end
    local originalText = function(self) self.textCalls = (self.textCalls or 0) + 1 end
    local originalPics = function(self) self.pictureCalls = (self.pictureCalls or 0) + 1 end
    local disabledBattle = {
      game = game, phase = "menu", queue = {}, kind = "wild",
      bgMode = function() return "world" end,
      wideLayout = function() return true end,
      draw = originalDraw, drawHUDs = originalHud,
      drawTextArea = originalText, drawPicsLayer = originalPics,
    }
    local decoratedBattle = hooks["ui.state.decorate"](
      function(_, value) return value end, game, disabledBattle, nil)
    check(decoratedBattle.draw == originalDraw
        and decoratedBattle.drawHUDs == originalHud
        and decoratedBattle.drawTextArea == originalText
        and decoratedBattle.drawPicsLayer == originalPics
        and decoratedBattle._gen1ModernBattleSceneIsolation == nil,
      "disabled battle UI leaves every native battle draw path untouched")

    local originalChildDraw = function(self)
      self.childDrawCalls = (self.childDrawCalls or 0) + 1
    end
    local introChild = { game = game, screenId = "ProfessorOakIntro",
      draw = originalChildDraw }
    game.stack.states = { disabledBattle, introChild }
    introChild = hooks["ui.state.decorate"](
      function(_, value) return value end, game, introChild, nil)
    check(introChild.draw == originalChildDraw
        and introChild._gen1ModernBattleChildDraw == nil,
      "disabled battle UI leaves intro and battle-child screens native")

    local disabledBattleBag = setmetatable({
      screenId = "BagMenu", items = {}, index = 1, scroll = 0,
      isOpaque = true,
    }, { __index = listClass })
    game.stack.states = { disabledBattle, disabledBattleBag }
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(disabledBattleBag.isOpaque == true,
      "disabled battle UI preserves opaque in-battle child screens")
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, disabledBattleBag) == true,
      "disabled battle UI keeps in-battle Bag and Party screens native")
    fill()
    compose(false)
    check(alpha() == 1,
      "disabled battle UI keeps the native in-battle child canvas visible")
    game.stack.states = { disabledBattle, introChild }

    values.battleUiWip = true
    disabledBattle = hooks["ui.state.decorate"](
      function(_, value) return value end, game, disabledBattle, nil)
    introChild = hooks["ui.state.decorate"](
      function(_, value) return value end, game, introChild, nil)
    check(disabledBattle.draw ~= originalDraw
        and disabledBattle.drawHUDs == originalHud
        and disabledBattle.drawTextArea == originalText
        and disabledBattle.drawPicsLayer == originalPics
        and introChild.draw == originalChildDraw
        and introChild._gen1ModernBattleChildDraw == nil,
      "enabled WIDE UI clips the source surface without shifting pictures or replacing native child/HUD fallbacks")

    values.battleUiWip = false
    game.stack.states = { disabledBattle, introChild }
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(disabledBattle.draw == originalDraw
        and disabledBattle.drawHUDs == originalHud
        and disabledBattle.drawTextArea == originalText
        and disabledBattle.drawPicsLayer == originalPics
        and introChild.draw == originalChildDraw,
      "disabling battle UI restores decorators installed earlier in the session")

    values.battleUiWip = true
    game.stack.states = { disabledBattle, introChild }
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(disabledBattle.draw ~= originalDraw
        and disabledBattle.drawHUDs == originalHud
        and introChild.draw == originalChildDraw
        and introChild._gen1ModernBattleChildDraw == nil,
      "re-enabling battle UI reinstalls scene decorators while retaining native child fallback")
    values.battleUiWip = false
    hooks["render.zones"](function(_, zones) return zones end, game, {})

    values.battleUiWip, values.battle3dBypass = true, true
    values.externalHandles.dramatic_shape = {
      id = "dramatic_shape", version = "1.7.8", exports = {
        lib = {
          require = function(name)
            if name == "OverworldBattle" then
              return { enabled = function() return true end }
            end
          end,
        },
      },
    }
    local native3dDraw = function() end
    local native3dHud = function() end
    local native3dText = function() end
    local native3dBattle = {
      game = game, phase = "menu", queue = {}, kind = "wild",
      draw = native3dDraw, drawHUDs = native3dHud,
      drawTextArea = native3dText,
    }
    local native3dChild = setmetatable({ game = game,
      screenId = "BagMenu", items = {}, index = 1, scroll = 0,
      isOpaque = true }, { __index = listClass })
    native3dBattle = hooks["ui.state.decorate"](
      function(_, value) return value end, game, native3dBattle, nil)
    native3dChild = hooks["ui.state.decorate"](
      function(_, value) return value end, game, native3dChild, nil)
    game.stack.states = { native3dBattle, native3dChild }
    hooks["render.zones"](function(_, zones) return zones end, game, {})
    check(native3dBattle.draw == native3dDraw
        and native3dBattle.drawHUDs == native3dHud
        and native3dBattle.drawTextArea == native3dText
        and native3dChild._gen1ModernBattleChildDraw == nil,
      "DramaticShape 3D-BTL leaves battle and child interfaces native")
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, native3dChild) == true,
      "DramaticShape 3D-BTL child remains visible to the native renderer")
    values.externalHandles.dramatic_shape = nil
    values.battleUiWip, values.battle3dBypass = false, true
    game.stack.states = { state }
  end

  values.battleUiWip = true
  values.battleUiMode = "full"
  do
    local hudCalls, textCalls = 0, 0
    local isolated = {
      phase = "menu", queue = {}, kind = "wild",
      wideLayout = function() return false end,
      drawHUDs = function() hudCalls = hudCalls + 1 end,
      drawTextArea = function() textCalls = textCalls + 1 end,
    }
    isolated = hooks["ui.state.decorate"](
      function(_, value) return value end, game, isolated, nil)
    isolated:drawHUDs(0)
    isolated:drawTextArea()
    check(hudCalls == 1 and textCalls == 1,
      "classic 2D battle keeps native HUD and text available as a fallback")
    isolated.introBalls = true
    isolated:drawHUDs(0)
    check(hudCalls == 2,
      "classic 2D battle preserves source-owned intro party-ball animation")
    isolated.introBalls = nil
    values.battleUiMode = "hud"
    isolated:drawHUDs(0)
    isolated:drawTextArea()
    check(hudCalls == 3 and textCalls == 2,
      "legacy HUD value leaves an ineligible standard battle wholly native")
    values.battleUiMode = "full"

    local worldBattle = {
      phase = "menu", queue = {}, kind = "wild",
      bgMode = function() return "world" end,
      wideLayout = function() return true end,
      drawPicsLayer = function(self, slide, sx, sy, onlySide)
        self.lastPictureSide = onlySide
        self.lastPictureX = sx
      end,
      draw = function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 304, 144)
        -- A white sprite pixel must remain opaque; WORLD transparency is
        -- achieved by suppressing the exact paper fill, never by color key.
        love.graphics.rectangle("fill", 150, 48, 4, 4)
      end,
    }
    worldBattle = hooks["ui.state.decorate"](
      function(_, value) return value end, game, worldBattle, nil)
    local worldCanvas = love.graphics.newCanvas(304, 144)
    local rectangleBefore = love.graphics.rectangle
    love.graphics.setCanvas(worldCanvas)
    love.graphics.clear(0, 0, 0, 0)
    worldBattle:draw()
    love.graphics.setCanvas()
    local worldImage = worldCanvas:newImageData()
    local worldEdgeR, worldEdgeG, worldEdgeB, worldEdgeA =
      worldImage:getPixel(20, 20)
    local worldPaperR, worldPaperG, worldPaperB, worldPaperA =
      worldImage:getPixel(40, 20)
    local worldSpriteR, worldSpriteG, worldSpriteB, worldSpriteA =
      worldImage:getPixel(151, 49)
    check(worldEdgeA > 0.95 and worldEdgeR > 0.95
        and worldEdgeG > 0.95 and worldEdgeB > 0.95,
      "WORLD battle paper reaches the complete source edge inside its frame")
    check(worldPaperA > 0.95 and worldPaperR > 0.95
        and worldPaperG > 0.95 and worldPaperB > 0.95,
      "WORLD battle decoration fills the modern arena with battle paper")
    check(worldSpriteA > 0.95 and worldSpriteR > 0.95
        and worldSpriteG > 0.95 and worldSpriteB > 0.95,
      "WORLD battle decoration preserves legitimate white sprite pixels")
    check(love.graphics.rectangle == rectangleBefore,
      "WORLD battle decoration restores the graphics API after source draw")
    worldBattle:drawPicsLayer(0, 0, 0, "enemy")
    check(worldBattle.lastPictureX == 0,
      "WIDE battle preserves source-authored opponent placement")
    worldBattle:drawPicsLayer(0, 0, 0, "player")
    check(worldBattle.lastPictureX == 0,
      "WIDE battle decoration leaves the player picture placement unchanged")

    local pushedHudCalls, pushedTextCalls = 0, 0
    local pushedBattle = {
      game = game, phase = "menu", queue = {}, kind = "wild",
      wideLayout = function() return false end,
      drawHUDs = function() pushedHudCalls = pushedHudCalls + 1 end,
      drawTextArea = function() pushedTextCalls = pushedTextCalls + 1 end,
    }
    eventListeners["screen.pushed"]({ state = pushedBattle })
    pushedBattle:drawHUDs(0)
    pushedBattle:drawTextArea()
    check(pushedHudCalls == 1 and pushedTextCalls == 1
        and pushedBattle._gen1ModernBattleSceneIsolation == nil,
      "screen push keeps classic battle HUD and text available before first modern frame")
  end
  state = { phase = "menu", queue = {}, kind = "wild", menuIndex = 1,
    draw = function() end,
    wideLayout = function() return false end,
    player = { mon = { species = "TESTMON", level = 5, hp = 20,
      stats = { hp = 20 } } },
    enemy = { mon = { species = "TESTMON", level = 3, hp = 12,
      stats = { hp = 12 } } } }
  game.stack.states = { state }
  do
    -- Regression coverage for the user-visible failure: enabling the WIP
    -- battle presenter must not make a newly pushed Start/dialogue state
    -- disappear while its model is still settling.
    local nativeWideLayout = state.wideLayout
    state.wideLayout = function() return true end
    local transientPopup = setmetatable({ game = game, screenId = "StartMenu",
      items = {}, index = 1, isOpaque = true, draw = function(self)
        self.nativeDraws = (self.nativeDraws or 0) + 1
      end }, { __index = menuClass })
    game.stack.states = { state, transientPopup }
    transientPopup = hooks["ui.state.decorate"](
      function(_, value) return value end, game, transientPopup, nil)
    game.stack.states[2] = transientPopup
    hooks["render.zones"](function(_, value) return value end, game, {})
    transientPopup:draw()
    check(transientPopup.nativeDraws == 1
        and hooks["screen.render_visible"](
          function(visible) return visible end, true, transientPopup) == true,
      "WIP battle keeps an incomplete Start menu native and visible")
    fill()
    compose(false)
    check(alpha() == 1,
      "WIP battle keeps an incomplete Start menu canvas visible")

    local readyStart = setmetatable({ game = game, screenId = "StartMenu",
      items = { { label = "POKéMON" }, { label = "ITEM" } }, index = 1,
      isOpaque = true }, { __index = menuClass })
    local readyDialogue = setmetatable({ game = game, pages = {
      { "HELLO" },
    }, pageIndex = 1, lineIndex = 1, charIndex = 5, done = true,
      isOpaque = true }, { __index = textBoxClass })
    game.stack.states = { state, readyStart }
    hooks["render.zones"](function(_, value) return value end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, readyStart) == true,
      "WIP battle defers Start menu suppression to composition")
    local readyStartCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(readyStartCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = readyStartCanvas, uiw = 304, uih = 144,
    })
    local readyStartImage = readyStartCanvas:newImageData()
    local startR, startG, startB, startA = readyStartImage:getPixel(0, 0)
    local startArenaR, startArenaG, startArenaB, startArenaA =
      readyStartImage:getPixel(150, 48)
    check(startR > 0.95 and startG > 0.95 and startB > 0.95
        and startA > 0.95 and startArenaR > 0.95
        and startArenaG > 0.95 and startArenaB > 0.95
        and startArenaA > 0.95,
      ("complete modern Start replacement restores the full framed battle paper "
        .. "(corner %.2f/%.2f/%.2f/%.2f, arena %.2f/%.2f/%.2f/%.2f)")
        :format(startR, startG, startB, startA,
          startArenaR, startArenaG, startArenaB, startArenaA))
    game.stack.states = { state, readyDialogue }
    hooks["render.zones"](function(_, value) return value end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, readyDialogue) == true,
      "WIP battle defers dialogue suppression to composition")
    local readyDialogueCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(readyDialogueCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = readyDialogueCanvas, uiw = 304, uih = 144,
    })
    local readyDialogueImage = readyDialogueCanvas:newImageData()
    local dialogueR, dialogueG, dialogueB, dialogueA =
      readyDialogueImage:getPixel(0, 0)
    local dialogueArenaR, dialogueArenaG, dialogueArenaB, dialogueArenaA =
      readyDialogueImage:getPixel(150, 48)
    check(dialogueR > 0.95 and dialogueG > 0.95 and dialogueB > 0.95
        and dialogueA > 0.95 and dialogueArenaR > 0.95
        and dialogueArenaG > 0.95 and dialogueArenaB > 0.95
        and dialogueArenaA > 0.95,
      "complete modern dialogue replacement restores the full framed battle paper")
    state.wideLayout = nativeWideLayout
  end
  game.stack.states = { state }
  fill()
  compose(false)
  check(alpha() == 1,
    "standard battle stays wholly native when WIDE metadata is false")
  do
    local sourceCanvas = love.graphics.newCanvas(160, 144)
    love.graphics.setCanvas(sourceCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.zones"](function(_, value) return value end, game, {})
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = sourceCanvas, uiw = 160, uih = 144,
    })
    local image = sourceCanvas:newImageData()
    local enemyR, enemyG = image:getPixel(4, 4)
    local playerR, playerG = image:getPixel(80, 60)
    local menuR, menuG = image:getPixel(8, 112)
    local sceneR, sceneG = image:getPixel(100, 40)
    check(enemyR > 0.95 and enemyG < 0.05
        and playerR > 0.95 and playerG < 0.05
        and menuR > 0.95 and menuG < 0.05
        and sceneR > 0.95 and sceneG < 0.05,
      "false WIDE metadata leaves the complete native 160x144 canvas untouched")

    state.wideLayout = function() return true end
    local wideCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(wideCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.zones"](function(_, value) return value end, game, {})
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = wideCanvas, uiw = 304, uih = 144,
    })
    local wideImage = wideCanvas:newImageData()
    local wideEnemyR, wideEnemyG = wideImage:getPixel(4, 4)
    local widePlayerR, widePlayerG = wideImage:getPixel(200, 60)
    local wideMenuR, wideMenuG = wideImage:getPixel(8, 120)
    local wideSceneR, wideSceneG = wideImage:getPixel(150, 48)
    check(wideEnemyR > 0.95 and wideEnemyG > 0.95
        and widePlayerR > 0.95 and widePlayerG > 0.95
        and wideMenuR > 0.95 and wideMenuG > 0.95,
      "WIDE 2D battle compose scrubs its native HUD and lower menu")
    check(wideSceneR > 0.95 and wideSceneG < 0.05,
      "WIDE 2D battle compose preserves its sprite and animation arena")

    state.phase = "animations"
    love.graphics.setCanvas(wideCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = wideCanvas, uiw = 304, uih = 144,
    })
    wideImage = wideCanvas:newImageData()
    wideMenuR, wideMenuG = wideImage:getPixel(8, 120)
    check(wideMenuR > 0.95 and wideMenuG > 0.95,
      "idle WIDE battle scrubs the always-painted native text frame")
    state.phase = "menu"

    state.bgMode = function() return "world" end
    love.graphics.setCanvas(wideCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.zones"](function(_, value) return value end, game, {})
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = wideCanvas, uiw = 304, uih = 144,
    })
    local worldWideImage = wideCanvas:newImageData()
    local worldWideHudR, worldWideHudG, worldWideHudB, worldWideHudA =
      worldWideImage:getPixel(4, 4)
    local worldWideLeftR, worldWideLeftG, _, worldWideLeftA =
      worldWideImage:getPixel(0, 40)
    local worldWideRightR, worldWideRightG, _, worldWideRightA =
      worldWideImage:getPixel(303, 40)
    local worldWideSceneR, worldWideSceneG, _, worldWideSceneA =
      worldWideImage:getPixel(150, 48)
    check(worldWideHudA > 0.95 and worldWideHudR > 0.95
        and worldWideHudG > 0.95 and worldWideHudB > 0.95,
      "WORLD WIDE native HUD tiles scrub back to battle paper")
    check(worldWideLeftA > 0.95 and worldWideRightA > 0.95
        and worldWideLeftR > 0.95 and worldWideLeftG < 0.05
        and worldWideRightR > 0.95 and worldWideRightG < 0.05,
      "WORLD WIDE source scene reaches both horizontal arena edges")
    check(worldWideSceneA > 0.95 and worldWideSceneR > 0.95
        and worldWideSceneG < 0.05,
      "WORLD WIDE battle scrub leaves the source sprite arena opaque")

    love.graphics.setCanvas(wideCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.compose"](function() return false end,
      { battleDim = 0.4 }, {
        uiCanvas = wideCanvas, uiw = 304, uih = 144,
      })
    local dimmedWorldImage = wideCanvas:newImageData()
    local dimR, dimG, _, dimA = dimmedWorldImage:getPixel(150, 48)
    check(dimR > 0.95 and dimG < 0.05 and dimA > 0.95,
      "WORLD WIDE battle dimming never veils the framed source arena")

    local childBase = state
    childBase.bgMode = function() return "world" end
    childBase.wideLayout = function() return true end
    childBase.phase = "menu"
    local childOverlay = setmetatable({ screenId = "BagMenu", isOpaque = true },
      { __index = listClass })
    game.stack.states = { childBase, childOverlay }
    local childCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(childCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.zones"](function(_, value) return value end, game, {})
    hooks["render.compose"](function() return false end,
      { battleDim = 0.4 }, {
        uiCanvas = childCanvas, uiw = 304, uih = 144,
      })
    local childImage = childCanvas:newImageData()
    local childArenaR, childArenaG, childArenaB, childArenaA =
      childImage:getPixel(150, 48)
    local childGutterR, childGutterG, childGutterB, childGutterA =
      childImage:getPixel(290, 60)
    check(childArenaA > 0.95 and childArenaR > 0.95
        and childArenaG > 0.95 and childArenaB > 0.95,
      "WORLD battle keeps its white arena behind Bag/Party children")
    check(childGutterR > 0.95 and childGutterG > 0.95
        and childGutterB > 0.95 and childGutterA > 0.95,
      "WORLD battle keeps paper to the arena edge behind Bag/Party children")

    childBase.bgMode = nil
    game.stack.states = { childBase, childOverlay }
    local nonWorldChildCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(nonWorldChildCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.zones"](function(_, value) return value end, game, {})
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = nonWorldChildCanvas, uiw = 304, uih = 144,
    })
    local nonWorldChildImage = nonWorldChildCanvas:newImageData()
    local nonWorldCornerR, nonWorldCornerG, nonWorldCornerB, nonWorldCornerA =
      nonWorldChildImage:getPixel(4, 4)
    local nonWorldArenaR, nonWorldArenaG, nonWorldArenaB, nonWorldArenaA =
      nonWorldChildImage:getPixel(150, 48)
    check(nonWorldCornerR > 0.95 and nonWorldCornerG > 0.95
        and nonWorldCornerB > 0.95 and nonWorldCornerA > 0.95
        and nonWorldArenaR > 0.95 and nonWorldArenaG > 0.95
        and nonWorldArenaB > 0.95 and nonWorldArenaA > 0.95,
      "non-WORLD battle child cleanup restores the complete 304x144 arena paper")
    game.stack.states = { state }
    state.bgMode = nil
    state.wideLayout = function() return true end

    local battleBase = state
    battleBase.isOpaque = true
    local childNativeDraws = 0
    local originalListDraw = listClass.draw
    listClass.draw = function() childNativeDraws = childNativeDraws + 1 end
    local battleBag = setmetatable({ screenId = "BagMenu", items = {},
      index = 1, scroll = 0, isOpaque = true }, { __index = listClass })
    game.stack.states = { battleBase, battleBag }
    battleBag = hooks["ui.state.decorate"](
      function(_, value) return value end, game, battleBag, nil)
    game.stack.states[2] = battleBag
    battleBag:draw()
    check(childNativeDraws == 1
        and battleBag._gen1ModernBattleChildNativeDraw == nil,
      "battle child source draw stays native until composition proves replacement")
    eventListeners["screen.pushed"]({ state = battleBag })
    hooks["render.zones"](function(_, value) return value end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, battleBase) == true,
      "battle native draw remains visible under a modern child screen")
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, battleBag) == true,
      "Bag child native draw stays visible until composition proves replacement")

    -- Match the released host exactly: BattleState.StatBox has no kind,
    -- screenId, isOpaque flag, or instance-owned draw/update functions. Its
    -- public class identity is the only reliable discriminator.
    local oldBattleMetatable = getmetatable(battleBase)
    local oldBattleGame = battleBase.game
    local oldBattleBgMode = battleBase.bgMode
    local oldBattleWideLayout = battleBase.wideLayout
    local battleClass = {}
    battleClass.__index = battleClass
    local statBoxClass = {}
    statBoxClass.__index = statBoxClass
    local levelUpNativeDraws = 0
    statBoxClass.draw = function()
      levelUpNativeDraws = levelUpNativeDraws + 1
    end
    statBoxClass.update = function() end
    battleClass.StatBox = statBoxClass
    setmetatable(battleBase, battleClass)
    battleBase.game = game
    battleBase.bgMode = function() return "world" end
    battleBase.wideLayout = function() return true end
    battleBase.phase = "menu"

    local levelUpState = setmetatable({
      game = game,
      mon = {
        nickname = "TESTMON",
        level = 6,
        stats = { attack = 12, defense = 11, speed = 13, special = 14 },
      },
    }, statBoxClass)
    game.stack.states = { battleBase, levelUpState }
    levelUpState = hooks["ui.state.decorate"](
      function(_, value) return value end, game, levelUpState, nil)
    game.stack.states[2] = levelUpState
    levelUpState:draw()
    check(levelUpNativeDraws == 1
        and levelUpState._gen1ModernBattleChildNativeDraw == nil,
      "level-up native StatBox draw stays native until composition proves replacement")
    hooks["render.zones"](function(_, value) return value end, game, {})
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, battleBase) == true,
      "battle scene remains visible under the modern level-up card")
    check(hooks["screen.render_visible"](
        function(visible) return visible end, true, levelUpState) == true,
      "level-up native StatBox stays visible until composition proves replacement")

    local levelUpCanvas = love.graphics.newCanvas(304, 144)
    love.graphics.setCanvas(levelUpCanvas)
    love.graphics.clear(1, 0, 0, 1)
    love.graphics.setCanvas()
    hooks["render.compose"](function() return false end, {}, {
      uiCanvas = levelUpCanvas, uiw = 304, uih = 144,
    })
    local levelUpImage = levelUpCanvas:newImageData()
    local outsideR, outsideG, outsideB, outsideA =
      levelUpImage:getPixel(4, 4)
    local topStripR, topStripG, topStripB, topStripA =
      levelUpImage:getPixel(150, 5)
    -- Sample above the player ribbon and to the right of the native StatBox
    -- scrub so this remains a source-scene assertion, not a HUD assertion.
    local sceneR, sceneG, sceneB, sceneA =
      levelUpImage:getPixel(200, 48)
    check(outsideR > 0.95 and outsideG > 0.95 and outsideB > 0.95
        and outsideA > 0.95,
      "real host StatBox restores paper to the framed arena edge")
    check(topStripR > 0.95 and topStripG < 0.05 and topStripB < 0.05
        and topStripA > 0.95,
      "real host StatBox preserves the full-height WIDE source arena")
    check(sceneR > 0.95 and sceneG < 0.05 and sceneB < 0.05
        and sceneA > 0.95,
      "real host StatBox preserves source battle pixels inside modern scene")

    setmetatable(battleBase, oldBattleMetatable)
    battleBase.game = oldBattleGame
    battleBase.bgMode = oldBattleBgMode
    battleBase.wideLayout = oldBattleWideLayout
    listClass.draw = originalListDraw
    battleBase.isOpaque = nil
    game.stack.states = { battleBase }
  end
  values.battleUiMode = "hud"
  fill()
  compose(false)
  check(alpha() == 1,
    "legacy SCENE HUD setting remains a safe save-compatible battle mode")
  values.battleUiMode = "auto"
  values.battleUiWip = false

  game.save = {
    player = { name = "RED", id = 1 }, money = 1234, playTime = 3600,
    inventory = { POTION = 2 }, pokedex = { seen = { TESTMON = true },
      owned = { TESTMON = true } },
    currentBox = 1, boxes = { {} },
  }
  values.rbySpriteCanvas = love.graphics.newCanvas(16, 16)
  love.graphics.push("all")
  love.graphics.setCanvas(values.rbySpriteCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0.10, 0.24, 0.46, 1)
  love.graphics.rectangle("fill", 5, 1, 6, 4)
  love.graphics.setColor(0.25, 0.72, 0.92, 1)
  love.graphics.rectangle("fill", 3, 5, 10, 8)
  love.graphics.setColor(0.95, 0.80, 0.18, 1)
  love.graphics.rectangle("fill", 4, 13, 3, 3)
  love.graphics.rectangle("fill", 9, 13, 3, 3)
  love.graphics.setCanvas()
  love.graphics.pop()
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
    sprites = { PLAYER = { image = values.rbySpriteCanvas, frames = 6 } },
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
  local largeDesktopViewport = { width = 1600, height = 1000,
    safe = { x = 0, y = 0, width = 1600, height = 1000 } }
  values.uiScale, values.fontScale = "auto", "auto"
  -- Keep the remainder of the gallery on the opt-in font path so the default
  -- can remain conservative without losing real-host font coverage.
  values.pixelFont = true
  local autoPortrait = mod.exports.getScaleTokens(portraitViewport)
  local autoDesktop = mod.exports.getScaleTokens(largeDesktopViewport)
  check(autoPortrait.uiScale >= 0.75 and autoPortrait.uiScale <= 4.00
      and autoPortrait.fontScale >= 0.80 and autoPortrait.fontScale <= 4.00,
    "AUTO scale stays within the configured bounds")
  check(autoDesktop.uiScale > autoPortrait.uiScale
      and autoDesktop.fontScale == 1 and autoPortrait.fontScale == 1,
    "AUTO UI scale responds while pixel font scale stays on an integer step")
  values.pixelFont = false
  values.fiveKScale = mod.exports.getScaleTokens({ width = 5120, height = 2784,
    safe = { x = 0, y = 0, width = 5120, height = 2784 } })
  check(values.fiveKScale.uiScale == 3.85
      and values.fiveKScale.fontScale == 5,
    "AUTO scales UI to 385% and preserves the system-text ratio at 500% on 5K")
  values.fourKScale = mod.exports.getScaleTokens({ width = 3840, height = 2160,
    dpiX = 1, dpiY = 1,
    safe = { x = 0, y = 0, width = 3840, height = 2160 } })
  values.hiDpi1080Scale = mod.exports.getScaleTokens({ width = 1920, height = 1080,
    dpiX = 2, dpiY = 2,
    safe = { x = 0, y = 0, width = 1920, height = 1080 } })
  check(values.fourKScale.uiScale == 3 and values.fourKScale.fontScale == 4
      and values.hiDpi1080Scale.uiScale * 2 == values.fourKScale.uiScale
      and values.hiDpi1080Scale.fontScale * 2 == values.fourKScale.fontScale,
    "logical AUTO scale and host DPI produce equivalent physical 4K sizing")
  values.uiScale, values.fontScale = "100", "100"
  values.manualFiveKScale = mod.exports.getScaleTokens({ width = 5120, height = 2784,
    safe = { x = 0, y = 0, width = 5120, height = 2784 } })
  check(values.manualFiveKScale.uiScale == 1
      and values.manualFiveKScale.fontScale == 1,
    "manual 100% remains exactly 100% on high-resolution displays")
  values.uiScale, values.fontScale, values.pixelFont = "auto", "auto", true
  values.fiveKPixelScale = mod.exports.getScaleTokens({ width = 5120, height = 2784,
    safe = { x = 0, y = 0, width = 5120, height = 2784 } })
  check(values.fiveKPixelScale.fontScale == 3
      and values.fiveKPixelScale.fontScale % 1 == 0,
    "Plain Pixel AUTO resolves 5K to a whole 3X raster step")
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
      local image = hudCanvas:newImageData()
      local shotDir = os.getenv("GEN1_UI_SHOT_DIR")
      if shotDir and shotDir ~= "" then
        local encoded = image:encode("png")
        local separator = package.config:sub(1, 1)
        local path = shotDir .. separator .. "gen1_ui_" .. name .. ".png"
        local output, openError = io.open(path, "wb")
        if not output then error(openError or ("cannot open " .. path)) end
        output:write(encoded:getString())
        output:close()
      else
        image:encode("png", "gen1_ui_" .. name .. ".png")
      end
    end
    return hudCanvas
  end
  local function pixelAlpha(canvas, x, y)
    local _, _, _, a = canvas:newImageData():getPixel(x, y)
    return a
  end
  local function alphaBounds(canvas)
    local image = canvas:newImageData()
    local minX, minY, maxX, maxY
    for y = 0, image:getHeight() - 1 do
      for x = 0, image:getWidth() - 1 do
        local _, _, _, alpha = image:getPixel(x, y)
        if alpha > 0 then
          minX, minY = math.min(minX or x, x), math.min(minY or y, y)
          maxX, maxY = math.max(maxX or x, x), math.max(maxY or y, y)
        end
      end
    end
    if not minX then return nil end
    return { x = minX, y = minY, w = maxX - minX + 1, h = maxY - minY + 1 }
  end
  local function latestLayoutRect(role)
    local diagnostics = mod.exports.getLayoutDiagnostics()
    local layers = diagnostics and diagnostics.layers or {}
    for layerIndex = #layers, 1, -1 do
      local rects = layers[layerIndex].rects or {}
      for rectIndex = #rects, 1, -1 do
        if rects[rectIndex].role == role then return rects[rectIndex] end
      end
    end
    return nil
  end
  local function verticallySeparated(upper, lower)
    return upper and lower and upper.y + upper.h <= lower.y + 0.51
  end

  -- Modern 2D battle ownership is explicit-WIDE only. Standard/false/unknown
  -- layouts must fail open without HUD pixels, source scrubbing, or input
  -- remapping; either supported true form opts into the modern presenter.
  do
    values.battleUiWip, values.battleUiMode = true, "full"
    local function battleHudState()
      return {
        phase = "menu", queue = {}, kind = "wild", isOpaque = true,
        player = { name = "BUDDY", mon = testMon },
        enemy = { name = "FOE", mon = boxedMon },
        draw = function() end,
      }
    end
    for _, layoutCase in ipairs({
        { name = "callback_false", value = function() return false end },
        { name = "boolean_false", value = false },
        { name = "missing_metadata", missing = true },
      }) do
      local nativeState = battleHudState()
      if not layoutCase.missing then nativeState.wideLayout = layoutCase.value end
      local modernCanvas = renderHud({ nativeState },
        "battle_native_" .. layoutCase.name, viewport)
      check(alphaBounds(modernCanvas) == nil,
        layoutCase.name .. " battle receives no modern HUD pixels")

      local nativeCanvas = love.graphics.newCanvas(160, 144)
      love.graphics.setCanvas(nativeCanvas)
      love.graphics.clear(1, 0, 0, 1)
      love.graphics.setCanvas()
      game.stack.states = { nativeState }
      hooks["render.zones"](function(_, value) return value end, game, {})
      hooks["render.compose"](function() return false end, {}, {
        uiCanvas = nativeCanvas, uiw = 160, uih = 144,
      })
      local nativeImage = nativeCanvas:newImageData()
      local untouched = true
      for _, point in ipairs({ { 4, 4 }, { 80, 60 }, { 8, 112 }, { 150, 140 } }) do
        local r, g, b, a = nativeImage:getPixel(point[1], point[2])
        untouched = untouched and r > 0.95 and g < 0.05 and b < 0.05
          and a > 0.95
      end
      check(untouched,
        layoutCase.name .. " battle leaves its native canvas untouched")
    end

    for _, layoutCase in ipairs({
        { name = "callback_true", value = function() return true end },
        { name = "boolean_true", value = true },
      }) do
      local wideState = battleHudState()
      wideState.wideLayout = layoutCase.value
      local battleHud = renderHud({ wideState },
        "battle_wide_" .. layoutCase.name, viewport)
      check(alphaBounds(battleHud) ~= nil,
        layoutCase.name .. " WIDE battle renders the modern 2D HUD")
    end
    values.battleUiWip, values.battleUiMode = false, "auto"
  end

  -- A source-owned transient model is a deliberately narrower compatibility
  -- surface than a screen adapter: it supplies presentation data only while
  -- Gen1 Modern UI owns theme, safe-area layout, and drawing.
  local transientNotice = {
    id = "test_source:quick-save", title = "QUICK SAVED",
    detail = "CERULEAN CITY", severity = "success",
  }
  check(mod.exports.registerAdapter({ owner = "test_source", contract = {
    apiVersion = 1,
    screens = {},
    transient = {
      model = function() return transientNotice end,
    },
  } }), "a source transient registers through the public adapter contract")
  check(mod.exports.isTransientPresentationActive("test_source"),
    "an enabled Modern UI publicly claims the source transient")
  local transientCanvas = renderHud({ game.overworld }, "source_transient", viewport)
  check(alphaBounds(transientCanvas) ~= nil,
    "a valid source transient receives a themed Modern UI presentation")
  values.menuUi = false
  check(not mod.exports.isTransientPresentationActive("test_source"),
    "disabled Modern UI releases transient presentation to the source fallback")
  values.menuUi = true
  transientNotice = { id = "test_source:bad", title = "BAD", leaked = function() end }
  check(not mod.exports.isTransientPresentationActive("test_source", game),
    "a malformed source model releases the native fallback")
  transientCanvas = renderHud({ game.overworld }, "malformed_source_transient", viewport)
  check(alphaBounds(transientCanvas) == nil,
    "a malformed transient model is ignored without drawing arbitrary callbacks")
  local throwingModel = mod._gen1ModernCompatibility.adapters.test_source
    .contract.transient
  throwingModel.model = function() error("injected source failure") end
  check(not mod.exports.isTransientPresentationActive("test_source", game),
    "a throwing source model releases the native fallback")
  throwingModel.model = function() return transientNotice end
  transientNotice = nil
  check(mod.exports.unregisterAdapter("test_source"),
    "source transient unregisters with the ordinary adapter lifecycle")
  bag.items = { { label = "POTION", right = "x2", value = "POTION" } }
  bag.footer = "¥1234"
  local savedPage = textBox.pages
  local savedCharIndex = textBox.charIndex
  for _, scaleCase in ipairs({
      { ui = "75", font = "80", dialogue = "inherit" },
      { ui = "100", font = "100", dialogue = "110" },
      { ui = "125", font = "125", dialogue = "125" },
      { ui = "150", font = "150", dialogue = "175" },
      { ui = "150", font = "200", dialogue = "200" },
    }) do
    values.uiScale = scaleCase.ui
    values.fontScale = scaleCase.font
    values.dialogueTextScale = scaleCase.dialogue
    bag.items = { { label = "A VERY LONG LOCALIZED MENU LABEL THAT MUST WRAP",
      right = "A LONG VALUE COLUMN", value = "POTION" } }
    renderHud({ bag }, "scaling_bag_" .. scaleCase.font, portraitViewport)
    textBox.pages = {{
      "A very long revealed dialogue sentence with an intentionallylongwordthatmustbreakcleanly.",
    }}
    textBox.charIndex = #textBox.pages[1][1]
    renderHud({ overworld, textBox, choice }, "scaling_dialogue_" .. scaleCase.font,
      scaleCase.font == "200" and mobileLandscapeViewport or portraitViewport)
  end
  values.uiScale, values.fontScale = "auto", "auto"
  renderHud({ bag }, "scaling_bag_auto_portrait", portraitViewport)
  renderHud({ bag }, "scaling_bag_auto_desktop", largeDesktopViewport)
  textBox.pages = savedPage
  textBox.charIndex = savedCharIndex
  values.uiScale, values.fontScale, values.dialogueTextScale = "100", "100", "inherit"
  local savedDialogueDone, savedDialogueChoice = textBox.done, textBox.choice
  local savedDialoguePageIndex, savedDialogueLineIndex = textBox.pageIndex, textBox.lineIndex
  textBox.pages = {{ "Short dialogue should not inherit a tall chrome-only card." }}
  textBox.pageIndex, textBox.lineIndex = 1, 1
  values.uiScale, values.fontScale = "150", "100"
  textBox.charIndex, textBox.done, textBox.choice = 8, false, nil
  local typingDialogue = renderHud({ overworld, textBox },
    "dialogue_typing_no_speed_hint", largeDesktopViewport)
  textBox.charIndex, textBox.done, textBox.choice = #textBox.pages[1][1], true, nil
  local dialogueSized = renderHud({ overworld, textBox },
    "dialogue_content_sized", largeDesktopViewport)
  local readyDialogue = renderHud({ overworld, textBox },
    "dialogue_ready_no_button_hint", largeDesktopViewport)
  local typingBounds, readyBounds = alphaBounds(typingDialogue), alphaBounds(readyDialogue)
  check(typingBounds and readyBounds and typingBounds.x == readyBounds.x
      and typingBounds.y == readyBounds.y and typingBounds.w == readyBounds.w
      and typingBounds.h == readyBounds.h,
    "dialogue panel footprint stays stable through typewriter reveal")
  check(pixelAlpha(dialogueSized, 800, 800) == 0,
    "short dialogue uses a content-sized card")
  values.savedDialoguePages, values.savedDialogueShown = textBox.pages, textBox.shown
  values.savedDialogueCharIndex = textBox.charIndex
  textBox.pages = {{
    "PLAYER RED",
    "BADGES 4",
    "POKEDEX 35",
    "TIME 01:23",
  }}
  textBox.pageIndex, textBox.lineIndex = 1, 1
  textBox.charIndex, textBox.shown = #textBox.pages[1][1], {}
  textBox.done, textBox.waiting, textBox.choice = false, false, nil
  local longDialogueTyping = renderHud({ overworld, textBox },
    "dialogue_long_page_typing", largeDesktopViewport)
  textBox.lineIndex = 4
  textBox.charIndex, textBox.done = #textBox.pages[1][4], true
  local longDialogueReady = renderHud({ overworld, textBox },
    "dialogue_long_page_ready", largeDesktopViewport)
  local longTypingBounds, longReadyBounds = alphaBounds(longDialogueTyping),
    alphaBounds(longDialogueReady)
  check(longTypingBounds and longReadyBounds
      and longTypingBounds.x == typingBounds.x
      and longTypingBounds.y == typingBounds.y
      and longTypingBounds.w == typingBounds.w
      and longTypingBounds.h == typingBounds.h
      and longTypingBounds.x == longReadyBounds.x
      and longTypingBounds.y == longReadyBounds.y
      and longTypingBounds.w == longReadyBounds.w
      and longTypingBounds.h == longReadyBounds.h,
    "dialogue envelope stays stable when page content length changes")
  values.uiScale, values.fontScale, values.dialogueTextScale =
    "100", "100", "inherit"
  values.dialogueBreakState = setmetatable({
    pages = {{ "I like bugs, so", "I'm going back to", "Viridian Forest." }},
    pageIndex = 1, lineIndex = 3, charIndex = #"Viridian Forest.",
    shown = { {}, {}, {} }, done = true, waiting = false, isOpaque = true,
  }, { __index = textBoxClass })
  renderHud({ overworld, values.dialogueBreakState },
    "dialogue_legacy_breaks_collapsed", largeDesktopViewport)
  values.dialogueBreakBounds = alphaBounds(
    renderHud({ overworld, values.dialogueBreakState }, nil,
      largeDesktopViewport))
  values.dialogueSingleState = setmetatable({
    pages = {{ "I like bugs, so I'm going back to Viridian Forest." }},
    pageIndex = 1, lineIndex = 1,
    charIndex = #"I like bugs, so I'm going back to Viridian Forest.",
    shown = { {} }, done = true, waiting = false, isOpaque = true,
  }, { __index = textBoxClass })
  values.dialogueSingleBounds = alphaBounds(
    renderHud({ overworld, values.dialogueSingleState }, nil,
      largeDesktopViewport))
  check(values.dialogueBreakBounds and values.dialogueSingleBounds
      and values.dialogueBreakBounds.x == values.dialogueSingleBounds.x
      and values.dialogueBreakBounds.y == values.dialogueSingleBounds.y
      and values.dialogueBreakBounds.w == values.dialogueSingleBounds.w
      and values.dialogueBreakBounds.h == values.dialogueSingleBounds.h,
    "legacy newline fragments reflow like one modern-width sentence")
  values.dialogueHardWrapState = setmetatable({
    pages = {{ "ABCDEFGHIJKLMNOPQR", "STUVWXYZABCDEFGHIJ",
      "KLMNOPQRSTUVWXYZAB", "CDEFGHIJKLMNOPQRST" }},
    maxCols = 18, pageIndex = 1, lineIndex = 4,
    charIndex = #"CDEFGHIJKLMNOPQRST", shown = { {}, {}, {}, {} },
    done = true, waiting = false, isOpaque = true,
  }, { __index = textBoxClass })
  values.dialogueHardWrapBounds = alphaBounds(
    renderHud({ overworld, values.dialogueHardWrapState }, nil,
      largeDesktopViewport))
  values.dialogueHardWrapSingleState = setmetatable({
    pages = {{ "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRST" }},
    maxCols = 18, pageIndex = 1, lineIndex = 1,
    charIndex = #"ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRST",
    shown = { {} }, done = true, waiting = false, isOpaque = true,
  }, { __index = textBoxClass })
  values.dialogueHardWrapSingleBounds = alphaBounds(
    renderHud({ overworld, values.dialogueHardWrapSingleState }, nil,
      largeDesktopViewport))
  check(values.dialogueHardWrapBounds and values.dialogueHardWrapSingleBounds
      and values.dialogueHardWrapBounds.x == values.dialogueHardWrapSingleBounds.x
      and values.dialogueHardWrapBounds.y == values.dialogueHardWrapSingleBounds.y
      and values.dialogueHardWrapBounds.w == values.dialogueHardWrapSingleBounds.w
      and values.dialogueHardWrapBounds.h == values.dialogueHardWrapSingleBounds.h,
    "classic hard wraps rejoin without inserting spaces into long tokens")
  values.dialogueTextScale = "200"
  values.dialogueDoubleBounds = alphaBounds(
    renderHud({ overworld, values.dialogueSingleState },
      "dialogue_balanced_200", largeDesktopViewport))
  check(values.dialogueDoubleBounds
      and values.dialogueDoubleBounds.w >= values.dialogueSingleBounds.w * 1.75
      and values.dialogueDoubleBounds.h >= values.dialogueSingleBounds.h * 1.75,
    "200% dialogue scaling grows the text envelope and breathing room together")
  values.dialogueTextScale = "inherit"
  textBox.pages, textBox.shown = values.savedDialoguePages, values.savedDialogueShown
  textBox.charIndex = values.savedDialogueCharIndex
  textBox.pages, textBox.charIndex = savedPage, savedCharIndex
  textBox.pageIndex, textBox.lineIndex = savedDialoguePageIndex, savedDialogueLineIndex
  textBox.done, textBox.choice = savedDialogueDone, savedDialogueChoice
  values.uiScale, values.fontScale = "100", "100"
  for _, themeChoice in ipairs(themeRow.choices) do
    values.theme = themeChoice[2]
    values.panelOpacity, values.foregroundOpacity = 0, 0
    renderHud({ bag }, "theme_zero_" .. themeChoice[2]:gsub(":", "_"), portraitViewport)
    values.panelOpacity, values.foregroundOpacity = 100, 100
    renderHud({ bag }, "theme_full_" .. themeChoice[2]:gsub(":", "_"), mobileLandscapeViewport)
  end
  values.theme = themeRow.default
  for _, style in ipairs({ "theme", "pixel", "soft", "plain" }) do
    values.frameStyle = style
    renderHud({ bag }, "frame_" .. style, mobileLandscapeViewport)
  end
  check(modAssetLoads > 0,
    "theme-owned pixel frame loads through the mod asset helper")
  values.frameStyle = frameStyleRow.default
  values.frameAsset = frameAssetRow.default
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
  renderHud({ startMenu }, nil, largeDesktopViewport)
  values.desktopStartPanel = latestLayoutRect("panel")
  check(values.desktopStartPanel
      and values.desktopStartPanel.h > values.desktopStartPanel.w
      and values.desktopStartPanel.h > largeDesktopViewport.height * 0.5
      and values.desktopStartPanel.w < largeDesktopViewport.width * 0.65,
    "desktop Start menu uses the tall, narrow NAV envelope")
  check(pixelAlpha(desktopMenu, 10, 180) == 0
      and pixelAlpha(desktopMenu, 610, 180) > 0,
    "desktop start menu floats at the right with outside breathing room")
  local mobileMenu = renderHud({ startMenu }, "start_menu_mobile_landscape",
    mobileLandscapeViewport)
  check(pixelAlpha(mobileMenu, 0, 0) == 0,
    "adaptive mobile landscape start menu leaves the world area transparent")

  values.modMenusState = setmetatable({ screenId = "Menu", index = 1,
    _gen1ModMenus = true, items = {
      { label = "UI SETTINGS" }, { label = "DEX RADAR" },
      { label = "BOXES" }, { label = "ANOTHER MOD" },
    } }, { __index = menuClass })
  renderHud({ values.modMenusState }, nil, largeDesktopViewport)
  values.modMenusPanel = latestLayoutRect("panel")
  check(values.modMenusPanel
      and values.modMenusPanel.h > values.modMenusPanel.w
      and values.modMenusPanel.h > largeDesktopViewport.height * 0.5
      and values.modMenusPanel.w < largeDesktopViewport.width * 0.65,
    "MOD MENUS uses the same tall, narrow NAV envelope")

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

  -- Battle fixtures intentionally render only the post-composite modern
  -- layer. The native BattleState canvas remains underneath in the game so
  -- its attack/send-out/capture/voxel animations keep running.
  local savedMoves = game.data.moves
  game.data.moves = {
    BUBBLEBEAM = { name = "BUBBLEBEAM", type = "WATER", pp = 20,
      power = 65, accuracy = 100 },
    BODY_SLAM = { name = "BODY SLAM", type = "NORMAL", pp = 15,
      power = 85, accuracy = 100 },
    GUST = { name = "GUST", type = "FLYING", pp = 35,
      power = 40, accuracy = 100 },
    THUNDERBOLT = { name = "THUNDERBOLT", type = "ELECTRIC", pp = 15,
      power = 95, accuracy = 100 },
  }
  local battle = {
    phase = "moveSelect", queue = {}, kind = "wild", moveIndex = 1,
    menuIndex = 1, draw = function() end,
    wideLayout = true,
    player = { name = "HERCULES", shownHP = 118,
      mon = { species = "TESTMON", nickname = "HERCULES", level = 32,
        hp = 118, exp = 1000, stats = { hp = 118 } },
      curMoves = {
        { id = "BUBBLEBEAM", pp = 20 }, { id = "BODY_SLAM", pp = 15 },
        { id = "GUST", pp = 35 }, { id = "THUNDERBOLT", pp = 15 },
      } },
    enemy = { name = "PIDGEY", shownHP = 37,
      mon = { species = "TESTMON", level = 15, hp = 37,
        stats = { hp = 37 } } },
    overlays = {
      caughtIndicator = true,
      catchRates = { pokeball = 34, greatBall = 51, ultraBall = 68 },
      experience = { current = 42, maximum = 67 },
    },
  }
  local savedBattleUiScale, savedBattleFontScale = values.uiScale, values.fontScale
  values.uiScale, values.fontScale = "100", "100"
  values.battleUiWip, values.battleUiMode = true, "full"
  local battleCanvas = renderHud({ battle }, "battle_2d_moves")
  check(verticallySeparated(latestLayoutRect("battle-player-card"),
      latestLayoutRect("battle-move-panel")),
    "landscape WIDE player card stays above the move panel")
  -- renderHud reuses one canvas per viewport size. Inspect this ordinary
  -- battle immediately so later compact overlays (including AskName) cannot
  -- replace the pixels these checks are meant to describe.
  check(pixelAlpha(battleCanvas,
      math.floor(viewport.width / 2), viewport.height - 12) > 0,
    "2D battle replacement paints an opaque modern move region")
  check(pixelAlpha(battleCanvas,
      math.floor(viewport.width / 2), 80) == 0,
    "2D battle arena frame leaves the live source scene visible")
  values.savedBattleMessagePhase = battle.phase
  values.savedBattleMessageCurrent = battle.current
  values.savedBattleMessageLines = battle.lines
  values.savedBattleMessageShown = battle.shown
  values.savedBattleMessageLineIndex = battle.lineIndex
  values.savedBattleMessageWaiting = battle.msgWaiting
  battle.phase, battle.current = "message", { text = "FIRST\vSECRET" }
  battle.lines, battle.lineIndex = { {}, {} }, 1
  battle.shown, battle.msgWaiting = { { 1, 2, 3, 4, 5 } }, true
  values.gatedBattleMessagePixels = renderHud({ battle },
    "battle_message_continuation_gated", viewport):newImageData()
    :encode("png"):getString()
  battle.current, battle.lines = { text = "FIRST" }, { {} }
  values.referenceBattleMessagePixels = renderHud({ battle }, nil, viewport)
    :newImageData():encode("png"):getString()
  check(values.gatedBattleMessagePixels == values.referenceBattleMessagePixels,
    "modern battle text does not reveal content beyond an unresolved CONT gate")
  battle.phase = values.savedBattleMessagePhase
  battle.current = values.savedBattleMessageCurrent
  battle.lines = values.savedBattleMessageLines
  battle.shown = values.savedBattleMessageShown
  battle.lineIndex = values.savedBattleMessageLineIndex
  battle.msgWaiting = values.savedBattleMessageWaiting
  local battleViewport = { width = 1024, height = 768,
    safe = { x = 0, y = 0, width = 1024, height = 768 } }
  renderHud({ battle }, "battle_2d_moves_desktop", battleViewport)
  local visualLevelUp = {
    mon = {
      nickname = "HERCULES", level = 33,
      stats = { attack = 104, defense = 73, speed = 74, special = 87 },
    },
  }
  local levelUpCardCanvas = renderHud({ battle, visualLevelUp },
    "battle_level_up_modern", battleViewport)
  check(alphaBounds(levelUpCardCanvas) ~= nil,
    "modern level-up stats card renders above the preserved battle scene")

  verifyCatchNicknameScreens({
    mod = mod, battle = battle, textBoxClass = textBoxClass,
    choiceClass = choiceClass,
    namingClass = package.loaded["src.ui.NamingScreen"],
    renderHud = renderHud, alphaBounds = alphaBounds,
    battleViewport = battleViewport, compactViewport = viewport,
    portraitViewport = portraitViewport,
  })
  local fixedBattleViewport = { width = 1920, height = 720,
    safe = { x = 40, y = 20, width = 1840, height = 680 },
    gameX = 480, gameY = 80, gameWidth = 960, gameHeight = 540 }
  battle.wideLayout = function() return true end
  local fixedBattleCanvas = renderHud({ battle },
    "battle_2d_moves_fixed_surface", fixedBattleViewport)
  local fixedBattleBounds = alphaBounds(fixedBattleCanvas)
  check(fixedBattleBounds and fixedBattleBounds.x >= fixedBattleViewport.gameX
      and fixedBattleBounds.y >= fixedBattleViewport.gameY
      and fixedBattleBounds.x + fixedBattleBounds.w
        <= fixedBattleViewport.gameX + fixedBattleViewport.gameWidth
      and fixedBattleBounds.y + fixedBattleBounds.h
        <= fixedBattleViewport.gameY + fixedBattleViewport.gameHeight,
    "FIXED battle presenter stays inside the host battle surface")
  check(fixedBattleBounds
      and fixedBattleBounds.x >= fixedBattleViewport.safe.x
      and fixedBattleBounds.y >= fixedBattleViewport.safe.y
      and fixedBattleBounds.x + fixedBattleBounds.w
        <= fixedBattleViewport.safe.x + fixedBattleViewport.safe.width
      and fixedBattleBounds.y + fixedBattleBounds.h
        <= fixedBattleViewport.safe.y + fixedBattleViewport.safe.height,
    "FIXED battle presenter stays inside the monitor safe area")
  check(fixedBattleBounds and fixedBattleBounds.w <= 641
      and fixedBattleBounds.h <= 361,
    "WIDE battle uses a fixed 640x360 envelope at 100% scale")

  values.uiScale, values.fontScale, values.pixelFont = "auto", "auto", false
  values.highResolutionBattleViewport = { width = 2560, height = 1440,
    safe = { x = 0, y = 0, width = 2560, height = 1440 } }
  renderHud({ battle }, "battle_2d_moves_1440p_auto",
    values.highResolutionBattleViewport)
  values.highResolutionBattleEnvelope = latestLayoutRect("battle-envelope")
  check(values.highResolutionBattleEnvelope
      and math.abs(values.highResolutionBattleEnvelope.w - 1280) <= 1
      and math.abs(values.highResolutionBattleEnvelope.h - 720) <= 1,
    "AUTO grows the WIDE battle envelope beyond the old 150% cap at 1440p")
  values.uiScale, values.fontScale, values.pixelFont = "100", "100", true

  -- The released host normally blits a 304x144 WIDE canvas at its own
  -- integer letterbox scale. Modern UI captures that cleaned source and
  -- places it in the fixed arena instead, so a large desktop cannot retain
  -- an oversized second copy behind the modern frame.
  verifyFixedBattleSourceTransform({
    hooks = hooks, game = game, battle = battle,
    alphaBounds = alphaBounds, renderHud = renderHud,
    viewport = largeDesktopViewport,
    portraitViewport = { width = 420, height = 760,
      safe = { x = 20, y = 40, width = 380, height = 680 } },
  })

  values.battleUiMode = "hud"
  local legacyHudCanvas = renderHud({ battle },
    "battle_2d_legacy_hud_alias", fixedBattleViewport)
  local legacyHudBounds = alphaBounds(legacyHudCanvas)
  check(legacyHudBounds and legacyHudBounds.w <= 641
      and legacyHudBounds.h <= 361,
    "legacy SCENE HUD value resolves to the fixed WIDE envelope")
  check(verticallySeparated(latestLayoutRect("battle-player-card"),
      latestLayoutRect("battle-move-panel")),
    "legacy SCENE HUD value cannot restore unbounded overlapping geometry")
  values.battleUiMode = "full"

  local portraitBattleViewport = { width = 420, height = 760,
    safe = { x = 20, y = 40, width = 380, height = 680 } }
  local portraitBattleCanvas = renderHud({ battle },
    "battle_2d_moves_portrait_safe", portraitBattleViewport)
  check(verticallySeparated(latestLayoutRect("battle-enemy-card"),
      latestLayoutRect("battle-arena")),
    "portrait WIDE opponent card stays above the battle renderer")
  check(verticallySeparated(latestLayoutRect("battle-arena"),
      latestLayoutRect("battle-player-card")),
    "portrait WIDE player card stays below the battle renderer")
  check(verticallySeparated(latestLayoutRect("battle-player-card"),
      latestLayoutRect("battle-move-panel")),
    "portrait WIDE status cards stay above the reflowed move panel")
  local portraitBattleBounds = alphaBounds(portraitBattleCanvas)
  check(portraitBattleBounds
      and portraitBattleBounds.x >= portraitBattleViewport.safe.x
      and portraitBattleBounds.y >= portraitBattleViewport.safe.y
      and portraitBattleBounds.x + portraitBattleBounds.w
        <= portraitBattleViewport.safe.x + portraitBattleViewport.safe.width
      and portraitBattleBounds.y + portraitBattleBounds.h
        <= portraitBattleViewport.safe.y + portraitBattleViewport.safe.height,
    "portrait WIDE battle presenter stays inside the safe area")
  values.fontScale = "400"
  local pixelFourBattle = renderHud({ battle }, "battle_2d_moves_pixel_4x")
  local pixelFourBounds = alphaBounds(pixelFourBattle)
  local pixelFourDiagnostics = mod.exports.getLayoutDiagnostics()
  local pixelFourLayer = pixelFourDiagnostics.layers
    and pixelFourDiagnostics.layers[#pixelFourDiagnostics.layers]
  check(pixelFourBounds and pixelFourBounds.x >= 0 and pixelFourBounds.y >= 0
      and pixelFourBounds.x + pixelFourBounds.w <= viewport.width
      and pixelFourBounds.y + pixelFourBounds.h <= viewport.height,
    "4X Plain Pixel battle request remains inside the monitor")
  check(verticallySeparated(latestLayoutRect("battle-player-card"),
      latestLayoutRect("battle-move-panel")),
    "4X Plain Pixel battle request caps by whole steps before panels overlap")
  check(pixelFourLayer and #(pixelFourLayer.overflows or {}) == 0,
    "4X Plain Pixel battle request reports no layout overflow")
  values.fontScale = "100"
  battle.phase, battle.current, battle.introSlide = "messages", nil, 12
  local introCanvas = renderHud({ battle }, "battle_native_intro_passthrough")
  check(pixelAlpha(introCanvas, 100, 100) == 0
      and pixelAlpha(introCanvas, math.floor(viewport.width / 2),
        viewport.height - 40) == 0,
    "battle intro and party-ball animations remain unobscured")
  battle.introSlide = nil
  battle.current = { text = "HERCULES used BUBBLEBEAM!" }
  renderHud({ battle }, "battle_animation_message_seed")
  battle.current = nil
  battle.player.shownHP = 91
  battle.animPlaying, battle.msgHold = true, true
  local animationCanvas = renderHud({ battle },
    "battle_animation_modern_hud")
  check(pixelAlpha(animationCanvas, math.floor(viewport.width / 2),
      viewport.height - 80) > 0,
    "modern battle message and animated HP HUD remain visible during attacks")
  battle.animPlaying, battle.msgHold = nil, nil
  battle.player.shownHP = 118
  battle.phase, battle.current, battle.msgWaiting =
    "messages", { text = "Wild PIDGEY appeared!" }, true
  renderHud({ battle }, "battle_2d_message")
  renderHud({ battle }, "battle_2d_message_desktop", battleViewport)
  battle.phase, battle.current, battle.msgWaiting = "menu", nil, nil
  renderHud({ battle }, "battle_2d_commands")
  renderHud({ battle }, "battle_2d_commands_desktop", battleViewport)
  battle.dramaticShapeShot = { canvas = true }
  values.battleUiMode = "auto"
  renderHud({ battle }, "battle_voxel_commands")
  renderHud({ battle }, "battle_voxel_commands_desktop", battleViewport)
  battle.dramaticShapeShot = nil
  values.battleUiWip, values.battleUiMode = false, "auto"
  values.uiScale, values.fontScale = savedBattleUiScale, savedBattleFontScale
  game.data.moves = savedMoves
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
  verifyRichPixelHeaders(values, renderHud, latestLayoutRect,
    verticallySeparated, mod.exports.getLayoutDiagnostics,
    dex, "Pokédex", "pokedex_pixel_4x",
    largeDesktopViewport)

  local party = setmetatable({ screenId = "PartyMenu", game = game,
    index = 1, party = game.save.party }, { __index = partyClass })
  renderHud({ party }, "party_rich")
  renderHud({ party }, "party_rich_portrait", portraitViewport)
  local savedPartyForShot = party.party
  party.party = {}
  for index = 1, 6 do
    party.party[index] = {
      species = "TESTMON", nickname = "PARTY " .. index, level = 12 + index,
      hp = 31, stats = { hp = 40, attack = 24, defense = 22, speed = 25,
        special = 20 }, moves = { { id = "TEST_MOVE", pp = 17 } },
    }
  end
  local partySixLarge = renderHud({ party }, "party_rich_six_large", largeDesktopViewport)
  check(pixelAlpha(partySixLarge, 800, 900) == 0,
    "Party rich panel sizes to six rows and detail content")
  verifyRichPixelHeaders(values, renderHud, latestLayoutRect,
    verticallySeparated, mod.exports.getLayoutDiagnostics,
    party, "Party", "party_pixel_4x",
    largeDesktopViewport)
  party.party = savedPartyForShot
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
  game.data.pokemon.NIDORAN_M = { id = "NIDORAN_M",
    name = "NIDORAN\226\153\130", types = { "POISON" },
    baseStats = { hp = 46, attack = 57, defense = 40, speed = 50, special = 40 } }
  game.data.pokemon.NIDORAN_F = { id = "NIDORAN_F",
    name = "NIDORAN\226\153\128", types = { "POISON" },
    baseStats = { hp = 55, attack = 47, defense = 52, speed = 41, special = 40 } }
  local genderParty = setmetatable({ screenId = "PartyMenu", game = game,
    index = 1, party = {
      { species = "NIDORAN_M", level = 5, hp = 20,
        moves = { { id = "TEST_MOVE", pp = 30 } } },
      { species = "NIDORAN_F", level = 5, hp = 21,
        moves = { { id = "TEST_MOVE", pp = 30 } } },
    } }, { __index = partyClass })
  renderHud({ genderParty }, "party_nidoran_male")
  genderParty.index = 2
  renderHud({ genderParty }, "party_nidoran_female")
  values.uiScale, values.fontScale = "150", "200"
  renderHud({ genderParty }, "party_nidoran_female_portrait", portraitViewport)
  genderParty.index = 1
  renderHud({ genderParty }, "party_nidoran_male_portrait", portraitViewport)
  values.uiScale, values.fontScale = "100", "100"
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
  local summarySized = renderHud({ summary }, "summary_content_sized",
    largeDesktopViewport)
  check(pixelAlpha(summarySized, 800, 900) == 0,
    "Summary stat panel stays content-sized on a large desktop")

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
  game.data.text = game.data.text or {}
  game.data.text.TESTMON_DATA = "A compact data description used to verify that the Pokédex data page sizes to its visible content instead of reserving a full-height card."
  game.data.pokemon.TESTMON.dexEntry = {
    kind = "SEED TESTMON", heightM = 0.7, weightKg = 6.9, text = "TESTMON_DATA",
  }
  local dexDataSized = renderHud({ dexEntry }, "dex_entry_data_content_sized",
    largeDesktopViewport)
  check(pixelAlpha(dexDataSized, 800, 900) == 0,
    "Dex data panel sizes to its visible description")
  dexEntry.view = "stats"
  dexEntry.stats = {
    stats = {
      { key = "HP", value = 40 }, { key = "ATK", value = 24 },
      { key = "DEF", value = 22 }, { key = "SPD", value = 25 },
      { key = "SPC", value = 20 },
    },
    bst = 131,
    evolutions = { { label = "LV 16", name = "TESTMON 2" } },
  }
  local dexStatsSized = renderHud({ dexEntry }, "dex_entry_stats_content_sized",
    largeDesktopViewport)
  check(pixelAlpha(dexStatsSized, 800, 900) == 0,
    "Dex stats panel sizes to its visible stat rows")
  dexEntry.view, dexEntry.stats = "data", nil

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

  local leaderSheet = love.graphics.newCanvas(16, 16)
  love.graphics.push("all")
  love.graphics.setCanvas(leaderSheet)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 3, 2, 10, 12)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 6, 5, 4, 5)
  love.graphics.setCanvas()
  love.graphics.pop()
  local leaderQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
  local leaderQuads = {}
  for index = 0, 7 do leaderQuads[index] = leaderQuad end
  values.trainer = setmetatable({ screenId = "TrainerCard", game = game,
    faces = { img = leaderSheet, quads = leaderQuads } },
    { __index = trainerCardClass })
  renderHud({ values.trainer }, "trainer")
  renderHud({ values.trainer }, "trainer_portrait", portraitViewport)
  local savedTrainerTheme = values.theme
  values.theme = "gen1_modern_ui:dark"
  renderHud({ values.trainer }, "trainer_dark_leader_paper")
  values.theme = savedTrainerTheme

  do
    -- RBY MMO's profile/rank states are plain local classes with public
    -- semantic ids, not engine widgets. Keep a custom draw method on the
    -- fixtures so the suppression seam proves the adapter is intentionally
    -- modeling the foreign screen rather than accidentally accepting a stock
    -- draw implementation.
    local rbyProfile = {
      screenId = "RbyMmoProfile",
      player = {
        name = "ONLINE",
        sprite = "PLAYER",
        points = 42,
        money = 1234,
        profile = { idNo = 7, playtime = 7260, badges = 3, seen = 86, owned = 35 },
      },
      draw = function() end,
    }
    check(mod._gen1ModernSpecialPresenters.rbyMmoPortrait(game, "PLAYER")
        ~= nil, "RBY MMO profile resolves the selected player sprite")
    local rbyProfileCanvas = renderHud({ rbyProfile }, "rby_mmo_profile")
    check(pixelAlpha(rbyProfileCanvas, 320, 180) > 0,
      "RBY MMO profile renders through its semantic presenter")
    game.stack.states = { overworld, rbyProfile }
    fill()
    compose(false)
    check(alpha() == 0,
      "RBY MMO profile suppresses its native custom draw")

    local rbyRankRows = {}
    for index = 1, 8 do
      rbyRankRows[index] = { name = "PLAYER " .. index, points = index * 10,
        sprite = "PLAYER" }
    end
    local rbyRank = {
      screenId = "RbyMmoRank", offset = 0, rows = rbyRankRows,
      client = { isRanked = function() return true end }, draw = function() end,
    }
    local rbyRankCanvas = renderHud({ rbyRank }, "rby_mmo_rank")
    check(pixelAlpha(rbyRankCanvas, 320, 180) > 0,
      "RBY MMO rank renders through its semantic presenter")
    game.stack.states = { overworld, rbyRank }
    fill()
    compose(false)
    check(alpha() == 0,
      "RBY MMO rank suppresses its native custom draw")

    local rbyCharPick = setmetatable({
      screenId = "RbyMmoCharPick", title = "CHARACTER", index = 1, scroll = 0,
      items = {
        { label = "PLAYER", value = "PLAYER" },
        { label = "RED", value = "PLAYER" },
      }, draw = function() end,
    }, { __index = listClass })
    check(alphaBounds(renderHud({ rbyCharPick }, "rby_mmo_character_pick",
      largeDesktopViewport)) ~= nil,
      "RBY MMO character selection renders with a selected portrait preview")
  end

  do
    -- Dex Radar 1.x deliberately uses a private screen class, but publishes
    -- this complete live model under the stable DexRadar screen id.
    values.dexRadar = {
      screenId = "DexRadar", mapLabel = "ROUTE 22",
      ownedN = 1, totalN = 3, cursor = 2, scroll = 0,
      showLevels = true, showRates = true,
      rows = {
        { kind = "header", text = "GRASS" },
        { kind = "mon", id = "TESTMON", name = "TESTMON", seen = true,
          owned = true, minLv = 3, maxLv = 5, rate = 25 },
        { kind = "mon", id = "PIDGEY", name = "PIDGEY", seen = true,
          owned = false, minLv = 2, maxLv = 4, rate = 25 },
        { kind = "header", text = "FISH" },
        { kind = "mon", id = "MAGIKARP", name = "?????", seen = false,
          owned = false, minLv = 5, maxLv = 5, rate = 10 },
      },
      monIndex = { 2, 3, 5 },
      moveCursor = function() end,
      update = function() end,
      draw = function() end,
    }
    check(alphaBounds(renderHud({ values.dexRadar }, "dex_radar",
      largeDesktopViewport)) ~= nil,
      "Dex Radar renders through its semantic responsive presenter")
    game.stack.states = { overworld, values.dexRadar }
    fill()
    compose(false)
    check(alpha() == 0,
      "Dex Radar suppresses its native custom draw when the model is complete")

    values.incompleteRadar = {
      screenId = "DexRadar", draw = function() end,
    }
    game.stack.states = { overworld, values.incompleteRadar }
    fill()
    compose(false)
    check(alpha() > 0,
      "incomplete Dex Radar state retains the native fallback")
    if os.getenv("GEN1_UI_DEX_RADAR_ONLY") == "1" then
      print("Dex Radar presenter test: PASS")
      love.event.quit(0)
      return
    end
  end

  values.shop = setmetatable({ title = "BUY", dialogue = true,
    money = function() return 1234 end, footer = "What would you like?",
    items = { { label = "POTION", right = "¥300", value = "POTION" } },
    index = 1, scroll = 0 }, { __index = listClass })
  check(alphaBounds(renderHud({ values.shop }, "shop")) ~= nil,
    "shop detail renders with its owned-quantity model")
  -- The production renderer captures love.graphics.print before the fixture
  -- loads. Its current shop probe is covered by the visual smoke path below;
  -- keep this test focused on the presenter not crashing on shop detail.
  values.shop.items = { { label = "TM01", right = "¥3000", value = "TM_TEST" } }
  renderHud({ values.shop }, "shop_portrait", portraitViewport)
  values.savedTestMoveName = game.data.moves.TEST_MOVE.name
  game.data.moves.TEST_MOVE.name = "A VERY LONG DOUBLE TEAM MOVE NAME"
  values.uiScale, values.fontScale = "150", "150"
  renderHud({ values.shop }, "shop_detail_wrapped", largeDesktopViewport)
  game.data.moves.TEST_MOVE.name = values.savedTestMoveName
  values.uiScale, values.fontScale = "100", "100"
  values.shop.items = { { label = "POTION", right = "¥300", value = "POTION" } }
  values.minimalUi = true
  renderHud({ values.shop }, "shop_minimal")
  values.minimalUi = false

  -- Nested prompts should share one modal policy across rich parents. Bare
  -- quantity/choice states belong over the shop or Bag that opened them, not
  -- at an unrelated safe-window edge; the parent remains visible but dimmed.
  values.nestedQuantity = setmetatable({ qty = 1, unitPrice = 150 },
    { __index = quantityClass })
  renderHud({ values.shop, values.nestedQuantity }, "shop_quantity_modal")
  renderHud({ bag, values.nestedQuantity }, "bag_quantity_modal")
  values.dexOptions = setmetatable({ title = "POKÃ©DEX OPTIONS", index = 1,
    items = { { label = "DATA" }, { label = "CRY" }, { label = "AREA" },
      { label = "QUIT" } } }, { __index = menuClass })
  renderHud({ dex, values.dexOptions }, "pokedex_action_modal")

  -- On a large desktop viewport, rich screens should spend the extra vertical
  -- room that readability scaling requests instead of keeping the reference
  -- height ceiling. At 150% the shop frame reaches this sample row; at 100%
  -- it intentionally ends above it.
  values.savedShopItems = values.shop.items
  local largeShopItems = {}
  for index = 1, 12 do
    largeShopItems[index] = { label = "SHOP ITEM " .. index,
      right = "¥" .. (index * 100), value = "POTION" }
  end
  values.shop.items = largeShopItems
  values.layoutStyle = "floating"
  values.uiScale, values.fontScale = "100", "100"
  local largeShop100 = renderHud({ values.shop }, "shop_large_100", largeDesktopViewport)
  local largeShop100Sample = pixelAlpha(largeShop100, 800, 850)
  values.uiScale, values.fontScale = "150", "150"
  local largeShop150 = renderHud({ values.shop }, "shop_large_150", largeDesktopViewport)
  check(largeShop100Sample == 0
      and pixelAlpha(largeShop150, 800, 850) > 0,
    "large desktop shop uses additional vertical room at higher readability scale")
  values.shop.items = values.savedShopItems
  values.uiScale, values.fontScale = "100", "100"

  -- Minimal rich lists should grow their content-width budget with the
  -- readable font instead of keeping the old 760px ceiling. The high-scale
  -- frame reaches this sample column; the reference-scale frame ends before
  -- it and would otherwise silently truncate the label/value row.
  local savedBagItems = bag.items
  local savedMinimalUi = values.minimalUi
  bag.items = {{
    label = "A VERY LONG MINIMAL BAG LABEL THAT SHOULD REMAIN FULLY READABLE",
    right = "A LONG VALUE COLUMN", value = "POTION",
  }}
  values.minimalUi = true
  values.uiScale, values.fontScale = "100", "100"
  local minimalBag100 = renderHud({ bag }, "minimal_bag_100", largeDesktopViewport)
  local minimalBag100Sample = pixelAlpha(minimalBag100, 1200, 500)
  values.uiScale, values.fontScale = "150", "200"
  local minimalBag200 = renderHud({ bag }, "minimal_bag_200", largeDesktopViewport)
  check(minimalBag100Sample == 0
      and pixelAlpha(minimalBag200, 1200, 500) > 0,
    "minimal bag width grows with larger readable text")
  bag.items = savedBagItems
  values.minimalUi = savedMinimalUi
  values.uiScale, values.fontScale = "100", "100"

  values.pc = setmetatable({ title = "WITHDRAW", messageBox = true,
    footer = "Withdraw how many?",
    items = { { label = "POTION", right = "x2", value = "POTION" } },
    index = 1, scroll = 0 }, { __index = listClass })
  renderHud({ values.pc }, "pc")
  renderHud({ values.pc }, "pc_portrait", portraitViewport)

  textBox.choice = true
  choice.anchor = "bottom"
  renderHud({ overworld, textBox, choice }, "dialogue_choice")
  check(alphaBounds(renderHud({ overworld, textBox, choice },
    "dialogue_choice_portrait", portraitViewport)) ~= nil,
    "dialogue choices render without redundant button-tip layout")
  textBox.choice, textBox.done = nil, true
  check(alphaBounds(renderHud({ overworld, textBox }, nil)) ~= nil,
    "ready dialogue renders with a compact continuation cue")
  values.savedDialoguePagesForWideCard = textBox.pages
  textBox.pages = {{
    "A dialogue panel should leave comfortable room around readable text.",
  }}
  textBox.choice, textBox.done = nil, nil
  check(alphaBounds(renderHud({ overworld, textBox },
    "dialogue_wide_padding", largeDesktopViewport)) ~= nil,
    "dialogue renders with the wider padded card")
  textBox.pages = values.savedDialoguePagesForWideCard
  textBox.choice = true

  state = setmetatable({ screenId = "MoveLearnMenu", selecting = true,
    index = 1, newMoveId = "TEST_MOVE", mon = testMon },
    { __index = package.loaded["src.ui.MoveLearnMenu"] })
  check(alphaBounds(renderHud({ state }, "p2_move_learn", largeDesktopViewport)) ~= nil,
    "Move Learn presenter renders the replacement list")
  state = setmetatable({ screenId = "PicBox", image = nil,
    text = "A picture caption wraps without the classic canvas." },
    { __index = package.loaded["src.ui.PicBox"] })
  check(alphaBounds(renderHud({ state }, "p2_picbox", portraitViewport)) ~= nil,
    "PicBox presenter renders its themed card")
  state = setmetatable({ screenId = "NameRater", title = "NICKNAME?",
    maxLen = 10, glyphs = {}, default = "PIKACHU", row = 1, col = 1,
    lower = false,
    mon = { nickname = "PIKACHU", species = "PIKACHU" },
    grid = function()
      return {
        { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
        { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
        { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
        { "x", "(", ")", ":", ";", "[", "]", "<PK>", "<MN>" },
        { "-", "?", "!", "♂", "♀", "/", ".", ",", "ED" },
        { "lower case" },
      }
    end },
    { __index = { draw = function() end } })
  check(alphaBounds(renderHud({ state }, "p2_naming", portraitViewport)) ~= nil,
    "Name Rater presenter renders its glyph grid")
  check(table.concat(state.glyphs) == "PIKACHU",
    "Name Rater presenter seeds an editable existing nickname")
  values.nameRaterFixture = { state = state, point = {} }
  -- Name Rater pushes NamingScreen.new() directly, so this path intentionally
  -- has no screenId. RBY MMO then adds an instance draw wrapper on top.
  values.wrappedNaming = setmetatable({
    title = "GYARADOS'S NAME?", maxLen = 10, glyphs = { "G", "Y" },
    row = 1, col = 1, lower = false, default = "GYARADOS",
    grid = state.grid,
    draw = function() end },
    { __index = package.loaded["src.ui.NamingScreen"] })
  check(alphaBounds(renderHud({ values.wrappedNaming }, "p2_naming_wrapped",
    portraitViewport)) ~= nil,
    "Name Rater presenter accepts a wrapped built-in NamingScreen")
  state = setmetatable({ screenId = "TownMap", mode = "list", sel = 1,
    locs = { { name = "PALLET TOWN" }, { name = "VIRIDIAN CITY" } } },
    { __index = package.loaded["src.ui.TownMap"] })
  check(alphaBounds(renderHud({ state }, "p2_town_map_list", largeDesktopViewport)) ~= nil,
    "Town Map presenter renders its location list")
  state = setmetatable({ screenId = "TownMap", mode = "grid", sel = 1,
    locs = { { name = "PALLET TOWN", x = 2, y = 11 } },
    byMap = { PALLET_TOWN = { name = "PALLET TOWN", x = 2, y = 11 } },
    partyMembers = { { mapId = "PALLET_TOWN", name = "MISTY" } } },
    { __index = package.loaded["src.ui.TownMap"] })
  check(alphaBounds(renderHud({ state }, "p2_town_map_party", largeDesktopViewport)) ~= nil,
    "Town Map presenter accepts party-member map markers")
  values.rbyTownMap = setmetatable({ screenId = "TownMap", mode = "grid",
    sel = 1, locs = { { name = "PALLET TOWN", x = 2, y = 11 } },
    byMap = { PALLET_TOWN = { name = "PALLET TOWN", x = 2, y = 11 } },
    playerLoc = nil }, { __index = package.loaded["src.ui.TownMap"] })
  values.rbyPartyExports = {
    party = function()
      return { { id = "local" }, { id = "partner", name = "MISTY" } }
    end,
    players = function()
      return { { id = "partner", name = "MISTY", sprite = "PLAYER",
        map = "PALLET_TOWN" } }
    end,
  }
  values.rbyMarkers = mod._gen1ModernSpecialPresenters.townMapPartyMarkers(
    values.rbyTownMap)
  check(#values.rbyMarkers == 1 and values.rbyMarkers[1].name == "MISTY"
      and values.rbyMarkers[1].sprite == "PLAYER"
      and values.rbyMarkers[1].loc == values.rbyTownMap.byMap.PALLET_TOWN,
    "Town Map presenter consumes RBYMMO public party, roster, and sprite exports")
  check(alphaBounds(renderHud({ values.rbyTownMap }, "p2_town_map_rby_mmo",
    largeDesktopViewport)) ~= nil,
    "Town Map presenter renders the RBYMMO party marker")
  values.rbyPartyExports = nil
  state = setmetatable({ screenId = "QuarantineReport", offset = 0,
    lines = { "Moved to LOST box:", " CHARMANDER (ROUTE_1)" },
    maxOffset = function() return 0 end },
    { __index = package.loaded["src.ui.QuarantineReport"] })
  check(alphaBounds(renderHud({ state }, nil, portraitViewport)) ~= nil,
    "Quarantine report presenter renders its recovery summary")
  values.uiScale, values.fontScale = "100", "100"
  values._reportBounds = alphaBounds(renderHud({ state },
    "quarantine_report_compact", largeDesktopViewport))
  check(values._reportBounds and values._reportBounds.w <= 660
      and values._reportBounds.h <= 480,
    "Load Report uses a compact stable envelope instead of filling desktop")
  values._reportBounds = nil

  local pointerItems = {}
  for index = 1, 12 do
    pointerItems[index] = { label = "POINTER ITEM " .. index,
      right = "x" .. index, value = "POTION" }
  end
  bag.items = pointerItems
  bag.index, bag.scroll = 1, 0
  values.uiScale, values.fontScale = "100", "100"
  values.pointerUi, values.dragPanels = false, false
  renderHud({ bag }, "pointer_bag", viewport)
  local pointerNextCalls = 0
  local pointerNext = function()
    pointerNextCalls = pointerNextCalls + 1
    return false
  end
  values.pointerUi = true
  renderHud({ values.nameRaterFixture.state }, nil, portraitViewport)
  for y = 0, portraitViewport.height - 1, 4 do
    for x = 0, portraitViewport.width - 1, 4 do
      values.nameRaterFixture.state.row, values.nameRaterFixture.state.col = 1, 1
      hooks["input.pointer"](pointerNext, game,
        { phase = "moved", source = "mouse", id = "mouse",
          x = x, y = y })
      if values.nameRaterFixture.state.col == 2 then
        values.nameRaterFixture.point.x, values.nameRaterFixture.point.y = x, y
        break
      end
    end
    if values.nameRaterFixture.point.x then break end
  end
  check(values.nameRaterFixture.point.x ~= nil,
    "Name Rater mouse hover selects a character")
  values.nameRaterFixture.tapCount = #pointerTaps
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = values.nameRaterFixture.point.x, y = values.nameRaterFixture.point.y,
      button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = values.nameRaterFixture.point.x, y = values.nameRaterFixture.point.y,
      button = 1 })
  check(#pointerTaps == values.nameRaterFixture.tapCount + 1
      and pointerTaps[#pointerTaps].button == "a",
    "Name Rater mouse click activates a character")
  values.pointerUi = false
  pointerNextCalls = 0
  while #pointerTaps > 0 do table.remove(pointerTaps) end
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 1 })
  check(pointerNextCalls == 2 and #pointerTaps == 0,
    "default-off pointer interaction forwards clicks without game actions")
  values.pointerUi = true
  renderHud({ bag }, "pointer_bag", viewport)
  pointerNextCalls = 0
  hooks["input.pointer"](pointerNext, game,
    { phase = "moved", source = "mouse", id = "mouse", x = 5, y = 5 })
  check(pointerNextCalls == 1,
    "pointer outside the modern UI remains available to later hooks")
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 2 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 2 })
  check(#pointerTaps == 2 and pointerTaps[1].button == "a"
      and pointerTaps[2].button == "b",
    "outside left/right clicks map to source-safe A/B actions")
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 5, y = 5, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "moved", source = "mouse", id = "mouse",
      x = 25, y = 25, dx = 20, dy = 20 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 25, y = 25, button = 1 })
  check(#pointerTaps == 2,
    "an outside mouse drag does not fire the click action on release")
  local hoverY
  for y = 40, 320, 4 do
    bag.index = 1
    hooks["input.pointer"](pointerNext, game,
      { phase = "moved", source = "mouse", id = "mouse", x = 320, y = y })
    if bag.index == 2 then hoverY = y break end
  end
  check(hoverY ~= nil,
    "mouse hover finds a visible row in the responsive card")
  check(bag.index == 2,
    "mouse hover moves the live cursor without activating a row")
  check(#pointerTaps == 2,
    "mouse hover does not synthesize an A action")
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 320, y = hoverY, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 320, y = hoverY, button = 1 })
  check(#pointerTaps == 3 and pointerTaps[3].button == "a",
    "pointer row tap selects through the source-safe A action")

  do
    local thirdRowY
    for y = 40, 320, 4 do
      bag.index = 1
      hooks["input.pointer"](pointerNext, game,
        { phase = "moved", source = "mouse", id = "mouse", x = 320, y = y })
      if bag.index == 3 then thirdRowY = y break end
    end
    check(thirdRowY ~= nil, "pointer test locates a second release target")
    local before = #pointerTaps
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = 320, y = hoverY, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = 320, y = thirdRowY, button = 1 })
    check(#pointerTaps == before,
      "a click only activates when press and release resolve to the same row")

    renderHud({ bag }, "pointer_stale_capture", viewport)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = 320, y = hoverY, button = 1 })
    game.stack.states = { choice }
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = 320, y = hoverY, button = 1 })
    check(#pointerTaps == before,
      "a captured row cannot release into a different stack state")

    renderHud({ bag, choice }, "pointer_modal_isolation", viewport)
    bag.index = 1
    for y = 16, viewport.height - 16, 12 do
      for x = 16, viewport.width - 16, 12 do
        hooks["input.pointer"](pointerNext, game,
          { phase = "moved", source = "mouse", id = "mouse", x = x, y = y })
        check(bag.index == 1,
          "a modal never exposes its parent list to hover")
      end
    end

    local bagCanvas = renderHud({ bag }, "pointer_panel_whitespace", viewport)
    local bounds = alphaBounds(bagCanvas)
    check(bounds ~= nil, "pointer panel has visible bounds")
    local panelX = math.floor(bounds.x + bounds.w / 2)
    local panelY = math.floor(bounds.y + 20)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = panelX, y = panelY, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = panelX, y = panelY, button = 1 })
    check(#pointerTaps == before,
      "blank list-panel chrome blocks global A without activating a row")
  end

  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "touch", id = 1, x = 320, y = hoverY })
  hooks["input.pointer"](pointerNext, game,
    { phase = "moved", source = "touch", id = 1, x = 320, y = hoverY - 70,
      dx = 0, dy = -70 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "touch", id = 1, x = 320, y = hoverY - 70 })
  check((bag.scroll or 0) > 0,
    "dragging a long list scrolls its live state instead of moving the panel")
  check((bag.scroll or 0) <= 2,
    "one-row drag distance does not race through a long list")

  values.dragPanels = true
  local dragFound = false
  for y = 20, 340, 4 do
    renderHud({ bag }, "pointer_drag_bag_" .. y, viewport)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = 320, y = y, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "moved", source = "mouse", id = "mouse", x = 360, y = y + 20,
      dx = 40, dy = 20 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = 360, y = y + 20, button = 1 })
    if savedPins.panelOffsets and savedPins.panelOffsets.bag
        and math.abs(savedPins.panelOffsets.bag.x) > 0
        and math.abs(savedPins.panelOffsets.bag.y) > 0 then
      dragFound = true
      break
    end
  end
  check(dragFound,
    "a responsive panel exposes a draggable surface")
  check(savedPins.panelOffsets and savedPins.panelOffsets.bag
      and math.abs(savedPins.panelOffsets.bag.x) > 0
      and math.abs(savedPins.panelOffsets.bag.y) > 0,
    "multi-source pointer drag persists a normalized panel offset")

  local pointerManager = setmetatable({
    screenId = "ManagerState", screen = "options", cursor = 1, scroll = 0,
    currentMod = { id = "gen1_modern_ui", name = "Gen1 Modern UI" },
    optionRows = {
      { id = "theme", label = "UI THEME" },
      { id = "startMenuFastJump", label = "START MENU FAST JUMP" },
    },
    -- Real ManagerState intentionally returns no rows from rowsForScreen()
    -- while on options, so snapCursor would reset every hovered option to 1.
    snapCursor = function(self) self.cursor = 1 end,
  }, { __index = managerClass })
  renderHud({ pointerManager }, "pointer_manager", viewport)
  local managerHoverY
  for y = 40, 320, 4 do
    pointerManager.cursor = 1
    hooks["input.pointer"](pointerNext, game,
      { phase = "moved", source = "mouse", id = "mouse", x = 320, y = y })
    if pointerManager.cursor == 2 then managerHoverY = y break end
  end
  check(managerHoverY ~= nil,
    "UI settings exposes its categorized rows to mouse hover")
  local managerTapCount = #pointerTaps
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = 320, y = managerHoverY, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = 320, y = managerHoverY, button = 1 })
  check(pointerManager.cursor == 2 and #pointerTaps == managerTapCount + 1
      and pointerTaps[#pointerTaps].button == "a",
    "UI settings hover and left-click use the live manager cursor and A action")

  do
    local before = #pointerTaps
    renderHud({ pointerManager }, "pointer_manager_mode_capture", viewport)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = 320, y = managerHoverY, button = 1 })
    pointerManager.screen = "detail"
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = 320, y = managerHoverY, button = 1 })
    check(#pointerTaps == before,
      "a pointer captured in one Manager mode cannot fire in another")
    pointerManager.screen = "options"

    pointerManager._gen1OptionDescription = {
      title = "UI THEME", text = "Choose a readable presentation theme.",
    }
    renderHud({ pointerManager }, "pointer_manager_help_modal", viewport)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = viewport.width / 2, y = viewport.height / 2, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = viewport.width / 2, y = viewport.height / 2, button = 1 })
    check(pointerManager._gen1OptionDescription == nil
        and #pointerTaps == before,
      "clicking option help dismisses it without adjusting the row below")

    pointerManager.cursor = 2
    pointerManager.overlay = { kind = "confirm", index = 1,
      lines = { "APPLY THESE CHANGES?" } }
    renderHud({ pointerManager }, "pointer_manager_confirm_modal", viewport)
    for y = 20, viewport.height - 20, 16 do
      for x = 20, viewport.width - 20, 16 do
        hooks["input.pointer"](pointerNext, game,
          { phase = "moved", source = "mouse", id = "mouse", x = x, y = y })
        check(pointerManager.cursor == 2,
          "Manager confirmation blocks hover into its underlying options")
      end
    end
    pointerManager.overlay = nil
    renderHud({ pointerManager }, "pointer_manager_after_modal", viewport)
  end

  local extraControls = {}
  for y = 220, viewport.height - 2, 6 do
    for x = 2, viewport.width - 2, 6 do
      hooks["input.pointer"](pointerNext, game,
        { phase = "pressed", source = "mouse", id = "mouse",
          x = x, y = y, button = 1 })
      hooks["input.pointer"](pointerNext, game,
        { phase = "released", source = "mouse", id = "mouse",
          x = x, y = y, button = 1 })
      local button = pointerTaps[#pointerTaps] and pointerTaps[#pointerTaps].button
      if button == "left" or button == "right" or button == "select" then
        extraControls[button] = true
      end
      if extraControls.left and extraControls.right and extraControls.select then
        break
      end
    end
    if extraControls.left and extraControls.right and extraControls.select then
      break
    end
  end
  check(extraControls.left and extraControls.right and extraControls.select,
    "UI settings renders clickable LEFT/RIGHT/SELECT controls")

  local pointerBox = { screenId = "Gen3Box", mode = "box", row = 0, col = 0,
    draw = function() end }
  renderHud({ pointerBox }, "pointer_box", viewport)
  local boxHoverX, boxHoverY
  for y = 20, viewport.height - 20, 4 do
    for x = 20, viewport.width - 20, 4 do
      pointerBox.row, pointerBox.col = 0, 0
      hooks["input.pointer"](pointerNext, game,
        { phase = "moved", source = "mouse", id = "mouse", x = x, y = y })
      if pointerBox.row == 0 and pointerBox.col == 1 then
        boxHoverX, boxHoverY = x, y
        break
      end
    end
    if boxHoverX then break end
  end
  check(boxHoverX ~= nil,
    "PC box grid cells expose hover selection regions")
  local boxTapCount = #pointerTaps
  hooks["input.pointer"](pointerNext, game,
    { phase = "pressed", source = "mouse", id = "mouse",
      x = boxHoverX, y = boxHoverY, button = 1 })
  hooks["input.pointer"](pointerNext, game,
    { phase = "released", source = "mouse", id = "mouse",
      x = boxHoverX, y = boxHoverY, button = 1 })
  check(pointerBox.row == 0 and pointerBox.col == 1
      and #pointerTaps == boxTapCount + 1
      and pointerTaps[#pointerTaps].button == "a",
    "PC box cell click selects the cell before sending A")

  do
    local savedParty = party.party
    party.party = { testMon, testMon, testMon }
    party.index, party.subIndex = 2, 1
    party.submenu = true
    party.subItems = { { label = "SUMMARY" }, { label = "SWITCH" } }
    renderHud({ party }, "pointer_party_submenu", viewport)
    local actionX, actionY
    for y = 16, viewport.height - 16, 6 do
      for x = 16, viewport.width - 16, 6 do
        party.subIndex = 1
        hooks["input.pointer"](pointerNext, game,
          { phase = "moved", source = "mouse", id = "mouse", x = x, y = y })
        check(party.index == 2,
          "Party action modal never moves the underlying party cursor")
        if party.subIndex == 2 then actionX, actionY = x, y break end
      end
      if actionX then break end
    end
    check(actionX ~= nil,
      "Party action rows remain directly hoverable inside their modal")
    local before = #pointerTaps
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = actionX, y = actionY, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = actionX, y = actionY, button = 1 })
    check(party.index == 2 and party.subIndex == 2
        and #pointerTaps == before + 1
        and pointerTaps[#pointerTaps].button == "a",
      "Party action click targets only the live submenu row")
    party.submenu, party.subItems = nil, nil
    party.party, party.index = savedParty, 1

    local summaryCanvas = renderHud({ summary }, "pointer_summary_continue", viewport)
    local summaryBounds = alphaBounds(summaryCanvas)
    check(summaryBounds ~= nil, "summary panel has visible bounds")
    before = #pointerTaps
    local summaryX = math.floor(summaryBounds.x + summaryBounds.w / 2)
    local summaryY = math.floor(summaryBounds.y + summaryBounds.h / 2)
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = summaryX, y = summaryY, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = summaryX, y = summaryY, button = 1 })
    check(#pointerTaps == before + 1
        and pointerTaps[#pointerTaps].button == "a",
      "clicking a continue-only data card maps to A")

    local emptyList = setmetatable({ title = "EMPTY", items = {}, index = 1 },
      { __index = listClass })
    local emptyCanvas = renderHud({ emptyList }, "pointer_empty_list", viewport)
    local emptyBounds = alphaBounds(emptyCanvas)
    before = #pointerTaps
    hooks["input.pointer"](pointerNext, game,
      { phase = "pressed", source = "mouse", id = "mouse",
        x = emptyBounds.x + emptyBounds.w / 2,
        y = emptyBounds.y + emptyBounds.h / 2, button = 1 })
    hooks["input.pointer"](pointerNext, game,
      { phase = "released", source = "mouse", id = "mouse",
        x = emptyBounds.x + emptyBounds.w / 2,
        y = emptyBounds.y + emptyBounds.h / 2, button = 1 })
    check(#pointerTaps == before,
      "an empty-list placeholder cannot synthesize A against a missing item")
  end

  bag.items = savedBagItems
  bag.index, bag.scroll = 1, 0

  verifyUiGallery({
    mod = mod, game = game, hooks = hooks,
    renderHud = renderHud, alphaBounds = alphaBounds,
    viewport = viewport,
  })

  if captureHud then
    print("compose suppression shots: " .. love.filesystem.getSaveDirectory())
  end

  love.filesystem.remove(PLAIN_PIXEL_VIRTUAL)
  print("compose suppression test: PASS")
  love.event.quit(0)
end

-- Gen1 Modern UI
--
-- A visual-only overhaul for the released gen1recomp mod API.  The game keeps
-- ownership of input, state transitions, and menu callbacks; this mod reads
-- the live top menu state and paints a high-resolution presentation through
-- render.hud.  When enabled, render.compose clears the finished classic UI
-- canvas before the engine composites it, leaving the independent world pass
-- intact.  That keeps menu rows supplied by other mods visible without
-- replacing their state objects or reimplementing the renderer.

local MOD_ID = "gen1_modern_ui"
local API_VERSION = 1

local DEFAULT_THEME = {
  id = "default",
  name = "Gen1 Modern",
  version = 1,
  colors = {
    backdrop = { 0.025, 0.045, 0.085, 0.98 },
    surface = { 0.075, 0.105, 0.17, 0.98 },
    surfaceRaised = { 0.12, 0.17, 0.27, 1 },
    selected = { 0.18, 0.43, 0.72, 1 },
    accent = { 0.48, 0.86, 1.00, 1 },
    text = { 0.96, 0.98, 1.00, 1 },
    textMuted = { 0.62, 0.70, 0.82, 1 },
    onAccent = { 0.02, 0.05, 0.09, 1 },
    divider = { 0.25, 0.34, 0.50, 0.90 },
    -- Health states intentionally use teal/gold/orange/purple rather than
    -- the usual green/yellow/red ramp. The adjacent numeric HP label remains
    -- the authoritative, non-color status cue.
    health = {
      track = { 0.16, 0.22, 0.30, 1 },
      high = { 0.18, 0.78, 0.72, 1 },
      medium = { 0.96, 0.72, 0.24, 1 },
      low = { 0.98, 0.47, 0.22, 1 },
      critical = { 0.82, 0.40, 0.94, 1 },
    },
  },
  typography = { title = 24, body = 17, caption = 13 },
  spacing = { xs = 5, sm = 9, md = 13, lg = 18, xl = 26 },
  radii = { sm = 8, md = 16, lg = 22 },
  frame = { style = "pixel", asset = "assets/pixel_frame1.png", slice = 24,
    pixelScale = 2, pixelInset = 7, width = 3, corner = 12, inset = 2,
    margin = 4, step = 4, shadow = 2 },
  density = { rowHeight = 54, panelMax = 780 },
  -- Metrics are presentation tokens rather than engine pixels.  The
  -- effective UI scale resolver below adjusts these before any presenter
  -- measures text or chooses a panel size.
  metrics = { border = 4, divider = 1, icon = 38, dialogueMinHeight = 112 },
}

-- Built-in themes are intentionally data-only. They are merged once during
-- installation, so switching palettes adds no render branches, canvases,
-- shaders, fonts, or assets. The `default` ID remains stable for existing
-- saves; every additional built-in uses the same namespace required of theme
-- packs supplied by other mods.
local BUILTIN_THEMES = {
  {
    id = "gen1_modern_ui:modern_glass",
    name = "Modern Glass",
    colors = {
      backdrop = { 0.025, 0.045, 0.085, 0.38 },
      surface = { 0.075, 0.105, 0.17, 0.84 },
      surfaceRaised = { 0.12, 0.17, 0.27, 0.88 },
      selected = { 0.18, 0.43, 0.72, 0.94 },
      divider = { 0.25, 0.34, 0.50, 0.62 },
    },
  },
  {
    id = "gen1_modern_ui:classic_mono",
    name = "Classic Mono",
    colors = {
      backdrop = { 0.035, 0.035, 0.030, 0.76 },
      surface = { 0.96, 0.95, 0.89, 1 },
      surfaceRaised = { 0.86, 0.85, 0.78, 1 },
      selected = { 0.75, 0.77, 0.68, 1 },
      accent = { 0.08, 0.09, 0.07, 1 },
      text = { 0.055, 0.060, 0.050, 1 },
      textMuted = { 0.30, 0.31, 0.27, 1 },
      onAccent = { 0.98, 0.98, 0.93, 1 },
      divider = { 0.48, 0.49, 0.43, 0.82 },
      health = {
        track = { 0.80, 0.80, 0.72, 1 },
        high = { 0.02, 0.38, 0.36, 1 },
        medium = { 0.56, 0.32, 0.02, 1 },
        low = { 0.66, 0.20, 0.04, 1 },
        critical = { 0.36, 0.08, 0.48, 1 },
      },
    },
    radii = { sm = 2, md = 4, lg = 6 },
  },
  {
    id = "gen1_modern_ui:pocket_green",
    name = "Pocket Green",
    colors = {
      backdrop = { 0.035, 0.075, 0.040, 0.78 },
      surface = { 0.80, 0.84, 0.63, 1 },
      surfaceRaised = { 0.68, 0.75, 0.50, 1 },
      selected = { 0.70, 0.78, 0.49, 1 },
      accent = { 0.10, 0.22, 0.12, 1 },
      text = { 0.08, 0.13, 0.09, 1 },
      textMuted = { 0.20, 0.28, 0.17, 1 },
      onAccent = { 0.90, 0.95, 0.72, 1 },
      divider = { 0.34, 0.44, 0.29, 0.90 },
      health = {
        track = { 0.76, 0.81, 0.62, 1 },
        high = { 0.02, 0.38, 0.36, 1 },
        medium = { 0.56, 0.32, 0.02, 1 },
        low = { 0.66, 0.20, 0.04, 1 },
        critical = { 0.36, 0.08, 0.48, 1 },
      },
    },
    radii = { sm = 2, md = 5, lg = 8 },
  },
  {
    id = "gen1_modern_ui:midnight",
    name = "Midnight",
    colors = {
      backdrop = { 0.018, 0.022, 0.040, 0.96 },
      surface = { 0.035, 0.045, 0.075, 1 },
      surfaceRaised = { 0.075, 0.090, 0.150, 1 },
      selected = { 0.19, 0.12, 0.38, 1 },
      accent = { 0.64, 0.47, 1.00, 1 },
      text = { 0.96, 0.95, 1.00, 1 },
      textMuted = { 0.69, 0.67, 0.80, 1 },
      onAccent = { 0.05, 0.03, 0.10, 1 },
      divider = { 0.22, 0.22, 0.34, 0.95 },
    },
  },
  {
    id = "gen1_modern_ui:midnight_glass",
    name = "Midnight Glass",
    colors = {
      backdrop = { 0.018, 0.022, 0.040, 0.42 },
      surface = { 0.035, 0.045, 0.075, 0.84 },
      surfaceRaised = { 0.075, 0.090, 0.150, 0.88 },
      selected = { 0.19, 0.12, 0.38, 0.94 },
      accent = { 0.64, 0.47, 1.00, 1 },
      text = { 0.96, 0.95, 1.00, 1 },
      textMuted = { 0.69, 0.67, 0.80, 1 },
      onAccent = { 0.05, 0.03, 0.10, 1 },
      divider = { 0.22, 0.22, 0.34, 0.65 },
    },
  },
  {
    id = "gen1_modern_ui:frost",
    name = "Frost",
    colors = {
      backdrop = { 0.055, 0.090, 0.140, 0.45 },
      surface = { 0.96, 0.98, 1.00, 1 },
      surfaceRaised = { 0.88, 0.93, 0.98, 1 },
      selected = { 0.70, 0.84, 1.00, 1 },
      accent = { 0.04, 0.38, 0.66, 1 },
      text = { 0.055, 0.095, 0.160, 1 },
      textMuted = { 0.28, 0.35, 0.45, 1 },
      onAccent = { 0.98, 1.00, 1.00, 1 },
      divider = { 0.58, 0.68, 0.80, 0.82 },
      health = {
        track = { 0.86, 0.90, 0.95, 1 },
        high = { 0.02, 0.38, 0.36, 1 },
        medium = { 0.56, 0.32, 0.02, 1 },
        low = { 0.66, 0.20, 0.04, 1 },
        critical = { 0.36, 0.08, 0.48, 1 },
      },
    },
  },
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

local function merge(base, patch)
  local out = copy(base)
  if type(patch) ~= "table" then return out end
  for key, value in pairs(patch) do
    if type(value) == "table" and type(out[key]) == "table" then
      out[key] = merge(out[key], value)
    else
      out[key] = copy(value)
    end
  end
  return out
end

local function setColor(c)
  love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
end

-- Supported classic UI is removed independently by render.compose, so theme
-- alpha is safe to honor here. Opaque palettes hide the world; glass palettes
-- intentionally retain it without exposing the classic menu underneath.
local function setBackdrop(theme)
  setColor(theme.colors.backdrop)
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function normalizedPercent(value, fallback, minimum, maximum)
  local percent = tonumber(value) or fallback
  percent = clamp(percent, minimum, maximum)
  return math.floor(percent / 5 + 0.5) * 5
end

local nativeGenderSigns = false

local function safeText(value)
  if value == nil then return "" end
  local text = tostring(value)
  -- The released game's display data uses UTF-8 for the Gen1 gender signs,
  -- but the default LÖVE font used by this overlay may not contain those
  -- glyphs. Keep the names readable in the visual-only layer instead of
  -- emitting a tofu box; the extra space also keeps the fallback distinct
  -- from the species name itself.
  if not nativeGenderSigns then
    text = text:gsub("\226\153\130", " M")
    text = text:gsub("\226\153\128", " F")
  end
  return text
end

-- Images are optional presentation metadata.  A menu author may provide an
-- Image/Canvas userdata directly, a small descriptor such as
-- { image = image }, or a virtual Love path.  Loading is guarded and cached:
-- an unavailable asset simply leaves the text row intact, which is important
-- for mods that are installed without their optional art pack.
local function drawable(value)
  if value == nil then return nil end
  if type(value) == "table" then
    value = value.image or value.texture or value.path or value.asset
  end
  if type(value) == "userdata" then
    local ok, width = pcall(function() return value:getWidth() end)
    local okH, height = pcall(function() return value:getHeight() end)
    if ok and okH and width and height and width > 0 and height > 0 then
      return value
    end
    return nil
  end
  if type(value) ~= "string" or value == "" then return nil end
  return value
end

-- Optional image descriptors can opt into the same sheet convention used by
-- sprite replacement mods: frames are stacked vertically unless `axis` is
-- set to `horizontal`.  Pokemon sprites are marked animated by spriteFor /
-- iconFor below, so existing replacement packs need no manifest changes.
local function imageDescriptor(value)
  local descriptor = {}
  if type(value) == "table" then
    local animation = value.animation
    if type(animation) == "table" then
      descriptor.frames = animation.frames or animation.count
      descriptor.duration = animation.duration or animation.frameDuration
      descriptor.axis = animation.axis
      descriptor.animated = animation.enabled ~= false
    end
    descriptor.frames = value.frames or descriptor.frames
    descriptor.duration = value.frameDuration or value.duration or descriptor.duration
    descriptor.axis = value.axis or descriptor.axis
    if descriptor.frames ~= nil and descriptor.animated == nil then
      descriptor.animated = true
    end
    if value.animated ~= nil then descriptor.animated = value.animated end
  end
  return drawable(value), descriptor
end

local function imageCandidate(item)
  if type(item) ~= "table" then return nil end
  return item.image or item.icon or item.thumbnail or item.sprite or item.asset
end

local function titleFor(Strings, state, kind)
  local names = {
    -- The game context already makes the Start menu obvious. Keeping this
    -- empty lets the compact floating layout begin with its first action row.
    StartMenu = "",
    BagMenu = "ITEMS",
    ShopMenu = "SHOP",
    PlayerPC = "ITEM STORAGE",
    BoxMenu = "PC BOX",
    PokedexMenu = "POKéDEX",
    OptionsMenu = "OPTIONS",
    PartyMenu = "POKéMON",
    SummaryMenu = "SUMMARY",
    RunModeOptions = "RUN MODE",
    ShinyPokemonOptions = "SHINY POKEMON",
    QualityOfLife = "QUALITY OF LIFE",
    LinkState = "LINK",
  }
  local title = state and state.title or names[state and state.screenId]
  if state and state._gen1ModMenus and not state.title then
    title = "MOD MENUS"
  end
  if not title then
    title = ({ menu = "MENU", list = "LIST", choice = "CHOOSE",
               quantity = "QUANTITY", options = "OPTIONS",
               mod_options = "OPTIONS", link = "LINK",
               party = "POKéMON", summary = "SUMMARY" })[kind]
  end
  if kind == "choice" or (kind == "menu" and not (state and state.title)
      and not (state and names[state.screenId])) then
    title = ""
  end
  return Strings(title or "MENU")
end

local PLAIN_PIXEL_FONT = "assets/fonts/plainpixel/PlainPixel-Regular.ttf"
-- Plain Pixel's authored glyph cell is 11 rows high (Latin glyphs are
-- usually 5x11; double-width glyphs are 11x11).  The font's own usage notes
-- recommend a 15-point raster step, though, because its OpenType metrics and
-- baseline are not a literal 11px font-size grid.  Keep those two contracts
-- separate: the cell describes the artwork, while the raster step keeps the
-- rendered glyph bitmap undistorted.
local PLAIN_PIXEL_CELL_HEIGHT = 11
local PLAIN_PIXEL_RASTER_STEP = 15
local PIXEL_FONT_SCALE_CHOICES = {
  { "1X", "100" }, { "2X", "200" }, { "3X", "300" },
  { "4X", "400" },
}
local FONT_SCALE_CHOICES = { { "AUTO", "auto" } }
for percent = 80, 200, 5 do
  FONT_SCALE_CHOICES[#FONT_SCALE_CHOICES + 1] = {
    percent .. "%", tostring(percent)
  }
end

local function normalizedPixelFontScale(value, pixelEnabled)
  if pixelEnabled then
    local numeric = tonumber(value)
    if not numeric then return "100" end
    local scale = numeric < 10 and numeric or numeric / 100
    return tostring(clamp(math.floor(scale + 0.5), 1, 4) * 100)
  end
  if value ~= nil and tostring(value):lower() == "auto" then return "auto" end
  local numeric = tonumber(value) or 100
  return tostring(clamp(math.floor(numeric / 5 + 0.5) * 5, 80, 200))
end

-- LÖVE's nearest texture filter cannot correct a fractional draw position.
-- Keep metadata by font object so every modern text primitive can snap its
-- origin only when the active font is Plain Pixel.  System-font rendering is
-- deliberately left byte-for-byte on its existing path.
local pixelFontMetrics = setmetatable({}, { __mode = "k" })
local rawPrint = love.graphics.print
local rawPrintf = love.graphics.printf

local function pixelTextDpi()
  if love and love.graphics and type(love.graphics.getDPIScale) == "function" then
    local ok, value = pcall(love.graphics.getDPIScale)
    if ok and type(value) == "number" and value > 0 then return value end
  end
  return 1
end

local function snapPixelTextCoordinate(value)
  if type(value) ~= "number" or type(love.graphics.getFont) ~= "function" then
    return value
  end
  local active = love.graphics.getFont()
  if not active or not pixelFontMetrics[active] then return value end
  local dpi = pixelTextDpi()
  return math.floor(value * dpi + 0.5) / dpi
end

local function drawText(text, x, y, ...)
  return rawPrint(text, snapPixelTextCoordinate(x),
    snapPixelTextCoordinate(y), ...)
end

local function drawTextWrapped(text, x, y, width, align, ...)
  if type(width) == "number" and love.graphics.getFont()
      and pixelFontMetrics[love.graphics.getFont()] then
    local dpi = pixelTextDpi()
    width = math.max(1, math.floor(width * dpi + 0.5) / dpi)
  end
  return rawPrintf(text, snapPixelTextCoordinate(x),
    snapPixelTextCoordinate(y), width, align, ...)
end

local function useNativeGenderSigns(selected)
  nativeGenderSigns = false
  if selected and type(selected.hasGlyphs) == "function" then
    local ok, supported = pcall(function()
      return selected:hasGlyphs("♀") and selected:hasGlyphs("♂")
    end)
    nativeGenderSigns = ok and supported == true
  end
  return nativeGenderSigns
end

local function plainPixelRasterScale(pixels)
  -- Keep Plain Pixel on its authored 15pt raster steps. Constructing it at an
  -- arbitrary UI size and compensating with fractional DPI resamples the
  -- glyph atlas before nearest filtering can help.
  local requested = math.max(1, pixels)
  local rasterScale = math.max(1,
    math.floor(requested / PLAIN_PIXEL_RASTER_STEP + 0.5))
  local raster = rasterScale * PLAIN_PIXEL_RASTER_STEP
  return raster, rasterScale
end

local function font(cache, size)
  local pixels = math.max(10, math.floor((size or 16) + 0.5))
  local usePixel = cache and cache._usePixel == true
  local family = usePixel and "pixel" or "system"
  local raster, rasterScale = plainPixelRasterScale(pixels)
  local requestedRaster = usePixel and raster or pixels
  local key = family .. ":" .. requestedRaster
  if cache[key] then
    nativeGenderSigns = cache["gender:" .. key] == true
    return cache[key]
  end

  local selected
  if usePixel and not cache._pixelUnavailable then
    -- Plain Pixel's authored cells raster cleanly at multiples of 15. The DPI
    -- argument lets LÖVE build such a raster while preserving the requested
    -- logical font size and therefore the layout's uniform x/y scale.
    local ok, loaded = pcall(love.graphics.newFont,
      PLAIN_PIXEL_FONT, raster, "mono", 1)
    if not ok then
      -- LÖVE before 11.0 has no explicit font DPI argument. Those compatible
      -- hosts retain the old path and still receive nearest filtering.
      ok, loaded = pcall(love.graphics.newFont,
        PLAIN_PIXEL_FONT, raster, "mono")
    end
    if ok and loaded then
      selected = loaded
      pixelFontMetrics[selected] = {
        cellHeight = PLAIN_PIXEL_CELL_HEIGHT,
        rasterStep = PLAIN_PIXEL_RASTER_STEP,
        raster = raster,
        rasterScale = rasterScale,
      }
      if type(selected.setFilter) == "function" then
        pcall(selected.setFilter, selected, "nearest", "nearest", 0)
      end
      local systemKey = "system:" .. raster
      local fallback = cache[systemKey]
      if not fallback then
        local fallbackOk, fallbackFont = pcall(love.graphics.newFont, raster)
        if fallbackOk and fallbackFont then
          fallback = fallbackFont
          cache[systemKey] = fallback
        end
      end
      if fallback and type(selected.setFallbacks) == "function" then
        pcall(selected.setFallbacks, selected, fallback)
      end
    else
      cache._pixelUnavailable = true
    end
  end
  if not selected then selected = love.graphics.newFont(pixels) end
  cache["gender:" .. key] = useNativeGenderSigns(selected)
  cache[key] = selected
  return selected
end

local function textHeight(textFont)
  if not textFont then return 0 end
  local height = textFont:getHeight()
  if type(textFont.getLineHeight) == "function" then
    local ok, multiplier = pcall(textFont.getLineHeight, textFont)
    if ok and type(multiplier) == "number" and multiplier > 0 then
      height = height * multiplier
    end
  end
  return height
end

local function removeLastTextCharacter(text)
  local index = #text
  while index > 0 do
    local byte = text:byte(index)
    -- UTF-8 continuation bytes begin 10xxxxxx. Stop at the lead byte so a
    -- truncation never hands LÖVE an incomplete multi-byte character.
    if byte < 128 or byte >= 192 then
      return text:sub(1, index - 1)
    end
    index = index - 1
  end
  return ""
end

local function truncate(text, maxWidth, textFont)
  text = safeText(text)
  maxWidth = math.max(1, tonumber(maxWidth) or 1)
  textFont = textFont or love.graphics.getFont()
  if textFont:getWidth(text) <= maxWidth then return text end
  local suffix = "..."
  while #text > 0 and textFont:getWidth(text .. suffix) > maxWidth do
    text = removeLastTextCharacter(text)
  end
  return text .. suffix
end

local wrapFittedText = false

local function drawFittedText(text, x, y, maxWidth, textFont)
  textFont = textFont or love.graphics.getFont()
  love.graphics.setFont(textFont)
  if wrapFittedText then
    drawTextWrapped(safeText(text), x, y, math.max(1, maxWidth), "left")
    return
  end
  drawText(truncate(text, maxWidth, textFont), x, y)
end

local utf8TextLibrary

local function textCharacters(value)
  if utf8TextLibrary == nil then
    local ok, library = pcall(require, "utf8")
    utf8TextLibrary = ok and library or false
  end
  local chars = {}
  if utf8TextLibrary and type(utf8TextLibrary.codes) == "function"
      and type(utf8TextLibrary.char) == "function" then
    for _, codepoint in utf8TextLibrary.codes(value) do
      chars[#chars + 1] = utf8TextLibrary.char(codepoint)
    end
  else
    for index = 1, #value do chars[#chars + 1] = value:sub(index, index) end
  end
  return chars
end

local function wrappedLines(text, maxWidth, textFont)
  local lines = {}
  text = safeText(text):gsub("\v", "\n"):gsub("\f", "\n")
  maxWidth = math.max(1, tonumber(maxWidth) or 1)
  textFont = textFont or love.graphics.getFont()
  local function width(value) return textFont:getWidth(value) end
  local function appendWord(line, word)
    if word == "" then return line end
    if width(word) <= maxWidth then
      return line == "" and word or line .. " " .. word
    end
    if line ~= "" then lines[#lines + 1] = line end
    local fragment = ""
    for _, character in ipairs(textCharacters(word)) do
      local candidate = fragment .. character
      if fragment ~= "" and width(candidate) > maxWidth then
        lines[#lines + 1] = fragment
        fragment = character
      else
        fragment = candidate
      end
    end
    return fragment
  end
  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if line ~= "" and width(candidate) > maxWidth then
        lines[#lines + 1] = line
        line = appendWord("", word)
      else
        line = appendWord(line, word)
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function drawWrappedText(text, x, y, maxWidth, textFont, lineGap)
  textFont = textFont or love.graphics.getFont()
  lineGap = lineGap or (textHeight(textFont) + 2)
  local lines = wrappedLines(text, maxWidth, textFont)
  love.graphics.setFont(textFont)
  for index, line in ipairs(lines) do
    drawText(line, x, y + (index - 1) * lineGap)
  end
  return y + #lines * lineGap, #lines
end

local function viewportRect(viewport)
  if viewport and viewport.safe then
    local safe = viewport.safe
    return safe.x or 0, safe.y or 0,
      math.max(1, safe.width or viewport.width or 1),
      math.max(1, safe.height or viewport.height or 1)
  end
  if viewport and viewport.safeX then
    return viewport.safeX, viewport.safeY,
      math.max(1, viewport.safeWidth or viewport.width or 1),
      math.max(1, viewport.safeHeight or viewport.height or 1)
  end
  if love.window and love.window.getSafeArea then
    local ok, sx, sy, sw, sh = pcall(love.window.getSafeArea)
    if ok and sw and sh then return sx, sy, math.max(1, sw), math.max(1, sh) end
  end
  local w = viewport and viewport.width or love.graphics.getWidth()
  local h = viewport and viewport.height or love.graphics.getHeight()
  return 0, 0, math.max(1, w), math.max(1, h)
end

-- AUTO keeps the authored scale controls responsive to the usable window while
-- retaining the same bounded, five-percent increments as the manual choices.
-- Landscape sizing uses both dimensions so an ultrawide window cannot grow
-- panels based on width alone; portrait sizing keys off width because that is
-- the limiting dimension for readable phone UI.
local function autoScalePercent(viewport, minimum, maximum)
  local _, _, width, height = viewportRect(viewport)
  local ratio
  if height > width * 1.2 then
    ratio = width / 400
  else
    ratio = math.min(width / 640, height / 360)
  end
  return normalizedPercent(ratio * 100, 100, minimum, maximum)
end

local function resolvedScalePercent(value, viewport, minimum, maximum)
  if safeText(value):lower() == "auto" then
    return autoScalePercent(viewport, minimum, maximum), true
  end
  return normalizedPercent(value, 100, minimum, maximum), false
end

-- The engine draws the virtual controls after render.hud.  On a phone that
-- means a full-height presenter would otherwise put its footer underneath a
-- d-pad/A/B button.  Keep the original viewport untouched for the game and
-- give presenters a shallow copy whose safe rect ends above the controls.
-- Desktop installs have no visible TouchControls, so this is a no-op there.
local function viewportForTouchControls(game, viewport)
  local touch = game and game.touchControls
  local stack = game and game.stack
  if not touch or (stack and type(stack.touchControlsHidden) == "function"
      and stack:touchControlsHidden()) then
    return viewport
  end
  if type(touch.visible) ~= "function" or type(touch.layout) ~= "function" then
    return viewport
  end
  local okVisible, visible = pcall(touch.visible, touch)
  if not okVisible or not visible then return viewport end
  local adjusted = {}
  for key, value in pairs(viewport or {}) do adjusted[key] = value end
  adjusted._gen1TouchVisible = true
  local okLayout, controls = pcall(touch.layout, touch)
  if not okLayout or type(controls) ~= "table" then return adjusted end

  local x, y, w, h = viewportRect(viewport)
  local lowerTop = y + h
  local names = { "dpad", "a", "b", "start", "select" }
  for _, name in ipairs(names) do
    local zone = controls[name]
    if type(zone) == "table" and type(zone.cx) == "number"
        and type(zone.cy) == "number" and type(zone.w) == "number"
        and zone.cy > y + h * 0.52 then
      local radius = zone.w * 0.58
      if name == "start" or name == "select" then
        radius = radius + zone.w * 0.28 -- include the START/SELECT caption
      end
      lowerTop = math.min(lowerTop, zone.cy - radius)
    end
  end
  local inset = math.max(0, y + h - lowerTop + 10)
  if inset <= 12 then return adjusted end
  -- A landscape phone has a very short safe height; keep the footer above
  -- the controls without allowing a stray custom position to consume the
  -- entire canvas. Portrait uses the measured control edge directly.
  local landscape = w >= h
  local cap = landscape and math.max(110, h * 0.52)
    or math.max(180, h * 0.30)
  inset = math.min(inset, cap)
  local safeH = math.max(1, h - inset)
  adjusted.safeX, adjusted.safeY = x, y
  adjusted.safeWidth, adjusted.safeHeight = w, safeH
  adjusted.safe = { x = x, y = y, width = w, height = safeH }
  adjusted.fullSafe = { x = x, y = y, width = w, height = h }
  return adjusted
end

local function fullViewportRect(viewport)
  if viewport and viewport.fullSafe then
    local safe = viewport.fullSafe
    return safe.x or 0, safe.y or 0, math.max(1, safe.width or 1),
      math.max(1, safe.height or 1)
  end
  return viewportRect(viewport)
end

-- Rect used by presenters. On a landscape phone the side controls can sit
-- over the lower corners, so let the narrow central card use the full window
-- height; START/SELECT may layer over its lower edge.
local function presenterRect(viewport)
  local x, y, w, h = viewportRect(viewport)
  if viewport and viewport.fullSafe and w > h * 1.2 then
    local fx, fy, fw, fh = fullViewportRect(viewport)
    return fx, fy, fw, fh
  end
  return x, y, w, h
end

local function shiftedViewport(viewport, dx, dy)
  if (tonumber(dx) or 0) == 0 and (tonumber(dy) or 0) == 0 then
    return viewport
  end
  local out = copy(viewport or {})
  local function shiftRect(rect)
    if type(rect) ~= "table" then return rect end
    local shifted = copy(rect)
    if type(shifted.x) == "number" then shifted.x = shifted.x + dx end
    if type(shifted.y) == "number" then shifted.y = shifted.y + dy end
    return shifted
  end
  out.safe = shiftRect(out.safe)
  out.fullSafe = shiftRect(out.fullSafe)
  if type(out.safeX) == "number" then out.safeX = out.safeX + dx end
  if type(out.safeY) == "number" then out.safeY = out.safeY + dy end
  if type(out.x) == "number" then out.x = out.x + dx end
  if type(out.y) == "number" then out.y = out.y + dy end
  return out
end

local function panelWidthFor(viewport, availableW, maxWidth)
  local panelW = math.min(availableW, maxWidth)
  local _, _, w, h = presenterRect(viewport)
  if viewport and viewport.fullSafe and w > h * 1.2 then
    -- Keep rich/static presenters readable on narrow landscape windows too;
    -- content-specific callers still provide their own upper bound.
    panelW = math.min(panelW, w * 0.72)
  end
  return math.max(1, panelW)
end

-- LOVE reports Android/iOS windows in logical units, but the phone screenshots
-- are still physically much taller than a desktop canvas.  A modest portrait
-- scale keeps 17px body text and 54px rows from looking undersized without
-- changing landscape/desktop presentation or the underlying input geometry.
local function viewportClass(viewport)
  local _, _, w, h = viewportRect(viewport)
  if h > w * 1.55 and w <= 720 then return "portrait-phone" end
  if w > h * 2.0 then return "ultrawide" end
  if w > h * 1.2 then return "landscape" end
  return "standard"
end

local function scaledTheme(theme, uiScale, fontScale, cache)
  local key = ("%.3f:%.3f"):format(uiScale, fontScale)
  local bucket = cache[theme]
  if not bucket then
    bucket = {}
    cache[theme] = bucket
  end
  if bucket[key] then return bucket[key] end

  local out = copy(theme)
  out.typography = copy(theme.typography)
  out.spacing = copy(theme.spacing)
  out.radii = copy(theme.radii)
  out.frame = copy(theme.frame or {})
  out.density = copy(theme.density)
  out.metrics = copy(theme.metrics or {})
  for name, value in pairs(out.typography) do
    if type(value) == "number" then out.typography[name] = value * fontScale end
  end
  for name, value in pairs(out.spacing) do
    if type(value) == "number" then out.spacing[name] = value * uiScale end
  end
  for name, value in pairs(out.radii) do
    if type(value) == "number" then out.radii[name] = value * uiScale end
  end
  for name, value in pairs(out.frame) do
    if type(value) == "number" and name ~= "pixelScale" and
        name ~= "pixelInset" and name ~= "pixelBorder" and name ~= "slice" and
        name ~= "pixelDpiX" and name ~= "pixelDpiY" then
      out.frame[name] = value * uiScale
    end
  end
  if type(out.density.rowHeight) == "number" then
    out.density.rowHeight = out.density.rowHeight * uiScale
  end
  if type(out.density.panelMax) == "number" then
    out.density.panelMax = out.density.panelMax * uiScale
  end
  for name, value in pairs(out.metrics) do
    if type(value) == "number" then out.metrics[name] = value * uiScale end
  end
  out.scale = { ui = uiScale, font = fontScale, dialogue = 1 }
  bucket[key] = out
  return out
end

local function responsiveTheme(theme, viewport, cache)
  -- AUTO already incorporates the current viewport. Applying the legacy
  -- portrait boost again would scale that responsive value twice.
  if theme.scale and theme.scale.auto then return theme end
  local _, _, w, h = viewportRect(viewport)
  if not (h > w * 1.55 and w <= 720) then return theme end
  local scale = clamp(w / 460, 1.16, 1.28)
  local key = viewportClass(viewport) .. ":" .. ("%.3f"):format(scale)
  local bucket = cache and cache[theme]
  if bucket and bucket[key] then return bucket[key] end
  local out = copy(theme)
  out.typography = copy(theme.typography)
  out.spacing = copy(theme.spacing)
  out.radii = copy(theme.radii)
  out.frame = copy(theme.frame or {})
  out.density = copy(theme.density)
  out.metrics = copy(theme.metrics or {})
  for key, value in pairs(out.typography) do out.typography[key] = value * scale end
  for key, value in pairs(out.spacing) do out.spacing[key] = value * scale end
  for key, value in pairs(out.radii) do out.radii[key] = value * scale end
  for key, value in pairs(out.frame) do
    if type(value) == "number" and key ~= "pixelScale" and
        key ~= "pixelInset" and key ~= "pixelBorder" and key ~= "slice" and
        key ~= "pixelDpiX" and key ~= "pixelDpiY" then
      out.frame[key] = value * scale
    end
  end
  out.density.rowHeight = out.density.rowHeight * scale
  for key, value in pairs(out.metrics) do out.metrics[key] = value * scale end
  if cache then
    bucket = bucket or {}
    cache[theme] = bucket
    bucket[key] = out
  end
  return out
end

local function classOf(state)
  local mt = state and getmetatable(state)
  return mt and mt.__index
end

local function inherits(class, target, seen)
  if not target then return false end
  if class == target then return true end
  if type(class) ~= "table" or not target then return false end
  seen = seen or {}
  if seen[class] then return false end
  seen[class] = true
  local mt = getmetatable(class)
  return mt and inherits(mt.__index, target, seen) or false
end

-- The stock naming grid has no numeric glyphs. Keep both original letter
-- pages intact and add two compact number rows immediately before the
-- page-switch row. This uses the host's existing grid navigation and confirm
-- callbacks, so Name Rater and trainer naming still finish through their
-- original onDone handlers. If another mod already supplies digits (RBY MMO
-- does), leave its page untouched.
local NAMING_NUMBER_ROWS = {
  { "1", "2", "3", "4", "5" },
  { "6", "7", "8", "9", "0" },
}

local function namingGridHasDigit(grid)
  if type(grid) ~= "table" then return false end
  for _, row in ipairs(grid) do
    if type(row) == "table" then
      for _, cell in ipairs(row) do
        if cell == "0" or cell == "1" or cell == "2"
            or cell == "3" or cell == "4" or cell == "5"
            or cell == "6" or cell == "7" or cell == "8"
            or cell == "9" then
          return true
        end
      end
    end
  end
  return false
end

local function namingGridHasLowercase(grid)
  if type(grid) ~= "table" then return false end
  for _, row in ipairs(grid) do
    if type(row) == "table" then
      for _, cell in ipairs(row) do
        if type(cell) == "string" and cell:match("^[a-z]$") then
          return true
        end
      end
    end
  end
  return false
end

local function namingGridWithNumbers(grid)
  if type(grid) ~= "table" or #grid == 0 then return grid end
  local hasDigit = namingGridHasDigit(grid)
  local caseRow = #grid
  for rowIndex, row in ipairs(grid) do
    if type(row) == "table" then
      if #row == 1 and (row[1] == "lower case"
          or row[1] == "UPPER CASE" or row[1] == "lower"
          or row[1] == "UPPER" or row[1] == "123"
          or row[1] == "ABC") then
        caseRow = rowIndex
      end
    end
  end

  -- RBY MMO labels the uppercase page's case-switch row `123` and its
  -- numeric page's return row `ABC`. Those labels are meaningful to its
  -- original renderer, but the engine's NamingScreen only recognizes the
  -- semantic `lower case` / `UPPER CASE` labels when locating the switch.
  -- Normalize the labels while preserving the row's position and callback
  -- behavior. This also keeps the modern presenter from advertising a
  -- button that looks like a digits page but actually toggles case.
  local normalized = {}
  for rowIndex, row in ipairs(grid) do
    if type(row) == "table" and #row == 1 then
      local label = row[1]
      if label == "123" then
        normalized[rowIndex] = { "lower case" }
      elseif label == "ABC" then
        normalized[rowIndex] = { "UPPER CASE" }
      end
    end
    if not normalized[rowIndex] then normalized[rowIndex] = row end
  end
  if hasDigit then return normalized end

  local augmented = {}
  for rowIndex, row in ipairs(normalized) do
    if rowIndex == caseRow then
      for _, numberRow in ipairs(NAMING_NUMBER_ROWS) do
        augmented[#augmented + 1] = numberRow
      end
    end
    augmented[#augmented + 1] = row
  end
  return augmented
end

local function normalizedScreenId(value)
  return type(value) == "string"
    and value:lower():gsub("[^a-z0-9]", "") or ""
end

local function isRbyMmoProfileState(state)
  if type(state) ~= "table" then return false end
  return normalizedScreenId(state.screenId):find("rbymmoprofile", 1, true) ~= nil
    and type(state.player) == "table"
end

local function isRbyMmoRankState(state)
  if type(state) ~= "table" then return false end
  local id = normalizedScreenId(state.screenId)
  return id:find("rbymmorank", 1, true) ~= nil
    and (type(state.offset) == "number" or type(state.client) == "table"
      or type(state.rows) == "table")
end

local function isRbyMmoCharacterPickState(state)
  if type(state) ~= "table" or type(state.screenId) ~= "string" then
    return false
  end
  local id = normalizedScreenId(state.screenId)
  -- RBY MMO registers this screen as RbyMmoCharPick. Keep the stable id as
  -- the primary seam so an unrelated CHARACTER list is never commandeered.
  return id:find("rbymmocharpick", 1, true) ~= nil
    and type(state.items) == "table" and type(state.index) == "number"
end

return function(mod)
  local okStrings, engineStrings = pcall(require, "src.core.Strings")
  local function fallbackStrings(value, ...)
    if select("#", ...) == 0 then return value end
    local ok, formatted = pcall(string.format, value, ...)
    return ok and formatted or value
  end
  local Strings = okStrings and engineStrings or fallbackStrings
  local okTypeChart, typeChart = pcall(require, "src.battle.TypeChart")
  local function displayType(value)
    if okTypeChart and type(typeChart.displayName) == "function" then
      local ok, name = pcall(typeChart.displayName, value)
      if ok and name then return name end
    end
    return safeText(value):gsub("_TYPE$", "")
  end
  local themes = { default = copy(DEFAULT_THEME) }
  local themeChoices = { { "Gen1 Modern", "default" } }
  local fontCache = {}
  local themeScaleCache = setmetatable({}, { __mode = "k" })
  local themePresentationCache = setmetatable({}, { __mode = "k" })
  local responsiveThemeCache = setmetatable({}, { __mode = "k" })
  local dialogueThemeCache = setmetatable({}, { __mode = "k" })
  local imageCache = {}
  local modAssetCache = {}
  local utf8Library
  local glyphFont = mod.ui and mod.ui.Font
  local filteredImages = setmetatable({}, { __mode = "k" })
  local animatedImages = setmetatable({}, { __mode = "k" })
  -- Keep palette state in one runtime object.  LÖVE/LuaJIT limits each
  -- function prototype to 200 local variables; this module's factory is
  -- intentionally large, so feature-local helpers must not consume that
  -- budget just by being declared here.
  local paletteRuntime = {
    imagePalettes = setmetatable({}, { __mode = "k" }),
    paletteShaders = setmetatable({}, { __mode = "k" }),
  }
  function paletteRuntime.load()
    local ok, result = pcall(require, "src.render.PaletteFX")
    return ok and result or nil
  end
  paletteRuntime.fx = paletteRuntime.load()
  paletteRuntime.load = nil
  local spriteAnimationOn = true
  -- render.compose does not receive the Game object.  render.zones caches the
  -- live singleton immediately before it so both hooks inspect one frame.
  local currentGame
  -- Pointer regions are rebuilt from the same presenter geometry used to
  -- draw each frame. That keeps taps and drags aligned with responsive
  -- layouts instead of maintaining a second set of screen-specific boxes.
  local pointerRegions = {}
  local pointerCaptures = {}
  local pointerRuntime = { generation = 0, topOrder = 0, topState = nil }
  local panelOffsetMemory = {}
  local savedPanelOffsets
  local pointerDrawContext
  local hoveredPointer

  -- Several released screens change modes without replacing their stack
  -- state (Party actions, Manager overlays, Link stages, PC box tabs). A
  -- pointer pressed before that transition must not release into the new
  -- mode just because the Lua table identity stayed the same.
  pointerRuntime.stateMode = function(state, kind)
    if type(state) ~= "table" then return tostring(state) end
    if kind == "mod_manager" then
      return table.concat({ safeText(state.screen), tostring(state.optionRows),
        tostring(state.overlay), tostring(state._gen1OptionDescription) }, ":")
    elseif kind == "party" then
      return tostring(state.submenu) .. ":" .. tostring(state.subItems)
    elseif kind == "link" then
      return safeText(state.stage)
    elseif kind == "gen3_box" then
      return safeText(state.mode)
    elseif kind == "summary" then
      return safeText(state.page)
    elseif kind == "dex_entry" then
      return safeText(state.view)
    elseif kind == "move_learn" then
      return tostring(state.selecting) .. ":" .. tostring(state.index)
    elseif kind == "naming" then
      local glyphCount = type(state.glyphs) == "table" and #state.glyphs or 0
      -- Cursor movement is the interaction being tracked here; row/column
      -- must not invalidate a pointer capture between press and release.
      return table.concat({ tostring(state.lower), tostring(glyphCount),
        tostring(state.grid or state.gridRows) }, ":")
    elseif kind == "town_map" then
      return tostring(state.mode) .. ":" .. tostring(state.sel)
    elseif kind == "quarantine_report" then
      return tostring(state.offset)
    elseif kind == "choice" then
      return tostring(state.pending)
    elseif kind == "bag" then
      local bag = type(state.modernBag) == "table" and state.modernBag or nil
      return tostring(state.items) .. ":" .. tostring(bag and
        (bag.pocket or bag.tab or bag.index))
    elseif kind == "menu" or kind == "list" or kind == "shop_list"
        or kind == "pc_list" or kind == "box_root"
        or kind == "box_mon_list" then
      return tostring(state.items)
    elseif kind == "options" or kind == "mod_options" then
      return tostring(state.rows)
    end
    return safeText(state.screenId or kind)
  end

  local function registerPointerRegion(x, y, w, h, metadata)
    if not pointerDrawContext or type(x) ~= "number" or type(y) ~= "number"
        or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
      return
    end
    local region = {
      x = x, y = y, w = w, h = h,
      kind = pointerDrawContext.kind,
      state = pointerDrawContext.state,
      layerKey = pointerDrawContext.layerKey,
      viewport = pointerDrawContext.viewport,
      order = pointerDrawContext.order,
      generation = pointerRuntime.generation,
      stateMode = pointerRuntime.stateMode(pointerDrawContext.state,
        pointerDrawContext.kind),
      modalOwner = pointerDrawContext.modalOwner,
    }
    for key, value in pairs(metadata or {}) do region[key] = value end
    pointerRegions[#pointerRegions + 1] = region
  end

  local function panelOffsets()
    if savedPanelOffsets ~= nil then return savedPanelOffsets end
    local loaded
    if mod.save and type(mod.save.get) == "function" then
      local ok, value = pcall(mod.save.get, mod.save, "panelOffsets", {})
      if ok and type(value) == "table" then loaded = value end
    end
    savedPanelOffsets = loaded or {}
    return savedPanelOffsets
  end

  local function layerOffset(kind, viewport)
    local _, _, width, height = presenterRect(viewport)
    local key = safeText(kind or "screen")
    local stored = panelOffsetMemory[key] or panelOffsets()[key]
    local normalizedX = stored and tonumber(stored.x) or 0
    local normalizedY = stored and tonumber(stored.y) or 0
    normalizedX = clamp(normalizedX, -0.45, 0.45)
    normalizedY = clamp(normalizedY, -0.45, 0.45)
    return normalizedX * width, normalizedY * height
  end

  local function rememberLayerOffset(kind, viewport, x, y, persist)
    local _, _, width, height = presenterRect(viewport)
    local key = safeText(kind or "screen")
    local normalized = {
      x = clamp((tonumber(x) or 0) / math.max(1, width), -0.45, 0.45),
      y = clamp((tonumber(y) or 0) / math.max(1, height), -0.45, 0.45),
    }
    panelOffsetMemory[key] = normalized
    if persist and mod.save and type(mod.save.set) == "function" then
      local values = copy(panelOffsets())
      values[key] = copy(normalized)
      pcall(mod.save.set, mod.save, "panelOffsets", values)
      savedPanelOffsets = values
    end
    return normalized.x * width, normalized.y * height
  end

  local function prepareImage(image)
    if not image or filteredImages[image] then return image end
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest", 0)
    end
    filteredImages[image] = true
    return image
  end

  function paletteRuntime.pokemon(game, species)
    local fx = paletteRuntime.fx
    if not fx or not game or not game.data or not species
        or type(fx.monPal) ~= "function" then
      return nil
    end
    local ok, palette = pcall(fx.monPal, game.data, species)
    return ok and type(palette) == "table" and palette or nil
  end

  function paletteRuntime.world(game)
    local fx = paletteRuntime.fx
    if not fx or not game or not game.data
        or type(fx.pal) ~= "function" then
      return nil
    end
    local overworld = game.overworld
    local map = overworld and overworld.map
    if overworld and map and type(overworld.paletteNameFor) == "function" then
      local okName, name = pcall(overworld.paletteNameFor, overworld, map)
      if okName and name then
        local okPalette, palette = pcall(fx.pal, game.data, name)
        if okPalette and type(palette) == "table" then return palette end
      end
    end
    for _, name in ipairs({ "GREENBAR", "TOWNMAP", "ROUTE" }) do
      local okPalette, palette = pcall(fx.pal, game.data, name)
      if okPalette and type(palette) == "table" then return palette end
    end
    return nil
  end

  function paletteRuntime.setImage(image, palette)
    if image then paletteRuntime.imagePalettes[image] = palette end
    return image
  end

  function paletteRuntime.withImage(image, draw)
    local fx = paletteRuntime.fx
    local palette = image and paletteRuntime.imagePalettes[image]
    if not palette or not fx or type(fx.shader) ~= "function"
        or type(fx.sendColors) ~= "function" then
      return draw()
    end
    local shader = paletteRuntime.paletteShaders[palette]
    if not shader then
      local ok, created = pcall(fx.shader)
      if not ok or not created then return draw() end
      shader = created
      paletteRuntime.paletteShaders[palette] = shader
    end
    local sent = pcall(fx.sendColors, shader, palette)
    if not sent then return draw() end
    local previous
    if type(love.graphics.getShader) == "function" then
      previous = love.graphics.getShader()
    end
    love.graphics.setShader(shader)
    local ok, first, second = pcall(draw)
    love.graphics.setShader(previous)
    if not ok then return false end
    return first, second
  end

  -- A mod's files are mounted under its private virtual root.  A plain
  -- love.graphics.newImage("assets/foo.png") lookup only sees the game's
  -- global read path, so it cannot resolve art shipped beside this entry
  -- point after the mod has been imported.  Prefer the loader-provided asset
  -- helper for theme-owned files, while retaining the ordinary image lookup
  -- for engine and third-party paths.
  local function modAssetImage(relative)
    if type(relative) ~= "string" or relative == "" or not mod.assets or
        type(mod.assets.image) ~= "function" then
      return nil
    end
    if modAssetCache[relative] == false then return nil end
    if modAssetCache[relative] then return modAssetCache[relative] end
    local ok, image = pcall(function()
      return mod.assets:image(relative)
    end)
    if ok and image then
      image = prepareImage(image)
      modAssetCache[relative] = image
      return image
    end
    modAssetCache[relative] = false
    return nil
  end

  local function markAnimated(image, options)
    if not image or type(options) ~= "table" or options.animated ~= true then
      return image
    end
    local requestedFrames = tonumber(options.frames)
    if requestedFrames and requestedFrames < 2 then return image end
    local frames = requestedFrames or 2
    frames = math.max(2, math.floor(frames))
    local axis = options.axis == "horizontal" and "horizontal" or "vertical"
    local okW, width = pcall(function() return image:getWidth() end)
    local okH, height = pcall(function() return image:getHeight() end)
    if not okW or not okH or not width or not height or width <= 0 or height <= 0 then
      return image
    end
    local frameWidth = axis == "horizontal" and width / frames or width
    local frameHeight = axis == "horizontal" and height or height / frames
    if options.detectSheet and axis == "vertical" and height ~= width * frames then
      return image
    end
    if frameWidth < 1 or frameHeight < 1 or
        frameWidth ~= math.floor(frameWidth) or frameHeight ~= math.floor(frameHeight) then
      return image
    end
    local duration = tonumber(options.duration) or 0.45
    duration = math.max(0.05, duration)
    local existing = animatedImages[image]
    if existing and existing.frames == frames and existing.axis == axis and
        existing.duration == duration and
        existing.staticFrame == (options.staticFrame ~= nil and
          clamp(math.floor(tonumber(options.staticFrame) or 0), 0, frames - 1) or nil) then
      return image
    end
    local quads = {}
    if love.graphics and love.graphics.newQuad then
      for frame = 0, frames - 1 do
        local qx = axis == "horizontal" and frame * frameWidth or 0
        local qy = axis == "vertical" and frame * frameHeight or 0
        local ok, quad = pcall(love.graphics.newQuad, qx, qy,
          frameWidth, frameHeight, width, height)
        if ok and quad then quads[frame + 1] = quad end
      end
    end
    animatedImages[image] = {
      frames = frames,
      axis = axis,
      duration = duration,
      frameWidth = frameWidth,
      frameHeight = frameHeight,
      quads = quads,
      -- Vanilla party icons are vertical pose sheets (some are 16x96), but
      -- the original renderer chooses one rest frame rather than playing the
      -- whole sheet as a looping animation. Keep that distinction explicit
      -- so modern rows do not scale the entire sheet into a one-pixel strip.
      staticFrame = options.staticFrame ~= nil and
        clamp(math.floor(tonumber(options.staticFrame) or 0), 0, frames - 1) or nil,
    }
    return image
  end

  local function imageMetrics(image)
    if not image then return nil, nil end
    local okW, width = pcall(function() return image:getWidth() end)
    local okH, height = pcall(function() return image:getHeight() end)
    if not okW or not okH or not width or not height or width <= 0 or height <= 0 then
      return nil, nil
    end
    local animation = animatedImages[image]
    if animation then return animation.frameWidth, animation.frameHeight end
    return width, height
  end

  local function drawImage(image, x, y, rotation, scaleX, scaleY)
    if not image then return false end
    return paletteRuntime.withImage(image, function()
      local animation = animatedImages[image]
      if animation and #animation.quads > 0 then
        local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local frame = animation.staticFrame
        if frame == nil then
          frame = spriteAnimationOn
            and math.floor(now / animation.duration) % animation.frames or 0
        end
        love.graphics.draw(image, animation.quads[frame + 1], x, y,
          rotation or 0, scaleX or 1, scaleY or scaleX or 1)
      else
        love.graphics.draw(image, x, y, rotation or 0,
          scaleX or 1, scaleY or scaleX or 1)
      end
      return true
    end)
  end

  local function drawImageFit(image, x, y, w, h, maxScale)
    local iw, ih = imageMetrics(image)
    if not iw or not ih or w <= 0 or h <= 0 then return false end
    local scale = math.min(w / iw, h / ih)
    if maxScale then scale = math.min(scale, maxScale) end
    scale = math.max(0.01, scale)
    setColor({ 1, 1, 1, 1 })
    return drawImage(image, x + (w - iw * scale) / 2,
      y + (h - ih * scale) / 2, 0, scale, scale)
  end

  local function imageFor(value, options)
    local descriptor
    value, descriptor = imageDescriptor(value)
    if not value then return nil end
    options = merge(descriptor, options or {})
    if type(value) == "userdata" then
      local image = prepareImage(value)
      return markAnimated(image, options)
    end
    if imageCache[value] == false then return nil end
    if imageCache[value] then
      return markAnimated(imageCache[value], options)
    end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, value)
    if ok and image then
      imageCache[value] = prepareImage(image)
      return markAnimated(imageCache[value], options)
    end
    imageCache[value] = false
    return nil
  end

  function paletteRuntime.worldImage(game, value)
    return paletteRuntime.setImage(imageFor(value), paletteRuntime.world(game))
  end

  -- Presenter helpers are declared in stages below; initialize the shared
  -- table before the image helpers attach the RBYMMO portrait adapter.
  mod._gen1ModernSpecialPresenters = mod._gen1ModernSpecialPresenters or {}
  mod._gen1ModernSpecialPresenters._qolLocationBanner =
    mod._gen1ModernSpecialPresenters._qolLocationBanner or {}

  -- RBYMMO exposes the selected avatar as a sprite id.  The host's merged
  -- sprite catalog owns the actual sheet, so keep this adapter independent
  -- of RBYMMO's private Chars module and crop its front-facing 16x16 pose.
  -- The returned descriptor is deliberately shared by the profile, rank,
  -- and Town Map presenters so a sheet is loaded only once.
  function mod._gen1ModernSpecialPresenters.rbyMmoPortrait(game, spriteId)
    if type(spriteId) ~= "string" then return nil end
    local sprites = game and game.data and game.data.sprites
    local record = type(sprites) == "table" and sprites[spriteId] or nil
    local imageValue = type(record) == "table"
      and (record.image or record.path or record.texture) or nil
    if not imageValue then return nil end
    local cache = mod._gen1ModernSpecialPresenters._rbyMmoPortraitCache
    if type(cache) ~= "table" then
      cache = {}
      mod._gen1ModernSpecialPresenters._rbyMmoPortraitCache = cache
    end
    local cacheKey = tostring(imageValue)
    if cache[cacheKey] == false then return nil end
    if cache[cacheKey] then
      paletteRuntime.setImage(cache[cacheKey].image, paletteRuntime.world(game))
      return cache[cacheKey]
    end
    local image = imageFor(imageValue)
    if not image or not love.graphics.newQuad then
      cache[cacheKey] = false
      return nil
    end
    local okW, imageW = pcall(function() return image:getWidth() end)
    local okH, imageH = pcall(function() return image:getHeight() end)
    if not okW or not okH or not imageW or not imageH
        or imageW < 16 or imageH < 16 then
      cache[cacheKey] = false
      return nil
    end
    local okQuad, quad = pcall(love.graphics.newQuad, 0, 0, 16, 16,
      imageW, imageH)
    if not okQuad or not quad then
      cache[cacheKey] = false
      return nil
    end
    cache[cacheKey] = { image = image, quad = quad, width = 16, height = 16 }
    paletteRuntime.setImage(image, paletteRuntime.world(game))
    return cache[cacheKey]
  end

  function mod._gen1ModernSpecialPresenters.drawImageFitRegion(image, x, y,
      w, h)
    if type(image) ~= "table" or not image.image or not image.quad then
      return drawImageFit(image, x, y, w, h)
    end
    local iw, ih = image.width or 16, image.height or 16
    if w <= 0 or h <= 0 or iw <= 0 or ih <= 0 then return false end
    local scale = math.min(w / iw, h / ih)
    setColor({ 1, 1, 1, 1 })
    return paletteRuntime.withImage(image.image, function()
      love.graphics.draw(image.image, image.quad,
        x + (w - iw * scale) / 2, y + (h - ih * scale) / 2,
        0, scale, scale)
      return true
    end)
  end

  local function themeAssetFor(value)
    local image = imageFor(value)
    if image then return image end
    return modAssetImage(value)
  end

  -- PokePCFollowers registers its 6-frame overworld sheets as `frames = 1`
  -- because the engine's icon registry expects one image descriptor.  The
  -- resulting 16x96 sheet must still be cropped to one 16px frame or it
  -- appears as a paper-thin sliver in modern party/box rows. Keep this
  -- compatibility rule path-scoped so unrelated authored tall artwork is
  -- never silently reinterpreted.
  local function knownSheetOptions(value, image, staticFrame)
    local raw = value
    if type(raw) == "table" then
      raw = raw.image or raw.texture or raw.path or raw.asset
    end
    if type(raw) ~= "string" then return nil end
    local path = raw:lower()
    if not path:find("follower_") then return nil end
    local okW, width = pcall(function() return image:getWidth() end)
    local okH, height = pcall(function() return image:getHeight() end)
    if not okW or not okH or not width or not height then return nil end
    local frames, axis
    if width == 16 and height >= 32 and height % 16 == 0 then
      frames, axis = height / 16, "vertical"
    elseif height == 16 and width >= 32 and width % 16 == 0 then
      frames, axis = width / 16, "horizontal"
    end
    if not frames or frames < 2 then return nil end
    return { animated = true, frames = frames, axis = axis,
      staticFrame = staticFrame }
  end

  local function option(key, default)
    local value = mod.options:get(key)
    return value == nil and default or value
  end

  local function drawHint(theme, value, x, y, maxWidth)
    local text = safeText(value)
    local size = theme.typography.caption
    local selected = font(fontCache, size)
    while selected:getWidth(text) > maxWidth and size > 10 do
      size = size - 1
      selected = font(fontCache, size)
    end
    love.graphics.setFont(selected)
    drawText(truncate(text, maxWidth), x, y)
  end

  local function hintHasExtraControls(value)
    local text = safeText(value):upper()
    -- "A select" is an action label, not the physical SELECT button. Leave
    -- standalone SELECT/START tokens intact so pages with extra controls
    -- still advertise them.
    text = text:gsub("%f[%a]A%f[%A]%s+SELECT%f[%A]", "")
    text = text:gsub("%f[%a]A%f[%A]%s+START%f[%A]", "")
    local function hasWord(word)
      return text:match("%f[%a]" .. word .. "%f[%A]") ~= nil
    end
    return hasWord("SELECT") or hasWord("START") or hasWord("ARROWS")
      or text:find("D%-PAD") ~= nil
      or text:find("L/R", 1, true) ~= nil
      or hasWord("LEFT") or hasWord("RIGHT")
      or hasWord("UP") or hasWord("DOWN")
  end

  local function hintIsBasicButtonText(value)
    local text = safeText(value)
    return text:match("%f[%a]A%f[%A]") ~= nil
      or text:match("%f[%a]B%f[%A]") ~= nil
  end

  local function shouldDrawHint(value)
    local text = safeText(value)
    if text == "" then return false end
    if not hintIsBasicButtonText(text) then return true end
    return hintHasExtraControls(text)
  end

  local function drawHintIfUseful(theme, value, x, y, maxWidth)
    if not shouldDrawHint(value) then return false end
    drawHint(theme, value, x, y, maxWidth)
    return true
  end

  local function currentTheme(viewport)
    local usePixelFont = option("pixelFont", false) == true
    fontCache._usePixel = usePixelFont
    local base = themes[option("theme", "gen1_modern_ui:classic_mono")]
      or themes["gen1_modern_ui:classic_mono"] or themes.default
    local uiPercent, uiAuto = resolvedScalePercent(option("uiScale", 100),
      viewport, 75, 150)
    local fontPercent, fontAuto
    if usePixelFont then
      fontPercent = tonumber(normalizedPixelFontScale(
        option("fontScale", 100), true)) or 100
      fontAuto = false
    else
      fontPercent, fontAuto = resolvedScalePercent(option("fontScale", 100),
        viewport, 80, 200)
    end
    local uiScale = uiPercent / 100
    local fontScale = fontPercent / 100
    local density = safeText(option("density", "auto"))
    local frameStyle = safeText(option("frameStyle", "pixel"))
    local frameAsset = safeText(option("frameAsset", "2"))
    if frameAsset ~= "1" and frameAsset ~= "2" and frameAsset ~= "3" then
      frameAsset = "2"
    end
    local frameScale = clamp(math.floor(
      tonumber(option("frameScale", 2)) or 2), 1, 4)
    local dpiX = math.max(1, tonumber(viewport and viewport.dpiX) or 1)
    local dpiY = math.max(1, tonumber(viewport and viewport.dpiY) or 1)
    local panelOpacity = clamp((tonumber(option("panelOpacity", 100)) or 100) / 100, 0, 1)
    local foregroundOpacity = clamp((tonumber(option("foregroundOpacity", 100)) or 100) / 100, 0, 1)
    local key = ("%.3f:%.3f:%s:%s:%s:%s:%s:%.3f:%.3f"):format(uiScale, fontScale,
      uiAuto and "auto" or "manual", fontAuto and "auto" or "manual", density,
      usePixelFont and "pixel" or "system",
      frameStyle .. ":" .. frameAsset .. ":" .. frameScale,
      panelOpacity, foregroundOpacity) .. (":%.4f:%.4f"):format(dpiX, dpiY)
    local bucket = themePresentationCache[base]
    if not bucket then
      bucket = {}
      themePresentationCache[base] = bucket
    end
    if bucket[key] then return bucket[key] end

    local theme = scaledTheme(base, uiScale, fontScale, themeScaleCache)
    theme = copy(theme)
    theme.scale = copy(theme.scale or {})
    theme.scale.auto = uiAuto or fontAuto
    theme.frame = copy(theme.frame or {})
    theme.frame.asset = "assets/pixel_frame" .. frameAsset .. ".png"
    theme.frame.pixelScale = frameScale
    theme.frame.pixelDpiX = dpiX
    theme.frame.pixelDpiY = dpiY
    if frameStyle == "pixel" or frameStyle == "soft" then
      theme.frame.style = frameStyle
    elseif frameStyle == "plain" then
      theme.frame.style = "none"
    end
    if theme.frame.style == "pixel" then
      -- Pixel frames carry their own corners and edge treatment. Do not
      -- combine them with rounded theme chrome or a separate accent strip.
      theme.radii.sm = 0
      theme.radii.md = 0
      theme.radii.lg = 0
    end
    theme.colors = copy(base.colors)
    for _, key in ipairs({ "backdrop", "surface", "surfaceRaised", "selected" }) do
      local color = theme.colors[key]
      if color then color[4] = (color[4] or 1) * panelOpacity end
    end
    for _, key in ipairs({ "text", "textMuted", "onAccent", "accent", "divider" }) do
      local color = theme.colors[key]
      if color then color[4] = (color[4] or 1) * foregroundOpacity end
    end
    bucket[key] = theme
    return theme
  end

  local function dialogueMultiplier()
    local value = option("dialogueTextScale", "inherit")
    if value == nil or value == "inherit" then return 1 end
    return normalizedPercent(value, 100, 100, 200) / 100
  end

  local function dialogueTheme(theme)
    local multiplier = dialogueMultiplier()
    if multiplier == 1 then return theme end
    local key = ("%.3f"):format(multiplier)
    local bucket = dialogueThemeCache[theme]
    if not bucket then
      bucket = {}
      dialogueThemeCache[theme] = bucket
    end
    if bucket[key] then return bucket[key] end
    local out = copy(theme)
    out.typography = copy(theme.typography)
    out.typography.body = (theme.typography.body or 17) * multiplier
    out.typography.caption = (theme.typography.caption or 13) * multiplier
    out.scale = copy(theme.scale or {})
    out.scale.dialogue = multiplier
    bucket[key] = out
    return out
  end

  local function registerTheme(spec)
    assert(type(spec) == "table", "theme must be a table")
    assert(type(spec.id) == "string" and spec.id ~= "",
      "theme.id must be a non-empty string")
    if spec.id ~= "default" and not spec.id:find(":", 1, true) then
      error("theme.id must be namespaced as mod_id:name")
    end
    local theme = merge(DEFAULT_THEME, spec)
    theme.id = spec.id
    themes[spec.id] = theme
    for _, choice in ipairs(themeChoices) do
      if choice[2] == spec.id then
        choice[1] = theme.name or spec.id
        return spec.id
      end
    end
    themeChoices[#themeChoices + 1] = { theme.name or spec.id, spec.id }
    return spec.id
  end

  for _, theme in ipairs(BUILTIN_THEMES) do registerTheme(theme) end

  mod.exports = {
    version = API_VERSION,
    registerTheme = registerTheme,
    themes = themes,
    pixelFontTokens = {
      cellHeight = PLAIN_PIXEL_CELL_HEIGHT,
      rasterStep = PLAIN_PIXEL_RASTER_STEP,
      coordinateStep = 1,
    },
    scaleTokens = {
      uiMin = 0.75, uiMax = 1.50, uiStep = 0.05,
      fontMin = 0.80, fontMax = 2.00, fontStep = 0.05,
      dialogueMin = 1.10, dialogueMax = 2.00, dialogueStep = 0.05,
    },
    getScaleTokens = function(viewport)
      local uiPercent = resolvedScalePercent(option("uiScale", 100),
        viewport, 75, 150)
      local pixelFont = option("pixelFont", false) == true
      local fontPercent = pixelFont
        and tonumber(normalizedPixelFontScale(option("fontScale", 100), true))
        or resolvedScalePercent(option("fontScale", 100), viewport, 80, 200)
      return {
        uiScale = uiPercent / 100,
        fontScale = fontPercent / 100,
        dialogueTextScale = dialogueMultiplier(),
      }
    end,
  }

  local function percentChoices(minimum, maximum, includeAuto)
    local choices = {}
    if includeAuto then choices[#choices + 1] = { "AUTO", "auto" } end
    for percent = minimum, maximum, 5 do
      choices[#choices + 1] = { percent .. "%", tostring(percent) }
    end
    return choices
  end

  local optionSchema = {
    { key = "theme", label = "UI THEME", type = "choice",
      description = "Choose the color, contrast, and panel style used by the modern interface.",
      choices = themeChoices, default = "gen1_modern_ui:classic_mono" },
    { key = "frameStyle", label = "UI FRAME STYLE", type = "choice",
      description = "Choose the panel border treatment. THEME uses the active theme's authored frame.",
      choices = { { "THEME", "theme" }, { "PIXEL", "pixel" },
                  { "SOFT", "soft" }, { "PLAIN", "plain" } }, default = "pixel" },
    { key = "frameAsset", label = "PIXEL FRAME", type = "choice",
      description = "Choose the authored PNG used when PIXEL framing is active.",
      choices = { { "FRAME 1", "1" }, { "FRAME 2", "2" },
                  { "FRAME 3", "3" } }, default = "2" },
    { key = "frameScale", label = "PIXEL FRAME SCALE", type = "choice",
      description = "Scale PNG pixel frames by a whole-number multiplier so their authored pixels remain visible.",
      choices = { { "1X", "1" }, { "2X", "2" }, { "3X", "3" },
                  { "4X", "4" } }, default = "2" },
    { key = "density", label = "UI DENSITY", type = "choice",
      description = "Adjust the spacing and row height used by modern panels.",
      choices = { { "AUTO", "auto" }, { "COMPACT", "compact" },
                  { "COMFORTABLE", "comfortable" } }, default = "auto" },
    { key = "uiScale", label = "UI SCALE", type = "choice",
      description = "Scale panel chrome, row rhythm, icons, and control spacing from 75% to 150%, or choose AUTO for responsive window sizing.",
      choices = percentChoices(75, 150, true), default = "100" },
    { key = "fontScale", label = "FONT SCALE", type = "choice",
      description = "Scale title, body, caption, value, and hint text from 80% to 200%, or choose AUTO for responsive window sizing.",
      choices = FONT_SCALE_CHOICES, default = "100" },
    { key = "pixelFont", label = "PIXEL ART FONT", type = "toggle", default = false,
      description = "Enable the experimental multilingual Plain Pixel font. Its 11-row artwork uses the author's crisp 15-point raster steps, and fractional text origins snap to whole pixels. Older builds and missing glyphs fall back safely to the system font.", },
    { key = "dialogueTextScale", label = "DIALOGUE TEXT SCALE", type = "choice",
      description = "Boost dialogue, choices, quantities, and confirmation prompts for readability.",
      choices = { { "INHERIT", "inherit" }, { "110%", "110" },
                  { "125%", "125" }, { "150%", "150" },
                  { "175%", "175" }, { "200%", "200" } }, default = "inherit" },
    { key = "hideOriginalUi", label = "HIDE ORIGINAL UI", type = "toggle", default = true,
      description = "Hide the classic UI canvas when this mod safely presents the complete screen.", },
    -- The battle presenter remains available for testing, but is opt-in until
    -- its responsive layout is finished.  Keeping the option visible makes
    -- the WIP status explicit without disrupting the game's native battle UI.
    { key = "battleUiWip", label = "BATTLE UI (WIP)", type = "toggle", default = false,
      description = "Show the experimental battle presenter. It is unfinished and off by default.", },
    { key = "layoutStyle", label = "LAYOUT STYLE", type = "choice",
      description = "Choose adaptive floating panels or a full-screen themed presentation.",
      choices = { { "ADAPTIVE", "auto" }, { "FLOATING", "floating" },
                  { "FULL SCREEN", "full" } }, default = "auto" },
    { key = "panelOpacity", label = "PANEL OPACITY", type = "number",
      description = "Set the opacity of panel backgrounds independently from text and borders.",
      min = 0, max = 100, step = 5, default = 100 },
    { key = "foregroundOpacity", label = "TEXT / LINE OPACITY", type = "number",
      description = "Set the opacity of labels, borders, dividers, and accent lines.",
      min = 0, max = 100, step = 5, default = 100 },
    -- Retained as a migration field for saves created by v0.5.0.
    { key = "desktopFloating", label = "DESKTOP FLOATING UI", type = "toggle", default = true,
      description = "Legacy compatibility setting. Use LAYOUT STYLE for new installs.", },
    { key = "startMenuShortcut", label = "PIN UI SETTINGS", type = "toggle", default = false,
      description = "Pin UI SETTINGS directly on the Start menu. When off, it remains under MOD MENUS.", },
    { key = "startMenuModMenus", label = "START MOD MENUS", type = "toggle", default = true,
      description = "Group menu entries added by other mods under one MOD MENUS entry.", },
    { key = "startMenuFastJump", label = "START MENU FAST JUMP", type = "toggle", default = true,
      description = "Let left/right directional presses jump five rows in the Start menu.", },
    { key = "startMenuQuickView", label = "START MENU PARTY VIEW", type = "toggle", default = false,
      description = "Show a compact party summary beside the Start menu in adaptive or floating layouts.", },
    { key = "startMenuInset", label = "SIDE MENU INSET", type = "number", min = 0, max = 50, step = 10, default = 0,
      description = "Move floating side menus toward the center on wide displays. 0 keeps them at the edge; 50 centers them.", },
    -- Keep the richer presentation as the first-run experience. Existing
    -- saves retain a player's explicit choice through the normal option store.
    { key = "minimalUi", label = "MINIMAL UI", type = "toggle", default = false,
      description = "Use a compact presentation with fewer previews and less extra detail.", },
    { key = "pointerUi", label = "TOUCH / CLICK UI (WIP)", type = "toggle", default = false,
      description = "WIP: enable experimental row/grid hover and taps, global mouse A/B, and contextual arrow, SELECT, and START buttons.", },
    { key = "dragPanels", label = "DRAG UI PANELS (WIP)", type = "toggle", default = false,
      description = "WIP: allow experimental touch or mouse dragging to reposition modern panels. Requires TOUCH / CLICK UI; positions are saved per screen family.", },
    { key = "dialogueUi", label = "DIALOGUE UI", type = "toggle", default = true,
      description = "Use modern text boxes, choices, quantities, and confirmation prompts.", },
    { key = "menuUi", label = "MENU UI", type = "toggle", default = true,
      description = "Use modern generic menus such as Start, Bag actions, and shops.", },
    { key = "pokemonUi", label = "POKEMON SCREENS", type = "toggle", default = true,
      description = "Use modern Party, PC, Pokédex, Trainer, Summary, and box screens.", },
    { key = "managerUi", label = "MOD MANAGER UI", type = "toggle", default = true,
      description = "Use the modern presentation for the game's mod manager screens.", },
    { key = "spriteAnimation", label = "SPRITE ANIMATION", type = "toggle", default = true,
      description = "Animate supported two-frame artwork while preserving ratio and nearest filtering.", },
  }
  mod.options:define(optionSchema)

  -- Resolve the presentation policy once per draw path.  The policy is
  -- deliberately independent from the classic UI suppression switch: hiding
  -- the old canvas must never imply that the world should be hidden too.
  --
  -- ADAPTIVE is the compatibility-friendly default. Supported presenters
  -- remain world-visible just like FLOATING on new installs; FULL SCREEN is
  -- the explicit opt-in for a themed backdrop behind the panel. The old
  -- boolean can still preserve a previous FULL treatment during migration.
  local function layoutStyle(viewport)
    local selected = option("layoutStyle", nil)
    if selected == "full" or selected == "floating" then return selected end
    -- Migrate the old boolean only when a user explicitly disabled it. The
    -- new adaptive default is floating on every device, including phones.
    if (selected == nil or selected == "auto")
        and option("desktopFloating", true) == false then return "full" end
    return "floating"
  end

  local function worldVisibleLayout(viewport)
    return layoutStyle(viewport) ~= "full"
  end

  -- Filled screens (Party, Pokédex, Trainer Card, PC, and several third-
  -- party presenters) are opaque engine states. Clearing `uiCanvas` cannot
  -- reveal a world that StateStack never drew, so the input-step sync below
  -- temporarily makes eligible, modernized states transparent to the draw
  -- stack. The original value is restored as soon as FULL SCREEN, classic
  -- fallback, or an unsupported/custom draw becomes active.
  local syncWorldVisibility

  local function drawPresenterBackdrop(theme, viewport)
    -- Every rich presenter (Party, PC, Trainer Card, Pokédex, Bag, and
    -- third-party adapters) comes through this helper.  Keeping the decision
    -- here prevents one screen from accidentally blacking out the world when
    -- the user selected FLOATING or ADAPTIVE.
    -- Panel offsets move the UI surface, not the world/backdrop underneath it.
    local backdropViewport = pointerDrawContext
      and pointerDrawContext.baseViewport or viewport
    if worldVisibleLayout(backdropViewport) then return false end
    local x, y, w, h = fullViewportRect(backdropViewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", x, y, w, h)
    return true
  end

  local function drawModalScrim(theme, viewport)
    local x, y, w, h = presenterRect(viewport)
    -- Nested prompts are still composited over their live parent, but the
    -- parent/world should read as context rather than a second active card.
    setColor({ 0, 0, 0, 0.24 })
    love.graphics.rectangle("fill", x, y, w, h)
  end

  local menuClass = mod.ui and mod.ui.Menu
  local listClass = mod.ui and mod.ui.ListMenu
  local choiceClass = mod.ui and mod.ui.ChoiceBox
  local quantityClass = mod.ui and mod.ui.QuantityBox
  local textBoxClass = mod.ui and mod.ui.TextBox
  local function optionalClass(path)
    local ok, class = pcall(require, path)
    return ok and class or false
  end
  local trainerCardClass = optionalClass("src.ui.TrainerCard")
  local optionsClass = optionalClass("src.ui.OptionsMenu")
  local partyClass = optionalClass("src.ui.PartyMenu")
  local summaryClass = optionalClass("src.ui.SummaryMenu")
  local dexEntryClass = optionalClass("src.ui.DexEntryMenu")
  mod._gen1ModernSpecialClasses = {
    moveLearn = optionalClass("src.ui.MoveLearnMenu"),
    picBox = optionalClass("src.ui.PicBox"),
    naming = optionalClass("src.ui.NamingScreen"),
    townMap = optionalClass("src.ui.TownMap"),
    quarantineReport = optionalClass("src.ui.QuarantineReport"),
  }
  local managerClass = optionalClass("src.mods.ManagerState")
  local titleClass = optionalClass("src.ui.TitleState")
  -- LinkState is a released custom state rather than a Menu/ListMenu.  Keep
  -- it optional so older clients simply fall back to their native link UI.
  local linkClass = optionalClass("src.link.LinkState")
  local runtimeClasses = {
    linkCodeEntry = optionalClass("src.link.CodeEntry"),
    linkNet = optionalClass("src.link.Net"),
    stats = optionalClass("src.pokemon.Stats"),
  }
  -- The released overworld is a singleton class table rather than a normal
  -- instance. Its drawUI method is therefore a legitimate raw field. Capture
  -- the shipped identities once so a replaced world renderer still triggers
  -- the conservative classic fallback. Additive drawUI wrappers (for example
  -- Quality of Life's location banner) are allowed when the world draw itself
  -- remains the released renderer, so they do not disable every menu layered
  -- over the overworld.
  local overworldClass = optionalClass("src.world.OverworldController")

  local function isTitleState(state)
    if not (state and titleClass) then return false end
    -- v0.1.68 can omit the screenId stamp on the title instance while still
    -- exposing the released TitleState class. Accept either identity signal.
    return state.screenId == "TitleState"
      or inherits(classOf(state), titleClass)
  end

  local function isLinkState(state)
    return linkClass and state and inherits(classOf(state), linkClass) or false
  end

  -- TitleState's palette pass honors the Menu `titleUiBox` as a true-color
  -- zone. The native box covers only its left-side tile rectangle, which is
  -- useful for the classic menu but leaves a modern floating menu over a
  -- partly monochrome title. When our title menu is active, expand that zone
  -- to the complete 20x18 title canvas so the artwork behind the panel has a
  -- deliberate, uniform grayscale treatment. The original box is restored as
  -- soon as the menu is popped or either presentation toggle is disabled.
  local function syncTitleMenuPalette(game, state)
    if not (game and state and menuClass
        and inherits(classOf(state), menuClass)
        and type(state.titleUiBox) == "table") then
      return
    end
    local stack = game.stack and game.stack.states
    local titleOnStack = false
    for _, visible in ipairs(type(stack) == "table" and stack or {}) do
      if isTitleState(visible) then titleOnStack = true break end
    end
    local modern = titleOnStack and option("hideOriginalUi", true) ~= false
      and option("menuUi", true) ~= false
    if modern then
      if not state._gen1OriginalTitleUiBox then
        state._gen1OriginalTitleUiBox = copy(state.titleUiBox)
      end
      state.titleUiBox = { 0, 0, 20, 18 }
    elseif state._gen1OriginalTitleUiBox then
      state.titleUiBox = state._gen1OriginalTitleUiBox
      state._gen1OriginalTitleUiBox = nil
    end
  end

  local function openModernOptions(game)
    if not (game and mod.ui and type(mod.ui.push) == "function") then return end
    local manager = mod.ui.push(game, "ManagerState")
    if not manager or type(manager.openOptions) ~= "function" then return manager end
    local manifest = manager.byId and manager.byId[MOD_ID]
    if not manifest and game.mods and type(game.mods.status) == "function" then
      local ok, status = pcall(game.mods.status, game.mods)
      for _, candidate in ipairs(ok and status and status.available or {}) do
        if candidate.id == MOD_ID then manifest = candidate break end
      end
    end
    if manifest then
      -- ManagerState's normal detail -> options path sets currentMod before
      -- opening the option rows.  The Start-menu shortcut jumps directly to
      -- openOptions, so establish that context here as well; otherwise the
      -- category adapter cannot recognize our manifest and the flat legacy
      -- list is rendered instead.
      manager.currentMod = manifest
      manager._gen1ModernOptions = true
      pcall(manager.openOptions, manager, manifest)
    end
    return manager
  end

  -- Start-menu pinning is intentionally keyed by the descriptor's stable id.
  -- A label fallback keeps older third-party rows usable, but authors should
  -- provide ids so renaming a menu does not create a second pin.
  local pinCache
  local function pinKey(item)
    if type(item) ~= "table" then return nil end
    if type(item.id) == "string" and item.id ~= "" then return item.id end
    if type(item.label) == "string" and item.label ~= "" then
      return "label:" .. item.label
    end
    return nil
  end

  local function pinMap()
    local ok, stored = false, nil
    if mod.save and type(mod.save.get) == "function" then
      ok, stored = pcall(mod.save.get, mod.save, "startMenuPins", {})
    end
    -- Read the backing bucket again instead of permanently retaining the
    -- table from the first save slot.  The engine can replace modSave when a
    -- player continues, starts a new game, or hot-reloads a session.
    if ok and type(stored) == "table" then
      pinCache = stored
    elseif type(pinCache) ~= "table" then
      pinCache = {}
    end
    return pinCache
  end

  local function isPinned(item)
    local key = pinKey(item)
    if not key then return false end
    local pins = pinMap()
    if pins[key] ~= nil then return pins[key] == true end
    -- Migrate the old direct-shortcut setting for existing saves. An
    -- explicit pin-map value always wins, so SELECT can unpin it normally.
    return key == "gen1_modern_ui.options"
      and option("startMenuShortcut", false) == true
  end

  local function setPinned(item, pinned)
    local key = pinKey(item)
    if not key then return nil end
    local pins = pinMap()
    pins[key] = pinned == true
    if mod.save and type(mod.save.set) == "function" then
      pcall(mod.save.set, mod.save, "startMenuPins", pins)
    end
    return pins[key]
  end

  local function togglePinned(item)
    local key = pinKey(item)
    if not key then return nil end
    local nextPinned = not isPinned(item)
    return setPinned(item, nextPinned)
  end

  local function decoratePinned(item)
    if type(item) ~= "table" then return item end
    local decorated = {}
    for key, value in pairs(item) do decorated[key] = value end
    decorated._gen1Pinned = true
    return decorated
  end

  local function uiSettingsRow(game)
    return {
      id = "gen1_modern_ui.options",
      label = "UI SETTINGS",
      onSelect = function() openModernOptions(game) end,
    }
  end

  local function openModMenus(game, items)
    if not (game and mod.ui and mod.ui.Menu and type(mod.ui.Menu.new) == "function") then
      return
    end
    local rows = {}
    for _, item in ipairs(items or {}) do rows[#rows + 1] = item end
    local menu = mod.ui.Menu.new(game, rows, {
      tx = 8, ty = 1, tw = 12,
      onCancel = function() mod.ui.push(game, "StartMenu") end,
    })
    menu._gen1ModMenus = true
    game.stack:push(menu)
  end

  -- The grouping is additive and anchored on stable labels. Each descriptor
  -- remains intact, so the source mod still owns its callback and navigation.
  -- UI SETTINGS is treated as one more mod menu: it is grouped by default and
  -- only appears directly when pinned (or when an older save migrated the
  -- former START UI SETTINGS shortcut setting).
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local original = {}
    for _, item in ipairs(items or {}) do original[item] = true end
    local out = next(game, items)
    if type(out) ~= "table" then
      return out
    end

    -- There is no required mod-id field on this hook, so use object identity
    -- for rows appended by another hook. This keeps the grouping opt-in at the
    -- presentation layer without rewriting labels or guessing at vanilla rows.
    local canGroupModMenus = mod.ui and mod.ui.Menu
      and type(mod.ui.Menu.new) == "function"
    local groupingEnabled = option("startMenuModMenus", true) ~= false
      and canGroupModMenus
    local settings = uiSettingsRow(game)
    local added, addedSet, hasOriginal, hasGroup, hasSettings = {}, {}, false,
      false, false
    local settingsItem
    local pinnedDirect = {}
    for _, item in ipairs(out) do
      if type(item) == "table" then
        if original[item] then
          hasOriginal = true
        elseif item.id == "gen1_modern_ui.mod_menus" then
          hasGroup = true
        elseif item.id == "gen1_modern_ui.options" then
          hasSettings = true
          settingsItem = item
        else
          added[#added + 1] = item
          addedSet[item] = true
          if isPinned(item) then pinnedDirect[item] = true end
        end
      end
    end

    if groupingEnabled then
      -- MOD MENUS is the complete inventory of added entries. Pinning changes
      -- only whether a row is also promoted to the root Start menu; it must
      -- never remove the row from this grouped view, otherwise SELECT could
      -- not be used to unpin it later.
      local groupedItems = {}
      for _, item in ipairs(added) do
        groupedItems[#groupedItems + 1] = item
      end
      if not settingsItem or not addedSet[settingsItem] then
        groupedItems[#groupedItems + 1] = settings
      end

      for index = #out, 1, -1 do
        local item = out[index]
        if addedSet[item] and not pinnedDirect[item] then
          table.remove(out, index)
        elseif item.id == "gen1_modern_ui.options" and not isPinned(item) then
          -- Respect an already-present descriptor supplied by another hook,
          -- but keep the unpinned row grouped with the canonical settings.
          table.remove(out, index)
          settingsItem = item
        end
      end
      -- Direct entries are shallow copies so the modern presenter can expose
      -- a stable visual PINNED marker without mutating another mod's row.
      for index, item in ipairs(out) do
        if pinnedDirect[item] or (item.id == "gen1_modern_ui.options"
            and isPinned(item)) then
          out[index] = decoratePinned(item)
        end
      end
      if #groupedItems > 0 and hasOriginal and not hasGroup then
        local grouped = {
          id = "gen1_modern_ui.mod_menus",
          label = Strings("MOD MENUS"),
          onSelect = function() openModMenus(game, groupedItems) end,
        }
        if mod.ui and type(mod.ui.insertBefore) == "function" then
          mod.ui.insertBefore(out, "MODS", grouped)
        else
          table.insert(out, grouped)
        end
      end
    elseif not hasSettings then
      -- Disabling grouping should never strand the modern UI settings. In
      -- that explicit compatibility mode the settings row is direct again.
      hasSettings = true
      if mod.ui and type(mod.ui.insertBefore) == "function" then
        mod.ui.insertBefore(out, "OPTION", settings)
      else
        table.insert(out, 1, settings)
      end
    end

    -- A pinned UI SETTINGS row is direct even while grouping is enabled. This
    -- also migrates the former START UI SETTINGS shortcut setting via isPinned.
    if groupingEnabled and isPinned(settings) and not hasSettings then
      local directSettings = decoratePinned(settings)
      if mod.ui and type(mod.ui.insertBefore) == "function" then
        mod.ui.insertBefore(out, "OPTION", directSettings)
      else
        table.insert(out, 1, directSettings)
      end
    end
    return out
  end, 90)

  -- TouchControls intentionally exposes the same directional button queue as
  -- a keyboard/controller, rather than a mod-specific pointer API.  The
  -- released StartMenu ignores left/right, so consuming a pending horizontal
  -- press here is both touch-friendly and safe for other menu implementations:
  -- only Menu-like states that explicitly close on START are eligible.  A
  -- single press advances five rows and the ordinary up/down/A/B behavior is
  -- left entirely to the engine's state.
  local function pendingPress(input, button)
    for _, queued in ipairs(input and input.pressQueue or {}) do
      if queued == button then return true end
    end
    return false
  end

  local function consumePending(input, buttons)
    local queue = input and input.pressQueue
    if type(queue) ~= "table" then return false end
    local consumed = false
    for index = #queue, 1, -1 do
      if buttons[queue[index]] then
        table.remove(queue, index)
        consumed = true
      end
    end
    return consumed
  end

  local function optionDescription(id)
    if id == "__reset" then
      return "Restore every Gen1 Modern UI setting to its default value."
    end
    if id == "uiScale" then
      local percent, auto = resolvedScalePercent(option("uiScale", 100),
        nil, 75, 150)
      local label = auto and ("AUTO (" .. percent .. "%)") or (percent .. "%")
      return ("Scale panel chrome, rows, icons, borders, and control spacing. Current effective size: %s."):format(
        label)
    end
    if id == "frameScale" then
      local value = clamp(math.floor(tonumber(option("frameScale", 2)) or 2), 1, 4)
      return ("Scale PNG pixel-frame artwork by %dX using nearest-neighbor sampling. Current setting: %dX."):format(
        value, value)
    end
    if id == "frameAsset" then
      local value = safeText(option("frameAsset", "2"))
      if value ~= "1" and value ~= "2" and value ~= "3" then value = "2" end
      return ("Choose the authored pixel-frame border. Current frame: %s."):format(
        value)
    end
    if id == "fontScale" then
      if option("pixelFont", false) == true then
        local scale = (tonumber(normalizedPixelFontScale(
          option("fontScale", 100), true)) or 100) / 100
        return ("Scale Plain Pixel glyphs by %dX. Integer steps keep its authored raster crisp."):format(
          scale)
      end
      local percent, auto = resolvedScalePercent(option("fontScale", 100),
        nil, 80, 200)
      local label = auto and ("AUTO (" .. percent .. "%)") or (percent .. "%")
      return ("Scale readable interface text before measuring and laying out content. Current effective size: %s."):format(
        label)
    end
    if id == "dialogueTextScale" then
      local value = option("dialogueTextScale", "inherit")
      local label = value == "inherit" and "INHERIT" or
        (normalizedPercent(value, 100, 100, 200) .. "%")
      return ("Scale dialogue, choice, quantity, and confirmation text. Current setting: %s."):format(label)
    end
    for _, row in ipairs(optionSchema) do
      if row.key == id then return row.description end
    end
    return nil
  end

  -- The UI settings schema is intentionally kept flat for the engine's
  -- compatibility API.  The modern presenter adds a light category layer on
  -- top: category rows expand/collapse in place, while the original option
  -- descriptors (and their callbacks) remain untouched underneath.
  local OPTION_CATEGORY_ORDER = {
    { id = "appearance", label = "APPEARANCE",
      description = "Theme, layout, density, transparency, and presentation detail." },
    { id = "navigation", label = "NAVIGATION",
      description = "Shortcuts and Start-menu organization." },
    { id = "presenters", label = "PRESENTERS",
      description = "Choose which modern screen families replace the classic UI." },
    { id = "advanced", label = "ADVANCED",
      description = "Compatibility and reset controls." },
  }
  local OPTION_CATEGORY_BY_KEY = {
    theme = "appearance", frameStyle = "appearance", frameAsset = "appearance",
    frameScale = "appearance",
    density = "appearance", layoutStyle = "appearance",
    uiScale = "appearance", fontScale = "appearance", pixelFont = "appearance",
    dialogueTextScale = "appearance",
    panelOpacity = "appearance", foregroundOpacity = "appearance",
    minimalUi = "appearance", pointerUi = "appearance", dragPanels = "appearance",
    hideOriginalUi = "appearance",
    startMenuShortcut = "navigation", startMenuModMenus = "navigation",
    startMenuFastJump = "navigation",
    startMenuQuickView = "navigation", startMenuInset = "navigation",
    dialogueUi = "presenters", menuUi = "presenters", pokemonUi = "presenters",
    managerUi = "presenters", spriteAnimation = "presenters", battleUiWip = "presenters",
    desktopFloating = "advanced", __reset = "advanced",
  }

  local function ensureOptionCategories(state)
    if not (state and state.screen == "options" and state.currentMod
        and state.currentMod.id == MOD_ID and type(state.optionRows) == "table") then
      return
    end
    local pixelEnabled = option("pixelFont", false) == true
    local fontSchema
    for _, descriptor in ipairs(optionSchema) do
      if descriptor.key == "fontScale" then
        fontSchema = descriptor
        break
      end
    end
    if fontSchema then
      fontSchema.label = pixelEnabled and "PIXEL ART FONT SCALE" or "FONT SCALE"
      fontSchema.choices = pixelEnabled
        and PIXEL_FONT_SCALE_CHOICES or FONT_SCALE_CHOICES
      local stored = option("fontScale", 100)
      local normalized = normalizedPixelFontScale(stored, pixelEnabled)
      if tostring(stored) ~= normalized and type(state.setOption) == "function" then
        pcall(state.setOption, state, MOD_ID, "fontScale", normalized)
      end
    end
    local activeRows = state._gen1OptionRowsSource or state.optionRows
    for _, row in ipairs(activeRows or {}) do
      if row and row.id == "fontScale" then
        row.label = pixelEnabled and "PIXEL ART FONT SCALE" or "FONT SCALE"
      end
    end
    for _, row in ipairs(state.optionRows or {}) do
      if row and row.id == "fontScale" then
        row.label = pixelEnabled and "PIXEL ART FONT SCALE" or "FONT SCALE"
      end
    end
    if state._gen1OptionRowsActive == state.optionRows then return end
    local source = state.optionRows
    local groups = {}
    for _, category in ipairs(OPTION_CATEGORY_ORDER) do
      groups[category.id] = { spec = category, rows = {} }
    end
    for _, row in ipairs(source) do
      local id = row and row.id
      -- desktopFloating is a v0.5 migration field. It remains persisted and
      -- resettable, but hiding it from the normal list removes one redundant
      -- row from every install.
      if id ~= "desktopFloating" then
        local category = OPTION_CATEGORY_BY_KEY[id] or "advanced"
        groups[category].rows[#groups[category].rows + 1] = row
      end
    end
    state._gen1OptionRowsSource = source
    state._gen1OptionGroups = groups
    state._gen1OptionExpanded = state._gen1OptionExpanded or {
      appearance = true, navigation = false, presenters = false, advanced = false,
    }
    local function rebuild(preferred)
      local flattened = {}
      for _, category in ipairs(OPTION_CATEGORY_ORDER) do
        local group = groups[category.id]
        if #group.rows > 0 then
          flattened[#flattened + 1] = {
            id = "__category:" .. category.id, category = true,
            label = category.label,
            value = function()
              return state._gen1OptionExpanded[category.id] and "OPEN" or "CLOSED"
            end,
            activate = function()
              state._gen1OptionExpanded[category.id] =
                not state._gen1OptionExpanded[category.id]
              rebuild(state.cursor)
            end,
            description = category.description,
          }
          if state._gen1OptionExpanded[category.id] then
            for _, row in ipairs(group.rows) do flattened[#flattened + 1] = row end
          end
        end
      end
      state.optionRows = flattened
      state._gen1OptionRowsActive = flattened
      state.cursor = clamp(preferred or state.cursor or 1, 1, math.max(1, #flattened))
      state.scroll = 0
    end
    state._gen1RebuildOptionRows = rebuild
    rebuild()
  end

  local function optionState(game)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if not (top and top.screenId == "ManagerState" and top.screen == "options"
        and type(top.optionRows) == "table" and type(top.cursor) == "number") then
      return nil
    end
    return top
  end

  local function updateModMenuPin(game, input)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if not (top and top._gen1ModMenus and type(top.items) == "table"
        and type(top.index) == "number") then return end
    if not pendingPress(input, "select") then return end
    local item = top.items[top.index]
    if togglePinned(item) ~= nil then
      -- Pins are presentation preferences, but mod.save is backed by the
      -- current game save. Flush immediately so a client restart does not
      -- discard a deliberate SELECT pin/unpin action.
      if game.save and type(game.writeSave) == "function" then
        pcall(game.writeSave, game)
      end
      -- SELECT is a presentation-only pin action. Leave A/arrow callbacks to
      -- the engine so every source mod keeps its normal menu behavior.
      consumePending(input, { select = true })
    end
  end

  local function updateOptionHelp(game, input)
    if option("managerUi", true) == false then return end
    local state = optionState(game)
    if not state then return end
    local active = state._gen1OptionDescription
    if active then
      -- A/B/SELECT dismiss the help card without changing the focused option
      -- or leaving the manager. Directional input closes it and remains in the
      -- queue so the manager can move/adjust normally on the same step.
      if consumePending(input, { a = true, b = true, select = true }) then
        state._gen1OptionDescription = nil
        return
      end
      if pendingPress(input, "up") or pendingPress(input, "down")
          or pendingPress(input, "left") or pendingPress(input, "right")
          or pendingPress(input, "start") then
        state._gen1OptionDescription = nil
      end
      return
    end
    if not pendingPress(input, "select") then return end
    local row = state.optionRows[state.cursor]
    local description = row and (optionDescription(row.id) or row.description)
    if not description or description == "" then return end
    state._gen1OptionDescription = {
      title = row.label or row.id,
      text = description,
    }
    consumePending(input, { select = true })
  end

  local function remapChoiceDirections(game)
    local top = game and game.stack and game.stack.top and game.stack:top()
    local input = game and game.input
    if not (choiceClass and top and inherits(classOf(top), choiceClass)
        and input and type(input.pressQueue) == "table") then
      return
    end
    -- The modern presenter can place YES/NO side by side on a wide window,
    -- while ChoiceBox only listens to up/down. Never rewrite a queued button
    -- in place: Input associates each queue edge with its original live
    -- source, so turning a released RIGHT edge into a source-less DOWN edge
    -- can make DOWN remain held until the player presses it physically. Retire
    -- the horizontal edge and enqueue an atomic, source-safe vertical tap.
    for index = #input.pressQueue, 1, -1 do
      local button = input.pressQueue[index]
      local mapped = button == "left" and "up"
        or (button == "right" and "down" or nil)
      if mapped and mod.input and type(mod.input.tap) == "function" then
        table.remove(input.pressQueue, index)
        pcall(mod.input.tap, mod.input, game, mapped)
      end
    end
  end

  mod.hooks:wrap("input.step", function(next, game, dt)
    remapChoiceDirections(game)
    local result = next(game, dt)
    if not game then
      return result
    end
    if syncWorldVisibility then syncWorldVisibility(game) end
    local topAfter = game.stack and game.stack.top and game.stack:top()
    ensureOptionCategories(topAfter)
    local input = game.input
    updateModMenuPin(game, input)
    updateOptionHelp(game, input)
    if option("startMenuFastJump", true) == false then return result end
    local top = game.stack and game.stack.top and game.stack:top()
    if not (input and top and top.screenId == "StartMenu"
        and type(top.items) == "table"
        and top.startCloses == true and type(top.index) == "number"
        and #top.items > 0) then
      return result
    end
    local left = pendingPress(input, "left")
    local right = pendingPress(input, "right")
    if left == right then return result end
    local count = #top.items
    local delta = right and 5 or -5
    top.index = ((top.index - 1 + delta) % count) + 1
    if type(top.clampScroll) == "function" then top:clampScroll() end
    if game.save then game.save.startMenuIndex = top.index end
    return result
  end, 80)

  local isBoxRoot
  local function boxPokemonList(state)
    if not (state and inherits(classOf(state), listClass)
        and type(state.items) == "table") then return nil end
    local game = state.game
    local root
    local stack = game and game.stack and game.stack.states
    if type(stack) == "table" then
      for index = #stack, 1, -1 do
        if stack[index] == state then
          for lower = index - 1, 1, -1 do
            if isBoxRoot(stack[lower]) then root = stack[lower] break end
          end
          break
        end
      end
    end
    if not root then return nil end
    local source, action
    if root.index == 2 then
      source, action = game and game.save and game.save.party, "DEPOSIT"
    elseif root.index == 1 then
      local save = game and game.save
      source, action = save and save.boxes and save.boxes[save.currentBox or 1], "WITHDRAW"
    elseif root.index == 3 then
      local save = game and game.save
      source, action = save and save.boxes and save.boxes[save.currentBox or 1], "RELEASE"
    end
    if type(source) ~= "table" or not action or #state.items ~= #source then return nil end
    for index, item in ipairs(state.items) do
      if type(source[index]) ~= "table" or source[index].species == nil
          or type(item) ~= "table"
          or (action ~= "RELEASE" and item.value ~= index) then return nil end
    end
    return source, action
  end

  isBoxRoot = function(state)
    if not (state and state.screenId == "BoxMenu"
        and inherits(classOf(state), menuClass)
        and type(state.items) == "table" and state.noSound == true
        and #state.items >= 5) then return false end
    for index = 1, 4 do
      local item = state.items[index]
      if type(item) ~= "table" or item.keepOpen ~= true
          or type(item.onSelect) ~= "function" then return false end
    end
    local exit = state.items[#state.items]
    return type(exit) == "table" and exit.keepOpen ~= true
  end

  local function isGen3Box(state)
    return (state.screenId == "Gen3Box" or state.screenId == "Gen3BoxMenu")
      and (state.mode == "box" or state.mode == "party")
      and type(state.row) == "number" and type(state.col) == "number"
  end

  local function isUsefulDexEntry(state)
    return state.screenId == "DexEntryMenu" and type(state.vanilla) == "table"
      and type(state.def) == "table"
      and (state.view == "data" or state.view == "stats" or state.view == "moves")
  end

  -- Several popular mods expose their settings as registered screen factories
  -- built on the released `src.ui.OptionRows` helper. Those screens are plain
  -- tables (not an OptionsMenu subclass), so class-only detection would leave
  -- their native 160x144 renderer visible. Keep the adapter deliberately
  -- semantic: an OptionRows screen has a stable screen id, live row table,
  -- cursor, update method, and draw method. The suffix rule covers future
  -- option screen names while the Quality of Life id is retained for that
  -- mod's established public contract.
  local function isOptionRowsScreen(state)
    if type(state) ~= "table" or type(state.screenId) ~= "string"
        or type(state.rows) ~= "table" or type(state.index) ~= "number"
        or type(state.update) ~= "function" or type(state.draw) ~= "function" then
      return false
    end
    local id = state.screenId
    if id == "OptionsMenu" then return false end
    return id == "RunModeOptions" or id == "ShinyPokemonOptions"
      or id == "QualityOfLife" or id:match("Options$") ~= nil
      or id:match("Settings$") ~= nil
  end

  local function isNamingState(state)
    if type(state) ~= "table" then
      return false
    end
    local id = type(state.screenId) == "string"
      and state.screenId:lower() or ""
    -- Name Rater itself pushes the engine's ordinary NamingScreen. Mods such
    -- as RBY MMO wrap that instance's draw method to adjust the naming field,
    -- which must remain a modeled naming screen rather than falling through
    -- the unknown-draw safety guard. Keep the class check narrow so arbitrary
    -- screens named "NamingScreen" cannot opt into this presenter by id alone.
    local namingClass = mod._gen1ModernSpecialClasses
      and mod._gen1ModernSpecialClasses.naming
    local isBuiltinNaming = namingClass
      and inherits(classOf(state), namingClass)
    if not isBuiltinNaming and not id:find("namerater", 1, true)
        and not id:find("nickname", 1, true) then
      return false
    end
    local hasGrid = type(state.grid) == "function"
      or type(state.grid) == "table" or type(state.gridRows) == "table"
    return hasGrid and type(state.glyphs) == "table"
      and type(state.row) == "number" and type(state.col) == "number"
  end

  local function kindFor(state)
    if not state then return nil end
    local id = state.screenId
    local class = classOf(state)
    -- RBY MMO's profile and leaderboard are plain local classes rather than
    -- engine widgets. Their stable screen ids and public payloads are the
    -- compatibility seam; do not rely on the mod's private class identity.
    if isRbyMmoProfileState(state) then return "rby_mmo_profile" end
    if isRbyMmoRankState(state) then return "rby_mmo_rank" end
    if isRbyMmoCharacterPickState(state) then return "rby_mmo_char_pick" end
    if isLinkState(state) then return "link" end
    if state.phase and state.queue and
        (state.kind == "wild" or state.kind == "trainer" or
         state.kind == "link" or state.enemy or state.player) then
      return "battle"
    end
    -- ManagerState is part of the released in-game mod manager.  It is not a
    -- Menu/ListMenu subclass, so identify it by its public screen id rather
    -- than by reaching into the engine's class hierarchy.
    if id == "ManagerState" and managerClass
        and inherits(class, managerClass) then return "mod_manager" end
    if isGen3Box(state) then return "gen3_box" end
    if id == "DexEntryMenu" and ((dexEntryClass and inherits(class, dexEntryClass))
        or isUsefulDexEntry(state)) then return "dex_entry" end
    if id == "MoveLearnMenu" and mod._gen1ModernSpecialClasses.moveLearn
        and inherits(class, mod._gen1ModernSpecialClasses.moveLearn) then
      return "move_learn"
    end
    if id == "PicBox" and mod._gen1ModernSpecialClasses.picBox
        and inherits(class, mod._gen1ModernSpecialClasses.picBox) then
      return "pic_box"
    end
    if mod._gen1ModernSpecialClasses.naming
        and inherits(class, mod._gen1ModernSpecialClasses.naming) then
      return "naming"
    end
    if isNamingState(state) then return "naming" end
    if id == "TownMap" and mod._gen1ModernSpecialClasses.townMap
        and inherits(class, mod._gen1ModernSpecialClasses.townMap) then
      return "town_map"
    end
    if id == "QuarantineReport"
        and mod._gen1ModernSpecialClasses.quarantineReport
        and inherits(class, mod._gen1ModernSpecialClasses.quarantineReport) then
      return "quarantine_report"
    end
    if isOptionRowsScreen(state) then return "mod_options" end
    if id == "TrainerCard" and trainerCardClass
        and inherits(class, trainerCardClass) then return "trainer_card" end
    if isBoxRoot(state) then return "box_root" end
    if boxPokemonList(state) then return "box_mon_list" end
    if id == "PokedexMenu" and inherits(class, listClass) then return "pokedex" end
    if id == "BagMenu" and inherits(class, listClass) then return "bag" end
    if id == "OptionsMenu" and optionsClass
        and inherits(class, optionsClass) then return "options" end
    -- Several released callers (Day Care, Name Rater, scripted pickers) push
    -- PartyMenu directly rather than through Screens, so the stable class is
    -- authoritative even when no screenId was stamped.
    if partyClass and inherits(class, partyClass) then return "party" end
    if id == "SummaryMenu" and summaryClass
        and inherits(class, summaryClass) then return "summary" end
    if inherits(class, textBoxClass) then return "text" end
    if inherits(class, choiceClass) then return "choice" end
    if inherits(class, quantityClass) then return "quantity" end
    if inherits(class, listClass) and state.dialogue then return "shop_list" end
    if inherits(class, listClass) and state.messageBox then return "pc_list" end
    if inherits(class, listClass) then return "list" end
    if inherits(class, menuClass) then return "menu" end
    return nil
  end

  -- Keep availability checks in one place so render.compose only removes the
  -- classic UI on frames that render.hud will actually replace.  In
  -- particular, the unfinished battle presenter remains opt-in and never
  -- blanks the stable native battle UI by default.
  local function presenterEnabled(kind)
    if kind == "battle" then return option("battleUiWip", false) == true end
    if kind == "link" then return option("menuUi", true) ~= false end
    if kind == "text" or kind == "choice" or kind == "quantity" then
      return option("dialogueUi", true) ~= false
    end
    if kind == "mod_manager" or kind == "mod_options" then
      return option("managerUi", true) ~= false
    end
    if kind == "gen3_box" or kind == "dex_entry" or kind == "summary"
        or kind == "party" or kind == "trainer_card" or kind == "pokedex"
        or kind == "box_mon_list" then
      return option("pokemonUi", true) ~= false
    end
    if kind == "move_learn" or kind == "pic_box" or kind == "naming"
        or kind == "town_map" or kind == "quarantine_report"
        or kind == "rby_mmo_profile" or kind == "rby_mmo_rank"
        or kind == "rby_mmo_char_pick" then
      return option("menuUi", true) ~= false
    end
    return option("menuUi", true) ~= false
  end

  -- Some mods keep a standard Menu/ListMenu state but replace `draw` on the
  -- instance. That custom pipeline may contain tabs, badges, previews, or
  -- prompts which cannot be recovered from ordinary rows, so suppressing it
  -- would silently lose UI. Only audited structural adapters are exceptions:
  -- Modern Bag delegates to live ListMenu rows, Useful Dex exposes its vanilla
  -- entry plus public page model, and Gen 3 Box exposes its complete grid model.
  local function customDrawModeled(state, kind)
    if kind == "link" and isLinkState(state) then return true end
    if kind == "mod_options" and isOptionRowsScreen(state) then return true end
    if kind == "bag" and state.screenId == "BagMenu"
        and type(state.modernBag) == "table" then return true end
    if kind == "gen3_box" and isGen3Box(state) then return true end
    if kind == "dex_entry" and isUsefulDexEntry(state) then return true end
    if kind == "naming" and isNamingState(state) then return true end
    if kind == "rby_mmo_profile" or kind == "rby_mmo_rank"
        or kind == "rby_mmo_char_pick" then return true end
    if kind == "box_root" and isBoxRoot(state) then return true end
    if kind == "menu" and state._gen1ModernTitleMenu == true
        and rawget(state, "draw") == state._gen1ModernTitleDraw then return true end
    return false
  end

  local function expectedClass(kind)
    if kind == "link" then return linkClass end
    if kind == "menu" then return menuClass end
    if kind == "box_root" then return menuClass end
    if kind == "list" or kind == "pokedex" or kind == "bag"
        or kind == "shop_list" or kind == "pc_list"
        or kind == "box_mon_list" then return listClass end
    if kind == "choice" then return choiceClass end
    if kind == "quantity" then return quantityClass end
    if kind == "text" then return textBoxClass end
    if kind == "options" then return optionsClass end
    if kind == "party" then return partyClass end
    if kind == "summary" then return summaryClass end
    if kind == "trainer_card" then return trainerCardClass end
    if kind == "dex_entry" then return dexEntryClass end
    if kind == "move_learn" then return mod._gen1ModernSpecialClasses.moveLearn end
    if kind == "pic_box" then return mod._gen1ModernSpecialClasses.picBox end
    if kind == "naming" then return mod._gen1ModernSpecialClasses.naming end
    if kind == "town_map" then return mod._gen1ModernSpecialClasses.townMap end
    if kind == "quarantine_report" then
      return mod._gen1ModernSpecialClasses.quarantineReport
    end
    if kind == "rby_mmo_profile" or kind == "rby_mmo_rank" then return nil end
    if kind == "rby_mmo_char_pick" then return listClass end
    if kind == "mod_manager" then return managerClass end
    return nil
  end

  local function resolvedDraw(class, seen)
    if type(class) ~= "table" then return nil end
    seen = seen or {}
    if seen[class] then return nil end
    seen[class] = true
    local draw = rawget(class, "draw")
    if type(draw) == "function" then return draw end
    local mt = getmetatable(class)
    return mt and resolvedDraw(mt.__index, seen) or nil
  end

  local function hasUnknownDrawOverride(state, kind)
    if customDrawModeled(state, kind) then return false end
    local ownDraw = rawget(state, "draw")
    local class = classOf(state)
    if type(ownDraw) == "function" and ownDraw ~= resolvedDraw(class) then
      return true
    end
    local expected = expectedClass(kind)
    local expectedDraw = resolvedDraw(expected)
    local actualDraw = resolvedDraw(class)
    return expectedDraw ~= nil and actualDraw ~= nil and actualDraw ~= expectedDraw
  end

  -- Rich screens are allowed to come from other screen factories.  The
  -- released SummaryMenu stores its live record in `mon`, while a few older
  -- callers and third-party wrappers use `pokemon`, `target`, or keep the
  -- vanilla record underneath the wrapper.  Resolve those shapes in one
  -- place so floating presentation never clears the classic canvas before
  -- the replacement has enough data to draw.
  local function pokemonDefinition(game, species)
    local data = game and game.data
    local pokemon = data and data.pokemon
    return pokemon and species and pokemon[species] or nil
  end

  local function summaryPokemon(state)
    if type(state) ~= "table" then return nil end
    local candidates = { state.mon, state.pokemon, state.target, state.poke }
    if type(state.vanilla) == "table" then
      candidates[#candidates + 1] = state.vanilla.mon
      candidates[#candidates + 1] = state.vanilla.pokemon
    end
    for _, candidate in ipairs(candidates) do
      if type(candidate) == "table" and candidate.species ~= nil then
        return candidate
      end
    end
    return nil
  end

  local function dexDefinition(game, state)
    if type(state) ~= "table" then return nil end
    local def = state.def
    if type(def) ~= "table" and type(state.vanilla) == "table" then
      def = state.vanilla.def
    end
    if type(def) == "table" and (def.id or def.name or def.dex
        or def.dexEntry) then
      return def
    end
    local species = state.species or state.speciesId
    if type(species) == "table" then
      species = species.species or species.id
    end
    if not species and type(state.vanilla) == "table" then
      species = state.vanilla.species or state.vanilla.speciesId
    end
    return pokemonDefinition(game, species)
  end

  local function presenterReady(game, state, kind)
    if kind == "summary" then
      local mon = summaryPokemon(state)
      return mon ~= nil and pokemonDefinition(game, mon.species) ~= nil
    elseif kind == "dex_entry" then
      return dexDefinition(game, state) ~= nil
    end
    return true
  end

  local function syncStateVisibility(game, state)
    if not (game and state and state ~= game.overworld) then return end
    local kind = kindFor(state)
    local revealWorld = worldVisibleLayout(nil)
      and option("hideOriginalUi", true) ~= false
    local eligible = revealWorld and kind and presenterEnabled(kind)
      and not state.capture and not hasUnknownDrawOverride(state, kind)
    if eligible then
      if state._gen1ModernOpaqueManaged == nil then
        state._gen1ModernOpaqueManaged = true
        state._gen1ModernOriginalOpaque = state.isOpaque == true
      end
      state.isOpaque = false
    elseif state._gen1ModernOpaqueManaged then
      state.isOpaque = state._gen1ModernOriginalOpaque == true
      state._gen1ModernOpaqueManaged = nil
      state._gen1ModernOriginalOpaque = nil
    end
  end

  syncWorldVisibility = function(game)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return end
    for _, state in ipairs(states) do
      if state and state ~= game.overworld then
        syncStateVisibility(game, state)
      end
    end
  end

  -- Quality of Life's location banner is intentionally a visual-only overlay
  -- attached to the overworld. Read the same saved option it reads, but keep
  -- the presenter independent of that mod's private banner state. This lets
  -- Modern UI replace the classic Font.drawBox without requiring QOL to
  -- expose an implementation detail as a public API.
  function mod._gen1ModernSpecialPresenters.qolLocationDuration(game)
    local options = game and game.save and game.save.options
    local modOptions = options and options.modOptions
    local bucket = type(modOptions) == "table"
      and modOptions.quality_of_life or nil
    local value = type(bucket) == "table"
      and bucket.qol_location_banners or nil
    if value == true then return 2 end
    value = tonumber(value)
    return value and value > 0 and value or 0
  end

  function mod._gen1ModernSpecialPresenters.qolLocationName(game, mapId, map)
    local field = game and game.data and game.data.field
    local townMap = field and field.townMap
    local locations = townMap and (townMap.locations or townMap)
    local entry = type(locations) == "table" and locations[mapId] or nil
    local name = type(entry) == "table" and (entry.name or entry.label) or nil
    local maps = game and game.data and game.data.maps
    local def = map and map.def or (maps and maps[mapId])
    if not name and def and type(def.label) == "string" then
      name = def.label:gsub("(%l)(%u)", "%1 %2")
    end
    return safeText(name or tostring(mapId):gsub("_", " ")):upper()
  end

  function mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(
      game, suppress)
    local world = mod.world
    local ow = world and type(world.overworld) == "function"
      and world:overworld() or nil
    local overlay = ow and rawget(ow, "__qolLocationBannerOverlay") or nil
    if type(overlay) ~= "table" then return end
    local savedKey = "__gen1ModernQolOriginalDraw"
    if suppress then
      if rawget(overlay, savedKey) == nil then
        rawset(overlay, savedKey, rawget(overlay, "draw"))
      end
      overlay.draw = function() end
    else
      local original = rawget(overlay, savedKey)
      if original ~= nil then
        overlay.draw = original
        rawset(overlay, savedKey, nil)
      end
    end
  end

  if mod.events and type(mod.events.on) == "function" then
    -- QOL uses the default priority. Register after it so its overlay has
    -- already been created; we can then mirror its setting and neutralize the
    -- classic draw function before the first modern frame is presented.
    mod.events:on("map.entered", function(event)
      local game = currentGame or (mod.world and mod.world.game)
      local banner = mod._gen1ModernSpecialPresenters._qolLocationBanner
      local world = mod.world
      local ow = world and type(world.overworld) == "function"
        and world:overworld() or nil
      banner.name, banner.expiresAt, banner.overworld = nil, nil, nil
      if not game or not ow or type(event) ~= "table" or not event.mapId
          or event.mapId == "ROCK_TUNNEL_POKECENTER" then
        mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(game, false)
        return
      end
      local duration =
        mod._gen1ModernSpecialPresenters.qolLocationDuration(game)
      local overlay = rawget(ow, "__qolLocationBannerOverlay")
      if duration <= 0 or type(overlay) ~= "table" then
        mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(game, false)
        return
      end
      local name = mod._gen1ModernSpecialPresenters.qolLocationName(
        game, event.mapId, event.map)
      -- Match QOL's small de-duplication guard: a same-name map transition
      -- does not flash a second banner until a different location is seen.
      if banner.lastName == name then
        mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(game, false)
        return
      end
      banner.lastName = name
      banner.name = name
      banner.expiresAt = (love.timer and love.timer.getTime
        and love.timer.getTime() or 0) + duration
      banner.overworld = ow
      local modernWorld = option("menuUi", true) ~= false
        and option("hideOriginalUi", true) ~= false
      mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(
        game, modernWorld)
    end, -10)
  end

  -- `input.step` runs before the active state's update.  Screens pushed by a
  -- button press therefore used to remain opaque until the *next* fixed step,
  -- which is exactly the frame where Summary/DexEntry could be composited
  -- without their world pass.  The screen lifecycle event fires immediately
  -- after StateStack:push and is safe to use when the host exposes events;
  -- the per-step sweep remains the compatibility fallback for older clients.
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("screen.pushed", function(payload)
      local state = payload and payload.state
      local game = state and state.game or currentGame
      syncTitleMenuPalette(game, state)
      syncStateVisibility(game, state)
    end, 90)
    mod.events:on("screen.popped", function(payload)
      local state = payload and payload.state
      if state and state._gen1OriginalTitleUiBox then
        state.titleUiBox = state._gen1OriginalTitleUiBox
        state._gen1OriginalTitleUiBox = nil
      end
    end, 90)
  end

  -- Build the complete visible UI stack bottom-up. `ctx.uiCanvas` contains
  -- every one of these states, so it is safe to clear only when each visible
  -- draw owner has a modern presenter. This lets a Bag -> action -> quantity
  -- or TextBox -> YES/NO chain become one coherent modern composition while
  -- any unknown/custom layer immediately falls back to the classic canvas.
  local function presentationStack(game)
    if not game then return {}, false end
    local stack = game.stack
    local states = stack and stack.states
    if type(states) ~= "table" or type(stack.visibleBase) ~= "function" then
      return {}, false
    end
    local ok, base = pcall(stack.visibleBase, stack)
    if not ok or type(base) ~= "number" then return {}, false end
    local layers = {}
    local preserveUiCanvas = false
    local topState = states[#states]
    local optionRowsTop = isOptionRowsScreen(topState)
    for index = base, #states do
      local visible = states[index]
      -- The overworld is rendered independently on the world canvas. States
      -- without a draw function likewise contribute nothing to uiCanvas.
      if visible == game.overworld then
        local emote = visible and visible.emote
        if (emote and emote.pikaPic)
            or ((tonumber(visible and visible.poisonFlash) or 0) > 0) then
          return {}, false
        end
        if overworldClass then
          if visible ~= overworldClass
              or rawget(visible, "draw") ~= rawget(overworldClass, "draw")
              or type(rawget(visible, "drawUI")) ~= "function" then
            return {}, false
          end
        elseif type(rawget(visible, "drawUI")) == "function" then
          return {}, false
        end
      elseif isTitleState(visible) then
        -- The title art and its Menu share uiCanvas. The title-menu draw is
        -- suppressed independently by ui.state.decorate below, so preserve
        -- the canvas here rather than erasing the logo and title Pokémon.
        preserveUiCanvas = true
      elseif type(visible and visible.draw) == "function" then
        local kind = kindFor(visible)
        if not kind or not presenterEnabled(kind) or visible.capture
            or hasUnknownDrawOverride(visible, kind)
            or not presenterReady(game, visible, kind) then
          return {}, false
        end
        -- A registered OptionRows screen is pushed above the manager state
        -- that opened it. The custom screen is the complete visible surface;
        -- retaining the manager beneath it would duplicate panels in floating
        -- layouts. The manager remains in the engine stack for input/back
        -- navigation, but is omitted from this visual composition.
        if not (kind == "mod_manager" and optionRowsTop) then
          layers[#layers + 1] = { state = visible, kind = kind, index = index }
        end
      end
    end
    return layers, #layers > 0, not preserveUiCanvas
  end

  function mod._gen1ModernSpecialPresenters.shouldHideNativeOptions(game,
      state)
    if not (game and state and option("hideOriginalUi", true) ~= false
        and option("menuUi", true) ~= false) then
      return false
    end
    local layers, complete = presentationStack(game)
    if not complete then return false end
    for _, layer in ipairs(layers) do
      if layer.state == state then return true end
    end
    return false
  end

  -- Current released clients do not expose a state-decoration hook; the
  -- title menu is drawn directly through Menu:draw. Wrap that class method
  -- once and use the same stack proof as render.compose. This is restricted
  -- to TitleState's published titleUiBox marker, so ordinary menus and
  -- third-party Menu subclasses retain their native renderer.
  if menuClass and type(rawget(menuClass, "draw")) == "function"
      and not rawget(menuClass, "_gen1ModernTitleClassDraw") then
    local nativeMenuDraw = rawget(menuClass, "draw")
    menuClass._gen1ModernTitleClassDraw = true
    menuClass.draw = function(self, ...)
      local game = self.game or currentGame
      syncTitleMenuPalette(game, self)
      if type(self.titleUiBox) == "table"
          and option("hideOriginalUi", true) ~= false
          and option("menuUi", true) ~= false then
        local stack = game and game.stack and game.stack.states
        local titleOnStack = false
        for _, visible in ipairs(type(stack) == "table" and stack or {}) do
          if isTitleState(visible) then titleOnStack = true break end
        end
        if titleOnStack then
          local layers, complete = presentationStack(game)
          if complete then
            for _, layer in ipairs(layers) do
              if layer.state == self then return end
            end
          end
        end
      end
      return nativeMenuDraw(self, ...)
    end
  end

  -- TitleState draws its artwork and its native Menu into the same 160x144
  -- UI canvas. Unlike ordinary screens, clearing that canvas would erase the
  -- logo and title Pokémon too. The title Menu decorator suppresses the
  -- duplicate native rows while the modern presenter owns the complete stack,
  -- so the shared artwork canvas must remain untouched.
  local function optionValue(game, row)
    if not row or row.value == nil then return "" end
    if type(row.value) ~= "function" then return safeText(row.value) end
    local ok, value = pcall(row.value, game)
    return ok and safeText(value) or ""
  end

  local managerRowsFor
  local iconFor
  local spriteFor
  local spriteResolver

  local function rowsFor(game, state, kind)
    local rows = {}
    local selected = state.index or 1
    local scroll = state.scroll or 0
    local title = titleFor(Strings, state, kind)
    local footer

    if kind == "mod_manager" then
      return managerRowsFor(game, state)
    elseif kind == "options" or kind == "mod_options" then
      for _, row in ipairs(state.rows or {}) do
        rows[#rows + 1] = {
          label = row.label, value = optionValue(game, row),
          enabled = row.enabled, image = imageCandidate(row), source = row,
        }
      end
      rows[#rows + 1] = { label = Strings("CANCEL"), source = false }
    elseif kind == "party" then
      if state.submenu and type(state.subItems) == "table" then
        selected = state.subIndex or 1
        title = Strings("POKéMON ACTIONS")
        for _, item in ipairs(state.subItems) do
          rows[#rows + 1] = { label = item.label or "", source = item }
        end
        if #rows == 0 then rows[1] = { label = Strings("CANCEL") } end
        return rows, selected, scroll, title, nil
      end
      local party = state.party or (game.save and game.save.party) or {}
      for _, mon in ipairs(party) do
        local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
        local name = mon.nickname or (def and def.name) or mon.species or "POKéMON"
        local hp = mon.stats and mon.stats.hp and ("%d/%d"):format(mon.hp or 0, mon.stats.hp)
          or ""
        local value
        if state.tmhm and state.tmhm.move then
          local canLearn = false
          for _, move in ipairs(def and def.tmhm or {}) do
            if move == state.tmhm.move then canLearn = true break end
          end
          value = canLearn and Strings("ABLE") or Strings("NOT ABLE")
        else
          value = (mon.level and ("Lv %d"):format(mon.level) or "")
            .. (hp ~= "" and ("  " .. hp) or "")
            .. (mon.hp and mon.hp <= 0 and "  FNT" or mon.status and ("  " .. mon.status) or "")
        end
        rows[#rows + 1] = {
          label = name,
          value = value,
          image = imageCandidate(mon),
          source = mon,
        }
      end
      if #rows == 0 then
        rows[1] = { label = Strings("No POKéMON!"), enabled = false }
      end
    elseif kind == "box_mon_list" then
      local mons, action = boxPokemonList(state)
      for _, mon in ipairs(mons or {}) do
        local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
        local name = mon.nickname or (def and def.name) or mon.species or "POKéMON"
        local maxHP = mon.stats and mon.stats.hp
        local hp = maxHP and ("%d/%d"):format(mon.hp or 0, maxHP) or ""
        rows[#rows + 1] = {
          label = name,
          value = (mon.level and ("Lv %d"):format(mon.level) or "")
            .. (hp ~= "" and ("  " .. hp) or ""),
          image = imageCandidate(mon), source = mon,
        }
      end
      if #rows == 0 then
        rows[1] = { label = Strings("No POKéMON!"), enabled = false }
      end
      footer = action == "RELEASE" and Strings("A  release    B  back")
        or action and Strings("A  %s / stats    B  back", action:lower()) or nil
    elseif kind == "summary" then
      return nil, selected, scroll, title, nil
    elseif kind == "choice" then
      rows = {
        { label = Strings("YES") }, { label = Strings("NO") },
      }
    elseif kind == "quantity" then
      local qty = math.floor(state.qty or 1)
      local value = ("×%02d"):format(qty)
      if state.unitPrice then value = value .. ("  ¥%d"):format(qty * state.unitPrice) end
      rows = { { label = Strings("QUANTITY"), value = value } }
    else
      for index, item in ipairs(state.items or {}) do
        local value = item.right ~= nil and item.right or item.displayValue
        local pinned = isPinned(item)
        if pinned then
          local renderedValue = safeText(value)
          value = renderedValue ~= "" and (renderedValue .. "  PINNED") or "PINNED"
        end
        rows[#rows + 1] = {
          label = item.label or item.name or "",
          -- `value` is commonly an opaque callback payload, item ID, or table.
          -- Only render fields that a row explicitly declares as presentation
          -- metadata; this keeps third-party list rows from leaking internals.
          value = value,
          enabled = item.enabled,
          marker = item.ball or state.swapIndex == index or state.hollowIndex == index
            or pinned,
          image = imageCandidate(item),
          source = item,
        }
      end
      if #rows == 0 then
        rows[1] = { label = Strings("Nothing here."), enabled = false }
      end
      footer = state.footer
      if state._gen1ModMenus then
        footer = Strings("A  open   SELECT  pin/unpin   B  back")
      end
      if not footer and state.money then
        local ok, money = pcall(state.money)
        if ok and money ~= nil then footer = ("¥%d"):format(money) end
      end
    end
    if kind == "party" and state.bottomMessage then
      local ok, message = pcall(function() return state:bottomMessage() end)
      if ok then footer = message end
    end
    return rows, selected, scroll, title, footer
  end

  -- ManagerState intentionally exposes its screen as ordinary data and row
  -- methods.  Build a read-only presentation from those fields so the
  -- manager keeps owning all keyboard/controller input and callbacks.  This
  -- also means rows supplied by other mods (and newly installed mods) appear
  -- without an adapter for each author.
  managerRowsFor = function(game, state)
    local rawRows = {}
    local screen = state.screen or "list"
    if screen == "options" then
      ensureOptionCategories(state)
      rawRows = state.optionRows or {}
    elseif type(state.rowsForScreen) == "function" then
      local ok, result = pcall(state.rowsForScreen, state)
      if ok and type(result) == "table" then rawRows = result end
    end

    local rows = {}
    local function rowValue(raw)
      if raw.value == nil then return "" end
      if type(raw.value) ~= "function" then return safeText(raw.value) end
      local ok, value = pcall(raw.value, game)
      return ok and safeText(value) or ""
    end
    local function staged(mod)
      if not mod or type(state.isStaged) ~= "function" then return false end
      local ok, value = pcall(state.isStaged, state, mod)
      return ok and value and true or false
    end

    for _, raw in ipairs(rawRows) do
      local row = { label = raw.label or "", source = raw,
                    enabled = raw.enabled, header = raw.header,
                    category = raw.category, id = raw.id,
                    mod = raw.mod, profile = raw.profile,
                    image = imageCandidate(raw) or imageCandidate(raw.mod) }
      if raw.mod then
        local mod = raw.mod
        local status = mod.enabled and "ON" or "OFF"
        if staged(mod) then status = status .. "  *" end
        if mod.error then status = status .. "  !" end
        row.value = status .. (mod.version and ("  v" .. mod.version) or "")
        row.marker = raw.glyph and raw.glyph ~= " " or false
        if raw.glyph and raw.glyph ~= " " then
          row.label = ("%s  %s"):format(raw.glyph, row.label)
        end
      elseif raw.profile then
        local opts = state.optionsTable and state:optionsTable() or {}
        row.value = opts.activeProfile == raw.profile.name and "ACTIVE" or ""
      elseif raw.inert then
        row.enabled = false
        row.value = rowValue(raw)
      else
        row.value = rowValue(raw)
      end
      rows[#rows + 1] = row
    end
    if #rows == 0 then
      rows[1] = { label = Strings("Nothing here."), enabled = false }
    end

    local selected = state.cursor or 1
    local scroll = state.scroll or 0
    -- ManagerState uses one-based list scroll, while the modern presenter
    -- uses a zero-based offset.  Options already uses zero-based scrolling.
    if screen ~= "options" then scroll = math.max(0, scroll - 1) end

    local title = Strings("MOD MANAGER")
    if screen == "detail" and state.currentMod then
      title = safeText(state.currentMod.name or state.currentMod.id)
    elseif screen == "options" and state.currentMod then
      title = state.currentMod.id == MOD_ID and Strings("UI SETTINGS")
        or (Strings("OPTIONS") .. "  " ..
          safeText(state.currentMod.name or state.currentMod.id))
    elseif screen == "permissions" then
      title = Strings("PERMISSIONS")
    elseif screen == "errors" then
      title = Strings("ERRORS")
    elseif screen == "apply" then
      title = Strings("PENDING CHANGES")
    end
    return rows, selected, scroll, title
  end

  local function contentWidthFor(theme, rows, title, footer, minWidth, maxWidth)
    local bodyFont = font(fontCache, theme.typography.body)
    local titleFont = font(fontCache, theme.typography.title)
    local widest = math.max(titleFont:getWidth(safeText(title)),
      bodyFont:getWidth(safeText(footer)))
    for _, row in ipairs(rows or {}) do
      if type(row) == "table" and not row.header then
        local label = bodyFont:getWidth(safeText(row.label))
        local value = bodyFont:getWidth(safeText(row.value))
        -- Leave room for an optional icon and a small value column without
        -- forcing every short menu to inherit the width of a rich screen.
        widest = math.max(widest, label + (value > 0 and value + theme.spacing.md or 0)
          + (row.image and 46 or 0))
      end
    end
    return clamp(widest + theme.spacing.lg * 2 + theme.spacing.md,
      minWidth or 1, maxWidth or widest + theme.spacing.lg * 2)
  end

  local function densityFactor()
    local density = option("density", "auto")
    return density == "compact" and 0.88
      or density == "comfortable" and 1.12 or 1
  end

  local function minimumRowHeight(theme)
    local body = font(fontCache, theme.typography.body)
    local caption = font(fontCache, theme.typography.caption)
    local textMinimum = math.max(textHeight(body), textHeight(caption))
      + theme.spacing.sm * 1.6
    return math.max(theme.density.rowHeight * densityFactor(), textMinimum)
  end

  local function themeMetric(theme, name, fallback)
    local metrics = theme.metrics or {}
    return metrics[name] or fallback
  end

  local function readabilityScale(theme)
    local scale = theme.scale or {}
    return math.max(tonumber(scale.ui) or 1, tonumber(scale.font) or 1)
  end

  local function scaledPanelWidth(theme, baseWidth)
    return baseWidth * readabilityScale(theme)
  end

  local function panelMaxWidth(theme, fallback)
    local density = theme.density or {}
    local uiScale = tonumber(theme.scale and theme.scale.ui) or 1
    local authoredMax = (tonumber(density.panelMax) or fallback) / uiScale
    return scaledPanelWidth(theme, math.max(authoredMax, fallback))
  end

  -- Rich presenters historically used fixed height ceilings. That worked at
  -- the reference viewport, but it made larger UI/font scales consume more
  -- rows without giving the screen any additional vertical room. Scale the
  -- ceiling with the largest readability control, then let each presenter
  -- clamp it to the safe viewport below.
  local function scaledPanelHeight(theme, landscape, landscapeBase, portraitBase)
    local base = landscape and landscapeBase or portraitBase
    return base * readabilityScale(theme)
  end

  local function layoutFor(viewport, theme, kind, rows, title, footerText)
    rows = rows or {}
    local rowCount = #rows
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing or {}
    local scale = densityFactor()
    local landscape = w > h * 1.2
    local desktopFloat = worldVisibleLayout(viewport)
    -- Touch controls can consume a large fraction of a phone's short
    -- landscape height. Use a denser outer rhythm there, then fit rows to the
    -- available presenter height before falling back to scrolling.
    local gutter = (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale
    local titleHeight = textHeight(font(fontCache, theme.typography.title))
    local captionHeight = textHeight(font(fontCache, theme.typography.caption))
    local header = safeText(title) ~= "" and (titleHeight +
      (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale)
      or (spacing.md or 13) * scale
    local footer = (landscape and (spacing.sm or 9) or (spacing.lg or 18)) * scale
      + captionHeight
    local rowHeight = minimumRowHeight(theme)
    local panelMax = panelMaxWidth(theme, 780)
    if landscape then
      -- Keep content-sized panels compact, but leave enough room for long
      -- localized labels and option values before truncating them.
      panelMax = math.min(panelMax, w * 0.72)
    end
    if landscape and rowCount > 0 then
      local fitHeight = (h - gutter * 2 - header - footer) / rowCount
      -- Keep text comfortably legible, but do not reserve desktop-sized rows
      -- when the touch-safe landscape viewport is short.
      local minLandscapeRow = textHeight(font(fontCache, theme.typography.body))
        + (spacing.sm or 9) * 1.6
      rowHeight = math.min(rowHeight, math.max(minLandscapeRow, fitHeight))
    end
    local minPanelW = landscape and 220 or 250
    local measuredW = contentWidthFor(theme, rows, title, footerText,
      minPanelW, panelMax)
    local panelW = math.min(w - gutter * 2, measuredW)
    local bodyFont = font(fontCache, theme.typography.body)
    local rowTextWidth = math.max(1, panelW - spacing.lg * 2)
    local wrapRows = false
    for _, row in ipairs(rows) do
      if type(row) == "table" and not row.header and not row.category then
        local labelWidth = bodyFont:getWidth(safeText(row.label))
        local valueWidth = bodyFont:getWidth(safeText(row.value))
        local valueColumn = valueWidth > 0 and math.min(valueWidth,
          math.max(1, rowTextWidth * 0.52)) or 0
        if labelWidth + valueColumn + (valueColumn > 0 and spacing.md or 0)
            > rowTextWidth then
          wrapRows = true
          break
        end
      end
    end
    if wrapRows then
      rowHeight = math.max(rowHeight,
        textHeight(bodyFont) * 2 + spacing.sm * 2)
    end
    local navigationMenu = kind == "menu" or kind == "box_root"
    -- The title screen is a composed artwork canvas rather than ordinary
    -- in-game navigation. Keep its modern menu centered in both axes so it
    -- does not inherit the wide-window side-dock used by the overworld menu.
    local titleMenu = kind == "menu" and pointerDrawContext
      and pointerDrawContext.state
      and type(pointerDrawContext.state.titleUiBox) == "table"
    local sidePanel = desktopFloat and landscape and navigationMenu
      and rowCount > 0 and not titleMenu
    if navigationMenu or kind == "choice" or kind == "quantity" then
      -- Short action/confirmation menus should read as focused cards in
      -- landscape, not as banners stretched across the whole phone. Longer
      -- list/options screens keep the wider panel calculated from the theme
      -- max.
      panelW = math.min(panelW, (w > h * 1.2) and w * 0.70
        or scaledPanelWidth(theme, 560))
    end
    if sidePanel then
      -- The ordinary in-game menu is navigational chrome, not a modal data
      -- screen. On wide windows keep it narrow and dock it to the edge so the
      -- world remains visible instead of dimming behind a centered card.
      local preferredSideW = clamp(w * 0.30, 220, 460)
      panelW = math.min(w - gutter * 2, math.max(panelW, preferredSideW))
      gutter = spacing.lg or 18
      header = safeText(title) ~= "" and (titleHeight
        + (spacing.md or 13)) or (spacing.md or 13)
      footer = (spacing.sm or 9) + captionHeight
      rowHeight = math.min(rowHeight, math.max(
        textHeight(font(fontCache, theme.typography.body)) + (spacing.sm or 9) * 1.6,
        (h - gutter * 2 - header - footer) / math.max(1, rowCount)))
    end
    panelW = math.max(1, panelW)
    local visible = math.max(1, math.floor((h - gutter * 2 - header - footer) / rowHeight))
    visible = math.min(visible, math.max(1, rowCount))
    local contentH = header + footer + visible * rowHeight
    local panelH = math.min(h - gutter * 2, contentH)
    panelH = math.max(1, panelH)
    local sidePanelInset = clamp(tonumber(option("startMenuInset", 0)) or 0,
      0, 50) / 50
    local sidePanelX = x + w - panelW - gutter
    if sidePanel then
      -- At 0% retain the established edge dock. At 50% use the available
      -- horizontal travel to place the side menu at the viewport center;
      -- intermediate 10% steps are useful on ultrawide displays without
      -- changing the layout contract for ordinary windows.
      local centerTravel = math.max(0, (w - panelW) / 2 - gutter)
      sidePanelX = sidePanelX - centerTravel * sidePanelInset
    end
    return {
      x = sidePanel and sidePanelX or x + (w - panelW) / 2,
      y = y + (h - panelH) / 2,
      w = panelW, h = panelH, rowHeight = rowHeight,
      header = header, footer = footer, visible = visible,
      wrapRows = wrapRows,
      safeX = x, safeY = y, safeW = w, safeH = h,
      radius = theme.radii and theme.radii.md or 16,
      sidePanel = sidePanel,
    }
  end

  local function drawPanelFrame(theme, x, y, w, h, radius, fillColor)
    -- Register the visible panel before choosing a frame style so plain and
    -- theme-framed panels remain draggable through the same hit region.
    if pointerDrawContext and not pointerDrawContext.primaryPanel then
      pointerDrawContext.primaryPanel = { x = x, y = y, w = w, h = h }
    end
    local panelAction = ({
      text = "a", summary = "a", dex_entry = "a", trainer_card = "a",
    })[pointerDrawContext and pointerDrawContext.kind]
    registerPointerRegion(x, y, w, h, {
      role = "panel", dragHandle = true, action = panelAction,
    })
    local frame = theme.frame or {}
    local style = frame.style or "pixel"
    if style == "none" then return end
    local colors = theme.colors
    local width = math.max(1, tonumber(frame.width) or
      themeMetric(theme, "border", 3))
    local inset = math.max(0, tonumber(frame.inset) or 0)
    local margin = math.max(0, tonumber(frame.margin) or 0)
    local shadow = math.max(0, tonumber(frame.shadow) or 0)
    local lineRadius = style == "soft" and (radius or theme.radii.md) or 0
    local fx, fy = x - margin + inset, y - margin + inset
    local fw = math.max(1, w + margin * 2 - inset * 2)
    local fh = math.max(1, h + margin * 2 - inset * 2)
    local frameColor = colors.frame or colors.accent
    local shadowColor = colors.frameShadow or colors.divider

    setColor(frameColor)
    love.graphics.setLineWidth(width)
    local asset = style == "pixel" and frame.asset and themeAssetFor(frame.asset)
    if asset then
      local iw, ih = imageMetrics(asset)
      if iw and ih then
      -- Pixel artwork must meet the same integer grid in which it was
      -- authored. The viewport can be fractional (window DPI and responsive
      -- centering both contribute), so snap the panel to physical pixels and
      -- make its size a whole number of source-pixel blocks. Derive the
      -- complete nine-slice rectangle from those snapped edges; independently
      -- rounding the right/bottom used to create the visible one-pixel drift.
      local pixelScale = clamp(math.floor(
        tonumber(frame.pixelScale) or 1), 1, 4)
      local dpiX = math.max(1, tonumber(frame.pixelDpiX) or 1)
      local dpiY = math.max(1, tonumber(frame.pixelDpiY) or 1)
      local function snapPixel(value, dpi, quantum)
        local q = math.max(1, quantum or 1)
        return math.floor(value * dpi / q + 0.5) * q / dpi
      end
      local panelX, panelY = snapPixel(x, dpiX, 1), snapPixel(y, dpiY, 1)
      local panelRight = snapPixel(x + w, dpiX, 1)
      local panelBottom = snapPixel(y + h, dpiY, 1)
      local panelW = math.max(pixelScale / dpiX,
        snapPixel(panelRight - panelX, dpiX, pixelScale))
      local panelH = math.max(pixelScale / dpiY,
        snapPixel(panelBottom - panelY, dpiY, pixelScale))
      local sourceSlice = math.max(1, math.min(
        math.floor(tonumber(frame.slice) or 24),
        math.floor(math.min(iw or 1, ih or 1) / 2)))
      local edgeScaleX, edgeScaleY = pixelScale / dpiX, pixelScale / dpiY
      local maxCornerSource = math.max(1, math.min(sourceSlice,
        math.floor(panelW / (2 * edgeScaleX) + 0.0001),
        math.floor(panelH / (2 * edgeScaleY) + 0.0001)))
      sourceSlice = maxCornerSource
      local destinationCornerX = sourceSlice * edgeScaleX
      local destinationCornerY = sourceSlice * edgeScaleY
      -- The frame image reserves a seven-source-pixel outer inset by
      -- contract. Expand by that inset rather than the whole slice, so the
      -- image edge sits just outside the UI while its authored border lands
      -- snugly at the panel boundary. Keep the old pixelBorder spelling as a
      -- harmless compatibility alias for early unreleased theme experiments.
      local sourceInset = math.max(0, math.min(
        tonumber(frame.pixelInset) or tonumber(frame.pixelBorder) or 7,
        sourceSlice))
      local frameMarginX = sourceInset * edgeScaleX
      local frameMarginY = sourceInset * edgeScaleY
      local assetFx, assetFy = panelX - frameMarginX, panelY - frameMarginY
      local assetFw = math.max(pixelScale / dpiX,
        panelW + frameMarginX * 2)
      local assetFh = math.max(pixelScale / dpiY,
        panelH + frameMarginY * 2)
      -- Keep the authored transparent inset outside the UI surface. The
      -- panel itself is already snapped to the visible content boundary; if
      -- we fill the full image bounds here, the transparent outer ornament
      -- becomes a visibly oversized container on the right and bottom.
      setColor(fillColor or colors.surface)
      love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
      -- Asset-backed pixel frames own their shadow/edge treatment. A second
      -- shifted rectangle would necessarily protrude only on the right and
      -- bottom, making the container look asymmetrical.
      local function drawSlice(sx, sy, sw, sh, dx, dy, dw, dh)
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0 then return end
        local ok, quad = pcall(love.graphics.newQuad, sx, sy, sw, sh, iw, ih)
        if not ok or not quad then return end
        love.graphics.draw(asset, quad, dx, dy, 0, dw / sw, dh / sh)
      end
      local function drawTiledX(sx, sy, sw, sh, dx, dy, dw, dh)
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0 or edgeScaleX <= 0 then return end
        local tileWidth = sw * edgeScaleX
        local offset = 0
        while offset < dw - 0.001 do
          -- Never crop a fractional source pixel for the final tile. The
          -- destination width is snapped to this same block grid above, so a
          -- whole source-pixel tile always fits exactly.
          local sourceWidth = math.min(sw, math.floor(
            (dw - offset) / edgeScaleX + 0.0001))
          if sourceWidth < 1 then break end
          local drawWidth = sourceWidth * edgeScaleX
          drawSlice(sx, sy, sourceWidth, sh, dx + offset, dy,
            drawWidth, dh)
          offset = offset + drawWidth
        end
      end
      local function drawTiledY(sx, sy, sw, sh, dx, dy, dw, dh)
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0 or edgeScaleY <= 0 then return end
        local tileHeight = sh * edgeScaleY
        local offset = 0
        while offset < dh - 0.001 do
          local sourceHeight = math.min(sh, math.floor(
            (dh - offset) / edgeScaleY + 0.0001))
          if sourceHeight < 1 then break end
          local drawHeight = sourceHeight * edgeScaleY
          drawSlice(sx, sy, sw, sourceHeight, dx, dy + offset,
            dw, drawHeight)
          offset = offset + drawHeight
        end
      end
      local centerSourceW, centerSourceH = iw - sourceSlice * 2,
        ih - sourceSlice * 2
      local centerDestW, centerDestH = assetFw - destinationCornerX * 2,
        assetFh - destinationCornerY * 2
      setColor({ 1, 1, 1, 1 })
      drawSlice(0, 0, sourceSlice, sourceSlice,
        assetFx, assetFy, destinationCornerX, destinationCornerY)
      drawTiledX(sourceSlice, 0, centerSourceW, sourceSlice,
        assetFx + destinationCornerX, assetFy, centerDestW, destinationCornerY)
      drawSlice(iw - sourceSlice, 0, sourceSlice, sourceSlice,
        assetFx + assetFw - destinationCornerX, assetFy,
        destinationCornerX, destinationCornerY)
      drawTiledY(0, sourceSlice, sourceSlice, centerSourceH,
        assetFx, assetFy + destinationCornerY, destinationCornerX, centerDestH)
      drawSlice(sourceSlice, sourceSlice, centerSourceW, centerSourceH,
        assetFx + destinationCornerX, assetFy + destinationCornerY,
        centerDestW, centerDestH)
      drawTiledY(iw - sourceSlice, sourceSlice, sourceSlice, centerSourceH,
        assetFx + assetFw - destinationCornerX, assetFy + destinationCornerY,
        destinationCornerX, centerDestH)
      drawSlice(0, ih - sourceSlice, sourceSlice, sourceSlice,
        assetFx, assetFy + assetFh - destinationCornerY,
        destinationCornerX, destinationCornerY)
      drawTiledX(sourceSlice, ih - sourceSlice, centerSourceW, sourceSlice,
        assetFx + destinationCornerX, assetFy + assetFh - destinationCornerY,
        centerDestW, destinationCornerY)
      drawSlice(iw - sourceSlice, ih - sourceSlice, sourceSlice, sourceSlice,
        assetFx + assetFw - destinationCornerX,
        assetFy + assetFh - destinationCornerY,
        destinationCornerX, destinationCornerY)
      love.graphics.setLineWidth(1)
      return
      end
    end
    if shadow > 0 then
      setColor(shadowColor)
      love.graphics.setLineWidth(width)
      love.graphics.rectangle("line", fx + shadow, fy + shadow,
        math.max(1, fw), math.max(1, fh), lineRadius)
    end
    setColor(frameColor)
    love.graphics.rectangle("line", fx, fy, fw, fh, lineRadius)
    love.graphics.setLineWidth(1)

    if style ~= "pixel" then return end
    local step = math.max(width * 2, tonumber(frame.step) or width * 2)
    local mark = math.max(width, math.min(tonumber(frame.corner) or step,
      math.min(fw, fh) / 4))
    local notch = math.min(mark * 0.58, step)
    local function corner(cx, cy, sx, sy)
      love.graphics.rectangle("fill", cx, cy, mark, width)
      love.graphics.rectangle("fill", cx, cy, width, mark)
      love.graphics.rectangle("fill", cx + sx * notch,
        cy + sy * notch, width, width)
    end
    corner(fx - width * 0.5, fy - width * 0.5, 1, 1)
    corner(fx + fw - mark + width * 0.5, fy - width * 0.5, -1, 1)
    corner(fx - width * 0.5, fy + fh - mark + width * 0.5, 1, -1)
    corner(fx + fw - mark + width * 0.5,
      fy + fh - mark + width * 0.5, -1, -1)
  end

  local function drawPanelAccent(theme, x, y, w, radius, height)
    if theme.frame and theme.frame.style == "pixel" then return end
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", x, y, w, height or
      themeMetric(theme, "border", 4), radius, radius, 0, 0)
  end

  local function drawHeader(theme, layout, title, fillColor)
    if layout.h then
      drawPanelFrame(theme, layout.x, layout.y, layout.w, layout.h,
        layout.radius, fillColor)
    end
    if safeText(title) == "" then return end
    local colors = theme.colors
    drawPanelAccent(theme, layout.x, layout.y, layout.w, layout.radius)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    setColor(colors.text)
    drawText(truncate(title, layout.w - theme.spacing.lg * 2),
      layout.x + theme.spacing.lg,
      layout.y + theme.spacing.md)
  end

  local function drawRows(theme, layout, rows, selected, scroll, game)
    local colors = theme.colors
    local pointerState = pointerDrawContext and pointerDrawContext.state
    local pointerScrollable = pointerState and type(pointerState.scroll) == "number"
      and layout.visible < #rows
    local pointerScrollBias = pointerDrawContext
      and pointerDrawContext.kind == "mod_manager"
      and pointerState and pointerState.screen ~= "options" and 1 or 0
    local selectableIndices = {}
    for index, row in ipairs(rows) do
      if row and not row.header and row.enabled ~= false then
        selectableIndices[#selectableIndices + 1] = index
      end
    end
    if layout.horizontalChoice then
      local gap = theme.spacing.sm
      local width = math.max(1, (layout.w - theme.spacing.lg * 2
        - gap * math.max(0, #rows - 1)) / math.max(1, #rows))
      local bodyFont = font(fontCache, theme.typography.body)
      for index, row in ipairs(rows) do
        local rx = layout.x + theme.spacing.lg + (index - 1) * (width + gap)
        local ry = layout.y + layout.header
        local rowSelected = index == selected and row.enabled ~= false
        registerPointerRegion(rx, ry, width, layout.rowHeight - 4, {
          rowIndex = index, interactive = row and row.enabled ~= false,
          dragHandle = false, rowCount = #rows,
          selectionField = layout.pointerSelectionField,
          selectableIndices = selectableIndices,
        })
        setColor(rowSelected and colors.selected or colors.surfaceRaised)
        love.graphics.rectangle("fill", rx, ry, width, layout.rowHeight - 4,
          theme.radii.sm or 8)
        setColor(rowSelected and colors.text or colors.textMuted)
        love.graphics.setFont(bodyFont)
        local label = truncate(safeText(row.label), width)
        drawText(label, rx + (width - bodyFont:getWidth(label)) / 2,
          ry + (layout.rowHeight - textHeight(bodyFont)) / 2)
      end
      return
    end
    love.graphics.setFont(font(fontCache, theme.typography.body))
    for slot = 1, layout.visible do
      local index = scroll + slot
      local row = rows[index]
      if not row then break end
      local ry = layout.y + layout.header + (slot - 1) * layout.rowHeight
      local rowSelected = index == selected and row.enabled ~= false
      registerPointerRegion(layout.x + theme.spacing.sm, ry,
        layout.w - theme.spacing.sm * 2, layout.rowHeight - 4, {
          rowIndex = index,
          interactive = not row.header and row.enabled ~= false,
          dragHandle = false,
          selectionField = layout.pointerSelectionField,
          scrollable = pointerScrollable,
          scrollValue = scroll,
          scrollBias = pointerScrollBias,
          visibleCount = layout.visible,
          rowCount = #rows,
          rowHeight = layout.rowHeight,
          selectableIndices = selectableIndices,
        })
      if row.category then
        setColor(rowSelected and colors.selected or colors.surfaceRaised)
        love.graphics.rectangle("fill", layout.x + theme.spacing.sm, ry,
          layout.w - theme.spacing.sm * 2, layout.rowHeight - 4,
          theme.radii.sm or 8)
        setColor(rowSelected and colors.text or colors.accent)
        local categoryFont = font(fontCache, theme.typography.body)
        local valueFont = font(fontCache, theme.typography.caption)
        local value = optionValue(game, row)
        local valueWidth = value ~= "" and valueFont:getWidth(value) or 0
        local labelWidth = math.max(20, layout.w - theme.spacing.lg * 2
          - (valueWidth > 0 and valueWidth + theme.spacing.md or 0))
        love.graphics.setFont(categoryFont)
        drawText(truncate(row.label, labelWidth, categoryFont),
          layout.x + theme.spacing.lg,
          ry + (layout.rowHeight - textHeight(categoryFont)) / 2)
        if value ~= "" then
          love.graphics.setFont(valueFont)
          setColor(rowSelected and colors.text or colors.textMuted)
          drawText(truncate(value, math.max(20, layout.w - theme.spacing.lg * 2), valueFont),
            layout.x + layout.w - theme.spacing.lg - valueFont:getWidth(
              truncate(value, math.max(20, layout.w - theme.spacing.lg * 2), valueFont)),
            ry + (layout.rowHeight - textHeight(valueFont)) / 2)
        end
      elseif row.header then
        setColor(colors.textMuted)
        love.graphics.setFont(font(fontCache, theme.typography.caption))
        drawText(safeText(row.label):upper(),
          layout.x + theme.spacing.lg, ry + (layout.rowHeight -
            textHeight(love.graphics.getFont())) / 2)
        love.graphics.setFont(font(fontCache, theme.typography.body))
      elseif rowSelected then
        setColor(colors.selected)
        love.graphics.rectangle("fill", layout.x + theme.spacing.sm, ry,
          layout.w - theme.spacing.sm * 2, layout.rowHeight - 4,
          theme.radii.sm or 8)
      end
      if row.category then
        -- Category rows are actionable (A expands/collapses), so their value
        -- is rendered above and they do not receive icon/value columns.
      elseif row.header then
        -- Category headings in the mod list are deliberately inert; the
        -- vanilla cursor skips them and the presenter only changes their
        -- typography, not their position in the live row array.
        setColor(colors.divider)
        love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
          ry + layout.rowHeight - themeMetric(theme, "divider", 1),
          layout.w - theme.spacing.lg * 2, themeMetric(theme, "divider", 1))
      else
        setColor(row.enabled == false and colors.textMuted or colors.text)
      end
      local icon = not row.header and not row.category and imageFor(row.image) or nil
      if icon then
        paletteRuntime.setImage(icon, row.source and row.source.species
          and paletteRuntime.pokemon(game, row.source.species) or nil)
      end
      if not icon and not row.header and game and row.source and
          row.source.species and iconFor then
        local ok, resolved = pcall(iconFor, game, row.source)
        if ok then icon = resolved end
      end
      local iconSize = icon and math.max(18, math.min(38, layout.rowHeight - 12)) or 0
      local textX = layout.x + theme.spacing.lg +
        (icon and iconSize + theme.spacing.sm or 0)
      if icon then
        local iw, ih = imageMetrics(icon)
        if iw and ih then
          local scale = math.min(iconSize / iw, iconSize / ih)
          setColor({ 1, 1, 1, 1 })
          drawImage(icon,
            layout.x + theme.spacing.lg + (iconSize - iw * scale) / 2,
            ry + (layout.rowHeight - ih * scale) / 2, 0, scale, scale)
          setColor(row.enabled == false and colors.textMuted or colors.text)
        end
      end
      local label = safeText(row.label)
      local value = safeText(row.value)
      local bodyFont = font(fontCache, theme.typography.body)
      local textAvail = math.max(1, layout.x + layout.w - theme.spacing.lg - textX)
      local gap = theme.spacing.md
      local labelWidth = bodyFont:getWidth(label)
      local valueWidth = value ~= "" and bodyFont:getWidth(value) or 0
      -- Preserve the complete value whenever the measured panel can hold it.
      -- Only fall back to a bounded right column when label + value cannot
      -- coexist; this prevents short panels from clipping values such as
      -- "Classic Mono" while still guaranteeing that the two columns never
      -- overlap on narrow phones.
      if valueWidth > 0 and labelWidth + gap + valueWidth > textAvail then
        local maxValueColumn = math.max(1,
          textAvail - math.max(48, textAvail * 0.48))
        valueWidth = math.min(valueWidth, maxValueColumn)
      end
      local leftWidth = textAvail - (valueWidth > 0 and valueWidth + gap or 0)
      if not row.header and not row.category then
        local labelLines = { truncate(label, math.max(20, leftWidth)) }
        local valueLines = value ~= "" and { truncate(value, valueWidth) } or {}
        if layout.wrapRows then
          labelLines = wrappedLines(label, math.max(1, leftWidth), bodyFont)
          valueLines = value ~= "" and wrappedLines(value, math.max(1, valueWidth), bodyFont) or {}
        end
        local lineCount = math.max(#labelLines, #valueLines)
        local blockHeight = lineCount * textHeight(bodyFont)
          + math.max(0, lineCount - 1) * theme.spacing.xs
        local textY = ry + (layout.rowHeight - blockHeight) / 2
        love.graphics.setFont(bodyFont)
        for lineIndex, line in ipairs(labelLines) do
          drawText(line, textX,
            textY + (lineIndex - 1) * (textHeight(bodyFont) + theme.spacing.xs))
        end
        for lineIndex, line in ipairs(valueLines) do
          local lineWidth = bodyFont:getWidth(line)
          drawText(line,
            layout.x + layout.w - theme.spacing.lg - lineWidth,
            textY + (lineIndex - 1) * (textHeight(bodyFont) + theme.spacing.xs))
        end
      end
      if row.marker then
        setColor(colors.accent)
        love.graphics.circle("fill", layout.x + layout.w - theme.spacing.lg -
          valueWidth - 10, ry + layout.rowHeight * 0.5, 4)
      end
      if index < #rows then
        setColor(colors.divider)
        love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
          ry + layout.rowHeight - themeMetric(theme, "divider", 1),
          layout.w - theme.spacing.lg * 2, themeMetric(theme, "divider", 1))
      end
    end
    if scroll > 0 then
      setColor(colors.accent)
      drawText("^", layout.x + layout.w - theme.spacing.lg - 8,
        layout.y + layout.header - 4)
    end
    if scroll + layout.visible < #rows then
      setColor(colors.accent)
      drawText("v", layout.x + layout.w - theme.spacing.lg - 8,
        layout.y + layout.h - layout.footer - 2)
    end
  end

  local function textPrefix(value, glyphs)
    value = safeText(value)
    glyphs = math.max(0, math.floor(tonumber(glyphs) or 0))
    if glyphs == 0 then return "" end
    if glyphFont == nil then
      local ok, library = pcall(require, "src.render.Font")
      glyphFont = ok and library or false
    end
    if glyphFont and type(glyphFont.split) == "function" then
      local ok, spans = pcall(glyphFont.split, value)
      if ok and type(spans) == "table" then
        if glyphs >= #spans then return value end
        local span = spans[glyphs]
        if span and span.to then return value:sub(1, span.to) end
      end
    end
    if utf8Library == nil then
      local ok, lib = pcall(require, "utf8")
      utf8Library = ok and lib or false
    end
    if utf8Library and type(utf8Library.offset) == "function" then
      local ok, nextByte = pcall(utf8Library.offset, value, glyphs + 1)
      if ok then
        return nextByte and value:sub(1, nextByte - 1) or value
      end
    end
    return value:sub(1, glyphs)
  end

  local function dialogueLines(state)
    local pages = state and state.pages
    local page = type(pages) == "table" and pages[state.pageIndex or 1]
    if type(page) ~= "table" then return { "" } end
    local current = clamp(state.lineIndex or 1, 1, math.max(1, #page))
    local shownCount = type(state.shown) == "table" and #state.shown or 1
    shownCount = clamp(shownCount, 1, 5)
    -- The vanilla TextBox is a two-line tile window, so it keeps only the
    -- latest two lines in `shown` and scrolls whenever a page contains a
    -- normal newline. Modern dialogue cards have room to grow, though, and
    -- should let a longer message read as one stable card. Preserve the
    -- engine's intentional \v continuation pauses; those are the cases where
    -- scrolling is part of the authored interaction rather than just a
    -- consequence of the classic two-line window.
    local expandPage = true
    local conts = type(pages.contBefore) == "table"
      and pages.contBefore[state.pageIndex or 1] or nil
    if type(conts) == "table" then
      for index = 2, #page do
        if conts[index] then
          expandPage = false
          break
        end
      end
    end
    local first = expandPage and 1
      or math.max(1, current - shownCount + 1)
    local lines = {}
    for index = first, current do
      local line = safeText(page[index])
      if index == current then line = textPrefix(line, state.charIndex or #line) end
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  local function completeDialogueLines(state)
    local pages = state and state.pages
    local page = type(pages) == "table" and pages[state.pageIndex or 1]
    if type(page) ~= "table" then return { "" } end
    local current = clamp(state.lineIndex or 1, 1, math.max(1, #page))
    local shownCount = type(state.shown) == "table" and #state.shown or 1
    shownCount = clamp(shownCount, 1, 5)
    local expandPage = true
    local conts = type(pages.contBefore) == "table"
      and pages.contBefore[state.pageIndex or 1] or nil
    if type(conts) == "table" then
      for index = 2, #page do
        if conts[index] then
          expandPage = false
          break
        end
      end
    end
    local first = expandPage and 1
      or math.max(1, current - shownCount + 1)
    local last = expandPage and #page or current
    local lines = {}
    for index = first, last do
      lines[#lines + 1] = safeText(page[index])
    end
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  local function wrappedDialogueLines(state, body, maxWidth)
    local lines = {}
    for _, source in ipairs(dialogueLines(state)) do
      for _, line in ipairs(wrappedLines(source, maxWidth, body)) do
        lines[#lines + 1] = line
      end
    end
    return lines
  end

  local function modalHint(kind, footerText)
    if safeText(footerText) ~= "" then return footerText end
    if kind == "choice" then return nil end
    if kind == "quantity" then
      return "UP/DOWN  amount   A  confirm   B  cancel"
    end
    return "A  select   B  back"
  end

  local function modalReserveHeight(game, theme, kind, state, viewport)
    local rows, _, _, title, footerText = rowsFor(game, state, kind)
    local rowCount = math.max(1, math.min(#(rows or {}), 6))
    local x, y, w, h = presenterRect(viewport)
    if kind == "choice" and w > h * 1.2 then rowCount = 1 end
    local titleHeight = textHeight(font(fontCache, theme.typography.title))
    local captionHeight = textHeight(font(fontCache, theme.typography.caption))
    local header = safeText(title) ~= "" and (titleHeight + theme.spacing.md)
      or theme.spacing.md
    local footer = shouldDrawHint(modalHint(kind, footerText))
      and captionHeight + theme.spacing.md or 0
    return header + footer + rowCount * minimumRowHeight(theme)
  end

  local function dialogueRect(viewport, theme, state, game, reserveKind, reserveState)
    local x, y, w, h = presenterRect(viewport)
    local landscape = w > h * 1.2
    local gutter = theme.spacing.lg
    -- Dialogue is a reading surface, so give it a little more horizontal
    -- breathing room than the compact list cards.  Keep the padding here in
    -- lockstep with drawDialogue below so wrapping and the painted text use
    -- the same usable width.
    local paddingX = theme.spacing.xl
    local paddingY = theme.spacing.lg
    local body = font(fontCache, theme.typography.body)
    local widest = 0
    for _, line in ipairs(completeDialogueLines(state) or {}) do
      widest = math.max(widest, body:getWidth(line))
    end
    local uiScale = theme.scale and theme.scale.ui or 1
    local maxWidth = landscape and math.min(900 * uiScale, w * 0.84)
      or math.min(620 * uiScale, w - gutter * 2)
    local minWidth = math.min(landscape and 400 or 340, maxWidth)
    local width = clamp(widest + paddingX * 2, minWidth, maxWidth)
    -- TextBox pages in the released engine normally expose two visible lines.
    -- Size to the complete ordinary page instead of reserving a fixed number
    -- of lines for every message; explicit continuation pauses still use the
    -- engine-compatible two-line window.
    local lineGap = textHeight(body) + theme.spacing.xs
    local available = math.max(1, width - paddingX * 2)
    local desiredLines = 0
    for _, line in ipairs(completeDialogueLines(state)) do
      desiredLines = desiredLines + #wrappedLines(line, available, body)
    end
    -- Grow to the full current page whenever the viewport can hold it. The
    -- old five-line cap was still an arbitrary version of the vanilla
    -- two-line window and made four-line NPC/save messages race through a
    -- visually scrolling card at FAST text speed.
    local maxHeight = h - gutter * 2
    if reserveKind then
      local reserve = modalReserveHeight(game, theme, reserveKind, reserveState, viewport)
      maxHeight = math.min(maxHeight,
        math.max(1, h - gutter * 2 - reserve - theme.spacing.sm))
    end
    local maxLines = math.max(2,
      math.floor((maxHeight - paddingY * 2) / lineGap))
    desiredLines = math.max(2, math.min(desiredLines, maxLines))
    -- Keep the card large enough for the revealed text and footer, but do not
    -- let a chrome-only minimum create a tall empty box when UI SCALE is high
    -- and FONT SCALE is intentionally smaller.
    local contentHeight = lineGap * desiredLines + paddingY * 2
    local minimumHeight = lineGap * 2 + paddingY * 2
    local height = math.max(minimumHeight, contentHeight)
    if reserveKind then
      local reserve = modalReserveHeight(game, theme, reserveKind, reserveState, viewport)
      local availableHeight = h - gutter * 2 - reserve - theme.spacing.sm
      height = math.min(height, math.max(1, availableHeight))
    end
    height = math.min(height, h - gutter * 2)
    return x + (w - width) / 2, y + h - height - gutter, width, height
  end

  local function drawDialogue(state, viewport, theme, game, reserveKind, reserveState)
    local px, py, panelW, panelH = dialogueRect(viewport, theme, state, game,
      reserveKind, reserveState)
    local spacing, colors = theme.spacing, theme.colors
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.md)
    drawPanelAccent(theme, px, py, panelW, theme.radii.md)

    local body = font(fontCache, theme.typography.body)
    love.graphics.setFont(body)
    local paddingX = spacing.xl
    local paddingY = spacing.lg
    local available = panelW - paddingX * 2
    local lines = wrappedDialogueLines(state, body, available)
    local lineGap = textHeight(body) + spacing.xs
    local maxLines = math.max(1, math.floor((panelH - paddingY * 2) / lineGap))
    while #lines > maxLines do table.remove(lines, 1) end
    local textY = py + paddingY
    setColor(colors.text)
    for index, line in ipairs(lines) do
      drawText(line, px + paddingX, textY + (index - 1) * lineGap)
    end

    local ready = state.waiting or (state.done and not state.choice
      and not state.auto and not state.stay)
    if ready and not state.choice then
      local indicator = "..."
      setColor(colors.accent)
      drawText(indicator,
        px + panelW - paddingX - body:getWidth(indicator),
        py + panelH - paddingY - textHeight(body))
    end
    return { x = px, y = py, w = panelW, h = panelH }
  end

  local function drawModalRows(game, state, kind, viewport, theme, underKind,
      underState)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, kind)
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local landscape = w > h * 1.2
    local rowHeight = minimumRowHeight(theme)
    local titleHeight = textHeight(font(fontCache, theme.typography.title))
    local captionHeight = textHeight(font(fontCache, theme.typography.caption))
    local header = safeText(title) ~= "" and (titleHeight + spacing.md)
      or spacing.md
    local hint = modalHint(kind, footerText)
    local footer = shouldDrawHint(hint) and captionHeight + spacing.md or 0
    local maxPanelW = landscape and math.min(w * 0.70, 520) or math.min(w - spacing.lg * 2, 520)
    local panelW = math.min(w - spacing.lg * 2,
      contentWidthFor(theme, rows, title, footerText, landscape and 220 or 250, maxPanelW))
    local horizontalChoice = kind == "choice" and landscape
    if horizontalChoice then
      local choiceFont = font(fontCache, theme.typography.body)
      local desiredWidth = spacing.lg * 2 + spacing.sm * math.max(0, #rows - 1)
      for _, row in ipairs(rows) do
        desiredWidth = desiredWidth + choiceFont:getWidth(safeText(row.label))
          + spacing.sm * 2
      end
      panelW = math.min(w - spacing.lg * 2, math.max(panelW, desiredWidth))
    end
    local choiceRowCount = horizontalChoice and 1 or 2
    local availableRows = math.max(1, math.floor(
      (h - spacing.lg * 2 - header - footer) / rowHeight))
    local visible = math.min(#rows, horizontalChoice and choiceRowCount
      or (landscape and 7 or 6), availableRows)
    visible = math.max(1, visible)
    local panelH = header + footer + visible * rowHeight
    panelH = math.min(panelH, h - spacing.lg * 2)
    local px = x + (w - panelW) / 2
    local py = y + (h - panelH) / 2
    if underKind == "text" then
      local dx, dy, dw = dialogueRect(viewport, theme, underState, game)
      px = dx + dw - panelW
      py = math.max(y + spacing.lg, dy - panelH - spacing.sm)
    end
    local layout = {
      x = px, y = py, w = panelW, h = panelH,
      rowHeight = rowHeight, header = header, footer = footer,
      visible = visible, radius = theme.radii.md, sidePanel = false,
      horizontalChoice = horizontalChoice,
    }
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, layout, title)
    drawRows(theme, layout, rows, selected, scroll, game)
    if footer > 0 then
      setColor(theme.colors.divider)
      love.graphics.rectangle("fill", px + spacing.lg,
        py + panelH - footer, panelW - spacing.lg * 2,
        themeMetric(theme, "divider", 1))
      setColor(theme.colors.textMuted)
      drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footer + spacing.xs, panelW - spacing.lg * 2)
    end
  end

  local function drawManagerTabs(theme, layout, state)
    if state.screen ~= "list" then return end
    local labels = { "MODS", "PROFILES", "ERRORS" }
    local active = state.tab or 1
    local x = layout.x + theme.spacing.lg
    local y = layout.y + layout.header - theme.spacing.md
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    for i, label in ipairs(labels) do
      local shown = i == active and ("[" .. label .. "]") or label
      local textWidth = love.graphics.getFont():getWidth(shown)
      local width = textWidth + theme.spacing.lg
      local action
      if i ~= active then
        action = ((active % #labels) + 1 == i) and "right" or "left"
      end
      registerPointerRegion(x - theme.spacing.xs, y - theme.spacing.xs,
        textWidth + theme.spacing.sm, textHeight(love.graphics.getFont())
          + theme.spacing.sm, {
          role = "control", action = action, interactive = true,
          controlKey = "manager-tab:" .. i, dragHandle = false,
        })
      setColor(i == active and theme.colors.accent or theme.colors.textMuted)
      drawText(shown, x, y)
      x = x + width
    end
    love.graphics.setFont(font(fontCache, theme.typography.body))
  end

  local function drawManagerSubtitle(theme, layout, state)
    local subtitle
    if state.screen == "detail" and state.currentMod then
      local m = state.currentMod
      local status = m.enabled and "ENABLED" or "DISABLED"
      if m.state == "blocked_dependency" then status = status .. "  ?" end
      if m.error then status = status .. "  !" end
      if type(state.isStaged) == "function" then
        local ok, staged = pcall(state.isStaged, state, m)
        if ok and staged then status = status .. "  STAGED" end
      end
      subtitle = status .. "  " .. safeText(m.category or "OTHER")
    elseif state.screen == "apply" then
      local staged = type(state.stagedList) == "function" and state:stagedList() or {}
      subtitle = (#staged > 0 and (tostring(#staged) .. " MODS STAGED") or
        (state.banner or "NO CHANGES"))
    elseif state.screen == "list" then
      subtitle = state.banner or ""
    end
    if subtitle and subtitle ~= "" then
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(theme.colors.textMuted)
      drawText(truncate(subtitle,
        layout.w - theme.spacing.lg * 2), layout.x + theme.spacing.lg,
        layout.y + theme.spacing.md + theme.typography.title + 2)
      love.graphics.setFont(font(fontCache, theme.typography.body))
    end
  end

  local function drawManagerOverlay(theme, layout, state, viewport)
    local overlay = state.overlay
    if not overlay then return end
    drawPresenterBackdrop(theme, viewport)
    drawModalScrim(theme, viewport)
    local vx, vy, vw, vh = presenterRect(viewport)
    registerPointerRegion(vx, vy, vw, vh, {
      role = "scrim", modalBlocker = true, interactive = true,
      dragHandle = false,
    })
    local lines = overlay.lines or {}
    local lineHeight = theme.typography.body + theme.spacing.sm
    local modalW = math.min(layout.w * 0.84, 620)
    local modalH = math.min(layout.h * 0.72,
      theme.spacing.lg * 2 + lineHeight * (#lines +
        (overlay.kind == "confirm" and 3 or 1)))
    local mx = layout.x + (layout.w - modalW) / 2
    local my = layout.y + (layout.h - modalH) / 2
    registerPointerRegion(mx, my, modalW, modalH, {
      role = "modal", modalOwner = overlay,
      activate = overlay.kind == "ok", interactive = true,
      dragHandle = false,
    })
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    drawPanelAccent(theme, mx, my, modalW, theme.radii.lg or 20)
    love.graphics.setFont(font(fontCache, theme.typography.body))
    for i, line in ipairs(lines) do
      setColor(theme.colors.text)
      drawText(truncate(line, modalW - theme.spacing.lg * 2),
        mx + theme.spacing.lg, my + theme.spacing.lg + (i - 1) * lineHeight)
    end
    local footerY = my + modalH - theme.spacing.lg - lineHeight
    if overlay.kind == "confirm" then
      local index = overlay.index or 1
      local yesX = mx + theme.spacing.lg
      local noX = mx + theme.spacing.lg + theme.spacing.xl * 2.75
      local yesW = math.max(love.graphics.getFont():getWidth("YES") +
        theme.spacing.md * 2, noX - yesX - theme.spacing.sm)
      local noW = love.graphics.getFont():getWidth("NO") + theme.spacing.md * 2
      registerPointerRegion(yesX - theme.spacing.sm, footerY - theme.spacing.sm,
        yesW, lineHeight + theme.spacing.sm * 2, {
          selectionState = overlay, selectionField = "index",
          selectionIndex = 1, activate = true, dragHandle = false,
        })
      registerPointerRegion(noX - theme.spacing.sm, footerY - theme.spacing.sm,
        noW, lineHeight + theme.spacing.sm * 2, {
          selectionState = overlay, selectionField = "index",
          selectionIndex = 2, activate = true, dragHandle = false,
        })
      setColor(index == 1 and theme.colors.accent or theme.colors.textMuted)
      drawText("YES", yesX, footerY)
      setColor(index == 2 and theme.colors.accent or theme.colors.textMuted)
      drawText("NO", noX, footerY)
    else
      setColor(theme.colors.textMuted)
      drawHintIfUseful(theme, "A / B  CLOSE", mx + theme.spacing.lg, footerY,
        modalW - theme.spacing.lg * 2)
    end
  end

  local function drawManagerOptionHelp(theme, layout, state, viewport)
    local help = state._gen1OptionDescription
    if not help then return end
    drawPresenterBackdrop(theme, viewport)
    drawModalScrim(theme, viewport)
    local vx, vy, vw, vh = presenterRect(viewport)
    registerPointerRegion(vx, vy, vw, vh, {
      role = "scrim", modalBlocker = true, interactive = true,
      dragHandle = false,
    })
    local spacing = theme.spacing
    local body = font(fontCache, theme.typography.body)
    local titleFont = font(fontCache, theme.typography.title * 0.82)
    love.graphics.setFont(body)
    local maxTextW = math.max(120, layout.w - spacing.lg * 4)
    local lines = wrappedLines(help.text, maxTextW)
    local maxLines = 6
    if #lines > maxLines then
      while #lines > maxLines do table.remove(lines) end
      local last = lines[#lines] or ""
      lines[#lines] = truncate(last, maxTextW)
    end
    local title = safeText(help.title or "SETTING")
    local titleW = titleFont:getWidth(title)
    local widest = math.max(titleW, maxTextW)
    local modalW = math.min(layout.w - spacing.md * 2,
      math.max(240, widest + spacing.lg * 2))
    local lineHeight = textHeight(body) + spacing.xs
    local footerH = textHeight(body) + spacing.sm
    local modalH = spacing.lg * 2 + textHeight(titleFont) + spacing.sm
      + #lines * lineHeight + footerH
    modalH = math.min(layout.h - spacing.md * 2, modalH)
    local mx = layout.x + (layout.w - modalW) / 2
    local my = layout.y + (layout.h - modalH) / 2
    registerPointerRegion(mx, my, modalW, modalH, {
      role = "modal", pointerCommand = "dismiss_help",
      interactive = true, dragHandle = false,
    })
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    drawPanelAccent(theme, mx, my, modalW, theme.radii.lg or 20)
    love.graphics.setFont(titleFont)
    setColor(theme.colors.text)
    drawText(truncate(title, modalW - spacing.lg * 2),
      mx + spacing.lg, my + spacing.md)
    love.graphics.setFont(body)
    local textY = my + spacing.md + textHeight(titleFont) + spacing.sm
    for index, line in ipairs(lines) do
      setColor(theme.colors.text)
      drawText(line, mx + spacing.lg, textY + (index - 1) * lineHeight)
    end
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", mx + spacing.lg,
      my + modalH - footerH, modalW - spacing.lg * 2,
      themeMetric(theme, "divider", 1))
    setColor(theme.colors.textMuted)
    drawHintIfUseful(theme, "SELECT / A / B  CLOSE", mx + spacing.lg,
      my + modalH - footerH + spacing.xs, modalW - spacing.lg * 2)
  end

  local function drawManager(game, state, viewport, theme)
    local rows, selected, scroll, title = managerRowsFor(game, state)
    local layout = layoutFor(viewport, theme, "mod_manager", rows, title,
      state.notice)
    -- The manager has a tab strip and (for detail/apply views) a status
    -- subtitle in addition to the normal title. Reserve that line before
    -- calculating how many rows fit so portrait layouts never overlap text.
    local headerExtra = state.screen == "list" and (theme.spacing.md + theme.spacing.xs)
      or state.screen == "detail" and (theme.spacing.md + theme.spacing.xs)
      or state.screen == "apply" and (theme.spacing.md + theme.spacing.xs) or 0
    if headerExtra > 0 then
      layout.header = layout.header + headerExtra
      layout.visible = math.max(1, math.floor((layout.h - layout.header -
        layout.footer) / layout.rowHeight))
      layout.visible = math.min(layout.visible, math.max(1, #rows))
    end
    scroll = clamp(scroll, 0, math.max(0, #rows - layout.visible))
    selected = clamp(selected, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visible then scroll = selected - layout.visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h,
      layout.radius)
    drawHeader(theme, layout, title)
    drawManagerTabs(theme, layout, state)
    drawManagerSubtitle(theme, layout, state)
    drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2,
      themeMetric(theme, "divider", 1))
    setColor(theme.colors.textMuted)
    local footer = state.notice
    if not footer and state.screen == "list" then
      if state.tab == 1 then
        footer = "A  open   SELECT  toggle   START  apply   B  exit"
      elseif state.tab == 2 then
        footer = "A  apply   SELECT  rename   START  delete"
      else
        footer = "UP/DOWN  scroll"
      end
    elseif not footer and state.screen == "detail" then
      footer = "L/R  details   A  choose   SELECT  toggle   B  back"
    elseif not footer and state.screen == "errors" then
      footer = "UP/DOWN  scroll   B  back"
    elseif not footer and state.screen == "permissions" then
      footer = "Declared by author; not enforced   B  back"
    elseif not footer and state.screen == "options" then
      footer = "Arrow keys  adjust   SELECT  help   B  done"
    elseif not footer then
      footer = "A  choose   B  back"
    end
    drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8,
      layout.w - theme.spacing.lg * 2)
    drawManagerOverlay(theme, layout, state, viewport)
    drawManagerOptionHelp(theme, layout, state, viewport)
    love.graphics.pop()
  end

  local function drawSummary(game, state, viewport, theme)
    love.graphics.push("all")
    love.graphics.origin()
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 780))
    -- Summary pages are data cards, not canvases. Keep their width near the
    -- amount of information they display so a large UI scale does not turn a
    -- six-row stat page into a huge empty rectangle.
    local mon = summaryPokemon(state) or {}
    local def = pokemonDefinition(game, mon.species)
    local name = safeText(mon.nickname or (def and def.name)
      or mon.species or "POKéMON")
    local summarySprite = state.page ~= 2
      and spriteFor(game, mon, nil, "summary") or nil
    local page = state.page == 2 and "MOVES / EXPERIENCE" or
      "STATUS / TRAINER DATA"
    panelW = math.min(panelW, scaledPanelWidth(theme,
      state.page == 2 and 680 or 640))
    local compact = panelW < 620
    local titleFont = font(fontCache, compact and theme.typography.title * 0.86
      or theme.typography.title)
    local bodyFont = font(fontCache, compact and theme.typography.body * 0.86
      or theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local titleH = textHeight(titleFont)
    local lineGap = compact and (textHeight(bodyFont) + spacing.xs)
      or (spacing.lg + 10)
    local bodyLine = textHeight(bodyFont) + spacing.xs
    local titleOffset = spacing.md + titleH + spacing.xs
    local pageOffset = titleOffset
    local levelOffset = pageOffset + textHeight(bodyFont) + spacing.xs
    local hpOffset = levelOffset + lineGap
    local statusOffset = hpOffset + lineGap
    local contentBottom
    if state.page == 2 then
      local moveGap = compact and bodyLine or 28
      contentBottom = statusOffset + lineGap * 2 + textHeight(bodyFont)
        + moveGap * 3 + textHeight(bodyFont)
    else
      local spriteSize = compact and math.min(112, panelW * 0.24) or 150
      local spriteBottom = summarySprite
        and (statusOffset + lineGap * 2 + spacing.sm + spriteSize)
        or (statusOffset + lineGap)
      local statGap = compact and bodyLine or 28
      local statsBottom = pageOffset + statGap * 5 + textHeight(bodyFont)
      contentBottom = math.max(spriteBottom, statsBottom)
    end
    local panelH = math.min(h - gutter * 2,
      contentBottom + spacing.lg + textHeight(captionFont) + spacing.md)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local pageY = py + spacing.md + titleH + spacing.xs
    local levelY = pageY + textHeight(bodyFont) + spacing.xs
    local hpY = levelY + lineGap
    local statusY = hpY + lineGap
    drawPresenterBackdrop(theme, viewport)
    love.graphics.setFont(bodyFont)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText(name, px + spacing.lg, py + spacing.md,
      panelW - spacing.lg * 2, titleFont)
    love.graphics.setFont(bodyFont)
    local level = mon.level and ("LEVEL %d"):format(mon.level) or ""
    local hp = mon.stats and mon.stats.hp and ("HP  %d / %d"):format(mon.hp or 0, mon.stats.hp) or ""
    local status = mon.status or "OK"
    if panelW < 620 and state.page ~= 2 then page = "STATUS" end
    setColor(theme.colors.textMuted)
    drawFittedText(page, px + spacing.lg, pageY,
      panelW - spacing.lg * 2, bodyFont)
    setColor(theme.colors.text)
    drawFittedText(level, px + spacing.lg, levelY,
      panelW - spacing.lg * 2, bodyFont)
    drawFittedText(hp, px + spacing.lg, hpY,
      panelW - spacing.lg * 2, bodyFont)
    drawFittedText(("STATUS  %s"):format(status), px + spacing.lg, statusY,
      panelW - spacing.lg * 2, bodyFont)
    if state.page ~= 2 then
      local sprite = summarySprite
      if sprite then
        local iw, ih = imageMetrics(sprite)
        if iw and ih then
          local spriteSize = compact and math.min(112, panelW * 0.24) or 150
          local spriteX = px + spacing.lg
          local spriteY = statusY + lineGap * 2 + spacing.sm
          local scale = math.min(spriteSize / iw, spriteSize / ih)
          setColor({ 1, 1, 1, 1 })
          drawImage(sprite, spriteX + (spriteSize - iw * scale) / 2,
            spriteY + (spriteSize - ih * scale) / 2, 0, scale, scale)
        end
      end
    end
    if state.page == 2 then
      drawFittedText(("EXP  %s"):format(safeText(mon.exp)), px + spacing.lg,
        statusY + lineGap, panelW - spacing.lg * 2, bodyFont)
      local moves = mon.moves or {}
      local moveX = px + spacing.lg
      local moveY = statusY + lineGap * 2
      local moveGap = compact and (textHeight(bodyFont) + spacing.xs) or 28
      local ppX = px + panelW - spacing.lg - bodyFont:getWidth("PP 00/00")
      local moveMax = math.max(24, ppX - spacing.sm - moveX)
      for i = 1, 4 do
        local move = moves[i]
        local moveDef = move and game.data and game.data.moves and game.data.moves[move.id]
        local moveName = moveDef and moveDef.name or move and move.id or "-"
        local pp = "--"
        if move and moveDef then
          local maxPP = (moveDef.pp or 0) + (move.ppUps or 0) * math.floor((moveDef.pp or 0) / 5)
          pp = ("%d/%d"):format(move.pp or 0, maxPP)
        end
        setColor(theme.colors.text)
        drawFittedText(moveName, moveX, moveY + (i - 1) * moveGap,
          moveMax, bodyFont)
        setColor(theme.colors.textMuted)
        drawText(("PP %s"):format(pp), ppX,
          moveY + (i - 1) * moveGap)
      end
    else
      local types = def and def.types or {}
      drawText(("TYPE  %s %s"):format(safeText(types[1]), safeText(types[2])),
        px + spacing.lg, statusY + lineGap)
      local stats = mon.stats or {}
      local infoX = compact and (px + panelW * 0.48) or (px + panelW * 0.52)
      local statGap = compact and (textHeight(bodyFont) + spacing.xs) or 28
      local statY = pageY
      local statRows = {
        { "ATTACK", stats.attack }, { "DEFENSE", stats.defense },
        { "SPEED", stats.speed }, { "SPECIAL", stats.special },
        { "ID", mon.otId or (game.save and game.save.player
          and game.save.player.id) or 0 },
        { "OT", mon.ot or (game.save and game.save.player
          and game.save.player.name) or "RED" },
      }
      for i, item in ipairs(statRows) do
        setColor(theme.colors.textMuted)
        drawFittedText(item[1], infoX, statY + (i - 1) * statGap,
          math.max(24, px + panelW - spacing.lg - infoX), bodyFont)
        setColor(theme.colors.text)
        local value = safeText(item[2])
        local valueX = infoX + bodyFont:getWidth(item[1]) + spacing.sm
        drawFittedText(value, valueX, statY + (i - 1) * statGap,
          math.max(24, px + panelW - spacing.lg - valueX), bodyFont)
      end
    end
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    drawHintIfUseful(theme, "A / B  continue", px + spacing.lg,
      py + panelH - spacing.lg - 14, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  iconFor = function(game, mon)
    local def = mon and game.data and game.data.pokemon and
      game.data.pokemon[mon.species]
    local icons = game.data and game.data.icons
    local entry = icons and icons.bySpecies and icons.bySpecies[mon.species]
    entry = entry or (def and def.icon)
    local iconName
    local hasDescriptor = type(entry) == "table" and
      (entry.image or entry.texture or entry.path or entry.asset)
    if type(entry) == "table" and not hasDescriptor then
      entry = entry.image or entry.path
    end
    if type(entry) == "string" and icons and icons.icons then
      iconName = entry
      entry = icons.icons[entry] or entry
    end
    if not entry and def and def.dex and icons and icons.byDex then
      entry = icons.byDex[def.dex]
      if icons.icons and type(entry) == "string" then
        iconName = entry
        entry = icons.icons[entry]
      end
    end
    if spriteResolver == nil then
      local ok, resolver = pcall(require, "src.pokemon.Sprites")
      spriteResolver = ok and resolver or false
    end
    local originalEntry = entry
    local replaced = false
    if spriteResolver and type(spriteResolver.iconPath) == "function" then
      local original = entry
      local ok, hooked = pcall(spriteResolver.iconPath, game.data, mon, entry, {})
      if ok then
        entry = hooked
        replaced = hooked ~= original
      end
    end
    -- Load first so we can distinguish the engine's built-in pose sheets from
    -- authored two-frame replacement art.  Built-in sheets are commonly
    -- 16x32 or 16x96; the vanilla renderer selects one 16px rest frame from
    -- those sheets, while replacement descriptors explicitly opt into their
    -- own animation contract.
    local image = imageFor(entry)
    if not image then return nil end
    -- Vanilla icon sheets are monochrome source art; apply the species' live
    -- palette just as the native summary/party renderer does. Explicit icon
    -- descriptors remain authored artwork and are left untouched.
    paletteRuntime.setImage(image, not hasDescriptor
      and paletteRuntime.pokemon(game, mon and mon.species) or nil)
    local followerSheet = knownSheetOptions(originalEntry or entry, image, 0)
    if followerSheet then image = markAnimated(image, followerSheet) end
    if hasDescriptor then
      return image
    end
    if replaced then
      return markAnimated(image, { animated = true, frames = 2,
        detectSheet = true })
    end
    if iconName then
      local okW, width = pcall(function() return image:getWidth() end)
      local okH, height = pcall(function() return image:getHeight() end)
      if okW and okH and width == 16 and height >= 32 and height % 16 == 0 then
        return markAnimated(image, { animated = true,
          frames = height / 16, staticFrame = 0 })
      end
    end
    return image
  end

  local function resolvedSpritePath(game, mon, side, kind, fallback)
    local species = mon and mon.species
    local def = species and game.data and game.data.pokemon and
      game.data.pokemon[species]
    local path = fallback or (def and
      (side == "back" and def.spriteBack or def.spriteFront))
    if not path or not species then return path, false, false end
    local replaced = false
    local trueColor = false

    -- src.pokemon.Sprites.path is the runtime's sanctioned sprite seam. It
    -- invokes enabled pokemon.sprite replacements (Gold/Silver, alternate
    -- skins, etc.) and returns the vanilla path when none is active. Older
    -- builds without the helper fall back to the data path.
    if spriteResolver == nil then
      local ok, resolver = pcall(require, "src.pokemon.Sprites")
      spriteResolver = ok and resolver or false
    end
    if spriteResolver and type(spriteResolver.path) == "function" then
      local ok, hooked, hookedTrueColor = pcall(spriteResolver.path,
        game.data, species, side, {
        mon = mon, kind = kind or "menu",
      })
      if ok and type(hooked) == "string" and hooked ~= "" then
        replaced = hooked ~= path
        path = hooked
        trueColor = hookedTrueColor == true
      end
    end
    return path, replaced, trueColor
  end

  spriteFor = function(game, mon, fallback, kind)
    local candidate = mon and imageCandidate(mon)
    local image = imageFor(candidate)
    if image then
      local sheet = knownSheetOptions(candidate, image, nil)
      if sheet then image = markAnimated(image, sheet) end
      paletteRuntime.setImage(image, type(candidate) ~= "table"
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path, _, trueColor = resolvedSpritePath(game, mon, "front", kind,
      fallbackPath)
    -- Battle sprite replacement assets are complete single-frame pictures by
    -- default (including Gold/Silver packs). Only an explicit image
    -- descriptor with `frames` opts into sheet animation.
    image = imageFor(path)
    local sheet = image and knownSheetOptions(path, image, nil)
    if sheet then image = markAnimated(image, sheet) end
    if image then
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    image = imageFor(fallback)
    paletteRuntime.setImage(image, paletteRuntime.pokemon(game, mon and mon.species))
    return image
  end

  local function spriteForSide(game, mon, side, fallback, kind)
    local candidate = mon and imageCandidate(mon)
    local image = imageFor(candidate)
    if image then
      local sheet = knownSheetOptions(candidate, image, nil)
      if sheet then image = markAnimated(image, sheet) end
      paletteRuntime.setImage(image, type(candidate) ~= "table"
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path, _, trueColor = resolvedSpritePath(game, mon, side, kind,
      fallbackPath)
    -- `pokemon.sprite` paths are authored battle pictures, not animation
    -- sheets. Explicit descriptors can still request frame cropping.
    image = imageFor(path)
    local sheet = image and knownSheetOptions(path, image, nil)
    if sheet then image = markAnimated(image, sheet) end
    if image then
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    image = imageFor(fallback)
    paletteRuntime.setImage(image, paletteRuntime.pokemon(game, mon and mon.species))
    return image
  end

  local function drawTrainerCard(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 720))
    panelW = math.min(panelW, scaledPanelWidth(theme, 620))
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local titleFont = font(fontCache, theme.typography.title)
    local headerH = textHeight(titleFont) + spacing.lg
    local rowH = textHeight(bodyFont) + spacing.md
    local footerH = textHeight(captionFont) + spacing.lg
    local contentH = rowH * 3 + spacing.lg
    local panelH = math.min(h - gutter * 2,
      headerH + contentH + footerH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    local headerLayout = { x = px, y = py, w = panelW, h = panelH,
      radius = theme.radii.md }
    drawHeader(theme, headerLayout, Strings("TRAINER CARD"))

    local save = game.save or {}
    local player = save.player or {}
    local playTime = math.floor(save.playTime or 0)
    local fields = {
      { Strings("NAME"), player.name or "RED" },
      { Strings("TIME"), ("%d:%02d"):format(math.floor(playTime / 3600),
          math.floor(playTime / 60) % 60) },
      { Strings("MONEY"), ("¥%d"):format(save.money or 0) },
    }
    local contentY = py + headerH
    local labelFont = bodyFont
    local valueFont = bodyFont
    love.graphics.setFont(labelFont)
    local labelWidth = 0
    for _, row in ipairs(fields) do
      labelWidth = math.max(labelWidth, labelFont:getWidth(row[1]))
    end
    local valueX = px + spacing.lg + labelWidth + spacing.md
    local valueMax = math.max(24, px + panelW - spacing.lg - valueX)
    for index, row in ipairs(fields) do
      local rowY = contentY + spacing.sm + (index - 1) * rowH
      setColor(index == 1 and (colors.surfaceRaised or colors.surface)
        or colors.surface)
      love.graphics.rectangle("fill", px + spacing.lg, rowY,
        panelW - spacing.lg * 2, rowH - 1, theme.radii.sm)
      setColor(colors.textMuted)
      drawText(row[1], px + spacing.lg + spacing.sm,
        rowY + (rowH - textHeight(labelFont)) / 2)
      setColor(colors.text)
      drawFittedText(row[2], valueX,
        rowY + (rowH - textHeight(valueFont)) / 2, valueMax, valueFont)
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    setColor(colors.textMuted)
    drawHintIfUseful(theme, Strings("A / B  back"), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function selectedListRow(rows, selected)
    return rows and rows[clamp(selected or 1, 1, math.max(1, #rows))]
  end

  local function maxMovePP(move, moveDef)
    if not (move and moveDef) then return 0 end
    local base = tonumber(moveDef.pp) or 0
    return base + (tonumber(move.ppUps) or 0) * math.floor(base / 5)
  end

  -- Imported box_struct records intentionally omit their calculated stat
  -- block. Derive a temporary display copy for Bill's PC without calling
  -- Stats.ensure (which would mutate the save merely because UI was drawn).
  local function displayStats(game, mon, derive)
    if type(mon) ~= "table" then return {} end
    if type(mon.stats) == "table" then return mon.stats end
    local def = derive and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    if def and type(def.baseStats) == "table"
        and runtimeClasses.stats
        and type(runtimeClasses.stats.calc) == "function" then
      local ok, stats = pcall(runtimeClasses.stats.calc, def, mon.level or 1,
        mon.dvs or {}, mon.statExp)
      if ok and type(stats) == "table" then return stats end
    end
    return {}
  end

  local function monDisplayRows(game, mons, state, deriveStats)
    local rows = {}
    for index, mon in ipairs(mons or {}) do
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local stats = displayStats(game, mon, deriveStats)
      local maxHP = stats.hp
      local shownHP = state and state.heal and state.heal.mon == mon
        and math.floor(state.heal.shown or state.heal.from or mon.hp or 0)
        or math.min(tonumber(mon.hp) or maxHP or 0, maxHP or math.huge)
      local status = shownHP <= 0 and "FNT" or mon.status
      local value
      if state and state.tmhm and state.tmhm.move then
        local able = false
        for _, moveId in ipairs(def and def.tmhm or {}) do
          if moveId == state.tmhm.move then able = true break end
        end
        value = able and Strings("ABLE") or Strings("NOT ABLE")
      else
        value = (mon.level and ("Lv %d"):format(mon.level) or "")
          .. (maxHP and ("  %d/%d"):format(shownHP, maxHP) or "")
          .. (status and status ~= "" and ("  " .. safeText(status)) or "")
      end
      rows[#rows + 1] = {
        label = mon.nickname or (def and def.name) or mon.species or "POKéMON",
        value = value, source = mon,
        marker = state and (state.swapFrom == index
          or state.softboiledFrom == index) or false,
      }
    end
    if #rows == 0 then
      rows[1] = { label = Strings("No POKéMON!"), enabled = false }
    end
    return rows
  end

  -- The Start menu remains the navigation owner, but an optional companion
  -- card can expose the most frequently checked party facts without opening
  -- Party. Keep it informational: no second cursor or callback is introduced
  -- and the native StartMenu continues to own every transition.
  function mod._gen1ModernSpecialPresenters.drawStartMenuQuickView(
      game, state, viewport, theme, menuLayout)
    if option("startMenuQuickView", false) ~= true
        or layoutStyle(viewport) == "full"
        or not (state and state.screenId == "StartMenu" and menuLayout) then
      return
    end
    local x, y, w, h = presenterRect(viewport)
    if w <= h * 1.20 then return end
    local party = state.party or (game and game.save and game.save.party) or {}
    if type(party) ~= "table" or #party == 0 then return end

    local spacing, colors = theme.spacing, theme.colors
    local gap = spacing.lg
    local rightEdge = menuLayout.x - gap
    local panelX = x + gap
    local availableW = rightEdge - panelX
    if availableW < 220 then return end
    local panelW = math.min(availableW, clamp(w * 0.26, 260, 380))
    local bodyFont = font(fontCache, theme.typography.body)
    local titleFont = font(fontCache, theme.typography.title)
    local captionFont = font(fontCache, theme.typography.caption)
    local rowH = math.max(minimumRowHeight(theme) * 0.78,
      textHeight(bodyFont) + spacing.sm)
    local headerH = textHeight(titleFont) + spacing.md + spacing.sm
    local maxH = math.max(1, h - spacing.lg * 2)
    local overflowH = textHeight(captionFont) + spacing.xs
    local visible = math.min(#party, math.max(1,
      math.floor((maxH - headerH - spacing.lg - overflowH) / rowH)))
    local panelH = math.min(maxH, headerH + visible * rowH + spacing.lg
      + (#party > visible and overflowH or 0))
    local panelY = clamp(menuLayout.y, y + spacing.lg,
      y + h - panelH - spacing.lg)
    local layout = { x = panelX, y = panelY, w = panelW, h = panelH,
      radius = theme.radii.md }

    drawHeader(theme, layout, Strings("PARTY"))
    local valueFont = bodyFont
    love.graphics.setFont(bodyFont)
    for index = 1, visible do
      local mon = party[index]
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local stats = displayStats(game, mon, true)
      local maxHP = tonumber(stats.hp) or tonumber(mon.maxHp) or 0
      local currentHP = tonumber(mon.hp)
      if currentHP == nil then currentHP = maxHP end
      currentHP = clamp(currentHP, 0, math.max(maxHP, currentHP, 1))
      local name = mon.nickname or (def and def.name) or mon.species or "POKEMON"
      local value = (mon.level and ("Lv %d"):format(mon.level) or "")
        .. (maxHP > 0 and ("  %d/%d"):format(currentHP, maxHP) or "")
      local rowY = panelY + headerH + (index - 1) * rowH
      setColor(colors.surfaceRaised or colors.surface)
      love.graphics.rectangle("fill", panelX + spacing.sm, rowY,
        panelW - spacing.sm * 2, rowH - 2, theme.radii.sm)
      local leftX = panelX + spacing.md
      local rightInset = panelX + panelW - spacing.md
      local valueWidth = valueFont:getWidth(value)
      local valueMax = math.max(24, panelW * 0.50 - spacing.sm)
      valueWidth = math.min(valueWidth, valueMax)
      local valueX = rightInset - valueWidth
      local nameMax = math.max(24, valueX - leftX - spacing.sm)
      setColor(colors.text)
      drawFittedText(name, leftX,
        rowY + (rowH - textHeight(bodyFont)) / 2, nameMax, bodyFont)
      setColor(colors.textMuted)
      drawFittedText(value, valueX,
        rowY + (rowH - textHeight(bodyFont)) / 2, valueMax, bodyFont)
    end
    if visible < #party then
      love.graphics.setFont(captionFont)
      setColor(colors.textMuted)
      drawText(Strings("%d more in party", #party - visible),
        panelX + spacing.md,
        panelY + headerH + visible * rowH + spacing.xs)
    end
  end

  local function healthPalette(theme)
    local colors = theme.colors or {}
    local health = colors.health or {}
    return {
      track = health.track or colors.divider or colors.backdrop,
      high = health.high or { 0.18, 0.78, 0.72, 1 },
      medium = health.medium or { 0.96, 0.72, 0.24, 1 },
      low = health.low or { 0.98, 0.47, 0.22, 1 },
      critical = health.critical or { 0.82, 0.40, 0.94, 1 },
    }
  end

  local function healthFillColor(theme, ratio)
    local palette = healthPalette(theme)
    if ratio <= 0.05 then return palette.critical end
    if ratio <= 0.20 then return palette.low end
    if ratio <= 0.50 then return palette.medium end
    return palette.high
  end

  local function drawHPBar(theme, x, y, w, hp, maxHP)
    maxHP = math.max(1, tonumber(maxHP) or 1)
    local ratio = clamp((tonumber(hp) or 0) / maxHP, 0, 1)
    setColor(healthPalette(theme).track)
    love.graphics.rectangle("fill", x, y, w, 8, 4)
    setColor(healthFillColor(theme, ratio))
    love.graphics.rectangle("fill", x, y, math.max(0, w * ratio), 8, 4)
  end

  -- Shared selected-Pokémon detail card for Party and Bill's PC. All data is
  -- read from the current Pokémon/species/move records so total conversions,
  -- sprite packs, added moves, and live party copies remain authoritative.
  local function drawMonDetail(game, mon, x, y, w, h, theme, context)
    local spacing, colors = theme.spacing, theme.colors
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.sm)
    if not mon then
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.textMuted)
      drawTextWrapped(Strings("No POKéMON selected."), x + spacing.lg,
        y + h / 2 - 10, w - spacing.lg * 2, "center")
      return
    end
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species] or {}
    local name = mon.nickname or def.name or mon.species or "POKéMON"
    local compact = h < 250 or w < 360
    local titleFont = font(fontCache, compact and theme.typography.body
      or theme.typography.title)
    local bodyFont = font(fontCache, compact and theme.typography.caption
      or theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local artSize = math.max(54, math.min(compact and 92 or 150,
      h * (compact and 0.42 or 0.48), w * 0.30))
    local artX, artY = x + spacing.md, y + spacing.md
    local sprite = spriteFor(game, mon, def.spriteFront, context or "party")
    if sprite then drawImageFit(sprite, artX, artY, artSize, artSize) end
    local infoX = artX + artSize + spacing.md
    local infoW = math.max(32, x + w - spacing.md - infoX)
    love.graphics.setFont(titleFont)
    setColor(colors.text)
    drawText(truncate(name, infoW), infoX, y + spacing.md)
    love.graphics.setFont(captionFont)
    setColor(colors.textMuted)
    local speciesName = def.name and def.name ~= name and def.name or nil
    local level = mon.level and ("Lv %d"):format(mon.level) or ""
    local types = {}
    for _, value in ipairs(def.types or {}) do types[#types + 1] = displayType(value) end
    drawFittedText(table.concat({ level, speciesName or "",
      table.concat(types, " / ") }, "  "):gsub("  +", "  "), infoX,
      y + spacing.md + textHeight(titleFont) + spacing.xs, infoW, captionFont)
    local stats = displayStats(game, mon, context == "box")
    local maxHP = stats.hp
    local shownHP = math.min(tonumber(mon.hp) or maxHP or 0,
      maxHP or math.huge)
    if maxHP then
      local barY = y + spacing.md + textHeight(titleFont)
        + textHeight(captionFont) + spacing.md
      drawHPBar(theme, infoX, barY, infoW, shownHP, maxHP)
      drawFittedText(("HP %d/%d%s"):format(shownHP, maxHP,
        mon.status and ("  " .. safeText(mon.status)) or ""), infoX, barY + 12,
        infoW, captionFont)
    end

    local lowerY = y + math.max(artSize + spacing.md * 2,
      textHeight(titleFont) + textHeight(captionFont) * 2 + spacing.xl * 2)
    local lowerH = math.max(1, y + h - spacing.md - lowerY)
    love.graphics.setFont(bodyFont)
    local statText = {
      ("ATK %s"):format(safeText(stats.attack or "—")),
      ("DEF %s"):format(safeText(stats.defense or "—")),
      ("SPD %s"):format(safeText(stats.speed or "—")),
      ("SPC %s"):format(safeText(stats.special or "—")),
    }
    setColor(colors.textMuted)
    local statWidth = math.max(20, (w - spacing.md * 2 - spacing.sm * 3) / 4)
    for index, value in ipairs(statText) do
      drawFittedText(value,
        x + spacing.md + (index - 1) * (statWidth + spacing.sm), lowerY,
        statWidth, bodyFont)
    end
    local movesY = lowerY + textHeight(bodyFont) + spacing.sm
    local moves = mon.moves or {}
    local available = math.max(1, math.floor((lowerH - textHeight(bodyFont) - spacing.sm)
      / math.max(1, textHeight(bodyFont) + spacing.xs)))
    local count = math.min(#moves, 4, available)
    for index = 1, count do
      local move = moves[index]
      local moveDef = move and game.data and game.data.moves and game.data.moves[move.id]
      local moveName = moveDef and moveDef.name or move and move.id or "—"
      local pp = move and moveDef and ("PP %d/%d"):format(move.pp or 0,
        maxMovePP(move, moveDef)) or ""
      setColor(colors.text)
      setColor(colors.textMuted)
      local ppWidth = bodyFont:getWidth(pp)
      local moveX = x + spacing.md
      local moveMax = math.max(20, x + w - spacing.md - ppWidth
        - spacing.sm - moveX)
      setColor(colors.text)
      drawFittedText(moveName, moveX,
        movesY + (index - 1) * (textHeight(bodyFont) + spacing.xs),
        moveMax, bodyFont)
      setColor(colors.textMuted)
      drawText(pp, x + w - spacing.md - ppWidth,
        movesY + (index - 1) * (textHeight(bodyFont) + spacing.xs))
    end
    if #moves == 0 then
      setColor(colors.textMuted)
      drawText(Strings("No moves."), x + spacing.md, movesY)
    end
  end

  local function drawParty(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local party = state.party or (game.save and game.save.party) or {}
    local rows = monDisplayRows(game, party, state)
    local selected = clamp(state.index or 1, 1, math.max(1, #party))
    local minimal = option("minimalUi", false) == true
    local partyTitle = #party <= 6 and Strings("POKéMON  %d/6", #party)
      or Strings("POKéMON  %d", #party)
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 980))
    panelW = math.min(panelW, scaledPanelWidth(theme, 760))
    if minimal then
      local footer = Strings("A  choose   B  back")
      panelW = math.min(panelW, contentWidthFor(theme, rows, partyTitle,
        footer, math.min(250, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 680), w - gutter * 2)))
    end
    local landscape = w > h * 1.20
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local rowHeight = minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 6))
    local desiredListH = desiredRows * rowHeight
    local detailBody = font(fontCache, theme.typography.body)
    local detailMinH = math.max(220,
      170 + textHeight(detailBody) * 5 + spacing.sm * 5)
    local desiredContentH = minimal and desiredListH
      or landscape and math.max(desiredListH, detailMinH)
      or detailMinH + spacing.sm + desiredListH
    local compactH = headerH + footerH + desiredListH + spacing.lg * 2
    local richH = headerH + footerH + desiredContentH
    local panelH = math.min(h - gutter * 2, minimal and compactH or richH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local contentY = py + headerH
    local contentH = math.max(1, panelH - headerH - footerH)
    local detailW = not minimal and landscape and math.min(panelW * 0.48, 470) or 0
    local detailH = not minimal and not landscape
      and math.min(detailMinH, math.max(1, contentH - spacing.sm - rowHeight)) or 0
    local listX = px
    local listY = contentY + (detailH > 0 and detailH + spacing.sm or 0)
    local listW = panelW - (detailW > 0 and detailW + spacing.sm or 0)
    local listH = math.max(1, contentH - (detailH > 0 and detailH + spacing.sm or 0))
    rowHeight = math.max(minimumRowHeight(theme),
      math.min(theme.density.rowHeight,
        math.max(38, listH / math.max(1, #rows))))
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp((state.scroll or 0), 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md },
      partyTitle)
    local listLayout = { x = listX, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false,
      pointerSelectionField = "index" }
    drawRows(theme, listLayout, rows, selected, scroll, game)
    if detailW > 0 then
      drawMonDetail(game, party[selected], px + panelW - detailW,
        contentY, detailW, contentH, theme, "party")
    elseif detailH > 0 then
      drawMonDetail(game, party[selected], px + spacing.sm, contentY,
        panelW - spacing.sm * 2, detailH, theme, "party")
    end
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    local footer = nil
    if type(state.bottomMessage) == "function" then
      local ok, result = pcall(state.bottomMessage, state)
      if ok then footer = result end
    end
    drawHintIfUseful(theme, footer or Strings("A  choose   B  back"), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)

    -- PartyMenu owns its injected action list internally rather than pushing
    -- another state. Draw those exact live rows as a visual modal; callbacks,
    -- selection, and cancellation remain with PartyMenu.
    if state.submenu and type(state.subItems) == "table" then
      drawModalScrim(theme, viewport)
      local vx, vy, vw, vh = presenterRect(viewport)
      registerPointerRegion(vx, vy, vw, vh, {
        role = "scrim", modalBlocker = true, interactive = true,
        dragHandle = false,
      })
      local actionRows = {}
      for _, item in ipairs(state.subItems) do
        actionRows[#actionRows + 1] = { label = item.label or "", source = item }
      end
      local actionHeader = theme.typography.title + spacing.lg
      local actionRowH = 44
      local actionH = math.min(panelH * 0.72,
        actionHeader + #actionRows * actionRowH + spacing.lg)
      local actionW = math.min(420, panelW * 0.62)
      local ax, ay = px + (panelW - actionW) / 2, py + (panelH - actionH) / 2
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", ax, ay, actionW, actionH, theme.radii.md)
      if pointerDrawContext then pointerDrawContext.modalOwner = state.submenu end
      drawHeader(theme, { x = ax, y = ay, w = actionW, h = actionH, radius = theme.radii.md },
        Strings("POKéMON ACTIONS"), colors.surfaceRaised)
      local actionVisible = math.max(1, math.min(#actionRows,
        math.floor((actionH - actionHeader) / actionRowH)))
      local actionSelected = clamp(state.subIndex or 1, 1,
        math.max(1, #actionRows))
      local actionScroll = clamp(actionSelected - actionVisible, 0,
        math.max(0, #actionRows - actionVisible))
      drawRows(theme, { x = ax, y = ay, w = actionW, h = actionH,
        rowHeight = actionRowH, header = actionHeader,
        footer = 0, visible = actionVisible, radius = theme.radii.sm,
        pointerSelectionField = "subIndex" },
        actionRows, actionSelected, actionScroll, game)
      if pointerDrawContext then pointerDrawContext.modalOwner = nil end
    end
    love.graphics.pop()
  end

  local function drawBoxPokemonList(game, state, viewport, theme)
    local mons, action = boxPokemonList(state)
    if not mons then return end
    local rows = monDisplayRows(game, mons, nil, true)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local minimal = option("minimalUi", false) == true
    local boxTitle = state.title or Strings("PC BOX")
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 980))
    if minimal then
      local footer = action == "RELEASE" and "A  release    B  back"
        or Strings("A  %s / stats    B  back", (action or "choose"):lower())
      panelW = math.min(panelW, contentWidthFor(theme, rows, boxTitle,
        footer, math.min(250, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 760), w - gutter * 2)))
    end
    local compactH = theme.typography.title + theme.typography.caption
      + math.min(#rows, 6) * minimumRowHeight(theme)
      + spacing.lg * 3
    local richH = scaledPanelHeight(theme, w > h * 1.20, 520, 640)
    local panelH = math.min(h - gutter * 2, minimal and compactH or richH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    if minimal then
      for _, row in ipairs(rows) do row.source = nil end
    end
    local landscape = panelW > panelH * 1.15
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local contentY, contentH = py + headerH, panelH - headerH - footerH
    local detailW = not minimal and landscape and math.min(panelW * 0.46, 450) or 0
    local detailH = not minimal and not landscape and math.min(contentH * 0.38, 280) or 0
    local listY = contentY + (detailH > 0 and detailH + spacing.sm or 0)
    local listW = panelW - (detailW > 0 and detailW + spacing.sm or 0)
    local listH = math.max(1, contentH - (detailH > 0 and detailH + spacing.sm or 0))
    local selected = clamp(state.index or 1, 1, math.max(1, #mons))
    local rowHeight = minimumRowHeight(theme)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp(state.scroll or 0, 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end
    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md },
      boxTitle)
    local save = game.save or {}
    local box = save.boxes and save.boxes[save.currentBox or 1] or {}
    local context = action == "DEPOSIT"
      and Strings("BOX %d  %d/20", save.currentBox or 1, #box)
      or Strings("PARTY  %d/6", #(save.party or {}))
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.textMuted)
    local contextW = love.graphics.getFont():getWidth(context)
    local titleW = font(fontCache, theme.typography.title):getWidth(
      safeText(state.title or Strings("PC BOX")))
    if titleW + contextW + spacing.lg * 3 < panelW then
      drawText(context, px + panelW - spacing.lg - contextW,
        py + spacing.md + 5)
    end
    drawRows(theme, { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm }, rows, selected, scroll, game)
    if detailW > 0 then
      drawMonDetail(game, mons[selected], px + panelW - detailW,
        contentY, detailW, contentH, theme, "box")
    elseif detailH > 0 then
      drawMonDetail(game, mons[selected], px + spacing.sm, contentY,
        panelW - spacing.sm * 2, detailH, theme, "box")
    end
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    local hint = action == "RELEASE" and "A  release    B  back"
      or Strings("A  %s / stats    B  back", (action or "choose"):lower())
    drawHintIfUseful(theme, hint,
      px + spacing.lg, py + panelH - footerH + spacing.xs,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function drawPokedex(game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, "pokedex")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 920))
    panelW = math.min(panelW, scaledPanelWidth(theme, 760))
    local landscape = w > h * 1.05
    local headerH = theme.typography.title + spacing.lg
    local footerH = landscape and (theme.typography.caption + spacing.lg)
      or (theme.typography.caption * 2 + spacing.lg + spacing.xs)
    local rowHeight = minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 6))
    local desiredListH = desiredRows * rowHeight
    local previewBody = font(fontCache, theme.typography.body)
    local previewCaption = font(fontCache, theme.typography.caption)
    local desiredPreviewH = math.max(190,
      textHeight(previewBody) + textHeight(previewCaption) * 3
        + spacing.lg * 4 + 110)
    local desiredContentH = landscape and math.max(desiredListH, desiredPreviewH)
      or desiredPreviewH + spacing.sm + desiredListH
    local panelH = math.min(h - gutter * 2,
      headerH + footerH + desiredContentH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local previewW = landscape and math.min(panelW * 0.38, 330) or panelW
    local previewH = landscape and desiredContentH or desiredPreviewH
    local listW = landscape and (panelW - previewW - spacing.sm) or panelW
    local listY = landscape and (py + headerH) or (py + headerH + previewH + spacing.sm)
    local listH = math.max(1, py + panelH - footerH - listY)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

    local previewX = landscape and (px + panelW - previewW) or px
    local previewY = py + headerH
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", previewX + spacing.sm, previewY,
      previewW - spacing.sm * 2, previewH, theme.radii.sm)
    local row = selectedListRow(rows, selected)
    local source = row and row.source
    local species = source and source.value
    local def = species and game.data and game.data.pokemon and game.data.pokemon[species]
    if def then
      local sprite = spriteFor(game, { species = species }, def.spriteFront, "dex")
      local artSize = landscape and math.min(previewW - spacing.lg * 2,
        previewH * 0.50) or math.min(previewH - spacing.md * 2, previewW * 0.24)
      local artX = previewX + spacing.lg
      local artY = previewY + spacing.md
      if sprite then drawImageFit(sprite, artX, artY, artSize, artSize) end
      local infoX = landscape and (previewX + spacing.lg)
        or (artX + artSize + spacing.lg)
      local infoY = landscape and (artY + artSize + spacing.sm) or (previewY + spacing.md)
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.text)
      drawFittedText(def.name or species, infoX, infoY,
        previewX + previewW - spacing.lg - infoX, bodyFont)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(colors.textMuted)
      local digits = tonumber(game.data and game.data.constants
        and game.data.constants.dexDigits) or 3
      digits = clamp(math.floor(digits), 1, 8)
      local number = def.dex and ("No. %0" .. digits .. "d"):format(def.dex) or ""
      drawFittedText(number, infoX, infoY + theme.typography.body + spacing.xs,
        previewX + previewW - spacing.lg - infoX, previewCaption)
      local types = def.types or {}
      local typeNames = {}
      for _, value in ipairs(types) do typeNames[#typeNames + 1] = displayType(value) end
      drawFittedText(table.concat(typeNames, " / "), infoX,
        infoY + theme.typography.body + theme.typography.caption + spacing.sm,
        previewX + previewW - spacing.lg - infoX, previewCaption)
      setColor(colors.accent)
      drawFittedText(source.ball and Strings("OWNED") or Strings("SEEN"),
        infoX, infoY + theme.typography.body + theme.typography.caption * 2
          + spacing.md, previewX + previewW - spacing.lg - infoX,
        previewCaption)
    else
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.textMuted)
      drawTextWrapped(Strings("No data for this entry."),
        previewX + spacing.lg, previewY + previewH / 2 - theme.typography.body,
        previewW - spacing.lg * 2, "center")
    end

    local listLayout = { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false }
    drawRows(theme, listLayout, rows, selected, scroll, game)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.textMuted)
    local hint = (state.pageJump and "L/R  page   " or "")
      .. (type(state.onSelectKey) == "function" and "SELECT  view   " or "")
      .. "A  options   B  back"
    if landscape then
      if footerText and footerText ~= "" then hint = footerText .. "    " .. hint end
      drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    else
      if footerText and footerText ~= "" then
        drawHintIfUseful(theme, footerText, px + spacing.lg,
          py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
      end
      drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footerH + spacing.xs + theme.typography.caption + spacing.xs,
        panelW - spacing.lg * 2)
    end
    love.graphics.pop()
  end

  local function itemValueText(itemId, def)
    if not def or def.price == nil then return nil end
    local base = math.max(0, math.floor(tonumber(def.price) or 0))
    local unsellable = def.keyItem == true
      or (type(itemId) == "string" and itemId:find("^HM_")) ~= nil
      or (def.machine and def.machine.kind == "HM")
    local sell = unsellable and "—" or ("¥%d"):format(math.floor(base / 2))
    return Strings("BASE ¥%d   SELL %s", base, sell)
  end

  local function drawBag(game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, "bag")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 900))
    local minimalBag = option("minimalUi", false) == true
    local landscape = w > h * 1.05
    if minimalBag then
      panelW = math.min(panelW, contentWidthFor(theme, rows, title,
        footerText or "A  use   B  back", math.min(250, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 760), w - gutter * 2)))
    else
      local listBudget = contentWidthFor(theme, rows, title,
        footerText or "A  use   B  back", math.min(300, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 560), w - gutter * 2))
      local detailBudget = landscape
        and math.min(scaledPanelWidth(theme, 360), w - gutter * 2) or 0
      panelW = math.min(panelW, listBudget + detailBudget
        + (detailBudget > 0 and spacing.sm or 0))
    end
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local rowHeight = minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 7))
    local desiredListH = desiredRows * rowHeight
    local detailMinH = math.max(160,
      theme.typography.body + theme.typography.caption * 4 + spacing.lg * 3)
    local detailW = minimalBag and 0
      or landscape and math.min(panelW * 0.44, scaledPanelWidth(theme, 360))
      or panelW
    local previewSelected = clamp(selected or 1, 1, math.max(1, #rows))
    local previewRow = selectedListRow(rows, previewSelected)
    local previewSource = previewRow and previewRow.source
    local previewItemId = previewSource and previewSource.value
    local previewDef = previewItemId and game.data and game.data.items
      and game.data.items[previewItemId]
    local previewIcon = imageFor(imageCandidate(previewSource)
      or imageCandidate(previewDef))
    local previewIconSize = previewIcon and 64 or 0
    local previewCardW = detailW > 0 and detailW or panelW
    local previewInfoW = math.max(24, previewCardW - spacing.lg * 2
      - (previewIconSize > 0 and previewIconSize + spacing.md or 0))
    local detailBodyFont = font(fontCache, theme.typography.body)
    local detailFont = font(fontCache, theme.typography.caption)
    local detailLineGap = textHeight(detailFont) + spacing.xs
    local detailTitleLines = #wrappedLines(previewRow and previewRow.label
      or Strings("ITEM"), previewInfoW, detailBodyFont)
    local detailLines = 0
    local function countDetail(text)
      if text and text ~= "" then
        detailLines = detailLines + #wrappedLines(text, previewInfoW, detailFont)
      end
    end
    if previewSource and previewSource.machineMoveName then
      countDetail(previewSource.machineMoveName)
      if previewDef and previewDef.machine then
        local move = game.data.moves and game.data.moves[previewDef.machine.move]
        if move then
          countDetail(Strings("TYPE %s   PP %s", move.type or "â€”", move.pp or "â€”"))
        end
      end
      countDetail(itemValueText(previewItemId, previewDef))
    elseif previewDef and previewDef.machine then
      local move = game.data.moves and game.data.moves[previewDef.machine.move]
      countDetail(Strings("%s  %s", previewDef.machine.kind or "TM",
        move and move.name or previewDef.machine.move))
      if move then
        countDetail(Strings("TYPE %s   PP %s", move.type or "â€”", move.pp or "â€”"))
      end
      countDetail(itemValueText(previewItemId, previewDef))
    elseif previewDef then
      if previewDef.keyItem then
        countDetail(Strings("KEY ITEM"))
        countDetail(itemValueText(previewItemId, previewDef))
      else
        countDetail(itemValueText(previewItemId, previewDef) or Strings("ITEM"))
      end
      countDetail(previewDef.description or previewDef.desc or previewDef.effectText)
    else
      countDetail(Strings("Select an item."))
    end
    if detailLines > 0 then
      detailMinH = math.max(detailMinH,
        spacing.md + detailTitleLines * textHeight(detailBodyFont) + spacing.sm
          + detailLines * detailLineGap + spacing.md)
    end
    local desiredContentH = minimalBag and desiredListH
      or landscape and math.max(desiredListH, detailMinH)
      or detailMinH + spacing.sm + desiredListH
    local compactBagH = headerH + footerH + desiredListH + spacing.lg * 2
    local panelH = math.min(h - gutter * 2,
      minimalBag and compactBagH or headerH + footerH + desiredContentH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local minimal = minimalBag
    local detailH = minimal and 0
      or landscape and (panelH - headerH - footerH)
      or math.min(detailMinH, math.max(1, panelH - headerH - footerH
        - spacing.sm - rowHeight))
    local listW = landscape and (panelW - detailW - spacing.sm) or panelW
    local listY = (landscape or minimal) and (py + headerH)
      or (py + headerH + detailH + spacing.sm)
    local listH = math.max(1, py + panelH - footerH - listY)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

    if detailW > 0 and detailH > 0 then
      wrapFittedText = true
      local detailX = landscape and (px + panelW - detailW) or px
      local detailY = py + headerH
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", detailX + spacing.sm, detailY,
        detailW - spacing.sm * 2, detailH, theme.radii.sm)
      local row = selectedListRow(rows, selected)
      local source = row and row.source
      local itemId = source and source.value
      local def = itemId and game.data and game.data.items and game.data.items[itemId]
      local itemName = row and row.label or Strings("ITEM")
      local icon = imageFor(imageCandidate(source) or imageCandidate(def))
      local iconSize = icon and math.min(64, detailH - spacing.md * 2) or 0
      local infoX = detailX + spacing.lg
      if icon then
        drawImageFit(icon, infoX, detailY + spacing.md, iconSize, iconSize)
        infoX = infoX + iconSize + spacing.md
      end
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.text)
      local titleBottom = drawWrappedText(itemName, infoX, detailY + spacing.md,
        detailX + detailW - spacing.lg - infoX,
        font(fontCache, theme.typography.body), theme.typography.body + spacing.xs)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      local infoY = titleBottom + spacing.sm
      local detailFont = love.graphics.getFont()
      local detailMax = math.max(24, detailX + detailW - spacing.lg - infoX)
      setColor(colors.textMuted)
      if source and source.machineMoveName then
      infoY = drawWrappedText(source.machineMoveName, infoX, infoY, detailMax,
        detailFont, theme.typography.caption + spacing.xs)
      if def and def.machine then
        local move = game.data.moves and game.data.moves[def.machine.move]
        if move then
          drawFittedText(Strings("TYPE %s   PP %s", move.type or "—", move.pp or "—"),
            infoX, infoY + theme.typography.caption + spacing.xs,
            detailMax, detailFont)
        end
      end
      local value = itemValueText(itemId, def)
      if value then
        drawFittedText(value, infoX,
          infoY + (theme.typography.caption + spacing.xs) * 2,
          detailMax, detailFont)
      end
    elseif def and def.machine then
      local move = game.data.moves and game.data.moves[def.machine.move]
      drawFittedText(Strings("%s  %s", def.machine.kind or "TM",
        move and move.name or def.machine.move), infoX, infoY, detailMax,
        detailFont)
      if move then
        drawFittedText(Strings("TYPE %s   PP %s", move.type or "—", move.pp or "—"),
          infoX, infoY + theme.typography.caption + spacing.xs,
          detailMax, detailFont)
      end
      local value = itemValueText(itemId, def)
      if value then
        drawFittedText(value, infoX,
          infoY + (theme.typography.caption + spacing.xs) * 2,
          detailMax, detailFont)
      end
    elseif def then
      local descriptionY = infoY + theme.typography.caption + spacing.xs
      if def.keyItem then
        drawFittedText(Strings("KEY ITEM"), infoX, infoY, detailMax, detailFont)
        local value = itemValueText(itemId, def)
        if value then
          drawFittedText(value, infoX, descriptionY, detailMax, detailFont)
          descriptionY = descriptionY + theme.typography.caption + spacing.xs
        end
      else
        drawFittedText(itemValueText(itemId, def) or Strings("ITEM"),
          infoX, infoY, detailMax, detailFont)
      end
      local description = def.description or def.desc or def.effectText
      if description then
        drawFittedText(description, infoX, descriptionY, detailMax, detailFont)
      end
      else
        drawFittedText(Strings("Select an item."), infoX, infoY, detailMax, detailFont)
      end
    end
    wrapFittedText = false

    local listLayout = { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false }
    drawRows(theme, listLayout, rows, selected, scroll, game)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.textMuted)
    local hint = type(state.modernBag) == "table"
      and "LEFT/RIGHT  pocket   A  use   B  back"
      or "A  use   SELECT  move   B  back"
    if footerText and footerText ~= "" then hint = footerText .. "    " .. hint end
    drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function drawContextList(game, state, kind, viewport, theme)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, kind)
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 900))
    local minimalContext = option("minimalUi", false) == true
    local landscape = w > h * 1.10
    if minimalContext then
      panelW = math.min(panelW, contentWidthFor(theme, rows, title,
        footerText or "A  choose   B  back", math.min(250, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 760), w - gutter * 2)))
    else
      local listBudget = contentWidthFor(theme, rows, title,
        footerText or "A  choose   B  back", math.min(300, w - gutter * 2),
        math.min(scaledPanelWidth(theme, 560), w - gutter * 2))
      local detailBudget = landscape
        and math.min(scaledPanelWidth(theme, 360), w - gutter * 2) or 0
      panelW = math.min(panelW, listBudget + detailBudget
        + (detailBudget > 0 and spacing.sm or 0))
    end
    local headerH = theme.typography.title + spacing.lg
    local messageH = math.max(72, theme.typography.caption * 2 + spacing.lg * 2)
    local rowHeight = minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 8))
    local desiredListH = desiredRows * rowHeight
    local detailMinH = math.max(150,
      theme.typography.body + theme.typography.caption * 4 + spacing.lg * 3)
    local detailW = not minimalContext and landscape
      and math.min(panelW * 0.44, scaledPanelWidth(theme, 360)) or 0
    local previewSelected = clamp(selected or 1, 1, math.max(1, #rows))
    local previewRow = selectedListRow(rows, previewSelected)
    local previewSource = previewRow and previewRow.source
    local previewItemId = previewSource
      and type(previewSource.value) == "string" and previewSource.value or nil
    local previewDef = previewItemId and game.data and game.data.items
      and game.data.items[previewItemId]
    local previewIcon = imageFor(imageCandidate(previewSource)
      or imageCandidate(previewDef))
    local previewIconSize = previewIcon and 56 or 0
    local previewCardW = detailW > 0 and detailW or panelW
    local previewInfoW = math.max(24, previewCardW - spacing.lg * 2
      - (previewIconSize > 0 and previewIconSize + spacing.md or 0))
    local detailTitleFont = font(fontCache, theme.typography.body)
    local detailTitleLines = #wrappedLines(
      previewRow and previewRow.label or Strings("ITEM"), previewInfoW,
      detailTitleFont)
    local detailFont = font(fontCache, theme.typography.caption)
    local detailLineGap = textHeight(detailFont) + spacing.xs
    local detailLines = 0
    local previewOwnedText
    if kind == "shop_list" and previewItemId
        and game.save and type(game.save.inventory) == "table" then
      local quantity = math.max(0, math.floor(
        tonumber(game.save.inventory[previewItemId]) or 0))
      previewOwnedText = Strings("HAVE x%d", quantity)
    end
    local function countDetail(text)
      if text and text ~= "" then
        detailLines = detailLines + #wrappedLines(text, previewInfoW, detailFont)
      end
    end
    if previewSource and previewSource.right then countDetail(previewSource.right) end
    countDetail(previewOwnedText)
    if previewDef and previewDef.machine then
      local move = game.data.moves and game.data.moves[previewDef.machine.move]
      countDetail(Strings("%s  %s", previewDef.machine.kind or "TM",
        move and move.name or previewDef.machine.move))
      if move then
        countDetail(Strings("TYPE %s   PP %s", move.type or "â€”", move.pp or "â€”"))
      end
    elseif previewDef and previewDef.keyItem then
      countDetail(Strings("KEY ITEM"))
    end
    countDetail(itemValueText(previewItemId, previewDef))
    if detailLines > 0 then
      detailMinH = math.max(detailMinH,
        spacing.md + detailTitleLines * textHeight(detailTitleFont) + spacing.sm
          + detailLines * detailLineGap + spacing.md)
    end
    local desiredContentH = minimalContext and desiredListH
      or landscape and math.max(desiredListH, detailMinH)
      or detailMinH + spacing.sm + desiredListH
    local compactContextH = headerH + messageH + desiredListH + spacing.lg * 2
    local panelH = math.min(h - gutter * 2,
      minimalContext and compactContextH
        or headerH + messageH + desiredContentH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local minimal = minimalContext
    local detailH = not minimal and not landscape
      and math.min(detailMinH, math.max(1, panelH - headerH - messageH
        - spacing.sm - rowHeight)) or 0
    local listW = panelW - detailW - (detailW > 0 and spacing.sm or 0)
    local listY = py + headerH + (detailH > 0 and detailH + spacing.sm or 0)
    local listH = math.max(1, py + panelH - messageH - listY)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

    if kind == "shop_list" and type(state.money) == "function" then
      local ok, money = pcall(state.money)
      if ok and money ~= nil then
        local amount = ("¥%d"):format(money)
        love.graphics.setFont(font(fontCache, theme.typography.body))
        local amountW = love.graphics.getFont():getWidth(amount)
        setColor(colors.surfaceRaised)
        love.graphics.rectangle("fill", px + panelW - spacing.lg - amountW -
          spacing.md * 2, py + spacing.sm, amountW + spacing.md * 2,
          theme.typography.body + spacing.sm * 2, theme.radii.sm)
        setColor(colors.text)
        drawText(amount, px + panelW - spacing.lg - amountW - spacing.md,
          py + spacing.sm * 1.5)
      end
    end

    local listLayout = { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false }
    drawRows(theme, listLayout, rows, selected, scroll, game)

    if detailW > 0 or detailH > 0 then
      local detailX = detailW > 0 and (px + panelW - detailW) or px
      local detailY = py + headerH
      local cardW = detailW > 0 and detailW or panelW
      local cardH = detailW > 0 and listH or detailH
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", detailX + spacing.sm, detailY,
        cardW - spacing.sm * 2, cardH, theme.radii.sm)
      local row = selectedListRow(rows, selected)
      local source = row and row.source
      local itemId = source and type(source.value) == "string" and source.value or nil
      local def = itemId and game.data and game.data.items and game.data.items[itemId]
      local icon = imageFor(imageCandidate(source) or imageCandidate(def))
      local iconSize = icon and math.min(56, cardH - spacing.md * 2) or 0
      local infoX = detailX + spacing.lg
      if icon then
        drawImageFit(icon, infoX, detailY + spacing.md, iconSize, iconSize)
        infoX = infoX + iconSize + spacing.md
      end
      local infoW = math.max(24, detailX + cardW - spacing.lg - infoX)
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.text)
      local titleBottom = drawWrappedText(row and row.label or Strings("ITEM"),
        infoX, detailY + spacing.md, infoW,
        font(fontCache, theme.typography.body),
        theme.typography.body + spacing.xs)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(colors.textMuted)
      local infoY = titleBottom + spacing.sm
      local detailFont = love.graphics.getFont()
      local detailMax = math.max(24, detailX + cardW - spacing.lg - infoX)
      local ownedText
      if kind == "shop_list" and itemId
          and game.save and type(game.save.inventory) == "table" then
        local quantity = math.max(0, math.floor(
          tonumber(game.save.inventory[itemId]) or 0))
        ownedText = Strings("HAVE x%d", quantity)
      end
      if source and source.right then
        infoY = drawWrappedText(source.right, infoX, infoY, detailMax,
          detailFont, theme.typography.caption + spacing.xs)
      end
      if ownedText then
        infoY = drawWrappedText(ownedText, infoX, infoY, detailMax,
          detailFont, theme.typography.caption + spacing.xs)
      end
      if def and def.machine then
        local move = game.data.moves and game.data.moves[def.machine.move]
        infoY = drawWrappedText(Strings("%s  %s", def.machine.kind or "TM",
          move and move.name or def.machine.move), infoX, infoY, detailMax,
          detailFont, theme.typography.caption + spacing.xs)
        if move then
          infoY = drawWrappedText(Strings("TYPE %s   PP %s",
            move.type or "—", move.pp or "—"), infoX, infoY, detailMax,
            detailFont)
        end
      elseif def and def.keyItem then
        infoY = drawWrappedText(Strings("KEY ITEM"), infoX, infoY, detailMax,
          detailFont, theme.typography.caption + spacing.xs)
      end
      local value = itemValueText(itemId, def)
      if value then
        drawWrappedText(value, infoX, infoY, detailMax, detailFont,
          theme.typography.caption + spacing.xs)
      end
    end

    local messageY = py + panelH - messageH
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", px + spacing.sm, messageY,
      panelW - spacing.sm * 2, messageH - spacing.sm, theme.radii.sm)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.text)
    local messageLines = wrappedLines(footerText or "", panelW - spacing.lg * 2)
    for index = 1, math.min(2, #messageLines) do
      drawText(messageLines[index], px + spacing.lg,
        messageY + spacing.sm + (index - 1) * (theme.typography.caption + spacing.xs))
    end
    setColor(colors.textMuted)
    local hint = kind == "shop_list" and "A  choose   B  back"
      or "A  choose   B  back"
    drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
      py + panelH - spacing.md - theme.typography.caption,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function drawGen3Box(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 780))
    -- The grid itself is the content. Keep a compact square-cell frame
    -- instead of reserving the entire viewport around a 5x4 or 3x2 grid.
    local panelH = math.min(h - gutter * 2,
      scaledPanelHeight(theme, w > h * 1.20, 470, 620))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local mode = state.mode == "party" and "party" or "box"
    local cols, gridRows = mode == "box" and 5 or 3, mode == "box" and 4 or 2
    local list
    if mode == "party" then
      list = game.save and game.save.party or {}
    else
      local boxes = game.save and game.save.boxes or {}
      list = boxes[(game.save and game.save.currentBox) or 1] or {}
    end
    local selected = (state.row or 0) * cols + (state.col or 0) + 1
    local title
    if mode == "box" then
      title = ("PC BOX %d  %d/%d"):format((game.save and game.save.currentBox) or 1,
        #list, 20)
    else
      title = ("PARTY  %d/%d"):format(#list, 6)
    end
    local header = theme.typography.title + spacing.xl + 18
    local footer = theme.typography.caption + spacing.lg + 8
    local pad = spacing.md
    local availableW = math.max(1, panelW - pad * 2)
    local availableH = math.max(1, panelH - header - footer - pad * 2)
    local cellSize = math.max(1, math.min(availableW / cols, availableH / gridRows))
    local gridW, gridH = cellSize * cols, cellSize * gridRows
    local cellW, cellH = cellSize, cellSize
    local gx = px + (panelW - gridW) / 2
    -- A box is read top-to-bottom; centering the whole 5x4 grid vertically
    -- leaves an especially large dead band above it on portrait phones.
    -- Anchor it just below the title and reserve the remaining panel for the
    -- footer/carrying state instead.
    local gy = py + header + pad

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    drawText(title, px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local footerText = state.notice or (mode == "box"
      and "A  pick/place   START  stats   SELECT  party   B  back"
      or "A  pick/place   START  stats   SELECT  box   B  back")
    drawHintIfUseful(theme, Strings(footerText), px + spacing.lg,
      py + panelH - footer + 2, panelW - spacing.lg * 2)

    for i = 1, cols * gridRows do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      local cx, cy = gx + c * cellW, gy + r * cellH
      local mon = list[i]
      registerPointerRegion(cx + 2, cy + 2, cellW - 4, cellH - 4, {
        gridRow = r, gridCol = c, activate = true,
        gridRows = gridRows, gridCols = cols,
        interactive = true, dragHandle = false,
      })
      if i == selected then
        setColor(theme.colors.selected)
      else
        setColor(theme.colors.surfaceRaised or theme.colors.surface)
      end
      love.graphics.rectangle("fill", cx + 2, cy + 2, cellW - 4, cellH - 4,
        theme.radii.sm)
      if mon then
        local img = spriteFor(game, mon)
        -- Small phone cells need a dedicated caption strip.  Keeping the
        -- name/level out of the sprite area prevents short names and the
        -- artwork from colliding when a 5x4 box is squeezed into landscape.
        local captionSize = cellW < 128 and 10 or theme.typography.caption
        local captionFont = font(fontCache, captionSize)
        local cellPad = math.max(3, math.min(spacing.sm, cellW * 0.08))
        local captionH = textHeight(captionFont) + cellPad * 0.8
        local spriteAreaY = cy + cellPad
        local spriteAreaH = math.max(1, cellH - captionH - cellPad * 1.4)
        if img then
          local iw, ih = imageMetrics(img)
          if iw and ih then
            local maxW, maxH = cellW * 0.68, spriteAreaH * 0.92
            local scale = math.min(maxW / iw, maxH / ih)
            setColor({ 1, 1, 1, 1 })
            drawImage(img, cx + (cellW - iw * scale) / 2,
              spriteAreaY + (spriteAreaH - ih * scale) / 2, 0, scale, scale)
          end
        end
        setColor(theme.colors.surface)
        love.graphics.rectangle("fill", cx + 2,
          cy + cellH - captionH - 2, cellW - 4, captionH + 1)
        setColor(theme.colors.text)
        love.graphics.setFont(captionFont)
        local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
        local name = mon.nickname or (def and def.name) or mon.species or "?"
        local level = mon.level and ("Lv " .. tostring(mon.level)) or ""
        local levelW = captionFont:getWidth(level)
        local nameMax = math.max(12, cellW - cellPad * 2 - levelW - cellPad)
        local captionY = cy + cellH - captionH
          + (captionH - textHeight(captionFont)) / 2 - 1
        drawText(truncate(name, nameMax), cx + cellPad, captionY)
        setColor(theme.colors.textMuted)
        if level ~= "" then
          drawText(level, cx + cellW - cellPad - levelW, captionY)
        end
      end
    end
    if state.held and state.held.mon then
      local carried = state.held.mon
      local cardW, cardH = math.min(230, panelW * 0.34), 68
      local cardX = px + panelW - cardW - spacing.lg
      local cardY = py + spacing.sm
      setColor(theme.colors.surfaceRaised or theme.colors.surface)
      love.graphics.rectangle("fill", cardX, cardY, cardW, cardH,
        theme.radii.sm)
      local carriedImage = spriteFor(game, carried)
      if carriedImage then
        local iw, ih = imageMetrics(carriedImage)
        if iw and ih then
          local scale = math.min(48 / iw, 48 / ih)
          setColor({ 1, 1, 1, 1 })
          drawImage(carriedImage, cardX + spacing.sm,
            cardY + (cardH - ih * scale) / 2, 0, scale, scale)
        end
      end
      local def = game.data and game.data.pokemon and
        game.data.pokemon[carried.species]
      local carriedName = carried.nickname or (def and def.name) or
        carried.species or "POKÃ©MON"
      setColor(theme.colors.accent)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      drawText("CARRYING", cardX + 64, cardY + 10)
      setColor(theme.colors.text)
      drawText(truncate(carriedName, cardW - 76),
        cardX + 64, cardY + 32)
    end
    love.graphics.pop()
  end

  local function drawDexEntry(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 780))
    local def = dexDefinition(game, state) or {}
    local species = def.id or state.species or state.speciesId
    if type(species) == "table" then species = species.species or species.id end
    local page = state.view or "data"
    local title = safeText(def.name or "POKÃ©DEX")
    local sprite = spriteFor(game, { species = species }, state.sprite or
      (state.vanilla and state.vanilla.sprite))
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    -- Dex data and base-stat cards are content panels. A responsive scale may
    -- enlarge the type, but it should not make these two-column pages span
    -- most of an ultrawide window.
    panelW = math.min(panelW, scaledPanelWidth(theme,
      page == "moves" and 720 or 620))
    local lineGap = textHeight(bodyFont) + spacing.sm
    local desiredHeroH = math.max(190,
      math.min(250, textHeight(bodyFont) * 4 + spacing.lg * 3 + 70))
    local desiredDetailH = lineGap * 4 + spacing.lg * 2
    local descriptionLines = 1
    local detailWidthEstimate = math.max(80,
      panelW - math.min(240, panelW * 0.34) - spacing.xl - spacing.lg * 2)
    if page == "stats" and state.stats then
      local evolutionLines = 0
      for _, evo in ipairs(state.stats.evolutions or {}) do
        evolutionLines = evolutionLines + #wrappedLines(
          (evo.label or "") .. " " .. (evo.name or ""),
          detailWidthEstimate, bodyFont)
      end
      desiredDetailH = lineGap * math.max(1, #(state.stats.stats or {}) + 1)
        + spacing.md + math.max(1, evolutionLines) * lineGap
        + spacing.lg * 2
    elseif page == "moves" then
      local ok, moveRows = pcall(function() return state:rows() end)
      desiredDetailH = lineGap * math.min(10, #(ok and moveRows or {}))
        + spacing.lg * 2
    else
      local entry = def.dexEntry or {}
      local owned = state.forceOwned or (state.vanilla and state.vanilla.forceOwned)
        or (game.save and game.save.pokedex and game.save.pokedex.owned and
          game.save.pokedex.owned[def.id])
      local text = owned and entry.text and game.data.text and game.data.text[entry.text]
      if text then
        descriptionLines = #wrappedLines(safeText(text):gsub("[\r\n\v\f]+", " "),
          panelW - spacing.lg * 2, bodyFont)
      end
      desiredDetailH = desiredHeroH + spacing.lg
        + math.min(8, descriptionLines) * lineGap + spacing.lg
    end
    local desiredContentH = page == "data"
      and desiredDetailH or math.max(desiredHeroH, desiredDetailH)
    local panelH = math.min(h - gutter * 2,
      textHeight(titleFont) + spacing.xl + 12 + desiredContentH
        + spacing.lg + textHeight(captionFont))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local heroX = px + spacing.lg
    local heroY = py + textHeight(titleFont) + spacing.xl + 12
    local heroW = math.min(240, panelW * 0.34)
    local heroH = math.min(250, desiredHeroH)
    local detailX = heroX + heroW + spacing.xl
    local detailW = math.max(40, panelW - (detailX - px) - spacing.lg)
    local footerY = py + panelH - spacing.lg - textHeight(captionFont) - 4

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText(title, px + spacing.lg, py + spacing.md,
      panelW - spacing.lg * 2, titleFont)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    drawText((page == "stats" and "BASE STATS" or page == "moves" and "MOVES" or
      "DEX DATA"), px + spacing.lg, py + spacing.lg + 32)
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", heroX, heroY, heroW, heroH, theme.radii.md)
    if sprite then
      local iw, ih = imageMetrics(sprite)
      if iw and ih then
        local scale = math.min((heroW - spacing.md * 2) / iw,
          (heroH - spacing.md * 2) / ih)
        setColor({ 1, 1, 1, 1 })
        drawImage(sprite, heroX + (heroW - iw * scale) / 2,
          heroY + (heroH - ih * scale) / 2, 0, scale, scale)
      end
    end
    local tx = detailX
    local maxW = detailW
    setColor(theme.colors.text)
    love.graphics.setFont(bodyFont)
    if page == "stats" and state.stats then
      local stats = state.stats.stats or {}
      local yy = heroY + spacing.md
      for _, stat in ipairs(stats) do
        drawFittedText(("%s  %s"):format(safeText(stat.key), safeText(stat.value)),
          tx, yy, maxW, bodyFont)
        yy = yy + textHeight(bodyFont) + spacing.sm
      end
      drawFittedText("BST  " .. safeText(state.stats.bst), tx, yy + 4,
        maxW, bodyFont)
      yy = yy + textHeight(bodyFont) + spacing.md
      for _, evo in ipairs(state.stats.evolutions or {}) do
        local nextY = drawWrappedText((evo.label or "") .. " "
          .. (evo.name or ""), tx, yy, maxW, bodyFont,
          textHeight(bodyFont) + spacing.xs)
        yy = nextY + spacing.xs
      end
    elseif page == "moves" then
      local ok, moveRows = pcall(function() return state:rows() end)
      local rows = ok and moveRows or {}
      local start = ((state.page or 1) - 1) * 10 + 1
      local lineGap = textHeight(bodyFont) + spacing.sm
      local remaining = math.max(0, #rows - start + 1)
      local requested = math.min(10, remaining)
      -- Keep the footer as a hard layout boundary.  Dex move pages can expose
      -- a tenth row (TM/HM); without reserving this space the final row can
      -- collide with the navigation hint on short landscape displays.
      local contentBottom = footerY - spacing.sm - textHeight(bodyFont)
      if requested > 1 then
        local compressedGap = (contentBottom - heroY) / (requested - 1)
        lineGap = math.min(lineGap, compressedGap)
      end
      lineGap = math.max(textHeight(bodyFont) + 1, lineGap)
      local maxVisible = math.max(1,
        math.floor((contentBottom - heroY) / lineGap) + 1)
      local visible = math.min(10, remaining, maxVisible)
      for offset = 0, visible - 1 do
        local row = rows[start + offset]
        drawWrappedText(row, tx, heroY + offset * lineGap, maxW, bodyFont,
          textHeight(bodyFont) + spacing.xs)
      end
      if visible < requested then
        setColor(theme.colors.textMuted)
        drawText("...", tx,
          footerY - textHeight(captionFont) - spacing.sm)
        setColor(theme.colors.text)
      end
    else
      local entry = def.dexEntry or {}
      drawFittedText("No. " .. safeText(def.dex), tx, heroY + spacing.md,
        maxW, bodyFont)
      drawFittedText(entry.kind, tx,
        heroY + spacing.md + textHeight(bodyFont) + spacing.sm, maxW, bodyFont)
      drawFittedText(entry.heightM and ("HT " .. entry.heightM .. "m") or "",
        tx, heroY + spacing.md + (textHeight(bodyFont) + spacing.sm) * 2,
        maxW, bodyFont)
      drawFittedText(entry.weightKg and ("WT " .. entry.weightKg .. "kg") or "",
        tx, heroY + spacing.md + (textHeight(bodyFont) + spacing.sm) * 3,
        maxW, bodyFont)
      local owned = state.forceOwned or (state.vanilla and state.vanilla.forceOwned)
        or (game.save and game.save.pokedex and game.save.pokedex.owned and
          game.save.pokedex.owned[def.id])
      local text = owned and entry.text and game.data.text and game.data.text[entry.text]
      local descriptionY = heroY + heroH + spacing.lg
      setColor(theme.colors.textMuted)
      if text then
        local lines = wrappedLines(safeText(text):gsub("[\r\n\v\f]+", " "),
          panelW - spacing.lg * 2, bodyFont)
        local lineHeight = textHeight(bodyFont) + spacing.sm
        for i, line in ipairs(lines) do
          local yy = descriptionY + (i - 1) * lineHeight
          if yy > footerY - lineHeight then break end
          drawText(line, px + spacing.lg, yy)
        end
      else
        drawText("Data unknown.", px + spacing.lg, descriptionY)
      end
    end
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    local footer = "A  next page   B  back"
    if page == "moves" and type(state.pages) == "function" then
      local ok, pageCount = pcall(state.pages, state)
      if ok and tonumber(pageCount) and pageCount > 1 then
        footer = "UP/DOWN  page   A  next page   B  back"
      end
    end
    drawHintIfUseful(theme, Strings(footer), px + spacing.lg, footerY,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  mod._gen1ModernSpecialPresenters = mod._gen1ModernSpecialPresenters or {}

  function mod._gen1ModernSpecialPresenters.drawMoveLearn(game, state, viewport, theme)
    if state.selecting ~= true then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local body = font(fontCache, theme.typography.body)
    local titleFont = font(fontCache, theme.typography.title)
    local caption = font(fontCache, theme.typography.caption)
    local moves = state.mon and type(state.mon.moves) == "table"
      and state.mon.moves or {}
    local moveDefs = game.data and game.data.moves or {}
    local rows = {}
    for _, move in ipairs(moves) do
      local moveId = type(move) == "table" and move.id or move
      local def = moveDefs[moveId] or {}
      rows[#rows + 1] = { label = def.name or moveId or "MOVE",
        value = def.type and safeText(def.type) or "" }
    end
    rows[#rows + 1] = { label = Strings("CANCEL"), value = "" }
    local panelW = math.min(w - spacing.lg * 2,
      math.max(320, contentWidthFor(theme, rows, "FORGET A MOVE", nil,
        320, math.min(700, w - spacing.lg * 2))))
    local rowH = math.max(textHeight(body) + spacing.md,
      math.min(62, theme.density.rowHeight * 0.78))
    local headerH = textHeight(titleFont) + textHeight(body) + spacing.xl
    local footerH = textHeight(caption) + spacing.md
    local panelH = math.min(h - spacing.lg * 2,
      headerH + #rows * rowH + footerH + spacing.lg * 2)
    rowH = math.max(textHeight(body) + spacing.sm,
      (panelH - headerH - footerH - spacing.lg * 2) / math.max(1, #rows))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local selected = clamp(state.index or 1, 1, #rows)

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawText("FORGET A MOVE", px + spacing.lg, py + spacing.md)
    local newDef = moveDefs[state.newMoveId] or {}
    setColor(colors.textMuted)
    love.graphics.setFont(body)
    drawFittedText("NEW MOVE  " .. safeText(newDef.name or state.newMoveId),
      px + spacing.lg, py + spacing.md + textHeight(titleFont) + spacing.sm,
      panelW - spacing.lg * 2, body)

    local rowY = py + spacing.lg + headerH
    for index, row in ipairs(rows) do
      local ry = rowY + (index - 1) * rowH
      registerPointerRegion(px + spacing.sm, ry, panelW - spacing.sm * 2,
        rowH - 2, { rowIndex = index, selectionField = "index",
          selectionState = state, rowCount = #rows, activate = true,
          interactive = true, dragHandle = false })
      setColor(index == selected and colors.selected or colors.surfaceRaised)
      love.graphics.rectangle("fill", px + spacing.sm, ry,
        panelW - spacing.sm * 2, rowH - 2, theme.radii.sm)
      setColor(index == selected and colors.text or colors.textMuted)
      love.graphics.setFont(body)
      drawText(safeText(row.label), px + spacing.lg,
        ry + (rowH - textHeight(body)) / 2 - 1)
      if row.value ~= "" then
        local valueW = body:getWidth(row.value)
        drawText(row.value, px + panelW - spacing.lg - valueW,
          ry + (rowH - textHeight(body)) / 2 - 1)
      end
    end
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    drawHintIfUseful(theme, "A  replace   B  cancel", px + spacing.lg,
      py + panelH - footerH + spacing.sm, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawPicBox(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local body = font(fontCache, theme.typography.body)
    local image = imageFor(state.image)
    local caption = safeText(state.text)
    local maxW = math.min(w - spacing.lg * 2, 720)
    local panelW = math.min(maxW, math.max(300,
      body:getWidth(caption) + spacing.lg * 2))
    local artSize = math.min(320, panelW - spacing.lg * 2,
      h * 0.42)
    local captionLines = caption ~= "" and wrappedLines(caption,
      panelW - spacing.lg * 2, body) or {}
    local lineGap = textHeight(body) + spacing.xs
    local panelH = math.min(h - spacing.lg * 2,
      textHeight(titleFont) + artSize + #captionLines * lineGap
        + spacing.lg * 4)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local cardH = math.max(1, panelH - textHeight(titleFont) -
      #captionLines * lineGap - spacing.lg * 3)

    love.graphics.push("all")
    love.graphics.origin()
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    registerPointerRegion(px, py, panelW, panelH, {
      role = "picbox", action = "a", interactive = true, dragHandle = false,
    })
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawText("PICTURE", px + spacing.lg, py + spacing.md)
    local artY = py + textHeight(titleFont) + spacing.lg
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", px + spacing.lg, artY,
      panelW - spacing.lg * 2, cardH, theme.radii.md)
    if image then
      drawImageFit(image, px + spacing.lg, artY,
        panelW - spacing.lg * 2, cardH, 1)
    else
      setColor(colors.textMuted)
      love.graphics.setFont(body)
      drawFittedText("IMAGE UNAVAILABLE", px + spacing.lg,
        artY + (cardH - textHeight(body)) / 2,
        panelW - spacing.lg * 2, body)
    end
    setColor(colors.text)
    love.graphics.setFont(body)
    for index, line in ipairs(captionLines) do
      drawText(line, px + spacing.lg,
        artY + cardH + spacing.md + (index - 1) * lineGap)
    end
    love.graphics.pop()
  end

  -- RBY MMO exposes these as plain local classes, so they cannot share the
  -- engine's TrainerCard/ListMenu presenters. Keep the adapter semantic and
  -- read only the public payload sent by the mod: profile/player for the
  -- card, and client/entries/offset for the leaderboard.
  function mod._gen1ModernSpecialPresenters.drawRbyMmoProfile(
      game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local player = state.player or {}
    local card = type(player.profile) == "table" and player.profile or nil
    local own = player.money ~= nil
    local rows = card and (own and 4 or 3) or 1
    local panelW = panelWidthFor(viewport, w - spacing.lg * 2,
      panelMaxWidth(theme, 760))
    panelW = math.min(panelW, scaledPanelWidth(theme, 720))
    local compact = w > h * 1.15
    local headerH = textHeight(titleFont) + (compact and spacing.md or spacing.lg)
    local footerH = textHeight(captionFont) + (compact and spacing.sm or spacing.md)
    local heroH = compact and 76 or math.max(92, math.min(150, panelW * 0.25))
    local rowH = math.max(textHeight(bodyFont) + spacing.sm,
      compact and 32 or 42)
    local panelH = math.min(h - spacing.lg * 2,
      headerH + heroH + rows * rowH + footerH
        + (compact and spacing.md * 2 or spacing.lg * 3))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local contentX = px + spacing.lg
    local contentW = panelW - spacing.lg * 2

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText("TRAINER PROFILE", contentX, py + spacing.md,
      contentW, titleFont)

    local heroY = py + headerH
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", contentX, heroY, contentW, heroH,
      theme.radii.sm)
    local portrait =
      mod._gen1ModernSpecialPresenters.rbyMmoPortrait(game, player.sprite)
      or paletteRuntime.worldImage(game, player.portrait or player.image or player.icon)
    local artSize = math.min(heroH - spacing.md * 2, 92)
    local artX = contentX + spacing.md
    if portrait then
      mod._gen1ModernSpecialPresenters.drawImageFitRegion(portrait, artX,
        heroY + (heroH - artSize) / 2, artSize, artSize)
    else
      setColor(colors.selected)
      love.graphics.circle("fill", artX + artSize / 2,
        heroY + heroH / 2, artSize * 0.34)
      setColor(colors.text)
      love.graphics.setFont(titleFont)
      local initial = safeText(player.name or "?"):sub(1, 1):upper()
      drawText(initial,
        artX + (artSize - titleFont:getWidth(initial)) / 2,
        heroY + (heroH - textHeight(titleFont)) / 2)
    end
    local infoX = artX + artSize + spacing.md
    local infoW = math.max(24, contentX + contentW - spacing.md - infoX)
    setColor(colors.text)
    love.graphics.setFont(bodyFont)
    drawFittedText(player.name or "UNKNOWN", infoX, heroY + spacing.md,
      infoW, bodyFont)
    local spriteName = safeText(player.sprite or "TRAINER")
      :gsub("_", " "):gsub("^SPRITE%s*", "")
    setColor(colors.textMuted)
    drawFittedText(spriteName, infoX,
      heroY + spacing.md + textHeight(bodyFont) + spacing.xs,
      infoW, bodyFont)
    if not card then
      drawWrappedText(own and "NO SAVE DATA." or "NO CARD SENT.", infoX,
        heroY + spacing.md + textHeight(bodyFont) * 2 + spacing.sm,
        infoW, captionFont, textHeight(captionFont) + spacing.xs)
    end

    local function pair(label, value, row, column)
      local gap = spacing.md
      local colW = (contentW - gap) / 2
      local rx = contentX + (column - 1) * (colW + gap)
      local ry = heroY + heroH + spacing.sm + (row - 1) * rowH
      setColor(colors.textMuted)
      love.graphics.setFont(captionFont)
      drawText(label, rx, ry + spacing.xs)
      setColor(colors.text)
      love.graphics.setFont(bodyFont)
      drawFittedText(value, rx, ry + spacing.xs + textHeight(captionFont),
        colW, bodyFont)
    end

    if card then
      local playtime = math.max(0, tonumber(card.playtime) or 0)
      pair("ID NO", ("%05d"):format(tonumber(card.idNo) or 0), 1, 1)
      pair("TIME", ("%d:%02d"):format(math.floor(playtime / 3600),
        math.floor(playtime / 60) % 60), 1, 2)
      pair("BADGES", tostring(tonumber(card.badges) or 0), 2, 1)
      pair("RANK", tostring(tonumber(player.points) or 0), 2, 2)
      pair("SEEN", tostring(tonumber(card.seen) or 0), 3, 1)
      pair("OWNED", tostring(tonumber(card.owned) or 0), 3, 2)
      if own then
        pair("MONEY", ("Y%d"):format(tonumber(player.money) or 0), 4, 1)
      end
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", contentX,
      py + panelH - footerH, contentW, themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    drawHintIfUseful(theme, "A / B  back", contentX,
      py + panelH - footerH + spacing.xs, contentW)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawRbyMmoRank(
      game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local client = state.client
    local rows = type(state.rows) == "table" and state.rows or nil
    local asked, seen, ranked = false, false, true
    if not rows and client and type(client.ranking) == "function" then
      local ok, result, requested, received = pcall(client.ranking, client)
      if ok then rows, asked, seen = result, requested, received end
    end
    if type(rows) ~= "table" and type(state.entries) == "function" then
      local ok, result = pcall(state.entries, state)
      if ok then rows = result end
    end
    rows = type(rows) == "table" and rows or {}
    if client and type(client.isRanked) == "function" then
      local ok, result = pcall(client.isRanked, client)
      if ok then ranked = result == true end
    elseif state.ranked ~= nil then
      ranked = state.ranked == true
    end
    local visible = 6
    local offset = clamp(math.floor(tonumber(state.offset) or 0), 0,
      math.max(0, #rows - visible))
    local compact = w > h * 1.15
    local panelW = panelWidthFor(viewport, w - spacing.lg * 2,
      panelMaxWidth(theme, 720))
    local headerH = textHeight(titleFont) + (compact and spacing.md or spacing.lg)
    local footerH = textHeight(captionFont) + (compact and spacing.sm or spacing.md)
    local rowH = math.max(textHeight(bodyFont) + spacing.xs,
      compact and 36 or 52)
    local rowCount = math.min(visible, math.max(1, #rows))
    local panelH = math.min(h - spacing.lg * 2,
      headerH + rowCount * rowH + footerH
        + (compact and spacing.md * 2 or spacing.lg * 2))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local contentX = px + spacing.lg
    local contentW = panelW - spacing.lg * 2

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawText("RANK", contentX, py + spacing.md)

    local function emptyMessage()
      if not asked and client then
        return "NOT IN A GAME.\nJOIN ONE FIRST."
      end
      if not ranked then
        return "THAT NAME IS TAKEN ON THIS HUB.\nPICK ANOTHER NAME."
      end
      if not seen and client then return "ASKING THE HUB..." end
      return "NOBODY HAS WON A BATTLE HERE YET."
    end

    if #rows == 0 then
      setColor(colors.textMuted)
      drawWrappedText(emptyMessage(), contentX, py + headerH + spacing.md,
        contentW, bodyFont, textHeight(bodyFont) + spacing.xs)
    else
      for slot = 1, math.min(visible, #rows - offset) do
        local row = rows[offset + slot]
        local ry = py + headerH + (slot - 1) * rowH
        local selected = slot == 1 and offset > 0
        setColor(selected and colors.selected or colors.surfaceRaised)
        love.graphics.rectangle("fill", contentX, ry, contentW, rowH - 3,
          theme.radii.sm)
        local place = tostring(offset + slot)
        local points = tostring(row.points or row.score or 0)
        local name = safeText(row.name or row.player or "UNKNOWN")
        local portrait =
          mod._gen1ModernSpecialPresenters.rbyMmoPortrait(game, row.sprite)
          or paletteRuntime.worldImage(game, row.portrait or row.image or row.icon)
        local artSize = math.max(24, math.min(40, rowH - spacing.sm * 2))
        local artX = contentX + spacing.sm
        if portrait then
          mod._gen1ModernSpecialPresenters.drawImageFitRegion(portrait, artX,
            ry + (rowH - artSize) / 2, artSize, artSize)
        else
          setColor(colors.selected)
          love.graphics.circle("fill", artX + artSize / 2,
            ry + rowH / 2, artSize * 0.34)
        end
        local nameX = artX + artSize + spacing.sm
        local pointsW = bodyFont:getWidth(points)
        local placeW = bodyFont:getWidth(place)
        setColor(selected and colors.text or colors.textMuted)
        love.graphics.setFont(captionFont)
        drawText(place, contentX + spacing.sm, ry + spacing.sm)
        love.graphics.setFont(bodyFont)
        drawFittedText(name, nameX, ry + (rowH - textHeight(bodyFont)) / 2,
          math.max(24, contentX + contentW - spacing.lg - pointsW
            - spacing.md - nameX), bodyFont)
        drawText(points, contentX + contentW - spacing.lg - pointsW,
          ry + (rowH - textHeight(bodyFont)) / 2)
      end
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", contentX,
      py + panelH - footerH, contentW, themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    local footer = (#rows > visible or offset > 0)
      and "UP/DOWN  scroll   A / B  back" or "A / B  back"
    drawHintIfUseful(theme, footer, contentX,
      py + panelH - footerH + spacing.xs, contentW)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawRbyMmoCharacterPick(
      game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, "list")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local landscape = w > h * 1.05
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      panelMaxWidth(theme, 820))
    panelW = math.min(panelW, scaledPanelWidth(theme, 820))
    local headerH = textHeight(titleFont) + spacing.lg
    local footerH = textHeight(captionFont) + spacing.md
    local rowH = minimumRowHeight(theme)
    local detailMinH = math.max(170,
      textHeight(bodyFont) * 2 + 96 + spacing.lg * 3)
    local detailW = landscape
      and math.min(scaledPanelWidth(theme, 330), panelW * 0.42) or 0
    local desiredRows = math.max(1, math.min(#rows, landscape and 8 or 5))
    local desiredListH = desiredRows * rowH
    local desiredContentH = landscape
      and math.max(desiredListH, detailMinH)
      or detailMinH + spacing.sm + desiredListH
    local panelH = math.min(h - gutter * 2,
      headerH + footerH + desiredContentH + spacing.lg * 2)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local detailH = not landscape and math.min(detailMinH,
      math.max(1, panelH - headerH - footerH - spacing.sm - rowH)) or 0
    local listW = panelW - detailW - (detailW > 0 and spacing.sm or 0)
    local listY = py + headerH + (detailH > 0 and detailH + spacing.sm or 0)
    local listH = math.max(1, py + panelH - footerH - listY)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowH)))
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawHeader(theme, { x = px, y = py, w = panelW, h = panelH,
      radius = theme.radii.lg }, title or "CHARACTER")

    local row = selectedListRow(rows, selected)
    local source = row and row.source
    local spriteId = source and (source.value or source.sprite)
    -- Character artwork is authored avatar art, not a map tile/sprite. Do not
    -- tint it with the current overworld palette; that can turn every avatar
    -- into the active route's colors (the native RBY MMO picker has the same
    -- underlying palette confusion on some builds).
    local portrait = mod._gen1ModernSpecialPresenters.rbyMmoPortrait(
      game, spriteId)
    if not portrait then
      portrait = paletteRuntime.setImage(imageFor(source and
        (source.image or source.icon)), nil)
    else
      paletteRuntime.setImage(portrait.image, nil)
    end
    if detailW > 0 or detailH > 0 then
      local detailX = detailW > 0 and (px + panelW - detailW) or px
      local detailY = py + headerH
      local cardW = detailW > 0 and detailW or panelW
      local cardH = detailW > 0 and listH or detailH
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", detailX + spacing.sm, detailY,
        cardW - spacing.sm * 2, cardH, theme.radii.sm)
      local contentX = detailX + spacing.lg
      local contentW = math.max(24, cardW - spacing.lg * 2)
      setColor(colors.text)
      love.graphics.setFont(bodyFont)
      drawFittedText(row and row.label or "CHARACTER", contentX,
        detailY + spacing.md, contentW, bodyFont)
      local artSize = math.max(32, math.min(112,
        cardH - textHeight(bodyFont) - spacing.lg * 3))
      local artX = detailX + (cardW - artSize) / 2
      local artY = detailY + textHeight(bodyFont) + spacing.lg
      if portrait then
        mod._gen1ModernSpecialPresenters.drawImageFitRegion(portrait,
          artX, artY, artSize, artSize)
      else
        setColor(colors.selected)
        love.graphics.circle("fill", artX + artSize / 2,
          artY + artSize / 2, artSize * 0.34)
        setColor(colors.text)
        local initial = safeText(row and row.label or "?"):sub(1, 1):upper()
        love.graphics.setFont(titleFont)
        drawText(initial,
          artX + (artSize - titleFont:getWidth(initial)) / 2,
          artY + (artSize - textHeight(titleFont)) / 2)
      end
      setColor(colors.textMuted)
      love.graphics.setFont(captionFont)
      local spriteName = safeText(spriteId):gsub("^SPRITE_", "")
        :gsub("_", " ")
      drawFittedText(spriteName, contentX,
        detailY + cardH - spacing.lg - textHeight(captionFont),
        contentW, captionFont)
    end

    local listLayout = { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowH, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false }
    drawRows(theme, listLayout, rows, selected, scroll, game)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2,
      themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    drawHintIfUseful(theme, footerText or "A  choose   B  back",
      px + spacing.lg, py + panelH - footerH + spacing.xs,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  mod._gen1ModernSpecialPresenters.namingGridUpper = {
    { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
    { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
    { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
    { "×", "(", ")", ":", ";", "[", "]", "<PK>", "<MN>" },
    { "-", "?", "!", "♂", "♀", "/", ".", ",", "ED" },
    { "1", "2", "3", "4", "5" },
    { "6", "7", "8", "9", "0" },
    { "lower case" },
  }

  function mod._gen1ModernSpecialPresenters.namingGrid(state)
    local source = state and state.grid
    local result
    local function validNamingGrid(grid)
      if type(grid) ~= "table" or #grid == 0 then return false end
      for _, row in ipairs(grid) do
        if type(row) ~= "table" or #row == 0 then return false end
      end
      return true
    end
    if type(source) == "function" then
      local ok, value = pcall(source, state)
      if ok then result = value end
    elseif type(source) == "table" then
      result = source
    elseif type(state and state.gridRows) == "table" then
      result = state.gridRows
    end
    if validNamingGrid(result) then return result end
    if not state or not state.lower then
      return mod._gen1ModernSpecialPresenters.namingGridUpper
    end
    local lower = {}
    for rowIndex, row in ipairs(
        mod._gen1ModernSpecialPresenters.namingGridUpper) do
      lower[rowIndex] = {}
      for colIndex, cell in ipairs(row) do
        lower[rowIndex][colIndex] = cell:lower()
      end
    end
    lower[#lower][1] = "UPPER CASE"
    return lower
  end

  mod.hooks:wrap("ui.naming.grid", function(next, grid, ctxInfo)
    local out = next(grid, ctxInfo)
    -- RBY MMO uses the lower-case flag for its numeric page. Reuse the host's
    -- lower-case base page in that state, then add numbers to it, preserving
    -- both capabilities without requiring a third state in NamingScreen.
    if type(ctxInfo) == "table" and ctxInfo.lower
        and namingGridHasDigit(out) and namingGridHasLowercase(grid) then
      return namingGridWithNumbers(grid)
    end
    return namingGridWithNumbers(out)
  end, 100)

  function mod._gen1ModernSpecialPresenters.drawNaming(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local body = font(fontCache, theme.typography.body)
    local caption = font(fontCache, theme.typography.caption)
    local grid = mod._gen1ModernSpecialPresenters.namingGrid(state)
    local function namingTarget()
      local target = state and (state.mon or state.pokemon or state.targetMon
        or state.subject)
      if type(target) == "table" then
        return safeText(target.nickname or target.name or target.species)
      end
      return safeText(state and (state.targetName or state.monName
        or state.currentName or state.nickname))
    end
    local function namingCellLabel(cell)
      local label = safeText(cell)
      if label == "lower case" then return "lower" end
      if label == "UPPER CASE" then return "UPPER" end
      if label == "<PK>" then return "PK" end
      if label == "<MN>" then return "MN" end
      return label
    end
    local maxCols, maxLabelWidth = 1, 0
    for _, row in ipairs(grid) do
      if type(row) == "table" then
        maxCols = math.max(maxCols, #row)
        for _, cell in ipairs(row) do
          maxLabelWidth = math.max(maxLabelWidth,
            body:getWidth(namingCellLabel(cell)))
        end
      end
    end
    -- Keep the card footprint stable when RBY MMO supplies its compact
    -- uppercase page (seven rows after the numeric rows are inserted) while
    -- the engine's lowercase page has eight. Reserve the common eight-row
    -- rhythm instead of making the panel jump when SELECT changes case.
    local layoutRows = math.max(#grid, 8)
    maxLabelWidth = math.max(maxLabelWidth, body:getWidth("lower case"),
      body:getWidth("UPPER CASE"), body:getWidth("<MN>"))
    local maxLen = math.max(1, tonumber(state.maxLen) or 10)
    local glyphs = type(state.glyphs) == "table" and state.glyphs or {}
    -- NamingScreen treats `default` as a confirm-time fallback. Rename
    -- callers (including Name Rater-style mods) expect it to be the editable
    -- starting value instead, so seed the live glyph buffer once when one is
    -- supplied. This keeps B/delete and the native callback semantics intact.
    if state._gen1ModernNamingSeeded ~= true then
      local seed = state.default or state.initialName or state.currentName
        or state.nickname
      local target = state.mon or state.pokemon or state.targetMon
        or state.subject
      if not seed and type(target) == "table" then
        seed = target.nickname
      end
      if #glyphs == 0 and seed ~= nil and safeText(seed) ~= "" then
        local seedChars = textCharacters(safeText(seed))
        for index = 1, math.min(maxLen, #seedChars) do
          glyphs[index] = seedChars[index]
        end
      end
      state._gen1ModernNamingSeeded = true
    end
    local targetName = namingTarget()
    local currentName = safeText(state.currentName or state.existingName
      or state.default)
    local targetLine = targetName ~= "" and ("FOR  " .. targetName) or ""
    if targetLine == "" and currentName ~= "" then
      targetLine = "CURRENT  " .. currentName
    end
    local availableW = math.max(1, w - spacing.lg * 2)
    local gridFont = body
    local cellW = math.max(body:getWidth("W") + spacing.sm * 2,
      maxLabelWidth + spacing.sm * 2)
    local desiredW = maxCols * cellW + spacing.lg * 2
    if desiredW > availableW then
      gridFont = caption
      maxLabelWidth = 0
      for _, row in ipairs(grid) do
        for _, cell in ipairs(row) do
          maxLabelWidth = math.max(maxLabelWidth,
            gridFont:getWidth(namingCellLabel(cell)))
        end
      end
      cellW = math.max(gridFont:getWidth("W") + spacing.sm * 2,
        maxLabelWidth + spacing.sm * 2)
      desiredW = maxCols * cellW + spacing.lg * 2
    end
    local panelW = math.min(availableW, math.max(420, desiredW))
    cellW = math.max(1, (panelW - spacing.lg * 2) / maxCols)
    local titleH = textHeight(titleFont)
    local targetH = targetLine ~= "" and textHeight(caption) + spacing.xs or 0
    local slotH = math.max(textHeight(body) + spacing.sm, 28)
    local footerH = textHeight(caption) + spacing.md
    local headerH = spacing.lg + titleH + targetH + spacing.sm + slotH
      + spacing.lg
    local desiredCellH = math.max(textHeight(gridFont) + spacing.sm, 36)
    local desiredH = headerH + layoutRows * desiredCellH + footerH + spacing.lg
    local panelH = math.min(h - spacing.lg * 2, desiredH)
    local gridH = math.max(textHeight(gridFont) + 2,
      panelH - headerH - footerH - spacing.lg)
    local cellH = math.max(textHeight(gridFont) + 2,
      gridH / layoutRows)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local title = safeText(state.title or "YOUR NAME?")
    local typedCount = #glyphs
    local counter = ("%d/%d"):format(typedCount, maxLen)

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText(title, px + spacing.lg, py + spacing.md,
      panelW - spacing.lg * 2, titleFont)
    local headerY = py + spacing.md + titleH
    if targetLine ~= "" then
      setColor(colors.textMuted)
      love.graphics.setFont(caption)
      drawFittedText(targetLine, px + spacing.lg, headerY + spacing.xs,
        panelW - spacing.lg * 2, caption)
      headerY = headerY + targetH
    end

    local slotsY = headerY + spacing.sm
    local slotGap = spacing.xs
    local slotW = (panelW - spacing.lg * 2 - (maxLen - 1) * slotGap)
      / maxLen
    local slotFont = body
    if slotW < body:getWidth("W") + spacing.sm * 2 then slotFont = caption end
    for index = 1, maxLen do
      local sx = px + spacing.lg + (index - 1) * (slotW + slotGap)
      setColor(index <= typedCount and colors.selected or colors.surfaceRaised)
      love.graphics.rectangle("fill", sx, slotsY, slotW, slotH,
        theme.radii.sm)
      local glyph = glyphs[index] and safeText(glyphs[index]) or "-"
      setColor(index <= typedCount and colors.text or colors.textMuted)
      love.graphics.setFont(slotFont)
      drawFittedText(glyph, sx + (slotW - slotFont:getWidth(glyph)) / 2,
        slotsY + (slotH - textHeight(slotFont)) / 2, slotW, slotFont)
    end
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    local counterW = caption:getWidth(counter)
    drawText(counter, px + panelW - spacing.lg - counterW,
      slotsY + slotH + spacing.xs)

    local gridY = py + headerH
    for rowIndex, row in ipairs(grid) do
      if type(row) == "table" then
        local isCaseRow = #row == 1
        for colIndex, cell in ipairs(row) do
          local rowW = isCaseRow and (cellW * maxCols) or cellW
          local cx = px + spacing.lg
            + (isCaseRow and 0 or (colIndex - 1) * cellW)
          local cy = gridY + (rowIndex - 1) * cellH
          registerPointerRegion(cx + 1, cy + 1, rowW - 2, cellH - 2, {
            namingRow = rowIndex, namingCol = colIndex,
            activate = true, interactive = true, dragHandle = false,
          })
          local selected = state.row == rowIndex and state.col == colIndex
          setColor(selected and colors.selected or colors.surfaceRaised)
          love.graphics.rectangle("fill", cx + 1, cy + 1,
            rowW - 2, cellH - 2, theme.radii.sm)
          local label = namingCellLabel(cell)
          local renderedLabel = Strings(label)
          local labelW = isCaseRow and rowW - spacing.sm * 2
            or cellW - spacing.xs * 2
          local cellTextFont = gridFont
          if cellTextFont:getWidth(renderedLabel) > labelW
              and caption:getWidth(renderedLabel) <= labelW then
            cellTextFont = caption
          end
          setColor(selected and colors.text or colors.textMuted)
          love.graphics.setFont(cellTextFont)
          drawFittedText(renderedLabel, isCaseRow
            and (cx + (rowW - cellTextFont:getWidth(renderedLabel)) / 2)
            or (cx + spacing.xs),
            cy + (cellH - textHeight(cellTextFont)) / 2,
            isCaseRow and rowW - spacing.sm * 2
              or cellW - spacing.xs * 2, cellTextFont)
        end
      end
    end
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    drawHintIfUseful(theme, "A  choose   B  delete   SELECT  case   START  done",
      px + spacing.lg, py + panelH - footerH + spacing.sm,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.townMapMarker(loc)
    if not loc or not loc.x or not loc.y then return nil end
    return loc.x * 8 + 16, loc.y * 8 + 8
  end

  function mod._gen1ModernSpecialPresenters.rbyMmoExports()
    if type(mod.find) ~= "function" then return nil end
    local ok, handle = pcall(mod.find, "rby_mmo")
    if not ok or type(handle) ~= "table" then return nil end
    return type(handle.exports) == "table" and handle.exports or nil
  end

  function mod._gen1ModernSpecialPresenters.townMapPartyMarkers(state)
    local sources = {
      state.partyMarkers, state.partyMembers, state.partyLocations,
      state.players,
    }
    if type(state.party) == "table" then
      sources[#sources + 1] = state.party.members or state.party
    end
    local byMap = type(state.byMap) == "table" and state.byMap or {}
    local markers, seen, seenIds = {}, {}, {}
    local function add(raw, mapKey)
      if type(raw) ~= "table" then return end
      local location = raw.location or raw.loc or raw.townMap or raw.map
      local mapId = raw.mapId or raw.mapID or raw.locationId
        or raw.townMapId or (type(raw.map) == "string" and raw.map)
        or (type(mapKey) == "string" and mapKey)
      local loc
      if type(location) == "table" then
        loc = location
      elseif type(location) == "string" or type(location) == "number" then
        loc = byMap[location] or byMap[tostring(location)]
      elseif type(mapId) == "string" or type(mapId) == "number" then
        loc = byMap[mapId] or byMap[tostring(mapId)]
      end
      if not loc and raw.x ~= nil and raw.y ~= nil then loc = raw end
      local markerId = raw.id or raw.playerId or raw.userId
      if not loc or loc.x == nil or loc.y == nil or seen[raw]
          or (markerId ~= nil and seenIds[markerId]) then return end
      seen[raw] = true
      if markerId ~= nil then seenIds[markerId] = true end
      local rawSprite = raw.sprite
      local rawImage = raw.image or raw.icon or raw.portrait
      -- Older integrations sometimes put a drawable in `sprite`, while
      -- RBYMMO uses that field for a catalog id. Preserve both shapes.
      if not rawImage and type(rawSprite) ~= "string" then rawImage = rawSprite end
      markers[#markers + 1] = {
        loc = loc, image = rawImage,
        sprite = type(rawSprite) == "string" and rawSprite or nil,
        name = raw.name or raw.playerName or raw.nickname,
        color = raw.color,
      }
    end
    for _, source in ipairs(sources) do
      if type(source) == "table" then
        for key, raw in pairs(source) do add(raw, key) end
      end
    end

    -- RBYMMO deliberately keeps its live party and roster behind public
    -- exports rather than copying them onto TownMap state. Read those
    -- exports when present so the modern presenter does not suppress the
    -- mod's native map marker along with the classic UI. `party()` includes
    -- the local player, while `players()` contains remote roster entries;
    -- intersecting them means only the travelling partner is drawn.
    local exports = mod._gen1ModernSpecialPresenters.rbyMmoExports()
    if exports and type(exports.party) == "function"
        and type(exports.players) == "function" then
      local okParty, party = pcall(exports.party)
      local okPlayers, players = pcall(exports.players)
      if okParty and okPlayers and type(party) == "table"
          and type(players) == "table" then
        local partyIds = {}
        for _, member in ipairs(party) do
          if type(member) == "table" and member.id ~= nil then
            partyIds[member.id] = true
          end
        end
        for _, player in ipairs(players) do
          if type(player) == "table" and player.id ~= nil
              and partyIds[player.id] then
            add({ id = player.id, name = player.name, map = player.map,
              sprite = player.sprite,
              image = player.image or player.icon or player.portrait,
              color = player.color }, player.id)
          end
        end
      end
    end
    return markers
  end

  function mod._gen1ModernSpecialPresenters.drawTownMapBackground(state, x, y, w, h)
    local bg = state.bg
    local fallbackScale = math.min(w / 160, h / 144)
    local fallbackW, fallbackH = 160 * fallbackScale, 144 * fallbackScale
    local fallbackX = x + (w - fallbackW) / 2
    local fallbackY = y + (h - fallbackH) / 2
    if type(bg) ~= "table" or not bg.img or type(bg.map) ~= "table"
        or type(bg.quads) ~= "table" then
      return false, fallbackX, fallbackY, fallbackScale
    end
    local scale = math.min(w / 160, h / 144)
    local mapW, mapH = 160 * scale, 144 * scale
    local ox, oy = x + (w - mapW) / 2, y + (h - mapH) / 2
    prepareImage(bg.img)
    setColor({ 1, 1, 1, 1 })
    -- Drawing every tile directly at a fractional destination lets the
    -- rasterizer round adjacent tile edges differently.  At some scales that
    -- exposes a one-pixel seam between otherwise touching tiles.  Compose the
    -- complete 20x18 map at native pixels first, then scale that one image.
    -- Nearest filtering is already applied by prepareImage and is also set on
    -- the intermediate canvas so the map stays crisp at every UI scale.
    local cache = mod._gen1ModernSpecialPresenters._townMapBackgroundCache
    if type(cache) ~= "table" then
      cache = setmetatable({}, { __mode = "k" })
      mod._gen1ModernSpecialPresenters._townMapBackgroundCache = cache
    end
    local canvas = cache[bg]
    if not canvas and love.graphics.newCanvas then
      local okCanvas, target = pcall(love.graphics.newCanvas, 160, 144)
      if okCanvas and target then
        love.graphics.push("all")
        love.graphics.setCanvas(target)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        for index, tile in ipairs(bg.map) do
          local quad = bg.quads[tile]
          if quad then
            local col = (index - 1) % 20
            local row = math.floor((index - 1) / 20)
            love.graphics.draw(bg.img, quad, col * 8, row * 8)
          end
        end
        love.graphics.setCanvas()
        love.graphics.pop()
        canvas = prepareImage(target)
        cache[bg] = canvas
      end
    end
    if canvas then
      love.graphics.draw(canvas, ox, oy, 0, scale, scale)
    else
      -- Compatibility fallback for older LÖVE builds without canvases.  It
      -- still rounds the tile origins, which avoids the most common hairline
      -- gap while retaining the original renderer's behavior.
      for index, tile in ipairs(bg.map) do
        local quad = bg.quads[tile]
        if quad then
          local col = (index - 1) % 20
          local row = math.floor((index - 1) / 20)
          love.graphics.draw(bg.img, quad,
            math.floor(ox + col * 8 * scale + 0.5),
            math.floor(oy + row * 8 * scale + 0.5), 0, scale, scale)
        end
      end
    end
    return true, ox, oy, scale
  end

  function mod._gen1ModernSpecialPresenters.drawTownMap(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local body = font(fontCache, theme.typography.body)
    local caption = font(fontCache, theme.typography.caption)
    local landscape = w > h * 1.2
    local title = state.fly and "FLY TO" or state.nestSpecies and "AREA" or "TOWN MAP"
    local panelW = math.min(w - spacing.lg * 2,
      landscape and 900 or math.max(340, w - spacing.lg * 2))
    local panelH = math.min(h - spacing.lg * 2, landscape and 650 or 760)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local topH = textHeight(titleFont) + spacing.xl
    local footerH = textHeight(caption) + spacing.md
    local detailW = landscape and math.min(270, panelW * 0.32) or panelW - spacing.lg * 2
    local mapW = landscape and panelW - detailW - spacing.xl * 2
      or panelW - spacing.lg * 2
    local mapH = landscape and panelH - topH - footerH - spacing.lg * 2
      or math.min(mapW * 0.72, panelH - topH - footerH - spacing.lg * 3)
    mapH = math.max(100, mapH)
    local mapX = px + spacing.lg
    local mapY = py + topH
    local locs = type(state.locs) == "table" and state.locs or {}
    local selected = locs[state.sel or 1]
    local partyMarkers =
      mod._gen1ModernSpecialPresenters.townMapPartyMarkers(state)

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawText(title, px + spacing.lg, py + spacing.md)

    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, theme.radii.md)
    local hasMap, mapOriginX, mapOriginY, mapScale =
      mod._gen1ModernSpecialPresenters.drawTownMapBackground(
      state, mapX, mapY, mapW, mapH)
    if not hasMap then
      setColor(colors.surface)
      love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, theme.radii.md)
    end
    if hasMap or state.mode == "grid" then
      -- RBYMMO and similar integrations can expose party members as public
      -- map markers. Draw those before the native location cursor/player dot
      -- so the selected-location indicator remains readable on top.
      for _, marker in ipairs(partyMarkers) do
        local markerX, markerY =
          mod._gen1ModernSpecialPresenters.townMapMarker(marker.loc)
        if markerX and mapScale then
          local cellX = mapOriginX + markerX * mapScale
          local cellY = mapOriginY + markerY * mapScale
          local cellSize = 8 * mapScale
          local image =
            mod._gen1ModernSpecialPresenters.rbyMmoPortrait(game, marker.sprite)
            or paletteRuntime.worldImage(game, marker.image)
          if image then
            mod._gen1ModernSpecialPresenters.drawImageFitRegion(image, cellX,
              cellY, cellSize, cellSize)
          else
            setColor(marker.color or colors.accent)
            love.graphics.circle("fill", cellX + cellSize / 2,
              cellY + cellSize / 2, math.max(2, cellSize * 0.34))
            setColor(colors.text)
            love.graphics.setLineWidth(math.max(1, math.floor(mapScale + 0.5)))
            love.graphics.circle("line", cellX + cellSize / 2,
              cellY + cellSize / 2, math.max(2, cellSize * 0.34))
            love.graphics.setLineWidth(1)
          end
          local markerName = safeText(marker.name)
          if markerName ~= "" then
            local labelH = textHeight(caption) + spacing.xs * 2
            local labelW = math.min(mapW,
              caption:getWidth(markerName) + spacing.sm * 2)
            local labelX = math.max(mapX,
              math.min(mapX + mapW - labelW,
                cellX + cellSize / 2 - labelW / 2))
            local labelY = cellY - labelH - spacing.xs
            if labelY < mapY then labelY = cellY + cellSize + spacing.xs end
            setColor(colors.surface)
            love.graphics.rectangle("fill", labelX, labelY, labelW, labelH,
              theme.radii.xs or theme.radii.sm)
            setColor(colors.text)
            love.graphics.setFont(caption)
            drawFittedText(markerName, labelX + spacing.xs,
              labelY + spacing.xs, labelW - spacing.xs * 2, caption)
          end
        end
      end
      for index, loc in ipairs(locs) do
        local mx, my = mod._gen1ModernSpecialPresenters.townMapMarker(loc)
        if mx and mapScale then
          -- TownMap:markerXY returns the top-left of the location's 8x8
          -- screen cell. Keep the cell origin separate from its center: the
          -- old presenter used the origin as a circle center and then drew a
          -- fixed 18px cursor around it, producing the same small up/left
          -- drift at every UI/window scale.
          local cellX = mapOriginX + mx * mapScale
          local cellY = mapOriginY + my * mapScale
          local cellSize = 8 * mapScale
          local centerX = cellX + cellSize / 2
          local centerY = cellY + cellSize / 2
          registerPointerRegion(cellX, cellY, cellSize, cellSize, {
            selectionState = state, selectionField = "sel",
            selectionIndex = index, rowCount = #locs, activate = true,
            interactive = true, dragHandle = false,
          })
          if index == state.sel then
            -- Use a scale-aware double outline so the selected location reads
            -- against both pale routes and dark map areas, including custom
            -- themes whose accent is intentionally subtle.
            local outline = math.max(1, math.floor(mapScale + 0.5))
            setColor(colors.text)
            love.graphics.setLineWidth(outline + 2)
            love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize)
            setColor(colors.accent)
            love.graphics.setLineWidth(outline)
            love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize)
            love.graphics.setLineWidth(1)
          end
          if state.playerLoc == loc then
            setColor(colors.text)
            love.graphics.circle("fill", centerX, centerY,
              math.max(2, 3 * mapScale))
          end
          if state.nestSpecies and state.nests then
            for _, nest in ipairs(state.nests) do
              if nest == loc then
                setColor(colors.accent)
                love.graphics.circle("fill", centerX, centerY,
                  math.max(2, 4 * mapScale))
              end
            end
          end
        end
      end
    else
      local listY = mapY + spacing.md
      local rowH = math.max(textHeight(body) + spacing.md, 42)
      for index, loc in ipairs(locs) do
        local ry = listY + (index - 1) * rowH
        if ry + rowH > mapY + mapH then break end
        registerPointerRegion(mapX + spacing.sm, ry, mapW - spacing.sm * 2,
          rowH - 2, { selectionState = state, selectionField = "sel",
            selectionIndex = index, rowCount = #locs, activate = true,
            interactive = true, dragHandle = false })
        setColor(index == state.sel and colors.selected or colors.surfaceRaised)
        love.graphics.rectangle("fill", mapX + spacing.sm, ry,
          mapW - spacing.sm * 2, rowH - 2, theme.radii.sm)
        setColor(index == state.sel and colors.text or colors.textMuted)
        love.graphics.setFont(body)
        drawText(safeText(loc.name), mapX + spacing.lg,
          ry + (rowH - textHeight(body)) / 2)
      end
    end

    local infoX = landscape and mapX + mapW + spacing.xl or mapX
    local infoY = landscape and mapY or mapY + mapH + spacing.md
    local infoW = landscape and detailW or mapW
    if selected then
      setColor(colors.text)
      love.graphics.setFont(body)
      drawFittedText(state.fly and ("TO " .. safeText(selected.name))
        or safeText(selected.name), infoX, infoY, infoW, body)
      local names = {}
      local named = {}
      for _, marker in ipairs(partyMarkers) do
        local sameLocation = marker.loc == selected
          or (marker.loc and selected and marker.loc.name == selected.name
            and marker.loc.x == selected.x and marker.loc.y == selected.y)
        local markerName = safeText(marker.name)
        if sameLocation and markerName ~= "" and not named[markerName] then
          named[markerName] = true
          names[#names + 1] = markerName
        end
      end
      if #names > 0 then
        setColor(colors.textMuted)
        love.graphics.setFont(caption)
        drawWrappedText("Players here:\n" .. table.concat(names, "\n"),
          infoX, infoY + textHeight(body) + spacing.sm, infoW, caption,
          textHeight(caption) + spacing.xs)
      end
      if state.nestSpecies then
        setColor(colors.textMuted)
        love.graphics.setFont(caption)
        local noteY = infoY + textHeight(body) + spacing.sm
        if #names > 0 then
          noteY = noteY + (#names + 1) * (textHeight(caption) + spacing.xs)
        end
        drawWrappedText("Blinking markers show where this species can be found.",
          infoX, noteY, infoW, caption,
          textHeight(caption) + spacing.xs)
      end
    end
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    local footer = state.fly and "UP/DOWN  choose   A  fly   B  back"
      or state.nestSpecies and "A  close   B  back"
      or "ARROWS  move   A  view   B  back"
    drawHintIfUseful(theme, footer, px + spacing.lg,
      py + panelH - footerH + spacing.sm, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawQolLocationBanner(
      game, viewport, theme)
    local banner = mod._gen1ModernSpecialPresenters._qolLocationBanner
    if type(banner) ~= "table" or safeText(banner.name) == "" then
      return false
    end
    local world = mod.world
    local ow = world and type(world.overworld) == "function"
      and world:overworld() or nil
    local now = love.timer and love.timer.getTime
      and love.timer.getTime() or 0
    if banner.overworld ~= ow or (banner.expiresAt and now >= banner.expiresAt)
        or mod._gen1ModernSpecialPresenters.qolLocationDuration(game) <= 0 then
      banner.name, banner.expiresAt, banner.overworld = nil, nil, nil
      return false
    end

    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.caption)
    local bodyFont = font(fontCache, theme.typography.body)
    local name = safeText(banner.name)
    local maxW = math.max(1, w - spacing.lg * 2)
    local nameW = bodyFont:getWidth(name)
    local minW = math.min(maxW, scaledPanelWidth(theme, 220))
    local panelW = math.min(maxW, math.max(minW,
      nameW + spacing.xl * 2))
    local panelH = textHeight(titleFont) + textHeight(bodyFont)
      + spacing.lg * 2 + spacing.sm
    local px = x + (w - panelW) / 2
    -- Location notices use the same lower-card placement as dialogue. This
    -- keeps them out of the playfield's top edge and makes the transition
    -- between a map notice and an actual TextBox feel intentional.
    local py = y + h - panelH - spacing.lg

    love.graphics.push("all")
    love.graphics.origin()
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH,
      theme.radii.md)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.md)
    drawPanelAccent(theme, px, py, panelW, theme.radii.md)
    setColor(colors.textMuted)
    love.graphics.setFont(titleFont)
    local title = "LOCATION"
    drawText(title,
      px + (panelW - titleFont:getWidth(title)) / 2,
      py + spacing.sm)
    setColor(colors.text)
    love.graphics.setFont(bodyFont)
    local nameText = truncate(name, panelW - spacing.lg * 2, bodyFont)
    drawText(nameText,
      px + (panelW - bodyFont:getWidth(nameText)) / 2,
      py + spacing.sm + textHeight(titleFont) + spacing.xs)
    love.graphics.pop()
    return true
  end

  function mod._gen1ModernSpecialPresenters.drawQuarantineReport(game, state,
      viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local body = font(fontCache, theme.typography.body)
    local caption = font(fontCache, theme.typography.caption)
    local lines = type(state.lines) == "table" and state.lines or {}
    local maxOffset = 0
    if type(state.maxOffset) == "function" then
      local ok, value = pcall(state.maxOffset, state)
      if ok and tonumber(value) then maxOffset = math.max(0, value) end
    end
    local offset = clamp(tonumber(state.offset) or 0, 0, maxOffset)
    local visible = math.min(13, #lines)
    local rowH = textHeight(body) + spacing.xs
    local widest = body:getWidth("LOAD REPORT")
    for index = 1, visible do
      widest = math.max(widest,
        body:getWidth(safeText(lines[offset + index] or "")))
    end
    local panelW = math.min(w - spacing.lg * 2,
      math.max(360, widest + spacing.lg * 2))
    local footerH = textHeight(caption) + spacing.md
    local panelH = math.min(h - spacing.lg * 2,
      textHeight(titleFont) + visible * rowH + footerH + spacing.lg * 3)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local contentY = py + spacing.lg + textHeight(titleFont) + spacing.sm
    local footerY = py + panelH - footerH

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    registerPointerRegion(px, py, panelW, panelH, {
      role = "quarantine_report", action = "a", interactive = true,
      dragHandle = false,
    })
    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawText("LOAD REPORT", px + spacing.lg, py + spacing.md)
    setColor(colors.textMuted)
    love.graphics.setFont(body)
    for index = 1, visible do
      local line = lines[offset + index]
      if line and line ~= "" then
        drawText(safeText(line), px + spacing.lg,
          contentY + (index - 1) * rowH)
      end
    end
    if offset > 0 then
      setColor(colors.accent)
      drawText("^", px + panelW - spacing.lg - body:getWidth("^"),
        contentY)
    end
    if offset < maxOffset then
      setColor(colors.accent)
      drawText("v", px + panelW - spacing.lg - body:getWidth("v"),
        contentY + math.max(0, visible - 1) * rowH)
    end
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg, footerY,
      panelW - spacing.lg * 2, themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    local footer = maxOffset > 0 and "UP/DOWN  scroll   A/B  continue"
      or "A/B  continue"
    drawHintIfUseful(theme, footer, px + spacing.lg,
      footerY + spacing.sm, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function battleName(game, battler)
    local mon = battler and battler.mon or battler
    local def = mon and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return safeText((battler and battler.name) or (mon and mon.nickname) or
      (def and def.name) or (mon and mon.species) or "POKEMON")
  end

  local function battleHP(battler)
    local mon = battler and battler.mon
    if not mon then return 0, 1 end
    local maxHP = math.max(1, (mon.stats and mon.stats.hp) or mon.hp or 1)
    local hp = battler.shownHP or mon.hp or 0
    return clamp(hp, 0, maxHP), maxHP
  end

  local function drawBattleBar(theme, x, y, w, h, hp, maxHP)
    setColor(healthPalette(theme).track)
    love.graphics.rectangle("fill", x, y, w, h, h / 2)
    local ratio = clamp(hp / math.max(1, maxHP), 0, 1)
    if ratio > 0 then
      setColor(healthFillColor(theme, ratio))
      love.graphics.rectangle("fill", x, y, w * ratio, h, h / 2)
    end
  end

  local function drawBattleFit(image, x, y, w, h)
    local iw, ih = imageMetrics(image)
    if not iw or not ih then return end
    local scale = math.min(w / iw, h / ih)
    setColor({ 1, 1, 1, 1 })
    drawImage(image, x + (w - iw * scale) / 2,
      y + (h - ih * scale) / 2, 0, scale, scale)
  end

  local function drawBattleCard(game, theme, battler, x, y, w, h, alignRight)
    if not battler then return end
    local spacing = theme.spacing
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.md)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.body))
    local name = battleName(game, battler)
    local mon = battler.mon or battler
    local level = mon.level and ("Lv " .. tostring(mon.level)) or ""
    local hp, maxHP = battleHP(battler)
    local levelW = love.graphics.getFont():getWidth(level)
    -- Keep the level in its own right-hand column.  The old right-aligned
    -- calculation used the longer of the two strings as the text origin,
    -- which made names and levels collide on narrow portrait cards.
    local nameX = x + spacing.md
    local levelX = x + w - spacing.md - levelW
    local nameMax = math.max(20, levelX - nameX - spacing.sm)
    drawText(truncate(name, nameMax), nameX, y + spacing.sm)
    if level ~= "" then
      setColor(theme.colors.textMuted)
      drawText(level, levelX, y + spacing.sm)
    end
    local barY = y + spacing.sm
      + textHeight(font(fontCache, theme.typography.body)) + 5
    drawBattleBar(theme, x + spacing.md, barY, w - spacing.md * 2, 8, hp, maxHP)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    drawText(("HP %d/%d"):format(math.floor(hp), math.floor(maxHP)),
      x + spacing.md, barY + 12)
    local status = battler.shownStatus or mon.status
    if status then
      setColor(theme.colors.accent)
      drawText(safeText(status):upper(),
        x + w - spacing.md - love.graphics.getFont():getWidth(safeText(status)), barY + 12)
    end
  end

  local function battleImage(game, state, battler, side)
    if not battler then return nil end
    local fallback = battler.sprite
    local image
    if side == "back" and state.showPlayerBack and state.playerBackPic then
      image = imageFor(state.playerBackPic)
    elseif side == "front" and state.showEnemyTrainer and state.trainerPic then
      image = imageFor(state.trainerPic)
    end
    if image then return image end
    image = spriteForSide(game, battler.mon, side, nil, "battle")
    return image or imageFor(fallback)
  end

  local function battleMessage(state)
    local item = state.current
    local text = item and item.text or state.introText
    if not text and state.phase == "menu" then return "Choose an action." end
    if not text then return "" end
    return safeText(text):gsub("<PK>", "PKMN"):gsub("[\r\n\v]+", " ")
  end

  -- Mirror the battle state's actual cursor geometry. WIDE battles navigate
  -- a 2x2 grid; OG battles use the original vertical list. Synthetic/public
  -- battle states without either method default to the modern grid.
  local function battleUsesWideLayout(state)
    if not state then return true end
    local method = state.wideLayout
    if type(method) == "function" then
      local ok, value = pcall(method, state)
      if ok then return value == true end
    end
    method = state.isWideBattleLayout
    if type(method) == "function" then
      local ok, value = pcall(method, state)
      if ok then return value == true end
    end
    return true
  end

  local function drawBattleActionPanel(game, state, theme, x, y, w, h)
    local spacing = theme.spacing
    local contentH = math.max(1, h - spacing.md * 2 - 26)
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.md)
    local phase = state.phase
    if phase == "menu" then
      local labels = { "FIGHT", "POKEMON", "ITEM", "RUN" }
      local cols = 2
      local cellW, cellH = (w - spacing.md * 3) / cols,
        (contentH - spacing.md) / 2
      for i, label in ipairs(labels) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx = x + spacing.md + col * (cellW + spacing.md)
        local cy = y + spacing.md + row * (cellH + spacing.md)
        if i == (state.menuIndex or 1) then
          setColor(theme.colors.selected)
          love.graphics.rectangle("fill", cx, cy, cellW, cellH, theme.radii.sm)
        end
        setColor(i == (state.menuIndex or 1) and theme.colors.text or theme.colors.textMuted)
        love.graphics.setFont(font(fontCache, theme.typography.body))
        drawText(Strings(label), cx + spacing.sm,
          cy + (cellH - textHeight(love.graphics.getFont())) / 2)
      end
    elseif phase == "moveSelect" or phase == "mimicSelect" then
      local moves = phase == "mimicSelect" and state.mimicMoves
        or state.player and state.player.curMoves or {}
      moves = type(moves) == "table" and moves or {}
      local selected = phase == "mimicSelect" and (state.mimicIndex or 1)
        or (state.moveIndex or 1)
      local wide = battleUsesWideLayout(state)
      local cols = wide and 2 or 1
      -- BattleState keeps a stable 2x2 cursor even when a Pokémon knows only
      -- one, two, or three moves. Draw all four slots so the visual grid has
      -- the same index-to-cell mapping as the vanilla navigation code.
      local slotCount = wide and math.max(4, #moves) or math.max(1, #moves)
      local rows = math.max(wide and 2 or 1, math.ceil(slotCount / cols))
      local cellW = (w - spacing.md * (cols + 1)) / cols
      local cellH = math.max(36, (contentH - spacing.md * (rows - 1)) / rows)
      for i = 1, slotCount do
        local move = moves[i]
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx = x + spacing.md + col * (cellW + spacing.md)
        local cy = y + spacing.md + row * (cellH + spacing.md)
        if i == selected then
          setColor(theme.colors.selected)
          love.graphics.rectangle("fill", cx, cy, cellW, cellH - 4, theme.radii.sm)
        end
        local def = move and game.data and game.data.moves and game.data.moves[move.id]
        local label = move and (def and def.name or move.id or "-") or ""
        local pp = move and move.pp ~= nil and ("PP %d"):format(move.pp) or ""
        local compact = cellW < 190
        local moveFont = font(fontCache,
          compact and theme.typography.caption or theme.typography.body)
        love.graphics.setFont(moveFont)
        local ppFont = font(fontCache, theme.typography.caption)
        local ppW = ppFont:getWidth(pp)
        local labelMax = math.max(12, cellW - spacing.sm * 2 - ppW - spacing.sm)
        setColor(i == selected and theme.colors.text or theme.colors.textMuted)
        if move then
          drawText(truncate(label, labelMax), cx + spacing.sm,
            cy + (cellH - textHeight(moveFont)) / 2)
        else
          drawText("-", cx + (cellW - moveFont:getWidth("-")) / 2,
            cy + (cellH - textHeight(moveFont)) / 2)
        end
        setColor(theme.colors.textMuted)
        love.graphics.setFont(ppFont)
        drawText(pp, cx + cellW - spacing.md - ppW,
          cy + (cellH - textHeight(ppFont)) / 2)
      end
    else
      local text = battleMessage(state)
      setColor(theme.colors.text)
      love.graphics.setFont(font(fontCache, theme.typography.body))
      local lines = wrappedLines(text, w - spacing.lg * 2)
      local lineH = textHeight(love.graphics.getFont()) + spacing.sm
      for i, line in ipairs(lines) do
        if i > math.max(1, math.floor(contentH / lineH)) then break end
        drawText(line, x + spacing.lg, y + spacing.md + (i - 1) * lineH)
      end
      if state.msgWaiting or state.msgPrompt then
        setColor(theme.colors.accent)
        drawText("A  continue", x + w - spacing.lg - 90, y + h - spacing.lg - 14)
      end
    end
  end

  local function drawBattle(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      math.max(1, panelMaxWidth(theme, 900)))
    local panelH = math.max(1, h - gutter * 2)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local cardW = math.min(390, panelW * 0.43)
    local cardH = math.min(104, math.max(76, panelH * 0.12))
    local wide = battleUsesWideLayout(state)
    local footerH = wide and math.min(190, math.max(128, panelH * 0.27))
      or math.min(280, math.max(240, panelH * 0.34))
    local arenaY = py + spacing.lg + cardH + spacing.md
    local arenaH = math.max(40, panelH - footerH - cardH - spacing.lg * 3)

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    drawText(state.kind == "trainer" and "TRAINER BATTLE" or "BATTLE",
      px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    drawText("LIVE BATTLE", px + panelW - spacing.lg - 82, py + spacing.md + 5)

    drawBattleCard(game, theme, state.enemy, px + spacing.lg,
      py + spacing.lg + 34, cardW, cardH, false)
    drawBattleCard(game, theme, state.player,
      px + panelW - cardW - spacing.lg, py + panelH - footerH - cardH - spacing.lg,
      cardW, cardH, true)

    local enemyImage = battleImage(game, state, state.enemy, "front")
    local playerImage = battleImage(game, state, state.player, "back")
    local spriteW, spriteH = panelW * 0.34, arenaH * 0.82
    if enemyImage then
      drawBattleFit(enemyImage, px + panelW - spriteW - spacing.xl,
        arenaY, spriteW, spriteH * 0.56)
    end
    if playerImage then
      drawBattleFit(playerImage, px + spacing.xl,
        arenaY + arenaH * 0.32, spriteW, spriteH * 0.68)
    end

    drawBattleActionPanel(game, state, theme, px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, footerH)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    drawHintIfUseful(theme, "A  select    B  back", px + spacing.lg,
      py + panelH - spacing.sm - 14, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  -- LinkState owns networking and input, but its released renderer is a
  -- small native 160x144 canvas. Present its public stages as ordinary modern
  -- rows while leaving every transition/callback in LinkState untouched.
  local function drawLink(game, state, viewport, theme)
    local stage = state.stage or "menu"
    local title = ({
      menu = "LINK",
      lanMenu = "LINK CABLE (LAN)",
      onlineMenu = "ONLINE MATCH",
      onlineHosting = "HOSTING ONLINE",
      codeEntry = "ENTER CODE",
      onlineJoining = "CONNECTING",
      hosting = "HOSTING",
      addrEntry = "ENTER HOST ADDRESS",
      joining = "JOINING",
      modeSelect = "CONNECTED",
      battleOptions = "BATTLE OPTIONS",
      waitMode = "CONNECTED",
      waitHello = "CONNECTED",
      notice = state.verdict == "engine_skew" and "UPDATE YOUR GAME"
        or "CHECK YOUR MODS",
      trade = "TRADE",
      battleWait = "LINK BATTLE",
      battleRunning = "LINK BATTLE",
    })[stage] or "LINK"
    local rows = {}
    local selected = tonumber(state.index) or 1
    local footer = "A  select   B  back"
    local function listText(values, charset)
      local out = {}
      for _, value in ipairs(values or {}) do
        if charset and type(value) == "number" then
          value = charset:sub(value, value)
        end
        out[#out + 1] = safeText(value)
      end
      return table.concat(out)
    end
    local defaultPort = "7777"
    if runtimeClasses.linkNet
        and type(runtimeClasses.linkNet.defaultPort) == "function" then
      local ok, value = pcall(runtimeClasses.linkNet.defaultPort)
      if ok and value then defaultPort = safeText(value) end
    end
    local function row(label, value, enabled)
      rows[#rows + 1] = {
        label = safeText(label), value = value, enabled = enabled,
      }
    end
    if stage == "menu" then
      row("LINK CABLE (LAN)")
      row("ONLINE MATCH")
      row("TOURNAMENT")
    elseif stage == "lanMenu" then
      row("HOST A GAME")
      row("JOIN A GAME")
      footer = "A  choose   B  back"
    elseif stage == "onlineMenu" then
      row("HOST ONLINE")
      row("JOIN ONLINE")
    elseif stage == "modeSelect" then
      row("TRADE")
      row("BATTLE")
    elseif stage == "battleOptions" then
      row("LEVEL", state.levelChoice == nil and "ANY"
        or safeText(state.levelChoice))
      footer = "UP/DOWN  adjust   A  continue   B  back"
    elseif stage == "codeEntry" then
      local entry = state.codeEntry
      local code = "------"
      if entry and runtimeClasses.linkCodeEntry
          and type(runtimeClasses.linkCodeEntry.text) == "function" then
        local ok, value = pcall(runtimeClasses.linkCodeEntry.text, entry)
        if ok and value then code = safeText(value) end
      elseif entry and entry.chars then
        local charset = runtimeClasses.linkCodeEntry
          and runtimeClasses.linkCodeEntry.CHARSET
        code = listText(entry.chars, charset)
      end
      if entry and entry.pos then
        local chars = {}
        for index = 1, #code do
          local char = code:sub(index, index)
          chars[#chars + 1] = index == entry.pos and ("[" .. char .. "]") or char
        end
        code = table.concat(chars)
      end
      row("CODE", code)
      row("POSITION", entry and entry.pos and
        (safeText(entry.pos) .. " / 6") or "1 / 6", false)
      selected = 1
      footer = "ARROWS  edit   A  connect   B  back"
    elseif stage == "addrEntry" then
      local digits = "------------"
      if state.addr then
        local address = {}
        for index, value in ipairs(state.addr) do
          local digit = safeText(value)
          address[#address + 1] = index == state.addrPos
            and ("[" .. digit .. "]") or digit
          if index % 3 == 0 and index < #state.addr then
            address[#address + 1] = "."
          end
        end
        digits = table.concat(address)
      end
      row("HOST", digits)
      row("POSITION", state.addrPos and
        (safeText(state.addrPos) .. " / " .. safeText(#(state.addr or {})))
        or "1 / 12", false)
      row("PORT", defaultPort, false)
      selected = 1
      footer = "UP/DOWN  digit   LEFT/RIGHT  slot   A  connect   B  back"
    elseif stage == "onlineHosting" then
      row("CODE", state.net and state.net.code or "??????", false)
      row("STATUS", "WAITING FOR JOIN", false)
      footer = "B  cancel"
    elseif stage == "hosting" then
      row("ADDRESS", state.net and state.net.address or "?", false)
      row("STATUS", "WAITING FOR JOIN", false)
      footer = "B  cancel"
    elseif stage == "onlineJoining" or stage == "joining" then
      row("STATUS", "CALLING...", false)
      row("TARGET", state.net and state.net.target or "", false)
      footer = "B  cancel"
    elseif stage == "waitMode" or stage == "waitHello" then
      row("STATUS", stage == "waitHello" and "CHECKING OTHER GAME"
        or "WAITING FOR HOST", false)
      footer = "B  cancel"
    elseif stage == "notice" then
      for _, line in ipairs(state.noticeLines or {}) do row(line) end
      footer = state.noticeExits and "A  back" or "A  trade anyway"
    elseif stage == "trade" then
      local party = game and game.save and game.save.party or {}
      for _, mon in ipairs(party) do
        local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
        row(mon.nickname or (def and def.name) or mon.species or "POKEMON")
      end
      footer = "A  choose   B  back"
    elseif stage == "battleWait" or stage == "battleRunning" then
      row("STATUS", "EXCHANGING DATA...", false)
      footer = "B  cancel"
    else
      row("STATUS", safeText(state.status or "WAITING..."), false)
    end
    if #rows == 0 then row("WAITING...", nil, false) end

    local layout = layoutFor(viewport, theme, "link", rows, Strings(title), footer)
    selected = clamp(selected, 1, #rows)
    local scroll = 0
    love.graphics.push("all")
    love.graphics.origin()
    if not layout.sidePanel then drawPresenterBackdrop(theme, viewport) end
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h,
      layout.radius)
    drawHeader(theme, layout, Strings(title))
    drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2,
      themeMetric(theme, "divider", 1))
    setColor(theme.colors.textMuted)
    drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + theme.spacing.sm,
      layout.w - theme.spacing.lg * 2)
    love.graphics.pop()
  end

  local function drawModern(game, state, kind, viewport, theme, asModal, underKind,
      underState, overKind, overState)
    if not presenterEnabled(kind) then return end
    if kind == "text" or kind == "choice" or kind == "quantity"
        or (asModal and underKind == "text") then
      theme = dialogueTheme(theme)
    end
    if kind == "text" then
      drawDialogue(state, viewport, theme, game, overKind, overState)
      return
    end
    if kind == "move_learn" then
      mod._gen1ModernSpecialPresenters.drawMoveLearn(game, state, viewport, theme)
      return
    end
    if kind == "pic_box" then
      mod._gen1ModernSpecialPresenters.drawPicBox(game, state, viewport, theme)
      return
    end
    if kind == "naming" then
      mod._gen1ModernSpecialPresenters.drawNaming(game, state, viewport, theme)
      return
    end
    if kind == "town_map" then
      mod._gen1ModernSpecialPresenters.drawTownMap(game, state, viewport, theme)
      return
    end
    if kind == "quarantine_report" then
      mod._gen1ModernSpecialPresenters.drawQuarantineReport(
        game, state, viewport, theme)
      return
    end
    if kind == "rby_mmo_profile" then
      mod._gen1ModernSpecialPresenters.drawRbyMmoProfile(
        game, state, viewport, theme)
      return
    end
    if kind == "rby_mmo_rank" then
      mod._gen1ModernSpecialPresenters.drawRbyMmoRank(
        game, state, viewport, theme)
      return
    end
    if kind == "rby_mmo_char_pick" then
      mod._gen1ModernSpecialPresenters.drawRbyMmoCharacterPick(
        game, state, viewport, theme)
      return
    end
    if asModal or kind == "choice" or kind == "quantity" then
      drawModalRows(game, state, kind, viewport, theme, underKind, underState)
      return
    end
    if kind == "battle" then
      drawBattle(game, state, viewport, theme)
      return
    end
    if kind == "link" then
      drawLink(game, state, viewport, theme)
      return
    end
    if kind == "mod_manager" then
      drawManager(game, state, viewport, theme)
      return
    end
    local minimal = option("minimalUi", false) == true
    local forceGeneric = minimal and kind == "pokedex"
    if kind == "gen3_box" then
      drawGen3Box(game, state, viewport, theme)
      return
    end
    if kind == "dex_entry" then
      drawDexEntry(game, state, viewport, theme)
      return
    end
    if kind == "summary" then
      drawSummary(game, state, viewport, theme)
      return
    end
    if kind == "trainer_card" then
      drawTrainerCard(game, state, viewport, theme)
      return
    end
    if kind == "party" then
      drawParty(game, state, viewport, theme)
      return
    end
    if kind == "box_mon_list" then
      drawBoxPokemonList(game, state, viewport, theme)
      return
    end
    if kind == "pokedex" and not forceGeneric then
      drawPokedex(game, state, viewport, theme)
      return
    end
    if kind == "bag" and not forceGeneric then
      drawBag(game, state, viewport, theme)
      return
    end
    if (kind == "shop_list" or kind == "pc_list") and not forceGeneric then
      drawContextList(game, state, kind, viewport, theme)
      return
    end
    local rows, selected, scroll, title, footerText = rowsFor(game, state, kind)
    if not rows then return end
    local layout = layoutFor(viewport, theme, kind, rows, title, footerText)
    scroll = clamp(scroll, 0, math.max(0, #rows - layout.visible))
    selected = clamp(selected, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visible then scroll = selected - layout.visible end

    love.graphics.push("all")
    love.graphics.origin()
    if not layout.sidePanel then drawPresenterBackdrop(theme, viewport) end
    local surface = theme.colors.surface
    if layout.sidePanel then
      surface = { surface[1], surface[2], surface[3], math.min(surface[4] or 1, 0.96) }
    end
    setColor(surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, layout.radius)
    drawHeader(theme, layout, title)
    drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2, 1)
    setColor(theme.colors.textMuted)
    local footer = layout.sidePanel and "A  select   B  back" or footerText or
      (kind == "choice" and "A  choose    B  cancel"
      or kind == "quantity" and "A  confirm    B  cancel"
      or "Arrow keys / A  select    B  back")
    drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8,
      layout.w - theme.spacing.lg * 2)
    if kind == "menu" and state and state.screenId == "StartMenu" then
      mod._gen1ModernSpecialPresenters.drawStartMenuQuickView(
        game, state, viewport, theme, layout)
    end
    love.graphics.pop()
  end

  -- A stack can contain a full rich screen above another rich screen (Party
  -- -> Summary, Pokédex -> DexEntry, Box -> Pokémon list).  Only actual
  -- modal layers should switch to the compact rows card.  Treating every
  -- layer after the first as modal made those screens render an empty
  -- "Nothing here" card and hid the page that was just opened.
  local function isModalLayer(kind)
    return kind == "menu" or kind == "list" or kind == "choice"
      or kind == "quantity" or kind == "text" or kind == "pic_box"
  end

  -- A/B are available globally through the mouse buttons, but a few screens
  -- expose meaningful controls that cannot be represented by row clicks.
  -- Surface only those extras, and leave mobile's native TouchControls alone:
  -- they receive pointer first refusal and already provide the full pad.
  local function pointerControlsFor(kind, state)
    if not state then return {} end
    local actions, seen = {}, {}
    local function add(action)
      if not seen[action] then
        actions[#actions + 1] = action
        seen[action] = true
      end
    end

    if kind == "mod_manager" then
      if state._gen1OptionDescription then return actions end
      if state.overlay then
        if state.overlay.kind == "confirm" then add("up"); add("down") end
        return actions
      elseif state.screen == "options" then
        add("left"); add("right"); add("select")
      elseif state.screen == "list" then
        add("left"); add("right"); add("select"); add("start")
      elseif state.screen == "detail" then
        add("left"); add("right"); add("select")
      end
    elseif kind == "options" or kind == "mod_options" then
      add("left"); add("right")
    elseif kind == "quantity" then
      add("down"); add("up")
    elseif kind == "choice" then
      add("left"); add("right")
    elseif kind == "gen3_box" then
      add("up"); add("down"); add("left"); add("right")
      add("select"); add("start")
    elseif kind == "link" then
      local stage = state.stage
      if stage == "codeEntry" or stage == "addrEntry" then
        add("up"); add("down"); add("left"); add("right")
      elseif stage == "battleOptions" then
        add("up"); add("down")
      end
    elseif kind == "bag" and type(state.modernBag) == "table" then
      add("left"); add("right")
    elseif kind == "naming" then
      add("select"); add("start")
    elseif kind == "town_map" then
      if state.mode == "grid" and not state.fly and not state.nestSpecies then
        add("left"); add("right")
      end
      add("up"); add("down")
    elseif kind == "quarantine_report" then
      if tonumber(state.offset) and type(state.maxOffset) == "function" then
        local ok, maxOffset = pcall(state.maxOffset, state)
        if ok and tonumber(maxOffset) and maxOffset > 0 then
          add("up"); add("down")
        end
      end
    elseif kind == "rby_mmo_rank" then
      add("up"); add("down")
    end

    if state.pageJump then add("left"); add("right") end
    if type(state.onSelectKey) == "function" then add("select") end
    return actions
  end

  local POINTER_CONTROL_LABEL = {
    up = "^", down = "v", left = "<", right = ">",
    select = "SELECT", start = "START",
  }

  POINTER_CONTROL_LABEL.forContext = function(kind, state, action)
    if kind == "quantity" then
      if action == "down" then return "-" end
      if action == "up" then return "+" end
    elseif kind == "mod_manager" then
      if state.screen == "options" and action == "select" then return "HELP" end
      if state.screen == "list" and action == "select" then return "TOGGLE" end
      if state.screen == "list" and action == "start" then return "APPLY" end
    elseif kind == "gen3_box" then
      if action == "select" then
        return state.mode == "party" and "BOX" or "PARTY"
      end
      if action == "start" then return "STATS" end
    elseif kind == "bag" and type(state.modernBag) == "table" then
      if action == "left" then return "< POCKET" end
      if action == "right" then return "POCKET >" end
    end
    if state.pageJump then
      if action == "left" then return "< PAGE" end
      if action == "right" then return "PAGE >" end
    end
    return POINTER_CONTROL_LABEL[action] or action:upper()
  end

  local function drawPointerControls(theme, context)
    if option("pointerUi", false) ~= true or not context
        or not context.primaryPanel
        or (context.viewport and context.viewport._gen1TouchVisible) then
      return
    end
    local actions = pointerControlsFor(context.kind, context.state)
    if #actions == 0 then return end
    local panel = context.primaryPanel
    local vx, vy, vw, vh = presenterRect(context.baseViewport or context.viewport)
    local spacing = theme.spacing
    local controlFont = font(fontCache, theme.typography.caption)
    love.graphics.setFont(controlFont)
    local gap = math.max(3, spacing.xs)
    local buttonH = math.max(28, textHeight(controlFont) + spacing.sm)
    local widths, dockW = {}, 0
    for index, action in ipairs(actions) do
      local label = POINTER_CONTROL_LABEL.forContext(
        context.kind, context.state, action)
      local width = math.max(buttonH,
        controlFont:getWidth(label) + spacing.md)
      widths[index] = width
      dockW = dockW + width + (index > 1 and gap or 0)
    end

    local rightRoom = vx + vw - (panel.x + panel.w)
    local leftRoom = panel.x - vx
    local dockX, dockY
    if rightRoom >= dockW + spacing.md * 2 then
      dockX = panel.x + panel.w + spacing.md
      dockY = clamp(panel.y + panel.h - buttonH, vy + spacing.sm,
        vy + vh - buttonH - spacing.sm)
    elseif leftRoom >= dockW + spacing.md * 2 then
      dockX = panel.x - dockW - spacing.md
      dockY = clamp(panel.y + panel.h - buttonH, vy + spacing.sm,
        vy + vh - buttonH - spacing.sm)
    else
      -- Tight windows still get the controls, tucked into the footer. The
      -- opaque chips intentionally replace the least-useful end of its hint.
      dockX = clamp(panel.x + panel.w - dockW - spacing.md,
        vx + spacing.sm, vx + vw - dockW - spacing.sm)
      dockY = clamp(panel.y + panel.h - buttonH - spacing.xs,
        vy + spacing.sm, vy + vh - buttonH - spacing.sm)
    end

    local x = dockX
    for index, action in ipairs(actions) do
      local width = widths[index]
      local controlKey = safeText(context.layerKey) .. ":" .. action
      local hovered = hoveredPointer
        and hoveredPointer.controlKey == controlKey
      setColor(hovered and theme.colors.selected
        or (theme.colors.surfaceRaised or theme.colors.surface))
      love.graphics.rectangle("fill", x, dockY, width, buttonH,
        theme.radii.sm or 6)
      setColor(hovered and theme.colors.text or theme.colors.textMuted)
      local label = POINTER_CONTROL_LABEL.forContext(
        context.kind, context.state, action)
      drawText(label, x + (width - controlFont:getWidth(label)) / 2,
        dockY + (buttonH - textHeight(controlFont)) / 2)
      registerPointerRegion(x, dockY, width, buttonH, {
        action = action, activate = true, interactive = true,
        controlKey = controlKey, dragHandle = false,
      })
      x = x + width + gap
    end
  end

  local function drawModernStack(game, layers, viewport)
    local theme = responsiveTheme(currentTheme(viewport), viewport, responsiveThemeCache)
    pointerRuntime.generation = pointerRuntime.generation + 1
    pointerRegions = {}
    pointerRuntime.topOrder = #layers
    local nextTopState = layers[#layers] and layers[#layers].state or nil
    if pointerRuntime.topState ~= nextTopState then
      hoveredPointer = nil
      for _, capture in pairs(pointerCaptures) do capture.invalid = true end
    end
    pointerRuntime.topState = nextTopState
    love.graphics.push("all")
    love.graphics.origin()
    local modalActive = false
    for index, layer in ipairs(layers) do
      local underKind = index > 1 and layers[index - 1].kind or nil
      local underState = index > 1 and layers[index - 1].state or nil
      local overKind = index < #layers and layers[index + 1].kind or nil
      local overState = index < #layers and layers[index + 1].state or nil
      local modal = index > 1 and isModalLayer(layer.kind)
      if modal and not modalActive then drawModalScrim(theme, viewport) end
      modalActive = modal
      local offsetX, offsetY = layerOffset(layer.kind, viewport)
      local layerViewport = shiftedViewport(viewport, offsetX, offsetY)
      pointerDrawContext = {
        kind = layer.kind, state = layer.state,
        layerKey = safeText(layer.kind or "screen") .. ":" .. index,
        viewport = layerViewport, baseViewport = viewport, order = index,
      }
      drawModern(game, layer.state, layer.kind, layerViewport, theme,
        modal, underKind, underState,
        overKind, overState)
      if index == #layers then
        drawPointerControls(theme, pointerDrawContext)
      end
      pointerDrawContext = nil
    end
    pointerDrawContext = nil
    love.graphics.pop()
  end

  local function pointerInputReady()
    return mod.input and type(mod.input.tap) == "function"
  end

  local function pointerContains(region, x, y)
    return type(x) == "number" and type(y) == "number"
      and x >= region.x and x <= region.x + region.w
      and y >= region.y and y <= region.y + region.h
  end

  pointerRuntime.stackTop = function(game)
    local stack = game and game.stack
    if not (stack and type(stack.top) == "function") then return nil end
    local ok, top = pcall(stack.top, stack)
    return ok and top or nil
  end

  pointerRuntime.regionAlive = function(game, region)
    if not region or region.order ~= pointerRuntime.topOrder
        or region.state ~= pointerRuntime.topState then return false end
    local top = pointerRuntime.stackTop(game)
    if top and top ~= region.state then return false end
    if region.stateMode ~= pointerRuntime.stateMode(region.state, region.kind) then
      return false
    end

    -- Manager overlays live inside ManagerState rather than as stack states.
    -- A stale option-row region must not remain active while one of those
    -- overlays is on screen, or its queued A edge can change the option below
    -- the modal (and then run against a rebuilt row list).
    local state = region.state
    if region.kind == "choice" and state and state.pending ~= nil then
      return false
    end
    if region.kind == "party" and state then
      if region.modalOwner ~= nil and region.modalOwner ~= state.submenu then
        return false
      end
      if state.submenu then
        return region.modalBlocker == true
          or region.modalOwner == state.submenu
      end
    end
    if region.kind == "mod_manager" and state then
      if state._gen1OptionDescription then
        return region.pointerCommand == "dismiss_help"
          or region.modalBlocker == true
      end
      if state.overlay then
        return region.modalBlocker == true
          or region.modalOwner == state.overlay
          or region.selectionState == state.overlay
      end
      if region.selectionState and region.selectionState ~= state then
        return false
      end
    end
    return true
  end

  local function pointerHit(x, y)
    -- Regions are appended in draw order. Only the active/top layer may own
    -- hover or click; visible parents underneath a modal remain context, not
    -- live hit targets. Reverse iteration still gives controls and rows first
    -- refusal over their panel's drag surface.
    for index = #pointerRegions, 1, -1 do
      local region = pointerRegions[index]
      if pointerContains(region, x, y)
          and region.interactive ~= false
          and pointerRuntime.regionAlive(currentGame, region) then
        return region
      end
    end
    return nil
  end

  pointerRuntime.insideUi = function(x, y)
    for index = #pointerRegions, 1, -1 do
      local region = pointerRegions[index]
      if pointerContains(region, x, y)
          and (region.role == "panel" or region.role == "modal"
            or region.role == "scrim" or region.role == "control") then
        return true
      end
    end
    return false
  end

  pointerRuntime.targetKey = function(region)
    if not region then return nil end
    local owner = tostring(region.selectionState or region.state)
    if region.controlKey then return "control:" .. safeText(region.controlKey) end
    if region.pointerCommand then
      return "command:" .. safeText(region.pointerCommand) .. ":" .. owner
    end
    if region.gridRow ~= nil and region.gridCol ~= nil then
      return ("grid:%s:%s:%s"):format(owner, region.gridRow, region.gridCol)
    end
    if region.namingRow ~= nil and region.namingCol ~= nil then
      return ("naming:%s:%s:%s"):format(owner, region.namingRow,
        region.namingCol)
    end
    if region.selectionField and region.selectionIndex ~= nil then
      return ("selection:%s:%s:%s"):format(owner,
        region.selectionField, region.selectionIndex)
    end
    if region.rowIndex ~= nil then
      return ("row:%s:%s"):format(owner, region.rowIndex)
    end
    if region.role then
      return ("%s:%s:%d:%d:%d:%d"):format(region.role, owner,
        math.floor(region.x + 0.5), math.floor(region.y + 0.5),
        math.floor(region.w + 0.5), math.floor(region.h + 0.5))
    end
    return "region:" .. owner
  end

  pointerRuntime.sameTarget = function(first, second)
    local a, b = pointerRuntime.targetKey(first), pointerRuntime.targetKey(second)
    return a ~= nil and a == b
  end

  local function pointerSelectionField(region)
    local state = region and (region.selectionState or region.state)
    if not state then return nil end
    if region.selectionField then return region.selectionField end
    if region.rowIndex == nil then return nil end
    if region.kind == "mod_manager" then
      return "cursor"
    elseif region.kind == "party" and state.submenu then
      return "subIndex"
    elseif type(state.index) == "number" then
      return "index"
    elseif type(state.cursor) == "number" then
      return "cursor"
    elseif type(state.selected) == "number" then
      return "selected"
    end
    return nil
  end

  local function setPointerSelection(region, desiredIndex, game)
    local state = region and (region.selectionState or region.state)
    if not state or not region
        or not pointerRuntime.regionAlive(game or currentGame, region) then return false end
    if region.namingRow ~= nil and region.namingCol ~= nil then
      local row = math.max(1, math.floor(tonumber(region.namingRow) or 1))
      local col = math.max(1, math.floor(tonumber(region.namingCol) or 1))
      return pcall(function() state.row, state.col = row, col end)
    end
    if region.gridRow ~= nil and region.gridCol ~= nil then
      local rows = math.max(1, tonumber(region.gridRows) or region.gridRow + 1)
      local cols = math.max(1, tonumber(region.gridCols) or region.gridCol + 1)
      local row = clamp(math.floor(tonumber(region.gridRow) or 0), 0, rows - 1)
      local col = clamp(math.floor(tonumber(region.gridCol) or 0), 0, cols - 1)
      return pcall(function() state.row, state.col = row, col end)
    end
    local index = tonumber(desiredIndex or region.selectionIndex
      or region.rowIndex)
    local field = pointerSelectionField(region)
    if not state or not index or not field then return false end
    index = math.floor(index)
    if tonumber(region.rowCount) then
      index = clamp(index, 1, math.max(1, math.floor(region.rowCount)))
    end

    local ok = pcall(function()
      state[field] = index
      if region.kind == "party" and field == "index"
          and state.game then
        state.game.partyMenuSavedIndex = index
      end

      -- ManagerState:snapCursor() deliberately models every manager screen
      -- except options. Calling it from an option-row hover therefore sees an
      -- empty rowsForScreen() result and resets the cursor to one. Keep its
      -- zero-based option scroll in sync here and reserve snapCursor for the
      -- manager screens it actually owns.
      if region.kind == "mod_manager" and state.screen == "options" then
        local visible = math.max(1, tonumber(region.visibleCount) or 1)
        local count = math.max(1, tonumber(region.rowCount) or index)
        local scroll = clamp(tonumber(state.scroll) or 0, 0,
          math.max(0, count - visible))
        if index <= scroll then
          scroll = index - 1
        elseif index > scroll + visible then
          scroll = index - visible
        end
        state.scroll = clamp(scroll, 0, math.max(0, count - visible))
      elseif type(state.clampScroll) == "function" then
        state:clampScroll()
      elseif type(state.syncScroll) == "function" then
        state:syncScroll()
      elseif field == "cursor" and type(state.snapCursor) == "function" then
        state:snapCursor()
      end
    end)
    return ok
  end

  local function updatePointerHover(region, game)
      if region and not pointerRuntime.regionAlive(game or currentGame, region) then
        region = nil
    end
    hoveredPointer = region
    if region and region.interactive ~= false
        and (region.rowIndex ~= nil or region.selectionField ~= nil
          or region.namingRow ~= nil
          or (region.gridRow ~= nil and region.gridCol ~= nil)) then
      -- Hovering a row is the mouse equivalent of moving the native cursor.
      -- Selection remains owned by the live state, so the next draw naturally
      -- paints the same highlight used by keyboard/controller navigation.
      setPointerSelection(region, nil, game)
    end
  end

  local function pointerScroll(region, normalizedScroll)
    local state = region and region.state
    if not state or type(state.scroll) ~= "number"
        or not region.scrollable
        or not pointerRuntime.regionAlive(currentGame, region) then
      return false
    end
    local maxScroll = math.max(0, (tonumber(region.rowCount) or 0)
      - (tonumber(region.visibleCount) or 0))
    local scroll = clamp(math.floor((tonumber(normalizedScroll) or 0) + 0.5),
      0, maxScroll)
    local bias = tonumber(region.scrollBias) or 0
    return pcall(function()
      state.scroll = scroll + bias

      -- Presenter layouts keep the live cursor visible. Move that cursor to
      -- the nearest selectable row as a drag scrolls; manager section headers
      -- are deliberately skipped so a touch can never strand its cursor on
      -- an inert heading.
      local field = pointerSelectionField(region)
      local current = field and tonumber(state[field])
      if field and current then
        local first = scroll + 1
        local last = math.min(tonumber(region.rowCount) or first,
          scroll + math.max(1, tonumber(region.visibleCount) or 1))
        local target = clamp(current, first, last)
        local selectable = region.selectableIndices
        if type(selectable) == "table" and #selectable > 0 then
          local nearest, distance
          for _, candidate in ipairs(selectable) do
            if candidate >= first and candidate <= last then
              local candidateDistance = math.abs(candidate - target)
              if not distance or candidateDistance < distance then
                nearest, distance = candidate, candidateDistance
              end
            end
          end
          if nearest then target = nearest end
        end
        state[field] = target
      end
    end)
  end

  local function tapGameButton(game, button)
    local ok, result = pcall(mod.input.tap, mod.input, game, button)
    return ok and result ~= false
  end

  local function tapPointerAction(game, region)
    if not region or not pointerRuntime.regionAlive(game, region) then return false end
    if region.pointerCommand == "dismiss_help" then
      if region.state and region.state._gen1OptionDescription then
        region.state._gen1OptionDescription = nil
        return true
      end
      return false
    end
    if region.action then return tapGameButton(game, region.action) end
    local hasSelection = region.rowIndex ~= nil or region.selectionField ~= nil
      or region.namingRow ~= nil
      or (region.gridRow ~= nil and region.gridCol ~= nil)
    local selected = not hasSelection or setPointerSelection(region, nil, game)
    if not selected then return false end
    local canActivate = region.activate == true or region.rowIndex ~= nil
      or region.namingRow ~= nil
      or (region.gridRow ~= nil and region.gridCol ~= nil)
      or region.kind == "text" or region.kind == "quantity"
    if not canActivate then return false end
    return tapGameButton(game, "a")
  end

  local function pointerCaptureKey(pointer)
    local source = pointer and pointer.source or "mouse"
    local id = pointer and pointer.id ~= nil and pointer.id or "mouse"
    return tostring(source) .. ":" .. tostring(id)
  end

  -- The upstream hook fires after TouchControls has had first refusal. A
  -- pointer that arrives here is therefore safe for the mod to capture for a
  -- full lifecycle, including multi-touch drags and short click/tap pulses.
  pointerRuntime.dispatch = function(next, game, pointer)
    if type(pointer) ~= "table" then
      return next(game, pointer)
    end
    local phase = pointer.phase
    local key = pointerCaptureKey(pointer)
    if option("pointerUi", false) ~= true or not pointerInputReady() then
      -- A setting or compatibility change can happen in the middle of a
      -- gesture. Never leave that pointer's old capture waiting to fire when
      -- click support is enabled again later.
      pointerCaptures[key] = nil
      return next(game, pointer)
    end
    if phase == "pressed" then
      local mouseAction
      if pointer.source == "mouse" then
        local button = tonumber(pointer.button)
        if button == nil or button == 1 then
          mouseAction = "a"
        elseif button == 2 then
          mouseAction = "b"
        else
          return next(game, pointer)
        end
      end

      -- Right-click is always the global B action. Left-click resolves only
      -- the active layer. A visible parent beneath a modal blocks click-
      -- through but is never allowed to move its hidden cursor.
      local region = mouseAction == "b" and nil
        or pointerHit(pointer.x, pointer.y)
      local insideUi = pointerRuntime.insideUi(pointer.x, pointer.y)
      local blocked = mouseAction ~= "b" and not region and insideUi
      if not region and not mouseAction and not blocked then
        if pointer.source == "mouse" then updatePointerHover(nil, game) end
        return next(game, pointer)
      end
      if region then setPointerSelection(region, nil, game) end
      local startX = tonumber(pointer.x) or (region and region.x) or 0
      local startY = tonumber(pointer.y) or (region and region.y) or 0
      pointerCaptures[key] = {
        region = region,
        targetKey = pointerRuntime.targetKey(region),
        buttonAction = blocked and nil or mouseAction,
        blocked = blocked,
        startX = startX,
        startY = startY,
        offsetX = region and select(1, layerOffset(region.kind, region.viewport)) or 0,
        offsetY = region and select(2, layerOffset(region.kind, region.viewport)) or 0,
        lastX = startX,
        lastY = startY,
        scrollStart = region and (tonumber(region.scrollValue)
          or (region.state and tonumber(region.state.scroll)) or 0) or 0,
        scrollStep = region and math.max(36,
          (tonumber(region.rowHeight) or 1) * 1.40) or 36,
        moved = false,
      }
      return true
    end

    local capture = pointerCaptures[key]
    if not capture then
      if phase == "moved" and pointer.source == "mouse" then
        updatePointerHover(pointerHit(pointer.x, pointer.y), game)
      end
      return next(game, pointer)
    end
    if capture.region and not pointerRuntime.regionAlive(game, capture.region) then
      capture.invalid = true
    end
    if phase == "moved" then
      local x = tonumber(pointer.x) or capture.lastX
      local y = tonumber(pointer.y) or capture.lastY
      capture.lastX, capture.lastY = x, y
      local totalX, totalY = x - capture.startX, y - capture.startY

      local region = capture.region
      local threshold = 6
      if capture.invalid or not region then
        if math.abs(totalX) >= threshold or math.abs(totalY) >= threshold then
          capture.moved = true
        end
        return true
      end
      if region.scrollable and math.abs(totalY) >= threshold then
        capture.moved = true
        local distance = math.max(0, math.abs(totalY) - threshold)
        local step = math.max(1, capture.scrollStep or 28)
        -- Quantize from the gesture origin with a little hysteresis. This
        -- keeps high-frequency touch move events from making long shop/bag
        -- lists race several rows ahead of the finger.
        local rows = math.floor((distance + step * 0.20) / step)
        if rows > 0 then
          capture.scrolled = true
          pointerScroll(region, capture.scrollStart
            + (totalY < 0 and rows or -rows))
        end
        return true
      end

      local panelDrag = region.dragHandle == true
      if option("dragPanels", false) == true and panelDrag
          and (math.abs(totalX) >= threshold or math.abs(totalY) >= threshold) then
        capture.moved = true
        capture.panelMoved = true
        capture.offsetX, capture.offsetY = rememberLayerOffset(
          region.kind, region.viewport,
          capture.offsetX + totalX - (capture.dragX or 0),
          capture.offsetY + totalY - (capture.dragY or 0), false)
        capture.dragX, capture.dragY = totalX, totalY
      elseif math.abs(totalX) >= threshold or math.abs(totalY) >= threshold then
        -- Rows that do not scroll are click targets, not accidental panel
        -- handles. Crossing the drag threshold cancels their click.
        capture.moved = true
      end
      return true
    end

    pointerCaptures[key] = nil
    if phase == "released" then
      local x = tonumber(pointer.x) or capture.lastX
      local y = tonumber(pointer.y) or capture.lastY
      if not capture.invalid and not capture.moved then
        if capture.region then
          -- Re-hit on release and act through the current region, not the
          -- table captured before a menu transition or responsive redraw.
          local releasedOver = pointerHit(x, y)
          if pointerRuntime.sameTarget(capture.region, releasedOver) then
            tapPointerAction(game, releasedOver)
          end
        elseif capture.buttonAction == "b" then
          tapGameButton(game, "b")
        elseif capture.buttonAction == "a"
            and not pointerRuntime.insideUi(x, y) then
          tapGameButton(game, "a")
        end
      end
      if capture.panelMoved and capture.region
          and pointerRuntime.regionAlive(game, capture.region) then
        rememberLayerOffset(capture.region.kind, capture.region.viewport,
          capture.offsetX, capture.offsetY, true)
      end
      return true
    elseif phase == "cancelled" then
      return true
    end
    return next(game, pointer)
  end

  mod.hooks:wrap("input.pointer", function(next, game, pointer)
    local forwarded = false
    local function forward(...)
      forwarded = true
      return next(...)
    end
    local ok, result = pcall(pointerRuntime.dispatch, forward, game, pointer)
    if ok then return result end
    -- A malformed third-party state or unusual pointer payload must never
    -- take down the client. Retire only this gesture and let the normal input
    -- path continue. Errors raised by a downstream hook are not ours to hide.
    if forwarded then error(result, 0) end
    if type(pointer) == "table" then
      local keyOk, failedKey = pcall(pointerCaptureKey, pointer)
      if keyOk then pointerCaptures[failedKey] = nil end
    end
    hoveredPointer = nil
    local message = tostring(result)
    if pointerRuntime.lastError ~= message then
      pointerRuntime.lastError = message
      if mod.log and type(mod.log.warn) == "function" then
        pcall(mod.log.warn, mod.log, "pointer interaction ignored: %s", message)
      end
    end
    return next(game, pointer)
  end, 100)

  -- TitleState and its menu are flattened into the same classic canvas. A
  -- whole-canvas clear would erase the logo and title Pokémon along with the
  -- menu, so suppress only the ordinary title Menu's draw method. The state
  -- still owns update/input/callbacks, and another mod's custom draw remains
  -- untouched because only an unmodified Menu instance is decorated.
  mod.hooks:wrap("ui.state.decorate", function(next, game, state, model)
    local decorated = next(game, state, model)
    if type(decorated) ~= "table" then decorated = state end
    -- The title menu is identified by its published titleUiBox contract, not
    -- by the stack top at decoration time.  v0.1.68 decorates the menu before
    -- it is pushed, so the old under-state check left the native rows visible.
    if inherits(classOf(decorated), menuClass)
        and type(decorated.titleUiBox) == "table"
        and not decorated._gen1ModernTitleMenu then
      local originalDraw = decorated.draw
      decorated._gen1ModernTitleMenu = true
      local function drawTitleMenu(self)
        if option("hideOriginalUi", true) ~= false
            and option("menuUi", true) ~= false then
          local stack = game and game.stack and game.stack.states
          local titleOnStack = false
          for _, visible in ipairs(type(stack) == "table" and stack or {}) do
            if isTitleState(visible) then titleOnStack = true break end
          end
          if titleOnStack then
            local layers, complete = presentationStack(game)
            if complete then
              for _, layer in ipairs(layers) do
                if layer.state == self then return end
              end
            end
          end
        end
        return originalDraw(self)
      end
      decorated._gen1ModernTitleDraw = drawTitleMenu
      decorated.draw = drawTitleMenu
    end
    -- Options opened from the title remain above TitleState, so both native
    -- screens share the title UI canvas. The normal compose fallback must
    -- preserve that canvas to keep the logo and title artwork visible; hide
    -- only the native OptionsMenu draw while the modern options presenter has
    -- proved it can render the complete state.
    if optionsClass and inherits(classOf(decorated), optionsClass)
        and type(decorated.draw) == "function"
        and not decorated._gen1ModernOptionsMenu then
      decorated._gen1ModernOptionsNativeDraw = decorated.draw
      decorated._gen1ModernOptionsMenu = true
      decorated.draw = function(self)
        if mod._gen1ModernSpecialPresenters.shouldHideNativeOptions(
            self.game or game or currentGame, self) then
          return
        end
        return self._gen1ModernOptionsNativeDraw(self)
      end
    end
    return decorated
  end, 100)

  -- render.zones is the last state-aware render hook before endFrame.  Cache
  -- its Game reference so render.compose can inspect this exact frame's top
  -- state without requiring engine internals or relying on a previous frame.
  mod.hooks:wrap("render.zones", function(next, game, zones)
    currentGame = game
    return next(game, zones)
  end, 100)

  -- render.compose receives the already-drawn world and UI canvases before
  -- the engine performs its normal whole-window composite.  Clearing only the
  -- UI canvas hides the classic interface while still letting the engine do
  -- its own world scaling, palette zones, fades, post-processing, and display
  -- effects.  Downstream compose hooks see the untouched canvas first; only
  -- the normal fall-through path is cleared, so another mod that takes over
  -- the whole window can still use the original UI if it needs it.
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    local game = currentGame
    local layers, complete, suppressCanvas = presentationStack(game)
    local hide = option("hideOriginalUi", true) ~= false
    if handled ~= true and hide and complete and #layers > 0
        and love and love.graphics and ctx and ctx.uiCanvas then
      if suppressCanvas then
        love.graphics.push("all")
        love.graphics.setCanvas(ctx.uiCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.pop()
      end
      -- TitleState and its Menu share the same canvas as the logo and title
      -- artwork. The title Menu decorator above already suppresses duplicate
      -- native rows when the modern presenter is complete, so never clear a
      -- rectangle here. Clearing the published `titleUiBox` exposes the
      -- window's black backdrop and turns the title screen into a black block.
    end
    return handled
  end, 100)

  -- render.hud runs after the normal composite and before touch controls, so
  -- the modern layer can use the entire window while the original state keeps
  -- ownership of keyboard/controller behavior and callbacks.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    currentGame = game
    next(game, viewport)
    if not (love and love.graphics) then return end
    spriteAnimationOn = option("spriteAnimation", true) ~= false
    local layers, complete = presentationStack(game)
    local topState = game and game.stack and game.stack.top
      and game.stack:top() or nil
    local modernWorld = option("menuUi", true) ~= false
      and option("hideOriginalUi", true) ~= false
    local overworldActive = game and game.overworld
      and topState == game.overworld
    local modernOwnsQolBanner = modernWorld
      and (overworldActive or (complete and #layers > 0))
    mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(
      game, modernOwnsQolBanner)
    if complete and #layers > 0 then
      drawModernStack(game, layers, viewportForTouchControls(game, viewport))
    else
      pointerRegions = {}
      pointerRuntime.topOrder = 0
      if pointerRuntime.topState ~= nil then
        for _, capture in pairs(pointerCaptures) do capture.invalid = true end
      end
      pointerRuntime.topState = nil
      hoveredPointer = nil
      if overworldActive and modernWorld then
        mod._gen1ModernSpecialPresenters.drawQolLocationBanner(
          game, viewportForTouchControls(game, viewport),
          responsiveTheme(currentTheme(viewport), viewport,
            responsiveThemeCache))
      end
    end
  end, 100)
end

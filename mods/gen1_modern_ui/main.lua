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
    textMuted = { 0.74, 0.82, 0.92, 1 },
    onAccent = { 0.02, 0.05, 0.09, 1 },
    divider = { 0.38, 0.50, 0.68, 0.94 },
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
      backdrop = { 0.018, 0.035, 0.070, 0.72 },
      surface = { 0.055, 0.085, 0.15, 0.94 },
      surfaceRaised = { 0.105, 0.155, 0.25, 0.96 },
      selected = { 0.20, 0.48, 0.78, 0.98 },
      textMuted = { 0.76, 0.84, 0.94, 1 },
      divider = { 0.38, 0.52, 0.72, 0.92 },
      health = {
        track = { 0.14, 0.21, 0.31, 1 },
        high = { 0.14, 0.78, 0.74, 1 },
        medium = { 0.98, 0.76, 0.22, 1 },
        low = { 1.00, 0.48, 0.18, 1 },
        critical = { 0.86, 0.43, 0.96, 1 },
      },
    },
  },
  {
    id = "gen1_modern_ui:classic_mono",
    name = "Classic Mono",
    colors = {
      backdrop = { 0.035, 0.035, 0.030, 0.76 },
      surface = { 0.96, 0.95, 0.89, 1 },
      surfaceRaised = { 0.86, 0.85, 0.78, 1 },
      selected = { 0.72, 0.77, 0.72, 1 },
      accent = { 0.06, 0.09, 0.12, 1 },
      text = { 0.035, 0.045, 0.055, 1 },
      textMuted = { 0.25, 0.30, 0.36, 1 },
      onAccent = { 0.98, 0.98, 0.93, 1 },
      divider = { 0.34, 0.40, 0.47, 0.94 },
      health = {
        track = { 0.78, 0.79, 0.72, 1 },
        high = { 0.02, 0.34, 0.48, 1 },
        medium = { 0.58, 0.32, 0.02, 1 },
        low = { 0.74, 0.16, 0.03, 1 },
        critical = { 0.42, 0.08, 0.52, 1 },
      },
    },
    radii = { sm = 2, md = 4, lg = 6 },
  },
  {
    id = "gen1_modern_ui:pocket_green",
    name = "Pocket Green",
    colors = {
      backdrop = { 0.035, 0.075, 0.040, 0.78 },
      surface = { 0.84, 0.88, 0.70, 1 },
      surfaceRaised = { 0.73, 0.80, 0.58, 1 },
      selected = { 0.62, 0.73, 0.46, 1 },
      accent = { 0.07, 0.20, 0.14, 1 },
      text = { 0.045, 0.095, 0.065, 1 },
      textMuted = { 0.18, 0.27, 0.19, 1 },
      onAccent = { 0.90, 0.95, 0.72, 1 },
      divider = { 0.27, 0.38, 0.24, 0.96 },
      health = {
        track = { 0.73, 0.79, 0.59, 1 },
        high = { 0.02, 0.34, 0.48, 1 },
        medium = { 0.58, 0.32, 0.02, 1 },
        low = { 0.74, 0.16, 0.03, 1 },
        critical = { 0.42, 0.08, 0.52, 1 },
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
      selected = { 0.24, 0.18, 0.48, 1 },
      accent = { 0.70, 0.58, 1.00, 1 },
      text = { 0.96, 0.95, 1.00, 1 },
      textMuted = { 0.74, 0.76, 0.89, 1 },
      onAccent = { 0.05, 0.03, 0.10, 1 },
      divider = { 0.34, 0.38, 0.54, 0.96 },
      health = {
        track = { 0.13, 0.16, 0.24, 1 },
        high = { 0.14, 0.78, 0.74, 1 },
        medium = { 0.98, 0.76, 0.22, 1 },
        low = { 1.00, 0.48, 0.18, 1 },
        critical = { 0.86, 0.43, 0.96, 1 },
      },
    },
  },
  {
    id = "gen1_modern_ui:midnight_glass",
    name = "Midnight Glass",
    colors = {
      backdrop = { 0.018, 0.022, 0.040, 0.58 },
      surface = { 0.035, 0.045, 0.075, 0.94 },
      surfaceRaised = { 0.075, 0.090, 0.150, 0.96 },
      selected = { 0.24, 0.18, 0.48, 0.98 },
      accent = { 0.70, 0.58, 1.00, 1 },
      text = { 0.96, 0.95, 1.00, 1 },
      textMuted = { 0.74, 0.76, 0.89, 1 },
      onAccent = { 0.05, 0.03, 0.10, 1 },
      divider = { 0.34, 0.38, 0.54, 0.94 },
      health = {
        track = { 0.13, 0.16, 0.24, 1 },
        high = { 0.14, 0.78, 0.74, 1 },
        medium = { 0.98, 0.76, 0.22, 1 },
        low = { 1.00, 0.48, 0.18, 1 },
        critical = { 0.86, 0.43, 0.96, 1 },
      },
    },
  },
  {
    id = "gen1_modern_ui:frost",
    name = "Frost",
    colors = {
      backdrop = { 0.055, 0.090, 0.140, 0.45 },
      surface = { 0.96, 0.98, 1.00, 1 },
      surfaceRaised = { 0.88, 0.93, 0.98, 1 },
      selected = { 0.38, 0.63, 0.88, 1 },
      accent = { 0.04, 0.38, 0.66, 1 },
      text = { 0.055, 0.095, 0.160, 1 },
      textMuted = { 0.24, 0.32, 0.43, 1 },
      onAccent = { 0.98, 1.00, 1.00, 1 },
      divider = { 0.36, 0.49, 0.63, 0.96 },
      health = {
        track = { 0.82, 0.88, 0.94, 1 },
        high = { 0.02, 0.34, 0.48, 1 },
        medium = { 0.58, 0.32, 0.02, 1 },
        low = { 0.74, 0.16, 0.03, 1 },
        critical = { 0.42, 0.08, 0.52, 1 },
      },
    },
  },
  {
    id = "gen1_modern_ui:light",
    name = "Light",
    colors = {
      backdrop = { 0.78, 0.80, 0.84, 1 },
      surface = { 0.98, 0.98, 0.96, 1 },
      surfaceRaised = { 0.89, 0.90, 0.88, 1 },
      selected = { 0.40, 0.63, 0.88, 1 },
      accent = { 0.07, 0.24, 0.46, 1 },
      text = { 0.035, 0.050, 0.085, 1 },
      textMuted = { 0.24, 0.29, 0.36, 1 },
      onAccent = { 1.00, 1.00, 1.00, 1 },
      divider = { 0.36, 0.43, 0.52, 1 },
      health = {
        track = { 0.78, 0.85, 0.92, 1 },
        high = { 0.02, 0.34, 0.48, 1 },
        medium = { 0.58, 0.32, 0.02, 1 },
        low = { 0.74, 0.16, 0.03, 1 },
        critical = { 0.42, 0.08, 0.52, 1 },
      },
    },
  },
  {
    id = "gen1_modern_ui:dark",
    name = "Dark",
    colors = {
      backdrop = { 0.012, 0.016, 0.024, 1 },
      surface = { 0.055, 0.065, 0.085, 1 },
      surfaceRaised = { 0.105, 0.125, 0.155, 1 },
      selected = { 0.25, 0.52, 0.78, 1 },
      accent = { 0.52, 0.85, 1.00, 1 },
      text = { 0.96, 0.98, 1.00, 1 },
      textMuted = { 0.73, 0.78, 0.88, 1 },
      onAccent = { 0.015, 0.035, 0.065, 1 },
      divider = { 0.34, 0.44, 0.56, 1 },
      health = {
        track = { 0.14, 0.19, 0.27, 1 },
        high = { 0.14, 0.78, 0.74, 1 },
        medium = { 0.98, 0.76, 0.22, 1 },
        low = { 1.00, 0.48, 0.18, 1 },
        critical = { 0.86, 0.43, 0.96, 1 },
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
local activeFontCache
local fontSizes = setmetatable({}, { __mode = "k" })

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
  if kind == "choice" or (kind == "menu"
      and not (state and state._gen1ModMenus)
      and not (state and state.title)
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
local ensurePixelTextFont

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
  local current = love.graphics.getFont()
  local selected = ensurePixelTextFont
    and ensurePixelTextFont(text, current) or current
  if selected and selected ~= current then love.graphics.setFont(selected) end
  local result = rawPrint(text, snapPixelTextCoordinate(x),
    snapPixelTextCoordinate(y), ...)
  if selected and selected ~= current then love.graphics.setFont(current) end
  return result
end

local function drawTextWrapped(text, x, y, width, align, ...)
  local current = love.graphics.getFont()
  local selected = ensurePixelTextFont
    and ensurePixelTextFont(text, current) or current
  if selected and selected ~= current then love.graphics.setFont(selected) end
  if type(width) == "number" and love.graphics.getFont()
      and pixelFontMetrics[love.graphics.getFont()] then
    local dpi = pixelTextDpi()
    width = math.max(1, math.floor(width * dpi + 0.5) / dpi)
  end
  local result = rawPrintf(text, snapPixelTextCoordinate(x),
    snapPixelTextCoordinate(y), width, align, ...)
  if selected and selected ~= current then love.graphics.setFont(current) end
  return result
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

local function font(cache, size, forcePixel)
  local pixels = math.max(10, math.floor((size or 16) + 0.5))
  activeFontCache = cache or activeFontCache
  local usePixel = forcePixel == true or cache and cache._usePixel == true
  local family = usePixel and "pixel" or "system"
  local raster, rasterScale = plainPixelRasterScale(pixels)
  local requestedRaster = usePixel and raster or pixels
  local key = family .. ":" .. requestedRaster
  if cache[key] then
    nativeGenderSigns = cache["gender:" .. key] == true
    fontSizes[cache[key]] = pixels
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
      local systemKey = "fallback:system:" .. raster
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
  fontSizes[selected] = pixels
  return selected
end

ensurePixelTextFont = function(text, current)
  current = current or love.graphics.getFont()
  if not activeFontCache or not current or pixelFontMetrics[current]
      or activeFontCache._usePixel == true or tostring(text or "") == ""
      or type(current.hasGlyphs) ~= "function" then
    return current
  end
  local ok, supported = pcall(current.hasGlyphs, current,
    tostring(text or ""))
  -- A font API failure is not evidence that the glyph is missing. Keep the
  -- selected face unless LÖVE explicitly reports incomplete coverage.
  if not ok or supported == true then return current end
  local pixels = fontSizes[current]
    or math.max(10, math.floor(current:getHeight() + 0.5))
  return font(activeFontCache, pixels, true) or current
end

local function fontForCurrentText(textFont, text)
  textFont = textFont or love.graphics.getFont()
  return ensurePixelTextFont(text, textFont) or textFont
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
  textFont = fontForCurrentText(textFont, text)
  if textFont:getWidth(text) <= maxWidth then return text end
  local suffix = "..."
  while #text > 0 and textFont:getWidth(text .. suffix) > maxWidth do
    text = removeLastTextCharacter(text)
  end
  return text .. suffix
end

local wrapFittedText = false

local function drawFittedText(text, x, y, maxWidth, textFont)
  local previousFont = love.graphics.getFont()
  text = safeText(text)
  textFont = fontForCurrentText(textFont, text)
  love.graphics.setFont(textFont)
  if wrapFittedText then
    drawTextWrapped(text, x, y, math.max(1, maxWidth), "left")
    if previousFont and previousFont ~= textFont then
      love.graphics.setFont(previousFont)
    end
    return
  end
  drawText(truncate(text, maxWidth, textFont), x, y)
  if previousFont and previousFont ~= textFont then
    love.graphics.setFont(previousFont)
  end
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
  textFont = fontForCurrentText(textFont, text)
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
  local previousFont = love.graphics.getFont()
  text = safeText(text)
  textFont = fontForCurrentText(textFont, text)
  lineGap = lineGap or (textHeight(textFont) + 2)
  local lines = wrappedLines(text, maxWidth, textFont)
  love.graphics.setFont(textFont)
  for index, line in ipairs(lines) do
    drawText(line, x, y + (index - 1) * lineGap)
  end
  if previousFont and previousFont ~= textFont then
    love.graphics.setFont(previousFont)
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

  local runtime = {}
  runtime.nativeNewGameGames = setmetatable({}, { __mode = "k" })
  runtime.stateGames = setmetatable({}, { __mode = "k" })
  local okStrings, engineStrings = pcall(require, "src.core.Strings")
  runtime.fallbackStrings = function(value, ...)
    if select("#", ...) == 0 then return value end
    local ok, formatted = pcall(string.format, value, ...)
    return ok and formatted or value
  end
  local Strings = okStrings and engineStrings or runtime.fallbackStrings
  local okTypeChart, typeChart = pcall(require, "src.battle.TypeChart")
  runtime.displayType = function(value)
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

  -- Third-party presenters are intentionally data-only. Source mods keep
  -- ownership of their state and semantic actions, while this registry only
  -- decides whether a public model can be rendered safely. Keeping the
  -- registry on the mod object avoids spending another factory-scope local;
  -- LuaJIT's 200-local limit is easy to hit in this deliberately broad
  -- presenter module.
  mod._gen1ModernCompatibility = {
    apiVersion = API_VERSION,
    adapters = {},
    active = setmetatable({}, { __mode = "k" }),
    errors = {},
    legacy = {},
    frames = {},
    frameChoices = { { "FRAME 1", "1" }, { "FRAME 2", "2" },
      { "FRAME 3", "3" } },
    assetOwners = {},
    knownOwners = { "rby_mmo", "dex_radar", "useful_dex", "gen3_box",
      "modern_bag", "useful_bag", "dv_tracker",
      "quality_of_life", "qol", "dramatic_shape", "dramatic_shape_voxel",
      "pokemon-gen1-recomp-mod-qol" },
  }

  -- Useful Bag is a separate source mod. Its current release deliberately
  -- keeps the engine's BagMenu/ListMenu and decorates the live state with a
  -- pocket projection instead of publishing the older `modernBag` model.
  -- Recognize that documented runtime shape without calling its projection
  -- function or reaching into its private modules. This keeps the source
  -- mod in charge of inventory mutations, sorting, and callbacks while the
  -- modern presenter owns only the visual pass.
  function mod._gen1ModernCompatibility:isUsefulBagState(state)
    if type(state) ~= "table" or state.screenId ~= "BagMenu"
        or type(state.items) ~= "table" then return false end
    if type(state.modernBag) == "table" then return true end
    return type(state.__pocketIndex) == "number"
      and type(state.__pocketIds) == "table"
      and type(state.__project) == "function"
  end

  function mod._gen1ModernCompatibility:bagHasPockets(state)
    return self:isUsefulBagState(state)
  end

  function mod._gen1ModernCompatibility:recordError(owner, message)
    self.errors[owner or "unknown"] = safeText(message)
  end

  function mod._gen1ModernCompatibility:containsFunction(value, seen, active)
    if type(value) ~= "table" then return type(value) == "function" end
    seen = seen or {}
    active = active or {}
    if active[value] then return true end
    if seen[value] then return false end
    seen[value] = true
    active[value] = true
    for _, child in pairs(value) do
      if self:containsFunction(child, seen, active) then return true end
    end
    active[value] = nil
    return false
  end

  function mod._gen1ModernCompatibility:validate(contract)
    if type(contract) ~= "table" then return false, "contract is not a table" end
    if tonumber(contract.apiVersion) ~= self.apiVersion then
      return false, "unsupported gen1ModernUi apiVersion"
    end
    if type(contract.screens) ~= "table" then
      return false, "contract.screens is required"
    end
    if contract.themes ~= nil and type(contract.themes) ~= "table" then
      return false, "contract.themes must be a table"
    end
    if contract.frames ~= nil and type(contract.frames) ~= "table" then
      return false, "contract.frames must be a table"
    end
    if self:containsFunction(contract.themes)
        or self:containsFunction(contract.frames) then
      return false, "themes and frames cannot contain callbacks"
    end
    for frameId, frame in pairs(contract.frames or {}) do
      if type(frameId) ~= "string" then
        return false, "frame IDs must be strings"
      end
      local asset = type(frame) == "table"
        and (frame.asset or frame.image or frame.texture or frame.path) or frame
      if type(asset) ~= "string" and type(asset) ~= "userdata"
          and type(asset) ~= "table" then
        return false, "frame assets must be declared paths or public images"
      end
    end
    for themeId, theme in pairs(contract.themes or {}) do
      if type(themeId) ~= "string" or type(theme) ~= "table"
          or (theme.id ~= nil and type(theme.id) ~= "string") then
        return false, "theme IDs and specs must be strings and tables"
      end
    end
    for screenId, screen in pairs(contract.screens) do
      if type(screenId) ~= "string" or type(screen) ~= "table"
          or type(screen.match) ~= "function"
          or type(screen.model) ~= "function" then
        return false, "screen descriptors require match and model functions"
      end
      if screen.draw or screen.render or screen.drawCallback then
        return false, "custom draw callbacks are not supported"
      end
      if screen.layer ~= nil and type(screen.layer) ~= "string" then
        return false, "screen.layer must be a string"
      end
      if screen.canSuppressNative ~= nil
          and type(screen.canSuppressNative) ~= "boolean" then
        return false, "screen.canSuppressNative must be boolean"
      end
      if screen.actions ~= nil and type(screen.actions) ~= "table" then
        return false, "screen.actions must be a table"
      end
      if screen.themes ~= nil or screen.frames ~= nil then
        return false, "themes and frames belong on the contract, not screens"
      end
      for action, callback in pairs(screen.actions or {}) do
        if action ~= "up" and action ~= "down" and action ~= "left"
            and action ~= "right" and action ~= "select" and action ~= "back"
            and action ~= "start" and action ~= "hover" then
          return false, "unsupported semantic action: " .. tostring(action)
        end
        if type(callback) ~= "function" then
          return false, "semantic actions must be functions"
        end
      end
    end
    return true
  end

  function mod._gen1ModernCompatibility:ownerActive(owner)
    if type(owner) ~= "string" or owner == "" or owner == MOD_ID
        or type(mod.find) ~= "function" then return false end
    local ok, handle = pcall(mod.find, owner)
    return ok and type(handle) == "table"
  end

  function mod._gen1ModernCompatibility:clearOwnerAssets(owner)
    local owned = self.assetOwners[owner]
    if type(owned) ~= "table" then return end
    for id in pairs(owned.frames or {}) do
      self.frames[id] = nil
      for index = #self.frameChoices, 1, -1 do
        if self.frameChoices[index][2] == id then
          table.remove(self.frameChoices, index)
        end
      end
    end
    for id in pairs(owned.themes or {}) do
      themes[id] = nil
      for index = #themeChoices, 1, -1 do
        if themeChoices[index][2] == id then
          table.remove(themeChoices, index)
        end
      end
    end
    self.assetOwners[owner] = nil
  end

  function mod._gen1ModernCompatibility:register(spec)
    if type(spec) ~= "table" then
      return false, "adapter registration must be a table"
    end
    local owner = spec.owner or spec.sourceModId or spec.modId
    local contract = spec.contract or spec
    if type(owner) ~= "string" or owner == "" or owner == MOD_ID then
      return false, "adapter owner must be the source mod id"
    end
    local valid, reason = self:validate(contract)
    if not valid then
      self:recordError(owner, reason)
      return false, reason
    end
    if not self:ownerActive(owner) then
      return false, "source mod is not active"
    end
    self:clearOwnerAssets(owner)
    self.errors[owner] = nil
    self.adapters[owner] = {
      owner = owner,
      version = spec.version,
      contract = contract,
    }
    -- Themes and frames are optional data extensions of the same public
    -- contract. They are registered only through the Gen1 Modern UI export;
    -- the source mod still owns the image/path and must use a namespaced ID.
    if contract.frames ~= nil then
      for frameId, frame in pairs(contract.frames) do
        local frameSpec = type(frame) == "table" and copy(frame) or {
          asset = frame,
        }
        frameSpec.owner = owner
        frameSpec.id = frameSpec.id or frameId
        local registered, frameError = self:registerFrame(frameSpec)
        if not registered then
          self:recordError(owner, "frame registration failed: "
            .. tostring(frameError))
        end
      end
    end
    if contract.themes ~= nil and mod.exports
        and type(mod.exports.registerTheme) == "function" then
      for themeId, theme in pairs(contract.themes) do
        if type(theme) == "table" then
          local themeSpec = copy(theme)
          themeSpec.id = themeSpec.id or themeId
          themeSpec.owner = owner
          if not themeSpec.id:find(":", 1, true) then
            themeSpec.id = owner .. ":" .. themeSpec.id
          end
          local okTheme, themeError = pcall(mod.exports.registerTheme,
            themeSpec)
          if okTheme then
            local owned = self.assetOwners[owner] or { themes = {}, frames = {} }
            owned.themes[themeSpec.id] = true
            self.assetOwners[owner] = owned
          else
            self:recordError(owner, "theme registration failed: "
              .. tostring(themeError))
          end
        end
      end
    end
    self.active = setmetatable({}, { __mode = "k" })
    return true
  end

  function mod._gen1ModernCompatibility:unregister(owner)
    if type(owner) ~= "string" then return false end
    self.adapters[owner] = nil
    self:clearOwnerAssets(owner)
    self.active = setmetatable({}, { __mode = "k" })
    return true
  end

  function mod._gen1ModernCompatibility:pruneAssets()
    -- Direct theme/frame registration is useful for theme-only mods that do
    -- not publish a screen adapter. Keep those assets tied to an active
    -- source mod so a disable/reload cannot leave stale choices behind.
    for owner in pairs(self.assetOwners) do
      if not self:ownerActive(owner) then self:clearOwnerAssets(owner) end
    end
  end

  function mod._gen1ModernCompatibility:registerFrame(spec)
    if type(spec) ~= "table" then
      return false, "frame registration must be a table"
    end
    local owner = spec.owner or spec.sourceModId or spec.modId
    local id = spec.id
    local asset = spec.asset or spec.image or spec.texture or spec.path
    if type(owner) ~= "string" or owner == "" or owner == MOD_ID
        or type(id) ~= "string" or id == "" then
      return false, "frame owner and id are required"
    end
    if not id:find(":", 1, true) then id = owner .. ":" .. id end
    if type(asset) ~= "string" and type(asset) ~= "userdata"
        and type(asset) ~= "table" then
      return false, "frame asset must be a declared path or public image"
    end
    if self:containsFunction(asset) then
      return false, "frame assets cannot contain callbacks"
    end
    if not self:ownerActive(owner) then return false, "source mod is not active" end
    self.frames[id] = asset
    local label = safeText(spec.name or spec.label or id)
    local found
    for _, choice in ipairs(self.frameChoices) do
      if choice[2] == id then
        choice[1] = label
        found = true
        break
      end
    end
    if not found then self.frameChoices[#self.frameChoices + 1] = { label, id } end
    local owned = self.assetOwners[owner] or { themes = {}, frames = {} }
    owned.frames[id] = true
    self.assetOwners[owner] = owned
    return id
  end

  function mod._gen1ModernCompatibility:frameAsset(value)
    value = safeText(value)
    if value == "1" then return "assets/pixel_frame1.png" end
    if value == "2" then return "assets/pixel_frame2.png" end
    if value == "3" then return "assets/pixel_frame3.png" end
    if self.frames[value] ~= nil then return value end
    return "assets/pixel_frame2.png"
  end

  function mod._gen1ModernCompatibility:adapterFor(game, state)
    if type(state) ~= "table" then return nil end
    self:discover()
    for owner, entry in pairs(self.adapters) do
      if self:ownerActive(owner) then
        for screenId, screen in pairs(entry.contract.screens) do
          local ok, matched = pcall(screen.match, state)
          if not ok then
            self:recordError(owner, "screen match failed: " .. tostring(screenId))
          elseif matched == true then
            local context = { owner = owner, id = screenId, screen = screen,
              entry = entry }
            self.active[state] = context
            return context
          end
        end
      else
        self:unregister(owner)
        self.errors[owner] = nil
      end
    end
    self.active[state] = nil
    return nil
  end

  function mod._gen1ModernCompatibility:discover()
    self:pruneAssets()
    if type(mod.find) ~= "function" then return 0 end
    local discovered = 0
    for _, owner in ipairs(self.knownOwners) do
      local ok, handle = pcall(mod.find, owner)
      local exports = ok and type(handle) == "table" and handle.exports or nil
      local contract = type(exports) == "table"
        and exports.gen1ModernUi or nil
      local existing = self.adapters[owner]
      if type(contract) == "table" then
        local valid, reason = self:validate(contract)
        if not valid then
          if existing then self:unregister(owner) end
          self:recordError(owner, reason)
        else
          -- Re-register when a reload replaces the public export table. Models
          -- remain live when the table is mutated in place, while a new table
          -- safely invalidates the old screen context and assets.
          if not existing or existing.contract ~= contract then
            local registered = self:register({ owner = owner, contract = contract,
              version = handle.version })
            if registered then discovered = discovered + 1 end
          end
        end
      elseif existing then
        self:unregister(owner)
        self.errors[owner] = nil
      end
    end
    return discovered
  end

  function mod._gen1ModernCompatibility:modelFor(game, state, context)
    context = context or self.active[state] or self:adapterFor(game, state)
    if not context or type(context.screen.model) ~= "function" then return nil end
    local ok, model = pcall(context.screen.model, game, state)
    if not ok or type(model) ~= "table" or self:containsFunction(model) then
      self:recordError(context.owner, "screen model failed: " .. context.id)
      self.active[state] = nil
      return nil
    end
    if type(model.rows) ~= "table" then
      self:recordError(context.owner, "screen model has no rows: " .. context.id)
      self.active[state] = nil
      return nil
    end
    local normalizedOk, normalized = pcall(function()
      local out = {
        title = model.title,
        rows = {},
        index = math.max(1, math.floor(tonumber(model.index) or 1)),
        scroll = math.max(0, math.floor(tonumber(model.scroll) or 0)),
        footer = copy(model.footer),
        details = copy(model.details),
        assets = copy(model.assets),
        -- Battle adapters use the same read-only model contract, with a
        -- small set of semantic fields that the built-in presenter already
        -- understands. No callbacks or drawing functions cross this seam.
        kind = model.kind,
        phase = model.phase,
        mode = model.mode,
        presentation = model.presentation,
        voxel = model.voxel,
        voxel3d = model.voxel3d,
        isVoxelBattle = model.isVoxelBattle,
        player = copy(model.player),
        enemy = copy(model.enemy),
        moves = copy(model.moves),
        message = model.message,
        overlays = copy(model.overlays),
        slots = copy(model.slots),
      }
      for index, row in ipairs(model.rows) do
        if type(row) == "string" or type(row) == "number" then
          out.rows[index] = { label = safeText(row) }
        elseif type(row) == "table" then
          out.rows[index] = copy(row)
        else
          out.rows[index] = { label = "" }
        end
      end
      return out
    end)
    if not normalizedOk then
      self:recordError(context.owner, "screen model normalization failed: "
        .. context.id)
      self.active[state] = nil
      return nil
    end
    context.model = normalized
    return normalized
  end

  function mod._gen1ModernCompatibility:action(game, state, action, payload)
    local context = self.active[state] or self:adapterFor(game, state)
    local callback = context and context.screen.actions
      and context.screen.actions[action]
    if type(callback) ~= "function" then return false end
    local ok, result = pcall(callback, game, state, payload)
    if not ok then
      self:recordError(context.owner, "semantic action failed: " .. tostring(action))
      self.active[state] = nil
      return false
    end
    return result ~= false
  end

  -- These bridges are the compatibility-safe home for the currently shipped
  -- public RBYMMO and Dex Radar state models. They remain until those mods
  -- publish their versioned export; no private class/module identity is used.
  mod._gen1ModernCompatibility.legacy = {
    { kind = "rby_mmo_profile", match = isRbyMmoProfileState },
    { kind = "rby_mmo_rank", match = isRbyMmoRankState },
    { kind = "rby_mmo_char_pick", match = isRbyMmoCharacterPickState },
    { kind = "dex_radar", match = function(state)
      return type(state) == "table" and state.screenId == "DexRadar"
        and type(state.rows) == "table" and type(state.monIndex) == "table"
        and type(state.cursor) == "number" and type(state.mapLabel) == "string"
    end },
  }

  function mod._gen1ModernCompatibility:legacyKind(state)
    for _, bridge in ipairs(self.legacy) do
      local ok, matched = pcall(bridge.match, state)
      if ok and matched then return bridge.kind end
    end
    return nil
  end

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
      local pocket = bag and (bag.pocket or bag.tab or bag.index)
        or state.__pocketIndex or state.title
      return tostring(state.items) .. ":" .. tostring(pocket)
    elseif kind == "menu" or kind == "list" or kind == "shop_list"
        or kind == "pc_list" or kind == "box_root"
        or kind == "box_mon_list" then
      return tostring(state.items)
    elseif kind == "options" or kind == "mod_options" then
      return tostring(state.rows)
    end
    return safeText(state.screenId or kind)
  end

  runtime.registerPointerRegion = function(x, y, w, h, metadata)
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

  runtime.panelOffsets = function()
    if savedPanelOffsets ~= nil then return savedPanelOffsets end
    local loaded
    if mod.save and type(mod.save.get) == "function" then
      local ok, value = pcall(mod.save.get, mod.save, "panelOffsets", {})
      if ok and type(value) == "table" then loaded = value end
    end
    savedPanelOffsets = loaded or {}
    return savedPanelOffsets
  end

  runtime.layerOffset = function(kind, viewport)
    local _, _, width, height = presenterRect(viewport)
    local key = safeText(kind or "screen")
    local stored = panelOffsetMemory[key] or runtime.panelOffsets()[key]
    local normalizedX = stored and tonumber(stored.x) or 0
    local normalizedY = stored and tonumber(stored.y) or 0
    normalizedX = clamp(normalizedX, -0.45, 0.45)
    normalizedY = clamp(normalizedY, -0.45, 0.45)
    return normalizedX * width, normalizedY * height
  end

  runtime.rememberLayerOffset = function(kind, viewport, x, y, persist)
    local _, _, width, height = presenterRect(viewport)
    local key = safeText(kind or "screen")
    local normalized = {
      x = clamp((tonumber(x) or 0) / math.max(1, width), -0.45, 0.45),
      y = clamp((tonumber(y) or 0) / math.max(1, height), -0.45, 0.45),
    }
    panelOffsetMemory[key] = normalized
    if persist and mod.save and type(mod.save.set) == "function" then
      local values = copy(runtime.panelOffsets())
      values[key] = copy(normalized)
      pcall(mod.save.set, mod.save, "panelOffsets", values)
      savedPanelOffsets = values
    end
    return normalized.x * width, normalized.y * height
  end

  runtime.prepareImage = function(image)
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
  runtime.modAssetImage = function(relative)
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
      image = runtime.prepareImage(image)
      modAssetCache[relative] = image
      return image
    end
    modAssetCache[relative] = false
    return nil
  end

  runtime.markAnimated = function(image, options)
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

  runtime.imageMetrics = function(image)
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

  runtime.drawImage = function(image, x, y, rotation, scaleX, scaleY)
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

  runtime.drawImageFit = function(image, x, y, w, h, maxScale)
    local iw, ih = runtime.imageMetrics(image)
    if not iw or not ih or w <= 0 or h <= 0 then return false end
    local scale = math.min(w / iw, h / ih)
    if maxScale then scale = math.min(scale, maxScale) end
    scale = math.max(0.01, scale)
    setColor({ 1, 1, 1, 1 })
    return runtime.drawImage(image, x + (w - iw * scale) / 2,
      y + (h - ih * scale) / 2, 0, scale, scale)
  end

  runtime.imageFor = function(value, options)
    local descriptor
    value, descriptor = imageDescriptor(value)
    if not value then return nil end
    options = merge(descriptor, options or {})
    if type(value) == "userdata" then
      local image = runtime.prepareImage(value)
      return runtime.markAnimated(image, options)
    end
    if imageCache[value] == false then return nil end
    if imageCache[value] then
      return runtime.markAnimated(imageCache[value], options)
    end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, value)
    if ok and image then
      imageCache[value] = runtime.prepareImage(image)
      return runtime.markAnimated(imageCache[value], options)
    end
    imageCache[value] = false
    return nil
  end

  function paletteRuntime.worldImage(game, value)
    return paletteRuntime.setImage(runtime.imageFor(value), paletteRuntime.world(game))
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
    local image = runtime.imageFor(imageValue)
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
      return runtime.drawImageFit(image, x, y, w, h)
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

  runtime.themeAssetFor = function(value)
    local registered = mod._gen1ModernCompatibility.frames[value]
    if registered ~= nil then value = registered end
    local image = runtime.imageFor(value)
    if image then return image end
    return runtime.modAssetImage(value)
  end

  -- PokePCFollowers registers its 6-frame overworld sheets as `frames = 1`
  -- because the engine's icon registry expects one image descriptor.  The
  -- resulting 16x96 sheet must still be cropped to one 16px frame or it
  -- appears as a paper-thin sliver in modern party/box rows. Keep this
  -- compatibility rule path-scoped so unrelated authored tall artwork is
  -- never silently reinterpreted.
  runtime.knownSheetOptions = function(value, image, staticFrame)
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

  runtime.option = function(key, default)
    local value = mod.options:get(key)
    return value == nil and default or value
  end

  runtime.drawHint = function(theme, value, x, y, maxWidth)
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

  runtime.hintHasExtraControls = function(value)
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

  runtime.hintIsBasicButtonText = function(value)
    local text = safeText(value)
    return text:match("%f[%a]A%f[%A]") ~= nil
      or text:match("%f[%a]B%f[%A]") ~= nil
  end

  runtime.shouldDrawHint = function(value)
    local text = safeText(value)
    if text == "" then return false end
    if not runtime.hintIsBasicButtonText(text) then return true end
    return runtime.hintHasExtraControls(text)
  end

  runtime.drawHintIfUseful = function(theme, value, x, y, maxWidth)
    if not runtime.shouldDrawHint(value) then return false end
    runtime.drawHint(theme, value, x, y, maxWidth)
    return true
  end

  runtime.currentTheme = function(viewport, fontState)
    local usePixelFont = runtime.option("pixelFont", false) == true
    activeFontCache = fontCache
    -- The explicit preference is screen-wide. Automatic fallback is decided
    -- separately for each measured/drawn string from Font:hasGlyphs, so an
    -- unsupported row can never change the face used by its neighbours or by
    -- later frames while a menu scrolls.
    fontCache._fontState = fontState
    fontCache._usePixel = usePixelFont
    local base = themes[runtime.option("theme", "gen1_modern_ui:classic_mono")]
      or themes["gen1_modern_ui:classic_mono"] or themes.default
    local uiPercent, uiAuto = resolvedScalePercent(runtime.option("uiScale", 100),
      viewport, 75, 150)
    local fontPercent, fontAuto
    if usePixelFont then
      fontPercent = tonumber(normalizedPixelFontScale(
        runtime.option("fontScale", 100), true)) or 100
      fontAuto = false
    else
      fontPercent, fontAuto = resolvedScalePercent(runtime.option("fontScale", 100),
        viewport, 80, 200)
    end
    local uiScale = uiPercent / 100
    local fontScale = fontPercent / 100
    local density = safeText(runtime.option("density", "auto"))
    local frameStyle = safeText(runtime.option("frameStyle", "pixel"))
    local frameAsset = safeText(runtime.option("frameAsset", "2"))
    local frameValue = mod._gen1ModernCompatibility:frameAsset(frameAsset)
    local frameScale = clamp(math.floor(
      tonumber(runtime.option("frameScale", 2)) or 2), 1, 4)
    local dpiX = math.max(1, tonumber(viewport and viewport.dpiX) or 1)
    local dpiY = math.max(1, tonumber(viewport and viewport.dpiY) or 1)
    local panelOpacity = clamp((tonumber(runtime.option("panelOpacity", 100)) or 100) / 100, 0, 1)
    local foregroundOpacity = clamp((tonumber(runtime.option("foregroundOpacity", 100)) or 100) / 100, 0, 1)
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
    if frameStyle ~= "theme" then theme.frame.asset = frameValue end
    theme.frame.pixelScale = frameScale
    theme.frame.pixelDpiX = dpiX
    theme.frame.pixelDpiY = dpiY
    if frameStyle == "pixel" or frameStyle == "soft" then
      theme.frame.style = frameStyle
    elseif frameStyle == "plain" then
      theme.frame.style = "none"
    elseif frameStyle == "theme" and not theme.frame.style then
      theme.frame.style = "pixel"
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

  runtime.dialogueMultiplier = function()
    local value = runtime.option("dialogueTextScale", "inherit")
    if value == nil or value == "inherit" then return 1 end
    return normalizedPercent(value, 100, 100, 200) / 100
  end

  runtime.dialogueTheme = function(theme)
    local multiplier = runtime.dialogueMultiplier()
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

  runtime.registerTheme = function(spec)
    assert(type(spec) == "table", "theme must be a table")
    assert(type(spec.id) == "string" and spec.id ~= "",
      "theme.id must be a non-empty string")
    if spec.id ~= "default" and not spec.id:find(":", 1, true) then
      error("theme.id must be namespaced as mod_id:name")
    end
    local owner = spec.owner or spec.sourceModId
    if owner ~= nil then
      assert(type(owner) == "string" and owner ~= "" and owner ~= MOD_ID,
        "theme owner must be the source mod id")
      assert(mod._gen1ModernCompatibility:ownerActive(owner),
        "theme source mod is not active")
    end
    local publicSpec = copy(spec)
    publicSpec.owner = nil
    publicSpec.sourceModId = nil
    local theme = merge(DEFAULT_THEME, publicSpec)
    theme.id = spec.id
    themes[spec.id] = theme
    if owner then
      local owned = mod._gen1ModernCompatibility.assetOwners[owner]
        or { themes = {}, frames = {} }
      owned.themes[spec.id] = true
      mod._gen1ModernCompatibility.assetOwners[owner] = owned
    end
    for _, choice in ipairs(themeChoices) do
      if choice[2] == spec.id then
        choice[1] = theme.name or spec.id
        return spec.id
      end
    end
    themeChoices[#themeChoices + 1] = { theme.name or spec.id, spec.id }
    return spec.id
  end

  for _, theme in ipairs(BUILTIN_THEMES) do runtime.registerTheme(theme) end

  mod.exports = {
    version = API_VERSION,
    compatibilityApiVersion = API_VERSION,
    registerTheme = runtime.registerTheme,
    themes = themes,
    -- Source mods should pass their own public `mod.exports.gen1ModernUi`
    -- table here. The UI never loads sibling files or private modules.
    registerAdapter = function(spec)
      return mod._gen1ModernCompatibility:register(spec)
    end,
    unregisterAdapter = function(owner)
      return mod._gen1ModernCompatibility:unregister(owner)
    end,
    registerFrame = function(spec)
      return mod._gen1ModernCompatibility:registerFrame(spec)
    end,
    frames = mod._gen1ModernCompatibility.frames,
    frameChoices = mod._gen1ModernCompatibility.frameChoices,
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
      local uiPercent = resolvedScalePercent(runtime.option("uiScale", 100),
        viewport, 75, 150)
      local pixelFont = runtime.option("pixelFont", false) == true
      local fontPercent = pixelFont
        and tonumber(normalizedPixelFontScale(runtime.option("fontScale", 100), true))
        or resolvedScalePercent(runtime.option("fontScale", 100), viewport, 80, 200)
      return {
        uiScale = uiPercent / 100,
        fontScale = fontPercent / 100,
        dialogueTextScale = runtime.dialogueMultiplier(),
      }
    end,
  }

  runtime.percentChoices = function(minimum, maximum, includeAuto)
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
      description = "Choose the authored PNG used when PIXEL framing is active. Source mods may add namespaced borders.",
      choices = mod._gen1ModernCompatibility.frameChoices, default = "2" },
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
      choices = runtime.percentChoices(75, 150, true), default = "100" },
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
    { key = "battleUiMode", label = "BATTLE UI MODE", type = "choice",
      description = "AUTO frames ordinary 2D battles and uses compact scene-safe placement for voxel/3D battles. Both keep native battle animations running.",
      choices = { { "AUTO", "auto" }, { "2D FRAMED", "full" },
                  { "SCENE HUD", "hud" } }, default = "auto" },
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
  runtime.layoutStyle = function(viewport)
    local selected = runtime.option("layoutStyle", nil)
    if selected == "full" or selected == "floating" then return selected end
    -- Migrate the old boolean only when a user explicitly disabled it. The
    -- new adaptive default is floating on every device, including phones.
    if (selected == nil or selected == "auto")
        and runtime.option("desktopFloating", true) == false then return "full" end
    return "floating"
  end

  runtime.worldVisibleLayout = function(viewport)
    return runtime.layoutStyle(viewport) ~= "full"
  end

  -- Filled screens (Party, Pokédex, Trainer Card, PC, and several third-
  -- party presenters) are opaque engine states. Clearing `uiCanvas` cannot
  -- reveal a world that StateStack never drew, so the input-step sync below
  -- temporarily makes eligible, modernized states transparent to the draw
  -- stack. The original value is restored as soon as FULL SCREEN, classic
  -- fallback, or an unsupported/custom draw becomes active.
  local syncWorldVisibility

  runtime.drawPresenterBackdrop = function(theme, viewport)
    -- Every rich presenter (Party, PC, Trainer Card, Pokédex, Bag, and
    -- third-party adapters) comes through this helper.  Keeping the decision
    -- here prevents one screen from accidentally blacking out the world when
    -- the user selected FLOATING or ADAPTIVE.
    -- Panel offsets move the UI surface, not the world/backdrop underneath it.
    local backdropViewport = pointerDrawContext
      and pointerDrawContext.baseViewport or viewport
    if runtime.worldVisibleLayout(backdropViewport) then return false end
    local x, y, w, h = fullViewportRect(backdropViewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", x, y, w, h)
    return true
  end

  runtime.drawModalScrim = function(theme, viewport)
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
  runtime.optionalClass = function(path)
    local ok, class = pcall(require, path)
    return ok and class or false
  end
  local trainerCardClass = runtime.optionalClass("src.ui.TrainerCard")
  local optionsClass = runtime.optionalClass("src.ui.OptionsMenu")
  local partyClass = runtime.optionalClass("src.ui.PartyMenu")
  local summaryClass = runtime.optionalClass("src.ui.SummaryMenu")
  local dexEntryClass = runtime.optionalClass("src.ui.DexEntryMenu")
  mod._gen1ModernSpecialClasses = {
    moveLearn = runtime.optionalClass("src.ui.MoveLearnMenu"),
    picBox = runtime.optionalClass("src.ui.PicBox"),
    naming = runtime.optionalClass("src.ui.NamingScreen"),
    townMap = runtime.optionalClass("src.ui.TownMap"),
    quarantineReport = runtime.optionalClass("src.ui.QuarantineReport"),
  }
  local managerClass = runtime.optionalClass("src.mods.ManagerState")
  local titleClass = runtime.optionalClass("src.ui.TitleState")
  -- LinkState is a released custom state rather than a Menu/ListMenu.  Keep
  -- it optional so older clients simply fall back to their native link UI.
  local linkClass = runtime.optionalClass("src.link.LinkState")
  local runtimeClasses = {
    linkCodeEntry = runtime.optionalClass("src.link.CodeEntry"),
    linkNet = runtime.optionalClass("src.link.Net"),
    oakSpeech = runtime.optionalClass("src.ui.OakSpeech"),
    stats = runtime.optionalClass("src.pokemon.Stats"),
  }
  -- The released overworld is a singleton class table rather than a normal
  -- instance. Its drawUI method is therefore a legitimate raw field. Capture
  -- the shipped identities once so a replaced world renderer still triggers
  -- the conservative classic fallback. Additive drawUI wrappers (for example
  -- Quality of Life's location banner) are allowed when the world draw itself
  -- remains the released renderer, so they do not disable every menu layered
  -- over the overworld.
  local overworldClass = runtime.optionalClass("src.world.OverworldController")
  runtimeClasses.overworldDraw = overworldClass
    and rawget(overworldClass, "draw") or nil
  runtimeClasses.overworldDrawUI = overworldClass
    and rawget(overworldClass, "drawUI") or nil

  runtime.isTitleState = function(state)
    if not (state and titleClass) then return false end
    -- v0.1.68 can omit the screenId stamp on the title instance while still
    -- exposing the released TitleState class. Accept either identity signal.
    return state.screenId == "TitleState"
      or inherits(classOf(state), titleClass)
  end

  -- New Game clears TitleState before pushing OakSpeech, then layers native
  -- TextBox, Menu, and NamingScreen states above it. Treat that complete stack
  -- branch as one source-owned flow: partial replacement breaks Oak's speech,
  -- the name choices, and the fixed-size native keyboard.
  runtime.isOakSpeechState = function(state)
    if not state then return false end
    return state.screenId == "OakSpeech"
      or (runtimeClasses.oakSpeech
        and inherits(classOf(state), runtimeClasses.oakSpeech))
      or false
  end

  runtime.markNativeNewGame = function(game)
    if game then runtime.nativeNewGameGames[game] = true end
  end

  runtime.stackContainsState = function(game, state)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" or not state then return false end
    for index = #states, 1, -1 do
      if states[index] == state then return true end
    end
    return false
  end

  -- StateStack lifecycle payloads contain only the state. Cache ownership as
  -- states are pushed so render-visible and naming hooks can still recognize
  -- nested Oak menus even before render.zones refreshes currentGame.
  runtime.ownerGame = function(state, fallback)
    if not state then return fallback end
    local game = state.game or runtime.stateGames[state]
    if game then return game end
    if fallback and runtime.stackContainsState(fallback, state) then
      runtime.stateGames[state] = fallback
      return fallback
    end
    for knownGame in pairs(runtime.nativeNewGameGames) do
      if runtime.stackContainsState(knownGame, state) then
        runtime.stateGames[state] = knownGame
        return knownGame
      end
    end
    return fallback
  end

  runtime.stackHasOakSpeech = function(game)
    local states = game.stack and game.stack.states
    if type(states) ~= "table" then return false end
    for index = #states, 1, -1 do
      if runtime.isOakSpeechState(states[index]) then return true end
    end
    return false
  end

  runtime.hasNativeNewGameFlow = function(game)
    if not game then return false end
    if runtime.stackHasOakSpeech(game) then
      runtime.markNativeNewGame(game)
      local states = game.stack and game.stack.states
      if type(states) == "table" then
        for index = 1, #states do
          runtime.stateGames[states[index]] = game
        end
      end
      return true
    end
    runtime.nativeNewGameGames[game] = nil
    return false
  end

  runtime.isNativeNewGameState = function(game, state)
    game = runtime.ownerGame(state, game)
    if not (game and state) then return false end
    if runtime.isOakSpeechState(state) then return true end
    if not runtime.hasNativeNewGameFlow(game) then return false end
    local states = game and game.stack and game.stack.states
    if type(states) == "table" then
      for index = #states, 1, -1 do
        if states[index] == state then return true end
      end
    end
    return runtime.ownerGame(state, game) == game
  end

  runtime.isLinkState = function(state)
    return linkClass and state and inherits(classOf(state), linkClass) or false
  end

  -- TitleState's palette pass honors the Menu `titleUiBox` as a true-color
  -- zone. The native box covers only its left-side tile rectangle, which is
  -- useful for the classic menu but leaves a modern floating menu over a
  -- partly monochrome title. When our title menu is active, expand that zone
  -- to the complete 20x18 title canvas so the artwork behind the panel has a
  -- deliberate, uniform grayscale treatment. The original box is restored as
  -- soon as the menu is popped or either presentation toggle is disabled.
  runtime.syncTitleMenuPalette = function(game, state)
    if not (game and state and menuClass
        and inherits(classOf(state), menuClass)
        and type(state.titleUiBox) == "table") then
      return
    end
    local stack = game.stack and game.stack.states
    local titleOnStack = false
    for _, visible in ipairs(type(stack) == "table" and stack or {}) do
      if runtime.isTitleState(visible) then titleOnStack = true break end
    end
    local modern = titleOnStack and runtime.option("hideOriginalUi", true) ~= false
      and runtime.option("menuUi", true) ~= false
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

  runtime.openModernOptions = function(game)
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
  runtime.pinKey = function(item)
    if type(item) ~= "table" then return nil end
    if type(item.id) == "string" and item.id ~= "" then return item.id end
    if type(item.label) == "string" and item.label ~= "" then
      return "label:" .. item.label
    end
    return nil
  end

  runtime.pinMap = function()
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

  runtime.isPinned = function(item)
    local key = runtime.pinKey(item)
    if not key then return false end
    local pins = runtime.pinMap()
    if pins[key] ~= nil then return pins[key] == true end
    -- Migrate the old direct-shortcut setting for existing saves. An
    -- explicit pin-map value always wins, so SELECT can unpin it normally.
    return key == "gen1_modern_ui.options"
      and runtime.option("startMenuShortcut", false) == true
  end

  runtime.setPinned = function(item, pinned)
    local key = runtime.pinKey(item)
    if not key then return nil end
    local pins = runtime.pinMap()
    pins[key] = pinned == true
    if mod.save and type(mod.save.set) == "function" then
      pcall(mod.save.set, mod.save, "startMenuPins", pins)
    end
    return pins[key]
  end

  runtime.togglePinned = function(item)
    local key = runtime.pinKey(item)
    if not key then return nil end
    local nextPinned = not runtime.isPinned(item)
    return runtime.setPinned(item, nextPinned)
  end

  runtime.decoratePinned = function(item)
    if type(item) ~= "table" then return item end
    local decorated = {}
    for key, value in pairs(item) do decorated[key] = value end
    decorated._gen1Pinned = true
    return decorated
  end

  -- Hook chains are allowed to rebuild row descriptor tables.  Match the
  -- vanilla inventory by a stable public identity as well as object identity
  -- so a copying wrapper cannot make every ordinary row look mod-added.
  runtime.startMenuItemKey = function(item)
    if type(item) ~= "table" then return nil end
    local id = safeText(item.id)
    if id ~= "" then return "id:" .. id end
    local label = safeText(item.label):lower():gsub("%s+", " ")
    if label ~= "" then return "label:" .. label end
    return nil
  end

  runtime.copyArray = function(items)
    local copied = {}
    for _, item in ipairs(items or {}) do copied[#copied + 1] = item end
    return copied
  end

  runtime.uiSettingsRow = function(game)
    return {
      id = "gen1_modern_ui.options",
      label = "UI SETTINGS",
      onSelect = function() runtime.openModernOptions(game) end,
    }
  end

  runtime.openModMenus = function(game, items)
    if not (game and mod.ui and mod.ui.Menu and type(mod.ui.Menu.new) == "function") then
      return
    end
    local rows = {}
    for _, item in ipairs(items or {}) do rows[#rows + 1] = item end
    local menu = mod.ui.Menu.new(game, rows, {
      tx = 8, ty = 1, tw = 12,
      onCancel = function() mod.ui.push(game, "StartMenu") end,
    })
    -- This is a Modern UI-owned manager surface, not an arbitrary native
    -- Menu. Stamp its ownership explicitly so precise suppression never has
    -- to infer the Game from a previous render frame, and so it remains
    -- identifiable when the generic Menu/Dialogue presenters are disabled.
    menu.game = menu.game or game
    menu.screenId = menu.screenId or "Gen1ModernModMenus"
    menu.title = menu.title or Strings("MOD MENUS")
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
    local originalCounts = {}
    for _, item in ipairs(items or {}) do
      original[item] = true
      local key = runtime.startMenuItemKey(item)
      if key then originalCounts[key] = (originalCounts[key] or 0) + 1 end
    end
    local out = next(game, items)
    if type(out) ~= "table" then
      return out
    end
    -- Never mutate a downstream mod's returned inventory in place.
    out = runtime.copyArray(out)

    -- There is no required source-mod field on this hook. Prefer exact object
    -- identity, then consume stable id/label matches from the incoming vanilla
    -- inventory. Rows that remain unmatched are the mod-menu candidates.
    local canGroupModMenus = mod.ui and mod.ui.Menu
      and type(mod.ui.Menu.new) == "function"
    local groupingEnabled = runtime.option("startMenuModMenus", true) ~= false
      and canGroupModMenus
    local settings = runtime.uiSettingsRow(game)
    local added, addedSet, hasGroup, hasSettings = {}, {}, false, false
    local settingsItem
    local pinnedDirect = {}
    for _, item in ipairs(out) do
      if type(item) == "table" then
        if item.id == "gen1_modern_ui.mod_menus" then
          hasGroup = true
        elseif item.id == "gen1_modern_ui.options" then
          hasSettings = true
          settingsItem = item
        else
          local key = runtime.startMenuItemKey(item)
          local isOriginal = original[item] == true
          if isOriginal then
            if key and (originalCounts[key] or 0) > 0 then
              originalCounts[key] = originalCounts[key] - 1
            end
          elseif key and (originalCounts[key] or 0) > 0 then
            isOriginal = true
            originalCounts[key] = originalCounts[key] - 1
          end
          if not isOriginal then
            added[#added + 1] = item
            addedSet[item] = true
            if runtime.isPinned(item) then pinnedDirect[item] = true end
          end
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
        elseif item.id == "gen1_modern_ui.options" and not runtime.isPinned(item) then
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
            and runtime.isPinned(item)) then
          out[index] = runtime.decoratePinned(item)
        end
      end
      if #groupedItems > 0 and not hasGroup then
        local grouped = {
          id = "gen1_modern_ui.mod_menus",
          label = Strings("MOD MENUS"),
          onSelect = function() runtime.openModMenus(game, groupedItems) end,
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
    if groupingEnabled and runtime.isPinned(settings) and not hasSettings then
      local directSettings = runtime.decoratePinned(settings)
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
  runtime.pendingPress = function(input, button)
    for _, queued in ipairs(input and input.pressQueue or {}) do
      if queued == button then return true end
    end
    return false
  end

  runtime.consumePending = function(input, buttons)
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

  runtime.optionDescription = function(id)
    if id == "__reset" then
      return "Restore every Gen1 Modern UI setting to its default value."
    end
    if id == "uiScale" then
      local percent, auto = resolvedScalePercent(runtime.option("uiScale", 100),
        nil, 75, 150)
      local label = auto and ("AUTO (" .. percent .. "%)") or (percent .. "%")
      return ("Scale panel chrome, rows, icons, borders, and control spacing. Current effective size: %s."):format(
        label)
    end
    if id == "frameScale" then
      local value = clamp(math.floor(tonumber(runtime.option("frameScale", 2)) or 2), 1, 4)
      return ("Scale PNG pixel-frame artwork by %dX using nearest-neighbor sampling. Current setting: %dX."):format(
        value, value)
    end
    if id == "frameAsset" then
      local value = safeText(runtime.option("frameAsset", "2"))
      local label = value
      for _, choice in ipairs(mod._gen1ModernCompatibility.frameChoices) do
        if choice[2] == value then label = choice[1] break end
      end
      return ("Choose the authored pixel-frame border. Current frame: %s."):format(
        label)
    end
    if id == "fontScale" then
      if runtime.option("pixelFont", false) == true then
        local scale = (tonumber(normalizedPixelFontScale(
          runtime.option("fontScale", 100), true)) or 100) / 100
        return ("Scale Plain Pixel glyphs by %dX. Integer steps keep its authored raster crisp."):format(
          scale)
      end
      local percent, auto = resolvedScalePercent(runtime.option("fontScale", 100),
        nil, 80, 200)
      local label = auto and ("AUTO (" .. percent .. "%)") or (percent .. "%")
      return ("Scale readable interface text before measuring and laying out content. Current effective size: %s."):format(
        label)
    end
    if id == "dialogueTextScale" then
      local value = runtime.option("dialogueTextScale", "inherit")
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
    managerUi = "presenters", spriteAnimation = "presenters",
    battleUiWip = "presenters", battleUiMode = "presenters",
    desktopFloating = "advanced", __reset = "advanced",
  }

  runtime.ensureOptionCategories = function(state)
    if not (state and state.screen == "options" and state.currentMod
        and state.currentMod.id == MOD_ID and type(state.optionRows) == "table") then
      return
    end
    local pixelEnabled = runtime.option("pixelFont", false) == true
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
      local stored = runtime.option("fontScale", 100)
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

  runtime.optionState = function(game)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if not (top and top.screenId == "ManagerState" and top.screen == "options"
        and type(top.optionRows) == "table" and type(top.cursor) == "number") then
      return nil
    end
    return top
  end

  runtime.updateModMenuPin = function(game, input)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if not (top and top._gen1ModMenus and type(top.items) == "table"
        and type(top.index) == "number") then return end
    if not runtime.pendingPress(input, "select") then return end
    local item = top.items[top.index]
    if runtime.togglePinned(item) ~= nil then
      -- Pins are presentation preferences, but mod.save is backed by the
      -- current game save. Flush immediately so a client restart does not
      -- discard a deliberate SELECT pin/unpin action.
      if game.save and type(game.writeSave) == "function" then
        pcall(game.writeSave, game)
      end
      -- SELECT is a presentation-only pin action. Leave A/arrow callbacks to
      -- the engine so every source mod keeps its normal menu behavior.
      runtime.consumePending(input, { select = true })
    end
  end

  runtime.updateOptionHelp = function(game, input)
    if runtime.option("managerUi", true) == false then return end
    local state = runtime.optionState(game)
    if not state then return end
    local active = state._gen1OptionDescription
    if active then
      -- A/B/SELECT dismiss the help card without changing the focused option
      -- or leaving the manager. Directional input closes it and remains in the
      -- queue so the manager can move/adjust normally on the same step.
      if runtime.consumePending(input, { a = true, b = true, select = true }) then
        state._gen1OptionDescription = nil
        return
      end
      if runtime.pendingPress(input, "up") or runtime.pendingPress(input, "down")
          or runtime.pendingPress(input, "left") or runtime.pendingPress(input, "right")
          or runtime.pendingPress(input, "start") then
        state._gen1OptionDescription = nil
      end
      return
    end
    if not runtime.pendingPress(input, "select") then return end
    local row = state.optionRows[state.cursor]
    local description = row and (runtime.optionDescription(row.id) or row.description)
    if not description or description == "" then return end
    state._gen1OptionDescription = {
      title = row.label or row.id,
      text = description,
    }
    runtime.consumePending(input, { select = true })
  end

  runtime.remapChoiceDirections = function(game)
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

  runtime.moveGridIndex = function(index, count, direction)
    count = math.max(0, math.floor(tonumber(count) or 0))
    if count < 1 then return nil end
    index = clamp(math.floor(tonumber(index) or 1), 1, count)
    local row = math.floor((index - 1) / 2)
    local col = (index - 1) % 2
    if direction == "left" or direction == "right" then
      local other = row * 2 + (1 - col) + 1
      return other <= count and other or index
    end
    local other = (1 - row) * 2 + col + 1
    return other <= count and other or index
  end

  mod.hooks:wrap("input.step", function(next, game, dt)
    runtime.remapBattleMoveGrid(game)
    runtime.remapChoiceDirections(game)
    local result = next(game, dt)
    if not game then
      return result
    end
    if syncWorldVisibility then syncWorldVisibility(game) end
    local topAfter = game.stack and game.stack.top and game.stack:top()
    runtime.ensureOptionCategories(topAfter)
    local input = game.input
    runtime.updateModMenuPin(game, input)
    runtime.updateOptionHelp(game, input)
    if runtime.option("startMenuFastJump", true) == false then return result end
    local top = game.stack and game.stack.top and game.stack:top()
    if not (input and top and top.screenId == "StartMenu"
        and type(top.items) == "table"
        and top.startCloses == true and type(top.index) == "number"
        and #top.items > 0) then
      return result
    end
    local left = runtime.pendingPress(input, "left")
    local right = runtime.pendingPress(input, "right")
    if left == right then return result end
    local count = #top.items
    local delta = right and 5 or -5
    top.index = ((top.index - 1 + delta) % count) + 1
    if type(top.clampScroll) == "function" then top:clampScroll() end
    if game.save then game.save.startMenuIndex = top.index end
    return result
  end, 80)

  local isBoxRoot
  runtime.boxPokemonList = function(state)
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

  runtime.isGen3Box = function(state)
    return (state.screenId == "Gen3Box" or state.screenId == "Gen3BoxMenu")
      and (state.mode == "box" or state.mode == "party")
      and type(state.row) == "number" and type(state.col) == "number"
  end

  runtime.isUsefulDexEntry = function(state)
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
  runtime.isOptionRowsScreen = function(state)
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

  runtime.isNamingState = function(state)
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

  runtime.kindFor = function(state, game)
    if not state then return nil end
    -- An explicitly registered source-mod contract always wins over a
    -- legacy bridge. This lets RBYMMO/Dex Radar ship richer public models
    -- without requiring a new hardcoded presenter in every UI release.
    local sourceAdapter = mod._gen1ModernCompatibility:adapterFor(game, state)
    if sourceAdapter then
      return sourceAdapter.screen.layer == "battle" and "battle" or "external"
    end
    local id = state.screenId
    local class = classOf(state)
    -- RBY MMO's profile and leaderboard are plain local classes rather than
    -- engine widgets. Their stable screen ids and public payloads are the
    -- compatibility seam; do not rely on the mod's private class identity.
    local legacyKind = mod._gen1ModernCompatibility:legacyKind(state)
    if legacyKind then return legacyKind end
    -- Dex Radar 1.x publishes a stable screen id and keeps its complete
    -- presentation model on the screen instance.  Treat that public shape as
    -- the compatibility seam so the foreign screen can retain update/input
    -- ownership while this mod replaces only its 160x144 draw pass.
    if runtime.isLinkState(state) then return "link" end
    if state.phase and state.queue and
        (state.kind == "wild" or state.kind == "trainer" or
         state.kind == "link" or state.enemy or state.player) then
      return "battle"
    end
    -- ManagerState is part of the released in-game mod manager.  It is not a
    -- Menu/ListMenu subclass, so identify it by its public screen id rather
    -- than by reaching into the engine's class hierarchy.
    if id == "ManagerState" then return "mod_manager" end
    if runtime.isGen3Box(state) then return "gen3_box" end
    if id == "DexEntryMenu" and ((dexEntryClass and inherits(class, dexEntryClass))
        or runtime.isUsefulDexEntry(state)) then return "dex_entry" end
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
    if runtime.isNamingState(state) then return "naming" end
    if id == "TownMap" and mod._gen1ModernSpecialClasses.townMap
        and inherits(class, mod._gen1ModernSpecialClasses.townMap) then
      return "town_map"
    end
    if id == "QuarantineReport"
        and mod._gen1ModernSpecialClasses.quarantineReport
        and inherits(class, mod._gen1ModernSpecialClasses.quarantineReport) then
      return "quarantine_report"
    end
    if runtime.isOptionRowsScreen(state) then return "mod_options" end
    if id == "TrainerCard" and trainerCardClass
        and inherits(class, trainerCardClass) then return "trainer_card" end
    if isBoxRoot(state) then return "box_root" end
    if runtime.boxPokemonList(state) then return "box_mon_list" end
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
  runtime.presenterEnabled = function(kind, state)
    -- MOD MENUS is a Modern UI-owned utility surface. It remains available
    -- when ordinary Menu/Dialogue presenters are disabled and follows the
    -- dedicated Mod Manager UI toggle instead.
    if state and state._gen1ModMenus then
      return runtime.option("managerUi", true) ~= false
    end
    if kind == "external" then return runtime.option("menuUi", true) ~= false end
    if kind == "battle" then return runtime.option("battleUiWip", false) == true end
    if kind == "link" then return runtime.option("menuUi", true) ~= false end
    if kind == "text" or kind == "choice" or kind == "quantity" then
      return runtime.option("dialogueUi", true) ~= false
    end
    if kind == "mod_manager" or kind == "mod_options" then
      return runtime.option("managerUi", true) ~= false
    end
    if kind == "gen3_box" or kind == "dex_entry" or kind == "summary"
        or kind == "party" or kind == "trainer_card" or kind == "pokedex"
        or kind == "box_mon_list" then
      return runtime.option("pokemonUi", true) ~= false
    end
    if kind == "move_learn" or kind == "pic_box" or kind == "naming"
        or kind == "town_map" or kind == "quarantine_report"
        or kind == "rby_mmo_profile" or kind == "rby_mmo_rank"
        or kind == "rby_mmo_char_pick" then
      return runtime.option("menuUi", true) ~= false
    end
    return runtime.option("menuUi", true) ~= false
  end

  -- Every battle presenter leaves the native battle pass alive. BattleState
  -- owns much more than static pictures: send-out/capture sequences, move
  -- animation sprites, palette flashes, shakes, fades, WideBattle's overlay
  -- hook, and DramaticShape's staged scene all run inside that draw. For the
  -- classic 2D surface we decorate BattleState's HUD/text methods so that its
  -- scene pipeline keeps drawing while modern UI owns every information and
  -- menu surface. WIDE and third-party scene modes retain conservative
  -- post-compose cleanup until they expose the same scene-only seam.
  -- Keep battle-only helpers on one runtime table. The installer is a large
  -- compatibility module, and LuaJIT/LÃ–VE limits one function prototype to
  -- 200 local slots. Table-backed helpers keep future battle integrations
  -- from pushing the factory over that limit.
  local battleRuntime = {}

  function battleRuntime.nativeSceneRequested(state)
    local configured = safeText(runtime.option("battleUiMode", "auto")):lower()
    if configured == "hud" or configured == "hud_only"
        or configured == "menu" then
      return true
    end
    if configured == "full" or configured == "canvas" then return false end
    local source = state or {}
    local compatibility = mod._gen1ModernCompatibility
    local context = compatibility.active[source]
    if context and context.screen and context.screen.layer == "battle" then
      local model = compatibility:modelFor(currentGame or source.game,
        source, context)
      if model then
        local presentation = safeText(model.presentation
          or model.presentationMode or model.battlePresentation):lower()
        if presentation == "hud" or presentation == "hud_only"
            or presentation == "menu" or model.isVoxelBattle == true
            or model.voxel3d == true or model.voxel == true then
          return true
        end
      end
    end
    if source.isVoxelBattle == true or source.voxel3d == true
        or source.voxel == true or type(source.voxel3dBattleData) == "table"
        or type(source.dramaticShapeShot) == "table"
        or source.battleMode == "voxel" or source.battleMode == "3d"
        or source.battleMode == "stadium" then
      return true
    end
    -- Installing a voxel or QOL mod does not prove that this particular
    -- battle uses its scene. Active source state (or a public adapter model)
    -- is the only safe AUTO-mode signal; otherwise ordinary 2D battles would
    -- incorrectly be forced into the voxel layout merely because QOL exists.
    return false
  end

  -- Standard BattleState keeps the Game Boy's vertical move-list input even
  -- though the modern panel uses the same readable 2x2 arrangement as WIDE.
  -- Consume only that directional edge and update the source cursor field;
  -- A/B/SELECT, PP checks, disabled moves, callbacks, and turn resolution
  -- continue through BattleState unchanged. AUTO scene/voxel battles keep
  -- every direction source-owned along with the compact HUD presentation.
  runtime.remapBattleMoveGrid = function(game)
    if runtime.option("battleUiWip", false) ~= true then return end
    local stack = game and game.stack
    local state = stack and type(stack.top) == "function" and stack:top() or nil
    local phase = state and state.phase
    if phase ~= "moveSelect" and phase ~= "mimicSelect"
        or battleRuntime.nativeSceneRequested(state) then return end
    local wide = false
    if type(state.wideLayout) == "function" then
      local ok, value = pcall(state.wideLayout, state)
      wide = ok and value == true
    end
    if wide then return end
    local input = game.input
    if not (input and type(input.pressQueue) == "table") then return end
    local moves = phase == "mimicSelect" and state.mimicMoves
      or state.player and state.player.curMoves
    if type(moves) ~= "table" or #moves < 1 then return end
    local field = phase == "mimicSelect" and "mimicIndex" or "moveIndex"
    for queueIndex = #input.pressQueue, 1, -1 do
      local direction = input.pressQueue[queueIndex]
      if direction == "left" or direction == "right"
          or direction == "up" or direction == "down" then
        state[field] = runtime.moveGridIndex(state[field], #moves, direction)
        table.remove(input.pressQueue, queueIndex)
      end
    end
  end

  -- Some mods keep a standard Menu/ListMenu state but replace `draw` on the
  -- instance. That custom pipeline may contain tabs, badges, previews, or
  -- prompts which cannot be recovered from ordinary rows, so suppressing it
  -- would silently lose UI. Only audited structural adapters are exceptions:
  -- Modern Bag delegates to live ListMenu rows, Useful Dex exposes its vanilla
  -- entry plus public page model, and Gen 3 Box exposes its complete grid model.
  runtime.customDrawModeled = function(state, kind)
    if runtime.option("battleUiWip", false) == true
        and state._gen1ModernBattleChildNativeDraw then
      return true
    end
    if kind == "external"
        and mod._gen1ModernCompatibility.active[state] then return true end
    if kind == "link" and runtime.isLinkState(state) then return true end
    if kind == "mod_options" and runtime.isOptionRowsScreen(state) then return true end
    if kind == "bag"
        and mod._gen1ModernCompatibility:isUsefulBagState(state) then
      return true
    end
    if kind == "gen3_box" and runtime.isGen3Box(state) then return true end
    if kind == "dex_entry" and runtime.isUsefulDexEntry(state) then return true end
    if kind == "naming" and runtime.isNamingState(state) then return true end
    if kind == "dex_radar" and state.screenId == "DexRadar" then return true end
    if kind == "rby_mmo_profile" or kind == "rby_mmo_rank"
        or kind == "rby_mmo_char_pick" then return true end
    if kind == "options" and state._gen1ModernOptionsMenu == true
        and type(state._gen1ModernOptionsNativeDraw) == "function" then
      return true
    end
    if kind == "box_root" and isBoxRoot(state) then return true end
    if kind == "menu" and state._gen1ModernTitleMenu == true
        and rawget(state, "draw") == state._gen1ModernTitleDraw then return true end
    return false
  end

  runtime.expectedClass = function(kind)
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

  runtime.resolvedDraw = function(class, seen)
    if type(class) ~= "table" then return nil end
    seen = seen or {}
    if seen[class] then return nil end
    seen[class] = true
    local draw = rawget(class, "draw")
    if type(draw) == "function" then return draw end
    local mt = getmetatable(class)
    return mt and runtime.resolvedDraw(mt.__index, seen) or nil
  end

  local orig_hasUnknownDrawOverride = runtime.hasUnknownDrawOverride
  runtime.hasUnknownDrawOverride = function(state, kind)
    if runtime.customDrawModeled(state, kind) then return false end
    -- Battle states are plain source-owned records rather than Menu/ListMenu
    -- subclasses. Their native draw function is expected and must not be
    -- mistaken for an unsupported replacement.
    if kind == "battle" then return false end
    local ownDraw = rawget(state, "draw")
    local class = classOf(state)
    if type(ownDraw) == "function" and ownDraw ~= runtime.resolvedDraw(class) then
      return true
    end
    local expected = runtime.expectedClass(kind)
    local expectedDraw = runtime.resolvedDraw(expected)
    local actualDraw = runtime.resolvedDraw(class)
    return expectedDraw ~= nil and actualDraw ~= nil and actualDraw ~= expectedDraw
  end

  -- Rich screens are allowed to come from other screen factories.  The
  -- released SummaryMenu stores its live record in `mon`, while a few older
  -- callers and third-party wrappers use `pokemon`, `target`, or keep the
  -- vanilla record underneath the wrapper.  Resolve those shapes in one
  -- place so floating presentation never clears the classic canvas before
  -- the replacement has enough data to draw.
  runtime.pokemonDefinition = function(game, species)
    local data = game and game.data
    local pokemon = data and data.pokemon
    return pokemon and species and pokemon[species] or nil
  end

  runtime.summaryPokemon = function(state)
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

  runtime.dexDefinition = function(game, state)
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
    return runtime.pokemonDefinition(game, species)
  end

  runtime.presenterReady = function(game, state, kind)
    if kind == "external" then
      local context = mod._gen1ModernCompatibility.active[state]
        or mod._gen1ModernCompatibility:adapterFor(game, state)
      return context and context.screen.canSuppressNative == true
        and mod._gen1ModernCompatibility:modelFor(game, state, context) ~= nil
    elseif kind == "battle" then
      local context = mod._gen1ModernCompatibility.active[state]
        or mod._gen1ModernCompatibility:adapterFor(game, state)
      -- Battle adapters enrich the overlay model but never suppress the
      -- source draw: animation and third-party overlay ownership stays with
      -- BattleState/source mods regardless of canSuppressNative.
      if context then
        return context.screen.layer == "battle"
          and mod._gen1ModernCompatibility:modelFor(game, state, context) ~= nil
      end
      return true
    elseif kind == "text" then
      -- TextBox states are pushed before the first page is always populated
      -- (notably during the New Game introduction). Never hide that native
      -- state until there is an actual page for the modern presenter to draw.
      local pages = type(state) == "table" and state.pages
      local page = type(pages) == "table" and pages[state.pageIndex or 1]
      return type(page) == "table" and #page > 0
    elseif kind == "menu" then
      -- Menus can likewise exist for a frame before their choices arrive.
      -- Suppressing that incomplete frame blanks prompts such as the first
      -- New Game name question, so require at least one source-owned row.
      return type(state) == "table" and type(state.items) == "table"
        and #state.items > 0
    elseif kind == "summary" then
      local mon = runtime.summaryPokemon(state)
      return mon ~= nil and runtime.pokemonDefinition(game, mon.species) ~= nil
    elseif kind == "dex_entry" then
      return runtime.dexDefinition(game, state) ~= nil
    end
    return true
  end

  runtime.battleStateBelow = function(game, target)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" or not target then return nil end
    local targetIndex
    for index = #states, 1, -1 do
      if states[index] == target then
        targetIndex = index
        break
      end
    end
    if not targetIndex then return nil end
    for index = targetIndex - 1, 1, -1 do
      local candidate = states[index]
      if candidate and runtime.kindFor(candidate, game) == "battle" then
        return candidate
      end
    end
    return nil
  end

  -- The new host hook asks about one state at a time while StateStack is
  -- choosing its visible base. This predicate deliberately does not call
  -- `visibleBase` or `presentationStack`, so it is safe inside that query.
  runtime.canSuppressState = function(game, state)
    if not (game and state and state ~= game.overworld)
        or runtime.isTitleState(state)
        or runtime.hasNativeNewGameFlow(game) or state.capture
        or runtime.option("hideOriginalUi", true) == false then
      return false
    end
    -- Battle child screens share source-owned battle canvases and transitions.
    -- If the WIP battle presenter is disabled, Bag/Party/choice children must
    -- remain wholly native instead of being suppressed as standalone menus.
    if runtime.option("battleUiWip", false) ~= true
        and runtime.battleStateBelow(game, state) then
      return false
    end
    if type(battleRuntime) == "table"
        and type(battleRuntime.isLevelUpState) == "function"
        and battleRuntime.isLevelUpState(game, state) then
      -- The native StatBox is another battle child.  Its values are read from
      -- the source state and presented by the modern battle layer below, so
      -- leave only its semantic update/input ownership with the host.
      return runtime.option("battleUiWip", false) == true
    end
    local kind = runtime.kindFor(state, game)
    if kind == "battle" then return false end
    return kind and runtime.presenterEnabled(kind, state)
      and not runtime.hasUnknownDrawOverride(state, kind)
      and runtime.presenterReady(game, state, kind) or false
  end

  -- Build a non-recursive proof for hosts that have screen.render_visible.
  -- Managed modern states are treated as transparent for the base scan; an
  -- unknown opaque state remains the native drawing boundary and prevents us
  -- from blanking anything above it.
  runtime.visibleSuppressionProof = function(game)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return false, {} end
    local function rawOpaque(state)
      if state and state._gen1ModernOpaqueManaged then
        return state._gen1ModernOriginalOpaque == true
      end
      return state and state.isOpaque == true
    end
    local base = 1
    local preservedBase
    for index = #states, 1, -1 do
      local state = states[index]
      if state and state ~= game.overworld and runtime.isTitleState(state) then
        -- Title art is a shared native canvas; its menu decorator handles the
        -- rows separately and the canvas must remain available.
      elseif state and type(state.draw) == "function"
          and rawOpaque(state) and not runtime.canSuppressState(game, state) then
        base = index
        preservedBase = state
        break
      end
    end
    local hidden = {}
    for index = base, #states do
      local state = states[index]
      if state and state ~= game.overworld and not runtime.isTitleState(state)
          and type(state.draw) == "function" then
        if state == preservedBase then
          -- Keep an authoritative opaque base (notably BattleState) alive,
          -- while still suppressing individually-presented Bag/Party/modal
          -- children above it through screen.render_visible.
        elseif runtime.canSuppressState(game, state) then
          hidden[state] = true
        else
          return false, {}
        end
      end
    end
    return next(hidden) ~= nil, hidden
  end

  runtime.syncStateVisibility = function(game, state)
    if not (game and state and state ~= game.overworld) then return end
    local kind = runtime.kindFor(state, game)
    local revealWorld = runtime.worldVisibleLayout(nil)
      and runtime.option("hideOriginalUi", true) ~= false
    local disabledBattleChild = runtime.option("battleUiWip", false) ~= true
      and runtime.battleStateBelow(game, state) ~= nil
    local nativeNewGame = runtime.hasNativeNewGameFlow(game)
    local eligible = revealWorld and kind and runtime.presenterEnabled(kind, state)
      and kind ~= "battle" and not state.capture
      and not disabledBattleChild and not nativeNewGame
      and not runtime.hasUnknownDrawOverride(state, kind)
      and runtime.presenterReady(game, state, kind)
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
        runtime.syncStateVisibility(game, state)
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
      local modernWorld = runtime.option("menuUi", true) ~= false
        and runtime.option("hideOriginalUi", true) ~= false
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
    -- Refresh public adapter exports after a mod reload or enable/disable
    -- change. `discover` also removes adapters whose source mod vanished.
    mod.events:on("mods.loaded", function()
      mod._gen1ModernCompatibility:discover()
    end, 90)
    mod.events:on("screen.pushed", function(payload)
      local state = payload and payload.state
      local game = runtime.ownerGame(state, currentGame)
      if game and state then runtime.stateGames[state] = game end
      if runtime.isOakSpeechState(state) then
        runtime.markNativeNewGame(game)
      end
      if runtime.option("battleUiWip", false) == true then
        if type(battleRuntime.decorateClassicScene) == "function" then
          battleRuntime.decorateClassicScene(game, state)
        end
        if type(battleRuntime.decorateWorldSurface) == "function"
            and runtime.kindFor(state, game) == "battle" then
          battleRuntime.decorateWideScenePlacement(state)
          battleRuntime.decorateWorldSurface(state)
        end
      elseif type(battleRuntime.restoreDecoratedState) == "function" then
        battleRuntime.restoreDecoratedState(state)
      end
      runtime.syncTitleMenuPalette(game, state)
      runtime.syncStateVisibility(game, state)
    end, 90)
    mod.events:on("screen.popped", function(payload)
      local state = payload and payload.state
      local game = runtime.ownerGame(state, currentGame)
      if state then runtime.stateGames[state] = nil end
      -- OakSpeech stays below all of its native child states. Its presence is
      -- therefore the authoritative lifetime for the native New Game flow.
      if game then runtime.hasNativeNewGameFlow(game) end
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
  runtime.presentationStack = function(game)
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
    if runtime.hasNativeNewGameFlow(game) then
      return {}, false
    end
    if runtime.option("battleUiWip", false) ~= true
        and runtime.battleStateBelow(game, topState) then
      return {}, false
    end
    local levelUpTop = runtime.option("battleUiWip", false) == true
      and type(battleRuntime) == "table"
      and type(battleRuntime.isLevelUpState) == "function"
      and battleRuntime.isLevelUpState(game, topState) or false
    local optionRowsTop = runtime.isOptionRowsScreen(topState)
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
              or rawget(visible, "draw") ~= runtimeClasses.overworldDraw
              or type(rawget(visible, "drawUI")) ~= "function" then
            return {}, false
          end
        elseif type(rawget(visible, "drawUI")) == "function" then
          return {}, false
        end
      elseif runtime.isTitleState(visible) then
        -- The title art and its Menu share uiCanvas. The title-menu draw is
        -- suppressed independently by ui.state.decorate below, so preserve
        -- the canvas here rather than erasing the logo and title Pokémon.
        preserveUiCanvas = true
      elseif type(visible and visible.draw) == "function" then
        if visible == topState and levelUpTop then
          -- BattleState.StatBox deliberately has no generic presenter kind.
          -- Its native draw is suppressed independently; the underlying
          -- BattleState remains the animation authority and supplies the
          -- source scene for the modern level-up card.
          preserveUiCanvas = true
        else
          local kind = runtime.kindFor(visible, game)
          if not kind or not runtime.presenterEnabled(kind, visible) or visible.capture
              or runtime.hasUnknownDrawOverride(visible, kind)
              or not runtime.presenterReady(game, visible, kind) then
            return {}, false
          end
          if kind == "battle" then
            -- BattleState is always the animation authority. Keep its canvas
            -- in AUTO, 2D FRAMED, and SCENE HUD modes; the modern presenter
            -- covers only the legacy HUD/menu rectangles after composition.
            preserveUiCanvas = true
          end
          -- A registered OptionRows screen is pushed above the manager state
          -- that opened it. The custom screen is the complete visible surface;
          -- retaining the manager beneath it would duplicate panels in floating
          -- layouts. The manager remains in the engine stack for input/back
          -- navigation, but is omitted from this visual composition.
          if not (kind == "mod_manager" and optionRowsTop) then
            layers[#layers + 1] = {
              state = visible, kind = kind, index = index,
            }
          end
        end
      end
    end

    -- An opaque child such as Bag/Party can sit on top of BattleState.  The
    -- host's visibleBase quite correctly hides everything below that child,
    -- but the modern battle presenter still needs the battle canvas as its
    -- animated backdrop.  Reinsert the source-owned battle layer only when
    -- it is actually below the visible base; this keeps the child's native
    -- draw and input ownership intact while preventing compose from wiping
    -- the arena to a flat clear color.
    if base > 1 then
      for index = base - 1, 1, -1 do
        local hidden = states[index]
        if hidden and runtime.kindFor(hidden, game) == "battle"
            and (battleRuntime.presentationMode(hidden) == "full"
              or levelUpTop)
            and runtime.presenterEnabled("battle")
            and runtime.presenterReady(game, hidden, "battle") then
          local alreadyVisible = false
          for _, layer in ipairs(layers) do
            if layer.state == hidden then
              alreadyVisible = true
              break
            end
          end
          if not alreadyVisible then
            table.insert(layers, 1, {
              state = hidden, kind = "battle", index = index,
            })
            preserveUiCanvas = true
          end
          break
        end
      end
    end
    return layers, #layers > 0, not preserveUiCanvas
  end

  function mod._gen1ModernSpecialPresenters.shouldHideNativeOptions(game,
      state)
    if not (game and state and runtime.option("hideOriginalUi", true) ~= false
        and runtime.option("menuUi", true) ~= false) then
      return false
    end
    local layers, complete = runtime.presentationStack(game)
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
      runtime.syncTitleMenuPalette(game, self)
      if type(self.titleUiBox) == "table"
          and runtime.option("hideOriginalUi", true) ~= false
          and runtime.option("menuUi", true) ~= false then
        local stack = game and game.stack and game.stack.states
        local titleOnStack = false
        for _, visible in ipairs(type(stack) == "table" and stack or {}) do
          if runtime.isTitleState(visible) then titleOnStack = true break end
        end
        if titleOnStack then
          local layers, complete = runtime.presentationStack(game)
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
  runtime.optionValue = function(game, row)
    if not row or row.value == nil then return "" end
    if type(row.value) ~= "function" then return safeText(row.value) end
    local ok, value = pcall(row.value, game)
    return ok and safeText(value) or ""
  end

  local managerRowsFor
  local iconFor
  local spriteFor
  local spriteResolver

  runtime.rowsFor = function(game, state, kind)
    local rows = {}
    local selected = state.index or 1
    local scroll = state.scroll or 0
    local title = titleFor(Strings, state, kind)
    local footer

    if kind == "external" then
      local context = mod._gen1ModernCompatibility.active[state]
        or mod._gen1ModernCompatibility:adapterFor(game, state)
      local model = mod._gen1ModernCompatibility:modelFor(game, state, context)
      if not model then return nil end
      title = safeText(model.title or "")
      selected, scroll = model.index, model.scroll
      for index, raw in ipairs(model.rows) do
        local row = type(raw) == "table" and raw or { label = raw }
        rows[index] = {
          label = row.label or row.name or "",
          value = row.value ~= nil and row.value or row.right,
          enabled = row.enabled,
          marker = row.marker,
          header = row.header,
          category = row.category,
          image = row.image or row.icon or row.thumbnail or row.sprite
            or row.asset or row.path,
          assetCatalog = model.assets,
          source = row,
        }
      end
      if #rows == 0 then rows[1] = { label = "Nothing here.", enabled = false } end
      footer = model.footer
      if type(footer) == "table" then
        local parts = {}
        for _, part in ipairs(footer) do parts[#parts + 1] = safeText(part) end
        footer = table.concat(parts, "   ")
      end
      return rows, selected, scroll, title, footer
    elseif kind == "mod_manager" then
      return managerRowsFor(game, state)
    elseif kind == "options" or kind == "mod_options" then
      for _, row in ipairs(state.rows or {}) do
        rows[#rows + 1] = {
          label = row.label, value = runtime.optionValue(game, row),
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
      local mons, action = runtime.boxPokemonList(state)
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
        local pinned = runtime.isPinned(item)
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
      runtime.ensureOptionCategories(state)
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

  runtime.contentWidthFor = function(theme, rows, title, footer, minWidth, maxWidth)
    -- Detect translated labels before constructing the fonts used for the
    -- measurement pass; otherwise the first width calculation could still
    -- use the lightweight host face and only switch during painting.
    title = safeText(title)
    footer = safeText(footer)
    for _, row in ipairs(rows or {}) do
      if type(row) == "table" then
        safeText(row.label)
        safeText(row.value)
      end
    end
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

  runtime.densityFactor = function()
    local density = runtime.option("density", "auto")
    return density == "compact" and 0.88
      or density == "comfortable" and 1.12 or 1
  end

  runtime.minimumRowHeight = function(theme)
    local body = font(fontCache, theme.typography.body)
    local caption = font(fontCache, theme.typography.caption)
    local textMinimum = math.max(textHeight(body), textHeight(caption))
      + theme.spacing.sm * 1.6
    return math.max(theme.density.rowHeight * runtime.densityFactor(), textMinimum)
  end

  runtime.themeMetric = function(theme, name, fallback)
    local metrics = theme.metrics or {}
    return metrics[name] or fallback
  end

  runtime.readabilityScale = function(theme)
    local scale = theme.scale or {}
    return math.max(tonumber(scale.ui) or 1, tonumber(scale.font) or 1)
  end

  runtime.scaledPanelWidth = function(theme, baseWidth)
    return baseWidth * runtime.readabilityScale(theme)
  end

  runtime.panelMaxWidth = function(theme, fallback)
    local density = theme.density or {}
    local uiScale = tonumber(theme.scale and theme.scale.ui) or 1
    local authoredMax = (tonumber(density.panelMax) or fallback) / uiScale
    return runtime.scaledPanelWidth(theme, math.max(authoredMax, fallback))
  end

  -- Rich presenters historically used fixed height ceilings. That worked at
  -- the reference viewport, but it made larger UI/font scales consume more
  -- rows without giving the screen any additional vertical room. Scale the
  -- ceiling with the largest readability control, then let each presenter
  -- clamp it to the safe viewport below.
  runtime.scaledPanelHeight = function(theme, landscape, landscapeBase, portraitBase)
    local base = landscape and landscapeBase or portraitBase
    return base * runtime.readabilityScale(theme)
  end

  runtime.layoutFor = function(viewport, theme, kind, rows, title, footerText)
    rows = rows or {}
    local rowCount = #rows
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing or {}
    local scale = runtime.densityFactor()
    local landscape = w > h * 1.2
    local desktopFloat = runtime.worldVisibleLayout(viewport)
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
    local rowHeight = runtime.minimumRowHeight(theme)
    local panelMax = runtime.panelMaxWidth(theme, 780)
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
    local measuredW = runtime.contentWidthFor(theme, rows, title, footerText,
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
        or runtime.scaledPanelWidth(theme, 560))
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
    local sidePanelInset = clamp(tonumber(runtime.option("startMenuInset", 0)) or 0,
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

  runtime.drawPanelFrame = function(theme, x, y, w, h, radius, fillColor)
    -- Register the visible panel before choosing a frame style so plain and
    -- theme-framed panels remain draggable through the same hit region.
    if pointerDrawContext and not pointerDrawContext.primaryPanel then
      pointerDrawContext.primaryPanel = { x = x, y = y, w = w, h = h }
    end
    local panelAction = ({
      text = "a", summary = "a", dex_entry = "a", trainer_card = "a",
    })[pointerDrawContext and pointerDrawContext.kind]
    runtime.registerPointerRegion(x, y, w, h, {
      role = "panel", dragHandle = true, action = panelAction,
    })
    local frame = theme.frame or {}
    local style = frame.style or "pixel"
    if style == "none" then return end
    local colors = theme.colors
    local width = math.max(1, tonumber(frame.width) or
      runtime.themeMetric(theme, "border", 3))
    local inset = math.max(0, tonumber(frame.inset) or 0)
    local margin = math.max(0, tonumber(frame.margin) or 0)
    local shadow = math.max(0, tonumber(frame.shadow) or 0)
    local lineRadius = style == "soft" and (radius or theme.radii.md) or 0
    local fx, fy = x - margin + inset, y - margin + inset
    local fw = math.max(1, w + margin * 2 - inset * 2)
    local fh = math.max(1, h + margin * 2 - inset * 2)
    local frameColor = colors.frame or colors.accent
    local shadowColor = colors.frameShadow or colors.divider
    -- Passing false asks for ornamental frame pixels only. Ordinary panels
    -- intentionally fill their content area, but the 2D battle arena must
    -- leave its live source scene visible through that area.
    local frameOnly = fillColor == false

    setColor(frameColor)
    love.graphics.setLineWidth(width)
    local asset = style == "pixel" and frame.asset and runtime.themeAssetFor(frame.asset)
    if asset then
      local iw, ih = runtime.imageMetrics(asset)
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
      if not frameOnly then
        setColor(fillColor or colors.surface)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
      end
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
      if not frameOnly then
        drawSlice(sourceSlice, sourceSlice, centerSourceW, centerSourceH,
          assetFx + destinationCornerX, assetFy + destinationCornerY,
          centerDestW, centerDestH)
      end
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

  runtime.drawPanelAccent = function(theme, x, y, w, radius, height)
    if theme.frame and theme.frame.style == "pixel" then return end
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", x, y, w, height or
      runtime.themeMetric(theme, "border", 4), radius, radius, 0, 0)
  end

  runtime.drawHeader = function(theme, layout, title, fillColor)
    if layout.h then
      runtime.drawPanelFrame(theme, layout.x, layout.y, layout.w, layout.h,
        layout.radius, fillColor)
    end
    if safeText(title) == "" then return end
    local colors = theme.colors
    runtime.drawPanelAccent(theme, layout.x, layout.y, layout.w, layout.radius)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    setColor(colors.text)
    drawText(truncate(title, layout.w - theme.spacing.lg * 2),
      layout.x + theme.spacing.lg,
      layout.y + theme.spacing.md)
  end

  runtime.drawRows = function(theme, layout, rows, selected, scroll, game)
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
        runtime.registerPointerRegion(rx, ry, width, layout.rowHeight - 4, {
          rowIndex = index, interactive = row and row.enabled ~= false,
          dragHandle = false, rowCount = #rows,
          selectionField = layout.pointerSelectionField,
          selectableIndices = selectableIndices,
          adapterIndex = pointerDrawContext.kind == "external" and index or nil,
          adapterAction = pointerDrawContext.kind == "external" and "select" or nil,
          adapterHover = pointerDrawContext.kind == "external" and "hover" or nil,
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
        runtime.registerPointerRegion(layout.x + theme.spacing.sm, ry,
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
          adapterIndex = pointerDrawContext.kind == "external" and index or nil,
          adapterAction = pointerDrawContext.kind == "external" and "select" or nil,
          adapterHover = pointerDrawContext.kind == "external" and "hover" or nil,
        })
      if row.category then
        setColor(rowSelected and colors.selected or colors.surfaceRaised)
        love.graphics.rectangle("fill", layout.x + theme.spacing.sm, ry,
          layout.w - theme.spacing.sm * 2, layout.rowHeight - 4,
          theme.radii.sm or 8)
        setColor(rowSelected and colors.text or colors.accent)
        local categoryFont = font(fontCache, theme.typography.body)
        local valueFont = font(fontCache, theme.typography.caption)
        local value = safeText(runtime.optionValue(game, row))
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
          ry + layout.rowHeight - runtime.themeMetric(theme, "divider", 1),
          layout.w - theme.spacing.lg * 2, runtime.themeMetric(theme, "divider", 1))
      else
        setColor(row.enabled == false and colors.textMuted or colors.text)
      end
      local imageValue = row.image
      if type(imageValue) == "string" and type(row.assetCatalog) == "table"
          and row.assetCatalog[imageValue] ~= nil then
        imageValue = row.assetCatalog[imageValue]
      end
      local icon = not row.header and not row.category and runtime.imageFor(imageValue) or nil
      if icon then
        local trueColor = type(imageValue) == "table"
          and imageValue.trueColor == true
        paletteRuntime.setImage(icon, not trueColor and row.source
          and row.source.species
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
        local iw, ih = runtime.imageMetrics(icon)
        if iw and ih then
          local scale = math.min(iconSize / iw, iconSize / ih)
          setColor({ 1, 1, 1, 1 })
          runtime.drawImage(icon,
            layout.x + theme.spacing.lg + (iconSize - iw * scale) / 2,
            ry + (layout.rowHeight - ih * scale) / 2, 0, scale, scale)
          setColor(row.enabled == false and colors.textMuted or colors.text)
        end
      end
      local label = safeText(row.label)
      local value = safeText(row.value)
      local status = layout.statusColumn and safeText(row.status) or ""
      local bodyFont = font(fontCache, theme.typography.body)
      local textAvail = math.max(1, layout.x + layout.w - theme.spacing.lg - textX)
      local gap = theme.spacing.md
      local labelWidth = bodyFont:getWidth(label)
      local valueWidth = value ~= "" and bodyFont:getWidth(value) or 0
      local statusWidth = status ~= "" and bodyFont:getWidth(status) or 0
      -- Preserve the complete value whenever the measured panel can hold it.
      -- Only fall back to a bounded right column when label + value cannot
      -- coexist; this prevents short panels from clipping values such as
      -- "Classic Mono" while still guaranteeing that the two columns never
      -- overlap on narrow phones.
      if valueWidth > 0 and labelWidth + gap + valueWidth
          + (statusWidth > 0 and gap + statusWidth or 0) > textAvail then
        local maxValueColumn = math.max(1,
          textAvail - math.max(48, textAvail * 0.48))
        valueWidth = math.min(valueWidth, maxValueColumn)
      end
      local valueEnd = layout.x + layout.w - theme.spacing.lg
      local valueStart = valueEnd - valueWidth
      local statusX = valueStart - (statusWidth > 0 and gap or 0) - statusWidth
      local leftWidth = (statusWidth > 0 and statusX or valueStart)
        - gap - textX
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
            valueEnd - lineWidth,
            textY + (lineIndex - 1) * (textHeight(bodyFont) + theme.spacing.xs))
        end
        if statusWidth > 0 then
          setColor(rowSelected and colors.text or colors.textMuted)
          drawText(status, statusX,
            textY + (lineCount - 1) * (textHeight(bodyFont) + theme.spacing.xs))
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
          ry + layout.rowHeight - runtime.themeMetric(theme, "divider", 1),
          layout.w - theme.spacing.lg * 2, runtime.themeMetric(theme, "divider", 1))
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

  runtime.textPrefix = function(value, glyphs)
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

  runtime.dialogueLines = function(state)
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
      if index == current then line = runtime.textPrefix(line, state.charIndex or #line) end
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  runtime.completeDialogueLines = function(state)
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

  runtime.wrappedDialogueLines = function(state, body, maxWidth)
    local lines = {}
    for _, source in ipairs(runtime.dialogueLines(state)) do
      for _, line in ipairs(wrappedLines(source, maxWidth, body)) do
        lines[#lines + 1] = line
      end
    end
    return lines
  end

  runtime.modalHint = function(kind, footerText)
    if safeText(footerText) ~= "" then return footerText end
    if kind == "choice" then return nil end
    if kind == "quantity" then
      return "UP/DOWN  amount   A  confirm   B  cancel"
    end
    return "A  select   B  back"
  end

  runtime.modalReserveHeight = function(game, theme, kind, state, viewport)
    local rows, _, _, title, footerText = runtime.rowsFor(game, state, kind)
    local rowCount = math.max(1, math.min(#(rows or {}), 6))
    local x, y, w, h = presenterRect(viewport)
    if kind == "choice" and w > h * 1.2 then rowCount = 1 end
    local titleHeight = textHeight(font(fontCache, theme.typography.title))
    local captionHeight = textHeight(font(fontCache, theme.typography.caption))
    local header = safeText(title) ~= "" and (titleHeight + theme.spacing.md)
      or theme.spacing.md
    local footer = runtime.shouldDrawHint(runtime.modalHint(kind, footerText))
      and captionHeight + theme.spacing.md or 0
    return header + footer + rowCount * runtime.minimumRowHeight(theme)
  end

  runtime.dialogueRect = function(viewport, theme, state, game, reserveKind, reserveState)
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
    for _, line in ipairs(runtime.completeDialogueLines(state) or {}) do
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
    for _, line in ipairs(runtime.completeDialogueLines(state)) do
      desiredLines = desiredLines + #wrappedLines(line, available, body)
    end
    -- Grow to the full current page whenever the viewport can hold it. The
    -- old five-line cap was still an arbitrary version of the vanilla
    -- two-line window and made four-line NPC/save messages race through a
    -- visually scrolling card at FAST text speed.
    local maxHeight = h - gutter * 2
    if reserveKind then
      local reserve = runtime.modalReserveHeight(game, theme, reserveKind, reserveState, viewport)
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
      local reserve = runtime.modalReserveHeight(game, theme, reserveKind, reserveState, viewport)
      local availableHeight = h - gutter * 2 - reserve - theme.spacing.sm
      height = math.min(height, math.max(1, availableHeight))
    end
    height = math.min(height, h - gutter * 2)
    return x + (w - width) / 2, y + h - height - gutter, width, height
  end

  runtime.drawDialogue = function(state, viewport, theme, game, reserveKind, reserveState)
    local px, py, panelW, panelH = runtime.dialogueRect(viewport, theme, state, game,
      reserveKind, reserveState)
    local spacing, colors = theme.spacing, theme.colors
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.md)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.md)

    local body = font(fontCache, theme.typography.body)
    love.graphics.setFont(body)
    local paddingX = spacing.xl
    local paddingY = spacing.lg
    local available = panelW - paddingX * 2
    local lines = runtime.wrappedDialogueLines(state, body, available)
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

  runtime.drawModalRows = function(game, state, kind, viewport, theme, underKind,
      underState)
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, kind)
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local landscape = w > h * 1.2
    local rowHeight = runtime.minimumRowHeight(theme)
    local titleHeight = textHeight(font(fontCache, theme.typography.title))
    local captionHeight = textHeight(font(fontCache, theme.typography.caption))
    local header = safeText(title) ~= "" and (titleHeight + spacing.md)
      or spacing.md
    local hint = runtime.modalHint(kind, footerText)
    local footer = runtime.shouldDrawHint(hint) and captionHeight + spacing.md or 0
    local maxPanelW = landscape and math.min(w * 0.70, 520) or math.min(w - spacing.lg * 2, 520)
    local panelW = math.min(w - spacing.lg * 2,
      runtime.contentWidthFor(theme, rows, title, footerText, landscape and 220 or 250, maxPanelW))
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
      local dx, dy, dw = runtime.dialogueRect(viewport, theme, underState, game)
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
    runtime.drawHeader(theme, layout, title)
    runtime.drawRows(theme, layout, rows, selected, scroll, game)
    if footer > 0 then
      setColor(theme.colors.divider)
      love.graphics.rectangle("fill", px + spacing.lg,
        py + panelH - footer, panelW - spacing.lg * 2,
        runtime.themeMetric(theme, "divider", 1))
      setColor(theme.colors.textMuted)
      runtime.drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footer + spacing.xs, panelW - spacing.lg * 2)
    end
  end

  runtime.drawManagerTabs = function(theme, layout, state)
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
      runtime.registerPointerRegion(x - theme.spacing.xs, y - theme.spacing.xs,
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

  runtime.drawManagerSubtitle = function(theme, layout, state)
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

  runtime.drawManagerOverlay = function(theme, layout, state, viewport)
    local overlay = state.overlay
    if not overlay then return end
    runtime.drawPresenterBackdrop(theme, viewport)
    runtime.drawModalScrim(theme, viewport)
    local vx, vy, vw, vh = presenterRect(viewport)
    runtime.registerPointerRegion(vx, vy, vw, vh, {
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
    runtime.registerPointerRegion(mx, my, modalW, modalH, {
      role = "modal", modalOwner = overlay,
      activate = overlay.kind == "ok", interactive = true,
      dragHandle = false,
    })
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    runtime.drawPanelAccent(theme, mx, my, modalW, theme.radii.lg or 20)
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
      runtime.registerPointerRegion(yesX - theme.spacing.sm, footerY - theme.spacing.sm,
        yesW, lineHeight + theme.spacing.sm * 2, {
          selectionState = overlay, selectionField = "index",
          selectionIndex = 1, activate = true, dragHandle = false,
        })
      runtime.registerPointerRegion(noX - theme.spacing.sm, footerY - theme.spacing.sm,
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
      runtime.drawHintIfUseful(theme, "A / B  CLOSE", mx + theme.spacing.lg, footerY,
        modalW - theme.spacing.lg * 2)
    end
  end

  runtime.drawManagerOptionHelp = function(theme, layout, state, viewport)
    local help = state._gen1OptionDescription
    if not help then return end
    runtime.drawPresenterBackdrop(theme, viewport)
    runtime.drawModalScrim(theme, viewport)
    local vx, vy, vw, vh = presenterRect(viewport)
    runtime.registerPointerRegion(vx, vy, vw, vh, {
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
    runtime.registerPointerRegion(mx, my, modalW, modalH, {
      role = "modal", pointerCommand = "dismiss_help",
      interactive = true, dragHandle = false,
    })
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    runtime.drawPanelAccent(theme, mx, my, modalW, theme.radii.lg or 20)
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
      runtime.themeMetric(theme, "divider", 1))
    setColor(theme.colors.textMuted)
    runtime.drawHintIfUseful(theme, "SELECT / A / B  CLOSE", mx + spacing.lg,
      my + modalH - footerH + spacing.xs, modalW - spacing.lg * 2)
  end

  runtime.drawManager = function(game, state, viewport, theme)
    local rows, selected, scroll, title = managerRowsFor(game, state)
    local layout = runtime.layoutFor(viewport, theme, "mod_manager", rows, title,
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h,
      layout.radius)
    runtime.drawHeader(theme, layout, title)
    runtime.drawManagerTabs(theme, layout, state)
    runtime.drawManagerSubtitle(theme, layout, state)
    runtime.drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2,
      runtime.themeMetric(theme, "divider", 1))
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
    runtime.drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8,
      layout.w - theme.spacing.lg * 2)
    runtime.drawManagerOverlay(theme, layout, state, viewport)
    runtime.drawManagerOptionHelp(theme, layout, state, viewport)
    love.graphics.pop()
  end

  runtime.drawSummary = function(game, state, viewport, theme)
    love.graphics.push("all")
    love.graphics.origin()
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 780))
    -- Summary pages are data cards, not canvases. Keep their width near the
    -- amount of information they display so a large UI scale does not turn a
    -- six-row stat page into a huge empty rectangle.
    local mon = runtime.summaryPokemon(state) or {}
    local def = runtime.pokemonDefinition(game, mon.species)
    local name = safeText(mon.nickname or (def and def.name)
      or mon.species or "POKéMON")
    local isMovePage = state.page == 2
    -- DV Tracker adds a third SummaryMenu page while retaining the source
    -- SummaryMenu state and its normal page navigation. Read the public mon
    -- record (or the mod's equivalent page payload) without requiring the
    -- tracker or its private draw implementation.
    local isDvPage = state.page == 3 or state.page == "dvs"
      or state.view == "dvs" or state.dvsPage == true
    local summarySprite = not isMovePage and not isDvPage
      and spriteFor(game, mon, nil, "summary") or nil
    local page = isDvPage and "DVs / STAT EXP"
      or isMovePage and "MOVES / EXPERIENCE" or "STATUS / TRAINER DATA"
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme,
      isMovePage and 680 or 640))
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
    if isDvPage then
      contentBottom = statusOffset + lineGap * 6 + textHeight(bodyFont)
    elseif isMovePage then
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
    runtime.drawPresenterBackdrop(theme, viewport)
    love.graphics.setFont(bodyFont)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText(name, px + spacing.lg, py + spacing.md,
      panelW - spacing.lg * 2, titleFont)
    love.graphics.setFont(bodyFont)
    local level = mon.level and ("LEVEL %d"):format(mon.level) or ""
    local hp = mon.stats and mon.stats.hp and ("HP  %d / %d"):format(mon.hp or 0, mon.stats.hp) or ""
    local status = mon.status or "OK"
    if panelW < 620 and not isMovePage and not isDvPage then page = "STATUS" end
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
    if not isMovePage and not isDvPage then
      local sprite = summarySprite
      if sprite then
        local iw, ih = runtime.imageMetrics(sprite)
        if iw and ih then
          local spriteSize = compact and math.min(112, panelW * 0.24) or 150
          local spriteX = px + spacing.lg
          local spriteY = statusY + lineGap * 2 + spacing.sm
          local scale = math.min(spriteSize / iw, spriteSize / ih)
          setColor({ 1, 1, 1, 1 })
          runtime.drawImage(sprite, spriteX + (spriteSize - iw * scale) / 2,
            spriteY + (spriteSize - ih * scale) / 2, 0, scale, scale)
        end
      end
    end
    if isMovePage then
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
    elseif isDvPage then
      local dvs = type(state.dvs) == "table" and state.dvs
        or type(state.ivs) == "table" and state.ivs
        or type(mon.dvs) == "table" and mon.dvs
        or type(mon.ivs) == "table" and mon.ivs
        or type(mon.stats) == "table" and (
          (type(mon.stats.dvs) == "table" and mon.stats.dvs)
          or (type(mon.stats.ivs) == "table" and mon.stats.ivs)) or {}
      local statExp = type(state.statExp) == "table" and state.statExp
        or type(mon.statExp) == "table" and mon.statExp or {}
      local hpDv = dvs.hp or dvs.HP
      if hpDv == nil and (dvs.attack ~= nil or dvs.atk ~= nil
          or dvs.ATK ~= nil or dvs.defense ~= nil or dvs.def ~= nil
          or dvs.DEF ~= nil or dvs.speed ~= nil or dvs.spd ~= nil
          or dvs.SPD ~= nil or dvs.special ~= nil or dvs.spc ~= nil
          or dvs.SPC ~= nil) then
        hpDv = ((tonumber(dvs.attack or dvs.atk or dvs.ATK) or 0) % 2) * 8
          + ((tonumber(dvs.defense or dvs.def or dvs.DEF) or 0) % 2) * 4
          + ((tonumber(dvs.speed or dvs.spd or dvs.SPD) or 0) % 2) * 2
          + ((tonumber(dvs.special or dvs.spc or dvs.SPC) or 0) % 2)
      end
      local function statValue(source, keys)
        for _, key in ipairs(keys) do
          if source[key] ~= nil then return safeText(source[key]) end
        end
        return "-"
      end
      local dvRows = {
        { "HP", hpDv == nil and "-" or safeText(hpDv) },
        { "ATTACK", statValue(dvs, { "attack", "atk", "ATK" }) },
        { "DEFENSE", statValue(dvs, { "defense", "def", "DEF" }) },
        { "SPEED", statValue(dvs, { "speed", "spd", "SPD" }) },
        { "SPECIAL", statValue(dvs, { "special", "spc", "SPC" }) },
      }
      local expRows = {
        { "HP", statValue(statExp, { "hp", "HP" }) },
        { "ATTACK", statValue(statExp, { "attack", "atk", "ATK" }) },
        { "DEFENSE", statValue(statExp, { "defense", "def", "DEF" }) },
        { "SPEED", statValue(statExp, { "speed", "spd", "SPD" }) },
        { "SPECIAL", statValue(statExp, { "special", "spc", "SPC" }) },
      }
      local leftX = px + spacing.lg
      local rightX = px + panelW * 0.52
      local valueGap = bodyFont:getWidth("DEFENSE") + spacing.sm
      setColor(theme.colors.textMuted)
      drawText("DVs", leftX, statusY + lineGap)
      drawText("STAT EXP", rightX, statusY + lineGap)
      for index = 1, #dvRows do
        local rowY = statusY + lineGap * (index + 2)
        setColor(theme.colors.textMuted)
        drawText(dvRows[index][1], leftX, rowY)
        drawText(expRows[index][1], rightX, rowY)
        setColor(theme.colors.text)
        drawFittedText(dvRows[index][2], leftX + valueGap, rowY,
          math.max(24, rightX - spacing.sm - leftX - valueGap), bodyFont)
        drawFittedText(expRows[index][2], rightX + valueGap, rowY,
          math.max(24, px + panelW - spacing.lg - rightX - valueGap), bodyFont)
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
    runtime.drawHintIfUseful(theme, "A / B  continue", px + spacing.lg,
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
    local trueColor = type(entry) == "table" and entry.trueColor == true
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

    local image = runtime.imageFor(entry)
    if not image then return nil end

    -- =====================================================================
    -- UNIQUE MENU ICONS FIX
    -- We intercept the image path. If the game is loading the icon from the
    -- mod's custom color folders, we force the native trueColor flag ON!
    -- =====================================================================
    local checkPath = type(originalEntry) == "table" and (originalEntry.image or originalEntry.path) or originalEntry
    if type(checkPath) == "string" and (checkPath:find("icons_color") or checkPath:find("icons_gbc_red")) then
        trueColor = true
    end

    -- Icon descriptors are not automatically true-color art.  Mods such as
    -- Unique Menu Icons commonly provide grayscale PNGs as `{ image = ... }`
    -- descriptors, and those still need the active species palette.  Match
    -- the host renderer's contract: only an explicit `trueColor = true`
    -- descriptor opts out of palette remapping.
    trueColor = trueColor or (type(entry) == "table" and entry.trueColor == true)
    paletteRuntime.setImage(image, not trueColor
      and paletteRuntime.pokemon(game, mon and mon.species) or nil)

    local followerSheet = runtime.knownSheetOptions(originalEntry or entry, image, 0)
    if followerSheet then image = runtime.markAnimated(image, followerSheet) end
    if hasDescriptor then
      return image
    end
    if replaced then
      return runtime.markAnimated(image, { animated = true, frames = 2,
        detectSheet = true })
    end
    if iconName then
      local okW, width = pcall(function() return image:getWidth() end)
      local okH, height = pcall(function() return image:getHeight() end)
      if okW and okH and width == 16 and height >= 32 and height % 16 == 0 then
        return runtime.markAnimated(image, { animated = true,
          frames = height / 16, staticFrame = 0 })
      end
    end
    return image
  end

  runtime.resolvedSpritePath = function(game, mon, side, kind, fallback)
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
    local image = runtime.imageFor(candidate)
    if image then
      local sheet = runtime.knownSheetOptions(candidate, image, nil)
      if sheet then image = runtime.markAnimated(image, sheet) end
      local trueColor = type(candidate) == "table"
        and candidate.trueColor == true
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path, _, trueColor = runtime.resolvedSpritePath(game, mon, "front", kind,
      fallbackPath)
    -- Battle sprite replacement assets are complete single-frame pictures by
    -- default (including Gold/Silver packs). Only an explicit image
    -- descriptor with `frames` opts into sheet animation.
    image = runtime.imageFor(path)
    local sheet = image and runtime.knownSheetOptions(path, image, nil)
    if sheet then image = runtime.markAnimated(image, sheet) end
    if image then
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    image = runtime.imageFor(fallback)
    paletteRuntime.setImage(image, paletteRuntime.pokemon(game, mon and mon.species))
    return image
  end

  runtime.spriteForSide = function(game, mon, side, fallback, kind)
    local candidate = mon and imageCandidate(mon)
    local image = runtime.imageFor(candidate)
    if image then
      local sheet = runtime.knownSheetOptions(candidate, image, nil)
      if sheet then image = runtime.markAnimated(image, sheet) end
      local trueColor = type(candidate) == "table"
        and candidate.trueColor == true
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path, _, trueColor = runtime.resolvedSpritePath(game, mon, side, kind,
      fallbackPath)
    -- `pokemon.sprite` paths are authored battle pictures, not animation
    -- sheets. Explicit descriptors can still request frame cropping.
    image = runtime.imageFor(path)
    local sheet = image and runtime.knownSheetOptions(path, image, nil)
    if sheet then image = runtime.markAnimated(image, sheet) end
    if image then
      paletteRuntime.setImage(image, not trueColor
        and paletteRuntime.pokemon(game, mon and mon.species) or nil)
      return image
    end
    image = runtime.imageFor(fallback)
    paletteRuntime.setImage(image, paletteRuntime.pokemon(game, mon and mon.species))
    return image
  end

  runtime.drawTrainerCard = function(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 860))
    local panelH = math.min(h - gutter * 2,
      runtime.scaledPanelHeight(theme, w > h * 1.15, 500, 640))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.15

    love.graphics.push("all")
    love.graphics.origin()
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    local headerLayout = { x = px, y = py, w = panelW, h = panelH,
      radius = theme.radii.md }
    runtime.drawHeader(theme, headerLayout, Strings("TRAINER CARD"))

    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local contentY = py + headerH
    local contentH = panelH - headerH - footerH
    local profileH = landscape and math.min(contentH * 0.38, 170)
      or math.min(contentH * 0.34, 210)
    local portraitSize = math.max(72, math.min(profileH - spacing.md * 2,
      landscape and 128 or panelW * 0.26))
    local portraitX = px + panelW - spacing.lg - portraitSize
    local portraitY = contentY + spacing.md
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize,
      theme.radii.sm)
    local portrait = runtime.prepareImage(state.pic)
    if portrait then
      runtime.drawImageFit(portrait, portraitX + spacing.sm, portraitY + spacing.sm,
        portraitSize - spacing.sm * 2, portraitSize - spacing.sm * 2)
    end

    local save = game.save or {}
    local player = save.player or {}
    local playTime = math.floor(save.playTime or 0)
    local profileX = px + spacing.lg
    local profileW = math.max(80, portraitX - profileX - spacing.lg)
    local profileFont = font(fontCache, theme.typography.body)
    love.graphics.setFont(profileFont)
    local profile = {
      { Strings("NAME"), player.name or "RED" },
      { Strings("ID"), ("%05d"):format(tonumber(player.id) or 0) },
      { Strings("MONEY"), ("¥%d"):format(save.money or 0) },
      { Strings("TIME"), ("%d:%02d"):format(math.floor(playTime / 3600),
          math.floor(playTime / 60) % 60) },
    }
    local profileGap = math.max(26,
      math.min(44, (profileH - spacing.md * 2) / #profile))
    local labelWidth = 0
    for _, row in ipairs(profile) do
      labelWidth = math.max(labelWidth, profileFont:getWidth(row[1]))
    end
    local valueX = profileX + labelWidth + spacing.md
    for index, row in ipairs(profile) do
      local ry = contentY + spacing.md + (index - 1) * profileGap
      setColor(colors.textMuted)
      drawText(row[1], profileX, ry)
      setColor(colors.text)
      drawText(truncate(row[2], math.max(20,
        profileX + profileW - valueX)), valueX, ry)
    end

    local badges = game.data and game.data.constants and game.data.constants.badges
    if type(badges) ~= "table" or #badges == 0 then
      badges = {
        { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
        { id = "THUNDERBADGE" }, { id = "RAINBOWBADGE" },
        { id = "SOULBADGE" }, { id = "MARSHBADGE" },
        { id = "VOLCANOBADGE" }, { id = "EARTHBADGE" },
      }
    end
    local inventory = save.inventory or {}
    local ownedCount = 0
    for _, badge in ipairs(badges) do
      if inventory[badge.item or badge.id] then ownedCount = ownedCount + 1 end
    end
    local gridY = contentY + profileH + spacing.sm
    local gridH = math.max(1, contentY + contentH - gridY - spacing.sm)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.textMuted)
    drawText(Strings("BADGES  %d/%d", ownedCount, #badges),
      px + spacing.lg, gridY)
    gridY = gridY + theme.typography.caption + spacing.sm
    gridH = math.max(1, contentY + contentH - gridY)
    local baseCols = landscape and 4 or 2
    local maxRows = math.max(1, math.floor((gridH + spacing.sm) / 34))
    local cols = math.max(baseCols, math.ceil(#badges / maxRows))
    cols = math.max(1, math.min(cols, #badges))
    local gridRows = math.max(1, math.ceil(#badges / cols))
    local gap = spacing.sm
    local cellW = (panelW - spacing.lg * 2 - gap * (cols - 1)) / cols
    local cellH = math.max(1, (gridH - gap * (gridRows - 1)) / gridRows)

    for index, badge in ipairs(badges) do
      local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
      local cx = px + spacing.lg + col * (cellW + gap)
      local cy = gridY + row * (cellH + gap)
      local owned = inventory[badge.item or badge.id] and true or false
      setColor(owned and colors.surfaceRaised or colors.surface)
      love.graphics.rectangle("fill", cx, cy, cellW, cellH, theme.radii.sm)
      setColor(owned and colors.accent or colors.divider)
      love.graphics.rectangle("line", cx + 0.5, cy + 0.5,
        cellW - 1, cellH - 1, theme.radii.sm)

      local icon = runtime.imageFor(badge.icon or badge.image)
      local artSize = math.max(20, math.min(cellH - spacing.sm * 2, cellW * 0.34))
      if icon then
        runtime.drawImageFit(icon, cx + spacing.sm, cy + (cellH - artSize) / 2,
          artSize, artSize)
      else
        local sheet = owned and state.badges or state.faces
        local quad = sheet and sheet.quads and sheet.quads[index - 1]
        if sheet and sheet.img and quad then
          local image = runtime.prepareImage(sheet.img)
          local ok, qx, qy, qw, qh = pcall(quad.getViewport, quad)
          if ok and qw and qh then
            local scale = math.min(artSize / qw, artSize / qh)
            local drawW, drawH = qw * scale, qh * scale
            local drawX = cx + spacing.sm + (artSize - drawW) / 2
            local drawY = cy + (cellH - drawH) / 2
            -- The vanilla sheet deliberately uses transparent pixels for
            -- its white paper. That is harmless on the original white card,
            -- but a dark theme otherwise shows through faces and badge
            -- highlights. Restore the source paper behind this quad only;
            -- unrelated portraits keep their authored transparency.
            setColor({ 1, 1, 1, 1 })
            love.graphics.rectangle("fill", math.floor(drawX),
              math.floor(drawY), math.ceil(drawW), math.ceil(drawH))
            setColor({ 1, 1, 1, 1 })
            love.graphics.draw(image, quad, drawX, drawY, 0, scale, scale)
          end
        else
          setColor(owned and colors.accent or colors.divider)
          love.graphics.circle("line", cx + spacing.sm + artSize / 2,
            cy + cellH / 2, artSize * 0.34)
        end
      end
      local badgeName = safeText(badge.name or badge.id or ("BADGE " .. index))
        :gsub("_", " "):gsub("BADGE$", "")
      local labelX = cx + spacing.sm + artSize + spacing.sm
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(owned and colors.text or colors.textMuted)
      drawText(truncate(("%d  %s"):format(index, badgeName),
        math.max(20, cx + cellW - spacing.sm - labelX)), labelX,
        cy + (cellH - theme.typography.caption) / 2)
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    setColor(colors.textMuted)
    runtime.drawHintIfUseful(theme, Strings("A / B  back"), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.selectedListRow = function(rows, selected)
    return rows and rows[clamp(selected or 1, 1, math.max(1, #rows))]
  end

  runtime.maxMovePP = function(move, moveDef)
    if not (move and moveDef) then return 0 end
    local base = tonumber(moveDef.pp) or 0
    return base + (tonumber(move.ppUps) or 0) * math.floor(base / 5)
  end

  -- Imported box_struct records intentionally omit their calculated stat
  -- block. Derive a temporary display copy for Bill's PC without calling
  -- Stats.ensure (which would mutate the save merely because UI was drawn).
  runtime.displayStats = function(game, mon, derive)
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

  runtime.monDisplayRows = function(game, mons, state, deriveStats)
    local rows = {}
    for index, mon in ipairs(mons or {}) do
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local stats = runtime.displayStats(game, mon, deriveStats)
      local maxHP = stats.hp
      local shownHP = state and state.heal and state.heal.mon == mon
        and math.floor(state.heal.shown or state.heal.from or mon.hp or 0)
        or math.min(tonumber(mon.hp) or maxHP or 0, maxHP or math.huge)
      local status = shownHP <= 0 and "FNT" or mon.status
      local statusText = status and status ~= "" and safeText(status) or ""
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
      end
      rows[#rows + 1] = {
        label = mon.nickname or (def and def.name) or mon.species or "POKéMON",
        value = value, status = statusText, source = mon,
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
    if runtime.option("startMenuQuickView", false) ~= true
        or runtime.layoutStyle(viewport) == "full"
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
    local rowH = math.max(runtime.minimumRowHeight(theme) * 0.78,
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

    runtime.drawHeader(theme, layout, Strings("PARTY"))
    local valueFont = bodyFont
    love.graphics.setFont(bodyFont)
    for index = 1, visible do
      local mon = party[index]
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local stats = runtime.displayStats(game, mon, true)
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

  runtime.healthPalette = function(theme)
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

  runtime.healthFillColor = function(theme, ratio)
    local palette = runtime.healthPalette(theme)
    if ratio <= 0.05 then return palette.critical end
    if ratio <= 0.20 then return palette.low end
    if ratio <= 0.50 then return palette.medium end
    return palette.high
  end

  runtime.drawHPBar = function(theme, x, y, w, hp, maxHP)
    maxHP = math.max(1, tonumber(maxHP) or 1)
    local ratio = clamp((tonumber(hp) or 0) / maxHP, 0, 1)
    setColor(runtime.healthPalette(theme).track)
    love.graphics.rectangle("fill", x, y, w, 8, 4)
    setColor(runtime.healthFillColor(theme, ratio))
    love.graphics.rectangle("fill", x, y, math.max(0, w * ratio), 8, 4)
  end

  -- Shared selected-Pokémon detail card for Party and Bill's PC. All data is
  -- read from the current Pokémon/species/move records so total conversions,
  -- sprite packs, added moves, and live party copies remain authoritative.
  runtime.drawMonDetail = function(game, mon, x, y, w, h, theme, context)
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
    if sprite then runtime.drawImageFit(sprite, artX, artY, artSize, artSize) end
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
    for _, value in ipairs(def.types or {}) do types[#types + 1] = runtime.displayType(value) end
    drawFittedText(table.concat({ level, speciesName or "",
      table.concat(types, " / ") }, "  "):gsub("  +", "  "), infoX,
      y + spacing.md + textHeight(titleFont) + spacing.xs, infoW, captionFont)
    local stats = runtime.displayStats(game, mon, context == "box")
    local maxHP = stats.hp
    local shownHP = math.min(tonumber(mon.hp) or maxHP or 0,
      maxHP or math.huge)
    if maxHP then
      local barY = y + spacing.md + textHeight(titleFont)
        + textHeight(captionFont) + spacing.md
      runtime.drawHPBar(theme, infoX, barY, infoW, shownHP, maxHP)
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
        runtime.maxMovePP(move, moveDef)) or ""
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

  runtime.drawParty = function(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local party = state.party or (game.save and game.save.party) or {}
    local rows = runtime.monDisplayRows(game, party, state)
    local selected = clamp(state.index or 1, 1, math.max(1, #party))
    local minimal = runtime.option("minimalUi", false) == true
    local partyTitle = #party <= 6 and Strings("POKéMON  %d/6", #party)
      or Strings("POKéMON  %d", #party)
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 980))
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme, 760))
    if minimal then
      local footer = Strings("A  choose   B  back")
      panelW = math.min(panelW, runtime.contentWidthFor(theme, rows, partyTitle,
        footer, math.min(250, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 680), w - gutter * 2)))
    end
    local landscape = w > h * 1.20
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local rowHeight = runtime.minimumRowHeight(theme)
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
    rowHeight = math.max(runtime.minimumRowHeight(theme),
      math.min(theme.density.rowHeight,
        math.max(38, listH / math.max(1, #rows))))
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp((state.scroll or 0), 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md },
      partyTitle)
    local listLayout = { x = listX, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false,
      pointerSelectionField = "index", statusColumn = true }
    runtime.drawRows(theme, listLayout, rows, selected, scroll, game)
    if detailW > 0 then
      runtime.drawMonDetail(game, party[selected], px + panelW - detailW,
        contentY, detailW, contentH, theme, "party")
    elseif detailH > 0 then
      runtime.drawMonDetail(game, party[selected], px + spacing.sm, contentY,
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
    runtime.drawHintIfUseful(theme, footer or Strings("A  choose   B  back"), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)

    -- PartyMenu owns its injected action list internally rather than pushing
    -- another state. Draw those exact live rows as a visual modal; callbacks,
    -- selection, and cancellation remain with PartyMenu.
    if state.submenu and type(state.subItems) == "table" then
      runtime.drawModalScrim(theme, viewport)
      local vx, vy, vw, vh = presenterRect(viewport)
      runtime.registerPointerRegion(vx, vy, vw, vh, {
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
      runtime.drawHeader(theme, { x = ax, y = ay, w = actionW, h = actionH, radius = theme.radii.md },
        Strings("POKéMON ACTIONS"), colors.surfaceRaised)
      local actionVisible = math.max(1, math.min(#actionRows,
        math.floor((actionH - actionHeader) / actionRowH)))
      local actionSelected = clamp(state.subIndex or 1, 1,
        math.max(1, #actionRows))
      local actionScroll = clamp(actionSelected - actionVisible, 0,
        math.max(0, #actionRows - actionVisible))
      runtime.drawRows(theme, { x = ax, y = ay, w = actionW, h = actionH,
        rowHeight = actionRowH, header = actionHeader,
        footer = 0, visible = actionVisible, radius = theme.radii.sm,
        pointerSelectionField = "subIndex" },
        actionRows, actionSelected, actionScroll, game)
      if pointerDrawContext then pointerDrawContext.modalOwner = nil end
    end
    love.graphics.pop()
  end

  runtime.drawBoxPokemonList = function(game, state, viewport, theme)
    local mons, action = runtime.boxPokemonList(state)
    if not mons then return end
    local rows = runtime.monDisplayRows(game, mons, nil, true)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local minimal = runtime.option("minimalUi", false) == true
    local boxTitle = state.title or Strings("PC BOX")
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 980))
    if minimal then
      local footer = action == "RELEASE" and "A  release    B  back"
        or Strings("A  %s / stats    B  back", (action or "choose"):lower())
      panelW = math.min(panelW, runtime.contentWidthFor(theme, rows, boxTitle,
        footer, math.min(250, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 760), w - gutter * 2)))
    end
    local compactH = theme.typography.title + theme.typography.caption
      + math.min(#rows, 6) * runtime.minimumRowHeight(theme)
      + spacing.lg * 3
    local richH = runtime.scaledPanelHeight(theme, w > h * 1.20, 520, 640)
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
    local rowHeight = runtime.minimumRowHeight(theme)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp(state.scroll or 0, 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end
    love.graphics.push("all")
    love.graphics.origin()
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md },
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
    runtime.drawRows(theme, { x = px, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm }, rows, selected, scroll, game)
    if detailW > 0 then
      runtime.drawMonDetail(game, mons[selected], px + panelW - detailW,
        contentY, detailW, contentH, theme, "box")
    elseif detailH > 0 then
      runtime.drawMonDetail(game, mons[selected], px + spacing.sm, contentY,
        panelW - spacing.sm * 2, detailH, theme, "box")
    end
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    local hint = action == "RELEASE" and "A  release    B  back"
      or Strings("A  %s / stats    B  back", (action or "choose"):lower())
    runtime.drawHintIfUseful(theme, hint,
      px + spacing.lg, py + panelH - footerH + spacing.xs,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.drawPokedex = function(game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, "pokedex")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 920))
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme, 760))
    local landscape = w > h * 1.05
    local headerH = theme.typography.title + spacing.lg
    local footerH = landscape and (theme.typography.caption + spacing.lg)
      or (theme.typography.caption * 2 + spacing.lg + spacing.xs)
    local rowHeight = runtime.minimumRowHeight(theme)
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

    local previewX = landscape and (px + panelW - previewW) or px
    local previewY = py + headerH
    setColor(colors.surfaceRaised)
    love.graphics.rectangle("fill", previewX + spacing.sm, previewY,
      previewW - spacing.sm * 2, previewH, theme.radii.sm)
    local row = runtime.selectedListRow(rows, selected)
    local source = row and row.source
    local species = source and source.value
    local def = species and game.data and game.data.pokemon and game.data.pokemon[species]
    if def then
      local sprite = spriteFor(game, { species = species }, def.spriteFront, "dex")
      local artSize = landscape and math.min(previewW - spacing.lg * 2,
        previewH * 0.50) or math.min(previewH - spacing.md * 2, previewW * 0.24)
      local artX = previewX + spacing.lg
      local artY = previewY + spacing.md
      if sprite then runtime.drawImageFit(sprite, artX, artY, artSize, artSize) end
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
      for _, value in ipairs(types) do typeNames[#typeNames + 1] = runtime.displayType(value) end
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
    runtime.drawRows(theme, listLayout, rows, selected, scroll, game)
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
      runtime.drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    else
      if footerText and footerText ~= "" then
        runtime.drawHintIfUseful(theme, footerText, px + spacing.lg,
          py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
      end
      runtime.drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
        py + panelH - footerH + spacing.xs + theme.typography.caption + spacing.xs,
        panelW - spacing.lg * 2)
    end
    love.graphics.pop()
  end

  runtime.itemValueText = function(itemId, def)
    if not def or def.price == nil then return nil end
    local base = math.max(0, math.floor(tonumber(def.price) or 0))
    local unsellable = def.keyItem == true
      or (type(itemId) == "string" and itemId:find("^HM_")) ~= nil
      or (def.machine and def.machine.kind == "HM")
    local sell = unsellable and "—" or ("¥%d"):format(math.floor(base / 2))
    return Strings("BASE ¥%d   SELL %s", base, sell)
  end

  runtime.drawBag = function(game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, "bag")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 900))
    local minimalBag = runtime.option("minimalUi", false) == true
    local landscape = w > h * 1.05
    if minimalBag then
      panelW = math.min(panelW, runtime.contentWidthFor(theme, rows, title,
        footerText or "A  use   B  back", math.min(250, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 760), w - gutter * 2)))
    else
      local listBudget = runtime.contentWidthFor(theme, rows, title,
        footerText or "A  use   B  back", math.min(300, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 560), w - gutter * 2))
      local detailBudget = landscape
        and math.min(runtime.scaledPanelWidth(theme, 360), w - gutter * 2) or 0
      panelW = math.min(panelW, listBudget + detailBudget
        + (detailBudget > 0 and spacing.sm or 0))
    end
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local rowHeight = runtime.minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 7))
    local desiredListH = desiredRows * rowHeight
    local detailMinH = math.max(160,
      theme.typography.body + theme.typography.caption * 4 + spacing.lg * 3)
    local detailW = minimalBag and 0
      or landscape and math.min(panelW * 0.44, runtime.scaledPanelWidth(theme, 360))
      or panelW
    local previewSelected = clamp(selected or 1, 1, math.max(1, #rows))
    local previewRow = runtime.selectedListRow(rows, previewSelected)
    local previewSource = previewRow and previewRow.source
    local previewItemId = previewSource and previewSource.value
    local previewDef = previewItemId and game.data and game.data.items
      and game.data.items[previewItemId]
    local previewIcon = runtime.imageFor(imageCandidate(previewSource)
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
      countDetail(runtime.itemValueText(previewItemId, previewDef))
    elseif previewDef and previewDef.machine then
      local move = game.data.moves and game.data.moves[previewDef.machine.move]
      countDetail(Strings("%s  %s", previewDef.machine.kind or "TM",
        move and move.name or previewDef.machine.move))
      if move then
        countDetail(Strings("TYPE %s   PP %s", move.type or "â€”", move.pp or "â€”"))
      end
      countDetail(runtime.itemValueText(previewItemId, previewDef))
    elseif previewDef then
      if previewDef.keyItem then
        countDetail(Strings("KEY ITEM"))
        countDetail(runtime.itemValueText(previewItemId, previewDef))
      else
        countDetail(runtime.itemValueText(previewItemId, previewDef) or Strings("ITEM"))
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

    if detailW > 0 and detailH > 0 then
      wrapFittedText = true
      local detailX = landscape and (px + panelW - detailW) or px
      local detailY = py + headerH
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", detailX + spacing.sm, detailY,
        detailW - spacing.sm * 2, detailH, theme.radii.sm)
      local row = runtime.selectedListRow(rows, selected)
      local source = row and row.source
      local itemId = source and source.value
      local def = itemId and game.data and game.data.items and game.data.items[itemId]
      local itemName = row and row.label or Strings("ITEM")
      local icon = runtime.imageFor(imageCandidate(source) or imageCandidate(def))
      local iconSize = icon and math.min(64, detailH - spacing.md * 2) or 0
      local infoX = detailX + spacing.lg
      if icon then
        runtime.drawImageFit(icon, infoX, detailY + spacing.md, iconSize, iconSize)
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
      local value = runtime.itemValueText(itemId, def)
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
      local value = runtime.itemValueText(itemId, def)
      if value then
        drawFittedText(value, infoX,
          infoY + (theme.typography.caption + spacing.xs) * 2,
          detailMax, detailFont)
      end
    elseif def then
      local descriptionY = infoY + theme.typography.caption + spacing.xs
      if def.keyItem then
        drawFittedText(Strings("KEY ITEM"), infoX, infoY, detailMax, detailFont)
        local value = runtime.itemValueText(itemId, def)
        if value then
          drawFittedText(value, infoX, descriptionY, detailMax, detailFont)
          descriptionY = descriptionY + theme.typography.caption + spacing.xs
        end
      else
        drawFittedText(runtime.itemValueText(itemId, def) or Strings("ITEM"),
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
    runtime.drawRows(theme, listLayout, rows, selected, scroll, game)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    setColor(colors.textMuted)
    local hint = mod._gen1ModernCompatibility:bagHasPockets(state)
      and "LEFT/RIGHT  pocket   A  use   B  back"
      or "A  use   SELECT  move   B  back"
    if footerText and footerText ~= "" then hint = footerText .. "    " .. hint end
    runtime.drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.drawContextList = function(game, state, kind, viewport, theme)
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, kind)
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 900))
    local minimalContext = runtime.option("minimalUi", false) == true
    local landscape = w > h * 1.10
    if minimalContext then
      panelW = math.min(panelW, runtime.contentWidthFor(theme, rows, title,
        footerText or "A  choose   B  back", math.min(250, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 760), w - gutter * 2)))
    else
      local listBudget = runtime.contentWidthFor(theme, rows, title,
        footerText or "A  choose   B  back", math.min(300, w - gutter * 2),
        math.min(runtime.scaledPanelWidth(theme, 560), w - gutter * 2))
      local detailBudget = landscape
        and math.min(runtime.scaledPanelWidth(theme, 360), w - gutter * 2) or 0
      panelW = math.min(panelW, listBudget + detailBudget
        + (detailBudget > 0 and spacing.sm or 0))
    end
    local headerH = theme.typography.title + spacing.lg
    local messageH = math.max(72, theme.typography.caption * 2 + spacing.lg * 2)
    local rowHeight = runtime.minimumRowHeight(theme)
    local desiredRows = math.max(1, math.min(#rows, 8))
    local desiredListH = desiredRows * rowHeight
    local detailMinH = math.max(150,
      theme.typography.body + theme.typography.caption * 4 + spacing.lg * 3)
    local detailW = not minimalContext and landscape
      and math.min(panelW * 0.44, runtime.scaledPanelWidth(theme, 360)) or 0
    local previewSelected = clamp(selected or 1, 1, math.max(1, #rows))
    local previewRow = runtime.selectedListRow(rows, previewSelected)
    local previewSource = previewRow and previewRow.source
    local previewItemId = previewSource
      and type(previewSource.value) == "string" and previewSource.value or nil
    local previewDef = previewItemId and game.data and game.data.items
      and game.data.items[previewItemId]
    local previewIcon = runtime.imageFor(imageCandidate(previewSource)
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
    countDetail(runtime.itemValueText(previewItemId, previewDef))
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH, radius = theme.radii.md }, title)

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
    runtime.drawRows(theme, listLayout, rows, selected, scroll, game)

    if detailW > 0 or detailH > 0 then
      local detailX = detailW > 0 and (px + panelW - detailW) or px
      local detailY = py + headerH
      local cardW = detailW > 0 and detailW or panelW
      local cardH = detailW > 0 and listH or detailH
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", detailX + spacing.sm, detailY,
        cardW - spacing.sm * 2, cardH, theme.radii.sm)
      local row = runtime.selectedListRow(rows, selected)
      local source = row and row.source
      local itemId = source and type(source.value) == "string" and source.value or nil
      local def = itemId and game.data and game.data.items and game.data.items[itemId]
      local icon = runtime.imageFor(imageCandidate(source) or imageCandidate(def))
      local iconSize = icon and math.min(56, cardH - spacing.md * 2) or 0
      local infoX = detailX + spacing.lg
      if icon then
        runtime.drawImageFit(icon, infoX, detailY + spacing.md, iconSize, iconSize)
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
      local value = runtime.itemValueText(itemId, def)
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
    runtime.drawHintIfUseful(theme, Strings(hint), px + spacing.lg,
      py + panelH - spacing.md - theme.typography.caption,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.drawGen3Box = function(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 780))
    -- The grid itself is the content. Keep a compact square-cell frame
    -- instead of reserving the entire viewport around a 5x4 or 3x2 grid.
    local panelH = math.min(h - gutter * 2,
      runtime.scaledPanelHeight(theme, w > h * 1.20, 470, 620))
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    drawText(title, px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local footerText = state.notice or (mode == "box"
      and "A  pick/place   START  stats   SELECT  party   B  back"
      or "A  pick/place   START  stats   SELECT  box   B  back")
    runtime.drawHintIfUseful(theme, Strings(footerText), px + spacing.lg,
      py + panelH - footer + 2, panelW - spacing.lg * 2)

    for i = 1, cols * gridRows do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      local cx, cy = gx + c * cellW, gy + r * cellH
      local mon = list[i]
      runtime.registerPointerRegion(cx + 2, cy + 2, cellW - 4, cellH - 4, {
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
          local iw, ih = runtime.imageMetrics(img)
          if iw and ih then
            local maxW, maxH = cellW * 0.68, spriteAreaH * 0.92
            local scale = math.min(maxW / iw, maxH / ih)
            setColor({ 1, 1, 1, 1 })
            runtime.drawImage(img, cx + (cellW - iw * scale) / 2,
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
        local iw, ih = runtime.imageMetrics(carriedImage)
        if iw and ih then
          local scale = math.min(48 / iw, 48 / ih)
          setColor({ 1, 1, 1, 1 })
          runtime.drawImage(carriedImage, cardX + spacing.sm,
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

  runtime.drawDexEntry = function(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 780))
    local def = runtime.dexDefinition(game, state) or {}
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
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme,
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)
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
      local iw, ih = runtime.imageMetrics(sprite)
      if iw and ih then
        local scale = math.min((heroW - spacing.md * 2) / iw,
          (heroH - spacing.md * 2) / ih)
        setColor({ 1, 1, 1, 1 })
        runtime.drawImage(sprite, heroX + (heroW - iw * scale) / 2,
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
    runtime.drawHintIfUseful(theme, Strings(footer), px + spacing.lg, footerY,
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
      math.max(320, runtime.contentWidthFor(theme, rows, "FORGET A MOVE", nil,
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
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
      runtime.registerPointerRegion(px + spacing.sm, ry, panelW - spacing.sm * 2,
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
    runtime.drawHintIfUseful(theme, "A  replace   B  cancel", px + spacing.lg,
      py + panelH - footerH + spacing.sm, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawPicBox(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local body = font(fontCache, theme.typography.body)
    local image = runtime.imageFor(state.image)
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
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    runtime.registerPointerRegion(px, py, panelW, panelH, {
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
      runtime.drawImageFit(image, px + spacing.lg, artY,
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
      runtime.panelMaxWidth(theme, 760))
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme, 720))
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
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
      py + panelH - footerH, contentW, runtime.themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    runtime.drawHintIfUseful(theme, "A / B  back", contentX,
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
      runtime.panelMaxWidth(theme, 720))
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
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
      py + panelH - footerH, contentW, runtime.themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    local footer = (#rows > visible or offset > 0)
      and "UP/DOWN  scroll   A / B  back" or "A / B  back"
    runtime.drawHintIfUseful(theme, footer, contentX,
      py + panelH - footerH + spacing.xs, contentW)
    love.graphics.pop()
  end

  function mod._gen1ModernSpecialPresenters.drawRbyMmoCharacterPick(
      game, state, viewport, theme)
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, "list")
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local landscape = w > h * 1.05
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 820))
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme, 820))
    local headerH = textHeight(titleFont) + spacing.lg
    local footerH = textHeight(captionFont) + spacing.md
    local rowH = runtime.minimumRowHeight(theme)
    local detailMinH = math.max(170,
      textHeight(bodyFont) * 2 + 96 + spacing.lg * 3)
    local detailW = landscape
      and math.min(runtime.scaledPanelWidth(theme, 330), panelW * 0.42) or 0
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawHeader(theme, { x = px, y = py, w = panelW, h = panelH,
      radius = theme.radii.lg }, title or "CHARACTER")

    local row = runtime.selectedListRow(rows, selected)
    local source = row and row.source
    local spriteId = source and (source.value or source.sprite)
    -- Character artwork is authored avatar art, not a map tile/sprite. Do not
    -- tint it with the current overworld palette; that can turn every avatar
    -- into the active route's colors (the native RBY MMO picker has the same
    -- underlying palette confusion on some builds).
    local portrait = mod._gen1ModernSpecialPresenters.rbyMmoPortrait(
      game, spriteId)
    if not portrait then
      portrait = paletteRuntime.setImage(runtime.imageFor(source and
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
    runtime.drawRows(theme, listLayout, rows, selected, scroll, game)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2,
      runtime.themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    runtime.drawHintIfUseful(theme, footerText or "A  choose   B  back",
      px + spacing.lg, py + panelH - footerH + spacing.xs,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  -- Dex Radar keeps the live encounter model and all navigation behavior on
  -- its screen object.  This presenter intentionally consumes only those
  -- public fields; the source mod remains responsible for collection,
  -- cursor wrapping, held-direction repeat, and closing the screen.
  function mod._gen1ModernSpecialPresenters.drawDexRadar(
      game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local gutter = spacing.lg
    local landscape = w > h * 1.08
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      runtime.panelMaxWidth(theme, 760))
    panelW = math.min(panelW, runtime.scaledPanelWidth(theme, 760))
    local headerH = textHeight(titleFont) + textHeight(captionFont)
      + spacing.lg + spacing.sm
    local footerH = textHeight(captionFont) + spacing.lg
    local sectionH = math.max(textHeight(captionFont) + spacing.sm,
      spacing.lg + runtime.themeMetric(theme, "divider", 1))
    local rowH = math.max(runtime.minimumRowHeight(theme),
      textHeight(bodyFont) + textHeight(captionFont) + spacing.md)

    local function radarRowHeight(row)
      return row and row.kind == "header" and sectionH or rowH
    end

    local totalListH = 0
    for _, row in ipairs(state.rows or {}) do
      totalListH = totalListH + radarRowHeight(row)
    end
    if totalListH <= 0 then
      totalListH = textHeight(bodyFont) * 2 + spacing.xl
    end
    local maxPanelH = math.min(h - gutter * 2,
      runtime.scaledPanelHeight(theme, landscape, 620, 760))
    local maxListH = math.max(rowH,
      maxPanelH - headerH - footerH)
    local desiredListH = math.min(totalListH, maxListH)
    local panelH = math.min(h - gutter * 2,
      headerH + footerH + desiredListH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local listY = py + headerH
    local listH = math.max(1, panelH - headerH - footerH)
    local selectedCursor = clamp(math.floor(tonumber(state.cursor) or 1),
      1, math.max(1, #(state.monIndex or {})))
    local selectedRaw = state.monIndex and state.monIndex[selectedCursor]
    local cursorByRaw = {}
    for cursor, rawIndex in ipairs(state.monIndex or {}) do
      cursorByRaw[rawIndex] = cursor
    end

    -- Build a content-height window around the selected species. Section
    -- labels have a smaller height than encounter rows, so an ordinary
    -- row-count scroll would either clip labels or waste room at some scales.
    local firstRow, lastRow = 1, #(state.rows or {})
    local usedH = totalListH
    if totalListH > listH and selectedRaw then
      firstRow, lastRow = selectedRaw, selectedRaw
      usedH = radarRowHeight(state.rows[selectedRaw])
      while firstRow > 1 do
        local candidateH = radarRowHeight(state.rows[firstRow - 1])
        if usedH + candidateH > listH * 0.55 then break end
        firstRow = firstRow - 1
        usedH = usedH + candidateH
      end
      while lastRow < #state.rows do
        local candidateH = radarRowHeight(state.rows[lastRow + 1])
        if usedH + candidateH > listH then break end
        lastRow = lastRow + 1
        usedH = usedH + candidateH
      end
      while firstRow > 1 do
        local candidateH = radarRowHeight(state.rows[firstRow - 1])
        if usedH + candidateH > listH then break end
        firstRow = firstRow - 1
        usedH = usedH + candidateH
      end
    end

    love.graphics.push("all")
    love.graphics.origin()
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg, 4)

    setColor(colors.text)
    love.graphics.setFont(titleFont)
    drawFittedText("DEX RADAR", px + spacing.lg, py + spacing.md,
      panelW * 0.62, titleFont)
    local ownedLabel = ("%d/%d OWNED"):format(
      tonumber(state.ownedN) or 0, tonumber(state.totalN) or 0)
    love.graphics.setFont(captionFont)
    local ownedW = captionFont:getWidth(ownedLabel)
    setColor(colors.accent)
    drawText(ownedLabel, px + panelW - spacing.lg - ownedW,
      py + spacing.md + math.max(0,
        (textHeight(titleFont) - textHeight(captionFont)) / 2))
    setColor(colors.textMuted)
    drawFittedText(safeText(state.mapLabel):upper(), px + spacing.lg,
      py + spacing.md + textHeight(titleFont) + spacing.xs,
      panelW - spacing.lg * 2, captionFont)
    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      listY - spacing.xs, panelW - spacing.lg * 2,
      runtime.themeMetric(theme, "divider", 1))

    if #(state.monIndex or {}) == 0 then
      setColor(colors.surfaceRaised)
      love.graphics.rectangle("fill", px + spacing.lg,
        listY + spacing.sm, panelW - spacing.lg * 2,
        math.max(1, listH - spacing.md), theme.radii.md)
      setColor(colors.text)
      love.graphics.setFont(bodyFont)
      local empty = "NO WILD POKEMON"
      drawText(empty, px + (panelW - bodyFont:getWidth(empty)) / 2,
        listY + (listH - textHeight(bodyFont)) / 2)
    else
      love.graphics.setScissor(px, listY, panelW, listH)
      local rowY = listY + math.max(0, (listH - usedH) / 2)
      for rawIndex = firstRow, lastRow do
        local row = state.rows[rawIndex]
        local height = radarRowHeight(row)
        if row and row.kind == "header" then
          setColor(colors.accent)
          love.graphics.setFont(captionFont)
          drawFittedText(safeText(row.text or row.label):upper(),
            px + spacing.lg, rowY + (height - textHeight(captionFont)) / 2,
            panelW - spacing.lg * 2, captionFont)
          setColor(colors.divider)
          love.graphics.rectangle("fill", px + spacing.lg,
            rowY + height - runtime.themeMetric(theme, "divider", 1),
            panelW - spacing.lg * 2, runtime.themeMetric(theme, "divider", 1))
        elseif row then
          local cursorIndex = cursorByRaw[rawIndex]
          local selected = cursorIndex == selectedCursor
          local rowX = px + spacing.sm
          local rowW = panelW - spacing.sm * 2
          runtime.registerPointerRegion(rowX, rowY + 2, rowW, height - 4, {
            selectionField = "cursor", selectionIndex = cursorIndex,
            rowCount = #(state.monIndex or {}), interactive = cursorIndex ~= nil,
            activate = false, dragHandle = false,
          })
          setColor(selected and colors.selected or colors.surfaceRaised)
          love.graphics.rectangle("fill", rowX, rowY + 2, rowW,
            height - 4, theme.radii.sm)

          local iconSize = math.max(20, math.min(42, height - spacing.sm * 2))
          local iconX = px + spacing.lg
          local iconY = rowY + (height - iconSize) / 2
          local encounterIcon = row.id and iconFor(game, { species = row.id })
          if encounterIcon then
            local iw, ih = runtime.imageMetrics(encounterIcon)
            if iw and ih then
              local scale = math.min(iconSize / iw, iconSize / ih)
              setColor(row.seen and { 1, 1, 1, 1 } or { 0, 0, 0, 1 })
              runtime.drawImage(encounterIcon,
                iconX + (iconSize - iw * scale) / 2,
                iconY + (iconSize - ih * scale) / 2, 0, scale, scale)
            end
          else
            setColor(colors.divider)
            love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize,
              theme.radii.sm)
          end

          local textX = iconX + iconSize + spacing.md
          local rightEdge = px + panelW - spacing.lg
          local ownedText = row.owned and row.seen and "OWNED" or ""
          love.graphics.setFont(captionFont)
          local ownedTextW = captionFont:getWidth(ownedText)
          setColor(colors.text)
          love.graphics.setFont(bodyFont)
          drawFittedText(safeText(row.name or (row.seen and row.id) or "?????"),
            textX, rowY + spacing.sm,
            math.max(24, rightEdge - textX - ownedTextW - spacing.md), bodyFont)
          if ownedText ~= "" then
            setColor(colors.accent)
            love.graphics.setFont(captionFont)
            drawText(ownedText, rightEdge - ownedTextW,
              rowY + spacing.sm + math.max(0,
                (textHeight(bodyFont) - textHeight(captionFont)) / 2))
          end

          if row.seen then
            local details = {}
            if state.showLevels ~= false and row.minLv ~= nil then
              local minLv = tonumber(row.minLv) or row.minLv
              local maxLv = tonumber(row.maxLv) or minLv
              details[#details + 1] = minLv == maxLv
                and ("Lv " .. safeText(minLv))
                or ("Lv " .. safeText(minLv) .. "-" .. safeText(maxLv))
            end
            if state.showRates ~= false and row.rate ~= nil then
              details[#details + 1] = "RATE " .. safeText(row.rate)
            end
            setColor(colors.textMuted)
            love.graphics.setFont(captionFont)
            drawFittedText(table.concat(details, "   "), textX,
              rowY + height - spacing.sm - textHeight(captionFont),
              math.max(24, rightEdge - textX), captionFont)
          end
        end
        rowY = rowY + height
      end
      love.graphics.setScissor()
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2,
      runtime.themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    runtime.drawHintIfUseful(theme,
      "UP/DOWN  choose   LEFT/RIGHT  jump   B  back",
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
    local namingState = type(ctxInfo) == "table" and ctxInfo.state or nil
    local namingGame = runtime.ownerGame(namingState,
      type(ctxInfo) == "table" and ctxInfo.game or currentGame)
    -- Menus UI off means exactly native menu behavior. In particular, do not
    -- append our numeric rows to the original naming keyboard, whose native
    -- viewport cannot display or navigate the extended grid coherently.
    if runtime.option("menuUi", true) == false
        or runtime.hasNativeNewGameFlow(namingGame) then
      return out
    end
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
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
          runtime.registerPointerRegion(cx + 1, cy + 1, rowW - 2, cellH - 2, {
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
    runtime.drawHintIfUseful(theme, "A  choose   B  delete   SELECT  case   START  done",
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
    runtime.prepareImage(bg.img)
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
        canvas = runtime.prepareImage(target)
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
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
          runtime.registerPointerRegion(cellX, cellY, cellSize, cellSize, {
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
        runtime.registerPointerRegion(mapX + spacing.sm, ry, mapW - spacing.sm * 2,
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
    runtime.drawHintIfUseful(theme, footer, px + spacing.lg,
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
    local minW = math.min(maxW, runtime.scaledPanelWidth(theme, 220))
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
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.md)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.md)
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
    runtime.drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelFrame(theme, px, py, panelW, panelH, theme.radii.lg)
    runtime.drawPanelAccent(theme, px, py, panelW, theme.radii.lg)
    runtime.registerPointerRegion(px, py, panelW, panelH, {
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
      panelW - spacing.lg * 2, runtime.themeMetric(theme, "divider", 1))
    setColor(colors.textMuted)
    love.graphics.setFont(caption)
    local footer = maxOffset > 0 and "UP/DOWN  scroll   A/B  continue"
      or "A/B  continue"
    runtime.drawHintIfUseful(theme, footer, px + spacing.lg,
      footerY + spacing.sm, panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.battleName = function(game, battler)
    local mon = battler and battler.mon or battler
    local def = mon and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return safeText((battler and battler.name) or (mon and mon.nickname) or
      (def and def.name) or (mon and mon.species) or "POKEMON")
  end

  runtime.battleHP = function(battler)
    local mon = battler and battler.mon or battler
    if not mon then return 0, 1 end
    local maxHP = math.max(1, (mon.stats and mon.stats.hp) or mon.maxHp
      or mon.maxHP or mon.hp or 1)
    local hp = (battler and battler.shownHP) or mon.hp
      or (battler and battler.hp) or 0
    return clamp(hp, 0, maxHP), maxHP
  end

  function battleRuntime.opaque(color)
    color = color or { 0, 0, 0, 1 }
    return { color[1] or 0, color[2] or 0, color[3] or 0, 1 }
  end

  runtime.drawBattleBar = function(theme, x, y, w, h, hp, maxHP)
    setColor(runtime.healthPalette(theme).track)
    love.graphics.rectangle("fill", x, y, w, h, h / 2)
    local ratio = clamp(hp / math.max(1, maxHP), 0, 1)
    if ratio > 0 then
      setColor(runtime.healthFillColor(theme, ratio))
      love.graphics.rectangle("fill", x, y, w * ratio, h, h / 2)
    end
  end

  runtime.drawBattleFit = function(image, x, y, w, h)
    local iw, ih = runtime.imageMetrics(image)
    if not iw or not ih then return end
    local scale = math.min(w / iw, h / ih)
    setColor({ 1, 1, 1, 1 })
    runtime.drawImage(image, x + (w - iw * scale) / 2,
      y + (h - ih * scale) / 2, 0, scale, scale)
  end

  runtime.drawBattleCard = function(game, theme, battler, x, y, w, h, alignRight,
      opacity, info)
    if not battler then return end
    local spacing = theme.spacing
    local surface = theme.colors.surfaceRaised or theme.colors.surface
    -- Battle cards are cleanup plates as well as information panels. They
    -- must be opaque even when the global panel-opacity preference is lower,
    -- otherwise the native HUD remains legible underneath as a duplicate.
    surface = battleRuntime.opaque(surface)
    setColor(surface)
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.md)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", x, y, w, math.max(2,
      runtime.themeMetric(theme, "accent", 3)), theme.radii.md)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.body))
    local name = runtime.battleName(game, battler)
    local mon = battler.mon or battler
    local level = mon.level and ("Lv " .. tostring(mon.level)) or ""
    local hp, maxHP = runtime.battleHP(battler)
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
    runtime.drawBattleBar(theme, x + spacing.md, barY, w - spacing.md * 2, 8, hp, maxHP)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    drawText(("HP %d/%d"):format(math.floor(hp), math.floor(maxHP)),
      x + spacing.md, barY + 12)
    local status = battler.shownStatus or mon.status
    if status then
      setColor(theme.colors.accent)
      local statusText = safeText(status):upper()
      drawText(statusText,
        x + w - spacing.md - love.graphics.getFont():getWidth(statusText),
        barY + 12)
    elseif info and info.caught then
      local caughtText = "OWNED"
      setColor(theme.colors.accent)
      drawText(caughtText,
        x + w - spacing.md - love.graphics.getFont():getWidth(caughtText),
        barY + 12)
    end
    local experience = info and info.experience
    if type(experience) == "table" then
      local current = tonumber(experience.current or experience.value)
      local maximum = tonumber(experience.maximum or experience.max)
      if current and maximum and maximum > 0 and h >= 112 then
        local expY = y + h - spacing.md - 6
        setColor(theme.colors.textMuted)
        love.graphics.setFont(font(fontCache, theme.typography.caption))
        drawText("EXP", x + spacing.md, expY - 5)
        local expX = x + spacing.md + love.graphics.getFont():getWidth("EXP")
          + spacing.sm
        local expW = math.max(16, x + w - spacing.md - expX)
        setColor(runtime.healthPalette(theme).track)
        love.graphics.rectangle("fill", expX, expY, expW, 4, 2)
        setColor(theme.colors.accent)
        love.graphics.rectangle("fill", expX, expY,
          expW * clamp(current / maximum, 0, 1), 4, 2)
      end
    end
  end

  function battleRuntime.typeText(game, battler)
    local mon = battler and (battler.mon or battler)
    if not mon then return "" end
    local definition = mon.species and runtime.pokemonDefinition(game, mon.species)
      or nil
    local values = mon.types or definition and definition.types
    local result = {}
    if type(values) == "table" then
      for _, value in ipairs(values) do
        local label = runtime.displayType(value)
        if label ~= "" and label ~= "-" then result[#result + 1] = label end
      end
    else
      for _, value in ipairs({ mon.type1, mon.type2,
          definition and definition.type1, definition and definition.type2 }) do
        local label = value and runtime.displayType(value) or ""
        if label ~= "" and label ~= "-" then
          local duplicate = false
          for _, existing in ipairs(result) do
            if existing == label then duplicate = true break end
          end
          if not duplicate then result[#result + 1] = label end
        end
      end
    end
    return table.concat(result, " / ")
  end

  function battleRuntime.catchRateText(source, overlays)
    local rates = battleRuntime.overlayValue(source, overlays,
      { "catchRates", "catchRateBalls", "ballRates", "catchRate" })
    if type(rates) == "string" then return rates end
    if type(rates) ~= "table" then return "" end
    local function rate(keys)
      for _, key in ipairs(keys) do
        if rates[key] ~= nil then return safeText(rates[key]) end
      end
      return "-"
    end
    return ("P# %s   G# %s   U# %s"):format(
      rate({ "pokeball", "poke", "p" }),
      rate({ "greatBall", "great", "g" }),
      rate({ "ultraBall", "ultra", "u" }))
  end

  -- Content-sized status ribbons for the framed 2D presentation. These are
  -- deliberately separate from SCENE HUD cards so the voxel/native-scene
  -- layout can keep its established geometry while 2D is polished in
  -- isolation.
  runtime.drawBattle2dCard = function(game, theme, battler, x, y, w, info)
    if not battler then return 0 end
    info = info or {}
    local spacing = theme.spacing
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local bodyH, captionH = textHeight(bodyFont), textHeight(captionFont)
    local accentH = math.max(3, runtime.themeMetric(theme, "accent", 3))
    local barH = math.max(6, math.floor(captionH * 0.38))
    local compact = info.compact == true
    local metadata = {}
    if not compact and safeText(info.typeText) ~= "" then
      metadata[#metadata + 1] = info.typeText
    end
    if not compact and safeText(info.rateText) ~= "" then
      metadata[#metadata + 1] = info.rateText
    end
    local experience = info.experience
    local expCurrent = type(experience) == "table"
      and tonumber(experience.current or experience.value) or nil
    local expMaximum = type(experience) == "table"
      and tonumber(experience.maximum or experience.max) or nil
    local h = accentH + spacing.sm + bodyH + spacing.xs + barH
      + spacing.xs + captionH + spacing.sm
    if #metadata > 0 then h = h + spacing.xs + captionH end
    if compact and (safeText(info.rateText) ~= ""
        or (expCurrent and expMaximum and expMaximum > 0)) then
      h = h + spacing.xs + captionH
    end
    if not compact and expCurrent and expMaximum and expMaximum > 0 then
      h = h + spacing.xs + captionH
    end

    local surface = battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface)
    setColor(surface)
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.sm)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", x, y, w, accentH,
      theme.radii.sm, theme.radii.sm, 0, 0)
    love.graphics.rectangle("fill", x, y, math.max(3, accentH), h,
      theme.radii.sm, 0, theme.radii.sm, 0)
    setColor(theme.colors.divider)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5,
      math.max(1, w - 1), math.max(1, h - 1), theme.radii.sm)
    -- Battle status cards are real UI containers too. Reuse the selected
    -- theme frame so they remain legible and visually belong to the framed
    -- arena instead of looking like unstyled HUD leftovers.
    runtime.drawPanelFrame(theme, x, y, w, h, theme.radii.sm, false)

    local mon = battler.mon or battler
    local name = runtime.battleName(game, battler)
    local level = mon.level and ("Lv " .. tostring(mon.level)) or ""
    local hp, maxHP = runtime.battleHP(battler)
    local textX = x + spacing.md
    local textRight = x + w - spacing.md
    local titleY = y + accentH + spacing.sm
    love.graphics.setFont(bodyFont)
    local levelW = bodyFont:getWidth(level)
    local status = battler.shownStatus or mon.status
    local badge = status and safeText(status):upper()
      or info.caught and "OWNED" or ""
    if status and info.caught then badge = badge .. "  OWNED" end
    setColor(theme.colors.text)
    drawText(truncate(name, math.max(24,
      textRight - textX - levelW - spacing.sm)), textX, titleY)
    if level ~= "" then
      setColor(theme.colors.textMuted)
      drawText(level, textRight - levelW, titleY)
    end

    local barY = titleY + bodyH + spacing.xs
    runtime.drawBattleBar(theme, textX, barY,
      math.max(1, textRight - textX), barH, hp, maxHP)
    local footerY = barY + barH + spacing.xs
    love.graphics.setFont(captionFont)
    setColor(theme.colors.textMuted)
    drawText(("HP %d/%d"):format(math.floor(hp), math.floor(maxHP)),
      textX, footerY)
    if badge ~= "" then
      setColor(theme.colors.accent)
      drawText(badge, textRight - captionFont:getWidth(badge), footerY)
    end

    if compact and safeText(info.rateText) ~= "" then
      local compactRates = safeText(info.rateText):gsub("#%s*", "")
      compactRates = truncate(compactRates, textRight - textX)
      setColor(theme.colors.textMuted)
      drawText(compactRates, textX, footerY + captionH + spacing.xs)
    elseif compact and expCurrent and expMaximum and expMaximum > 0 then
      local expY = footerY + captionH + spacing.xs
      setColor(theme.colors.textMuted)
      drawText("EXP", textX, expY)
      local expX = textX + captionFont:getWidth("EXP") + spacing.sm
      local expW = math.max(24, textRight - expX)
      expY = expY + math.floor(captionH / 2) - 2
      setColor(runtime.healthPalette(theme).track)
      love.graphics.rectangle("fill", expX, expY, expW, 4, 2)
      setColor(theme.colors.accent)
      love.graphics.rectangle("fill", expX, expY,
        expW * clamp(expCurrent / expMaximum, 0, 1), 4, 2)
    end

    local nextY = footerY + captionH
    if #metadata > 0 then
      nextY = nextY + spacing.xs
      setColor(theme.colors.textMuted)
      drawText(truncate(table.concat(metadata, "   "), textRight - textX),
        textX, nextY)
      nextY = nextY + captionH
    end
    if not compact and expCurrent and expMaximum and expMaximum > 0 then
      nextY = nextY + spacing.xs
      setColor(theme.colors.textMuted)
      drawText("EXP", textX, nextY)
      local expX = textX + captionFont:getWidth("EXP") + spacing.sm
      local expY = nextY + math.floor(captionH / 2) - 2
      local expW = math.max(12, textRight - expX)
      setColor(runtime.healthPalette(theme).track)
      love.graphics.rectangle("fill", expX, expY, expW, 4, 2)
      setColor(theme.colors.accent)
      love.graphics.rectangle("fill", expX, expY,
        expW * clamp(expCurrent / expMaximum, 0, 1), 4, 2)
    end
    return h
  end

  runtime.battleImage = function(game, state, battler, side)
    if not battler then return nil end
    local mon = battler.mon or battler
    local fallback = battler.sprite or mon.sprite
    local image
    if side == "back" and state.showPlayerBack and state.playerBackPic then
      image = runtime.imageFor(state.playerBackPic)
    elseif side == "front" and state.showEnemyTrainer and state.trainerPic then
      image = runtime.imageFor(state.trainerPic)
    end
    if image then return image end
    image = runtime.spriteForSide(game, mon, side, nil, "battle")
    return image or runtime.imageFor(fallback)
  end

  battleRuntime.messageCache = setmetatable({}, { __mode = "k" })

  runtime.battleMessage = function(state)
    local native = battleRuntime.inputState(state) or state or {}
    local item = state and state.current or native.current
    local text = state and state.message or (item and item.text)
      or state and state.introText or native.message or native.introText
    if type(text) == "table" then
      text = text.text or text.value or text.label
    end
    if text then
      text = safeText(text):gsub("<PK>", "PKMN"):gsub("[\r\n\v]+", " ")
      if text ~= "" and type(native) == "table" then
        battleRuntime.messageCache[native] = text
      end
      return text
    end
    if native.phase == "menu" then
      battleRuntime.messageCache[native] = nil
      return "Choose an action."
    end
    -- BattleState clears `current` before an attack animation and HP drain,
    -- but deliberately keeps its last encoded two-line window in `shown`.
    -- Retain the last public message for the same state so modern text stays
    -- visible for exactly that source-owned hold instead of flashing blank.
    if native.msgHold or native.animPlaying then
      return battleRuntime.messageCache[native] or ""
    end
    return ""
  end

  -- Detect the host surface geometry for native-HUD cleanup. Both standard
  -- and WIDE move selectors are presented as the same source-indexed 2x2
  -- modern grid, so no directional input translation is necessary.
  runtime.battleUsesWideLayout = function(state)
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

  -- A source mod can publish a battle screen through the same data-only
  -- compatibility contract used by the other presenters. The adapter may
  -- refine the public battler/menu model, but it never owns rendering or
  -- input. Missing or invalid models simply leave the host battle state in
  -- charge.
  function battleRuntime.sourceModel(game, state)
    local compatibility = mod._gen1ModernCompatibility
    local context = compatibility.active[state]
      or compatibility:adapterFor(game, state)
    if not (context and context.screen and context.screen.layer == "battle") then
      return nil
    end
    return compatibility:modelFor(game, state, context)
  end

  function battleRuntime.presentationMode(state, model)
    local configured = safeText(runtime.option("battleUiMode", "auto")):lower()
    if configured == "hud" or configured == "hud_only"
        or configured == "menu" then
      return "hud"
    end
    if configured == "full" or configured == "canvas" then
      return "full"
    end

    local source = model or state or {}
    local explicit = safeText(source.presentation or source.presentationMode
      or source.battlePresentation):lower()
    if explicit == "hud" or explicit == "hud_only"
        or explicit == "menu" then
      return "hud"
    end
    if explicit == "full" or explicit == "canvas" then return "full" end

    if battleRuntime.nativeSceneRequested(source) then return "hud" end
    return "full"
  end

  battleRuntime.qolExpState = setmetatable({}, { __mode = "k" })

  function battleRuntime.publicExports(owners)
    if type(mod.find) ~= "function" then return nil end
    for _, owner in ipairs(owners or {}) do
      local ok, handle = pcall(mod.find, owner)
      if ok and type(handle) == "table" and type(handle.exports) == "table" then
        return handle.exports, owner
      end
    end
    return nil
  end

  function battleRuntime.modOption(game, owners, key)
    local options = game and game.save and game.save.options
    local buckets = options and options.modOptions
    if type(buckets) ~= "table" then return nil end
    for _, owner in ipairs(owners or {}) do
      local bucket = buckets[owner]
      if type(bucket) == "table" and bucket[key] ~= nil then
        return bucket[key]
      end
    end
    return nil
  end

  -- Normalize the source-owned Gen 1 experience total into the progress
  -- segment used by the modern battle card.  `Pokemon.exp` is the cumulative
  -- value at the current level, so the bar must subtract the current level's
  -- floor rather than treating the total as a 0..next-level value.  The
  -- public growth-rate registry is preferred; the vanilla curves below keep
  -- this feature working on older hosts and for plain base battles.
  function battleRuntime.baseExperience(game, battler)
    local mon = battler and (battler.mon or battler)
    local data = game and game.data
    local defs = data and data.pokemon
    local def = mon and mon.species and defs and defs[mon.species]
    local total = mon and tonumber(mon.exp or mon.experience
      or mon.expPoints or mon.experiencePoints)
    local level = mon and tonumber(mon.level)
    local growth = def and (def.growthRate or def.growth_rate)
    if not (def and total and level and growth) then return nil end

    local function expFor(value)
      local rates = data and data.growth_rates
      local record = rates and rates[growth]
      if type(record) == "table" and type(record.expForLevel) == "function" then
        local ok, result = pcall(record.expForLevel, value)
        if ok and tonumber(result) then return math.max(0, tonumber(result)) end
      end
      local n = math.max(0, tonumber(value) or 0)
      local key = safeText(growth):upper()
      if key == "FAST" then return math.floor(4 * n * n * n / 5) end
      if key == "SLOW" then return math.floor(5 * n * n * n / 4) end
      if key == "SLIGHTLY_FAST" then
        return math.floor(3 * n * n * n / 4) + 10 * n * n - 30
      end
      if key == "SLIGHTLY_SLOW" then
        return math.floor(3 * n * n * n / 4) + 20 * n * n - 70
      end
      if key == "MEDIUM_SLOW" then
        return math.floor(6 * n * n * n / 5) - 15 * n * n
          + 100 * n - 140
      end
      return n * n * n
    end

    local floor = expFor(level)
    local nextFloor = expFor(level + 1)
    local maximum = nextFloor - floor
    if maximum <= 0 then return nil end
    return {
      current = clamp(total - floor, 0, maximum),
      maximum = maximum,
      source = "gen1-modern-ui",
    }
  end

  function battleRuntime.enrichOverlays(game, state, source, overlays)
    local enriched = copy(type(overlays) == "table" and overlays or {})
    local native = battleRuntime.inputState(source) or state
    local owners = { "quality_of_life", "qol",
      "pokemon-gen1-recomp-mod-qol" }
    local exports = battleRuntime.publicExports(owners)

    if battleRuntime.overlayValue(source, enriched,
        { "experience", "expBar", "experienceBar" }) == nil then
      local baseExperience = battleRuntime.baseExperience(game,
        native and native.player)
      if baseExperience then enriched.experience = baseExperience end
    end

    if battleRuntime.overlayValue(source, enriched,
        { "experience", "expBar", "experienceBar" }) == nil
        and exports then
      local mode = battleRuntime.modOption(game, owners, "qol_exp_bar")
      local expFunction = exports.animatedExpPixels or exports.expPixels
      if mode == "on" and type(expFunction) == "function"
          and native and native.player then
        local expState = battleRuntime.qolExpState[native]
        if not expState then
          expState = {}
          battleRuntime.qolExpState[native] = expState
        end
        local ok, pixels
        if expFunction == exports.animatedExpPixels then
          ok, pixels = pcall(expFunction, native, expState)
        else
          ok, pixels = pcall(expFunction, native)
        end
        if ok and tonumber(pixels) then
          enriched.experience = { current = tonumber(pixels), maximum = 67,
            source = "quality_of_life" }
        end
      end
    end

    if battleRuntime.overlayValue(source, enriched,
        { "caughtIndicator", "caught" }) == nil then
      local enemy = native and native.enemy
      local mon = enemy and (enemy.mon or enemy)
      local dex = game and game.save and game.save.pokedex
      if native and native.kind == "wild"
          and not native.demo and not native.ghost and mon and mon.species
          and dex and type(dex.owned) == "table" then
        enriched.caughtIndicator = dex.owned[mon.species] == true
      end
    end
    return enriched
  end

  function battleRuntime.dataSource(game, state, model)
    local source = model or state or {}
    local overlays = source.overlays or source.battleOverlays
      or source.battleUiOverlays or state and state.overlays
    overlays = battleRuntime.enrichOverlays(game, state, source, overlays)
    return source, overlays
  end

  function battleRuntime.overlayValue(source, overlays, keys)
    for _, key in ipairs(keys) do
      if source[key] ~= nil then return source[key] end
      if overlays[key] ~= nil then return overlays[key] end
    end
    return nil
  end

  function battleRuntime.drawExtras(theme, source, overlays, x, y, w, h,
      skipExperience, skipCaught)
    local spacing = theme.spacing
    local exp = battleRuntime.overlayValue(source, overlays,
      { "experience", "expBar", "experienceBar" })
    local caught = battleRuntime.overlayValue(source, overlays,
      { "caughtIndicator", "caught" })
    local rates = battleRuntime.overlayValue(source, overlays,
      { "catchRates", "catchRateBalls", "ballRates", "catchRate" })
    local entries = {}

    if not skipExperience and type(exp) == "table" then
      local current = tonumber(exp.current or exp.value or exp.exp)
      local maximum = tonumber(exp.maximum or exp.max or exp.needed)
      if current and maximum and maximum > 0 then
        entries[#entries + 1] = {
          kind = "bar", label = "EXP", current = current,
          maximum = maximum,
        }
      elseif exp.label or exp.text then
        entries[#entries + 1] = { label = exp.label or exp.text }
      end
    elseif not skipExperience and type(exp) == "string" then
      entries[#entries + 1] = { label = exp }
    end

    if not skipCaught and caught ~= nil then
      local caughtValue = caught
      if type(caught) == "table" then
        caughtValue = caught.caught
        if caughtValue == nil then caughtValue = caught.owned end
      end
      entries[#entries + 1] = {
        label = caughtValue == true and "CAUGHT" or "NOT CAUGHT",
      }
    end

    if type(rates) == "table" then
      local function rate(keys)
        for _, key in ipairs(keys) do
          if rates[key] ~= nil then return safeText(rates[key]) end
        end
        return "-"
      end
      entries[#entries + 1] = {
        label = ("P# %s   G# %s   U# %s"):format(
          rate({ "pokeball", "poke", "p" }),
          rate({ "greatBall", "great", "g" }),
          rate({ "ultraBall", "ultra", "u" })),
      }
    elseif type(rates) == "string" then
      entries[#entries + 1] = { label = rates }
    end

    if #entries == 0 then return 0 end
    local fontValue = font(fontCache, theme.typography.caption)
    love.graphics.setFont(fontValue)
    local rowH = textHeight(fontValue) + spacing.xs * 2
    local shown = math.min(#entries, math.max(1, math.floor(h / rowH)))
    local panelH = shown * rowH + spacing.sm * 2
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", x, y, w, panelH, theme.radii.sm)
    for index = 1, shown do
      local entry = entries[index]
      local ey = y + spacing.sm + (index - 1) * rowH
      if entry.kind == "bar" then
        setColor(theme.colors.textMuted)
        drawText(("EXP %d/%d"):format(math.floor(entry.current),
          math.floor(entry.maximum)), x + spacing.sm, ey)
        local ratio = clamp(entry.current / entry.maximum, 0, 1)
        local barX = x + w * 0.48
        local barW = w - barX - spacing.sm
        setColor(runtime.healthPalette(theme).track)
        love.graphics.rectangle("fill", barX, ey + 3, barW,
          math.max(3, rowH - 8), 2)
        setColor(runtime.healthFillColor(theme, ratio))
        love.graphics.rectangle("fill", barX, ey + 3, barW * ratio,
          math.max(3, rowH - 8), 2)
      else
        setColor(theme.colors.textMuted)
        drawText(safeText(entry.label), x + spacing.sm, ey)
      end
    end
    return panelH
  end

  function battleRuntime.inputState(state)
    return state and state._gen1ModernBattleState or state
  end

  runtime.drawBattleActionPanel = function(game, state, theme, x, y, w, h)
    local spacing = theme.spacing
    local inputState = battleRuntime.inputState(state)
    local contentH = math.max(1, h - spacing.md * 2 - 26)
    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.md)
    runtime.drawPanelFrame(theme, x, y, w, h, theme.radii.md)
    runtime.drawPanelAccent(theme, x, y, w, theme.radii.md, 3)
    local phase = state.phase
    if phase == "menu" then
      local labels
      if state.safari then
        labels = { "BALL x" .. safeText(state.safari.balls or 0),
          "BAIT", "THROW ROCK", "RUN" }
      else
        labels = { "FIGHT", "POKEMON", "ITEM", "RUN" }
      end
      local cols = 2
      local cellW, cellH = (w - spacing.md * 3) / cols,
        (contentH - spacing.md) / 2
      local selectedIndex = tonumber(inputState and inputState.menuIndex)
        or tonumber(state.menuIndex) or 1
      for i, label in ipairs(labels) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx = x + spacing.md + col * (cellW + spacing.md)
        local cy = y + spacing.md + row * (cellH + spacing.md)
        runtime.registerPointerRegion(cx, cy, cellW, cellH, {
          selectionState = inputState, selectionField = "menuIndex",
          selectionIndex = i, rowCount = #labels, activate = true,
          interactive = true, dragHandle = false,
        })
        if i == selectedIndex then
          setColor(theme.colors.selected)
          love.graphics.rectangle("fill", cx, cy, cellW, cellH, theme.radii.sm)
        end
        setColor(i == selectedIndex and theme.colors.text or theme.colors.textMuted)
        love.graphics.setFont(font(fontCache, theme.typography.body))
        drawText(Strings(label), cx + spacing.sm,
          cy + (cellH - textHeight(love.graphics.getFont())) / 2)
      end
    elseif phase == "moveSelect" or phase == "mimicSelect" then
      local moves = phase == "mimicSelect" and state.mimicMoves
        or state.moves or state.player and state.player.curMoves or {}
      moves = type(moves) == "table" and moves or {}
      local selected = phase == "mimicSelect"
        and (inputState.mimicIndex or state.mimicIndex or 1)
        or (inputState.moveIndex or state.moveIndex or 1)
      local wide = runtime.battleUsesWideLayout(state)
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
        if move then
          runtime.registerPointerRegion(cx, cy, cellW, cellH - 4, {
            selectionState = inputState,
            selectionField = phase == "mimicSelect" and "mimicIndex"
              or "moveIndex",
            selectionIndex = i, rowCount = slotCount, activate = true,
            interactive = true, dragHandle = false,
          })
        end
        if i == selected then
          setColor(theme.colors.selected)
          love.graphics.rectangle("fill", cx, cy, cellW, cellH - 4, theme.radii.sm)
        end
        local def = move and game.data and game.data.moves and game.data.moves[move.id]
        local label = move and (def and def.name or move.id or "-") or ""
        local maximum = def and def.pp
          and def.pp + (move.ppUps or 0) * math.floor(def.pp / 5) or nil
        local pp = move and move.pp ~= nil and maximum
          and ("PP %d/%d"):format(move.pp, maximum)
          or (move and move.pp ~= nil and ("PP %d"):format(move.pp) or "")
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
      local text = runtime.battleMessage(state)
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

  runtime.drawBattleMoveDetails = function(game, state, theme, x, y, w, h)
    local spacing = theme.spacing
    local inputState = battleRuntime.inputState(state)
    local phase = state.phase
    local moves = phase == "mimicSelect" and state.mimicMoves
      or state.moves or state.player and state.player.curMoves or {}
    local selected = phase == "mimicSelect"
      and (inputState and inputState.mimicIndex or state.mimicIndex or 1)
      or (inputState and inputState.moveIndex or state.moveIndex or 1)
    local move = type(moves) == "table" and moves[selected] or nil
    local def = move and game.data and game.data.moves
      and game.data.moves[move.id] or nil
    local maximum = def and def.pp
      and def.pp + (move.ppUps or 0) * math.floor(def.pp / 5) or nil

    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.md)
    runtime.drawPanelFrame(theme, x, y, w, h, theme.radii.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    drawText("MOVE", x + spacing.md, y + spacing.md)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.body))
    local name = def and def.name or move and move.id or "-"
    drawText(truncate(safeText(name), w - spacing.md * 2),
      x + spacing.md, y + spacing.md + 22)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local moveType = def and runtime.displayType(def.type) or "-"
    drawText("TYPE  " .. safeText(moveType), x + spacing.md,
      y + h - spacing.md - 30)
    local pp = move and move.pp ~= nil and maximum
      and ("PP  %d/%d"):format(move.pp, maximum) or "PP  -"
    drawText(pp, x + spacing.md, y + h - spacing.md - 12)
  end

  function battleRuntime.moveSelection(game, state)
    local inputState = battleRuntime.inputState(state) or state or {}
    local phase = state and state.phase
    local moves = phase == "mimicSelect" and state.mimicMoves
      or state and state.moves
      or state and state.player and state.player.curMoves or {}
    moves = type(moves) == "table" and moves or {}
    local selected = phase == "mimicSelect"
      and (inputState.mimicIndex or state.mimicIndex or 1)
      or (inputState.moveIndex or state and state.moveIndex or 1)
    selected = clamp(math.floor(tonumber(selected) or 1), 1, math.max(1, #moves))
    local move = moves[selected]
    local definition = move and game.data and game.data.moves
      and game.data.moves[move.id] or nil
    local maximum = definition and definition.pp
      and definition.pp + (move.ppUps or 0) * math.floor(definition.pp / 5)
      or nil
    return moves, selected, move, definition, maximum, inputState
  end

  function battleRuntime.moveStat(value, accuracy)
    value = tonumber(value)
    if not value or value <= 0 then return "-" end
    if accuracy and value > 100 and value <= 255 then
      value = math.floor(value * 100 / 255 + 0.5)
    end
    return accuracy and (tostring(math.floor(value)) .. "%")
      or tostring(math.floor(value))
  end

  runtime.drawBattle2dMessage = function(theme, message, x, y, w, h, waiting)
    local spacing = theme.spacing
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    love.graphics.setFont(bodyFont)
    local paddingX, paddingY = spacing.lg, spacing.md
    local maxW = math.max(1, math.min(w, math.max(360, w * 0.76)))
    local minW = math.min(maxW, math.max(280, w * 0.38))
    local naturalW = bodyFont:getWidth(message) + paddingX * 2
    local panelW = clamp(naturalW, minW, maxW)
    local lines = wrappedLines(message, math.max(1, panelW - paddingX * 2))
    local lineH = textHeight(bodyFont) + spacing.xs
    local panelH = paddingY * 2 + math.max(1, #lines) * lineH
    panelH = math.min(h, panelH)
    local panelX = x + (w - panelW) / 2
    local panelY = y + h - panelH

    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH,
      theme.radii.md)
    runtime.drawPanelFrame(theme, panelX, panelY, panelW, panelH,
      theme.radii.md)
    runtime.drawPanelAccent(theme, panelX, panelY, panelW, theme.radii.md, 3)
    setColor(theme.colors.text)
    love.graphics.setFont(bodyFont)
    local maxLines = math.max(1,
      math.floor((panelH - paddingY * 2) / math.max(1, lineH)))
    for index = 1, math.min(#lines, maxLines) do
      drawText(lines[index], panelX + paddingX,
        panelY + paddingY + (index - 1) * lineH)
    end
    if waiting then
      setColor(theme.colors.accent)
      love.graphics.setFont(captionFont)
      drawText("...", panelX + panelW - paddingX - captionFont:getWidth("..."),
        panelY + panelH - paddingY - textHeight(captionFont))
    end
    return panelX, panelY, panelW, panelH
  end

  function battleRuntime.commandPanelHeight(theme)
    local spacing = theme.spacing
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local rowH = math.max(38, textHeight(bodyFont) + spacing.xs * 2)
    return spacing.sm * 2 + textHeight(captionFont) + spacing.xs
      + rowH * 2
  end

  runtime.drawBattle2dCommands = function(game, state, theme, x, y, w)
    local spacing = theme.spacing
    local inputState = battleRuntime.inputState(state) or state
    local labels = state.safari and {
      "BALL x" .. safeText(state.safari.balls or 0), "BAIT", "THROW ROCK", "RUN",
    } or { "FIGHT", "POKEMON", "ITEM", "RUN" }
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local headerH = textHeight(captionFont)
    local rowH = math.max(38, textHeight(bodyFont) + spacing.xs * 2)
    local panelH = battleRuntime.commandPanelHeight(theme)
    local selected = tonumber(inputState and inputState.menuIndex)
      or tonumber(state.menuIndex) or 1

    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", x, y, w, panelH, theme.radii.md)
    runtime.drawPanelFrame(theme, x, y, w, panelH, theme.radii.md)
    runtime.drawPanelAccent(theme, x, y, w, theme.radii.md, 3)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    drawText(state.safari and "SAFARI ACTION" or "CHOOSE ACTION",
      x + spacing.sm, y + spacing.sm)

    local gridY = y + spacing.sm + headerH + spacing.xs
    local cellW = (w - spacing.sm * 2 - spacing.xs) / 2
    for index, label in ipairs(labels) do
      local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
      local cellX = x + spacing.sm + col * (cellW + spacing.xs)
      local cellY = gridY + row * rowH
      runtime.registerPointerRegion(cellX, cellY, cellW, rowH, {
        selectionState = inputState, selectionField = "menuIndex",
        selectionIndex = index, rowCount = #labels, activate = true,
        interactive = true, dragHandle = false,
      })
      if index == selected then
        setColor(theme.colors.selected)
        love.graphics.rectangle("fill", cellX, cellY, cellW, rowH,
          theme.radii.sm)
        setColor(theme.colors.accent)
        love.graphics.rectangle("fill", cellX, cellY, 3, rowH,
          theme.radii.sm, 0, theme.radii.sm, 0)
      end
      love.graphics.setFont(bodyFont)
      setColor(index == selected and theme.colors.text or theme.colors.textMuted)
      drawText(Strings(label), cellX + spacing.sm,
        cellY + (rowH - textHeight(bodyFont)) / 2)
    end
    return panelH
  end

  function battleRuntime.movePanelHeight(theme, slotCount)
    local spacing = theme.spacing
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local rowH = math.max(42,
      math.max(textHeight(bodyFont), textHeight(captionFont))
        + spacing.xs * 2)
    return spacing.sm * 2 + textHeight(captionFont) + spacing.xs
      + rowH * 2
  end

  runtime.drawBattle2dMoves = function(game, state, theme, x, y, w)
    local spacing = theme.spacing
    local moves, selected, move, definition, maximum, inputState =
      battleRuntime.moveSelection(game, state)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local titleFont = font(fontCache, theme.typography.title)
    local headerH = textHeight(captionFont)
    local rowH = math.max(42,
      math.max(textHeight(bodyFont), textHeight(captionFont))
        + spacing.xs * 2)
    local slotCount = 4
    local panelH = battleRuntime.movePanelHeight(theme, slotCount)
    local detailW = clamp(w * 0.30, 190, math.max(190, w * 0.38))
    local listX = x + detailW
    local listW = w - detailW

    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", x, y, w, panelH, theme.radii.md)
    runtime.drawPanelFrame(theme, x, y, w, panelH, theme.radii.md)
    runtime.drawPanelAccent(theme, x, y, w, theme.radii.md, 3)
    setColor(battleRuntime.opaque(theme.colors.surface))
    love.graphics.rectangle("fill", x, y, detailW, panelH,
      theme.radii.md, 0, theme.radii.md, 0)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", listX, y + spacing.sm, 1,
      panelH - spacing.sm * 2)

    local detailX = x + spacing.sm
    local detailRight = listX - spacing.sm
    local detailY = y + spacing.sm
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    drawText("MOVE INFO", detailX, detailY)
    detailY = detailY + headerH + spacing.xs
    local moveNameFont = detailW < 250 and bodyFont or titleFont
    love.graphics.setFont(moveNameFont)
    setColor(theme.colors.text)
    local moveName = definition and definition.name or move and move.id or "-"
    drawText(truncate(safeText(moveName), detailRight - detailX),
      detailX, detailY)
    detailY = detailY + textHeight(moveNameFont) + spacing.xs
    love.graphics.setFont(captionFont)
    local moveType = definition and runtime.displayType(definition.type) or "-"
    local pp = move and move.pp ~= nil and maximum
      and ("%d/%d"):format(move.pp, maximum) or "-"
    local power = battleRuntime.moveStat(definition
      and (definition.power or definition.basePower), false)
    local accuracy = battleRuntime.moveStat(definition
      and (definition.accuracy or definition.acc), true)
    local statGap = spacing.sm
    local statW = (detailRight - detailX - statGap) / 2
    for index, row in ipairs({
        { nil, moveType }, { "PP", pp },
        { "POW", power }, { "ACC", accuracy },
      }) do
      local col = (index - 1) % 2
      local statRow = math.floor((index - 1) / 2)
      local statX = detailX + col * (statW + statGap)
      local statY = detailY + statRow * (textHeight(captionFont) + spacing.xs)
      setColor(theme.colors.textMuted)
      local label = row[1] and (row[1] .. " ") or ""
      if label ~= "" then drawText(label, statX, statY) end
      setColor(theme.colors.text)
      drawText(truncate(safeText(row[2]),
        math.max(1, statW - captionFont:getWidth(label))),
        statX + captionFont:getWidth(label), statY)
    end
    local native = battleRuntime.inputState(state) or state
    if native.player and native.player.disabledSlot == selected then
      setColor(theme.colors.accent)
      drawText("DISABLED", detailX,
        y + panelH - spacing.sm - textHeight(captionFont))
    end

    local gridY = y + spacing.sm + headerH + spacing.xs
    local cellW = listW / 2
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    drawText(state.phase == "mimicSelect" and "COPY A MOVE" or "CHOOSE MOVE",
      listX + spacing.sm, y + spacing.sm)
    for index = 1, slotCount do
      local entry = moves[index]
      local col = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      local cellX = listX + col * cellW
      local cellY = gridY + row * rowH
      runtime.registerPointerRegion(cellX, cellY, cellW, rowH, {
        selectionState = inputState,
        selectionField = state.phase == "mimicSelect" and "mimicIndex"
          or "moveIndex",
        selectionIndex = index, rowCount = slotCount,
        activate = entry ~= nil, interactive = entry ~= nil,
        dragHandle = false,
      })
      if index == selected then
        setColor(theme.colors.selected)
        love.graphics.rectangle("fill", cellX + 1, cellY,
          cellW - 1, rowH, theme.radii.sm)
        setColor(theme.colors.accent)
        love.graphics.rectangle("fill", cellX + 1, cellY, 3, rowH)
      end
      if col == 1 then
        setColor(theme.colors.divider)
        love.graphics.rectangle("fill", cellX, cellY + spacing.xs,
          1, rowH - spacing.xs * 2)
      end
      if row == 1 then
        setColor(theme.colors.divider)
        love.graphics.rectangle("fill", cellX + spacing.sm, cellY,
          cellW - spacing.sm * 2, 1)
      end
      local entryDefinition = entry and game.data and game.data.moves
        and game.data.moves[entry.id] or nil
      local entryName = entry and (entryDefinition and entryDefinition.name
        or entry.id) or "-"
      local entryMaximum = entryDefinition and entryDefinition.pp
        and entryDefinition.pp + (entry.ppUps or 0)
          * math.floor(entryDefinition.pp / 5) or nil
      local entryPP = entry and entry.pp ~= nil and entryMaximum
        and ("PP %d/%d"):format(entry.pp, entryMaximum) or ""
      if native.moveSwapIndex == index then
        entryPP = "MOVING"
      elseif native.player and native.player.disabledSlot == index then
        entryPP = "DISABLED"
      end
      love.graphics.setFont(bodyFont)
      setColor(index == selected and theme.colors.text or theme.colors.textMuted)
      local ppW = captionFont:getWidth(entryPP)
      drawText(truncate(safeText(entryName),
        math.max(20, cellW - spacing.sm * 2 - ppW - spacing.xs)),
        cellX + spacing.sm,
        cellY + (rowH - textHeight(bodyFont)) / 2)
      love.graphics.setFont(captionFont)
      setColor(theme.colors.textMuted)
      drawText(entryPP, cellX + cellW - spacing.sm - ppW,
        cellY + (rowH - textHeight(captionFont)) / 2)
    end
    return panelH
  end

  function battleRuntime.topState(game)
    local stack = game and game.stack
    if not stack then return nil end
    if type(stack.top) == "function" then
      local ok, top = pcall(stack.top, stack)
      if ok then return top end
    end
    local states = stack.states
    return type(states) == "table" and states[#states] or nil
  end

  -- Level-up is a native BattleState child rather than a normal presenter.
  -- The host still owns the stat transition and semantic input, while the
  -- modern battle layer owns the visible presentation. The explicit stat
  -- shape is intentional: older hosts do not publish a stable child ID, but
  -- StatBox has always exposed these four values through `mon.stats`.
  function battleRuntime.isLevelUpState(game, state)
    if type(state) ~= "table" then return false end
    local states = game and game.stack and game.stack.states
    local battle
    local exactStatBox = false
    local stateIndex
    local stateClass = classOf(state)
    if type(states) == "table" then
      -- Search below the child first. BattleState.StatBox is pushed on top of
      -- its owning battle, and limiting the primary search to that ancestry
      -- avoids mistaking an unrelated state elsewhere in the stack for its
      -- owner. Some hosts decorate the child before this hook runs, so keep a
      -- structural fallback after the exported class check.
      for index = #states, 1, -1 do
        if states[index] == state and not stateIndex then
          stateIndex = index
          break
        end
      end
      local first = (stateIndex or (#states + 1)) - 1
      for index = first, 1, -1 do
        local candidate = states[index]
        if candidate ~= state and candidate then
          -- Newer hosts publicly export BattleState.StatBox. Prefer that
          -- stable identity over field guessing so an untagged native
          -- level-up state cannot be rejected as an unknown opaque screen.
          local candidateClass = classOf(candidate)
          local statClass = type(candidateClass) == "table"
            and rawget(candidateClass, "StatBox") or nil
          if type(statClass) == "table"
              and (stateClass == statClass
                or getmetatable(state) == statClass
                or inherits(stateClass, statClass)) then
            exactStatBox = true
          end
          if not battle and runtime.kindFor(candidate, game) == "battle" then
            battle = candidate
          end
        end
      end
      -- A few older stack implementations hand hooks a proxy rather than the
      -- literal table stored in `states`. Fall back to the complete stack for
      -- its owning BattleState in that case.
      if not battle then
        for index = #states, 1, -1 do
          local candidate = states[index]
          if candidate ~= state and candidate
              and runtime.kindFor(candidate, game) == "battle" then
            battle = candidate
            break
          end
        end
      end
    end
    if exactStatBox and battle and state ~= battle then return true end
    if not battle or state == battle then return false end
    if state.kind == "levelup" or state.kind == "level_up"
        or state.screenId == "levelup" or state.screenId == "level_up" then
      return true
    end
    local mon = state.mon
    local stats = mon and mon.stats
    return type(mon) == "table" and type(stats) == "table"
      and stats.attack ~= nil and stats.defense ~= nil
      and stats.speed ~= nil and stats.special ~= nil
      and state.screenId == nil and state.kind == nil
  end

  function battleRuntime.fullBattleInStack(game)
    if runtime.option("battleUiWip", false) ~= true then return nil end
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return nil end
    for index = #states, 1, -1 do
      local candidate = states[index]
      if candidate and runtime.kindFor(candidate, game) == "battle"
          and (battleRuntime.presentationMode(candidate,
            battleRuntime.sourceModel(game, candidate)) == "full"
            or battleRuntime.isLevelUpState(game,
              battleRuntime.topState(game))) then
        return candidate
      end
    end
    return nil
  end

  -- Battle UI is intentionally opt-in while it remains WIP. State decorators
  -- must therefore be reversible: disabling the option in-session must leave
  -- the host and every other mod with the exact draw methods they supplied.
  -- Only restore a method when our wrapper is still the current owner; a later
  -- third-party wrapper is never overwritten.
  function battleRuntime.restoreDecoratedState(state)
    if type(state) ~= "table" then return state end

    if state._gen1ModernBattleChildDraw
        and state.draw == state._gen1ModernBattleChildDraw then
      state.draw = state._gen1ModernBattleChildNativeDraw
      state._gen1ModernBattleChildDraw = nil
      state._gen1ModernBattleChildNativeDraw = nil
    end
    if state._gen1ModernBattleHudDraw
        and state.drawHUDs == state._gen1ModernBattleHudDraw then
      state.drawHUDs = state._gen1ModernBattleNativeHud
      state._gen1ModernBattleHudDraw = nil
      state._gen1ModernBattleNativeHud = nil
      state._gen1ModernBattleSceneIsolation = nil
    end
    if state._gen1ModernBattleTextDraw
        and state.drawTextArea == state._gen1ModernBattleTextDraw then
      state.drawTextArea = state._gen1ModernBattleNativeText
      state._gen1ModernBattleTextDraw = nil
      state._gen1ModernBattleNativeText = nil
    end
    if state._gen1ModernBattlePicturesDraw
        and state.drawPicsLayer == state._gen1ModernBattlePicturesDraw then
      state.drawPicsLayer = state._gen1ModernBattleNativePictures
      state._gen1ModernBattlePicturesDraw = nil
      state._gen1ModernBattleNativePictures = nil
      state._gen1ModernBattleWidePictures = nil
    end
    if state._gen1ModernBattleSurfaceDraw
        and state.draw == state._gen1ModernBattleSurfaceDraw then
      state.draw = state._gen1ModernBattleWorldDraw
      state._gen1ModernBattleSurfaceDraw = nil
      state._gen1ModernBattleWorldDraw = nil
      state._gen1ModernBattleWorldSurface = nil
    end
    return state
  end

  function battleRuntime.restoreBattleDecorations(game)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return end
    for _, state in ipairs(states) do
      battleRuntime.restoreDecoratedState(state)
    end
  end

  function battleRuntime.childOpen(game, state)
    local native = battleRuntime.inputState(state) or state
    local top = battleRuntime.topState(game)
    return top ~= nil and top ~= native
  end

  function battleRuntime.ownsClassicSurface(state)
    state = battleRuntime.inputState(state) or state
    local levelUp = state and state.game
      and battleRuntime.isLevelUpState(state.game,
        battleRuntime.topState(state.game))
    return type(state) == "table"
      and runtime.option("battleUiWip", false) == true
      and runtime.option("hideOriginalUi", true) ~= false
      and (battleRuntime.presentationMode(state, nil) == "full" or levelUp)
      and not runtime.battleUsesWideLayout(state)
  end

  function battleRuntime.usesWorldBackground(state)
    state = battleRuntime.inputState(state) or state
    if type(state) ~= "table" then return false end
    if type(state.bgMode) == "function" then
      local ok, value = pcall(state.bgMode, state)
      if ok then return safeText(value):lower() == "world" end
    end
    local options = state.game and state.game.save and state.game.save.options
    return type(options) == "table"
      and safeText(options.battleBg):lower() == "world"
  end

  function battleRuntime.usesBlackBackground(state)
    state = battleRuntime.inputState(state) or state
    if type(state) ~= "table" then return false end
    if type(state.bgMode) == "function" then
      local ok, value = pcall(state.bgMode, state)
      if ok then return safeText(value):lower() == "black" end
    end
    local options = state.game and state.game.save and state.game.save.options
    return type(options) == "table"
      and safeText(options.battleBg):lower() == "black"
  end

  function battleRuntime.ownsWorldSurface(state)
    state = battleRuntime.inputState(state) or state
    local levelUp = state and state.game
      and battleRuntime.isLevelUpState(state.game,
        battleRuntime.topState(state.game))
    return type(state) == "table"
      and runtime.option("battleUiWip", false) == true
      and runtime.option("hideOriginalUi", true) ~= false
      and (battleRuntime.presentationMode(state, nil) == "full" or levelUp)
      and battleRuntime.usesWorldBackground(state)
  end

  -- Native-coordinate bounds of the modern battle arena. WIDE still renders
  -- its live 304x144 source scene, but the modern frame intentionally uses a
  -- narrower 1.78:1 composition. Keeping this rectangle in native pixels lets
  -- the source draw, compose scrub, and screen-space frame share one edge.
  function battleRuntime.worldSceneRect(state)
    if runtime.battleUsesWideLayout(state) then
      -- The source WORLD surface is scaled independently of the ornamental
      -- frame. Four native pixels of horizontal safety on each side keep the
      -- paper fill and animated scene inside the frame after scaling/rounding,
      -- while leaving the usable battle height and sprite staging intact.
      -- WIDE's native paper begins at y=0, while the modern arena begins seven
      -- source pixels lower after the nine-slice inset is applied.  Clip to
      -- that same edge (and preserve the old y=105 lower bound) so the source
      -- paper cannot reappear as a white strip above the ornamental frame at
      -- larger or fractional window scales.
      return 28, 7, 248, 98
    end
    return 3, 3, 154, 102
  end

  -- WIDE positions the opponent for all 304 native pixels. The modern arena
  -- trims roughly 27 pixels from each side, so pull only the source-owned
  -- opponent picture inward. This preserves send-out/faint picture timing and
  -- palette animation instead of drawing a second static sprite in the HUD.
  function battleRuntime.decorateWideScenePlacement(state)
    if runtime.option("battleUiWip", false) ~= true
        or type(state) ~= "table" or type(state.drawPicsLayer) ~= "function"
        or state._gen1ModernBattleWidePictures then
      return state
    end
    state._gen1ModernBattleWidePictures = true
    state._gen1ModernBattleNativePictures = state.drawPicsLayer
    state._gen1ModernBattlePicturesDraw = function(self, slide, sx, sy,
        onlySide, ...)
      if runtime.option("battleUiWip", false) == true
          and runtime.option("hideOriginalUi", true) ~= false
          and battleRuntime.presentationMode(self, nil) == "full"
          and runtime.battleUsesWideLayout(self)
          and onlySide == "enemy" then
        sx = (tonumber(sx) or 0) - 12
      end
      return self._gen1ModernBattleNativePictures(self,
        slide, sx, sy, onlySide, ...)
    end
    state.drawPicsLayer = state._gen1ModernBattlePicturesDraw
    return state
  end

  -- WORLD normally paints all 304x144 source pixels with battle paper. Replace
  -- that fill with paper only inside the modern arena and clip the rest of the
  -- source battle draw to the same rectangle. White sprite pixels, palettes,
  -- flashes, attacks, send-outs, captures, and shakes remain source-owned,
  -- while the overworld is visible everywhere outside our ornamental frame.
  function battleRuntime.decorateWorldSurface(state)
    if runtime.option("battleUiWip", false) ~= true
        or type(state) ~= "table" or type(state.draw) ~= "function"
        or state._gen1ModernBattleWorldSurface then
      return state
    end
    state._gen1ModernBattleWorldSurface = true
    state._gen1ModernBattleWorldDraw = state.draw
    state._gen1ModernBattleSurfaceDraw = function(self, ...)
      if not battleRuntime.ownsWorldSurface(self)
          or not (love and love.graphics
            and type(love.graphics.rectangle) == "function") then
        return self._gen1ModernBattleWorldDraw(self, ...)
      end

      local graphics = love.graphics
      local wide = runtime.battleUsesWideLayout(self)
      local fieldW = wide and 304 or 160
      local sceneX, sceneY, sceneW, sceneH =
        battleRuntime.worldSceneRect(self)
      local originalRectangle = graphics.rectangle
      local skippedPaper = false
      local arguments = { n = select("#", ...), ... }
      local unpackValues = table.unpack or unpack
      local results
      local previousScissor
      if type(graphics.getScissor) == "function" then
        previousScissor = { graphics.getScissor() }
      end

      -- Classic color battles retain a private BG canvas between frames.
      -- Clear it before skipping the paper fill so stale pixels cannot leak
      -- into the newly transparent world-backed field.
      if not wide and (self.bgCanvas or self.waveCanvas)
          and type(graphics.getCanvas) == "function"
          and type(graphics.setCanvas) == "function"
          and type(graphics.clear) == "function" then
        local previousCanvas = graphics.getCanvas()
        for _, battleCanvas in ipairs({ self.bgCanvas, self.waveCanvas }) do
          if battleCanvas then
            graphics.setCanvas(battleCanvas)
            graphics.clear(0, 0, 0, 0)
          end
        end
        graphics.setCanvas(previousCanvas)
      end

      graphics.rectangle = function(mode, x, y, width, height, ...)
        if mode == "fill" and x == 0 and y == 0
            and width == fieldW and height == 144 then
          local target = type(graphics.getCanvas) == "function"
            and graphics.getCanvas() or nil
          local privatePaper = not wide
            and (target == self.bgCanvas or target == self.waveCanvas)
          if privatePaper or not skippedPaper then
            skippedPaper = true
            return originalRectangle(mode, sceneX, sceneY,
              sceneW, sceneH, ...)
          end
        end
        return originalRectangle(mode, x, y, width, height, ...)
      end

      local function pack(...)
        return { n = select("#", ...), ... }
      end
      local function onError(problem)
        if debug and type(debug.traceback) == "function" then
          return debug.traceback(problem, 2)
        end
        return tostring(problem)
      end
      if type(graphics.setScissor) == "function" then
        graphics.setScissor(sceneX, sceneY, sceneW, sceneH)
      end
      local ok, problem = xpcall(function()
        results = pack(self._gen1ModernBattleWorldDraw(self,
          unpackValues(arguments, 1, arguments.n)))
      end, onError)
      graphics.rectangle = originalRectangle
      if type(graphics.setScissor) == "function" then
        if previousScissor and #previousScissor == 4 then
          graphics.setScissor(previousScissor[1], previousScissor[2],
            previousScissor[3], previousScissor[4])
        else
          graphics.setScissor()
        end
      end
      if not ok then error(problem, 0) end
      return unpackValues(results, 1, results.n)
    end
    state.draw = state._gen1ModernBattleSurfaceDraw
    return state
  end

  function battleRuntime.nativeIntroHudNeeded(state)
    state = battleRuntime.inputState(state) or state or {}
    return state.introBalls == true
  end

  -- Convert the Game Boy battle-effect offsets into the current fixed battle
  -- surface. The scene remains host-rendered; applying the same displacement
  -- to modern cards keeps impact shakes coherent without reproducing battle
  -- animation timing in this mod.
  function battleRuntime.animationOffsets(state, w, h)
    state = battleRuntime.inputState(state) or state or {}
    local fx = type(state.fx) == "table" and state.fx or {}
    local sx = tonumber(fx.shakeX) or 0
    local sy = tonumber(fx.shakeY) or 0
    if sx == 0 and sy == 0 and (tonumber(fx.shake) or 0) > 0 then
      sx = (tonumber(state.frame) or 0) % 4 < 2 and 2 or -2
    end
    local scale = math.max(1, math.min(w / 160, h / 144))
    return math.floor(sx * scale + 0.5), math.floor(sy * scale + 0.5),
      math.floor((tonumber(fx.hudShakeX) or 0) * scale + 0.5)
  end

  function battleRuntime.presentationTheme(theme, w, h)
    local scale = clamp(math.min(w / 760, h / 600), 1, 1.55)
    if scale <= 1.001 then return theme end
    return scaledTheme(theme, scale, scale, themeScaleCache)
  end

  function battleRuntime.decorateClassicScene(game, state)
    if runtime.option("battleUiWip", false) ~= true
        or type(state) ~= "table" or runtime.kindFor(state, game) ~= "battle"
        or type(state.drawHUDs) ~= "function"
        or type(state.drawTextArea) ~= "function"
        or state._gen1ModernBattleSceneIsolation then
      return state
    end
    state._gen1ModernBattleNativeHud = state.drawHUDs
    state._gen1ModernBattleNativeText = state.drawTextArea
    state._gen1ModernBattleSceneIsolation = true
    state._gen1ModernBattleHudDraw = function(self, ...)
      if battleRuntime.ownsClassicSurface(self)
          and not battleRuntime.nativeIntroHudNeeded(self) then
        return
      end
      return self._gen1ModernBattleNativeHud(self, ...)
    end
    state.drawHUDs = state._gen1ModernBattleHudDraw
    state._gen1ModernBattleTextDraw = function(self, ...)
      if battleRuntime.ownsClassicSurface(self) then return end
      return self._gen1ModernBattleNativeText(self, ...)
    end
    state.drawTextArea = state._gen1ModernBattleTextDraw
    return state
  end

  function battleRuntime.battlerVisible(state, side)
    state = battleRuntime.inputState(state) or state or {}
    if (tonumber(state.introSlide) or 0) ~= 0 or state.introBalls then
      return false
    end
    if side == "enemy" then
      local enemy = state.enemy
      if not enemy or state.showEnemyTrainer or state.enemySendingOut
          or enemy.fainted then return false end
      if type(state.growInScale) == "function" then
        local ok, growing = pcall(state.growInScale, state, enemy)
        if ok and growing then return false end
      end
      return true
    end
    return state.player ~= nil and not state.safari and not state.demo
      and not state.showPlayerBack
  end

  function battleRuntime.drawPartyStatus(theme, party, x, y, w, label)
    if type(party) ~= "table" then return 0 end
    local spacing = theme.spacing
    local captionFont = font(fontCache, theme.typography.caption)
    local dot = math.max(10, textHeight(captionFont) - 2)
    local h = spacing.sm * 2 + textHeight(captionFont) + spacing.xs + dot
    setColor(battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface))
    love.graphics.rectangle("fill", x, y, w, h, theme.radii.sm)
    setColor(theme.colors.divider)
    love.graphics.rectangle("line", x + 0.5, y + 0.5,
      math.max(1, w - 1), math.max(1, h - 1), theme.radii.sm)
    love.graphics.setFont(captionFont)
    setColor(theme.colors.textMuted)
    drawText(label or "PARTY", x + spacing.md, y + spacing.sm)
    local palette = runtime.healthPalette(theme)
    local startX = x + w - spacing.md - dot * 6 - spacing.xs * 5
    local dotY = y + spacing.sm + textHeight(captionFont) + spacing.xs
    for index = 1, 6 do
      local mon = party[index]
      local color = palette.track
      if mon then
        local hp = tonumber(mon.hp) or tonumber(mon.mon and mon.mon.hp) or 0
        local status = mon.status or mon.mon and mon.mon.status
        color = hp <= 0 and palette.critical
          or status and palette.medium or palette.high
      end
      setColor(color)
      love.graphics.circle("fill",
        startX + (index - 1) * (dot + spacing.xs) + dot / 2,
        dotY + dot / 2, dot / 2)
      setColor(theme.colors.divider)
      love.graphics.circle("line",
        startX + (index - 1) * (dot + spacing.xs) + dot / 2,
        dotY + dot / 2, dot / 2)
    end
    return h
  end

  function battleRuntime.drawCleanup(theme, x, y, w, h)
    if w <= 0 or h <= 0 then return end
    setColor(battleRuntime.opaque(theme.colors.surface))
    love.graphics.rectangle("fill", math.floor(x), math.floor(y),
      math.ceil(w), math.ceil(h))
  end

  function battleRuntime.caughtValue(source, overlays)
    local caught = battleRuntime.overlayValue(source, overlays,
      { "caughtIndicator", "caught" })
    if type(caught) == "table" then
      if caught.caught ~= nil then return caught.caught == true end
      return caught.owned == true
    end
    return caught == true
  end

  -- FIXED battles expose the exact centred surface rectangle through the HUD
  -- viewport. Anchor modern battle furniture to that surface instead of the
  -- whole monitor, which is especially important on ultrawide displays.
  function battleRuntime.viewportRect(viewport, state)
    local safeX, safeY, safeW, safeH = presenterRect(viewport)
    local x = tonumber(viewport and viewport.gameX)
    local y = tonumber(viewport and viewport.gameY)
    local w = tonumber(viewport and viewport.gameWidth)
    local h = tonumber(viewport and viewport.gameHeight)
    if x and y and w and h and w > 0 and h > 0 then
      local right = math.min(safeX + safeW, x + w)
      local bottom = math.min(safeY + safeH, y + h)
      x, y = math.max(safeX, x), math.max(safeY, y)
      if right > x and bottom > y then
        w, h = right - x, bottom - y
      else
        x, y, w, h = safeX, safeY, safeW, safeH
      end
    else
      x, y, w, h = safeX, safeY, safeW, safeH
    end
    -- WIDE's 304:144 surface is intentionally panoramic, but mirroring that
    -- full span with modern furniture makes every card and button feel
    -- needlessly stretched on desktop. Keep the live source scene untouched
    -- while bringing the ornamental frame and controls modestly inward.
    if runtime.battleUsesWideLayout(state) and w > h * 1.78 then
      local framedW = math.min(w, h * 1.78, safeW * 0.90)
      x = x + (w - framedW) / 2
      w = framedW
    end
    return x, y, w, h
  end

  -- Level-up is a battle child, but it is still part of the modern battle
  -- presentation.  Keep the host responsible for the stat transition and
  -- read the resulting public mon values into a compact, content-sized card.
  -- This deliberately does not redraw the battle scene or the Pokémon: those
  -- remain source-owned so their animation, palette, and transition timing
  -- continue uninterrupted underneath the card.
  runtime.drawBattleLevelUp = function(game, state, viewport, theme, model)
    local x, y, w, h = battleRuntime.viewportRect(viewport, state)
    theme = battleRuntime.presentationTheme(theme, w, h)
    local spacing = theme.spacing
    local top = battleRuntime.topState(game) or state
    local mon = top and top.mon or top and top.pokemon or {}
    local stats = type(mon.stats) == "table" and mon.stats or {}
    local titleFont = font(fontCache, theme.typography.title)
    local bodyFont = font(fontCache, theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local inset = math.max(spacing.md,
      math.floor(math.min(w, h) * 0.018))
    local titleH = textHeight(titleFont)
    local bodyH = textHeight(bodyFont)
    local captionH = textHeight(captionFont)
    local tileH = math.max(bodyH, captionH) + spacing.sm * 2
    local panelW = math.min(w - inset * 2,
      math.max(300, math.min(460, w * 0.44)))
    local panelH = spacing.md + titleH + spacing.xs + bodyH
      + spacing.md + tileH * 2 + spacing.sm + spacing.md
    panelH = math.min(h - inset * 2, panelH)
    local panelX
    if w < 640 then
      panelX = x + (w - panelW) / 2
    else
      panelX = x + w - panelW - inset
    end
    local panelY = y + math.max(inset, (h - panelH) * 0.30)
    local nickname = safeText(mon.nickname or mon.name or mon.species)
    local level = safeText(mon.level or top.level)
    local rows = {
      { "ATTACK", stats.attack },
      { "DEFENSE", stats.defense },
      { "SPEED", stats.speed },
      { "SPECIAL", stats.special },
    }

    love.graphics.push("all")
    love.graphics.origin()
    local surface = battleRuntime.opaque(theme.colors.surfaceRaised
      or theme.colors.surface)
    runtime.drawPanelFrame(theme, panelX, panelY, panelW, panelH,
      theme.radii.lg, surface)
    runtime.drawPanelAccent(theme, panelX, panelY, panelW,
      theme.radii.lg, 3)

    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    drawText("LEVEL UP!", panelX + spacing.md, panelY + spacing.md)
    local identityY = panelY + spacing.md + titleH + spacing.xs
    love.graphics.setFont(bodyFont)
    setColor(theme.colors.text)
    local levelText = level ~= "" and ("Lv " .. level) or ""
    local levelW = bodyFont:getWidth(levelText)
    drawText(truncate(nickname ~= "" and nickname or "POKEMON",
      math.max(40, panelW - spacing.md * 2 - levelW - spacing.sm)),
      panelX + spacing.md, identityY)
    if levelText ~= "" then
      setColor(theme.colors.textMuted)
      drawText(levelText, panelX + panelW - spacing.md - levelW, identityY)
    end

    local gridY = identityY + bodyH + spacing.md
    local columnW = (panelW - spacing.md * 2 - spacing.sm) / 2
    for index, row in ipairs(rows) do
      local column = (index - 1) % 2
      local line = math.floor((index - 1) / 2)
      local cellX = panelX + spacing.md + column * (columnW + spacing.sm)
      local cellY = gridY + line * (tileH + spacing.sm)
      setColor(battleRuntime.opaque(theme.colors.selected
        or theme.colors.surface))
      love.graphics.rectangle("fill", cellX, cellY, columnW, tileH,
        theme.radii.sm)
      setColor(theme.colors.divider)
      love.graphics.rectangle("line", cellX, cellY, columnW, tileH,
        theme.radii.sm)
      setColor(theme.colors.textMuted)
      love.graphics.setFont(captionFont)
      drawText(row[1], cellX + spacing.sm,
        cellY + (tileH - captionH) / 2)
      local value = row[2] == nil and "--" or safeText(row[2])
      setColor(theme.colors.text)
      love.graphics.setFont(bodyFont)
      drawText(value, cellX + columnW - spacing.sm - bodyFont:getWidth(value),
        cellY + (tileH - bodyH) / 2)
    end
    love.graphics.pop()
  end

  runtime.drawBattle2dHud = function(game, state, viewport, theme, model, options)
    -- FIX 1: NEUTRALIZE FORCED OPACITY
    battleRuntime.opaque = function(color) return color end

    options = options or {}
    local x, y, w, h = battleRuntime.viewportRect(viewport, state)
    theme = battleRuntime.presentationTheme(theme, w, h)
    local spacing = theme.spacing
    local source, overlays = battleRuntime.dataSource(game, state, model)
    local native = battleRuntime.inputState(source) or state
    local phase = source.phase or native.phase
    local shakeX, shakeY, enemyShakeX =
      battleRuntime.animationOffsets(source, w, h)
    local inset = math.max(spacing.md,
      math.floor(math.min(w, h) * 0.018))
    local innerX, innerY = x + inset, y + inset
    local innerW, innerH = w - inset * 2, h - inset * 2
    local arenaH = math.max(spacing.xl,
      h * (104 / 144) - inset)

    love.graphics.push("all")
    love.graphics.origin()

    runtime.drawPanelFrame(theme, innerX, innerY, innerW, arenaH,
      theme.radii.lg, false)
    runtime.drawPanelAccent(theme, innerX, innerY, innerW,
      theme.radii.lg, 3)

    local compactLandscape = h < 480 and w > h

    -- =====================================================================
    -- FIX 2: EXACTLY 170 PIXELS WIDE
    -- If Pokémon names truncate, slightly lower FONT SCALE in UI Settings!
    -- =====================================================================
    local cardW = 170

    local enemyX = innerX + spacing.xl + 8
    local enemyY = innerY + spacing.xl + 8
    local playerX = innerX + innerW - cardW - spacing.xl - 8
    local playerY = innerY + arenaH * 0.52

    local experience = battleRuntime.overlayValue(source, overlays,
      { "experience", "expBar", "experienceBar" })

    if battleRuntime.battlerVisible(source, "enemy") then
      runtime.drawBattle2dCard(game, theme, source.enemy,
        enemyX + shakeX + enemyShakeX, enemyY + shakeY, cardW, {
          caught = battleRuntime.caughtValue(source, overlays),
          typeText = battleRuntime.typeText(game, source.enemy),
          rateText = battleRuntime.catchRateText(source, overlays),
          compact = compactLandscape,
        })
    elseif native.showEnemyBalls and native.enemyParty then
      battleRuntime.drawPartyStatus(theme, native.enemyParty,
        enemyX + shakeX + enemyShakeX, enemyY + shakeY,
        cardW, "FOE PARTY")
    end

    if not options.hidePlayerCard
        and battleRuntime.battlerVisible(source, "player") then
      runtime.drawBattle2dCard(game, theme, source.player,
        playerX + shakeX, playerY + shakeY, cardW, {
          typeText = battleRuntime.typeText(game, source.player),
          experience = experience,
          compact = compactLandscape,
        })
    end

    if battleRuntime.childOpen(game, native) then
      love.graphics.pop()
      return
    end

    local isMove = phase == "moveSelect" or phase == "mimicSelect"

    local topState = game.stack and game.stack.top and game.stack:top()
    local isTop = (topState == state or topState == native)

    if isTop then
        if isMove then
          local panelW = math.min(innerW,
            math.max(620, math.min(980, innerW * 0.68)))
          local moves = phase == "mimicSelect" and source.mimicMoves
            or source.moves or source.player and source.player.curMoves or {}
          local probeH = battleRuntime.movePanelHeight(theme,
            type(moves) == "table" and #moves or 0)
          local panelX = x + (w - panelW) / 2 + shakeX
          local panelY = y + h - inset - probeH + shakeY
          runtime.drawBattle2dMoves(game, source, theme,
            panelX, panelY, panelW)
        elseif phase == "menu" then
          local panelW = math.min(innerW,
            math.max(460, math.min(720, innerW * 0.48)))
          local probeH = battleRuntime.commandPanelHeight(theme)
          local panelX = x + (w - panelW) / 2 + shakeX
          local panelY = y + h - inset - probeH + shakeY
          runtime.drawBattle2dCommands(game, source, theme,
            panelX, panelY, panelW)
        else
          local message = runtime.battleMessage(source)

          -- =====================================================================
          -- FIX 3: THE INTRO TEXT KILLER
          -- Delete the sticky fallback text as soon as a real message appears!
          -- =====================================================================
          if source and type(source) == "table" then
              if message ~= "" and message ~= source.introText then
                  source.introText = nil
              end
          end

          -- Refresh message in case we just killed the fallback
          message = runtime.battleMessage(source)

          if message ~= "" then
            runtime.drawBattle2dMessage(theme, message,
              innerX + shakeX, innerY + shakeY, innerW, innerH,
              source.msgWaiting or source.msgPrompt)
          end
        end
    end
    love.graphics.pop()
  end

  runtime.drawBattleHud = function(game, state, viewport, theme, model, mode)
    -- FIX 1: NEUTRALIZE FORCED OPACITY
    battleRuntime.opaque = function(color) return color end

    local top = battleRuntime.topState(game)
    if battleRuntime.isLevelUpState(game, top) then
      runtime.drawBattle2dHud(game, state, viewport, theme, model, {
        hidePlayerCard = true,
      })
      runtime.drawBattleLevelUp(game, state, viewport, theme, model)
      return
    end
    if mode == "full" then
      return runtime.drawBattle2dHud(game, state, viewport, theme, model)
    end
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local source, overlays = battleRuntime.dataSource(game, state, model)
    local native = battleRuntime.inputState(source) or state
    local phase = source.phase or native.phase
    local voxel = mode == "hud"
    local shortLandscape = h < 480 and w > h
    local inset = math.max(spacing.md, math.floor(math.min(w, h) * 0.018))

    -- FIX 2: EXACTLY 170 PIXELS WIDE
    local cardW = 170

    local experience = battleRuntime.overlayValue(source, overlays,
      { "experience", "expBar", "experienceBar" })
    local enemyCardH = math.min(184, math.max(112, h * 0.22))
    local playerCardH = math.min(196, math.max(112,
      h * (voxel and 0.20 or 0.24)))
    local enemyX, enemyY = x + spacing.xl + 8, y + h * 0.04
    local playerX = x + w - cardW - spacing.xl - 8

    local isMove = phase == "moveSelect" or phase == "mimicSelect"
    local playerY = shortLandscape and enemyY
      or y + h * (voxel and 0.52 or 0.43)
    local panelH = isMove
      and math.min(h - inset * 2, math.max(190, math.min(280, h * 0.34)))
      or math.min(h - inset * 2, math.max(132, math.min(230, h * 0.30)))
    local panelY = y + h - inset - panelH
    local panelX, panelW = x + w * 0.11, w * 0.78

    local message = runtime.battleMessage(source)

    -- FIX 3: THE INTRO TEXT KILLER
    if source and type(source) == "table" then
        if message ~= "" and message ~= source.introText then
            source.introText = nil
        end
    end

    -- Refresh message in case we just killed the fallback
    message = runtime.battleMessage(source)

    local canPresentAction = phase == "menu" or isMove
      or (message ~= nil and message ~= "")

    love.graphics.push("all")
    love.graphics.origin()

    if mode == "full" then
      runtime.drawPanelFrame(theme, x + inset, y + inset,
        w - inset * 2, h - inset * 2, theme.radii.lg, false)
      runtime.drawPanelAccent(theme, x + inset, y + inset,
        w - inset * 2, theme.radii.lg, 3)
    end

    if battleRuntime.battlerVisible(source, "enemy") then
      runtime.drawBattleCard(game, theme, source.enemy, enemyX, enemyY,
        cardW, enemyCardH, true, nil, {
          caught = battleRuntime.caughtValue(source, overlays),
        })
    end
    if battleRuntime.battlerVisible(source, "player") then
      runtime.drawBattleCard(game, theme, source.player, playerX, playerY,
        cardW, playerCardH, true, nil, { experience = experience })
    end

    if canPresentAction then
      battleRuntime.drawCleanup(theme, x, panelY - spacing.sm,
        w, y + h - panelY + spacing.sm)

      local topState = game.stack and game.stack.top and game.stack:top()
      local isTop = (topState == state or topState == native)

      if isTop then
          if isMove then
            local gap = spacing.sm
            local detailsX = x + inset
            local detailsW = math.min(w * 0.40, 430)
            local actionX = detailsX + detailsW + gap
            local actionW = x + w - inset - actionX
            runtime.drawBattleMoveDetails(game, source, theme,
              detailsX, panelY, detailsW, panelH)
            runtime.drawBattleActionPanel(game, source, theme,
              actionX, panelY, actionW, panelH)
          else
            runtime.drawBattleActionPanel(game, source, theme,
              panelX, panelY, panelW, panelH)
          end

          if message ~= "" then
            battleRuntime.drawExtras(theme, source, overlays,
              x + inset, y + h * 0.26, math.min(cardW, w * 0.46),
              math.max(36, h * 0.15), true, true)
          end
      end
    end
    love.graphics.pop()
  end

  runtime.drawBattle = function(game, state, viewport, theme)
    local nativeState = state
    local model = battleRuntime.sourceModel(game, state)
    if model then
      -- Pointer selection and semantic button taps must still mutate the
      -- source-owned BattleState, never the read-only normalized model copy.
      model._gen1ModernBattleState = nativeState
      setmetatable(model, { __index = state })
      state = model
    end
    -- The internal `full` value now means the larger 2D FRAMED composition,
    -- not ownership of the battlefield canvas. `hud` selects the tighter
    -- SCENE HUD placement. Both
    -- preserve the same live source draw and all of its animations.
    local mode = battleRuntime.presentationMode(state, model)
    runtime.drawBattleHud(game, state, viewport, theme, model, mode)
  end

  -- Remove only the standard or wide 2D HUD rectangles from the native battle
  -- surface before it is scaled/composited. The arena pictures and animation
  -- layer remain untouched. This is substantially safer than covering broad
  -- screen-space bands and lets the modern cards be genuinely content-sized.
  function battleRuntime.scrubNativeUi(game, ctx, layers, renderer)
    if runtime.option("battleUiWip", false) ~= true then return false end
    if not (game and ctx and ctx.uiCanvas and type(layers) == "table") then
      return false
    end
    local battleState
    for _, layer in ipairs(layers) do
      if layer.kind == "battle" then battleState = layer.state break end
    end
    if not battleState then return false end
    local model = battleRuntime.sourceModel(game, battleState)
    if model then
      model._gen1ModernBattleState = battleState
      if getmetatable(model) == nil then
        setmetatable(model, { __index = battleState })
      end
    end
    local source = model or battleState
    local top = battleRuntime.topState(game)
    local levelUp = battleRuntime.isLevelUpState(game, top)
    if battleRuntime.presentationMode(battleState, model) ~= "full"
        and not levelUp then
      return false
    end
    local canvasW, canvasH = ctx.uiCanvas:getDimensions()
    local wide = runtime.battleUsesWideLayout(battleState)
    local nativeW = wide and 304 or 160
    if canvasW < nativeW or canvasH < 144 then return false end
    local offsetX = math.floor((canvasW - nativeW) / 2)
    local native = battleState
    local childOpen = top ~= nil and top ~= native

    -- New classic BattleState instances are isolated before drawing: their
    -- scene, sprites, flashes, and animation layer reach this canvas, while
    -- drawHUDs/drawTextArea are already absent. Never paint over that scene.
    -- On old hosts the rectangle scrub below remains the safe fallback.
    if battleState._gen1ModernBattleSceneIsolation and not wide
        and battleRuntime.ownsClassicSurface(battleState)
        and (not childOpen or runtime.renderVisibleHookSeen) then
      return true
    end

    love.graphics.push("all")
    love.graphics.setCanvas(ctx.uiCanvas)
    love.graphics.origin()
    local transparentWorld = battleRuntime.ownsWorldSurface(battleState)
    local worldDim = transparentWorld
      and clamp(tonumber(renderer and renderer.battleDim) or 0, 0, 1) or 0
    local worldSceneX, worldSceneY, worldSceneW, worldSceneH
    local worldSceneLeft, worldSceneRight
    local function setWorldOutsidePaint()
      love.graphics.setColor(0, 0, 0, worldDim)
    end
    if transparentWorld then
      -- Replace, rather than alpha-blend, these exact native HUD rectangles
      -- with transparent pixels. This exposes the already-rendered WORLD
      -- canvas without treating legitimate white pixels in battle sprites as
      -- a color key.
      love.graphics.setBlendMode("replace")
      love.graphics.setColor(0, 0, 0, 0)
      -- Remove every source pixel outside the same native arena rectangle
      -- used by the WORLD draw decorator. This catches retained canvas pixels
      -- and animated effects that would otherwise remain active in the bright
      -- side gutters beyond the modern frame.
      worldSceneX, worldSceneY, worldSceneW, worldSceneH =
        battleRuntime.worldSceneRect(battleState)
      worldSceneLeft = offsetX + worldSceneX
      worldSceneRight = worldSceneLeft + worldSceneW
      love.graphics.rectangle("fill", 0, 0, worldSceneLeft, canvasH)
      love.graphics.rectangle("fill", worldSceneRight, 0,
        math.max(0, canvasW - worldSceneRight), canvasH)
      love.graphics.rectangle("fill", worldSceneLeft, 0,
        worldSceneW, worldSceneY)
      love.graphics.rectangle("fill", worldSceneLeft,
        worldSceneY + worldSceneH, worldSceneW,
        math.max(0, canvasH - worldSceneY - worldSceneH))
      -- Renderer dims the overworld outside its complete native UI viewport.
      -- Reapply that same veil to our now-transparent inner gutters so the
      -- old viewport cannot survive as a conspicuously brighter rectangle.
      if worldDim > 0 then
        setWorldOutsidePaint()
        love.graphics.rectangle("fill", 0, 0, worldSceneLeft, canvasH)
        love.graphics.rectangle("fill", worldSceneRight, 0,
          math.max(0, canvasW - worldSceneRight), canvasH)
        love.graphics.rectangle("fill", worldSceneLeft, 0,
          worldSceneW, worldSceneY)
        love.graphics.rectangle("fill", worldSceneLeft,
          worldSceneY + worldSceneH, worldSceneW,
          math.max(0, canvasH - worldSceneY - worldSceneH))
      end
    else
      love.graphics.setColor(1, 1, 1, 1)
    end
    if childOpen and not levelUp
        and (not top or not top._gen1ModernBattleChildNativeDraw) then
      -- If this host never passed the child through ui.state.decorate, there
      -- is no reliable way to recover the battle pixels after a centred
      -- classic child overwrites them. Keep the WORLD outside dimmed and
      -- restore only the framed arena paper instead of filling the entire
      -- canvas with that dim color.
      if transparentWorld then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setScissor(worldSceneLeft, worldSceneY,
          worldSceneW, worldSceneH)
        love.graphics.rectangle("fill", worldSceneLeft, worldSceneY,
          worldSceneW, worldSceneH)
        love.graphics.setScissor()
      else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, canvasW, canvasH)
      end
      love.graphics.pop()
      return true
    end
    if transparentWorld then
      -- The native HP boxes live inside the arena. Erase their text and bars
      -- back to battle paper, not transparency, so no map-shaped holes remain
      -- around the modern content-sized status ribbons.
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setScissor(worldSceneLeft, worldSceneY,
        worldSceneW, worldSceneH)
    end
    if battleRuntime.battlerVisible(source, "enemy") then
      love.graphics.rectangle("fill", offsetX, 0,
        wide and 132 or 90, wide and 36 or 32)
    end
    if battleRuntime.battlerVisible(source, "player") then
      love.graphics.rectangle("fill", offsetX + (wide and 180 or 72),
        wide and 52 or 56, wide and 124 or 88, wide and 48 or 40)
    end
    if levelUp then
      -- StatBox is a battle child. Remove its native stat window while
      -- leaving the live battle scene and all source-owned animations intact;
      -- drawBattleLevelUp paints the modern card after this scrub.
      love.graphics.rectangle("fill", offsetX + 72, 16, 88, 80)
    end
    if transparentWorld then love.graphics.setScissor() end
    local phase = source.phase or native.phase
    local isMove = phase == "moveSelect" or phase == "mimicSelect"
    local message = runtime.battleMessage(source)
    if childOpen or phase == "menu" or isMove or message ~= "" then
      if transparentWorld then setWorldOutsidePaint() end
      love.graphics.rectangle("fill", offsetX, wide and 104 or 96,
        nativeW, wide and 40 or 48)
    end
    if isMove and not wide then
      if transparentWorld then love.graphics.setColor(1, 1, 1, 1) end
      love.graphics.rectangle("fill", offsetX, 56, 92, 48)
    end
    love.graphics.pop()
    return true
  end

  -- LinkState owns networking and input, but its released renderer is a
  -- small native 160x144 canvas. Present its public stages as ordinary modern
  -- rows while leaving every transition/callback in LinkState untouched.
  runtime.drawLink = function(game, state, viewport, theme)
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

    local layout = runtime.layoutFor(viewport, theme, "link", rows, Strings(title), footer)
    selected = clamp(selected, 1, #rows)
    local scroll = 0
    love.graphics.push("all")
    love.graphics.origin()
    if not layout.sidePanel then runtime.drawPresenterBackdrop(theme, viewport) end
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h,
      layout.radius)
    runtime.drawHeader(theme, layout, Strings(title))
    runtime.drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2,
      runtime.themeMetric(theme, "divider", 1))
    setColor(theme.colors.textMuted)
    runtime.drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + theme.spacing.sm,
      layout.w - theme.spacing.lg * 2)
    love.graphics.pop()
  end

  runtime.drawModern = function(game, state, kind, viewport, theme, asModal, underKind,
      underState, overKind, overState)
    if not runtime.presenterEnabled(kind, state) then return end
    if kind == "text" or kind == "choice" or kind == "quantity"
        or (asModal and underKind == "text") then
      theme = runtime.dialogueTheme(theme)
    end
    if kind == "text" then
      runtime.drawDialogue(state, viewport, theme, game, overKind, overState)
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
    if kind == "dex_radar" then
      mod._gen1ModernSpecialPresenters.drawDexRadar(
        game, state, viewport, theme)
      return
    end
    if asModal or kind == "choice" or kind == "quantity" then
      runtime.drawModalRows(game, state, kind, viewport, theme, underKind, underState)
      return
    end
    if kind == "battle" then
      runtime.drawBattle(game, state, viewport, theme)
      return
    end
    if kind == "link" then
      runtime.drawLink(game, state, viewport, theme)
      return
    end
    if kind == "mod_manager" then
      runtime.drawManager(game, state, viewport, theme)
      return
    end
    local minimal = runtime.option("minimalUi", false) == true
    local forceGeneric = minimal and kind == "pokedex"
    if kind == "gen3_box" then
      runtime.drawGen3Box(game, state, viewport, theme)
      return
    end
    if kind == "dex_entry" then
      runtime.drawDexEntry(game, state, viewport, theme)
      return
    end
    if kind == "summary" then
      runtime.drawSummary(game, state, viewport, theme)
      return
    end
    if kind == "trainer_card" then
      runtime.drawTrainerCard(game, state, viewport, theme)
      return
    end
    if kind == "party" then
      runtime.drawParty(game, state, viewport, theme)
      return
    end
    if kind == "box_mon_list" then
      runtime.drawBoxPokemonList(game, state, viewport, theme)
      return
    end
    if kind == "pokedex" and not forceGeneric then
      runtime.drawPokedex(game, state, viewport, theme)
      return
    end
    if kind == "bag" and not forceGeneric then
      runtime.drawBag(game, state, viewport, theme)
      return
    end
    if (kind == "shop_list" or kind == "pc_list") and not forceGeneric then
      runtime.drawContextList(game, state, kind, viewport, theme)
      return
    end
    local rows, selected, scroll, title, footerText = runtime.rowsFor(game, state, kind)
    if not rows then return end
    local layout = runtime.layoutFor(viewport, theme, kind, rows, title, footerText)
    scroll = clamp(scroll, 0, math.max(0, #rows - layout.visible))
    selected = clamp(selected, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visible then scroll = selected - layout.visible end

    love.graphics.push("all")
    love.graphics.origin()
    if not layout.sidePanel then runtime.drawPresenterBackdrop(theme, viewport) end
    local surface = theme.colors.surface
    if layout.sidePanel then
      surface = { surface[1], surface[2], surface[3], math.min(surface[4] or 1, 0.96) }
    end
    setColor(surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, layout.radius)
    runtime.drawHeader(theme, layout, title)
    runtime.drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2, 1)
    setColor(theme.colors.textMuted)
    local footer = layout.sidePanel and "A  select   B  back" or footerText or
      (kind == "choice" and "A  choose    B  cancel"
      or kind == "quantity" and "A  confirm    B  cancel"
      or "Arrow keys / A  select    B  back")
    runtime.drawHintIfUseful(theme, Strings(footer), layout.x + theme.spacing.lg,
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
  runtime.isModalLayer = function(kind)
    return kind == "menu" or kind == "list" or kind == "choice"
      or kind == "quantity" or kind == "text" or kind == "pic_box"
  end

  -- A/B are available globally through the mouse buttons, but a few screens
  -- expose meaningful controls that cannot be represented by row clicks.
  -- Surface only those extras, and leave mobile's native TouchControls alone:
  -- they receive pointer first refusal and already provide the full pad.
  runtime.pointerControlsFor = function(kind, state)
    if not state then return {} end
    local actions, seen = {}, {}
    local function add(action)
      if not seen[action] then
        actions[#actions + 1] = action
        seen[action] = true
      end
    end

    if kind == "external" then
      local context = mod._gen1ModernCompatibility.active[state]
      local externalActions = context and context.screen.actions or {}
      for _, action in ipairs({ "up", "down", "left", "right", "select", "back", "start" }) do
        if type(externalActions[action]) == "function" then add(action) end
      end
    elseif kind == "mod_manager" then
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
    elseif kind == "bag"
        and mod._gen1ModernCompatibility:bagHasPockets(state) then
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
    elseif kind == "dex_radar" then
      add("up"); add("down"); add("left"); add("right")
    elseif kind == "battle" then
      -- Battle cells register their own hover/click regions. Keep the dock
      -- available for phases such as message waits, move selection, and
      -- source-owned battle states that do not expose every cell visually.
      add("up"); add("down"); add("left"); add("right"); add("select")
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
    elseif kind == "bag"
        and mod._gen1ModernCompatibility:bagHasPockets(state) then
      if action == "left" then return "< POCKET" end
      if action == "right" then return "POCKET >" end
    end
    if state.pageJump then
      if action == "left" then return "< PAGE" end
      if action == "right" then return "PAGE >" end
    end
    return POINTER_CONTROL_LABEL[action] or action:upper()
  end

  runtime.drawPointerControls = function(theme, context)
    if runtime.option("pointerUi", false) ~= true or not context
        or not context.primaryPanel
        or (context.viewport and context.viewport._gen1TouchVisible) then
      return
    end
    local actions = runtime.pointerControlsFor(context.kind, context.state)
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
      runtime.registerPointerRegion(x, dockY, width, buttonH, {
        action = context.kind == "external" and nil or action,
        adapterAction = context.kind == "external" and action or nil,
        activate = true, interactive = true,
        controlKey = controlKey, dragHandle = false,
      })
      x = x + width + gap
    end
  end

  runtime.drawModernStack = function(game, layers, viewport)
    local topState = layers[#layers] and layers[#layers].state or nil
    local theme = responsiveTheme(runtime.currentTheme(viewport, topState), viewport,
      responsiveThemeCache)
    pointerRuntime.generation = pointerRuntime.generation + 1
    pointerRegions = {}
    pointerRuntime.topOrder = #layers
    local nextTopState = topState
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
      local modal = index > 1 and runtime.isModalLayer(layer.kind)
      if modal and not modalActive then runtime.drawModalScrim(theme, viewport) end
      modalActive = modal
      local offsetX, offsetY = runtime.layerOffset(layer.kind, viewport)
      local layerViewport = shiftedViewport(viewport, offsetX, offsetY)
      pointerDrawContext = {
        kind = layer.kind, state = layer.state,
        layerKey = safeText(layer.kind or "screen") .. ":" .. index,
        viewport = layerViewport, baseViewport = viewport, order = index,
      }
      runtime.drawModern(game, layer.state, layer.kind, layerViewport, theme,
        modal, underKind, underState,
        overKind, overState)
      if index == #layers then
        runtime.drawPointerControls(theme, pointerDrawContext)
      end
      pointerDrawContext = nil
    end
    pointerDrawContext = nil
    love.graphics.pop()
  end

  runtime.pointerInputReady = function()
    return mod.input and type(mod.input.tap) == "function"
  end

  runtime.pointerContains = function(region, x, y)
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

  runtime.pointerHit = function(x, y)
    -- Regions are appended in draw order. Only the active/top layer may own
    -- hover or click; visible parents underneath a modal remain context, not
    -- live hit targets. Reverse iteration still gives controls and rows first
    -- refusal over their panel's drag surface.
    for index = #pointerRegions, 1, -1 do
      local region = pointerRegions[index]
      if runtime.pointerContains(region, x, y)
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
      if runtime.pointerContains(region, x, y)
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

  runtime.pointerSelectionField = function(region)
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

  runtime.setPointerSelection = function(region, desiredIndex, game)
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
    local field = runtime.pointerSelectionField(region)
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

  runtime.updatePointerHover = function(region, game)
    if region and not pointerRuntime.regionAlive(game or currentGame, region) then
      region = nil
    end
    local previous = hoveredPointer
    hoveredPointer = region
    if region and region.interactive ~= false and region.kind == "external"
        and region.adapterIndex ~= nil and region.adapterHover
        and (not previous or pointerRuntime.targetKey(previous)
          ~= pointerRuntime.targetKey(region)) then
      mod._gen1ModernCompatibility:action(game or currentGame,
        region.state, region.adapterHover, region.adapterIndex)
    elseif region and region.interactive ~= false
        and (region.rowIndex ~= nil or region.selectionField ~= nil
          or region.namingRow ~= nil
          or (region.gridRow ~= nil and region.gridCol ~= nil)) then
      -- Hovering a row is the mouse equivalent of moving the native cursor.
      -- Selection remains owned by the live state, so the next draw naturally
      -- paints the same highlight used by keyboard/controller navigation.
      runtime.setPointerSelection(region, nil, game)
    end
  end

  runtime.pointerScroll = function(region, normalizedScroll)
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
      local field = runtime.pointerSelectionField(region)
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

  runtime.tapGameButton = function(game, button)
    local ok, result = pcall(mod.input.tap, mod.input, game, button)
    return ok and result ~= false
  end

  runtime.tapPointerAction = function(game, region)
    if not region or not pointerRuntime.regionAlive(game, region) then return false end
    if region.pointerCommand == "dismiss_help" then
      if region.state and region.state._gen1OptionDescription then
        region.state._gen1OptionDescription = nil
        return true
      end
      return false
    end
    if region.adapterAction then
      return mod._gen1ModernCompatibility:action(game, region.state,
        region.adapterAction, region.adapterIndex)
    end
    if region.action then return runtime.tapGameButton(game, region.action) end
    local hasSelection = region.rowIndex ~= nil or region.selectionField ~= nil
      or region.namingRow ~= nil
      or (region.gridRow ~= nil and region.gridCol ~= nil)
    local selected = not hasSelection or runtime.setPointerSelection(region, nil, game)
    if not selected then return false end
    local canActivate = region.activate == true or region.rowIndex ~= nil
      or region.namingRow ~= nil
      or (region.gridRow ~= nil and region.gridCol ~= nil)
      or region.kind == "text" or region.kind == "quantity"
    if not canActivate then return false end
    return runtime.tapGameButton(game, "a")
  end

  runtime.pointerCaptureKey = function(pointer)
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
    local key = runtime.pointerCaptureKey(pointer)
    if runtime.option("pointerUi", false) ~= true or not runtime.pointerInputReady() then
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
        or runtime.pointerHit(pointer.x, pointer.y)
      local insideUi = pointerRuntime.insideUi(pointer.x, pointer.y)
      local blocked = mouseAction ~= "b" and not region and insideUi
      if not region and not mouseAction and not blocked then
        if pointer.source == "mouse" then runtime.updatePointerHover(nil, game) end
        return next(game, pointer)
      end
      if region then runtime.setPointerSelection(region, nil, game) end
      local startX = tonumber(pointer.x) or (region and region.x) or 0
      local startY = tonumber(pointer.y) or (region and region.y) or 0
      pointerCaptures[key] = {
        region = region,
        targetKey = pointerRuntime.targetKey(region),
        buttonAction = blocked and nil or mouseAction,
        blocked = blocked,
        startX = startX,
        startY = startY,
        offsetX = region and select(1, runtime.layerOffset(region.kind, region.viewport)) or 0,
        offsetY = region and select(2, runtime.layerOffset(region.kind, region.viewport)) or 0,
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
        runtime.updatePointerHover(runtime.pointerHit(pointer.x, pointer.y), game)
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
          runtime.pointerScroll(region, capture.scrollStart
            + (totalY < 0 and rows or -rows))
        end
        return true
      end

      local panelDrag = region.dragHandle == true
      if runtime.option("dragPanels", false) == true and panelDrag
          and (math.abs(totalX) >= threshold or math.abs(totalY) >= threshold) then
        capture.moved = true
        capture.panelMoved = true
        capture.offsetX, capture.offsetY = runtime.rememberLayerOffset(
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
          local releasedOver = runtime.pointerHit(x, y)
          if pointerRuntime.sameTarget(capture.region, releasedOver) then
            runtime.tapPointerAction(game, releasedOver)
          end
        elseif capture.buttonAction == "b" then
          runtime.tapGameButton(game, "b")
        elseif capture.buttonAction == "a"
            and not pointerRuntime.insideUi(x, y) then
          runtime.tapGameButton(game, "a")
        end
      end
      if capture.panelMoved and capture.region
          and pointerRuntime.regionAlive(game, capture.region) then
        runtime.rememberLayerOffset(capture.region.kind, capture.region.viewport,
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
      local keyOk, failedKey = pcall(runtime.pointerCaptureKey, pointer)
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
        if runtime.option("hideOriginalUi", true) ~= false
            and runtime.option("menuUi", true) ~= false then
          local stack = game and game.stack and game.stack.states
          local titleOnStack = false
          for _, visible in ipairs(type(stack) == "table" and stack or {}) do
            if runtime.isTitleState(visible) then titleOnStack = true break end
          end
          if titleOnStack then
            local layers, complete = runtime.presentationStack(game)
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
    if runtime.option("battleUiWip", false) ~= true then
      battleRuntime.restoreDecoratedState(decorated)
      return decorated
    end
    -- Some released hosts still draw an opaque Bag/Party child into the
    -- battle canvas even after screen.render_visible rejects it. Suppress a
    -- fully modeled child at its source while a framed battle is underneath;
    -- this avoids trying to erase a centred 160x144 child after it has already
    -- overwritten the live back/front sprites on the 304px WIDE surface.
    if type(decorated.draw) == "function"
        and runtime.kindFor(decorated, game) ~= "battle"
        and not decorated._gen1ModernBattleChildNativeDraw
        and not decorated._gen1ModernTitleMenu
        and not decorated._gen1ModernOptionsMenu then
      decorated._gen1ModernBattleChildNativeDraw = decorated.draw
      decorated._gen1ModernBattleChildDraw = function(self, ...)
        local activeGame = self.game or game or currentGame
        if runtime.option("battleUiWip", false) == true
            and runtime.option("hideOriginalUi", true) ~= false
            and battleRuntime.fullBattleInStack(activeGame)
            and runtime.canSuppressState(activeGame, self) then
          return
        end
        return self._gen1ModernBattleChildNativeDraw(self, ...)
      end
      decorated.draw = decorated._gen1ModernBattleChildDraw
    end
    -- Classic BattleState's public draw is already split into scene pictures,
    -- animation sprites, HUD, and text methods. Intercept only the latter two
    -- on the instance. The host still owns every timer, palette effect,
    -- send-out/capture/faint sequence, and source sprite draw, while native
    -- status/menu tiles can no longer flash through during HP animation.
    battleRuntime.decorateClassicScene(game, decorated)
    if runtime.kindFor(decorated, game) == "battle" then
      battleRuntime.decorateWideScenePlacement(decorated)
      battleRuntime.decorateWorldSurface(decorated)
    end
    return decorated
  end, 100)

  -- render.zones is the last state-aware render hook before endFrame.  Cache
  -- its Game reference so render.compose can inspect this exact frame's top
  -- state without requiring engine internals or relying on a previous frame.
  mod.hooks:wrap("render.zones", function(next, game, zones)
    currentGame = game
    if runtime.option("battleUiWip", false) ~= true then
      battleRuntime.restoreBattleDecorations(game)
    end
    return next(game, zones)
  end, 100)

  -- Preferred native suppression on newer hosts. The released fallback below
  -- still clears only uiCanvas for clients that do not expose this hook.
  -- Support both the current `(visibleByDefault, state)` signature and the
  -- early one-argument fixture used by development clients.
  mod.hooks:wrap("screen.render_visible", function(next, visible, state)
    runtime.renderVisibleHookSeen = true
    local oneArgument = state == nil and type(visible) == "table"
    if oneArgument then state, visible = visible, true end
    -- A newly-pushed state can belong to a different Game/stack than the
    -- render.zones cache from the previous frame (notably during New Game).
    -- Always trust the screen's own owner first so an Oak child is never
    -- suppressed using stale overworld evidence.
    local game = runtime.ownerGame(state, currentGame)
    if game and runtime.hasNativeNewGameFlow(game) then
      if oneArgument then return next(state) end
      return next(visible, state)
    end
    -- MOD MENUS is a manager-owned surface, not a generic game menu. Keep
    -- its replacement usable when Menu UI and Dialogue UI are disabled,
    -- while suppressing only the stock Menu instance created for it.
    local managedKind = game and state and runtime.kindFor(state, game)
    local isManagerSurface = state and (state._gen1ModMenus
      or managedKind == "mod_manager" or managedKind == "mod_options")
    local presenterKind = state and state._gen1ModMenus and "menu" or managedKind
    if game and isManagerSurface
        and runtime.option("hideOriginalUi", true) ~= false
        and runtime.presenterEnabled(presenterKind, state)
        and runtime.presenterReady(game, state, presenterKind) then
      return false
    end
    local complete, hidden = runtime.visibleSuppressionProof(game)
    if complete and hidden[state] then return false end
    if oneArgument then return next(state) end
    return next(visible, state)
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
    local layers, complete, suppressCanvas = runtime.presentationStack(game)
    local hide = runtime.option("hideOriginalUi", true) ~= false
    if handled ~= true and hide and complete and #layers > 0
        and love and love.graphics and ctx and ctx.uiCanvas then
      if suppressCanvas then
        love.graphics.push("all")
        love.graphics.setCanvas(ctx.uiCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.pop()
      else
        battleRuntime.scrubNativeUi(game, ctx, layers, renderer)
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
    spriteAnimationOn = runtime.option("spriteAnimation", true) ~= false
    local layers, complete = runtime.presentationStack(game)
    local topState = game and game.stack and game.stack.top
      and game.stack:top() or nil
    local modernWorld = runtime.option("menuUi", true) ~= false
      and runtime.option("hideOriginalUi", true) ~= false
    local overworldActive = game and game.overworld
      and topState == game.overworld
    local modernOwnsQolBanner = modernWorld
      and (overworldActive or (complete and #layers > 0))
    mod._gen1ModernSpecialPresenters.syncQolLocationOverlay(
      game, modernOwnsQolBanner)
    if complete and #layers > 0 then
      runtime.drawModernStack(game, layers, viewportForTouchControls(game, viewport))
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
            responsiveTheme(runtime.currentTheme(viewport, nil), viewport,
            responsiveThemeCache))
      end
    end
  end, 100)
end

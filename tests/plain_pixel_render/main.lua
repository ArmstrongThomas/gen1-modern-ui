-- Visual probe for Plain Pixel's 11-row artwork and 15-point raster grid.
--
-- Run from the repository root:
--   $env:GEN1_PLAIN_PIXEL_FONT =
--     'G:\dev\misc\gen1recomp\assets\fonts\plainpixel\PlainPixel-Regular.ttf'
--   & 'C:\Program Files\LOVE\lovec.exe' tests/plain_pixel_render

local function fail(message)
  error("Plain Pixel render test: " .. tostring(message), 0)
end

local function check(value, message)
  if not value then fail(message) end
end

local PLAIN_PIXEL_CELL_HEIGHT = 11
local PLAIN_PIXEL_RASTER_STEP = 15
local PLAIN_PIXEL_SCALES = { 1, 2, 3, 4 }
local EPSILON = 0.0001

-- Keep the probe source-encoding independent. These strings exercise the
-- Latin accent, Gen1 gender signs, Cyrillic, and Japanese coverage rendered
-- by the production font and its configured fallback path.
local REPRESENTATIVE_GLYPHS = {
  "Pok\195\169mon",
  "NIDORAN\226\153\128\226\153\130",
  "Espa\195\177ol",
  "\208\160\209\131\209\129\209\129\208\186\208\184\208\185",
  "\230\151\165\230\156\172\232\170\158",
}
local REPRESENTATIVE_FALLBACK_GLYPHS = {
  "\195\169", -- é
  "\195\177", -- ñ
}

local function snapCoordinate(value, dpi)
  return math.floor(value * dpi + 0.5) / dpi
end

local function assertSnappedCoordinate(value, dpi, label)
  local snapped = snapCoordinate(value, dpi)
  local physical = snapped * dpi
  check(math.abs(physical - math.floor(physical + 0.5)) < EPSILON,
    label .. " must land on a whole physical pixel")
  return snapped
end

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

function love.load()
  local source = os.getenv("GEN1_PLAIN_PIXEL_FONT")
  check(source and source ~= "", "GEN1_PLAIN_PIXEL_FONT is required")
  local input, openError = io.open(source, "rb")
  check(input, openError)
  local bytes = input:read("*a")
  input:close()
  check(bytes and #bytes > 0, "font file is empty")

  local staged = "plain_pixel_render_test.ttf"
  love.filesystem.remove(staged)
  local wrote, writeError = love.filesystem.write(staged, bytes)
  check(wrote, writeError)

  local canvas = love.graphics.newCanvas(1560, 1220)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.94, 0.94, 0.87, 1)
  local labelFont = love.graphics.newFont(14)
  local samples = {
    "LAYOUT  Pokémon  NIDORAN♀♂  1234",
    "Español  Русский  日本語",
  }
  local columns = {
    { label = "old / arbitrary raster", dpi = function() return 1 end },
    { label = "nearest authored raster", dpi = function(size)
        local native = math.max(PLAIN_PIXEL_RASTER_STEP,
          math.floor(size / PLAIN_PIXEL_RASTER_STEP + 0.5)
            * PLAIN_PIXEL_RASTER_STEP)
        return native / size, native
      end },
    { label = "production / direct authored raster", directRaster = true,
      dpi = function(size)
        local native = math.max(PLAIN_PIXEL_RASTER_STEP,
          math.floor(size / PLAIN_PIXEL_RASTER_STEP + 0.5)
            * PLAIN_PIXEL_RASTER_STEP)
        return 1, native
      end },
    { label = "system line-box reference", system = true,
      dpi = function() return 1 end },
  }
  local sizes = { 13, 17, 21, 24, 30 }
  local productionFonts = {}
  local previousLineBox
  local graphicsDpi = love.graphics.getDPIScale and love.graphics.getDPIScale() or 1
  check(type(graphicsDpi) == "number" and graphicsDpi > 0,
    "render DPI must be a positive number")

  for _, scale in ipairs(PLAIN_PIXEL_SCALES) do
    local native = PLAIN_PIXEL_RASTER_STEP * scale
    check(native / PLAIN_PIXEL_RASTER_STEP == scale,
      ("production %dx raster must be a whole authored step"):format(scale))
    local productionFont = love.graphics.newFont(staged, native, "mono", 1)
    productionFont:setFilter("nearest", "nearest", 0)
    local systemFont = love.graphics.newFont(native)
    local fallbackOk, fallbackError = pcall(
      productionFont.setFallbacks, productionFont, systemFont)
    check(fallbackOk, ("production %dx fallback setup failed: %s"):format(
      scale, tostring(fallbackError)))
    check(type(productionFont.getDPIScale) == "function",
      "production Font:getDPIScale is required")
    check(math.abs(productionFont:getDPIScale() - 1) < EPSILON,
      ("production %dx font must use direct authored DPI 1"):format(scale))
    check(type(productionFont.getHeight) == "function"
      and type(productionFont.getLineHeight) == "function",
      "production font line metrics are required")
    local height = productionFont:getHeight()
    local lineHeight = productionFont:getLineHeight()
    local lineBox = height * lineHeight
    check(height > 0 and lineHeight > 0 and lineBox >= height,
      ("production %dx font must expose positive line metrics"):format(scale))
    if previousLineBox then
      check(lineBox > previousLineBox,
        ("production %dx line box must grow with raster scale"):format(scale))
    end
    previousLineBox = lineBox
    for glyphIndex, glyphs in ipairs(REPRESENTATIVE_FALLBACK_GLYPHS) do
      check(systemFont:hasGlyphs(glyphs),
        ("system fallback glyph set %d is missing for production %dx"):format(
          glyphIndex, scale))
      check(productionFont:hasGlyphs(glyphs),
        ("production %dx fallback glyph set %d is unavailable"):format(
          scale, glyphIndex))
    end
    productionFonts[scale] = {
      font = productionFont, raster = native, height = height,
      lineHeight = lineHeight, lineBox = lineBox,
    }
  end

  for index, rawCoordinate in ipairs({ 0.1, 0.49, 0.5, 1.25, 15.75 }) do
    assertSnappedCoordinate(rawCoordinate, graphicsDpi,
      ("render coordinate %d"):format(index))
  end

  love.graphics.setColor(0.08, 0.09, 0.07, 1)
  love.graphics.setFont(love.graphics.newFont(22))
  love.graphics.print("PLAIN PIXEL RASTERIZATION PROBE", 24, 18)
  for column, spec in ipairs(columns) do
    local x = 24 + (column - 1) * 380
    love.graphics.setFont(labelFont)
    love.graphics.print(spec.label, x, 62)
  end

  local y = 100
  for _, size in ipairs(sizes) do
    for column, spec in ipairs(columns) do
      local x = 24 + (column - 1) * 380
      local dpi, native = spec.dpi(size)
      local font = spec.system and love.graphics.newFont(size)
        or (spec.directRaster and love.graphics.newFont(staged, native,
          "mono", 1))
        or love.graphics.newFont(staged, size, "mono", dpi)
      font:setFilter("nearest", "nearest", 0)
      local systemFont = love.graphics.newFont(size)
      if spec.directRaster then
        local fallbackOk, fallbackError = pcall(
          font.setFallbacks, font, systemFont)
        check(fallbackOk, "system fallback failed: " .. tostring(fallbackError))
        for glyphIndex, glyphs in ipairs(REPRESENTATIVE_FALLBACK_GLYPHS) do
          check(systemFont:hasGlyphs(glyphs),
            ("direct raster fallback glyph set %d is missing"):format(
              glyphIndex))
        end
        check(font:hasGlyphs("Pokémon Español Русский 日本語"),
          "production font must retain representative multilingual glyphs")
      end
      if not spec.system and native then
        check(type(font.getDPIScale) == "function",
          "Font:getDPIScale is required for the raster contract")
        local expectedDpi = spec.directRaster and 1 or native / size
        check(math.abs(font:getDPIScale() - expectedDpi) < 0.01,
          "Plain Pixel raster must use the expected DPI contract")
        check(native % PLAIN_PIXEL_RASTER_STEP == 0,
          "Plain Pixel raster must be a multiple of the authored step")
      end
      local lineHeight = font:getLineHeight()
      local lineBox = font:getHeight() * lineHeight
      check(font:getHeight() > 0 and lineHeight > 0 and lineBox >= font:getHeight(),
        "every probe font must expose explicit positive line metrics")
      love.graphics.setFont(labelFont)
      love.graphics.setColor(0.30, 0.31, 0.27, 1)
      love.graphics.print(("cell %d / logical %d / raster %s / h %.1f / line %.1f"):format(
        PLAIN_PIXEL_CELL_HEIGHT, size, tostring(native or size),
        font:getHeight(), lineBox), x, y)
      love.graphics.setColor(0.08, 0.09, 0.07, 1)
      love.graphics.setFont(font)
      for lineIndex, sample in ipairs(samples) do
        love.graphics.print(sample, x,
          y + 24 + (lineIndex - 1) * lineBox)
      end
      love.graphics.setColor(0.55, 0.56, 0.49, 1)
      love.graphics.line(x, y + 24 + lineBox * #samples, x + 350,
        y + 24 + lineBox * #samples)
    end
    y = y + 160
  end

  -- Production uses direct authored rasters at whole-number 1x-4x steps.
  -- Draw at deliberately fractional logical coordinates, then snap to the
  -- physical render grid just like the presenter does for Plain Pixel text.
  local productionY = 900
  love.graphics.setFont(labelFont)
  love.graphics.setColor(0.30, 0.31, 0.27, 1)
  love.graphics.print("production authored raster / snapped coordinates",
    24, productionY - 28)
  for index, scale in ipairs(PLAIN_PIXEL_SCALES) do
    local metrics = productionFonts[scale]
    local rawX = 24.25 + (index - 1) * 380
    local rawY = productionY + 0.375
    local x = assertSnappedCoordinate(rawX, graphicsDpi,
      ("production %dx x coordinate"):format(scale))
    local y = assertSnappedCoordinate(rawY, graphicsDpi,
      ("production %dx y coordinate"):format(scale))
    love.graphics.setFont(labelFont)
    love.graphics.setColor(0.30, 0.31, 0.27, 1)
    love.graphics.print(("%dx  raster %d  h %.1f  line %.1f"):format(
      scale, metrics.raster, metrics.height, metrics.lineBox), x, y)
    love.graphics.setFont(metrics.font)
    love.graphics.setColor(0.08, 0.09, 0.07, 1)
    for lineIndex, sample in ipairs(samples) do
      love.graphics.print(sample, x,
        y + 24 + (lineIndex - 1) * metrics.lineBox)
    end
    love.graphics.setColor(0.55, 0.56, 0.49, 1)
    love.graphics.line(x, y + 24 + metrics.lineBox * #samples,
      x + 350, y + 24 + metrics.lineBox * #samples)
  end
  love.graphics.setCanvas()
  canvas:newImageData():encode("png", "plain_pixel_render_probe.png")
  print("Plain Pixel probe: " .. love.filesystem.getSaveDirectory()
    .. "/plain_pixel_render_probe.png")
  love.filesystem.remove(staged)
  love.event.quit(0)
end

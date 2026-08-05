-- Visual probe for Plain Pixel's 15-point raster grid.
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

  local canvas = love.graphics.newCanvas(1560, 940)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.94, 0.94, 0.87, 1)
  local labelFont = love.graphics.newFont(14)
  local samples = {
    "LAYOUT  Pokémon  NIDORAN♀♂  1234",
    "Español  Русский  日本語",
  }
  local columns = {
    { label = "old / arbitrary raster", dpi = function() return 1 end },
    { label = "nearest 15pt raster", dpi = function(size)
        local native = math.max(15, math.floor(size / 15 + 0.5) * 15)
        return native / size, native
      end },
    { label = "production / normalized lines", normalize = true,
      dpi = function(size)
        local native = math.max(15, math.floor(size / 15 + 0.5) * 15)
        return native / size, native
      end },
    { label = "system line-box reference", system = true,
      dpi = function() return 1 end },
  }
  local sizes = { 13, 17, 21, 24, 30 }

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
        or love.graphics.newFont(staged, size, "mono", dpi)
      font:setFilter("nearest", "nearest", 0)
      local systemFont = love.graphics.newFont(size)
      if spec.normalize then
        local fallbackOk, fallbackError = pcall(
          font.setFallbacks, font, systemFont)
        check(fallbackOk, "system fallback failed: " .. tostring(fallbackError))
        font:setLineHeight(systemFont:getHeight() / font:getHeight())
        check(math.abs(font:getHeight() * font:getLineHeight()
          - systemFont:getHeight()) < 0.01,
          "normalized line box must match the system font")
        check(font:hasGlyphs("Pokémon Español Русский 日本語"),
          "production font must retain representative multilingual glyphs")
      end
      if not spec.system and native then
        check(type(font.getDPIScale) == "function",
          "Font:getDPIScale is required for the raster contract")
        check(math.abs(size * font:getDPIScale() - native) < 0.01,
          "physical Plain Pixel raster must align to 15 pixels")
        check(native % 15 == 0,
          "Plain Pixel raster must be a multiple of 15")
      end
      local lineBox = font:getHeight() * font:getLineHeight()
      love.graphics.setFont(labelFont)
      love.graphics.setColor(0.30, 0.31, 0.27, 1)
      love.graphics.print(("logical %d / raster %s / h %.1f / line %.1f"):format(
        size, tostring(native or size), font:getHeight(), lineBox), x, y)
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
  love.graphics.setCanvas()
  canvas:newImageData():encode("png", "plain_pixel_render_probe.png")
  print("Plain Pixel probe: " .. love.filesystem.getSaveDirectory()
    .. "/plain_pixel_render_probe.png")
  love.filesystem.remove(staged)
  love.event.quit(0)
end

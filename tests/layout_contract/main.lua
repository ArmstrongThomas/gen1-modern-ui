-- Pure layout-contract coverage for reusable Modern UI geometry rules.
--
-- Run from the repository root with:
--   & 'C:\\Program Files\\LOVE\\lovec.exe' tests/layout_contract
--
-- This test intentionally does not load the production presenter.  The
-- assertions are reusable by production or adapter fixtures without needing
-- the large game-state mock used by compose_suppression.

local assertions = 0

local function fail(message)
  error("layout contract test: " .. tostring(message), 0)
end

local function check(value, message)
  assertions = assertions + 1
  if not value then fail(message) end
end

local function finiteNumber(value, fallback)
  local number = tonumber(value)
  if number == nil then return fallback end
  return number
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function normalizeRect(value, label)
  check(type(value) == "table", (label or "rectangle") .. " is a table")
  local rect = {
    x = finiteNumber(value.x, nil),
    y = finiteNumber(value.y, nil),
    w = finiteNumber(value.w or value.width, nil),
    h = finiteNumber(value.h or value.height, nil),
  }
  check(rect.x ~= nil and rect.y ~= nil and rect.w ~= nil and rect.h ~= nil,
    (label or "rectangle") .. " has numeric x/y/w/h")
  check(rect.w >= 0 and rect.h >= 0,
    (label or "rectangle") .. " has non-negative dimensions")
  return rect
end

local function right(rect)
  return rect.x + rect.w
end

local function bottom(rect)
  return rect.y + rect.h
end

local function assertRectInsideSafeArea(candidate, safeArea, label, tolerance)
  tolerance = finiteNumber(tolerance, 0.001)
  local rect = normalizeRect(candidate, (label or "rectangle") .. " candidate")
  local safe = normalizeRect(safeArea, (label or "rectangle") .. " safe area")
  check(rect.x >= safe.x - tolerance,
    (label or "rectangle") .. " does not cross the safe area's left edge")
  check(rect.y >= safe.y - tolerance,
    (label or "rectangle") .. " does not cross the safe area's top edge")
  check(right(rect) <= right(safe) + tolerance,
    (label or "rectangle") .. " does not cross the safe area's right edge")
  check(bottom(rect) <= bottom(safe) + tolerance,
    (label or "rectangle") .. " does not cross the safe area's bottom edge")
  return rect
end

local function assertNoRowOverlap(rows, label, tolerance)
  tolerance = finiteNumber(tolerance, 0.001)
  check(type(rows) == "table", (label or "rows") .. " is a table")
  for index = 1, #rows do
    local first = normalizeRect(rows[index],
      (label or "rows") .. "[" .. tostring(index) .. "]")
    for otherIndex = index + 1, #rows do
      local second = normalizeRect(rows[otherIndex],
        (label or "rows") .. "[" .. tostring(otherIndex) .. "]")
      local overlapW = math.min(right(first), right(second))
        - math.max(first.x, second.x)
      local overlapH = math.min(bottom(first), bottom(second))
        - math.max(first.y, second.y)
      check(not (overlapW > tolerance and overlapH > tolerance),
        (label or "rows") .. " overlap between rows "
          .. tostring(index) .. " and " .. tostring(otherIndex))
    end
  end
end

local function assertStableOuterBounds(first, second, label, tolerance)
  tolerance = finiteNumber(tolerance, 0.001)
  local left = normalizeRect(first, (label or "outer bounds") .. " first")
  local rightRect = normalizeRect(second,
    (label or "outer bounds") .. " second")
  check(math.abs(left.x - rightRect.x) <= tolerance,
    (label or "outer bounds") .. " changed its x position")
  check(math.abs(left.y - rightRect.y) <= tolerance,
    (label or "outer bounds") .. " changed its y position")
  check(math.abs(left.w - rightRect.w) <= tolerance,
    (label or "outer bounds") .. " changed its width")
  check(math.abs(left.h - rightRect.h) <= tolerance,
    (label or "outer bounds") .. " changed its height")
end

-- This mirrors the public pixel-font contract: values may be supplied as
-- 1X-4X or as percentages, but the effective raster scale is always a whole
-- authored step.  UI scale remains independent and may use five-percent
-- increments.
local function effectivePixelFontScale(value)
  local numeric = tonumber(value)
  if numeric == nil then numeric = 100 end
  local scale = numeric < 10 and numeric or numeric / 100
  return clamp(math.floor(scale + 0.5), 1, 4) * 100
end

local function assertWholeStepPixelFontScale(uiValue, fontValue, expected,
    label)
  local uiPercent = finiteNumber(uiValue, nil)
  check(uiPercent ~= nil and uiPercent >= 75 and uiPercent <= 400
      and uiPercent % 5 == 0,
    (label or "scale") .. " uses a valid five-percent UI scale")
  local actual = effectivePixelFontScale(fontValue)
  check(actual == expected,
    (label or "scale") .. " resolves the expected pixel-font scale")
  check(actual % 100 == 0 and actual >= 100 and actual <= 400,
    (label or "scale") .. " resolves to a whole 1X-4X pixel-font step")
  return actual
end

local function insetRect(rect, insetX, insetY)
  return {
    x = rect.x + insetX,
    y = rect.y + insetY,
    w = math.max(0, rect.w - insetX * 2),
    h = math.max(0, rect.h - insetY * 2),
  }
end

local function pageLayout(safeArea, rows)
  local outer = insetRect(safeArea, 48, 36)
  local content = insetRect(outer, 24, 28)
  local rowHeight = 44
  local result = { outer = outer, rows = {}, content = content }
  for index = 1, #rows do
    result.rows[index] = {
      x = content.x,
      y = content.y + (index - 1) * rowHeight,
      w = content.w,
      h = rowHeight - 4,
      label = rows[index],
    }
  end
  return result
end

local function runRectangleContract()
  local safeArea = { x = 32, y = 24, w = 896, h = 492 }
  local pages = {
    { "SUMMARY", "BADGES", "POKéDEX" },
    { "HP", "ATTACK", "DEFENSE", "SPEED", "SPECIAL", "EXPERIENCE" },
    { "A long page label that wraps", "A second page with different content" },
  }
  local firstLayout
  for pageIndex, rows in ipairs(pages) do
    local layout = pageLayout(safeArea, rows)
    assertRectInsideSafeArea(layout.outer, safeArea,
      "page " .. tostring(pageIndex) .. " outer panel")
    assertNoRowOverlap(layout.rows, "page " .. tostring(pageIndex) .. " rows")
    for rowIndex, row in ipairs(layout.rows) do
      assertRectInsideSafeArea(row, layout.outer,
        "page " .. tostring(pageIndex) .. " row " .. tostring(rowIndex))
      check(row.y >= layout.content.y and bottom(row) <= bottom(layout.content),
        "page " .. tostring(pageIndex) .. " row stays inside content region")
    end
    if firstLayout then
      assertStableOuterBounds(firstLayout.outer, layout.outer,
        "outer panel across page/content changes")
    else
      firstLayout = layout
    end
  end

  local touchingRows = {
    { x = 0, y = 0, width = 100, height = 20 },
    { x = 0, y = 20, width = 100, height = 20 },
  }
  assertNoRowOverlap(touchingRows, "edge-touching rows")

  local separatedColumns = {
    { x = 0, y = 0, w = 40, h = 40 },
    { x = 50, y = 10, w = 40, h = 40 },
  }
  assertNoRowOverlap(separatedColumns, "non-overlapping columns")
end

local function runPixelFontContract()
  local cases = {
    { ui = 75, font = 80, expected = 100 },
    { ui = 100, font = 100, expected = 100 },
    { ui = 125, font = 125, expected = 100 },
    { ui = 150, font = 150, expected = 200 },
    { ui = 150, font = 200, expected = 200 },
    { ui = 200, font = 300, expected = 300 },
    { ui = 400, font = 400, expected = 400 },
    { ui = 100, font = 250, expected = 300 },
    { ui = 100, font = 350, expected = 400 },
    { ui = 100, font = 450, expected = 400 },
    { ui = 100, font = 1, expected = 100 },
    { ui = 100, font = 2.5, expected = 300 },
  }
  for index, case in ipairs(cases) do
    assertWholeStepPixelFontScale(case.ui, case.font, case.expected,
      "combined scale case " .. tostring(index))
  end
end

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

function love.load()
  io.stdout:setvbuf("no")
  runRectangleContract()
  runPixelFontContract()
  print(("layout contract test: PASS (%d assertions)"):format(assertions))
  love.event.quit(0)
end

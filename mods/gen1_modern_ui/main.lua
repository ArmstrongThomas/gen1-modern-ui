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
  },
  typography = { title = 24, body = 17, caption = 13 },
  spacing = { xs = 5, sm = 9, md = 13, lg = 18, xl = 26 },
  radii = { sm = 8, md = 16, lg = 22 },
  density = { rowHeight = 54, panelMax = 780 },
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

local function safeText(value)
  if value == nil then return "" end
  return tostring(value)
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
  }
  local title = state and state.title or names[state and state.screenId]
  if not title then
    title = ({ menu = "MENU", list = "LIST", choice = "CHOOSE",
               quantity = "QUANTITY", options = "OPTIONS",
               party = "POKéMON", summary = "SUMMARY" })[kind]
  end
  if kind == "choice" or (kind == "menu" and not (state and state.title)
      and not (state and names[state.screenId])) then
    title = ""
  end
  return Strings(title or "MENU")
end

local function font(cache, size)
  local key = math.max(10, math.floor(size or 16))
  if not cache[key] then cache[key] = love.graphics.newFont(key) end
  return cache[key]
end

local function truncate(text, maxWidth)
  text = safeText(text)
  if love.graphics.getFont():getWidth(text) <= maxWidth then return text end
  local suffix = "..."
  while #text > 0 and love.graphics.getFont():getWidth(text .. suffix) > maxWidth do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local function wrappedLines(text, maxWidth)
  local lines = {}
  text = safeText(text):gsub("\v", "\n"):gsub("\f", "\n")
  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if line ~= "" and love.graphics.getFont():getWidth(candidate) > maxWidth then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  if #lines == 0 then lines[1] = "" end
  return lines
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
local function responsiveTheme(theme, viewport)
  local _, _, w, h = viewportRect(viewport)
  if not (h > w * 1.55 and w <= 720) then return theme end
  local scale = clamp(w / 460, 1.16, 1.28)
  local out = copy(theme)
  out.typography = copy(theme.typography)
  out.spacing = copy(theme.spacing)
  out.radii = copy(theme.radii)
  out.density = copy(theme.density)
  for key, value in pairs(out.typography) do out.typography[key] = value * scale end
  for key, value in pairs(out.spacing) do out.spacing[key] = value * scale end
  for key, value in pairs(out.radii) do out.radii[key] = value * scale end
  out.density.rowHeight = out.density.rowHeight * scale
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
  local imageCache = {}
  local utf8Library
  local glyphFont = mod.ui and mod.ui.Font
  local filteredImages = setmetatable({}, { __mode = "k" })
  local animatedImages = setmetatable({}, { __mode = "k" })
  local spriteAnimationOn = true
  -- render.compose does not receive the Game object.  render.zones caches the
  -- live singleton immediately before it so both hooks inspect one frame.
  local currentGame

  local function prepareImage(image)
    if not image or filteredImages[image] then return image end
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest", 0)
    end
    filteredImages[image] = true
    return image
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
    love.graphics.print(truncate(text, maxWidth), x, y)
  end

  local function currentTheme()
    local base = themes[option("theme", "default")] or themes.default
    local panelOpacity = clamp((tonumber(option("panelOpacity", 100)) or 100) / 100, 0, 1)
    local foregroundOpacity = clamp((tonumber(option("foregroundOpacity", 100)) or 100) / 100, 0, 1)
    local theme = copy(base)
    theme.colors = copy(base.colors)
    for _, key in ipairs({ "backdrop", "surface", "surfaceRaised", "selected" }) do
      local color = theme.colors[key]
      if color then color[4] = (color[4] or 1) * panelOpacity end
    end
    for _, key in ipairs({ "text", "textMuted", "onAccent", "accent", "divider" }) do
      local color = theme.colors[key]
      if color then color[4] = (color[4] or 1) * foregroundOpacity end
    end
    return theme
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
  }

  local optionSchema = {
    { key = "theme", label = "UI THEME", type = "choice",
      description = "Choose the color, contrast, and panel style used by the modern interface.",
      choices = themeChoices, default = "default" },
    { key = "density", label = "UI DENSITY", type = "choice",
      description = "Adjust the spacing and row height used by modern panels.",
      choices = { { "AUTO", "auto" }, { "COMPACT", "compact" },
                  { "COMFORTABLE", "comfortable" } }, default = "auto" },
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
    { key = "startMenuShortcut", label = "START UI SETTINGS", type = "toggle", default = true,
      description = "Add a direct UI SETTINGS entry to the in-game Start menu.", },
    { key = "startMenuFastJump", label = "START MENU FAST JUMP", type = "toggle", default = true,
      description = "Let left/right directional presses jump five rows in the Start menu.", },
    -- Keep the richer presentation as the first-run experience. Existing
    -- saves retain a player's explicit choice through the normal option store.
    { key = "minimalUi", label = "MINIMAL UI", type = "toggle", default = false,
      description = "Use a compact presentation with fewer previews and less extra detail.", },
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
    if worldVisibleLayout(viewport) then return false end
    local x, y, w, h = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", x, y, w, h)
    return true
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
  local managerClass = optionalClass("src.mods.ManagerState")
  local titleClass = optionalClass("src.ui.TitleState")
  local statsLibrary = optionalClass("src.pokemon.Stats")
  -- The released overworld is a singleton class table rather than a normal
  -- instance. Its drawUI method is therefore a legitimate raw field. Capture
  -- the shipped identities once so a replaced world renderer still triggers
  -- the conservative classic fallback. Additive drawUI wrappers (for example
  -- Quality of Life's location banner) are allowed when the world draw itself
  -- remains the released renderer, so they do not disable every menu layered
  -- over the overworld.
  local overworldClass = optionalClass("src.world.OverworldController")
  local overworldDraw = overworldClass and rawget(overworldClass, "draw")

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
    if manifest then pcall(manager.openOptions, manager, manifest) end
    return manager
  end

  -- The shortcut is additive and anchored on a stable label. It remains a
  -- normal Start-menu row, so other mods' rows and the existing Back path are
  -- untouched. Older clients without ManagerState/openOptions simply open the
  -- ordinary manager and retain full compatibility.
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or option("startMenuShortcut", true) == false then
      return out
    end
    for _, item in ipairs(out) do
      if type(item) == "table" and item.id == "gen1_modern_ui.options" then
        return out
      end
    end
    local shortcut = {
      id = "gen1_modern_ui.options",
      label = Strings("UI SETTINGS"),
      onSelect = function() openModernOptions(game) end,
    }
    if mod.ui and type(mod.ui.insertBefore) == "function" then
      return mod.ui.insertBefore(out, "OPTION", shortcut)
    end
    table.insert(out, 1, shortcut)
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
    for _, row in ipairs(optionSchema) do
      if row.key == id then return row.description end
    end
    return nil
  end

  local function optionState(game)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if not (top and top.screenId == "ManagerState" and top.screen == "options"
        and type(top.optionRows) == "table" and type(top.cursor) == "number") then
      return nil
    end
    return top
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
    local description = row and optionDescription(row.id)
    if not description or description == "" then return end
    state._gen1OptionDescription = {
      title = row.label or row.id,
      text = description,
    }
    consumePending(input, { select = true })
  end

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if not game then
      return result
    end
    if syncWorldVisibility then syncWorldVisibility(game) end
    local input = game.input
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

  local function kindFor(state)
    if not state then return nil end
    local id = state.screenId
    local class = classOf(state)
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
    if kind == "text" or kind == "choice" or kind == "quantity" then
      return option("dialogueUi", true) ~= false
    end
    if kind == "mod_manager" then return option("managerUi", true) ~= false end
    if kind == "gen3_box" or kind == "dex_entry" or kind == "summary"
        or kind == "party" or kind == "trainer_card" or kind == "pokedex"
        or kind == "box_mon_list" then
      return option("pokemonUi", true) ~= false
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
    if kind == "bag" and state.screenId == "BagMenu"
        and type(state.modernBag) == "table" then return true end
    if kind == "gen3_box" and isGen3Box(state) then return true end
    if kind == "dex_entry" and isUsefulDexEntry(state) then return true end
    if kind == "box_root" and isBoxRoot(state) then return true end
    if kind == "menu" and state._gen1ModernTitleMenu == true
        and rawget(state, "draw") == state._gen1ModernTitleDraw then return true end
    return false
  end

  local function expectedClass(kind)
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
      syncStateVisibility(game, state)
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
              or rawget(visible, "draw") ~= overworldDraw
              or type(rawget(visible, "drawUI")) ~= "function" then
            return {}, false
          end
        elseif type(rawget(visible, "drawUI")) == "function" then
          return {}, false
        end
      elseif titleClass and visible.screenId == "TitleState"
          and inherits(classOf(visible), titleClass) then
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
        layers[#layers + 1] = { state = visible, kind = kind, index = index }
      end
    end
    return layers, #layers > 0, not preserveUiCanvas
  end

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
    elseif kind == "options" then
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
      if #rows == 0 then rows[1] = { label = Strings("No POKéMON!") } end
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
      if #rows == 0 then rows[1] = { label = Strings("No POKéMON!") } end
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
        rows[#rows + 1] = {
          label = item.label or item.name or "",
          -- `value` is commonly an opaque callback payload, item ID, or table.
          -- Only render fields that a row explicitly declares as presentation
          -- metadata; this keeps third-party list rows from leaking internals.
          value = item.right ~= nil and item.right or item.displayValue,
          enabled = item.enabled,
          marker = item.ball or state.swapIndex == index or state.hollowIndex == index,
          image = imageCandidate(item),
          source = item,
        }
      end
      if #rows == 0 then rows[1] = { label = Strings("Nothing here.") } end
      footer = state.footer
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
    if #rows == 0 then rows[1] = { label = Strings("Nothing here.") } end

    local selected = state.cursor or 1
    local scroll = state.scroll or 0
    -- ManagerState uses one-based list scroll, while the modern presenter
    -- uses a zero-based offset.  Options already uses zero-based scrolling.
    if screen ~= "options" then scroll = math.max(0, scroll - 1) end

    local title = Strings("MOD MANAGER")
    if screen == "detail" and state.currentMod then
      title = safeText(state.currentMod.name or state.currentMod.id)
    elseif screen == "options" and state.currentMod then
      title = Strings("OPTIONS") .. "  " ..
        safeText(state.currentMod.name or state.currentMod.id)
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

  local function layoutFor(viewport, theme, kind, rows, title, footerText)
    rows = rows or {}
    local rowCount = #rows
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing or {}
    local density = option("density", "auto")
    local scale = density == "compact" and 0.88 or density == "comfortable" and 1.12 or 1
    local landscape = w > h * 1.2
    local desktopFloat = worldVisibleLayout(viewport)
    -- Touch controls can consume a large fraction of a phone's short
    -- landscape height. Use a denser outer rhythm there, then fit rows to the
    -- available presenter height before falling back to scrolling.
    local gutter = (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale
    local header = safeText(title) ~= "" and ((theme.typography.title or 24) +
      (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale)
      or (spacing.md or 13) * scale
    local footer = (landscape and (spacing.sm or 9) or (spacing.lg or 18)) * scale
      + (theme.typography.caption or 13)
    local rowHeight = (theme.density.rowHeight or 54) * scale
    local panelMax = theme.density.panelMax or 780
    if landscape then
      -- Keep content-sized panels compact, but leave enough room for long
      -- localized labels and option values before truncating them.
      panelMax = math.min(panelMax, w * 0.72)
    end
    if landscape and rowCount > 0 then
      local fitHeight = (h - gutter * 2 - header - footer) / rowCount
      -- Keep text comfortably legible, but do not reserve desktop-sized rows
      -- when the touch-safe landscape viewport is short.
      local minLandscapeRow = landscape and 30 or 34
      rowHeight = math.min(rowHeight, math.max(minLandscapeRow * scale, fitHeight))
    end
    local minPanelW = landscape and 220 or 250
    local measuredW = contentWidthFor(theme, rows, title, footerText,
      minPanelW, panelMax)
    local panelW = math.min(w - gutter * 2, measuredW)
    local navigationMenu = kind == "menu" or kind == "box_root"
    local sidePanel = desktopFloat and landscape and navigationMenu and rowCount > 0
    if navigationMenu or kind == "choice" or kind == "quantity" then
      -- Short action/confirmation menus should read as focused cards in
      -- landscape, not as banners stretched across the whole phone. Longer
      -- list/options screens keep the wider panel calculated from the theme
      -- max.
      panelW = math.min(panelW, (w > h * 1.2) and w * 0.70 or 560)
    end
    if sidePanel then
      -- The ordinary in-game menu is navigational chrome, not a modal data
      -- screen. On wide windows keep it narrow and dock it to the edge so the
      -- world remains visible instead of dimming behind a centered card.
      local preferredSideW = clamp(w * 0.30, 220, 460)
      panelW = math.min(w - gutter * 2, math.max(panelW, preferredSideW))
      gutter = spacing.lg or 18
      header = safeText(title) ~= "" and ((theme.typography.title or 24)
        + (spacing.md or 13)) or (spacing.md or 13)
      footer = (spacing.sm or 9) + (theme.typography.caption or 13)
      rowHeight = math.min(rowHeight, math.max(30 * scale,
        (h - gutter * 2 - header - footer) / math.max(1, rowCount)))
    end
    panelW = math.max(1, panelW)
    local visible = math.max(1, math.floor((h - gutter * 2 - header - footer) / rowHeight))
    visible = math.min(visible, math.max(1, rowCount))
    local contentH = header + footer + visible * rowHeight
    local panelH = math.min(h - gutter * 2, contentH)
    panelH = math.max(1, panelH)
    return {
      x = sidePanel and (x + w - panelW - gutter) or x + (w - panelW) / 2,
      y = y + (h - panelH) / 2,
      w = panelW, h = panelH, rowHeight = rowHeight,
      header = header, footer = footer, visible = visible,
      safeX = x, safeY = y, safeW = w, safeH = h,
      radius = theme.radii and theme.radii.md or 16,
      sidePanel = sidePanel,
    }
  end

  local function drawHeader(theme, layout, title)
    if safeText(title) == "" then return end
    local colors = theme.colors
    setColor(colors.accent)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, 4,
      layout.radius, layout.radius, 0, 0)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    setColor(colors.text)
    love.graphics.print(truncate(title, layout.w - theme.spacing.lg * 2),
      layout.x + theme.spacing.lg,
      layout.y + theme.spacing.md)
  end

  local function drawRows(theme, layout, rows, selected, scroll, game)
    local colors = theme.colors
    love.graphics.setFont(font(fontCache, theme.typography.body))
    for slot = 1, layout.visible do
      local index = scroll + slot
      local row = rows[index]
      if not row then break end
      local ry = layout.y + layout.header + (slot - 1) * layout.rowHeight
      if row.header then
        setColor(colors.textMuted)
        love.graphics.setFont(font(fontCache, theme.typography.caption))
        love.graphics.print(safeText(row.label):upper(),
          layout.x + theme.spacing.lg, ry + (layout.rowHeight -
            love.graphics.getFont():getHeight()) / 2)
        love.graphics.setFont(font(fontCache, theme.typography.body))
      elseif index == selected then
        setColor(colors.selected)
        love.graphics.rectangle("fill", layout.x + theme.spacing.sm, ry,
          layout.w - theme.spacing.sm * 2, layout.rowHeight - 4,
          theme.radii.sm or 8)
      end
      if row.header then
        -- Category headings in the mod list are deliberately inert; the
        -- vanilla cursor skips them and the presenter only changes their
        -- typography, not their position in the live row array.
        setColor(colors.divider)
        love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
          ry + layout.rowHeight - 2, layout.w - theme.spacing.lg * 2, 1)
      else
        setColor(row.enabled == false and colors.textMuted or colors.text)
      end
      local icon = not row.header and imageFor(row.image) or nil
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
      local textAvail = math.max(1, layout.x + layout.w - theme.spacing.lg - textX)
      local gap = theme.spacing.md
      local labelWidth = love.graphics.getFont():getWidth(label)
      local valueWidth = value ~= "" and love.graphics.getFont():getWidth(value) or 0
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
      if not row.header then
        love.graphics.print(truncate(label, math.max(20, leftWidth)),
          textX, ry + (layout.rowHeight -
            love.graphics.getFont():getHeight()) / 2)
        if value ~= "" then
          love.graphics.print(truncate(value, valueWidth),
            layout.x + layout.w - theme.spacing.lg - valueWidth,
            ry + (layout.rowHeight - love.graphics.getFont():getHeight()) / 2)
        end
      end
      if row.marker then
        setColor(colors.accent)
        love.graphics.circle("fill", layout.x + layout.w - theme.spacing.lg -
          valueWidth - 10, ry + layout.rowHeight * 0.5, 4)
      end
      if index < #rows then
        setColor(colors.divider)
        love.graphics.rectangle("fill", layout.x + theme.spacing.lg, ry + layout.rowHeight - 2,
          layout.w - theme.spacing.lg * 2, 1)
      end
    end
    if scroll > 0 then
      setColor(colors.accent)
      love.graphics.print("^", layout.x + layout.w - theme.spacing.lg - 8,
        layout.y + layout.header - 4)
    end
    if scroll + layout.visible < #rows then
      setColor(colors.accent)
      love.graphics.print("v", layout.x + layout.w - theme.spacing.lg - 8,
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
    shownCount = clamp(shownCount, 1, 3)
    local first = math.max(1, current - shownCount + 1)
    local lines = {}
    for index = first, current do
      local line = safeText(page[index])
      if index == current then line = textPrefix(line, state.charIndex or #line) end
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  local function dialogueRect(viewport, theme, state)
    local x, y, w, h = presenterRect(viewport)
    local landscape = w > h * 1.2
    local gutter = theme.spacing.lg
    local body = font(fontCache, theme.typography.body)
    local widest = 0
    for _, line in ipairs(dialogueLines(state) or {}) do
      widest = math.max(widest, body:getWidth(safeText(line)))
    end
    local maxWidth = landscape and math.min(760, w * 0.70) or math.min(620, w - gutter * 2)
    local minWidth = math.min(landscape and 280 or 260, maxWidth)
    local width = clamp(widest + gutter * 2, minWidth, maxWidth)
    local height = math.max(104,
      body:getHeight() * 2 + theme.spacing.lg * 2 + theme.typography.caption + 12)
    height = math.min(height, h - gutter * 2)
    return x + (w - width) / 2, y + h - height - gutter, width, height
  end

  local function drawDialogue(state, viewport, theme)
    local px, py, panelW, panelH = dialogueRect(viewport, theme, state)
    local spacing, colors = theme.spacing, theme.colors
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    setColor(colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4,
      theme.radii.md, theme.radii.md, 0, 0)

    local body = font(fontCache, theme.typography.body)
    love.graphics.setFont(body)
    local available = panelW - spacing.lg * 2
    local lines = {}
    for _, source in ipairs(dialogueLines(state)) do
      for _, line in ipairs(wrappedLines(source, available)) do
        lines[#lines + 1] = line
      end
    end
    -- The released TextBox owns two visible lines. Preserve that contract
    -- after high-resolution wrapping so the affordance strip cannot overlap.
    while #lines > 2 do table.remove(lines, 1) end
    local lineGap = body:getHeight() + spacing.xs
    local textY = py + spacing.lg
    setColor(colors.text)
    for index, line in ipairs(lines) do
      love.graphics.print(line, px + spacing.lg, textY + (index - 1) * lineGap)
    end

    local ready = state.waiting or (state.done and not state.choice
      and not state.auto and not state.stay)
    setColor(colors.textMuted)
    local hint
    if ready then hint = "A / B  continue"
    elseif state.done and state.choice then hint = "Choose an option"
    elseif state.done and state.auto then hint = "Please wait"
    elseif not (state.done and state.stay) then hint = "Hold A / B  speed up" end
    if hint then
      drawHint(theme, Strings(hint), px + spacing.lg,
        py + panelH - spacing.md - theme.typography.caption,
        panelW - spacing.lg * 2)
    end
    if ready and not state.choice then
      setColor(colors.accent)
      love.graphics.print("v", px + panelW - spacing.lg - 8,
        py + panelH - spacing.md - theme.typography.caption)
    end
    return { x = px, y = py, w = panelW, h = panelH }
  end

  local function drawModalRows(game, state, kind, viewport, theme, underKind)
    local rows, selected, scroll, title, footerText = rowsFor(game, state, kind)
    if not rows then return end
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local landscape = w > h * 1.2
    local rowHeight = math.max(40, math.min(theme.density.rowHeight, 50))
    local header = safeText(title) ~= "" and (theme.typography.title + spacing.md)
      or spacing.md
    local footer = theme.typography.caption + spacing.md
    local visible = math.min(#rows, landscape and 7 or 6)
    local maxPanelW = landscape and math.min(w * 0.70, 520) or math.min(w - spacing.lg * 2, 520)
    local panelW = math.min(w - spacing.lg * 2,
      contentWidthFor(theme, rows, title, footerText, landscape and 220 or 250, maxPanelW))
    local panelH = header + footer + visible * rowHeight
    panelH = math.min(panelH, h - spacing.lg * 2)
    local px = x + (w - panelW) / 2
    local py = y + (h - panelH) / 2
    if underKind == "text" then
      local dx, dy, dw = dialogueRect(viewport, theme)
      px = dx + dw - panelW
      py = math.max(y + spacing.lg, dy - panelH - spacing.sm)
    elseif underKind then
      px = x + w - panelW - spacing.lg
      py = y + spacing.lg * 2
    end
    local layout = {
      x = px, y = py, w = panelW, h = panelH,
      rowHeight = rowHeight, header = header, footer = footer,
      visible = visible, radius = theme.radii.md, sidePanel = false,
    }
    scroll = clamp(scroll or 0, 0, math.max(0, #rows - visible))
    selected = clamp(selected or 1, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, layout, title)
    drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footer, panelW - spacing.lg * 2, 1)
    setColor(theme.colors.textMuted)
    local hint = footerText or (kind == "choice" and "A  choose   B  no"
      or kind == "quantity" and "UP/DOWN  amount   A  confirm   B  cancel"
      or "A  select   B  back")
    drawHint(theme, Strings(hint), px + spacing.lg,
      py + panelH - footer + spacing.xs, panelW - spacing.lg * 2)
  end

  local function drawManagerTabs(theme, layout, state)
    if state.screen ~= "list" then return end
    local labels = { "MODS", "PROFILES", "ERRORS" }
    local active = state.tab or 1
    local x = layout.x + theme.spacing.lg
    local y = layout.y + layout.header - theme.spacing.md
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    for i, label in ipairs(labels) do
      local width = love.graphics.getFont():getWidth(label) + theme.spacing.lg
      setColor(i == active and theme.colors.accent or theme.colors.textMuted)
      love.graphics.print(i == active and ("[" .. label .. "]") or label, x, y)
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
      love.graphics.print(truncate(subtitle,
        layout.w - theme.spacing.lg * 2), layout.x + theme.spacing.lg,
        layout.y + theme.spacing.md + theme.typography.title + 2)
      love.graphics.setFont(font(fontCache, theme.typography.body))
    end
  end

  local function drawManagerOverlay(theme, layout, state, viewport)
    local overlay = state.overlay
    if not overlay then return end
    drawPresenterBackdrop(theme, viewport)
    local lines = overlay.lines or {}
    local lineHeight = theme.typography.body + 8
    local modalW = math.min(layout.w * 0.84, 620)
    local modalH = math.min(layout.h * 0.72,
      theme.spacing.lg * 2 + lineHeight * (#lines +
        (overlay.kind == "confirm" and 3 or 1)))
    local mx = layout.x + (layout.w - modalW) / 2
    local my = layout.y + (layout.h - modalH) / 2
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", mx, my, modalW, 4,
      theme.radii.lg or 20, theme.radii.lg or 20, 0, 0)
    love.graphics.setFont(font(fontCache, theme.typography.body))
    for i, line in ipairs(lines) do
      setColor(theme.colors.text)
      love.graphics.print(truncate(line, modalW - theme.spacing.lg * 2),
        mx + theme.spacing.lg, my + theme.spacing.lg + (i - 1) * lineHeight)
    end
    local footerY = my + modalH - theme.spacing.lg - lineHeight
    if overlay.kind == "confirm" then
      local index = overlay.index or 1
      setColor(index == 1 and theme.colors.accent or theme.colors.textMuted)
      love.graphics.print("YES", mx + theme.spacing.lg, footerY)
      setColor(index == 2 and theme.colors.accent or theme.colors.textMuted)
      love.graphics.print("NO", mx + theme.spacing.lg + 72, footerY)
    else
      setColor(theme.colors.textMuted)
      love.graphics.print("A / B  CLOSE", mx + theme.spacing.lg, footerY)
    end
  end

  local function drawManagerOptionHelp(theme, layout, state, viewport)
    local help = state._gen1OptionDescription
    if not help then return end
    drawPresenterBackdrop(theme, viewport)
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
    local lineHeight = body:getHeight() + spacing.xs
    local footerH = body:getHeight() + spacing.sm
    local modalH = spacing.lg * 2 + titleFont:getHeight() + spacing.sm
      + #lines * lineHeight + footerH
    modalH = math.min(layout.h - spacing.md * 2, modalH)
    local mx = layout.x + (layout.w - modalW) / 2
    local my = layout.y + (layout.h - modalH) / 2
    setColor(theme.colors.surfaceRaised or theme.colors.surface)
    love.graphics.rectangle("fill", mx, my, modalW, modalH,
      theme.radii.lg or 20)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", mx, my, modalW, 4,
      theme.radii.lg or 20, theme.radii.lg or 20, 0, 0)
    love.graphics.setFont(titleFont)
    setColor(theme.colors.text)
    love.graphics.print(truncate(title, modalW - spacing.lg * 2),
      mx + spacing.lg, my + spacing.md)
    love.graphics.setFont(body)
    local textY = my + spacing.md + titleFont:getHeight() + spacing.sm
    for index, line in ipairs(lines) do
      setColor(theme.colors.text)
      love.graphics.print(line, mx + spacing.lg, textY + (index - 1) * lineHeight)
    end
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", mx + spacing.lg,
      my + modalH - footerH, modalW - spacing.lg * 2, 1)
    setColor(theme.colors.textMuted)
    love.graphics.print("SELECT / A / B  CLOSE", mx + spacing.lg,
      my + modalH - footerH + spacing.xs)
  end

  local function drawManager(game, state, viewport, theme)
    local rows, selected, scroll, title = managerRowsFor(game, state)
    local layout = layoutFor(viewport, theme, "mod_manager", rows, title,
      state.notice)
    -- The manager has a tab strip and (for detail/apply views) a status
    -- subtitle in addition to the normal title. Reserve that line before
    -- calculating how many rows fit so portrait layouts never overlap text.
    local headerExtra = state.screen == "list" and 20
      or state.screen == "detail" and 20
      or state.screen == "apply" and 20 or 0
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
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2, 1)
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
    drawHint(theme, Strings(footer), layout.x + theme.spacing.lg,
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
      theme.density.panelMax or 780)
    local panelH = math.min(h - gutter * 2,
      (w > h * 1.20) and 430 or 560)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local compact = panelH < 380
    local mon = summaryPokemon(state) or {}
    local def = pokemonDefinition(game, mon.species)
    local name = mon.nickname or (def and def.name) or mon.species or "POKéMON"
    local titleFont = font(fontCache, compact and theme.typography.title * 0.86
      or theme.typography.title)
    local bodyFont = font(fontCache, compact and theme.typography.body * 0.86
      or theme.typography.body)
    local captionFont = font(fontCache, theme.typography.caption)
    local titleH = titleFont:getHeight()
    local lineGap = compact and (bodyFont:getHeight() + spacing.xs)
      or (spacing.lg + 10)
    local pageY = py + spacing.md + titleH + spacing.xs
    local levelY = pageY + bodyFont:getHeight() + spacing.xs
    local hpY = levelY + lineGap
    local statusY = hpY + lineGap
    drawPresenterBackdrop(theme, viewport)
    love.graphics.setFont(bodyFont)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4, theme.radii.lg, theme.radii.lg, 0, 0)
    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    love.graphics.print(name, px + spacing.lg, py + spacing.md)
    love.graphics.setFont(bodyFont)
    local level = mon.level and ("LEVEL %d"):format(mon.level) or ""
    local hp = mon.stats and mon.stats.hp and ("HP  %d / %d"):format(mon.hp or 0, mon.stats.hp) or ""
    local status = mon.status or "OK"
    local page = state.page == 2 and "MOVES / EXPERIENCE" or "STATUS / TRAINER DATA"
    if panelW < 620 and state.page ~= 2 then page = "STATUS" end
    setColor(theme.colors.textMuted)
    love.graphics.print(page, px + spacing.lg, pageY)
    setColor(theme.colors.text)
    love.graphics.print(level, px + spacing.lg, levelY)
    love.graphics.print(hp, px + spacing.lg, hpY)
    love.graphics.print(("STATUS  %s"):format(status), px + spacing.lg, statusY)
    if state.page ~= 2 then
      local sprite = spriteFor(game, mon, nil, "summary")
      if sprite then
        local iw, ih = imageMetrics(sprite)
        if iw and ih then
          local spriteSize = compact and math.min(112, panelW * 0.24) or 150
          local spriteX = px + spacing.lg
          local spriteY = compact and (statusY + lineGap * 2 + spacing.sm)
            or (py + spacing.lg + 208)
          local scale = math.min(spriteSize / iw, spriteSize / ih)
          setColor({ 1, 1, 1, 1 })
          drawImage(sprite, spriteX + (spriteSize - iw * scale) / 2,
            spriteY + (spriteSize - ih * scale) / 2, 0, scale, scale)
        end
      end
    end
    if state.page == 2 then
      love.graphics.print(("EXP  %s"):format(safeText(mon.exp)), px + spacing.lg,
        statusY + lineGap)
      local moves = mon.moves or {}
      local moveX = px + spacing.lg
      local moveY = statusY + lineGap * 2
      local moveGap = compact and (bodyFont:getHeight() + spacing.xs) or 28
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
        love.graphics.print(truncate(moveName, panelW * 0.42), moveX,
          moveY + (i - 1) * moveGap)
        setColor(theme.colors.textMuted)
        love.graphics.print(("PP %s"):format(pp), px + panelW - spacing.lg - 90,
          moveY + (i - 1) * moveGap)
      end
    else
      local types = def and def.types or {}
      love.graphics.print(("TYPE  %s %s"):format(safeText(types[1]), safeText(types[2])),
        px + spacing.lg, statusY + lineGap)
      local stats = mon.stats or {}
      local infoX = compact and (px + panelW * 0.48) or (px + panelW * 0.52)
      local statGap = compact and (bodyFont:getHeight() + spacing.xs) or 28
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
        love.graphics.print(item[1], infoX, statY + (i - 1) * statGap)
        setColor(theme.colors.text)
        local value = safeText(item[2])
        local valueX = infoX + bodyFont:getWidth(item[1]) + spacing.sm
        love.graphics.print(truncate(value, panelW * 0.40), valueX,
          statY + (i - 1) * statGap)
      end
    end
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    love.graphics.print("A / B  continue", px + spacing.lg, py + panelH - spacing.lg - 14)
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
    if not path or not species then return path, false end
    local replaced = false

    -- src.pokemon.Sprites.path is the runtime's sanctioned sprite seam. It
    -- invokes enabled pokemon.sprite replacements (Gold/Silver, alternate
    -- skins, etc.) and returns the vanilla path when none is active. Older
    -- builds without the helper fall back to the data path.
    if spriteResolver == nil then
      local ok, resolver = pcall(require, "src.pokemon.Sprites")
      spriteResolver = ok and resolver or false
    end
    if spriteResolver and type(spriteResolver.path) == "function" then
      local ok, hooked = pcall(spriteResolver.path, game.data, species, side, {
        mon = mon, kind = kind or "menu",
      })
      if ok and type(hooked) == "string" and hooked ~= "" then
        replaced = hooked ~= path
        path = hooked
      end
    end
    return path, replaced
  end

  spriteFor = function(game, mon, fallback, kind)
    local image = imageFor(mon and imageCandidate(mon))
    if image then return image end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path = resolvedSpritePath(game, mon, "front", kind, fallbackPath)
    -- Battle sprite replacement assets are complete single-frame pictures by
    -- default (including Gold/Silver packs). Only an explicit image
    -- descriptor with `frames` opts into sheet animation.
    image = imageFor(path)
    if image then return image end
    return imageFor(fallback)
  end

  local function spriteForSide(game, mon, side, fallback, kind)
    local image = imageFor(mon and imageCandidate(mon))
    if image then return image end
    local fallbackPath = type(fallback) == "string" and fallback or nil
    local path = resolvedSpritePath(game, mon, side, kind, fallbackPath)
    -- `pokemon.sprite` paths are authored battle pictures, not animation
    -- sheets. Explicit descriptors can still request frame cropping.
    image = imageFor(path)
    if image then return image end
    return imageFor(fallback)
  end

  local function drawTrainerCard(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      math.max(theme.density.panelMax or 780, 860))
    local panelH = math.min(h - gutter * 2,
      (w > h * 1.15) and 500 or 640)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.15

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    local headerLayout = { x = px, y = py, w = panelW,
      radius = theme.radii.md }
    drawHeader(theme, headerLayout, Strings("TRAINER CARD"))

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
    local portrait = prepareImage(state.pic)
    if portrait then
      drawImageFit(portrait, portraitX + spacing.sm, portraitY + spacing.sm,
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
      love.graphics.print(row[1], profileX, ry)
      setColor(colors.text)
      love.graphics.print(truncate(row[2], math.max(20,
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
    love.graphics.print(Strings("BADGES  %d/%d", ownedCount, #badges),
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

      local icon = imageFor(badge.icon or badge.image)
      local artSize = math.max(20, math.min(cellH - spacing.sm * 2, cellW * 0.34))
      if icon then
        drawImageFit(icon, cx + spacing.sm, cy + (cellH - artSize) / 2,
          artSize, artSize)
      else
        local sheet = owned and state.badges or state.faces
        local quad = sheet and sheet.quads and sheet.quads[index - 1]
        if sheet and sheet.img and quad then
          local image = prepareImage(sheet.img)
          local ok, qx, qy, qw, qh = pcall(quad.getViewport, quad)
          if ok and qw and qh then
            local scale = math.min(artSize / qw, artSize / qh)
            setColor({ 1, 1, 1, 1 })
            love.graphics.draw(image, quad,
              cx + spacing.sm + (artSize - qw * scale) / 2,
              cy + (cellH - qh * scale) / 2, 0, scale, scale)
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
      love.graphics.print(truncate(("%d  %s"):format(index, badgeName),
        math.max(20, cx + cellW - spacing.sm - labelX)), labelX,
        cy + (cellH - theme.typography.caption) / 2)
    end

    setColor(colors.divider)
    love.graphics.rectangle("fill", px + spacing.lg,
      py + panelH - footerH, panelW - spacing.lg * 2, 1)
    setColor(colors.textMuted)
    drawHint(theme, Strings("A / B  back"), px + spacing.lg,
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
        and statsLibrary and type(statsLibrary.calc) == "function" then
      local ok, stats = pcall(statsLibrary.calc, def, mon.level or 1,
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
    if #rows == 0 then rows[1] = { label = Strings("No POKéMON!") } end
    return rows
  end

  local function drawHPBar(theme, x, y, w, hp, maxHP)
    maxHP = math.max(1, tonumber(maxHP) or 1)
    local ratio = clamp((tonumber(hp) or 0) / maxHP, 0, 1)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", x, y, w, 8, 4)
    local color = ratio <= 0.20 and { 0.92, 0.24, 0.28, 1 }
      or ratio <= 0.50 and { 0.96, 0.72, 0.20, 1 }
      or { 0.24, 0.78, 0.46, 1 }
    setColor(color)
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
      love.graphics.printf(Strings("No POKéMON selected."), x + spacing.lg,
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
    love.graphics.print(truncate(name, infoW), infoX, y + spacing.md)
    love.graphics.setFont(captionFont)
    setColor(colors.textMuted)
    local speciesName = def.name and def.name ~= name and def.name or nil
    local level = mon.level and ("Lv %d"):format(mon.level) or ""
    local types = {}
    for _, value in ipairs(def.types or {}) do types[#types + 1] = displayType(value) end
    love.graphics.print(truncate(table.concat({ level, speciesName or "",
      table.concat(types, " / ") }, "  "):gsub("  +", "  "), infoW),
      infoX, y + spacing.md + titleFont:getHeight() + spacing.xs)
    local stats = displayStats(game, mon, context == "box")
    local maxHP = stats.hp
    local shownHP = math.min(tonumber(mon.hp) or maxHP or 0,
      maxHP or math.huge)
    if maxHP then
      local barY = y + spacing.md + titleFont:getHeight()
        + captionFont:getHeight() + spacing.md
      drawHPBar(theme, infoX, barY, infoW, shownHP, maxHP)
      love.graphics.print(("HP %d/%d%s"):format(shownHP, maxHP,
        mon.status and ("  " .. safeText(mon.status)) or ""), infoX, barY + 12)
    end

    local lowerY = y + math.max(artSize + spacing.md * 2,
      titleFont:getHeight() + captionFont:getHeight() * 2 + spacing.xl * 2)
    local lowerH = math.max(1, y + h - spacing.md - lowerY)
    love.graphics.setFont(bodyFont)
    local statText = {
      ("ATK %s"):format(safeText(stats.attack or "—")),
      ("DEF %s"):format(safeText(stats.defense or "—")),
      ("SPD %s"):format(safeText(stats.speed or "—")),
      ("SPC %s"):format(safeText(stats.special or "—")),
    }
    setColor(colors.textMuted)
    love.graphics.print(table.concat(statText, "   "), x + spacing.md, lowerY)
    local movesY = lowerY + bodyFont:getHeight() + spacing.sm
    local moves = mon.moves or {}
    local available = math.max(1, math.floor((lowerH - bodyFont:getHeight() - spacing.sm)
      / math.max(1, bodyFont:getHeight() + spacing.xs)))
    local count = math.min(#moves, 4, available)
    for index = 1, count do
      local move = moves[index]
      local moveDef = move and game.data and game.data.moves and game.data.moves[move.id]
      local moveName = moveDef and moveDef.name or move and move.id or "—"
      local pp = move and moveDef and ("PP %d/%d"):format(move.pp or 0,
        maxMovePP(move, moveDef)) or ""
      setColor(colors.text)
      love.graphics.print(truncate(moveName, w * 0.58), x + spacing.md,
        movesY + (index - 1) * (bodyFont:getHeight() + spacing.xs))
      setColor(colors.textMuted)
      love.graphics.print(pp, x + w - spacing.md - bodyFont:getWidth(pp),
        movesY + (index - 1) * (bodyFont:getHeight() + spacing.xs))
    end
    if #moves == 0 then
      setColor(colors.textMuted)
      love.graphics.print(Strings("No moves."), x + spacing.md, movesY)
    end
  end

  local function drawParty(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing, colors = theme.spacing, theme.colors
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      math.max(theme.density.panelMax or 780, 980))
    local party = state.party or (game.save and game.save.party) or {}
    local rows = monDisplayRows(game, party, state)
    local selected = clamp(state.index or 1, 1, math.max(1, #party))
    local minimal = option("minimalUi", false) == true
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local compactH = headerH + footerH + math.min(#rows, 6) *
      math.min(theme.density.rowHeight, 54) + spacing.lg * 2
    local richH = w > h * 1.20 and 520 or 640
    local panelH = math.min(h - gutter * 2, minimal and compactH or richH)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.15
    local contentY = py + headerH
    local contentH = math.max(1, panelH - headerH - footerH)
    local detailW = not minimal and landscape and math.min(panelW * 0.48, 470) or 0
    local detailH = not minimal and not landscape and math.min(contentH * 0.40, 300) or 0
    local listX = px
    local listY = contentY + (detailH > 0 and detailH + spacing.sm or 0)
    local listW = panelW - (detailW > 0 and detailW + spacing.sm or 0)
    local listH = math.max(1, contentH - (detailH > 0 and detailH + spacing.sm or 0))
    local rowHeight = math.min(theme.density.rowHeight,
      math.max(38, listH / math.max(1, #rows)))
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp((state.scroll or 0), 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    local partyTitle = #party <= 6 and Strings("POKéMON  %d/6", #party)
      or Strings("POKéMON  %d", #party)
    drawHeader(theme, { x = px, y = py, w = panelW, radius = theme.radii.md },
      partyTitle)
    local listLayout = { x = listX, y = listY, w = listW, h = listH,
      rowHeight = rowHeight, header = 0, footer = 0, visible = visible,
      radius = theme.radii.sm, sidePanel = false }
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
    drawHint(theme, footer or Strings("A  choose   B  back"), px + spacing.lg,
      py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)

    -- PartyMenu owns its injected action list internally rather than pushing
    -- another state. Draw those exact live rows as a visual modal; callbacks,
    -- selection, and cancellation remain with PartyMenu.
    if state.submenu and type(state.subItems) == "table" then
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
      drawHeader(theme, { x = ax, y = ay, w = actionW, radius = theme.radii.md },
        Strings("POKéMON ACTIONS"))
      local actionVisible = math.max(1, math.min(#actionRows,
        math.floor((actionH - actionHeader) / actionRowH)))
      local actionSelected = clamp(state.subIndex or 1, 1,
        math.max(1, #actionRows))
      local actionScroll = clamp(actionSelected - actionVisible, 0,
        math.max(0, #actionRows - actionVisible))
      drawRows(theme, { x = ax, y = ay, w = actionW, h = actionH,
        rowHeight = actionRowH, header = actionHeader,
        footer = 0, visible = actionVisible, radius = theme.radii.sm },
        actionRows, actionSelected, actionScroll, game)
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
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      math.max(theme.density.panelMax or 780, 980))
    local minimal = option("minimalUi", false) == true
    local compactH = theme.typography.title + theme.typography.caption
      + math.min(#rows, 6) * math.min(theme.density.rowHeight, 54)
      + spacing.lg * 3
    local richH = w > h * 1.20 and 520 or 640
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
    local rowHeight = clamp(theme.density.rowHeight, 38, 54)
    local visible = math.max(1, math.min(#rows, math.floor(listH / rowHeight)))
    local scroll = clamp(state.scroll or 0, 0, math.max(0, #rows - visible))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + visible then scroll = selected - visible end
    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.md)
    drawHeader(theme, { x = px, y = py, w = panelW, radius = theme.radii.md },
      state.title or Strings("PC BOX"))
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
      love.graphics.print(context, px + panelW - spacing.lg - contextW,
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
    drawHint(theme, hint,
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
      math.max(theme.density.panelMax or 780, 920))
    local panelH = math.min(h - gutter * 2,
      (w > h * 1.05) and 520 or 680)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.05
    local headerH = theme.typography.title + spacing.lg
    local footerH = landscape and (theme.typography.caption + spacing.lg)
      or (theme.typography.caption * 2 + spacing.lg + spacing.xs)
    local previewW = landscape and math.min(panelW * 0.38, 330) or panelW
    local previewH = landscape and (panelH - headerH - footerH)
      or math.min(128, panelH * 0.26)
    local listW = landscape and (panelW - previewW - spacing.sm) or panelW
    local listY = landscape and (py + headerH) or (py + headerH + previewH + spacing.sm)
    local listH = math.max(1, py + panelH - footerH - listY)
    local rowHeight = clamp(theme.density.rowHeight, 38, 54)
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
    drawHeader(theme, { x = px, y = py, w = panelW, radius = theme.radii.md }, title)

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
      love.graphics.print(truncate(def.name or species,
        previewX + previewW - spacing.lg - infoX), infoX, infoY)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(colors.textMuted)
      local digits = tonumber(game.data and game.data.constants
        and game.data.constants.dexDigits) or 3
      digits = clamp(math.floor(digits), 1, 8)
      local number = def.dex and ("No. %0" .. digits .. "d"):format(def.dex) or ""
      love.graphics.print(number, infoX, infoY + theme.typography.body + spacing.xs)
      local types = def.types or {}
      local typeNames = {}
      for _, value in ipairs(types) do typeNames[#typeNames + 1] = displayType(value) end
      love.graphics.print(table.concat(typeNames, " / "), infoX,
        infoY + theme.typography.body + theme.typography.caption + spacing.sm)
      setColor(colors.accent)
      love.graphics.print(source.ball and Strings("OWNED") or Strings("SEEN"),
        infoX, infoY + theme.typography.body + theme.typography.caption * 2 + spacing.md)
    else
      love.graphics.setFont(font(fontCache, theme.typography.body))
      setColor(colors.textMuted)
      love.graphics.printf(Strings("No data for this entry."),
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
      drawHint(theme, Strings(hint), px + spacing.lg,
        py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
    else
      if footerText and footerText ~= "" then
        drawHint(theme, footerText, px + spacing.lg,
          py + panelH - footerH + spacing.xs, panelW - spacing.lg * 2)
      end
      drawHint(theme, Strings(hint), px + spacing.lg,
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
      math.max(theme.density.panelMax or 780, 900))
    local minimalBag = option("minimalUi", false) == true
    local compactBagH = theme.typography.title + theme.typography.caption
      + math.min(#rows, 7) * math.min(theme.density.rowHeight, 54)
      + spacing.lg * 3
    local panelH = math.min(h - gutter * 2,
      minimalBag and compactBagH or ((w > h * 1.05) and 520 or 640))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.05
    local minimal = minimalBag
    local headerH = theme.typography.title + spacing.lg
    local footerH = theme.typography.caption + spacing.lg
    local detailW = minimal and 0
      or landscape and math.min(panelW * 0.38, 320) or panelW
    local detailH = minimal and 0
      or landscape and (panelH - headerH - footerH)
      or math.min(148, panelH * 0.28)
    local listW = landscape and (panelW - detailW - spacing.sm) or panelW
    local listY = (landscape or minimal) and (py + headerH)
      or (py + headerH + detailH + spacing.sm)
    local listH = math.max(1, py + panelH - footerH - listY)
    local rowHeight = clamp(theme.density.rowHeight, 38, 54)
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
    drawHeader(theme, { x = px, y = py, w = panelW, radius = theme.radii.md }, title)

    if detailW > 0 and detailH > 0 then
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
      love.graphics.print(truncate(itemName,
        detailX + detailW - spacing.lg - infoX), infoX, detailY + spacing.md)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      local infoY = detailY + spacing.md + theme.typography.body + spacing.sm
      setColor(colors.textMuted)
      if source and source.machineMoveName then
      love.graphics.print(safeText(source.machineMoveName), infoX, infoY)
      if def and def.machine then
        local move = game.data.moves and game.data.moves[def.machine.move]
        if move then
          love.graphics.print(Strings("TYPE %s   PP %s", move.type or "—", move.pp or "—"),
            infoX, infoY + theme.typography.caption + spacing.xs)
        end
      end
      local value = itemValueText(itemId, def)
      if value then
        love.graphics.print(value, infoX,
          infoY + (theme.typography.caption + spacing.xs) * 2)
      end
    elseif def and def.machine then
      local move = game.data.moves and game.data.moves[def.machine.move]
      love.graphics.print(Strings("%s  %s", def.machine.kind or "TM",
        move and move.name or def.machine.move), infoX, infoY)
      if move then
        love.graphics.print(Strings("TYPE %s   PP %s", move.type or "—", move.pp or "—"),
          infoX, infoY + theme.typography.caption + spacing.xs)
      end
      local value = itemValueText(itemId, def)
      if value then
        love.graphics.print(value, infoX,
          infoY + (theme.typography.caption + spacing.xs) * 2)
      end
    elseif def then
      local descriptionY = infoY + theme.typography.caption + spacing.xs
      if def.keyItem then
        love.graphics.print(Strings("KEY ITEM"), infoX, infoY)
        local value = itemValueText(itemId, def)
        if value then
          love.graphics.print(value, infoX, descriptionY)
          descriptionY = descriptionY + theme.typography.caption + spacing.xs
        end
      else
        love.graphics.print(itemValueText(itemId, def) or Strings("ITEM"),
          infoX, infoY)
      end
      local description = def.description or def.desc or def.effectText
      if description then
        love.graphics.print(truncate(description,
          detailX + detailW - spacing.lg - infoX), infoX, descriptionY)
      end
      else
        love.graphics.print(Strings("Select an item."), infoX, infoY)
      end
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
    local hint = type(state.modernBag) == "table"
      and "LEFT/RIGHT  pocket   A  use   B  back"
      or "A  use   SELECT  move   B  back"
    if footerText and footerText ~= "" then hint = footerText .. "    " .. hint end
    drawHint(theme, Strings(hint), px + spacing.lg,
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
      math.max(theme.density.panelMax or 780, 900))
    local minimalContext = option("minimalUi", false) == true
    local compactContextH = theme.typography.title + theme.typography.caption * 2
      + math.min(#rows, 6) * math.min(theme.density.rowHeight, 54)
      + spacing.lg * 4
    local panelH = math.min(h - gutter * 2,
      minimalContext and compactContextH or ((w > h * 1.10) and 520 or 640))
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local landscape = panelW > panelH * 1.10
    local headerH = theme.typography.title + spacing.lg
    local messageH = math.max(72, theme.typography.caption * 2 + spacing.lg * 2)
    local minimal = minimalContext
    local detailW = not minimal and landscape and math.min(panelW * 0.34, 300) or 0
    local detailH = not minimal and not landscape
      and math.min(148, panelH * 0.25) or 0
    local listW = panelW - detailW - (detailW > 0 and spacing.sm or 0)
    local listY = py + headerH + (detailH > 0 and detailH + spacing.sm or 0)
    local listH = math.max(1, py + panelH - messageH - listY)
    local rowHeight = clamp(theme.density.rowHeight, 38, 54)
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
    drawHeader(theme, { x = px, y = py, w = panelW, radius = theme.radii.md }, title)

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
        love.graphics.print(amount, px + panelW - spacing.lg - amountW - spacing.md,
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
      love.graphics.print(truncate(row and row.label or Strings("ITEM"),
        infoW), infoX, detailY + spacing.md)
      love.graphics.setFont(font(fontCache, theme.typography.caption))
      setColor(colors.textMuted)
      local infoY = detailY + spacing.md + theme.typography.body + spacing.sm
      if source and source.right then
        love.graphics.print(safeText(source.right), infoX, infoY)
        infoY = infoY + theme.typography.caption + spacing.xs
      end
      if def and def.machine then
        local move = game.data.moves and game.data.moves[def.machine.move]
        love.graphics.print(Strings("%s  %s", def.machine.kind or "TM",
          move and move.name or def.machine.move), infoX, infoY)
        infoY = infoY + theme.typography.caption + spacing.xs
        if move then
          love.graphics.print(Strings("TYPE %s   PP %s",
            move.type or "—", move.pp or "—"), infoX, infoY)
          infoY = infoY + theme.typography.caption + spacing.xs
        end
      elseif def and def.keyItem then
        love.graphics.print(Strings("KEY ITEM"), infoX, infoY)
        infoY = infoY + theme.typography.caption + spacing.xs
      end
      local value = itemValueText(itemId, def)
      if value then
        love.graphics.print(value, infoX, infoY)
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
      love.graphics.print(messageLines[index], px + spacing.lg,
        messageY + spacing.sm + (index - 1) * (theme.typography.caption + spacing.xs))
    end
    setColor(colors.textMuted)
    local hint = kind == "shop_list" and "A  choose   B  back"
      or "A  choose   B  back"
    drawHint(theme, Strings(hint), px + spacing.lg,
      py + panelH - spacing.md - theme.typography.caption,
      panelW - spacing.lg * 2)
    love.graphics.pop()
  end

  local function drawGen3Box(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      theme.density.panelMax or 780)
    -- The grid itself is the content. Keep a compact square-cell frame
    -- instead of reserving the entire viewport around a 5x4 or 3x2 grid.
    local panelH = math.min(h - gutter * 2,
      (w > h * 1.20) and 470 or 620)
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
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4, theme.radii.lg, theme.radii.lg, 0, 0)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    love.graphics.print(title, px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local footerText = state.notice or (mode == "box"
      and "A  pick/place   START  stats   SELECT  party   B  back"
      or "A  pick/place   START  stats   SELECT  box   B  back")
    drawHint(theme, Strings(footerText), px + spacing.lg,
      py + panelH - footer + 2, panelW - spacing.lg * 2)

    for i = 1, cols * gridRows do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      local cx, cy = gx + c * cellW, gy + r * cellH
      local mon = list[i]
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
        local captionH = captionFont:getHeight() + cellPad * 0.8
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
        local captionY = cy + cellH - captionH + (captionH - captionFont:getHeight()) / 2 - 1
        love.graphics.print(truncate(name, nameMax), cx + cellPad, captionY)
        setColor(theme.colors.textMuted)
        if level ~= "" then
          love.graphics.print(level, cx + cellW - cellPad - levelW, captionY)
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
      love.graphics.print("CARRYING", cardX + 64, cardY + 10)
      setColor(theme.colors.text)
      love.graphics.print(truncate(carriedName, cardW - 76),
        cardX + 64, cardY + 32)
    end
    love.graphics.pop()
  end

  local function drawDexEntry(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      theme.density.panelMax or 780)
    local panelH = math.min(h - gutter * 2,
      (w > h * 1.10) and 520 or 700)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
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
    local heroX = px + spacing.lg
    local heroY = py + titleFont:getHeight() + spacing.xl + 12
    local heroW = math.min(240, panelW * 0.34)
    local heroH = math.min(250, panelH * 0.34)
    local detailX = heroX + heroW + spacing.xl
    local detailW = math.max(40, panelW - (detailX - px) - spacing.lg)
    local footerY = py + panelH - spacing.lg - captionFont:getHeight() - 4

    love.graphics.push("all")
    love.graphics.origin()
    drawPresenterBackdrop(theme, viewport)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4, theme.radii.lg, theme.radii.lg, 0, 0)
    setColor(theme.colors.text)
    love.graphics.setFont(titleFont)
    love.graphics.print(title, px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(captionFont)
    love.graphics.print((page == "stats" and "BASE STATS" or page == "moves" and "MOVES" or
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
        love.graphics.print(("%s  %s"):format(safeText(stat.key), safeText(stat.value)),
          tx, yy)
        yy = yy + bodyFont:getHeight() + spacing.sm
      end
      love.graphics.print("BST  " .. safeText(state.stats.bst), tx, yy + 4)
      yy = yy + bodyFont:getHeight() + spacing.md
      for _, evo in ipairs(state.stats.evolutions or {}) do
        love.graphics.print(truncate((evo.label or "") .. " " .. (evo.name or ""), maxW),
          tx, yy)
        yy = yy + bodyFont:getHeight() + spacing.xs
      end
    elseif page == "moves" then
      local ok, moveRows = pcall(function() return state:rows() end)
      local rows = ok and moveRows or {}
      local start = ((state.page or 1) - 1) * 10 + 1
      local lineGap = bodyFont:getHeight() + spacing.sm
      local remaining = math.max(0, #rows - start + 1)
      local requested = math.min(10, remaining)
      -- Keep the footer as a hard layout boundary.  Dex move pages can expose
      -- a tenth row (TM/HM); without reserving this space the final row can
      -- collide with the navigation hint on short landscape displays.
      local contentBottom = footerY - spacing.sm - bodyFont:getHeight()
      if requested > 1 then
        local compressedGap = (contentBottom - heroY) / (requested - 1)
        lineGap = math.min(lineGap, compressedGap)
      end
      lineGap = math.max(bodyFont:getHeight() + 1, lineGap)
      local maxVisible = math.max(1,
        math.floor((contentBottom - heroY) / lineGap) + 1)
      local visible = math.min(10, remaining, maxVisible)
      for offset = 0, visible - 1 do
        local row = rows[start + offset]
        love.graphics.print(truncate(row, maxW), tx, heroY + offset * lineGap)
      end
      if visible < requested then
        setColor(theme.colors.textMuted)
        love.graphics.print("...", tx, footerY - captionFont:getHeight() - spacing.sm)
        setColor(theme.colors.text)
      end
    else
      local entry = def.dexEntry or {}
      love.graphics.print("No. " .. safeText(def.dex), tx, heroY + spacing.md)
      love.graphics.print(safeText(entry.kind), tx,
        heroY + spacing.md + bodyFont:getHeight() + spacing.sm)
      love.graphics.print(safeText(entry.heightM and ("HT " .. entry.heightM .. "m") or ""),
        tx, heroY + spacing.md + (bodyFont:getHeight() + spacing.sm) * 2)
      love.graphics.print(safeText(entry.weightKg and ("WT " .. entry.weightKg .. "kg") or ""),
        tx, heroY + spacing.md + (bodyFont:getHeight() + spacing.sm) * 3)
      local owned = state.forceOwned or (state.vanilla and state.vanilla.forceOwned)
        or (game.save and game.save.pokedex and game.save.pokedex.owned and
          game.save.pokedex.owned[def.id])
      local text = owned and entry.text and game.data.text and game.data.text[entry.text]
      local descriptionY = heroY + heroH + spacing.lg
      setColor(theme.colors.textMuted)
      if text then
        local lines = wrappedLines(safeText(text):gsub("[\r\n\v\f]+", " "),
          panelW - spacing.lg * 2)
        local lineHeight = bodyFont:getHeight() + spacing.sm
        for i, line in ipairs(lines) do
          local yy = descriptionY + (i - 1) * lineHeight
          if yy > footerY - lineHeight then break end
          love.graphics.print(line, px + spacing.lg, yy)
        end
      else
        love.graphics.print("Data unknown.", px + spacing.lg, descriptionY)
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
    love.graphics.print(footer, px + spacing.lg, footerY)
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
    setColor(theme.colors.backdrop)
    love.graphics.rectangle("fill", x, y, w, h, h / 2)
    local ratio = clamp(hp / math.max(1, maxHP), 0, 1)
    if ratio > 0 then
      setColor(ratio <= 0.25 and { 0.92, 0.30, 0.28, 1 }
        or ratio <= 0.5 and { 0.96, 0.72, 0.24, 1 }
        or { 0.28, 0.82, 0.48, 1 })
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
    love.graphics.print(truncate(name, nameMax), nameX, y + spacing.sm)
    if level ~= "" then
      setColor(theme.colors.textMuted)
      love.graphics.print(level, levelX, y + spacing.sm)
    end
    local barY = y + spacing.sm + font(fontCache, theme.typography.body):getHeight() + 5
    drawBattleBar(theme, x + spacing.md, barY, w - spacing.md * 2, 8, hp, maxHP)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    love.graphics.print(("HP %d/%d"):format(math.floor(hp), math.floor(maxHP)),
      x + spacing.md, barY + 12)
    local status = battler.shownStatus or mon.status
    if status then
      setColor(theme.colors.accent)
      love.graphics.print(safeText(status):upper(),
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
        love.graphics.print(Strings(label), cx + spacing.sm,
          cy + (cellH - love.graphics.getFont():getHeight()) / 2)
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
          love.graphics.print(truncate(label, labelMax), cx + spacing.sm,
            cy + (cellH - moveFont:getHeight()) / 2)
        else
          love.graphics.print("-", cx + (cellW - moveFont:getWidth("-")) / 2,
            cy + (cellH - moveFont:getHeight()) / 2)
        end
        setColor(theme.colors.textMuted)
        love.graphics.setFont(ppFont)
        love.graphics.print(pp, cx + cellW - spacing.md - ppW,
          cy + (cellH - ppFont:getHeight()) / 2)
      end
    else
      local text = battleMessage(state)
      setColor(theme.colors.text)
      love.graphics.setFont(font(fontCache, theme.typography.body))
      local lines = wrappedLines(text, w - spacing.lg * 2)
      local lineH = love.graphics.getFont():getHeight() + spacing.sm
      for i, line in ipairs(lines) do
        if i > math.max(1, math.floor(contentH / lineH)) then break end
        love.graphics.print(line, x + spacing.lg, y + spacing.md + (i - 1) * lineH)
      end
      if state.msgWaiting or state.msgPrompt then
        setColor(theme.colors.accent)
        love.graphics.print("A  continue", x + w - spacing.lg - 90, y + h - spacing.lg - 14)
      end
    end
  end

  local function drawBattle(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      math.max(1, theme.density.panelMax or 900))
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
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4, theme.radii.lg, theme.radii.lg, 0, 0)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    love.graphics.print(state.kind == "trainer" and "TRAINER BATTLE" or "BATTLE",
      px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    love.graphics.print("LIVE BATTLE", px + panelW - spacing.lg - 82, py + spacing.md + 5)

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
    love.graphics.print("A  select    B  back", px + spacing.lg,
      py + panelH - spacing.sm - 14)
    love.graphics.pop()
  end

  local function drawModern(game, state, kind, viewport, theme, asModal, underKind)
    if not presenterEnabled(kind) then return end
    if kind == "text" then
      drawDialogue(state, viewport, theme)
      return
    end
    if asModal or kind == "choice" or kind == "quantity" then
      drawModalRows(game, state, kind, viewport, theme, underKind)
      return
    end
    if kind == "battle" then
      drawBattle(game, state, viewport, theme)
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
    drawHint(theme, Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8,
      layout.w - theme.spacing.lg * 2)
    love.graphics.pop()
  end

  -- A stack can contain a full rich screen above another rich screen (Party
  -- -> Summary, Pokédex -> DexEntry, Box -> Pokémon list).  Only actual
  -- modal layers should switch to the compact rows card.  Treating every
  -- layer after the first as modal made those screens render an empty
  -- "Nothing here" card and hid the page that was just opened.
  local function isModalLayer(kind)
    return kind == "menu" or kind == "list" or kind == "choice"
      or kind == "quantity" or kind == "text"
  end

  local function drawModernStack(game, layers, viewport)
    local theme = responsiveTheme(currentTheme(), viewport)
    love.graphics.push("all")
    love.graphics.origin()
    for index, layer in ipairs(layers) do
      local underKind = index > 1 and layers[index - 1].kind or nil
      drawModern(game, layer.state, layer.kind, viewport, theme,
        index > 1 and isModalLayer(layer.kind), underKind)
    end
    love.graphics.pop()
  end

  -- TitleState and its menu are flattened into the same classic canvas. A
  -- whole-canvas clear would erase the logo and title Pokémon along with the
  -- menu, so suppress only the ordinary title Menu's draw method. The state
  -- still owns update/input/callbacks, and another mod's custom draw remains
  -- untouched because only an unmodified Menu instance is decorated.
  mod.hooks:wrap("ui.state.decorate", function(next, game, state, model)
    local decorated = next(game, state, model)
    if type(decorated) ~= "table" then decorated = state end
    local under = game and game.stack and game.stack.top and game.stack:top()
    local isTitleUnder = titleClass and under and under.screenId == "TitleState"
      and inherits(classOf(under), titleClass)
    if isTitleUnder and inherits(classOf(decorated), menuClass)
        and type(decorated.titleUiBox) == "table"
        and rawget(decorated, "draw") == nil then
      local originalDraw = decorated.draw
      decorated._gen1ModernTitleMenu = true
      local function drawTitleMenu(self)
        if option("hideOriginalUi", true) ~= false
            and option("menuUi", true) ~= false then
          local layers, complete = presentationStack(game)
          if complete then
            for _, layer in ipairs(layers) do
              if layer.state == self then return end
            end
          end
        end
        return originalDraw(self)
      end
      decorated._gen1ModernTitleDraw = drawTitleMenu
      decorated.draw = drawTitleMenu
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
    if handled ~= true and hide and suppressCanvas and complete and #layers > 0
        and love and love.graphics and ctx and ctx.uiCanvas then
      love.graphics.push("all")
      love.graphics.setCanvas(ctx.uiCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.pop()
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
    if complete and #layers > 0 then
      drawModernStack(game, layers, viewportForTouchControls(game, viewport))
    end
  end, 100)
end

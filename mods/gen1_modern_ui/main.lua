-- Gen1 Modern UI
--
-- A visual-only overhaul for the released gen1recomp mod API.  The game keeps
-- ownership of input, state transitions, and menu callbacks; this mod reads
-- the live top menu state from the render.hud hook and paints a high-resolution
-- presentation over the classic 160x144 composite.  That keeps menu rows
-- supplied by other mods visible without replacing their state objects.

local MOD_ID = "gen1_modern_ui"
local API_VERSION = 1

local DEFAULT_THEME = {
  id = "default",
  name = "Gen1 Modern",
  version = 1,
  colors = {
    backdrop = { 0.025, 0.045, 0.085, 0.82 },
    surface = { 0.075, 0.105, 0.17, 0.98 },
    surfaceRaised = { 0.12, 0.17, 0.27, 1 },
    selected = { 0.20, 0.48, 0.78, 1 },
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

-- Classic screens remain underneath the visual overlay. Keep the modern
-- backdrop almost opaque so their text and borders do not ghost through the
-- presenter, while retaining a small amount of world ambience.
local function setBackdrop(theme)
  local c = theme.colors.backdrop
  love.graphics.setColor(c[1], c[2], c[3], math.max(c[4] or 1, 0.98))
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
    StartMenu = "MENU",
    BagMenu = "ITEMS",
    ShopMenu = "SHOP",
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
  local okLayout, controls = pcall(touch.layout, touch)
  if not okLayout or type(controls) ~= "table" then return viewport end

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
  if inset <= 12 then return viewport end
  -- A landscape phone has a very short safe height; keep the footer above
  -- the controls without allowing a stray custom position to consume the
  -- entire canvas. Portrait uses the measured control edge directly.
  local landscape = w >= h
  local cap = landscape and math.max(110, h * 0.52)
    or math.max(180, h * 0.30)
  inset = math.min(inset, cap)
  local safeH = math.max(1, h - inset)
  local adjusted = {}
  for key, value in pairs(viewport or {}) do adjusted[key] = value end
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
    panelW = math.min(panelW, w * 0.60)
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
  if class == target then return true end
  if type(class) ~= "table" or not target then return false end
  seen = seen or {}
  if seen[class] then return false end
  seen[class] = true
  local mt = getmetatable(class)
  return mt and inherits(mt.__index, target, seen) or false
end

return function(mod)
  local Strings = (mod.ui and mod.ui.Strings) or function(value) return value end
  local themes = { default = copy(DEFAULT_THEME) }
  local themeChoices = { { "Gen1 Modern", "default" } }
  local fontCache = {}
  local imageCache = {}
  local filteredImages = setmetatable({}, { __mode = "k" })
  local animatedImages = setmetatable({}, { __mode = "k" })
  local spriteAnimationOn = true

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

  local function currentTheme()
    return themes[option("theme", "default")] or themes.default
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
      if choice[2] == spec.id then return spec.id end
    end
    themeChoices[#themeChoices + 1] = { theme.name or spec.id, spec.id }
    return spec.id
  end

  mod.exports = {
    version = API_VERSION,
    registerTheme = registerTheme,
    themes = themes,
  }

  mod.options:define({
    { key = "theme", label = "UI THEME", type = "choice",
      choices = themeChoices, default = "default" },
    { key = "density", label = "UI DENSITY", type = "choice",
      choices = { { "AUTO", "auto" }, { "COMPACT", "compact" },
                  { "COMFORTABLE", "comfortable" } }, default = "auto" },
    -- The battle presenter remains available for testing, but is opt-in until
    -- its responsive layout is finished.  Keeping the option visible makes
    -- the WIP status explicit without disrupting the game's native battle UI.
    { key = "battleUiWip", label = "BATTLE UI (WIP)", type = "toggle", default = false },
    { key = "menuUi", label = "MENU UI", type = "toggle", default = true },
    { key = "pokemonUi", label = "POKEMON SCREENS", type = "toggle", default = true },
    { key = "managerUi", label = "MOD MANAGER UI", type = "toggle", default = true },
    { key = "spriteAnimation", label = "SPRITE ANIMATION", type = "toggle", default = true },
  })

  local menuClass = mod.ui and mod.ui.Menu
  local listClass = mod.ui and mod.ui.ListMenu
  local choiceClass = mod.ui and mod.ui.ChoiceBox
  local quantityClass = mod.ui and mod.ui.QuantityBox

  local function kindFor(state)
    if not state then return nil end
    local id = state.screenId
    if state.phase and state.queue and
        (state.kind == "wild" or state.kind == "trainer" or
         state.kind == "link" or state.enemy or state.player) then
      return "battle"
    end
    -- ManagerState is part of the released in-game mod manager.  It is not a
    -- Menu/ListMenu subclass, so identify it by its public screen id rather
    -- than by reaching into the engine's class hierarchy.
    if id == "ManagerState" then return "mod_manager" end
    if id == "Gen3Box" or id == "Gen3BoxMenu" then return "gen3_box" end
    if id == "DexEntryMenu" then return "dex_entry" end
    if id == "OptionsMenu" then return "options" end
    if id == "PartyMenu" then return "party" end
    if id == "SummaryMenu" then return "summary" end
    local class = classOf(state)
    if inherits(class, choiceClass) then return "choice" end
    if inherits(class, quantityClass) then return "quantity" end
    if inherits(class, listClass) then return "list" end
    if inherits(class, menuClass) then return "menu" end
    return nil
  end

  local function topSupported(game)
    local stack = game and game.stack
    local top = stack and stack.top and stack:top()
    local kind = kindFor(top)
    if kind then return top, kind end
    return nil, nil
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
      for _, item in ipairs(state.items or {}) do
        rows[#rows + 1] = {
          label = item.label or item.name or "",
          value = item.right ~= nil and item.right or item.value,
          enabled = item.enabled,
          marker = item.ball,
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

  local function layoutFor(viewport, theme, kind, rowCount)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing or {}
    local density = option("density", "auto")
    local scale = density == "compact" and 0.88 or density == "comfortable" and 1.12 or 1
    local landscape = w > h * 1.2
    -- Touch controls can consume a large fraction of a phone's short
    -- landscape height. Use a denser outer rhythm there, then fit rows to the
    -- available presenter height before falling back to scrolling.
    local gutter = (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale
    local header = (theme.typography.title or 24) +
      (landscape and (spacing.md or 13) or (spacing.lg or 18)) * scale
    local footer = (landscape and (spacing.sm or 9) or (spacing.lg or 18)) * scale
      + (theme.typography.caption or 13)
    local rowHeight = (theme.density.rowHeight or 54) * scale
    local panelMax = theme.density.panelMax or 780
    if landscape then
      panelMax = math.min(panelMax, w * 0.60)
    end
    if landscape and rowCount > 0 then
      local fitHeight = (h - gutter * 2 - header - footer) / rowCount
      -- Keep text comfortably legible, but do not reserve desktop-sized rows
      -- when the touch-safe landscape viewport is short.
      local minLandscapeRow = landscape and 30 or 34
      rowHeight = math.min(rowHeight, math.max(minLandscapeRow * scale, fitHeight))
    end
    local panelW = math.min(w - gutter * 2, panelMax)
    if kind == "menu" or kind == "choice" or kind == "quantity" then
      -- Short action/confirmation menus should read as focused cards in
      -- landscape, not as banners stretched across the whole phone. Longer
      -- list/options screens keep the wider panel calculated from the theme
      -- max.
      panelW = math.min(panelW, (w > h * 1.2) and 720 or 560)
    end
    panelW = math.max(1, panelW)
    local visible = math.max(1, math.floor((h - gutter * 2 - header - footer) / rowHeight))
    visible = math.min(visible, math.max(1, rowCount))
    local contentH = header + footer + visible * rowHeight
    -- Reserve one additional row-height in landscape for wrapped labels,
    -- secondary values, and the extra move/metadata line used by Dex screens.
    -- This applies to every generic menu rather than special-casing one mod.
    if landscape then contentH = contentH + rowHeight end
    local panelH = math.min(h - gutter * 2, contentH)
    panelH = math.max(1, panelH)
    return {
      x = x + (w - panelW) / 2,
      y = y + (h - panelH) / 2,
      w = panelW, h = panelH, rowHeight = rowHeight,
      header = header, footer = footer, visible = visible,
      safeX = x, safeY = y, safeW = w, safeH = h,
      radius = theme.radii and theme.radii.md or 16,
    }
  end

  local function drawHeader(theme, layout, title)
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
      local value = safeText(row.value)
      local valueWidth = value ~= "" and love.graphics.getFont():getWidth(value) or 0
      local maxValueWidth = layout.w * 0.36
      valueWidth = math.min(valueWidth, maxValueWidth)
      local leftWidth = layout.w - (textX - layout.x) - theme.spacing.lg - valueWidth - 16
      if not row.header then
        love.graphics.print(truncate(row.label, math.max(20, leftWidth)),
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

  local function drawManagerOverlay(theme, layout, state)
    local overlay = state.overlay
    if not overlay then return end
    setBackdrop(theme)
    love.graphics.rectangle("fill", layout.safeX, layout.safeY,
      layout.safeW, layout.safeH)
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

  local function drawManager(game, state, viewport, theme)
    local rows, selected, scroll, title = managerRowsFor(game, state)
    local layout = layoutFor(viewport, theme, "mod_manager", #rows)
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
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
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
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local footer = state.notice or (state.screen == "list" and
      "A  open   SELECT  toggle   START  apply" or "A  choose   B  back")
    love.graphics.print(Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8)
    drawManagerOverlay(theme, layout, state)
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
    local panelH = math.min(h - gutter * 2, 520)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local compact = panelH < 380
    local mon = state.mon or {}
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
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
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
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
        { "ID", mon.otId or game.save.player.id or 0 },
        { "OT", mon.ot or game.save.player.name or "RED" },
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

  local function drawGen3Box(game, state, viewport, theme)
    local x, y, w, h = presenterRect(viewport)
    local spacing = theme.spacing
    local gutter = spacing.lg
    local panelW = panelWidthFor(viewport, w - gutter * 2,
      theme.density.panelMax or 780)
    local panelH = math.max(1, h - gutter * 2)
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
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", px, py, panelW, panelH, theme.radii.lg)
    setColor(theme.colors.accent)
    love.graphics.rectangle("fill", px, py, panelW, 4, theme.radii.lg, theme.radii.lg, 0, 0)
    setColor(theme.colors.text)
    love.graphics.setFont(font(fontCache, theme.typography.title))
    love.graphics.print(title, px + spacing.lg, py + spacing.md)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    love.graphics.print(mode == "box" and "A  pick/place   SELECT  party   B  back"
      or "A  pick/place   SELECT  box   B  back", px + spacing.lg,
      py + panelH - footer + 2)

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
    local panelH = math.max(1, h - gutter * 2)
    local px, py = x + (w - panelW) / 2, y + (h - panelH) / 2
    local def = state.def or (state.vanilla and state.vanilla.def) or {}
    local page = state.view or "data"
    local title = safeText(def.name or "POKÃ©DEX")
    local sprite = spriteFor(game, { species = def.id }, state.sprite or
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
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
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
      -- Keep the footer as a hard layout boundary.  Dex move pages can expose
      -- a tenth row (TM/HM); without reserving this space the final row can
      -- collide with the navigation hint on short landscape displays.
      local maxVisible = math.max(1,
        math.floor((footerY - spacing.sm - heroY) / lineGap))
      local visible = math.min(10, remaining, maxVisible)
      for offset = 0, visible - 1 do
        local row = rows[start + offset]
        love.graphics.print(truncate(row, maxW), tx, heroY + offset * lineGap)
      end
      if visible < math.min(10, remaining) then
        setColor(theme.colors.textMuted)
        love.graphics.print("...", tx, footerY - lineGap)
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
      local owned = game.save and game.save.pokedex and game.save.pokedex.owned and
        game.save.pokedex.owned[def.id]
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
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
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

  local function drawModern(game, state, kind, viewport)
    local theme = responsiveTheme(currentTheme(), viewport)
    if kind == "battle" then
      if option("battleUiWip", false) == true then drawBattle(game, state, viewport, theme) end
      return
    end
    if kind == "mod_manager" and option("managerUi", true) == false then return end
    if (kind == "gen3_box" or kind == "dex_entry" or kind == "summary" or kind == "party")
        and option("pokemonUi", true) == false then return end
    if kind ~= "mod_manager" and kind ~= "gen3_box" and kind ~= "dex_entry"
        and kind ~= "summary" and kind ~= "party"
        and option("menuUi", true) == false then return end
    if kind == "mod_manager" then
      drawManager(game, state, viewport, theme)
      return
    end
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
    local rows, selected, scroll, title, footerText = rowsFor(game, state, kind)
    if not rows then return end
    local layout = layoutFor(viewport, theme, kind, #rows)
    scroll = clamp(scroll, 0, math.max(0, #rows - layout.visible))
    selected = clamp(selected, 1, math.max(1, #rows))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visible then scroll = selected - layout.visible end

    love.graphics.push("all")
    love.graphics.origin()
    local backX, backY, backW, backH = fullViewportRect(viewport)
    setBackdrop(theme)
    love.graphics.rectangle("fill", backX, backY, backW, backH)
    setColor(theme.colors.surface)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, layout.radius)
    drawHeader(theme, layout, title)
    drawRows(theme, layout, rows, selected, scroll, game)
    setColor(theme.colors.divider)
    love.graphics.rectangle("fill", layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer, layout.w - theme.spacing.lg * 2, 1)
    setColor(theme.colors.textMuted)
    love.graphics.setFont(font(fontCache, theme.typography.caption))
    local footer = footerText or (kind == "choice" and "A  choose    B  cancel"
      or kind == "quantity" and "A  confirm    B  cancel"
      or "Arrow keys / A  select    B  back")
    love.graphics.print(Strings(footer), layout.x + theme.spacing.lg,
      layout.y + layout.h - layout.footer + 8)
    love.graphics.pop()
  end

  -- render.hud is part of the released API: it runs after the classic
  -- composite, so the overlay can use the entire window while the original
  -- state continues to own all keyboard/controller behavior and callbacks.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    next(game, viewport)
    if not (love and love.graphics) then return end
    spriteAnimationOn = option("spriteAnimation", true) ~= false
    local state, kind = topSupported(game)
    if state and kind then
      drawModern(game, state, kind, viewportForTouchControls(game, viewport))
    end
  end, 100)
end

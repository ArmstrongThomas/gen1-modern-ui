-- Gen1 Modern UI v2 custom-surface example.
--
-- Copy or require this file from the source mod's own entry point. The source
-- mod still owns its state, data collection, selection, and actions. Modern UI
-- supplies an isolated canvas, safe fitting, pointer mapping, effects, and the
-- transactional native fallback.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  local exports = ui and ui.exports or nil
  local supportsV2 = exports and type(exports.registerAdapter) == "function"
    and ((type(exports.supports) == "function"
        and exports.supports("custom_surface", 2))
      or tonumber(exports.surfaceApiVersion) == 2)
  if not supportsV2 then
    return false, "Gen1 Modern UI custom-surface API v2 is unavailable"
  end

  local function call(state, names, ...)
    if type(state) ~= "table" then return false end
    for _, name in ipairs(names) do
      if type(state[name]) == "function" then
        return state[name](state, ...)
      end
    end
    return false
  end

  local function copyCells(source)
    local cells = {}
    for index, cell in ipairs(source or {}) do
      -- Deliberately copy only stable presentation fields. Never return the
      -- source state, methods, timers, or callbacks from model().
      cells[index] = {
        id = cell.id or index,
        name = tostring(cell.name or cell.label or "?????"),
        level = cell.level and tostring(cell.level) or nil,
        discovered = cell.discovered ~= false,
        image = cell.publicImage or cell.image,
        palette = cell.publicPalette or cell.palette,
        registered = cell.registered == true,
      }
    end
    return cells
  end

  local function galleryCells(count)
    local cells = {}
    for index = 1, count do
      cells[index] = {
        id = index,
        name = ("SPECIES %03d"):format(index),
        level = tostring(4 + index),
        discovered = index % 5 ~= 0,
        registered = index % 7 == 0,
      }
    end
    return cells
  end

  -- Gallery fixtures are constructed now. The resulting gallery table is
  -- data-only; galleryCells itself is not stored in the contract.
  local galleryModels = {
    empty = { title = "DEXNAV", cells = {}, selected = 1 },
    sparse = { title = "DEXNAV", cells = galleryCells(1), selected = 1 },
    normal = { title = "DEXNAV", cells = galleryCells(6), selected = 3 },
    full = { title = "DEXNAV", cells = galleryCells(20), selected = 10 },
    overflow = {
      title = "DEXNAV", cells = galleryCells(32), selected = 20,
    },
  }

  local function themeColor(ctx, name, fallback)
    local colors = ctx.theme and ctx.theme.colors or nil
    local value = colors and colors[name] or nil
    return type(value) == "table" and value or fallback
  end

  local function setColor(value)
    love.graphics.setColor(value[1] or 1, value[2] or 1,
      value[3] or 1, value[4] == nil and 1 or value[4])
  end

  local function setFont(font)
    if font then love.graphics.setFont(font) end
  end

  local function fontHeight(font)
    if not font or type(font.getHeight) ~= "function" then return 0 end
    local ok, height = pcall(font.getHeight, font)
    return ok and tonumber(height) or 0
  end

  local function drawImageContained(image, x, y, width, height)
    if not image then return false end
    local ok, imageWidth, imageHeight = pcall(function()
      return image:getDimensions()
    end)
    if not ok or not imageWidth or not imageHeight
        or imageWidth <= 0 or imageHeight <= 0 then
      return false
    end
    local scale = math.min(width / imageWidth, height / imageHeight)
    love.graphics.draw(image,
      math.floor(x + (width - imageWidth * scale) * 0.5 + 0.5),
      math.floor(y + (height - imageHeight * scale) * 0.5 + 0.5),
      0, scale, scale)
    return true
  end

  local function renderSprite(ctx, cell, x, y, width, height)
    local image = cell.image
    if image and ctx.assets and ctx.assets.image then
      image = ctx.assets.image(image) or image
    end
    local function draw()
      if drawImageContained(image, x, y, width, height) then return end
      -- A placeholder keeps this example useful without bundled art.
      love.graphics.rectangle("fill", x + width * 0.25, y + height * 0.2,
        width * 0.5, height * 0.58, 2, 2)
    end

    if cell.discovered == false and ctx.effects
        and ctx.effects.withSilhouette then
      ctx.effects.withSilhouette({ 0, 0, 0, 1 }, draw)
    elseif cell.palette and ctx.effects and ctx.effects.withPalette then
      ctx.effects.withPalette(cell.palette, draw)
    else
      draw()
    end
  end

  local function renderSurface(model, ctx)
    local width, height = ctx.virtual.width, ctx.virtual.height
    local portrait = height > width
    local padding = 8
    local titleFont = ctx.fonts and ctx.fonts.title
    local bodyFont = ctx.fonts and ctx.fonts.body
    local captionFont = ctx.fonts and ctx.fonts.caption
    if fontHeight(titleFont) > height * 0.16 then titleFont = bodyFont end
    if fontHeight(titleFont) > height * 0.16 then titleFont = captionFont end
    local titleHeight = fontHeight(titleFont)
    local captionHeight = fontHeight(captionFont)
    local headerHeight = math.max(24,
      math.min(math.floor(height * 0.22), titleHeight + 8))
    local footerHeight = captionHeight + 6 <= height * 0.10
      and (captionHeight + 6) or 12
    local gridX = padding
    local gridY = headerHeight + padding
    local gridWidth = portrait and (width - padding * 2)
      or math.floor(width * 0.64)
    local gridHeight = portrait and 152
      or (height - gridY - footerHeight - padding)
    local detailsX = portrait and padding or (gridX + gridWidth + padding)
    local detailsY = portrait and (gridY + gridHeight + padding) or gridY
    local detailsWidth = portrait and (width - padding * 2)
      or (width - detailsX - padding)
    local detailsHeight = portrait
      and (height - detailsY - footerHeight - padding)
      or gridHeight
    local columns, rows = 5, 4
    local cellWidth = math.floor(gridWidth / columns)
    local cellHeight = math.floor(gridHeight / rows)
    local visibleCount = columns * rows
    local selected = math.max(1, math.floor(tonumber(model.selected) or 1))
    local frameTime = ctx.frame and tonumber(ctx.frame.time) or 0

    local background = themeColor(ctx, "surface",
      { 0.96, 0.95, 0.86, 1 })
    local raised = themeColor(ctx, "surfaceRaised",
      { 0.86, 0.87, 0.80, 1 })
    local selectedColor = themeColor(ctx, "selected",
      { 0.42, 0.64, 0.88, 1 })
    local text = themeColor(ctx, "text", { 0.06, 0.07, 0.09, 1 })
    local muted = themeColor(ctx, "textMuted", { 0.28, 0.31, 0.35, 1 })
    local divider = themeColor(ctx, "divider", { 0.36, 0.40, 0.44, 1 })
    local accent = themeColor(ctx, "accent", { 0.10, 0.46, 0.62, 1 })

    setColor(background)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setScissor(0, 0, width, headerHeight)
    setFont(titleFont)
    setColor(text)
    love.graphics.print(tostring(model.title or "DEXNAV"), padding,
      math.max(1, math.floor((headerHeight - titleHeight) * 0.5)))
    if captionHeight + 4 <= headerHeight then
      setFont(captionFont)
      setColor(muted)
      love.graphics.printf(("%d FOUND"):format(#(model.cells or {})),
        width - 92, math.max(1, math.floor((headerHeight - captionHeight) * 0.5)),
        84, "right")
    end
    love.graphics.setScissor(0, 0, width, height)

    setColor(divider)
    love.graphics.rectangle("line", gridX, gridY, gridWidth, gridHeight)

    for slot = 1, visibleCount do
      local cell = model.cells and model.cells[slot] or nil
      local column = (slot - 1) % columns
      local row = math.floor((slot - 1) / columns)
      local x = gridX + column * cellWidth
      local y = gridY + row * cellHeight
      local w = column == columns - 1
        and (gridX + gridWidth - x) or cellWidth
      local h = row == rows - 1
        and (gridY + gridHeight - y) or cellHeight

      setColor(slot == selected and selectedColor or raised)
      love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
      setColor(divider)
      love.graphics.rectangle("line", x, y, w, h)

      if cell then
        love.graphics.setScissor(x + 1, y + 1,
          math.max(1, w - 2), math.max(1, h - 2))
        -- Animation uses host-provided frame time. Rounding the bob to a whole
        -- virtual pixel keeps nearest-neighbor sprites crisp.
        local bob = math.floor(math.sin(frameTime * 4 + slot * 0.35) * 2 + 0.5)
        setColor(cell.discovered == false and muted or accent)
        renderSprite(ctx, cell, x + 3, y + 2 + bob, w - 6, h - 13)
        if captionHeight + 2 <= h then
          setFont(captionFont)
          setColor(text)
          love.graphics.printf(tostring(cell.id or slot), x + 2,
            y + h - captionHeight - 1, w - 4, "center")
        end
        love.graphics.setScissor(0, 0, width, height)

        ctx.input.region({
          id = "dexnav-cell-" .. tostring(cell.id or slot),
          x = x,
          y = y,
          w = w,
          h = h,
          action = "open_actions",
          payload = { index = slot, id = cell.id },
        })
      end
    end

    local detail = model.cells and model.cells[selected] or nil
    setColor(raised)
    love.graphics.rectangle("fill", detailsX, detailsY,
      detailsWidth, detailsHeight)
    setColor(divider)
    love.graphics.rectangle("line", detailsX, detailsY,
      detailsWidth, detailsHeight)
    love.graphics.setScissor(detailsX + 1, detailsY + 1,
      math.max(1, detailsWidth - 2), math.max(1, detailsHeight - 2))
    local detailFont = bodyFont
    if fontHeight(detailFont) > detailsHeight * 0.28 then
      detailFont = captionFont
    end
    local detailLineHeight = fontHeight(detailFont)
    if detailLineHeight > 0 and detailLineHeight <= detailsHeight * 0.34 then
      setFont(detailFont)
      setColor(text)
      love.graphics.printf(detail and detail.name or "NO TARGET",
        detailsX + 6, detailsY + 7, detailsWidth - 12, "left")
      setColor(muted)
      if detail then
        love.graphics.printf("LV " .. tostring(detail.level or "--"),
          detailsX + 6, detailsY + 7 + detailLineHeight,
          detailsWidth - 12, "left")
        love.graphics.printf(
          detail.registered and "REGISTERED" or "NOT REGISTERED",
          detailsX + 6, detailsY + 7 + detailLineHeight * 2,
          detailsWidth - 12, "left")
      end
    end
    love.graphics.setScissor(0, 0, width, height)

    if captionHeight + 6 <= footerHeight then
      setFont(captionFont)
      setColor(muted)
      love.graphics.printf("SELECT A CELL  |  B BACK", padding,
        height - footerHeight + 3, width - padding * 2, "left")
    end

    ctx.input.region({
      id = "dexnav-back",
      x = 0,
      y = height - footerHeight,
      w = width,
      h = footerHeight,
      action = "back",
    })

    if ctx.debug and ctx.debug.bounds then
      ctx.debug.bounds("dexnav-grid", gridX, gridY, gridWidth, gridHeight)
      ctx.debug.bounds("dexnav-details", detailsX, detailsY,
        detailsWidth, detailsHeight)
    end

    -- Restore the private-canvas scissor expected by the surface host.
    love.graphics.setScissor(0, 0, width, height)

    -- A surface frame is committed only when the callback explicitly succeeds.
    return true
  end

  mod.exports = mod.exports or {}
  mod.exports.gen1ModernUi = {
    apiVersion = 2,
    surfaces = {
      DexNavGrid = {
        match = function(state)
          return type(state) == "table" and state.screenId == "DexNavGrid"
        end,

        model = function(game, state)
          return {
            title = tostring(state.publicTitle or "DEXNAV"),
            cells = copyCells(state.publicCells),
            selected = tonumber(state.cursor) or 1,
          }
        end,

        layout = {
          default = {
            virtualWidth = 320,
            virtualHeight = 240,
            preset = "L",
          },
          landscape = {
            virtualWidth = 320,
            virtualHeight = 240,
            preset = "L",
          },
          portrait = {
            virtualWidth = 240,
            virtualHeight = 320,
            preset = "M",
          },
          fit = "contain",
          scaleMode = "integer-fit",
        },

        native = {
          -- Use "preserve" for a true overlay. "replace" is transactional:
          -- native uiCanvas drawing is removed only after renderSurface succeeds.
          policy = "replace",
          scope = "uiCanvas",
        },

        render = renderSurface,

        actions = {
          open_actions = function(game, state, payload)
            call(state, { "setCursor", "focus" }, payload and payload.index)
            return {
              type = "modal_overlay",
              title = "DEXNAV ACTIONS",
              dim_background = true,
              dim_opacity = 0.4,
              options = {
                { label = "SEARCH", action = "search", payload = payload },
                { label = "REGISTER", action = "register", payload = payload },
              },
            }
          end,
          search = function(game, state, payload)
            return call(state, { "search", "startSearch" },
              payload and (payload.id or payload.index))
          end,
          register = function(game, state, payload)
            return call(state, { "register", "toggleRegistration" },
              payload and (payload.id or payload.index))
          end,
          back = function(game, state)
            if call(state, { "back", "close", "exit" }) ~= false then
              return true
            end
            return false
          end,
        },

        gallery = {
          name = "DEXNAV 5x4 GRID",
          screenId = "DexNavGrid",
          category = "Integration",
          variant = "custom surface v2",
          models = galleryModels,
        },
      },
    },
  }

  return exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

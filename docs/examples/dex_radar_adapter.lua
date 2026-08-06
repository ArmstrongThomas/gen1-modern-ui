-- Dex Radar -> Gen1 Modern UI adapter template.
-- Copy this into Dex Radar's own entry point. The source mod still owns
-- encounter collection, cursor repeat, selection, and closing the screen.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  local function call(state, names, ...)
    for _, name in ipairs(names) do
      if type(state[name]) == "function" then
        return state[name](state, ...)
      end
    end
    return false
  end

  local function back(game, state)
    if call(state, { "back", "close", "exit" }) ~= false then return true end
    -- Keep this fallback only while the source screen has no public close
    -- method. Prefer adding `state:back()` to Dex Radar before release.
    if game and game.stack and type(game.stack.pop) == "function" then
      game.stack:pop()
      return true
    end
    return false
  end

  local function levelText(row)
    if row.minLv == nil then return "" end
    if row.minLv == row.maxLv or row.maxLv == nil then
      return ("L%s"):format(tostring(row.minLv))
    end
    return ("L%s-%s"):format(tostring(row.minLv), tostring(row.maxLv))
  end

  local function modelFor(game, state)
    local rows = {}
    for _, source in ipairs(state.rows or {}) do
      if source.kind == "header" then
        rows[#rows + 1] = {
          label = source.text or source.title or "AREA",
          header = true,
          enabled = false,
        }
      else
        local value = levelText(source)
        if source.rate ~= nil then
          value = value ~= "" and (value .. "  ") or ""
          value = value .. ("RATE %s"):format(tostring(source.rate))
        end
        rows[#rows + 1] = {
          label = source.name or "?????",
          value = value,
          image = source.image or source.icon or source.iconImage,
          marker = source.seen == true and source.owned == true,
          enabled = true,
        }
      end
    end

    local selected = state.cursor or 1
    if type(state.monIndex) == "table" and state.monIndex[selected] then
      selected = state.monIndex[selected]
    end
    local count = state.ownedN and state.totalN
      and ("  %s/%s"):format(tostring(state.ownedN), tostring(state.totalN)) or ""
    return {
      title = "DEX RADAR" .. count,
      rows = rows,
      index = selected,
      -- The current Dex Radar stores pixel scroll. Source adapters should
      -- publish a row offset when possible; zero is a safe generic fallback.
      scroll = tonumber(state.rowScroll) or 0,
      footer = { "A select", "B back" },
      assets = state.assets,
    }
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      DexRadar = {
        match = function(state)
          return type(state) == "table" and state.screenId == "DexRadar"
            and type(state.rows) == "table"
            and type(state.monIndex) == "table"
            and type(state.cursor) == "number"
            and type(state.mapLabel) == "string"
        end,
        model = modelFor,
        actions = {
          up = function(game, state) return call(state, { "moveCursor", "move" }, -1) end,
          down = function(game, state) return call(state, { "moveCursor", "move" }, 1) end,
          left = function(game, state) return call(state, { "moveCursor", "move" }, -3) end,
          right = function(game, state) return call(state, { "moveCursor", "move" }, 3) end,
          select = function(game, state)
            return call(state, { "select", "choose", "view" })
          end,
          back = back,
        },
        layer = "screen",
        canSuppressNative = true,
      },
    },
  }

  return ui.exports.registerAdapter({ owner = mod.id,
    contract = mod.exports.gen1ModernUi })
end

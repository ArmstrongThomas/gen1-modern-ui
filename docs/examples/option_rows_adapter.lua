-- OptionRows -> Gen1 Modern UI adapter template.
-- Useful for Run Mode, Shiny Pokémon, Quality of Life, and other mods using
-- the public src.ui.OptionRows screen shape.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  local function matches(state)
    if type(state) ~= "table" or type(state.screenId) ~= "string"
        or type(state.rows) ~= "table" or type(state.index) ~= "number" then
      return false
    end
    return state.screenId == "RunModeOptions"
      or state.screenId == "ShinyPokemonOptions"
      or state.screenId == "QualityOfLife"
      or state.screenId:match("Options$") ~= nil
      or state.screenId:match("Settings$") ~= nil
  end

  local function call(state, names, ...)
    for _, name in ipairs(names) do
      if type(state[name]) == "function" then
        return state[name](state, ...)
      end
    end
    return false
  end

  local function model(game, state)
    local rows = {}
    for _, source in ipairs(state.rows or {}) do
      local value = source.value
      if type(value) == "function" then
        local ok, result = pcall(value, game)
        value = ok and result or ""
      end
      rows[#rows + 1] = {
        label = source.label or source.name or "OPTION",
        value = value,
        enabled = source.enabled,
        header = source.header,
        category = source.category,
      }
    end
    return {
      title = state.title or state.screenId or "OPTIONS",
      rows = rows,
      index = state.index or 1,
      scroll = state.scroll or 0,
      footer = { "ARROWS adjust", "A select", "B back" },
    }
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      Options = {
        match = matches,
        model = model,
        actions = {
          up = function(game, state) return call(state, { "move", "moveCursor" }, -1) end,
          down = function(game, state) return call(state, { "move", "moveCursor" }, 1) end,
          left = function(game, state) return call(state, { "adjust", "change" }, -1) end,
          right = function(game, state) return call(state, { "adjust", "change" }, 1) end,
          select = function(game, state) return call(state, { "select", "toggle" }) end,
          back = function(game, state)
            return call(state, { "back", "close", "exit" })
          end,
        },
        layer = "screen",
        canSuppressNative = true,
      },
    },
  }

  return ui.exports.registerAdapter({ owner = mod.id,
    contract = mod.exports.gen1ModernUi })
end

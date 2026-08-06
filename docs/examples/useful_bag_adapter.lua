-- Useful Bag -> Gen1 Modern UI adapter template.
--
-- Shane's Useful Bag keeps BagMenu/ListMenu as the source-owned screen and
-- projects the current pocket into `items`, `title`, `index`, and `scroll`.
-- Add the small public semantic facade shown at the bottom of this file to
-- the source mod, then copy this installer into that mod's entry point.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  local function matches(state)
    return type(state) == "table"
      and state.screenId == "BagMenu"
      and type(state.items) == "table"
      and type(state.__pocketIndex) == "number"
      and type(state.__pocketIds) == "table"
      and type(state.title) == "string"
  end

  local function call(state, names, ...)
    local api = state.gen1ModernUi
    if type(api) == "table" then
      for _, name in ipairs(names) do
        if type(api[name]) == "function" then
          return api[name](api, ...)
        end
      end
    end
    -- These direct names are optional aliases for a source mod that prefers
    -- methods on the ListMenu itself. They must remain semantic source-owned
    -- operations; do not mutate index/items from this adapter.
    for _, name in ipairs(names) do
      if type(state[name]) == "function" then
        return state[name](state, ...)
      end
    end
    return false
  end

  local function model(_, state)
    local rows = {}
    for _, item in ipairs(state.items or {}) do
      rows[#rows + 1] = {
        label = item.label or item.name or "ITEM",
        value = item.right or item.displayValue or item.count,
        enabled = item.enabled,
        -- Keep only presentation data in the model. The source still owns
        -- item IDs, pocket reordering, use/toss flows, and network callbacks.
        source = {
          id = item.value,
          prefix = item.prefix,
          move = item.move,
        },
      }
    end
    return {
      title = state.title or "ITEMS",
      rows = rows,
      index = state.index or 1,
      scroll = state.scroll or 0,
      footer = { "LEFT/RIGHT pocket", "A use", "SELECT move", "B back" },
    }
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      UsefulBag = {
        match = matches,
        model = model,
        actions = {
          up = function(_, state)
            return call(state, { "moveCursor", "move" }, -1)
          end,
          down = function(_, state)
            return call(state, { "moveCursor", "move" }, 1)
          end,
          left = function(_, state)
            return call(state, { "switchPocket", "movePocket", "pocket" }, -1)
          end,
          right = function(_, state)
            return call(state, { "switchPocket", "movePocket", "pocket" }, 1)
          end,
          select = function(_, state)
            return call(state, { "select", "choose", "use" })
          end,
          back = function(_, state)
            return call(state, { "back", "close", "exit" })
          end,
          hover = function(_, state, index)
            return call(state, { "hover", "preview" }, index)
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

-- Source-mod facade example (inside Useful Bag's decorate(list, ...)):
--
-- list.gen1ModernUi = {
--   moveCursor = function(_, delta)
--     -- Route through the same validated ListMenu movement used by vanilla.
--     return list:moveCursor(delta)
--   end,
--   switchPocket = function(_, delta)
--     return switchPocket(list, delta)
--   end,
--   select = function(_) return list:onChoose(list.items[list.index], list) end,
--   back = function(_) return list.game.stack:pop() end,
-- }

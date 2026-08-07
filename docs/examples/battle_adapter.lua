-- Battle source-mod -> Gen1 Modern UI adapter template.
-- Copy this into the battle-owning mod. Publish only documented public fields;
-- Gen1 Modern UI never loads this file from another mod's directory.
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

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      Battle = {
        match = function(state)
          return type(state) == "table"
            and state.screenId == "Battle"
            and type(state.publicBattle) == "table"
        end,

        model = function(game, state)
          local battle = state.publicBattle
          return {
            title = battle.trainer and "TRAINER BATTLE" or "BATTLE",
            rows = battle.rows or {},
            index = battle.menuIndex or 1,
            scroll = battle.scroll or 0,
            footer = { "A select", "B back" },
            phase = battle.phase,
            presentation = battle.presentation,
            isVoxelBattle = battle.isVoxelBattle == true,
            player = battle.player,
            enemy = battle.enemy,
            moves = battle.moves,
            message = battle.message,
            overlays = {
              experience = battle.experience,
              caughtIndicator = battle.caughtIndicator,
              catchRates = battle.catchRates,
            },
            assets = battle.assets,
          }
        end,

        actions = {
          up = function(game, state)
            return call(state, { "moveCursor", "move" }, -1)
          end,
          down = function(game, state)
            return call(state, { "moveCursor", "move" }, 1)
          end,
          left = function(game, state)
            return call(state, { "moveCursor", "move" }, -1)
          end,
          right = function(game, state)
            return call(state, { "moveCursor", "move" }, 1)
          end,
          select = function(game, state)
            return call(state, { "select", "choose", "confirm" })
          end,
          back = function(game, state)
            return call(state, { "back", "cancel", "close" })
          end,
        },

        -- Battle adapters never suppress the source draw. Publish
        -- presentation = "hud"/isVoxelBattle for compact voxel-safe card
        -- placement; ordinary 2D battles use the framed placement. Native
        -- move/capture/send-out animations and source overlays keep running.
        layer = "battle",
        canSuppressNative = false,
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

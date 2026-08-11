-- Adapter-side demonstration of the 0.8.3 unofficial battle-menu tuning.
-- The shipped Modern UI presenter already contains the visual fixes from
-- FelizNavidad-D: readable fixed-width battle cards, native-scene-safe
-- placement, transparent theme alpha handling, and stale intro-text cleanup.
-- This extension demonstrates the currently exposed public seam a
-- battle/voxel author can use to tune card width without forking the whole
-- Modern UI presenter.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    extensions = {
      feliznavidadBattleMenu = {
        match = function(state, kind)
          return kind == "battle"
        end,

        model = function(game, state, kind)
          return {
            battle = {
              -- The value used by the 0.8.3 unofficial card layout. Modern
              -- UI clamps this to its safe presentation range.
              cardWidth = 170,
            },
          }
        end,
        priority = 10,
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

-- Additive Party row styling.
-- The source mod supplies presentation patches only; PartyMenu still owns
-- the live cursor, submenu, callbacks, and all party actions.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    extensions = {
      partyRowColors = {
        match = function(state, kind)
          return kind == "party"
        end,

        model = function(game, state, kind)
          local rows = {}
          for index in ipairs(state.party or {}) do
            rows[index] = {
              background = index % 2 == 0 and "surfaceRaised" or "surface",
              selectedBackground = "selected",
            }
          end
          return { rows = rows }
        end,
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

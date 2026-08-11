-- Additive Gen1 Modern UI extension template.
-- The source mod keeps ownership of PartyMenu/Summary state and callbacks;
-- Modern UI only merges the returned presentation data.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    -- `screens` is optional for an additive-only contract.
    extensions = {
      partyDetails = {
        match = function(state, kind)
          return kind == "party" or kind == "summary"
        end,

        model = function(game, state, kind)
          if kind == "party" then
            local rows = {}
            for index, mon in ipairs(state.party or {}) do
              local gender = mon.gender
              rows[index] = {
                badge = gender == "F" and { text = "♀", color = "accent" }
                  or gender == "M" and { text = "♂", color = "accent" }
                  or nil,
              }
            end
            return { rows = rows }
          end

          local mon = state.mon or {}
          return {
            pages = {
              {
                id = "extra-stats",
                title = "EXTRA STATS",
                rows = {
                  { label = "ABILITY", value = mon.abilityName or "-" },
                  { label = "NATURE", value = mon.natureName or "-" },
                },
              },
            },
          }
        end,

        menu = function(game, mon, context)
          if context and context.battle then return {} end
          return { { id = "details", label = "DETAILS" } }
        end,

        actions = {
          details = function(game, partyState, payload)
            -- Push the source mod's own detail screen here, for example:
            -- Screens.push(game, "MyDetails", payload.mon)
          end,
        },
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

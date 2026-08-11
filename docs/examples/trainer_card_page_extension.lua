-- Additive Trainer Card page.
-- The native TrainerCard remains the state owner. A/B enters this page and
-- A/B closes it; LEFT returns to the built-in card when there are multiple
-- extension pages.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    extensions = {
      trainerNotes = {
        match = function(state, kind)
          return kind == "trainer_card"
        end,

        model = function(game, state, kind)
          local save = game and game.save or {}
          local player = save.player or {}
          local dex = save.pokedex or {}
          local seen = type(dex.seen) == "table" and #dex.seen or "-"
          local owned = type(dex.owned) == "table" and #dex.owned or "-"

          return {
            pages = {
              {
                id = "trainer-notes",
                title = "TRAINER NOTES",
                footer = "A / B  close   L  card",
                rows = {
                  { label = "TRAINER", value = player.name or "RED" },
                  { label = "DEX SEEN", value = seen },
                  { label = "DEX OWNED", value = owned },
                  { label = "PLAY TIME", value = save.playTime or 0 },
                },
              },
            },
          }
        end,
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

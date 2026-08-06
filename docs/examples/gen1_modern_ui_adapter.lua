-- Source-mod-owned Gen1 Modern UI compatibility template.
-- Load this file from the supporting mod's own entry point. Gen1 Modern UI
-- never loads arbitrary files from sibling mods.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  -- Resolve the source-owned file through the source mod's asset API. Passing
  -- the resulting public image reference keeps Gen1 Modern UI from reaching
  -- into this mod's private filesystem.
  local frameAsset = mod.assets and mod.assets.image
    and mod.assets:image("assets/profile-frame.png") or nil
  local frames = {}
  if frameAsset then
    frames["profile-frame"] = { asset = frameAsset }
  end

  -- Only expose stable, public state. Do not return private module objects,
  -- callbacks, or draw functions from model().
  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      ExampleProfile = {
        match = function(state)
          return state.screenId == "ExampleProfile"
        end,
        model = function(game, state)
          return {
            title = "PROFILE",
            rows = state.publicRows or {},
            index = state.cursor or 1,
            scroll = state.scroll or 0,
            footer = { "A select", "B back" },
            details = state.publicDetails,
            assets = { portrait = state.publicPortrait },
          }
        end,
        actions = {
          up = function(game, state) return state:move(-1) end,
          down = function(game, state) return state:move(1) end,
          select = function(game, state) return state:select() end,
          back = function(game, state) return state:back() end,
        },
        layer = "screen",
        canSuppressNative = true,
      },
    },

    -- Theme IDs and frame IDs are namespaced automatically with this mod's
    -- public ID. The frame asset remains owned by this source mod.
    themes = {
      profile = {
        name = "Example Profile",
        colors = {
          surface = { 0.08, 0.10, 0.16, 0.98 },
          text = { 0.95, 0.97, 1.00, 1 },
        },
        frame = {
          style = "pixel",
          asset = mod.id .. ":profile-frame",
          pixelInset = 7,
          pixelScale = 2,
        },
      },
    },
    frames = frames,
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end

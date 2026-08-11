# Source-mod adapter examples

These files are intended to be copied into the supporting mod's own entry
point or loaded from it. Gen1 Modern UI does not discover or execute files from
another mod's directory.

| Example | Current integration | What it covers |
| --- | --- | --- |
| [`useful_bag_adapter.lua`](useful_bag_adapter.lua) | Useful Bag | Six-pocket item projection, counts, pocket switching, and source-owned item actions. |
| [`dex_radar_adapter.lua`](dex_radar_adapter.lua) | Dex Radar | Encounter sections, seen/owned state, levels/rates, cursor movement, and back. |
| [`rby_mmo_adapter.lua`](rby_mmo_adapter.lua) | RBYMMO | Profile, rank, and character selection models, portraits, and semantic navigation. |
| [`battle_adapter.lua`](battle_adapter.lua) | 2D WIDE battle source mods | Explicit WIDE eligibility, public battlers, moves, messages, EXP/caught/catch-rate data, and source-owned actions. |
| [`option_rows_adapter.lua`](option_rows_adapter.lua) | Run Mode, Shiny Pokémon, Quality of Life, and similar settings mods | Public option rows and source-owned setting changes. |
| [`gen1_modern_ui_adapter.lua`](gen1_modern_ui_adapter.lua) | New integrations | A general profile, theme, frame, and image-catalog starter. |
| [`additive_extension.lua`](additive_extension.lua) | New integrations | Additive Party row badges, a Party submenu option, and a Summary detail page without replacing the base presenters. |
| [`party_row_background_extension.lua`](party_row_background_extension.lua) | New integrations | Alternating Party row backgrounds and a focused-row color without rebuilding PartyMenu. |
| [`trainer_card_page_extension.lua`](trainer_card_page_extension.lua) | New integrations | A data-only extra Trainer Card page with rows from the live save. |
| [`feliznavidad_battle_menu_extension.lua`](feliznavidad_battle_menu_extension.lua) | Battle/voxel UI authors | The standalone adapter-side seam for the 0.8.3 unofficial battle-menu layout tuning. |
| [`custom_surface_v2.lua`](custom_surface_v2.lua) | Coordinate-driven integrations | A transactional 5x4 grid with virtual coordinates, frame-time bobbing, silhouette/palette helpers, regions, named actions, a declarative modal, and Gallery fixtures. |

The first three mirror the public fields used by the current legacy bridges.
They are migration templates: the source mod may need to add or rename a
small public action method (`moveCursor`, `back`, `select`, and so on), but the
state/model shape is already aligned with the screens Gen1 Modern UI presents.

Some existing integrations are intentionally not represented as a direct
screen adapter yet:

- Gen 3 Box needs a public grid/slot model rather than a flattened list.
- Useful Dex entry pages need a public entry/details model for their tabs.
- QOL location banners are transient world overlays, not screens. They need a
  future public overlay contract before they can move out of the legacy bridge.
- PokePCFollowers and sprite packs should publish public image/catalog
  references; they do not need to expose private renderer modules.

Until those contracts exist, the current compatibility bridge remains in place
and unknown/malformed adapters safely fall back to native rendering.

## Recommended source-mod pattern

1. Publish only stable, read-only state fields from the source mod.
2. Add semantic methods or callbacks owned by that source mod.
3. Resolve source-owned images with `mod.assets:image(...)`.
4. Copy the relevant example and set `mod.exports.gen1ModernUi`.
5. Register the contract with `ui.exports.registerAdapter`.
6. Test with Gen1 Modern UI absent, disabled, reloaded, and on an unsupported
   API version.

The full field and fallback rules are documented in
[`../CUSTOM_UI_AND_THEME_API.md`](../CUSTOM_UI_AND_THEME_API.md).

## Choose v1 shared presentation or a v2 surface

Keep `apiVersion = 1` for shared `screens` and additive `extensions`. Those
data-first contracts remain backward-compatible and are still the preferred
choice for lists, options, badges, row colors, and extra pages. Moving a
working v1 contract to v2 is unnecessary unless it uses a v2 capability.

Use `apiVersion = 2` and `surfaces` only when the UI needs a true coordinate
system, such as a spatial grid, per-frame animation, or a shader pass. Check
the capability first and leave the source mod's native UI active when it is
unavailable:

```lua
local ui = mod.find("gen1_modern_ui")
local canUseSurface = ui and ui.exports and ui.exports.supports
  and ui.exports.supports("custom_surface", 2)
```

[`custom_surface_v2.lua`](custom_surface_v2.lua) is a complete source-mod
template. It uses a 320x240 landscape / 240x320 portrait virtual canvas and
`integer-fit`, so the host owns monitor bounds, DPI, and pointer transforms.
Its `native.policy = "replace"` is transactional: Modern UI renders to a
private canvas first, and any model/render failure leaves native drawing
untouched. Change the policy to `preserve` for an overlay that should sit above
the source UI.

For a data-first v2 screen that only needs richer details, keep using
`screens` and publish measured fields instead of writing a surface renderer:

```lua
return {
  title = "DEXNAV",
  rows = rows,
  details = {
    custom_fields = {
      columns = 4,
      data = {
        { label = "HP", value = 45 },
        { label = "TOTAL", value = 255, style = "accent" },
      },
    },
    footer_lists = {
      { title = "ENCOUNTER", items = {
        { label = "GRASS", value = "24%" },
      } },
    },
  },
  layout_options = {
    overflow = "shrink_to_fit",
    max_content_height = "100%",
  },
}
```

The shared presenter reduces flexible content inside its stable preset
envelope, anchors `footer_lists` to the card bottom, and keeps pixel-font
scaling on whole steps. A changing row/page must not resize the outer card.
Named surface actions may return a data-only `modal_overlay`; option actions
route back to other names in the surface's `actions` table. See the full API
guide for the modal shape and fallback rules.

## Add to an existing Modern UI screen

Use an `extensions` entry when the screen already exists in Gen1 Modern UI.
This is the important difference from a `screens` adapter: the source mod
publishes only the extra presentation data and lets Modern UI keep the shared
layout and the original state owner.

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 1,
  extensions = {
    genderAndStats = {
      match = function(state, kind)
        return kind == "party" or kind == "summary"
      end,
      model = function(game, state, kind)
        if kind == "party" then
          local rows = {}
          for index, mon in ipairs(state.party or {}) do
            rows[index] = {
              badge = mon.gender == "F" and { text = "♀", color = "accent" }
                or mon.gender == "M" and { text = "♂", color = "accent" }
                or nil,
            }
          end
          return { rows = rows }
        end
        local mon = state.mon or {}
        return {
          pages = {
            { title = "EXTRA STATS", rows = {
              { label = "ABILITY", value = mon.abilityName },
              { label = "NATURE", value = mon.natureName },
            } },
          },
        }
      end,
    },
  },
}
```

`rows[index]` decorates the already-rendered row, so the source mod does not
rebuild Party, the Pokédex, or the PC list. The same pattern works for
Pokédex/list rows by matching `kind == "pokedex"` and returning row badges or
public `image` references. `pages` can extend Summary or a Pokédex entry;
Summary pages are entered after the built-in second page with A/B, while a
Pokédex entry uses its next A/B press. Multiple extension pages use LEFT/RIGHT.

For a party row background, return only the patch for the live row:

```lua
rows[index] = {
  background = index % 2 == 0 and "surfaceRaised" or "surface",
  selectedBackground = "selected",
}
```

For an extra Trainer Card page, return `pages` while matching
`kind == "trainer_card"`. The page is rendered by Modern UI's shared rows
presenter, so the source mod does not copy TrainerCard's portrait, badge grid,
panel geometry, or input handling. See
[`party_row_background_extension.lua`](party_row_background_extension.lua) and
[`trainer_card_page_extension.lua`](trainer_card_page_extension.lua).

## Let a voxel mod own 3D battles

If a source mod owns the complete 3D battle HUD, publish a native-ownership
callback alongside its additive extensions:

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 1,
  battle = {
    native3d = function(game, state)
      return mod.options:get("battleUi") ~= false
    end,
  },
  extensions = {
    -- Optional data-only 2D/compatibility refinements go here.
  },
}
```

When it returns true, Modern UI leaves the whole BattleState stack native,
including field, HUD, dialogue, Party/Bag/choice screens, level-up windows,
cleanup, and battle input remapping. The Modern UI option
`LEAVE 3D BATTLES ALONE` defaults on in the PRESENTERS group. DramaticShape's
released `OverworldBattle.enabled()` export is detected automatically for its
known public mod IDs, so a DramaticShape-dependent source mod does not need to
reach into private files.

## Add a Party submenu option

The released PartyMenu exposes `ui.party.submenu`. Return data-only menu rows
from `menu`, then implement the behavior in the matching `actions` table:

```lua
extensions = {
  quests = {
    match = function(state, kind) return kind == "party" end,
    model = function() return {} end,
    menu = function(game, mon, context)
      return { { id = "quest-data", label = "QUEST DATA" } }
    end,
    actions = {
      ["quest-data"] = function(game, partyState, payload)
        -- Push the source mod's own screen here.
      end,
    },
  },
}
```

The action callback owns validation, state transitions, and side effects. The
Modern UI layer only appends the row and routes the selection back to that
callback. If a target screen is not one of the additive targets, use a normal
`screens` adapter or publish a new stable host hook rather than cloning the
entire Modern UI presenter.

## Useful Bag

[`useful_bag_adapter.lua`](useful_bag_adapter.lua) is the migration template
for Shane's standalone Useful Bag mod. The current release is already
supported by the live legacy bridge: its decorated `BagMenu` exposes a
six-pocket `items` projection with the pocket title, item IDs, labels, and
counts, so Gen1 Modern UI can replace its native draw without taking over
inventory behavior. The template shows the versioned contract form once the
source mod exposes semantic cursor, pocket, select, and back methods.

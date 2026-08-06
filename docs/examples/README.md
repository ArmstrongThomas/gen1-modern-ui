# Source-mod adapter examples

These files are intended to be copied into the supporting mod's own entry
point or loaded from it. Gen1 Modern UI does not discover or execute files from
another mod's directory.

| Example | Current integration | What it covers |
| --- | --- | --- |
| [`useful_bag_adapter.lua`](useful_bag_adapter.lua) | Useful Bag | Six-pocket item projection, counts, pocket switching, and source-owned item actions. |
| [`dex_radar_adapter.lua`](dex_radar_adapter.lua) | Dex Radar | Encounter sections, seen/owned state, levels/rates, cursor movement, and back. |
| [`rby_mmo_adapter.lua`](rby_mmo_adapter.lua) | RBYMMO | Profile, rank, and character selection models, portraits, and semantic navigation. |
| [`option_rows_adapter.lua`](option_rows_adapter.lua) | Run Mode, Shiny Pokémon, Quality of Life, and similar settings mods | Public option rows and source-owned setting changes. |
| [`gen1_modern_ui_adapter.lua`](gen1_modern_ui_adapter.lua) | New integrations | A general profile, theme, frame, and image-catalog starter. |

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

## Useful Bag

[`useful_bag_adapter.lua`](useful_bag_adapter.lua) is the migration template
for Shane's standalone Useful Bag mod. The current release is already
supported by the live legacy bridge: its decorated `BagMenu` exposes a
six-pocket `items` projection with the pocket title, item IDs, labels, and
counts, so Gen1 Modern UI can replace its native draw without taking over
inventory behavior. The template shows the versioned contract form once the
source mod exposes semantic cursor, pocket, select, and back methods.

# UI presentation API

This document describes the released mod API used by `gen1_modern_ui`. The
mod is a visual overlay: it does not require an engine patch, replace states,
or own input.

## `render.hud`

Wrap the additive hook from a mod entry chunk:

```lua
mod.hooks:wrap("render.hud", function(next, game, viewport)
  next(game, viewport) -- exactly once
  -- draw a visual overlay here
end, 100)
```

The hook runs after the finished world/UI composite and before the legacy touch
controls draw. `viewport` is a window-space table containing the current
window dimensions, classic game rectangle, scale, and DPI values. Overlay code
may draw against the full `viewport.width`/`viewport.height`; it does not need
to stay inside the 160x144 game rectangle. `gen1_modern_ui` creates a
presenter-only safe rect above the live virtual controls when they are visible;
the game viewport and input coordinates are never changed.

The hook must remain observational. Do not replace `game.stack` states, mutate
another mod's menu arrays, or invoke menu callbacks from the draw pass.

## Supported state data

The current presenter recognizes these released classes or screen IDs:

- `Menu` and `ListMenu`: reads `state.items`, `state.index`, and `state.scroll`.
- `ChoiceBox`: reads the current choice index.
- `QuantityBox`: reads quantity, maximum, and optional unit price.
- `OptionsMenu`: reads `state.rows` and current selection.
- `PartyMenu`: reads the live party and selected index.
- `ManagerState`: reads live MODS/PROFILES/ERRORS, detail, options,
  permissions, and pending-apply rows.
- `DexEntryMenu`: presents the data/stats/moves pages used by Useful Dex.
- `Gen3Box`: presents the box/party grid from its public mode/cursor/save
  fields while the screen retains all movement and storage actions.
- Battle-state-shaped screens: reads public `kind`, `phase`, `player`,
  `enemy`, move, and message fields for a responsive status/action overlay.
- `SummaryMenu`: reads the selected Pokémon and summary page.

Rows are rebuilt from live state during each HUD pass. Preserve descriptor
identity and unknown fields in any data you add, and use stable `id` fields for
your own bookkeeping. Generic rows can optionally provide `image`, `icon`,
`thumbnail`, `sprite`, or `asset` artwork. Any PC/Box or shop state implemented
with a recognized generic `Menu`/`ListMenu` class may receive that generic list
shell; rich content-specific metadata is not inferred. Unsupported or unknown
screens remain vanilla.

PokÃ©mon presenters resolve front artwork through the runtime's active
`pokemon.sprite` seam, and party icons through `pokemon.icon`, when those
helpers exist; they then fall back to the species record. Enabled replacement
packs therefore appear in the modern presentation, while disabled packs are
not consulted.

Built-in party icon sheets use two vertically stacked frames and are presented
as a looping animation (450 ms per frame) rather than as one tall image.
Gold/Silver battle sprites are complete single-frame pictures and are not
split. Generic image descriptors can opt into sheet animation with `frames = 2`
or an `animation` table; all image paths use nearest filtering and preserve
aspect ratio when fitted into a row or card.

The battle presenter is draw-only and leaves `BattleState` input, timing,
queues, callbacks, and third-party hooks untouched. Its `battleUi` visibility
toggle is independent from the generic `menuUi`, `pokemonUi`, `managerUi`, and
`spriteAnimation` toggles exposed by the mod options.

On portrait phones the presenter scales typography and row density modestly.
Gen 3 Box cells remain square and reserve a caption strip for name/level text;
battle move cells reserve a separate PP column. These are presentation-only
choices and do not alter the underlying menu geometry or callbacks. Battle
move presentation mirrors the public layout state: WIDE is a fixed 2x2 grid;
OG is a vertical list, which keeps three-or-fewer move selections aligned with
the engine's up/down cursor.

## Input behavior

The overlay does not implement pointer handlers. Keyboard and controller input
continues through the original game states and callbacks unchanged. Touch and
click activation are deliberately deferred; the legacy virtual controls and
existing mouse/touch behavior remain the source of truth.

## Theme registration

`gen1_modern_ui` exposes `mod.exports.version = 1`,
`mod.exports.registerTheme(spec)`, and `mod.exports.themes`:

```lua
local ui = mod.find("gen1_modern_ui")
if ui then
  ui.exports.registerTheme({
    id = mod.id .. ":midnight", -- IDs other than default must be namespaced
    name = "Midnight",
    colors = { surface = { 0.04, 0.05, 0.09, 0.98 } },
  })
end
```

Theme specs are merged with the built-in defaults. Supported token groups are
semantic colors, typography sizes, spacing, corner radii, density, and motion.
The presenter uses data only; theme mods cannot provide drawing callbacks.

## Compatibility checklist

- Call `next(game, viewport)` once before drawing.
- Keep the overlay visual-only and leave state transitions to the game.
- Read dynamic rows each frame so other mods' additions remain visible.
- Leave unsupported screens and unknown fields unchanged.
- Do not assume a custom engine build: the manifest currently targets released
  game versions `>=0.0.0-0 <2.0.0` (0.x and 1.x).
- Test with LÖVE 11.5 in both portrait and landscape window sizes.

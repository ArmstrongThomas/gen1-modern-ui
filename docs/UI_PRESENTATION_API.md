# UI presentation API

This document describes the released mod API used by `gen1_modern_ui`. The
mod is a visual overlay: it does not require an engine patch, replace states,
or own input.

## Frame hook sequence

Version 0.4.0 uses three released hooks in order:

1. `render.zones` caches the live `Game` reference for the current frame. This
   is needed because `render.compose` receives a renderer/context, not `Game`.
2. `render.compose` checks that frame's top state and options. It first calls
   `next(renderer, ctx)`, allowing lower-priority compositor mods to inspect or
   take over the untouched canvases. When the result is not `true`, **HIDE
   ORIGINAL UI** is on, and a supported presenter owns the whole visible UI
   layer, it clears only `ctx.uiCanvas` to transparent. It does not clear or
   replace the world canvas. Nested transparent modals and custom capture
   prompts retain the classic canvas until a stack-aware presenter exists.
   Returning the unclaimed result (`false`) lets the engine perform its normal
   composition, scaling, zones, fades, post-processing, and display effects.
3. `render.hud` calls `next(game, viewport)` once, refreshes the live Game
   reference, and draws the modern UI over the composed frame. The engine draws
   `TouchControls` after this hook, keeping mobile controls visible and active.

Conceptually, the released hooks are used like this:

```lua
mod.hooks:wrap("render.zones", function(next, game, zones)
  currentGame = game
  return next(game, zones)
end, 100)

mod.hooks:wrap("render.compose", function(next, renderer, ctx)
  local handled = next(renderer, ctx)
  if handled ~= true and shouldHideClassicUi(currentGame, ctx) then
    clearToTransparent(ctx.uiCanvas)
  end
  return handled -- false continues into the normal engine compositor
end, 100)

mod.hooks:wrap("render.hud", function(next, game, viewport)
  next(game, viewport)
  drawModernUi(game, viewport)
end, 100)
```

`viewport` is a window-space table containing the current window dimensions,
classic game rectangle, scale, and DPI values. Overlay code may draw against
the full `viewport.width`/`viewport.height`; it does not need to stay inside the
160x144 game rectangle. `gen1_modern_ui` creates a presenter-only safe rect
above the live virtual controls when they are visible; the game viewport and
input coordinates are never changed.

The suppression guard is deliberately conservative. If **HIDE ORIGINAL UI**
is off, no supported/enabled presenter owns the visible UI stack, a custom
capture prompt is active, or the graphics/context/UI canvas is unavailable,
the original `ctx.uiCanvas` is left untouched. An unsupported, nested, or
disabled presenter therefore cannot blank required classic context. Unknown
instance-level `draw` replacements also retain the classic canvas; the audited
Modern Bag wrapper is an explicit exception because its live pocket title and
rows are already represented.

These hooks must remain observational. Do not replace `game.stack` states,
mutate another mod's menu arrays, or invoke menu callbacks from a draw hook.

### `render.compose` interoperability

Clearing `ctx.uiCanvas` is cooperative with the engine compositor but cannot be
transparent to every other compositor mod. A mod that reads, clears, or
replaces the same canvas may encounter an already-transparent classic UI canvas
on supported frames, depending on hook priority. Users can disable **HIDE
ORIGINAL UI** to retain the classic canvas. Authors of multiple
`render.compose` consumers should coordinate priorities and avoid assuming the
canvas still contains the original UI.

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

Built-in party icon sheets are cropped to their native rest frame rather than
scaled as one tall image. Authored replacement descriptors can opt into a
looping animation (450 ms per frame by default). Gold/Silver battle sprites are
complete single-frame pictures and are not split. Generic image descriptors
can opt into sheet animation with `frames = 2` or an `animation` table; all
image paths use nearest filtering and preserve aspect ratio when fitted into a
row or card.

The battle presenter is draw-only and leaves `BattleState` input, timing,
queues, callbacks, and third-party hooks untouched. Its `battleUiWip` visibility
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

The overlay does not yet implement pointer handlers. Keyboard and controller
input continues through the original game states and callbacks unchanged.
The engine currently routes gameplay touch input only to `TouchControls`; it
does not expose pointer events to `StateStack`, `Menu`, or `ListMenu`, and real
mouse input is not routed to gameplay in the default configuration.

An experimental mod-only implementation can poll LÖVE pointer state from the
released `input.step` hook, reuse window-space presenter hitboxes, exclude
virtual-control hits, and translate taps into the live state selection plus a
normal Game Boy action. Direct row callbacks are not safe because the owning
state also controls sounds, stack order, validation, and timing. Robust public
support would benefit from an `input.pointer` event and a source-safe
`mod.input` tap/press facade. Full source findings and per-screen interaction
rules are in [`INPUT_AND_INTEROP_AUDIT.md`](INPUT_AND_INTEROP_AUDIT.md).

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
semantic colors, typography sizes, spacing, corner radii, and density. The
presenter uses data only; theme mods cannot provide drawing callbacks.

The built-in choice order is Gen1 Modern (`default`), Modern Glass,
Classic Mono, Pocket Green, Midnight, Midnight Glass, and Frost. Built-in IDs
other than `default` use the `gen1_modern_ui:` namespace. Glass themes retain
their authored alpha; use **HIDE ORIGINAL UI** to remove the classic menu layer
before showing the world through them. Re-registering an existing namespaced
theme refreshes its tokens and label without duplicating the option.

## Compatibility checklist

- Call `next(game, viewport)` once before drawing.
- Keep the overlay visual-only and leave state transitions to the game.
- Clear only `ctx.uiCanvas`, and only when the matching presenter is supported
  and enabled; preserve the normal `render.compose` chain/result.
- Read dynamic rows each frame so other mods' additions remain visible.
- Leave unsupported screens and unknown fields unchanged.
- Do not assume a custom engine build: version 0.4.0 targets released game
  versions `>=0.1.51 <2.0.0` (v0.1.51 and later 0.x, plus 1.x).
- Test with LÖVE 11.5 in both portrait and landscape window sizes.

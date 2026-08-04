# UI presentation API

This document describes the released mod API used by `gen1_modern_ui`. The
mod is a visual overlay: it does not require an engine patch, replace states,
or own input.

## Frame hook sequence

Version 0.6.8 uses four released hooks plus a narrowly scoped class wrapper:

1. The ordinary title `Menu:draw` method is wrapped using its published
   `titleUiBox` marker. On clients exposing `ui.state.decorate`, the same guard
   is also applied to the decorated instance. While the complete title stack
   is supported, the wrapper skips only the native title rows so the shared
   title-art canvas remains intact. It never replaces update/input/callback
   behavior, and restores the original draw whenever an unknown overlay is
   visible.

2. `render.zones` caches the live `Game` reference for the current frame. This
   is needed because `render.compose` receives a renderer/context, not `Game`.
3. `render.compose` snapshots every drawing state from the visible stack base
   through the top. It first calls `next(renderer, ctx)`, allowing
   lower-priority compositor mods to inspect or take over the untouched
   canvases. When the result is not `true`, **HIDE ORIGINAL UI** is on, and
   every visible drawing state has an enabled presenter, it clears only
   `ctx.uiCanvas` to transparent. It does not clear or replace the world
   canvas. An unknown/custom draw, capture prompt, or incomplete presenter
   chain retains the complete classic slice. Returning the unclaimed result
   (`false`) lets the engine perform its normal composition, scaling, zones,
   fades, post-processing, and display effects.
4. `render.hud` calls `next(game, viewport)` once, refreshes the live Game
   reference, and draws the complete modern stack bottom-up over the composed
   frame. The engine draws `TouchControls` after this hook, keeping mobile
   controls visible and active.

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

The presenter marks viewports with visible virtual controls before layout.
`layoutStyle=auto` is the default and leaves the area outside content-sized
cards transparent on desktop and mobile; the Start Menu docks to a compact
card and richer screens grow only when their live content requires it.
`layoutStyle=floating` forces this world-visible behavior for every supported
presenter, including full-card screens such as Party, Trainer Card, Pokédex,
and PC. `layoutStyle=full` is the explicit backdrop-first presentation: it
paints the themed backdrop before drawing that same card. The old
`desktopFloating=false` value is retained only as a migration path for saves
that predate `layoutStyle`; explicit FLOATING always wins, while an older
save whose adaptive setting is still paired with `desktopFloating=false`
keeps its previous full treatment until that legacy toggle is enabled. This
changes only HUD drawing, never the engine viewport or input coordinates.

The title menu is a special shared-canvas case. While the modern title menu is
active, its `titleUiBox` palette marker is temporarily expanded to the full
20x18 title canvas. This keeps the logo, version ribbon, and title PokÃ©mon on a
single deliberate grayscale treatment instead of leaving the native menu's
partial true-color zone behind. The marker is restored when the menu closes or
when either classic-UI suppression toggle is disabled.

Opaque released menu states normally prevent the overworld from being drawn at
all, so clearing `ctx.uiCanvas` alone cannot reveal it. While a supported
presenter is active in a world-visible style, the mod temporarily sets that
state's `isOpaque` flag to `false` during `input.step`, records the original
value, and restores it for Full Screen or any classic/unsupported fallback.
This is a draw-stack presentation adjustment only; the state still owns its
update, input, callbacks, and lifecycle.

The suppression guard is deliberately conservative. If **HIDE ORIGINAL UI**
is off, any visible drawing state lacks a supported/enabled presenter, a custom
capture prompt is active, or the graphics/context/UI canvas is unavailable,
the original `ctx.uiCanvas` is left untouched. A complete recognized modal
chain can be modernized together; an incomplete chain cannot blank required
classic context. Unknown instance- or class-level `draw` replacements also
retain the classic canvas. The audited Modern Bag, Useful Dex entry, and Gen 3
Box adapters are explicit structural exceptions because their live models are
already represented. Released Bill's-PC screens require their verified root in
the full stack. Active overworld-owned UI such as the Pikachu portrait or
poison flash likewise keeps the classic canvas. Additive wrappers around the
released singleton's raw `drawUI` method are allowed so Quality-of-Life
location banners and similar overlays do not disable Start/dialogue
presentation; a replaced world `draw` or foreign overworld still falls back to
classic.

These hooks must remain presentation-only. Do not replace `game.stack` states,
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
- `TextBox`: reads live pages, page/line/glyph progress, waiting, and done state
  to reproduce only text the engine has already revealed.
- `ChoiceBox`: reads the current choice index and pending state.
- `QuantityBox`: reads quantity, maximum, and optional unit price.
- `OptionsMenu`: reads `state.rows` and current selection.
- `PartyMenu`: reads the live party, selected index, healing/swap/TM state,
  current stats, moves/PP, and exact injected submenu rows. Class identity is
  accepted for released direct callers that do not stamp a `screenId`.
- `ManagerState`: reads live MODS/PROFILES/ERRORS, detail, options,
  permissions, and pending-apply rows.
- `DexEntryMenu`: presents the data/stats/moves pages used by Useful Dex.
- `TrainerCard`: reads the live player portrait, name, five-digit trainer ID,
  money, play time, and runtime badge definitions.
- `PokedexMenu`: reads the live list/filter rebuild, selection, seen/owned
  status, and active selected-species artwork.
- `BagMenu`: reads current rows, selection, swap markers, pockets, counts,
  item/machine details, BASE/SELL values, and nested
  action/quantity/confirmation layers.
- Shop and Player-PC item lists: recognized by their released
  `dialogue`/`money` or `messageBox` capabilities and rendered with their live
  money/message and item rows.
- Released Bill's PC: requires the structural `screenId="BoxMenu"` root in the
  full stack, then resolves deposit/withdraw rows through their numeric payload
  and release rows by live row position. The rich detail view is presentation
  only; private action, Summary, TextBox, and Choice states retain ownership.
- `Gen3Box`: presents the box/party grid from its public mode/cursor/save
  fields while the screen retains all movement and storage actions.
- Battle-state-shaped screens: reads public `kind`, `phase`, `player`,
  `enemy`, move, and message fields for a responsive status/action overlay.
- `SummaryMenu`: reads the selected Pokémon and summary page.

`src.link.LinkState` stages (LAN, online, tournament, connection, trade, and
battle handshakes) use a draw-only modern adapter while LinkState retains all
networking and input ownership.

The `minimalUi` option does not change these models. It selects a lower-detail
presentation that keeps the same live rows, selection, prompts, and callbacks
while omitting optional preview/detail panes, then measures the remaining
content again so hidden regions do not leave empty columns or oversized cards.

Dialogue panels reserve up to five wrapped lines plus their prompt strip, with
the same typewriter reveal and callback ownership as the released TextBox.

`panelOpacity` controls backdrop and filled-surface alpha independently from
`foregroundOpacity`, which controls text, borders, dividers, and accents. Both
are percentage values from 0 to 100 and multiply the authored theme alpha.

Rows are rebuilt from live state during each HUD pass. Preserve descriptor
identity and unknown fields in any data you add, and use stable `id` fields for
your own bookkeeping. Generic rows can optionally provide `image`, `icon`,
`thumbnail`, `sprite`, or `asset` artwork. Other PC/Box states implemented with
a recognized generic `Menu`/`ListMenu` class may receive the generic list
shell; rich content-specific metadata is not inferred without a stable
contract. Unsupported or unknown screens remain vanilla.

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

PokePCFollowers registers six-frame `follower_###.png` sheets as one-frame
icon descriptors. The presenter recognizes that path family and crops a 16px
frame for modern icons and previews; the follower mod remains governed by the
normal mod manager enable state.

Gen1 Modern UI settings are presented in expandable Appearance, Navigation,
Presenters, and Advanced categories. This is a presentation layer over the
unchanged flat option schema, so option keys, stored values, and callbacks
remain compatible with existing saves and tools.

The battle presenter is draw-only and leaves `BattleState` input, timing,
queues, callbacks, and third-party hooks untouched. Its `battleUiWip` visibility
toggle is independent from the `layoutStyle`, `panelOpacity`,
`foregroundOpacity`, `startMenuShortcut`, `startMenuFastJump`, `dialogueUi`, generic
`menuUi`, `pokemonUi`, `managerUi`, and `spriteAnimation` toggles exposed by
the mod options.

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

The one intentional shortcut is `startMenuFastJump`: it observes a queued
left/right GB-button edge (including the released touch d-pad) while a
StartMenu is active and moves its cursor by five rows. It does not capture the
touch event or bypass the StartMenu's normal A/B callbacks.

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
- Do not assume a custom engine build: version 0.6.8 targets released game
  versions `>=0.1.51 <2.0.0` (v0.1.51 and later 0.x, plus 1.x).
- Test with LÖVE 11.5 in both portrait and landscape window sizes.

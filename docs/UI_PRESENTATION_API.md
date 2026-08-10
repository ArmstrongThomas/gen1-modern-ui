# UI presentation API

This document describes the released mod API used by `gen1_modern_ui`. The
mod is a visual-first overlay: it does not require an engine patch, replace
states, or own keyboard/controller input and callbacks.

## Frame hook sequence

The current release uses the preferred `screen.render_visible` hook when the host
provides it, with the released `render.compose` path as a conservative fallback,
plus a narrowly scoped class wrapper and the host's source-safe pointer/input
hooks:

1. The ordinary title `Menu:draw` method is wrapped using its published
   `titleUiBox` marker. On clients exposing `ui.state.decorate`, the same guard
   is also applied to the decorated instance. While the complete title stack
   is supported, the wrapper skips only the native title rows so the shared
   title-art canvas remains intact. It never replaces update/input/callback
   behavior, and restores the original draw whenever an unknown overlay is
   visible.

2. `render.zones` caches the live `Game` reference for the current frame. This
   is needed because `render.compose` receives a renderer/context, not `Game`.
3. On hosts exposing `screen.render_visible`, the adapter proof suppresses only
   a supported modern state. The state remains in the stack, continues to
   update, and still receives its normal input. A failed or incomplete proof
   returns the host's original visibility decision.
4. `render.compose` snapshots every drawing state from the visible stack base
   through the top. It first calls `next(renderer, ctx)`, allowing
   lower-priority compositor mods to inspect or take over the untouched
   canvases. When the result is not `true`, **HIDE ORIGINAL UI** is on, and
   every visible drawing state has an enabled presenter, it clears only
   `ctx.uiCanvas` to transparent. It does not clear or replace the world
   canvas. An unknown custom draw, capture prompt, or incomplete presenter
   chain retains the complete classic slice. A registered v2 custom surface is
   handled by a separate private-canvas transaction described below; its
   native layer stays alive until that transaction commits. Returning the unclaimed result
   (`false`) lets the engine perform its normal composition, scaling, zones,
   fades, post-processing, and display effects.
5. `render.hud` calls `next(game, viewport)` once, refreshes the live Game
   reference, and draws the complete modern stack bottom-up over the composed
   frame. The engine draws `TouchControls` after this hook, keeping mobile
   controls visible and active.

Conceptually, the released hooks are used like this:

```lua
mod.hooks:wrap("render.zones", function(next, game, zones)
  currentGame = game
  return next(game, zones)
end, 100)

mod.hooks:wrap("screen.render_visible", function(next, visible, state)
  if shouldHideSupportedState(state) then return false end
  return next(visible, state)
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

For an `apiVersion = 2` surface, the early `screen.render_visible` decision is
always conservative. `render.compose` first keeps native drawing, builds and
copies the source model, renders the surface on a private canvas, verifies the
callback, and only then applies `native.policy = "replace"` to `ctx.uiCanvas`.
`native.policy = "preserve"` never clears the native layer. A failed model or
render transaction has no committed surface and therefore leaves the native
frame untouched.

The presenter marks viewports with visible virtual controls before layout.
`layoutStyle=auto` is the default and leaves the area outside content-sized
cards transparent on desktop and mobile; the Start Menu docks to a compact
card and richer screens use scale-aware width and height budgets when the safe
viewport has room, so larger readability settings reveal more of the available
card without retaining reference-size ceilings.
`layoutStyle=floating` forces this world-visible behavior for every supported
presenter, including full-card screens such as Party, Trainer Card, Pokédex,
and PC. `layoutStyle=full` is the explicit backdrop-first presentation: it
paints the themed backdrop before drawing that same card. The old
`desktopFloating=false` value is retained only as a migration path for saves
that predate `layoutStyle`; explicit FLOATING always wins, while an older
save whose adaptive setting is still paired with `desktopFloating=false`
keeps its previous full treatment until that legacy toggle is enabled. This
changes only HUD drawing, never the engine viewport or input coordinates.

Rich Party, PokÃ©dex, Bag, Shop, and item-detail presenters derive their panel
height from visible rows, detail content, and footer before clamping to the
safe viewport. Dialogue and modal cards use the same content-first rule, so a
large UI scale does not create empty vertical space when font scale is smaller.
Detail columns wrap localized labels, move names, prices, descriptions, and
stat values before using a bounded fallback for text that cannot reflow. The
content-heavy Summary and PokÃ©dex entry cards also cap their width to the
measured data layout instead of inheriting a full rich-panel ceiling.

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
For released `ChoiceBox` states, the input hook aliases LEFT to UP and RIGHT
to DOWN so horizontal YES/NO cards remain navigable without changing the
engine's state or callback implementation.

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
- `MoveLearnMenu`: reads the active replacement list, new move, and cursor;
  the surrounding trying-to-learn and abandon prompts remain native layers.
- `PicBox`: reads the optional image and caption for an aspect-fit picture card.
- `NamingScreen` and semantic Name Rater states: reads the live glyph grid,
  typed glyphs, row/column, case, name length, and optional target nickname.
- `TownMap`: reads map tiles, location markers, selection, fly destinations,
  AREA/nest state, and common party-member marker shapes without owning
  movement or callbacks. When RBY MMO is active, it also consumes the mod's
  public `party()` and `players()` exports to place remote party members at
  their current map location while leaving the MMO roster and navigation
  ownership untouched.
- `QuarantineReport`: reads the prepared recovery lines, offset, and paging
  bound for a content-sized report card.
- Dex Radar `DexRadar`: reads the public encounter rows, species cursor, map
  label, ownership totals, and level/rate visibility flags. Dex Radar retains
  encounter collection, held-input repeat, cursor wrapping, and close behavior;
  the modern adapter supplies only responsive themed drawing and pointer hover.
- `OptionsMenu`: reads `state.rows` and current selection.
- `PartyMenu`: reads the live party, selected index, healing/swap/TM state,
  current stats, moves/PP, and exact injected submenu rows. Class identity is
  accepted for released direct callers that do not stamp a `screenId`.
- `ManagerState`: reads live MODS/PROFILES/ERRORS, detail, options,
  permissions, and pending-apply rows.
- `DexEntryMenu`: presents the data/stats/moves pages used by Useful Dex.
- `TrainerCard`: reads the live player portrait, name, five-digit trainer ID,
  money, play time, and runtime badge definitions.
- RBY MMO `RbyMmoProfile`: reads the public `player` payload for the remote or
  local trainer name, selected sprite, avatar label, profile card, rank points,
  and local money. The selected sprite ID resolves through the host catalog
  and crops its front-facing 16x16 pose. The adapter uses semantic screen IDs
  rather than RBY MMO's private classes.
- RBY MMO `RbyMmoRank`: reads the public `client:ranking()` result and
  `offset`, rendering each row's selected sprite when available, with guarded
  support for `entries`, `rows`, and `isRanked()` so leaderboard updates
  remain owned by RBY MMO.
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

Dialogue panels size to the complete current page envelope while drawing only
the currently revealed glyphs. Ordinary legacy line placement reflows to the
modern width; continuation-gated windows remain bounded by the host's visible
segment. Typewriter reveal and callback ownership remain the same as the
released TextBox.

`panelOpacity` controls backdrop and filled-surface alpha independently from
`foregroundOpacity`, which controls text, borders, dividers, and accents. Both
are percentage values from 0 to 100 and multiply the authored theme alpha.

The readability controls are applied before measurement and layout:

- `uiScale` accepts `AUTO`, the existing 75% through 150% values in 5% steps,
  and high-resolution presets from 175% through 400% in 25% steps. It scales
  spacing, row rhythm, icons, radii, borders, panel limits, and control-hint
  spacing. `AUTO` preserves the released curve through 1920×1080, then resumes
  growing: 2560×1440 resolves to 200%, 3840×2160 to 300%, and a 5120×2784 safe
  viewport to 385%. Landscape uses both dimensions, so ultrawide windows are
  height-limited; every presenter still caps to its safe viewport.
- `fontScale` accepts `AUTO`, 80% through 200% in 5% steps, and 225% through
  400% in 25% steps. It scales the cached title, body, caption, value, and hint
  fonts. Its `AUTO` value keeps the released 200:150 text-to-UI ratio through
  high-resolution growth and may reach 500% on 5K; manual choices remain
  capped at 400%.
- `pixelFont` selects gen1recomp's bundled Plain Pixel face for every one of
  those font roles. This experimental option defaults off. When enabled, it
  requests monochrome hinting and nearest filtering. Plain Pixel's artwork
  uses an 11-row base cell, while its documented 15-point raster steps keep
  the glyph bitmap undistorted; text origins snap to the physical render grid
  so fractional responsive panel coordinates do not soften the glyphs. Its
  multilingual metrics are used directly at that raster size rather than
  rescaled into a system-font line box. The system face remains a missing-glyph fallback and
  replaces Plain Pixel entirely if the engine asset is absent. Its AUTO mode
  derives a whole raster step from the responsive UI size: 1× on ordinary
  desktop windows, 2× at 4K, and 3× on the reported 5120×2784 viewport.
- `dialogueTextScale` accepts Inherit, 110%, 125%, 150%, 175%, and 200%. It
  derives a cached text theme for live dialogue, choices, quantities, and
  confirmation prompts. Padding, row rhythm, radii, and non-raster chrome grow
  with the effective text step, so 200% does not place oversized text in a
  100%-sized shell. Plain Pixel remains on whole 1×–4× raster steps.
- `frameStyle` accepts `THEME`, `PIXEL`, `SOFT`, and `PLAIN`. `THEME` uses the
  active theme's authored frame tokens; the other values select a built-in
  ornamental treatment or disable the frame. Dialogue keeps its content-sized
  footprint stable while text is typing and does not display a speed-up hint.

Larger fonts raise measured row minimums and can promote generic rows to a
two-line layout. Dialogue wraps the currently revealed glyph prefix, so a
scale change never advances or rewrites the TextBox typewriter state. Images
remain aspect-fit and nearest-neighbor filtered. A dependent theme can inspect
`mod.exports.scaleTokens` or call `mod.exports.getScaleTokens(viewport)`; pass
the active safe viewport when resolving an `AUTO` setting outside the built-in
presenter. Its authored typography, spacing, density, and `metrics` tokens are
scaled consistently. `fontMax` remains the manual 4.0 ceiling;
`fontAutoMax` reports the system-font AUTO ceiling of 5.0.

The host parses dialogue before Modern UI sees it. `\f` remains a hard page
boundary and `\v` retains its A/B continuation gate. Once a fragment is
eligible to display, Modern UI treats legacy `\n`/`\v` line placement and the
host's 18-column soft wraps as reflow hints rather than mandatory modern-card
breaks. Existing trailing spaces, hard-wrapped tokens, hyphenation, and
unspaced CJK text are preserved while the visible sentence wraps to the real
card width.

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
toggle is independent from the `battleUiMode`, `layoutStyle`, `panelOpacity`,
`foregroundOpacity`, `startMenuShortcut`, `startMenuFastJump`,
`startMenuQuickView`, `startMenuInset`, `dialogueUi`, generic `menuUi`,
`pokemonUi`, `managerUi`, and `spriteAnimation` toggles exposed by the mod
options. The modern presenter requires explicit proof of a 2D WIDE source
layout. Standard 160x144 battles, false/missing/unknown WIDE markers, and all
3D/voxel or other scene-owned battles retain their complete native/source draw,
HUD, dialogue, child menus, and input behavior. Legacy `battleUiMode` values do
not override that eligibility check and resolve to the same fixed WIDE shell
once eligibility is proven. In a supported WIDE battle, source picture
and animation layers remain live, so send-outs, attacks, capture sequences,
faints, palette flashes, shakes, and fades still render with source timing.
Modern cards track the live animated HP value and retain the current message
across source message holds. Battle adapters enrich the read-only model;
`canSuppressNative` is deliberately ignored for `layer = "battle"`. The
Start-menu quick view is off by default; `startMenuInset` is a
0–50% Navigation setting in 10% steps, with 0% retaining edge docking.

On portrait phones the presenter scales typography and row density modestly.
Gen 3 Box cells remain square and reserve a caption strip for name/level text;
battle move cells reserve a separate PP column. These are presentation-only
choices and do not replace source callbacks. Supported WIDE battle moves use a
source-indexed 2x2 grid and retain native grid navigation before `BattleState`
handles selection, PP, disabled slots, swapping, and turn resolution. Optional
data-only battle overlays may provide
experience/EXP bars, caught indicators, and `P#`/`G#`/`U#` catch-rate values;
their source mod remains responsible for calculating and updating that data.

## Input behavior

Keyboard and controller input continues through the original game states and
callbacks unchanged. The pointer layer is additive and activates when the
host exposes the `input.pointer` middleware event and `mod.input` facade. The
upstream contract is described in [gen1recomp issue #807](https://github.com/bryanthaboi/gen1recomp/issues/807).

The engine gives `TouchControls` first refusal. A pointer that begins on a
virtual D-pad, A, B, START, or SELECT control is not visible to this mod; a
pointer that begins outside those controls remains mod-visible even if it
later crosses them. Focus/visibility recovery can emit `cancelled`, which
clears any captured drag without synthesizing a game action.

Each HUD pass registers hit regions from the same presenter geometry used for
the drawing. Mouse movement over a row, manager confirmation choice, or public
row/column grid cell selects the live cursor without activation. A tap selects
the live target and calls `mod.input:tap(game, "a")`, leaving validation,
sounds, callbacks, stack order, and timing with the owning state. Text and
quantity cards use the same normal action path. Direct row callbacks and
private input queues are never used. A pointer that remains pressed scrolls an
overflowing list in stable row-sized steps when it begins on a row, or drags
the captured panel when it begins on panel chrome; normalized panel offsets
are saved per screen family when released. Multiple touch IDs are tracked
independently.

Hit testing is modal and release-validated. Only the top presentation layer is
interactive; internal Party/Manager prompts register blockers over their
parent rows. The release must still be over the same semantic target, and a
stack change, in-place screen-mode change, rebuilt row model, modal change, or
cancelled lifecycle invalidates the capture. Empty/disabled placeholder rows
never activate, and blank panel space consumes the click without falling
through to global A. This keeps rapid clicking from invoking a callback against
a state or row table that no longer owns the pixels being clicked.

Desktop left-click maps to `A` and right-click maps to `B` globally, including
outside presenter hit regions. Crossing the gesture threshold suppresses that
button action on release.

On desktop, a topmost presenter that needs directional, `select`, or `start`
input can expose a compact action dock. Those controls call only
`mod.input:tap`; they do not invoke state methods directly. The dock is hidden
when native TouchControls are visible so the two control surfaces never
compete.

**TOUCH / CLICK UI** enables taps and pointer capture. **DRAG UI PANELS**
separately enables panel movement and requires the pointer layer. Both
experimental settings default off and gracefully fall back to the previous
behavior on older hosts that do not provide the new hooks. The
`startMenuFastJump` shortcut remains independent: it observes a queued
left/right GB-button edge and moves the Start-menu cursor by five rows.
Side-by-side YES/NO navigation never rewrites that queue: L/R is consumed and
reissued as an atomic source-safe UP/DOWN tap, preventing a remapped direction
from becoming an unowned held button. Mouse-wheel input is not consumed; long
lists currently use captured drag scrolling.
Full source findings and per-screen interaction rules are in
[`INPUT_AND_INTEROP_AUDIT.md`](INPUT_AND_INTEROP_AUDIT.md).

## Theme registration

`gen1_modern_ui` exposes `mod.exports.version = 1`,
`mod.exports.registerTheme(spec)`, `mod.exports.registerFrame(spec)`, and the
public `mod.exports.themes`/`mod.exports.frames` catalogs. A theme or frame
pack can use either direct registration, or publish `themes` and `frames` as
part of its `gen1ModernUi` contract. Direct registration is useful for a
theme-only mod that does not replace a screen. Each table may contain multiple
entries; namespaced frame entries are also added to the PIXEL FRAME option so
users can select them directly:

```lua
local ui = mod.find("gen1_modern_ui")
if ui then
  local frame = mod.assets:image("assets/midnight-frame.png")
  ui.exports.registerFrame({
    owner = mod.id,
    id = "midnight-frame",
    asset = frame, -- public Image/ImageData resolved by this source mod
  })
  ui.exports.registerTheme({
    owner = mod.id,
    id = mod.id .. ":midnight", -- IDs other than default must be namespaced
    name = "Midnight",
    colors = { surface = { 0.04, 0.05, 0.09, 0.98 } },
    frame = {
      style = "pixel",
      asset = mod.id .. ":midnight-frame",
      pixelInset = 7,
      pixelScale = 2,
    },
  })
end
```

New installs start with **Classic Mono**, **PIXEL** framing, and **FRAME 2**.
The experimental **PIXEL ART FONT** toggle defaults off. When enabled it loads
gen1recomp's bundled
`assets/fonts/plainpixel/PlainPixel-Regular.ttf` for every presenter and uses
nearest filtering. The rasterizer constructs the face directly at the closest
authored 15-pixel multiple and snaps text origins to the physical render grid.
Line layout uses the resulting font metrics rather than rescaling the face's
multilingual bounding box.
If an older compatible host does not contain that asset, the presenter falls
back to LÖVE's system font without disabling the UI. The system face also acts
as a fallback for any glyph outside Plain Pixel's extensive language coverage.
Font selection is a user preference rather than a theme token, so every
registered theme can use either face.

Plain Pixel is by Douglas Vautour / Burpy Fresh and is published under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); see the
[font's source page](https://burpyfresh.itch.io/plain-pixel).

Theme specs are merged with the built-in defaults. Supported token groups are
semantic colors, typography sizes, spacing, corner radii, density, ornamental
`frame` geometry, and presentation `metrics` (`border`, `divider`, `icon`, and
`dialogueMinHeight`). A frame can be authored with `style` (`pixel`, `soft`, or
`none`), an optional `asset` PNG, nine-slice `slice` size, pixel-art
`pixelScale` multiplier, source `pixelInset`, destination `width`, `corner`,
`inset`, `margin`, `step`, and `shadow`. Numeric frame geometry follows the
active UI size, while source `slice`, `pixelScale`, and `pixelInset` remain
pixel-art tokens.
Pixel assets are drawn as
nine-slice borders with nearest-neighbor filtering, so their corners remain
crisp while the top/bottom and left/right edge slices repeat along their
respective axes instead of stretching. The `margin` keeps ornamental pixels
outside the content container. The presenter uses data only; theme mods
cannot provide drawing callbacks. All other numeric geometry tokens are
adjusted by `uiScale` before the presenter measures content; typography tokens
use `fontScale`.

For asset-backed pixel frames, `pixelInset` describes the source pixels from
the image's outer edge to the UI boundary. The renderer places the image edge
that many scaled pixels outside the panel, rather than expanding by the whole
transparent slice. This keeps an authored frame snug to the panel while
preserving its deliberate outer decorative space.
The panel surface is painted through the snapped UI rectangle, while the
transparent image inset remains outside that rectangle for authored ornament.
This keeps the content area solid without making the container as large as the
entire PNG bounds.
When the effective frame style is `pixel`, the presenter also suppresses
rounded panel corners and separate top accent strips; the PNG owns that chrome.
Themes may also provide `colors.health` with `track`, `high`, `medium`, `low`,
and `critical` colors. Party, PC, and battle HP bars use those semantic tokens
and keep their numeric HP labels visible so health is not communicated by
color alone.

For example:

```lua
frame = {
  style = "pixel",
  asset = "assets/pixel_frame1.png",
  slice = 24,
  pixelScale = 2,
        pixelInset = 7,
  width = 3,
  corner = 12,
  inset = 2,
  margin = 4,
  step = 4,
  shadow = 2,
},
```

The built-in choice order is Gen1 Modern (`default`), Modern Glass,
Classic Mono, Pocket Green, Midnight, Midnight Glass, Frost, Light, and Dark.
Built-in IDs
other than `default` use the `gen1_modern_ui:` namespace. Glass themes retain
their authored alpha; use **HIDE ORIGINAL UI** to remove the classic menu layer
before showing the world through them. Re-registering an existing namespaced
theme refreshes its tokens and label without duplicating the option.

## Compatibility contract (v1)

Supporting source mods may publish a namespaced, versioned presentation model
through `mod.exports.gen1ModernUi`. Gen1 Modern UI discovers the public export
from known installed integrations and source mods can register an arbitrary
owner explicitly through the public `registerAdapter` export. The model is
read-only presentation data; semantic actions continue to call the source
mod's own state and callbacks.

```lua
local ui = mod.find("gen1_modern_ui")

mod.exports.gen1ModernUi = {
  apiVersion = 1,
  screens = {
    Profile = {
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
  themes = {
    profile = {
      name = "Example Profile",
      colors = { surface = { 0.08, 0.10, 0.16, 0.98 } },
      frame = { style = "pixel", asset = "example_mod:profile-frame" },
    },
  },
  frames = {
    -- Resolve this through the source mod's own mod.assets:image API.
    ["profile-frame"] = { asset = mod.assets:image("assets/profile-frame.png") },
  },
}

if ui and ui.exports and ui.exports.registerAdapter then
  ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end
```

The source mod owns `assets/profile-frame.png` and resolves it through its own
`mod.assets:image` API; its exported frame is namespaced to
`example_mod:profile-frame`, and the theme references that public ID. A source
mod may instead pass another public image/texture reference. A plain string is
reserved for a host-resolved public asset path; it is not interpreted relative
to another mod's private root. Gen1 Modern UI does not load arbitrary sibling
files or private modules. It accepts data-only themes, frames, public
sprite/catalog references, and host-resolved public paths. v1 screen and
extension descriptors reject custom draw/render callbacks and every model
rejects leaked callbacks. Frame PNGs use
the same nearest-neighbor, nine-slice renderer as built-in themes, so source
mods get repeating edges, integer pixel scaling, and the standard seven-pixel
inset behavior.

Screen models may also expose an `assets` catalog containing public image,
texture, sprite-catalog, or host-resolved path references. A row can select an
entry with `image = "portrait"` (or provide the reference directly through
`image`, `icon`, `thumbnail`, `sprite`, or `asset`). The generic presenter
aspect-fits these images, keeps nearest-neighbor filtering, and leaves missing
optional art as a text-only row. This gives source mods reusable portraits,
icons, badges, and animated image descriptors without adding draw callbacks or
custom coordinate systems.

### Transient source notices

The same v1 contract may optionally expose one transient notice without turning
its owner into a HUD renderer. This is intended for brief, non-modal results
such as a completed tool action. The source owns whether a notice exists and
when it expires; Gen1 Modern UI owns the current theme, responsive layout, and
safe placement above virtual controls.

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 1,
  screens = {},
  transient = {
    model = function(game)
      local active = currentNotice()
      if not active then return nil end
      return {
        id = "example_mod:operation",
        title = active.title,
        detail = active.detail,
        severity = active.failed and "error" or "success",
      }
    end,
  },
}
```

`title` is required; `id`, `detail`, and `severity` are optional. Severity is
`info`, `success`, `warning`, or `error`; unknown values become `info`. The
returned model must be data-only. Custom draw callbacks, source-owned theme
lookups, and arbitrary object references are rejected. The host bounds visible
source notices and renders them in deterministic owner order.

After registering the ordinary adapter, a source may call
`isTransientPresentationActive(mod.id)`. If it returns false because Modern UI
is absent, disabled, malformed, or unsupported, the source must retain its own
native fallback. It must never draw both presentations for the same notice.

Missing exports, unsupported API versions, malformed models, source-mod
exceptions, disabled mods, and reload races immediately retain vanilla drawing
for that state. The active adapter cache is refreshed when mods load and when a
public export table is replaced. See the [`examples/README.md`](examples/README.md)
index for the generic, Dex Radar, RBYMMO, and OptionRows source-mod templates.

## Compatibility contract (v2 custom surfaces)

API v2 extends rather than replaces v1. Existing `apiVersion = 1` screens and
extensions retain their data-first renderer and action behavior. An
`apiVersion = 2` contract may use the same shared screens/extensions and may
add `surfaces` when it needs custom coordinates, frame-time animation, or a
shader pass.

Each surface descriptor requires:

- non-empty string ID plus `match(state)`, `model(game, state)`, and
  `render(model, ctx)` functions;
- a data-only virtual `layout`, using `contain` and either `integer-fit` or
  `smooth-fit`;
- an explicit `native.policy` of `replace` or `preserve`, optionally scoped to
  `uiCanvas`;
- optional named `actions`, `input.pointer`, and data-only `gallery` fixtures.

The default virtual canvas and every orientation override are limited to
2048x2048 and four million pixels. Presets are `XS`, `S`, `M`, `L`, `XL`,
`BATTLE_WIDE`, or `VIEWPORT`. The fit resolver caps the output to the safe
monitor rectangle. Pixel fonts retain whole authored scale steps even when
the surface itself must down-fit.

Surface rendering is transactional. Modern UI copies a cycle-free,
function-free model, binds a private canvas, and supplies virtual dimensions,
output bounds, frame `time`/`dt`, theme/font/scale snapshots, scoped
shader/palette/silhouette helpers, input-region collection, and Gallery bounds
diagnostics. The renderer returns `true` to commit. Any match/model/render
exception, invalid model, graphics-state violation, or non-true result discards
the private frame and leaves native UI visible. With `preserve`, a successful
surface is drawn over native UI; with `replace`, the native `uiCanvas` is
removed only after the full frame succeeds.

Pointer and touch regions are declared in the same virtual coordinates used by
the renderer and route to names in `surface.actions`. An action may return a
data-only `modal_overlay` containing labeled options; each option routes to
another named action, so callbacks never enter the model or modal table.
V2 shared-screen descriptors may use the same named-action modal routing;
v1 shared screens continue to accept only the established semantic action set.

API v2 also extends shared data-first detail models without requiring a custom
surface:

- `details.custom_fields = { columns, data }` formats `{ label, value, style }`
  records into measured columns;
- `details.footer_lists` reserves and bottom-anchors titled item lists while
  shrinking the flexible sprite/details region above them;
- `layout_options = { overflow = "shrink_to_fit",
  max_content_height = "100%" }` fits measured content inside a stable preset
  envelope rather than resizing the container as selection/pages change. At
  the minimum whole pixel-font step, compact cells and bounded omission prevent
  impossible content from overlapping the bottom-anchored footer.

The complete descriptor, render-context, modal, and fallback rules are in
[`CUSTOM_UI_AND_THEME_API.md`](CUSTOM_UI_AND_THEME_API.md). The copyable
[`examples/custom_surface_v2.lua`](examples/custom_surface_v2.lua) template
implements a 5x4 grid with host frame timing, effect helpers, virtual input
regions, named actions, and EMPTY through OVERFLOW Gallery fixtures.

## Compatibility checklist

- An independent `render.hud` wrapper calls `next(game, viewport)` once before
  drawing. A v2 surface renderer never calls `next`; Modern UI owns that hook
  chain and invokes the surface on its private canvas.
- Keep the overlay visual-first and leave state transitions and callbacks to
  the game; pointer taps may route through the host's source-safe action API.
- Independent compositor wrappers clear only `ctx.uiCanvas`, and only when the
  matching presenter is supported and enabled. A v2 surface declares
  `native.policy` and never clears a canvas itself.
- Read dynamic rows each frame so other mods' additions remain visible.
- Leave unsupported screens and unknown fields unchanged.
- For a v2 surface, draw only inside the supplied virtual coordinate system,
  return `true` only after the complete frame succeeds, and let Modern UI own
  private-canvas binding and native replacement.
- Exercise every surface Gallery fixture with portrait/landscape, all UI/font
  scale choices, and forced model/render failures before shipping.
- Do not assume a custom engine build: the manifest targets `0.0.0-dev ||
  >=0.1.51 <2.0.0` (`0.0.0-dev` for local engine testing, plus v0.1.51 and
  later 0.x and released 1.x builds).
- Test with LÖVE 11.5 in both portrait and landscape window sizes.

# Gen1 Modern UI

A lightweight `overhaul` mod for released gen1recomp builds. It uses released
UI/render hooks to paint supported menus in high-resolution safe
window space, so portrait phones, landscape tablets, desktop windows, and
ultrawide displays can use their available room instead of being confined to
the original 160x144 layout. It is visual-first: the game remains responsible
for keyboard/controller input, state transitions, and callbacks; pointer taps
use only the host's source-safe action facade.

## Install a release

Download the newest archive from the
[Gen1 Modern UI Releases page](https://github.com/ArmstrongThomas/gen1-modern-ui/releases),
then launch gen1recomp and open **Mods → Import mod .zip**. Select the archive,
confirm the import, and enable the mod under **UI** if needed. The launcher
extracts and installs the package automatically.

For bug reports, compatibility requests, or new UI ideas, please
[open an issue](https://github.com/ArmstrongThomas/gen1-modern-ui/issues) with
your gen1recomp version, screen, resolution/orientation, and reproduction
details.

The manifest points to `ArmstrongThomas/gen1-modern-ui`, so gen1recomp can
check Releases for newer `gen1_modern_ui-<version>.zip` packages and offer
updates from the Mods panel.

## Layout

- `manifest.json` - identity, version range, load order
- `main.lua` - the visual presenter and theme registry

Version 0.8.4 targets `0.0.0-dev || >=0.1.51 <2.0.0`: the released
gen1recomp v0.1.51 and later 0.x releases, the released 1.x line, and the
development engine build for local testing. The packaged mod does not
require a custom engine checkout or a patched binary.

## Input and compatibility

- Keyboard and controller navigation remain vanilla because the overlay does
  not replace states or consume their input.
- TouchControls remain the first refusal for virtual buttons. When the
  default-off **TOUCH / CLICK UI** experiment is enabled on hosts that expose
  `input.pointer` and `mod.input`, supported modern rows and dialogue cards
  accept touch or mouse taps; a tap selects the live row and sends the normal
  source-safe `A` action, so the owning state still runs validation, sounds,
  callbacks, and stack changes. Pointers that begin outside a modern region
  fall through to the next hook.
- Touch or mouse dragging can reposition supported panels when **DRAG UI
  PANELS** is enabled. Offsets are normalized to the viewport and persisted by
  screen family, so the layout remains usable across resolutions. A cancelled
  pointer lifecycle discards its capture without changing game input.
- Mouse movement over a modern row moves the live cursor without activating it.
  This includes categorized UI Settings rows, PC box grid cells, and manager
  confirmation choices. Touch-dragging a list with more rows than fit in the
  card scrolls that live list in stable row-sized steps; dragging panel chrome
  moves the panel instead.
- Only the top modal layer can receive hover/click. Press and release must
  still identify the same live row, and stack changes, in-place mode changes,
  rebuilt row models, or cancellation invalidate the capture. Party/Manager
  prompts block parent rows; empty/disabled rows and blank panel space do not
  synthesize A.
- Desktop left-click sends the source-safe `A` action and right-click sends
  `B`, even outside a modern panel. A mouse gesture that crosses the drag
  threshold does not also activate its button on release.
- Screens that need more than row selection and A/B expose contextual desktop
  buttons for directions, **SELECT**, and **START**. These buttons use the same
  source-safe action facade and stay hidden when native TouchControls are
  visible.
- Side-by-side YES/NO cards translate L/R into atomic UP/DOWN taps. The mod
  never renames a queued directional edge, which prevents an input source from
  being detached and leaving DOWN held after the choice closes.
- **TOUCH / CLICK UI** and **DRAG UI PANELS** are experimental, default off,
  and separately toggleable; panel dragging requires the pointer layer. Hosts
  without the new hooks retain the previous keyboard/controller-only behavior.
- **START MOD MENUS** collects rows appended by other mods and this mod's UI
  settings beneath one Start-menu entry by default. In the grouped submenu,
  highlight any row and press **SELECT** to pin/unpin it on the Start menu.
  Disable grouping in the mod options to keep a flat list.
- In this mod's options screen, press **SELECT** on a focused setting for a
  brief explanation; **SELECT**, **A**, or **B** closes the help card.
- Source-mod compatibility is provided by the versioned
  `mod.exports.gen1ModernUi` contract (`apiVersion = 1`). Supporting mods can
  publish read-only screen models and source-owned semantic actions, then
  register them through `mod.find("gen1_modern_ui").exports`:

  ```lua
  local ui = mod.find("gen1_modern_ui")
  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {}, -- see docs/UI_PRESENTATION_API.md for the full example
    themes = {
      profile = {
        name = "My Theme",
        frame = { style = "pixel", asset = mod.id .. ":frame" },
      },
    },
    frames = {
      frame = { asset = mod.assets:image("assets/frame.png") },
    },
  }
  if ui and ui.exports and ui.exports.registerAdapter then
    ui.exports.registerAdapter({ owner = mod.id,
      contract = mod.exports.gen1ModernUi })
  end
  ```

  Frame and theme IDs are namespaced to the source mod. PNGs use the standard
  nearest-neighbor nine-slice renderer, repeating edge pixels and preserving
  the seven-pixel authored inset. Source mods own their assets and may pass
  public image/texture/catalog references resolved by the source mod instead of
  private paths. Custom draw/render
  callbacks, malformed models, unsupported versions, disabled mods, and
  adapter errors fall back to the native UI. The UI never loads private
  modules or arbitrary files from another mod. See
  [`docs/UI_PRESENTATION_API.md`](../../docs/UI_PRESENTATION_API.md#compatibility-contract-v1)
  and the [adapter examples](../../docs/examples/README.md).

  Custom screen rows may use `image`, `icon`, `thumbnail`, `sprite`, or
  `asset` references. For reuse, expose a public `assets` catalog from the
  model and set a row's `image` to the catalog key. The generic presenter
  aspect-fits public portraits, icons, badges, and animated descriptors with
  nearest filtering; unavailable optional art falls back to the row text.

- The presenter reads the complete visible state stack after the classic
  frame. It does not rebuild hook-provided descriptor tables or call callbacks
  directly.
- **MINIMAL UI** defaults to off so new installs receive the richer Party,
  Pokédex, Bag, Shop, and PC presenters; enable it when a compact list is
  preferred.
- New installs default to **Classic Mono**, **PIXEL** framing, and **FRAME 2**.
  The experimental **PIXEL ART FONT** defaults off. Enabling it applies Plain
  Pixel to all modern presenters with nearest filtering. The face's artwork
  uses an 11-row base cell, while its documented 15-point raster steps keep
  the glyph bitmap undistorted; text origins also snap to the physical render
  grid. Layout uses the selected raster's real line metrics instead of
  rescaling them into a system-font line box. It falls back safely on older game builds that do not ship the asset
  and uses the system face for any missing glyphs.
- The normal UI font remains the host/LÖVE font so the mod stays lightweight.
  Each rendered string is checked against that face's actual glyph coverage;
  only a string containing an unsupported glyph uses the game's Plain Pixel
  fallback. The choice is never cached for the rest of the screen, so ordinary
  Latin rows cannot be switched merely because another row is multilingual.
- OptionRows-based settings screens from Run Mode, Shiny Pokémon, and Quality
  of Life are presented through the same live-row path. Their callbacks and
  input remain owned by the source mod; unknown custom screen shapes stay
  vanilla.
- Dex Radar's stable `DexRadar` screen receives a responsive encounter list
  with section labels, active-palette icons, unseen silhouettes, ownership,
  levels, and rates. Dex Radar continues to own encounter collection, cursor
  wrapping, input repeat, and closing; incomplete future screen models fall
  back to the native renderer.
- RBY MMO's public `RbyMmoProfile` and `RbyMmoRank` screens receive semantic
  profile and leaderboard cards. The adapter reads only their stable screen
  IDs and public player/client payloads, so RBY MMO keeps ownership of network
  requests, scrolling, callbacks, and future screen internals. Its chosen
  overworld sprite is cropped from the host catalog for profile and rank art.
- When RBY MMO is active, its public `party()` and `players()` exports also
  place the remote party member on the modern Town Map at the member's current
  city, with the chosen sprite and display name above the marker plus a
  `Players here` detail. The modern map remains draw-only and falls back
  quietly when the mod is absent or the public payload is unavailable.
- Start-menu mod pins are flushed to the active save as soon as SELECT changes
  them, so direct shortcuts survive a client restart and save-slot reload.
- The presenter decorates `Menu`, `ListMenu`, `ChoiceBox`, `QuantityBox`,
  `TextBox`, `OptionsMenu`, `PartyMenu`, `SummaryMenu`, and the released in-game
  `ManagerState` mod-list/profile/error screens. The manager rows are read
  live, so newly installed mods and other authors' entries appear without a
  per-mod adapter. It also presents the public `DexEntryMenu` and `Gen3Box`
  screen IDs used by Useful Dex and Gen 3 Box. Trainer Card, Pokédex list,
  Bag, Shop-product, Player-PC, Party, and released Bill's-PC Pokémon lists
  have responsive specialized presenters. Plain OptionRows settings screens
  from Run Mode, Shiny Pokémon, Quality of Life, and future screens ending in
  `Options` or `Settings` use the shared high-resolution rows presenter. Battle
  states receive a separate responsive status/action presenter.

### Dialogue and modal stacks

Version 0.6.5 presents ordinary `TextBox` dialogue and attached `Menu`,
`ChoiceBox`, and `QuantityBox` layers as one composition. The text presenter
reconstructs only the glyphs already revealed by the live typewriter state;
the original state still owns reveal speed, waiting, advancement, sounds, and
callbacks. Bag actions, shop quantities, confirmation prompts, and YES/NO
choices can therefore sit above their modern parent without exposing or
blanking a classic layer. If any visible drawing state is unknown, captured,
disabled, or custom-drawn outside an audited adapter, the entire UI slice stays
classic for that frame.

The normal overworld singleton is identity-checked against its released
`draw` method, so its built-in world renderer no longer gets mistaken for a
custom override. Additive `drawUI` wrappers from other mods remain compatible;
the released world draw must still be intact. The title-screen main Menu is
suppressed independently from
its title artwork; this keeps the logo and title Pokémon intact while the live
menu rows receive the same floating desktop presentation as the in-game Start
menu. A custom title draw or unknown overlay restores the complete classic
title stack.

### Original UI suppression

**HIDE ORIGINAL UI** defaults on. Each frame, `render.zones` caches the live
Game, then `render.compose` checks whether every drawing state from the visible
base through the top has a supported, enabled presenter. It lets downstream
compositor hooks inspect the untouched canvases first; only when none takes
over does it clear `ctx.uiCanvas`. Known transparent modals are drawn above
their modern parent; unknown layers and custom input-capture prompts retain
their classic context. The mod
never clears the world canvas. The hook leaves the normal engine scaling,
palette zones, fades, post-processing, and display effects in place.
`render.hud` then draws the modern presentation.

If the state is unsupported, its surface toggle is off, graphics/context data
is unavailable, or **HIDE ORIGINAL UI** is disabled, the UI canvas is left
unchanged. This is the safe fallback and prevents an unfinished or disabled
presenter from blanking the classic interface. The engine draws
`TouchControls` after `render.hud`, so mobile controls remain above the modern
layer and continue to own touch input.

Floating Summary and Pokédex entry presenters validate their live Pokémon
record before the classic canvas is hidden. A screen pushed by the same input
step is synchronized through the screen lifecycle event when the host exposes
it; older clients use the next-step compatibility sweep. If a third-party
wrapper is still initializing, the classic page remains visible instead of
showing a blank frame.

Mods that also inspect, clear, or replace `ctx.uiCanvas` inside
`render.compose` need extra care: on supported frames they may receive or leave
a transparent classic UI canvas while suppression is enabled. Disable **HIDE
ORIGINAL UI** when combining with an incompatible compositor, or coordinate
hook priorities so both mods see the canvas state they expect.

### Layout style and world visibility

**LAYOUT STYLE** controls the presentation behind every supported modern
screen:

- **ADAPTIVE** (default) uses world-visible cards on new installs and keeps
  content-sized panels compact on desktop and mobile.
- **FLOATING** always leaves the rendered world visible around Party,
  Pokédex, Trainer Card, PC, Bag, and other rich presenters.
- **FULL SCREEN** paints the selected theme's backdrop before drawing the same
  presenter, preserving the classic blacked-out presentation when desired.

The old **DESKTOP FLOATING UI** option is retained only for migration. An
older save with that value disabled may keep ADAPTIVE in full treatment until
the legacy option is enabled; choosing FLOATING explicitly always wins.

### Images

Rows may opt into artwork with an `image`, `icon`, `thumbnail`, `sprite`, or
`asset` field. The value may be an already-loaded LÖVE Image/Canvas, a
descriptor containing `image`, or a virtual LÖVE path. Missing optional art
never removes the text row. Manager entries may expose the same fields from
their manifest for an optional mod thumbnail. Existing mods that keep their
images inside a custom `draw` method continue to own that drawing unless an
explicit audited semantic adapter (such as Useful Dex or Gen 3 Box) represents
the complete surface.

For Pokémon artwork, the presenter asks the runtime's sprite/icon resolvers for
the active `pokemon.sprite`/`pokemon.icon` results before falling back to the
base data paths. This means enabled replacement packs such as
`Gold_Silver_Sprites` are reflected in the Dex, Summary, party, and Gen 3 Box
presenters; disabling the pack returns those views to normal art without
changing save data.

The built-in party icon sheets follow the engine's native layout: the presenter
crops the selected rest frame from 16x32/16x96 pose sheets instead of scaling
the entire sheet into a thin strip. Authored replacement icon descriptors may
opt into looping frames at 450 ms per frame. Gold/Silver battle sprites are
complete single-frame pictures and are not split. Other image rows remain
static unless their descriptor opts in with `{ frames = 2 }` (or
`{ animation = { frames = 2, duration = 0.45 } }`). All frames retain nearest
filtering and aspect-ratio-preserving scale.

The Gen 3 Box presenter calculates one shared cell size from the safe viewport,
so box and party grids stay square in both portrait and landscape windows. Box
captions use a dedicated strip beneath each sprite, which keeps names and
levels readable when five columns are squeezed onto a phone.

The Useful Dex moves page advertises `UP/DOWN page` in its footer only when the
live screen reports more than one move page; single-page lists keep the footer
compact.

The Pokédex list keeps the live selection, scroll/filter rows, seen/owned
markers, and Useful Dex rebuilds while adding a selected-species preview.
Trainer Card uses the already-resolved player portrait, shows the canonical
five-digit Trainer ID, money, play time, and badge progress, and supports runtime badge definitions including
optional custom badge art. Party and released Bill's-PC deposit/withdraw lists
show the selected Pokémon's active front sprite, HP/status, current stats, and
live move PP while retaining injected Party action rows. Box records that do
not store calculated stats receive a read-only display calculation; opening the
UI never expands or rewrites the save record. Bag, Shop, and Player-PC
presenters read their current rows and selected item details instead of
replacing their menu factories. Their detail cards work in landscape and
portrait. Item details expose both the base purchase value and the half-price
sell value; TM details also retain move, type, and PP, while key items and HMs
clearly remain unsellable.

**MINIMAL UI** keeps the responsive themed shell, selections, live rows, and
control hints while removing optional Pokédex/Bag/Shop preview panes. Party
retains its compact Pokémon icons and essential level/HP/status data; Bill's-PC
lists use original-style text rows. Both omit the large selected-Pokémon detail
pane. The panel is measured again after those regions are removed, so short
lists do not leave large blank columns or full-height cards. The setting
affects only presentation and does not alter state,
callbacks, menus, or save data.

### Mobile layout

When the game's virtual touch controls are visible, the presenter measures
their current safe-area positions and keeps panels, footers, and move grids
above the controls. The modern backdrop still covers the full safe window, so
the translucent controls sit over a consistent theme instead of exposing a
misaligned classic frame. Portrait windows receive a modest typography/row
scale; landscape action menus and Pokémon/Dex cards use narrow central panels
with full available height, while box screens retain compact square grids. A custom
touch-control
layout is respected because the inset is measured from the live control
positions rather than hard-coded screen coordinates.

### Adaptive floating layout

**LAYOUT STYLE** defaults to **ADAPTIVE**. On Windows, macOS, Linux, and
supported mobile layouts, modern panels leave the surrounding HUD layer
transparent so the independently rendered world remains visible. The Start
Menu becomes a compact content-sized card; larger data screens grow only when
their live content needs the space. Nested choices and quantities float
relative to their parent.

Choose **FLOATING** to force world-visible panels or **FULL SCREEN** to restore
the backdrop-first presentation. **PANEL OPACITY** controls filled surfaces,
while **TEXT / LINE OPACITY** independently controls labels, borders, dividers,
and accents. The old **DESKTOP FLOATING UI** setting is retained only to
migrate existing saves.

### Battle presentation

Battles have an opt-in responsive presenter with enemy/player status cards,
palette-aware HP bars, action buttons, move rows, and battle messages. It is
draw-only: the existing `BattleState` still owns all navigation, timing,
callbacks, and third-party battle hooks. `BATTLE UI MODE` offers `AUTO`,
`2D FRAMED`, and `SCENE HUD`. In the classic 2D path, Modern UI isolates the
native HUD and text methods while retaining the source picture, attack-effect,
send-out, capture, faint, palette, shake, and fade layers. This makes Modern UI
the complete presentation compositor without duplicating battle simulation or
animation timing. WIDE and scene-owned battles keep their native draw path and
use the conservative composition fallback. AUTO uses the framed compositor for
ordinary 2D battles, then switches to compact voxel-safe card placement when
an active scene marker is published.

Source mods may publish a data-only `layer = "battle"` adapter. Its model can
provide public battlers, moves, message text, and data-only `experience`,
`caughtIndicator`, or `catchRates` overlays. Modern UI never calls a source
mod's draw callback; semantic actions and all validation, networking, and
state transitions remain source-owned. If the adapter is missing, malformed,
throws, the battle falls back to the native UI. A battle adapter enriches the
overlay only; its `canSuppressNative` value never suppresses BattleState.

Modern status cards stay present during source-owned effects and follow the
live animated HP value. The last active message is retained during a source
message hold, so attacks and HP drains do not flash a blank panel. Native intro
party-ball animation remains delegated to the host; the compositor supplies a
compact party-status row for the post-faint enemy-party reveal.

The overlay recognizes wild, trainer, link, safari, and scripted battle phases
through their public state fields.
The move presenter uses a source-indexed 2x2 grid in both OG and WIDE battle
layouts. WIDE keeps its native four-direction cursor; OG directional edges are
mapped onto the same grid before BattleState performs the selected move's
normal PP, disabled-slot, callback, and turn validation.

The battle presenter is WIP and disabled by default; leave its option off for
normal play while its responsive layout is stabilized. The mod options expose
independent toggles for the battle overlay, desktop floating layout, dialogue,
generic menus, Pokémon screens, minimal detail mode, the mod manager, and
sprite animation. Turning a surface off leaves the original game presentation visible; turning sprite
animation off freezes animated sheets on their first frame. **HIDE ORIGINAL
UI** is independent of those surface toggles and defaults on; it suppresses the
classic UI only when the corresponding modern presenter is enabled.

## Theme packs

The UI theme option ships with nine lightweight built-ins:

- **Gen1 Modern** — the stable, opaque default.
- **Modern Glass** — the default palette with the world visible beneath it.
- **Classic Mono** — a crisp paper-and-ink take on the original UI.
- **Pocket Green** — a classic handheld-inspired green palette.
- **Midnight** and **Midnight Glass** — modern violet dark variants.
- **Frost** — a bright modern theme with a translucent cool backdrop.
- **Light** — a simple high-contrast light palette.
- **Dark** — a simple high-contrast dark palette.

Opaque themes prioritize maximum contrast. Glass themes intentionally show
the independently rendered world through their backdrop and panels; they work
best with **HIDE ORIGINAL UI** enabled so the classic menu is removed first.
All themes are token tables merged once at startup and add no assets, shaders,
canvases, or per-theme rendering branches.

For the complete source-mod contract, including screen models, semantic
actions, public image catalogs, theme packs, frame packs, and fallback rules,
see [`docs/CUSTOM_UI_AND_THEME_API.md`](../../docs/CUSTOM_UI_AND_THEME_API.md).
Current integration templates are listed in
[`docs/examples/README.md`](../../docs/examples/README.md).

Theme mods should depend on `gen1_modern_ui`, resolve their own image assets
with `mod.assets:image`, then register a data-only token/frame pack from their
entry chunk. A mod can register any number of themes and frames;
`registerFrame` namespaces an unqualified frame ID with the source mod ID,
adds it to the PIXEL FRAME selector, and accepts the resulting public image
object:

```lua
return function(mod)
  local base = mod.find("gen1_modern_ui")
  if not base then return end
  local frame = mod.assets:image("assets/midnight-frame.png")
  base.exports.registerFrame({
    owner = mod.id,
    id = "midnight-frame",
    asset = frame,
  })
  base.exports.registerTheme({
    owner = mod.id,
    id = mod.id .. ":midnight",
    name = "Midnight",
    colors = {
      surface = { 0.04, 0.05, 0.09, 0.98 },
      selected = { 0.35, 0.20, 0.72, 1 },
    },
    frame = {
      style = "pixel",
      asset = mod.id .. ":midnight-frame",
      pixelInset = 7,
      pixelScale = 2,
    },
  })
end
```

Themes may override semantic colors, typography sizes, spacing, radii, density,
and the ornamental `frame` group. Frame tokens include `style` (`pixel`, `soft`,
or `none`), an optional nine-slice `asset` PNG, `slice`, integer `pixelScale`,
source `pixelInset`, `width`, `corner`, `inset`, `margin`, `step`, and
`shadow`; destination frame geometry follows UI scaling except for the source
`slice`, `pixelScale`, and `pixelInset` tokens. `pixelInset` is the source-pixel distance from the outer image edge to
the UI boundary; the image edge is placed that many scaled pixels outside the
panel. Pixel
assets use nearest-neighbor filtering, keep their corners crisp while repeating
their top/bottom and left/right edge slices along their respective axes, and
`margin` keeps decorative pixels outside the content container. The **UI FRAME
STYLE** option can select the theme's frame,
a built-in pixel or soft treatment, or a plain panel; **PIXEL FRAME** selects
one of the three shipped PNG borders, while **PIXEL FRAME SCALE** selects a
1X–4X multiplier for authored pixel frames. Drawing callbacks are
intentionally not part of the theme contract.
Themes can also provide `colors.health` tokens for `track`, `high`, `medium`,
`low`, and `critical`; Party, PC, and battle presenters use them for HP bars
while keeping numeric HP labels visible.

The built-in options expose the selected theme and row density in the mod
options menu. Theme IDs other than `default` must be namespaced with the
registering mod ID.

## Development

The supported local runtime is LÖVE 11.5. A source checkout is useful for
development and tests, but is not required by players who install the packaged
mod in a released game.

1. Install LÖVE 11.5 and keep `love.exe` on `PATH` (or use its full path).
2. From a game source checkout, start the developer runtime with
   `POKEPORT_DEV=1 love-11.5.exe .` (PowerShell: `$env:POKEPORT_DEV="1"; &
   "C:\\Program Files\\LOVE\\love.exe" .`).
3. Copy or sync `mods/gen1_modern_ui` into the launcher mod directory, then
   press F5 to hot-reload after edits. Restart the game if the mod was newly
   installed.
4. Run `python tools/modkit.py lint mods/gen1_modern_ui` and, when LuaJIT is
   installed, `python tools/modkit.py validate gen1_modern_ui --strict`.
5. Run `python tools/modkit.py pack mods/gen1_modern_ui` to create a release
   archive.

For local smoke tests, the launcher reads unpacked mods from
`%APPDATA%\pokemon-love2d\mods`. From PowerShell, sync this mod directly into
that tree:

```powershell
$source = (Resolve-Path "mods/gen1_modern_ui").Path
$target = Join-Path $env:APPDATA "pokemon-love2d\mods\gen1_modern_ui"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
```

From Windows Explorer, you can double-click the repository-root
`sync_gen1_modern_ui.cmd` to sync the folder and create a launcher-ready
`gen1_modern_ui-<version>.zip` in the project root. It uses the portable build
script so `manifest.json` is the first root entry and every ZIP path uses `/`,
which is safe for both desktop and mobile importers.

Restart the game after syncing so the mod loader discovers the updated entry
chunk. Keep `manifest.json` and `main.lua` directly inside the mod folder.

When LuaJIT or LÖVE 11.5 is unavailable, syntax checks and `modkit lint` still
provide useful preflight coverage, but strict validation and visual smoke tests
must run on a developer machine or CI host with those tools installed.

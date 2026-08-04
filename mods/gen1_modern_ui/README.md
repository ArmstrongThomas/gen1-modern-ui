# Gen1 Modern UI

A lightweight `overhaul` mod for released gen1recomp builds. It uses released
UI/render hooks to paint supported menus in high-resolution safe
window space, so portrait phones, landscape tablets, desktop windows, and
ultrawide displays can use their available room instead of being confined to
the original 160x144 layout. It is visual-only: the game remains responsible
for input, state transitions, and callbacks.

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

Version 0.6.1 targets `>=0.1.51 <2.0.0`: gen1recomp v0.1.51 and later 0.x
releases plus the released 1.x line. The packaged mod does not require a
custom engine checkout or a patched binary.

## Input and compatibility

- Keyboard and controller navigation remain vanilla because the overlay does
  not replace states or consume input.
- Touch and click activation remain owned by the engine. The mod adds one
  compatibility-safe shortcut: left/right on the released touch d-pad (or the
  equivalent keyboard/controller direction) jumps five rows in the Start menu.
- In this mod's options screen, press **SELECT** on a focused setting for a
  brief explanation; **SELECT**, **A**, or **B** closes the help card.
- The presenter reads the complete visible state stack after the classic
  frame. It does not rebuild hook-provided descriptor tables or call callbacks
  directly.
- The presenter leaves unknown custom screens vanilla; explicit adapters are
  added only for screens with a stable public state contract.
- The presenter decorates `Menu`, `ListMenu`, `ChoiceBox`, `QuantityBox`,
  `TextBox`, `OptionsMenu`, `PartyMenu`, `SummaryMenu`, and the released in-game
  `ManagerState` mod-list/profile/error screens. The manager rows are read
  live, so newly installed mods and other authors' entries appear without a
  per-mod adapter. It also presents the public `DexEntryMenu` and `Gen3Box`
  screen IDs used by Useful Dex and Gen 3 Box. Trainer Card, Pokédex list,
  Bag, Shop-product, Player-PC, Party, and released Bill's-PC Pokémon lists
  have responsive specialized presenters. Battle states receive a separate
  responsive status/action presenter.

### Dialogue and modal stacks

Version 0.6.1 presents ordinary `TextBox` dialogue and attached `Menu`,
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

Mods that also inspect, clear, or replace `ctx.uiCanvas` inside
`render.compose` need extra care: on supported frames they may receive or leave
a transparent classic UI canvas while suppression is enabled. Disable **HIDE
ORIGINAL UI** when combining with an incompatible compositor, or coordinate
hook priorities so both mods see the canvas state they expect.

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
five-digit Trainer ID, and supports runtime badge definitions including
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

Battles have a responsive overlay with enemy/player status cards, live HP
bars, replacement sprites, action buttons, move rows, and battle messages. It
is draw-only: the existing `BattleState` still owns all navigation, timing,
callbacks, and third-party battle hooks. The overlay recognizes wild, trainer,
link, safari, and scripted battle phases through their public state fields.
The move presenter follows the active battle layout: WIDE keeps the native 2x2
cursor (including empty slots), while OG uses a vertical list so fewer-than-
four moves retain the engine's up/down selection order.

The battle presenter is WIP and disabled by default; leave its option off for
normal play while its responsive layout is stabilized. The mod options expose
independent toggles for the battle overlay, desktop floating layout, dialogue,
generic menus, Pokémon screens, minimal detail mode, the mod manager, and
sprite animation. Turning a surface off leaves the original game presentation visible; turning sprite
animation off freezes animated sheets on their first frame. **HIDE ORIGINAL
UI** is independent of those surface toggles and defaults on; it suppresses the
classic UI only when the corresponding modern presenter is enabled.

## Theme packs

The UI theme option ships with seven lightweight built-ins:

- **Gen1 Modern** — the stable, opaque default.
- **Modern Glass** — the default palette with the world visible beneath it.
- **Classic Mono** — a crisp paper-and-ink take on the original UI.
- **Pocket Green** — a classic handheld-inspired green palette.
- **Midnight** and **Midnight Glass** — modern violet dark variants.
- **Frost** — a bright modern theme with a translucent cool backdrop.

Opaque themes prioritize maximum contrast. Glass themes intentionally show
the independently rendered world through their backdrop and panels; they work
best with **HIDE ORIGINAL UI** enabled so the classic menu is removed first.
All themes are token tables merged once at startup and add no assets, shaders,
canvases, or per-theme rendering branches.

Theme mods should depend on `gen1_modern_ui`, then register a data-only token
pack from their entry chunk:

```lua
return function(mod)
  local base = mod.find("gen1_modern_ui")
  if not base then return end
  base.exports.registerTheme({
    id = mod.id .. ":midnight",
    name = "Midnight",
    colors = {
      surface = { 0.04, 0.05, 0.09, 0.98 },
      selected = { 0.35, 0.20, 0.72, 1 },
    },
  })
end
```

Themes may override semantic colors, typography sizes, spacing, radii, and
density. Drawing callbacks are intentionally not part of the theme contract.

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

# Gen1 Modern UI

A lightweight `overhaul` mod for released gen1recomp builds. It uses the
released `render.hud` hook to paint supported menus in high-resolution safe
window space, so portrait phones, landscape tablets, desktop windows, and
ultrawide displays can use their available room instead of being confined to
the original 160x144 layout. It is visual-only: the game remains responsible
for input, state transitions, and callbacks.

## Layout

- `manifest.json` - identity, version range, load order
- `main.lua` - the visual presenter and theme registry

The manifest targets `>=0.0.0-0 <2.0.0`, covering released 0.x and 1.x builds.
The packaged mod does not require a custom engine checkout or a patched binary.

## Input and compatibility

- Keyboard and controller navigation remain vanilla because the overlay does
  not replace states or consume input.
- Touch and click activation are intentionally deferred; the existing game
  touch controls and pointer behavior remain the source of truth.
- The presenter reads the live top menu state after the classic frame. It does
  not rebuild hook-provided descriptor tables or call callbacks directly.
- The presenter leaves unknown custom screens vanilla; explicit adapters are
  added only for screens with a stable public state contract.
- The presenter decorates `Menu`, `ListMenu`, `ChoiceBox`, `QuantityBox`,
  `OptionsMenu`, `PartyMenu`, `SummaryMenu`, and the released in-game
  `ManagerState` mod-list/profile/error screens. The manager rows are read
  live, so newly installed mods and other authors' entries appear without a
  per-mod adapter. It also presents the public `DexEntryMenu` and `Gen3Box`
  screen IDs used by Useful Dex and Gen 3 Box. PC/Box and shop screens that
  use a generic `Menu`/`ListMenu` shell receive the generic list overlay;
  content-specific metadata such as money, shop totals, or a third-party
  custom drawing pipeline is not inferred. Battle states receive a separate
  responsive status/action presenter; dialogue remains vanilla for now.

### Images

Rows may opt into artwork with an `image`, `icon`, `thumbnail`, `sprite`, or
`asset` field. The value may be an already-loaded LÖVE Image/Canvas, a
descriptor containing `image`, or a virtual LÖVE path. Missing optional art
never removes the text row. Manager entries may expose the same fields from
their manifest for an optional mod thumbnail. Existing mods that keep their
images inside a custom `draw` method continue to own that drawing.

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
independent toggles for the battle overlay, generic
menus, PokÃ©mon screens, the mod manager, and sprite animation. Turning a
surface off leaves the original game presentation visible; turning sprite
animation off freezes animated sheets on their first frame.

## Theme packs

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

Themes may override semantic colors, typography sizes, spacing, radii,
density, and motion tokens. Drawing callbacks are intentionally not part of
the theme contract.

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
`gen1_modern_ui-<version>.zip` in the project root.

Restart the game after syncing so the mod loader discovers the updated entry
chunk. Keep `manifest.json` and `main.lua` directly inside the mod folder.

When LuaJIT or LÖVE 11.5 is unavailable, syntax checks and `modkit lint` still
provide useful preflight coverage, but strict validation and visual smoke tests
must run on a developer machine or CI host with those tools installed.

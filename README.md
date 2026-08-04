# Gen1 Modern UI

Standalone high-resolution UI overhaul mod for released
[gen1recomp](https://github.com/bryanthaboi/gen1recomp) builds.

This repository contains only the mod and its documentation. It does not
modify the game executable or require a custom engine checkout at runtime.
Version 0.6.8 requires gen1recomp v0.1.51 or newer (and remains compatible
with the released 1.x line).

## Install the latest release

1. Download the newest `gen1_modern_ui-<version>.zip` from the
   [Releases page](https://github.com/ArmstrongThomas/gen1-modern-ui/releases).
2. Launch gen1recomp and open the **Mods** tab.
3. Choose **Import mod .zip**, select the downloaded archive, and confirm the
   import.
4. Enable **Gen1 Modern UI** under the **UI** section if it is not already
   enabled, then restart the game if prompted.

The launcher handles extraction and installation; users do not need to unpack
the archive manually. Windows users can also use `sync_gen1_modern_ui.cmd` when
working from a source checkout.

## Updates

The mod manifest advertises this repository as
`ArmstrongThomas/gen1-modern-ui`, and every release includes the matching
`gen1_modern_ui-<version>.zip` asset. This lets gen1recomp show the mod's
available versions and offer updates from its Mods panel. The same release
shape is compatible with the community
[gen1recomp mod index](https://github.com/bryanthaboi/gen1recomp-mod-index)
when the listing is enabled there.

## Highlights

- Responsive portrait and landscape menus with content-sized safe-window
  layouts. Compact panels shrink to their visible labels instead of reserving
  large empty regions, including when **MINIMAL UI** is enabled.
- Adaptive floating panels keep the world visible on desktop and mobile. Use
  **LAYOUT STYLE** to choose Adaptive, Floating, or Full Screen presentation.
  Adaptive and Floating keep the world rendered behind Party, Pokédex, Trainer
  Card, PC, and other rich screens; Full Screen is the explicit themed-backdrop
  mode. Opaque screens are adjusted only for the draw stack; their input and
  callbacks remain engine-owned.
- Independent **PANEL OPACITY** and **TEXT / LINE OPACITY** controls make
  transparent panels readable without fading borders or labels.
- **START MOD MENUS** groups rows appended by other mods and this mod's **UI
  SETTINGS** beneath one **MOD MENUS** entry by default, keeping a busy Start
  menu readable while preserving each mod's live callback. Highlight a row in
  that submenu and press **SELECT** to pin or unpin it on the Start menu. The
  grouping can be disabled when a flat list is preferred.
- **START MENU FAST JUMP** lets a left/right touch-button press (or the same
  directional input from a keyboard/controller) jump five rows in the Start
  menu, with normal up/down navigation unchanged.
- Press **SELECT** on any Gen1 Modern UI setting to open a short description;
  press **SELECT**, **A**, or **B** again to close it.
- Optional classic-UI suppression: **HIDE ORIGINAL UI** defaults on and only
  clears the UI canvas when a supported modern presenter safely owns the whole
  visible UI layer; nested or custom prompts retain their classic context.
- Floating Summary and Pokédex entry screens validate their live Pokémon data
  before suppressing the classic canvas, preventing blank frames while a
  mobile stats or entry page is being initialized.
- Live rows and options, so other mods' menu entries remain visible.
- Shared OptionRows adapters for Run Mode, Shiny Pokémon, Quality of Life, and
  future mod settings screens keep their custom options readable at high
  resolution without replacing their callbacks or input ownership.
- Stack-aware dialogue, YES/NO, quantity, and action cards that preserve the
  game's typewriter timing and callback/input ownership.
- The in-game Start menu and title-screen main menu use the same floating
  desktop presentation; title art is preserved independently and the native
  title menu is suppressed without clearing the shared artwork canvas. While
  the modern title menu is open, the title artwork uses one uniform grayscale
  treatment instead of inheriting the native menu's partial palette zone.
- Responsive Trainer Card, Pokédex list, Bag, Shop, Player PC, Party, and
  Bill's PC presenters built from live state rather than replacement menus.
- Party and Bill's PC Pokémon lists include active sprite-pack artwork, HP and
  status, current stats, and the selected Pokémon's live moves/PP. Missing box
  stats are calculated for display without mutating the save.
- Bag and Shop details show the base purchase value and half-price sell value,
  including TM move/type/PP/value data; Trainer Card includes the five-digit ID.
- **MINIMAL UI** is off by default. When enabled, it keeps the modern shell and
  live controls while removing optional detail/preview panes and recomputing a
  genuinely compact layout. Party, PC, Bag, Shop, and context panels now size
  themselves to their visible content instead of reserving a wide empty card.
- Content-sized option rows reserve enough width for long values and
  localized labels before falling back to safe, non-overlapping truncation.
- Seven built-in themes spanning modern/classic, light/dark, opaque/glass
  styles, plus density controls and a public data-only theme API.
- Nearest-neighbor, aspect-fit artwork and active sprite-pack compatibility.
- Link Cable, Online Match, and Tournament screens use the modern presenter
  while LinkState keeps ownership of networking and input. Host/code entry
  shows the active digit slot and keeps the fixed UDP port separate. The title
  menu is suppressed through the released `titleUiBox` contract without
  clearing its artwork.
- PokePCFollowers compatibility crops its six-frame `follower_###.png`
  sheets to the correct nearest-neighbor frame for party/box icons and larger
  previews.
- Dialogue panels size to the live text window: normal two-line messages stay
  compact, while longer supplied page models can expand up to five wrapped
  lines plus a readable prompt.
  UI SETTINGS is organized into expandable Appearance, Navigation, Presenters,
  and Advanced categories instead of one long list.
- Useful Dex and Gen 3 Box presenters with square grids and animated authored
  art support.
- Battle presentation remains explicitly WIP and disabled by default.

## Compatibility with other mods

The presenter reads live public menu rows rather than replacing other mods'
state or callbacks. It currently supports UI surfaces from mods such as
[Useful Dex](https://github.com/bryanthaboi/gen1recomp/wiki), **Gen 3 Box**, and
the built-in mod manager, while preserving custom entries added by other
authors. Sprite replacement packs such as **Gold_Silver_Sprites** are used when
they are enabled. Unknown or unsupported screens remain vanilla instead of
being forced through an incorrect layout.

Mod settings screens built with gen1recomp's public `src.ui.OptionRows`
contract are also recognized. The current compatibility pass covers
[Run Mode](https://github.com/masterwebx/gen1recomp-run-mode),
[Shiny Pokémon](https://github.com/masterwebx/gen1recomp-shiny-pokemon), and
[Quality of Life](https://github.com/unxpected-uxp/pokemon-gen1-recomp-mod-qol);
their live rows and values are presented by Gen1 Modern UI while each mod
continues to own navigation and callbacks. A custom screen with an unknown
shape still falls back to its native renderer.

The presentation path stays inside released hooks. `ui.state.decorate`
suppresses only the ordinary title Menu draw while retaining its shared title
art, `render.zones` caches the live Game for the frame, `render.compose` lets downstream compositor hooks run and
then optionally clears only `ctx.uiCanvas` before the normal engine composite,
while `render.hud` draws the complete modern screen/modal stack.
The engine's virtual touch controls draw afterward, so they remain visible and
interactive. If the presenter is unsupported or its surface option is off,
the classic UI canvas is left untouched. The same fallback applies when a
transparent modal is stacked over another visible menu or a custom capture
prompt is active.

One integration caveat: another mod that consumes or rewrites `ctx.uiCanvas`
inside `render.compose` may observe a transparent UI canvas while **HIDE
ORIGINAL UI** is enabled on a supported screen. Disable that option to retain
the classic canvas, or coordinate hook priorities with the other compositor
mod. The world canvas and the engine's normal scaling, effects, and composition
path are not replaced.

See [the handoff document](docs/GEN1_MODERN_UI_HANDOFF.md) for the compatibility
contract, layout rules, testing notes, and release checklist.
The [screen roadmap](docs/SCREEN_ROADMAP.md) tracks every audited built-in and
installed-mod UI surface, its detection contract, priority, and fallback plan.
The [readability and scaling plan](docs/READABILITY_SCALING_PLAN.md) defines
the next UI/font/dialogue sizing milestone and its mobile reflow requirements.
The [input and interoperability audit](docs/INPUT_AND_INTEROP_AUDIT.md)
documents the current engine pointer seams, safe direct-navigation rules, and
the adapter plan for category bags and other replacement UIs.

## Requests and bug reports

Please [open an issue](https://github.com/ArmstrongThomas/gen1-modern-ui/issues)
for bug reports, compatibility requests, new screen types, themes, or layout
ideas. Include the gen1recomp version, mod versions, screen name, device or
window resolution/orientation, and a screenshot or reproduction path when
possible.

## Development

The mod source lives in `mods/gen1_modern_ui`. Run the lightweight checks from
the gen1recomp source checkout:

```powershell
npx --yes luaparse -q mods/gen1_modern_ui/main.lua
python tools/modkit.py lint mods/gen1_modern_ui
```

With LÖVE 11.5 installed, run the compositor regression from this repository:

```powershell
$env:GEN1_UI_MAIN = (Resolve-Path 'mods/gen1_modern_ui/main.lua').Path
& 'C:\Program Files\LOVE\lovec.exe' tests/compose_suppression
```

Set `$env:GEN1_UI_SHOTS = '1'` before that command to write the responsive
Bag, Pokédex, Trainer, Party, Bill's PC, Shop, PC, title, and dialogue/modal
gallery to the LÖVE save directory for visual QA.

After building, verify the actual archive through the same PhysFS mount path
used by the launcher importer:

```powershell
$env:GEN1_UI_ZIP = (Resolve-Path 'gen1_modern_ui-0.6.8.zip').Path
& 'C:\Program Files\LOVE\lovec.exe' tests/archive_package
```

To build the launcher-ready archive, double-click `sync_gen1_modern_ui.cmd` or
run `build_gen1_modern_ui.ps1`. The packer puts `manifest.json` first at the
archive root, writes portable forward-slash entry names, and omits editor
placeholders so the same ZIP imports consistently on desktop and mobile.

## Automated releases

The workflow in `.github/workflows/release.yml` runs on pushes to `main` and
manual dispatches. It validates the manifest and Lua syntax, builds the
launcher-ready zip, and creates a GitHub release only when the manifest version
does not already have a tag. To publish the next release, update the
`version` field in `mods/gen1_modern_ui/manifest.json` (for example, to
`0.6.8`) and push that commit to `main`. Each release includes a commit-based
change log, compatibility notes, quick-start install steps, and the archive's
SHA-256 checksum. Add `docs/releases/v<version>.md` when a release needs a
curated change log; the workflow uses that file as the release body and adds
the generated archive checksum automatically.

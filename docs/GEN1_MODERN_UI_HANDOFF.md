# Gen1 Modern UI handoff

Last updated: 2026-08-03

## Current status

`mods/gen1_modern_ui` is a standalone, visual-only overhaul for released
gen1recomp builds. It uses the existing `render.hud` hook to draw a modern
high-resolution overlay after the classic frame. It does not replace engine
states, patch the executable, or require a custom engine checkout at runtime.
Its manifest category is `UI`, so the released mod manager places it under the
UI section alongside other presentation-focused mods.

The current slice presents `Menu`, `ListMenu`, `ChoiceBox`, `QuantityBox`,
`OptionsMenu`, `PartyMenu`, `SummaryMenu`, `ManagerState`, Useful Dex's
`DexEntryMenu`, and Gen 3 Box's `Gen3Box` screen. Battle states have a
responsive, draw-only overlay for status cards, HP bars, sprites, action/move
panels, and messages, but it is WIP and disabled by default. Generic PC/Box and shop states still receive a list shell,
while rich third-party drawing pipelines and content-specific metadata are not
inferred. Dialogue and other data-heavy presenters remain future work.

The manifest range, `>=0.0.0-0 <2.0.0`, covers released 0.x and 1.x builds.
Keep that range aligned with the released mod API when publishing a new
version; a source checkout is optional for development and testing only.

The working tree may also contain earlier exploratory engine-seam changes from
the abandoned touch-first prototype. They are not packaged, loaded, or needed
by `gen1_modern_ui` 0.2.0. Treat the mod folder and its archive as the release
boundary; clean up those prototype-only checkout changes separately before
submitting unrelated engine work.

The standalone repository includes a GitHub Actions release workflow. A push
to `main` validates the manifest and Lua syntax, builds the launcher-ready zip,
and creates `v<manifest.version>` only when that tag/release does not already
exist. Release notes include the commits since the previous version, a quick
start install guide, compatibility notes, and the archive checksum. Bump the
manifest version for each distributable release; ordinary code or documentation
pushes at an existing version are intentionally idempotent.

## Architecture

1. The mod wraps `render.hud`, calls `next(game, viewport)` exactly once, then
   inspects the live top state from `game.stack`.
2. Supported states are recognized by their released UI classes or screen IDs.
   Rows are read afresh from the state each frame, so third-party additions,
   labels, ordering, and values remain visible without rebuilding callbacks.
3. The presenter draws directly in window coordinates using the safe viewport
   when the runtime provides one (falling back to the full window); the
   original 160x144 composite remains intact underneath.
4. Theme tokens are merged with the built-in defaults. The presenter owns only
   drawing; the game continues to own input, state transitions, and callbacks.

## Compatibility contract

- The hook chain is additive: `next` is called once before any overlay work.
- No state objects are wrapped or replaced, and no menu callback is invoked by
  the mod. Keyboard and controller behavior therefore remains vanilla.
- Unknown custom screens and unsupported states are left unchanged; explicit
  adapters are limited to stable public screen contracts.
- Dynamic rows supplied by other mods are read from the current state on every
  HUD pass. The presenter does not mutate those arrays.
- Optional row artwork uses `image`, `icon`, `thumbnail`, `sprite`, or `asset`
  metadata and degrades to text if the asset is absent.
- Pokémon art goes through the active runtime `pokemon.sprite` resolver when
  available, so enabled packs such as `Gold_Silver_Sprites` are honored and
  disabled packs are ignored.
- Built-in party icon pose sheets are cropped to the engine's native rest frame
  (including 16x32 and 16x96 sheets) instead of scaling the whole sheet into a
  thin strip. Authored replacement descriptors may explicitly opt in with
  `frames = 2` and loop at 450 ms per frame. Battle sprite replacements remain
  complete single-frame pictures. Every frame keeps nearest-neighbor filtering
  and aspect-ratio-preserving scale.
- The manager, Useful Dex entry, and Gen 3 Box adapters read public state fields
  only; they do not call row actions or replace custom screen objects.
- Useful Dex move pages show an `UP/DOWN page` footer hint only when the live
  screen reports multiple pages, matching its actual input behavior.
- The battle adapter reads public battler, phase, move, and message fields. Its
  `battleUiWip` toggle is WIP and defaults off; other surfaces have
  independent `menuUi`, `pokemonUi`, `managerUi`, and `spriteAnimation`
  toggles.
- A PC/Box or shop screen using a recognized generic list class may get the
  generic shell; this does not imply its content-specific metadata is covered.
- A theme is data-only and namespaced. Theme code must not assume private
  engine classes or install another whole-screen input owner.

## Input scope

Modern keyboard/controller presentation is intentionally visual only: the
original game continues to receive and process those inputs. Touch and click
activation are deferred to a later milestone; this release does not capture
pointer events, hide virtual controls, or add a second navigation path.

## Theme API

`gen1_modern_ui` exports API version 1 through `mod.exports`. A dependent theme
mod calls `mod.find("gen1_modern_ui")` and registers a namespaced theme ID such
as `theme_mod:midnight`:

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

Themes may override semantic colors, typography sizes, spacing, radii, density,
and motion tokens. The built-in presenter executes no theme drawing callbacks
and ships no ROM-derived art.

## Responsive behavior

- The overlay uses the safe window viewport rather than the classic game
  rectangle, including portrait, landscape, tablet, desktop, and ultrawide
  layouts.
- Panels size themselves from the live window dimensions and theme density.
- Short action/confirmation menus use a focused-width card in landscape;
  longer list/options screens retain the wider reading column.
- Landscape rows adapt down from the desktop rhythm before scrolling, so
  touch-control insets do not reduce a normal menu to only two visible rows.
- Landscape Pokémon, Dex, and box presenters use the same narrow central card
  and extended-height treatment; side controls may layer over the lower edge.
- Menu rows retain the current game selection and values; Summary uses a wider
  information panel when the display allows it.
- Because pointer interaction is deferred, layout changes do not alter input
  hit testing or controller navigation.

## Development workflow (LÖVE 11.5)

LÖVE 11.5 is the supported local runtime. A source checkout is useful for
running the game and hot reload, but it is not a dependency for distributing
the mod to players.

1. Install LÖVE 11.5 and put `love.exe` on `PATH` (or use its full path).
2. From the game source root, run `POKEPORT_DEV=1 love-11.5.exe .`. In
   PowerShell, use `$env:POKEPORT_DEV="1"; &
   "C:\\Program Files\\LOVE\\love.exe" .`.
3. Sync or copy `mods/gen1_modern_ui` into
   `%APPDATA%\\pokemon-love2d\\mods\\gen1_modern_ui`; press F5 to reload
   after edits and restart after a first install.
4. Run `python tools/modkit.py lint mods/gen1_modern_ui`. Strict validation
   additionally needs LuaJIT: `python tools/modkit.py validate
   gen1_modern_ui --strict`.
5. Package for release with `python tools/modkit.py pack
   mods/gen1_modern_ui`. The archive root must contain `manifest.json` and
   `main.lua` directly.

When LuaJIT or LÖVE 11.5 is unavailable, syntax checks and `modkit lint` still
provide useful preflight coverage, but strict validation and visual smoke tests
must run on a developer machine or CI host with those tools installed.

## Contributor checklist

When extending the standalone mod:

1. Use only released mod APIs (`render.hud`, `mod.ui`, `mod.options`, and
   `mod.find`) unless the compatibility range is intentionally changed.
2. Call the wrapped hook exactly once and keep all work in the draw pass;
   never replace a state or invoke a third-party callback.
3. Read dynamic state data defensively and leave unsupported screens vanilla.
4. Exercise portrait and landscape windows, dynamic rows, theme registration,
   keyboard/controller navigation, and the unchanged virtual touch controls.
5. Run syntax/lint/manifest checks and a LÖVE 11.5 smoke test before sharing.

## Mobile QA notes

The presenter measures the live virtual-control layout and reserves a
presenter-only safe rect above it. The backdrop still covers the full safe
window, so translucent controls never reveal a misaligned classic frame.
Portrait windows receive modest typography/row scaling; box cells stay square,
with a dedicated caption strip for name/level text. The battle presenter is
currently WIP and defaults off; when explicitly enabled, its move cells reserve
a separate PP column and follow the active OG vertical list or WIDE 2x2 cursor,
including empty WIDE slots. The smoke driver accepts
`SMOKE_INITIAL_WIDTH`/`SMOKE_INITIAL_HEIGHT` and `SMOKE_WIDTH`/`SMOKE_HEIGHT`
for exact-size runs such as 570x1278 portrait and 1280x640 landscape.

## Next milestones

- Add visual presenters for title/save selection, naming, and dialogue, plus
  richer opt-in cards for shops and custom preview pipelines.
- Design and test an opt-in touch/click input layer without breaking vanilla
  controller/keyboard behavior.
- Add portrait/landscape screenshot coverage and a theme-pack example.
- Update the official wiki/API reference as the released mod API evolves.

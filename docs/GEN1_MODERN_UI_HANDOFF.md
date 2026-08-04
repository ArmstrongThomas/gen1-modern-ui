# Gen1 Modern UI handoff

Last updated: 2026-08-04

## Current status

`mods/gen1_modern_ui` 0.6.7 is a standalone, visual-only overhaul for released
gen1recomp builds. It uses the released `render.zones`, `render.compose`, and
`render.hud` hooks to suppress the classic UI only when a modern presenter is
ready, preserve normal engine composition, and draw a high-resolution overlay.
It does not replace engine states, patch the executable, or require a custom
engine checkout at runtime.
Its manifest category is `UI`, so the released mod manager places it under the
UI section alongside other presentation-focused mods.

The comprehensive presenter inventory and delivery sequence live in
[`SCREEN_ROADMAP.md`](SCREEN_ROADMAP.md). Keep this handoff focused on shipped
behavior and release procedure; update the roadmap whenever a new screen ID,
adapter, or installed-mod compatibility contract is discovered.

The current slice presents `Menu`, `ListMenu`, `TextBox`, `ChoiceBox`,
`QuantityBox`, `OptionsMenu`, `PartyMenu`, `SummaryMenu`, `TrainerCard`,
`PokedexMenu`, `ManagerState`, Useful Dex's `DexEntryMenu`, and Gen 3 Box's
`Gen3Box` screen. Bag, Shop-product, and Player-PC item lists have live
detail-aware presenters, and compatible action/quantity/confirmation/dialogue
layers render as one modern stack. Released Bill's PC root, deposit, withdraw,
and release lists now have audited presenters; deposit/withdraw show the
selected Pokémon's sprite, HP/status, current stats, and moves/PP while the
released action/summary/confirmation states retain control. Party uses the same
detail model and continues to render injected live submenu rows. Battle states
have a responsive, draw-only overlay for status cards, HP bars, sprites,
action/move panels, and messages, but it is WIP and disabled by default.

The Start-menu hook collects rows appended by lower-priority mod hooks and this
mod's UI settings into one **MOD MENUS** entry (`START MOD MENUS`, enabled by
default). Rows retain their original descriptors and callbacks inside the
submenu. Pressing **SELECT** on the highlighted row toggles a stable-ID pin so
frequently used mod menus can remain direct Start-menu entries; disabling the
option restores the flat list. This is intentionally conservative because the
released hook does not require a mod-id field on every row.

The manifest range, `>=0.1.51 <2.0.0`, requires gen1recomp v0.1.51 or newer
and covers later 0.x plus released 1.x builds. Keep that range aligned with the
released render-hook API when publishing a new version; a source checkout is
optional for development and testing only.

The working tree may also contain earlier exploratory engine-seam changes from
the abandoned touch-first prototype. They are not packaged, loaded, or needed
by `gen1_modern_ui` 0.6.7. Treat the mod folder and its archive as the release
boundary; clean up those prototype-only checkout changes separately before
submitting unrelated engine work.

The standalone repository includes a GitHub Actions release workflow. A push
to `main` validates the manifest and Lua syntax, builds the launcher-ready zip,
and creates `v<manifest.version>` only when that tag/release does not already
exist. Release notes include the commits since the previous version, a quick
start install guide, compatibility notes, and the archive checksum. Bump the
manifest version for each distributable release; ordinary code or documentation
pushes at an existing version are intentionally idempotent. For a curated
release body, add `docs/releases/v<manifest.version>.md`; the workflow copies
that file and appends the generated archive checksum.

## Architecture

1. `ui.state.decorate` marks only the released ordinary title Menu and wraps
   its draw method with a dynamic, presentation-completeness guard. It does not
   replace the state or touch update/input/callbacks.
2. `render.zones` caches the live `Game` reference immediately before
   composition, because `render.compose` does not receive it directly.
3. `render.compose` snapshots the complete visible state stack and calls
   lower-priority compose hooks first. If none takes over, **HIDE ORIGINAL UI**
   (enabled by default) clears only `ctx.uiCanvas` when every drawing state has
   an enabled presenter and no unknown draw or capture mode is active. Known
   transparent modals render above their modern parent; an incomplete chain
   keeps the entire classic slice. The false result then falls
   through to the normal engine compositor, so scaling, fades, zones, and
   effects remain active.
4. Rich Summary and Pokédex entry layers validate their live Pokémon record
   before this suppression is allowed. `screen.pushed` synchronizes eligible
   opaque states immediately on hosts that expose the lifecycle event; the
   existing per-step sweep remains the fallback for older clients. Partially
   initialized third-party wrappers therefore retain the classic canvas rather
   than producing a blank floating frame.
5. `render.hud` calls `next(game, viewport)` exactly once, then draws the
   complete modern stack from its visible base upward. The engine's
   `TouchControls` draw afterward and remain visible.
6. Supported states are recognized by their released UI classes or screen IDs.
   Rows are read afresh from the state each frame, so third-party additions,
   labels, ordering, and values remain visible without rebuilding callbacks.
7. The presenter draws directly in window coordinates using the safe viewport
   when the runtime provides one (falling back to the full window); the
   world and normal whole-window composition remain intact underneath.
8. Theme tokens are merged with the built-in defaults. The presenter owns only
   drawing; the game continues to own input, state transitions, and callbacks.

Version 0.6.7 includes seven data-only themes: Gen1 Modern, Modern Glass,
Classic Mono, Pocket Green, Midnight, Midnight Glass, and Frost. The default
backdrop is explicitly opaque; glass theme alpha is honored now that supported
classic UI is suppressed independently.

## Compatibility contract

- The hook chain is additive: `next` is called once before any overlay work.
- **HIDE ORIGINAL UI** defaults on, but clears only `ctx.uiCanvas`, only for a
  supported state whose presenter toggle is enabled. The world canvas is never
  cleared by the mod.
- If the option is off or any state/presenter/context prerequisite is missing,
  the UI canvas is untouched. This is the safe fallback for unknown,
  unfinished, disabled, incomplete-stack, custom-capture, and headless paths.
- A Summary or DexEntry state without a resolvable live Pokémon record is
  treated as an incomplete prerequisite. The original canvas remains intact
  until the state has initialized; alternate public wrapper fields (`pokemon`,
  `target`, `vanilla.def`, and species IDs) are accepted when available.
- `render.compose` continues through the normal engine compositor and leaves
  the chain unclaimed (`false`); `render.hud` supplies the replacement UI later.
- Other mods that consume the same `ctx.uiCanvas` may observe it after it has
  been cleared, depending on hook priority. Disable **HIDE ORIGINAL UI** or
  coordinate priorities when combining incompatible compositor mods.
- No state object is replaced and no menu callback is invoked by the mod. The
  sole draw-method decoration is the audited title Menu suppression described
  below; update/input/callback ownership remains vanilla.
- Unknown custom screens and unsupported states are left unchanged; explicit
  adapters are limited to stable public screen contracts.
- An unknown instance- or class-level `draw` replacement keeps the classic
  canvas even when its state still inherits a recognized menu class. The
  audited Modern Bag, Useful Dex entry, and Gen 3 Box adapters are explicit
  structural exceptions because their complete live models are represented.
- Active overworld-owned UI such as the Pikachu portrait and poison flash also
  retains the classic canvas; clearing a recognized menu must not erase those
  independently timed overlays.
- The released overworld is a singleton class table with raw `draw` and
  `drawUI` methods. Its released `draw` identity must remain intact; additive
  `drawUI` wrappers are accepted so Quality-of-Life location banners and
  similar overlays do not disable Start, dialogue, or choice presentation. A
  replaced world draw or foreign overworld still forces classic fallback.
- The title menu is the one narrow presentation-only state decoration: its
  ordinary Menu draw is skipped only while the full title/menu stack remains
  presentable. The title artwork canvas is preserved rather than cleared. Any
  unknown overlay or custom draw immediately restores the native title Menu.
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
- The manager, third-party OptionRows settings, Trainer Card, Pokédex, Useful
  Dex entry, Bag/Shop/Player-PC,
  released Bill's PC, Party, and Gen 3 Box adapters read public state fields
  only; they do not call row actions or replace custom screen objects.
- Bill's PC detection requires the released `screenId="BoxMenu"` root and
  structural menu contract in the full stack. Withdraw/deposit resolve their
  live mon through the row payload; release resolves by current row position
  because its retained payloads become stale after a release. Unknown or
  reordered replacements stay classic. Imported box records may omit the
  calculated `stats` table; the presenter calls `Stats.calc` into a temporary
  display table and never calls the mutating `Stats.ensure` path.
- Dialogue reconstructs only the currently revealed glyph prefix from live
  `TextBox` pages and counters. The original state continues to own typewriter
  timing, waits, advancement, sounds, and choice callbacks.
- Useful Dex move pages show an `UP/DOWN page` footer hint only when the live
  screen reports multiple pages, matching its actual input behavior.
- The battle adapter reads public battler, phase, move, and message fields. Its
  `battleUiWip` toggle is WIP and defaults off; other surfaces have independent
  `layoutStyle`, `panelOpacity`, `foregroundOpacity`, `startMenuShortcut`,
  `startMenuFastJump`,
  `dialogueUi`, `menuUi`, `pokemonUi`, `managerUi`, and `spriteAnimation`
  options. `desktopFloating` remains only as a migration field for old saves.
- Every option schema row includes a short description. The modern manager
  presents it as a non-destructive help card when SELECT is pressed on that
  row; SELECT, A, or B dismisses the card without changing the setting.
- The richer presentation is the default: `minimalUi` starts `false` on new
  installs and only becomes compact when the player enables it.
- `minimalUi` is presentation-only. It removes optional Pokédex/Bag/Shop
  previews and large Party/Bill detail panes while retaining live rows,
  selection, essential Pokémon data, prompts, and input ownership.
- Bag/Shop/Player-PC detail cards render in both landscape and portrait.
  Item values come from the active item definition. `BASE` is the
  purchase value and `SELL` is `floor(BASE / 2)`; missing definitions, key
  items, and HMs are shown as unsellable. TM machine metadata and values are
  displayed together.
- Shop product and Player-PC item lists are detected by their released
  dialogue/message capabilities, not labels. Other PC/Box list screens receive
  the generic shell unless a richer stable contract is recognized.
- A theme is data-only and namespaced. Theme code must not assume private
  engine classes or install another whole-screen input owner.

## Input scope

Modern keyboard/controller presentation is intentionally visual only: the
original game continues to receive and process those inputs. The released
touch overlay also remains the input owner. `startMenuFastJump` observes the
same queued left/right GB-button edges and moves a Start-menu cursor by five;
it does not capture raw pointer coordinates, hide virtual controls, or add a
second state/input owner. The engine draws `TouchControls` after `render.hud`,
above the modern layer.

The upstream audit found no public gameplay pointer event or semantic input
facade. A first experimental layer can poll pointer state from `input.step`,
reuse presenter hitboxes, exclude virtual-control hits, and translate taps
through the real state selection plus normal Game Boy actions. Reliable
release support should request `input.pointer` and source-safe `mod.input`
press/tap hooks. See
[`INPUT_AND_INTEROP_AUDIT.md`](INPUT_AND_INTEROP_AUDIT.md) for source findings,
flow-by-flow rules, and the installed Modern Bag/category compatibility audit.

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

Themes may override semantic colors, typography sizes, spacing, radii, and
density. The built-in presenter executes no theme drawing callbacks and ships
no ROM-derived art. Built-in and third-party themes share one live options
list; re-registering a namespaced ID refreshes its name and tokens without
adding a duplicate choice.

## Responsive behavior

- The overlay uses the safe window viewport rather than the classic game
  rectangle, including portrait, landscape, tablet, desktop, and ultrawide
  layouts.
- `layoutStyle=auto` is the default. Presenters remain floating on desktop and
  mobile, while `full` restores a backdrop-first presentation.
- Panels size themselves from live content, window dimensions, and theme
  density. Short menus shrink to their widest visible label/value plus padding;
  longer menus grow only until scrolling is needed.
- Minimal UI removes optional detail regions before measuring, so hidden
  previews do not leave blank columns or oversized panels.
- Compact landscape panels generally cap at about 60--70% of the viewport;
  they may overlap Start/Select touch controls when necessary to preserve a
  usable height.
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
5. From the standalone repository, run the compositor regression with
   `$env:GEN1_UI_MAIN = (Resolve-Path
   'mods/gen1_modern_ui/main.lua').Path; &
   'C:\Program Files\LOVE\lovec.exe' tests/compose_suppression`.
   Set `$env:GEN1_UI_SHOTS = '1'` first to save the desktop/portrait gallery
   under LÖVE's `compose_suppression` save directory.
6. Package for release with `python tools/modkit.py pack
   mods/gen1_modern_ui`. The archive root must contain `manifest.json` and
   `main.lua` directly.

When LuaJIT or LÖVE 11.5 is unavailable, syntax checks and `modkit lint` still
provide useful preflight coverage, but strict validation and visual smoke tests
must run on a developer machine or CI host with those tools installed.

## Contributor checklist

When extending the standalone mod:

1. Use only released mod APIs (`render.zones`, `render.compose`, `render.hud`,
   `mod.ui`, `mod.options`, and `mod.find`) unless the compatibility range is
   intentionally changed.
2. Call each wrapped hook exactly once, preserve normal composition, and never
   replace a state or invoke a third-party callback.
3. Clear only `ctx.uiCanvas`, guarded by the same supported/enabled check used
   by the HUD presenter. Always retain the classic-UI fallback.
4. Read dynamic state data defensively and leave unsupported screens vanilla.
5. Exercise portrait and landscape windows, dynamic rows, theme registration,
   keyboard/controller navigation, and the unchanged virtual touch controls.
6. Test both **HIDE ORIGINAL UI** settings and coexistence with any other
   `render.compose` consumer in scope.
7. Run syntax/lint/manifest checks and a LÖVE 11.5 smoke test before sharing.
8. Build releases with `build_gen1_modern_ui.ps1` (called automatically by the
   double-click sync script). It guarantees a root-level, first-entry
   `manifest.json`, portable `/` entry names, and no editor placeholders.
9. Set `GEN1_UI_ZIP` to the built archive and run LÖVE against
   `tests/archive_package`. This stages and mounts the real ZIP through the
   same PhysFS path used by `LauncherMods.installZip`, then verifies that the
   root manifest and entry chunk are readable.

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

- Implement the independent UI/font/dialogue scaling milestone in
  `docs/READABILITY_SCALING_PLAN.md`, starting with dialogue and generic menu
  measurement before applying it to richer presenters.
- Exercise the new dialogue, title, Trainer, Party, Bill's PC, Pokédex, Bag,
  Shop, and Player-PC
  presenters in the released game with installed UI/category mods and retain
  classic fallback for any unmodeled branch.
- Add visual presenters for move learning, PicBox, naming, Town Map/Fly/AREA,
  and the title Continue-info/save-selection card.
- Design and test an opt-in touch/click input layer without breaking vanilla
  controller/keyboard behavior.
- Expand portrait/landscape screenshot coverage and add a theme-pack example.
- Update the official wiki/API reference as the released mod API evolves.

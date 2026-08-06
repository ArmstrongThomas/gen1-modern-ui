# Gen1 Modern UI screen roadmap

Last updated: 2026-08-04

This is the implementation matrix for built-in gen1recomp UI and the custom
screens found in the currently installed mod set. It describes intended visual
coverage only. Original states continue to own input, callbacks, timing, and
gameplay behavior.

The v0.6.1 layout pass adds content-sized floating panels across supported
screens. Minimal mode removes optional regions before sizing, so a short list
does not inherit the empty space of a rich preview layout.

Pointer feasibility, direct-navigation rules, and the installed category-bag
audit are recorded in
[`INPUT_AND_INTEROP_AUDIT.md`](INPUT_AND_INTEROP_AUDIT.md).

## Presenter architecture prerequisite

Gen1recomp UI is frequently a stack rather than one screen. Examples include
Bag → action → quantity → confirmation → message, Pokédex → side menu, and
Naming → preset menu. `ctx.uiCanvas` contains every visible layer. Modern UI
must therefore suppress it only when one of these conditions is true:

1. A specialized presenter owns the complete visible screen family.
2. Every visible UI state has a compatible screen or modal presenter.
3. No custom drawing/capture mode is active outside the semantic model.

Unknown states, custom draw overrides, incomplete presenter chains, adapter
errors, and capture prompts keep the classic UI. Version 0.3.0 implemented the
first conservative guard: only one modern-owned UI layer (plus the overworld)
may be suppressed; nested layers and `state.capture` retain vanilla context.
Version 0.4.0 also rejects unknown instance-level `draw` replacements, with an
explicit exception for the audited Modern Bag wrapper. Version 0.6.0 ships the
stack-aware chain: every visible drawing state must have an enabled presenter,
known modals render bottom-up above their modern parent, and any unknown layer
retains the complete classic slice. It also rejects unknown class-level draw
overrides and admits only the audited Modern Bag, Useful Dex, and Gen 3 Box
structural adapters. The current v0.6.1 work also audits the released Bill's-PC
root/child contract and the title Menu: Bill lists require verified full-stack
ancestry, while the ordinary title Menu is suppressed independently so its
shared title-art canvas is preserved.

The v1 source-mod contract now exposes `layer = "screen" | "modal"`,
`canSuppressNative`, read-only models, source-owned semantic actions, and
data-only namespaced themes and frames. Adapter exceptions remain narrower
than their live semantic contract; custom draw callbacks are never accepted.

## Revised 1.0 delivery phases

- **0.8.x — compatibility foundation:** versioned adapter registration and
  discovery, namespaced themes and frames, model/action validation, reload and
  disable invalidation, error isolation, `screen.render_visible`, and the
  conservative `render.compose` fallback. RBYMMO and Dex Radar move to public
  exports first, with an example source-mod adapter and API documentation.
- **0.9.x — compatibility and polish:** migrate remaining installed-mod
  integrations, test absence/disable/version mismatch/hot reload/malformed
  models, and complete released-game QA across themes, palettes, pixel assets,
  fonts, scaling, responsive layouts, nested modals, and pointer settings.
  Controls/Bindings, Continue/save selection, battle, and touch/drag remain
  explicitly WIP or deferred.
- **1.0.0 — stable core UI:** require the documented contract, public RBYMMO
  and Dex Radar adapters, source-mod-owned UI files that publish the contract,
  precise suppression with fallback, stable presenters and input safety, and
  synchronized manifest, changelog, API docs, and examples.
- **After 1.0:** Controls/Bindings replacement, semantic save-slot cards,
  battle, evolution/trade/Hall of Fame/Diploma/Credits/cinematics/minigames,
  universal drag/drop or mouse interaction, custom third-party drawing, and
  the permanently dropped Kid Mode remain out of scope.

## Historical delivery phases

- **P0 — safety and layering:** stack-aware presenter chain, TextBox and modal
  primitives, custom-draw detection, and failure fallback are shipped. Adapter
  error containment and optional developer logging remain.
- **P1 — daily menus:** Trainer Card, richer Party/Bag/Shop/PC, Pokédex list,
  Bill's-PC lists, adaptive floating layouts, compact/minimal sizing, and
  independent opacity controls are shipped; Controls and stabilization remain.
- **P1.5 — readability (v0.7.0 shipped):** independent UI/font/dialogue
  scaling, accessible scale ranges, measured generic-row reflow, cached
  scaled-theme compatibility, and long-word dialogue wrapping. See
  [`READABILITY_SCALING_PLAN.md`](READABILITY_SCALING_PLAN.md) for the
  implementation contract and remaining visual QA.
- **P2 — spatial/editing screens:** Naming, Town Map/Fly/AREA, Move Learn,
  PicBox, reports, and the third-party adapter API.
- **P3 — title/online/special:** title family, Link/Tournament, and adapters for
  large custom UI mods.
- **WIP — battle:** remains off until the screen-stack and animation ownership
  architecture is stable.
- **Vanilla by design:** cinematics and minigames remain classic unless a full
  replacement is intentionally designed.

## Built-in screen matrix

| Surface | Detection / live data | Current status | Implementation plan |
|---|---|---|---|
| Generic menu | `mod.ui.Menu`; `items`, `index`, `scroll`, `screenId` | Shipped baseline | Preserve injected rows, disabled state, images, and `keepOpen`; retain vanilla when custom drawing is detected. |
| Generic list | `mod.ui.ListMenu`; title/items/index/scroll/footer/dialogue/message/money/swap | Shipped baseline | Add details region, wrap/page hints, money/message areas, and swap marker without rebuilding row callbacks. |
| TextBox/dialogue | `mod.ui.TextBox`; pages/typewriter/waiting/done/geometry | Shipped | Reads only the revealed glyph prefix and preserves the original typewriter, waiting, page, sound, and callback ownership. |
| YES/NO | `ChoiceBox`; `index`, `pending` | Shipped layered modal | Renders above a complete modern parent stack; pending timing remains engine-owned. |
| Quantity | `QuantityBox`; `qty`, `max`, `unitPrice` | Shipped layered modal | Layers above Bag/Shop/PC and displays totals when unit price is available. |
| Picture popup | `mod.ui.PicBox`; `image`, `text` | Dedicated presenter | Aspect-fit nearest-neighbor image card plus wrapped caption; native close/callback flow remains authoritative. |
| Start menu | `screenId="StartMenu"`; live injected items | Shipped | Retain the unobtrusive landscape side panel, group third-party/UI settings rows under MOD MENUS, support SELECT pin/unpin, and optionally show a compact party quick view beside floating/adaptive layouts. |
| Save/quit flow | Start row plus TextBox and ChoiceBox states | Stack-ready; QA needed | Dialogue/modal layering is shipped; test overwrite, saving, quit, and return-to-title branches before calling the family complete. |
| Trainer card | `screenId="TrainerCard"`; player name, money, play time | Shipped | Compact content-sized card focused on the three most useful trainer facts. |
| Bag | `screenId="BagMenu"`; rows/item defs/counts/swap/money plus nested actions | Shipped specialized presenter | Live counts, pockets, BASE/SELL values, TM move/type/PP/value, swap markers, and layered actions. Continue compatibility QA with Modern Bag, Bag 999, Item Shortcut, and reusable machines. |
| Shops | product `ListMenu`; `dialogue`, money, rows, quantities | Shipped capability presenter | Product list + BASE/SELL details, persistent money/clerk message, quantity and confirmation modal chain; root BUY/SELL remains generic. |
| Player item PC | item `ListMenu`; `messageBox`, rows, quantities/confirms | Shipped capability presenter | Shares list-details/modal architecture and follows live count removal; root PC choices remain generic. |
| Bill's PC/classic boxes | released `screenId="BoxMenu"` root plus opaque mon lists/actions | Shipped structural presenter | Root uses the modern menu; deposit/withdraw show sprite, HP/status, stats, and moves/PP. Release resolves current row position and retains native confirmation; unknown/reordered replacements stay classic. |
| Gen 3 Box | `screenId="Gen3Box"`; mode/grid/held/party/boxes | Dedicated presenter | Shipped; retain square cells, held-mon card, aspect ratio, nearest filtering, and active sprite hooks. |
| Party | `PartyMenu` class; party/submenu/swap/heal/TM/battle/pick-only | Shipped rich presenter | Selected-mon sprite, HP/status, stats, moves/PP plus live compact rows; retains healing/TM/pick/swap data and injected submenu rows. Direct callers without `screenId` are supported by class identity. |
| Summary/status | `screenId="SummaryMenu"`; mon/page/sprite | Dedicated presenter | Stabilize compact landscape layout and continue sprite-resolver compatibility. |
| Move learning | `screenId="MoveLearnMenu"`; mon/new move/selecting/move data | Dedicated presenter | Five-row replace/cancel view with move type details; trying-to-learn and abandon prompts remain layered native TextBox states. |
| Evolution | `screenId="EvolutionState"`; old/new sprites, timer, cancel/done | Vanilla | Later full-sequence cosmetic presenter or intentionally remain vanilla; do not replace only part of its animation canvas. |
| Pokédex list | `screenId="PokedexMenu"`; rows, ball/seen marker, values, filters | Shipped specialized presenter | Responsive list + selected-species preview while preserving unseen entries and Useful Dex sort/filter rebuilding. |
| Pokédex entry | `screenId="DexEntryMenu"`; definition/sprite/view/page/stats/moves | Dedicated presenter | Shipped; maintain data/stats/moves variants and conditional UP/DOWN hints. |
| Pokédex side menu | `Menu` layered above Pokédex | Shipped layered modal | Presents over the modern Pokédex only when the complete visible chain is modeled. |
| Town Map / Fly / AREA | `screenId="TownMap"`; map image, locations, selection, fly/nests | Dedicated presenter | Responsive map/list card, scale-aligned selection/player markers, fly destination details, AREA marker support, and conservative party-marker compatibility with native navigation/callback ownership. RBY MMO's public party/roster exports place the remote party member on the corresponding city with their selected sprite and name, and the detail pane lists players at the selected location. |
| Dex Radar | `screenId="DexRadar"`; rows/monIndex/cursor/mapLabel/owned totals | Dedicated presenter | Responsive themed encounter list with section labels, active-palette party icons, unseen silhouettes, level/rate metadata, pointer hover, and conservative native input/update ownership. Incomplete or changed models stay classic. |
| Options | `screenId="OptionsMenu"`; live descriptor rows | Dedicated rows | Shipped; allow stable-ID grouping only and never reorder unknown mod rows. |
| Third-party OptionRows settings | Plain registered screen with `rows`, `index`, `scroll`, `update`, and `draw`; known IDs include `RunModeOptions`, `ShinyPokemonOptions`, and `QualityOfLife` | Shared adapter | Shipped in v0.6.6; reads live labels/values, preserves source callbacks/input, and falls back for non-semantic custom screens. |
| Controls/bindings | `screenId="BindingsMenu"`; list fields plus `capture`/pending | Unsafe generic fallback | **P0 safety/P1 presenter.** Keep capture prompt vanilla now; later show logical control, existing bindings, reset/clear hints, and capture modal. |
| Mod manager | `screenId="ManagerState"`; screen/tab/rows/current mod/overlays | Dedicated presenter | Shipped across list, profiles, errors, detail, options, permissions, and apply; keep explicit adapter. |
| Quarantine report | `screenId="QuarantineReport"`; lines/offset/maxOffset | Dedicated presenter | Content-sized scrollable recovery report with explicit paging controls and classic fallback for malformed state. |
| Naming / Name Rater | `NamingScreen` or semantic Name Rater state; glyph grid, row/col/case/maxLen, target nickname | Dedicated presenter | Responsive full character grid with editable existing nicknames, pointer activation, and preset menu layering. |
| Title/Continue | ordinary title Menu over released TitleState; private ContinueInfo | Main Menu shipped; Continue classic | The title Menu draw is suppressed independently while preserving title art; any unknown overlay restores classic. ContinueInfo remains classic until it has a stable semantic presenter. |
| Oak speech/intros | `OakSpeech`, `IntroMovie`, `YellowIntro`; art + TextBox/Menu/Naming | Vanilla | Leave cinematic canvas intact initially; revisit after dialogue and naming presenters. |
| Battle | phase/queue/kind/player/enemy and battle screen variants | WIP, off | See battle section below. |
| Link | direct `LinkState`; stage/index/address/code/network/trade data | Vanilla | **P3.** Request stable screen ID; cover host/join/code/compatibility/settings/trade/wait states. |
| Tournament | direct `Tournament`; stage/settings/bracket/roster/champion | Vanilla | **P3 after Link.** Request stable ID and build bracket/roster semantic models. |
| Trade animation | `screenId="TradeAnim"`; sequence phases/sprites | Vanilla | Treat as cinematic; only replace as a complete animation. |
| Hall of Fame / Diploma / Credits | screen IDs where available; phases/sprites/save data | Vanilla | Final cosmetic phase; preserve timing and transitions. |
| Slot machine / Surfing minigame | custom state phases and art | Vanilla by design | Treat as games, not menus; consider only an accessibility-specific redesign. |
| One-off lists | Elevator, fossil/prize choice, blackboard, Oak rating, etc. | Generic/vanilla | Let generic widgets cover them after P0; never add label-driven gameplay logic. |

## Battle interface plan

Battle stays labeled **WIP** and disabled by default. Native battle sprites,
animations, HUD, prompts, and text currently share `uiCanvas`; the compositor
cannot remove only the HUD while retaining the native animation layer.

Required variants include wild/trainer/link, Safari, old-man demo, intro and
party-ball sequences, messages, 2×2 commands, OG list versus WIDE 2×2 moves,
fewer-than-four-move navigation, Mimic/move swapping, Bag/Party overlays,
forced replacement, nickname prompts, and level-up StatBox. Implement one
phase at a time only after P0. A future engine split between battle scene and
battle HUD would lower the cost of a faithful replacement, but v0.3.0 does not
require it.

## Installed-mod adapters and compatibility

| Mod/surface | Contract and plan |
|---|---|
| Useful Dex | Its list remains `ListMenu`; entry exposes data/stats/moves and stable fields. Continue explicit Dex Entry support and add list preview without breaking dynamic sort/filter modes. |
| Gen 3 Box | Stable `screenId="Gen3Box"` and grid/held fields. Existing adapter remains appropriate. |
| Gold/Silver Sprites | Continue resolving through `Sprites.path`/`iconPath`; disabled packs naturally leave their hooks inactive. |
| Unique Menu Icons | Preserve authored `frames=2` descriptors; keep vanilla pose sheets static instead of guessing animation frames. |
| Run Mode / Shiny Pokémon / Quality of Life | Plain OptionRows screens (`RunModeOptions`, `ShinyPokemonOptions`, `QualityOfLife`) with rows/index/scroll. The shared adapter shipped in v0.6.6; source mods continue to own updates and callbacks. |
| Overworld Wild Spawns | List views mostly fit generic models; preview detail/animation screen IDs need explicit adapters or vanilla fallback. |
| RBY MMO | Generic widget screens can inherit baseline coverage; Town Map party-member markers accept common location/map-id shapes and the public `party()`/`players()` exports. `RbyMmoProfile` and `RbyMmoRank` now have semantic presenters that read the public player/card and client/entries/offset payloads, crop selected sprite art from the host catalog, and leave network and navigation callbacks native. Future opaque screens still need explicit adapters. |
| Dex Radar | Stable `screenId="DexRadar"` plus its public live rows, `monIndex`, cursor, map label, ownership totals, and visibility flags. The dedicated presenter preserves Dex Radar's own encounter API and navigation while replacing only the native 160x144 draw pass. |
| Modern Bag / Bag 999 / Item Shortcut / PC-shop utilities | Preserve their live row objects and constructors. Render only explicit `right`/`displayValue` metadata, not opaque `value` payloads. Use an explicit capability/adapter for custom tabs and drawing before suppression; a blanket custom-draw rejection would also reject wrappers that safely delegate. |

## Third-party presenter adapter proposal

Expose a small semantic registration API keyed by stable `screenId`:

- Namespaced adapter ID and API version.
- `kind`, `title`, rows/grid/cards, selection, footer, and optional artwork
  descriptors.
- `layer = "screen" | "modal"`.
- An explicit `canSuppressClassic(state, visibleStack)` result.
- No callbacks or input ownership in the adapter; those remain on the state.
- Adapter errors immediately retain the classic UI for that frame.

## Start-menu and settings follow-up

The `START MOD MENUS` option now groups rows appended by other mods beneath a
single Start-menu entry while preserving their original descriptors and
callbacks. Keep this grouping conservative because the released hook does not
require every row to carry a mod identifier. Gen1 Modern UI's own options are
already organized into expandable Appearance, Navigation, Presenters, and
Advanced categories; new Start-menu controls belong in Navigation without
reordering or grouping unknown rows supplied by other authors.

## Definition of done per presenter

Each new surface needs:

1. Desktop, portrait phone, landscape phone, and ultrawide layout checks.
2. Empty, short, full, and scrolling datasets where applicable.
3. Nested modal and cancel/return flow coverage.
4. **HIDE ORIGINAL UI** on/off verification and an adapter-error fallback.
5. Keyboard/controller parity; touch controls remain unobstructed enough to use.
6. Active and inactive sprite/image replacement mods, aspect-fit scaling, and
   nearest-neighbor filtering.
7. At least one relevant third-party mod compatibility pass.

The next implementation slice should focus on released-game QA for the new
P2 presenters, title ContinueInfo, and pointer coverage for replacement and
drag/drop flows. First complete released-game QA for
the v0.5.0 dialogue, title, Trainer, Party, Bill's PC, Pokédex, Bag, Shop, and Player-PC stack;
any unmodeled branch must keep the classic UI.

# Gen1 Modern UI screen roadmap

Last updated: 2026-08-03

This is the implementation matrix for built-in gen1recomp UI and the custom
screens found in the currently installed mod set. It describes intended visual
coverage only. Original states continue to own input, callbacks, timing, and
gameplay behavior.

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
explicit exception for the audited Modern Bag wrapper.

Future presenters should expose `layer = "screen" | "modal"` and an explicit
suppression-safety result. A stack-aware presenter chain is P0 before broadening
suppression.

## Delivery phases

- **P0 — safety and layering:** stack-aware presenter chain, TextBox and modal
  primitives, custom-draw detection, failure fallback, and developer logging.
- **P1 — daily menus:** Trainer Card, Controls, richer Bag/Shop/PC, Pokédex
  list, and stabilization of the presenters already shipped.
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
| TextBox/dialogue | `mod.ui.TextBox`; pages/typewriter/waiting/done/geometry | Vanilla | **P0.** Build a modal/screen dialogue presenter that reads already-revealed text and preserves typewriter/page state. |
| YES/NO | `ChoiceBox`; `index`, `pending` | Standalone generic card | **P0.** Render as a modal above the modern underlying screen; never clear its context alone. |
| Quantity | `QuantityBox`; `qty`, `max`, `unitPrice` | Standalone generic card | **P0.** Layer above Bag/Shop/PC and display total price. |
| Picture popup | `mod.ui.PicBox`; `image`, `text` | Vanilla | **P2.** Aspect-fit nearest-neighbor image modal plus caption. |
| Start menu | `screenId="StartMenu"`; live injected items | Shipped | Retain the unobtrusive landscape side panel and automatic third-party rows. |
| Save/quit flow | Start row plus TextBox and ChoiceBox states | Partial | Completed by P0 dialogue/modal layering; test overwrite, saving, quit, and return-to-title. |
| Trainer/badge card | `screenId="TrainerCard"`; player, money, play time, badges, portrait | Vanilla | **P1 first feature.** Responsive profile card, portrait, metadata, and scalable badge grid with optional custom badge art. |
| Bag | `screenId="BagMenu"`; rows/item defs/counts/swap/money plus nested actions | Generic | **P1.** Counts, pockets, selection details, TM/move info, battle mode, and layered actions. Preserve Modern Bag, Bag 999, Item Shortcut, and reusable-machine rows. |
| Shops | `screenId="ShopMenu"`; BUY/SELL rows, money, dialogue, quantities | Generic | **P1.** Product list + details, persistent money/clerk message, quantity and confirmation modal chain. |
| Player item PC | `screenId="PlayerPC"`; nested lists/messages/quantities/confirms | Generic | **P1.** Share the commerce/list-details and modal architecture; handle live count removal. |
| Bill's PC/classic boxes | `screenId="BoxMenu"`; mode, current box/capacity, mon lists/actions | Generic | **P1.** Box metadata and mon details; preserve STATS/action and release confirmations. |
| Gen 3 Box | `screenId="Gen3Box"`; mode/grid/held/party/boxes | Dedicated presenter | Shipped; retain square cells, held-mon card, aspect ratio, nearest filtering, and active sprite hooks. |
| Party | `screenId="PartyMenu"`; party/submenu/swap/heal/TM/battle/pick-only | Dedicated presenter | Stabilize switching, healing, TM eligibility, pick-only, and battle-switch visual modes while retaining injected submenu rows. |
| Summary/status | `screenId="SummaryMenu"`; mon/page/sprite | Dedicated presenter | Stabilize compact landscape layout and continue sprite-resolver compatibility. |
| Move learning | `screenId="MoveLearnMenu"`; mon/new move/selecting/move data | Vanilla | **P2.** Five-row replace/cancel view with PP/type details after modal layering exists. |
| Evolution | `screenId="EvolutionState"`; old/new sprites, timer, cancel/done | Vanilla | Later full-sequence cosmetic presenter or intentionally remain vanilla; do not replace only part of its animation canvas. |
| Pokédex list | `screenId="PokedexMenu"`; rows, ball/seen marker, values, filters | Generic | **P1.** Responsive list + selected-species preview while preserving unseen entries and Useful Dex sort/filter rebuilding. |
| Pokédex entry | `screenId="DexEntryMenu"`; definition/sprite/view/page/stats/moves | Dedicated presenter | Shipped; maintain data/stats/moves variants and conditional UP/DOWN hints. |
| Pokédex side menu | `Menu` layered above Pokédex | Top-only generic | **P0/P1.** Present as modal over the modern Pokédex; never suppress the list beneath it alone. |
| Town Map / Fly / AREA | `screenId="TownMap"`; map image, locations, selection, fly/nests | Vanilla | **P2.** Full-window map, responsive banner/details, grid navigation, fly list, blinking nest markers. |
| Options | `screenId="OptionsMenu"`; live descriptor rows | Dedicated rows | Shipped; allow stable-ID grouping only and never reorder unknown mod rows. |
| Controls/bindings | `screenId="BindingsMenu"`; list fields plus `capture`/pending | Unsafe generic fallback | **P0 safety/P1 presenter.** Keep capture prompt vanilla now; later show logical control, existing bindings, reset/clear hints, and capture modal. |
| Mod manager | `screenId="ManagerState"`; screen/tab/rows/current mod/overlays | Dedicated presenter | Shipped across list, profiles, errors, detail, options, permissions, and apply; keep explicit adapter. |
| Quarantine report | `screenId="QuarantineReport"`; lines/offset/maxOffset | Vanilla | **P2.** Simple scrollable report with paging hints. |
| Naming | `screenId="NamingScreen"`; glyph grid, row/col/case/maxLen | Vanilla | **P2.** Responsive character grid supporting modded glyph/address pages; preset menu remains layered. |
| Title/Continue | Title menu over TitleState; Continue info save/title box | Partial/unsafe | **P3.** Build one complete title-family presenter before suppression; request stable ID for ContinueInfo if structural detection proves fragile. |
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
| Quality of Life | Plain `screenId="QualityOfLife"` with rows/index/scroll. Add an option-model adapter in P3. |
| Overworld Wild Spawns | List views mostly fit generic models; preview detail/animation screen IDs need explicit adapters or vanilla fallback. |
| RBY MMO | Generic widget screens can inherit baseline coverage; Naming, PicBox, opaque custom screens, and network flows need P2/P3 adapters. |
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

The next feature after the v0.3.0 suppression work should be the Trainer Card.
It is self-contained, explicitly requested, and exercises responsive profile,
image, metadata, and grid layout without battle or modal-stack complexity.

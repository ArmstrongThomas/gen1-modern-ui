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

Future third-party presenters should expose `layer = "screen" | "modal"` and an
explicit suppression-safety result. Adapter exceptions must remain narrower
than their live semantic contract.

## Delivery phases

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
| Picture popup | `mod.ui.PicBox`; `image`, `text` | Vanilla | **P2.** Aspect-fit nearest-neighbor image modal plus caption. |
| Start menu | `screenId="StartMenu"`; live injected items | Shipped | Retain the unobtrusive landscape side panel, group third-party/UI settings rows under MOD MENUS, and support SELECT pin/unpin for direct shortcuts. |
| Save/quit flow | Start row plus TextBox and ChoiceBox states | Stack-ready; QA needed | Dialogue/modal layering is shipped; test overwrite, saving, quit, and return-to-title branches before calling the family complete. |
| Trainer/badge card | `screenId="TrainerCard"`; player ID/name, money, play time, badges, portrait | Shipped | Responsive profile card, five-digit Trainer ID, active portrait, live metadata, and scalable badge grid with optional custom badge art. |
| Bag | `screenId="BagMenu"`; rows/item defs/counts/swap/money plus nested actions | Shipped specialized presenter | Live counts, pockets, BASE/SELL values, TM move/type/PP/value, swap markers, and layered actions. Continue compatibility QA with Modern Bag, Bag 999, Item Shortcut, and reusable machines. |
| Shops | product `ListMenu`; `dialogue`, money, rows, quantities | Shipped capability presenter | Product list + BASE/SELL details, persistent money/clerk message, quantity and confirmation modal chain; root BUY/SELL remains generic. |
| Player item PC | item `ListMenu`; `messageBox`, rows, quantities/confirms | Shipped capability presenter | Shares list-details/modal architecture and follows live count removal; root PC choices remain generic. |
| Bill's PC/classic boxes | released `screenId="BoxMenu"` root plus opaque mon lists/actions | Shipped structural presenter | Root uses the modern menu; deposit/withdraw show sprite, HP/status, stats, and moves/PP. Release resolves current row position and retains native confirmation; unknown/reordered replacements stay classic. |
| Gen 3 Box | `screenId="Gen3Box"`; mode/grid/held/party/boxes | Dedicated presenter | Shipped; retain square cells, held-mon card, aspect ratio, nearest filtering, and active sprite hooks. |
| Party | `PartyMenu` class; party/submenu/swap/heal/TM/battle/pick-only | Shipped rich presenter | Selected-mon sprite, HP/status, stats, moves/PP plus live compact rows; retains healing/TM/pick/swap data and injected submenu rows. Direct callers without `screenId` are supported by class identity. |
| Summary/status | `screenId="SummaryMenu"`; mon/page/sprite | Dedicated presenter | Stabilize compact landscape layout and continue sprite-resolver compatibility. |
| Move learning | `screenId="MoveLearnMenu"`; mon/new move/selecting/move data | Vanilla | **P2.** Five-row replace/cancel view with PP/type details after modal layering exists. |
| Evolution | `screenId="EvolutionState"`; old/new sprites, timer, cancel/done | Vanilla | Later full-sequence cosmetic presenter or intentionally remain vanilla; do not replace only part of its animation canvas. |
| Pokédex list | `screenId="PokedexMenu"`; rows, ball/seen marker, values, filters | Shipped specialized presenter | Responsive list + selected-species preview while preserving unseen entries and Useful Dex sort/filter rebuilding. |
| Pokédex entry | `screenId="DexEntryMenu"`; definition/sprite/view/page/stats/moves | Dedicated presenter | Shipped; maintain data/stats/moves variants and conditional UP/DOWN hints. |
| Pokédex side menu | `Menu` layered above Pokédex | Shipped layered modal | Presents over the modern Pokédex only when the complete visible chain is modeled. |
| Town Map / Fly / AREA | `screenId="TownMap"`; map image, locations, selection, fly/nests | Vanilla | **P2.** Full-window map, responsive banner/details, grid navigation, fly list, blinking nest markers. |
| Options | `screenId="OptionsMenu"`; live descriptor rows | Dedicated rows | Shipped; allow stable-ID grouping only and never reorder unknown mod rows. |
| Third-party OptionRows settings | Plain registered screen with `rows`, `index`, `scroll`, `update`, and `draw`; known IDs include `RunModeOptions`, `ShinyPokemonOptions`, and `QualityOfLife` | Shared adapter | Shipped in v0.6.6; reads live labels/values, preserves source callbacks/input, and falls back for non-semantic custom screens. |
| Controls/bindings | `screenId="BindingsMenu"`; list fields plus `capture`/pending | Unsafe generic fallback | **P0 safety/P1 presenter.** Keep capture prompt vanilla now; later show logical control, existing bindings, reset/clear hints, and capture modal. |
| Mod manager | `screenId="ManagerState"`; screen/tab/rows/current mod/overlays | Dedicated presenter | Shipped across list, profiles, errors, detail, options, permissions, and apply; keep explicit adapter. |
| Quarantine report | `screenId="QuarantineReport"`; lines/offset/maxOffset | Vanilla | **P2.** Simple scrollable report with paging hints. |
| Naming | `screenId="NamingScreen"`; glyph grid, row/col/case/maxLen | Vanilla | **P2.** Responsive character grid supporting modded glyph/address pages; preset menu remains layered. |
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

## Start-menu and settings follow-up

The `START MOD MENUS` option now groups rows appended by other mods beneath a
single Start-menu entry while preserving their original descriptors and
callbacks. Keep this grouping conservative because the released hook does not
require every row to carry a mod identifier. The next settings polish should
add category headers or collapsible sections to Gen1 Modern UI's own options
without reordering or grouping unknown rows supplied by other authors.

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

The next implementation slice should focus on minimal UI sizing and settings
category polish, then Move Learn, PicBox, Naming, Town Map/Fly/AREA, and title
ContinueInfo. First complete released-game QA for
the v0.5.0 dialogue, title, Trainer, Party, Bill's PC, Pokédex, Bag, Shop, and Player-PC stack;
any unmodeled branch must keep the classic UI.
